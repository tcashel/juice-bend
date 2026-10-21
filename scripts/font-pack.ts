// Offline asset packing only. The application renders the resulting data in Bend.
import { createHash } from "node:crypto";
import { readFileSync, statSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

function requireValue(ok: unknown, message: string): asserts ok {
  if (!ok) throw new Error(message);
}

function sha256(bytes: Uint8Array): string {
  return createHash("sha256").update(bytes).digest("hex");
}

function readBounded(path: string): Buffer {
  const stat = statSync(path);
  requireValue(stat.isFile() && stat.size <= 1_048_576, `Invalid or oversized asset: ${path}`);
  return readFileSync(path);
}

function glyph(rows: number[]): string {
  return `Glyph{Half{${rows.slice(0, 8).join(",")}},Half{${rows.slice(8).join(",")}}}`;
}

type Glyph = { codepoint: number; rows: number[] };

function tree(items: Glyph[], name: string): string {
  if (items.length === 1) {
    const item = items[0];
    return `def ${name}.choose(valid: Bool) -> Glyph:\n  match valid:\n    case True{}: ${glyph(item.rows)}\n    case False{}: missing()\n\ndef ${name}(code: U32) -> Glyph:\n  ${name}.choose(U32.is_eq(code,${item.codepoint}))\n\n`;
  }
  const middle = Math.floor(items.length / 2);
  return tree(items.slice(0, middle), `${name}l`) + tree(items.slice(middle), `${name}r`) +
    `def ${name}.choose(code: U32,left: Bool) -> Glyph:\n  match left:\n    case True{}: ${name}l(code)\n    case False{}: ${name}r(code)\n\ndef ${name}(+code: U32) -> Glyph:\n  ${name}.choose(code,U32.is_lt(code,${items[middle].codepoint}))\n\n`;
}

function rowsValid(rows: unknown): rows is number[] {
  return Array.isArray(rows) && rows.length === 16 &&
    rows.every(word => Number.isInteger(word) && word >= 0 && word <= 0xffff_ffff);
}

function main(): void {
  requireValue(Bun.version === "1.4.2", "Use the repository's pinned Bun 1.4.2 through scripts/font-pack");
  const args = process.argv.slice(2);
  requireValue(args.length === 2 && ["--check", "--output"].includes(args[0]),
    "Usage: scripts/font-pack --check EXISTING_FONT | --output NEW_FILE");
  const assets = resolve(dirname(fileURLToPath(import.meta.url)), "../assets/fonts/jetbrains-mono");
  const manifest = JSON.parse(readBounded(resolve(assets, "manifest.json")).toString("utf8"));
  const atlasBytes = readBounded(resolve(assets, "atlas.json"));
  const preambleBytes = readBounded(resolve(assets, "preamble.bend"));
  requireValue(manifest.schema_version === 1, "Unknown font manifest schema");
  requireValue(sha256(atlasBytes) === manifest.atlas_sha256, "Quantized atlas hash mismatch");
  requireValue(sha256(preambleBytes) === manifest.preamble_sha256, "Bend preamble hash mismatch");
  requireValue(sha256(readBounded(resolve(assets, "JetBrainsMono-Regular.ttf"))) === manifest.font_sha256,
    "Pinned source font hash mismatch");
  requireValue(sha256(readBounded(resolve(assets, "OFL.txt"))) === manifest.license_sha256,
    "Font license hash mismatch");
  const atlas = JSON.parse(atlasBytes.toString("utf8"));
  requireValue(atlas.schema_version === 1 && atlas.format === "u32-rows-little-nibble-x" &&
    JSON.stringify(atlas.glyph_size) === "[8,16]" && atlas.coverage_bits === 4 &&
    atlas.advance === 8 && atlas.baseline === 12, "Unexpected atlas geometry or encoding");
  const preamble = preambleBytes.toString("utf8");
  requireValue(preamble.endsWith("\n\n"), "Invalid Bend preamble terminator");
  requireValue(rowsValid(atlas.missing_rows), "Invalid fallback glyph rows");
  const expectedCodes = [
    ...Array.from({ length: 95 }, (_, index) => index + 32),
    ...Array.from({ length: 96 }, (_, index) => index + 160),
    8211, 8212, 8216, 8217, 8220, 8221, 8226, 8230, 8592, 8593, 8594, 8595, 65533,
  ];
  requireValue(Array.isArray(atlas.glyphs) && atlas.glyphs.length === expectedCodes.length &&
    manifest.glyph_count === expectedCodes.length, "Unexpected glyph inventory");
  atlas.glyphs.forEach((item: Glyph, index: number) => {
    requireValue(item.codepoint === expectedCodes[index] && rowsValid(item.rows),
      `Invalid codepoint order or packed rows at glyph ${index}`);
  });
  const result = Buffer.from(preamble + `def missing() -> Glyph:\n  ${glyph(atlas.missing_rows)}\n\n` +
    tree(atlas.glyphs, "glyph"), "utf8");
  const digest = sha256(result);
  requireValue(digest === manifest.generated_bend_sha256, "Generated Bend hash differs from manifest");
  const target = resolve(args[1]);
  if (args[0] === "--check") {
    requireValue(readBounded(target).equals(result), "Generated Bend differs from the checked file");
  } else {
    // Refuse existing paths, including symlinks. Adoption is a separate reviewed edit.
    writeFileSync(target, result, { flag: "wx", mode: 0o644 });
  }
  console.log(JSON.stringify({ mode: args[0], glyphs: atlas.glyphs.length, bytes: result.length,
    sha256: digest, bun: Bun.version }));
}

try {
  main();
} catch (error) {
  console.error(`font-pack: ${error instanceof Error ? error.message : String(error)}`);
  process.exitCode = 1;
}
