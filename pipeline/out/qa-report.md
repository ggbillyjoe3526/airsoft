Task: HA1 · QA commit 06474f9 · Verdict: Pass

Blocking: none.

Advisory (no failing test pinned; none is visible in play):
- game/play/arms_view.gd:162 (`hold`): switching rifle -> pistol/bomb with the sight raised leaves the old shoulder move in the bones until the next `aim()` call (the clip doesn't key UpperArm_L's position, `ArmsTuck.clear` only runs inside `_draw_in`). ReplicaView calls `aim` every pose, so it lasts under a frame and is never drawn; GrenadeView has its own ArmsView, never aimed. Trigger: `hands._show(1)` after `aim(1.0)`, read a bone before the next `aim`. A `_tuck.clear` in `hold` would close it.
- Float noise: after hundreds of random aim() frames with `force_update_all_bone_transforms` between them (as `left_hand` does) the left hand's basis sits up to ~0.1 degree off the clip's (position < 4e-5 m). Bit-exact over 30,000 frames without the readback, no scale drift. Invisible; the tests use a 5e-3 tolerance for it.
- pistol_Reload / cyber_Reload do not exist, only `_two_Reload`; fine with `clip_base`, but the one-handed pistol clip has no reload.

Tests added, tests/unit/test_ha1_qa.gd (16, all pass, gdlint clean). "Fails without" = how it would fail with the feature removed (production code can't be edited, so by construction/old-model facts):
- test_a_raise_outside_0_to_1_or_at_the_spans_ends_breaks_no_bone · aim at -3..4 and the span ends: finite bones, both lengths kept, clean at 0 · would fail with a NaN/unclamped solve.
- test_an_id_in_aim_slide_but_not_in_aim_tuck_... and test_an_id_in_aim_tuck_but_not_in_aim_slide_... · each table alone moves only its part · fail if the tables were coupled or `.get` defaults missing.
- test_rifle_to_pistol_to_rifle_while_raised_leaves_no_slid_hand_or_moved_shoulder · switching three replicas, left bones equal a fresh clip · fails if `_tucked` residue stayed.
- test_a_bomb_after_a_raised_rifle_is_posed_by_its_clip_alone · one-handed hold not tucked.
- test_hide_and_show_while_raised_keeps_the_tuck_and_only_toggles_the_model · set_shown while raised.
- test_the_snipers_bolt_clip_runs_with_the_sight_going_down_and_leaves_no_residue · `sniper_Fire` seeked while raise falls 1 -> 0.
- test_a_grip_hold_is_tucked_and_comes_back_whole · vertical/angled grip holds (pending if the model lacks one).
- test_no_residue_frame_after_frame_and_the_hand_keeps_the_clips_turn_while_raised · 90 seeded random raises per rifle: hand turn is the clip's, lengths kept, sight-down equals clip alone, right arm untouched.
- test_pistol_and_cyber_have_both_hands_clips_in_the_model · `_Hold`, `_two_Hold`, `_two_Reload`, hold marks · fails on the old model (no `_two_*` clips).
- test_two_handed_pistol_hold_keeps_the_right_arm_but_the_thumb_and_the_thumb_lies_on_the_left_hand · right bones equal `_Hold` except Thumb1-3_R/Heel_R; thumb moved; Thumb3_R within 5 cm of a left bone, 12 cm of Hand_L.
- test_the_hint_reaches_its_values_at_the_spans_ends_and_the_arms_wear_their_own_again_at_0 · hint 0 / 0.5 / 1, own BaseMaterial3D back at 0 · fails if the fade stuck.
- test_fading_copies_are_made_once_per_material_and_not_per_frame · same objects over 120 frames and a switch.
- test_every_rifle_hold_the_bots_copy_has_the_left_hand_forward_on_the_replica_and_near_it · FigureArmsHold for aeg/sniper/smg (gap: existing tests compare fingers, not left-hand placement).
- test_the_model_as_imported_stays_in_its_budgets · file <= 8 MB, <= 40,000 triangles drawn (gloved and skin), <= 4 materials, textures <= 2048 px.
- test_a_view_freed_with_the_sight_raised_leaves_no_orphans · three setups freed with the sight raised, orphan count not above before.

Runs (my files only, the owner's check.sh was running): test_ha1_qa 16/16 (1.5 s); test_ha1_arms_tuck 9, test_ha1_arms_fade 6, test_arms_view 13, test_bp8_arms 16, test_bp8_arms_qa 27, test_hands_on_replica 10, test_figure_hands 24, test_figure_hands_qa 21: all pass. Full suite, check.sh and smoke test not run by me (told not to).

Could not test: real-window look (hands showing past a replica, the pistol's fade on screen, optics), focus loss/mouse capture/window modes (untouched by HA1), save files (untouched). Shader output (arms_fade.gdshader) needs a display; the owner's list.
