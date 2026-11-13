Task: HA1 · QA commit see `git log -1` (HA1 QA re-run 2) · Verdict: Pass

Blocking: none. Advisory: none new.
- The replica_view.gd merge (~line 287) keeps both: `hands_busy` joins sprint and climb in the carry target, and the eased `carried` smoothstep scales the drop and tilt. Run, not just read (tests below).
- The earlier four blocking items stay fixed: test_hands_on_replica, test_bp8_arms, test_ha1_arms_tuck all pass.

Tests added (tests/unit/test_ha1_rifle_hold.gd, 6 tests, 65 asserts):
- :52 test_without_a_grip_the_left_hand_sits_between_the_magazine_and_the_grip_mount · wrist z for aeg/sniper/smg is ahead of the magazine's middle, at most 4 cm behind its front, 3 cm+ short of the GripMount · fails on the old GUARD y (0.240 on the AEG puts the wrist past the 4 cm bound); checked by arithmetic against the old values in git, not by rebuilding the model. Sniper (2.8 cm) and SMG (0.7 cm) shifts stay within the bounds, so for them it guards against wandering, not the exact move.
- :74 test_no_left_fingertip_rides_above_the_handguard_in_the_hold · four fingertips' height against the replica's mesh top (1.5 cm along, 3 cm across) · guard only: I did not stub pose.py `over()` out (needs a Blender rebuild); no finger is above the top in the current model.
- :113 test_a_bot_holds_every_rifle_s_handguard_where_the_arms_do · bot left hand within 5 mm / 0.05 rad of FigureArmsHold's mark for aeg, sniper and smg (existing test lacks the SMG) · fails if the figure hand leaves the arms' hold.
- :170 test_busy_hands_carry_the_replica_low_as_a_sprint_does_and_let_it_back · hands_busy drops the replica sprint_drop like a sprint, nothing without it · fails without hands_busy in the carry target (drop stays 0).
- :185 test_the_carry_eases_in_and_out_and_is_released_when_the_hands_are_free · a quarter in by time the drop is 0.05-0.22 of full (smoothstep 0.156, linear 0.25), full at carry_time, 0 again when freed · fails with a linear carry.
- :232 test_each_reload_clip_ends_on_the_hold_pose · last frame of <id>_Reload (3 rifles) and both foregrip reloads (aeg, sniper) matches the Hold on every bone (3 mm, 0.02 rad) · fails if a reload clip ends off the hold.

Suite (single files, one Godot at a time; check.sh was running elsewhere): test_ha1_rifle_hold 6/6, test_ha1_grips 3/3, test_ha1_qa 20/20, test_ha1_arms_tuck 10/10, test_ha1_arms_fade 6/6, test_ha1_hands_motion 13/13, test_hands_on_replica 10/10, test_arms_view 13/13, test_figure_hands 24/24, test_figure_hands_qa 21/21, test_grenade_arms 15/15, test_grenade_arms_qa 7/7, test_holster_sprint_arms 2/2, test_bp8_arms_qa 27/27, test_bp8_arms 16/16. No failures. gdlint clean. Logs in pipeline/out/qa/.

Not run: tools/check.sh, the smoke test, the full suite (a check.sh run was in progress, as instructed). The new test file has no .uid yet (a headless GUT run does not write it; the next editor import will, commit it then). Needs a display, for the owner's list: how the hand looks on the handguard and grips.
