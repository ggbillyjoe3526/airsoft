Task: SM2 · Subway models #14 to #18: escalator banks, lift car and landing, spiral stair, platform stair, railing
Attempt: 3 of 4
Head: b9cc7c9 (= HEAD; CI passed on it. QA/performance predate d2e7c76, the model-only car sign, reviewed here)
Checks: 1 ✗ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 7/8 → Retry (near miss, judgment)
Failed checks, with evidence:
1. [judgment] The models still fail (a), (b) and (d) next to the owner's photos. Fixed since attempt 2: the stair wedge
   (v3/stair-corner.jpg), the railing capping, the wall-side handrail loop (v3/esc-loop.jpg), the panel's one-piece layout.
   Ratios (render against ref, same view):
   - Lift indicator height : door height 0.11 (v3/5-platforms, 53/450 px) against ref 115640 0.14 (37/262): 21 % off.
   - Vision panel height : door height 0.34 (155/450) against 0.28 (75/265): 21 % off. Panel width : door 0.38 against
     0.41: passes. It still reads as two framed slits with a ~15 % steel mullion (x 1285-1300), not one glazed panel.
   - Landing door width : height 0.64 (290/450) against 0.49 (130/262): 31 % off. Fine if gameplay sized it; say so in Decisions.
   - Railing post : bar width 1.0 against 2.4 (ref 120040): 58 % off, kept (see must-fix).
   - Escalator middle deck : lane 0.9 (esc-top, 220/245) against 115549 0.9: passes.
   (d) Lift display: v3/lift-sign, 5-platforms show a dead black slot, grey arrows (lift.py:+182 "unlit lenses"); ref 115640
     is a lit dot-matrix line. A must-fix in attempt 2; the changelog's "show the floor" is not true on screen.
   (d) Escalator decks: v3/esc-top and esc-loop show navy-charcoal slab sides under a grey cap, a matte painted block.
     Refs 115549/115620 are bright, reflective brushed stainless, with wide flat inclined deck panels.
   (b) The decks' rounded caps show 4 to 5 flat shaded bands (esc-loop x 0-500, esc-top x 950-1400): visible faceting.
   (d) Steps still read cream (esc-loop y 640-800, esc-top y 500-560) though TREAD is 0x48484C (transit_kit.py:+30); ref
     treads are dark with a thin yellow edge. In attempt 2's evidence, not addressed in Decisions.
Must-fix for the next attempt:
- Lift landing display: make it read lit from 6 m: emissive or unshaded warm dots or segments, and lit arrows.
  Indicator about 0.14 of the door's height. Vision panel: one glass pane, a hairline at the meeting line, about 0.28 of the
  door's height. If the doors' width is a gameplay size, write that in Decisions.
- Escalator: bright brushed stainless decks and sides (metallic or a much higher value with a sheen, not 0x7E8285 slate);
  smooth the cap curve (more segments or smooth normals); dark treads with a thin yellow edge. Check the look shader's tone
  on TREAD in a render.
- Railing posts: the "drawn = BB-stopping" rule is a fair readability argument, but it overrides the reference twice now.
  Either draw the post 2.5 bars wide and give it a matching collider, or put the ruling to the owner and record it in DECISIONS.
- Have performance and QA name the final head (d2e7c76 adds 2 surfaces per car: car_sign, car_sign_ink).
Owner should test in the game:
- From across the hall: does each lift's indicator read as a lit floor display, or as a black slot?
- Lift landing doors: does the vision panel read as one window or two slits?
- Escalator decks under station light: stainless steel, or painted slate blocks? Is the rounded cap smooth?
- Look down an escalator: dark steps with yellow edges, or cream steps?
- Railing round the spiral hole: are the posts readable, and do BBs stop where you see steel?
- Inside a lift car: is the capacity sign readable and placed well at eye height?
