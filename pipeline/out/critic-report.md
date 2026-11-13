Task: HA1 · First-person arms and grips, made realistic
Attempt: 3 of 4
Head: ef9d94f (checks passed on it; HEAD is 7768f7b, a merge of main (PB3, AU11) that touches none of this task's hunks; its re-run must pass before merge)
Checks: 1 ✗ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 7/8 → Retry (near miss, judgment: check 1 alone; QA Pass, performance Pass)
Failed checks, with evidence (file:line, one or two lines each, each marked measured or judgment):
1. [judgment] (b) AEG far side, attempt 2's must-fix "tips behind its front end" not met, and the record says otherwise. In ha1-round3-far-side.jpg "NOW: AEG Rifle" (and closeups "AEG: left hand, FROM THE FAR SIDE") the foremost (little) finger stands wholly in front of the handguard's front end, against the barrel under the front sight base, about one finger's width past it. docs/records/HA1.md:190 says "none past the handguard's front end". hold_tables.py GUARD (tip_at / tips_behind) does not hold it.
1. [judgment] (b)/(d) Far-side fingers now touch but don't read as a grip. AEG: the index stands alone, a clear gap of more than a finger's width to the middle finger, all four rising nearly straight up from a palm that hangs below the handguard. Sniper: the four fingers are pinched together into a beak, overlapping, pads at mid-height of the stock's side, a light gap between the palm and the stock's underside along its whole length, so the hand hangs from its fingertips. SMG: the index curls into a tight hook pointing back with daylight between it and the middle finger (an "OK sign" ring), the little finger aimed forward (pinky_ahead). A hand carrying a rifle lays the fingers along the side face, closed together, slightly curled, with the weight on the palm and finger roots. Bots show this close up.
1. passes: AEG hip, both looks (ha1-round3-hip.jpg NOW and ha1-final-bare-before-now.jpg): only the thumb shows. Sniper right hand (ha1-round3-sniper-hand.jpg): pad in the guard on the trigger, three fingers round the wrist. Palm arc gone, nails thin to the root (ha1-round3-palm-thumb.jpg). Thumb: 0.689 vs 0.710 (-2.9 %), seven older ratios within 7.7 %. Near side, foregrips and pistols unchanged as ruled.
Non-blocking notes (check 7 still passes): tests/unit/test_ha1_rifle_hold.gd:23-28, the new FINGERS doc was inserted under END_PLACE's doc line ("How near (m) a reload's last frame..."), so END_PLACE lost its doc and FINGERS carries a wrong first line; :127-128 `_finger_points` doc says "those on the replica's far side" but it returns every left finger point (`_far_side` filters).
Must-fix for the next attempt:
- AEG (GUARD): every far-side fingertip, little finger included, behind the handguard's front end by at least 5 mm; add that to the eye test or a sibling (tip z against the handguard's front in replica space) for AEG, Sniper, SMG, so the record's claim is tested.
- Far-side fingers on AEG, Sniper and SMG: closed together (no daylight between neighbours from the far side), slightly curled along the side face with pads on its lower half, no finger hooked back (SMG index) and no pinch (Sniper). Raise the palm's far edge to touch the underside if the eye check and the approved near-side thumb allow it; if the palm can't move, say so in the record and keep the fingers' line instead. Keep the eye test at 0 points.
- Re-render "FROM THE FAR SIDE" for all three from a side-on camera and the 3/4 below camera a bot is seen from.
- Fix the two doc comments above.
Owner should test in the game (at most 6, one line each):
- AEG, Sniper, SMG at the hip, gloves and bare: any left fingertip on the right of the replica while walking, firing and turning?
- Stand beside a bot with an AEG and a Sniper: do its left fingers read as holding the handguard?
- Sniper, work the bolt at the hip: the right glove fills the top-right quarter of the screen; acceptable?
- Raise and lower the sight fast on each rifle: any pop or flash of the left hand?
- Pistols at 25 cm, walking and firing: do the bob, flick and roll feel good and not seasick?
- Bare hands at 1440p: nails, tendons and skin as you approved them ("Perfect")?
