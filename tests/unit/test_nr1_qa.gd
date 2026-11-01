extends GutTest
## NR1 hunted for what Neon Heights' removal and Woodland and its Weapon Torch going public (2026-10-29) leave open: a
## missing map file read without an engine error, the shipped tables with nothing dev, a Woodland night match on the
## record, a bot night torch that is not dev content, no loop or cue of the gone city left in the sound tables, and
## a map no longer in the game reaching the crash screen's words.

const GONE := "neonHeights"
const TORCH := "000020"


func test_a_gone_maps_presets_read_day_alone_and_load_refuses_it_cleanly() -> void:
	assert_eq(MapData.presets_in(GONE), [&"day"] as Array[StringName])
	var m := MapData.load_map(GONE, MapStyle.new(), 1)
	assert_false(m.problems.is_empty(), "a refused map says why")


func test_no_shipped_map_or_item_is_dev_and_the_range_is_listed() -> void:
	var cat := MapCatalog.read_file()
	for e in cat.listed(false):
		assert_false(cat.is_dev(e.id), e.id)
	var ids := PackedStringArray()
	for e in cat.listed(false):
		ids.append(e.id)
	assert_eq(ids, PackedStringArray(["depot", "woodland", "street", "range"]))
	assert_eq(cat.listed(true).size(), cat.listed(false).size(), "Dev content hides nothing now")
	var pool := Pool.read_file()
	var every: Array[Pool.Item] = []
	every.append_array(pool.replicas)
	every.append_array(pool.powers)
	every.append_array(pool.parts)
	for it in every:
		assert_false(it.is_dev(), it.display_name)


func test_the_torch_is_a_night_light_for_bots_without_dev_content() -> void:
	var rules := LoadoutRules.standard()
	assert_false(rules.dev_content)
	var light := BotKits.night_light(rules)
	assert_not_null(light)
	assert_eq(light.id, TORCH)
	assert_false(light.is_dev())


func test_a_woodland_night_match_counts_on_the_record() -> void:
	var s := Settings.new(PlayTuning.new())
	var session := PlaySession.new()
	session.settings = s
	session.map_id = "woodland"
	session.lighting_pick = LightingConfig.NIGHT # its second time of day since WR1
	session.autopilot = true
	add_child_autofree(session)
	await wait_physics_frames(3)
	assert_not_null(session.state)
	assert_true(session.state.characters.size() > 2)
	assert_false(session.state.dev_content, "a public map, the public torch")
	assert_false(session.state.off_record, "Woodland by night is on the record")
	var lit := 0
	for c in session.state.characters:
		for l in c.armament.lights:
			if l != null:
				lit += 1
	assert_gt(lit, 0, "the bots carry the torch")


func test_nothing_of_the_gone_map_is_left_on_disk() -> void:
	for f: String in ["neon", "traffic", "drones"]:
		assert_false(FileAccess.file_exists("res://assets/audio/loops/%s.wav" % f), f)
		assert_false(FileAccess.file_exists("res://assets/audio/loops/%s.wav.import" % f), f)
	assert_false(FileAccess.file_exists("res://data/maps/%s.json" % GONE))
	assert_false(FileAccess.file_exists("res://assets/maps/%s.jpg" % GONE))
	assert_false(FileAccess.file_exists("res://assets/maps/%s.jpg.import" % GONE))


func test_a_record_of_the_gone_map_is_worded_without_a_catalogue_entry() -> void:
	assert_eq(ReportFacts.practice_text(GONE), ReportFacts.PRACTICE + ReportFacts.SEP + GONE.capitalize())
	assert_null(MapCatalog.read_file().find(GONE))
