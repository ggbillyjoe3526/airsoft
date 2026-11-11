extends GutTest
## BP8 HUD notes: the switch's off look, the level's "LVL", the round's start countdown (3, 2, 1, GO: held still, clock
## waiting, the whistle at GO), nothing sounding under the loading screen, the hit call's showing, the centred pause menu.

const DT := 1.0 / 60.0


func test_an_off_switch_is_a_quiet_grey_outline_with_no_fill() -> void:
	var off := MenuSwitch.colours(false, false, false)
	assert_eq(off[0].a, 0.0, "no fill when off: no second sphere")
	assert_eq(off[1], GameTheme.DIM, "a grey knob")
	assert_eq(off[2], GameTheme.DIM, "a grey outline")
	var on := MenuSwitch.colours(true, false, false)
	assert_eq(on[0], GameTheme.ACCENT)
	assert_eq(on[1], GameTheme.ACCENT_INK)
	var dim := MenuSwitch.colours(false, false, true)
	assert_lt(dim[2].a, off[2].a, "a greyed switch is fainter still")


func test_the_level_reads_lvl() -> void:
	assert_eq(tr("MENU_LEVEL_SHORT") % 7, "LVL 7")


func _round_world(countdown: float) -> Array:
	var tuning := SimTuning.new()
	tuning.rounds.start_countdown = countdown
	var end := MapEnd.new()
	end.spawns.append(SpawnPoint.new(Vector3(0.0, 0.0, 0.0), 0.0))
	var loadout: Array[ReplicaConfig] = []
	var cs: Array[Character] = [Character.new(0, 0, Vector3.ZERO, 0.0, loadout),
			Character.new(1, 1, Vector3.ZERO, 0.0, loadout)]
	var ends: Array[MapEnd] = [end, end]
	var rs := RoundState.new()
	var events := SimEvents.new()
	var pool := BBPool.new(2)
	Round.start_match(rs, cs, ends, pool, tuning, events)
	return [tuning, cs, ends, rs, events, pool]


func _kinds(events: SimEvents) -> Array[int]:
	var out: Array[int] = []
	for i in events.count:
		out.append(events.items[i].kind)
	return out


func test_a_countdown_holds_the_round_and_counts_three_two_one_go() -> void:
	var w := _round_world(3.0)
	var rs: RoundState = w[3]
	var events: SimEvents = w[4]
	assert_true(rs.held())
	assert_true(_kinds(events).has(GameEvent.Kind.ROUND_COUNT))
	assert_eq(events.items[events.count - 1].value, 3)
	var counts: Array[int] = [3]
	var went := false
	var clock := rs.clock
	for i in 200:
		events.clear()
		Round.step(rs, w[1], w[2], w[5], w[0], events, DT)
		for n in events.count:
			if events.items[n].kind == GameEvent.Kind.ROUND_COUNT:
				counts.append(events.items[n].value)
			elif events.items[n].kind == GameEvent.Kind.ROUND_GO:
				went = true
		if went:
			break
		assert_eq(rs.clock, clock, "the clock waits through the countdown")
	assert_eq(counts, [3, 2, 1] as Array[int])
	assert_true(went)
	assert_false(rs.held())


func test_no_countdown_goes_at_once() -> void:
	var w := _round_world(0.0)
	var rs: RoundState = w[3]
	assert_false(rs.held())
	assert_true(_kinds(w[4]).has(GameEvent.Kind.ROUND_GO))


func test_a_match_counts_down_three_seconds_and_the_sim_alone_none() -> void:
	var fresh := ResourceLoader.load(PlayTuning.DEFAULT_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as PlayTuning
	assert_eq(fresh.round_countdown, 3.0)
	assert_eq(SimTuning.new().rounds.start_countdown, 0.0, "the sim's own default has none: only a match counts down")


func test_nothing_sounds_under_the_loading_screen_or_a_skip() -> void:
	assert_false(PlaySession.is_heard(false, false, false), "not built")
	assert_false(PlaySession.is_heard(false, true, true), "held for Continue")
	assert_false(PlaySession.is_heard(true, true, false), "skipping")
	assert_true(PlaySession.is_heard(false, true, false))


func test_your_hit_call_shows_only_through_your_eyes_in_a_live_round_with_nothing_over_it() -> void:
	assert_true(Hud.hit_call_shown(true, false, true, false))
	assert_false(Hud.hit_call_shown(true, true, true, false), "watching a bot that was not hit")
	assert_false(Hud.hit_call_shown(true, false, false, false), "the round is decided")
	assert_false(Hud.hit_call_shown(true, false, true, true), "a scoreboard or result is up")
	assert_false(Hud.hit_call_shown(false, false, true, false), "in play")


func test_the_pause_menu_is_centred() -> void:
	var menu := PauseMenu.new()
	add_child_autofree(menu)
	menu.set_match("Depot", "Attack / Defend", 3, 1234)
	menu.visible = true
	await wait_process_frames(3)
	var panel := menu.find_child("Panel", true, false) as Control
	var centre := panel.get_global_rect().get_center().x
	for b in menu.find_children("*", "Button", true, false):
		var button := b as Button
		if not button.is_visible_in_tree() or button.name == &"ReportBug":
			continue
		assert_almost_eq(button.get_global_rect().get_center().x, centre, 2.0, "%s is centred" % button.text)
		if button.name != &"Challenge" and button.name != &"Loadout":
			assert_eq(button.alignment, HORIZONTAL_ALIGNMENT_CENTER, "%s's words" % button.text)


func _sim_world(countdown: float) -> Array:
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


func test_the_whole_sim_holds_clock_bodies_and_trigger_until_go() -> void:
	var made := _sim_world(1.0)
	var sim: Simulation = made[0]
	var state: GameState = made[1]
	var tuning: SimTuning = made[2]
	var rs := state.round_state
	var start := state.characters[0].position
	var cmd := PlayerCommand.new()
	cmd.reset(0.0, 0.0)
	cmd.forward = 1.0
	cmd.fire = true
	var cmds: Array[PlayerCommand] = [cmd, PlayerCommand.new()]
	var ticks := 0
	while rs.held() and ticks < 200:
		sim.step(state, cmds, DT)
		ticks += 1
		if rs.held():
			assert_eq(rs.clock, tuning.rounds.round_time, "the round clock waits for GO")
			assert_eq(rs.overtime, 0.0)
	assert_eq(state.characters[0].position.x, start.x, "nobody moved")
	assert_eq(state.characters[0].position.z, start.z)
	assert_eq(state.bbs.active_count(), 0, "nobody fired")
	assert_false(rs.held())
	sim.step(state, cmds, DT)
	assert_lt(rs.clock, tuning.rounds.round_time, "the clock runs after GO")


func test_ending_the_round_by_cheat_during_the_countdown_goes_then_ends_it() -> void:
	var made := _sim_world(3.0)
	var sim: Simulation = made[0]
	var state: GameState = made[1]
	var rs := state.round_state
	assert_true(rs.held())
	assert_true(Round.run_clock_out(rs))
	var cmds: Array[PlayerCommand] = [PlayerCommand.new(), PlayerCommand.new()]
	sim.step(state, cmds, DT)
	assert_false(rs.held(), "the countdown is over")
	assert_eq(state.events.count_of(GameEvent.Kind.ROUND_GO), 1, "it says GO once (the count on the HUD ends)")
	assert_ne(rs.phase, RoundState.Phase.LIVE, "and the round is played out the same tick")


func test_the_rail_shows_each_carried_bomb_kind_once_as_icons_and_none_not_carried() -> void:
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	c.grenades.carry(2, 0)
	var r := WeaponRail.new()
	add_child_autofree(r)
	var paints: Array[StringName] = [&"cobalt", &"cobalt"]
	r.setup(c.armament.replicas, paints)
	r.refresh(c.armament, c.grenades)
	var slots := c.armament.replicas.size()
	assert_eq(r.rows(), slots + 1, "no flash row when none is carried")
	var smoke: Array = r._glyphs[0]
	assert_true(smoke[0].visible and smoke[1].visible, "two smoke: the icon twice, no number")
	c.grenades.spend(Grenade.Kind.SMOKE)
	r.refresh(c.armament, c.grenades)
	assert_false(smoke[1].visible, "one smoke: one icon")
	assert_eq(WeaponRail.key_text(&"throw_smoke"), "4", "the key is the one that throws a smoke")


func test_the_round_is_under_way_in_the_countdown_but_not_live() -> void:
	var rs := RoundState.new()
	rs.phase = RoundState.Phase.LIVE
	rs.hold = 2.0
	assert_true(rs.under_way(), "the pole cues show during the countdown")
	assert_false(rs.is_live(), "but nothing is played yet")
	rs.hold = 0.0
	assert_true(rs.is_live())
	rs.phase = RoundState.Phase.OVER
	assert_false(rs.under_way())


func test_the_rail_s_key_labels_follow_a_rebind_mid_match() -> void:
	# PP1 (KNOWN_ISSUES row: the rail's key labels were read once, when the rail was built).
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	var r := WeaponRail.new()
	add_child_autofree(r)
	var paints: Array[StringName] = [&"cobalt", &"cobalt"]
	r.setup(c.armament.replicas, paints)
	var action: StringName = WeaponRail.SLOT_ACTIONS[0]
	var before: String = r._keys[0].text
	var kept := InputMap.action_get_events(action)
	InputMap.action_erase_events(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_F9
	InputMap.action_add_event(action, ev)
	r.refresh_keys()
	var shown: String = r._keys[0].text
	var wanted := WeaponRail.key_text(action)
	InputMap.action_erase_events(action)
	for e in kept:
		InputMap.action_add_event(action, e)
	assert_ne(shown, before, "the label changed with the rebind")
	assert_eq(shown, wanted, "the first row names the new key")
