Task: CL1 · QA commit PENDING · Verdict: Pass

Blocking: none.
Advisory:
- game/sim/character.gd:~154 rescue_if_out_of_world resets vault but not stairs/prev_stairs (respawn() does). Harmless: step_stairs ignores a jump over max_stride and eases to 0 in 0.12 s. Trigger: fall out of the level mid-stairs.
- game/play/figures/figure_body.gd:~202 _vault_way caches the last Transition request; if the AnimationTree is ever rebuilt in place it would not re-ask. Not reachable today.
- A climb is allowed onto any >=1.5 m deep, 0.6-0.95 m high flat ledge on every map (player side), not only Kingsmere; only the nav links are asserted Kingsmere-only (test_bot_climbs). By design (climb_depth), worth a playtest on Woodland crates.

Tests added (tests/unit/test_climb_qa.gd, 6):
- test_no_climb_onto_a_platform_with_no_headroom_on_top · Vault.plan with a ceiling 0.6 m over the top · fails if the on-top head clearance is dropped (control assert pins the open platform climbs). Not stubbed (no production edits).
- test_respawn_mid_climb_ends_it_and_clears_the_stairs_share · fails without Character.respawn resetting stairs/prev_stairs (values set non-zero first).
- test_stairs_share_rises_on_a_steep_climb_and_is_negative_going_down · step_stairs reaches +1/-1 on a 0.5 slope; fails without step_stairs.
- test_a_gentle_slope_or_a_jump_or_a_vault_is_not_stairs · 10% hill, airborne, vaulting give 0.
- test_a_teleport_is_not_stairs · >max_stride move gives 0.
- test_stairs_show_in_the_legs_only_when_stepping_ahead · stairs_blend: ahead = share, backing/strafing/still = 0, down = -1.
Checked, no bug found: climb ends with vy 0 and inactive vault; pose keeps climb flag only while vaulting/easing out; stairs off when airborne/vaulting; nav drop merge is CSR-consistent (test_bot_climbs).

Run: test_climb_qa + test_vault + test_bot_climbs: 38 tests, 38 pass, 334 asserts, 17 s. Smoke test: PASS (1161 frames, zero script errors, 1m26). Logs: pipeline/out/qa/climb_qa.log, smoke.log.
Note: tools/check.sh not run (CPU shared with balance run; owner asked for touched files + smoke only). `-gtest=` alone runs the whole suite with .gutconfig.json; I used a scratch -gconfig with no dirs.
Not testable headless: the climb/stairs animation look, first-person dip/tip feel, HUD prompt placement, window modes, mouse capture (owner to playtest Kingsmere track-to-platform climb and the escalators).
