extends GutTest
## QA hunt for LO1: saved-file edge cases, the kit and the bots' replicas.

const PATH := "user://test_lo1_qa.save"
const AEG := "000002"
const PISTOL := "000001"
const CYBER := "000019"
const LIPO := "000015"
const GREEN := "000004"

const POOL_TEXT := """### Replicas
| ID | Name | Key | Tags | Access |
|---|---|---|---|---|
| 000001 | GBB Pistol | pistol | pistol, gas | public |
| 000002 | AEG Rifle | aeg | rifle, electric | public |
| 000030 | Dev AEG | aeg | rifle, electric | dev |

### Power sources
| ID | Name | Type | Fits | Access |
|---|---|---|---|---|
| 000003 | Standard Battery | battery | electric | public |
| 000015 | LiPo | battery | electric | public |
| 000004 | Green Gas | gas | gas | public |
| 000031 | Dev Battery | battery | electric | dev |
"""

var rules: LoadoutRules


func before_each() -> void:
	SaveFile.remove(PATH)
	rules = LoadoutRules.new(Pool.read_file(), ReplicaStats.read_file(), ReplicaRulesConfig.new())


func after_each() -> void:
	SaveFile.remove(PATH)


func _saved() -> SavedLoadouts:
	return SavedLoadouts.new(rules)


func test_more_than_five_saved_loadouts_keep_five() -> void:
	var s := _saved()
	var list: Array = []
	for i in 8:
		list.append({"name": "L%d" % i})
	s.from_dict({"slots": list, "current": 7})
	assert_eq(s.slots.size(), 5)
	assert_eq(s.current, 4)


func test_odd_types_in_the_file_fall_back_without_error() -> void:
	var s := _saved()
	s.from_dict({"slots": [5, null, {"name": 7, "equipped": "x", "tunes": [1]},
			{"name": "A", "equipped": [1, null], "tunes": {AEG: {"bb_weight": "heavy", "hop_up": [], "paint": 4,
			"power": 9}}}], "current": "two"})
	assert_eq(s.slots.size(), 2)
	assert_eq(s.current, 0)
	for l in s.slots:
		assert_eq(l.equipped, PackedStringArray([AEG, PISTOL]))
	assert_eq(rules.tune_of(s.slots[1], AEG).bb_weight, 0.25)


func test_negative_current_clamps_to_first() -> void:
	var s := _saved()
	s.from_dict({"slots": [{"name": "A"}, {"name": "B"}], "current": -3})
	assert_eq(s.current, 0)


func test_duplicate_replica_in_both_slots_is_fixed_to_two_different() -> void:
	var s := _saved()
	s.from_dict({"slots": [{"name": "A", "equipped": [PISTOL, PISTOL]}]})
	assert_ne(s.carried().equipped[0], s.carried().equipped[1])
	var s2 := _saved()
	s2.from_dict({"slots": [{"name": "A", "equipped": [AEG, AEG]}]})
	assert_ne(s2.carried().equipped[0], s2.carried().equipped[1])


func test_overlong_and_blank_names_are_cleaned_on_load() -> void:
	var s := _saved()
	s.from_dict({"slots": [{"name": "x".repeat(50)}, {"name": "   "}]})
	assert_eq(s.slots[0].name.length(), 20)
	assert_eq(s.slots[1].name, "Loadout 1")


func test_unknown_fields_survive_a_save_and_load() -> void:
	var s := _saved()
	s.from_dict({"slots": [{"name": "A"}], "future": {"a": 1}})
	assert_true(s.save(PATH))
	var t := _saved()
	t.load_file(PATH)
	assert_eq(float((t.to_dict().get("future") as Dictionary).get("a")), 1.0)


func test_a_newer_file_is_refused_and_left_alone() -> void:
	SaveFile.write(PATH, "loadouts", SavedLoadouts.VERSION + 1, {"slots": [{"name": "Future"}]})
	var s := _saved()
	s.load_file(PATH)
	assert_ne(s.load_message, "")
	assert_eq(s.carried().name, "Loadout 1")
	assert_true(FileAccess.file_exists(PATH))


func test_a_corrupt_file_falls_back_with_a_message() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	var s := _saved()
	s.load_file(PATH)
	assert_ne(s.load_message, "")
	assert_eq(s.slots.size(), 1)
	SaveFile.remove(PATH)


func test_removing_the_carried_loadout_carries_the_next_one() -> void:
	var s := _saved()
	s.create()
	s.create()
	s.use(1)
	s.remove(1)
	assert_eq(s.carried().name, "Loadout 3", "the next one, as the browser game")
	s.remove(1)
	assert_eq(s.carried().name, "Loadout 1", "the one before it when it was last")


func test_removing_the_only_loadout_is_refused() -> void:
	var s := _saved()
	assert_false(s.remove(0))
	assert_eq(s.slots.size(), 1)


func test_sixth_loadout_is_refused() -> void:
	var s := _saved()
	for i in 4:
		s.create()
	assert_eq(s.create(), -1)
	assert_eq(s.duplicate_slot(0), -1)
	assert_eq(s.slots.size(), 5)


func test_equip_swaps_when_the_other_slot_holds_it() -> void:
	var l := rules.default_loadout("x")
	assert_true(rules.equip(l, Loadout.Slot.PRIMARY, PISTOL))
	assert_eq(l.equipped, PackedStringArray([PISTOL, AEG]))
	var later := Pool.Item.new()
	later.id = "000099"
	later.key = &"spring"
	rules.pool.replicas.append(later)
	assert_false(rules.equip(l, Loadout.Slot.PRIMARY, later.id), "not offered: no built-in config")


func test_bb_weight_and_dial_snap_and_clamp() -> void:
	var l := rules.default_loadout("x")
	assert_eq(rules.set_bb_weight(l, AEG, 5.0), 0.4)
	assert_eq(rules.set_bb_weight(l, AEG, -1.0), 0.2)
	assert_almost_eq(rules.set_bb_weight(l, AEG, 0.234), 0.23, 0.0001)
	assert_eq(rules.set_bb_weight(l, AEG, INF), 0.4)
	assert_eq(rules.set_hop_up(l, AEG, 9.0), 1.0)
	assert_almost_eq(rules.set_hop_up(l, AEG, 0.33), 0.35, 0.0001)


func test_a_power_source_that_does_not_fit_is_refused_and_a_saved_one_is_replaced() -> void:
	var l := rules.default_loadout("x")
	assert_false(rules.set_power(l, AEG, GREEN))
	var s := _saved()
	s.from_dict({"slots": [{"name": "A", "tunes": {AEG: {"power": GREEN}}}]})
	assert_eq(rules.tune_of(s.carried(), AEG).power_id, "000003")


func test_the_cyber_pistol_has_no_power_and_keeps_its_colour() -> void:
	var l := rules.default_loadout("x")
	assert_false(rules.set_power(l, CYBER, LIPO))
	assert_false(rules.set_paint(l, CYBER, &"cobalt"))


func test_site_limit_caps_energy_and_says_so() -> void:
	var l := rules.default_loadout("x")
	rules.stats.powers[LIPO] = ReplicaStats.Power.new()
	rules.stats.powers[LIPO].energy = 5.0
	rules.set_power(l, AEG, LIPO)
	var kit := rules.carried(l)
	assert_true(kit.capped[0])
	assert_almost_eq(kit.replicas[0].muzzle_energy, rules.stats.energy_limit(kit.replicas[0].site_class), 0.0001)


func test_the_kit_does_not_change_the_shared_built_in_config() -> void:
	var l := rules.default_loadout("x")
	var before := rules.config(rules.pool.item(AEG)).muzzle_energy
	rules.stats.powers[LIPO] = ReplicaStats.Power.new()
	rules.stats.powers[LIPO].energy = 0.1
	rules.stats.powers[LIPO].fire_rate = 0.2
	rules.set_power(l, AEG, LIPO)
	rules.carried(l)
	rules.carried(l)
	assert_eq(rules.config(rules.pool.item(AEG)).muzzle_energy, before)


func test_dev_replica_with_dev_content_off_plays_as_the_default() -> void:
	var r := LoadoutRules.new(Pool.parse(POOL_TEXT), ReplicaStats.read_file(), ReplicaRulesConfig.new())
	var l := r.default_loadout("x")
	l.equipped[0] = "000030"
	var kit := r.carried(l)
	assert_eq(kit.size(), 2)
	assert_false(kit.dev)
	r.dev_content = true
	kit = r.carried(l)
	assert_true(kit.dev)
	assert_eq(kit.size(), 2)


func test_dev_power_source_with_dev_content_off_does_not_apply() -> void:
	var r := LoadoutRules.new(Pool.parse(POOL_TEXT), ReplicaStats.read_file(), ReplicaRulesConfig.new())
	var p := ReplicaStats.Power.new()
	p.fire_rate = 0.5
	r.stats.powers["000031"] = p
	r.dev_content = true
	var l := r.default_loadout("x")
	assert_true(r.set_power(l, "000002", "000031"))
	r.dev_content = false
	var kit := r.carried(l)
	var base := r.config(r.pool.item("000002")).fire_rate
	assert_almost_eq(kit.replicas[0].fire_rate, base, 0.0001, "a dev power source not on offer must not boost")


func test_weights_reach_the_player_but_bots_keep_factory_replicas() -> void:
	var kit := rules.carried(rules.default_loadout("x"))
	kit.bb_weights[0] = 0.3
	var player := Character.new(0, 0, Vector3.ZERO, 0.0, kit.replicas, kit.bb_weights)
	var bot := Character.new(1, 1, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	assert_eq(player.armament.bb_weights[0], 0.3)
	assert_eq(bot.armament.bb_weights[0], bot.armament.replicas[0].bb_weight)


func test_a_session_start_uses_the_given_kit_and_a_short_weight_list_falls_back() -> void:
	var a := Armament.create(ReplicaStats.default_loadout(), PackedFloat64Array([0.3]))
	assert_eq(a.bb_weights[0], 0.3)
	assert_eq(a.bb_weights[1], a.replicas[1].bb_weight)
