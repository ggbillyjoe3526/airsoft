extends GutTest
## WL9 hunted for what the worker's own tests leave open: the range's layout byte for byte as
## before the move into Depot's site (owner, 2026-10-24), the range's skyline clear of its blocks, no practice target
## inside a solid block, the pause menu's Timed challenge row coming back, an older records file loading clean, the
## Match page after the saved Range and Practice, and Practice resumed on a field after the Loadout.

## SHA-256 of the pretty-printed, key-sorted JSON of the range's gameplay keys, taken from the file as it stood on main
## before WL9 (the dressing is what WL9 changes; none of these keys are dressing). Depot's twin went with DR1, which
## rebuilt Depot as the hall; the old play area is the yard fixture (tests/support/maps/yard.json).
const RANGE_KEYS: Array[String] = ["name", "blocks", "killY", "spawns", "deadZones", "lanes", "targets", "bakedLight",
		"keepClear"]
const RANGE_PLAY_SHA := "d4d59a8b057b0fa2fb7f7e15dd53ef8c66bf221c0bc59bbcbe412110d31d7481"
const MAPS: Array[String] = ["depot", "woodland"]

var tuning: SimTuning = SimTuning.load_default()
var play: PlayTuning = PlayTuning.load_default()


func _sha_of(path: String, keys: Array[String]) -> String:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var out := {}
	for k in keys:
		out[k] = (data as Dictionary).get(k)
	return JSON.stringify(out, "", true).sha256_text()


func test_the_ranges_layout_data_is_exactly_what_it_was_before_it_moved_into_depot() -> void:
	assert_eq(_sha_of("res://data/maps/range.json", RANGE_KEYS), RANGE_PLAY_SHA,
			"blocks, lanes, targets, spawns, dead zones, kill height, baked light and keep-clear are untouched")


func test_the_ranges_skyline_pokes_into_none_of_its_blocks() -> void:
	var map := MapData.load_map("range", play.map_style, 1)
	var v := SkylineView.build(map, play.skyline, play.lighting, BodyConfig.new().stand_eye_height)
	assert_not_null(v, "the range shows Depot's skyline")
	if v == null:
		return
	var pos: PackedVector3Array = v.mesh().surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var inside: Array[String] = []
	for b in map.blocks:
		var lo := b.center - b.size * 0.5 + Vector3.ONE * 0.02
		var hi := b.center + b.size * 0.5 - Vector3.ONE * 0.02
		for q in pos:
			if q.x > lo.x and q.x < hi.x and q.y > lo.y and q.y < hi.y and q.z > lo.z and q.z < hi.z:
				inside.append("%s block at %s holds %s" % [b.kind, b.center, q])
				break
	assert_eq(inside, [] as Array[String], "no skyline piece stands inside the range's walls or lanes")
	assert_eq(v.find_children("*", "CollisionObject3D", true, false).size(), 0, "scenery nobody can hit or stand on")
	v.free()


func test_no_practice_target_stands_inside_a_solid_block_on_any_field() -> void:
	for id in MAPS:
		var map := MapData.load_map(id, MapStyle.new(), 1)
		var level := MapLevel.new()
		add_child(level)
		level.build(map, MapStyle.new(), tuning.body)
		var nav := NavGrid.build(map, tuning.nav, tuning.body)
		var specs := PracticeSpots.layout(map, nav, level.query(), tuning)
		var cfg := tuning.targets
		var bad: Array[String] = []
		for t in specs:
			# A body column from knee to head over the target's own x, z (a plate's post and a figure alike).
			var feet := t.position.y - (cfg.start_height if t.start else (cfg.plate_height if t.kind == RangeTarget.Kind.STEEL else 0.0))
			for b in map.blocks:
				if b.kind == &"floor" or b.kind == &"ramp":
					continue
				var lo := b.center - b.size * 0.5
				var hi := b.center + b.size * 0.5
				if t.position.x > lo.x and t.position.x < hi.x and t.position.z > lo.z and t.position.z < hi.z \
						and feet + 0.4 < hi.y and feet + 1.4 > lo.y:
					bad.append("%s %s at %s in %s block at %s" % [id, t.label, t.position, b.kind, b.center])
					break
		assert_eq(bad, [] as Array[String], id)
		level.free()


func test_the_pause_menus_timed_challenge_row_comes_back_for_a_map_with_room() -> void:
	var menu := PauseMenu.new()
	add_child_autofree(menu)
	menu.set_practice("Woodland", false, 0, false)
	assert_false(menu.challenge_button().visible, "no room for START: no row")
	menu.set_practice("Depot", false, 0, true)
	assert_true(menu.challenge_button().visible, "room for START: the row")
	menu.set_practice("Depot", true, 3)
	assert_true(menu.challenge_button().visible, "the default is a row")


func test_an_older_records_file_loads_without_a_warning_and_a_range_best_survives() -> void:
	var r := Records.new()
	assert_eq(r.from_dict({"results": {}, "streak": 1}).size(), 0, "no timed challenge bests yet: not a problem")
	var r2 := Records.new()
	assert_eq(r2.from_dict({"best_challenge": {"range": 11, "neonHeights": 9}}).size(), 0,
			"a best on a map taken out of the game (Neon Heights) reads without a problem")
	assert_eq(r2.challenge_best("range"), 11)
	assert_eq(r2.challenge_best("woodland"), 0, "a map never played has no best")
	var run := RangeChallenge.Run.new()
	run.hits = 4
	assert_true(r2.add_challenge_run("woodland", run), "a field's id is a valid course")


func test_a_saved_range_and_practice_then_a_field_does_not_come_back_as_practice_by_surprise() -> void:
	var picks := MatchPicks.new()
	picks.map_id = "range"
	picks.mode = MatchOptions.MODE_PRACTICE
	var settings := Settings.new()
	settings.dev.dev_content = true
	var page := MatchPage.new(picks, settings)
	add_child_autofree(page)
	page.map_card("depot").pressed.emit()
	assert_eq(picks.mode, MatchOptions.DEFAULT_MODE, "the Range forced Practice: a field opens on the default mode")
	# Practice picked on a field still carries to the next field.
	page.mode_card(MatchOptions.MODE_PRACTICE).pressed.emit()
	page.map_card("woodland").pressed.emit()
	assert_eq(picks.mode, MatchOptions.MODE_PRACTICE)


func test_practice_resumed_on_a_field_puts_you_back_and_lays_out_the_same_targets() -> void:
	var first := PlaySession.new()
	first.practice = true
	first.map_id = "woodland"
	first.match_seed = 77
	first.settings = Settings.new()
	add_child_autofree(first)
	var spot := PracticeSpot.of(first.player, 1.0, -0.2, false, false, 77)
	spot.position = first.player.position + Vector3(2.0, 0.0, 0.0)
	var specs_a := _signature(first.state.targets)
	assert_gt(first.state.targets.size(), 10)
	first.queue_free()
	await wait_physics_frames(2)
	var second := PlaySession.new()
	second.practice = true
	second.map_id = "woodland"
	second.match_seed = 77
	second.resume = spot
	second.settings = Settings.new()
	add_child_autofree(second)
	assert_eq(_signature(second.state.targets), specs_a, "the same layout again")
	assert_almost_eq(second.player.position.x, spot.position.x, 0.01, "put back where you stood")
	assert_almost_eq(second.player.position.z, spot.position.z, 0.01)


func _signature(targets: Array[RangeTarget]) -> PackedStringArray:
	var out := PackedStringArray()
	for t in targets:
		out.append("%s %s %.3f" % [t.label, t.home, t.yaw])
	return out
