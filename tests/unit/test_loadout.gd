extends GutTest
## The loadout carried (LO1): data/pool.md's items and what fits what, the loadout rules (offered replicas, each
## replica as it comes, the edits snapped and checked) and the kit a loadout plays as (power sources and the site
## limit), ported from the browser game's pool/kit.test.ts and loadoutModel.test.ts.

const AEG := "000002"
const PISTOL := "000001"
const CYBER := "000019"
const SNIPER := "000021"
const STANDARD := "000003"
const LIPO := "000015"
const GREEN := "000004"
const BLACK := "000009"
## A replica the pool lists but the game has no built-in config for (added to the rules' pool by _unplayable).
const UNPLAYABLE := "000099"

var rules: LoadoutRules


func before_each() -> void:
	rules = LoadoutRules.new(Pool.read_file(), ReplicaStats.read_file(), ReplicaRulesConfig.new())


func test_the_shipped_pool_reads_without_a_problem() -> void:
	var pool := Pool.read_file()
	assert_eq(pool.problems, [] as Array[String])
	assert_eq(pool.replicas.map(func(i: Pool.Item) -> String: return i.id), [PISTOL, AEG, CYBER, "000021", "000026"])
	assert_eq(pool.powers.size(), 8, "two batteries, three gases, three springs (SN1)")
	assert_eq(pool.item(AEG).key, &"aeg")
	assert_true(pool.item(AEG).tags.has("electric"))


func test_batteries_fit_electric_replicas_gas_fits_gas_and_nothing_fits_built_in_power() -> void:
	var pool := rules.pool
	var ids := func(list: Array[Pool.Item]) -> Array: return list.map(func(i: Pool.Item) -> String: return i.id)
	assert_eq(ids.call(pool.powers_for(pool.item(AEG), false)), [STANDARD, LIPO])
	assert_eq(ids.call(pool.powers_for(pool.item(PISTOL), false)), [GREEN, "000008", BLACK])
	assert_eq(ids.call(pool.powers_for(pool.item(CYBER), false)), [])


func test_a_part_can_fit_one_replica_by_its_id() -> void:
	var pool := Pool.parse("""### Replicas
| ID | Name | Key | Tags | Access |
|---|---|---|---|---|
| 000002 | AEG Rifle | aeg | rifle, electric | public |
| 000001 | GBB Pistol | pistol | pistol, gas | |

### Power sources
| ID | Name | Type | Fits | Access |
|---|---|---|---|---|
| 000050 | Odd Gas | gas | 000002 | public |
""")
	assert_eq(pool.problems, [] as Array[String])
	assert_true(pool.fits(pool.item("000050"), pool.item(AEG)))
	assert_false(pool.fits(pool.item("000050"), pool.item(PISTOL)), "a blank Access reads as public, Fits by ID only")
	assert_eq(pool.item(PISTOL).access, &"public")


func test_a_bad_row_is_left_out_and_reported_with_its_line() -> void:
	var pool := Pool.parse("""### Replicas
| ID | Name | Key | Tags | Access |
|---|---|---|---|---|
| 2 | Short Id | aeg | rifle | public |
| 000002 | AEG Rifle | aeg | rifle | publik |
| 000003 | No Key |  | rifle | public |
| 000004 | Dev Rifle | aeg | rifle | dev |
""")
	assert_eq(pool.replicas.size(), 1, "only the dev rifle reads")
	assert_true(pool.replicas[0].is_dev())
	assert_eq(pool.problems.size(), 4, "three bad rows and no power table")
	assert_string_contains(pool.problems[0], "pool.md:4")


func _unplayable() -> void:
	var it := Pool.Item.new()
	it.id = UNPLAYABLE
	it.key = &"spring"
	it.display_name = "Spring Rifle"
	it.tags = PackedStringArray(["rifle"])
	rules.pool.replicas.append(it)


func test_only_replicas_the_game_can_play_are_offered() -> void:
	_unplayable()
	var offered := rules.offered().map(func(i: Pool.Item) -> String: return i.id)
	assert_eq(offered, [PISTOL, AEG, CYBER, SNIPER],
			"the Cyber Pistol plays since CP1, the Sniper Rifle is public since 2026-11-05; one with no config isn't offered")


func test_a_new_player_carries_the_browser_games_defaults() -> void:
	var l := rules.default_loadout("Loadout 1")
	assert_eq(l.equipped, PackedStringArray([AEG, PISTOL]))
	var aeg := rules.tune_of(l, AEG)
	assert_almost_eq(aeg.bb_weight, 0.25, 1e-9)
	assert_almost_eq(aeg.hop_up, 0.65, 1e-9)
	assert_eq(aeg.paint, &"cobalt")
	assert_eq(aeg.power_id, STANDARD)
	var pistol := rules.tune_of(l, PISTOL)
	assert_almost_eq(pistol.bb_weight, 0.2, 1e-9)
	assert_almost_eq(pistol.hop_up, 0.5, 1e-9)
	assert_eq(pistol.paint, &"ghost")
	assert_eq(pistol.power_id, GREEN)


func test_carrying_the_other_slots_replica_swaps_the_two() -> void:
	var l := rules.default_loadout("L")
	assert_true(rules.equip(l, Loadout.Slot.PRIMARY, PISTOL))
	assert_eq(l.equipped, PackedStringArray([PISTOL, AEG]))
	_unplayable()
	assert_false(rules.equip(l, Loadout.Slot.SECONDARY, UNPLAYABLE), "not on offer")
	assert_eq(l.equipped, PackedStringArray([PISTOL, AEG]))
	assert_true(rules.equip(l, Loadout.Slot.SECONDARY, CYBER))
	assert_eq(l.equipped, PackedStringArray([PISTOL, CYBER]))


func test_bb_weight_and_hop_up_stay_in_range_on_their_steps() -> void:
	var l := rules.default_loadout("L")
	assert_almost_eq(rules.set_bb_weight(l, AEG, 0.284), 0.28, 1e-9)
	assert_almost_eq(rules.set_bb_weight(l, AEG, 0.9), 0.4, 1e-9)
	assert_almost_eq(rules.set_bb_weight(l, AEG, 0.1), 0.2, 1e-9)
	assert_almost_eq(rules.set_hop_up(l, AEG, 0.81), 0.8, 1e-9)
	assert_almost_eq(rules.set_hop_up(l, AEG, -1.0), 0.0, 1e-9)
	assert_almost_eq(rules.set_hop_up(l, AEG, 3.0), 1.0, 1e-9)
	assert_almost_eq(rules.tune_of(l, PISTOL).bb_weight, 0.2, 1e-9, "each replica keeps its own setup")


func test_paint_is_a_scheme_or_a_plain_colour() -> void:
	var l := rules.default_loadout("L")
	assert_true(rules.set_paint(l, AEG, &"signal"))
	assert_true(rules.set_paint(l, PISTOL, &"tan"))
	assert_false(rules.set_paint(l, AEG, &"pink"))
	assert_eq(rules.tune_of(l, AEG).paint, &"signal")
	assert_eq(ReplicaSchemes.paint_name(&"signal", true), "Tan", "Realistic colours shows a scheme as its family")
	assert_eq(ReplicaSchemes.colours(&"cobalt", false).size(), ReplicaSchemes.PARTS.size())
	assert_eq(ReplicaSchemes.colours(ReplicaSchemes.OWN, false), [] as Array[Color])


func test_a_power_source_must_fit() -> void:
	var l := rules.default_loadout("L")
	assert_true(rules.set_power(l, AEG, LIPO))
	assert_false(rules.set_power(l, AEG, GREEN), "gas doesn't fit an AEG")
	assert_false(rules.set_power(l, AEG, AEG), "a replica is no power source")
	assert_eq(rules.tune_of(l, AEG).power_id, LIPO)


func test_a_battery_sets_the_rate_and_gas_the_energy_and_kick() -> void:
	var l := rules.default_loadout("L")
	var plain := rules.carried(l)
	rules.set_power(l, AEG, LIPO)
	rules.set_power(l, PISTOL, BLACK)
	var kit := rules.carried(l)
	assert_almost_eq(kit.replicas[0].fire_rate, plain.replicas[0].fire_rate * 1.15, 1e-6)
	assert_almost_eq(kit.replicas[0].muzzle_energy, plain.replicas[0].muzzle_energy, 1e-9)
	assert_almost_eq(kit.replicas[1].muzzle_energy, plain.replicas[1].muzzle_energy * 1.2, 1e-6)
	# RP1: Black Gas kicks 40 % harder and cycles the slide a tenth slower (20 % and no slower before).
	assert_almost_eq(kit.replicas[1].recoil_deg, plain.replicas[1].recoil_deg * 1.4, 1e-6)
	assert_almost_eq(kit.replicas[1].fire_rate, plain.replicas[1].fire_rate * 0.9, 1e-6)
	assert_eq(kit.capped, [false, false] as Array[bool])
	assert_false(kit.dev)


func test_the_site_limit_caps_the_energy_and_says_so() -> void:
	var stats := ReplicaStats.read_file()
	stats.site_limits[&"pistol"] = 0.55
	var capped_rules := LoadoutRules.new(Pool.read_file(), stats, ReplicaRulesConfig.new())
	var l := capped_rules.default_loadout("L")
	capped_rules.set_power(l, PISTOL, BLACK)
	var kit := capped_rules.carried(l)
	assert_almost_eq(kit.replicas[1].muzzle_energy, 0.55, 1e-9)
	assert_eq(kit.capped, [false, true] as Array[bool])


func test_the_kit_carries_the_dial_weight_and_paint_into_the_armament() -> void:
	var l := rules.default_loadout("L")
	rules.set_bb_weight(l, AEG, 0.28)
	rules.set_hop_up(l, AEG, 0.8)
	rules.set_paint(l, AEG, &"acid")
	var kit := rules.carried(l)
	assert_eq(kit.paints, [&"acid", &"ghost"] as Array[StringName])
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, kit.replicas, kit.bb_weights)
	assert_almost_eq(c.armament.bb_weights[0], 0.28, 1e-9)
	assert_almost_eq(c.armament.bb_weights[1], 0.2, 1e-9)
	assert_almost_eq(c.armament.hop_ups[0], 0.8, 1e-9)
	c.armament.hop_ups[0] = 0.1
	c.armament.reset_hop_ups()
	assert_almost_eq(c.armament.hop_ups[0], 0.8, 1e-9, "a new match starts at the loadout's dial")
	var bot := Character.new(1, 1, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	assert_almost_eq(bot.armament.bb_weights[0], 0.25, 1e-9, "bots load their factory weight")


func test_gear_not_on_offer_stays_picked_and_plays_as_the_default() -> void:
	var l := rules.default_loadout("L")
	_unplayable()
	l.equipped[Loadout.Slot.SECONDARY] = UNPLAYABLE
	assert_eq(rules.clean(l), [] as Array[String], "a real replica stays picked")
	assert_eq(l.equipped[1], UNPLAYABLE)
	var kit := rules.carried(l)
	assert_eq(kit.replicas.map(func(r: ReplicaConfig) -> StringName: return r.id), [&"aeg", &"pistol"])


func test_clean_puts_back_the_default_for_what_wont_do() -> void:
	var l := rules.default_loadout("L")
	l.equipped[0] = "999999"
	var t := rules.default_tune(rules.pool.item(AEG))
	t.bb_weight = 0.9
	t.hop_up = 0.333
	t.paint = &"pink"
	t.power_id = GREEN
	l.tunes[AEG] = t
	l.tunes["123456"] = ReplicaTune.new()
	var problems := rules.clean(l)
	assert_eq(problems.size(), 6, str(problems))
	assert_eq(l.equipped[0], AEG)
	var fixed := rules.tune_of(l, AEG)
	assert_almost_eq(fixed.bb_weight, 0.25, 1e-9)
	assert_almost_eq(fixed.hop_up, 0.65, 1e-9)
	assert_eq(fixed.paint, &"cobalt")
	assert_eq(fixed.power_id, STANDARD)
	assert_false(l.tunes.has("123456"))


func test_a_match_gives_the_player_the_kit_and_the_bots_their_replicas_as_they_come() -> void:
	var l := rules.default_loadout("L")
	rules.equip(l, Loadout.Slot.PRIMARY, PISTOL)
	rules.set_bb_weight(l, PISTOL, 0.25)
	var session := PlaySession.new()
	session.kit = rules.carried(l)
	add_child_autofree(session)
	await wait_physics_frames(2)
	var you := session.player.armament
	assert_eq(you.replicas[0].id, &"pistol")
	assert_almost_eq(you.bb_weights[0], 0.25, 1e-9)
	var bot := session.state.characters[1].armament
	assert_eq(bot.replicas[0].id, &"aeg")
	assert_almost_eq(bot.bb_weights[1], 0.2, 1e-9)
