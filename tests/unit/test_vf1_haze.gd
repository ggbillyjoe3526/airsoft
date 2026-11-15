extends GutTest
## VF1: Volumetric haze as four levels (Off, Low, Medium, High): the presets' levels, each level's grid and filter as
## sent, the switch on the field, old saves' "on", and the Graphics tab's row of four choices.

const ROOT := "user://test-vf1-haze"
const FOG := GraphicsQuality.VOLUMETRIC_FOG

var table: GraphicsTable = null
var look: LookConfig = PlayTuning.load_default().look


func before_each() -> void:
	table = GraphicsTable.shared()
	DirAccess.make_dir_recursive_absolute(ROOT)


func after_all() -> void:
	for f: String in DirAccess.get_files_at(ROOT):
		DirAccess.remove_absolute(ROOT.path_join(f))
	DirAccess.remove_absolute(ROOT)


func test_the_row_offers_four_levels_and_the_file_reads_cleanly() -> void:
	assert_eq(table.row(FOG).choices, PackedStringArray(["off", "low", "medium", "high"]))
	assert_eq(table.problems.size(), 0, "graphics.md reads without a problem: %s" % [table.problems])


func test_each_preset_takes_one_step_of_haze_and_low_draws_none() -> void:
	var want: Array[GraphicsQuality.VolumetricFog] = [GraphicsQuality.VolumetricFog.OFF,
			GraphicsQuality.VolumetricFog.LOW, GraphicsQuality.VolumetricFog.MEDIUM, GraphicsQuality.VolumetricFog.HIGH]
	for i in GraphicsTable.PRESETS.size():
		assert_eq(table.preset(GraphicsTable.PRESETS[i]).volumetric_fog, want[i], String(GraphicsTable.PRESETS[i]))


func test_the_built_in_row_matches_the_file() -> void:
	var built := GraphicsTable.parse("")
	for p in GraphicsTable.PRESETS:
		assert_eq(built.preset(p).volumetric_fog, table.preset(p).volumetric_fog, String(p))
	assert_eq(built.row(FOG).choices, table.row(FOG).choices)


func test_finer_levels_draw_more_cells_and_smooth_from_medium() -> void:
	assert_eq(look.fog_grid(GraphicsQuality.VolumetricFog.OFF), Vector2i.ZERO)
	var cells := 0
	for level: GraphicsQuality.VolumetricFog in [GraphicsQuality.VolumetricFog.LOW,
			GraphicsQuality.VolumetricFog.MEDIUM, GraphicsQuality.VolumetricFog.HIGH]:
		var grid := look.fog_grid(level)
		assert_gt(grid.x * grid.x * grid.y, cells, "level %d has more cells than the one below" % level)
		cells = grid.x * grid.x * grid.y
	assert_false(look.fog_filtered(GraphicsQuality.VolumetricFog.LOW), "Low is unsmoothed")
	assert_true(look.fog_filtered(GraphicsQuality.VolumetricFog.MEDIUM))
	assert_true(look.fog_filtered(GraphicsQuality.VolumetricFog.HIGH))
	assert_false(look.fog_filtered(GraphicsQuality.VolumetricFog.OFF))


func test_each_level_switches_the_haze_and_sends_its_grid_and_filter() -> void:
	var lighting := FieldLighting.build(LightingConfig.new(), look)
	add_child_autofree(lighting)
	var rs := GraphicsApply.Server.new()
	var values := table.preset(&"ultra")
	for level: GraphicsQuality.VolumetricFog in [GraphicsQuality.VolumetricFog.LOW,
			GraphicsQuality.VolumetricFog.HIGH, GraphicsQuality.VolumetricFog.MEDIUM]:
		values.volumetric_fog = level
		GraphicsApply.apply_field(values, lighting, null, rs)
		assert_true(lighting.environment.volumetric_fog_enabled, "level %d draws the haze" % level)
		assert_eq(rs.fog_grid, look.fog_grid(level))
		assert_eq(rs.fog_filter, look.fog_filtered(level))
	var sent := rs.fog_grid
	values.volumetric_fog = GraphicsQuality.VolumetricFog.OFF
	GraphicsApply.apply_field(values, lighting, null, rs)
	assert_false(lighting.environment.volumetric_fog_enabled, "Off draws none")
	assert_eq(rs.fog_grid, sent, "Off sends no grid")


func test_the_haze_looks_the_same_at_every_level() -> void:
	var lighting := FieldLighting.build(LightingConfig.new(), look)
	add_child_autofree(lighting)
	var env := lighting.environment
	var values := table.preset(&"ultra")
	var seen: Array = []
	for level: GraphicsQuality.VolumetricFog in [GraphicsQuality.VolumetricFog.LOW,
			GraphicsQuality.VolumetricFog.MEDIUM, GraphicsQuality.VolumetricFog.HIGH]:
		values.volumetric_fog = level
		GraphicsApply.apply_field(values, lighting, null, GraphicsApply.Server.new())
		seen.append([env.volumetric_fog_density, env.volumetric_fog_length, env.volumetric_fog_albedo,
				env.volumetric_fog_anisotropy])
	assert_eq(seen[0], seen[1])
	assert_eq(seen[1], seen[2])


func test_a_custom_level_round_trips_by_name() -> void:
	for level: GraphicsQuality.VolumetricFog in [GraphicsQuality.VolumetricFog.OFF,
			GraphicsQuality.VolumetricFog.LOW, GraphicsQuality.VolumetricFog.HIGH]:
		var q := table.preset(&"high")
		q.volumetric_fog = level
		var over := GraphicsQuality.overrides(q, &"high", table)
		assert_eq(over.get("volumetric_fog"), GraphicsQuality.CHOICES[FOG][level])
		assert_eq(GraphicsQuality.resolve(GraphicsQuality.CUSTOM, &"high", over, table).volumetric_fog, level)


func test_an_old_saves_on_becomes_high_and_off_stays_off() -> void:
	for pair: Array in [["on", GraphicsQuality.VolumetricFog.HIGH], ["off", GraphicsQuality.VolumetricFog.OFF]]:
		var path := ROOT.path_join("v3-%s.save" % pair[0])
		var old := {"graphics_choice": "custom", "graphics_base": "medium",
				"graphics_custom": {"volumetric_fog": pair[0], "glow": "off"}}
		assert_true(SaveFile.write(path, Settings.KIND, 3, old))
		var s := Settings.new(PlayTuning.new())
		s.load_file(path)
		assert_eq(s.graphics_custom.get("volumetric_fog"), GraphicsQuality.CHOICES[FOG][pair[1]], str(pair[0]))
		assert_eq(s.graphics_custom.get("glow"), "off", "the other rows are kept")
		var q := GraphicsQuality.resolve(s.graphics_choice, s.graphics_base, s.graphics_custom, table)
		assert_eq(q.volumetric_fog, pair[1], "%s draws" % [pair[0]])


func test_a_current_saves_levels_are_not_moved() -> void:
	var data := {"graphics_custom": {"volumetric_fog": "on"}}
	assert_eq(Settings.migrate_defaults(data, Settings.VERSION), data, "only an old file is moved")
	var low := {"graphics_custom": {"volumetric_fog": "low"}}
	assert_eq(Settings.migrate_defaults(low, 3), low, "a name it doesn't know from v3 is left for the reader")


func test_a_corrupt_old_custom_row_is_left_for_the_reader_to_drop() -> void:
	for bad: Variant in [1, true, null, [], {}, "ON"]:
		var moved := Settings.migrate_defaults({"graphics_custom": {"volumetric_fog": bad}}, 3)
		assert_eq((moved["graphics_custom"] as Dictionary)["volumetric_fog"], bad, "%s untouched" % [bad])
	assert_eq(Settings.migrate_defaults({"graphics_custom": "x"}, 3), {"graphics_custom": "x"})
	assert_eq(Settings.migrate_defaults({}, 3), {})


func test_a_version_three_files_volumes_are_not_moved_again() -> void:
	var data := {"volumes": Settings.VOLUME_DEFAULTS_V2.duplicate()}
	var moved := Settings.migrate_defaults(data, 3)
	assert_eq(moved["volumes"], data["volumes"], "version 3 already has the current volume defaults")


func test_only_forward_plus_draws_the_haze_at_any_level() -> void:
	for level in GraphicsQuality.CHOICES[FOG].size():
		assert_false(table.can_draw(FOG, level, "gl_compatibility"), "level %d" % level)
		assert_false(table.can_draw(FOG, level, "mobile"), "level %d" % level)
		assert_true(table.can_draw(FOG, level, "forward_plus"), "level %d" % level)
