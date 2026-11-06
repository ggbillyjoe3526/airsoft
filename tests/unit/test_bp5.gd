extends GutTest
## BP5, the second full bug and performance pass: in-match fixes. The trigger pull that throws a bomb in hand (MC1), or
## is held as one goes back, doesn't fire the replica once it is up again until the trigger is let go; the torch that
## was on before a bomb in hand comes back on after the throw, as before, and now when the bomb goes back too. Off the
## field: a hand-edited records save can't overflow a count; the Loadout's slot keys follow a rebind.

const DT := 1.0 / 60.0

var tuning: SimTuning = SimTuning.new()
var loadout: Array[ReplicaConfig] = []


func before_all() -> void:
	loadout = ReplicaStats.default_loadout()


func after_each() -> void:
	InputMap.load_from_project_settings()


func _match() -> Array:
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


## Steps `ticks` ticks, one-shot presses cleared after each; returns the SHOT and TORCH events of character 0 seen.
func _run(sim: Simulation, s: GameState, cmds: Array[PlayerCommand], ticks: int) -> Dictionary:
	var shots := 0
	var torch_on := 0
	var torch_off := 0
	for t in ticks:
		sim.step(s, cmds, DT)
		for i in s.events.count:
			var e := s.events.items[i]
			if e.actor != 0:
				continue
			if e.kind == GameEvent.Kind.SHOT:
				shots += 1
			elif e.kind == GameEvent.Kind.TORCH:
				if e.value == 1:
					torch_on += 1
				else:
					torch_off += 1
		for cmd in cmds:
			cmd.ready_grenade = Grenade.Kind.NONE
			cmd.throw_grenade = Grenade.Kind.NONE
			cmd.switch_to = -1
	return {"shots": shots, "torch_on": torch_on, "torch_off": torch_off}


func _throw_ticks() -> int:
	return roundi((tuning.grenades.windup + tuning.grenades.recover) / DT)


## Ticks for the replica to come back up and be ready after the throw, with room to spare.
func _redraw_ticks(you: Character) -> int:
	return roundi(you.armament.replica().draw_time / DT) + 30


func _on_full_auto(you: Character) -> void:
	assert_true(you.armament.replica().fire_modes.has(ReplicaConfig.FireMode.AUTO), "the AEG has full auto")
	you.armament.modes[you.armament.active] = ReplicaConfig.FireMode.AUTO


func test_a_trigger_held_after_the_pull_that_throws_a_bomb_in_hand_doesn_t_fire_the_replica_back_up() -> void:
	var m := _match()
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var you := s.characters[0]
	var cmds := _commands(s)
	_run(sim, s, cmds, 30)
	_on_full_auto(you)
	cmds[0].ready_grenade = Grenade.Kind.SMOKE
	_run(sim, s, cmds, 10)
	cmds[0].fire = true
	var held := _run(sim, s, cmds, _throw_ticks() + _redraw_ticks(you))
	assert_false(Grenades.throwing(you), "thrown")
	assert_false(you.armament.holstered, "the replica is back up")
	assert_eq(held["shots"], 0, "the held pull fired nothing (it fired on its own before BP5)")
	cmds[0].fire = false
	_run(sim, s, cmds, 1)
	cmds[0].fire = true
	assert_gt(_run(sim, s, cmds, 10)["shots"], 0, "a fresh pull fires")


func test_a_trigger_held_as_a_slot_puts_the_bomb_back_doesn_t_fire_until_let_go() -> void:
	var m := _match()
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var you := s.characters[0]
	var cmds := _commands(s)
	_run(sim, s, cmds, 30)
	_on_full_auto(you)
	cmds[0].ready_grenade = Grenade.Kind.SMOKE
	_run(sim, s, cmds, 5)
	cmds[0].fire = true
	_run(sim, s, cmds, 1)
	assert_true(Grenades.throwing(you), "that pull threw it")
	# a new bomb in hand, the trigger still down from the pull, and a slot press puts it back
	_run(sim, s, cmds, _throw_ticks() + 2)
	cmds[0].ready_grenade = Grenade.Kind.FLASH
	_run(sim, s, cmds, 5)
	assert_eq(you.grenades.readied, Grenade.Kind.FLASH, "a held trigger doesn't throw it")
	cmds[0].switch_to = 0
	var held := _run(sim, s, cmds, _redraw_ticks(you))
	assert_eq(you.grenades.readied, Grenade.Kind.NONE, "put back")
	assert_eq(held["shots"], 0, "the held trigger fires nothing")
	cmds[0].fire = false
	_run(sim, s, cmds, 1)
	cmds[0].fire = true
	assert_gt(_run(sim, s, cmds, 10)["shots"], 0, "a fresh pull fires")


func test_a_throw_with_the_trigger_let_go_still_lets_a_held_full_auto_fire_after_it() -> void:
	var m := _match()
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var you := s.characters[0]
	var cmds := _commands(s)
	_run(sim, s, cmds, 30)
	_on_full_auto(you)
	cmds[0].ready_grenade = Grenade.Kind.SMOKE
	_run(sim, s, cmds, 5)
	cmds[0].fire = true
	_run(sim, s, cmds, 1)
	cmds[0].fire = false
	_run(sim, s, cmds, _throw_ticks() + _redraw_ticks(you))
	cmds[0].fire = true
	assert_gt(_run(sim, s, cmds, 10)["shots"], 0, "held after a release: it fires")


func _with_torch(you: Character) -> void:
	var light := Torch.Light.new()
	light.key = &"weaponTorch"
	light.reach = 30.0
	var lights: Array[Torch.Light] = [light, light]
	you.armament.lights = lights


func test_the_torch_comes_back_on_after_a_bomb_in_hand_is_thrown() -> void:
	var m := _match()
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var you := s.characters[0]
	var cmds := _commands(s)
	_with_torch(you)
	_run(sim, s, cmds, 30)
	you.torch_on = true
	cmds[0].ready_grenade = Grenade.Kind.SMOKE
	assert_eq(_run(sim, s, cmds, 5)["torch_off"], 1, "out as the replica goes down, with its click")
	assert_false(you.torch_on)
	cmds[0].fire = true
	_run(sim, s, cmds, 1)
	cmds[0].fire = false
	var after := _run(sim, s, cmds, _throw_ticks() + 2)
	assert_true(you.torch_on, "on again once the replica is back")
	assert_eq(after["torch_on"], 0, "silently, as it always came back after a throw")


func test_the_torch_comes_back_on_when_a_slot_puts_the_bomb_back() -> void:
	var m := _match()
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var you := s.characters[0]
	var cmds := _commands(s)
	_with_torch(you)
	_run(sim, s, cmds, 30)
	you.torch_on = true
	cmds[0].ready_grenade = Grenade.Kind.SMOKE
	_run(sim, s, cmds, 5)
	assert_false(you.torch_on)
	cmds[0].switch_to = 0
	var back := _run(sim, s, cmds, 2)
	assert_eq(you.grenades.readied, Grenade.Kind.NONE, "put back")
	assert_true(you.torch_on, "on again (it stayed off before BP5)")
	assert_eq(back["torch_on"], 0, "as after a throw")


func test_the_torch_comes_back_on_when_a_reload_puts_the_bomb_back() -> void:
	var m := _match()
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var you := s.characters[0]
	var cmds := _commands(s)
	_with_torch(you)
	_run(sim, s, cmds, 30)
	you.torch_on = true
	cmds[0].ready_grenade = Grenade.Kind.SMOKE
	_run(sim, s, cmds, 5)
	assert_false(you.torch_on)
	cmds[0].reload = true
	var back := _run(sim, s, cmds, 2)
	assert_eq(you.grenades.readied, Grenade.Kind.NONE, "put back")
	assert_true(you.torch_on, "on again")
	assert_eq(back["torch_on"], 0, "silently")


func test_a_torch_off_before_the_bomb_stays_off() -> void:
	var m := _match()
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var you := s.characters[0]
	var cmds := _commands(s)
	_with_torch(you)
	_run(sim, s, cmds, 30)
	cmds[0].ready_grenade = Grenade.Kind.SMOKE
	_run(sim, s, cmds, 5)
	cmds[0].fire = true
	_run(sim, s, cmds, 1)
	cmds[0].fire = false
	var after := _run(sim, s, cmds, _throw_ticks() + 2)
	assert_false(you.torch_on)
	assert_eq(after["torch_on"], 0)


# --- off the field ---


func test_a_records_count_too_big_for_an_int_is_left_out() -> void:
	var r := Records.new()
	var problems := r.from_dict({"best_challenge": {"range": 1e300, "street": 42}})
	assert_false(r.best_challenge.has("range"), "1e300 left out")
	assert_eq(r.best_challenge.get("street", 0), 42)
	assert_gt(problems.size(), 0, "and said")


func test_the_loadout_s_slot_keys_show_the_bound_keys() -> void:
	InputMap.action_erase_events(&"slot_1")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F7
	InputMap.action_add_event(&"slot_1", key)
	var shown := KeyNames.of_action(&"slot_1")
	assert_ne(shown, "1", "the rebound key, not the default")
	var page := LoadoutPage.new(SavedLoadouts.new(LoadoutRules.standard()), Settings.new())
	add_child_autofree(page)
	var chip := page.find_children("*", "Label", true, false).filter(func(n: Node) -> bool:
			return (n as Label).text == shown)
	assert_gt(chip.size(), 0, "the PRIMARY card's chip shows %s" % shown)


func test_the_loadout_s_slot_keys_follow_a_rebind_made_while_the_page_is_built() -> void:
	var page := LoadoutPage.new(SavedLoadouts.new(LoadoutRules.standard()), Settings.new())
	add_child_autofree(page)
	InputMap.action_erase_events(&"slot_2")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F8
	InputMap.action_add_event(&"slot_2", key)
	var shown := KeyNames.of_action(&"slot_2")
	page.visible = false
	page.visible = true
	var chip := page.find_children("*", "Label", true, false).filter(func(n: Node) -> bool:
			return (n as Label).text == shown)
	assert_gt(chip.size(), 0, "back from Settings, the SECONDARY card's chip shows %s" % shown)
