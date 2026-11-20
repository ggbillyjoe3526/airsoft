extends GutTest
## Volumetric haze: four levels in VF1 (Off, Low, Medium, High), one switch again in UB3 (owner, 2026-11-20: the levels
## looked the same). The presets' choice, the grid and filter On sends, the switch on the field, old saves' levels and
## "on", and the Graphics tab's switch.

const ROOT := "user://test-vf1-haze"
const FOG := GraphicsQuality.VOLUMETRIC_FOG
const OFF := GraphicsQuality.VolumetricFog.OFF
const ON := GraphicsQuality.VolumetricFog.ON

var table: GraphicsTable = null
var look: LookConfig = PlayTuning.load_default().look


func before_each() -> void:
	table = GraphicsTable.shared()
	DirAccess.make_dir_recursive_absolute(ROOT)


func after_all() -> void:
	for f: String in DirAccess.get_files_at(ROOT):
		DirAccess.remove_absolute(ROOT.path_join(f))
	DirAccess.remove_absolute(ROOT)


func test_the_row_is_off_or_on_and_the_file_reads_cleanly() -> void:
	assert_eq(table.row(FOG).choices, PackedStringArray(["off", "on"]))
	assert_eq(table.problems.size(), 0, "graphics.md reads without a problem: %s" % [table.problems])


func test_high_and_ultra_draw_the_haze_and_low_and_medium_none() -> void:
	var want: Array[GraphicsQuality.VolumetricFog] = [OFF, OFF, ON, ON]
	for i in GraphicsTable.PRESETS.size():
		assert_eq(table.preset(GraphicsTable.PRESETS[i]).volumetric_fog, want[i], String(GraphicsTable.PRESETS[i]))


func test_the_built_in_row_matches_the_file() -> void:
	var built := GraphicsTable.parse("")
	for p in GraphicsTable.PRESETS:
		assert_eq(built.preset(p).volumetric_fog, table.preset(p).volumetric_fog, String(p))
	assert_eq(built.row(FOG).choices, table.row(FOG).choices)


func test_on_draws_vf1s_high_haze() -> void:
	assert_eq(look.fog_grid, Vector2i(128, 128), "High's grid")
	assert_true(look.fog_filtered, "smoothed")
	assert_almost_eq(look.fog_length, 80.0, 0.001, "High's reach")


func test_the_switch_turns_the_haze_on_and_off_and_on_sends_its_grid_and_filter() -> void:
	var lighting := FieldLighting.build(LightingConfig.new(), look)
	add_child_autofree(lighting)
	var rs := GraphicsApply.Server.new()
	var values := table.preset(&"ultra")
	values.volumetric_fog = ON
	GraphicsApply.apply_field(values, lighting, null, rs)
	assert_true(lighting.environment.volumetric_fog_enabled, "On draws the haze")
	assert_eq(rs.fog_grid, look.fog_grid)
	assert_eq(rs.fog_filter, look.fog_filtered)
	assert_almost_eq(lighting.environment.volumetric_fog_length, look.fog_length, 0.001)
	values.volumetric_fog = OFF
	GraphicsApply.apply_field(values, lighting, null, rs)
	assert_false(lighting.environment.volumetric_fog_enabled, "Off draws none")
	assert_eq(rs.fog_grid, look.fog_grid, "Off sends no grid")


func test_a_custom_switch_round_trips_by_name() -> void:
	for level: GraphicsQuality.VolumetricFog in [OFF, ON]:
		for base: StringName in [&"medium", &"high"]:
			var q := table.preset(base)
			q.volumetric_fog = level
			var over := GraphicsQuality.overrides(q, base, table)
			if level != table.preset(base).volumetric_fog:
				assert_eq(over.get("volumetric_fog"), GraphicsQuality.CHOICES[FOG][level])
			assert_eq(GraphicsQuality.resolve(GraphicsQuality.CUSTOM, base, over, table).volumetric_fog, level)


func test_an_old_saves_levels_and_on_become_on_and_off_stays_off() -> void:
	var cases: Array = [[3, "on", ON], [3, "off", OFF], [4, "low", ON], [5, "medium", ON], [6, "high", ON],
			[6, "off", OFF]]
	for c: Array in cases:
		var path := ROOT.path_join("v%d-%s.save" % [c[0], c[1]])
		var old := {"graphics_choice": "custom", "graphics_base": "medium",
				"graphics_custom": {"volumetric_fog": c[1], "glow": "off"}}
		assert_true(SaveFile.write(path, Settings.KIND, c[0], old))
		var s := Settings.new(PlayTuning.new())
		s.load_file(path)
		assert_eq(s.graphics_custom.get("volumetric_fog"), GraphicsQuality.CHOICES[FOG][c[2]], "v%d %s" % [c[0], c[1]])
		assert_eq(s.graphics_custom.get("glow"), "off", "the other rows are kept")
		var q := GraphicsQuality.resolve(s.graphics_choice, s.graphics_base, s.graphics_custom, table)
		assert_eq(q.volumetric_fog, c[2], "v%d %s draws" % [c[0], c[1]])


func test_a_current_saves_switch_is_not_moved() -> void:
	for value: String in ["on", "off"]:
		var data := {"graphics_custom": {"volumetric_fog": value}}
		assert_eq(Settings.migrate_defaults(data, Settings.VERSION), data, "only an old file is moved")


func test_a_version_six_files_hud_choices_are_not_moved_again() -> void:
	# Version 6 already moved the gauge patterns and the HUD opacity: a player who set them back since keeps them.
	var data := {"gauge_patterns": true, "hud": {"panel_opacity": 1.0}, "graphics_custom": {"volumetric_fog": "high"}}
	var moved := Settings.migrate_defaults(data, 6)
	assert_eq(moved["gauge_patterns"], true)
	assert_eq((moved["hud"] as Dictionary)["panel_opacity"], 1.0)
	assert_eq((moved["graphics_custom"] as Dictionary)["volumetric_fog"], "on")
	assert_eq((data["graphics_custom"] as Dictionary)["volumetric_fog"], "high", "the input is not changed")


func test_a_corrupt_old_custom_row_is_left_for_the_reader_to_drop() -> void:
	for bad: Variant in [1, true, null, [], {}, "ON", "HIGH", "extreme"]:
		var moved := Settings.migrate_defaults({"graphics_custom": {"volumetric_fog": bad}}, 3)
		assert_eq((moved["graphics_custom"] as Dictionary)["volumetric_fog"], bad, "%s untouched" % [bad])
	assert_eq(Settings.migrate_defaults({"graphics_custom": "x"}, 6), {"graphics_custom": "x"})
	assert_eq(Settings.migrate_defaults({}, 6), {})


func test_a_version_three_files_own_volumes_are_not_moved_by_the_haze_step() -> void:
	# Volumes the player set (none on an old default, no Power source, which FV1 rescales) come through as they were.
	var data := {"volumes": {"Master": 0.6, "Effects": 0.5, "Ambience": 0.3, "Interface": 0.1}}
	var moved := Settings.migrate_defaults(data, 3)
	assert_eq(moved["volumes"], data["volumes"], "only the haze row and FV1's old defaults move")


func test_only_forward_plus_draws_the_haze() -> void:
	assert_false(table.can_draw(FOG, ON, "gl_compatibility"))
	assert_false(table.can_draw(FOG, ON, "mobile"))
	assert_true(table.can_draw(FOG, ON, "forward_plus"))


# --- QA: the Graphics tab's switch, and what an old or odd save leaves ---

func _page_on(settings: Settings, method: String = "forward_plus") -> SettingsGraphicsPage:
	var screen := SettingsScreen.new()
	screen.settings = settings
	screen.save_path = ROOT.path_join("settings.save")
	add_child_autofree(screen)
	screen.open()
	var page := screen._graphics_page
	page.probe = GraphicsPick.Probe.new()
	page.probe.preset = &"high"
	page.probe.rendering_method = method
	page.probe.driver = "vulkan"
	page.build(screen)
	page.refresh()
	return page


func test_the_haze_row_is_a_switch_and_flipping_it_is_custom() -> void:
	var drawn_before := GraphicsApply.server().drawn
	var s := Settings.new(PlayTuning.new())
	var page := _page_on(s)
	var line := page.line(FOG)
	assert_null(line.choice, "a switch, not a row of choices")
	assert_not_null(line.check)
	var base := GraphicsQuality.resolve(s.graphics_choice, s.graphics_base, s.graphics_custom, table).volumetric_fog
	line.check.button_pressed = base == OFF
	var now := GraphicsQuality.resolve(s.graphics_choice, s.graphics_base, s.graphics_custom, table).volumetric_fog
	assert_ne(now, base, "flipped")
	assert_true(line.marked(), "a changed row is marked")
	page.reset_button().pressed.emit()
	assert_false(line.marked())
	assert_true(s.graphics_custom.is_empty(), "back to the card's pick")
	GraphicsApply.server().drawn = drawn_before


func test_the_simpler_renderer_greys_the_haze_switch() -> void:
	var page := _page_on(Settings.new(PlayTuning.new()), "gl_compatibility")
	var line := page.line(FOG)
	assert_true(line.shut)
	assert_true(line.check.disabled)


func test_a_corrupt_saved_haze_value_falls_back_to_the_presets_level() -> void:
	for bad: Variant in ["extreme", "", 2, true, null, ["high"], "ON"]:
		var q := GraphicsQuality.resolve(GraphicsQuality.CUSTOM, &"medium", {"volumetric_fog": bad}, table)
		assert_eq(q.volumetric_fog, table.preset(&"medium").volumetric_fog, "%s" % [bad])


func test_a_version_six_store_in_a_save_bundle_restores_its_level_as_on() -> void:
	var s := Settings.new(PlayTuning.new())
	var d := {"graphics_choice": "custom", "graphics_base": "low", "graphics_custom": {"volumetric_fog": "medium"}}
	var moved := Settings.migrate_defaults(d, 6)
	s.from_dict(moved)
	var q := GraphicsQuality.resolve(s.graphics_choice, s.graphics_base, s.graphics_custom, table)
	assert_eq(q.volumetric_fog, ON)
	assert_eq((d["graphics_custom"] as Dictionary)["volumetric_fog"], "medium", "the input is not changed")


func test_the_servers_first_filter_is_the_projects() -> void:
	var rs := GraphicsApply.Server.new()
	var project: bool = (ProjectSettings.get_setting(GraphicsApply.FOG_FILTER) as int) != 0
	assert_eq(rs.fog_filter, project)
	assert_eq(rs.fog_grid, Vector2i.ZERO)
	rs.set_fog_quality(look.fog_grid, look.fog_filtered)
	assert_eq(rs.fog_filter, look.fog_filtered)
	assert_eq(rs.fog_grid, look.fog_grid)
