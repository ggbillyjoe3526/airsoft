Task: FT1 (none in TASKS.md) · QA commit 08e5026 · Verdict: Pass

Blocking: none.
Advisory:
- docs/records/FT1.md:36 names the thicket colour #183327; game/config/map_style.gd:98 is Color8(0x18,0x33,0x28), which is what spruce.py's UNDER (forest #2b5c48 x 0.55) rounds to. The record has the typo, the code is right.
- The model band's section is 24.5 x 10 m against treeline_section 20 x 5 (already noted in the record); sections overlap, harmless.

Tests added (tests/unit/test_ft1_qa.gd, 15 tests). Each reads a field or signature that is not on 4dda616 (haze, grid_spread, specular, treeline_fade, the 0.2/0.3/colour values), so it fails there; I did not run it on a checkout of the base.
- test_ft1_qa.gd:34 · treeline cones carry haze = treeline_fade, hill pieces 1.0 · haze is new
- :46 · a treeline vertex at 300 m fades treeline_fade x as far as the same vertex at haze 1 (measured in linear light) · without the factor the ratio is 1
- :58 · treeline_fade 0 keeps the colour at 500 m · fails if the fade ignores haze
- :65 · SkylineModels band Placed.haze = treeline_fade (pending if the glb won't load)
- :77 · treeline_colours are greens, not near-black · old values failed g > 0.3
- :83 · skyline specular config is 0; LookMaterials default sets no override and the shader default is 0.5 (this last part needs a renderer, so it shows Pending headless)
- :94 · built SkylineView material's specular parameter equals cfg.specular (0)
- :115-:230 · spread 1 reproduces the old cell formula (along_x and not, n>1); spread 1.8/1.5 keeps every model inside the box, end models flush on all four sides, neighbours overlap; n.x = n.z = 1 and spread 0.5/10/50 never leave the box; only spruce is spread (crate, camo_net, cordwood not)
- :240-:275 · spruce core height 0.2, CORE_SHARE 0.3, thicket colour = forest x 0.55; core_box is a fifth tall and inset at most 0.3 of the width; touching thickets' cores still meet

Bug hunt: no bug found in the diff. Checked division by zero (n = 1 gives pitch 0), huge and sub-1 spreads, the rotated (along z) box, camo_net/crate/cordwood untouched (no grid_spread entry, default Vector2.ONE).
Not covered: variants (picks > 1) share the first model's footprint, as before; no test.

Runs (raw output in pipeline/out/qa/): test_ft1_qa 15 tests, 14 pass, 1 pending, 0.8 s · test_props 19/19, 7 s · test_wr3_qa 7/7, 18 s · test_skyline 20/20, 3 s.
tools/check.sh: changelog notes and wiki checks pass; gdlint is not installed here (CI runs it); the full GUT run took over 20 min and I stopped it, so the full suite and the smoke test were not completed here. CI needs to confirm them.

Needs a display or the owner: whether the distant treelines now read green in the sun (and the thicket no longer shows a block) by eye on Woodland, and the shader's 0.5 default.
