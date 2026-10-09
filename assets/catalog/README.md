# Minecraft block catalog

`blocks.json` is derived from PrismarineJS/minecraft-data, revision
`33a0f3e7323e124a81960a6d6c62df797d69cd85`:

- Java: `data/pc/26.1/blocks.json` (1,168 blocks)
- Bedrock: `data/bedrock/1.26.30/blocks.json` (1,356 blocks)

Source: https://github.com/PrismarineJS/minecraft-data/tree/33a0f3e7323e124a81960a6d6c62df797d69cd85

The combined catalog has 1,326 case-insensitive distinct display names, including
edition-exclusive and technical blocks. Shared names use the Java display name
and stack size, with aliases retained from both editions. It is a pinned snapshot,
not a promise of compatibility with every Minecraft release or modpack. The app
still accepts custom names (with a disclosed 64-item stack assumption).

Upstream declares the data MIT licensed. The original README, including its
license declaration and data-source credits, is preserved in UPSTREAM_README.md.
Credit: PrismarineJS/minecraft-data contributors. No textures or other Minecraft
assets are included.

Regenerate deterministically with `python3 scripts/build_block_catalog.py`.
