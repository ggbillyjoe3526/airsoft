extends GutTest
## BP5 QA: edge cases around the held-trigger and torch-back changes (instant throws, a hit, a respawn, a vault, a
## semi replica, the holster) and the records count bound.

const DT := 1.0 / 60.0

var tuning: SimTuning = SimTuning.new()
var loadout: Array[ReplicaConfig] = []


func before_all() -> void:
	loadout = ReplicaStats.default_loadout()


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


func _run(sim: Simulation, s: GameState, cmds: Array[PlayerCommand], ticks: int) -> int:
	var shots := 0
	for t in ticks:
		sim.step(s, cmds, DT)
		for i in s.events.count:
			var e := s.events.items[i]
			if e.actor == 0 and e.kind == GameEvent.Kind.SHOT:
				shots += 1
		for cmd in cmds:
			cmd.ready_grenade = Grenade.Kind.NONE
			cmd.throw_grenade = Grenade.Kind.NONE
			cmd.switch_to = -1
			cmd.holster = false
	return shots


func _auto(you: Character) -> void:
	you.armament.modes[you.armament.active] = ReplicaConfig.FireMode.AUTO


func _settle(sim: Simulation, s: GameState, cmds: Array[PlayerCommand]) -> void:
	_run(sim, s, cmds, 30)


func _long() -> int:
	return roundi((tuning.grenades.windup + tuning.grenades.recover) / DT) + 120


func test_an_instant_throw_with_a_held_trigger_still_fires_after_it_as_before() -> void:
	var m := _match()
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var cmds := _commands(s)
	_settle(sim, s, cmds)
	_auto(s.characters[0])
	cmds[0].fire = true
	cmds[0].throw_grenade = Grenade.Kind.SMOKE
	var shots := _run(sim, s, cmds, _long())
	assert_false(Grenades.throwing(s.characters[0]))
	assert_gt(shots, 0, "G is not a bomb in hand: the held trigger fires once the replica is back")


func test_a_respawn_clears_a_held_off_trigger() -> void:
	var m := _match()
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var you := s.characters[0]
	you.grenades.trigger_held_off = true
	you.grenades.torch_back = true
	you.respawn()
	assert_false(you.grenades.trigger_held_off)
	assert_false(you.grenades.torch_back)


func test_a_hit_while_the_trigger_is_held_off_leaves_nothing_to_fire() -> void:
	var m := _match()
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var you := s.characters[0]
	var cmds := _commands(s)
	_settle(sim, s, cmds)
	_auto(you)
	cmds[0].ready_grenade = Grenade.Kind.SMOKE
	_run(sim, s, cmds, 5)
	cmds[0].fire = true
	_run(sim, s, cmds, 1)
	assert_true(you.grenades.trigger_held_off)
	you.status = Character.Status.CALLING
	var shots := _run(sim, s, cmds, 20)
	assert_eq(shots, 0, "a character out of play never fires")
	assert_false(Grenades.throwing(you))


func test_a_semi_replica_does_not_read_the_held_pull_as_new_after_a_put_back() -> void:
	var m := _match()
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var you := s.characters[0]
	var cmds := _commands(s)
	_settle(sim, s, cmds)
	you.armament.modes[you.armament.active] = ReplicaConfig.FireMode.SEMI
	cmds[0].ready_grenade = Grenade.Kind.SMOKE
	_run(sim, s, cmds, 5)
	cmds[0].fire = true
	_run(sim, s, cmds, 1)
	_run(sim, s, cmds, _long())
	assert_eq(_run(sim, s, cmds, 30), 0, "a semi doesn't fire from the held pull either")


func test_a_pull_pressed_during_the_throw_recovery_is_let_go_until_the_next_release() -> void:
	# the held pull threw the bomb; let go and pulled again during the recovery: the second pull is a fresh one
	var m := _match()
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var you := s.characters[0]
	var cmds := _commands(s)
	_settle(sim, s, cmds)
	_auto(you)
	cmds[0].ready_grenade = Grenade.Kind.SMOKE
	_run(sim, s, cmds, 5)
	cmds[0].fire = true
	_run(sim, s, cmds, 1)
	cmds[0].fire = false
	_run(sim, s, cmds, 3)
	cmds[0].fire = true
	var shots := _run(sim, s, cmds, _long())
	assert_gt(shots, 0, "a pull made after letting go fires once the replica is up")


func test_a_held_off_trigger_through_a_vault_ends_without_a_stray_shot() -> void:
	var m := _match()
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var you := s.characters[0]
	var cmds := _commands(s)
	_settle(sim, s, cmds)
	_auto(you)
	cmds[0].ready_grenade = Grenade.Kind.SMOKE
	_run(sim, s, cmds, 5)
	cmds[0].fire = true
	_run(sim, s, cmds, 1)
	you.vault.active = true
	you.vault.time = 0.0
	var shots := _run(sim, s, cmds, 5)
	you.vault.cancel()
	shots += _run(sim, s, cmds, _long())
	assert_eq(shots, 0, "still the one held pull")


func test_a_bomb_put_back_to_a_slot_without_a_light_leaves_the_torch_off_and_silent() -> void:
	var m := _match()
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var you := s.characters[0]
	var cmds := _commands(s)
	_settle(sim, s, cmds)
	you.torch_on = true
	assert_null(you.armament.light_in_hand(), "the default replica has no light")
	cmds[0].ready_grenade = Grenade.Kind.SMOKE
	_run(sim, s, cmds, 5)
	cmds[0].switch_to = 0
	_run(sim, s, cmds, 10)
	assert_false(you.torch_on)
	assert_false(you.grenades.torch_back, "the flag is spent")


func test_a_holstered_bomb_put_back_keeps_the_torch_flag_from_leaking() -> void:
	var m := _match()
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var you := s.characters[0]
	var cmds := _commands(s)
	_settle(sim, s, cmds)
	you.torch_on = true
	cmds[0].ready_grenade = Grenade.Kind.SMOKE
	_run(sim, s, cmds, 5)
	cmds[0].holster = true
	_run(sim, s, cmds, 5)
	assert_false(you.grenades.torch_back)
	assert_false(you.torch_on)


func test_records_counts_at_the_bound_are_kept_and_beyond_it_nan_and_inf_are_left_out() -> void:
	var r := Records.new()
	r.from_dict({"streak": Records.COUNT_MAX, "best_streak": Records.COUNT_MAX + 1.0})
	assert_eq(r.streak, Records.COUNT_MAX)
	assert_eq(r.best_streak, r.streak, "past the bound counts as none")
	var r2 := Records.new()
	r2.from_dict({"best_challenge": {"a": INF, "b": NAN, "c": 5}, "results": {"normal.elimination": [1e300, 2]}})
	assert_false(r2.best_challenge.has("a"))
	assert_false(r2.best_challenge.has("b"))
	assert_eq(r2.best_challenge.get("c", 0), 5)
	assert_false(r2.results.has("normal.elimination"))


func test_a_hit_after_the_throw_with_the_pull_still_held_leaves_nothing_held_off_after_the_respawn() -> void:
	var m := _match()
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var you := s.characters[0]
	var cmds := _commands(s)
	_settle(sim, s, cmds)
	_auto(you)
	cmds[0].ready_grenade = Grenade.Kind.SMOKE
	_run(sim, s, cmds, 5)
	cmds[0].fire = true
	_run(sim, s, cmds, _long())
	assert_true(you.grenades.trigger_held_off, "the pull that threw it is still held off")
	assert_true(Grenades.throwing(you), "held cocked while the pull is held (BP8)")
	you.status = Character.Status.CALLING
	_run(sim, s, cmds, 5)
	assert_false(Grenades.throwing(you), "a hit while cocked drops the throw")
	assert_false(you.grenades.trigger_held_off, "and with it the held-off pull: the hit can't fire anyway")
	you.status = Character.Status.ALIVE
	you.respawn()
	assert_false(you.grenades.trigger_held_off, "a new life with the trigger down starts clear")
	assert_false(you.grenades.torch_back)
