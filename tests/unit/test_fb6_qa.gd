extends GutTest
## QA hunt for FB6: every way out of play lands on the Match page with the picks kept and nothing leaked; the score bar
## puts your team on the left at any pip count, with ATK / DEF and the stripes on the right blocks; and the drawn sight
## (AimFollow) through releases, reversals, replica swaps, game speed changes and respawns.

const MAIN := preload("res://game/main.tscn")
const LOAD_LIMIT := 20.0
const TICK := PlaySession.TICK
const EPS := 1e-5


func after_each() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# --- A: leaving ---

func _boot() -> Node:
	var main: Node = add_child_autofree(MAIN.instantiate())
	await wait_process_frames(2)
	return main


func _play(main: Node) -> PlaySession:
	main._start_play()
	assert_true(await wait_until(func() -> bool: return main._loading == null, LOAD_LIMIT), "the match loads")
	return main._play


func _leave_by_pause(main: Node) -> void:
	main._play._open_pause()
	main._play._pause.leave_button().pressed.emit()
	await wait_process_frames(2)


func _assert_match_page(main: Node, why: String) -> void:
	assert_null(main._play, why)
	assert_true(main._menus.visible, "%s: menus show" % why)
	assert_eq(main._menus.page_tab(), NavRail.Tab.MATCH, "%s: Match page" % why)
	assert_eq(get_viewport().gui_get_focus_owner(), main._menus.match_page().play_button(), "%s: Play focused" % why)
	assert_false(get_tree().paused, "%s: tree not left paused" % why)
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE, "%s: mouse released" % why)


func test_leaving_keeps_the_picks_and_the_next_play_is_the_same_team_and_map() -> void:
	var main := await _boot()
	main._picks.team = PlaySession.TEAM_BETA
	var map_id: String = main._picks.map_id
	await _play(main)
	assert_eq(main._play.player_team, PlaySession.TEAM_BETA)
	await _leave_by_pause(main)
	_assert_match_page(main, "left")
	assert_eq(main._picks.team, PlaySession.TEAM_BETA, "the team pick is kept")
	assert_eq(main._picks.map_id, map_id, "the map pick is kept")
	await _play(main)
	assert_eq(main._play.player_team, PlaySession.TEAM_BETA, "the next match is Beta again")
	assert_eq(main._play.map_id, map_id)


func test_two_matches_left_in_a_row_leave_no_extra_nodes() -> void:
	var main := await _boot()
	var counts: Array[int] = []
	for i in 2:
		await _play(main)
		await _leave_by_pause(main)
		await wait_process_frames(3)
		counts.append(main.get_child_count())
		_assert_match_page(main, "leave %d" % i)
	assert_eq(counts[0], counts[1], "main's children after the second leave equal the first's")


func test_settings_opened_on_the_match_page_then_a_match_then_leave_opens_settings_again() -> void:
	var main := await _boot()
	main._menus.nav_rail().tab_button(NavRail.Tab.SETTINGS).pressed.emit()
	await wait_process_frames(2)
	assert_not_null(main._settings_screen)
	await _play(main)
	assert_null(main._settings_screen, "the match closed the settings")
	await _leave_by_pause(main)
	_assert_match_page(main, "left after settings")
	main._menus.nav_rail().tab_button(NavRail.Tab.SETTINGS).pressed.emit()
	await wait_process_frames(2)
	assert_not_null(main._settings_screen, "Settings opens again")
	main._menus.nav_rail().tab_button(NavRail.Tab.MATCH).pressed.emit()
	await wait_process_frames(2)
	assert_null(main._settings_screen, "and closes to the Match page")


func test_leaving_from_the_match_summary_lands_on_the_match_page() -> void:
	var main := await _boot()
	var play := await _play(main)
	play.hud().open_summary(play.state, false, "")
	await wait_process_frames(3)
	assert_true(play.hud().summary().is_open(), "the summary is open")
	await _leave_by_pause(main)
	_assert_match_page(main, "left from the summary")


func test_leaving_while_the_round_table_holds_lands_on_the_match_page() -> void:
	var main := await _boot()
	var play := await _play(main)
	var result := play.hud().round_result()
	result.round_over(1, 30, play.state.time - 1000.0)
	result.update(play.state, play.match_stats(), play.player)
	await _leave_by_pause(main)
	_assert_match_page(main, "left from the round table")


func test_the_map_refusal_s_back_button_lands_on_the_match_page() -> void:
	var main := await _boot()
	var play := await _play(main)
	var ui := CanvasLayer.new()
	play.add_child(ui)
	var map := MapData.new()
	map.problems.append("QA: refused")
	play._refuse(ui, map)
	var back: Button = null
	for n in ui.find_children("*", "Button", true, false):
		back = n
	assert_not_null(back)
	assert_false("title" in back.text.to_lower(), "the button no longer promises the title")
	back.pressed.emit()
	await wait_process_frames(2)
	_assert_match_page(main, "refusal back")


func test_leaving_practice_then_picking_a_match_plays_a_match_not_practice() -> void:
	var main := await _boot()
	main._picks.mode = MatchOptions.MODE_PRACTICE
	await _play(main)
	await _leave_by_pause(main)
	_assert_match_page(main, "left practice")
	assert_null(main._spot, "no practice spot is kept")
	main._picks.mode = MatchOptions.MODE_ELIMINATION
	await _play(main)
	assert_false(main._play.practice, "an Elimination pick is a match")


# --- B: the score bar ---

func _bar(first: int, count: int) -> HudScore:
	var bar := HudScore.new()
	add_child_autofree(bar)
	bar.setup(TeamConfig.new(), count, first)
	return bar


func test_every_pip_and_block_sits_in_its_own_end_for_either_team_and_any_pip_count() -> void:
	for first in 2:
		for count: int in [1, 3, 5, 10]:
			var bar := _bar(first, count)
			var other := 1 - first
			var width := bar.custom_minimum_size.x
			assert_lt(bar.block_x(first), bar.block_x(other), "first %d count %d: yours left" % [first, count])
			for i in count:
				var mine: float = bar._shapes[first * count + i][0].x
				var theirs: float = bar._shapes[other * count + i][0].x
				assert_lt(mine, bar.block_x(first), "your pip %d left of your block" % i)
				assert_gt(theirs, bar.block_x(other), "their pip %d right of their block" % i)
				assert_true(mine >= 0.0 and theirs < width, "pips inside the bar")
				if i > 0:
					assert_gt(mine, bar._shapes[first * count + i - 1][0].x, "pips run left to right")
					assert_gt(theirs, bar._shapes[other * count + i - 1][0].x)
			assert_almost_eq(bar.block_x(other) - bar.block_x(first),
					HudStyle.BLOCK_WIDTH + HudStyle.CLOCK_WIDTH, EPS, "blocks flank the clock")


func test_a_first_team_out_of_range_is_clamped_to_a_team() -> void:
	assert_eq(_bar(5, 3).first_team(), 1)
	assert_eq(_bar(-2, 3).first_team(), 0)


func test_attack_and_defend_tags_follow_the_teams_through_a_swap_on_beta() -> void:
	var bar := _bar(1, 5)
	bar.set_sides(0)
	assert_eq(bar.tag_text(0), HudStyle.caps("HUD_ATK"), "Alpha attacks")
	assert_eq(bar.tag_text(1), HudStyle.caps("HUD_DEF"), "Beta defends")
	assert_eq(bar._tags[1].position.x, bar.block_x(1), "your DEF is over your block, on the left")
	assert_eq(bar._tags[0].position.x, bar.block_x(0))
	bar.set_sides(1)
	assert_eq(bar.tag_text(1), HudStyle.caps("HUD_ATK"))
	assert_eq(bar.tag_text(0), HudStyle.caps("HUD_DEF"))
	assert_lt(bar.block_x(1), bar.block_x(0))
	bar.set_sides(-1)
	assert_eq(bar.tag_text(0), "", "no tags outside Attack / Defend")
	assert_eq(bar.tag_text(1), "")


func test_scores_pips_and_overtime_read_the_same_on_either_team_s_bar() -> void:
	var a := _bar(0, 5)
	var b := _bar(1, 5)
	for bar: HudScore in [a, b]:
		bar.set_score(4, 2)
		assert_eq(bar.pips_filled(0), 4)
		assert_eq(bar.pips_filled(1), 2)
		assert_eq(bar.score_text(0), "4")
		assert_eq(bar.score_text(1), "2")
		bar.set_clock(30, true)
	assert_eq(a.clock_text(), b.clock_text(), "overtime reads the same")
	assert_true(b.clock_text().begins_with(tr("HUD_OT")), "and starts with OT")


func test_the_stripes_follow_betas_block_to_the_left() -> void:
	var bar := _bar(1, 5)
	bar.set_patterned(true)
	assert_true(bar.striped(1))
	assert_false(bar.striped(0))
	var stripe_rect: Rect2 = bar._block_stripes._rect
	assert_eq(stripe_rect.position.x, bar.block_x(HudStyle.STRIPED_TEAM), "the striped block is Beta's wherever it sits")


func test_a_real_attack_defend_session_as_beta_puts_atk_over_the_left_block_when_beta_attacks() -> void:
	var s := PlaySession.new()
	s.autopilot = false
	s.bots_active = false
	s.player_team = PlaySession.TEAM_BETA
	s.mode = MatchOptions.MODE_ATTACK_DEFEND
	add_child_autofree(s)
	await wait_physics_frames(2)
	var bar := s.hud().score()
	assert_lt(bar.block_x(1), bar.block_x(0))
	s.state.round_state.attackers = 1
	s.hud().update(s.state, 1.0, 1.0 / 60.0)
	assert_eq(bar.tag_text(1), HudStyle.caps("HUD_ATK"), "Beta attacks: ATK on the left block")
	assert_eq(bar._tags[1].position.x, bar.block_x(1))
	s.state.round_state.attackers = 0
	s.hud().update(s.state, 1.0, 1.0 / 60.0)
	assert_eq(bar.tag_text(1), HudStyle.caps("HUD_DEF"))


# --- C: the drawn sight ---

class Harness:
	var tuning := SimTuning.new()
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	var cmd := PlayerCommand.new()
	var follow := AimFollow.new()
	var rate: float = 1.0
	var frame_dt: float = 1.0 / 60.0
	var sim := PackedFloat32Array()
	var drawn := PackedFloat32Array()
	var _acc: float = 0.0
	var _carry: float = 0.0

	## One rendered frame at the engine's cadence: a 60 Hz physics tick comes due as real time passes, the pacer runs
	## `rate` simulation ticks per due tick; the follower then takes the frame's simulation time.
	func frame() -> void:
		_acc += frame_dt
		while _acc >= PlaySession.TICK - 1e-9:
			_acc -= PlaySession.TICK
			_carry += rate
			var n := floori(_carry)
			_carry -= n
			for i in n:
				Aiming.step(c, cmd, tuning.movement, PlaySession.TICK)
		var aim := follow.update(c, tuning.movement, frame_dt * rate)
		sim.append(c.aim_raise)
		drawn.append(aim)


func _harness(fps: float, rate: float) -> Harness:
	var h := Harness.new()
	h.frame_dt = 1.0 / fps
	h.rate = rate
	for i in 60:
		h.frame()
	h.sim.clear()
	h.drawn.clear()
	return h


func test_at_normal_speed_the_drawn_sight_is_never_ahead_or_more_than_a_tick_behind_at_any_frame_rate() -> void:
	for fps: float in [30.0, 60.0, 90.0, 144.0, 240.0]:
		var h := _harness(fps, 1.0)
		var tick := TICK / Aiming.raise_time(h.c, h.tuning.movement)
		h.cmd.aim = true
		for i in 120:
			h.frame()
		var worst := 0.0
		for i in h.sim.size():
			assert_true(h.drawn[i] <= h.sim[i] + EPS, "%s fps: never ahead" % fps)
			worst = maxf(worst, h.sim[i] - h.drawn[i])
		assert_true(worst <= tick + EPS, "%s fps: lag %s within a tick %s" % [fps, worst, tick])
		gut.p("lag at 100 %% and %d fps: %.3f of the raise (a tick is %.3f)" % [fps, worst, tick])
		h.cmd.aim = false
		for i in 120:
			h.frame()
		assert_eq(h.drawn[h.drawn.size() - 1], 0.0, "%s fps: back at the hip" % fps)


func test_at_normal_speed_and_one_tick_a_frame_the_drawn_sight_is_the_simulations() -> void:
	var h := _harness(60.0, 1.0)
	h.cmd.aim = true
	for i in 20:
		h.frame()
	for i in h.sim.size():
		assert_almost_eq(h.drawn[i], h.sim[i], 1e-4, "frame %d" % i)


func test_a_release_mid_raise_never_zooms_further_in_than_a_tick_after_the_button_goes() -> void:
	for rate: float in [0.25, 1.0, 1.5]:
		for fps: float in [60.0, 144.0]:
			var h := _harness(fps, rate)
			h.cmd.aim = true
			while h.sim.size() < 4 or h.sim[h.sim.size() - 1] < 0.45:
				h.frame()
			var at_release := h.drawn[h.drawn.size() - 1]
			h.cmd.aim = false
			var peak := at_release
			for i in 400:
				h.frame()
				peak = maxf(peak, h.drawn[h.drawn.size() - 1])
			var tick := TICK / Aiming.raise_time(h.c, h.tuning.movement)
			assert_true(peak - at_release <= tick + EPS,
					"%s x %s fps: keeps rising %s after release" % [rate, fps, peak - at_release])
			assert_eq(h.drawn[h.drawn.size() - 1], 0.0)


func test_the_game_speed_changing_mid_aim_keeps_the_raise_in_range_and_never_ahead() -> void:
	var h := _harness(144.0, 0.25)
	h.cmd.aim = true
	for i in 100:
		h.frame()
	h.rate = 1.5
	for i in 200:
		h.frame()
	h.rate = 0.25
	h.cmd.aim = false
	for i in 400:
		h.frame()
	for i in range(1, h.drawn.size()):
		assert_true(h.drawn[i] >= 0.0 and h.drawn[i] <= 1.0, "frame %d in range" % i)
	assert_eq(h.drawn[h.drawn.size() - 1], 0.0)


func test_swapping_replicas_mid_aim_ends_at_the_hip_following_the_new_replica() -> void:
	var h := _harness(144.0, 0.25)
	assert_gt(h.c.armament.replicas.size(), 1, "two replicas")
	h.c.armament.replicas[1].raise_scale = 2.5
	h.cmd.aim = true
	for i in 300:
		h.frame()
	assert_eq(h.drawn[h.drawn.size() - 1], 1.0)
	h.c.armament.active = 1
	h.c.armament.draw_left = 0.4
	h.c.armament.draw_total = 0.4
	for i in 400:
		h.frame()
	assert_eq(h.drawn[h.drawn.size() - 1], 0.0, "down after the swap")
	for i in h.drawn.size():
		assert_true(h.drawn[i] >= 0.0 and h.drawn[i] <= 1.0)


func test_a_new_round_s_respawn_puts_the_drawn_sight_at_the_hip_with_the_simulation() -> void:
	# A survivor aiming at the round's end is respawned at the start of the next with aim_raise 0 (Character.respawn):
	# the view is warped to the spawn, so a zoom left easing out there would read as a glitch.
	var cfg := MovementConfig.new()
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	var follow := AimFollow.new()
	c.aim_raise = 1.0
	follow.update(c, cfg, TICK)
	c.respawn()
	assert_eq(c.aim_raise, 0.0)
	assert_eq(follow.update(c, cfg, TICK), 0.0, "the sight is down on the first frame of the new round")


func test_an_aim_held_through_the_respawn_is_never_drawn_ahead_of_the_simulation() -> void:
	# The invariant the record states (never ahead of the simulation) across a respawn at normal speed: the survivor
	# holds aim at the round's end, the new round puts aim_raise back to 0 and the held button raises it from there.
	var h := _harness(60.0, 1.0)
	h.cmd.aim = true
	for i in 30:
		h.frame()
	assert_eq(h.drawn[h.drawn.size() - 1], 1.0)
	h.c.respawn()
	h.sim.clear()
	h.drawn.clear()
	for i in 12:
		h.frame()
	for i in h.drawn.size():
		assert_true(h.drawn[i] <= h.sim[i] + EPS, "frame %d: drawn %s ahead of the simulation's %s" % [i, h.drawn[i], h.sim[i]])


# --- Re-check: the snap threshold ---

## Frames of aim in and out (held, released, flicked) count a snap when the drawn raise moves further than the frame's step.
func _snaps(fps: float, rate: float, scale: float) -> int:
	var h := _harness(fps, rate)
	h.c.armament.replicas[h.c.armament.active].raise_scale = scale
	var step := h.frame_dt * rate / Aiming.raise_time(h.c, h.tuning.movement)
	var snaps := 0
	var pattern: Array[int] = [90, 90, 20, 15, 5, 40, 120, 60]
	for n in pattern.size():
		h.cmd.aim = n % 2 == 0
		for i in pattern[n] * 3:
			var before := h.drawn[h.drawn.size() - 1] if not h.drawn.is_empty() else 0.0
			h.frame()
			if absf(h.drawn[h.drawn.size() - 1] - before) > step + EPS:
				snaps += 1
	return snaps


func test_normal_aiming_in_and_out_never_snaps_at_any_speed_frame_rate_or_optic() -> void:
	for rate: float in [0.25, 1.0, 1.5, 2.0]:
		for fps: float in [30.0, 60.0, 144.0, 240.0]:
			for scale: float in [0.3, 0.6, 1.0, 1.6]:
				assert_eq(_snaps(fps, rate, scale), 0, "rate %s fps %s raise_scale %s snapped" % [rate, fps, scale])


func test_a_respawn_from_a_full_sight_snaps_at_every_speed_frame_rate_and_optic() -> void:
	for rate: float in [0.25, 1.0, 1.5]:
		for fps: float in [60.0, 144.0]:
			for scale: float in [0.8, 1.0, 1.6, 2.5]:
				var h := _harness(fps, rate)
				h.c.armament.replicas[h.c.armament.active].raise_scale = scale
				h.cmd.aim = true
				for i in 600:
					h.frame()
				assert_eq(h.drawn[h.drawn.size() - 1], 1.0)
				h.c.respawn()
				h.cmd.aim = false
				h.frame()
				assert_eq(h.drawn[h.drawn.size() - 1], 0.0, "rate %s fps %s scale %s: down at once" % [rate, fps, scale])
