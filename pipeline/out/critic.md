Task: BL1 · Blender batch 1: the AEG Rifle · attempt 2 · head fa46a29
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✗ → 7/8, Accept once QA and performance passed (both Pass)
1. Models: the image critic's rounds 4 to 10 against the owner's main photo; round 10 Accept, all 25 ratios within
   10 % (0.92 to 1.07); no gap, floating part, clipping or faceting in the close-ups; the arms are out of the diff.
2. The replica contract (empties, bones, five clips) kept; parts refitted by fit_parts.py.
3. sight_fold.gd's per-frame path sets cached rotations and scales; nothing allocated per frame.
4. test_parts_in_play.gd asserts both sights hidden under an optic and back without one.
6. No logos; a generic carbine; plain colours.
8. Docs said more than the build (fixed after this review): the wiki's "fold down (the AEG Rifle's are taken off)" now
   "come off"; the record's Critic cell holds this verdict; the arms' work named at its real place (project files).
Advisory: HIDDEN equals BONES, so the fold rotation no longer shows (comment now says so); the magazine curves 1.3 cm,
within the ratios, the owner to judge.
Owner to test: the carbine in first person, hip and aimed (sights lined up, nothing poking into view); red dot on and
off (both iron sights go and come back); bots' grip and support hand (known issue); every part in Customise; the
magazine's curve; frame rate at 8v8 on Low.
