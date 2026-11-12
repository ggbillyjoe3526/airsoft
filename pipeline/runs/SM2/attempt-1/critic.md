Task: SM2 · Subway's escalators, lifts, stairs and railing as models
Attempt: 1 of 4
Head: 74ea639 (checks passed on it: unit fixes re-run on the 3 files; full check.sh ran on d8f933a)
Checks: 1 ✗ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 7/8 → Retry (near miss, judgment). It is Retry anyway: QA reviewed 28e8bcc and performance 7af4936, both before d8f933a/74ea639 (decks re-laid, lane points moved, play_tuning.tres edited), so neither has a report for this head.
Failed checks, with evidence:
1. [judgment] The models fail the bar next to the owner's photos (a, b, d). Ratios, renders against refs from the same angle:
   - Escalator, middle deck : lane width: 2.0/1.2 = 1.67 (layout.py:+70 ESC_MID 1.0, ESC_LANE 1.2; esc-bottom.jpg ~240:120 px), refs 115549/115620 about 1.0-1.2: >10 % off. Balustrade : step rise and deck : wall-deck widths follow from it.
   - Railing, bar pitch : height: 0.14/1.1 = 0.127 (RailingConfig bar_pitch); ref 120040 ~28/290 = 0.097: 31 % off.
   - Railing, post : bar width: 1.0 (railing_look.gd:+14, "as wide along the run as a bar"); ref 120040/120051 ~2.4: posts don't read as posts.
   - Platform stair, handrail diameter : riser: ~0.2 (stair-up.jpg, ~8:40 px); ref 115846 ~0.9: rails read as wire.
   - Lift landing: one vision panel across both leaves in ref 115640; the model has two narrow ones, and a dark slot where the ref's dot-matrix indicator sits.
   (b) Construction: 3-inside-west-car-panel.jpg: the car's door opening is wider than the landing's, so the hall's tiled wall end shows inside the car beside the panel, and two headers stack over the door. esc-top/esclow-top.jpg: the decks' rounded nose caps are visibly faceted (5-6 flat bands). rail-close.jpg: the bars run through the foot rail to the floor (ref: they end in it), plates sit under a bar, not a post. stair-top.jpg: a black wedge between the flights and both walls (gap or unlit skirting; check).
   (d) Materials: escalator.py:+2-3 promises dark aluminium steps and brushed stainless balustrades; the renders show flat matte beige decks and cream steps with no sheen, seam or panel break (refs 115531/115549 are bright brushed steel). Spiral treads and platform-stair treads are flat untextured beige (ref 115846: chequer metal treads). As a set this reads as greybox-plus, not finished work.
Must-fix for the next attempt:
- Escalator: stainless decks and balustrades that read as metal (reflective, panelled), darker steps; smooth the nose caps (more segments, or normals); if the 7 m shaft stays, widen the wall decks and narrow the middle so middle : lane comes near 1.1, or ask the owner.
- Lift: match the car's opening to the landing's (no wall end inside the car), one header; one vision panel and a lit indicator over the door as photo 115640.
- Railing: posts ~2.5x a bar wide with base plates under them; bars end in the foot rail (draw the stub under it as the post/foot only, or ask whether the colliders may follow); same dark paint on the capping.
- Platform stair: handrails ~45 mm with visible brackets; textured treads; close or light the wedge at the walls.
- Re-run QA and performance on the final head (the narrowed decks and lane points are gameplay geometry).
Owner should test in the game:
- Ride both escalators two abreast, and try to vault or jump onto a 1 m deck (vault max_height is 0.95, 5 cm under it).
- Bots on m/s lanes: do they take the 1.2 m escalators without sticking on the decks' ends?
- Stand inside each lift at each stop with the doors open: any wall end or double header showing?
- Escalator decks and steps under the station lights: do they read as steel, or as painted plaster?
- Railing round the spiral hole close up: posts, foot rail, plates.
- Platform stair handrails from the half landing: thick enough to read?
