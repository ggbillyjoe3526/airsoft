extends GutTest
## FB6 (the owner's 0.1 Dev 1 feedback): leaving a match or the range lands on the menus' Match page with Play focused; on Beta your team is on the left of the score bar and first on every table; and the sight comes up
## evenly every drawn frame at any game speed (the Dev settings' pacer).

const MAIN := preload("res://game/main.tscn")
const LOAD_LIMIT := 20.0
const DT := 1.0 / 60.0
const EPS := 1e-5
const RATES: Array[float] = [0.25, 0.5, 1.0, 1.5, 2.0]


func after_each() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# --- A: back to the Match page ---

func _assert_on_the_match_page(main: Node, why: String) -> void:
	assert_null(main._play, why)
	assert_true(main._menus.visible, "%s: the menus show" % why)
	assert_eq(main._menus.page_tab(), NavRail.Tab.MATCH, "%s: on the Match page" % why)
	assert_eq(get_viewport().gui_get_focus_owner(), main._menus.match_page().play_button(), "%s: Play focused" % why)


func test_leave_in_the_pause_menu_lands_on_the_match_page() -> void:
	var main: Node = add_child_autofree(MAIN.instantiate())
	await wait_process_frames(2)
	main._start_play()
	assert_true(await wait_until(func() -> bool: return main._loading == null, LOAD_LIMIT), "the match loads")
	var play: PlaySession = main._play
	play._open_pause()
	play._pause.leave_button().pressed.emit()
	await wait_process_frames(2)
	_assert_on_the_match_page(main, "left a match")


func test_leaving_practice_lands_on_the_match_page_too() -> void:
	var main: Node = add_child_autofree(MAIN.instantiate())
	await wait_process_frames(2)
	main._picks.mode = MatchOptions.MODE_PRACTICE
	main._start_play()
	assert_true(await wait_until(func() -> bool: return main._loading == null, LOAD_LIMIT), "the range loads")
	assert_true(main._play.practice)
	main._play._open_pause()
	main._play._pause.leave_button().pressed.emit()
	await wait_process_frames(2)
	_assert_on_the_match_page(main, "left practice")


# --- B: your team on the left ---

func _session(team: int) -> PlaySession:
	var s := PlaySession.new()
	s.autopilot = false
	s.bots_active = false
	s.player_team = team
	add_child_autofree(s)
	await wait_physics_frames(2)
	return s


func test_on_beta_the_score_bar_reads_beta_then_alpha_each_in_its_own_colour() -> void:
	var s := await _session(PlaySession.TEAM_BETA)
	var bar := s.hud().score()
	assert_eq(bar.first_team(), 1)
	assert_lt(bar.block_x(1), bar.block_x(0), "Beta's block is left of the clock, Alpha's right")
	bar.set_score(1, 3)
	assert_eq(bar.score_text(1), "3", "Beta's own score on Beta's block")
	assert_eq(bar._score_labels[1].position.x, bar.block_x(1))
	assert_eq(bar._score_labels[1].get_theme_color("font_color"), HudStyle.ink_on(s._play.teams.colours[1]))
	var n := bar.pip_count()
	assert_lt(bar._shapes[n][0].x, bar._shapes[0][0].x, "Beta's pips on the left end")
	assert_eq(bar.pips_filled(1), 3)
	assert_eq(bar.pips_filled(0), 1)
	bar.set_sides(1)
	assert_eq(bar._tags[1].position.x, bar.block_x(1), "ATK sits on Beta's block, wherever it is")
	assert_eq(bar.tag_text(1), HudStyle.caps("HUD_ATK"))
	# Half time swaps the ends on the field, never the bar.
	var left := bar.block_x(1)
	s.state.round_state.number = SimTuning.new().rounds.half_time_after + 1
	s.hud().update(s.state, 1.0, DT)
	assert_eq(bar.block_x(1), left, "after half time Beta is still on the left")


func test_on_alpha_the_score_bar_is_as_before() -> void:
	var s := await _session(PlaySession.TEAM_ALPHA)
	var bar := s.hud().score()
	assert_eq(bar.first_team(), 0)
	assert_lt(bar.block_x(0), bar.block_x(1))


func test_on_beta_the_scoreboard_the_round_result_and_the_summary_list_beta_first() -> void:
	var s := await _session(PlaySession.TEAM_BETA)
	var names := s._play.teams.names
	var beta := HudStyle.caps(names[1])
	var alpha := HudStyle.caps(names[0])
	var board := s.hud().board()
	board.update(s.state, s.match_stats(), s.player, true)
	assert_eq(board.table().team_names(), PackedStringArray([beta, alpha]), "Tab scoreboard")
	var result := s.hud().round_result()
	result.round_over(1, 30, s.state.time - 1000.0)
	result.update(s.state, s.match_stats(), s.player)
	assert_eq(result.table().team_names(), PackedStringArray([beta, alpha]), "round result")
	var summary := s.hud().summary()
	summary.open(s.state, s.match_stats(), s.player, false, "")
	assert_eq(summary.table().team_names(), PackedStringArray([beta, alpha]), "match summary")
	summary.close()
	result.close()


# --- C: the sight at any game speed ---

## One frame's drawing as PlaySession does it: the pacer's ticks of the simulation's aiming, then the views.
class AimRun:
	var tuning := SimTuning.new()
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	var cmd := PlayerCommand.new()
	var pacer := TickPacer.new()
	var follow := AimFollow.new()
	var eyes: FirstPersonView = null
	var input: PlayerInput = null
	var hands: ReplicaView = null
	## Per drawn frame: the simulation's raise, the drawn raise, the camera's FOV and the replica's place.
	var sim := PackedFloat32Array()
	var drawn := PackedFloat32Array()
	var fov := PackedFloat32Array()
	var pose := PackedVector3Array()

	func frame() -> void:
		for i in pacer.ticks():
			Aiming.step(c, cmd, tuning.movement, PlaySession.TICK)
		var aim := follow.update(c, tuning.movement, DT * pacer.rate)
		eyes.sim_rate = pacer.rate
		eyes.update(c, input, pacer.fraction(0.0), DT, aim)
		hands.update(c, 0.0, 0.0, Vector3(0.0, 1.6, 0.0), Vector3.FORWARD, DT, aim)
		sim.append(c.aim_raise)
		drawn.append(aim)
		fov.append(eyes.camera.fov)
		pose.append(hands._held[c.armament.active].root.position)


func _run(rate: float) -> AimRun:
	var run := AimRun.new()
	run.pacer.rate = rate
	run.eyes = FirstPersonView.new()
	add_child_autofree(run.eyes)
	run.eyes.setup(ViewConfig.new(), run.tuning.body, run.tuning.hits)
	run.input = PlayerInput.new()
	add_child_autofree(run.input)
	run.hands = ReplicaView.new()
	add_child_autofree(run.hands)
	run.hands.setup(ViewModelConfig.new(), run.c.armament.replicas, BoxWorld.new())
	# Settled at the hip, then the aim button held until the sight is fully up.
	for i in 30:
		run.frame()
	run.sim.clear()
	run.drawn.clear()
	run.fov.clear()
	run.pose.clear()
	run.cmd.aim = true
	var limit := ceili(run.tuning.movement.aim_raise_time * 4.0 / (rate * DT)) + 10
	for i in limit:
		run.frame()
		if run.drawn[run.drawn.size() - 1] >= 1.0:
			break
	return run


func test_slowed_the_simulation_s_own_raise_holds_for_frames_then_jumps() -> void:
	# Control: why the view can't draw the simulation's raise as it is.
	var run := _run(0.25)
	var still := 0
	for i in range(1, run.sim.size()):
		if run.sim[i] == run.sim[i - 1] and run.sim[i] < 1.0:
			still += 1
	assert_gt(still, run.sim.size() / 2, "at 25 % three frames in four show no tick")


func test_the_sight_comes_up_evenly_every_drawn_frame_at_every_game_speed() -> void:
	for rate in RATES:
		var run := _run(rate)
		var c := run.c
		var even := rate * DT / Aiming.raise_time(c, run.tuning.movement)
		var tick := PlaySession.TICK / Aiming.raise_time(c, run.tuning.movement)
		assert_almost_eq(run.drawn[run.drawn.size() - 1], 1.0, EPS, "%s: fully up" % rate)
		# From the first frame it moves until the one it arrives on.
		var first := 0
		while run.drawn[first] <= 0.0:
			first += 1
		var last := run.drawn.size() - 1
		assert_gt(last - first, roundi(0.5 / even), "%s: the raise is drawn over many frames" % rate)
		for i in range(first + 1, last):
			var step := run.drawn[i] - run.drawn[i - 1]
			assert_almost_eq(step, even, EPS, "%s: frame %d moves the same as every other (no hold, no jump)" % [rate, i])
			assert_lt(run.fov[i], run.fov[i - 1], "%s: frame %d zooms in" % [rate, i])
			assert_ne(run.pose[i], run.pose[i - 1], "%s: frame %d moves the replica" % [rate, i])
		for i in range(first, last + 1):
			var step := run.drawn[i] - (run.drawn[i - 1] if i > 0 else 0.0)
			assert_true(step <= even + EPS, "%s: frame %d never a doubled step (%s > %s)" % [rate, i, step, even])
			# Never ahead of the simulation, and never more than a frame's worth behind it.
			assert_true(run.drawn[i] <= run.sim[i] + EPS, "%s: frame %d not ahead" % [rate, i])
			assert_true(run.sim[i] - run.drawn[i] <= maxf(even, tick) + EPS, "%s: frame %d close" % [rate, i])


func test_the_sight_snaps_when_out_and_when_the_view_moves_to_someone_else() -> void:
	var cfg := MovementConfig.new()
	var a := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	var b := Character.new(1, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	var follow := AimFollow.new()
	a.aim_raise = 1.0
	assert_eq(follow.update(a, cfg, DT), 1.0, "the first look is as it stands")
	b.aim_raise = 0.0
	assert_eq(follow.update(b, cfg, DT), 0.0, "someone else's at once")
	a.aim_raise = 1.0
	follow.update(a, cfg, DT)
	a.status = Character.Status.OUT
	a.aim_raise = 0.0
	assert_eq(follow.update(a, cfg, DT), 0.0, "out: down at once")


func test_recoil_on_screen_eases_over_simulation_time() -> void:
	var tuning := SimTuning.new()
	var input := PlayerInput.new()
	add_child_autofree(input)
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	c.armament.recoil = 0.1
	for rate in RATES:
		var eyes := FirstPersonView.new()
		add_child_autofree(eyes)
		eyes.setup(ViewConfig.new(), tuning.body, tuning.hits)
		eyes.sim_rate = rate
		eyes.update(c, input, 1.0, DT, 0.0)
		var want := 0.1 * (1.0 - exp(-FirstPersonView.RECOIL_FOLLOW * DT * rate))
		assert_almost_eq(eyes._recoil, want, EPS, "%s: a frame follows the kick over the simulation's time" % rate)


func test_the_sight_snaps_when_the_raise_takes_no_time_or_jumps_further_than_the_ticks_can_move_it() -> void:
	var cfg := MovementConfig.new()
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	var follow := AimFollow.new()
	follow.update(c, cfg, DT)
	cfg.aim_raise_time = 0.0
	c.aim_raise = 1.0
	var drawn := follow.update(c, cfg, DT)
	assert_eq(drawn, 1.0, "no raise time: drawn as the simulation's, never 0 / 0")
	cfg.aim_raise_time = 0.15
	c.aim_raise = 0.0
	assert_eq(follow.update(c, cfg, DT * 0.25), 0.0, "a drop of the whole raise in a quarter tick is a jump: snapped")
	c.aim_raise = PlaySession.TICK / Aiming.raise_time(c, cfg)
	assert_lt(follow.update(c, cfg, DT * 0.25), c.aim_raise, "one tick's move at 25 % is eased, not snapped")
