Task: GA1 · QA commit pending · Verdict: Pass

Blocking: none.
Advisory: none found. Checked: Hitbox.step_walk_cycle takes speed from c.velocity, not the ground moved; a vault or a
knock that moves position with zero velocity advances the cycle at the first table point (1.0 m / 0.8 m), harmless
(no stepping clip shows then). Walk-off and bots set velocity through Movement.step, so cadence follows speed.
Empty, zero and repeated-speed tables stay finite (MIN_CYCLE guard); steady_turn wraps across +-PI.

Tests added (tests/unit/test_gait_cycle.gd, 9 tests, 60 asserts, all pass):
- test_cycle_length_is_in_line_between_speeds_and_held_past_the_ends · fails if lerp or end-hold is removed (old code had no table).
- test_cycle_length_blends_to_the_crouched_table · fails if the crouch blend is dropped.
- test_cycle_length_never_below_the_minimum_even_with_bad_tables · fails without the MIN_CYCLE clamp.
- test_cycle_length_with_empty_or_repeated_tables_is_finite · fails without the empty/zero-span guards.
- test_step_walk_cycle_advances_a_whole_cycle_over_the_cycle_length · old code used strides_per_metre (0.75/m), not the 1.763 m table.
- test_each_gait_clip_covers_the_cycle_length_at_its_speed · human and robot sidecars, Walk_F/Run_F/Sprint/CrouchWalk, within 1% (fails if a clip or table is re-tuned alone).
- test_steady_turn_wraps_to_the_short_way_round · fails without wrapf.
- test_upper_steady_changes_the_upper_body_only_while_it_is_on · upper_steady 1 moves the strafe's upper joints, 0 reproduces the old pose.
- test_a_vaulting_or_out_character_keeps_the_hips_upper_body · fails if the alive/not-vaulting guard is removed.
Not run: tools/check.sh (main thread); in-game look of the gait needs a display (owner's list).
