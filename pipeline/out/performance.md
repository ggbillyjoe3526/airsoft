# Performance review, SL3: Pass

No perf-budget.json exists (no baseline yet); judged against origin/main and the targets. No runtime code paths change.
- GLBs (hall_exit, hall_shutter, hall_wall, roof_truss): byte sizes identical to origin/main; accessor counts, vertex totals,
  triangles (2186/2142/1568/2256), materials (1) and primitives (1) identical. Vertex colours only. No new materials/surfaces,
  so no draw-call change.
- .import files: none in the diff; settings unchanged.
- RoofConfig: two Color defaults only (fallback path), no cost.
- Images: maps/cards depot 29 KB, range 20 KB, woodland 28 KB (cards total 77 KB, +1 KB net region of -3.7/+6.4/+1.9 KB);
  match pictures depot 399 KB (-6), range 290 KB (+172), woodland 261 KB (+19); wiki image 163 KB (not shipped).
  Net shipped growth about +0.2 MB against a 500 MB install budget: negligible. VRAM: JPEG imports are fixed-size per
  dimension, so file size does not change GPU memory.
- New test: one pass over the roof mesh's ~2.3k triangles (one cross product each) plus one mesh load: sub-millisecond in
  GUT; not game code, does not ship. No leaked nodes (no instantiation; mesh is a RefCounted).
Note: ASSETS.md line 46 states no per-file sizes for these pictures, so nothing there to update.
