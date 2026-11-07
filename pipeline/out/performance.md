Task: BP6 round 2 · head 178abdd · Verdict: Pass
Run: no bot-match --perf run (tools/check.sh barred; static review + targeted GUT) · budget: no baseline yet, judged against targets and the record's measured load times
Metrics: GUT test_bp6_round2 7/7, test_bot_vaults 9/9, test_figure_raise 10/10 (measured). Woodland longest loading frame 2.7 s -> 0.9 s is the record's measurement, not re-measured here.
Regressions (> 10 %): none found
Blocking findings: none
Per-tick (judgment, read in full):
- upper_blend.gd step/holster_target/share: two lerpf + two exp per character per tick (32 exp for 16), no Array/Dictionary/String/Callable/instantiate. Negligible.
- simulation.gd:177,191: one static call per character per tick in both branches, no allocation.
- hit_pose.gd: holster_share is a pure static, GATE const; two extra _add_upper calls, no allocation (still "allocates nothing").
- character.gd: two floats, reset in respawn. armament.gd: one bool.
- figure_view.gd _raise_target: one float compare and a maxf; _since_wall is a float. No allocation. Per frame, not per tick.
Threads and memory (judgment):
- play_session.gd:504 one WorkerThreadPool task per load (bind Callable once, load-time only). Worker reads map.blocks and nav.floor_at only; main thread's NavVaults.find only reads the grid (astar weight, step_node) and the cover task is waited on (:508) before finish() mutates the grid. BotCover._floor_under uses no static scratch (_s is only used by the other search paths), so no data race.
- _cover_out is appended by the worker and popped/cleared only after the wait (:508, :1475). _exit_tree waits on _cover_task as for _nav_task. leave_loading/_leave_when_idle gives `left` only when neither task is running, so a screen keeps drawing and no task outlives the session.
- Finder (start/to PackedInt32Arrays, VaultState) is RefCounted, dropped at `_vaults = null` after finish; if loading is left mid-search it frees with the session. The Found cover is handed to the bots once and `_cover` nulled. No new nodes or resources; _build_ground only splits an existing MapLevel build across frames (guarded by `_level == null`, so no double build).
- Time.get_ticks_usec once per 256 nodes: negligible next to the rays.
Advisory:
- play_session.gd:25-26 doc comment line is over 120 columns (gdlint may flag; style, not perf).
- play_session.gd _process: an abandoned task that finishes after `_leaving` is only joined in _exit_tree (instant then); fine.
- Not measured: the 0.9 s remaining frames (views/HUD, MapLevel.build) are still above a 16 ms frame by design (loading screen); frame times count only on the owner's hardware.
- Suggest the owner/QA confirm the bot-match --perf script time per tick on a quiet machine, though the added work is a few dozen flops per tick.
Fixes: none required.
Task: BP6 round 2 re-check · head 1b47627 (over 178abdd) · Verdict: Pass
Basis: static read of git diff 178abdd..1b47627 (no runs; judgment).
- play_session.gd _prepare_bots: for_map now once per load (_prep_config, set when _vaults starts, nulled at the end); before it was per frame during the slices, so this removes a per-loading-frame BotConfig copy. Freed with the RefCounted drop; the worker task holds its own reference via bind.
- figure_view.gd: _since_wall, the held branch and an add per animate() are gone; back to main's single early return. Strictly less per-frame work, no allocation.
- upper_blend.gd: snap removed (it was unused); share unchanged. FigurePose.settle_share is now one extra static call into UpperBlend.share: no allocation, negligible.
- figure_config.gd gate_below = HitPose.GATE: a constant default, no cost.
- leave_loading: one progressed.emit plus a _leaving guard in _physics_process/go: one-off, no per-frame cost. en.po gains one string.
Blocking: none. Advisory: none.
