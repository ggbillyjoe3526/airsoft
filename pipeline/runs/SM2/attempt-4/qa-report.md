Task: SM2 · QA commit none (uncommitted, as asked) · tested head 70f791f · Verdict: Pass

Blocking: none. Advisory: none.

Tests added (tests/unit/test_lift_view.gd, after line 160):
- test_lit_arrows_share_the_landings_transforms · LandingLights exists, same instance count and identical transform per instance as Landings · fails if the lights node or its set_instance_transform line is removed (null node / mismatched transforms).
- test_a_missing_lit_model_still_builds_without_arrows · landing_lit_model = "" builds, Landings kept, no LandingLights · fails if the null guard is dropped.
- test_the_lit_arrows_are_freed_with_the_view · weakref to LandingLights is null after the view is freed.

Runs: test_lift_view 11/11 (46 asserts), test_sm2_edges 9/9, test_sm2_transit 6/6, test_lifts 18/18, test_saved_configs 1/1, test_model_pictures 7/7. Output: pipeline/runs/SM2/attempt-4/qa-lift-view.txt.
Not run: tools/check.sh and smoke test (CI, per instruction). Not testable headless: how the arrows and half panes look; owner to eyeball on Subway.
