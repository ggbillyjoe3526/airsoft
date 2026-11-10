Task: FT1 · Woodland's treelines green and its thickets without plain blocks (owner report 2026-11-10, no task block)
Attempt: 3 of 4
Head: d946192 (checks passed on it: gdlint on touched files, GUT 16 files all pass, 1 pending; full check.sh left to CI)
Checks: 1 ✗ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 7/8 → Retry (near miss, measured)
Failed checks, with evidence (file:line, one or two lines each, each marked measured or judgment):
1. [measured] The cause is now found and fixed at its step (look_vertex.gdshader:+122 keep_by_alpha, skyline_view.gd:+266
   alpha = keep; recorded FT1.md:+22), and the band reads green on both presets: a real step. But the attempt-2 target
   (saturation >= 0.3, hue 100-160, no near-black facets in panel 1) is not met. My measures on the after panels, sky
   excluded: panel 1 top (y 76-175) High hue 118 sat 0.28, Low hue 133 sat 0.26; panel 2 between trunks
   (x 1310-1370) High sat 0.27, Low 0.26. The record's own numbers agree (0.29 / 0.26). Near-black: High panel 1 still
   has 5% of band pixels under value 0.12 (Low 1%); the dark facets at the top centre (x ~1130-1200) and left
   (x ~900-1000) are plainly visible. BAND_SHADE 0.75 (far_tree.py:+63) halved them on paper but not on High.
Advisory (no check failed):
- The kept band is lighter and mintier than everything else under the 0.6 pull (High panel 1, upper right): check it
  still sits in the same world as the field's spruces in front of it rather than looking pasted on.
- No changelog.d note or docs/wiki row in the diff yet; add them at the records step.
- Performance passed on 766afe7; its re-check of d946192 must be on file before merge (one uniform-bool branch in
  fragment(), build-time alpha write: I expect no cost).
Must-fix for the next attempt:
- The far side is dark only on High (5% vs 1% on Low), so the cause is a High-only term on the band's shade side
  (shadow, SSAO/SSIL or the look_shade band), not the vertex shade: find it by the same isolation renders and exempt
  or soften it for the skyline (or lift BAND_SHADE further only if the isolation points there). Target: <1% of
  panel 1 band pixels under value 0.12 on High.
- Find the last ~0.03-0.05 of saturation (treeline_fade toward the grey horizon colour, the sky ambient, or the
  skirt's grey multiply) and get the band to mean saturation >= 0.30, hue 100-160, in panels 1 and 2 on both presets.
  Render the same panels and report the measures with the crop boxes used.
Owner should test in the game (at most 6, one line each):
- Woodland on High, at the east fence, look up: green treeline with no black facets?
- Same on Low, then across the woods to the west: green, not grey or olive?
- Does the far treeline look like the same forest as the spruces in front of it, or too pale/minty?
- Spruce thickets at the Sawmill and culvert in full sun: any pale tip or flat box left, or the dark slab on Low?
- Shoot into a thicket at chest height and its edges: BBs stop as before.
- F3 on Low close to a thicket: FPS against main.
