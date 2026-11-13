Task: MB4 · Woodland's Brow hazel, back in its place
Attempt: 1 of 4
Head: cbd75ffe66280645a5c383a242cf20c10e5c634e plus the uncommitted tree (partial checks ran on this tree: gdlint, check.py, 7 GUT
  files with 63 tests; the full unit parts and the night guards run in CI)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept (criterion 4's "the guards pass" holds only once CI is green on the pull request)

Evidence for the checks that pass:
1. Criterion 1: tools/woodland/layout.py +521 puts the hazel at (-16.3, -40.5). `git show 85e3f52:data/maps/woodland.json`
   and the working file are identical (I compared them). Criterion 2: I recounted eh, ehb, ehc, ehd: 117 of 246 decided
   rounds = 47.6 %, seeds 1 to 32, in band. rc16* gives 114 of 240 and ef to efg 177 of 418 (seeds 1 to 56), as the
   record says. Criterion 3: h9* gives 136 of 232 = 58.6 %, inside 40 to 65. All 232 rounds match rs9* round for round
   on seed, winner, attackers, reason and alpha_end, so the claim that BU1 never came into play holds. Criterion 4:
   seed 14 was replayed with held_up 0, and test_mb2_qa passes 7 of 7. The night guards are owed to CI. Criterion 5:
   test_mb4_brow.gd checks the hazel stands across the gap.
2. No contract is touched: nothing under game/ changes, only the data and the build script move.
3. Nothing on a per-frame path. The performance agent's identity argument stands: the map file is the one MB2's bench
   measured.
4. On MB2's layout (hazel at z -38.2, radius 1.3, leaves ending at about z -39.5), test 1 finds no bush within 0.2 m
   of the hazel's place and fails. Test 2's lines toward the gap cross x -16.3 at z -40 to -41.6, clear of those
   leaves, so the leaf depth stays under leaf_stop_depth and that test fails too. test_mb4_qa pins BU1's rule on the
   real hazel.
5. The only change is data: tuples in layout.py. The tests are typed and name their constants.
6. The hazel is soft cover with a way through, as MB1 designed and the owner's pictures show. The right call over the
   solid spruce clump.
7. The layout.py comment says why the hazel is back. Both new tests have `.uid` files.
8. One line of data plus its test. KNOWN_ISSUES deletes the fix-now Elimination row and brings the by-team row and
   the Attack / Defend row up to date; DECISIONS' MB2 entry is amended; the wiki's Maps page speaks of "a hazel
   hedge" in general, so no change is due.

Failed checks: none.

Advisory (no fix needed to accept):
- Test 3 (`assert_lt(nearest, 6.0)`) passes on either layout: it guards the lane, not the hazel.
- QA found a pair 0.7 m apart in the hazel still held for the leaves (BU1 opens at about 0.66 m). Seed 14 plays
  clean. If a night guard in CI flags held_up on Woodland, add a KNOWN_ISSUES row before merging rather than moving
  the hazel again.

Must-fix for the next attempt: none. Merge only once CI's full unit parts and night guards are green on this tree.

Owner should test in the game:
- Woodland Elimination from the west end: whether the Ridge's brow gives you a screen when the east comes off the
  North bridge.
- Woodland Elimination from the east end: whether pushing over the brow still feels fair, not blocked.
- Walk the north lane past the brow hazel: whether its way through reads, and whether you snag on it.
- In a firefight inside the hazel at point blank: whether you and a bot shoot each other rather than shuffling.
- Woodland Attack / Defend at the 9 s raise: whether the north approach to the flag feels the same as before.
