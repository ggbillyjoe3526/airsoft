Task: HA1 · First-person arms and grips, made realistic
Attempt: 1 of 4
Head: bbf29a3 (checks passed on 8218b4d; after it only the perf report and CI3's docs/guards merge, re-linted on bbf29a3)
Checks: 1 ✗ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✗ | 8 ✓
Score: 6/8 → Retry (near miss, judgment: check 1 alone stands between this and Accept)
Failed checks, with evidence (file:line, one or two lines each, each marked measured or judgment):
1. [judgment] Models rule (a) unmet: no render in the brief shows a hand at hand-skin-photo.jpg's angle (flat, from the back, fingers spread), so the five ratios can't be measured and nothing shows the hand is within 10 %. The record's own numbers point the wrong way: wrist 55 mm (50 +10 %) on an 85 mm hand is 0.65, and the photo's wrist to knuckle width is about 0.75 (~13 % thin; rough figures, needs the render).
1. [judgment] (b)/(c) ha1-final-closeups.jpg "AEG: from the far side": index and middle fingers are bent back into a knot under the handguard, their tips curled into the palm with a gap to the rail. They hold nothing, and their middle joints fold at angles a hand can't make. That contradicts KNOWN_ISSUES:113 ("lie open along the handguard's far side"). Bots copy this hold (FigureView.support_mark), so it shows on every bot close up. Sniper and SMG need the same check.
1. [judgment] (d) Bare skin in game (ha1-final-skin-zoom.jpg "GBB, bare hands", "GBB aimed, bare hands", "AEG, bare hand"): one flat tone with smooth shading. The back of the hand has no knuckle relief, no tendon lines and no vein or crease contrast. The thumbs read as thick, even tubes. Next to hand-skin-photo.jpg it reads as a plastic mannequin, not finished AAA work. The owner asked for "detail of the hand model and its textures", and the record admits the skin "read pale and smooth in the game".
1. [judgment] Pistol at the hip (ha1-final-hip.jpg "GBB Pistol, two hands"): the pistol is about 6 % of the frame width, against about 40 % in pistol-hip-two-hands-1/2.jpg, and the hands fill the foot of the screen. The references set placement and how much shows. This keeps the 2026-11-06 place as a "default taken" (HA1.md Decisions, Pistols), not an owner ruling.
7. [judgment] tools/blender/arms/arms.py grows to 1,459 lines (+579), with pose.py at 932 and glove.py at 881: the holds' tables (GUARD, GRIP_LEFT, SUPPORT_LEFT, CYBER_*) and their solvers sit in one script. Split the hold tables and per-family solvers into their own modules.
Must-fix for the next attempt:
- Add a Blender preview (tools/blender/arms/preview.py) of the bare left hand in rest pose, flat from the back, framed like hand-skin-photo.jpg. List at least five ratios against the photo: hand length to knuckle width, middle finger to palm, index to ring, thumb tip to index MCP, wrist to knuckle width. Fix any that is more than 10 % off (start with the wrist, glove.WRIST_FULL).
- No-grip rifle holds (arms.py GUARD, SNIPER_GUARD, SMG_GUARD; Hand.onto): lay the far-side fingers along or round the handguard's underside, touching it, each joint under about 90°. No knot, and keep the tips under tips_below so the eye still sees only the thumb. Re-render "from the far side" for all three rifles.
- Skin (skin.py TONE, MOTTLE_SHADE, crease/vein/tendon depth, and the normal map's strength): make the knuckles, tendons and veins read in the game's light at the skin-zoom framing, and taper the thumbs' sections toward the tip. Re-shoot ha1-final-skin-zoom.jpg beside the photo.
- Pistol hip place (ViewModelConfig.hip pistol/cyber): bring it nearer and larger toward the references' framing, or get the owner's word on the current place from a side-by-side picture and record it in DECISIONS.
Owner should test in the game (at most 6, one line each):
- Walk, strafe, jump and land with the AEG: are the bob, lean, landing dip and per-shot roll pleasant, not seasick (HandsLifeConfig)?
- Raise and lower the sight quickly on every rifle with each grip: does the left arm slide out of view cleanly, with no pop or flash of fingers?
- GBB and Cyber aimed: does the fade under the slide read as "tops of the hands", not a ghost smear at the bottom left?
- Bare hands (Settings › Dev › Skin-only arms) on the pistols: does the skin look like a hand or like plastic?
- Stand next to a bot holding an AEG with no grip: are its left fingers a believable hold?
- Pistol reload: does the left hand leave and come back without clipping the right arm?
