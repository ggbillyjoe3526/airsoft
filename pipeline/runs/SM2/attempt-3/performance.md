Task: SM2 · head 2cc241a · Verdict: Pass
Run: delta review of 2cdc8a5 and 658b211 over attempt 2 (no --perf rerun; no change to script paths that run per tick beyond one gated function) · budget: no baseline yet (pipeline/perf-budget.json absent), judged against targets and attempt 2
Metrics: not re-measured. Draw calls need a rendered run; frame times are owner hardware only.
Regressions (> 10 % worse): none found (judgment)
Blocking findings: none
Checked, clean (judgment):
- game/play/lift_view.gd:417-430 `_leaf()`: adds a Basis and at most one 180 degree Basis multiply per leaf. These are value types on the stack, no heap allocation. It runs only from `_place_leaves` (line 387), which is gated on a change of y, doors or stop, and writes into the preallocated `_leaf_xforms` and the one leaves MultiMesh. Not per frame while a lift is idle; a few dozen float ops per leaf while it moves.
- Lift landing: 734 tris (cap 1,200, was 728). Escalators and stair keep their tri counts. Still one MultiMesh for landings, so draw calls and shadow cost are unchanged.
- Lower wear values in config: constants read at load, no new material, shader or uniform, so no prewarm entry is needed.
- data/maps/subway.json lane points: static data read at load, no per-tick work.
- Other delta files are Blender build tools (tools/blender, tools/subway) and records, not shipped runtime code. No new node, timer, signal or tween, so nothing to free and no unbounded growth. Presets are not bypassed.
Advisory:
- As before: the owner should confirm Subway holds 60 FPS on the Low rig; trim escalator detail first if it dips.
Fixes: none required.
Unexplained: none
