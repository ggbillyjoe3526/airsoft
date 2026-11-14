Task: HA1 · QA commit a513680 · Verdict: Pass

Blocking: none. Advisory: none new.

Delta reviewed: 0697481..HEAD (53312e8): pose.py `_strays` (tighten, wrap), hold_solve.py (row set in left_on_guard, cleared per solve), hold_tables.py, the rebuilt arms.glb.

Fingertip gap (skinned last bone + tip length to nearest replica edge, test_ha1_qa4), run 9 against run 8:
- Sniper Index 8.3 (run 8: 8.7), Middle 7.4 (13.8), Ring 2.3 (3.8), Pinky 6.9 (7.8) mm.
- SMG Index 5.2 (5.2), Middle 1.0 (1.0), Ring 3.0 (3.4), Pinky 2.4 (2.4) mm.
- Sniper's middle fingertip is 6 mm closer than in run 8; every tip is under the 30 mm limit. The build's 4.3 mm middle figure is on its own skin measure; mine is to the replica's mesh edge.

Added: tests/unit/test_ha1_qa5.gd:26 · test_every_left_finger_is_closed_round_each_foregrip: for the AEG and the Sniper, Vertical and Angled Grip clips, each left finger's three joint bends (each against the bone before it, the hand's first) summed on the skinned model must exceed a floor (Index 110, Middle 140, Ring 330, Pinky 330 degrees).
- HEAD values, all four holds alike: Index 154 (vertical) / 129 (angled), Middle 171 / 184, Ring 368, Pinky 350.
- Checked it fails without the fix: I installed the kept intermediate build (scratchpad/full24/out.glb, whose log has the Sniper's ring and middle tighten at 0), imported, and the test failed on the Sniper's Vertical and Angled holds: Ring 260 and Pinky 299 degrees. Its Middle was 167 (above the floor, so only 2 of 4 fingers fail on it). Then restored with git checkout of arms.glb and imported again; the test passes on HEAD (20 asserts). The tree is clean of the glb.
- Note: my first measure (angle between first and last bone) passed on the loose build, since it wraps past 180 degrees on a tightly closed finger. It is a poor measure, and I left it out.
- AEG's values are the same on HEAD and the kept build (368 / 350), as expected.

Re-run on HEAD of the 12 listed files (the 11 you named plus test_ha1_qa5): 127 tests, 127 passing, 5,421 asserts (the build thread had 126, 5,401). Raw output in pipeline/out/qa/rerun9.txt. They cover the AEG's left fingers, the shotgun pump, the pistols, right hands, bots copying the holds, the reload and bolt start and end at the hold, the eye test at 0 points, the front-end test and the budget tests; none moved.

Not run (as told): tools/check.sh and the whole unit suite; the smoke test.
Not testable here: how the fists and fingertips look in play (needs a display): the owner should look at the Sniper's and the SMG's left hand on the handguard, and at the Sniper's Vertical Grip against the AEG's.
