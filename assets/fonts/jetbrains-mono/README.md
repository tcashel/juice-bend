# Native font data

The reader and controls draw 204 grayscale glyphs from JetBrains Mono 2.304.
The original font and derived glyph data are covered by the included
`OFL.txt`. `manifest.json` records the upstream URL, source hashes, geometry and
original raster recipe. No system or proprietary font is redistributed.

`atlas.json` is the checked-in quantized data; `preamble.bend` contains the
visible Bend helpers. The offline packer verifies both files, the source font,
the license and the explicit glyph inventory before emitting `src/font.bend`.
It does not rasterize the TrueType font again. Normal app builds use the Bend
source directly and require no font generator or Python packages.

```sh
mise run font-check
# Requires build/ and refuses to overwrite an existing output:
mise run font-pack
```

Both tasks use the repository's Bun 1.4.2 pin. The generated output must match
the hash in the manifest. Regeneration never silently overwrites application
source. Changing the glyph inventory or raster recipe requires an explicit
asset update and native visual/selection verification.

The atlas covers ASCII, Latin-1 and selected punctuation/arrows. Unsupported
characters use a fallback box; underlying selection, clipboard and exports
retain the original Unicode text. This is not font shaping, bidirectional
layout or complete IME support. The fixed window remains an upstream runtime
constraint.
