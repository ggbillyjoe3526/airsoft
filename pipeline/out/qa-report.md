Task: HA1 · QA commit (see git log, Agent: qa) · Verdict: Fail (re-run at d133a1e)

Blocking (existing tests fail with the rebuilt arms.glb; each run singly, none failed against the old model per their authors' thresholds):
1. tests/unit/test_hands_on_replica.gd:88,91 test_the_left_hand_holds_each_rifle_s_handguard_as_the_arms_do: the bots' left fingers (FigureConfig hold_fingers) are 0.35-1.8 rad off the arms' new left hand, thumb tip 3.4 cm off the thumb bone (aeg). The bots copy the new hold but their finger curl data is stale.
2. tests/unit/test_hands_on_replica.gd:203 test_behind_a_fitted_grip: vertical/angled fingers move back 0.120/0.143 m, expected 0.065/0.088 (support_behind_grip vs the new grip hold).
3. tests/unit/test_bp8_arms.gd:277 test_only_the_hand_and_wrist_show_through_a_reload: aeg_Reload, aeg_grip_vertical_Reload, aeg_grip_angled_Reload show left arm past the wrist (up to 0.28 vs 0.166 limit, at the start and end of the reload and 0.17-0.22 of the grip one): the re-solved reload clips bring the forearm on screen.
4. tests/unit/test_ha1_arms_tuck.gd:82 test_aimed_the_elbow_is_in_under_the_replica...: aeg/sniper elbow moves 2.4 cm in when aimed, test needs > 3 cm (the straight support arm leaves less elbow to tuck). Either tune aim_tuck / the threshold; the tuck still hides nothing it should not (the hand slide check on line 75 passes).
Advisory: none new. The earlier hold()-clears-tuck advisory is fixed and tested.

Tests added (tests/unit/test_ha1_qa.gd, end of file; all pass, 20 in the file):
- test_every_rifle_and_foregrip_hold_has_the_left_wrist_nearly_straight: aeg/sniper/smg _Hold and aeg/sniper grip vertical/angled _Hold, wrist bend vs the rig's rest under 12 deg (measured: 0.6-1.5 deg, SMG 10.0). Fails if a hold bends the wrist more; I did not swap in the old glb (assets/ off limits, no import allowed during check.sh), so "fails without the feature" is unverified; I checked the metric by tightening to 0.5 deg and seeing it fire at the measured values.
- test_the_cyber_pistol_two_handed_hold_has_the_thumb_as_the_gbb_pistols_does: right thumb direction in the hand frame, dot > 0.9 against pistol_two_Hold.
- test_every_clip_the_game_looks_up_still_exists_in_the_model: rifle/pistol/grip Hold, Reload, Fire clips.
- test_every_foregrip_hold_keeps_the_left_hand_on_the_replica_for_hold_and_reload: left hand 12-60 cm from the right, right hand same as the plain hold, reload finite.

Ran (single files only, no check.sh): test_ha1_qa 20/20 (1.4 s); test_ha1_arms_tuck 9/10; test_hands_on_replica 8/10; test_bp8_arms 42/43; passing: test_arms_view, bp8_arms_qa, figure_hands(+qa), hands_feel, ha1_hands_motion, ha1_arms_fade, mag_hand_off_hud, grenade_arms(+qa), holster_sprint_arms, hit_call_arm.
Not tested: how the holds look (needs a display); the old glb comparison; the whole suite and smoke test (owner is running check.sh).
