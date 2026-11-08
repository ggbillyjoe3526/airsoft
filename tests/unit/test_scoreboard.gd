extends GutTest
## The scoreboard while Tab is held (SB1; concept `scoreboard.png`): the map, mode, bots and size, the round and its
## time left; your team first and you first; this round's hits and the match's numbers per player, those out greyed;
## each team's count in play; a Pro tip against Hard bots only, one per round in order; the teammate markers hide under
## it, and the board refills as the field moves.

var session: PlaySession = null


func _session(difficulty: StringName = &"easy") -> PlaySession:
	var s := PlaySession.new()
	s.bots_active = false
	s.difficulty = difficulty
	add_child_autofree(s)
	return s


func _show(hud: Hud) -> void:
	hud.show_board(true)
	hud.update(session.state, 1.0, 0.0)


func _hit(shooter: int, victim: int) -> void:
	var state := session.state
	state.events.clear()
	var e := state.events.add(GameEvent.Kind.CHARACTER_HIT)
	e.actor = shooter
	e.target = victim
	session.match_stats().after_tick(state, 0.0)
	state.events.clear()


func test_the_tips_come_one_per_round_in_order_then_round_again() -> void:
	assert_eq(HudScoreboard.tip_for(1), &"PRO_TIP_1")
	assert_eq(HudScoreboard.tip_for(2), &"PRO_TIP_2")
	assert_eq(HudScoreboard.tip_for(HudScoreboard.PRO_TIPS.size() + 1), &"PRO_TIP_1")


func test_tab_shows_the_board_only_while_held_and_only_in_play() -> void:
	var input := PlayerInput.new()
	add_child_autofree(input)
	Input.action_press(&"scoreboard")
	assert_false(input.scoreboard_held(), "not while a menu has the mouse")
	input.active = true
	assert_true(input.scoreboard_held())
	Input.action_release(&"scoreboard")
	assert_false(input.scoreboard_held())
	assert_eq(KeyBindings.DEFAULTS[&"scoreboard"], [KEY_TAB])


func test_the_board_names_the_match_and_lists_your_team_first() -> void:
	session = _session()
	await wait_physics_frames(2)
	var hud := session.hud()
	var board := hud.board()
	hud.update(session.state, 1.0, 0.0)
	assert_false(board.visible, "hidden until Tab is held")
	_show(hud)
	assert_true(board.visible)
	var size := session._tuning.rounds.team_size
	assert_string_starts_with(board.table().heading_text(), "DEPOT · ELIMINATION · EASY BOTS · %d V %d · ROUND 1 · "
			% [size, size])
	assert_string_ends_with(board.table().heading_text(), " LEFT")
	var notes := board.table().team_notes()
	assert_eq(notes[0], "YOUR TEAM · %d OF %d IN PLAY" % [size, size])
	assert_eq(notes[1], "%d OF %d IN PLAY" % [size, size])
	var lines := board.table().lines()
	assert_eq(lines.size(), size * 2)
	assert_eq(lines[0], "You | 0 | 0 | 0 | 0 | – | 0:00", "you first; no BB yet, no accuracy")
	assert_eq(board.tip_text(), "", "no tip against Easy bots")


func test_the_board_follows_the_field_while_it_is_up() -> void:
	session = _session()
	await wait_physics_frames(2)
	var hud := session.hud()
	var board := hud.board()
	_show(hud)
	var state := session.state
	var mate := state.characters[1]
	var size := session._tuning.rounds.team_size
	_hit(size, 1) # their first player hits your first teammate
	mate.status = Character.Status.OUT
	hud.update(state, 1.0, 0.0)
	var lines := board.table().lines()
	assert_string_starts_with(lines[1], session._bots.name_of(1) + " OUT | 0 | 0 | 1 |", "out and hit once")
	assert_eq(board.table().team_notes()[0], "YOUR TEAM · %d OF %d IN PLAY" % [size - 1, size])
	assert_string_starts_with(lines[size], session._bots.name_of(size) + " | 1 | 1 | 0 |",
			"their first player's hit, this round too")
	mate.status = Character.Status.ALIVE


func test_the_teammate_markers_hide_under_the_board() -> void:
	session = _session()
	await wait_physics_frames(2)
	var hud := session.hud()
	var state := session.state
	var camera := Camera3D.new()
	add_child_autofree(camera)
	var mate := state.characters[1]
	mate.position = Vector3(20.0, 0.0, -8.0)
	mate.prev_position = mate.position
	camera.global_position = Vector3(20.0, 1.6, 0.0)
	camera.look_at(Vector3(20.0, 1.6, -8.0))
	hud.place_team_markers(camera, state.characters, session.player, 1.0)
	assert_true(hud.team_markers().is_shown(mate.id))
	_show(hud)
	hud.place_team_markers(camera, state.characters, session.player, 1.0)
	assert_false(hud.team_markers().is_shown(mate.id))


func test_against_pro_bots_a_tip_shows_for_the_round() -> void:
	session = _session(&"hard")
	await wait_physics_frames(2)
	var hud := session.hud()
	_show(hud)
	assert_eq(hud.board().tip_text(), tr("PRO_TIP_1"))
	assert_string_contains(hud.board().table().heading_text(), "HARD BOTS")


func test_in_overtime_the_board_counts_the_overtime_down_and_keeps_moving() -> void:
	var s := PlaySession.new()
	s.bots_active = false
	s.mode = MatchOptions.MODE_ATTACK_DEFEND
	add_child_autofree(s)
	session = s
	await wait_physics_frames(2)
	RoundHold.release(session.state)
	var hud := session.hud()
	var state := session.state
	var rs := state.round_state
	rs.clock = 0.0
	rs.overtime = 1.0
	_show(hud)
	var max_ot := SimTuning.new().flag.max_overtime
	assert_string_ends_with(hud.board().table().heading_text(),
			"ROUND 1 · OVERTIME %s" % HudStyle.clock_text(ceili(max_ot - 1.0)))
	rs.overtime = 5.0
	state.time += 4.0
	session.match_stats().after_tick(state, 4.0)
	hud.update(state, 1.0, 0.0)
	assert_string_ends_with(hud.board().table().heading_text(), HudStyle.clock_text(ceili(max_ot - 5.0)))
	assert_string_ends_with(hud.board().table().lines()[0], " | 0:04", "time in play still moves in overtime")


func test_the_pause_menu_hides_the_board() -> void:
	session = _session()
	await wait_physics_frames(2)
	var hud := session.hud()
	_show(hud)
	session._open_pause()
	assert_false(hud.board().visible)
	session._resume()


func test_bbs_alone_refill_the_board_at_most_every_refill_gap() -> void:
	session = _session()
	await wait_physics_frames(2)
	var hud := session.hud()
	var state := session.state
	_show(hud)
	state.events.clear()
	state.events.add(GameEvent.Kind.SHOT).actor = 0
	session.match_stats().after_tick(state, 0.0)
	state.events.clear()
	hud.update(state, 1.0, 0.0)
	assert_string_starts_with(hud.board().table().lines()[0], "You | 0 | 0 | 0 | 0 |", "not yet: a BB alone waits")
	state.time += PlayTuning.new().hud.board_refill_gap * 2.0
	hud.update(state, 1.0, 0.0)
	assert_string_starts_with(hud.board().table().lines()[0], "You | 0 | 0 | 0 | 1 |", "then the BB shows")
