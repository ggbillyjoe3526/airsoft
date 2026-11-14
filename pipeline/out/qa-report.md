Task: HA1 · QA commit 0697481 · Verdict: Pass

Blocking: none. Advisory: none new.

Measured on HEAD 0296059 (delta since 6b6101f; no game/ change):
- Floating (closing passes skipped): distance of each left fingertip (skinned last bone + its length, in the replica's space) to the nearest replica triangle edge. HEAD: Sniper Index 8.7, Middle 13.8, Ring 3.8, Pinky 7.8 mm; SMG 5.2, 1.0, 3.4, 2.4 mm. Attempt 4's model: Sniper 3.9, 2.9, 2.8, 4.9; SMG 4.9, 2.4, 4.0, 9.0 mm. The Sniper's index and middle tips stand a little further off (fingers now stand ahead and in a row); all under the 30 mm limit, none floating. The edge measure over-states the gap to a face, so these are upper bounds.
- Unchanged holds: test_sh2_qa (pump), test_ha1_grips, test_hands_on_replica (every rifle's left hand on the replica, no finger inside), pistols and right hands all green. Eye test (no left finger visible past the replica from the eye): 0 points on all four replicas, green.
- Reloads and bolt clips start/end at the hold (existing tests green, no pop).
- Fingertip test soundness: the tip is last-bone origin plus TIP_BONE along the bone's own axis (skinned), and "ahead" is judged in the replica's root space (-z). I installed attempt 4's glb (04497dc) and imported: it fails exactly the round-4 fault (Sniper and SMG Pinky tip behind its knuckle; ring to pinky tips 35.0 / 36.4 mm; index to middle 26.7 / 20.9 mm) and the spacing test fails there too. HEAD's glb restored with git checkout and re-imported; the tree has no arms.glb change.
- Front-end test: it asserts only that a handguard side exists with depth; it has no millimetre margin to quote, so I could not compare the "hundredth of a millimetre" figure from here (the margin lives in the build tool, not in a test).
- Budgets: triangle (40,000, both looks) and the file under 8 MB (6.48 MB) tests are in the green set.

Test added: tests/unit/test_ha1_qa4.gd:30 · test_no_left_fingertip_floats_off_the_handguard_on_the_sniper_and_the_smg: each of the eight left fingertips within 30 mm of the replica's surface. Checked against attempt 4's model: it passes there too (max 9.0 mm), so it is a regression guard for the skipped closing passes, not a catch for the old fault (test_ha1_qa3's new test is that, shown failing above).

Suite: the ten named files plus mine, 126 tests, all passing (125 of 5,393 asserts in the build's set re-run in 15 s by me, plus the new file's 8 asserts). Not run, by instruction: tools/check.sh and the whole suite, and the smoke test (the build thread's run).
Could not test: how the four fingers look side by side in a real window (needs a display; owner's list): that the little finger reads as a hand, not a comb, on the Sniper and SMG.
Raw output: pipeline/out/qa/run8-existing.txt
