extends GutTest
## BK1 QA: edge cases of the bots' kits (reading, picking, building, and a session that carries them).

const HEADER := """## Kits

| Kit | Primary | Primary parts | Secondary | Secondary parts | Suits | Easy | Normal | Hard |
|---|---|---|---|---|---|---|---|---|
"""

var pool: Pool
var rules: LoadoutRules


func before_each() -> void:
	pool = Pool.read_file()
	rules = LoadoutRules.new(pool, ReplicaStats.read_file(), ReplicaRulesConfig.new())


## A shipped kit by its name, so reordering bot-kits.md never breaks a test.
func _kit(k: BotKits, kit_name: String) -> BotKits.Plan:
	for p in k.kits:
		if p.kit_name == kit_name:
			return p
	fail_test("no kit named %s" % kit_name)
	return null


func _parse(rows: String) -> BotKits:
	return BotKits.parse(HEADER + rows, pool, BotKits.personalities())


func _session(seed_value: int, level: StringName = &"easy") -> PlaySession:
	var s := PlaySession.new()
	s.autopilot = true
	s.settings = Settings.new()
	s.difficulty = level
	s.match_seed = seed_value
	add_child_autofree(s)
	return s


func test_parts_by_id_and_odd_case_and_spacing_read() -> void:
	var red_dot := pool.named("Red Dot")
	var k := _parse("|  rIfLe  | aeg RIFLE |   %s ,, vertical GRIP ,  | gbb pistol | | CAREFUL , Anchor | 1 | 1 | 1 |\n" % red_dot.id)
	assert_eq(k.problems, [] as Array[String])
	assert_eq(k.kits.size(), 1)
	assert_eq(k.kits[0].slots[0].parts.size(), 2)
	assert_eq(k.kits[0].suits, PackedStringArray(["careful", "anchor"]))


func test_a_secondary_only_row_is_left_out() -> void:
	var k := _parse("| Side | | | GBB Pistol | | | 1 | 1 | 1 |\n")
	assert_eq(k.kits.size(), 0)
	assert_eq(k.problems.size(), 1)
	assert_string_contains(k.problems[0], "no Primary")


func test_two_power_sources_for_one_replica_are_left_out() -> void:
	var k := _parse("| Two | AEG Rifle | 11.1 V LiPo Battery, 7.4 V LiPo Battery | | | | 1 | 1 | 1 |\n")
	assert_eq(k.kits.size(), 0, "two power sources: one slot")


func test_weights_all_zero_pick_nothing_and_negative_weight_is_a_problem() -> void:
	var k := _parse("| Z | AEG Rifle | | | | | 0 | 0 | 0 |\n| N | AEG Rifle | | | | | -1 | 1 | 1 |\n")
	assert_eq(k.kits.size(), 1)
	assert_eq(k.problems.size(), 1)
	for d: StringName in [&"easy", &"normal", &"hard"]:
		assert_null(k.pick(d, rules, 5))


func test_an_infinite_or_nan_weight_is_a_problem() -> void:
	var k := _parse("| I | AEG Rifle | | | | | inf | 1 | 1 |\n| N | AEG Rifle | | | | | nan | 1 | 1 |\n")
	assert_eq(k.kits.size(), 0, "%s" % [k.problems])


func test_a_pistol_primary_with_the_aeg_as_secondary_swaps_the_slots() -> void:
	var k := _parse("| Swap | GBB Pistol | | AEG Rifle | | | 1 | 1 | 1 |\n| Cy | Cyber Pistol | | AEG Rifle | Red Dot | | 1 | 1 | 1 |\n")
	assert_eq(k.kits.size(), 2)
	var kit := BotKits.kit_of(k.kits[0], rules)
	assert_eq(kit.size(), 2)
	assert_eq(kit.replicas[0].id, &"pistol")
	assert_eq(kit.replicas[1].id, &"aeg")
	var cy := BotKits.kit_of(k.kits[1], rules)
	assert_eq(cy.replicas[0].id, &"cyber")
	assert_eq(cy.replicas[1].id, &"aeg")
	assert_eq(cy.parts[1], {&"optic": &"redDot"})
	assert_eq(cy.parts[0], {})


func test_a_kit_of_the_aeg_alone_with_the_pistol_as_primary_only() -> void:
	var k := _parse("| Solo | GBB Pistol | Red Laser | | | | 1 | 1 | 1 |\n")
	var kit := BotKits.kit_of(k.kits[0], rules)
	assert_eq(kit.size(), 1)
	assert_eq(kit.replicas[0].id, &"pistol")


func test_building_a_kit_does_not_change_the_shared_configs() -> void:
	var k := BotKits.read_file(pool)
	for p in k.kits:
		BotKits.kit_of(p, rules)
	var aeg := rules.config(pool.named("AEG Rifle"))
	var base := ReplicaStats.read_file().replica_config(pool.named("AEG Rifle").key)
	assert_eq(aeg.default_fire_mode, base.default_fire_mode)
	assert_eq(aeg.mag_size, base.mag_size)
	assert_eq(aeg.muffled, base.muffled)
	assert_eq(aeg.heard_scale, base.heard_scale)
	var cyber := rules.config(pool.named("Cyber Pistol"))
	assert_eq(cyber.default_fire_mode, ReplicaConfig.FireMode.SEMI)


func test_the_same_kit_twice_gives_equal_numbers() -> void:
	var k := BotKits.read_file(pool)
	var a := BotKits.kit_of(_kit(k, "Support"), rules)
	var b := BotKits.kit_of(_kit(k, "Support"), rules)
	assert_eq(a.replicas[0].mag_size, b.replicas[0].mag_size)
	assert_eq(a.replicas[0].muzzle_energy, b.replicas[0].muzzle_energy)


func test_every_shipped_kit_builds_on_standard_rules_with_parts_matching() -> void:
	var std := LoadoutRules.standard()
	var with_dev := LoadoutRules.standard()
	with_dev.dev_content = true
	for p in BotKits.shared().kits:
		# A kit carrying dev gear (SN1's Sniper) is offered only with Dev content on, and makes a dev match.
		var dev_kit := false
		for id in p.items():
			dev_kit = dev_kit or pool.item(id).is_dev()
		var rules_for := with_dev if dev_kit else std
		assert_eq(BotKits.offers(std, p), not dev_kit, p.kit_name)
		assert_true(BotKits.offers(rules_for, p), p.kit_name)
		var kit := BotKits.kit_of(p, rules_for)
		assert_eq(kit.size(), p.slots.size(), p.kit_name)
		assert_eq(kit.parts.size(), kit.size())
		assert_eq(kit.dev, dev_kit, p.kit_name)
		for i in kit.size():
			for id in p.slots[i].parts:
				var it := pool.item(id)
				if it.kind == Pool.Kind.PART:
					assert_eq(kit.parts[i].get(it.slot), it.key, "%s: %s fitted" % [p.kit_name, it.display_name])


func test_a_kitted_silencer_is_heard_less_far_by_other_bots() -> void:
	var k := BotKits.read_file(pool)
	var stealth := BotKits.kit_of(_kit(k, "Stealth"), rules)
	var factory := BotKits.kit_of(_kit(k, "Factory"), rules)
	assert_lt(stealth.replicas[0].heard_scale, factory.replicas[0].heard_scale)
	assert_lt(stealth.replicas[0].heard_scale, 1.0)


func test_the_same_seed_gives_the_same_kits_in_two_sessions() -> void:
	var a := _session(77, &"normal")
	var b := _session(77, &"normal")
	await wait_physics_frames(3)
	assert_eq(a.state.characters.size(), b.state.characters.size())
	for i in a.state.characters.size():
		var x := a.state.characters[i]
		var y := b.state.characters[i]
		assert_eq(x.armament.replicas.size(), y.armament.replicas.size())
		for j in x.armament.replicas.size():
			assert_eq(x.armament.replicas[j].mag_size, y.armament.replicas[j].mag_size)
			assert_eq(x.armament.replicas[j].muffled, y.armament.replicas[j].muffled)
	assert_eq(a._bot_parts, b._bot_parts)


func test_different_seeds_give_different_kits_somewhere() -> void:
	var differing := false
	var k := BotKits.shared()
	var r := LoadoutRules.standard()
	for sd in range(1, 30):
		var p1 := k.pick(&"hard", r, Seeds.kit_seed(sd, 5))
		var p2 := k.pick(&"hard", r, Seeds.kit_seed(sd + 100, 5))
		if p1.kit_name != p2.kit_name:
			differing = true
	assert_true(differing)


func test_a_rematch_keeps_the_kits() -> void:
	var s := _session(5, &"hard")
	await wait_physics_frames(3)
	var before: Array = []
	for c in s.state.characters:
		before.append(c.armament.replicas[0].mag_size)
	var parts_before := s._bot_parts.duplicate(true)
	s._sim.start_match(s.state)
	await wait_physics_frames(3)
	for i in s.state.characters.size():
		assert_eq(s.state.characters[i].armament.replicas[0].mag_size, before[i])
	assert_eq(s._bot_parts, parts_before)


func test_a_bots_figure_gets_its_parts_and_a_single_replica_kit_does_not_break() -> void:
	var s := _session(9, &"hard")
	await wait_physics_frames(3)
	assert_gt(s._bot_parts.size(), 0)
	assert_eq(s._figures.size(), s.state.characters.size() - 1)
	var f := FigureView.new()
	var c := Character.new(50, 1, Vector3.ZERO, 0.0, [BotKits.kit_of(_parse("| L | Cyber Pistol | | | | | 1 | 1 | 1 |\n").kits[0], rules).replicas[0]] as Array[ReplicaConfig])
	var parts: Array[Dictionary] = [{}]
	f.setup(c, Color.RED, s._tuning.hits, null, false, parts)
	add_child_autofree(f)
	await wait_physics_frames(2)
	assert_not_null(f)


func test_a_session_with_dev_content_off_never_picks_dev_gear() -> void:
	var s := _session(3, &"hard")
	await wait_physics_frames(3)
	assert_false(s.state.dev_content)
	assert_false(s.state.off_record)


func test_the_session_leaves_no_orphans_after_free() -> void:
	var before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var s := _session(8, &"hard")
	await wait_physics_frames(3)
	s.queue_free()
	await wait_physics_frames(3)
	assert_lte(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), before)


func test_levels_md_reads_the_same_after_the_name_helpers_moved() -> void:
	var t := LevelTable.read_file(pool)
	assert_eq(t.problems, [] as Array[String])
	assert_eq(DataTable.names(" a , ,b,"), PackedStringArray(["a", "b"]))
	assert_eq(pool.named("red dot"), pool.named(pool.named("Red Dot").id))
	assert_null(pool.named(""))
	assert_null(pool.named("no such thing"))


func test_a_dev_power_source_in_a_kit_is_carried_only_with_dev_content() -> void:
	pool.named("11.1 V LiPo Battery").access = &"dev"
	var k := _parse("| Dev | AEG Rifle | 11.1 V LiPo Battery | | | | 1 | 1 | 1 |\n")
	assert_eq(k.kits.size(), 1, "%s" % [k.problems])
	assert_null(k.pick(&"easy", rules, 1))
	rules.dev_content = true
	var plan := k.pick(&"easy", rules, 1)
	assert_not_null(plan)
	var kit := BotKits.kit_of(plan, rules)
	assert_true(kit.dev)
	var plain := BotKits.kit_of(_parse("| P | AEG Rifle | | | | | 1 | 1 | 1 |\n").kits[0], rules)
	assert_ne(kit.replicas[0].fire_rate, plain.replicas[0].fire_rate, "the dev battery is fitted")


func test_the_bot_kit_rules_follow_the_dev_content_setting() -> void:
	var s := PlaySession.new()
	s.settings = Settings.new()
	s.settings.dev.dev_content = true
	assert_true(s._bot_kit_rules().dev_content)
	s.settings.dev.dev_content = false
	assert_false(s._bot_kit_rules().dev_content)
	s.free()
