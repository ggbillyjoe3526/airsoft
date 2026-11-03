Task: SN3 · head 704372c + staged diff · Verdict: Pass
Run: tools/team_bench.gd, Street 8v8, 60 s match time, seed 1, headless (no GPU), 2 runs each on head and on origin/main (704372c, scratch worktree) · budget: no baseline yet (pipeline/perf-budget.json absent), judged against targets and origin/main
Metrics (tick mean / p95 / p99 ms, 2 runs): head 2.70, 2.68 / 5.98, 6.01 / 8.53, 7.30; main 2.93, 2.90 / 6.88, 6.79 / 8.53, 8.66. Frame (views) mean 1.0 both. Frames over 16.7 ms: head 3 and 2 of 3600, main 2 and 2. Worst-tick spikes 17 to 24 ms on both (noise on a shared 4-core box). All measured. Frame times reported only, not owner hardware.
Regressions (> 10 % worse): none (head is not slower; the spread is run noise). Node, orphan and memory monitors not touched by the diff (no scene, node, or resource added).
Caveat: the bench plays the shipped kits (Dev content off, no Sniper Rifle), so the scoped and revealed branches ran mostly on their early-out. Their cost is judged by reading below.

Blocking findings: none.
- game/ai/bot_senses.gd:112 sight_reach (judgment): per bot per candidate per perceive. Runs on the 0.1 s think tick (bot_brain.gd:36, think_interval 0.1), not every tick, and only after the `d >= best_d` skip, so only for enemies nearer than the best so far. Scalar math, two property reads, one id compare; no allocation. At 16 bots x <= 8 enemies x 10 Hz that is about 1300 calls/s of a few dozen ops. Negligible.
- game/ai/bot_combat.gd:205 scoped / :210 fights_aimed (judgment): scoped also runs in aim() every tick per bot with a target (bot_combat.gd:38). Two Armament.replica() lookups (array index) plus compares. No allocation. Negligible.
- game/ai/bot_combat.gd:194 bolt_waits (judgment): in shoot(), after the cheap aimed-raise early-out; short-circuits on in_hand.bolt_action (false for every AEG kit) before the settling() maths. No allocation.
- game/ai/bot_hearing.gd:87 _hit_call loop over w.bots (judgment): once per CHARACTER_HIT, at most 16 iterations of is_in_play and distance_to (float, no allocation). Hits are a few per round, not per tick. The new `var c` / `for b` are plain locals. Fine. reveal() at :196 writes two fields, no allocation.
- game/ai/bot.gd:157,327 (judgment): two scalar fields per Bot, reset in reset(); no leak, no pooling concern.
- game/config/bot_config.gd (judgment): five new @export scalars, read from cfg (cached local in the hot paths); no per-call allocation, no preset or shader involvement.
- data/maps/street.json / tools/street/layout.py:468 (judgment): one box ("bins") added to the Street's obstacle list. Adds one collider and one grid/nav bake cell set at load, plus one more occluder in sight rays on the Path; no new material or mesh type (reuses the box generator), so no prewarm entry is missing. Did not open the JSON.
- tests/support/match_runner.gd:186 kits_now: test support only, never shipped; a reference to an existing array (no copy).
- tests/balance/sniper_bench.gd: dev only, never exported; not reviewed for runtime cost.

Advisory: none.
Fixes: none needed.
Unexplained: none. The worst-tick spikes (17 to 24 ms) appear in both head and main runs, so not attributable to the diff.

Pass
