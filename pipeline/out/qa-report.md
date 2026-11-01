Task: FM2 (none; owner playtest 2026-11-01) · QA commit see git log (on top of 0dc04a8) · Verdict: Pass

Blocking: none. The first run's stale test (test_mm3_qa) is fixed and passes.

Advisory (none blocks)
- game/ui/minimap_field.gd (build, ground_rect): the picture is cols/step samples, so a terrain whose columns do not
  divide by the sample step stops up to one sample (relief_cell, 1 m) short of the terrain's far edge, and a terrain
  smaller than one sample (1x1 image) overshoots it by up to step-1 squares. Woodland divides evenly (352x240, step 2) and
  no real map is tiny, so nothing shows today; test_the_ground_picture_covers_the_terrain_to_within_one_sample pins the
  one-sample bound.

Re-run on 0dc04a8 (single files, raw output in pipeline/out/qa/): test_fm2_qa 35/35, test_fm2_field_map 12, test_fm1_field_map 15,
test_fm1_qa 21, test_mm3_qa 14, test_minimap_field 11, test_hud_minimap 17, test_bushes 38, test_two_flags 18,
test_ping_markers 22, test_pn2_qa 8, test_hud_size 12, test_dp4_qa 7, test_minimap_hearing 11, test_mm2_qa 9,
test_mm4_qa 16: all pass. gdlint on test_fm2_qa.gd clean. tools/check.sh and the full suite not run (run elsewhere).

Tests added (tests/unit/test_fm2_qa.gd, 10 new, 35 total, 13467 asserts, 12 s). Checked by temporarily stubbing the
feature in game/ (reverted, nothing under game/ committed): zone word taken as the first try with no clearing, the
storey wash removed, ground_of returning null.
- :486 zone words stay on the field and clear of every zone box, flag, compass, name and each other on 3 maps x 3 screen
  sizes · fails with the clearing stubbed (words over zone boxes, off the field)
- :520 zone boxes clipped to the field; a zone with no box has no word
- :532 first_clear: first clear try, slid inside the bounds, gap across vs down, none when boxed in or no tries
- :548 lay_out: zero-size want left out, Vector2 gap kept across and down
- :572 Woodland: ground picture inside the layer, layer clear over most of it, full map and minimap Views hold the texture
  · fails with ground_of stubbed to null
- :598 Depot and The Street (no terrain) and an empty map: no ground image, rect or texture, Views draw none
- :611 Tower Block with terrain: street storey clear, storeys above washed with below_storey_colour · fails with the wash removed
- :625 tiny terrains (1x1 cell, 3x2, odd 21x19): picture non-empty and drawn, a View built on it draws · fails with ground_of null
- :650 ground picture within one sample of the terrain's far edges (odd column count)
- :664 repeated build/ground_of leaves no growth and the image stays readable after mipmaps

Not testable headless: how the GPU-smoothed ground looks, whether names and zone words read well on a real window
(owner's list: open M on Woodland at 1920x1080 and 1280x720 and look at the ground blend, words and the key's flag glyph).
