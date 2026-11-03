Task: HV1 · QA commit 86cba0b · Verdict: Pass

Blocking: none. Advisory: none found.

Criteria:
1. Hit in every pose: test_hit_registration.gd covers stand, crouch, crouch-walk, crouch-back, run_0, between,
   aim_down and vault from three sides. test_hit_registration_qa.gd adds lean left and right, aim up, run 1 to 3,
   walk 1 and crouch-half (at least 93 % struck), and a jumping figure struck at the chest.
2. Beside the figure: at least 95 % of BBs fired just beside the body pass in the same poses; a ray 60 cm beside a
   jumping figure passes.
3. No tunnelling: a 400 m/s BB that starts 3 m in front and would end 3.7 m behind the target in one tick still
   strikes it (and the 160 m/s test passes).
4. Crouch under 1.2 m cover: test_hit_fit.gd, every pitch, still and crouch-walking.
5. Plywood figures and `fit = null`: test_hitbox.gd (15), test_bb_step.gd (18), test_range_targets.gd pass.
6. Volumes built only when needed: may_touch is false for a line 30 m off or a segment ending short, true through the
   figure; over 60 seeded random states with 40 rays each it never rejects a ray the full volume strikes. Bots'
   friendly-fire check: test_bots.gd.

Tests added: tests/unit/test_hit_registration_qa.gd (5 tests, 77 asserts, all pass).
- test_leaning_aiming_up_and_running_figures_are_struck_and_the_air_beside_them_passes
- test_a_jumping_figure_is_struck_at_the_chest
- test_a_bb_fast_enough_to_cross_a_body_in_a_tick_still_strikes_it
- test_a_far_character_is_not_touched_and_a_near_one_is
- test_a_standing_figure_under_the_volume_top_is_never_skipped_by_the_quick_test (random poses)

Fails without the feature (by reading): the built-in volume missed 25 to 36 % of crouched, crouch-walking and running
figures (FI7) and has no airborne pose, so the pose and jump tests fail on it.

Runs: test_hit_registration (3), test_hit_fit (3), test_bb_step (18), test_hitbox (15), all pass. The full suite was
run by the worker in four parts.

Not testable here: how hits feel in play. The owner checks by eye that the hit tick lands on the visible body when
crouch-walking, vaulting and leaning.
