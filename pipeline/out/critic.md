Task: GS2 · GBB slide at rest, the slide from the owner's photos, AEG sights and stock
Attempt: 5 (the owner's extra round, 2026-11-05 19:42)
Head: c546a06 (targeted tests only, 675 passing; QA and performance passed at 35baade; the change since is gbb.py, pistol.glb, a test and docs; full check still running)
Checks: 1 ✗ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 7/8 → Retry (near miss, judgment). This was the extra round: stop and report to the owner.
Ratios, at rest. Side: fea446d0 (0.088 mm/px) vs gbb6-left (0.221 mm/px, the slide's foot py 494):
 lip drop below the slide's foot 11.9 vs 11.5 mm (x 314-318, bottom py 546), -3 % (gbb.py:106 LIP_FOOT Z(143)): fixed;
 frame depth below the foot 15.0 vs 15.9 mm, +6 %; lip drop / frame depth 0.79 vs 0.72, -9 % (in range, near the edge);
 barrel OD, bore height, proud and grooves as attempt 4.
 Spring hole: a97f366d hole 34 px vs barrel crown 46 px (rows 128 and 256) = 0.74; gbb6-face 148 vs 205 px = 0.72;
 10.4/14 = 0.74 (gbb.py:112 GUIDE_R 0.0052). In range; attempt 4's 0.80 was read off outlines, not the crown.
Fixed from attempt 4: the lip depth; the spring is a coil (gbb.py:408-427, 7 turns of 1.2 mm wire, reads as a coil
 in gbb6back-qf); the channel's walls 1.2 mm (gbb.py:154 RAIL_SLOT_DEPTH 0.0039); 39,956/40,000 triangles.
Failed checks, with evidence:
1. [judgment] construction, locked back, against the owner's two locked-back photos (404a610f, 83c82df7; I had not
   compared them in attempt 4, so this is new): in both, the dust cover's nose is closed up to the barrel and nothing
   shows in front of the slide. In gbb6back-qf and gbb6back-low the spring stays full length (29.6 mm, gbb.py:411) in
   front of the slide: its front end bears on the rod's cap, not on the slide, so it threads through the lip's hole
   uncompressed and shows over the near wall, with the 9.6 mm cap standing in front of the frame. A real recoil spring
   pushes the slide: locked back it is squeezed behind the lip, and at most the rod's tip shows. It is also
   loose on the rod (inside 4.8 mm round a 2.4 mm rod). The dust cover's front is a flat, square-cut face with
   box-edged channel walls (gbb6back-low), where 83c82df7 shows a rounded nose.
Must-fix, if the owner wants another round:
1. Spring between the rod's rear flange and the slide's lip: compress it with the slide (a bone scaled along the
   rod or shape keys), or hide it behind the lip. Locked back, only the rod's tip shows in front of the slide.
2. Raise the channel's walls to just under the barrel (404a610f: a hairline gap), so nothing shows from the side.
3. Round the dust cover's front corners and bottom (83c82df7); bevel the channel's top edges about 0.3 mm.
Owner should test in the game:
- GBB locked back on empty (Inspect, third person): the spring sitting in front of the slide, next to your photos 404a610f and 83c82df7.
- GBB at rest after every action; firing and on empty only the slide and its lip move, the barrel shows.
- GBB front in Inspect: the muzzle and the 10.4 mm spring hole next to your photos.
- GBB sight picture unchanged: front post in the rear notch, readable at 25 m.
- AEG irons at 25 m; fit and remove an optic: irons gone whole, back on removal.
- AEG reload/Inspect: handle pulls straight back clear of the rail and stock.
