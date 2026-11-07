Task: BP6 round 2 · QA commit none (no edits) · Verdict: Pass

Blocking: none.

Advisory:
1. game/play/play_session.gd:1327-1331 leave_loading, with game/main.gd:562: between Esc and `left` (only while a nav or cover worker task is still running, i.e. while Continue is not yet shown) nothing else can start the match. When held for Continue the tasks are done, so `left` is emitted synchronously and no Continue window exists. Safe as written. If Continue could ever be pressed in that gap, go() would capture the mouse and _physics_process (which does not check _leaving) would tick the match until the node is freed. Cheap hardening: `if _leaving: return` in go() and _physics_process.
2. UpperBlend.snap is called only from tests (hit_area_probe). A real respawn zeroes the weights (character.gd respawn) and they ease in over 0.06 s / 0.12 s, so for a character placed holstered or sprinting the hit volume trails the drawn figure briefly after a round reset. Small; the drawn FigurePose has the same ease.
3. game/play/play_session.gd _prepare_bots: wait_for_task_completion(_cover_task) blocks the main thread if cover outlasts the vault search. On Woodland the cover (673 ms) is shorter than the links (1,560 ms), so it does not block in practice; a very small map with a slow cover pass would still be a single short stall, not a freeze.

Checked, no bug found:
- Leave mid-load: `_process` stops the build, `left` waits on is_completed for both the nav and cover tasks, `_exit_tree` waits for both and clears the outputs. The cover task reads only the map and nav grid, both held by refcount through the bound Callable, so nothing is freed under the thread. `_left_said` stops a double `left`; a second Esc is a no-op.
- Thread safety: find_cover uses no static scratch (`_s` is used only by the cover search at play time), and floor_at, node_at, step_node and node_position are pure reads. The main thread only reads the grid during the vault search; the grid is mutated (finish) only after the cover task is waited on.
- Match started twice: `_cover` is consumed once by _bot_options. _prepare_bots is guarded by `_cover != null` and `_vaults == null`. NavVaults.finish and link no-op on a linked grid, so a rematch or unstaged path (Options.cover null) finds cover itself and gets identical results.
- Bots without cover: an empty worker result falls back to find_cover on the main thread; a map that is not ok skips the step.
- Determinism: find always makes progress (the clock is read only after CLOCK_EVERY nodes), resumption keeps node order so links equal link()'s; the pinned test covers it. UpperBlend runs on the fixed tick with no RNG; both branches of the simulation loop step it.
- BotController.Options: all other callers (tests, match_runner) use the default and compile; match_runner is updated.

Tests run (targeted): test_bp6_round2, test_bot_vaults, test_figure_raise, test_figure_raise_qa, test_hit_fit, test_woodland_layout: 58 tests, 58 passing, 1,970 asserts, 119 s. Not run: tools/check.sh (per instructions) and the smoke test.
Needs a display/owner: Esc on the real loading screen on Woodland (screen keeps drawing while a worker task finishes, lands on the Match page, mouse visible); the look of the muzzle near walls and of the holster/sprint eases.
Task: BP6 round 2, attempt 2 · QA commit none (no edits) · Verdict: Pass
Head 1b47627 over 178abdd.

Blocking: none. Advisory: none new.

Checked:
- go() and _physics_process return early once _leaving; leave_loading is idempotent (a second call returns before re-emitting `progressed`). The hardening closes my earlier advisory 1.
- LOAD_LEAVING: the string is in en.po, and `progressed(_step, size, key)` matches the signal and LoadingScreen.set_progress_step. It emits once, before `left`, which is synchronous when held for Continue.
- _prep_config: set once with _vaults, used for the cover task and finish, then cleared. There is no for_map per frame, and the worker still reads an unchanged config.
- FB5 revert: _since_wall and the latch are gone, and the old level hold is back. test_figure_raise and test_figure_raise_qa pass (the tests were reverted to match).
- UpperBlend.snap removed. The tests no longer call it. My advisory 2 (the hit volume trailing a spawn) stands unchanged: eased 0.06 s / 0.12 s, same as the drawn figure.
- FigurePose.settle_share now calls UpperBlend.share. The formula is identical (test_each_blend_reaches_63_percent passes).
- FigureConfig.gate_below defaults to HitPose.GATE (0.001, same value). The class constant resolves at load with no cycle error (no script errors in the runs).

Tests run: test_bp6_round2, test_figure_raise, test_figure_raise_qa, test_hit_fit, test_woodland_layout: 47/47, 940 asserts, 82 s. Plus the 6 other files using FigurePose, HitPose, UpperBlend or gate_below: 87/87, 2,303 asserts, 9 s. check.sh and the smoke test were not run.
Needs a display: Esc on the real loading screen now shows "Leaving…" while a worker finishes.
