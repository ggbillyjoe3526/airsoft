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
