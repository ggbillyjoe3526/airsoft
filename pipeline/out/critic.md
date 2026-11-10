Task: FT1 · Woodland's treelines green and its thickets without plain blocks (owner report 2026-11-10, no task block)
Attempt: 1 of 4
Head: 766afe7 (checks passed on it)
Checks: 1 ✗ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 7/8 → Retry (near miss, judgment)
Failed checks, with evidence (file:line, one or two lines each, each marked measured or judgment):
1. [judgment] "White trees in the distance" is only half fixed. The skyline band is no longer white (skyline_config.gd:16
   treeline_fade, :22 specular, :146 colours), and the thicket blocks are gone (prop_dress_config.gd:248 core 0.2,
   :226 grid_spread). But the field's own spruces still read white: in 2-low-before-after.jpg panels 3 and 4 (after)
   every thicket spruce's upper half is pale beige-white, and the far spruce rows behind the bank in panel 4 have
   white spires on High too (1-high, panel 4 after). Those are distant models with white trees, which is the owner's
   wording. The record (docs/records/FT1.md, What was wrong) puts "white trees" down to the skyline alone and never
   looks at the spruce model. The likely cause: spruce.py:32 TOP = spruce x 1.12 mixed with sage, lit by the full sun
   with no shadow on Low, plus the props' distance haze.
   Also: from the fence (panel 1 after, both presets) the band reads olive-grey with near-black faces, not green. Its
   huge flat facets look like crumpled card at 9 m, not spruce. Muted fits Sunlit Concrete, but grey-black doesn't
   answer "they should have colour".
Advisory (no check failed):
- prop_dress_config.gd:244 and skyline_models.gd:173 have comment lines over the house width (gdlint passed).
- QA's advisory about the record colour is fixed (FT1.md says #183328, matching map_style.gd:98).
- On Low the dark core shows at the thicket's foot as a black slab (2-low panel 3 after). It is documented in
  KNOWN_ISSUES. Check whether CORE_SHARE or a lower height would hide it.
Must-fix for the next attempt:
- Find out why the field spruces' tops render pale. Measure spruce TOP's linear albedo against forest_colours, and the
  props' fade or fog at 30 to 80 m. Fix the cause (darker or greener TOP in spruce.py and a rebuilt .glb, or less
  haze on props). The tips should read lighter green, never white, on Low and High. Render the same four panels again.
- Make the treeline band seen from the fence read green, not grey-black. Raise the band's greens or its ambient, or
  cut the near-black faces (normals or the shade term), and show panel 1 again.
- Update the record's causes to cover the spruce tops.
Owner should test in the game (at most 6, one line each):
- Woodland on Low, then on High: look across the map at the spruce thickets and the far rows. Do any tips read white?
- Stand at each fence and look up at the treeline: green, or grey with black facets?
- Walk round the Sawmill and culvert thickets: any flat box, or the dark slab at the foot on Low?
- Shoot into a thicket at chest height and at its edges: BBs stop as before.
- F3 on Low close to a thicket: FPS against main (the spruces overlap more now).
