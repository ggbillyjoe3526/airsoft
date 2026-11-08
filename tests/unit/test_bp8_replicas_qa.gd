extends GutTest
## BP8 replicas QA: the held bomb throw's edges (a hit, a slot, both keys, running out, a held button through the
## bring-to-hand, the replica after the throw) and the BB hide's edges (a bounced BB, a late BB, a bot's BB).

const DT := 1.0 / 60.0

var tuning: SimTuning = SimTuning.new()
var cfg: GrenadeConfig = tuning.grenades


func _match() -> Array:
	var w := BoxWorld.new(tuning.body)
	w.add_floor(60.0, 30.0)
	var ends: Array[MapEnd] = []
	for e in 2:
		var end := MapEnd.new()
		for i in 3:
			end.spawns.append(SpawnPoint.new(Vector3(-10.0 if e == 0 else 10.0, 0.0, i * 2.0), 0.0))
			end.dead_zone.append(SpawnPoint.new(Vector3(-25.0 if e == 0 else 25.0, 0.0, 10.0), 0.0))
		ends.append(end)
	var sim := Simulation.new(tuning, w, w.mover(), ends, -10.0)
	var s := GameState.new(5, tuning)
	var loadout := ReplicaStats.default_loadout()
	for i in 2:
		s.characters.append(Character.new(i, i, Vector3.ZERO, 0.0, loadout))
	sim.start_match(s)
	var cmds: Array[PlayerCommand] = []
	for c in s.characters:
		var cmd := PlayerCommand.new()
		cmd.reset(c.yaw, c.pitch)
		cmds.append(cmd)
	return [sim, s, cmds]


func _run(sim: Simulation, s: GameState, cmds: Array[PlayerCommand], ticks: int) -> int:
	var n := 0
	for t in ticks:
		sim.step(s, cmds, DT)
		n += s.events.count_of(GameEvent.Kind.GRENADE_THROW)
		for cmd in cmds:
			cmd.throw_grenade = Grenade.Kind.NONE
			cmd.ready_grenade = Grenade.Kind.NONE
			cmd.switch_to = -1
			cmd.reload = false
	return n


func _cocked(m: Array, kind: Grenade.Kind = Grenade.Kind.SMOKE) -> void:
	var cmds: Array[PlayerCommand] = m[2]
	cmds[0].ready_grenade = kind
	_run(m[0], m[1], cmds, 3)
	cmds[0].fire = true
	_run(m[0], m[1], cmds, 60)
	assert_true(Grenades.throwing((m[1] as GameState).characters[0]), "cocked")


func test_a_hit_while_cocked_and_held_throws_nothing_and_keeps_the_bomb() -> void:
	var m := _match()
	var s: GameState = m[1]
	var cmds: Array[PlayerCommand] = m[2]
	_cocked(m)
	var you := s.characters[0]
	var before := you.grenades.smoke
	Elimination.eliminate(you, 1, s.characters, (m[0] as Simulation).ends)
	assert_eq(_run(m[0], s, cmds, 60), 0, "no bomb leaves the hand of someone hit")
	assert_false(you.grenades.throw_held, "no hold left over")
	assert_eq(you.grenades.smoke, before, "the bomb is kept")


func test_a_slot_press_while_cocked_does_not_cancel_the_hold_or_throw_early() -> void:
	var m := _match()
	var s: GameState = m[1]
	var cmds: Array[PlayerCommand] = m[2]
	_cocked(m)
	cmds[0].switch_to = 1
	assert_eq(_run(m[0], s, cmds, 30), 0, "still cocked")
	assert_true(Grenades.throwing(s.characters[0]))
	cmds[0].fire = false
	assert_eq(_run(m[0], s, cmds, 30), 1, "thrown on the release")


func test_the_other_bomb_key_while_cocked_changes_nothing() -> void:
	var m := _match()
	var s: GameState = m[1]
	var cmds: Array[PlayerCommand] = m[2]
	_cocked(m)
	cmds[0].ready_grenade = Grenade.Kind.FLASH
	_run(m[0], s, cmds, 10)
	cmds[0].fire = false
	assert_eq(_run(m[0], s, cmds, 40), 1, "one throw, the smoke")
	assert_eq(s.characters[0].grenades.readied, Grenade.Kind.NONE)


func test_the_other_key_swaps_the_bomb_in_hand_and_a_click_throws_that_one() -> void:
	var m := _match()
	var s: GameState = m[1]
	var cmds: Array[PlayerCommand] = m[2]
	cmds[0].ready_grenade = Grenade.Kind.SMOKE
	_run(m[0], s, cmds, 3)
	cmds[0].ready_grenade = Grenade.Kind.FLASH
	_run(m[0], s, cmds, 3)
	assert_eq(Grenades.in_hand(s.characters[0]), Grenade.Kind.FLASH)
	cmds[0].fire = true
	_run(m[0], s, cmds, 2)
	cmds[0].fire = false
	assert_eq(_run(m[0], s, cmds, 40), 1)
	assert_eq(s.characters[0].grenades.flash, s.characters[0].grenades.carried_flash - 1)


func test_a_button_held_through_the_bring_to_hand_throws_nothing_until_a_fresh_click() -> void:
	var m := _match()
	var s: GameState = m[1]
	var cmds: Array[PlayerCommand] = m[2]
	cmds[0].fire = true
	cmds[0].ready_grenade = Grenade.Kind.SMOKE
	assert_eq(_run(m[0], s, cmds, 90), 0)
	assert_false(Grenades.throwing(s.characters[0]), "the held button is not a pull")
	cmds[0].fire = false
	assert_eq(_run(m[0], s, cmds, 30), 0)
	cmds[0].fire = true
	_run(m[0], s, cmds, 2)
	cmds[0].fire = false
	assert_eq(_run(m[0], s, cmds, 40), 1)


func test_a_pull_during_the_recovery_after_a_held_throw_fires_no_shot_while_the_bomb_leaves() -> void:
	var m := _match()
	var s: GameState = m[1]
	var cmds: Array[PlayerCommand] = m[2]
	_cocked(m)
	var you := s.characters[0]
	cmds[0].fire = false
	assert_eq(_run(m[0], s, cmds, 8), 1, "thrown on the release")
	var shots := 0
	cmds[0].fire = true
	while Grenades.throwing(you):
		_run(m[0], s, cmds, 1)
		shots += s.events.count_of(GameEvent.Kind.SHOT)
	assert_false(you.grenades.throw_held, "no hold stays for the next bomb")
	assert_eq(shots, 0, "the replica is down until the throw ends")


func test_the_last_bomb_thrown_on_a_release_leaves_nothing_in_hand_and_the_next_key_is_refused() -> void:
	var m := _match()
	var s: GameState = m[1]
	var cmds: Array[PlayerCommand] = m[2]
	var you := s.characters[0]
	you.grenades.smoke = 1
	_cocked(m)
	cmds[0].fire = false
	assert_eq(_run(m[0], s, cmds, 40), 1)
	assert_eq(you.grenades.smoke, 0)
	cmds[0].ready_grenade = Grenade.Kind.SMOKE
	_run(m[0], s, cmds, 5)
	assert_eq(Grenades.in_hand(you), Grenade.Kind.NONE, "none left: nothing comes to hand")


func test_a_bot_with_a_bomb_press_and_fire_down_is_unaffected_by_the_hold() -> void:
	var m := _match()
	var s: GameState = m[1]
	var cmds: Array[PlayerCommand] = m[2]
	cmds[1].fire = true
	for k in 2:
		cmds[1].throw_grenade = Grenade.Kind.FLASH if k % 2 == 0 else Grenade.Kind.SMOKE
		assert_eq(_run(m[0], s, cmds, ceili(cfg.windup / DT) + ceili(cfg.recover / DT) + 2), 1, "bot throw %d" % k)
	assert_false(s.characters[1].grenades.throw_held)


func test_your_bb_that_has_bounced_is_never_hidden_by_the_muzzle_rule() -> void:
	var ecfg := EffectsConfig.new()
	var bb := BB.new()
	bb.owner_id = 0
	bb.velocity = Vector3(0.0, 0.0, -50.0)
	bb.bounces = 1
	assert_false(BBView.before_muzzle(ecfg, bb, 0, Vector3(0, 0, 1.0), Vector3(0, 0, -1.0), 0.01))


func test_a_bb_past_the_join_time_is_shown_even_behind_a_moved_muzzle() -> void:
	var ecfg := EffectsConfig.new()
	var bb := BB.new()
	bb.owner_id = 0
	bb.velocity = Vector3(0.0, 0.0, -50.0)
	assert_false(BBView.before_muzzle(ecfg, bb, 0, Vector3(0, 0, 3.0), Vector3(0, 0, -1.0), ecfg.muzzle_join_time))


# --- laser fit and inspect, every replica ---

const AEG := "000002"
const PISTOL := "000001"
const SNIPER := "000021"
const CYBER := "000019"
const LASER := "000005"
const TORCH_ID := "000004"
var rules: LoadoutRules


func _rules() -> LoadoutRules:
	return LoadoutRules.new(Pool.read_file(), ReplicaStats.read_file(), ReplicaRulesConfig.new())


func test_the_sniper_and_the_cyber_pistol_refuse_the_laser_through_the_loadout_rules() -> void:
	rules = _rules()
	var l := rules.default_loadout("Test")
	for id: String in [SNIPER, CYBER]:
		if l.equipped[0] != id:
			rules.equip(l, 0 as Loadout.Slot, id)
		assert_false(rules.set_part(l, id, &"laser", LASER), "%s has no rail for it" % id)


func test_the_aeg_holds_the_laser_and_writes_it_to_the_save() -> void:
	rules = _rules()
	var l := rules.default_loadout("Test")
	if l.equipped[0] != AEG:
		rules.equip(l, 0 as Loadout.Slot, AEG)
	assert_true(rules.set_part(l, AEG, &"laser", LASER))
	var saved := l.to_dict()
	assert_true(JSON.stringify(saved).contains(LASER), "the laser is written to the save")
	assert_eq(rules.carried(l).parts[0].get(&"laser"), &"redLaser")


func test_every_replicas_inspect_turns_the_muzzle_to_the_left() -> void:
	rules = _rules()
	for id: String in [AEG, PISTOL, SNIPER, CYBER]:
		var l := rules.default_loadout("Test")
		if l.equipped[0] != id:
			rules.equip(l, 0 as Loadout.Slot, id)
		var kit := rules.carried(l)
		var eyes := Camera3D.new()
		add_child_autofree(eyes)
		var hands := ReplicaView.new()
		eyes.add_child(hands)
		hands.setup(ViewModelConfig.new(), kit.replicas, null, kit.paints, false, kit.parts, ViewConfig.new(), eyes)
		var c := Character.new(0, 0, Vector3.ZERO, 0.0, kit.replicas)
		hands._query = BoxWorld.new()
		hands.update(c, 0.0, 0.0, Vector3.ZERO, Vector3.FORWARD, DT, 0.0)
		hands.inspect()
		var held: ReplicaView.Held = hands._held[0]
		var pose: InspectPose = ViewModelConfig.new().inspect_poses[held.id]
		for i in roundi(pose.duration * 0.5 / DT):
			hands.update(c, 0.0, 0.0, Vector3.ZERO, Vector3.FORWARD, DT, 0.0)
		var muzzle := hands.to_local(held.muzzle.global_position)
		assert_lt(muzzle.x, held.root.position.x - 0.03, "%s: muzzle left of the hold" % id)
