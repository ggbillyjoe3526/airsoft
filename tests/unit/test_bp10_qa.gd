extends GutTest
## QA for the 0.1 Beta 2 pass's fixes (BP10) beyond test_bp10_fixes.gd: coming back in a PlaySession (facing, toggles,
## the HUD's cards, the watched teammate), the round table's "Still in", a bot rejoining under Elimination's overtime
## flag, and the edges of the loadout menu, the plant prompt and the train announcer.

const K := GameEvent.Kind
const LOADOUTS := "user://test_bp10_qa_loadouts.save"
const SETTINGS := "user://test_bp10_qa_settings.save"
const DT := 1.0 / 60.0

var loadout: Array[ReplicaConfig] = ReplicaStats.default_loadout()


func after_each() -> void:
	await wait_process_frames(2)
	SaveFile.remove(LOADOUTS)
	SaveFile.remove(SETTINGS)
	get_tree().paused = false


func _session() -> PlaySession:
	var s := PlaySession.new()
	s.bots_active = false
	s.difficulty = &"easy"
	s.settings = Settings.new()
	s.settings.what_got_you = Settings.WhatGotYou.ON
	add_child_autofree(s)
	return s


func _tick(s: PlaySession, kind: GameEvent.Kind, actor: int = -1, target: int = -1) -> void:
	s.state.events.clear()
	var e := s.state.events.add(kind)
	e.actor = actor
	e.target = target
	s._after_tick()
	s.state.events.clear()


func _foe(s: PlaySession) -> int:
	for c in s.state.characters:
		if c.team != s.player.team:
			return c.id
	return -1


# --- coming back in a session ---

func test_coming_back_faces_the_way_the_character_stands_and_lets_go_of_a_toggled_aim_and_crouch() -> void:
	var s := _session()
	await wait_physics_frames(2)
	s.player.yaw = 1.25
	s._input.view_yaw = -2.0
	s._input._aimed = true
	s._input._crouched = true
	_tick(s, K.RESPAWNED, 5)
	assert_eq(s._input.view_yaw, -2.0, "someone else's return leaves your view alone")
	assert_true(s._input._aimed, "and your toggles")
	_tick(s, K.RESPAWNED, PlaySession.PLAYER_ID)
	assert_eq(s._input.view_yaw, 1.25, "the mouse turned while out: back in, the spawn's way")
	assert_false(s._input._aimed, "a toggled aim is let go")
	assert_false(s._input._crouched, "a toggled crouch is let go")


func test_coming_back_clears_what_got_you_and_the_kept_hit_lines_but_not_for_a_teammate() -> void:
	var s := _session()
	await wait_physics_frames(2)
	var foe := _foe(s)
	_tick(s, K.CHARACTER_HIT, foe, PlaySession.PLAYER_ID)
	assert_not_null(s.hud().what_got_you(), "hit by a foe: the card")
	s.hud()._hits.add(foe, PlaySession.PLAYER_ID, 0.0, true)
	var kept := false
	for i in s.hud()._hits.count():
		kept = kept or s.hud()._hits.line(i).keep
	assert_true(kept, "a kept line is up")
	_tick(s, K.RESPAWNED, foe)
	assert_not_null(s.hud().what_got_you(), "a foe coming back keeps your card")
	_tick(s, K.RESPAWNED, PlaySession.PLAYER_ID)
	await wait_process_frames(1)
	assert_null(s.hud().what_got_you(), "your own return takes it down")
	for i in s.hud()._hits.count():
		assert_false(s.hud()._hits.line(i).keep, "and lets the kept lines age out")


func test_a_teammate_coming_back_does_not_take_the_view_you_hold_out_in_the_dead_zone() -> void:
	var s := _session()
	await wait_physics_frames(2)
	var mates: Array[Character] = []
	for c in s.state.characters:
		if c.team == s.player.team and c != s.player:
			mates.append(c)
	assert_gte(mates.size(), 2, "a squad of at least three")
	s.player.status = Character.Status.OUT
	var first := s.spectated()
	assert_eq(first, mates[0], "the first teammate in play")
	first.status = Character.Status.OUT
	var second := s.spectated()
	assert_ne(second, first)
	first.status = Character.Status.ALIVE
	assert_eq(s.spectated(), second, "the earlier teammate back in play does not take the view")
	second.status = Character.Status.OUT
	assert_ne(s.spectated(), second, "the one watched hit: the view moves on")
	for m in mates:
		m.status = Character.Status.ALIVE
	s.player.status = Character.Status.ALIVE


func test_with_the_whole_team_out_the_view_falls_back_and_never_keeps_a_foe() -> void:
	var s := _session()
	await wait_physics_frames(2)
	s.player.status = Character.Status.OUT
	var mate := s.spectated()
	assert_eq(mate.team, s.player.team)
	for c in s.state.characters:
		if c.team == s.player.team:
			c.status = Character.Status.OUT
	var seen := s.spectated()
	assert_ne(seen.team, s.player.team, "anyone in play")
	mate.status = Character.Status.ALIVE
	assert_eq(s.spectated(), mate, "a teammate back: the view returns to the team")
	for c in s.state.characters:
		c.status = Character.Status.ALIVE


# --- the round table ---

func _row_state() -> Array:
	var state := GameState.new(1)
	state.characters.append(Character.new(0, 0, Vector3.ZERO, 0.0, loadout))
	state.characters.append(Character.new(1, 0, Vector3.ZERO, 0.0, loadout))
	state.characters.append(Character.new(2, 1, Vector3.ZERO, 0.0, loadout))
	var stats := MatchStats.new()
	state.events.add(K.ROUND_START).value = 1
	var hit := state.events.add(K.CHARACTER_HIT)
	hit.actor = 2
	hit.target = 0
	hit = state.events.add(K.CHARACTER_HIT)
	hit.actor = 2
	hit.target = 1
	stats.after_tick(state, DT)
	state.events.clear()
	return [state, stats]


func _table_rows(state: GameState, stats: MatchStats, you: Character) -> Array:
	var r := HudRoundResult.new()
	add_child_autofree(r)
	r.setup(HudConfig.new(), TeamConfig.new(), RoundConfig.new(), Color.WHITE)
	r.round_over(1, 30, 0.0)
	state.time = 1000.0
	r.update(state, stats, you)
	assert_true(r.is_up(), "the table is up")
	return r.table()._rows


func test_the_round_table_says_still_in_for_one_hit_and_back_in_play_and_dims_the_one_still_out() -> void:
	var made := _row_state()
	var state: GameState = made[0]
	var stats: MatchStats = made[1]
	assert_eq(stats.round_of(0).hit_by, 2, "the fixture's hit")
	state.characters[0].status = Character.Status.ALIVE # hit, then respawned
	state.characters[1].status = Character.Status.OUT
	var rows := _table_rows(state, stats, state.characters[0])
	var you_row: Variant = rows[0]
	assert_eq(you_row.cells[3], tr("HUD_STILL_IN"), "back in play: still in")
	assert_false(you_row.out, "and not dimmed")
	var mate_row: Variant = rows[1]
	assert_ne(mate_row.cells[3], tr("HUD_STILL_IN"), "hit and still out: the shooter's name")
	assert_true(mate_row.out, "dimmed")


func test_a_row_never_hit_is_still_in_and_a_waiting_character_is_not() -> void:
	var made := _row_state()
	var state: GameState = made[0]
	var stats: MatchStats = made[1]
	state.characters[0].status = Character.Status.OUT
	state.characters[0].respawn_left = 3.0
	var rows := _table_rows(state, stats, state.characters[0])
	assert_true(rows[0].out, "waiting to come back at the table is out, as the table is read")
	var shooter_row: Variant = rows[rows.size() - 1]
	assert_eq(shooter_row.cells[3], tr("HUD_STILL_IN"), "never hit")
	assert_false(shooter_row.out)


# --- a bot rejoining under the overtime flag ---

func _overtime_world(flag_up: bool) -> Array:
	var tuning := SimTuning.load_default()
	var map := MapData.load_map("depot", MapStyle.new(), tuning.rounds.team_size)
	var level := MapLevel.new()
	add_child_autofree(level)
	level.build(map, MapStyle.new(), tuning.body)
	var nav := NavGrid.build(map, tuning.nav, tuning.body)
	var state := GameState.new(3, tuning)
	var size := tuning.rounds.team_size
	var identities: Dictionary[int, BotRoster.Identity] = {}
	for i in size * 2:
		state.characters.append(Character.new(i, 0 if i < size else 1, Vector3.ZERO, 0.0, loadout))
	var levels: Dictionary[int, StringName] = {0: &"normal", 1: &"normal"}
	var bots := BotController.new(state, -1, map, nav, level.query(), tuning, BotConfig.load_default(), levels, identities)
	var sim := Simulation.new(tuning, level.query(), level.mover(tuning.body), map.ends, map.kill_y)
	sim.nav = nav
	state.round_state.has_overtime_spot = true
	state.round_state.overtime_spot = map.overtime_flag
	sim.start_match(state)
	bots.observe(state)
	state.time = 100.0
	if flag_up:
		state.round_state.overtime_flag.raise(map.overtime_flag)
	return [state, bots]


func _rejoin(state: GameState, bots: BotController, id: int) -> void:
	state.events.clear()
	state.events.add(K.RESPAWNED).actor = id
	bots.observe(state)
	state.events.clear()


func test_a_bot_coming_back_under_the_overtime_flag_sets_off_for_it_and_one_back_with_it_down_does_not() -> void:
	for up: bool in [true, false]:
		var made := _overtime_world(up)
		var state: GameState = made[0]
		var bots: BotController = made[1]
		var b: Bot = bots.world.bots[bots.world.bots.size() - 1]
		b.overtime_at = -1.0
		_rejoin(state, bots, b.character.id)
		if up:
			var r := b.skill.overtime_reaction
			assert_between(b.overtime_at - state.time, r.x, r.y, "its reaction counted from its return")
		else:
			assert_eq(b.overtime_at, INF, "no flag: a fresh life with no errand for it")


func test_a_return_for_a_character_no_bot_drives_is_ignored() -> void:
	var made := _overtime_world(true)
	var state: GameState = made[0]
	var bots: BotController = made[1]
	_rejoin(state, bots, 9999)
	_rejoin(state, bots, -1)
	assert_true(true, "no error")


# --- the loadout menu's edges ---

func _strip() -> LoadoutStrip:
	SaveFile.remove(LOADOUTS)
	SaveFile.remove(SETTINGS)
	var saved := SavedLoadouts.new(LoadoutRules.standard())
	var page := LoadoutPage.new(saved, Settings.new())
	page.save_path = LOADOUTS
	page.settings_path = SETTINGS
	add_child_autofree(page)
	var strip := page.strip()
	strip.new_card().pressed.emit()
	strip.new_card().pressed.emit()
	saved.use(0)
	return strip


func test_the_menu_key_on_another_card_opens_its_menu_under_that_card_with_the_keys_kept() -> void:
	var strip := _strip()
	await wait_process_frames(2)
	var card := strip.card(2)
	card.grab_focus()
	var key := InputEventKey.new()
	key.keycode = KEY_MENU
	key.pressed = true
	card.gui_input.emit(key)
	await wait_process_frames(2)
	assert_eq(strip.saved.current, 2, "it carries the card")
	assert_true(strip.card(2).has_focus(), "the keys stay on it")
	var expected := Vector2i((strip.card(2).get_screen_position() + Vector2(0.0, strip.card(2).size.y)).round())
	assert_eq(strip.menu().position, expected, "the menu hangs under the card")
	strip.menu().hide()


func test_a_duplicate_from_a_mouse_opened_menu_does_not_grab_the_keyboard() -> void:
	var strip := _strip()
	await wait_process_frames(2)
	strip.open_menu(1, Vector2(4.0, 4.0))
	strip.pick(LoadoutStrip.MenuItem.DUPLICATE)
	await wait_process_frames(2)
	for i in strip.saved.slots.size():
		assert_false(strip.card(i).has_focus(), "card %d" % i)
	strip.menu().hide()


func test_the_menu_ignores_an_index_off_the_strip_and_a_menu_without_a_card_to_open_on() -> void:
	var strip := _strip()
	await wait_process_frames(2)
	var current := strip.saved.current
	strip.open_menu(-1)
	strip.open_menu(99)
	assert_eq(strip.saved.current, current, "nothing carried")
	if strip.menu() != null:
		assert_false(strip.menu().visible)


func test_a_keyboard_duplicate_at_the_slot_limit_changes_nothing() -> void:
	var strip := _strip()
	while strip.saved.slots.size() < SavedLoadouts.MAX_SLOTS:
		strip.new_card().pressed.emit()
	await wait_process_frames(2)
	var n := strip.saved.slots.size()
	strip.card(0).grab_focus()
	strip.open_menu(0)
	assert_true(strip.menu_disabled(LoadoutStrip.MenuItem.DUPLICATE))
	strip.pick(LoadoutStrip.MenuItem.DUPLICATE)
	assert_eq(strip.saved.slots.size(), n)
	assert_true(strip.card(0).has_focus())
	strip.menu().hide()


# --- the plant prompt ---

func test_the_quiet_line_shows_for_a_zero_quiet_time_never_and_follows_a_prompt_that_comes_and_goes() -> void:
	var p := HudPlantPrompt.new(0.0)
	add_child_autofree(p)
	p.show_for(HudPlant.Prompt.NONE, true, 0.0, true)
	assert_false(p._quiet.visible, "a zero quiet time: no line")
	var q := HudPlantPrompt.new(2.5)
	add_child_autofree(q)
	q.show_for(HudPlant.Prompt.NONE, true, 0.0, true)
	assert_true(q._quiet.visible)
	q.show_for(HudPlant.Prompt.NONE, false, 0.1, true)
	q.show_for(HudPlant.Prompt.NONE, false, 5.0, true)
	q.show_for(HudPlant.Prompt.NONE, true, 0.1, true)
	assert_false(q._quiet.visible, "setting it down for longer than the quiet time: not told again")
	q.show_for(HudPlant.Prompt.NONE, false, 0.0, false)
	q.show_for(HudPlant.Prompt.NONE, true, 0.0, false)
	assert_true(q._quiet.visible, "an older caller who passes no holding: carrying times it, as before")


# --- the train announcer ---

func test_a_null_listener_never_starts_an_announcement_and_a_new_match_still_cuts_one() -> void:
	var tuning := load("res://game/config/play_tuning.tres") as PlayTuning
	var subway := MapData.load_map("subway", MapStyle.new(), 1)
	var audio := SimAudio.new()
	add_child_autofree(audio)
	audio.setup(tuning.sound, [] as Array[StringName], BodyConfig.new(), null, subway)
	var state := GameState.new(3)
	state.match_number = 1
	var inside := subway.trains[0].cars[0].middle
	state.characters.append(Character.new(0, 0, inside))
	for k in 400:
		state.time = k * 0.5
		audio.on_tick(state, 0, null)
	assert_false(audio._announcer.playing, "nobody listening: silence")
	state.round_state.phase = RoundState.Phase.MATCH_OVER
	for k in 400:
		state.time = 300.0 + k * 0.5
		audio.on_tick(state, 0, state.characters[0])
	assert_false(audio._announcer.playing, "the results: silence")
