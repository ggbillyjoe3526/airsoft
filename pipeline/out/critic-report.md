Task: HA1 · First-person arms and grips, made realistic
Attempt: 5 of 4 (past four, under the owner's standing ruling)
Head: 9cc3f11 (= git rev-parse HEAD; checks passed on db5afd5, and 9cc3f11 adds only pipeline/ reports)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept (QA Pass, performance Pass)
Failed checks, with evidence: none.
1. SMG far side (ha1-round5-far-side.jpg "NOW: Compact SMG, side-on", zoomed 4x): the loop is gone. The little finger rises from its knuckle, bends forward at a middle joint of about 60 degrees and lays its tip up the side face toward the bore, touching the ring finger at the tips, like the Sniper's. From below, all four lie closed side by side. Sniper: the four fingers stand side by side, tips up and a little forward, with no V of daylight and none leaning back. The near sides are unchanged, the AEG is kept as the owner ruled, and the hip view still shows only the thumb (ha1-final-hip.jpg). Residual (not a fail): on the SMG, a slit of daylight about a quarter of a finger wide shows between the ring and little fingers above the knuckles. A flexed hand, with its little finger converging, shows this too, and nobody sees it at bot distance. The record says so (HA1.md:240).
   Cause and fix read in the diff: pose.py:+914-925 `_strays` stops tighten/wrap at the row; sight.py:+63-86 `crowd` adds the tip-behind-knuckle and tip-gap terms; hold_solve.py:+406,+539,+586 clear the row per solve, so the grips' fists match attempt 4 (QA's qa5 floor test fails on the loose intermediate build).
2, 3, 5, 6. No file under game/ changed. The change is arms.glb, build tools, tests and docs. Budgets match attempt 4 (38,900/34,452 triangles, 4 materials, 6.18 MB).
4. test_ha1_qa3.gd:+75-93 asserts tip.z < knuckle.z and a 20 mm tip gap per neighbour pair on the skinned mesh. On attempt 4's model the little finger's tip lay behind its knuckle (SMG loop) and the ring-to-little tip gap was 35 to 36 mm, so it fails there, as QA confirmed. qa5 fails on the intermediate build (Ring 260, Pinky 299 degrees).
Non-blocking notes (check 7 passes):
- test_ha1_qa4.gd:2 describes the dropped approach ("with the closing passes skipped"). It should say the passes keep the row.
- test_ha1_qa4.gd:+21 `_surface_gap` measures to triangle edges, not faces. That overstates the gap, which is safe, but the name says surface.
- The SMG slit sits only in the attempt-5 entry (HA1.md:240). It belongs under Known issues left too.
- test_ha1_qa3.gd's TIP_GAP passes the SMG's middle-to-ring pair at 20.1 mm by 0.4 mm of rounding: little headroom against a re-bake.
Must-fix for the next attempt: none. Optional, in the records commit: the three notes above.
Owner should test in the game (at most 6, one line each):
- Beside a bot holding the Compact SMG: do its left fingers read as a hand wrapped on the handguard (no loop, no hole)?
- Beside a bot holding the Sniper: do the four left fingers stand together up the fore-end's side?
- Sniper and AEG with the Vertical and Angled Grips: are the fists still closed round the grip as you kept them?
- AEG, Sniper, SMG at the hip, gloves and bare: still only the left thumb while walking, firing and turning?
- Raise and lower the sight fast on each rifle: any pop of the left hand?
- Reload and bolt on the Sniper and SMG: does the left hand start and end on the handguard without a snap?
