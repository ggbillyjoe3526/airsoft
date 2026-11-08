extends GutTest
## KI1 QA (known issues before 0.1 Dev 1): the remembered Match page picks on the edges (a map gone or dev, the range, a
## save from before the field, junk values, a newer file), the lean gap beside the cast and SimAudio, a ping beside the
## order wheel opening in the same tick, the web address scrub on edge cases, and the hunt floor on Depot.

const PATH := "user://ki1_qa_progress.save"

var table: LevelTable = LevelTable.shared()
var input: PlayerInput = null


func after_each() -> void:
	DirAccess.remove_absolute(PATH)
	DirAccess.remove_absolute(PATH + ".bak")
	for action: StringName in [&"order_wheel", &"ping"]:
		Input.action_release(action)


func _load(data: Dictionary) -> Progress:
	assert_true(SaveFile.write(PATH, Progress.KIND, Progress.VERSION, data))
	var p := Progress.new(table)
	p.load_file(PATH)
	return p


# --- the remembered picks ---

func test_a_save_from_before_the_field_opens_on_depot_and_alpha_and_keeps_what_it_has() -> void:
	var p := _load({"xp": 40, "unlocked": [], "from_a_later_build": {"a": 1}})
	assert_eq([p.last_map, p.last_team], ["", -1])
	var picks := MatchPicks.new()
	picks.recall(p)
	assert_eq([picks.map_id, picks.team], ["depot", PlaySession.TEAM_ALPHA])
	p.remember_picks("woodland", PlaySession.TEAM_BETA)
	assert_true(p.save(PATH))
	var again := Progress.new(table)
	again.load_file(PATH)
	assert_eq([again.xp, again.last_map, again.last_team], [40, "woodland", PlaySession.TEAM_BETA])
	assert_true(again.to_dict().has("from_a_later_build"), "a key this build doesn't know is kept beside the picks")


func test_a_junk_team_leaves_the_map_and_a_junk_map_leaves_the_team() -> void:
	for team: Variant in [2, -1, 0.5, true, "1", null, [1], 1e30]:
		var p := _load({"last_map": "woodland", "last_team": team})
		var picks := MatchPicks.new()
		picks.recall(p)
		assert_eq([picks.map_id, picks.team], ["woodland", PlaySession.TEAM_ALPHA], "team %s" % str(team))
	for map: Variant in ["", "x".repeat(5000), "../../etc", "Depot", 3, null, ["depot"]]:
		var p := _load({"last_map": map, "last_team": 1})
		var picks := MatchPicks.new()
		picks.recall(p)
		assert_eq([picks.map_id, picks.team], ["depot", PlaySession.TEAM_BETA], "map %s" % str(map).left(12))


func test_a_float_team_from_the_json_is_the_team() -> void:
	# JSON reads every number as a float: 1 is 1.0 on the way back.
	var p := _load({"last_map": "depot", "last_team": 1.0})
	assert_eq(p.last_team, PlaySession.TEAM_BETA)
	assert_eq(_load({"last_team": 0.0}).last_team, PlaySession.TEAM_ALPHA)


func test_the_range_remembered_opens_the_page_on_practice_and_a_field_pick_leaves_it() -> void:
	var picks := MatchPicks.new()
	picks.recall(_load({"last_map": "range", "last_team": 1}))
	var page := MatchPage.new(picks, Settings.new())
	add_child_autofree(page)
	assert_eq(picks.map_id, "range")
	assert_eq(picks.mode, MatchOptions.MODE_PRACTICE, "the range hosts Practice alone")
	assert_eq(page.play_button().text, "PRACTICE")
	assert_eq(picks.team, PlaySession.TEAM_BETA, "the team is kept for the next field")
	page.map_card("depot").pressed.emit()
	assert_eq(picks.mode, MatchOptions.MODE_ATTACK_DEFEND, "off the range, the default mode again (BP8)")
	assert_eq(page.play_button().text, "PLAY")


func test_a_dev_map_remembered_with_dev_content_off_opens_on_depot_and_keeps_the_team() -> void:
	var was := DevContent.use_map()
	var picks := MatchPicks.new()
	picks.recall(_load({"last_map": "woodland", "last_team": 1}))
	assert_eq(picks.map_id, "woodland", "recall takes any map the catalogue has")
	var page := MatchPage.new(picks, Settings.new())
	add_child_autofree(page)
	DevContent.restore_map(was)
	assert_eq([picks.map_id, picks.team], ["depot", PlaySession.TEAM_BETA])
	assert_true(page.map_card("depot").is_picked())
	assert_false(page.play_button().disabled)


func test_a_remembered_map_the_catalogue_now_refuses_falls_back_to_one_that_plays() -> void:
	var picks := MatchPicks.new()
	picks.recall(_load({"last_map": "ghost", "last_team": 0}))
	var was := DevContent.use_map()
	var settings := Settings.new()
	settings.dev.dev_content = true
	var page := MatchPage.new(picks, settings)
	add_child_autofree(page)
	# A catalogue naming a field with no file yet, so MapData refuses it.
	page._catalog = MapCatalog.parse(FileAccess.get_file_as_string(MapCatalog.PATH).replace(
			"| range | Range |", "| ghost | Ghost | field | public | 5 | 5 | 6 | No file yet. |\n| range | Range |"))
	page._offered = PackedStringArray()
	page._list_maps()
	DevContent.restore_map(was)
	assert_true(page.is_unloadable("ghost"))
	assert_eq(picks.map_id, "depot", "the remembered map can't load: the first that can")
	assert_false(page.play_button().disabled)


func test_a_newer_builds_progress_is_never_written_over_by_the_picks() -> void:
	assert_true(SaveFile.write(PATH, Progress.KIND, Progress.VERSION + 1, {"xp": 5, "last_map": "future"}))
	var p := Progress.new(table)
	p.load_file(PATH)
	assert_eq(p.last_map, "", "a newer file is used for nothing")
	p.remember_picks("woodland", 1)
	p.save_if_dirty(PATH)
	var r := SaveFile.read(PATH, Progress.KIND)
	assert_eq(int(r.version), Progress.VERSION + 1, "left as it was")
	assert_eq(r.data.get("last_map"), "future")


func test_resetting_the_level_keeps_the_picks_and_a_damaged_file_forgets_them() -> void:
	var p := _load({"xp": 900, "last_map": "range", "last_team": 1})
	p.reset()
	assert_eq([p.xp, p.last_map, p.last_team], [0, "range", 1], "Reset level is the level, not the picks")
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	var damaged := Progress.new(table)
	damaged.load_file(PATH)
	assert_eq([damaged.last_map, damaged.last_team], ["", -1])
	DirAccess.remove_absolute(PATH + ".damaged")


# --- the lean gap ---

func test_sim_audio_gives_the_tracker_the_configured_lean_gap() -> void:
	var cfg := SoundConfig.new()
	cfg.foley_lean_gap = 1.25
	var audio := SimAudio.new()
	add_child_autofree(audio)
	audio.setup(cfg, [] as Array[StringName], BodyConfig.new(), null, null)
	assert_eq(audio._foley.lean_gap, 1.25)


func test_the_gap_counts_from_the_last_rustle_not_the_last_try_and_a_crouch_is_never_held_back() -> void:
	var tracker := FoleyTracker.new()
	tracker.lean_gap = 0.6
	var c := Character.new(0, 0, Vector3.ZERO)
	var cast: Array[Character] = [c]
	var heard: Array[bool] = []
	var t := 0.0
	# A lean starting every quarter second (steps of 0.125 s, exact in binary): heard at 0.25, then 1.0, then 1.75.
	for i in 8:
		for amount: float in [0.0, 0.4]:
			t += 0.125
			c.prev_lean = c.lean
			c.lean = amount
			tracker.update(cast, t)
			if amount > 0.0:
				heard.append(tracker.moves[0] & FoleyTracker.Move.LEAN != 0)
	assert_eq(heard, [true, false, false, true, false, false, true, false], "a refused try doesn't move the gap on")
	c.prev_crouch_amount = 0.0
	c.crouch_amount = 0.5
	tracker.update(cast, t + 0.01)
	assert_eq(tracker.moves[0] & FoleyTracker.Move.CROUCH, FoleyTracker.Move.CROUCH, "a crouch inside a lean's gap")


func test_the_gap_forgets_a_cast_made_again() -> void:
	var tracker := FoleyTracker.new()
	tracker.lean_gap = 0.6
	var a := Character.new(0, 0, Vector3.ZERO)
	var cast: Array[Character] = [a]
	a.lean = 0.5
	tracker.update(cast, 10.0)
	assert_eq(tracker.moves[0], FoleyTracker.Move.LEAN)
	# A new match: another cast, and the clock starts again from 0.
	var b := Character.new(0, 0, Vector3.ZERO)
	var more: Array[Character] = [b, Character.new(1, 1, Vector3.ZERO)]
	b.lean = 0.5
	tracker.update(more, 0.1)
	assert_eq(tracker.moves[0], FoleyTracker.Move.LEAN, "a new cast starts with no gap")


# --- a ping beside the wheel ---

func _press(action: StringName, pressed: bool = true) -> void:
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)
	var e := InputEventAction.new()
	e.action = action
	e.pressed = pressed
	input._unhandled_input(e)


func _input_ready() -> void:
	var controls := ControlsConfig.new()
	input = PlayerInput.new()
	input.setup(controls, 1.5)
	add_child_autofree(input)
	input.active = true


func test_a_ping_pressed_before_the_wheel_opens_in_the_same_tick_still_goes_and_one_after_does_not() -> void:
	_input_ready()
	_press(&"ping")
	_press(&"order_wheel")
	assert_true(input.wheel().open)
	_press(&"ping")
	var c := PlayerCommand.new()
	input.fill(c)
	assert_true(c.ping, "the press from before the wheel opened is kept")
	_press(&"ping", false)
	_press(&"order_wheel", false)
	assert_false(input.wheel().open)


func test_a_ping_pressed_and_the_wheel_closing_in_the_same_tick_pings_once_and_only_once() -> void:
	_input_ready()
	_press(&"order_wheel")
	_press(&"ping")
	_press(&"order_wheel", false)
	assert_false(input.wheel().open)
	var c := PlayerCommand.new()
	input.fill(c)
	assert_false(c.ping, "pressed while it was open")
	_press(&"ping", false)
	_press(&"ping")
	input.fill(c)
	assert_true(c.ping, "the wheel shut: pings")
	input.fill(c)
	assert_false(c.ping, "once")


func test_a_ping_where_the_wheel_cannot_open_pings() -> void:
	# Out of play (or a range) the wheel does not open, so a "wheel open" check never stands in the ping's way.
	_input_ready()
	input.allow_orders(true, false)
	_press(&"order_wheel")
	assert_false(input.wheel().open)
	_press(&"ping")
	var c := PlayerCommand.new()
	input.fill(c)
	assert_true(c.ping)


# --- the web address scrub ---

func _scrub() -> ReportScrub:
	return ReportScrub.new("/home/zandra/.local/share/airsoft", "/home/zandra", "zandra", "zandra-laptop")


func test_credentials_in_many_shapes_never_leave_the_secret() -> void:
	var s := _scrub()
	var cases: Dictionary[String, String] = {
		"https://user@host/": "user",
		"https://user:hunter2@host.example/": "hunter2",
		"proxy=http://bob:hunter2@10.0.0.1:8080": "hunter2",
		"https://u:p%40ss@h/": "p%40ss",
		"https://a:b@[::1]:80/x": "a:b",
		"https://u1:s1@h1/ https://u2:s2@h2/": "s2",
		"ssh://git:tok3n@github.com/o/r.git": "tok3n",
		"https://user:p@ss@example.com/": "p@ss",
	}
	for text: String in cases:
		var out := s.line(text)
		assert_false(out.contains(cases[text]), "%s -> %s" % [text, out])


func test_a_web_address_without_credentials_and_an_at_in_its_path_is_left_alone() -> void:
	var s := _scrub()
	for text: String in ["https://example.com/@scope/pkg", "see ://", "https://host/a?b=c@d", "https://example.com:443/",
			"at 12:00 //x@y", "res://game/main.gd"]:
		var out := s.line(text)
		assert_false(out.contains("<credentials>"), "%s -> %s" % [text, out])


func test_the_scrub_stays_linear_on_long_lines_of_every_shape() -> void:
	var whole := ReportConfig.new()
	whole.max_line_chars = 0
	var s := ReportScrub.new("", "", "zandra", "zandra-laptop", whole)
	var t := Time.get_ticks_msec()
	for text: String in ["https://" + "a".repeat(200000) + "@h/", "://".repeat(50000), "a://b:c@".repeat(20000),
			"https://" + "@".repeat(100000), ("https://" + "u".repeat(50) + "@").repeat(5000)]:
		s.line(text)
	assert_lt(Time.get_ticks_msec() - t, 3000, "five 100,000-character lines")


# --- map spots ---

func test_a_flag_or_overtime_spot_with_numbers_in_any_form_is_a_spot() -> void:
	var style := MapStyle.new()
	var m := MapData.parse(JSON.stringify({"flag": {"x": 3, "z": -4}, "overtimeFlag": {"x": 1.5, "y": 2, "z": 0}}), style, 1)
	assert_true(m.has_pole and m.has_overtime_flag)
	assert_eq(m.pole, Vector3(3.0, 0.0, -4.0))
	assert_eq(m.overtime_flag, Vector3(1.5, 2.0, 0.0))
	assert_true(m.warnings.is_empty())


func test_a_spot_that_is_not_an_object_is_none_with_a_warning_and_no_error() -> void:
	var style := MapStyle.new()
	for raw: Variant in [3, "x", [1, 2], true, {}, {"x": 1}, {"z": 1}, {"x": 1, "y": null, "z": 1}, {"x": true, "z": 1}]:
		var m := MapData.parse(JSON.stringify({"flag": raw, "overtimeFlag": raw}), style, 1)
		assert_false(m.has_pole or m.has_overtime_flag, JSON.stringify(raw))
		assert_eq(m.warnings.size(), 2, JSON.stringify(raw))


# --- the hunt floor ---

func test_depot_hunt_spots_keep_the_floor_they_had_and_any_new_one_is_reached() -> void:
	var tuning := SimTuning.load_default()
	var play_style: MapStyle = PlayTuning.load_default().map_style
	var map := MapData.load_map("depot", play_style, tuning.rounds.team_size)
	var level := MapLevel.new()
	add_child_autofree(level)
	level.build(map, play_style, tuning.body)
	var nav := NavGrid.build(map, tuning.nav, tuning.body)
	var state := GameState.new(3, tuning)
	var size := tuning.rounds.team_size
	for i in size * 2:
		var at := map.ends[0 if i < size else 1].spawns[i % size].position
		state.characters.append(Character.new(i, 0 if i < size else 1, at, 0.0, ReplicaStats.default_loadout()))
	var bots := BotController.new(state, -1, map, nav, level.query(), tuning, BotConfig.load_default(), {}, {})
	var w := bots.world
	var b := w.bots[0]
	var home := nav.nearest_walkable(b.character.position, nav.snap)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var same := 0
	var gained := 0
	var lo := w.planner.bounds_lo
	var hi := w.planner.bounds_hi
	for i in 4000:
		var spot := Vector3(rng.randf_range(lo.x, hi.x), w.planner.top_y, rng.randf_range(lo.y, hi.y))
		var top := nav.node_at(spot)
		var old_ok := nav.is_walkable_at(spot) and home >= 0 and nav.linked(home, top, true)
		var k := RoundPlanner._reached_floor(nav, home, top)
		if old_ok:
			assert_eq(k, top, "a spot that was drawn before lands on the same floor")
			same += 1
		elif k >= 0:
			gained += 1
			assert_eq(nav.walkable[k], 1)
			assert_true(nav.linked(home, k, true), "a floor the hunt takes is reached")
			assert_lte(nav.floor_y[k], nav.floor_y[top], "lower than the column's top")
	gut.p("depot: %d columns as before, %d more now drawn on a lower floor (of 4000)" % [same, gained])
	assert_gt(same, 0)
