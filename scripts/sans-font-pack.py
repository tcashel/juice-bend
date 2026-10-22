#!/usr/bin/env python3
"""Offline static font asset packing; never imported or run by the application.

--check validates pinned assets and the deterministic Bend packing using stdlib.
--output NEW_FILE packs the checked-in atlas without loading any font library.
--rasterize NEW_FILE independently regenerates the atlas with the pinned recipe.
Every write uses exclusive creation. No network requests, font installation,
runtime font parsing, application rendering policy, or application test logic.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "assets/fonts/inter-ui"
LIMIT = 4 * 1024 * 1024
CODES = list(range(32, 127)) + list(range(160, 256)) + [
    8211, 8212, 8216, 8217, 8220, 8221, 8226, 8230, 8592, 8593, 8594, 8595, 65533,
]
FACES = [
    {"id": 0, "font": "Inter-Regular.ttf", "size": 14, "baseline": 16, "height": 24},
    {"id": 1, "font": "Inter-SemiBold.ttf", "size": 14, "baseline": 16, "height": 24},
    {"id": 2, "font": "Inter-SemiBold.ttf", "size": 22, "baseline": 24, "height": 32},
]


def require(ok: bool, message: str) -> None:
    if not ok:
        raise ValueError(message)


def read(path: Path) -> bytes:
    require(path.is_file() and not path.is_symlink() and path.stat().st_size <= LIMIT,
            f"Not a bounded regular file: {path.name}")
    return path.read_bytes()


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def encoded(value: object) -> bytes:
    return (json.dumps(value, ensure_ascii=True, separators=(",", ":")) + "\n").encode()


def checked_assets() -> tuple[dict, dict, str]:
    manifest = json.loads(read(ASSETS / "manifest.json"))
    require(manifest["schema_version"] == 1, "Unknown font manifest schema")
    for filename, digest in manifest["input_sha256"].items():
        require(Path(filename).name == filename, "Unexpected font input path")
        require(sha(read(ASSETS / filename)) == digest, f"Input hash mismatch: {filename}")
    atlas_bytes = read(ASSETS / "atlas.json")
    require(sha(atlas_bytes) == manifest["atlas_sha256"], "Atlas hash mismatch")
    preamble = read(ASSETS / "preamble.bend")
    require(sha(preamble) == manifest["preamble_sha256"], "Preamble hash mismatch")
    require(preamble.endswith(b"\n\n"), "Preamble must end with two newlines")
    atlas = json.loads(atlas_bytes)
    require(atlas["schema_version"] == 1 and atlas["format"] == "u32-rows-little-nibble-x" and
            atlas["coverage_bits"] == 4 and atlas["glyph_size"] == [32, 32], "Unexpected atlas format")
    require(len(atlas["faces"]) == 3, "Unexpected face count")
    for expected, face in zip(FACES, atlas["faces"], strict=True):
        require(all(face[k] == v for k, v in expected.items()), "Unexpected face metrics")
        require([g["codepoint"] for g in face["glyphs"]] == CODES, "Unexpected glyph inventory")
        for glyph in face["glyphs"]:
            require(1 <= glyph["advance"] <= 32 and len(glyph["rows"]) == 32, "Invalid glyph geometry")
            for row in glyph["rows"]:
                require(len(row) == 4 and all(type(w) is int and 0 <= w <= 0xffffffff for w in row),
                        "Invalid packed row")
                for x in range(glyph["advance"], 32):
                    require((row[x // 8] >> (4 * (x % 8))) & 15 == 0, "Ink exceeds advance")
    return manifest, atlas, preamble.decode()


def packed_row(row: list[int]) -> str:
    return "zero_row()" if not any(row) else "Row{" + ",".join(map(str, row)) + "}"


def packed_rows(rows: list[list[int]]) -> str:
    if not any(any(r) for r in rows):
        return "zero_rows()"
    return "Rows8{" + ",".join(packed_row(row) for row in rows) + "}"


def packed_glyph(glyph: dict) -> str:
    return "Glyph{" + str(glyph["advance"]) + "," + ",".join(
        packed_rows(glyph["rows"][y:y + 8]) for y in range(0, 32, 8)) + "}"


def tree(glyphs: list[dict], name: str, missing: str) -> str:
    if len(glyphs) == 1:
        glyph = glyphs[0]
        return (f"def {name}.choose(valid: Bool) -> Glyph:\n  match valid:\n"
                f"    case True{{}}: {packed_glyph(glyph)}\n    case False{{}}: {missing}()\n\n"
                f"def {name}(code: U32) -> Glyph:\n  {name}.choose(U32.is_eq(code,{glyph['codepoint']}))\n\n")
    mid = len(glyphs) // 2
    return (tree(glyphs[:mid], name + "l", missing) + tree(glyphs[mid:], name + "r", missing) +
            f"def {name}.choose(code: U32,left: Bool) -> Glyph:\n  match left:\n"
            f"    case True{{}}: {name}l(code)\n    case False{{}}: {name}r(code)\n\n"
            f"def {name}(+code: U32) -> Glyph:\n  {name}.choose(code,U32.is_lt(code,{glyphs[mid]['codepoint']}))\n\n")


def generate(atlas: dict, preamble: str) -> bytes:
    text = preamble
    for face in atlas["faces"]:
        name = f"face{face['id']}"
        text += f"def {name}.missing() -> Glyph:\n  {packed_glyph(face['glyphs'][-1])}\n\n"
        text += tree(face["glyphs"], name, name + ".missing")
    text += ("def glyph(face: U32,code: U32) -> Glyph:\n  match face:\n"
             "    case 1: face1(code)\n    case 2: face2(code)\n    case _: face0(code)\n")
    return text.encode()


def rasterize() -> bytes:
    from PIL import Image, ImageDraw, ImageFont, features
    import PIL
    require(sys.version_info[:3] == (3, 12, 8), "Rasterization requires Python 3.12.8")
    require(PIL.__version__ == "11.1.0" and features.version("freetype2") == "2.13.2",
            "Rasterization requires Pillow 11.1.0 / FreeType 2.13.2")
    faces = []
    for spec in FACES:
        font = ImageFont.truetype(str(ASSETS / spec["font"]), spec["size"], layout_engine=ImageFont.Layout.BASIC)
        glyphs = []
        for code in CODES:
            char = chr(code)
            left, top, right, bottom = font.getbbox(char, anchor="ls")
            origin_x = max(0, -left)
            advance = max(1, math.ceil(font.getlength(char)) + origin_x, right + origin_x)
            require(advance <= 32 and top + spec["baseline"] >= 0 and
                    bottom + spec["baseline"] <= spec["height"], f"Glyph does not fit: {spec['id']}:{code}")
            image = Image.new("L", (32, 32), 0)
            ImageDraw.Draw(image).text((origin_x, spec["baseline"]), char, font=font, fill=255, anchor="ls")
            pixels = image.load()
            rows = [[sum(((pixels[word * 8 + x, y] + 8) // 17) << (4 * x) for x in range(8))
                     for word in range(4)] for y in range(32)]
            glyphs.append({"codepoint": code, "advance": advance, "origin_x": origin_x, "rows": rows})
        faces.append({**spec, "glyphs": glyphs})
    return encoded({"schema_version": 1, "format": "u32-rows-little-nibble-x", "coverage_bits": 4,
                    "glyph_size": [32, 32], "faces": faces})


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", type=Path)
    mode.add_argument("--output", type=Path)
    mode.add_argument("--rasterize", type=Path)
    args = parser.parse_args()
    manifest, atlas, preamble = checked_assets()
    result = rasterize() if args.rasterize else generate(atlas, preamble)
    expected = manifest["atlas_sha256"] if args.rasterize else manifest["generated_bend_sha256"]
    require(sha(result) == expected, "Regenerated bytes differ from pinned output")
    if args.check:
        require(read(args.check) == result, "Checked Bend module differs from packed atlas")
    else:
        target = args.output or args.rasterize
        with target.open("xb") as out:
            out.write(result)
    print(json.dumps({"mode": "check" if args.check else "rasterize" if args.rasterize else "output",
                      "faces": 3, "glyphs_per_face": len(CODES), "bytes": len(result), "sha256": sha(result)}))


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"sans-font-pack: {error}", file=sys.stderr)
        sys.exit(1)
