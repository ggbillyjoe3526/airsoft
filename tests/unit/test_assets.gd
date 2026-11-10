extends GutTest
## The assets salvaged from the browser game load in Godot: every model, the figures with their 35 clips and sidecars,
## every sound and loop, the fonts and the map layouts.

const MODEL_DIRS: Array[String] = [
	"res://assets/models/characters",
	"res://assets/models/replicas",
	"res://assets/models/replicaParts",
	"res://assets/models/powerSources",
]
const FIGURE_CLIPS := 35
const MAPS: Array[String] = ["depot", "woodland", "range", "kingsmere"]


func _files(dir: String, ext: String) -> Array[String]:
	var out: Array[String] = []
	for f: String in ResourceLoader.list_directory(dir):
		if f.get_extension() == ext:
			out.append(dir.path_join(f))
	return out


func test_every_model_loads() -> void:
	var count := 0
	for dir: String in MODEL_DIRS:
		for path: String in _files(dir, "glb"):
			var scene := load(path) as PackedScene
			assert_not_null(scene, path)
			if scene:
				var node := scene.instantiate()
				assert_not_null(node, path)
				node.free()
			count += 1
	assert_eq(count, 16, "two figures, five replicas, five part sets, four power sources (the Compact SMG's model and parts, CS2)")


func test_figures_have_their_clips_and_sidecars() -> void:
	for figure: String in ["human", "robot"]:
		var node := (load("res://assets/models/characters/%s.glb" % figure) as PackedScene).instantiate()
		var player := node.find_child("AnimationPlayer", true, false) as AnimationPlayer
		assert_not_null(player, figure)
		if player:
			assert_eq(player.get_animation_list().size(), FIGURE_CLIPS, figure)
		node.free()
		var sidecar: Variant = JSON.parse_string(
			FileAccess.get_file_as_string("res://assets/models/characters/%s.json" % figure)
		)
		assert_true(sidecar is Dictionary, "%s.json parses" % figure)
		if sidecar is Dictionary:
			var keys: Dictionary = sidecar
			assert_true(keys.has("replicaOnGrip"), "%s.json says where replicas sit" % figure)


func test_every_sound_loads_and_loops_loop() -> void:
	var cues := _files("res://assets/audio/cues", "wav")
	assert_eq(cues.size(), 428,
			"the salvage's 362 (the city's calls went with Neon Heights, the motor spin-up and spin-down with BP4), the whistle's 6, the pip, the bombs' 12 (SF1), the doors' 6 (DO1), the spring rifle's cocking 3 (SN1), the BBs on glass, plastic and cardboard 15 and the slide lock 3 (AU2), the doors' second takes 4 (AU5), less the 15 of three replicas' own dry clicks (AU8: one for all), the laser's 5 (LZ1), the Compact SMG's shot, motor and magazines 20 (CS1), the lifts' 6 (MT2)")
	for path: String in cues:
		var s := load(path) as AudioStreamWAV
		assert_true(s != null and s.get_length() > 0.0, path)
	var loops := _files("res://assets/audio/loops", "wav")
	assert_eq(loops.size(), 6, "the browser's yard (its other 3 went with BP4), the owner's room and street by day and night (AU5), woods by day (AU6) and by night (AU9)")
	for path: String in loops:
		var s := load(path) as AudioStreamWAV
		assert_true(s != null and s.loop_mode == AudioStreamWAV.LOOP_FORWARD, "%s loops" % path)


func test_fonts_load() -> void:
	var fonts := _files("res://assets/fonts", "woff2")
	assert_eq(fonts.size(), 11, "Inter's eight and Barlow Condensed's three (UR1, headings)")
	for path: String in fonts:
		var f := load(path) as FontFile
		var family := "Barlow" if path.get_file().begins_with("BarlowCondensed") else "Inter"
		assert_true(f != null and f.get_font_name().begins_with(family), path)
		if f:
			# the main faces carry the latin letters; the "marks" faces only the arrows and the tick
			var main := not path.get_file().begins_with("Inter-marks")
			assert_eq(f.has_char("A".unicode_at(0)), main, "%s latin" % path)
			if not main:
				assert_true(f.has_char(0x2713), "%s has the tick" % path)


func test_map_layouts_parse() -> void:
	for id: String in MAPS:
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json" % id))
		assert_true(data is Dictionary, id)
		if data is Dictionary:
			var map: Dictionary = data
			assert_true(map.has("blocks") and map.has("spawns"), "%s has blocks and spawns" % id)
