Task: none (BP5 part 1) · QA commit 313eb5e · Verdict: Fail

Blocking (1, minor):
- game/sim/grenades.gd held_off_command (clears only when it runs) + game/sim/simulation.gd:147-150: it is skipped while throwing/bomb in hand, so a trigger let go and pulled again DURING the throw (windup/recovery) leaves trigger_held_off true; the fresh pull is eaten after the replica is back up until the next release. Before BP5 it fired. Fix: in the throwing branch (or step_throw) clear trigger_held_off when the command's fire is false. Pinned by a failing test.

Advisory: none. Checked and fine: G/4/5 instant throw with held trigger fires after as before; respawn (refill->stop) clears both flags; a hit mid-throw/bomb-in-hand stops the hand; out-of-play characters are never held_off-filtered (no shots); held-off through a vault stays one held pull; semi replica doesn't re-read the held pull; torch_back is spent when the new slot has no light, on holster, and never leaks; records: COUNT_MAX kept, +1, INF, NaN, 1e300 in results pairs all left out (1e9 fits PackedInt32Array). Bots never ready bombs (only throw_grenade), unaffected.

Tests added (tests/unit/test_bp5_qa.gd, 9):
- test_an_instant_throw_with_a_held_trigger_still_fires_after_it_as_before: G with fire held; guards the "as before" case (fails if held_off were set for instant throws).
- test_a_respawn_clears_a_held_off_trigger: flags set, respawn(); fails if refill/stop did not reset them.
- test_a_hit_while_the_trigger_is_held_off_leaves_nothing_to_fire: CALLING status, no shots.
- test_a_semi_replica_does_not_read_the_held_pull_as_new_after_a_put_back: semi, 0 shots; fails without held_off_command.
- test_a_pull_pressed_during_the_throw_recovery_is_let_go_until_the_next_release: FAILS (the blocking bug above).
- test_a_held_off_trigger_through_a_vault_ends_without_a_stray_shot, test_a_bomb_put_back_to_a_slot_without_a_light_leaves_the_torch_off_and_silent, test_a_holstered_bomb_put_back_keeps_the_torch_flag_from_leaking: edge guards.
- test_records_counts_at_the_bound_are_kept_and_beyond_it_nan_and_inf_are_left_out: fails without the COUNT_MAX bound for 1e300 (not INF/NaN, which the old check already rejected).
Not mutation-checked individually (no production edits allowed); the first two held-trigger tests in test_bp5 cover the feature.

Runs: 54 touched files (bp5, bp5_qa, mc1*, grenade*, torch*, armament, vault*, bot_vaults, loadout*, saved_loadouts, records/LoadoutPage users): 774 tests, 772 pass, 530 s. 2 fails: the bug above, and test_uf1_qa picking_the_same_dot (Camera3D physics-interpolation engine error; passes 2/2 alone: flaky, unrelated, advisory for KNOWN_ISSUES). tools/smoke_test.sh: PASS (3361 frames, 6 rounds, zero script errors). tools/check.sh not run (per brief).
Not testable here: Loadout chips visually after a real rebind in Settings (display); sim_audio missing-peak warning (no test; audio, trivial).
