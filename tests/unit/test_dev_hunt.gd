extends GutTest
## QA hunt for the Dev tab and dev content (DV2): cheats that must not leak or outlive the box, the tick pacer across
## its rates, Spectate any bot edge cases, Reset the save, what the title screen's Map choice follows, and nodes and
## connections left behind.

const MAIN := preload("res://game/main.tscn")
const DT := 1.0 / 60.0
const ROOT := "user://test-dev-hunt"

var session: PlaySession = null
var s: Settings = null
var dir := ""
var _n := 0


func before_each() -> void:
	_n += 1
	dir = "%s/%d" % [ROOT, _n]
	DirAccess.make_dir_recursive_absolute(dir)
	s = Settings.new(PlayTuning.new())


func after_each() -> void:
	get_tree().paused = false
	InputMap.load_from_project_settings()
	SettingsApply.apply_audio(Settings.new(PlayTuning.new()))


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


func _play(autopilot: bool = false, bots_active: bool = true) -> void:
	session = PlaySession.new()
	session.settings = s
	session.autopilot = autopilot
	session.bots_active = bots_active
	add_child_autofree(session)
	await wait_physics_frames(2)


# --- Cheats ---

func test_turning_every_switch_off_clears_every_cheat_in_the_match() -> void:
	s.dev.game_speed = 2.0
	s.dev.ghost = true
	s.dev.bottomless = true
	s.dev.bots_hold_fire = true
	s.dev.spectate_bots = true
	s.dev.bot_intent = true
	s.dev.retro_filter = true
	await _play()
	assert_true(session.state.cheats.any())
	s.dev.from_dict({})
	s.mark_changed()
	await wait_process_frames(2)
	assert_false(session.state.cheats.any(), "no cheat survives its switch")
	assert_eq(session.state.cheats.game_speed, 1.0)
	assert_false(session.player.ghost)
	assert_false(session.player.armament.bottomless)
	assert_ne(session.spectated(), null)
	assert_eq(session.spectated(), session.player, "back in your own eyes")
	assert_eq(session.find_children("*", "BotIntentView", true, false).size(), 0)
	assert_eq(session.find_children("*", "RetroFilter", true, false).size(), 0)
	assert_true(session.state.off_record, "and the match stays off the record")


func test_cheats_are_the_players_only_never_a_bots() -> void:
	s.dev.ghost = true
	s.dev.bottomless = true
	await _play()
	for c in session.state.characters:
		assert_eq(c.ghost, c == session.player, "ghost on %d" % c.id)
		assert_eq(c.armament.bottomless, c == session.player, "bottomless on %d" % c.id)


func test_a_cheat_off_then_a_new_match_is_back_on_the_record() -> void:
	var state := GameState.new(5, SimTuning.new())
	state.characters.append(Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout()))
	var c := DevCheats.new()
	c.ghost = true
	DevCheats.apply(state, c, 0)
	assert_true(state.off_record)
	DevCheats.apply(state, DevCheats.new(), 0)
	assert_true(state.off_record, "off again: still marked for this match")
	state.off_record = state.dev_content or state.cheats.any()
	assert_false(state.off_record)


# --- The pacer ---

func test_the_pacer_never_loses_or_gains_a_tick_over_a_long_run() -> void:
	for speed: int in [1, 8]:
		for step: int in range(1, 9):
			var rate: float = step * 0.25 * speed
			var p := TickPacer.new()
			p.rate = rate
			var total := 0
			for i in 1000:
				var n := p.ticks()
				assert_gte(n, 0)
				total += n
				for f: float in [0.0, 0.5, 1.0]:
					assert_between(p.fraction(f), 0.0, 1.0, "fraction at rate %s" % rate)
			assert_eq(total, int(1000.0 * rate), "1000 physics ticks at rate %s" % rate)


func test_the_pacer_draws_forward_through_every_slowed_tick() -> void:
	for rate: float in [0.25, 0.5, 0.75]:
		var p := TickPacer.new()
		p.rate = rate
		var last := 0.0
		for i in 400:
			var ran := p.ticks()
			var at := p.fraction(0.0)
			if ran > 0:
				last = at
			else:
				assert_gte(at, last - 1e-9, "no step back at rate %s, frame %d" % [rate, i])
				last = at


# --- Spectate ---

func test_presses_made_while_spectating_fire_nothing_after_leaving_it() -> void:
	s.dev.spectate_bots = true
	await _play(false, false)
	Input.action_press(&"fire")
	await wait_physics_frames(3)
	Input.action_release(&"fire")
	await wait_physics_frames(3)
	s.dev.spectate_bots = false
	s.mark_changed()
	await wait_physics_frames(30)
	assert_eq(session.shots, 0, "no shot kept from the spectating pulls")
	assert_eq(session.spectated(), session.player)


func test_a_followed_bot_going_out_moves_the_view_to_one_in_play() -> void:
	s.dev.spectate_bots = true
	await _play(false, false)
	var first := session.spectated()
	first.status = Character.Status.OUT
	var next := session.spectated()
	assert_ne(next, first)
	assert_ne(next, session.player)
	assert_true(Elimination.is_in_play(next))


func test_with_every_bot_out_spectating_does_not_break_the_view() -> void:
	s.dev.spectate_bots = true
	await _play(false, false)
	for c in session.state.characters:
		if c != session.player:
			c.status = Character.Status.OUT
	var watched := session.spectated()
	assert_not_null(watched)
	await wait_process_frames(2)
	await wait_physics_frames(5)
	assert_not_null(session.spectated())


# --- Reset the save ---

func test_reset_the_save_removes_every_file_and_a_close_does_not_bring_it_back() -> void:
	var path := dir.path_join("settings.save")
	s.sensitivity = 2.0
	assert_true(s.save(path))
	for suffix: String in SaveFile.SUFFIXES:
		var f := FileAccess.open(path + suffix, FileAccess.WRITE)
		f.store_string("{}")
		f.close()
	var screen := SettingsScreen.new()
	screen.settings = s
	screen.save_path = path
	add_child_autofree(screen)
	screen.open()
	screen._speed.value = 150.0
	s.reset_save(path)
	screen._refresh()
	screen.close()
	await wait_process_frames(2)
	for suffix: String in SaveFile.SUFFIXES:
		assert_false(FileAccess.file_exists(path + suffix), "no %s" % suffix)
	assert_eq(s.dev.game_speed, 1.0)
	for i in screen._tabs.get_tab_count():
		assert_false(screen._tabs.is_tab_hidden(i), "every tab, Dev too, still there after (%d)" % i)


func test_reset_the_save_in_a_match_turns_the_cheats_off() -> void:
	s.dev.ghost = true
	s.dev.game_speed = 0.5
	await _play()
	assert_true(session.state.cheats.ghost)
	s.reset_save(dir.path_join("settings.save"))
	assert_false(session.state.cheats.any())
	assert_false(session.player.ghost)


# --- Maps ---

func test_the_catalogue_reads_what_it_can_and_names_the_rest() -> void:
	var m := MapCatalog.parse("# Maps\n\n## Maps\n\n| Id | Name | Kind | Tag | Min | Standard | Max | Blurb |\n"
			+ "|---|---|---|---|---|---|---|---|\n"
			+ "| a | A | field | public | 1 | 3 | 3 | x |\n| a | Again | field | public | 1 | 3 | 3 | x |\n"
			+ "| b | B | arena | public | 1 | 3 | 3 | x |\n| c | C | field | secret | 1 | 3 | 3 | x |\n"
			+ "| d |  | field | dev | 1 | 3 | 3 | x |\n| e | E | range | dev | 1 | 3 | 3 | x |\n")
	assert_eq(m.entries.size(), 2, "a and e")
	assert_eq(m.problems.size(), 4)
	assert_true(m.is_dev("zzz"), "a map with no row is dev")
	assert_true(m.is_dev("e"))
	assert_false(m.is_dev("a"))
	assert_eq(m.fields(true).size(), 1, "a range is never a field")
	assert_eq(MapCatalog.parse("").entries.size(), 0)
	assert_eq(MapCatalog.parse("").fields(true).size(), 0)
	var missing := MapCatalog.read_file("res://data/none.md")
	assert_eq(missing.fields(false).size(), 1)
	assert_eq(missing.entries[0].id, "depot")


func test_the_match_pages_maps_follow_dev_content() -> void:
	var catalog := DevContent.use_map()
	var shared := Settings.shared()
	var was_content := shared.dev.dev_content
	shared.dev.dev_content = false
	var main: Node = add_child_autofree(MAIN.instantiate())
	await wait_process_frames(2)
	var page: MatchPage = main._menus.match_page()
	var public_count := page.map_ids().size()
	assert_eq(public_count, MapCatalog.shared().listed(false).size(), "Dev content off: public maps only")
	shared.dev.dev_content = true
	shared.mark_changed()
	assert_eq(page.map_ids().size(), MapCatalog.shared().listed(true).size())
	assert_gt(page.map_ids().size(), public_count)
	main._picks.map_id = "woodland"
	shared.dev.dev_content = false
	shared.mark_changed()
	assert_eq(page.map_ids().size(), public_count)
	assert_eq(main._picks.map_id, "depot", "a map no longer listed falls back")
	assert_true(page.map_card("depot").is_picked())
	shared.dev.dev_content = was_content
	main.free()
	shared.mark_changed()
	DevContent.restore_map(catalog)


# --- Left behind ---

func test_toggling_the_dev_views_leaves_no_nodes_or_connections() -> void:
	await _play()
	await wait_process_frames(2)
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var wired := s.changed.get_connections().size()
	for i in 6:
		s.dev.bot_intent = true
		s.dev.retro_filter = true
		s.mark_changed()
		s.mark_changed()
		assert_eq(session.find_children("*", "BotIntentView", true, false).size(), 1, "never doubled")
		assert_eq(session.find_children("*", "RetroFilter", true, false).size(), 1, "never doubled")
		s.dev.bot_intent = false
		s.dev.retro_filter = false
		s.mark_changed()
		await wait_process_frames(2)
	assert_eq(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), nodes, "back to the same node count")
	assert_eq(s.changed.get_connections().size(), wired, "no connection added")


func test_a_session_with_every_dev_view_on_frees_clean() -> void:
	s.dev.bot_intent = true
	s.dev.retro_filter = true
	s.dev.spectate_bots = true
	var before := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	await _play()
	await wait_physics_frames(5)
	var apply := session._apply_dev
	session.free()
	session = null
	await wait_process_frames(2)
	assert_false(s.changed.is_connected(apply))
	assert_eq(s.changed.get_connections().size(), 0)
	assert_lte(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), before + 1)
