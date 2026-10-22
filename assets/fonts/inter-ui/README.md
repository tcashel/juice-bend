# Static UI font assets

These static glyphs derive from [Inter 4.1](https://github.com/rsms/inter/releases/tag/v4.1), revision `e3a3d4c57d5ecc01453a575621882a384c1995a3`. The original regular and semibold TrueType files and the complete SIL Open Font License 1.1 are retained beside the atlas. Font data remains under that license. No proprietary system font is used.

The release archive is `https://github.com/rsms/inter/releases/download/v4.1/Inter-4.1.zip`, 33,707,794 bytes, SHA-256 `9883fdd4a49d4fb66bd8177ba6625ef9a64aa45899767dde3d36aa425756b11e`. Exact archive entries, input hashes, recipe and generated hashes are in `manifest.json`. The archive itself is a download artifact and need not be published.

`src/sans_font.bend` is generated data plus small Bend lookup functions. Its three faces are regular 14 px, semibold 14 px and semibold 22 px. Each contains 204 scalars: ASCII, Latin-1 and a small punctuation/arrow set matching the existing monospace font. Coverage uses 4 bits per pixel, packed least-significant nibble first into four U32 words per row. Each glyph has 32 rows, with shared zero rows and blocks in generated source. Font baseline/line-height is 16/24 for 14 px and 24/32 for 22 px.

Every glyph has nonnegative pixel placement and an integer advance that contains all its ink. A negative source left bearing moves the glyph right and enlarges its advance. Unsupported scalars use the visible replacement glyph. This is label typography only: no kerning, shaping, ligatures, CJK, emoji, IME or runtime font fallback is claimed. Canonical transcript text, selection and copy remain the responsibility of existing application code.

The application does not parse font files or run the packer. From the repository root:

```sh
python3 scripts/sans-font-pack.py --check src/sans_font.bend
python3 scripts/sans-font-pack.py --output /tmp/new-sans-font.bend
python3 scripts/sans-font-pack.py --rasterize /tmp/new-sans-atlas.json
```

Packing and validation need only Python's standard library. Re-rasterization explicitly requires Python 3.12.8, Pillow 11.1.0 and FreeType 2.13.2. The packer refuses existing output paths, verifies all source hashes, and rejects output that differs from the pinned atlas/module. It performs no network requests or font installation.

`glyph(face, code)` retrieves one glyph. `advance(glyph)` gives its integer advance. `row_word(glyph, word, y)` returns one packed word, with zero outside word 0–3 or row 0–31. `coverage(glyph, x, y)` returns coverage 0–15, with zero outside the 32×32 tile. Fetch the glyph once per scalar and reuse its rows while composing an existing canvas band; do not repeat the codepoint lookup per pixel.
