extends GutTest
## QA hunt for AT1 (parts): hand-edited saves, odd edits, tiny magazines, quiet shots, and a bot match where every
## replica carries parts.

const DT := 1.0 / 60.0
const AEG := "000002"
const PISTOL := "000001"
const CYBER := "000019"
const RED_DOT := "000007"
const SCOPE := "000010"
const VERTICAL := "000006"
const HI_CAP := "000012"
const LOW_CAP := "000013"
const SILENCER := "000018"
const LASER := "000005"
const LIPO := "000015"

var rules: LoadoutRules


func before_each() -> void:
	rules = LoadoutRules.new(Pool.read_file(), ReplicaStats.read_file(), ReplicaRulesConfig.new())


func test_taking_a_part_off_something_that_is_not_a_replica_changes_nothing() -> void:
	var l := rules.default_loadout("Test")
	var before := l.tunes.size()
	assert_false(rules.set_part(l, SCOPE, &"optic", ""), "a scope is not a replica")
	assert_false(rules.set_part(l, LIPO, &"optic", ""), "a battery is not a replica")
	assert_eq(l.tunes.size(), before, "no setup made for a non-replica")


func test_a_hand_edited_file_keeps_only_parts_that_fit_their_slot() -> void:
	var s := SavedLoadouts.new(rules)
	var problems := s.from_dict({"slots": [{"name": "Edited", "equipped": [AEG, PISTOL], "tunes": {
		AEG: {"parts": {"optic": RED_DOT, "grip": RED_DOT, "laser": AEG, "muzzle": "", "barrel": 5, "stock": VERTICAL,
				"magazine": HI_CAP}},
		PISTOL: {"parts": "none"},
	}}], "current": 0})
	var t := s.carried().tunes[AEG]
	assert_eq(t.parts, {&"optic": RED_DOT, &"magazine": HI_CAP} as Dictionary[StringName, String])
	assert_false(problems.is_empty(), "the bad ones are listed")
	assert_eq(s.carried().tunes[PISTOL].parts, {} as Dictionary[StringName, String], "a non-dictionary reads as none")


func test_a_part_saved_for_the_wrong_replica_is_cleaned_not_carried() -> void:
	var l := rules.default_loadout("Test")
	var t := rules.default_tune(rules.pool.item(PISTOL))
	t.parts = {&"muzzle": SILENCER, &"optic": RED_DOT, &"laser": LASER}
	l.tunes[PISTOL] = t
	var said := rules.clean(l)
	assert_eq(t.parts, {&"muzzle": SILENCER, &"laser": LASER} as Dictionary[StringName, String])
	assert_eq(said.size(), 1)


func test_a_loadout_saved_before_parts_loads_with_none() -> void:
	var s := SavedLoadouts.new(rules)
	s.from_dict({"slots": [{"name": "Old", "equipped": [AEG, PISTOL], "tunes": {
		AEG: {"bb_weight": 0.25, "hop_up": 0.5, "paint": "cobalt", "power": LIPO}}}], "current": 0})
	var t := s.carried().tunes[AEG]
	assert_eq(t.parts, {} as Dictionary[StringName, String])
	assert_eq(t.power_id, LIPO)
	assert_eq(s.carried_kit(false).parts[0], {})


func test_a_loadouts_copy_and_dict_keep_their_own_parts() -> void:
	var l := rules.default_loadout("A")
	rules.set_part(l, AEG, &"optic", SCOPE)
	var c := l.copy("B")
	rules.set_part(c, AEG, &"optic", "")
	assert_eq(l.tunes[AEG].parts, {&"optic": SCOPE} as Dictionary[StringName, String])
	var s := SavedLoadouts.new(rules)
	s.from_dict(JSON.parse_string(JSON.stringify(SavedLoadouts.new(rules).to_dict())))
	assert_eq(s.slots.size(), 1)


func test_the_cyber_pistol_takes_no_part_but_the_light_and_plays_as_it_comes() -> void:
	var l := rules.default_loadout("Test")
	l.equipped[Loadout.Slot.SECONDARY] = CYBER
	for slot: StringName in Pool.PART_TABLES.values():
		if slot == &"light":
			continue
		assert_eq(rules.parts_for(CYBER, slot), [] as Array[Pool.Item], "nothing for %s" % slot)
		assert_false(rules.set_part(l, CYBER, slot, SILENCER))
	var kit := rules.carried(l)
	assert_eq(kit.replicas[1].id, &"cyber", "playable since CP1")
	assert_eq(kit.replicas[1].mag_size, 30, "RP1: 30 BBs a magazine (50 before)")
	assert_eq(kit.replicas[1].mags, 3)
	assert_false(kit.replicas[1].rattles)
	assert_eq(kit.replicas[1].heard_scale, 1.0)


func test_a_magazine_that_rounds_to_nothing_or_leaves_no_magazines_still_holds_a_bb_and_one_spare() -> void:
	var text := FileAccess.get_file_as_string("res://data/stats.md")
	text = text.replace("| 60 | 4 |", "| 3 | 4 |")
	text = text.replace("| lowCap | Low-Cap Magazine | 0.5 | 2 |", "| lowCap | Low-Cap Magazine | 0.1 | -10 |")
	var stats := ReplicaStats.parse(text)
	rules = LoadoutRules.new(Pool.read_file(), stats, ReplicaRulesConfig.new())
	var l := rules.default_loadout("Test")
	assert_true(rules.set_part(l, AEG, &"magazine", LOW_CAP))
	var r := rules.carried(l).replicas[0]
	assert_gte(r.mag_size, 1)
	assert_gte(r.mags, 1)
	assert_eq(Armament.create([r] as Array[ReplicaConfig]).mag(), r.mag_size)


func test_the_site_cap_holds_with_a_barrel_a_silencer_and_a_strong_battery() -> void:
	var l := rules.default_loadout("Test")
	rules.set_power(l, AEG, LIPO)
	rules.set_part(l, AEG, &"barrel", "000017")
	rules.set_part(l, AEG, &"muzzle", SILENCER)
	var kit := rules.carried(l)
	assert_lte(kit.replicas[0].muzzle_energy, rules.stats.energy_limit(rules.config(rules.pool.item(AEG)).site_class) + 1e-9)


func test_a_dev_part_off_and_on_again_comes_back_without_loss() -> void:
	var pool := Pool.parse("""### Replicas
| ID | Name | Key | Tags | Access |
|---|---|---|---|---|
| 000002 | AEG Rifle | aeg | rifle, electric, top-rail | public |
| 000001 | GBB Pistol | pistol | pistol, gas | public |

### Power sources
| ID | Name | Type | Fits | Access |
|---|---|---|---|---|
| 000003 | Standard Battery | battery | electric | public |
| 000004 | Green Gas | gas | gas | public |

### Optics
| ID | Name | Key | Fits | Access |
|---|---|---|---|---|
| 000010 | 2x Scope | scope2x | top-rail | dev |
""")
	rules = LoadoutRules.new(pool, ReplicaStats.read_file(), ReplicaRulesConfig.new())
	rules.dev_content = true
	var l := rules.default_loadout("Test")
	rules.set_part(l, AEG, &"optic", SCOPE)
	rules.dev_content = false
	rules.clean(l)
	var kit := rules.carried(l)
	assert_eq(kit.parts[0], {}, "no key for a part not fitted")
	assert_false(kit.dev)
	rules.dev_content = true
	kit = rules.carried(l)
	assert_eq(kit.parts[0], {&"optic": &"scope2x"})
	assert_true(kit.dev)


func test_a_part_with_no_stats_row_and_no_part_tables_plays_as_it_comes() -> void:
	var text := FileAccess.get_file_as_string("res://data/stats.md")
	var cut := text.find("## Optics")
	rules = LoadoutRules.new(Pool.read_file(), ReplicaStats.parse(text.substr(0, cut)), ReplicaRulesConfig.new())
	var l := rules.default_loadout("Test")
	rules.set_part(l, AEG, &"optic", SCOPE)
	rules.set_part(l, AEG, &"magazine", HI_CAP)
	var r := rules.carried(l).replicas[0]
	var base := rules.config(rules.pool.item(AEG))
	assert_eq(r.mag_size, base.mag_size)
	assert_eq(r.aim_zoom, 0.0)
	assert_eq(r.raise_scale, 1.0)
	assert_false(r.rattles)


func test_a_silencer_that_is_not_heard_at_all_does_not_break_hearing() -> void:
	var r := rules.config(rules.pool.item(AEG)).duplicate() as ReplicaConfig
	r.heard_scale = 0.0
	var tuning := SimTuning.load_default()
	var style := MapStyle.new()
	var map := MapData.load_map("depot", style, tuning.rounds.team_size)
	var level := MapLevel.new()
	add_child_autofree(level)
	level.build(map, style, tuning.body)
	var nav := NavGrid.build(map, tuning.nav, tuning.body)
	var state := GameState.new(3, tuning)
	var sim := Simulation.new(tuning, level.query(), level.mover(tuning.body), map.ends, map.kill_y)
	sim.nav = nav
	var cmds: Array[PlayerCommand] = []
	for i in tuning.rounds.team_size * 2:
		state.characters.append(Character.new(i, 0 if i < tuning.rounds.team_size else 1, Vector3.ZERO, 0.0,
				[r] as Array[ReplicaConfig]))
		cmds.append(PlayerCommand.new())
	var bots := BotController.new(state, -1, map, nav, level.query(), tuning, BotConfig.load_default())
	sim.start_match(state)
	var ear := bots.world.bots[0]
	var shooter := state.characters[tuning.rounds.team_size]
	ear.has_last_known = false
	ear.heard_at = -INF
	ear.character.position = Vector3(-14.0, 0.0, 0.0)
	shooter.position = Vector3(-14.0, 0.0, -1.0)
	state.events.clear()
	var shot := state.events.add(GameEvent.Kind.SHOT)
	shot.actor = shooter.id
	shot.position = shooter.position + Vector3(0.0, 1.5, 0.0)
	BotHearing.observe(state, bots.world)
	assert_false(ear.has_last_known, "a shot heard from no distance is not heard a metre off")


func test_a_rattling_walker_makes_no_allocations_per_tick() -> void:
	var r := rules.config(rules.pool.item(AEG)).duplicate() as ReplicaConfig
	r.rattles = true
	var cfg := FootstepConfig.new()
	var world := BoxWorld.new()
	var events := SimEvents.new()
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, [r] as Array[ReplicaConfig])
	c.walking = true
	c.grounded = true
	for i in 300:
		events.clear()
		c.prev_position = c.position
		c.position.z -= 0.03
		Footsteps.step(c, cfg, events, world)
	var tuning := SimTuning.load_default()
	var before := Performance.get_monitor(Performance.OBJECT_COUNT)
	var rattles := 0
	for i in 600:
		events.clear()
		c.prev_position = c.position
		c.position.z -= 0.03
		Footsteps.step(c, cfg, events, world)
		rattles += events.count_of(GameEvent.Kind.FOOTSTEP)
		Accuracy.step(c, tuning.movement, tuning.accuracy, DT)
	assert_gt(rattles, 0)
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), before)


func test_a_bot_match_where_everyone_carries_parts_still_plays_out() -> void:
	var tuning := SimTuning.load_default()
	var style := MapStyle.new()
	var map := MapData.load_map("depot", style, tuning.rounds.team_size)
	var level := MapLevel.new()
	add_child_autofree(level)
	level.build(map, style, tuning.body)
	var nav := NavGrid.build(map, tuning.nav, tuning.body)
	var l := rules.default_loadout("Parts")
	rules.set_part(l, AEG, &"optic", SCOPE)
	rules.set_part(l, AEG, &"grip", VERTICAL)
	rules.set_part(l, AEG, &"magazine", HI_CAP)
	rules.set_part(l, AEG, &"muzzle", SILENCER)
	var kit := rules.carried(l)
	var finished := false
	var friendly := 0
	var rattles := 0
	var shots := 0
	var config := BotConfig.load_default()
	var state := GameState.new(5, tuning)
	var sim := Simulation.new(tuning, level.query(), level.mover(tuning.body), map.ends, map.kill_y)
	sim.nav = nav
	var cmds: Array[PlayerCommand] = []
	for i in tuning.rounds.team_size * 2:
		var team := 0 if i < tuning.rounds.team_size else 1
		var rs: Array[ReplicaConfig] = [] as Array[ReplicaConfig]
		rs.assign(kit.replicas if team == 0 else ReplicaStats.default_loadout())
		state.characters.append(Character.new(i, team, Vector3.ZERO, 0.0, rs))
		cmds.append(PlayerCommand.new())
	var bots := BotController.new(state, -1, map, nav, level.query(), tuning, config)
	sim.start_match(state)
	bots.observe(state)
	for t in roundi(tuning.rounds.round_time / DT) * 14:
		bots.think(state, cmds, DT)
		sim.step(state, cmds, DT)
		bots.observe(state)
		for i in state.events.count:
			var e := state.events.items[i]
			if e.kind == GameEvent.Kind.CHARACTER_HIT and e.actor >= 0 \
					and state.characters[e.actor].team == state.characters[e.target].team:
				friendly += 1
			elif e.kind == GameEvent.Kind.MATCH_OVER:
				finished = true
			elif e.kind == GameEvent.Kind.SHOT:
				shots += 1
			elif e.kind == GameEvent.Kind.FOOTSTEP and e.value == GameEvent.Footstep.RATTLE:
				rattles += 1
		if finished:
			break
	gut.p("parts match: %d shots, %d rattles" % [shots, rattles])
	assert_true(finished, "the match was won")
	assert_gt(shots, 0)
	assert_eq(friendly, 0)
