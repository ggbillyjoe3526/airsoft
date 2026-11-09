Task: SL1 · QA commit (see git log, "Agent: qa") · Verdict: Pass

Reviewed against e8aada2.

Blocking: none. Advisory: none.

Checks
- project.godot shader_globals vs LookConfig.globals(): all 8 keys incl. look_paint_saturation match; already pinned by test_look.gd test_the_lights_values_are_the_projects_global_uniforms (iterates globals(), so the new key is covered).
- Team colours: flag_cloth.gdshader neither includes look_light nor calls look_paint; figures/flag use team_colour outside the look shaders.
- Night: night_lighting.tres keeps sun 0.18, ambient 0.3, exposure 1.2; only the day defaults in lighting_config.gd changed.
- 20 degree team-hue rule: test_no_palette_colour_reads_as_a_team iterates the whole palette, so `grass` is covered (and now explicitly).
- Note: MapStyle keeps literal Color8(0x5f,0x8a,0x3a) for ground and GRASS terrain, not a palette lookup; the new test pins them equal so they cannot drift.

Tests added (tests/unit/test_look.gd from line 307)
- test_grass_is_its_own_palette_colour_and_not_a_team_hue · palette has grass, differs from meadow, off team hues · fails on e8aada2's parent (no grass key / meadow = grass).
- test_the_map_style_ground_and_grass_terrain_are_the_palettes_grass · MapStyle ground and GRASS terrain equal palette grass · fails if either reverts to 8aa860.
- test_the_night_preset_keeps_its_own_light · night_lighting.tres values and differs from day sun · fails if night inherited the day retune.
- test_team_cloth_is_not_muted_by_the_paint_grade · flag cloth shader free of look_paint/look_light · fails if paint grade is routed into team cloth.

Runs (one file at a time, raw output in pipeline/out/qa/)
- test_look.gd 21/21 (244 asserts, 1.2 s); test_dh1_hall_shell.gd 9/9; test_dp2_qa.gd 9/9.
- Not run (per brief): tools/check.sh, full suite, smoke test.

Not testable headless: how the 0.6 paint saturation, sun 2.0 / ambient 0.55 / exposure 0.9 look on screen (owner to eyeball Depot, Range, Woodland, The Street, a night map; confirm meadow-floored Street reads right and team colours on figures/flags are unmuted).
