extends GutTest
## The second audit pass on the bots (AUD2): a bot leads by the replica it holds, kits kept to a kind of field (the
## Clearer indoors), bushes priced on the nav grid, the string-pulling's routes unchanged, and the bots' lift rides,
## magazine asks and squeezes past Subway's wagons.

const DT := 1.0 / 60.0

var tuning: SimTuning = SimTuning.load_default()


# --- A bot leads by the replica it holds (KNOWN_ISSUES: bots lead by the default loadout's first replica) ---


## A bot holding `replicas` (the first in its hands), alone in a world of `tuning`.
func _holding(replicas: Array[ReplicaConfig]) -> Array:
	var me := Character.new(0, 0, Vector3.ZERO, 0.0, replicas)
	var w := BotWorld.new()
	w.tuning = tuning
	w.cfg = BotConfig.load_default()
	w.characters = [me]
	return [Bot.new(me, 1, w.cfg.skill_for(&"normal"), 1), w]


func test_a_bot_leads_by_the_bbs_of_the_replica_in_its_hands() -> void:
	var aeg := ReplicaStats.load_replica(&"aeg")
	var shotgun := ReplicaStats.load_replica(&"shotgun")
	var with_aeg := _holding([aeg] as Array[ReplicaConfig])
	var with_shotgun := _holding([shotgun, aeg] as Array[ReplicaConfig])
	var by_aeg := BotCombat.flight_time(with_aeg[0], with_aeg[1], 30.0)
	var by_shotgun := BotCombat.flight_time(with_shotgun[0], with_shotgun[1], 30.0)
	var grams := shotgun.bb_weight
	assert_almost_eq(by_shotgun, Ballistics.flight_time_estimate(30.0, Ballistics.muzzle_velocity(shotgun,
			tuning.replica_rules, grams), Ballistics.bb_mass(shotgun, grams), tuning.ballistics), 1e-6,
			"the shotgun's own BBs")
	assert_gt(by_shotgun, by_aeg * 1.05, "slower BBs: a longer lead than the AEG's")
	var b: Bot = with_shotgun[0]
	b.character.armament.active = 1
	assert_almost_eq(BotCombat.flight_time(b, with_shotgun[1], 30.0), by_aeg, 1e-6, "the AEG once it is in hand")


# --- Kits kept to a kind of field (KNOWN_ISSUES: the Clearer on Woodland) ---


func test_indoor_fields_are_the_still_air_ones() -> void:
	var catalog := MapCatalog.shared()
	assert_eq(BotKits.field_kind(catalog.find("depot")), BotKits.INDOOR)
	assert_eq(BotKits.field_kind(catalog.find("subway")), BotKits.INDOOR)
	assert_eq(BotKits.field_kind(catalog.find("woodland")), BotKits.OUTDOOR)
	assert_eq(BotKits.field_kind(catalog.find("stockade")), BotKits.OUTDOOR)
	assert_eq(BotKits.field_kind(null), &"", "a field the catalogue doesn't list: any kit")


func test_the_clearer_is_carried_indoors_only() -> void:
	var k := BotKits.read_file(Pool.read_file())
	assert_eq(k.problems, [] as Array[String])
	var rules := LoadoutRules.standard()
	rules.dev_content = true
	var indoors := 0
	for i in 400:
		var personality: StringName = [&"rusher", &"flanker"][i % 2]
		var outdoor := k.pick(&"hard", rules, Seeds.kit_seed(i, 3), personality, 3.0, BotKits.OUTDOOR)
		assert_ne(outdoor.kit_name, "Clearer", "seed %d: never on Woodland or Stockade" % i)
		var indoor := k.pick(&"hard", rules, Seeds.kit_seed(i, 3), personality, 3.0, BotKits.INDOOR)
		if indoor.kit_name == "Clearer":
			indoors += 1
		var any := k.pick(&"hard", rules, Seeds.kit_seed(i, 3), personality, 3.0)
		assert_eq(any.kit_name, indoor.kit_name, "seed %d: indoors every kit is offered, as with no field" % i)
	assert_gt(indoors, 10, "still carried indoors")
	for plan in k.kits:
		assert_eq(plan.fields, BotKits.INDOOR if plan.kit_name == "Clearer" else &"", plan.kit_name)


func test_a_fields_cell_it_cant_read_is_left_out_with_its_line() -> void:
	var pool := Pool.read_file()
	var header := "| Kit | Primary | Primary parts | Secondary | Secondary parts | Fields | Easy | Normal | Hard |\n" \
			+ "|---|---|---|---|---|---|---|---|---|\n"
	var k := BotKits.parse(header + "| A | AEG Rifle | | | | Indoor | 1 | 1 | 1 |\n"
			+ "| B | AEG Rifle | | | | roof | 1 | 1 | 1 |\n", pool)
	assert_eq(k.kits.size(), 1)
	assert_eq(k.kits[0].fields, BotKits.INDOOR, "any case")
	assert_eq(k.problems.size(), 1)
	assert_string_contains(k.problems[0], "Fields \"roof\"")
