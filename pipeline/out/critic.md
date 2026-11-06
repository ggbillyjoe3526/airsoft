Task: CZ1 · The Cyber Pistol at the GBB Pistol's size (owner request, no task block)
Attempt: 2 of 4
Head: 4418577 (verdict holds only if the tools/check.sh rerun on 4418577 passes; QA Pass on f1685e8, performance Pass on f1685e8)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✗
Score: 7/8 → Accept
Ratios vs the GBB (bpy on 4418577's glb): length 206/204 (+1 %); height 152/140 (+8.6 %); half width where the thumb goes, z -30..+30: 13.3-14.4/12.9-14.2 (≤ 3 %); grip depth 54-59/58-61 (-5 %); bore 10.8/10.5 (+3 %); trigger reach at z -25: 73.6/68.3 mm (+7.8 %, now described honestly). All within 10 %.
1. Torch fixed: my overlap test now finds 0 face pairs against Body, Magazine and Trigger (242 before). In the side and under renders the torch's back end clears the guard, which is shorter in front (cyber.py:158-160) and still reads as BL6's. attachments.py:1152-1157 stops the build if a CLEAR_OF_BODY part touches the body, so this can't come back silently. The sights (cz1/5, test_cyber_sights.gd) and the resize meet the ask. The look is kept, round parts stay round and the normals are right.
4. test_cyber_sights.gd fails on 0283c69, and the selector expectations (test_cyber_pistol.gd:114-115, test_cp1_qa.gd:242) follow the length scale ×0.89.
5. The scales are now named (GBB_FRAME_HW / FRAME_HW, cyber.py:90-91, 103-104).
Failed checks, with evidence:
8. [judgment] Two leftovers:
- cyber.py:153 still says the trigger moved "to the GBB's reach from the back strap". The changelog, ASSETS and the record now correctly say it isn't (73.6 vs 68.3).
- cyber.py:179 is 138 characters, past the house's 120.
Must-fix (fold into this PR or the next one): reword cyber.py:153 ("nearer the grip, 5 mm longer reach than the GBB's") and wrap cyber.py:179.
Owner should test in the game:
- Fit the Weapon Torch and look along it from the side and from under: there should be a gap at the guard.
- Aim: the post and its cyan dot stand in the notch with light on both sides.
- Once the arms hold (#204) is refitted, the thumb lies on the frame and rear block without sinking in. Say whether the trigger finger feels stretched compared with the GBB (the reach is 5 mm longer).
- Next to the GBB in the Armory: same size, still the Cyber's look.
