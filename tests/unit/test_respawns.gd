extends GutTest
## RS1: respawns (owner 2026-11-17, playtest item 28). A hit character calls it and walks off, then comes back a delay
## after the hit at its start area or a forward spawn of its end it picked; a team with a respawn coming is not wiped
## out; Elimination plays one life unless the Custom rule turns respawns on; Plant The Bomb's stop as the bomb is
## armed; forward spawns are either side's (the defenders' by a rule), shut with an enemy near; an untended flag slips
## and a field sets its defenders' wait. The bots pick and rejoin, the
## maps carry their forward spawns, the Custom rule saves, and the panel and keys pick where you come back.

const DT := 1.0 / 60.0
const END_X := 10.0
const DEAD_ZONE_X := 14.0
const FORWARD_X := 8.0
const POLE_Z := 14.0
## Ticks for a wait to run out with room to spare (a 10 s delay at 60 Hz, plus a second).
const WAIT_TICKS := 11 * 60

var tuning: SimTuning = SimTuning.new()
var loadout: Array[ReplicaConfig] = []


func before_all() -> void:
	loadout = ReplicaStats.default_loadout()


func _ends() -> Array[MapEnd]:
	var ends: Array[MapEnd] = []
	for e in 2:
		var side := -1.0 if e == 0 else 1.0
		var facing := -PI / 2.0 if e == 0 else PI / 2.0
		var end := MapEnd.new()
		for i in 3:
			end.spawns.append(SpawnPoint.new(Vector3(side * END_X, 0.0, (i - 1) * 2.0), facing))
		for i in 3:
			end.dead_zone.append(SpawnPoint.new(Vector3(side * DEAD_ZONE_X, 0.0, 10.0 + i), facing))
		var f := ForwardSpawn.new()
		f.name = "Forward %d" % e
		for i in 2:
			f.spots.append(SpawnPoint.new(Vector3(side * FORWARD_X, 0.0, -6.0 + i), facing))
		f.centre = Vector3(side * FORWARD_X, 0.0, -5.5)
		end.forward.append(f)
		ends.append(end)
	return ends


## A 2v2 (ids 0..3, teams alternating) in `mode` on a flat floor, round 1 live.
func _match(mode: RoundState.Mode, rounds: RoundConfig = null) -> Array:
	var t := tuning
	if rounds != null:
		t = tuning.duplicate() as SimTuning
		t.rounds = rounds
	var w := BoxWorld.new(t.body)
	w.add_floor(60.0, 40.0)
	var sim := Simulation.new(t, w, w.mover(), _ends(), -10.0)
	var state := GameState.new(1, t)
	state.round_state.mode = mode
	state.round_state.pole = Vector3(0.0, 0.0, POLE_Z)
	for i in 4:
		state.characters.append(Character.new(i, i % 2, Vector3.ZERO, 0.0, loadout))
	sim.start_match(state)
	return [sim, state]


func _cmds() -> Array[PlayerCommand]:
	var cmds: Array[PlayerCommand] = []
	for i in 4:
		cmds.append(PlayerCommand.new())
	return cmds


func _hit(sim: Simulation, state: GameState, c: Character) -> void:
	Elimination.eliminate(c, -1, state.characters, sim.ends)


## Steps until `c` is in play again or `ticks` run out; the RESPAWNED event of its return, or null.
func _until_back(sim: Simulation, state: GameState, cmds: Array[PlayerCommand], c: Character, ticks: int) -> GameEvent:
	for i in ticks:
		sim.step(state, cmds, DT)
		for k in state.events.count:
			var e := state.events.items[k]
			if e.kind == GameEvent.Kind.RESPAWNED and e.actor == c.id:
				return e
	return null


# --- the rule ---

func test_by_mode_respawns_in_attack_defend_and_the_bomb_but_not_elimination() -> void:
	var r := RoundConfig.new()
	assert_eq(r.respawns, RoundConfig.RespawnRule.BY_MODE, "Skirmish plays by mode")
	assert_true(Respawns.on_in(r, RoundState.Mode.ATTACK_DEFEND))
	assert_true(Respawns.on_in(r, RoundState.Mode.PLANT_THE_BOMB))
	assert_false(Respawns.on_in(r, RoundState.Mode.ELIMINATION), "one life is Elimination")
	r.respawns = RoundConfig.RespawnRule.ALWAYS
	assert_true(Respawns.on_in(r, RoundState.Mode.ELIMINATION))
	r.respawns = RoundConfig.RespawnRule.NEVER
	assert_false(Respawns.on_in(r, RoundState.Mode.ATTACK_DEFEND))


func test_a_hit_in_attack_defend_comes_back_at_its_start_after_the_delay() -> void:
	var m := _match(RoundState.Mode.ATTACK_DEFEND)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var cmds := _cmds()
	var c := state.characters[1]
	c.position = Vector3(0.0, tuning.body.rest_gap, 4.0)
	_hit(sim, state, c)
	sim.step(state, cmds, DT)
	assert_true(Respawns.waiting(c), "the wait starts on the tick of the hit")
	assert_almost_eq(c.respawn_left, Respawns.delay(state.round_state, tuning.rounds, c.team), 1e-6)
	c.armament.ammo[0].mag = 0
	var back := _until_back(sim, state, cmds, c, WAIT_TICKS)
	assert_not_null(back, "it comes back")
	assert_eq(c.status, Character.Status.ALIVE)
	assert_eq(back.value, 0, "at its start area")
	assert_almost_eq(c.position.distance_to(c.spawn_position), 0.0, 0.05, "on its own spawn")
	assert_eq(c.respawn_left, -1.0, "no wait left")
	assert_eq(c.armament.ammo[0].mag, c.armament.replicas[0].mag_size, "with a full magazine")


func test_a_team_with_a_respawn_coming_is_not_wiped_out() -> void:
	var m := _match(RoundState.Mode.ATTACK_DEFEND)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var cmds := _cmds()
	_hit(sim, state, state.characters[1])
	_hit(sim, state, state.characters[3])
	for i in 60:
		sim.step(state, cmds, DT)
	assert_eq(state.round_state.phase, RoundState.Phase.LIVE, "both of Beta out, both coming back: the round plays on")
	assert_not_null(_until_back(sim, state, cmds, state.characters[3], WAIT_TICKS))
	assert_eq(state.round_state.phase, RoundState.Phase.LIVE)


func test_elimination_keeps_one_life_and_a_wipe_out_ends_the_round() -> void:
	var m := _match(RoundState.Mode.ELIMINATION)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var cmds := _cmds()
	_hit(sim, state, state.characters[1])
	_hit(sim, state, state.characters[3])
	sim.step(state, cmds, DT)
	assert_false(Respawns.waiting(state.characters[1]), "no respawn in Elimination")
	assert_ne(state.round_state.phase, RoundState.Phase.LIVE, "the wipe-out ends it as ever")


func test_the_custom_rule_on_brings_respawns_to_elimination() -> void:
	var r := RoundConfig.new()
	r.respawns = RoundConfig.RespawnRule.ALWAYS
	var m := _match(RoundState.Mode.ELIMINATION, r)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var cmds := _cmds()
	_hit(sim, state, state.characters[1])
	_hit(sim, state, state.characters[3])
	sim.step(state, cmds, DT)
	assert_true(Respawns.waiting(state.characters[1]))
	assert_eq(state.round_state.phase, RoundState.Phase.LIVE)


func test_an_attacker_comes_back_at_the_forward_spawn_it_picked() -> void:
	var m := _match(RoundState.Mode.ATTACK_DEFEND)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var cmds := _cmds()
	var attacker := state.characters[state.round_state.attackers]
	_hit(sim, state, attacker)
	cmds[attacker.id].spawn_pick = 1
	var back := _until_back(sim, state, cmds, attacker, WAIT_TICKS)
	assert_not_null(back)
	assert_eq(back.value, 1, "at its end's first forward spawn")
	var spot := sim.ends[attacker.end].forward[0].spots[0]
	assert_almost_eq(Vector2(attacker.position.x, attacker.position.z).distance_to(Vector2(spot.position.x,
			spot.position.z)), 0.0, 0.05)
	assert_almost_eq(attacker.yaw, spot.yaw, 1e-6, "facing the way the spot faces")


func test_a_defender_comes_back_forward_unless_the_rule_keeps_it_at_its_start() -> void:
	for allowed: bool in [true, false]:
		var r := RoundConfig.new()
		r.defender_forward_spawns = allowed
		var m := _match(RoundState.Mode.ATTACK_DEFEND, r)
		var sim: Simulation = m[0]
		var state: GameState = m[1]
		var cmds := _cmds()
		var defender := state.characters[1 - state.round_state.attackers]
		assert_eq(Respawns.forward_allowed(state.round_state, defender.team, r), allowed)
		_hit(sim, state, defender)
		cmds[defender.id].spawn_pick = 1
		var back := _until_back(sim, state, cmds, defender, WAIT_TICKS)
		assert_not_null(back)
		assert_eq(back.value, 1 if allowed else 0, "a defender's forward pick, where the rule allows it")


func test_an_enemy_near_a_forward_spawn_shuts_it() -> void:
	var m := _match(RoundState.Mode.ATTACK_DEFEND)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var cmds := _cmds()
	var rs := state.round_state
	var attacker := state.characters[rs.attackers]
	var enemy := state.characters[1 - rs.attackers]
	var f := sim.ends[attacker.end].forward[0]
	enemy.position = f.centre + Vector3(tuning.rounds.forward_block_radius - 1.0, 0.0, 0.0)
	assert_true(Respawns.shut(f, attacker.team, state.characters, tuning.rounds.forward_block_radius))
	attacker.spawn_pick = 1
	assert_eq(Respawns.resolve(attacker, rs, sim.ends, state.characters, tuning.rounds), 0, "shut: the start area")
	enemy.position = f.centre + Vector3(tuning.rounds.forward_block_radius + 1.0, 0.0, 0.0)
	assert_eq(Respawns.resolve(attacker, rs, sim.ends, state.characters, tuning.rounds), 1, "clear again")
	_hit(sim, state, enemy)
	enemy.position = f.centre
	assert_false(Respawns.shut(f, attacker.team, state.characters, tuning.rounds.forward_block_radius),
			"an enemy out of play shuts nothing")
	assert_eq(cmds.size(), 4)


func test_a_pick_past_the_end_s_forward_spawns_comes_back_at_the_start() -> void:
	var m := _match(RoundState.Mode.ATTACK_DEFEND)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var attacker := state.characters[state.round_state.attackers]
	attacker.spawn_pick = 5
	assert_eq(Respawns.resolve(attacker, state.round_state, sim.ends, state.characters, tuning.rounds), 0)


func test_two_coming_back_together_take_different_spots() -> void:
	var m := _match(RoundState.Mode.ATTACK_DEFEND)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var f := sim.ends[0].forward[0]
	var first := Respawns.free_spot(f, state.characters, tuning.body)
	assert_same(first, f.spots[0])
	state.characters[0].position = first.position
	assert_same(Respawns.free_spot(f, state.characters, tuning.body), f.spots[1], "the first is taken")


func test_arming_the_bomb_ends_respawns_and_drops_every_wait() -> void:
	var m := _match(RoundState.Mode.PLANT_THE_BOMB)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var cmds := _cmds()
	var rs := state.round_state
	var c := state.characters[1]
	_hit(sim, state, c)
	Respawns.step(rs, state.characters, cmds, sim.ends, tuning, state.events, DT)
	assert_true(Respawns.waiting(c), "before the plant a hit comes back")
	rs.plant.status = PlantState.Status.PLANTED
	assert_false(Respawns.open(rs))
	Respawns.step(rs, state.characters, cmds, sim.ends, tuning, state.events, DT)
	assert_false(Respawns.waiting(c), "armed: whoever is out stays out")


func test_nobody_comes_back_between_rounds_or_on_the_range() -> void:
	var rs := RoundState.new()
	rs.respawns = true
	rs.practice = true
	assert_false(Respawns.open(rs), "practice")
	var m := _match(RoundState.Mode.ATTACK_DEFEND)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var c := state.characters[1]
	_hit(sim, state, c)
	state.round_state.phase = RoundState.Phase.OVER
	Respawns.step(state.round_state, state.characters, _cmds(), sim.ends, tuning, state.events, DT)
	assert_false(Respawns.waiting(c), "no wait starts once the round is decided")


func test_a_new_round_clears_a_wait() -> void:
	var m := _match(RoundState.Mode.ATTACK_DEFEND)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var c := state.characters[1]
	_hit(sim, state, c)
	sim.step(state, _cmds(), DT)
	assert_true(Respawns.waiting(c))
	c.respawn()
	assert_eq(c.respawn_left, -1.0)
	assert_eq(c.spawn_pick, 0)


func test_the_defenders_wait_their_own_delay() -> void:
	var r := RoundConfig.new()
	r.respawn_delay = 7.0
	r.defender_respawn_delay = 12.0
	var rs := RoundState.new()
	rs.mode = RoundState.Mode.ATTACK_DEFEND
	rs.attackers = 0
	assert_eq(Respawns.delay(rs, r, 0), 7.0)
	assert_eq(Respawns.delay(rs, r, 1), 12.0)
	rs.mode = RoundState.Mode.ELIMINATION
	rs.attackers = -1
	assert_eq(Respawns.delay(rs, r, 1), 7.0, "no sides: everyone waits the same")


# --- the bots ---

func _bot_world(mode: RoundState.Mode, attackers: int) -> BotWorld:
	var w := BotWorld.new()
	w.cfg = BotConfig.new()
	w.tuning = SimTuning.new()
	w.mode = mode
	w.attackers = attackers
	w.ends = _ends()
	return w


func test_a_bot_on_defence_picks_forward_only_where_the_rule_lets_it() -> void:
	var w := _bot_world(RoundState.Mode.ATTACK_DEFEND, 0)
	var c := Character.new(1, 1, Vector3.ZERO, 0.0, loadout)
	c.end = 1
	var b := Bot.new(c, 7, BotSkill.new(), 2)
	w.cfg.forward_spawn_chance = 1.0
	assert_between(BotRespawn.pick(b, w), 1, w.ends[1].forward.size())
	b.reset(-1, 0, 0.0, w.cfg)
	w.tuning.rounds.defender_forward_spawns = false
	assert_eq(BotRespawn.pick(b, w), 0)


func test_an_attacking_bot_picks_a_forward_spawn_once_a_time_out() -> void:
	var w := _bot_world(RoundState.Mode.ATTACK_DEFEND, 0)
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, loadout)
	c.end = 0
	var b := Bot.new(c, 7, BotSkill.new(), 2)
	w.cfg.forward_spawn_chance = 1.0
	var first := BotRespawn.pick(b, w)
	assert_between(first, 1, w.ends[0].forward.size())
	w.cfg.forward_spawn_chance = 0.0
	assert_eq(BotRespawn.pick(b, w), first, "kept until it is back")
	b.reset(-1, 0, 0.0, w.cfg)
	assert_eq(BotRespawn.pick(b, w), 0, "picked afresh the next time out")


func test_the_nearest_lane_is_the_one_passing_closest() -> void:
	var lanes: Array[PackedVector3Array] = [
		PackedVector3Array([Vector3(-20.0, 0.0, -10.0), Vector3(20.0, 0.0, -10.0)]),
		PackedVector3Array([Vector3(-20.0, 0.0, 10.0), Vector3(20.0, 0.0, 10.0)]),
	]
	assert_eq(RoundPlanner.nearest_lane(Vector3(3.0, 0.0, 6.0), lanes), 1)
	assert_eq(RoundPlanner.nearest_lane(Vector3(3.0, 5.0, -7.0), lanes), 0, "on the flat")
	var none: Array[PackedVector3Array] = []
	assert_eq(RoundPlanner.nearest_lane(Vector3.ZERO, none), -1)


func test_a_bot_back_mid_round_walks_on_from_the_lane_point_ahead() -> void:
	var w := _bot_world(RoundState.Mode.ELIMINATION, -1)
	w.lanes = [PackedVector3Array([Vector3(-20.0, 0.0, 0.0), Vector3(-10.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0),
			Vector3(10.0, 0.0, 0.0), Vector3(20.0, 0.0, 0.0)])]
	w.planner = RoundPlanner.new(3)
	var c := Character.new(0, 0, Vector3(-4.0, 0.0, 1.0), 0.0, loadout)
	c.end = 0
	var b := Bot.new(c, 7, BotSkill.new(), 1)
	w.planner.rejoin(b, w)
	assert_eq(b.lane, 0)
	assert_eq(b.lane_dir, 1)
	assert_eq(b.lane_index + b.lane_dir, 2, "its next point is the one ahead of it, not the start of the lane")


# --- the maps ---

func test_each_field_has_two_forward_spawns_an_end_on_clear_floor() -> void:
	var body := tuning.body
	for id: String in ["depot", "woodland", "subway"]:
		var m := MapData.load_map(id, PlayTuning.load_default().map_style, 6)
		assert_true(m.ok(), id)
		for e in m.ends.size():
			assert_eq(m.ends[e].forward.size(), 2, "%s end %d" % [id, e])
			for f in m.ends[e].forward:
				assert_ne(f.name, "", id)
				assert_eq(f.spots.size(), 4, "%s %s" % [id, f.name])
				for s in f.spots:
					for blk in m.blocks:
						if blk.kind == &"floor" or blk.rise != MapData.Rise.NONE:
							continue
						var lo := blk.center - blk.size * 0.5
						var hi := blk.center + blk.size * 0.5
						var inside := s.position.x > lo.x - body.radius and s.position.x < hi.x + body.radius \
								and s.position.z > lo.z - body.radius and s.position.z < hi.z + body.radius \
								and hi.y > s.position.y + body.max_step and lo.y < s.position.y + body.height
						assert_false(inside, "%s %s spot %s stands in a %s" % [id, f.name, s.position, blk.kind])


# --- the Custom rule ---

func test_the_custom_rule_saves_and_plays_on_or_off() -> void:
	var r := CustomRules.new()
	assert_eq(r.respawns, RoundConfig.RespawnRule.BY_MODE, "starts as Skirmish plays")
	assert_eq(r.applied_to(tuning).rounds.respawns, RoundConfig.RespawnRule.BY_MODE)
	r.respawns = RoundConfig.RespawnRule.ALWAYS
	assert_eq(r.applied_to(tuning).rounds.respawns, RoundConfig.RespawnRule.ALWAYS)
	r.respawns = RoundConfig.RespawnRule.NEVER
	assert_eq(r.applied_to(tuning).rounds.respawns, RoundConfig.RespawnRule.NEVER)
	assert_eq(tuning.rounds.respawns, RoundConfig.RespawnRule.BY_MODE, "the loaded tuning keeps Skirmish's")
	var back := CustomRules.new()
	back.from_dict(r.to_dict())
	assert_eq(back.respawns, RoundConfig.RespawnRule.NEVER)
	back.from_dict({"respawns": 7})
	assert_eq(back.respawns, RoundConfig.RespawnRule.BY_MODE, "a bad value keeps the default")
	back.from_dict({"respawns": true})
	assert_eq(back.respawns, RoundConfig.RespawnRule.BY_MODE, "an old switch's value too")


func test_skirmish_s_chip_says_respawns_are_not_in_elimination() -> void:
	var found := false
	for chip in MatchOptions.rule_chips(RoundConfig.new(), HitConfig.new()):
		if chip[0] == tr("RULE_RESPAWNS"):
			found = true
			assert_eq(chip[1], tr("RULE_RESPAWNS_BY_MODE"))
	assert_true(found)


# --- your keys and the panel ---

func test_the_keys_and_the_wheel_pick_where_you_come_back() -> void:
	var input := PlayerInput.new()
	add_child_autofree(input)
	input._slot_latch = 1
	assert_eq(input.spawn_pick(0, 3), 1, "the second slot's key: the first forward spawn")
	input._holster_latch = true
	assert_eq(input.spawn_pick(1, 3), 2, "Holster's: the third place")
	input._slot_steps = 1
	assert_eq(input.spawn_pick(2, 3), 0, "the wheel goes round")
	input._slot_steps = -1
	assert_eq(input.spawn_pick(0, 3), 2)
	input._slot_latch = 1
	assert_eq(input.spawn_pick(0, 1), 0, "only the start area to pick")
	assert_eq(input._slot_latch, -1, "the press is taken")


func test_the_panel_shows_the_wait_and_the_places_while_you_wait() -> void:
	var m := _match(RoundState.Mode.ATTACK_DEFEND)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var panel := HudRespawn.new()
	add_child_autofree(panel)
	var you := state.characters[state.round_state.attackers]
	panel.show_for(you, state.round_state, sim.ends, state.characters, tuning.rounds)
	assert_false(panel.visible, "in play: hidden")
	_hit(sim, state, you)
	sim.step(state, _cmds(), DT)
	panel.show_for(you, state.round_state, sim.ends, state.characters, tuning.rounds)
	assert_true(panel.visible)
	assert_eq(panel.title_text(), tr("HUD_RESPAWN_IN") % ceili(you.respawn_left))
	assert_eq(panel.place_names(), PackedStringArray([tr("HUD_RESPAWN_START"), "Forward %d" % you.end]))
	assert_eq(panel.lit_place(), 0)
	var defender := state.characters[1 - state.round_state.attackers]
	_hit(sim, state, defender)
	sim.step(state, _cmds(), DT)
	panel.show_for(defender, state.round_state, sim.ends, state.characters, tuning.rounds)
	assert_eq(panel.place_names(), PackedStringArray([tr("HUD_RESPAWN_START"), "Forward %d" % defender.end]),
			"defending: its own end's forward spawns too")
	var off := RoundConfig.new()
	off.defender_forward_spawns = false
	panel.show_for(defender, state.round_state, sim.ends, state.characters, off)
	assert_eq(panel.place_names(), PackedStringArray([tr("HUD_RESPAWN_START")]), "the rule off: the start area only")


func test_the_balance_report_widens_the_clock_band_with_respawns() -> void:
	var m := MatchRunner.MatchTally.new()
	var r := MatchRunner.RoundTally.new()
	r.winner = 1
	r.attackers = 0
	r.reason = GameEvent.RoundEnd.TIME
	m.rounds.append(r)
	var matches: Array[MatchRunner.MatchTally] = [m]
	assert_eq(BalanceReport.flag_figures("depot", "Depot", matches)[1].band_max, BalanceReport.ON_TIME_MAX)
	m.respawns = 3
	assert_eq(BalanceReport.flag_figures("depot", "Depot", matches)[1].band_max,
			BalanceReport.FLAG_ON_TIME_RESPAWN_MAX, "with respawns the clock is the defenders' win: a wide band")
	assert_eq(BalanceReport.plant_figures("Depot", matches)[1].band_max, BalanceReport.PLANT_ON_TIME_RESPAWN_MAX)


func test_with_respawns_an_untended_flag_slips_back_down() -> void:
	var cfg := FlagConfig.new()
	var flag := FlagState.new()
	var nobody: Array[Character] = []
	var events := SimEvents.new()
	flag.progress = 0.5
	Flag.step(flag, nobody, 0, cfg, events, 1.0)
	assert_eq(flag.progress, 0.5, "one life: a part-raise stays")
	Flag.step(flag, nobody, 0, cfg, events, 1.0, cfg.respawn_slip_time)
	assert_almost_eq(flag.progress, 0.5 - 1.0 / cfg.respawn_slip_time, 1e-5, "with respawns it slips")
	Flag.step(flag, nobody, 0, cfg, events, cfg.respawn_slip_time, cfg.respawn_slip_time)
	assert_eq(flag.progress, 0.0, "never below the bottom")
	flag.progress = 1.0
	flag.held = 1.0
	Flag.step(flag, nobody, 0, cfg, events, 1.0, cfg.respawn_slip_time)
	assert_lt(flag.progress, 1.0, "with respawns a raised flag left alone slips too (BP10)")
	assert_eq(flag.held, 0.0, "and its hold starts again")
	flag.progress = 1.0
	flag.held = 1.0
	assert_false(Flag.step(flag, nobody, 0, cfg, events, 1.0), "one life: left up, its hold runs on")
	assert_true(Flag.step(flag, nobody, 0, cfg, events, cfg.hold_time), "and wins alone")
	var rs := RoundState.new()
	assert_eq(Respawns.slip_time(rs, cfg), 0.0)
	rs.respawns = true
	assert_eq(Respawns.slip_time(rs, cfg), cfg.respawn_slip_time)


func test_enemy_near_coming_and_going_moves_and_resizes_nothing() -> void:
	var m := _match(RoundState.Mode.ATTACK_DEFEND)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var panel := HudRespawn.new()
	add_child_autofree(panel)
	var rs := state.round_state
	var you := state.characters[rs.attackers]
	var enemy := state.characters[1 - rs.attackers]
	_hit(sim, state, you)
	sim.step(state, _cmds(), DT)
	var f := sim.ends[you.end].forward[0]
	enemy.position = f.centre + Vector3(tuning.rounds.forward_block_radius + 5.0, 0.0, 0.0)
	panel.show_for(you, rs, sim.ends, state.characters, tuning.rounds)
	var open_size := panel.get_combined_minimum_size()
	var open_chips := panel.chip_sizes()
	enemy.position = f.centre
	panel.show_for(you, rs, sim.ends, state.characters, tuning.rounds)
	assert_true(panel.shut_places() & 2 == 2, "the first forward spawn reads shut")
	assert_eq(panel.get_combined_minimum_size(), open_size, "the panel keeps its size")
	assert_eq(panel.chip_sizes(), open_chips, "every chip keeps its size")


func test_a_field_s_defender_respawn_is_read_and_played_and_blank_keeps_the_games() -> void:
	var head := "# Maps\n\n## Maps\n\n| Id | Name | Kind | Tag | Min | Standard | Max | Defender respawn (s) | Blurb |\n" \
			+ "|---|---|---|---|---|---|---|---|---|\n"
	var row := "| %s | %s | field | public | 5 | 6 | 8 | %s | A field. |\n"
	var m := MapCatalog.parse(head + row % ["near", "Near", ""] + row % ["far", "Far", "5"])
	assert_eq(m.problems, [] as Array[String])
	assert_eq(m.find("near").defender_respawn, 0.0, "blank: the round tuning's")
	assert_eq(m.find("far").defender_respawn, 5.0)
	var bad := MapCatalog.parse(head + row % ["far", "Far", "1"])
	assert_eq(bad.find("far").defender_respawn, 0.0, "under 2 s keeps the game's")
	assert_eq(bad.problems.size(), 1)
	var base := SimTuning.load_default()
	var games := base.rounds.defender_respawn_delay
	var own := 0
	for e in MapCatalog.shared().entries:
		if e.kind != &"field":
			continue
		var back := e.defender_respawn if e.defender_respawn > 0.0 else games
		own += 1 if e.defender_respawn > 0.0 else 0
		assert_eq(MatchOptions.match_tuning(base, e, null).rounds.defender_respawn_delay, back, "%s, Skirmish" % e.id)
		assert_eq(MatchOptions.match_tuning(base, e, CustomRules.new()).rounds.defender_respawn_delay, back,
				"%s, Custom" % e.id)
		assert_eq(MatchRunner.sized_for(e.id).rounds.defender_respawn_delay, back, "%s: the measures play it" % e.id)
	assert_gt(own, 0, "a field has its own, or this test proves nothing")
	assert_eq(base.rounds.defender_respawn_delay, games, "the loaded tuning is never written")


func test_coming_back_comes_up_out_of_dark_with_back_in_and_only_for_you() -> void:
	var you := Character.new(0, 0, Vector3.ZERO, 0.0, loadout)
	var hud := Hud.new()
	add_child_autofree(hud)
	var cfg := HudConfig.new()
	hud.setup(cfg, TeamConfig.new(), ViewConfig.new(), SimTuning.new(), you)
	var state := GameState.new(1, tuning)
	state.characters.append(you)
	state.characters.append(Character.new(1, 1, Vector3.ZERO, 0.0, loadout))
	state.events.add(GameEvent.Kind.RESPAWNED).actor = 1
	hud.on_tick(state)
	hud.update(state, 0.0, 0.0)
	assert_eq(hud.back_in_dark(), 0.0, "someone else's return: no fade")
	state.events.clear()
	state.events.add(GameEvent.Kind.RESPAWNED).actor = 0
	hud.on_tick(state)
	hud.update(state, 0.0, 0.0)
	assert_almost_eq(hud.back_in_dark(), cfg.back_in_dark, 1e-4, "your return starts dark")
	hud.update(state, 0.0, cfg.back_in_fade * 0.5)
	assert_almost_eq(hud.back_in_dark(), cfg.back_in_dark * 0.5, 1e-4, "and comes up")
	hud.update(state, 0.0, cfg.back_in_fade)
	assert_eq(hud.back_in_dark(), 0.0, "then clear")
