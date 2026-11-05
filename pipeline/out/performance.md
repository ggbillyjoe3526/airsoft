Task: BL3 · AEG Rifle rework · head working tree (uncommitted) · Verdict: Pass
Run: no game run; model-only change (no GDScript, scenes or config), so measured by parsing the glb JSON chunks (python3 -I) · budget: no pipeline/perf-budget.json lines; judged against the contract (replicas 40,000 tris in hands, 2K textures, 7 materials) and main's glbs
Metrics (main -> now, measured from glb accessors):
 aeg.glb    file 1,126,816 -> 1,131,788 B (+0.4 %) · meshes 12 -> 12 · primitives (draw calls) 26 -> 26 · materials 7 -> 7 (limit 7, ok) · textures/images 0 -> 0 · nodes 31 -> 31
 aeg.glb    triangles all meshes 40,038 -> 40,156 (+0.3 %); in the hands (minus Figure 340) 39,816 (limit 40,000, ok, 184 spare; matches the build log)
 sniper.glb file 1,157,204 -> 1,162,692 B (+0.5 %) · meshes 12 · primitives 26 -> 26 · materials 7 -> 7 (ok) · textures 0 · nodes 31
 sniper.glb triangles all meshes 40,178 -> 40,296 (+0.3 %); in the hands (minus Figure 360) 39,936 (limit 40,000, ok, only 64 spare)
Regressions (> 10 % worse): none
Blocking findings: none
Advisory:
 - tools/blender/replicas/sniper.py (derives from aeg.py): sniper hands total is 39,936, 64 tris under the budget; any further AEG body growth will push the sniper over. Judgment, not blocking.
 - Body is 30,996 tris of the 39,816 (78 %); if later work needs room, the Body mesh is where to trim. Judgment.
 - Textures: none embedded (flat materials), so no 2K texture or VRAM cost; file size delta is mesh data only (+5 KB each). Measured.
 - No code, scene or config change: no per-frame allocations, node or resource lifetime, or prewarm impact (7 materials unchanged, so no new shader variants). Judgment.
Fixes: not needed.
