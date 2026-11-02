extends GutTest
## The assets salvaged from the browser game load in Godot: every model, the figures with their 32 clips and sidecars,
## every sound and loop, the fonts and the map layouts.

const MODEL_DIRS: Array[String] = [
	"res://assets/models/characters",
	"res://assets/models/replicas",
	"res://assets/models/replicaParts",
	"res://assets/models/powerSources",
]
const FIGURE_CLIPS := 32
const MAPS: Array[String] = ["depot", "woodland", "range"]


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
	assert_eq(count, 14, "two figures, four replicas, four part sets, four power sources (the Sniper Rifle's and the spring, SN1)")


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
	assert_eq(cues.size(), 400,
			"the salvage's 372 (the city's calls went with Neon Heights), the whistle's 6, the pip, the bombs' 12 (SF1), the doors' 6 (DO1), the spring rifle's cocking 3 (SN1)")
	for path: String in cues:
		var s := load(path) as AudioStreamWAV
		assert_true(s != null and s.get_length() > 0.0, path)
	var loops := _files("res://assets/audio/loops", "wav")
	assert_eq(loops.size(), 4)
	for path: String in loops:
		var s := load(path) as AudioStreamWAV
		assert_true(s != null and s.loop_mode == AudioStreamWAV.LOOP_FORWARD, "%s loops" % path)


func test_fonts_load() -> void:
	var fonts := _files("res://assets/fonts", "woff2")
	assert_eq(fonts.size(), 8)
	for path: String in fonts:
		var f := load(path) as FontFile
		assert_true(f != null and f.get_font_name().begins_with("Inter"), path)
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
