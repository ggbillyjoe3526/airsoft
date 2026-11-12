Task: SM2 · Subway's escalators, lifts, stairs and railing as models
Attempt: 2 of 4
Head: 2cdc8a5 (= git rev-parse HEAD; full check.sh still running at review, QA re-ran the SM2, lift and field-rules tests here; performance reviewed 9d70160, whose delta to HEAD is 12 lines of lane points, no script)
Checks: 1 ✗ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 7/8 → Retry (near miss, judgment)
Failed checks, with evidence:
1. [judgment] The models still fail (a), (b) and (d) next to the owner's photos. Ratios (render against ref, same view):
   - Escalator middle deck : lane 1.2/1.2 = 1.0, ref 115620 about 1.0-1.1: pass now (layout.py:+70-71).
   - Railing post : bar width 1.0, ref 120040 2.4 (58 % off). The posts stay invisible and the plates sit under bars.
     "Wider would add steel no BB meets" does not hold: 2.5 cm of visual-only post is the same grazing error the record already accepts.
   - Railing capping colour: still beige over black bars (rail-close.jpg). Ref 120040 is one dark paint. This was a must-fix,
     and it is neither fixed nor argued in the Decisions.
   - Lift indicator depth : door height 0.04 (1-hall-both-doors.jpg, ~10/255 px), ref 115640 0.15 (~40/260): a thin black
     slot where the photo has a full-width lit dot-matrix head. The "lit lens" (lift.py:+61) can't be seen at 6 m.
   - Lift vision panel: two 15 px slits, one per leaf, against one ~0.4-door-wide panel across the meeting line (115640).
     "A MultiMesh can't mirror one leaf" is a tool limit, not a design reason: give each leaf the half panel at its meeting
     edge (two leaf meshes, or a flipped basis), or ask the owner.
   (b) esc-top.jpg (v2): three handrail newels loop over the landing, but the fourth (the right lane's wall side, x≈940)
     shows as a short stub inside the wall deck's end cap: sunk or clipped. stair-top.jpg (v2): the dark wedge between
     the first flight and the left wall (x 170-230, y 560-600) is still there.
   (d) esc-bottom.jpg / esc-on.jpg (v2): the decks (STAINLESS_DARK 0x8E8C86, transit_kit.py:+29) still render flat matte
     beige with no sheen or panel joints on their tops (the seams, escalator.py:+287-297, are only on the balustrade faces).
     The wall deck reads as the greybox block. Refs 115549/115620 are bright brushed steel with panelled decks. At the top
     landing the steps and plates still read cream (esc-top.jpg).
Must-fix for the next attempt:
- Escalator decks: brushed steel that reads as metal (metallic or a much brighter, cooler value with a sheen), panel joints
  across the deck tops, and the same on the wall decks. Fix the right-hand newel/handrail loop at both banks' tops.
- Railing: posts about 2.5x a bar wide with their plates under them; capping in the bars' dark paint.
- Lift: a full-width indicator head over each landing door (deeper box, visible lit display); one vision panel across the
  meeting line, half on each leaf.
- Platform stair: close the wedge at the left wall of the top flight.
- Have performance stamp HEAD (or the final head) so both reports name it.
Owner should test in the game:
- Escalator decks under the station lights: steel or painted plaster?
- Top of each escalator bank: all four handrails loop into their newels, none cut by the wall decks?
- Ride both escalators two abreast at 1.2 m; bots on the m lane keep to it without catching on the decks' ends.
- Try to jump or vault onto a 1 m deck (jump apex ~0.73 m, vault max 0.95 m): you should not get up.
- Each lift landing from across the hall: does the indicator read as a lit floor display?
- Railing round the spiral hole close up: do the posts read as posts?
