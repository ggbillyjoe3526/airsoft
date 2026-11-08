extends GutTest
## QA's hunt on BP8's HUD part: what the start countdown leaves behind (time in play, the digit on screen after a cheat
## ends the round), and the weapon rail across bomb counts and throws.

const K := GameEvent.Kind
const DT := 1.0 / 60.0


func _world(countdown: float) -> Array:
	var tuning := SimTuning.new()
	tuning.rounds.start_countdown = countdown
	var w := BoxWorld.new(tuning.body)
	w.add_floor(60.0, 30.0)
	var ends: Array[MapEnd] = []
	for e in 2:
		var end := MapEnd.new()
		end.spawns.append(SpawnPoint.new(Vector3(-20.0 if e == 0 else 20.0, 0.0, 0.0), 0.0))
		ends.append(end)
	var sim := Simulation.new(tuning, w, w.mover(), ends, -10.0)
	var state := GameState.new(1, tuning)
	for i in 2:
		state.characters.append(Character.new(i, i, Vector3.ZERO, 0.0, ReplicaStats.default_loadout()))
	sim.start_match(state)
	return [sim, state, tuning]


func test_time_in_play_does_not_count_the_start_countdown() -> void:
	var w := _world(2.0)
	var sim: Simulation = w[0]
	var state: GameState = w[1]
	var stats := MatchStats.new()
	stats.after_tick(state, DT)
	var cmds: Array[PlayerCommand] = [PlayerCommand.new(), PlayerCommand.new()]
	for i in 60:
		sim.step(state, cmds, DT)
		stats.after_tick(state, DT)
	assert_true(state.round_state.held(), "still counting down")
	assert_almost_eq(stats.match_of(0).time_in_play, 0.0, 0.05, "nobody was in play yet: it was a countdown")


func test_the_countdown_digit_does_not_stay_up_when_a_cheat_ends_the_round_in_it() -> void:
	var session := PlaySession.new()
	session.bots_active = false
	add_child_autofree(session)
	await wait_physics_frames(2)
	var hud: Hud = session._hud
	var st := session.state
	st.events.clear()
	st.events.add(K.ROUND_COUNT).value = 2
	hud.on_tick(st)
	assert_true(hud._count.visible, "the digit shows")
	st.events.clear()
	var e := st.events.add(K.ROUND_OVER)
	e.value = -1
	e.value2 = GameEvent.RoundEnd.TIME
	hud.on_tick(st)
	assert_false(hud._count.visible, "a round that is over has no countdown on it")


func _rail(smoke: int, flash: int) -> Array:
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	c.grenades.carry(smoke, flash)
	var r := WeaponRail.new()
	add_child_autofree(r)
	var paints: Array[StringName] = [&"cobalt", &"cobalt"]
	r.setup(c.armament.replicas, paints)
	r.refresh(c.armament, c.grenades)
	return [r, c]


func _shown(r: WeaponRail, kind: int) -> int:
	var n := 0
	for g: Control in r._glyphs[kind]:
		if g.visible:
			n += 1
	return n


func test_the_rail_shows_one_icon_for_one_bomb_two_for_two_and_one_dim_when_spent() -> void:
	for pair: Array in [[1, 1], [2, 2], [2, 1]]:
		var made := _rail(pair[0], pair[1])
		var r: WeaponRail = made[0]
		assert_eq(_shown(r, 0), pair[0], "smoke icons for %s" % [pair])
		assert_eq(_shown(r, 1), pair[1], "flash icons for %s" % [pair])
	var made := _rail(2, 2)
	var r: WeaponRail = made[0]
	var c: Character = made[1]
	c.grenades.spend(Grenade.Kind.FLASH)
	c.grenades.spend(Grenade.Kind.FLASH)
	r.refresh(c.armament, c.grenades)
	assert_eq(_shown(r, 1), 1, "a spent kind keeps one icon")
	assert_lt(r._glyphs[1][0].self_modulate.a, 0.5, "and it is dim")
	assert_true(r._plates[r._slots + 1].visible, "its row stays")


func test_a_bomb_in_hand_lights_its_row_and_no_replica_row() -> void:
	var made := _rail(1, 1)
	var c: Character = made[1]
	var hand := c.grenades
	assert_eq(WeaponRail.lit_row(c.armament, hand, 2), c.armament.active, "the replica in hand")
	c.armament.holstered = true
	assert_eq(WeaponRail.lit_row(c.armament, hand, 2), -1, "holstered: none")


func test_a_fresh_match_session_is_held_then_goes_live_with_one_go() -> void:
	var session := PlaySession.new()
	add_child_autofree(session)
	await wait_physics_frames(2)
	var rs := session.state.round_state
	assert_gt(rs.hold, 0.0, "a match starts held (the sweep helper is not what holds it)")
	assert_false(rs.is_live(), "held is not live")
	assert_true(rs.under_way(), "but the round is under way for the pole cues")
	var gos := 0
	var left := 600
	while rs.hold > 0.0 and left > 0:
		await wait_physics_frames(1)
		left -= 1
		gos += session.state.events.count_of(K.ROUND_GO)
	assert_gt(left, 0, "the hold ends by itself")
	assert_true(rs.is_live(), "live after the countdown")
	assert_lt(gos, 2, "at most one GO is seen")


func test_the_hold_helper_makes_a_held_round_live() -> void:
	var session := PlaySession.new()
	add_child_autofree(session)
	await wait_physics_frames(2)
	assert_false(session.state.round_state.is_live())
	RoundHold.release(session.state)
	assert_true(session.state.round_state.is_live(), "the helper ends the hold")
	assert_eq(session.state.events.count_of(K.ROUND_GO), 1, "and says GO, as the sim does at the end of the countdown")


# --- run 5: the cheat in the hold, pause across the digits, Tab in the countdown, the rail with two of a kind -----------


func _drain(sim: Simulation, state: GameState, cmds: Array[PlayerCommand], ticks: int, seen: Dictionary) -> void:
	for i in ticks:
		sim.step(state, cmds, DT)
		for k: int in [K.ROUND_GO, K.ROUND_OVER, K.ROUND_COUNT, K.ROUND_START]:
			seen[k] = int(seen.get(k, 0)) + state.events.count_of(k)


func test_ending_the_round_by_cheat_in_the_hold_gives_one_go_one_round_over_and_a_next_countdown() -> void:
	var w := _world(3.0)
	var sim: Simulation = w[0]
	var state: GameState = w[1]
	var cmds: Array[PlayerCommand] = [PlayerCommand.new(), PlayerCommand.new()]
	var seen := {}
	_drain(sim, state, cmds, 70, seen)
	assert_true(state.round_state.held(), "in the hold")
	assert_true(DevCheats.end_round(state), "the cheat takes a held round")
	seen.clear()
	_drain(sim, state, cmds, 1, seen)
	assert_eq(seen.get(K.ROUND_GO, 0), 1, "the next step says GO")
	assert_eq(seen.get(K.ROUND_OVER, 0), 1, "and plays the round out in the same tick")
	assert_false(state.round_state.held(), "no hold left to show a digit")
	assert_eq(state.round_state.counted, 0)
	seen.clear()
	var left := 60 * 30
	while int(seen.get(K.ROUND_START, 0)) == 0 and left > 0:
		_drain(sim, state, cmds, 1, seen)
		left -= 1
	assert_gt(left, 0, "the next round started")
	assert_eq(seen.get(K.ROUND_GO, 0), 0, "no second GO for the same round")
	assert_eq(seen.get(K.ROUND_OVER, 0), 0, "no second ROUND_OVER")
	assert_true(state.round_state.held(), "and counts down again (rematch / next round)")
	assert_eq(seen.get(K.ROUND_COUNT, 0), 1, "with its own 3")


func test_cheat_go_and_round_over_in_one_tick_leave_no_plate_up() -> void:
	var session := PlaySession.new()
	session.bots_active = false
	add_child_autofree(session)
	await wait_physics_frames(2)
	var hud: Hud = session._hud
	var st := session.state
	st.events.clear()
	st.events.add(K.ROUND_COUNT).value = 3
	hud.on_tick(st)
	st.events.clear()
	Round.end_countdown(st.round_state, st.events)
	var e := st.events.add(K.ROUND_OVER)
	e.value = -1
	e.value2 = GameEvent.RoundEnd.TIME
	hud.on_tick(st)
	hud.update(st, 1.0, 0.1)
	hud.update(st, 1.0, 5.0)
	assert_false(hud._count.visible, "neither the 3 nor a GO! is left on screen")


func test_pause_across_each_digit_keeps_the_digit_and_the_plate_returns() -> void:
	var hud := Hud.new()
	add_child_autofree(hud)
	var you := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	hud.setup(HudConfig.new(), TeamConfig.new(), ViewConfig.new(), SimTuning.new(), you)
	for digit: int in [3, 2, 1]:
		hud._count.count(digit)
		hud.set_paused(true)
		assert_eq(hud._count.modulate.a, 0.0, "hidden while paused on %d" % digit)
		assert_eq(hud._count.big_text(), str(digit), "the digit is kept")
		hud.set_paused(false)
		assert_eq(hud._count.modulate.a, 1.0, "back on %d" % digit)
		assert_true(hud._count.visible)
	hud._count.go("GO!", 0.8)
	hud.set_paused(true)
	hud.set_paused(false)
	assert_true(hud._count.visible, "GO! survives a pause")
	hud._count.tick(1.0)
	assert_false(hud._count.visible, "and still ends on its own time")


func test_a_pause_does_not_advance_the_countdown_and_resume_loses_no_digit() -> void:
	var session := PlaySession.new()
	session.bots_active = false
	add_child_autofree(session)
	await wait_physics_frames(2)
	var rs := session.state.round_state
	var before := rs.hold
	session._open_pause()
	await wait_physics_frames(20)
	assert_eq(rs.hold, before, "the sim waits under the pause menu")
	session._pause.resumed.emit()
	get_tree().paused = false
	await wait_physics_frames(3)
	assert_lt(rs.hold, before, "and carries on after")
	assert_false(session._hud._count.modulate.a < 1.0, "the plate is drawn again")


func test_tab_in_the_countdown_hides_the_plate_with_the_stack_and_brings_it_back() -> void:
	var session := PlaySession.new()
	session.bots_active = false
	add_child_autofree(session)
	await wait_physics_frames(2)
	var hud: Hud = session._hud
	var st := session.state
	st.events.clear()
	st.events.add(K.ROUND_COUNT).value = 3
	hud.on_tick(st)
	hud.show_board(true)
	hud.update(st, 1.0, 0.016)
	assert_false(hud._middle.visible, "the board covers the banner and plate")
	assert_true(hud._count.visible, "but the countdown itself runs on")
	hud.show_board(false)
	hud.update(st, 1.0, 0.016)
	assert_true(hud._middle.visible)
	assert_true(hud._count.visible)


func test_throwing_one_of_two_like_bombs_leaves_one_lit_icon_and_the_other_kind_alone() -> void:
	for kind: Grenade.Kind in [Grenade.Kind.SMOKE, Grenade.Kind.FLASH]:
		var made := _rail(2, 2)
		var r: WeaponRail = made[0]
		var c: Character = made[1]
		var idx: int = kind - Grenade.Kind.SMOKE
		c.grenades.readied = kind
		r.refresh(c.armament, c.grenades)
		assert_eq(r.lit(), r._slots + idx, "the bomb in hand lights its row")
		assert_eq(_shown(r, idx), 2, "still two while it is in hand")
		c.grenades.spend(kind)
		c.grenades.end_throw()
		r.refresh(c.armament, c.grenades)
		assert_eq(_shown(r, idx), 1, "one left after the throw")
		assert_gt(r._glyphs[idx][0].self_modulate.a, 0.5, "and it is not dim")
		assert_eq(_shown(r, 1 - idx), 2, "the other kind keeps both")
		assert_eq(r.lit(), c.armament.active, "the replica row is lit again")


func test_a_new_round_restocking_brings_both_icons_back() -> void:
	var made := _rail(2, 0)
	var r: WeaponRail = made[0]
	var c: Character = made[1]
	c.grenades.spend(Grenade.Kind.SMOKE)
	c.grenades.spend(Grenade.Kind.SMOKE)
	r.refresh(c.armament, c.grenades)
	assert_eq(_shown(r, 0), 1)
	c.grenades.refill()
	r.refresh(c.armament, c.grenades)
	assert_eq(_shown(r, 0), 2, "restocked")
	assert_gt(r._glyphs[0][0].self_modulate.a, 0.5)
	assert_false(r._plates[r._slots + 1].visible, "a kind never carried still has no row")


func test_the_rail_stays_inside_the_window_at_every_size_with_the_notes_up() -> void:
	for sz: Vector2 in [Vector2(1280, 720), Vector2(1920, 1080), Vector2(2560, 1440), Vector2(1280, 1024), Vector2(2560, 1080)]:
		var port := SubViewport.new()
		port.size = Vector2i(sz)
		port.disable_3d = true
		add_child_autofree(port)
		var you := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
		you.grenades.carry(2, 2)
		var hud := Hud.new()
		port.add_child(hud)
		hud.size = sz
		hud.setup(HudConfig.new(), TeamConfig.new(), ViewConfig.new(), SimTuning.new(), you)
		var paints: Array[StringName] = [&"cobalt", &"cobalt"]
		hud.setup_weapon_rail(you.armament.replicas, paints, false)
		hud._replica.refresh(you.armament, you.grenades)
		hud._replica.show_hop("HOP-UP 60")
		hud._replica._status.text = "RELOADING"
		hud._replica._status.visible = true
		await wait_process_frames(3)
		var rect := hud._rail.get_global_rect()
		assert_true(Rect2(Vector2.ZERO, sz).encloses(rect), "rail inside the window at %s: %s" % [sz, rect])
		assert_lte(hud._replica._status.get_global_rect().end.y, rect.position.y + 0.5, "notes above the rail at %s" % sz)
		assert_eq(hud.size, sz, "the HUD fills the window at %s" % sz)
		port.queue_free()
		await wait_process_frames(1)
