extends GutTest
## SF1 QA: smoke and flash bombs hunted past the worker's own tests (test_grenades.gd). The view (GrenadeView), the
## replica panel's bomb row, the key bindings and the input latch, and the edge cases of the throw: pool full at the
## release, a respawn or a hit mid-throw, a torch, a round ending mid-flight, throws straight up and down or into a wall,
## a bot standing inside a cloud.

const DT := 1.0 / 60.0

var tuning: SimTuning = SimTuning.new()
var cfg: GrenadeConfig = tuning.grenades
var loadout: Array[ReplicaConfig] = []


func before_all() -> void:
	loadout = ReplicaStats.default_loadout()


func after_each() -> void:
	InputMap.load_from_project_settings()
	for action: StringName in [&"throw_smoke", &"throw_flash"]:
		Input.action_release(action)


func _world(wall_x: float = INF) -> BoxWorld:
	var w := BoxWorld.new(tuning.body)
	w.add_floor(60.0, 30.0)
	if wall_x < INF:
		w.add_box(Vector3(wall_x, 1.5, 0.0), Vector3(0.2, 3.0, 30.0))
	return w


func _match(w: BoxWorld, count: int = 4) -> Array:
	var ends: Array[MapEnd] = []
	for e in 2:
		var end := MapEnd.new()
		for i in 3:
			end.spawns.append(SpawnPoint.new(Vector3(-10.0 if e == 0 else 10.0, 0.0, i * 2.0), 0.0))
			end.dead_zone.append(SpawnPoint.new(Vector3(-25.0 if e == 0 else 25.0, 0.0, 10.0), 0.0))
		ends.append(end)
	var sim := Simulation.new(tuning, w, w.mover(), ends, -10.0)
	var s := GameState.new(5, tuning)
	for i in count:
		s.characters.append(Character.new(i, 0 if i < 3 else 1, Vector3.ZERO, 0.0, loadout))
	sim.start_match(s)
	return [sim, s]


func _commands(s: GameState) -> Array[PlayerCommand]:
	var out: Array[PlayerCommand] = []
	for c in s.characters:
		var cmd := PlayerCommand.new()
		cmd.reset(c.yaw, c.pitch)
		out.append(cmd)
	return out


func _run(sim: Simulation, s: GameState, cmds: Array[PlayerCommand], ticks: int, counted: int = -1) -> int:
	var n := 0
	for t in ticks:
		sim.step(s, cmds, DT)
		if counted >= 0:
			n += s.events.count_of(counted)
		for cmd in cmds:
			cmd.throw_grenade = Grenade.Kind.NONE
	return n


static func _place(c: Character, at: Vector3, yaw: float, pitch: float = 0.0) -> void:
	c.position = at
	c.prev_position = at
	c.velocity = Vector3.ZERO
	c.yaw = yaw
	c.pitch = pitch


static func _smoke_at(s: GameState, slot: int, at: Vector3, smoking: float) -> Grenade:
	var g := s.grenades[slot]
	g.launch(Grenade.Kind.SMOKE, 0, at, Vector3.ZERO)
	g.resting = true
	g.popped = true
	g.smoking = smoking
	return g


func _view(count: int = 4, night: bool = false) -> GrenadeView:
	var v := GrenadeView.new()
	add_child_autofree(v)
	v.setup(count, cfg, night)
	return v


# --- GrenadeView ---


func test_an_idle_view_draws_nothing_and_a_view_with_no_eyes_has_no_wash() -> void:
	var s := GameState.new(5, tuning)
	var v := _view(s.grenades.size())
	v.update(s, 0.5, DT, null, Vector3.ZERO)
	for i in s.grenades.size():
		assert_false(v.canister_shown(i))
		assert_false(v.cloud_shown(i))
	assert_eq(v.wash().a, 0.0)
	assert_false(v.held_shown())
	assert_eq(v.flash_energy(), 0.0)


func test_a_flying_bomb_is_drawn_and_a_popped_smoke_gets_a_cloud_until_it_is_gone() -> void:
	var s := GameState.new(5, tuning)
	var v := _view(s.grenades.size())
	s.grenades[1].launch(Grenade.Kind.FLASH, 0, Vector3(0.0, 2.0, 0.0), Vector3(3.0, 0.0, 0.0))
	_smoke_at(s, 2, Vector3(5.0, 0.04, 0.0), cfg.smoke_grow)
	v.update(s, 0.5, DT, null, Vector3.ZERO)
	assert_true(v.canister_shown(1))
	assert_false(v.cloud_shown(1), "a flash has no cloud")
	assert_true(v.canister_shown(2))
	assert_true(v.cloud_shown(2))
	assert_false(v.canister_shown(0))
	s.grenades[2].active = false
	v.update(s, 0.5, DT, null, Vector3.ZERO)
	assert_false(v.canister_shown(2))
	assert_false(v.cloud_shown(2), "a smoke that has ended takes its puffs with it")


func test_a_smoke_in_the_air_that_has_not_popped_has_no_cloud() -> void:
	var s := GameState.new(5, tuning)
	var v := _view(s.grenades.size())
	s.grenades[0].launch(Grenade.Kind.SMOKE, 0, Vector3(0.0, 2.0, 0.0), Vector3(3.0, 0.0, 0.0))
	v.update(s, 0.5, DT, null, Vector3.ZERO)
	assert_true(v.canister_shown(0))
	assert_false(v.cloud_shown(0))


func test_a_bang_lights_up_and_fades_out_by_itself() -> void:
	var s := GameState.new(5, tuning)
	var v := _view(s.grenades.size())
	var e := s.events.add(GameEvent.Kind.FLASH_BANG)
	e.position = Vector3(3.0, 1.0, 0.0)
	v.on_tick(s)
	s.events.clear()
	v.update(s, 0.0, DT, null, Vector3.ZERO)
	assert_gt(v.flash_energy(), 0.0, "lit at the bang")
	v.update(s, 0.0, GrenadeView.FLASH_TIME * 2.0, null, Vector3.ZERO)
	assert_eq(v.flash_energy(), 0.0, "out after its time")
	v.on_tick(s)
	assert_eq(v.flash_energy(), 0.0, "a tick with no bang lights nothing")


func test_the_wash_is_white_while_dazzled_softer_with_reduced_motion_and_gone_when_it_wears_off() -> void:
	var s := GameState.new(5, tuning)
	var v := _view(s.grenades.size())
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, loadout)
	c.dazzle_left = 2.0
	c.dazzle_total = 2.0
	v.update(s, 0.0, DT, c, Vector3(0.0, 1.6, 0.0))
	var full := v.wash()
	assert_gt(full.a, 0.0)
	assert_gt(full.r, 0.9, "white")
	v.soft_flash = true
	v.update(s, 0.0, DT, c, Vector3(0.0, 1.6, 0.0))
	assert_lt(v.wash().a, full.a, "softer with Reduced motion")
	c.dazzle_left = 0.3
	v.soft_flash = false
	v.update(s, 0.0, DT, c, Vector3(0.0, 1.6, 0.0))
	assert_lt(v.wash().a, full.a, "fading over its last second")
	assert_gt(v.wash().a, 0.0)
	c.dazzle_left = 0.0
	v.update(s, 0.0, DT, c, Vector3(0.0, 1.6, 0.0))
	assert_eq(v.wash().a, 0.0)


func test_eyes_inside_a_cloud_see_a_smoke_wash_and_outside_it_none() -> void:
	var s := GameState.new(5, tuning)
	var v := _view(s.grenades.size())
	var g := _smoke_at(s, 0, Vector3(0.0, 0.04, 0.0), cfg.smoke_grow + 1.0)
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, loadout)
	v.update(s, 0.0, DT, c, Grenades.cloud_middle(g, cfg))
	assert_gt(v.wash().a, 0.5, "thick at the middle")
	v.update(s, 0.0, DT, c, Vector3(cfg.smoke_radius + 3.0, 1.6, 0.0))
	assert_eq(v.wash().a, 0.0, "clear outside")
	g.smoking = cfg.smoke_time - 0.05
	v.update(s, 0.0, DT, c, Grenades.cloud_middle(g, cfg))
	assert_lt(v.wash().a, 0.2, "a cloud thinned away washes little")


func test_the_held_canister_shows_during_the_windup_only() -> void:
	var s := GameState.new(5, tuning)
	var v := _view(s.grenades.size())
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, loadout)
	c.grenades.carry(1, 1)
	v.update(s, 0.0, DT, c, Vector3(0.0, 1.6, 0.0))
	assert_false(v.held_shown())
	c.grenades.throwing = Grenade.Kind.SMOKE
	c.grenades.windup_left = cfg.windup
	v.update(s, 0.0, DT, c, Vector3(0.0, 1.6, 0.0))
	assert_true(v.held_shown())
	c.grenades.released = true
	v.update(s, 0.0, DT, c, Vector3(0.0, 1.6, 0.0))
	assert_false(v.held_shown(), "gone from the hand once thrown")
	c.grenades.stop()
	v.update(s, 0.0, DT, null, Vector3.ZERO)
	assert_false(v.held_shown())


func test_a_view_made_for_no_slots_updates_and_a_pool_larger_than_the_view_is_safe() -> void:
	var s := GameState.new(5, tuning)
	var v := _view(0)
	v.update(s, 0.0, DT, null, Vector3.ZERO)
	var small := _view(2)
	_smoke_at(s, 5, Vector3(1.0, 0.04, 0.0), cfg.smoke_grow)
	small.update(s, 0.0, DT, null, Vector3.ZERO)
	assert_false(small.canister_shown(5), "past the view's own slots: not drawn, not an error")


func test_freeing_the_view_leaves_no_orphan_nodes() -> void:
	var s := GameState.new(5, tuning)
	var before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var v := GrenadeView.new()
	add_child(v)
	v.setup(s.grenades.size(), cfg, true)
	_smoke_at(s, 0, Vector3(0.0, 0.04, 0.0), cfg.smoke_grow)
	v.update(s, 0.0, DT, null, Vector3.ZERO)
	remove_child(v)
	v.free()
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), before)
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes)


func test_a_frame_of_the_view_allocates_nothing_once_warm() -> void:
	var s := GameState.new(5, tuning)
	var v := _view(s.grenades.size())
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, loadout)
	c.dazzle_left = 2.0
	c.dazzle_total = 2.0
	_smoke_at(s, 0, Vector3(0.0, 0.04, 0.0), cfg.smoke_grow)
	s.grenades[1].launch(Grenade.Kind.FLASH, 0, Vector3(0.0, 2.0, 0.0), Vector3(3.0, 0.0, 0.0))
	for i in 20:
		v.update(s, 0.5, DT, c, Vector3(0.0, 1.6, 0.0))
	var before := Performance.get_monitor(Performance.OBJECT_COUNT)
	for i in 120:
		v.update(s, 0.5, DT, c, Vector3(0.0, 1.6, 0.0))
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), before)


# --- Replica panel ---


func _panel(c: Character) -> ReplicaPanel:
	var p := ReplicaPanel.new()
	add_child_autofree(p)
	p.setup(HudConfig.new())
	p.refresh(c.armament, c.grenades)
	return p


func test_the_panel_counts_the_bombs_left_and_follows_a_throw() -> void:
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, loadout)
	c.grenades.carry(1, 1)
	var p := _panel(c)
	var texts := p.bomb_texts()
	assert_eq(texts[Grenade.Kind.SMOKE], "SMOKE 1")
	assert_eq(texts[Grenade.Kind.FLASH], "FLASH 1")
	assert_eq(texts[Grenade.Kind.NONE], "")
	c.grenades.spend(Grenade.Kind.FLASH)
	p.refresh(c.armament, c.grenades)
	assert_eq(p.bomb_texts()[Grenade.Kind.FLASH], "FLASH 0")
	assert_eq(p.bomb_texts()[Grenade.Kind.SMOKE], "SMOKE 1")
	c.respawn()
	p.refresh(c.armament, c.grenades)
	assert_eq(p.bomb_texts()[Grenade.Kind.FLASH], "FLASH 1", "a respawn shows them back")


func test_a_replica_put_down_for_a_throw_is_not_said_to_be_holstered() -> void:
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, loadout)
	c.grenades.carry(1, 1)
	var p := _panel(c)
	c.armament.put_down()
	c.grenades.throwing = Grenade.Kind.SMOKE
	p.refresh(c.armament, c.grenades)
	assert_false(p._status.visible, "no HOLSTERED flicker in a throw")
	c.grenades.stop()
	p.refresh(c.armament, c.grenades)
	assert_eq(p._status.text, "HOLSTERED", "a replica left away reads as holstered once the throw is over")
	assert_true(p._status.visible)
	c.armament.holstered = false
	p.refresh(c.armament, c.grenades)
	assert_false(p._status.visible)


func test_a_refresh_with_no_hand_leaves_the_bomb_row_alone() -> void:
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, loadout)
	var p := ReplicaPanel.new()
	add_child_autofree(p)
	p.setup(HudConfig.new())
	p.refresh(c.armament)
	assert_eq(p.bomb_texts()[Grenade.Kind.SMOKE], "")


# --- Key bindings and input ---


func test_the_throw_keys_default_to_4_and_5_and_are_in_project_godot() -> void:
	var b := KeyBindings.new()
	assert_true(KeyBindings.ACTIONS.has(&"throw_smoke"))
	assert_true(KeyBindings.ACTIONS.has(&"throw_flash"))
	# On 4 and 5 since MC1 (owner, 2026-11-01; were G and Y).
	assert_eq(Array(b.codes(&"throw_smoke")), [KEY_4])
	assert_eq(Array(b.codes(&"throw_flash")), [KEY_5])
	assert_true(InputMap.has_action(&"throw_smoke"))
	assert_true(InputMap.has_action(&"throw_flash"))


func test_no_default_key_is_bound_to_two_actions() -> void:
	var b := KeyBindings.new()
	var seen := {}
	for action: StringName in KeyBindings.ACTIONS:
		for code: int in b.codes(action):
			assert_false(seen.has(code), "%s shares a key with %s" % [action, seen.get(code, &"")])
			seen[code] = action


func test_taking_the_flash_key_for_smoke_swaps_the_two() -> void:
	var b := KeyBindings.new()
	assert_eq(b.rebind(&"throw_smoke", KEY_5), KeyBindings.Result.SWAPPED)
	assert_eq(b.last_other, &"throw_flash")
	assert_eq(Array(b.codes(&"throw_smoke")), [KEY_5])
	assert_eq(Array(b.codes(&"throw_flash")), [KEY_4])
	assert_eq(b.action_of(KEY_4), &"throw_flash")


func test_every_action_has_a_label_for_the_controls_page() -> void:
	for action: StringName in [&"throw_smoke", &"throw_flash"]:
		var key := "ACT_%s" % String(action).to_upper()
		assert_ne(tr(key), key, "%s is translated" % key)


func _input_press(input: PlayerInput, action: StringName) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	input._unhandled_input(e)


func _player_input() -> PlayerInput:
	var input := PlayerInput.new()
	input.setup(ControlsConfig.new(), 1.5)
	add_child_autofree(input)
	input.active = true
	return input


func test_a_throw_key_press_reaches_the_next_command_once() -> void:
	var input := _player_input()
	var cmd := PlayerCommand.new()
	_input_press(input, &"throw_smoke")
	input.fill(cmd)
	assert_eq(cmd.throw_grenade, Grenade.Kind.SMOKE)
	input.fill(cmd)
	assert_eq(cmd.throw_grenade, Grenade.Kind.NONE, "a press is one throw")
	_input_press(input, &"throw_flash")
	input.fill(cmd)
	assert_eq(cmd.throw_grenade, Grenade.Kind.FLASH)


func test_both_throw_keys_in_one_tick_send_the_last_pressed() -> void:
	var input := _player_input()
	var cmd := PlayerCommand.new()
	_input_press(input, &"throw_smoke")
	_input_press(input, &"throw_flash")
	input.fill(cmd)
	assert_eq(cmd.throw_grenade, Grenade.Kind.FLASH)


func test_a_throw_pressed_while_inactive_or_before_a_release_never_arrives() -> void:
	var input := _player_input()
	var cmd := PlayerCommand.new()
	input.active = false
	_input_press(input, &"throw_smoke")
	input.active = true
	input.fill(cmd)
	assert_eq(cmd.throw_grenade, Grenade.Kind.NONE, "a press in a menu is dropped")
	_input_press(input, &"throw_flash")
	input.release()
	input.active = true
	input.fill(cmd)
	assert_eq(cmd.throw_grenade, Grenade.Kind.NONE, "focus lost drops a latched press")


func test_a_filled_command_clears_a_stale_throw_when_nothing_is_pressed() -> void:
	var input := _player_input()
	var cmd := PlayerCommand.new()
	cmd.throw_grenade = Grenade.Kind.SMOKE
	input.fill(cmd)
	assert_eq(cmd.throw_grenade, Grenade.Kind.NONE)


# --- The throw's edge cases ---


func test_a_press_while_vaulting_is_refused() -> void:
	var m := _match(_world())
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var cmds := _commands(s)
	s.characters[0].vault.active = true
	cmds[0].throw_grenade = Grenade.Kind.SMOKE
	assert_eq(_run(sim, s, cmds, 1, GameEvent.Kind.GRENADE_PIN), 0)
	assert_false(Grenades.throwing(s.characters[0]))
	assert_false(s.characters[0].armament.holstered)


func test_a_sprinting_throw_adds_the_runners_speed_to_the_bomb() -> void:
	var m := _match(_world())
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var cmds := _commands(s)
	var c := s.characters[0]
	_place(c, Vector3(-10.0, 0.0, 0.0), -PI * 0.5)
	cmds[0].yaw = -PI * 0.5
	cmds[0].forward = 1.0
	cmds[0].sprint = true
	cmds[0].throw_grenade = Grenade.Kind.SMOKE
	var speed := 0.0
	for t in ceili(cfg.windup / DT) + 3:
		sim.step(s, cmds, DT)
		cmds[0].throw_grenade = Grenade.Kind.NONE
		var e := s.events.first(GameEvent.Kind.GRENADE_THROW)
		if e != null:
			speed = e.direction.length()
	assert_gt(speed, cfg.throw_speed, "the runner's own speed rides along")


func test_a_full_pool_at_the_release_keeps_the_bomb_and_still_redraws_the_replica() -> void:
	var m := _match(_world())
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var cmds := _commands(s)
	var c := s.characters[0]
	cmds[0].throw_grenade = Grenade.Kind.SMOKE
	_run(sim, s, cmds, 2)
	assert_true(Grenades.throwing(c))
	for g in s.grenades:
		g.launch(Grenade.Kind.SMOKE, 3, Vector3(20.0, 0.04, 5.0), Vector3.ZERO)
		g.resting = true
		g.popped = true
	var thrown := _run(sim, s, cmds, ceili((cfg.windup + cfg.recover) / DT) + 4, GameEvent.Kind.GRENADE_THROW)
	assert_eq(thrown, 0, "no slot: nothing leaves the hand")
	assert_eq(c.grenades.smoke, 1, "the bomb is kept")
	assert_false(Grenades.throwing(c), "the throw is over")
	assert_false(c.armament.holstered, "the replica comes back up")


func test_a_respawn_mid_windup_ends_the_throw_and_leaves_the_replica_in_hand() -> void:
	var m := _match(_world())
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var cmds := _commands(s)
	var c := s.characters[0]
	cmds[0].throw_grenade = Grenade.Kind.FLASH
	_run(sim, s, cmds, 3)
	assert_true(Grenades.throwing(c))
	c.respawn()
	assert_false(Grenades.throwing(c))
	assert_false(c.armament.holstered)
	var thrown := _run(sim, s, cmds, ceili(cfg.windup / DT) + 3, GameEvent.Kind.GRENADE_THROW)
	assert_eq(thrown, 0, "no ghost throw after the respawn")
	assert_eq(c.grenades.flash, 1)


func test_a_hit_after_the_release_leaves_the_bomb_flying_and_the_thrower_out() -> void:
	var m := _match(_world())
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var cmds := _commands(s)
	var c := s.characters[0]
	_place(c, Vector3(-10.0, 0.0, 0.0), -PI * 0.5)
	cmds[0].yaw = -PI * 0.5
	cmds[0].throw_grenade = Grenade.Kind.SMOKE
	var thrown := _run(sim, s, cmds, ceili(cfg.windup / DT) + 2, GameEvent.Kind.GRENADE_THROW)
	assert_eq(thrown, 1)
	Elimination.eliminate(c, 3, s.characters, sim.ends)
	var pops := _run(sim, s, cmds, ceili(cfg.smoke_fuse / DT) + 5, GameEvent.Kind.SMOKE_POP)
	assert_eq(pops, 1, "the bomb already in the air still pops")
	assert_false(Grenades.throwing(c))
	assert_eq(c.grenades.smoke, 0, "and stays spent")


func test_a_round_ending_mid_flight_lets_the_bomb_finish_and_a_new_round_clears_it() -> void:
	var m := _match(_world())
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var cmds := _commands(s)
	var c := s.characters[0]
	_place(c, Vector3(-10.0, 0.0, 0.0), -PI * 0.5)
	cmds[0].yaw = -PI * 0.5
	cmds[0].throw_grenade = Grenade.Kind.SMOKE
	_run(sim, s, cmds, ceili(cfg.windup / DT) + 2)
	s.round_state.phase = RoundState.Phase.OVER
	s.round_state.timer = 60.0
	var pops := _run(sim, s, cmds, ceili(cfg.smoke_fuse / DT) + 5, GameEvent.Kind.SMOKE_POP)
	assert_eq(pops, 1, "the whistle doesn't stop a bomb already thrown")
	assert_eq(_active_count(s), 1)
	assert_false(Grenades.throwing(c))


func _active_count(s: GameState) -> int:
	var n := 0
	for g in s.grenades:
		if g.active:
			n += 1
	return n


func test_a_torch_that_was_on_is_back_on_after_the_throw_and_off_in_between() -> void:
	var m := _match(_world())
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var cmds := _commands(s)
	var c := s.characters[0]
	c.armament.lights = [Torch.Light.new(), Torch.Light.new()]
	c.torch_on = true
	cmds[0].throw_grenade = Grenade.Kind.FLASH
	_run(sim, s, cmds, 3)
	assert_false(c.torch_on, "off with the replica down")
	_run(sim, s, cmds, ceili((cfg.windup + cfg.recover) / DT) + 3)
	assert_false(Grenades.throwing(c))
	assert_true(c.torch_on, "back on with the replica")


func test_a_torch_pressed_during_the_windup_does_not_switch_it_on_with_the_replica_down() -> void:
	var m := _match(_world())
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var cmds := _commands(s)
	var c := s.characters[0]
	c.armament.lights = [Torch.Light.new(), Torch.Light.new()]
	c.torch_on = false
	cmds[0].throw_grenade = Grenade.Kind.FLASH
	_run(sim, s, cmds, 2)
	cmds[0].toggle_torch = true
	_run(sim, s, cmds, 2)
	cmds[0].toggle_torch = false
	assert_false(c.torch_on)
	_run(sim, s, cmds, ceili((cfg.windup + cfg.recover) / DT) + 3)
	assert_false(c.torch_on, "it was off before the throw and is off after")


func test_a_bomb_thrown_straight_up_or_down_ends_on_the_floor_never_under_it() -> void:
	for pitch: float in [PI * 0.5, -PI * 0.5]:
		var m := _match(_world())
		var sim: Simulation = m[0]
		var s: GameState = m[1]
		var cmds := _commands(s)
		var c := s.characters[0]
		_place(c, Vector3(-10.0, 0.0, 0.0), 0.0, pitch)
		cmds[0].pitch = pitch
		cmds[0].throw_grenade = Grenade.Kind.FLASH
		var lowest := 100.0
		for t in 360:
			sim.step(s, cmds, DT)
			cmds[0].throw_grenade = Grenade.Kind.NONE
			cmds[0].pitch = pitch
			for g in s.grenades:
				if g.active:
					lowest = minf(lowest, g.position.y)
		assert_gt(lowest, -0.01, "never through the floor (pitch %.2f)" % pitch)


func test_a_bomb_thrown_at_a_wall_an_arm_away_stays_on_the_thrower_side() -> void:
	var m := _match(_world(5.0))
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var cmds := _commands(s)
	var c := s.characters[0]
	_place(c, Vector3(4.55, 0.0, 0.0), -PI * 0.5)
	cmds[0].yaw = -PI * 0.5
	cmds[0].throw_grenade = Grenade.Kind.SMOKE
	var farthest := -100.0
	for t in 300:
		sim.step(s, cmds, DT)
		cmds[0].throw_grenade = Grenade.Kind.NONE
		for g in s.grenades:
			if g.active:
				farthest = maxf(farthest, g.position.x)
	assert_lt(farthest, 4.95, "the wall's face is at 4.9: the bomb did not go through it")


func test_a_flash_does_not_dazzle_someone_already_out_and_a_smoke_never_does() -> void:
	var m := _match(_world())
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var cmds := _commands(s)
	var out := s.characters[1]
	_place(out, Vector3(0.0, 0.0, 0.0), 0.0)
	Elimination.eliminate(out, 3, s.characters, sim.ends)
	_place(out, Vector3(0.0, 0.0, 0.0), 0.0)
	var g := s.grenades[0]
	g.launch(Grenade.Kind.FLASH, 0, Vector3(0.0, 0.04, -2.0), Vector3.ZERO)
	g.resting = true
	g.age = cfg.flash_fuse
	var bangs := _run(sim, s, cmds, 2, GameEvent.Kind.FLASH_BANG)
	assert_eq(bangs, 1)
	assert_eq(out.dazzle_left, 0.0, "out of play: no dazzle")


func test_a_smoke_dazzles_nobody() -> void:
	var m := _match(_world())
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var cmds := _commands(s)
	_smoke_at(s, 1, Vector3(0.0, 0.04, -2.0), cfg.smoke_grow)
	assert_eq(_run(sim, s, cmds, 30, GameEvent.Kind.DAZZLED), 0)
	for c in s.characters:
		assert_eq(c.dazzle_left, 0.0)


# --- Smoke and bots ---


func test_two_overlapping_clouds_hide_more_than_one() -> void:
	var s := GameState.new(5, tuning)
	_smoke_at(s, 0, Vector3(0.0, 0.04, -5.0), cfg.smoke_grow + 1.0)
	var one := Grenades.smoke_depth(s.grenades, cfg, Vector3(0.0, 1.5, 0.0), Vector3(0.0, 1.5, -10.0))
	_smoke_at(s, 1, Vector3(0.0, 0.04, -5.0), cfg.smoke_grow + 1.0)
	var two := Grenades.smoke_depth(s.grenades, cfg, Vector3(0.0, 1.5, 0.0), Vector3(0.0, 1.5, -10.0))
	assert_gt(one, 0.0)
	assert_almost_eq(two, one * 2.0, 1e-3)


func test_a_line_that_ends_before_the_cloud_or_starts_after_it_passes_through_none() -> void:
	var s := GameState.new(5, tuning)
	_smoke_at(s, 0, Vector3(0.0, 0.04, -10.0), cfg.smoke_grow + 1.0)
	assert_eq(Grenades.smoke_depth(s.grenades, cfg, Vector3(0.0, 1.5, 0.0), Vector3(0.0, 1.5, -3.0)), 0.0, "short")
	assert_eq(Grenades.smoke_depth(s.grenades, cfg, Vector3(0.0, 1.5, -20.0), Vector3(0.0, 1.5, -30.0)), 0.0, "past")
	assert_eq(Grenades.smoke_depth(s.grenades, cfg, Vector3.ZERO, Vector3.ZERO), 0.0, "no length")


func test_a_cloud_inside_a_line_counts_only_its_own_part() -> void:
	var s := GameState.new(5, tuning)
	var g := _smoke_at(s, 0, Vector3(0.0, 0.04, -10.0), cfg.smoke_grow + 1.0)
	var mid := Grenades.cloud_middle(g, cfg)
	var from_inside := Grenades.smoke_depth(s.grenades, cfg, mid, mid + Vector3(0.0, 0.0, -20.0))
	assert_almost_eq(from_inside, cfg.smoke_radius, 0.05, "from the middle out: one radius")


func test_a_bot_in_the_middle_of_a_cloud_sees_a_far_enemy_only_when_it_has_thinned() -> void:
	var bots := BotConfig.load_default()
	var me := Character.new(0, 0, Vector3.ZERO, 0.0, loadout)
	var foe := Character.new(1, 1, Vector3(0.0, 0.0, -14.0), 0.0, loadout)
	var w := BotWorld.new()
	w.tuning = tuning
	w.cfg = bots
	w.query = _world()
	w.planner = RoundPlanner.new(1)
	w.characters = [me, foe]
	w.time = 10.0
	w.grenades = Grenades.make_pool(2)
	var g := w.grenades[0]
	g.launch(Grenade.Kind.SMOKE, 0, Vector3(0.0, 0.04, 0.0), Vector3.ZERO)
	g.resting = true
	g.popped = true
	g.smoking = cfg.smoke_grow + 1.0
	assert_eq(BotSenses.visible_part(me, foe, w), 0.0, "inside a cloud it sees out of it no better")
	g.smoking = cfg.smoke_time - 0.05
	assert_gt(BotSenses.visible_part(me, foe, w), 0.0, "a last wisp lets it through")


func test_a_bot_whose_dazzle_has_worn_off_sees_the_enemy_again() -> void:
	var bots := BotConfig.load_default()
	var me := Character.new(0, 0, Vector3.ZERO, 0.0, loadout)
	var foe := Character.new(1, 1, Vector3(0.0, 0.0, -10.0), 0.0, loadout)
	var w := BotWorld.new()
	w.tuning = tuning
	w.cfg = bots
	w.query = _world()
	w.planner = RoundPlanner.new(1)
	w.characters = [me, foe]
	w.time = 10.0
	w.grenades = Grenades.make_pool(2)
	me.dazzle_left = 0.02
	assert_eq(BotSenses.visible_part(me, foe, w), 0.0)
	me.dazzle_left = 0.0
	assert_gt(BotSenses.visible_part(me, foe, w), 0.0, "sees again")
