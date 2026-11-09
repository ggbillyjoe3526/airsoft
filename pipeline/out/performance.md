# Performance: SL1 · Sunlit Concrete: the light, grade and paint

Head e8aada2 (4493a30 plus a palette-only commit) · Verdict: **Pass** (judgment; no GPU in the cloud, no frame times)

- **GDScript:** nothing new per frame. One more key in `LookConfig.globals()`, pushed once a match. No new nodes,
  timers, tweens or connections.
- **look_paint():** one dot, one mix and a few multiplies on ALBEDO in look_vertex, look_clear, site_surface and
  door_leaf. No texture reads, no branches: negligible.
- **Site-surface grit 0.6 (was 0):** the grit branches are uniform-gated (no divergence) but now run on every
  site-surface fragment: roughly 3 to 6 more fbm samples (single channel, small, mipmapped) on slab, wall and ground,
  and the plywood's colour and normal samples on plywood. The heaviest fragments in a scene; only the owner's card can
  say whether Low still holds 60 FPS.
- **Memory:** the plywood photo pair (1k, VRAM-compressed with mips) now loads: about 2.7 MB of VRAM, shared by every
  material (ResourceCache). The slab set was already loaded. No new files on disk; the rebaked depot.res and range.res
  got smaller.
- **Shader warm-up:** no new material or shader; the plywood textures bind at map load.

Advisory: measure Low on Depot and the Range (F3) before and after. If over budget: gate the fine fbm samples by
preset, or grit 0 on Low, or bake the wear into a mask texture. Recorded in docs/KNOWN_ISSUES.md and the record.
