Task: BL6 · The Cyber Pistol rebuilt in Blender from code (no task block; judged against the brief)
Attempt: 2 of 4
Head: 229bd55 (git rev-parse HEAD). CI passed on e11a317. At 229bd55, Lint, Review line, Callout guards and two match guards are green; unit tests 1-4 and 13 guard jobs are still running.
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept (holds only once every CI job at 229bd55 is green; any red job makes it Retry)
Evidence:
1. Figure fixed: tools/blender/replicas/cyber.py:750-754 builds the outline from GUARD_LOOP[:5] (cyber.py:133). (50.5,-23) is gone.
   - No edge pair of the 13-point outline crosses. Its area is 11,468.5 mm2, and both caps in the glb have that same area.
   - Rasterised at 0.25 mm, both caps have 0 overlapping cells (e11a317: 755 and 8,410 cells, up to 3 deep).
   - The Figure is 240 tris, closed (360 edges each used twice) and has no degenerate faces. Its guard front stands at 52 mm, as on the hands model.
   - Against e11a317, only the Figure mesh changed. Body, Slide, Trigger, Selector and Magazine are byte-identical, as are nodes, skins, materials, the animation data and the inverse bind matrices. So the attempt-1 ratios still hold (all within 5 %; the grip's 23 % is ruled by the owner).
   - The renders cyber-v11-q_front and cyber-v11-q_rear at head show the moved guard joined to the front block's foot. Nothing floats, no gap opens under the loop, and the teeth sit clear in front of it.
2. No game/ diff. The trigger bone, its inverse bind matrix and its keys moved together (QA: -0.012 in y, nothing else). No code calls find_bone on the trigger.
3/5. No runtime code: cyber.py is an offline tool.
4. Asset only. test_cp1_qa.gd:294-306 loads the Figure and its materials, and the material names are unchanged.
6. Original design: no text, no logos, no brand names. Toy colours, ruled by the owner.
7. figure() is still one short function, and the outline now comes from the shared constant instead of a second copy.
8. docs/records/BL6.md fixes everything attempt 1 named:
   - :17-18 records the 23 % deeper grip.
   - The "safety blade" is gone.
   - :30-31 records the trigger bone's move.
   - :55 records the owner's 09:52 "Perfect".
   - :10 adds the attempts row.
QA (qa-report.md, 229bd55): Pass. Performance (performance-report.md, e7725d6): Pass. It still holds, because the hands' triangles are unchanged and the Figure's count stays 240.
Nit, not failed: the record (:37) gives 31,330 triangles for the hands. The glb has 31,328 (24,480 + 3,108 + 2,760 + 544 + 436). Fix it the next time the record is touched.
Must-fix for the next attempt: none. Merge only after every CI job at 229bd55 is green.
Owner should test in the game:
- Grip: it is 23 % deeper than the old one (63 vs 50.5 mm). Does it look right in your hand view?
- Fire: the trigger swings from its top with no jump, and the slide kicks.
- Aim: the front post and rear notch line up as before.
- A bot carrying it, near and far: the guard front now matches your own.
- The q_front view shows a small step at the top front corner of the guard opening. Does it read as intended up close?
- Fit the torch: it should clear the teeth. Then switch to Realistic colours: grey, no glow.
