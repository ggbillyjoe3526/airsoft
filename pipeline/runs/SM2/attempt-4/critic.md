Task: SM2 · Subway models #14 to #18: escalator banks, lift car and landing, spiral stair, platform stair, railing
Attempt: 4 of 4
Head: a768414 (= HEAD a76841493825; CI passed on it. QA and performance at 70f791f; later commits are tests, reports, the main merge, a README row)
Checks: 1 ✗ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 7/8 → Retry (near miss, judgment). Fourth attempt with check 1 failed: no auto-accept; goes to the owner.
Failed checks, with evidence:
1. [judgment] Fixed since attempt 3: the vision pane reads as one pane with a hairline, 0.29 of the door's height (v4/1, 74/254 px;
   ref 115640 75/262); the escalator treads are dark with thin edges (v4/esc-on); door size and railing posts are now
   argued in Decisions (records/SM2.md:86-93, SR1), accepted as gameplay constraints.
   Ratios (render against ref, same view): pane h : door h 0.29 against 0.29 (passes); door w : h 0.46 against 0.42-0.49
   (passes); display h : door h 0.11 (v4/1, 27/254) to 0.15 (v4/5, 56/380) against 0.14 (passes); pane w : door w 0.36
   (v4/5, 105/290) against 0.41-0.47 (12 to 23 % off); railing post : bar 1.0 against 2.4 (kept by SR1, recorded).
   (d) Landing display, a must-fix in attempts 2 and 3: the display is still a dead black slot across ~80 % of its width
   (v4/1 x 592-708 and 925-1078; v4/5 x 668-845, 1218-1520). Both references (115640, 115648) are a lit orange
   dot-matrix line. Only the arrows went unshaded (lift.py:+476 `lights.append(arrows...)`), in LENS 0xE6E2D6
   (lift.py:62): pale grey on grey trim, small, they don't read lit from 6 m (v4/1 x 570-590, 895-918). The changelog's
   "Lift landing doors show the floor across the full door width" (changelog.d/sm2-subway-transit-models.md:6) is
   still untrue on screen.
   (d) Escalator from the top (v4/esc-top): the newel ends and deck fronts still read as navy-slate blocks under a grey
   bolster (x 20-280 and 930-1400, y 380-640); refs 115620/115549 are bright stainless drums and flat inclined panels. The
   step edges read cream, not safety yellow (v4/esc-on y 540-900).
Must-fix (owner's call now; attempts are spent):
- Put something lit in the display slot: an unshaded line of warm segments or a static floor glyph (a non-team warm
  white or pale green if amber clashes with Beta's orange), filling the slot; make the arrows brighter than the trim.
  Or strike "show the floor" from the changelog and record the unlit display in KNOWN_ISSUES.
- Escalator newel ends and deck fronts in the bright stainless of the balustrades; step edges a clear yellow.
- Vision pane about 0.42 of the door's width (each half pane 0.22 m, not 0.16).
Owner should test in the game:
- From across the ticket hall: does a lift's display read as a lit floor indicator, or a black slot? Do the arrows read lit?
- Lift landing doors: one window across both leaves; is it wide enough?
- Standing at the top of an escalator bank: steel, or slate blocks? Steps dark with yellow edges?
- Ride an escalator: do the decks and balustrades read as stainless under station light?
- Railing round the spiral hole: are the posts readable, and do BBs stop only where you see steel?
- Inside a lift car: is the capacity sign readable at eye height?
