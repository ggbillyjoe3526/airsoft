Task: SM2 · head 9d70160 · Verdict: Pass
Run: delta review of 9d70160 over attempt 1 (no headless --perf rerun this attempt; the delta changes no script paths) · budget: no baseline yet (pipeline/perf-budget.json absent), judged against targets and attempt 1
Metrics: not re-measured. Draw calls need a rendered run (none here); frame times are owner hardware only.
Regressions (> 10 % worse): none found (judgment)
Blocking findings: none
Checked, all clean (judgment):
- Escalator meshes: 7,292 and 6,644 tris, under the 8,000 cap and about the same as attempt 1 (7.4k and 6.7k). Each is one SET, so no extra draw calls. Smooth shading and deck seams add no surfaces or materials.
- Lift landing linings: 728 tris (was 728 in attempt 1, cap 1,200). Still 6 landings in one MultiMesh. Stair treads ribbed with unchanged tri counts, so vertex load and shadow-pass cost are unchanged.
- game/config/prop_dress_config.gd (+4 lines): const dictionary entries for roughness and wear. They are read at load time. No new material, shader or uniform, so there is no first-use hitch and no prewarm entry is needed.
- data/maps/subway.json: one more barrier block per escalator bank, plus z offsets of 1.6 to 1.2 on other entries. This is a handful of static colliders and boxes at level load. It adds no per-frame or per-tick work and no allocation in a hot path.
- Scripts in the delta are Blender build tools only (tools/blender/, tools/subway/), not shipped runtime code. No new _process, tick, signal or timer code, so there is no new allocation, no unfreed node or resource and no unbounded growth. Presets are not bypassed.
Advisory:
- Same as attempt 1: the owner should confirm Subway holds 60 FPS on the Low rig. If it dips, trim the escalator detail first.
Fixes: none required.
Unexplained: none
