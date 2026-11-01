extends GutTest
## QA hunt for GR1 (the quality table, Custom and the hardware pick): parsing hostile cells, old and hostile settings
## files, Custom round trips, the frame-limit and monitor edges, the pick, the flag forms and the typed-dictionary
## workaround.

const ROOT := "user://test-gr1-qa"
const HEAD := """| ID | Label | Choices | Cost | Renderers | Low | Medium | High | Ultra |
|---|---|---|---|---|---|---|---|---|
"""

var dir := ""
var path := ""
var _n := 0
var s: Settings = null
var table: GraphicsTable = null


func before_all() -> void:
	table = GraphicsTable.read_file()


func before_each() -> void:
	_n += 1
	dir = "%s/%d" % [ROOT, _n]
	_wipe(dir)
	DirAccess.make_dir_recursive_absolute(dir)
	path = dir.path_join("settings.save")
	s = Settings.new(PlayTuning.new())


func after_all() -> void:
	_wipe(ROOT)


func _wipe(p: String) -> void:
	if not DirAccess.dir_exists_absolute(p):
		return
	for d: String in DirAccess.get_directories_at(p):
		_wipe(p.path_join(d))
	for f: String in DirAccess.get_files_at(p):
		DirAccess.remove_absolute(p.path_join(f))
	DirAccess.remove_absolute(p)


func _again() -> Settings:
	var t := Settings.new(PlayTuning.new())
	t.load_file(path)
	return t


func _loaded(data: Dictionary) -> Settings:
	SaveFile.write(path, Settings.KIND, Settings.VERSION, data)
	return _again()


func _problem(t: GraphicsTable, text: String) -> bool:
	for p in t.problems:
		if p.contains(text):
			return true
	return false


# --- the table's parser ---------------------------------------------------------------------------------------------

func test_a_windows_line_ending_file_reads_like_the_shipped_one() -> void:
	var text := FileAccess.get_file_as_string(GraphicsTable.PATH).replace("\n", "\r\n")
	var t := GraphicsTable.parse(text)
	assert_eq(t.problems, [] as Array[String], "CRLF is no problem")
	for p in GraphicsTable.PRESETS:
		assert_true(t.preset(p).equals(table.preset(p)), p)


func test_range_cells_in_other_spellings_read() -> void:
	var t := GraphicsTable.parse(HEAD + "| render_scale | GRAPHICS_RENDER_SCALE | 50 - 100 % | 3 | all | 80% | 90 | 100 | 100 % |")
	assert_eq(t.row(GraphicsQuality.RENDER_SCALE).lo, 50)
	assert_eq(t.row(GraphicsQuality.RENDER_SCALE).hi, 100)
	assert_eq(t.preset(&"low").render_scale, 80, "80% with no space")
	assert_eq(t.preset(&"medium").render_scale, 90, "no unit")
	var u := GraphicsTable.parse(HEAD + "| shadow_range | GRAPHICS_SHADOW_RANGE | 120—30 m | 1 | all | 40 m | 50 m | 70 m | 100 m |")
	assert_true(_problem(u, "shadow_range's Choices"), "a backwards range")
	assert_eq(u.row(GraphicsQuality.SHADOW_RANGE).hi, 120, "keeps the built-in range")
	var w := GraphicsTable.parse(HEAD + "| wind_dust | GRAPHICS_WIND_DUST | -10–100 % | 0 | all | 0 % | 50 % | 100 % | 100 % |")
	assert_true(_problem(w, "wind_dust's Choices"), "a range below the limit")


func test_bad_cells_of_each_kind_keep_the_built_ins_and_never_throw() -> void:
	var rows := [
		"| render_scale | GRAPHICS_RENDER_SCALE | 50–100 % | 2.5 | all | 80.5 % | abc | -5 | 1e2 |",
		"| upscaler | GRAPHICS_UPSCALER | bilinear, bilinear | | | | | | |",
		"| edge_smoothing | GRAPHICS_EDGE_SMOOTHING | | -1 | , | off | | | |",
		"| temporal_smoothing | | off, on | 3 | forward_plus, vulkan | | | | |",
		"| sun_shadows",
		"| shadow_detail | GRAPHICS_SHADOW_DETAIL | 1024, 2048 | 2 | all | 8192 | 1024 | 1024 | 1024 | extra | cells |",
		"| ||||||||| |",
	]
	var t := GraphicsTable.parse(HEAD + "\n".join(rows))
	var built := GraphicsTable.parse("")
	for p in GraphicsTable.PRESETS:
		var q := t.preset(p)
		for row in GraphicsQuality.ROWS:
			assert_true(t.valid(row, q.level(row)), "%s %s stays an offered value" % [p, row])
	assert_eq(t.row(GraphicsQuality.RENDER_SCALE).cost, built.row(GraphicsQuality.RENDER_SCALE).cost)
	assert_eq(t.preset(&"low").render_scale, 80)
	assert_eq(t.row(GraphicsQuality.UPSCALER).choices, built.row(GraphicsQuality.UPSCALER).choices, "duplicate choice")
	assert_true(_problem(t, "twice"))
	assert_eq(t.preset(&"ultra").shadow_detail, 1024, "8192 is no longer offered: Ultra falls to a choice offered")
	assert_true(t.problems.size() > 8, "each bad cell is reported")


func test_ids_choices_and_renderers_are_case_sensitive_and_say_so() -> void:
	var t := GraphicsTable.parse(HEAD + "\n".join([
		"| Render_Scale | GRAPHICS_RENDER_SCALE | 50–100 % | 3 | all | 70 % | 100 % | 100 % | 100 % |",
		"| edge_smoothing | GRAPHICS_EDGE_SMOOTHING | off, fxaa, smaa, msaa_2x, msaa_4x | 3 | All | FXAA | msaa_2x | msaa_4x | msaa_4x |",
	]))
	assert_eq(t.preset(&"low").render_scale, 80, "an ID in the wrong case is an unknown row")
	assert_true(_problem(t, "unknown row \"Render_Scale\""))
	assert_eq(t.preset(&"low").edge_smoothing, GraphicsQuality.EdgeSmoothing.OFF, "built-in kept for FXAA")
	assert_true(_problem(t, "edge_smoothing's Low \"FXAA\""))
	assert_true(_problem(t, "edge_smoothing's Renderers \"All\""))


func test_an_empty_or_junk_file_is_the_built_in_table() -> void:
	for text: String in ["", "\n\n", "just words", "| a | b |\n|---|---|\n| 1 | 2 |", "```\n| ID |\n```"]:
		var t := GraphicsTable.parse(text)
		for p in GraphicsTable.PRESETS:
			assert_true(t.preset(p).equals(table.preset(p)), "%s for %s" % [p, text.left(12)])


func test_the_only_table_drops_bad_lines_and_a_missing_one_keeps_the_built_in() -> void:
	var rows := HEAD + "| render_scale | GRAPHICS_RENDER_SCALE | 50–100 % | 3 | all | 80 % | 100 % | 100 % | 100 % |\n\n"
	var t := GraphicsTable.parse(rows + "| Row | Choice | Renderers |\n|---|---|---|\n| upscaler | fsr2 | mobile |\n"
			+ "| render_scale | 100 | all |\n| upscaler | nope | all |\n| sparkles | on | all |\n| upscaler | fsr1 | |\n")
	assert_true(t.can_draw(&"upscaler", GraphicsQuality.Upscaler.FSR2, "mobile"))
	assert_false(t.can_draw(&"upscaler", GraphicsQuality.Upscaler.FSR2, "forward_plus"))
	assert_true(_problem(t, "\"render_scale\" \"100\""), "a range row has no per-choice renderers")
	assert_true(_problem(t, "\"upscaler\" \"nope\""))
	assert_true(_problem(t, "\"sparkles\""))
	assert_true(_problem(t, "upscaler fsr1's Renderers"))
	assert_true(table.can_draw(&"upscaler", GraphicsQuality.Upscaler.FSR1, "forward_plus"))
	assert_false(table.can_draw(&"upscaler", GraphicsQuality.Upscaler.FSR1, "gl_compatibility"))
	assert_false(table.can_draw(&"ambient_occlusion", GraphicsQuality.AmbientOcclusion.HALF, "mobile"))
	assert_false(table.can_draw(&"sparkles", 0, "forward_plus"))
	assert_false(table.can_draw(&"wind_dust", 50, "vulkan"), "an unknown renderer draws nothing")


func test_level_of_and_valid_edges() -> void:
	assert_eq(table.level_of(&"wind_dust", 12.6), 13, "a float from JSON")
	assert_eq(table.level_of(&"wind_dust", true), GraphicsTable.NO_LEVEL, "a bool is no number")
	assert_eq(table.level_of(&"wind_dust", INF), GraphicsTable.NO_LEVEL)
	assert_eq(table.level_of(&"wind_dust", NAN), GraphicsTable.NO_LEVEL)
	assert_eq(table.level_of(&"wind_dust", "50"), GraphicsTable.NO_LEVEL, "a string for a range row")
	assert_eq(table.level_of(&"wind_dust", -1), GraphicsTable.NO_LEVEL)
	assert_eq(table.level_of(&"edge_smoothing", 2), GraphicsTable.NO_LEVEL, "a number for a choice row")
	assert_eq(table.level_of(&"edge_smoothing", "MSAA_4X"), GraphicsTable.NO_LEVEL, "case")
	assert_eq(table.level_of(&"edge_smoothing", &"msaa_4x"), GraphicsQuality.EdgeSmoothing.MSAA_4X, "a StringName")
	assert_eq(table.level_of(&"", "on"), GraphicsTable.NO_LEVEL)
	assert_eq(table.level_of(&"shadow_detail", "8192"), 3)
	assert_eq(table.level_of(&"render_scale", 49), GraphicsTable.NO_LEVEL, "below the file's 50")
	assert_eq(table.level_of(&"render_scale", 50), 50)
	assert_false(table.valid(&"render_scale", 101))
	assert_false(table.valid(&"upscaler", -1))
	assert_false(table.valid(&"upscaler", 3))


func test_a_fresh_quality_resolves_overrides_without_throwing() -> void:
	var fresh := GraphicsQuality.new()
	var o := GraphicsQuality.overrides(fresh, &"high", table)
	var back := GraphicsQuality.resolve(GraphicsQuality.CUSTOM, &"high", o, table)
	for row in GraphicsQuality.ROWS:
		assert_true(table.valid(row, back.level(row)), "%s survives a round trip of an all-zero object" % row)
	assert_eq(GraphicsQuality.resolve(&"", &"high", {}, table).level(&"render_scale"), 100, "automatic is the caller's: High")
	assert_true(GraphicsQuality.resolve(GraphicsQuality.CUSTOM, GraphicsQuality.CUSTOM, {}, table).equals(table.preset(&"high")),
			"a base that is itself Custom reads as High")


func test_every_preset_round_trips_through_choice_of_and_custom() -> void:
	for p in GraphicsTable.PRESETS:
		assert_eq(GraphicsQuality.choice_of(GraphicsQuality.resolve(p, &"high", {}, table), table), p)
		for base in GraphicsTable.PRESETS:
			var v := GraphicsQuality.resolve(GraphicsQuality.CUSTOM, base, {"wind_dust": 7, "upscaler": "bilinear"}, table)
			var o := GraphicsQuality.overrides(v, base, table)
			assert_true(GraphicsQuality.resolve(GraphicsQuality.CUSTOM, base, o, table).equals(v), "%s over %s" % [p, base])


# --- the typed-dictionary workaround --------------------------------------------------------------------------------

func _choices_by_variable(row: StringName) -> int:
	var names: Array = GraphicsQuality.CHOICES[row]
	return names.size()


func test_choices_and_built_in_read_back_as_arrays_by_every_kind_of_key() -> void:
	for row: StringName in GraphicsQuality.CHOICES:
		var a: Variant = GraphicsQuality.CHOICES[row]
		assert_eq(typeof(a), TYPE_ARRAY, "%s read by a loop key" % row)
		assert_eq(_choices_by_variable(row), a.size())
		assert_eq(PackedStringArray(a).size(), a.size())
		assert_eq(a.find(a[0]), 0)
		assert_eq(GraphicsQuality.CHOICES.get(row).size(), a.size(), "get()")
		for name: String in a:
			assert_eq(str(name), name)
	for k: Variant in GraphicsQuality.CHOICES.keys():
		assert_true(GraphicsQuality.ROWS.has(k))
	for i in GraphicsQuality.ROWS.size():
		var row := GraphicsQuality.ROWS[i]
		var cells: Array = GraphicsTable.BUILT_IN[row]
		assert_eq(cells.size(), 8, "%s has a label, choices, cost, renderers and four presets" % row)
		for c: Variant in cells:
			assert_true(c is String, "%s cell" % row)
		assert_eq(GraphicsTable.BUILT_IN.get(row).size(), 8)
	assert_eq(GraphicsQuality.CHOICES.size() + GraphicsQuality.LIMITS.size(), GraphicsQuality.ROWS.size(), "every row is one kind")
	for row in GraphicsQuality.ROWS:
		assert_ne(GraphicsQuality.CHOICES.has(row), GraphicsQuality.is_range(row), row)


# --- the pick -------------------------------------------------------------------------------------------------------

func test_the_pick_for_every_device_type_and_renderer_never_ultra() -> void:
	var want := {
		RenderingDevice.DEVICE_TYPE_CPU: &"low", RenderingDevice.DEVICE_TYPE_VIRTUAL_GPU: &"low",
		RenderingDevice.DEVICE_TYPE_OTHER: &"medium", RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU: &"medium",
		RenderingDevice.DEVICE_TYPE_DISCRETE_GPU: &"high",
	}
	for type: int in want:
		for method: String in ["forward_plus", "mobile", ""]:
			assert_eq(GraphicsPick.pick(type, method), want[type], "%d on '%s'" % [type, method])
		assert_eq(GraphicsPick.pick(type, "gl_compatibility"), &"low", "%d on Compatibility" % type)
	for type: int in range(-3, 12):
		for method: String in ["forward_plus", "mobile", "gl_compatibility", "GL_COMPATIBILITY", "", "vulkan"]:
			var p := GraphicsPick.pick(type, method)
			assert_true(GraphicsTable.PRESETS.has(p) and p != &"ultra", "%d on '%s'" % [type, method])


func test_the_pick_covers_every_device_type_the_engine_names() -> void:
	for type: int in [RenderingDevice.DEVICE_TYPE_OTHER, RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU,
			RenderingDevice.DEVICE_TYPE_DISCRETE_GPU, RenderingDevice.DEVICE_TYPE_VIRTUAL_GPU, RenderingDevice.DEVICE_TYPE_CPU]:
		assert_true(GraphicsPick.BY_DEVICE.has(type), "type %d is in BY_DEVICE" % type)
	assert_eq(RenderingDevice.DEVICE_TYPE_MAX, 5, "the engine has no sixth device type this table misses")
	var probe := GraphicsPick.probe()
	assert_ne(probe.preset, &"ultra")


# --- the flag -------------------------------------------------------------------------------------------------------

func test_the_flag_forms() -> void:
	var cases := [
		[["--graphics=low"], &"low"], [["--", "--graphics=low"], &"low"], [["--graphics", "low"], &"low"],
		[["--graphics=LOW"], &"low"], [["--graphics", "Ultra"], &"ultra"], [["--graphics=MeDiUm"], &"medium"],
		[["--graphics= high "], &"high"], [["--smoke", "--graphics=high", "--seed", "4"], &"high"],
		[["--graphics=extreme"], &""], [["--graphics="], &""], [["--graphics"], &""], [["--graphics", ""], &""],
		[["--graphics", "--smoke"], &""], [["--graphics=custom"], &""], [["--graphics=low=high"], &""],
		[["--graphicsx=low"], &""], [["graphics=low"], &""], [["-graphics=low"], &""], [[], &""],
		[["--graphics=bad", "--graphics=low"], &""], [["--graphics=low", "--graphics=ultra"], &"low"],
		[["--graphics=lo w"], &""], [["--graphics=low\n"], &"low"],
	]
	for c: Array in cases:
		var args := PackedStringArray(c[0])
		assert_eq(GraphicsPick.forced(args), c[1], str(c[0]))


func test_a_forced_run_with_a_changed_row_saves_custom_on_the_forced_preset_but_never_the_flag() -> void:
	s.graphics_choice = &"medium"
	s.graphics_forced = &"low"
	assert_true(s.change_graphics_row(&"wind_dust", 30, &"high", table))
	assert_eq(s.graphics_base, &"low")
	var got := _loaded(s.to_dict())
	assert_eq(got.graphics_forced, &"", "the flag is not in the file")
	assert_eq(got.graphics_choice, GraphicsQuality.CUSTOM)
	assert_eq(got.graphics_base, &"low")


# --- settings files -------------------------------------------------------------------------------------------------

func test_an_old_file_without_the_graphics_fields_loads_and_keeps_its_values() -> void:
	var got := _loaded({"sensitivity": 2.5, "fov": 100.0, "vsync": false, "window_mode": 1})
	assert_eq(got.sensitivity, 2.5)
	assert_eq(got.fov, 100.0)
	assert_false(got.vsync)
	assert_eq(got.window_mode, Settings.WindowMode.BORDERLESS)
	assert_eq(got.graphics_choice, Settings.GRAPHICS_AUTOMATIC)
	assert_eq(got.graphics_base, &"high")
	assert_eq(got.graphics_custom, {} as Dictionary[String, Variant])
	assert_eq(got.frame_limit, Settings.UNLIMITED)
	assert_eq(got.monitor, Settings.MONITOR_HERE)
	assert_eq(got.last_fullscreen, Settings.WINDOW_MODE_DEFAULT)
	assert_eq(got.renderer, Settings.Renderer.AUTO)
	assert_false(got.first_start_seen)
	assert_eq(got.load_message, "", "no complaint")
	assert_eq(Settings.VERSION, 3, "3 since AU1 moved the ambience's default")
	var raw := SaveFile.read(path, Settings.KIND)
	assert_eq(int(raw.version), Settings.VERSION)


func test_graphics_choice_of_every_wrong_kind_reads_as_automatic() -> void:
	for bad: Variant in [null, 3, 1.5, true, "", "HIGH", "extreme", "Custom", [], {}, "high "]:
		var got := _loaded({"graphics_choice": bad})
		assert_eq(got.graphics_choice, Settings.GRAPHICS_AUTOMATIC, str(bad))
	for good: String in ["low", "medium", "high", "ultra", "custom"]:
		assert_eq(_loaded({"graphics_choice": good}).graphics_choice, StringName(good))
	for bad: Variant in [null, 3, "", "custom", "HIGH", "ultra!", []]:
		assert_eq(_loaded({"graphics_base": bad}).graphics_base, &"high", "base %s" % str(bad))
	assert_eq(_loaded({"graphics_base": "low"}).graphics_base, &"low")


func test_graphics_custom_of_the_wrong_kind_or_with_wrong_rows() -> void:
	for bad: Variant in [null, 3, "x", [1, 2], true]:
		assert_eq(_loaded({"graphics_custom": bad}).graphics_custom, {} as Dictionary[String, Variant], str(bad))
	var got := _loaded({"graphics_choice": "custom", "graphics_custom": {
		"wind_dust": 12.4, "render_scale": 500, "shadow_range": "far", "edge_smoothing": "msaa_8x", "upscaler": 1,
		"sun_shadows": "ON", "mesh_detail": "ultra", "sparkles": "on", "texture_filtering": null, "shadow_detail": "8192",
		"temporal_smoothing": true, "ambient_occlusion": ["full"],
	}})
	assert_eq(got.graphics_custom, {"wind_dust": 12, "mesh_detail": "ultra", "shadow_detail": "8192"} as Dictionary[String, Variant])
	assert_eq(got.graphics_in_force(&"low", table).wind_dust, 12, "and they resolve")


func test_custom_survives_a_save_and_load_with_every_kind_of_row() -> void:
	s.graphics_choice = &"low"
	for c: Array in [[&"render_scale", 65], [&"upscaler", "bilinear"], [&"shadow_detail", "8192"], [&"wind_dust", 35],
			[&"shadow_range", 120], [&"sun_shadows", "on"], [&"texture_filtering", "off"]]:
		assert_true(s.change_graphics_row(c[0], c[1], &"high", table), str(c))
	assert_eq(s.graphics_choice, GraphicsQuality.CUSTOM)
	assert_eq(s.graphics_base, &"low")
	var before := s.graphics_in_force(&"high", table)
	assert_true(s.save(path))
	var got := _again()
	assert_eq(got.graphics_choice, GraphicsQuality.CUSTOM)
	assert_eq(got.graphics_base, &"low")
	assert_eq(got.graphics_custom, s.graphics_custom)
	assert_true(got.graphics_in_force(&"high", table).equals(before), "the same look after a restart")
	assert_true(got.save(path), "and saves again")
	assert_eq(_again().graphics_custom, s.graphics_custom)


func test_the_automatic_pick_is_never_written_through_any_route() -> void:
	assert_false(s.to_dict().has("graphics_choice"), "fresh")
	assert_true(s.change_graphics_row(&"wind_dust", 10, &"medium", table))
	assert_true(s.to_dict().has("graphics_choice"))
	s.save(path)
	assert_true(s.choose_graphics(Settings.GRAPHICS_AUTOMATIC, &"high"))
	s.save(path)
	var raw := SaveFile.read(path, Settings.KIND)
	assert_false((raw.data as Dictionary).has("graphics_choice"), "back to automatic removes the key from the file")
	assert_eq(_again().graphics_choice, Settings.GRAPHICS_AUTOMATIC)
	var t := _loaded({"graphics_choice": "ultra"})
	assert_true(t.choose_graphics(&"", &"low"))
	t.save(path)
	assert_false((SaveFile.read(path, Settings.KIND).data as Dictionary).has("graphics_choice"))
	s.from_dict({})
	assert_false(s.to_dict().has("graphics_choice"), "a reset save")
	assert_eq(s.graphics_choice, Settings.GRAPHICS_AUTOMATIC)


func test_picking_a_preset_then_custom_starts_clean_and_the_preset_ignores_old_rows() -> void:
	s.graphics_choice = &"ultra"
	s.change_graphics_row(&"wind_dust", 10, &"high", table)
	assert_true(s.choose_graphics(&"low", &"high"))
	assert_true(s.graphics_in_force(&"high", table).equals(table.preset(&"low")), "the preset ignores Custom's rows")
	assert_true(s.choose_graphics(GraphicsQuality.CUSTOM, &"high"))
	assert_eq(s.graphics_base, &"low", "Custom starts from the preset you were on")
	assert_eq(s.graphics_custom, {} as Dictionary[String, Variant], "with no rows")
	assert_true(s.graphics_in_force(&"high", table).equals(table.preset(&"low")))
	assert_false(s.choose_graphics(&"CUSTOM", &"high"), "a wrong-case name")
	assert_false(s.choose_graphics(&"Low", &"high"))
	assert_eq(s.graphics_choice, GraphicsQuality.CUSTOM, "a refused choice changes nothing")


func test_changing_a_row_to_the_value_it_has_still_makes_custom_with_no_rows() -> void:
	assert_true(s.change_graphics_row(&"wind_dust", 50, &"medium", table))
	assert_eq(s.graphics_choice, GraphicsQuality.CUSTOM)
	assert_eq(s.graphics_custom, {} as Dictionary[String, Variant])
	assert_eq(GraphicsQuality.choice_of(s.graphics_in_force(&"medium", table), table), &"medium")


func test_the_frame_limit_edges() -> void:
	var cases := {
		0.0: 0, -1.0: 0, -1000.0: 0, 0.001: 30, 1.0: 30, 29.9: 30, 30.0: 30, 44.9: 30, 45.0: 60, 90.0: 120,
		91.0: 120, 132.0: 144, 154.5: 165, 202.5: 240, 300.0: 360, 360.0: 360, 361.0: 360, 1.0e9: 360, 1.0e300: 360,
	}
	assert_eq(Settings.nearest_frame_limit(INF), 360)
	assert_eq(Settings.nearest_frame_limit(-INF), 0)
	assert_eq(Settings.nearest_frame_limit(NAN), 0)
	for given: float in cases:
		assert_eq(Settings.nearest_frame_limit(given), cases[given], "given %s" % given)
	for given: Variant in ["60", null, true, [], {}, "unlimited"]:
		assert_eq(_loaded({"frame_limit": given}).frame_limit, Settings.UNLIMITED, "a %s" % str(given))
	for given: Variant in [60, 60.0, 75, 59.5, 1e12, 0, -5, 0.2]:
		var f := _loaded({"frame_limit": given}).frame_limit
		assert_true(f == 0 or Settings.FRAME_LIMITS.has(f), "%s read as %d" % [str(given), f])
	assert_eq(_loaded({"frame_limit": -5}).frame_limit, Settings.UNLIMITED)
	assert_eq(_loaded({"frame_limit": 1e12}).frame_limit, 360)


func test_the_monitor_edges() -> void:
	var cases := {-1: -1, 0: 0, 1: 1, 63: 63, 64: -1, -2: -1, 1000: -1, 2.4: 2, 2.6: 3, 62.6: 63, 63.4: -1, -0.6: -1, -1.4: -1}
	for given: Variant in cases:
		assert_eq(_loaded({"monitor": given}).monitor, cases[given], "given %s" % given)
	for given: Variant in ["0", null, true, [], "primary"]:
		assert_eq(_loaded({"monitor": given}).monitor, Settings.MONITOR_HERE, str(given))


func test_last_fullscreen_renderer_and_first_start_edges() -> void:
	var fs := {0: 2, 1: 1, 2: 2, 3: 2, -1: 2, 1.4: 1, 1.6: 2, 2.4: 2, 2.6: 2}
	for given: Variant in fs:
		assert_eq(_loaded({"last_fullscreen": given}).last_fullscreen, fs[given] as Settings.WindowMode, "fullscreen %s" % given)
	var rd := {0: 0, 1: 1, 2: 0, -1: 0, 0.6: 1, 1.4: 0, 1.6: 0}
	for given: Variant in rd:
		assert_eq(_loaded({"renderer": given}).renderer, rd[given] as Settings.Renderer, "renderer %s" % given)
	for given: Variant in ["true", 1, null, "yes", []]:
		assert_false(_loaded({"first_start_seen": given}).first_start_seen, str(given))
	assert_true(_loaded({"first_start_seen": true}).first_start_seen)
	var t := _loaded({"last_fullscreen": 2, "renderer": 1, "first_start_seen": true, "monitor": 3, "frame_limit": 144})
	assert_true(t.save(path))
	var u := _again()
	assert_eq([int(u.last_fullscreen), int(u.renderer), u.first_start_seen, u.monitor, u.frame_limit], [2, 1, true, 3, 144])


func test_a_bad_graphics_field_does_not_disturb_the_others() -> void:
	var got := _loaded({"graphics_choice": 7, "graphics_custom": "x", "frame_limit": 120, "monitor": "left", "renderer": 1,
			"fov": 100.0, "graphics_base": "low"})
	assert_eq(got.frame_limit, 120)
	assert_eq(got.monitor, -1)
	assert_eq(got.renderer, Settings.Renderer.COMPATIBILITY)
	assert_eq(got.fov, 100.0)
	assert_eq(got.graphics_base, &"low")
	assert_eq(got.graphics_choice, Settings.GRAPHICS_AUTOMATIC)
