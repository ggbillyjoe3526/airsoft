Task: FT1 · Woodland's treelines green and its thickets without plain blocks (owner report 2026-11-10, no task block)
Attempt: 2 of 4
Head: afe9648 (checks passed on it: gdlint on touched files, GUT test_ft1_qa/test_props/test_wr3_qa/test_skyline 61 pass 1 pending; full check.sh left to CI)
Checks: 1 ✗ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 7/8 → Retry (near miss, judgment)
Failed checks, with evidence (file:line, one or two lines each, each marked measured or judgment):
1. [judgment, with pixel numbers] Half of attempt 1's must-fix is met: the field spruces' tips are green on both presets
   (prop_dress_config.gd:+348 spruce wear 0; 1-high and 2-low panels 3-4 after, no pale tops), the cause is recorded
   (FT1.md:+22) and the blocks are gone. The treeline is still not green. skyline_config.gd:+147 sets greens of
   saturation ~0.5 (hue ~150), but on screen the band reads grey: panel 1 after (fence) averages hue 73-86 (olive),
   saturation 0.15-0.20; panel 2 after (across the woods) 0.14 on High and 0.09 on Low (before: 0.07 and 0.03).
   Raising the input colours moved the result a little; something after them (the shared light in
   look_light.gdshaderinc, the model's own shade, or the Sunlit Concrete grade) strips the colour, and the record says
   so itself (FT1.md:+33 "still read olive-grey at the fence") without finding that term. Panel 1 still shows the
   near-black faces asked about in attempt 1. "They should have colour" is not met for the treeline the owner named.
Advisory (no check failed):
- High panel 3 after: the thicket's lower half is near-black (value ~0.06). That is the canopy's shadow, but check it reads as spruce.
- Low panel 3 after: the dark core still shows as a slab at the thicket's foot (documented in KNOWN_ISSUES).
- No changelog.d note or wiki row in the diff yet. Add them at the records step.
Must-fix for the next attempt:
- Find where the treeline's saturation is lost. Read one band vertex's colour from config to vertex (skyline_view.gd:262)
  to the lit pixel, and fix that step (shade term, ambient, or exempt the band from the grade), rather than raising the
  input greens again. Target: the band at the fence and across the woods reads green, saturation >= 0.3 with a green hue
  (about 100-160) in panels 1 and 2 on both presets, with no near-black facets in panel 1. Render the same panels again.
- Record the cause in docs/records/FT1.md.
Owner should test in the game (at most 6, one line each):
- Woodland on Low, then on High: across the map, do the far treelines read green or grey?
- Stand at each fence and look up at the treeline: green, or olive-grey with black facets?
- Look across at the spruce thickets and far rows in full sun: any tip still pale or white?
- Walk round the Sawmill and culvert thickets: any flat box, or the dark slab at the foot on Low?
- Shoot into a thicket at chest height and at its edges: BBs stop as before.
- F3 on Low close to a thicket: FPS against main (the spruces overlap more now).
