Task: BL6 · The Cyber Pistol rebuilt in Blender from code (no task block; judged against the brief)
Attempt: 1 of 4
Head: e11a317 (checks passed on it per the brief; two match-guard jobs still running)
Checks: 1 ✗ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✗
Score: 6/8 → Retry (check 1 measured, check 8 judgment; not a near miss)
Evidence for the passes:
1a. Proportions, old glb → head glb (side silhouettes rasterised from both files): L/H 1.192→1.197 (+0.4 %), guard bottom/H 0.454→0.460 (+1.3 %), guard opening/L 0.187→0.197 (+5 %), front strap from muzzle/L 0.654→0.631 (−3.5 %), front block depth/H 0.320→0.327 (+2 %). Grip depth/L at y −80 mm is 0.222→0.273 (+23 %; photo 125621 0.247, so +11 %). The photo's L/H of 1.62 is ignored because the owner ruled to keep the old silhouette. The owner approved pictures showing the deeper grip ("I love it", "Perfect"), so I flag it rather than fail it. Hands model in v10-left and v10-trigger-close: no text or logos, the trigger joins the frame, 3.4 mm above the guard floor. A full pull swings its foot about 7 mm back and leaves 5 mm clear. 31,328 tris in the hands (brief 31,330).
2. No ARCHITECTURE contract touched (no game/ diff). Empties, names, materials and rotation keys are unchanged. The trigger bone, its inverse bind matrix and its translation keys in all four clips moved together to 0.0045. Only selector_pose.gd:27, slide_lock_pose.gd:25 and sight_fold.gd:28 call find_bone, and none reads the trigger.
3/5. No runtime code. cyber.py is an offline tool. 4. Asset only: test_cyber_pistol.gd and test_cp1_qa.gd load cyber.glb (sights, selector, Figure), the same precedent as BL3.
Failed checks, with evidence:
1. [measured] The Figure (bots' LOD) is broken: tools/blender/replicas/cyber.py:750. Its frame outline (52,−21)→(50.5,−23)→(54,−14) crosses its own edge at y 52, z −19.1, a bowtie. I rasterised the cap and found up to 4 overlapping faces along z −54..−51 mm, y −12..−40 mm (0 in the old file). The outline came in with f1f369e and did not move in e11a317, so the Figure's guard front stands at 54 mm while the hands model's stands at 42 (12 mm ahead).
8. [judgment] docs/records/BL6.md is stale at head:
   - :22 still lists "a safety blade", which f1f369e removed.
   - :28 says the bones sit "at the old heads", but the trigger's moved.
   - :16 says the "silhouette" stays, but the grip is 23 % deeper.
   - The 09:52 "Perfect" on the final pictures is not recorded.
QA and performance: performance-report.md still holds at head (tris 31,594→31,328, hands primitives 15→13, 879,740→870,916 bytes, all down). qa-report.md does not: it was run at e7725d6 and says "same local transforms", which the trigger bone and its keys broke, and it missed the Figure. It needs a short QA rerun at the new head.
Must-fix for the next attempt:
- cyber.py:750: build the Figure's frame from GUARD_LOOP/GUARD_WEB, or follow them (52,−14)…(42,−34)…(37.5,−47)…(−20,−47), and drop (50.5,−23). Rebuild and confirm 0 overlapping faces.
- Render q_front and q_rear at head: no 3/4 view shows the moved guard yet, so the claim that "no notch opens under it" has no picture.
- Fix the record's lines 16, 22 and 28 and add the 09:52 ruling.
- Targeted QA rerun on the trigger bone, the clip keys and the Figure. Merge only after the last two match guards pass.
Owner should test in the game:
- Grip: it is 23 % deeper than the old one (63 vs 50.5 mm). Does it look right in your hand view?
- Fire: the trigger swings from its top, with no jump, and the slide kicks.
- Aim: the front post and rear notch line up as before.
- A bot carrying it, near and far: the guard reads right.
- Fit the torch: it clears the teeth. Then Realistic colours: grey, no glow.
