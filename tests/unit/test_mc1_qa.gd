extends GutTest
## QA for MC1: the edges of the bomb in hand (a vault, a round's end and start, a holstered replica, the wheel and a
## throw key in one tick), a skip played out to the match's end or left mid-way, the loading screen's fallback when the
## shaders never warm, and an old save's keys under partly changed bindings.

const DT := 1.0 / 60.0

var tuning: SimTuning = SimTuning.new()
var loadout: Array[ReplicaConfig] = []
var session: PlaySession = null


func before_all() -> void:
	loadout = ReplicaStats.default_loadout()


func after_each() -> void:
	Input.action_release(&"fire")
	InputMap.load_from_project_settings()
	get_tree().paused = false


## A started match of two (one a side) on a floor, with a low wall 0.7 m ahead of each spawn when `wall`:
## [Simulation, GameState].
func _match(wall: bool = false) -> Array:
	var w := BoxWorld.new(tuning.body)
	w.add_floor(60.0, 30.0)
	if wall:
		for x: float in [-10.0, 10.0]:
			w.add_box(Vector3(x, 0.425, -0.85), Vector3(6.0, 0.85, 0.3))
	var ends: Array[MapEnd] = []
	for e in 2:
		var end := MapEnd.new()
		end.spawns.append(SpawnPoint.new(Vector3(-10.0 if e == 0 else 10.0, 0.0, 0.0), 0.0))
		end.dead_zone.append(SpawnPoint.new(Vector3(-25.0 if e == 0 else 25.0, 0.0, 10.0), 0.0))
		ends.append(end)
	var sim := Simulation.new(tuning, w, w.mover(), ends, -10.0)
	var s := GameState.new(5, tuning)
	for i in 2:
		s.characters.append(Character.new(i, i, Vector3.ZERO, 0.0, loadout))
	sim.start_match(s)
	return [sim, s]


func _commands(s: GameState) -> Array[PlayerCommand]:
	var out: Array[PlayerCommand] = []
	for c in s.characters:
		var cmd := PlayerCommand.new()
		cmd.reset(c.yaw, c.pitch)
		out.append(cmd)
	return out


## Steps `ticks` ticks, the one-shot presses cleared after the first.
func _run(sim: Simulation, s: GameState, cmds: Array[PlayerCommand], ticks: int) -> void:
	for t in ticks:
		sim.step(s, cmds, DT)
		for cmd in cmds:
			cmd.ready_grenade = Grenade.Kind.NONE
			cmd.throw_grenade = Grenade.Kind.NONE
			cmd.switch_to = -1
			cmd.jump = false
			cmd.holster = false


func _active_bombs(s: GameState) -> int:
	var n := 0
	for g in s.grenades:
		if g.active:
			n += 1
	return n


# --- the bomb in hand ---


func test_a_bomb_in_hand_stays_in_hand_through_a_vault_and_no_pull_over_it_throws() -> void:
	var m := _match(true)
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var you := s.characters[0]
	var cmds := _commands(s)
	_run(sim, s, cmds, 30)
	cmds[0].ready_grenade = Grenade.Kind.SMOKE
	_run(sim, s, cmds, 1)
	cmds[0].jump = true
	cmds[0].forward = 1.0
	_run(sim, s, cmds, 1)
	assert_true(you.vault.active, "the wall is vaulted with the bomb in hand")
	cmds[0].fire = true # a pull over the wall
	var ticks := 0
	while you.vault.active and ticks < 240:
		_run(sim, s, cmds, 1)
		assert_false(Grenades.throwing(you), "nothing is thrown mid-vault")
		ticks += 1
	assert_false(you.vault.active, "the vault ended")
	assert_eq(you.grenades.readied, Grenade.Kind.SMOKE, "the bomb is still in hand after the vault")
	assert_eq(_active_bombs(s), 0)
	assert_eq(you.grenades.smoke, you.grenades.carried_smoke, "no bomb spent over the wall")
	cmds[0].fire = false
	cmds[0].forward = 0.0


func test_a_bomb_and_a_throw_key_in_one_tick_throw_the_key_and_the_replica_comes_back() -> void:
	var m := _match()
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var you := s.characters[0]
	var cmds := _commands(s)
	_run(sim, s, cmds, 30)
	var flashes := you.grenades.flash
	var smokes := you.grenades.smoke
	cmds[0].ready_grenade = Grenade.Kind.SMOKE
	cmds[0].throw_grenade = Grenade.Kind.FLASH
	_run(sim, s, cmds, 1)
	assert_eq(you.grenades.throwing, Grenade.Kind.FLASH, "the key throws, the wheel's bomb is not what leaves")
	assert_eq(you.grenades.readied, Grenade.Kind.NONE, "none left in hand")
	_run(sim, s, cmds, roundi((tuning.grenades.windup + tuning.grenades.recover) / DT) + 3)
	assert_eq(you.grenades.flash, flashes - 1)
	assert_eq(you.grenades.smoke, smokes, "the smoke is still there")
	assert_false(you.armament.holstered, "the replica is back up")
	assert_eq(_active_bombs(s), 1)


func test_a_bomb_in_hand_ends_with_the_round_and_the_next_round_starts_clean() -> void:
	var m := _match()
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var you := s.characters[0]
	var cmds := _commands(s)
	_run(sim, s, cmds, 30)
	cmds[0].ready_grenade = Grenade.Kind.FLASH
	_run(sim, s, cmds, 1)
	assert_true(DevCheats.end_round(s))
	_run(sim, s, cmds, 2)
	assert_eq(s.round_state.phase, RoundState.Phase.OVER)
	cmds[0].fire = true # a pull between rounds
	_run(sim, s, cmds, 3)
	cmds[0].fire = false
	assert_eq(_active_bombs(s), 0, "no bomb thrown between rounds")
	_run(sim, s, cmds, roundi(tuning.rounds.reset_delay / DT) + 30)
	assert_eq(s.round_state.phase, RoundState.Phase.LIVE, "the next round")
	assert_eq(you.grenades.readied, Grenade.Kind.NONE, "nothing in hand")
	assert_false(you.armament.holstered, "the replica is up")
	assert_eq(you.grenades.flash, you.grenades.carried_flash)


func test_a_bomb_taken_with_the_replica_holstered_leaves_it_holstered_after_the_throw() -> void:
	var m := _match()
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var you := s.characters[0]
	var cmds := _commands(s)
	_run(sim, s, cmds, 30)
	cmds[0].holster = true
	_run(sim, s, cmds, 1)
	assert_true(you.armament.holstered)
	cmds[0].ready_grenade = Grenade.Kind.SMOKE
	_run(sim, s, cmds, 1)
	cmds[0].fire = true
	_run(sim, s, cmds, 1)
	cmds[0].fire = false
	_run(sim, s, cmds, roundi((tuning.grenades.windup + tuning.grenades.recover) / DT) + 3)
	assert_eq(_active_bombs(s), 1)
	assert_true(you.armament.holstered, "as it was when the bomb was taken")
	assert_eq(s.bbs.active_count(), 0)


func test_a_reload_with_a_bomb_in_hand_puts_it_back_and_brings_the_replica_up() -> void:
	var m := _match()
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var you := s.characters[0]
	var cmds := _commands(s)
	_run(sim, s, cmds, 30)
	cmds[0].ready_grenade = Grenade.Kind.SMOKE
	_run(sim, s, cmds, 1)
	cmds[0].reload = true
	_run(sim, s, cmds, 1)
	cmds[0].reload = false
	assert_eq(you.grenades.readied, Grenade.Kind.NONE)
	assert_false(you.armament.holstered, "the press draws the replica")
	assert_eq(_active_bombs(s), 0)


func test_a_wheel_step_with_no_bombs_left_never_lands_on_one() -> void:
	assert_eq(PlayerInput.wheel_item(1, 1, false, false), 0, "past the pistol: round to the first replica")
	assert_eq(PlayerInput.wheel_item(0, -1, false, false), 1)
	assert_eq(PlayerInput.wheel_item(0, -1, true, true), PlayerInput.WHEEL_FLASH, "back from the first: the flash")
	assert_eq(PlayerInput.wheel_item(1, 9, true, false), 1, "nine notches round the three items, none of them the flash")
	assert_eq(PlayerInput.wheel_item(1, 4, true, false), 2, "four notches: the smoke, never the flash")
	assert_eq(PlayerInput.wheel_item(1, 0, true, true), 1, "no notch, no move")


# --- the skip ---


func _session() -> PlaySession:
	var s := PlaySession.new()
	s.bots_active = false
	s.difficulty = &"easy"
	s.settings = Settings.new()
	add_child_autofree(s)
	return s


func test_leaving_the_match_mid_skip_draws_the_window_again() -> void:
	session = _session()
	await wait_physics_frames(2)
	session.player.status = Character.Status.OUT
	session.start_skip()
	assert_true(session.skipping())
	assert_true(session.get_viewport().disable_3d)
	remove_child(session)
	assert_false(get_viewport().disable_3d, "the window's 3D is on again once the match is gone")
	session.free()
	session = null


func test_a_skip_to_the_end_of_the_match_shows_the_results_and_the_rematch_starts_unheld() -> void:
	session = _session()
	await wait_physics_frames(2)
	var rs := session.state.round_state
	var mine := session.player.team
	rs.score[mine] = tuning.rounds.wins_needed - 1
	var mates_alive := false
	for c in session.state.characters:
		if c.team != mine:
			c.status = Character.Status.OUT
		elif c.id != PlaySession.PLAYER_ID:
			mates_alive = true
	if not mates_alive:
		pending("no teammate to keep the player's team in")
		return
	session.player.status = Character.Status.OUT
	session.start_skip()
	var frames := 0
	while session.skipping() and frames < 600:
		session._physics_process(0.0)
		frames += 1
	assert_false(session.skipping(), "played out")
	assert_eq(rs.phase, RoundState.Phase.MATCH_OVER, "the last round decided the match")
	assert_true(session.hud().visible, "the HUD is back for the results")
	assert_false(session.get_viewport().disable_3d)
	assert_false(session._skip_cover.visible)
	# the rematch: its first round is not held by the skip
	session._rematch_left = 0.0
	session._physics_process(0.0)
	assert_eq(rs.phase, RoundState.Phase.LIVE, "a new match")
	assert_false(rs.hold_next)
	assert_eq(rs.score[0] + rs.score[1], 0)


func test_a_click_on_the_table_after_a_skip_starts_the_next_round() -> void:
	session = _session()
	await wait_physics_frames(2)
	var rs := session.state.round_state
	session._input.active = true
	session.player.status = Character.Status.OUT
	rs.clock = 1.0
	session.start_skip()
	var frames := 0
	while session.skipping() and frames < 600:
		session._physics_process(0.0)
		frames += 1
	assert_eq(rs.phase, RoundState.Phase.OVER)
	assert_true(rs.hold_next)
	# well past the table's delay and the wait between rounds: still waiting, the table up
	var ticks := roundi((session._hud.round_result()._cfg.table_delay + tuning.rounds.reset_delay + 1.0) / DT)
	for i in ticks:
		session._physics_process(0.0)
	await wait_process_frames(2)
	assert_eq(rs.phase, RoundState.Phase.OVER, "waits for the click")
	assert_true(session._hud.round_result().is_up(), "with its table up to click")
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	session._unhandled_input(e)
	session._physics_process(0.0)
	session._physics_process(0.0)
	assert_eq(rs.phase, RoundState.Phase.LIVE, "the click moves on")
	session._input.active = false


# --- the loading screen's fallback ---


func test_continue_comes_up_after_the_fallback_when_the_shaders_never_warm() -> void:
	session = _session()
	await wait_physics_frames(2)
	session._play = session._play.duplicate()
	session._play.go_fallback = 3.0
	session._holding = true
	session._warm = false
	session._go_said = false
	session._held_for = 0.0
	watch_signals(session)
	session._follow_hold(1.0)
	session._follow_hold(1.0)
	assert_false(session.ready_for_go(), "not before the fallback while the shaders warm")
	session._follow_hold(1.5)
	assert_true(session.ready_for_go())
	assert_signal_emit_count(session, "ready_to_go", 1)
	session._follow_hold(5.0)
	assert_signal_emit_count(session, "ready_to_go", 1, "said once")
	session._holding = false


func test_a_hold_that_has_not_drawn_yet_counts_no_time_toward_the_fallback() -> void:
	session = _session()
	await wait_physics_frames(2)
	session._play = session._play.duplicate()
	session._play.go_fallback = 1.0
	session._holding = true
	session._warm = false
	session._go_said = false
	session._held_for = -1.0
	session._follow_hold(30.0)
	assert_false(session.ready_for_go(), "the first frame is not drawn: the clock has not started")
	session._holding = false


func test_go_while_not_holding_does_nothing_and_a_second_go_is_harmless() -> void:
	session = _session()
	await wait_physics_frames(2)
	var mode_before := Input.mouse_mode
	session.go()
	assert_eq(Input.mouse_mode, mode_before, "not holding: the mouse is left alone")
	session._holding = true
	session.go()
	assert_false(session.holding())
	session.go()
	assert_false(session.holding())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	session._input.active = false


# --- old saves under partly changed bindings ---


## True if no key is on two actions.
func _no_shared_keys(b: KeyBindings) -> bool:
	var seen: Dictionary[int, StringName] = {}
	for action: StringName in KeyBindings.ACTIONS:
		for c in b.codes(action):
			if seen.has(c):
				return false
			seen[c] = action
	return true


func _layout_1_save() -> Dictionary:
	var saved := KeyBindings.new().to_dict()
	saved.erase(KeyBindings.LAYOUT_KEY)
	for action: StringName in KeyBindings.LAYOUT_1_MOVED:
		saved[String(action)] = KeyBindings.LAYOUT_1_MOVED[action]
	return saved


func test_partly_changed_old_saves_never_leave_a_key_on_two_actions_and_resave_the_same() -> void:
	var cases: Array[Dictionary] = []
	var swapped := _layout_1_save()
	swapped["throw_smoke"] = [KEY_Y]
	swapped["throw_flash"] = [KEY_G]
	cases.append(swapped)
	var dial_reordered := _layout_1_save()
	dial_reordered["hop_up_less"] = [KEY_PAGEDOWN, KEY_4]
	cases.append(dial_reordered)
	var four_taken := _layout_1_save()
	four_taken["hop_up_less"] = [KEY_PAGEDOWN]
	four_taken["crouch"] = [KEY_4]
	cases.append(four_taken)
	var door_on_g := _layout_1_save()
	door_on_g["throw_smoke"] = [KEY_J]
	door_on_g["use_door"] = [KEY_G]
	cases.append(door_on_g)
	var partial: Dictionary = {"fire": [-MOUSE_BUTTON_LEFT], "hop_up_more": [KEY_5, KEY_PAGEUP]}
	cases.append(partial)
	for saved in cases:
		var b := KeyBindings.new()
		b.load_dict(saved)
		assert_true(_no_shared_keys(b), "no shared key: %s" % [saved])
		for action: StringName in KeyBindings.ESSENTIAL:
			assert_false(b.codes(action).is_empty(), "%s keeps a key" % action)
		var again := KeyBindings.new()
		assert_true(again.load_dict(b.to_dict()), "its own save loads as it came")
		for action: StringName in KeyBindings.ACTIONS:
			assert_eq(again.codes(action), b.codes(action), "%s saves and loads the same" % action)


func test_a_partial_old_save_gets_the_new_defaults_for_what_it_lacks_and_for_old_defaults() -> void:
	var b := KeyBindings.new()
	var saved: Dictionary = {"hop_up_more": [KEY_5, KEY_PAGEUP]}
	assert_true(b.load_dict(saved))
	assert_eq(b.codes(&"hop_up_more"), PackedInt32Array([KEY_PAGEUP]), "the old default dial pair is the new default")
	assert_eq(b.codes(&"throw_flash"), PackedInt32Array([KEY_5]), "a lacking action takes the new default")
	assert_eq(b.codes(&"use_door"), PackedInt32Array([KEY_G]))


func test_the_layout_marker_in_any_shape_never_breaks_a_load() -> void:
	for marker: Variant in [2, 2.0, 1, "2", null, [], -3, 999999.0, true]:
		var saved := KeyBindings.new().to_dict()
		saved[KeyBindings.LAYOUT_KEY] = marker
		var b := KeyBindings.new()
		b.load_dict(saved)
		assert_true(_no_shared_keys(b), "marker %s" % [marker])
		assert_eq(b.codes(&"fire"), PackedInt32Array([-MOUSE_BUTTON_LEFT]))
