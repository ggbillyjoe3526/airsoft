Task: HA1 · First-person arms and grips, made realistic
Attempt: 2 of 4
Head: ec22685 (checks passed on it)
Checks: 1 ✗ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 7/8 → Retry (near miss, judgment: check 1 alone stands between this and Accept)
Failed checks, with evidence (file:line, one or two lines each, each marked measured or judgment):
1. [judgment] Owner's ruling broken at the AEG hip: the left fingertips show past the handguard's RIGHT side, in both looks (ha1-final-hip.jpg "AEG Rifle", a glove lump right of the rail's top; ha1-final-bare-before-now.jpg "NOW: AEG at the hip" and ha1-final-skin-zoom.jpg "AEG at the hip, bare hand", clearly skin). This is his "You can still see the players fingers on the right side of the AEG" exactly. hold_tables.py:177-183 (GUARD `tips_below` 0.050) keeps the tips 2 cm under the top in replica space, but the hip eye looks down past the far edge. test_ha1_rifle_hold.gd:82 tests height in replica space, not what the eye sees, so it passes. Sniper and SMG show only the near side (ok).
1. [judgment] (b) Far side, attempt 1's must-fix not met (ha1-final-closeups.jpg "FROM THE FAR SIDE", AEG, Sniper, SMG): an open "waiter's tray" palm. Only the index tip meets the handguard. The middle, ring and little fingers fan apart in the air with gaps between them and to the handguard. On the AEG and SMG their tips reach past the handguard's front, under the barrel. The ask was "along or round the underside, touching it". The joints are no longer knotted (<90°), but the fingers still float and hold nothing. Bots show it close up.
1. [judgment] (b) Palm side (rest_palm.png, same build): a hard-edged lighter patch, an arc, across the palm at the index finger's base (a paint or atlas seam). The thumb's outline has a sharp notch where its nail edge meets the pad, and a white nail sliver shows from the palm side. The palm is seen from below in the AEG bare hold.
1. [judgment] (b)/(c) Sniper right hand (closeups "Sniper: right hand"): the fist hangs under the stock's wrist. Only the thumb is over it. The middle, ring and little fingers close on nothing, and the trigger finger lies straight under the guard, 2 cm short and below the trigger. Listing it in KNOWN_ISSUES does not make it finished work, and it is in this task's scope ("grips ... made realistic").
1. (a) passes on the seven ratios, re-run by me (hand_ratios.py rest_back.png 1183): -6.7, +2.1, -2.6, -5.0, -5.2, +2.5, -7.7 %. The thumb is not proven. On rest_back.png the thumb's web-to-tip run over the middle finger is about 0.55, against 0.70 on the photo (-21 %). Some of that is foreshortening, but no picture settles it.
Must-fix for the next attempt:
- AEG no-grip hold (GUARD, Hand.onto): judge `tips_below` from the eye at GAME_HIP. Each far-side fingertip's projection must lie inside the replica's silhouette, at the hip and through the raise. Turn test_ha1_rifle_hold.gd:82 into that eye-space check (it fails today), then re-shoot the AEG at the hip in both looks.
- Far-side fingers (AEG, Sniper, SMG): curl the middle, ring and little fingers against the handguard's underside or far face, touching it, closed together like the index, tips behind its front end. Joints stay under 90°, and the eye check above still holds. Re-render "FROM THE FAR SIDE" for all three.
- Skin: remove the hard arc on the palm at the index base (paint or atlas seam; the colour must stay as approved) and smooth the thumb's outline at the nail edge. Re-render rest_palm.png.
- Sniper right hand (SNIPER_RIGHT): wrap the middle, ring and little fingers round the stock's wrist and seat the trigger finger's pad on the trigger, as the AEG's is.
- Thumb: add a rest render with the thumb held out as in the photo and list thumb length over middle finger length within 10 %.
Owner should test in the game (at most 6, one line each):
- AEG at the hip, gloves and bare: do any left fingertips show on the right of the handguard?
- Sniper, work the bolt at the hip: the right glove fills the top-right quarter of the screen (ha1-final-aimed-skin.jpg). Acceptable?
- Pistols at 25 cm, walking and firing: does the new bob, flick and roll feel good and not seasick?
- GBB and Cyber aimed, bare hands: does the faded lower edge of the left hand read as "tops of the hands" and not a ghost?
- Raise and lower the sight fast on each rifle: no pop or flash of the left hand?
- Stand by a bot with an AEG and a Sniper: are its left fingers and right hand a believable hold?
