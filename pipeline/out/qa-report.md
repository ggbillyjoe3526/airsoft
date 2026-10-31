Task: WA1 · QA commit 7310ead (worktree also carries uncommitted post-critic edits: litter/LEAVES colour, ART.md, README) · Verdict: Pass

Blocking: none.
Advisory:
- tests/unit/test_baked_light.gd:75 only checks maps whose json names a bake; test_wa1_qa now checks every .res in assets/maps/bakes against its map (depot and range both fresh).
- The headless runs use the dummy renderer, so shader errors do not show there. I compiled look_vertex (srgb on and off) and look_clear under xvfb + llvmpipe Vulkan: no shader errors.
- Not checked (needs a display): that the meadow/greybox look right, puddle blending over the slope, and Low-preset frame time.

Checked and found fine: MapLevel greybox, sloping-ground tiles and shadow caster all take the srgb ShaderMaterial; the baked vertex tint path (linear_to_srgb) still matches the sRGB flag; no stale grid_size/grid_shade/uv1_* references; puddles still prewarmed via WoodsView.materials(), bushes via BushView.materials(); no code casts these materials to StandardMaterial3D; Woodland map json differs only in moss colour.

Tests added (tests/unit/test_wa1_qa.gd, uncommitted):
- :9 · vertex_colour default stays linear, flag sets srgb_colours · fails on main (no param)
- :15 · clear_colour shader, roughness, priority MIN, alpha · fails on main (no clear_colour)
- :22 · MapStyle has no grid_size/grid_shade · fails on main (properties exist)
- :27 · built Woodland level: every mesh (greybox, ground tiles) is look_vertex with srgb on · fails on main (StandardMaterial3D)
- :48 · every bake in assets/maps/bakes matches its map's hash · fails with the old bakes after the repaint
- :71 · 3x build/free of MapLevel + WoodsView + BushView leaves node count unchanged · leak guard (passes on both)

Runs: test_look 16/16, test_woods_view(+qa) 30/30, test_bushes(+qa) 54/54, test_props 17, test_baked_light 12, test_dd1_qa 23, test_dp2_qa 9, test_map_level 15, test_terrain 30, plus colour_vision, wl1/wl2/wl9/wr2/wr3_qa, site_dress, minimap, range, assets, night_light, woodland_layout, skyline and others (21 more files): all pass. test_wa1_qa 6/6. tools/smoke_test.sh PASS (0 script errors). gdlint clean on touched files. Full suite and tools/check.sh not run here (CI runs them).
Logs: pipeline/out/qa/*.log
