extends GutTest
## WM1 QA: malformed marks data, old saves, the Compatibility renderer, teardown and the decal budget.

var play: PlayTuning = PlayTuning.load_default()
var table: GraphicsTable = null


func before_each() -> void:
	table = GraphicsTable.shared()


func _good() -> Dictionary:
	return {"kind": "oil", "x": 1, "z": 2, "length": 1.5}


func test_a_dressing_that_is_not_a_dictionary_names_no_marks() -> void:
	var warnings: Array[String] = []
	for bad: Variant in [[], "wearMarks", 5, 1.5, true, null]:
		assert_eq(WearMark.read(bad, warnings).size(), 0)
	assert_eq(warnings.size(), 0, "not a dressing at all is silent, as for every other dressing")


func test_marks_that_are_not_a_list_warn_once_and_name_none() -> void:
	for bad: Variant in [{"a": 1}, "oil", 3, true, null]:
		var warnings: Array[String] = []
		assert_eq(WearMark.read({"wearMarks": bad}, warnings).size(), 0)
		assert_eq(warnings.size(), 1, "marks = %s" % [bad])


func test_wrong_types_in_a_mark_leave_it_out_and_keep_the_rest() -> void:
	var warnings: Array[String] = []
	var list: Array = [
		"oil", 7, null, [], {},
		{"kind": 5, "x": 0, "z": 0, "length": 1},
		{"kind": "oil", "x": "1", "z": 0, "length": 1},
		{"kind": "oil", "x": 0, "z": null, "length": 1},
		{"kind": "oil", "x": 0, "z": 0, "length": "2"},
		{"kind": "oil", "x": 0, "z": 0, "length": -1},
		{"kind": "tyres", "x": 0, "z": 0, "length": 4, "bend": 181},
		{"kind": "tyres", "x": 0, "z": 0, "length": 4, "bend": -181},
		{"kind": "oil", "x": 0, "z": 0, "length": 1, "mud": "yes"},
		_good(),
	]
	var marks := WearMark.read({"wearMarks": list}, warnings)
	assert_eq(marks.size(), 1)
	assert_eq(warnings.size(), list.size() - 1)


func test_the_limits_themselves_are_allowed() -> void:
	var warnings: Array[String] = []
	var marks := WearMark.read({"wearMarks": [
		{"kind": "tyres", "x": 0, "z": 0, "length": WearMark.MOST_LENGTH, "bend": WearMark.MOST_BEND},
		{"kind": "tyres", "x": 0, "z": 0, "length": 0.01, "bend": -WearMark.MOST_BEND, "y": 3, "mud": true},
	]}, warnings)
	assert_eq(marks.size(), 2)
	assert_eq(warnings.size(), 0)
	assert_eq(marks[1].y, 3.0)


func test_a_longest_bent_mark_builds_a_bounded_number_of_decals() -> void:
	var map := MapData.parse('{"size":[40,40],"dressing":{"wearMarks":[{"kind":"tyres","x":0,"z":0,"length":30,"bend":180},'
			+ '{"kind":"tyres","x":0,"z":0,"length":30,"bend":-180,"mud":true}]}}', play.map_style, 6)
	if map.marks.is_empty():
		pending("a bare map does not parse in this build")
		return
	var marks := WearMarks.build(map, play.marks, play.look)
	add_child_autofree(marks)
	assert_lt(marks.decals().size(), 200, "the longest marks are a few dozen decals")
	for d in marks.decals():
		assert_true(is_finite(d.position.x) and is_finite(d.position.z))
		assert_gt(d.size.z, 0.0)


func test_every_shipped_map_stays_inside_a_decal_budget() -> void:
	for id: String in ["depot", "woodland"]:
		var map := MapData.load_map(id, play.map_style, 6)
		var marks := WearMarks.build(map, play.marks, play.look)
		add_child_autofree(marks)
		assert_lt(marks.decals().size(), 400, "%s: decals" % id)
		assert_gt(map.marks.size(), 0)


func test_building_is_repeatable() -> void:
	var map := MapData.load_map("depot", play.map_style, 6)
	var a := WearMarks.build(map, play.marks, play.look)
	var b := WearMarks.build(map, play.marks, play.look)
	add_child_autofree(a)
	add_child_autofree(b)
	assert_eq(a.decals().size(), b.decals().size())
	for i in a.decals().size():
		assert_eq(a.decals()[i].position, b.decals()[i].position)
		assert_eq(a.decals()[i].rotation, b.decals()[i].rotation)


func test_building_with_no_config_or_look_is_null_not_a_crash() -> void:
	var map := MapData.load_map("depot", play.map_style, 6)
	assert_null(WearMarks.build(map, null, play.look))
	assert_null(WearMarks.build(map, play.marks, null))


func test_freeing_the_marks_leaves_no_nodes_behind() -> void:
	var map := MapData.load_map("depot", play.map_style, 6)
	WearMarkArt.ensure(play.marks)
	var before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var marks := WearMarks.build(map, play.marks, play.look)
	add_child(marks)
	assert_gt(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), before)
	remove_child(marks)
	marks.free()
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), before, "no node outlives the marks")


func test_a_built_but_never_added_marks_is_freed_by_hand_cleanly() -> void:
	var map := MapData.load_map("woodland", play.map_style, 6)
	var before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	WearMarks.build(map, play.marks, play.look).free()
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), before)


func test_apply_field_without_marks_changes_nothing_and_does_not_crash() -> void:
	GraphicsApply.apply_field(table.preset(&"low"), null, null, GraphicsApply.Server.new(), null, null, null, null,
			null)
	GraphicsApply.apply_field(table.preset(&"low"), null, null, GraphicsApply.Server.new())
	assert_true(true)


func test_marks_follow_the_setting_both_ways() -> void:
	var marks := WearMarks.build(MapData.load_map("depot", play.map_style, 6), play.marks, play.look)
	add_child_autofree(marks)
	for name: StringName in [&"low", &"medium", &"low", &"ultra"]:
		GraphicsApply.apply_field(table.preset(name), null, null, GraphicsApply.Server.new(), null, null, null, null,
				marks)
		assert_eq(marks.visible, table.preset(name).wear_marks, name)


func test_compatibility_cannot_draw_the_row_at_any_level_and_others_can() -> void:
	assert_false(table.can_draw(GraphicsQuality.WEAR_MARKS, 0, "gl_compatibility") and
			table.can_draw(GraphicsQuality.WEAR_MARKS, 1, "gl_compatibility"))
	assert_false(table.can_draw(GraphicsQuality.WEAR_MARKS, 1, "gl_compatibility"))
	assert_true(table.can_draw(GraphicsQuality.WEAR_MARKS, 1, "mobile"))


func test_an_old_custom_save_without_wear_marks_takes_the_base_presets_value() -> void:
	var old := {"glow": "on", "volumetric_fog": "off"}
	assert_true(GraphicsQuality.resolve(GraphicsQuality.CUSTOM, &"medium", old, table).wear_marks)
	assert_false(GraphicsQuality.resolve(GraphicsQuality.CUSTOM, &"low", old, table).wear_marks)


func test_a_corrupt_wear_marks_custom_value_is_dropped_alone() -> void:
	for bad: Variant in [5, null, "maybe", [], {}, true, 1.0]:
		var q := GraphicsQuality.resolve(GraphicsQuality.CUSTOM, &"medium", {"wear_marks": bad, "glow": "on"}, table)
		assert_true(q.wear_marks, "%s falls back to the base (Medium: on)" % [bad])
		assert_true(q.glow, "the other row is kept")


func test_wear_marks_round_trip_through_custom_overrides() -> void:
	var q := table.preset(&"medium")
	q.wear_marks = false
	var over := GraphicsQuality.overrides(q, &"medium", table)
	assert_eq(over.get("wear_marks"), "off")
	assert_false(GraphicsQuality.resolve(GraphicsQuality.CUSTOM, &"medium", over, table).wear_marks)
	assert_eq(GraphicsQuality.choice_of(q, table), GraphicsQuality.CUSTOM)


func test_the_row_has_a_page_slot_and_text() -> void:
	var placed := false
	for section: String in SettingsGraphicsPage.RIGHT_SECTIONS:
		placed = placed or SettingsGraphicsPage.RIGHT_SECTIONS[section].has(GraphicsQuality.WEAR_MARKS)
	for section: String in SettingsGraphicsPage.LEFT_SECTIONS:
		placed = placed or SettingsGraphicsPage.LEFT_SECTIONS[section].has(GraphicsQuality.WEAR_MARKS)
	assert_true(placed, "the row is on the Graphics tab")
	assert_ne(tr("GRAPHICS_WEAR_MARKS"), "GRAPHICS_WEAR_MARKS")
	assert_ne(tr("GRAPHICS_WEAR_MARKS_NOTE"), "GRAPHICS_WEAR_MARKS_NOTE")


func test_the_range_has_no_marks_and_no_node() -> void:
	var map := MapData.load_map("range", play.map_style, 6)
	assert_eq(map.marks.size(), 0)
	assert_null(WearMarks.build(map, play.marks, play.look))


func test_the_map_builders_leave_the_shipped_maps_unchanged() -> void:
	var out: Array = []
	var code := OS.execute("bash", ["-c", "cd \"$(dirname \"$0\")\" 2>/dev/null; true"], out)
	if code != 0 or not FileAccess.file_exists("res://tools/depot/build_map.py"):
		pending("no tools here")
		return
	var root := ProjectSettings.globalize_path("res://")
	var before := {}
	for f: String in ["depot", "woodland"]:
		before[f] = FileAccess.get_file_as_string("res://data/maps/%s.json" % f)
	var py := OS.execute("bash", ["-c", "command -v python3"], out)
	if py != 0:
		pending("no python3")
		return
	var maps: Array[String] = ["depot"]
	# Woodland's builder needs numpy, which a bare runner (CI) lacks; its map is checked where numpy is installed
	if OS.execute("python3", ["-c", "import numpy"], out) == 0:
		maps.append("woodland")
	for f in maps:
		assert_eq(OS.execute("python3", [root + "tools/%s/build_map.py" % f]), 0, f)
	for f in maps:
		assert_eq(FileAccess.get_file_as_string("res://data/maps/%s.json" % f), before[f], "%s reproducible" % f)


# ---- rework: pieces, fades, lug pitch, degenerate tracks, art reuse ----

func _alpha_at(img: Image, row: int) -> float:
	return img.get_pixel(img.get_width() / 2, row).a


func test_one_piece_is_only_two_are_first_and_last_three_have_a_middle() -> void:
	assert_eq(WearMarks._piece(0, 1), WearMarkArt.Piece.ONLY)
	assert_eq(WearMarks._piece(0, 2), WearMarkArt.Piece.FIRST)
	assert_eq(WearMarks._piece(1, 2), WearMarkArt.Piece.LAST)
	assert_eq(WearMarks._piece(1, 3), WearMarkArt.Piece.MIDDLE)
	assert_eq(WearMarks._piece(2, 3), WearMarkArt.Piece.LAST)


func test_a_fade_of_zero_leaves_a_piece_untouched() -> void:
	var cfg := MarksConfig.new()
	cfg.track_fade = 0.0
	var tile := Image.create_empty(4, 16, false, Image.FORMAT_RGBA8)
	tile.fill(Color(1, 1, 1, 0.8))
	for piece: WearMarkArt.Piece in [WearMarkArt.Piece.FIRST, WearMarkArt.Piece.LAST, WearMarkArt.Piece.ONLY]:
		var out := WearMarkArt.faded(cfg, tile, piece)
		for row in 16:
			assert_almost_eq(_alpha_at(out, row), _alpha_at(tile, row), 0.01, "piece %d row %d" % [piece, row])


func test_a_fade_longer_than_the_piece_is_clamped_and_still_fades_the_ends() -> void:
	var cfg := MarksConfig.new()
	cfg.track_fade = 50.0
	var tile := Image.create_empty(4, 32, false, Image.FORMAT_RGBA8)
	tile.fill(Color.WHITE)
	var first := WearMarkArt.faded(cfg, tile, WearMarkArt.Piece.FIRST)
	assert_lt(_alpha_at(first, 31), _alpha_at(first, 0), "a first piece fades in from the bottom")
	var last := WearMarkArt.faded(cfg, tile, WearMarkArt.Piece.LAST)
	assert_lt(_alpha_at(last, 0), _alpha_at(last, 31), "a last piece fades out at the top")
	var only := WearMarkArt.faded(cfg, tile, WearMarkArt.Piece.ONLY)
	assert_lt(_alpha_at(only, 0), _alpha_at(only, 16))
	assert_lt(_alpha_at(only, 31), _alpha_at(only, 16))
	assert_eq(WearMarkArt.faded(cfg, tile, WearMarkArt.Piece.MIDDLE).get_data(), tile.get_data())


func test_faded_never_changes_the_source_tile_and_a_zero_track_piece_does_not_crash() -> void:
	var cfg := MarksConfig.new()
	cfg.track_piece = 0.0
	var tile := Image.create_empty(4, 16, false, Image.FORMAT_RGBA8)
	tile.fill(Color.WHITE)
	var before := tile.get_data()
	var out := WearMarkArt.faded(cfg, tile, WearMarkArt.Piece.ONLY)
	assert_eq(tile.get_data(), before)
	assert_eq(out.get_width(), 4)


func test_a_zero_or_tiny_lug_pitch_still_paints_a_finite_tread() -> void:
	var noise := FastNoiseLite.new()
	for pitch: float in [0.0, -1.0, 0.0001, 100.0]:
		var cfg := MarksConfig.new()
		cfg.lug_pitch = pitch
		cfg.tread_pixels = Vector2i(8, 64)
		var img := WearMarkArt.tread_image(cfg, noise, true)
		assert_eq(img.get_size(), Vector2i(8, 64), "pitch %s" % pitch)
		var seen := 0.0
		for y in 64:
			seen = maxf(seen, _alpha_at(img, y))
		assert_gt(seen, 0.0, "pitch %s paints something" % pitch)


func test_a_tread_picture_tiles_top_to_bottom() -> void:
	var cfg := MarksConfig.new()
	var noise := FastNoiseLite.new()
	noise.seed = WearMarkArt.SEED
	noise.frequency = 1.0
	var img := WearMarkArt.tread_image(cfg, noise, false)
	var h := img.get_height()
	assert_almost_eq(_alpha_at(img, 0), _alpha_at(img, h - 1), 0.1, "smear rows at the seam are alike")


func test_tracks_of_tiny_length_with_a_big_bend_have_no_nan_and_a_positive_size() -> void:
	for length: float in [0.01, 0.0001]:
		for mud: bool in [false, true]:
			var map := MapData.parse('{"size":[40,40],"dressing":{"wearMarks":[{"kind":"tyres","x":3,"z":3,"length":%s,"bend":180,"mud":%s}]}}'
					% [length, str(mud).to_lower()], play.map_style, 6)
			if map.marks.is_empty():
				continue
			var marks := WearMarks.build(map, play.marks, play.look)
			add_child_autofree(marks)
			assert_gt(marks.decals().size(), 0)
			for d in marks.decals():
				assert_true(is_finite(d.position.x) and is_finite(d.position.z) and is_finite(d.rotation.y))
				assert_gt(d.size.z, 0.0)
				assert_true(d.size.is_finite())


func test_every_bent_track_wheel_pieces_meet_end_to_end() -> void:
	var map := MapData.parse('{"size":[80,80],"dressing":{"wearMarks":[{"kind":"tyres","x":0,"z":0,"length":14,"bend":120}]}}',
			play.map_style, 6)
	if map.marks.is_empty():
		pending("a bare map does not parse in this build")
		return
	var marks := WearMarks.build(map, play.marks, play.look)
	add_child_autofree(marks)
	var all := marks.decals()
	var per := all.size() / 2
	for w in 2:
		for i in per - 1:
			var a := all[w * per + i]
			var b := all[w * per + i + 1]
			var end_a := Vector2(a.position.x, a.position.z) + Vector2(sin(-a.rotation.y), -cos(-a.rotation.y)) * a.size.z * 0.5
			var start_b := Vector2(b.position.x, b.position.z) - Vector2(sin(-b.rotation.y), -cos(-b.rotation.y)) * b.size.z * 0.5
			assert_lt(end_a.distance_to(start_b), 0.01, "wheel %d piece %d meets the next" % [w, i])


func test_the_art_repaints_after_a_config_change() -> void:
	var a := MarksConfig.new()
	a.tread_pixels = Vector2i(8, 32)
	WearMarkArt.ensure(a)
	assert_eq(WearMarkArt.tread(true, WearMarkArt.Piece.MIDDLE).get_height(), 32)
	var b := MarksConfig.new()
	b.tread_pixels = Vector2i(8, 64)
	b.smear_pixels = Vector2i(8, 16)
	WearMarkArt.ensure(b)
	assert_eq(WearMarkArt.tread(true, WearMarkArt.Piece.FIRST).get_height(), 64)
	assert_eq(WearMarkArt.tread(false, WearMarkArt.Piece.ONLY).get_height(), 16)
	WearMarkArt.ensure(play.marks)
	assert_eq(WearMarkArt.tread(true, WearMarkArt.Piece.LAST).get_height(), play.marks.tread_pixels.y)
