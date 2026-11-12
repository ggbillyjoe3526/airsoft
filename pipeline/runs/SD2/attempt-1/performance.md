Task: SD2 · head 4c4948c · Verdict: Pass
Run: headless GUT timing of StationDetail.build on Subway (805 blocks, 95 zones), 3 builds; no GPU, so no draw-call or frame-time run · budget: no baseline yet (pipeline/perf-budget.json does not exist), judged against targets and the diff. No origin/main bot-match run: the change has no per-tick code.
Metrics (all with a full check running elsewhere, so times are inflated):
- Build time at session load: 63 / 51 / 46 ms (first, second, third) (measured, ok). One-off, inside _dress_part, not per frame. Real time is lower.
- Triangles: 17,580 in 1 surface (measured). The GUT test bounds it to 2k-80k. The budget file has no triangle line, so this is reported only; about 17.6k tris is small for a Forward+ desktop target.
- Draw calls: +1 (one MeshInstance3D, one surface, one material) (judgment from code, measured child count 1). Shadows off, so no shadow-pass copies.
- Per-frame allocations: none (measured by reading). The script has no _process, _physics_process, signal or connection. Every Array, Dictionary, Run, SurfaceTool and _Solids is created only inside build().
- Frees: the node is add_child'd to the session, as GatePaddles is, so the mesh and the material (RefCounted, held only by the node) go with it. My build/free loop ran clean. A null return after pieces == 0 calls d.free().
Regressions (> 10 % worse): none measurable (no baseline; the only added runtime cost is a one-off build and +1 draw).
Blocking findings: none
Advisory:
- station_detail.gd:21-100: build cost scales with rooms x runs x 4 probe heights. 6 m x-buckets keep it cheap on Subway (about 50 ms). If a larger station arrives, probe in a cheaper way or build in the existing _dress_part chunks. (judgment)
- station_detail.gd:42: material is a new ShaderMaterial per session, but it shares VERTEX_SHADER and is in first_use (play_session.gd:942), so no first-use hitch. (ok)
- station_detail.gd:343/_near_lamp is a linear scan of roof_lamps for every hatch candidate; load only, fine now. (judgment)
- No LOD or visibility range on the single mesh: 17.6k tris are always submitted when the camera is anywhere in the station; the whole station is one mesh, so culling is all-or-nothing. Fine at this size; recheck on the owner's Low-preset hardware. (judgment)
- The new tactile strips in tools/subway/station_dress.py and data/maps/subway.json add a few boxes to the existing dress; no new material. Not measured separately. (judgment)
Presets: no shadows, no resolution or post effect, no draw distance; no preset bypass.
Fixes: none required.
Unexplained: none. The temporary GUT test was deleted; git status is clean of it.
