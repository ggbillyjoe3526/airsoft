Task: SM2 · QA head db1ceb9 (no new commit; tests uncommitted) · Verdict: Pass

Blocking: none. Advisory: instance colours cannot be read back headless (dummy renderer returns zeros), so the colour check only runs with a display.

Checked in game/play/lift_view.gd:102-120: use_colors is true on LandingLights, and set_instance_color(j, glow) runs for every lit instance (inside the same loop as the transform), glow = lit * landing_lit_gain with alpha 1. Nothing allocates per frame: the colours are set once in build. A missing lit model (landing_lit_model "") still builds: the null guard skips the lights and the landings are still drawn (existing test).

Changed test:
- tests/unit/test_lift_view.gd test_lit_arrows_share_the_landings_transforms · now also asserts use_colors and each instance colour = lit * gain with alpha 1 · fails if set_instance_color is removed or use_colors is false. Under the headless display server the colour loop is skipped with pass_test (verified: read-back gives 0 there, so the loop cannot run headless). Needs a display to run for real.
- The other two lit-arrow tests (missing model, freed with view) still pass unchanged.

Results: test_lift_view 11/11, test_sm2_edges 9/9, test_sm2_transit 6/6, test_lifts 18/18, test_saved_configs 1/1. tools/check.sh not run (CI).
Not testable here: the visible glow and the chevron model's look (owner, on a real window).
