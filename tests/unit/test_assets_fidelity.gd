extends GutTest
## QA: the salvaged assets match what the browser game played and drew: the ambience loops aren't clipped, the map
## layouts keep every value mapData had, the figures keep their bones, the marks faces carry the HUD's symbols and the
## exports carry the figure sidecars.

const LOOP_DIR := "res://assets/audio/loops"
const MAPS: Array[String] = ["depot", "woodland", "range", "kingsmere"]
## Share of a loop's samples allowed at full scale: a few stray peaks, never a squared-off wave.
const MAX_CLIPPED_SHARE := 0.001
const FIGURE_BONES := 65
const FULL_SCALE := 32767


## Samples of a 16-bit mono PCM WAV at or beyond full scale, and how many samples it has.
func _clipped(path: String) -> Vector2i:
	var bytes := FileAccess.get_file_as_bytes(path)
	var at := 12
	while at + 8 <= bytes.size():
		var id := bytes.slice(at, at + 4).get_string_from_ascii()
		var size := bytes.decode_u32(at + 4)
		if id == "data":
			var clipped := 0
			var count := size / 2
			for i: int in count:
				if absi(bytes.decode_s16(at + 8 + i * 2)) >= FULL_SCALE:
					clipped += 1
			return Vector2i(clipped, count)
		at += 8 + size + (size & 1)
	return Vector2i(0, 0)


func _nulls(value: Variant, path: String, out: Array[String]) -> void:
	if value == null:
		out.append(path)
	elif value is Dictionary:
		var d: Dictionary = value
		for k: Variant in d:
			_nulls(d[k], "%s.%s" % [path, k], out)
	elif value is Array:
		var a: Array = value
		for i: int in a.size():
			_nulls(a[i], "%s[%d]" % [path, i], out)


func _map(id: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json" % id))
	return data if data is Dictionary else {}


func test_ambience_loops_are_not_clipped() -> void:
	for f: String in ResourceLoader.list_directory(LOOP_DIR):
		if f.get_extension() != "wav":
			continue
		var c := _clipped(LOOP_DIR.path_join(f))
		assert_gt(c.y, 0, "%s has samples" % f)
		var share := float(c.x) / maxf(1.0, float(c.y))
		assert_lt(share, MAX_CLIPPED_SHARE, "%s: %d of %d samples at full scale" % [f, c.x, c.y])


func test_map_layouts_hold_no_lost_values() -> void:
	for id: String in MAPS:
		var lost: Array[String] = []
		_nulls(_map(id), id, lost)
		assert_eq(lost, [] as Array[String], "%s: values JSON turned to null (Infinity or NaN in mapData)" % id)


func test_woodland_terrain_heights_are_a_list_of_every_vertex() -> void:
	var terrain: Dictionary = _map("woodland").get("terrain", {})
	var heights: Variant = terrain.get("heights")
	assert_true(heights is Array, "terrain.heights is a list, not an object keyed by index")
	if heights is Array:
		var cols: int = int(terrain.get("cols", 0))
		var rows: int = int(terrain.get("rows", 0))
		assert_eq((heights as Array).size(), (cols + 1) * (rows + 1))


func test_figures_keep_their_skeleton_and_grip_bones() -> void:
	for figure: String in ["human", "robot"]:
		var node := (load("res://assets/models/characters/%s.glb" % figure) as PackedScene).instantiate()
		var skeletons := node.find_children("*", "Skeleton3D", true, false)
		assert_eq(skeletons.size(), 1, figure)
		if skeletons.size() == 1:
			var skeleton := skeletons[0] as Skeleton3D
			assert_eq(skeleton.get_bone_count(), FIGURE_BONES, figure)
			for bone: String in ["Grip_R", "Grip_L"]:
				assert_ne(skeleton.find_bone(bone), -1, "%s has %s" % [figure, bone])
		node.free()


func test_marks_faces_carry_the_arrows_and_tick_and_main_faces_the_up_down_arrows() -> void:
	for weight: String in ["500", "600", "700", "800"]:
		var marks := load("res://assets/fonts/Inter-marks-%s.woff2" % weight) as FontFile
		var main := load("res://assets/fonts/Inter-%s.woff2" % weight) as FontFile
		for c: int in [0x2190, 0x2192, 0x2713]:
			assert_true(marks.has_char(c), "Inter-marks-%s has U+%04X" % [weight, c])
		for c: int in [0x2191, 0x2193]:
			assert_true(main.has_char(c), "Inter-%s has U+%04X" % [weight, c])


func test_every_export_preset_ships_the_figure_sidecars() -> void:
	var presets := ConfigFile.new()
	assert_eq(presets.load("res://export_presets.cfg"), OK)
	var checked := 0
	for section: String in presets.get_sections():
		if not presets.has_section_key(section, "include_filter"):
			continue
		checked += 1
		var filters := str(presets.get_value(section, "include_filter")).split(",", false)
		for sidecar: String in ["assets/models/characters/human.json", "assets/models/characters/robot.json"]:
			var caught := false
			for filter: String in filters:
				caught = caught or sidecar.matchn(filter.strip_edges())
			assert_true(caught, "%s ships %s" % [section, sidecar])
	assert_gt(checked, 0, "export presets found")
