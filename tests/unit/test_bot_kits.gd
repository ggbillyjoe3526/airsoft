extends GutTest
## The bots' kits (BK1): data/bot-kits.md read against the pool, each opposing bot's seeded pick by its difficulty's
## weights, and a kit played as the player's loadout is (game/loadout/bot_kits.gd, game/play/play_session.gd).

const AEG := "000002"
const PISTOL := "000001"
const CYBER := "000019"
const SILENCER := "000018"
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


func test_the_shipped_file_reads_clean() -> void:
	var k := BotKits.read_file(pool)
	assert_eq(k.problems, [] as Array[String])
	assert_eq(k.kits.map(func(p: BotKits.Plan) -> String: return p.kit_name),
			["Factory", "Rifleman", "Marksman", "Support", "Stealth", "Pointman", "Cyber", "Sniper", "Breacher",
			"Clearer"])
	var cyber := _kit(k, "Cyber")
	assert_eq(cyber.slots[0].replica, CYBER)
	assert_eq(cyber.weights[&"easy"], 0.0, "never at Easy")
	assert_eq(_kit(k, "Support").suits, PackedStringArray(["anchor", "rusher"]))
	assert_eq(BotKits.personalities(), PackedStringArray(["rusher", "anchor", "flanker", "careful"]))


func test_a_row_it_cant_read_is_left_out_with_its_line() -> void:
	var k := _parse("""| Good | AEG Rifle | Red Dot | | | | 1 | 1 | 1 |
| Typo | AEG Rifel | | | | | 1 | 1 | 1 |
| Misfit | GBB Pistol | Vertical Grip | | | | 1 | 1 | 1 |
| Twice | AEG Rifle | Red Dot, 2x Scope | | | | 1 | 1 | 1 |
| Weight | AEG Rifle | | | | | 1 | lots | 1 |
| Torch | AEG Rifle | Weapon Torch | | | | 1 | 1 | 1 |
| Moody | AEG Rifle | | | | grumpy | 1 | 1 | 1 |
| good | AEG Rifle | | | | | 1 | 1 | 1 |
| Parts only | | Red Dot | | | | 1 | 1 | 1 |
| Power | AEG Rifle | Green Gas | | | | 1 | 1 | 1 |
| Built in | Cyber Pistol | 11.1 V LiPo Battery | | | | 1 | 1 | 1 |
| Same | GBB Pistol | | GBB Pistol | | | 1 | 1 | 1 |
| Not a replica | Red Dot | | | | | 1 | 1 | 1 |
""")
	assert_eq(k.kits.size(), 1, "only Good reads")
	assert_eq(k.problems.size(), 12)
	var wants := ["bot-kits.md:6: Primary \"AEG Rifel\" isn't a Name or ID",
			"bot-kits.md:7: Primary part \"Vertical Grip\" doesn't fit the GBB Pistol",
			"both take the optic slot", "Normal weight \"lots\" isn't a number", "weapon torches are fitted by rule",
			"Suits \"grumpy\" isn't a bot personality", "kit \"good\" is listed twice", "Primary parts but no Primary",
			"\"Green Gas\" doesn't fit the AEG Rifle", "\"11.1 V LiPo Battery\" doesn't fit the Cyber Pistol",
			"both the Primary and the Secondary", "\"Red Dot\" isn't a replica"]
	for i in wants.size():
		assert_string_contains(k.problems[i], wants[i])


func test_a_file_without_its_columns_gives_no_kits() -> void:
	var k := BotKits.parse("| Kit | Primary |\n|---|---|\n| A | AEG Rifle |\n", pool)
	assert_eq(k.kits.size(), 0)
	assert_string_contains(k.problems[0], "no \"Secondary\" column")
	assert_string_contains(BotKits.parse("nothing here", pool).problems[0], "no table with a Kit column")


func test_a_pick_is_seeded_and_follows_the_difficultys_weights() -> void:
	var k := BotKits.read_file(pool)
	var seed_value := Seeds.kit_seed(42, 4)
	assert_eq(k.pick(&"easy", rules, seed_value), k.pick(&"easy", rules, seed_value), "a seed replays its kit")
	var counts: Dictionary[String, int] = {}
	for i in 4000:
		var plan := k.pick(&"easy", rules, Seeds.kit_seed(i, 3))
		counts[plan.kit_name] = counts.get(plan.kit_name, 0) + 1
	assert_almost_eq(counts["Factory"] / 4000.0, 0.30, 0.03)
	assert_almost_eq(counts["Rifleman"] / 4000.0, 0.25, 0.03)
	assert_false(counts.has("Cyber"), "weighted 0 at Easy: never")
	var hard: Dictionary[String, int] = {}
	for i in 2000:
		var plan := k.pick(&"hard", rules, Seeds.kit_seed(i, 3))
		hard[plan.kit_name] = hard.get(plan.kit_name, 0) + 1
	assert_false(hard.has("Factory"), "Hard never factory")
	assert_true(hard.has("Cyber"))


func test_each_bot_picks_its_own_kit() -> void:
	var k := BotKits.read_file(pool)
	var names: Dictionary[String, bool] = {}
	for id in 6:
		names[k.pick(&"hard", rules, Seeds.kit_seed(7, id)).kit_name] = true
	assert_gt(names.size(), 1, "six bots on one seed don't all carry the same kit")


func test_no_weight_above_zero_means_the_replicas_as_they_come() -> void:
	var k := _parse("| Only Hard | AEG Rifle | Red Dot | | | | 0 | | 5 |\n")
	assert_null(k.pick(&"normal", rules, 1))
	assert_null(k.pick(&"unknown", rules, 1))
	assert_not_null(k.pick(&"hard", rules, 1))


func test_dev_gear_is_picked_only_with_dev_content_on() -> void:
	pool.item(SILENCER).access = &"dev"
	var k := _parse("| Dev | AEG Rifle | Silencer | | | | 1 | 1 | 1 |\n")
	assert_eq(k.problems, [] as Array[String])
	assert_null(k.pick(&"normal", rules, 1), "dev gear stays out")
	rules.dev_content = true
	var plan := k.pick(&"normal", rules, 1)
	assert_not_null(plan)
	assert_true(BotKits.kit_of(plan, rules).dev, "the match stays off the record")


func test_a_kit_plays_with_its_parts_and_power_source() -> void:
	var k := BotKits.read_file(pool)
	var support := BotKits.kit_of(_kit(k, "Support"), rules)
	var factory := BotKits.kit_of(_kit(k, "Factory"), rules)
	assert_eq(support.replicas[0].mag_size, 120, "hi-cap")
	assert_almost_eq(support.replicas[0].fire_rate, factory.replicas[0].fire_rate * 1.15, 1e-6, "LiPo")
	assert_true(support.replicas[0].rattles)
	assert_eq(support.parts[0], {&"optic": &"redDot", &"grip": &"vertical", &"magazine": &"hiCap"})
	assert_eq(support.parts[1], {&"magazine": &"extended"})
	var stealth := BotKits.kit_of(_kit(k, "Stealth"), rules)
	assert_true(stealth.replicas[0].muffled, "the Silencer's quieter shots")
	assert_lt(stealth.replicas[0].heard_scale, 1.0)
	assert_eq(factory.parts, [{}, {}] as Array[Dictionary])


func test_bots_never_touch_the_selector_so_a_kit_comes_on_auto_where_it_can() -> void:
	var k := BotKits.read_file(pool)
	var cyber := BotKits.kit_of(_kit(k, "Cyber"), rules)
	assert_eq(cyber.replicas[0].id, &"cyber")
	assert_eq(cyber.replicas[0].default_fire_mode, ReplicaConfig.FireMode.AUTO)
	assert_eq(cyber.replicas[1].default_fire_mode, ReplicaConfig.FireMode.SEMI, "the GBB Pistol has semi only")
	assert_eq(rules.config(pool.item(CYBER)).default_fire_mode, ReplicaConfig.FireMode.SEMI, "the shared config kept")


func test_a_kit_with_no_secondary_carries_its_primary_only() -> void:
	var k := _parse("| Lone | Cyber Pistol | | | | | 1 | 1 | 1 |\n")
	var kit := BotKits.kit_of(k.kits[0], rules)
	assert_eq(kit.size(), 1)
	assert_eq(kit.replicas[0].id, &"cyber")
	assert_eq(kit.parts.size(), 1)


func test_what_you_have_unlocked_never_changes_a_bots_kit() -> void:
	var s := PlaySession.new()
	var bot_rules := s._bot_kit_rules()
	s.free()
	assert_null(bot_rules.progress, "the bots' rules follow no progress")
	var k := BotKits.read_file(pool)
	assert_eq(BotKits.kit_of(_kit(k, "Marksman"), bot_rules).parts[0][&"optic"], &"scope2x", "the 2x Scope (level 5) fitted")


func test_in_a_session_every_bot_on_both_teams_carries_its_kit() -> void:
	var s := PlaySession.new()
	s.autopilot = true
	s.settings = Settings.new()
	s.difficulty = &"hard"
	s.match_seed = 11
	add_child_autofree(s)
	await wait_physics_frames(3)
	var k := BotKits.shared()
	var kitted := 0
	var teammates := 0
	for c in s.state.characters:
		if c.id == PlaySession.PLAYER_ID:
			continue
		# Its kit leans towards its personality (BN1); your teammates pick theirs the same way (B4).
		var plan := k.pick(&"hard", s._bot_kit_rules(), Seeds.kit_seed(11, c.id), s._identities[c.id].personality,
				s._bot_config.kit_suit_lean, BotKits.field_kind(MapCatalog.shared().find(s.map_id)))
		assert_not_null(plan, "Hard never carries the replicas as they come")
		var kit := BotKits.kit_of(plan, s._bot_kit_rules())
		assert_eq(c.armament.replicas.size(), kit.size())
		for i in kit.size():
			assert_eq(c.armament.replicas[i].id, kit.replicas[i].id)
			assert_eq(c.armament.replicas[i].mag_size, kit.replicas[i].mag_size)
		assert_eq(s._bot_parts[c.id], kit.parts)
		kitted += 1
		if c.team == s.player_team:
			teammates += 1
	assert_eq(kitted, s._tuning.rounds.team_size * 2 - 1, "every bot on both teams")
	assert_eq(teammates, s._tuning.rounds.team_size - 1, "your teammates too")
