Task: BL2 · the GBB Pistol's model (round 13: the owner's two changes only)
Attempt: round 13 (round 12 Retry 7/8 on item 1)
Head: da94804 + uncommitted working tree (gbb.py, pistol.glb = scratchpad gbb/v33.glb, byte-identical)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept
Measured (ref = g17.jpg 2x/4x crops; render = gbb33/td_closeL.png; band = slide foot to guard opening):
- Lean: ref lever 0.34 px/px (19°); render tab 0.34 (line fit), recess walls about 0.36 left and right. Pass (was 0.22).
- Recess W/H: ref 0.99, render 1.01 (113 x 112 px). H/band: ref 0.79, render 0.76. Top gap under the slide/band:
  ref 0.03, render 0.05. Lever centred across. Pass.
- Walls: left and bottom ramps about 10-12% of the recess each (ref about 12%), cosine-eased, with no hard outline;
  gbb.py:103 and the takedown_recess rings. The top wall is narrower at about 8%: reads as the light, acceptable. Pass.
- Lever width (owner asked to follow the photo): tab 0.18 of the recess width, ref 0.18; 0.135 of band, ref 0.14. Pass.
- Nose: v33 glb, slide Body z min -98.93 mm, frame nose -98.93 mm: flush to 0.00 mm; SLIDE_Y (gbb.py:62) unchanged
  since round 12. Pass.
- Hands 39,636 triangles, under the 40,000 budget. Lines at most 120 characters in gbb.py.
Failed checks: none.
Notes (not blocking):
- The slot (gbb.py:507) is 0.5 px wider than the tab's foot on the right only (279.3 against 278.8); invisible at
  this zoom, but match it to 278.8 + 0.17 next time gbb.py is touched.
- The lever plus slot stay about 10% shorter than the photo's lever in the recess (render 0.58 of the recess
  height, ref 0.62; outside this round, stood accepted).
- The higher-resolution tdh/noseh renders weren't there yet when I judged; the verdict rests on td_closeL and the glb.
Owner should test in the game:
- The recess in the first-person hold and the inspect view: a soft pocket, leaning with the narrower lever.
- The nose from the side in the hand: the slide's face and the frame's nose read as one plane.
