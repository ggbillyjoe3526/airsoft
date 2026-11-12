extends GutTest
## PH2 (the owner's 2026-11-12 balance change: the GBB Pistol 0.70 J and the Compact SMG 0.85 J), judged on
## data/stats.md as shipped through LoadoutRules and Ballistics.hop_up_reach.

const DT := 1.0 / 60.0
const BAND := 0.15
const RANGE := 80.0
const PISTOL := "000001"
const AEG := "000002"
const SMG := "000026"
const CYBER := "000019"
const SNIPER := "000021"
const PATH := "user://test_ph2_qa.save"
const PATH_B := "user://test_ph2_qa_b.save"
const GREEN := "000004"
const RED_GAS := "000008"
const BLACK_GAS := "000009"
## The fields' air (°C): the four the maps use.
const AIRS: Array[float] = [20.0, 16.0, 14.0, 8.0]

var tuning: SimTuning = SimTuning.new()
var rules: LoadoutRules


func before_each() -> void:
	rules = LoadoutRules.new(Pool.read_file(), ReplicaStats.read_file(), ReplicaRulesConfig.new())
	rules.dev_content = true


func _kit(id: String, power: String = "", parts: Dictionary = {}) -> Kit:
	var l := rules.default_loadout("T")
	assert_true(rules.equip(l, Loadout.Slot.PRIMARY, id), "equip %s" % id)
	for slot: StringName in parts:
		assert_true(rules.set_part(l, id, slot, parts[slot]))
	if power != "":
		assert_true(rules.set_power(l, id, power))
	return rules.carried(l)


## How far `r` stays on target at `dial` (of its max) in air at `temperature` °C (a gas replica given that day's energy).
func _reach(kit: Kit, temperature: float, dial: float = -1.0) -> float:
	kit.set_temperature(tuning.weather, temperature, tuning.ballistics.air_temperature)
	var r := kit.replicas[0]
	var air := AirModel.at(tuning.ballistics, temperature)
	return Ballistics.hop_up_reach(r, r.hop_up_dial if dial < 0.0 else dial, tuning, DT, BAND, RANGE, -1.0, air).on_target_to


func _best(r: ReplicaConfig) -> float:
	var best := 0.0
	var d := 0.0
	while d <= 1.0 + 1e-9:
		best = maxf(best, Ballistics.hop_up_reach(r, d, tuning, DT, BAND, RANGE).on_target_to)
		d += rules.rules.hop_up_dial_step
	return best


func test_the_pistol_and_smg_come_with_the_new_energies_and_dials() -> void:
	assert_almost_eq(_kit(PISTOL).replicas[0].muzzle_energy, 0.7, 1e-6)
	assert_almost_eq(_kit(SMG).replicas[0].muzzle_energy, 0.85, 1e-6)
	assert_almost_eq(_kit(PISTOL).replicas[0].hop_up_dial, 0.75, 1e-6)
	assert_almost_eq(_kit(PISTOL).replicas[0].hop_up_max, 0.19, 1e-6)
	assert_almost_eq(_kit(SMG).replicas[0].hop_up_dial, 0.95, 1e-6)
	assert_almost_eq(_kit(SMG).replicas[0].hop_up_max, 0.135, 1e-6)


func test_the_pistols_reach_as_it_comes_rises_with_each_stronger_gas_on_every_fields_air() -> void:
	for temp in AIRS:
		var green := _reach(_kit(PISTOL, GREEN), temp)
		var red := _reach(_kit(PISTOL, RED_GAS), temp)
		var black := _reach(_kit(PISTOL, BLACK_GAS), temp)
		assert_gt(red, green, "Red Gas beyond Green Gas at %s C (%.1f, %.1f)" % [temp, red, green])
		assert_gt(black, red, "Black Gas beyond Red Gas at %s C (%.1f, %.1f)" % [temp, black, red])
		assert_gt(green, 15.0, "Green Gas is no short-ranger at %s C (%.1f m)" % [temp, green])


func test_one_notch_either_side_of_the_factory_dial_the_pistol_on_green_gas_does_not_collapse() -> void:
	var step := rules.rules.hop_up_dial_step
	var factory := _reach(_kit(PISTOL, GREEN), 20.0)
	for dial: float in [0.75 - step, 0.75 + step]:
		var m := _reach(_kit(PISTOL, GREEN), 20.0, dial)
		assert_gt(m, factory * 0.6, "dial %.2f: %.1f m against %.1f m at the factory dial" % [dial, m, factory])


func test_no_gas_or_part_puts_the_pistol_over_its_limit_or_the_smg_over_its() -> void:
	for id: String in [PISTOL, SMG]:
		var it := rules.pool.item(id)
		var limit := rules.stats.energy_limit(rules.config(it).site_class)
		var powers: Array[String] = [""]
		for p: Pool.Item in rules.pool.powers_for(it, true):
			powers.append(p.id)
		for power in powers:
			var kit := _kit(id, power)
			assert_lte(kit.replicas[0].muzzle_energy, limit + 1e-9, "%s on %s" % [power, it.display_name])
			for slot: StringName in Pool.PART_TABLES.values():
				for part: Pool.Item in rules.pool.parts_for(it, slot, true):
					var k := _kit(id, power, {slot: part.id})
					assert_lte(k.replicas[0].muzzle_energy, limit + 1e-9, "%s + %s on %s" % [power, part.display_name, it.display_name])
	assert_lte(rules.stats.energy_limit(&"pistol"), 1.0 + 1e-9)
	assert_lt(_kit(SMG).replicas[0].muzzle_energy, 1.2)


func test_the_smgs_best_reach_stays_six_metres_short_of_the_aeg_rifles() -> void:
	var smg := _kit(SMG).replicas[0]
	var aeg := _kit(AEG).replicas[0]
	var smg_best := _best(smg)
	var aeg_as_it_comes := Ballistics.hop_up_reach(aeg, aeg.hop_up_dial, tuning, DT, BAND, RANGE).on_target_to
	assert_lte(smg_best, aeg_as_it_comes - 6.0, "SMG best %.1f m, AEG as it comes %.1f m" % [smg_best, aeg_as_it_comes])
	assert_gt(smg_best, 25.0, "and the SMG is still a rifle-class reach")


func test_the_smgs_factory_dial_is_on_a_notch_and_within_the_dial() -> void:
	var dial := _kit(SMG).replicas[0].hop_up_dial
	assert_almost_eq(dial, rules.snap_hop_up(dial), 1e-9, "on a notch")
	assert_lte(dial, rules.rules.hop_up_max_dial)
	var pistol := _kit(PISTOL).replicas[0].hop_up_dial
	assert_almost_eq(pistol, rules.snap_hop_up(pistol), 1e-9)


func test_the_bots_kits_with_the_pistol_or_smg_carry_the_new_figures() -> void:
	var kits := BotKits.read_file(Pool.read_file())
	assert_eq(kits.problems.size(), 0, str(kits.problems))
	var seen := 0
	for plan in kits.kits:
		var built := _plan_kit(plan)
		for i in plan.slots.size():
			var id := plan.slots[i].replica
			if id == SMG:
				assert_almost_eq(built.replicas[i].muzzle_energy, 0.85, 1e-6, plan.kit_name)
				seen += 1
			elif id == PISTOL and plan.slots[i].parts.is_empty():
				assert_almost_eq(built.replicas[i].muzzle_energy, 0.7, 1e-6, plan.kit_name)
				seen += 1
	assert_gt(seen, 0, "some kit carries the pistol or the SMG")


## A plan's kit built as the player's loadout is.
func _plan_kit(plan: BotKits.Plan) -> Kit:
	var l := rules.default_loadout("Bot")
	for i in plan.slots.size():
		var slot := Loadout.Slot.PRIMARY if i == 0 else Loadout.Slot.SECONDARY
		assert_true(rules.equip(l, slot, plan.slots[i].replica))
	return rules.carried(l)


func test_nothing_under_game_hard_codes_the_old_energies() -> void:
	# Looking for the old energies as muzzle figures: stats.md and the built-ins are the only homes of a replica's energy.
	for path: String in ["res://game/config/replicas/pistol.tres", "res://game/config/replicas/smg.tres"]:
		var r := load(path) as ReplicaConfig
		assert_not_null(r, path)
		assert_true(is_equal_approx(r.muzzle_energy, 0.7) or is_equal_approx(r.muzzle_energy, 0.85), path)
	var stats := ReplicaStats.read_file()
	assert_eq(stats.problems.size(), 0)
	assert_almost_eq(load("res://game/config/replicas/pistol.tres").muzzle_energy as float, rules.config(rules.pool.item(PISTOL)).muzzle_energy, 1e-9, "the built-in matches stats.md")
	assert_almost_eq(load("res://game/config/replicas/smg.tres").muzzle_energy as float, rules.config(rules.pool.item(SMG)).muzzle_energy, 1e-9)


# --- The cap: no tuning of the pistol or the SMG reaches past the replicas above them ---

func _weights() -> Array[float]:
	var out: Array[float] = []
	var step := rules.rules.bb_weight_step
	var n := int(roundf((rules.rules.bb_weight_max - rules.rules.bb_weight_min) / step))
	for i in n + 1:
		out.append(snappedf(rules.rules.bb_weight_min + i * step, step))
	return out


## The furthest `id` on `power` (default "") stays on target over every dial notch and BB weight, at the rated air and gas energy (the most a day gives).
func _best_tuned(id: String, power: String = "") -> float:
	var best := 0.0
	var step := rules.rules.hop_up_dial_step
	var notches := int(roundf(1.0 / step))
	for g in _weights():
		var l := rules.default_loadout("T")
		assert_true(rules.equip(l, Loadout.Slot.PRIMARY, id))
		if power != "":
			assert_true(rules.set_power(l, id, power))
		rules.set_bb_weight(l, id, g)
		var kit := rules.carried(l)
		var r := kit.replicas[0]
		for i in range(1, notches + 1):
			best = maxf(best, Ballistics.hop_up_reach(r, minf(i * step, 1.0), tuning, DT, BAND, RANGE, g).on_target_to)
	return best


func test_the_pistol_tuned_on_any_gas_and_bb_weight_stays_under_the_cyber_pistols_best() -> void:
	var cyber := _best_tuned(CYBER)
	for gas: String in [GREEN, RED_GAS, BLACK_GAS]:
		var pistol := _best_tuned(PISTOL, gas)
		gut.p("pistol best on %s: %.1f m; Cyber Pistol best %.1f m" % [gas, pistol, cyber])
		assert_lt(pistol, cyber, "tuned pistol on %s (%.1f m) against the Cyber Pistol (%.1f m)" % [gas, pistol, cyber])


func test_the_pistol_as_it_comes_on_every_gas_stays_under_the_cyber_pistol_as_it_comes() -> void:
	var cyber := _reach(_kit(CYBER), 20.0)
	for gas: String in [GREEN, RED_GAS, BLACK_GAS]:
		var m := _reach(_kit(PISTOL, gas), 20.0)
		assert_lt(m, cyber, "%s: %.1f m against %.1f m" % [gas, m, cyber])


func test_the_smgs_best_over_every_dial_and_bb_weight_stays_six_metres_under_the_aeg_as_it_comes() -> void:
	var aeg := _reach(_kit(AEG), 20.0)
	var smg := _best_tuned(SMG)
	assert_lte(smg, aeg - 6.0, "SMG tuned %.1f m, AEG as it comes %.1f m" % [smg, aeg])


# --- Saved dials from before PH2 ---

func _saved() -> SavedLoadouts:
	return SavedLoadouts.new(LoadoutRules.new(Pool.read_file(), ReplicaStats.read_file(), ReplicaRulesConfig.new()))


func after_each() -> void:
	SaveFile.remove(PATH)
	SaveFile.remove(PATH_B)


func _slot(tunes: Dictionary) -> Dictionary:
	return {"name": "Old", "equipped": [AEG, PISTOL], "tunes": tunes}


func _hop_of(s: SavedLoadouts, id: String, slot: int = 0) -> float:
	return s.rules.tune_of(s.slots[slot], id).hop_up


func _v1(tunes: Dictionary) -> Dictionary:
	return {"slots": [_slot(tunes)], "current": 0}


func test_a_version_1_file_loads_the_pistol_and_smg_dials_scaled_to_lift_as_before() -> void:
	assert_true(SaveFile.write(PATH, SavedLoadouts.KIND, 1, _v1({PISTOL: {"hop_up": 0.55}, SMG: {"hop_up": 0.85}})))
	var s := _saved()
	s.load_file(PATH)
	assert_almost_eq(_hop_of(s, PISTOL), 0.85, 1e-9)
	assert_almost_eq(_hop_of(s, SMG), 0.95, 1e-9)
	var step := s.rules.rules.hop_up_dial_step
	assert_almost_eq(_hop_of(s, PISTOL) * 0.19, 0.3 * 0.55, step * 0.19, "the same lift within a notch")
	assert_almost_eq(_hop_of(s, SMG) * 0.135, 0.15 * 0.85, step * 0.135)


func test_a_scaled_dial_past_the_top_clamps_to_full() -> void:
	SaveFile.write(PATH, SavedLoadouts.KIND, 1, _v1({PISTOL: {"hop_up": 0.9}, SMG: {"hop_up": 1.0}}))
	var s := _saved()
	s.load_file(PATH)
	assert_almost_eq(_hop_of(s, PISTOL), 1.0, 1e-9)
	assert_almost_eq(_hop_of(s, SMG), 1.0, 1e-9)


func test_a_version_1_file_leaves_other_replicas_dials_alone() -> void:
	SaveFile.write(PATH, SavedLoadouts.KIND, 1, _v1({AEG: {"hop_up": 0.55}, CYBER: {"hop_up": 0.35}, SNIPER: {"hop_up": 0.65}}))
	var s := _saved()
	s.load_file(PATH)
	assert_almost_eq(_hop_of(s, AEG), 0.55, 1e-9)
	assert_almost_eq(_hop_of(s, CYBER), 0.35, 1e-9)
	assert_almost_eq(_hop_of(s, SNIPER), 0.65, 1e-9)


func test_odd_entries_in_a_version_1_file_load_as_they_did_before() -> void:
	var data := {"slots": [_slot({PISTOL: {"bb_weight": 0.3}, SMG: {"hop_up": "high"}, AEG: 5}), "junk", 7,
			{"name": "NoTunes"}, {"name": "BadTunes", "tunes": [1]}], "current": 0}
	SaveFile.write(PATH, SavedLoadouts.KIND, 1, data)
	var s := _saved()
	s.load_file(PATH)
	assert_eq(s.load_message, "")
	assert_gt(s.slots.size(), 0)
	var d := _saved()
	d.from_dict(data)
	assert_eq(s.to_dict(), d.to_dict(), "as from_dict alone reads it")
	var no_slots := _saved()
	SaveFile.write(PATH_B, SavedLoadouts.KIND, 1, {"current": 0})
	no_slots.load_file(PATH_B)
	assert_eq(no_slots.slots.size(), 1)
	assert_eq(no_slots.load_message, "")


func test_a_nan_dial_is_left_for_from_dict_and_the_input_is_not_mutated() -> void:
	var s := _saved()
	var data := _v1({PISTOL: {"hop_up": NAN}, SMG: {"hop_up": 0.85}})
	var out := s._hop_ups_from_v1(data)
	assert_true(is_nan(((out["slots"][0]["tunes"] as Dictionary)[PISTOL] as Dictionary)["hop_up"] as float))
	assert_almost_eq(float(data["slots"][0]["tunes"][SMG]["hop_up"]), 0.85, 1e-12, "the caller's data is as it was")
	assert_almost_eq(float(out["slots"][0]["tunes"][SMG]["hop_up"]), 0.95, 1e-9)


func test_an_old_file_is_rewritten_as_version_2_and_not_scaled_again() -> void:
	SaveFile.write(PATH, SavedLoadouts.KIND, 1, _v1({PISTOL: {"hop_up": 0.55}, SMG: {"hop_up": 0.85}}))
	var s := _saved()
	s.load_file(PATH)
	assert_true(s.dirty, "to be saved as this version")
	s.save_if_dirty(PATH)
	assert_false(s.dirty)
	assert_eq(int(SaveFile.read(PATH, SavedLoadouts.KIND).version), 2)
	var t := _saved()
	t.load_file(PATH)
	assert_false(t.dirty)
	assert_almost_eq(_hop_of(t, PISTOL), 0.85, 1e-9, "not scaled twice")
	assert_almost_eq(_hop_of(t, SMG), 0.95, 1e-9)


func test_a_version_2_file_is_read_as_is() -> void:
	var s := _saved()
	assert_true(s.rules.equip(s.carried(), Loadout.Slot.SECONDARY, PISTOL))
	s.rules.set_hop_up(s.carried(), PISTOL, 0.55)
	s.rules.set_hop_up(s.carried(), AEG, 0.4)
	assert_true(s.save(PATH))
	assert_eq(int(SaveFile.read(PATH, SavedLoadouts.KIND).version), SavedLoadouts.VERSION)
	var t := _saved()
	t.load_file(PATH)
	assert_almost_eq(_hop_of(t, PISTOL), 0.55, 1e-9)
	assert_false(t.dirty)


func test_a_version_3_file_is_still_refused_and_left_alone() -> void:
	SaveFile.write(PATH, SavedLoadouts.KIND, 3, _v1({PISTOL: {"hop_up": 0.55}}))
	var s := _saved()
	s.load_file(PATH)
	assert_ne(s.load_message, "")
	assert_almost_eq(_hop_of(s, PISTOL), s.rules.tune_of(_saved().carried(), PISTOL).hop_up, 1e-9, "the default")
	assert_false(s.save(PATH), "never written over")
	assert_eq(int(SaveFile.read(PATH, SavedLoadouts.KIND).version), 3)


func test_importing_a_bundle_with_a_version_1_loadouts_store_ends_with_converted_dials_once() -> void:
	var data := _v1({PISTOL: {"hop_up": 0.55}, SMG: {"hop_up": 0.85}})
	var b := SaveBundle.from_dict({"version": Version.current(), "saved_at": 1, "stores": {
			SavedLoadouts.KIND: {"version": 1, "data": data}}})
	var paths: Array[String] = [PATH_B + "_p", PATH_B, PATH_B + "_q", PATH_B + "_r"]
	for p in paths:
		SaveFile.remove(p)
	assert_true(b.write(paths))
	var s := _saved()
	s.load_file(PATH_B)
	assert_almost_eq(_hop_of(s, PISTOL), 0.85, 1e-9)
	assert_almost_eq(_hop_of(s, SMG), 0.95, 1e-9)
	s.save_if_dirty(PATH_B)
	var t := _saved()
	t.load_file(PATH_B)
	assert_almost_eq(_hop_of(t, PISTOL), 0.85, 1e-9, "a second load does not scale again")
	for p in paths:
		SaveFile.remove(p)
