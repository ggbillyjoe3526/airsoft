Task: CR1 · head e9cd944 · Verdict: Pass
Run: smoke match (Depot, fixed seed, `--smoke --perf`), headless, both heads; plus a scratch bench (Woodland, 947 blocks) on both · budget: no baseline yet (pipeline/perf-budget.json absent), judged against targets and origin/main (8badf9e)
Metrics: nodes_max 1206 / 1206 (ok), orphans_max 792 / 792 (ok, same on main), steady nodes 978 / 978 (ok), draw calls 0 (headless, not measurable), smoke wall 89 s / 86 s (reported only; frames 2177 vs 1954 differ because headless frame count tracks speed, not ticks; shots/impacts/rounds identical)
Regressions (> 10 % worse): none. NavGrid.build Woodland, 5 runs each: main 5.2-6.3 s (median 5.7), cr1 5.2-6.3 s (median 6.2); ranges overlap, machine noise; nodes 528400 -> 529096
Blocking findings: none
 - Freed RIDs/bodies (judgment + measured): game/map/map_level.gd:262-267 appends the low body and its shape to _rids, bodies before shapes, freed in PREDELETE (map_level.gd:174-178). Bench: Object count 4962 -> 2990 after level.free(), identical on main and cr1.
 - Per-tick allocations (judgment): none new. JoltMover._use (jolt_mover.gd:107) swaps an RID and a float; room_to_stand, low_ahead, BoxWorld.sweep(height) and Elimination's crouch line use only Vector3 values; NavGrid.low is one PackedByteArray built at load; the params/result objects are still reused.
 - Build cost (measured): NavGridBuilder._stamp_low alone 100-175 ms of a ~6 s Woodland build (about 2-3 %), once at load behind the loading screen. 1659 low nodes of 529096.
 - Per-tick cost (measured, scratch bench, Woodland, GDScript timing): move+probe 174 us tall / 197 us low (main 193 us, noise); room_to_stand 41 us per low character per tick; low_ahead 5.4 us per bot per tick (node_at 0.7 us). Twelve crouched characters cost about 0.5 ms of the 16.7 ms tick worst case; typical is a few.
Advisory:
 - game/sim/movement.gd:39: `c.low and not mover.room_to_stand(c)` sweeps every tick while crouched, even when crouch is held and the answer is unused. `not cmd.crouch and c.low and ...` skips the 41 us sweep for the held-crouch case (player crouching, bots in cover) and keeps the result identical. Not blocking.
 - game/nav/nav_grid_builder.gd:231: _stamp_low walks every block's cells, unlike _stamp_blocks which skips non-surface blocks first; a cheap bottom-height pre-check would shave the ~150 ms. Load-time only.
 - game/ai/bot_brain.gd:101: low_ahead runs for every moving bot every think; fine at 12 bots, would be worth caching per node if bot counts grow.
Fixes, ranked: none required. (1) skip room_to_stand while crouch is held; (2) pre-filter blocks in _stamp_low.
Unexplained: the headless smoke frame count (2177 vs 1954) is not attributable to the diff (node, shot and impact counts are identical); likely run-speed noise in headless mode.
Not measured: rendered frame times and draw calls (no GPU in this container); owner's hardware.
