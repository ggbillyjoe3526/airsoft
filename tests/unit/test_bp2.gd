extends GutTest
## BP2 (the 0.1 Dev 2 bug pass): one test or more for each bug it fixed.

const DT := 1.0 / 60.0


func _wheel_input() -> PlayerInput:
	var input := PlayerInput.new()
	add_child_autofree(input)
	input.setup(ControlsConfig.new(), 1.5)
	input.active = true
	return input


func _notch(input: PlayerInput, button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	input._unhandled_input(event)


func test_a_wheel_notch_with_the_replica_holstered_draws_the_other_replica_not_a_bomb() -> void:
	var input := _wheel_input()
	var hand := Grenades.Hand.new()
	hand.carry(1, 1)
	var cmd := PlayerCommand.new()
	_notch(input, MOUSE_BUTTON_WHEEL_DOWN)
	input.fill(cmd, 1, hand, true)
	assert_eq(cmd.ready_grenade, Grenade.Kind.NONE, "no smoke taken from the holster")
	assert_eq(cmd.switch_to, 0, "past the bombs, round to the first replica")
	_notch(input, MOUSE_BUTTON_WHEEL_UP)
	input.fill(cmd, 0, hand, true)
	assert_eq(cmd.ready_grenade, Grenade.Kind.NONE, "no flash taken from the holster")
	assert_eq(cmd.switch_to, 1, "back past the bombs to the pistol")
	input.active = false


func test_a_wheel_notch_with_a_bomb_in_hand_still_steps_the_bombs() -> void:
	var input := _wheel_input()
	var hand := Grenades.Hand.new()
	hand.carry(1, 1)
	hand.readied = Grenade.Kind.SMOKE
	var cmd := PlayerCommand.new()
	_notch(input, MOUSE_BUTTON_WHEEL_DOWN)
	# a bomb in hand puts the replica down, so the armament reads holstered
	input.fill(cmd, 1, hand, true)
	assert_eq(cmd.ready_grenade, Grenade.Kind.FLASH, "smoke on to the flash")
	input.active = false


func test_woodlands_reflection_probes_capture_over_the_ground_not_inside_a_hill() -> void:
	var play := PlayTuning.load_default()
	var woodland := MapData.load_map("woodland", play.map_style, SimTuning.load_default().rounds.team_size)
	assert_not_null(woodland.terrain, "Woodland's ground rises and falls")
	var look := play.look
	var probes := AreaProbes.build(woodland, look)
	add_child_autofree(probes)
	var raised := 0
	for p: ReflectionProbe in probes.get_children():
		var eye := p.position + p.origin_offset
		var ground := woodland.terrain.height_at(p.position.x, p.position.z)
		if is_nan(ground):
			continue
		if ground > 1.0:
			raised += 1
		assert_almost_eq(eye.y, ground + look.probe_eye, 0.01, "eye height over the ground: %s" % p.name)
		var bottom := p.position.y - p.size.y * 0.5
		var top := p.position.y + p.size.y * 0.5
		assert_true(eye.y > bottom and eye.y < top, "the capture point inside its box: %s" % p.name)
		assert_lte(bottom, ground + 0.001, "the box reaches down to the ground: %s" % p.name)
	assert_gt(raised, 0, "some probes stand on raised ground")


func test_every_maps_open_doors_fold_back_in_sight_not_inside_a_wall() -> void:
	var play := PlayTuning.load_default()
	var swing := SimTuning.load_default().doors.swing_time
	for id: String in ["depot", "woodland", "street"]:
		var map := MapData.load_map(id, play.map_style, SimTuning.load_default().rounds.team_size)
		var view := DoorView.build(map, play.map_style, swing)
		if view == null:
			continue
		add_child_autofree(view)
		var doors := DoorState.new()
		doors.shut.resize(map.doors.size())
		doors.swing_left.resize(map.doors.size())
		view.refresh(doors) # every door open, no swing left
		for j in map.doors.size() * 2:
			var leaf := view.leaf_at(j)
			for b in map.blocks:
				if b.kind == &"floor" or b.kind == &"ramp":
					continue
				var inside := AABB(b.center - b.size * 0.5 + Vector3.ONE * 0.01, b.size - Vector3.ONE * 0.02)
				assert_false(inside.has_point(leaf.origin),
						"%s door %d's open leaf %d is inside a %s block" % [id, j / 2, j % 2, b.kind])


func test_on_the_range_a_bomb_taken_in_hand_stays_there_and_a_pull_throws_it() -> void:
	var tuning := SimTuning.new()
	var w := BoxWorld.new(tuning.body)
	w.add_floor(60.0, 30.0)
	var ends: Array[MapEnd] = []
	for e in 2:
		var end := MapEnd.new()
		end.spawns.append(SpawnPoint.new(Vector3(-10.0 if e == 0 else 10.0, 0.0, 0.0), 0.0))
		end.dead_zone.append(SpawnPoint.new(Vector3(-25.0 if e == 0 else 25.0, 0.0, 10.0), 0.0))
		ends.append(end)
	var sim := Simulation.new(tuning, w, w.mover(), ends, -10.0)
	var s := GameState.new(5, tuning)
	s.round_state.practice = true
	s.characters.append(Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout()))
	sim.start_match(s)
	var you := s.characters[0]
	var cmd := PlayerCommand.new()
	cmd.reset(you.yaw, you.pitch)
	var cmds: Array[PlayerCommand] = [cmd]
	for t in 30:
		sim.step(s, cmds, DT)
	var smokes := you.grenades.smoke
	cmd.ready_grenade = Grenade.Kind.SMOKE
	sim.step(s, cmds, DT)
	cmd.ready_grenade = Grenade.Kind.NONE
	sim.step(s, cmds, DT)
	assert_eq(you.grenades.readied, Grenade.Kind.SMOKE, "the range's restock leaves the bomb in hand")
	cmd.fire = true
	sim.step(s, cmds, DT)
	cmd.fire = false
	assert_true(Grenades.throwing(you), "the pull throws it")
	for t in roundi((tuning.grenades.windup + tuning.grenades.recover) / DT) + 2:
		sim.step(s, cmds, DT)
	assert_eq(you.grenades.smoke, smokes, "and the range gives it back")
	var thrown := 0
	for g in s.grenades:
		if g.active:
			thrown += 1
	assert_eq(thrown, 1, "the smoke is out")


func test_the_door_prompt_names_uses_key_as_rebound_while_you_stand_at_the_door() -> void:
	var frame := Control.new()
	frame.size = Vector2(1920.0, 1080.0)
	add_child_autofree(frame)
	var hud := Hud.new()
	frame.add_child(hud)
	var you := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	hud.setup(HudConfig.new(), TeamConfig.new(), ViewConfig.new(), SimTuning.new(), you)
	hud.set_door_prompt(Hud.DoorPrompt.OPEN)
	var before := hud._door_prompt.text
	var key := InputEventKey.new()
	key.physical_keycode = KEY_K
	InputMap.action_erase_events(&"use_door")
	InputMap.action_add_event(&"use_door", key)
	hud.set_door_prompt(Hud.DoorPrompt.OPEN)
	assert_eq(hud._door_prompt.text, before, "unchanged while the prompt is")
	hud.refresh_door_prompt()
	assert_ne(hud._door_prompt.text, before, "built again with the new key")
	assert_string_contains(hud._door_prompt.text, KeyNames.of_action(&"use_door"))
	InputMap.load_from_project_settings()
