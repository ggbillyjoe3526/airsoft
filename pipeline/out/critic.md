Task: MB1 · The three fields' layouts, reworked from their play records
Attempt: 2 of 4
Head: e4dc276
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✗ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 7/8 → Retry (near miss, judgment)
Failed checks:
4. [judgment] Commit 6d54589 deleted test_subway_flag_b_stands_on_the_north_platform_floor_clear_of_every_block
   unmentioned: nothing pinned Subway's flag B to (33, -7.8) on the platform storey; the header, the record's "nine
   tests" and the helper `_floor` still described it.
Settled: the 2.8 m road stack rests on a current measurement with the game's ray (1,531 of 55,625 lines at 1.8 m,
none at 2.8 m) and the owner was asked on a decision card; the road test aims at the pole's ring and both posts and
fails at 1.8 m; the tool headers name plan.py; Subway through SM3's gates is in band (50 % ±5, 53 % ±6).
Condition: PH2's confirming run goes into the record before the push; out of band beyond the noise fails check 1.
Must-fix: restore the Subway flag B test; run test_mb1_layouts at the new head and report the count.
Owner should test: the decision card on the 2.8 m stack; Long road trees; Ridge hazels and North bridge heads; Fort
west wall and Ford ramp; Depot's sites behind the stacks; Subway's flag B and the lift ride after the ticket gates.
