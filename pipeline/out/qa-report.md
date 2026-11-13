Task: HA1 · QA commit a215b0b · Verdict: Pass

Scope: git diff bbf29a3..010b00b (7689239 adds only an origin/main merge).

Blocking findings: none.
Advisory: none new. Not tested: how the rebuilt hands, nails and tendons look, and the pistols at 25 cm on screen. That needs a display (owner's list).

Tests added (tests/unit/test_ha1_qa2.gd, 7 tests, 575 asserts, all pass):
- test_every_hold_shows_exactly_one_hand_look_and_stays_in_the_triangle_budget: every replica id, smoke, flash and each grip hold in the model, in both looks. Skin_/Nails_ or HandSurface_/GloveKit_, never both or neither, left side hidden on one-handed holds, 40,000 triangles drawn. Fails without the feature: the old code drew Skin_ in the glove look as Look.BOTH.
- test_switching_the_look_mid_hold_and_mid_hold_changes_keeps_one_look: Skin-only toggled live between hold changes. Same check on the old code.
- test_robot_arms_keep_the_glove_shell_and_never_the_bare_hand: the robot gets the glove meshes even with skin set; a human again shows the bare hand.
- test_the_aimed_pistols_fade_reaches_the_bare_hand_and_its_nails: pistol and cyber, skin only, Skin_/Nails_ surfaces are fading copies at the mid hint; whole again at aim 0. Fails if the new meshes were left out of the fade.
- test_a_rifles_tuck_leaves_the_bare_hand_drawn_and_unfaded: rifle aimed, skin only, bare hand shown and no fading copies.
- test_the_bomb_in_hand_arms_follow_the_dev_setting_live: GrenadeView arms with smoke held, toggled three times.
- test_the_pistols_hip_is_the_old_place_drawn_in_along_the_same_line: the hip is 25 cm and collinear with the old 34 cm place. The reload move scales with it, and the reload peak stays in front of the eye inside a 75 degree field. Fails on the old values.

Checked by reading: the aimed sight line is hip-independent (replica_view.gd:257 uses aim_forward minus rear_sight). Bots do not read ViewModelConfig.hip. Only ReplicaView and the config use it.

Run: test_ha1_qa2.gd alone, 7/7. The other seven arms files were not re-run by me (the build thread reports them green). tools/check.sh and the full suite were not run, as instructed.
