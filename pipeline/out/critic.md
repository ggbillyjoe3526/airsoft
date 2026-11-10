Task: FT1 · Woodland's treelines green and its thickets without plain blocks (owner report 2026-11-10, no task block)
Attempt: 4 of 4
Head: 5e7e3c8 (checks passed on it: gdlint clean, GUT 8 files 114 tests, 113 pass, 1 pending; full check.sh left to CI)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept
Evidence (my own measures on the after panels of the sheets, 800x450 halves, sky with hue 180-252 and sat >0.3 left out):
1. Panel 1 (sheet x 800-1600, y 76-171 = full-res 0-1600 x 0-190): High hue 114, sat 0.39, 0.49 % under value 0.12;
   Low hue 122, sat 0.35, 0 %. Panel 2 (sheet x 1300-1368, y 702-767 = full-res 1000-1135 x 280-410): High hue 125,
   sat 0.33; Low hue 127, sat 0.31. Both attempt-3 targets met; the record's numbers agree. The cause is isolated
   (SSIL, FT1.md:+27) and fixed at the model's own shade (far_tree.py:+63 BAND_SHADE 0.95, used at :97), not by
   exempting one material from a global effect. White tops and thicket blocks stay fixed (panels 3, 4 both presets).
2. No contract touched in this commit: colours in skyline_config.gd:+147 and a rebuilt glb (192 triangles as before).
3. No runtime code in this commit; performance's d946192 pass covers the rest (build-time alpha write only).
4. test_ft1_qa's greens test (g > 0.3, not near-black) still fails on the old #1c3024 greens; the new ones pass it.
5-7. Data only (PackedColorArray export, a build-script constant); comments state why.
8. Scope held to the owner's report.
Advisory (no check failed):
- The far band is now more saturated and lighter than the field's spruces in front of it (High panels 3 and 4,
  upper right): aerial perspective runs backwards. If the owner calls it too bright, pull treeline_fade or the greens'
  value down a step; the 0.30 floor leaves little room for saturation.
- Up close at the east fence the band's facets are large and flat (panel 1): it is far scenery, acceptable, but the
  owner sees it every round from that spawn side.
- Low panel 3 still shows a dark slab at a thicket's foot (core box, sheet x ~1180-1290, y ~1460-1490).
- No changelog.d note or docs/wiki change in the diff: the records step must add the note before merge.
Must-fix for the next attempt: none.
Owner should test in the game (at most 6, one line each):
- Woodland on High at the east fence, look up: green treeline, no black facets?
- Same on Low, then across the woods to the west: green, not grey or olive?
- Does the far treeline sit in the same forest as the spruces in front, or read too bright and minty?
- Spruce thickets at the Sawmill and culvert in full sun: any pale tip, flat box, or dark slab at the foot on Low?
- Shoot into a thicket at chest height and at its edges: BBs stop as before.
- F3 on Low close to a thicket: FPS against main.
