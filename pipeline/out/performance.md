Task: none (BP5 part 1) · head b46abbf · Verdict: Pass
Run: tools/team_bench.gd (no `--perf` flag exists for the bot match; this is the repo's tick/frame bench: whole PlaySession, autopilot, hand-stepped), seed 1, 60 s match time after 5 s warm-up, depot+street at 6v6 and 8v8, headless (no GPU). Main = /home/user/airsoft at 90b0ff4 (confirmed clean). Interleaved main, head, main, head (2 runs a side). Machine shared (4 cores, load ~2 from other agents), so run-to-run noise is about 5-7 % on means. · budget: no baseline yet (no pipeline/perf-budget.json), judged against targets and main.
Metrics, mean tick ms (main run1/run2 -> head run1/run2), frame = views, ms:
 depot 6v6  tick 2.14/2.29 -> 2.34/2.33 (ok, +5 %)   frame 1.02/1.10 -> 1.09/1.09
 depot 8v8  tick 3.10/3.06 -> 3.10/3.13 (ok, +1 %)   frame 1.29/1.28 -> 1.29/1.37
 street 6v6 tick 2.26/2.16 -> 2.26/2.21 (ok, +1 %)   frame 1.08/1.01 -> 1.06/1.05
 street 8v8 tick 3.63/3.43 -> 3.38/3.66 (ok, 0 %)    frame 1.40/1.32 -> 1.32/1.41
 p95 tick 3.1-6.2 ms on both sides, p99 4.2-9.7 on both; worst tick 8-29 ms on both sides (street spikes in main too: 22-25 ms), not a head effect.
 Every config is far under Low's 16.7 ms frame (tick+frame <= ~5 ms mean, 8v8). Frame times are reported only (headless).
 Node count, orphans and static memory: not logged by team_bench; no scene or node code changed in the diff (judgment).
Regressions (> 10 % worse): none. The one visible gap (depot 6v6 tick, +5 %) is inside main's own run-to-run spread (2.14 vs 2.29) and did not repeat in other configs.
Blocking findings: none
 - game/sim/grenades.gd trigger_command (new, per tick per character): judgment+measured. Two bool reads and a return of `cmd` on the common path; copy_from into the preallocated `_throwing` only while a pull is held off. No Array, String, Callable or new object. `take_torch_back` is a bool read and write. Torch.step relight is a default bool param, no allocation. Measured cost is not distinguishable from noise.
 - game/sim/simulation.gd:134: new local `var trigger := cmd.fire` is a bool on the stack, no allocation. The `_throwing` command is the existing preallocated field, no new fields allocated per tick.
 - game/play/sim_audio.gd:746-754: push_warning with String formatting only on the missing-peak path at ambience start, not per frame.
 - game/progress/records.gd: one extra float compare in a load-time parse.
Advisory:
 - The diff also deletes assets/models/characters/human_bot_human_v12_{col,nrm,orm}.webp (+ .import), about 1.2 MB: a size win; the critic/QA should confirm nothing still references them (smoke ran per QA). Judgment.
 - team_bench does not print OBJECT_NODE_COUNT / orphans; adding them would give the next measured review a leak check (not needed for this diff).
Fixes: none needed.
Unexplained: none. Worst-tick spikes (up to ~29 ms on street 8v8) exist on main as well; on a shared machine they are not attributable to the diff.
Verdict: Pass
