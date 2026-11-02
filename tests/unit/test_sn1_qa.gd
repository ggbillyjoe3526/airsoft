extends GutTest
## QA for the Sniper Rifle (SN1; owner, 2026-11-02): what must never leak to a player with Dev content off, the unlock
## levels as the owner set them, a save from before the move, a held trigger, every spring under the sniper limit with
## any muzzle part, the Armory's words for the rifle, and a bot match in which every bot carries the Sniper kit.

const DT := 1.0 / 60.0
const EYE := Vector3(0.0, 1.6, 0.0)
const SNIPER := "000021"
const SCOPE := "000010"
const RED_GAS := "000008"
const BLACK_GAS := "000009"
const M130 := "000022"
const M140 := "000023"
const M150 := "000024"
const DEV_IDS: Array[String] = [SNIPER, M130, M140, M150]

var pool: Pool
var table: LevelTable
var rules: LoadoutRules


func before_all() -> void:
	pool = Pool.read_file()
	table = LevelTable.read_file(pool)


func before_each() -> void:
	rules = LoadoutRules.new(pool, ReplicaStats.read_file(), ReplicaRulesConfig.new())
	rules.dev_content = true


func _words(root: Node) -> PackedStringArray:
	var out := PackedStringArray()
	for l in root.find_children("*", "Label", true, false):
		out.append((l as Label).text)
	return out


func _sniper_config() -> ReplicaConfig:
	return rules.config(pool.item(SNIPER))


# --- the owner's unlock levels ---

func test_the_levels_are_as_the_owner_set_them_and_the_cap_stays_10() -> void:
	assert_eq(table.cap(), 10, "level cap stays 10")
	assert_eq(table.unlock_level(SNIPER), 5)
	assert_eq(table.unlock_level(M130), 5)
	assert_eq(table.unlock_level(SCOPE), 5)
	assert_eq(table.unlock_level(RED_GAS), 6, "Red Gas moved from 5 to 6")
	assert_eq(table.unlock_level(M140), 7)
	assert_eq(table.unlock_level(M150), 9)
	assert_eq(table.unlock_level(BLACK_GAS), 9, "Black Gas stays with the M150")


func test_the_springs_unlock_one_by_one_and_a_locked_one_cannot_be_picked() -> void:
	var p := Progress.new(table)
	rules.follow_progress(p, false)
	p.add_xp(table.levels[5].total)
	var l := rules.default_loadout("L")
	assert_true(rules.equip(l, Loadout.Slot.PRIMARY, SNIPER))
	assert_true(rules.set_power(l, SNIPER, M130))
	assert_false(rules.set_power(l, SNIPER, M140), "locked at level 5")
	p.add_xp(table.levels[7].total - p.xp)
	assert_true(rules.set_power(l, SNIPER, M140), "unlocked at level 7")
	assert_false(rules.set_power(l, SNIPER, M150), "locked at level 7")
	p.add_xp(table.levels[9].total - p.xp)
	assert_true(rules.set_power(l, SNIPER, M150), "unlocked at level 9")


# --- a save from before the move ---

func test_a_save_from_before_gets_the_new_level_5_gear_and_keeps_what_it_had() -> void:
	# A level 6 player of the old table: Red Gas (old level 5) in hand, no Sniper Rifle, M130 or 2x Scope (old level 7).
	var old := table.unlocks_up_to(6)
	var ids: Array = []
	for id in old:
		if not [SNIPER, M130, SCOPE].has(id):
			ids.append(id)
	var p := Progress.new(table)
	p.from_dict({"xp": table.levels[6].total, "unlocked": ids})
	assert_false(p.has(SNIPER))
	var added := p.grant_reached()
	assert_eq(Array(added).size(), 3, "exactly the three new level 5 items")
	for id: String in [SNIPER, M130, SCOPE]:
		assert_true(p.has(id), id)
	assert_true(p.has(RED_GAS))
	assert_false(p.has(M140), "level 7 is still ahead")


func test_an_old_player_at_level_5_keeps_red_gas_after_it_moved_to_6() -> void:
	var ids: Array = Array(table.unlocks_up_to(4))
	ids.append(RED_GAS)
	var p := Progress.new(table)
	p.from_dict({"xp": table.levels[5].total, "unlocked": ids})
	p.grant_reached()
	assert_true(p.has(RED_GAS), "never taken away")


# --- nothing dev shows to a player with Dev content off ---

func test_the_armory_names_no_sniper_gear_without_dev_content_and_with_it_names_all() -> void:
	var plain := ArmoryFacts.new(table, pool, table.levels[10].total, false, false)
	var dev := ArmoryFacts.new(table, pool, table.levels[10].total, false, true)
	var plain_ids := PackedStringArray()
	var dev_ids := PackedStringArray()
	for r in plain.rows:
		for it in r.items:
			plain_ids.append(it.id)
	for r in dev.rows:
		for it in r.items:
			dev_ids.append(it.id)
	for id in DEV_IDS:
		assert_false(plain_ids.has(id), "%s hidden" % id)
		assert_true(dev_ids.has(id), "%s shown with Dev content" % id)
	assert_eq(dev.item_count - plain.item_count, 5, "the rifle, three springs and the Variable Scope (SN2)")
	assert_true(plain_ids.has(SCOPE), "the public 2x Scope is still listed")


func test_the_next_unlock_skips_level_7_without_dev_content() -> void:
	# Level 7 gives only the dev M140 Spring: a public player's next unlock from level 6 is the level 8 battery.
	var facts := ArmoryFacts.new(table, pool, table.levels[6].total, false, false)
	var next := facts.next_row()
	assert_not_null(next)
	assert_eq(next.number, 8)
	for it in next.items:
		assert_false(it.is_dev())


func test_a_level_up_with_only_dev_gear_names_none_of_it_without_dev_content() -> void:
	var p := Progress.new(table)
	p.from_dict({"xp": table.levels[6].total})
	p.grant_reached()
	var o := MatchXp.Outcome.new()
	o.won = true
	o.rounds_won = 5
	var s := PlayerTally.Settled.new()
	s.earned = MatchXp.earned(table, o)
	s.level_up = p.add_xp(table.levels[7].total - p.xp)
	assert_eq(s.level_up.to, 7)
	var card := XpCard.new(s, p, pool, false)
	add_child_autofree(card)
	await wait_process_frames(2)
	for w in _words(card):
		assert_false(w.begins_with("Unlocked"), "no dev gear named: %s" % w)
		assert_false(w.contains("M140") or w.contains("Spring"), w)
	assert_eq(card.find_child("LevelUp", true, false).find_children("*", "TextureRect", true, false).size(), 0,
			"no picture of it either")


func test_a_rifle_in_a_saved_loadout_plays_as_the_default_without_dev_content() -> void:
	var l := rules.default_loadout("L")
	assert_true(rules.equip(l, Loadout.Slot.PRIMARY, SNIPER))
	rules.dev_content = false
	var kit := rules.carried(l)
	assert_ne(kit.replicas[0].id, &"sniper", "the AEG, not the rifle")
	assert_false(kit.dev, "and not a dev match")
	assert_false(rules.is_offered(SNIPER))


func test_no_bot_carries_the_sniper_kit_without_dev_content() -> void:
	var kits := BotKits.read_file(pool)
	rules.dev_content = false
	for difficulty: StringName in [&"easy", &"normal", &"hard"]:
		for seed_value in 300:
			for personality: StringName in [&"", &"anchor", &"careful"]:
				var plan := kits.pick(difficulty, rules, seed_value, personality)
				if plan != null:
					assert_ne(plan.kit_name, "Sniper", "%s seed %d" % [difficulty, seed_value])
					for id in plan.items():
						assert_false(DEV_IDS.has(id), id)


func test_with_dev_content_hard_bots_carry_the_sniper_kit_now_and_then() -> void:
	var kits := BotKits.read_file(pool)
	var seen := 0
	for seed_value in 300:
		var plan := kits.pick(&"hard", rules, seed_value, &"careful")
		if plan != null and plan.kit_name == "Sniper":
			seen += 1
	assert_gt(seen, 0, "weight 8 on Hard")


# --- the rifle's own rules ---

func test_a_held_trigger_fires_one_shot_and_no_more_until_it_is_released() -> void:
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, [_sniper_config()] as Array[ReplicaConfig])
	var cmd := PlayerCommand.new()
	cmd.fire = true
	var pool_bb := BBPool.new(8)
	var events := SimEvents.new()
	var tuning := SimTuning.new()
	var shots := 0
	for tick in 600:
		events.clear()
		Armament.step(c, cmd, EYE, 1.0, true, pool_bb, Seeds.stream(3), events, tuning, DT)
		shots += events.count_of(GameEvent.Kind.SHOT)
	assert_eq(shots, 1, "single shot: ten seconds of a held trigger is one BB")
	assert_eq(c.armament.fire_mode(), ReplicaConfig.FireMode.SEMI)
	assert_eq(_sniper_config().fire_modes.size(), 1, "no selector to another mode")


func test_every_spring_with_every_muzzle_part_stays_at_or_under_the_sniper_limit() -> void:
	var limit := rules.stats.energy_limit(&"sniper")
	var muzzles := pool.parts_for(pool.item(SNIPER), &"muzzle", true)
	assert_false(muzzles.is_empty(), "muzzle parts fit it")
	for spring: String in [M130, M140, M150]:
		for m in muzzles:
			var l := rules.default_loadout("L")
			rules.equip(l, Loadout.Slot.PRIMARY, SNIPER)
			assert_true(rules.set_power(l, SNIPER, spring))
			assert_true(rules.set_part(l, SNIPER, &"muzzle", m.id))
			var kit := rules.carried(l)
			assert_lte(kit.replicas[0].muzzle_energy, limit + 1e-6, "%s with %s" % [spring, m.display_name])


func test_the_hip_spread_is_the_aeg_s_unchanged_and_six_times_on_the_rifle_only_with_the_sight_down() -> void:
	var cfg := MovementConfig.new()
	var acc := AccuracyConfig.new()
	var sniper := Character.new(1, 0, Vector3.ZERO, 0.0, [_sniper_config()] as Array[ReplicaConfig])
	var aeg := Character.new(2, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	var hip_s := Accuracy.target_spread_scale(sniper, cfg, acc)
	var hip_a := Accuracy.target_spread_scale(aeg, cfg, acc)
	assert_almost_eq(hip_s / hip_a, 6.0, 1e-4, "six times the AEG's, sight down")
	sniper.aim_raise = 0.5
	aeg.aim_raise = 0.5
	var half := Accuracy.target_spread_scale(sniper, cfg, acc) / Accuracy.target_spread_scale(aeg, cfg, acc)
	assert_almost_eq(half, 3.5, 1e-4, "half way up: 1 + 5 * 0.5")
	sniper.aim_raise = 1.0
	aeg.aim_raise = 1.0
	assert_almost_eq(Accuracy.target_spread_scale(sniper, cfg, acc), Accuracy.target_spread_scale(aeg, cfg, acc), 1e-6,
			"sight up: the same as any replica")


# --- words ---

func test_the_armory_has_a_blurb_for_the_sniper_rifle_not_its_translation_key() -> void:
	var blurb := ArmoryFacts.blurb(pool.item(SNIPER))
	assert_ne(blurb, "", "has words")
	assert_false(blurb.begins_with("ARMORY_BLURB"), "shows '%s' as it is a missing translation" % blurb)


func test_the_sniper_rifle_has_a_class_name_for_the_loadout() -> void:
	assert_eq(tr("LOADOUT_CLASS_SNIPER"), "sniper rifle")


# --- a headless bot match with the Sniper kit on every bot ---

func test_a_match_of_sniper_kit_bots_shoots_and_goes_on() -> void:
	var tuning := SimTuning.load_default()
	var style := MapStyle.new()
	var map := YardMap.load_map(style, tuning.rounds.team_size)
	var level := MapLevel.new()
	add_child_autofree(level)
	level.build(map, style, tuning.body)
	var nav := NavGrid.build(map, tuning.nav, tuning.body)
	var kits := BotKits.read_file(pool)
	var plan: BotKits.Plan = null
	for p in kits.kits:
		if p.kit_name == "Sniper":
			plan = p
	assert_not_null(plan)
	var kit := BotKits.kit_of(plan, rules)
	var sim := Simulation.new(tuning, level.query(), level.mover(tuning.body), map.ends, map.kill_y)
	sim.nav = nav
	var state := GameState.new(21, tuning)
	var commands: Array[PlayerCommand] = []
	for i in tuning.rounds.team_size * 2:
		state.characters.append(Character.new(i, 0 if i < tuning.rounds.team_size else 1, Vector3.ZERO, 0.0,
				kit.replicas))
		commands.append(PlayerCommand.new())
	var bots := BotController.new(state, -1, map, nav, level.query(), tuning, BotConfig.load_default())
	sim.start_match(state)
	bots.observe(state)
	var shots := 0
	var from_hip := 0
	var hits := 0
	var finished := false
	var limit := roundi(tuning.rounds.round_time / DT) * 14
	for t in limit:
		bots.think(state, commands, DT)
		sim.step(state, commands, DT)
		bots.observe(state)
		for i in state.events.count:
			var e := state.events.items[i]
			if e.kind == GameEvent.Kind.SHOT:
				shots += 1
				if state.characters[e.actor].aim_raise < 0.9:
					from_hip += 1
			elif e.kind == GameEvent.Kind.CHARACTER_HIT:
				hits += 1
			elif e.kind == GameEvent.Kind.MATCH_OVER:
				finished = true
		if finished:
			break
	gut.p("sniper bots: %d shots (%d with the sight down), %d hits, finished %s" % [shots, from_hip, hits, finished])
	assert_gt(shots, 0, "the bots shoot")
	assert_true(finished, "the match ends")
