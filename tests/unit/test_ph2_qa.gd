extends GutTest
## PH2 (the owner's 2026-11-12 balance change: the GBB Pistol 0.70 J and the Compact SMG 0.85 J), judged on
## data/stats.md as shipped through LoadoutRules and Ballistics.hop_up_reach.

const DT := 1.0 / 60.0
const BAND := 0.15
const RANGE := 80.0
const PISTOL := "000001"
const AEG := "000002"
const SMG := "000026"
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
	assert_almost_eq(_kit(PISTOL).replicas[0].hop_up_dial, 0.5, 1e-6)
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
	for dial: float in [0.5 - step, 0.5 + step]:
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


func test_a_loadout_saved_before_the_change_still_loads_and_plays() -> void:
	var l := rules.default_loadout("Old")
	assert_true(rules.equip(l, Loadout.Slot.PRIMARY, SMG))
	assert_true(rules.equip(l, Loadout.Slot.SECONDARY, PISTOL))
	rules.set_hop_up(l, SMG, 0.85)
	rules.set_hop_up(l, PISTOL, 0.55)
	assert_eq(rules.clean(l).size(), 0, "nothing is dropped or reset")
	var kit := rules.carried(l)
	assert_almost_eq(kit.replicas[0].hop_up_dial, 0.85, 1e-9)
	assert_almost_eq(kit.replicas[1].hop_up_dial, 0.55, 1e-9)
	var smg := Ballistics.hop_up_reach(kit.replicas[0], 0.85, tuning, DT, BAND, RANGE)
	var pistol := Ballistics.hop_up_reach(kit.replicas[1], 0.55, tuning, DT, BAND, RANGE)
	gut.p("saved SMG 0.85 dial: %.1f m (peak rise %.2f m); saved pistol 0.55 dial on Green: %.1f m" % [
			smg.on_target_to, smg.peak_rise, pistol.on_target_to])
	assert_gt(smg.on_target_to, 15.0, "the SMG's old dial is not far short")
	assert_gt(pistol.on_target_to, 15.0, "the pistol's old dial is not far short")
	# Black Gas at the old 0.55 dial.
	assert_true(rules.set_power(l, PISTOL, BLACK_GAS))
	var black := rules.carried(l).replicas[1]
	var blk := Ballistics.hop_up_reach(black, 0.55, tuning, DT, BAND, RANGE)
	gut.p("saved pistol 0.55 dial on Black Gas: %.1f m (peak rise %.2f m)" % [blk.on_target_to, blk.peak_rise])
	assert_gt(blk.on_target_to, 15.0, "Black Gas at the old dial is not short")


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
