Task: SM2 · QA commit none (no tests added, nothing committed) · Verdict: Pass

Re-verified at 2cdc8a5 (escalator lane points on the 1.2 m lanes' middles).
- The earlier blocking bug (subway lane 2 points not standable, test_field_rules.gd:72) is fixed. test_field_rules passes 18/18.
- test_sm2_transit 6/6 (escalator and stair models fill their set_box unstretched), test_sm2_edges 7/7, test_lifts 18/18, test_lift_view 8/8, test_bot_lifts 8/8.

Blocking: none. Advisory: none.
Not run: the full suite and tools/check.sh (running in the background) and the smoke test. Visual checks (lit lens, ribbed treads, deck seams) need a display.
