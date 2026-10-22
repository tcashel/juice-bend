# Synthetic Zstandard fixture provenance

These compact manifests describe only synthetic, offline fixtures used by the maintained Bend tests. No binary fixtures, private histories, reference-source copies, local encoder installation paths or redundant compressed hex are included. The application never launches an encoder or external decoder.

- `manifest.json`: ten complete frame variants, independent raw byte counts and SHA256 values, and exact encoded identities.
- `block-manifest.json`: three compressed block payloads, their original full-frame membership, and independent raw expectations.
- `multiblock-2000-manifest.json`: three complete 2,000-record variants, block modes, measured decoded extents, table reuse and raw-block insertion.
- `empty-rle-manifest.json`: independent empty RLE edge case checked with the external offline oracle.
- `oracle-manifest.json`: the exact offline encoder version and binary identity used for fixture generation/cross-checks.

The maintained test modules independently construct expected raw bytes and compare every decoded byte. Source hashes identify the current vector module text; original hashes preserve preparation provenance. The format reference is [Zstandard v1.5.7 format](https://github.com/facebook/zstd/blob/v1.5.7/doc/zstd_compression_format.md). These manifests are evidence, not decoder acceptance results; native test receipts remain separate.
