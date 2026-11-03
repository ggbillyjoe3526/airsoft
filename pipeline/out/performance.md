Task: HV1 · head e3f2984 · Verdict: Pass
Run: micro-benchmark only (16 characters moving, headless, 2000-20000 iterations); no --perf match run · budget: no baseline yet, judged against targets and origin/main's built-in path
Metrics: build_volume fitted 51 us vs built-in 35 us (measured); may_touch 3.1 us/call incl. loop (measured); OBJECT_COUNT delta over 5000 builds 0 / 0 (no leaks, measured)
Regressions (>10 %): fitted build +45 % per build, by design; offset by lazy build (see advisory)
Blocking: none
 - Per-tick allocation: none found in _build_fitted, _fit_pose, _add_*, _legs, may_touch (statics reused; Vector3/Quaternion/Transform3D are values; HitFit.table()/rest() cache once, held by the resource).
Advisory:
 - game/sim/hitbox.gd _build (built-in path): `for k: int in [CHEST_R, CHEST_FRONT, CHEST_BACK]` allocates an Array per build (judgment); only fit==null and tests, not shipped path. Unroll or const PackedInt32Array.
 - game/ai/bot_combat.gd:389 _ahead_in_line rebuilds the mate's volume (up to 3 builds per mate per check: 351/367/389, ~50 us each) (judgment). Worst case 16 chars x 3 = ~2.4 ms per check, but only for walking in-play mates the line already passed may_touch for; consider reusing the unshifted build.
 - game/sim/bb_step.gd:215 may_touch runs per BB per character (3 us each): 30 BBs x 16 = ~1.4 ms/tick worst case if all pass the loop (judgment); a bound check ray_character does anyway, so a fused early-out would save it. Builds stay capped at 16/tick (0.8 ms).
 - game/sim/hit_fit.gd table(): first-use build per field at first fitted build (one-time hitch in a match, small); consider warming at start (judgment).
 - game/sim/hitbox.gd _add_gait: Geometry2D calls and nested loops on gait fallback path only; fine.
Fixes ranked: 1) reuse build in _ahead_in_line; 2) const array in _build; 3) warm HitFit tables at load.
