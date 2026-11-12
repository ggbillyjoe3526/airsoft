Task: MB1 · The three fields' layouts, reworked from their play records
Attempt: 1 of 4
Head: 2b7d90b (checks passed on it; QA and performance read 85bcc67, before the SM3 merge)
Checks: 1 ✗ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✗ | 8 ✓
Score: 6/8 → Retry (near miss: fixing check 1, judgment, gives Accept)
Failed checks:
1. [judgment] The 2.8 m road stack (tools/woodland/layout.py:390) breaks the 2026-11-09 "less tall" ruling, and the
   reason given for it is out of date: the 52 m figure is onto the old post at (44, 35), which moved behind the crates
   in the commit that raised the stack. By tools/maps/los.py (2.5D) neither the current post nor the pole is seen from
   400 hump points at either height.
7. [judgment] tools/map_heat.gd:4-5 and tools/map_survey.gd:3-4 name tools/maps/heat.py and report.py, which don't
   exist (plan.py and los.py do the job).
Notes: test_mb1_layouts.gd pins the line onto OLD_POST, a spot nobody is sent to; the Subway depth test allows 7 m.
Condition (check 8): Subway's figures must be re-measured through SM3's gates before the push; out of band beyond the
noise is a check 1 failure next attempt.
Must-fix: measure the stack at 1.8 m against the current posts and the pole (16 seeds or the game's ray); lower it if
the line stays shut, else ask the owner for the exception; point the hump test at the current posts and the pole and
correct the record's and DECISIONS' wording; fix the two tool headers.
Owner should test: Long road trees and the culvert stack's look at 2.8 m; Ridge hazels and North bridge heads; Fort
west wall and Ford ramp; Depot's sites behind the stacks; Subway's flag B and the lift ride past SM3's gates;
Woodland draw calls on High with F3.
