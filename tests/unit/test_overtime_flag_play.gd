extends GutTest
## Elimination's overtime flag on screen and in sound (OV3; concept `overtime-flag.png`): the flag built once a match
## and hidden until it goes up, rising in 0.8 s (at once under Reduced motion), its cloth turned to the view, chequered
## off-white and dark with its ring, both in the toucher's colour once touched and clear of the team hues until then, scenery only; the three short
## whistle blasts and the banner; the score bar's and the scoreboard's OT; the marker with the chequered glyph and the
## minimap's; FLAG TOUCHED, the round's table and the screen reader's lines; nothing allocated with it down.

const DT := 1.0 / 60.0

var session: PlaySession = null


func _session(mode: String = MatchOptions.MODE_ELIMINATION, reduced: bool = false) -> PlaySession:
	var s := PlaySession.new()
	s.mode = mode
	s.bots_active = false
	s.settings = Settings.new(PlayTuning.new())
	s.settings.reduced_motion = Settings.ReducedMotion.ON if reduced else Settings.ReducedMotion.OFF
	add_child_autofree(s)
	session = s
	return s


func _view() -> OvertimeFlagView:
	var view := OvertimeFlagView.new()
	view.setup(PlayTuning.new().flag, PlayTuning.new().teams, Vector3(2.0, 0.0, 1.6), OvertimeConfig.new().reach)
	add_child_autofree(view)
	return view


func _up(flag: OvertimeFlag) -> OvertimeFlag:
	flag.reset(OvertimeConfig.new())
	flag.raise(Vector3(2.0, 0.0, 1.6))
	return flag


func after_each() -> void:
	get_tree().paused = false


# --- the flag in the world ---

func test_hidden_until_it_goes_up_then_it_rises_in_its_time() -> void:
	var view := _view()
	var cfg := PlayTuning.new().flag
	var flag := OvertimeFlag.new()
	view.refresh(flag, -1, DT)
	assert_false(view.visible, "down: hidden")
	_up(flag)
	view.refresh(flag, -1, DT)
	assert_true(view.visible)
	assert_eq(view.position, Vector3(2.0, 0.0, 1.6), "at the map's spot")
	assert_almost_eq(view.risen(), cfg.overtime_rise_from, 1e-4, "out of the ground")
	var t := 0.0
	while t < cfg.overtime_rise * 0.5 - 1e-6:
		view.refresh(flag, -1, DT)
		t += DT
	assert_between(view.risen(), 0.5, 0.999, "half way through its rise, eased out")
	while t < cfg.overtime_rise + DT:
		view.refresh(flag, -1, DT)
		t += DT
	assert_eq(view.risen(), 1.0, "standing after 0.8 s")
	assert_almost_eq(cfg.overtime_rise, 0.8, 1e-6)
	flag.reset(OvertimeConfig.new())
	view.refresh(flag, -1, DT)
	assert_false(view.visible, "down again for the next round")


func test_its_cloth_turns_to_face_the_view() -> void:
	var view := _view()
	view.face(Vector3(20.0, 1.7, 1.6))
	assert_eq(view.facing(), 0.0, "down: nothing turns")
	view.refresh(_up(OvertimeFlag.new()), -1, DT)
	for eye: Vector3 in [Vector3(14.0, 1.7, 1.6), Vector3(2.0, 1.7, 13.6), Vector3(-10.0, 1.7, -10.4)]:
		view.face(eye)
		var normal := Vector3.BACK.rotated(Vector3.UP, view.facing())
		var towards := Vector3(eye.x - 2.0, 0.0, eye.z - 1.6).normalized()
		assert_almost_eq(normal.dot(towards), 1.0, 1e-4, "the cloth's face towards %s" % eye)


func test_under_reduced_motion_it_stands_at_once() -> void:
	var view := _view()
	view.rises = false
	view.refresh(_up(OvertimeFlag.new()), -1, DT)
	assert_eq(view.risen(), 1.0)


func test_off_white_until_touched_then_the_touchers_colour() -> void:
	var view := _view()
	var play := PlayTuning.new()
	var cfg := play.flag
	var flag := _up(OvertimeFlag.new())
	view.refresh(flag, -1, DT)
	assert_eq(view.cloth_colour(), cfg.overtime_pale, "the light checks off-white")
	assert_eq(cfg.overtime_pale, Color8(238, 234, 224))
	assert_eq(view.ring_colour(), Color(cfg.overtime_ring_idle, cfg.ring_alpha))
	flag.contested = true
	view.refresh(flag, -1, DT)
	assert_eq(view.ring_colour(), Color(cfg.ring_contested, cfg.ring_alpha), "both teams at it")
	for team in 2:
		view.refresh(flag, team, DT)
		assert_eq(view.cloth_colour(), play.teams.colours[team], "touched by %d" % team)
		assert_eq(view.ring_colour(), Color(play.teams.colours[team], cfg.ring_alpha))


func test_the_toucher_is_the_team_that_took_the_round_at_the_flag() -> void:
	var rs := RoundState.new()
	rs.overtime_flag = _up(OvertimeFlag.new())
	rs.phase = RoundState.Phase.LIVE
	rs.winner = 1
	rs.reason = GameEvent.RoundEnd.OVERTIME_FLAG
	assert_eq(OvertimeFlagView.toucher_of(rs), -1, "live: last round's result is not this one's")
	rs.phase = RoundState.Phase.OVER
	assert_eq(OvertimeFlagView.toucher_of(rs), 1)
	rs.phase = RoundState.Phase.MATCH_OVER
	assert_eq(OvertimeFlagView.toucher_of(rs), 1, "the match's last round")
	rs.reason = GameEvent.RoundEnd.ELIMINATED
	assert_eq(OvertimeFlagView.toucher_of(rs), -1, "a wipe-out in overtime: untouched")
	rs.reason = GameEvent.RoundEnd.TIME
	rs.winner = -1
	assert_eq(OvertimeFlagView.toucher_of(rs), -1, "its time out: a draw")


func test_the_cloth_and_ring_pass_the_team_colour_hue_test_until_touched() -> void:
	var cfg := PlayTuning.new().flag
	var neutral: Dictionary[String, Color] = {
		"off-white": cfg.overtime_pale, "dark": cfg.overtime_dark, "ring": cfg.overtime_ring_idle,
		"contested ring": cfg.ring_contested, "glyph off-white": HudFlagGlyph.CHECK_PALE,
		"glyph dark": HudFlagGlyph.CHECK_DARK,
	}
	for colour_set: TeamColours.Set in [TeamColours.Set.STANDARD, TeamColours.Set.HIGH_CONTRAST]:
		for night: bool in [false, true]:
			var tc := TeamColours.resolve(colour_set, night)
			var teams: Array[Color] = []
			teams.append_array(tc.figures.colours)
			teams.append_array(tc.hud.colours)
			for what: String in neutral:
				var c: Color = neutral[what]
				assert_false(FieldChecks.reads_as_team(c, teams), "%s #%s in set %d (night %s)" % [what,
						c.to_html(false), colour_set, night])


func test_scenery_only_so_bbs_pass_through() -> void:
	var view := _view()
	assert_eq(view.find_children("*", "CollisionObject3D", true, false).size(), 0)
	assert_eq(view.find_children("*", "CollisionShape3D", true, false).size(), 0)
	assert_eq(view.materials().size(), 2, "the cloth and the ring warm in the prewarm")


func test_a_frame_with_it_down_allocates_nothing() -> void:
	var view := _view()
	var flag := OvertimeFlag.new()
	view.refresh(flag, -1, DT)
	var before := Performance.get_monitor(Performance.OBJECT_COUNT)
	for i in 600:
		view.refresh(flag, -1, DT)
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), before)


# --- a match ---

func test_built_once_in_elimination_on_a_map_with_a_spot_and_never_in_attack_defend() -> void:
	_session()
	await wait_physics_frames(2)
	var view := session.overtime_flag_view()
	assert_not_null(view, "Depot has its spot")
	assert_false(view.visible, "hidden until it goes up")
	assert_eq(view.position, session.state.round_state.overtime_spot)
	assert_eq(session.find_children("*", "OvertimeFlagView", true, false).size(), 1)
	assert_true(session.hud()._flag_marker.chequered(), "the marker carries the chequered glyph")
	session.queue_free()
	await wait_process_frames(3)
	_session(MatchOptions.MODE_ATTACK_DEFEND)
	await wait_physics_frames(2)
	assert_null(session.overtime_flag_view())
	assert_false(session.hud()._flag_marker.chequered())


func test_the_clock_running_out_puts_it_up_with_the_banner_and_the_ot_clock() -> void:
	_session()
	await wait_physics_frames(2)
	var rs := session.state.round_state
	rs.clock = 0.01
	await wait_physics_frames(3)
	assert_true(rs.overtime_flag.up and rs.is_live())
	assert_eq(session.hud().banner_text(), "OVERTIME / TOUCH THE FLAG")
	assert_almost_eq(session.hud()._banner_left, 2.4, 0.1, "up 2.4 s")
	await wait_process_frames(3)
	assert_true(session.overtime_flag_view().visible)
	rs.overtime_flag.left = 24.2
	session.hud().update(session.state, 1.0, 0.0)
	assert_eq(session.hud().score().clock_text(), "OT 0:25", "the flag's time left")
	session.hud().show_board(true)
	session.hud().update(session.state, 1.0, 0.0)
	assert_string_ends_with(session.hud().board().table().heading_text(), "ROUND 1 · OVERTIME 0:25")


func test_the_marker_and_the_minimap_show_the_flag_while_it_stands() -> void:
	_session()
	await wait_physics_frames(2)
	var rs := session.state.round_state
	var hud := session.hud()
	var camera := Camera3D.new()
	add_child_autofree(camera)
	rs.overtime_flag.raise(rs.overtime_spot)
	camera.global_position = rs.overtime_spot + Vector3(0.0, 1.7, 12.0)
	hud.place_flag_marker(camera, rs.overtime_spot, rs.overtime_flag.up and rs.is_live())
	assert_eq(hud.flag_marker_text(), "FLAG · 12 m")
	camera.global_position = rs.overtime_spot + Vector3(0.0, 1.7, -12.0)
	hud.place_flag_marker(camera, rs.overtime_spot, true)
	assert_ne(hud._flag_marker.pinned_side(), 0, "behind you: pinned to a side")
	var watched := session.player
	hud.update_minimap(session.state, watched, 0.0, 1.0, false, Vector3.ZERO)
	var view := hud.minimap().view()
	assert_true(view.pole_count() == 1 and view._chequered, "the chequered glyph on the minimap")
	assert_eq(view.pole_at(0), Vector2(rs.overtime_spot.x, rs.overtime_spot.z))
	rs.phase = RoundState.Phase.OVER
	hud.update_minimap(session.state, watched, 0.0, 1.0, false, Vector3.ZERO)
	assert_eq(view.pole_count(), 0, "not once the round is over")


func test_a_round_won_at_the_flag_says_flag_touched_and_counts_its_overtime() -> void:
	_session()
	await wait_physics_frames(2)
	var state := session.state
	var rs := state.round_state
	var hud := session.hud()
	rs.clock = 0.0
	rs.overtime_flag.raise(rs.overtime_spot)
	rs.overtime_flag.left = 18.0
	state.events.clear()
	var won := state.events.add(GameEvent.Kind.ROUND_OVER)
	won.value = session.player.team
	won.value2 = GameEvent.RoundEnd.OVERTIME_FLAG
	hud.on_tick(state)
	assert_eq(hud.banner_text(), "WON / ROUND 1 · FLAG TOUCHED · ALPHA TAKE THE ROUND")
	var round_time := SimTuning.load_default().rounds.round_time
	assert_eq(hud.round_result()._played, roundi(round_time + 12.0), "the round's clock and 12 s at the flag")
	state.events.clear()
	var draw := state.events.add(GameEvent.Kind.ROUND_OVER)
	draw.value = -1
	draw.value2 = GameEvent.RoundEnd.TIME
	hud.on_tick(state)
	assert_eq(hud.banner_text(), "DRAW / ROUND 1 · THE ROUND IS PLAYED AGAIN", "untouched: a draw as before")
	state.events.clear()


func test_the_flag_turns_the_touchers_colour_in_the_pause_after() -> void:
	_session()
	await wait_physics_frames(2)
	var rs := session.state.round_state
	var view := session.overtime_flag_view()
	rs.overtime_flag.raise(rs.overtime_spot)
	await wait_process_frames(3)
	assert_eq(view.cloth_colour(), PlayTuning.new().flag.overtime_pale)
	rs.phase = RoundState.Phase.OVER
	rs.winner = 1
	rs.reason = GameEvent.RoundEnd.OVERTIME_FLAG
	await wait_process_frames(3)
	assert_eq(view.cloth_colour(), session.team_colours().figures.colours[1])


func test_reduced_motion_stands_it_at_once_in_a_match() -> void:
	_session(MatchOptions.MODE_ELIMINATION, true)
	await wait_physics_frames(2)
	var rs := session.state.round_state
	rs.overtime_flag.raise(rs.overtime_spot)
	await wait_process_frames(3)
	assert_eq(session.overtime_flag_view().risen(), 1.0)


func test_the_flag_text_reads_flag_touched() -> void:
	assert_eq(HudStyle.flag_round_won(GameEvent.RoundEnd.OVERTIME_FLAG), "FLAG TOUCHED")
	assert_eq(HudStyle.flag_round_sub(GameEvent.RoundEnd.OVERTIME_FLAG, "TEAM_BETA"), "BETA TAKE THE ROUND")
	assert_true(HudStyle.ended_by_flag(RoundState.Mode.ELIMINATION, GameEvent.RoundEnd.OVERTIME_FLAG))
	assert_false(HudStyle.ended_by_flag(RoundState.Mode.ELIMINATION, GameEvent.RoundEnd.TIME))
	assert_true(HudStyle.ended_by_flag(RoundState.Mode.ATTACK_DEFEND, GameEvent.RoundEnd.TIME))


# --- the screen reader and the whistle ---

func test_screen_reader_messages_read_the_overtime_and_its_result() -> void:
	var you := Character.new(0, 0, Vector3.ZERO)
	var reader := Announcer.new(TeamConfig.new(), you, 0)
	var state := GameState.new(1)
	state.round_state.number = 7
	state.round_state.score = PackedInt32Array([4, 3])
	state.events.add(GameEvent.Kind.OVERTIME)
	reader.on_tick(state)
	assert_true(reader.advance(1.0))
	assert_eq(reader.message(), "Overtime · Touch the flag")
	assert_false(reader.assertive(), "polite")
	state.events.clear()
	var won := state.events.add(GameEvent.Kind.ROUND_OVER)
	won.value = 0
	won.value2 = GameEvent.RoundEnd.OVERTIME_FLAG
	reader.on_tick(state)
	assert_true(reader.advance(1.0))
	assert_eq(reader.message(), "Won · Round 7 · Flag touched · Alpha take the round · Alpha 4 – 3 Beta")


func test_the_overtime_whistle_is_three_quick_short_blasts() -> void:
	var cfg := SoundConfig.new()
	assert_eq([cfg.overtime_blasts, cfg.overtime_gap], [3, 1.5], "the browser game's overtimeWhistle")
	var queue := WhistleQueue.new(cfg)
	queue.overtime(20.0)
	var heard: Array = []
	for t in 120:
		var now := 20.0 + t * DT
		var blast := queue.pop_due(now)
		while blast != WhistleQueue.Blast.NONE:
			heard.append([now, blast])
			blast = queue.pop_due(now)
	assert_eq(heard.size(), 3)
	for i in heard.size():
		assert_eq(heard[i][1], WhistleQueue.Blast.SHORT)
		assert_almost_eq(heard[i][0] - 20.0, cfg.whistle_short * cfg.overtime_gap * i, DT + 1e-6)


func test_sim_audio_blows_the_overtime_on_the_interface() -> void:
	var cfg := SoundConfig.new()
	var audio := SimAudio.new()
	add_child_autofree(audio)
	audio.setup(cfg, [] as Array[StringName], BodyConfig.new(), null, null)
	var state := GameState.new(1)
	state.events.add(GameEvent.Kind.OVERTIME)
	audio.on_tick(state, 0, null)
	assert_true((audio._streams[&"whistle_short"] as Array).has(audio._whistle.stream), "the first short blast")
	assert_true(audio._whistle.playing)
	assert_eq(audio._whistle.bus, SimAudio.BUS_INTERFACE)
	assert_eq(audio._blasts.waiting(), cfg.overtime_blasts - 1)
