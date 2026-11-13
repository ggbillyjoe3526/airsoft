Task: MB2 · Woodland's road stack at a woodpile's 1.8 m
Attempt: 1 of 4
Head: 763c0a5124121c843316dab03f38ae6ffa283b95 (checks passed on it; performance ran on 99930c3, and 763c0a5 only adds
docs/records/MB2.md and pipeline/out/performance.md, so its Pass stands)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✗
Score: 7/8 → Accept (one non-blocking check failed, judgment)

Evidence for the passes:
- Check 1, criterion 1: `tools/woodland/layout.py` drops `top=2.8`. In the map JSON the stack's block is 2.162 m tall
  with its centre at y 0.649 (it was 3.162 m), and `test_mb2_qa.gd` holds "only the six camp gate screens stand
  taller".
- Check 1, criterion 2: the THICKETS polygon builds as a thicket block x 21.3..23.0, z 39..45, 5.37 m tall.
  `test_mb1_layouts.gd`'s new test fails without it; the ray test is the one already on main.
- Check 1, criterion 3: the play records recounted. Elimination's west end: y18 111/235 = 47.2 %, w16 98/236 =
  41.5 %, v15 115/239 = 48.1 %. Attackers in Attack / Defend: y18 70/130 = 53.8 %, w16 74/121, v15 69/117. All match
  the record's table and are inside the bands.
- Check 1, criteria 4 and 5: nothing under game/ changes, no new model or sound, the three docs are updated.
- Check 6: the spruce passes as an honest reading of "Lower it to 1.8 m": the woodpile stands 1.8 m and the field's
  own thicket language closes the line, as the card's "cover it another way" allowed. In practice the 2.8 m wall is
  back as a 5 m one at the same spot, dressed as trees, and the stack is no longer the east's cover. The owner should
  judge this in play.

Failed check:
8. [judgment] The docs misstate what the evidence shows.
   - `docs/DECISIONS.md` and the THICKETS comment in `tools/woodland/layout.py` give 41 % to the bare lowered stack;
     it is the run with a stack added at flag B's yard. The bare stack was never match-measured.
   - `layout.py` cites MB1's "1,531 of 55,625 lines"; the record gives 1,485 for the bare lowered stack and 350 for
     the test's own count. One figure, labelled.
   - `layout.py` still calls the stack "the east end's hard cover over the dip", now false.
   - The record's Known issues left names a tight south passage with no `docs/KNOWN_ISSUES.md` row, and its width
     disagrees with QA's measure and with `test_mb2_qa.gd`'s message.

Must-fix (in this pull request, no retry needed): the four above.

Owner should test in the game:
- From the hump on the Long road west of the Culvert: does the 1.8 m stack with 5 m spruce right behind it read as a
  lowered woodpile, or as the old tall wall dressed up?
- As the east, push up the road: is the stand's corner at (24, 45) usable cover?
- Walk the south way round the stand (about x 22, z 45.5) at a sprint: do you snag between the spruce and the verge
  stack?
- Is the spruce the same green and density as the Ford's thickets, with no hard box edge where it meets the stack?
- At flag B as a defender: is the pole still safe from the road, and does B still feel soft?
