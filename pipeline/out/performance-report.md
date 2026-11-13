Task: BU1 · head e7a3add · Verdict: Pass
Run: none (no --perf run; the smoke test plays Depot, which has no bushes, and the brief says tools/check.sh owns the CPU) · budget: no baseline yet (pipeline/perf-budget.json absent), judged against targets and origin/main's code
Metrics: not measured (judgment only). Node count, orphans, memory: unchanged by construction, the diff adds no nodes or resources.
Regressions (> 10 % worse): none measured
Blocking findings: none
Advisory:
- game/ai/bot_combat.gd leaves_in_line (judgment): the close branch adds a Vector3 subtraction, a length(), two config reads and a Vector3 multiply-add. All are stack values with no heap allocation. Still one Foliage.depth() call per call, as before.
- game/ai/bot_combat.gd leaves_in_line (judgment): depth() scans only the grid cells the line's box covers and returns early once past `limit`. The close line is under 2.5 m across and stops at leaf_stop_depth, so it is cheaper than or equal to the old far-line call.
- Early-out for maps without foliage (null or empty) is kept first; Depot and other bush-free maps pay nothing.
- leaves_in_line is called up to 3 times per bot per tick (shoot, _knee_has_shot, _line_of_fire_blocked). That was true before the change. Caching per tick is not needed at this cost.
- Side effect (judgment): bots in a bush now shoot rather than stall. That means more BBs from pooled projectiles in those fights, which are already pooled.
- No new Callable, lambda, timer, tween, signal or material; no prewarm or preset impact. Diff in game/ is code, comments and docs only.
Fixes: none needed
Unexplained: none. A Woodland --perf comparison on the owner's setup is welcome but not blocking.
