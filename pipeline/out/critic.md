Task: none (BP6 round 2) · known-issue fixes: loading, the hit volume's eases, Esc on loading
Attempt: 2 of 4
Head: 1b47627 (= git rev-parse HEAD; QA re-check Pass, performance re-check Pass; my targeted GUT 42/42 pass: bp6_round2, figure_raise(+qa), hit_fit, figure_hit_area, holster_edges; gdlint clean)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept
Round 1 must-fix, each checked:
- (a) play_session.gd `_prepare_bots`: `_prep_config` is set once when the search starts, shared with the cover task and `finish`, then cleared. No per-frame duplicate is left.
- (b) FB5's level hold is back: figure_view.gd, test_figure_raise.gd and test_figure_raise_qa.gd are byte-identical to origin/main (empty diff). KNOWN_ISSUES keeps the muzzle row with an honest reason ("the 77° high ready while firing reads worse") and names the later option. Restoring the hold also undoes the raise-share mismatch while firing.
- (c) The record's balance line holds real numbers (16 seeds, 119 rounds, 0 on time), and its count of seven rows in six items is right.
- (d) A new row records the remaining stall: Woodland 0.7-0.9 s (MapLevel.build), Depot 1.2 s on the same machine.
- (e) `UpperBlend.snap` is gone, and the tests set the weights inline. `FigurePose.settle_share` calls `UpperBlend.share`, one formula. `gate_below` defaults to `HitPose.GATE`; no .tres overrides it, and the test that only pinned the two equal is gone, as it should be. The doc comment is back on `_box`, and play_session.gd:26 is rewrapped.
- Esc feedback: `leave_loading` emits `progressed(_step, size, LOAD_LEAVING)` at once, "Leaving…" is in en.po (the only locale), and the test asserts the line. It is idempotent (`or _leaving`). `go()` and `_physics_process` return early while leaving, so a Continue in the gap can't take the mouse or tick the match (test: `go()` does nothing, mouse not captured).
New breakage looked for, none found:
- `_process` returns early while leaving, so no later `progressed` or `ready_to_go` overwrites "Leaving…".
- At Continue, `left` is synchronous, so the screen is freed in the same frame.
- `_on_continue` calls `play.go()`, which is now a no-op once leaving.
- The worker is still waited on before `finish` and in `_exit_tree`.
- The simulation is deterministic: UpperBlend runs on the tick with no RNG, and the time-sliced vault search gives identical links (test_bot_vaults).
- Changelog: the muzzle entry is gone and the Leaving line added. Wiki Controls and Getting-Started are correct.
Advisory (not scored): a respawned character starts with its weights at 0 and eases in over 0.06 s or 0.12 s, the same as the drawn figure (QA's advisory 2). Fine as it is.
Owner should test in the game:
1. Load Woodland: the loading animation should keep moving. One stop of under a second may remain, as on every map.
2. Press Esc right after PLAY on Woodland: "Leaving…" should show at once, then the Match page within a few seconds.
3. Press Esc at Continue: you should land on the Match page at once with the mouse free.
4. Shoot bots as they holster, draw or start a sprint: hits should land where the arms and torso are drawn.
5. Watch bots fire over a ~1.5 m stack: the barrel may graze the top while firing (kept by default). Say if it bothers you.
