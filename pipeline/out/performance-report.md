Task: BL6 · head e7725d6 · Verdict: Pass
Run: none (asset-only change, no GDScript; glb JSON inspected with python, no Godot run) · budget: no baseline yet, judged against the 40k-triangle replica limit and origin/main's glb

Metrics (cyber.glb, old -> new), measured from the glb JSON:
- Triangles in the hands (all meshes except Figure): 2,688 -> 31,594 (limit 40,000, ok, 79 %)
- Figure (bot LOD): 148 -> 236 tris, 270 -> 426 verts (small, ok)
- Vertices total: 5,380 -> 27,578 (Body 19,887)
- Meshes 6 -> 6, nodes 18 -> 18, materials 5 -> 5 (shared, same set), animations 4 -> 4
- Surfaces (primitives): 16 -> 18; hands-side draw calls ~14 -> ~14+2 (Selector 1->2, Trigger 1->2); Figure 4 prims unchanged
- Images/textures: 0 / 0 (no textures, ok); extensions: none
- File size: 171,708 -> 879,740 bytes (+0.7 MB, 0.17 % of the 500 MB install budget, ok)

Regressions (> 10 % worse): triangle count, vertex count and file size are up, all inside budget. Only the 2 extra surfaces touch the draw-call count (+2 per viewmodel, negligible). Judgment, not blocking.

Blocking findings: none
 - Per-frame work: no .gd/.tscn/.tres/config changed (diff is glb, tools/blender/replicas/cyber.py, docs, changelog); nothing runs per frame or per tick (judgment, verified by diff stat).
 - cyber.py is an offline Blender build tool under tools/, not referenced by game code or exports (judgment).
 - Materials stay shared by name (5 per file), no per-instance materials introduced (measured).

Advisory:
 - Body is 24,422 tris, 77 % of the hands budget; further detail on this replica or a second pistol of this weight leaves little headroom. Re-measure on the owner's hardware at the next playtest (frame time is not measurable in the cloud container).
 - Selector and Trigger now carry 2 primitives each; if they share a material, merging them saves 2 draw calls per viewmodel (minor).
 - The record's 31,596 differs from the measured 31,594 by 2 triangles; cosmetic.

Fixes: none required.

Verdict: Pass
