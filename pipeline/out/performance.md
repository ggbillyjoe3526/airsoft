Task: none (BP5 part 2) · head c14d732 · Verdict: Pass
Run: team_bench 8v8, 40 s, woodland+depot, seed default, headless; 2 runs a side, interleaved (main 90b0ff4 / head) · budget: no baseline yet (pipeline/perf-budget.json absent), judged against targets and main
Metrics (mean ms, main run1/run2 -> head run1/run2; tick, frame, both):
 woodland tick 4.88/4.50 -> 4.67/4.51; frame 1.48/1.26 -> 1.34/1.23; both 6.36/5.75 -> 6.00/5.75 (ok)
 depot    tick 2.89/3.00 -> 2.90/3.02; frame 1.28/1.41 -> 1.22/1.21; both 4.17/4.40 -> 4.11/4.22 (ok)
 p99 both: woodland 12.5/10.5 -> 10.9/10.6; depot 8.4/8.3 -> 9.3/8.3 (noise; run-to-run spread on main alone is up to 8 %)
 Frames over 16.7 ms (of 2400): woodland main 3/0, head 1/0; depot 0 everywhere. Worst-case spikes are single-frame noise (head 20.6 vs main 16.8 in run 1, reversed in run 2).
Regressions (> 10 % worse): none (measured). Gain is small and within run-to-run noise on this machine (frame mean -3 to -14 %, both -0 to -6 %); the worker's larger gain in BP5.md is not reproduced here but nothing contradicts it.
Blocking findings: none
 - Allocations (judgment, read game/sim/hitbox.gd may_touch, game/ai/bot_combat.gd _body_in_line, game/play/figure_view.gd animate): only float/Vector3 locals (values, no heap), no Array/Dictionary/String/Callable/lambda, no node or resource creation, so no new per-tick allocation and nothing to free.
 - Freed nodes (judgment): no nodes, tweens, timers or connections added; no orphan lines in either head run.
Advisory:
 - game/ai/bot_combat.gd:~370 flight_time(b, w, dist) is computed once per call lazily; if flight_max is 0 (judgment) the quick test is skipped for every mate and flight_time is not re-tried, which is correct but leaves that case unaccelerated.
 - game/play/figure_view.gd:~364 unseen figures share _far_frames/_far_delta with the far path; fine because the branches are exclusive, but a figure switching between seen/unseen mid-stride keeps a stale partial count (at most one extra skipped frame; judgment).
 - game/config/figure_config.gd:90 unseen_stride=2 makes shadows of unseen figures pose at 30 Hz (design trade-off, intended; play-test for visible shadow stepping).
 - Frame times are from a GPU-less container: reported only, not a budget verdict.
Raw: <scratchpad>/perf_{main,head}_{1,2}.txt
Verdict: Pass
