Task: MQ1B · The Cyber Pistol's grip in the GBB Pistol's shape
Attempt: 1 of 4
Head: 7c4eb6cfcb960b5a365605548fa1f899bbd96d8b (checks passed on it per the brief: lint, notes, wiki, the ten named suites; the full suite on the pre-RP1 tree)
Checks: 1 ✗ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 7/8 → Retry (near miss, judgment)
Failed checks, with evidence (file:line, one or two lines each, each marked measured or judgment):
1. [judgment] The model fails the bar (rule b, d; a partly). It does meet the ask in outline: the straps and depth match the GBB's (test_cyber_grip.gd:54) and the slab is gone (cyber.py:+722 grip()).
   (b) A floating part: the cross pin is still at (-86, -16.5), the full FRAME_HW wide (cyber.py:688), but the dust cover's corner it went through was cut back (cyber.py:+636, -90 to -78) and the tang was narrowed (GRIP_CAP_NARROW, cyber.py:163). A bare grey rod now sticks out of both sides above the back strap (cy2/grip.png top right, gripf.png top left, rearq.png at the rear cap). The before pictures show only a flush pin head.
   (b) Visible faceting and lumpy shading on the curves: a stair-step shadow line and diagonal banding down the back strap (cy2/back.png). The finger grooves and back strap edge look wobbly and melted (grip.png, under.png). The GBB's grip is smooth at the same distance (gbb_grip.png). Likely causes: GRIP_RING = 28 (cyber.py:160), then the frame union and the six back-groove box cuts, then hs.finish (cyber.py:666) bevelling the loft.
   (b) Joins: the flat-sided guard web and frame overhang the rounded grip as a ledge at the top of the front strap, where the middle finger rests (grip.png about 440,240; gripf.png about 1120,220). The rear block's flat sides stand out from the tang (back.png about 650 to 950, y 130 to 190).
   (b) The base pad does not follow the grip: it is a square block, PAD_HW 17.0 (cyber.py:197) against the grip's 15.5 mm half width (QA: Magazine x ±16 against Body ±15). It sticks out past the rounded foot on every side (under.png), starts behind the heel and runs past the front strap (side.png: heel x 245 against pad x 258; shell front x 548 against pad front x 560).
   (a) Side views, each ratio divided by that model's own maximum grip depth. Cyber/GBB: foot depth 0.96/0.98 (−2 %); depth under the guard 0.89/0.86 (+3 %); heel rake 0.48/0.43 (+10 %); grip shell height 1.09/0.98 (+12 %, fails); pad height 0.30/0.18 (+67 %, fails); grip plus pad below the guard 1.40/1.16 (+20 %, fails). The 152 mm height rule leaves the Cyber about 13 mm extra, and all of it went into the grip and the tall pad, so the grip reads as a stretched GBB grip sitting on a block.
Must-fix for the next attempt:
- Move or drop the pin at cyber.py:688 so nothing sticks out of the narrowed tang, and render the area to confirm it.
- Smooth the grip skin: more ring points or rows, or apply the bevel and weighted normals before the groove cuts. back.png and under.png should show no stepped shading.
- Blend the web and frame into the grip's top (fillet or loft the tang into the frame's sides). Neither the front strap nor the rear cap should leave a ledge.
- Make the base pad follow the foot's rounded outline, inset at or under the grip's width, and lower: about the GBB's pad height plus at most 3 mm. Use the height you free to bring the grip shell within 10 % of the GBB's. Re-render side, back, under and grip close-ups next to gbb_side and gbb_grip, and list the ratios again.
- Non-blocking: cyber.py:742 calls gbb._at, a private helper in another module; make it public in gbb.py.
Owner should test in the game (at most 6, one line each):
- Inspect (Y) the Cyber and look above the back strap for a grey rod on either side.
- Turn the Cyber under the Depot lights: does the back strap and finger groove shading look smooth or lumpy?
- Compare the Cyber's grip length and base pad with the GBB's at the hip: does it read as the same grip?
- Until FP arms refits the hold, the right hand floats off the new grip (first_person.jpg inspect45 and 70). Check it after that merge.
- Reload the Cyber: the narrower cell and the moved pad should leave the grip with no visible gap or clipping.
- Look at a bot's Cyber close up (2,998-triangle copy): the grip should be rounded, not faceted.
