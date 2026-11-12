extends GutTest
## RP1 (the owner's 2026-11-12 balance pass: "each weapon has its own strengths and weaknesses", "attachments should
## offer incentives to use while also feeling unique from each other"): no replica beats another at everything, every
## part gives something and costs something, the Red Laser tightens only shots from the hip, the Vertical Grip steadies
## the move, and the part cards say so. Judged on data/stats.md as shipped, through LoadoutRules.

const DT := 1.0 / 60.0
const LOADOUTS := "user://test_rp1_loadouts.save"
const PISTOL := "000001"
const AEG := "000002"
const CYBER := "000019"
const SNIPER := "000021"
const SMG := "000026"
const REPLICAS: Array[String] = [PISTOL, AEG, CYBER, SNIPER, SMG]
const LASER := "000005"
const VERTICAL := "000006"
const RED_DOT := "000007"
const ANGLED := "000011"
const SILENCER := "000018"
## The springs, softest first.
const SPRINGS: Array[String] = ["000022", "000023", "000024"]
## The power sources a replica comes with: the lines the others are judged against.
const STANDARD_POWER: Array[String] = ["000003", "000004", "000022"]
## Hop-up readout band and range (HudConfig's), for a replica's reach.
const BAND := 0.15
const RANGE := 80.0

var tuning: SimTuning = SimTuning.new()
var rules: LoadoutRules


func before_each() -> void:
	rules = LoadoutRules.new(Pool.read_file(), ReplicaStats.read_file(), ReplicaRulesConfig.new())
	rules.dev_content = true


func after_all() -> void:
	SaveFile.remove(LOADOUTS)


## Replica `id` as carried with `parts` (slot → part ID) and power source `power` ("" as it comes).
func _carried(id: String, parts: Dictionary = {}, power: String = "") -> ReplicaConfig:
	var l := rules.default_loadout("T")
	assert_true(rules.equip(l, Loadout.Slot.PRIMARY, id), "equip %s" % id)
	for slot: StringName in parts:
		assert_true(rules.set_part(l, id, slot, parts[slot]), "%s on %s" % [parts[slot], id])
	if power != "":
		assert_true(rules.set_power(l, id, power), "%s on %s" % [power, id])
	return rules.carried(l).replicas[0]


## How wide `r` shoots running flat out from the hip (degrees): its spread, the run's and its own hip spread.
func _run_hip(r: ReplicaConfig) -> float:
	return r.spread_deg * r.hip_spread * (1.0 + (tuning.accuracy.run - 1.0) * r.move_spread)


## What a replica is judged on, each so that higher is better.
func _scores(r: ReplicaConfig) -> Dictionary[String, float]:
	return {
		"reach": Ballistics.hop_up_reach(r, r.hop_up_dial, tuning, DT, BAND, RANGE).on_target_to,
		"fire rate": r.fire_rate,
		"BBs carried": float(r.mag_size * r.mags),
		"draw": -r.draw_time,
		"reload": -r.reload_time,
		"spread": -r.spread_deg,
		"spread on the run": -_run_hip(r),
		"pace": r.pace,
		"kick": -r.recoil_deg,
	}


## What a part or power source changes, each so that higher is better.
func _part_scores(r: ReplicaConfig) -> Dictionary[String, float]:
	return {
		"energy": r.muzzle_energy,
		"fire rate": r.fire_rate,
		"magazine": float(r.mag_size),
		"magazines": float(r.mags),
		"reload": -r.reload_time,
		"draw": -r.draw_time,
		"raise": -r.raise_scale,
		"zoom": maxf(r.aim_zoom, r.aim_zoom_to),
		"spread": -r.spread_deg,
		"hip spread": -r.hip_spread,
		"moving spread": -r.move_spread,
		"shake": -r.shake_scale,
		"kick": -r.recoil_deg,
		"heard": -r.heard_scale,
		"rattle": -float(r.rattles),
	}


## The names of what `a` does better than `b`.
func _better(a: Dictionary[String, float], b: Dictionary[String, float]) -> PackedStringArray:
	var out := PackedStringArray()
	for k in a:
		if a[k] > b[k] + 1e-6:
			out.append(k)
	return out


# --- The data ---


func test_stats_md_reads_clean_with_the_new_columns() -> void:
	var stats := ReplicaStats.read_file()
	assert_eq(stats.problems.size(), 0, "stats.md reads clean: %s" % [stats.problems])
	var laser := stats.parts.part(&"laser", &"redLaser")
	assert_lt(laser.hip, 1.0, "the Red Laser's Hip spread column reads")
	assert_gt(laser.handling, 1.0, "and its Handling")
	assert_almost_eq(laser.spread, 1.0, 1e-6, "it no longer has a spread of its own")
	assert_lt(stats.parts.part(&"grip", &"vertical").move_spread, 1.0, "the Vertical Grip's Moving spread column reads")
	assert_almost_eq(stats.parts.part(&"grip", &"angled").move_spread, 1.0, 1e-6)


func test_a_grip_or_laser_table_without_its_new_column_changes_nothing_there_and_says_so() -> void:
	var text := "## Grips\n\n| Key | Name | Handling (×) | Shake (×) |\n|---|---|---|---|\n| vertical | V | 1.15 | 0.6 |\n\n" \
			+ "## Lasers\n\n| Key | Name | Spread (×) |\n|---|---|---|\n| redLaser | L | 0.8 |\n"
	var stats := ReplicaStats.parse(text)
	assert_almost_eq(stats.parts.part(&"grip", &"vertical").move_spread, 1.0, 1e-6)
	assert_almost_eq(stats.parts.part(&"laser", &"redLaser").hip, 1.0, 1e-6, "an old Spread column is not read as hip")
	assert_almost_eq(stats.parts.part(&"laser", &"redLaser").spread, 1.0, 1e-6)
	var said := "\n".join(stats.problems)
	assert_string_contains(said, "Moving spread (×)")
	assert_string_contains(said, "Hip spread (×)")


func test_an_out_of_range_new_cell_changes_nothing_and_is_listed() -> void:
	var text := "## Grips\n\n| Key | Name | Handling (×) | Shake (×) | Moving spread (×) |\n|---|---|---|---|---|\n" \
			+ "| vertical | V | 1.15 | 0.6 | 9 |\n\n## Lasers\n\n| Key | Name | Hip spread (×) | Handling (×) |\n" \
			+ "|---|---|---|---|\n| redLaser | L | none | 1.05 |\n"
	var stats := ReplicaStats.parse(text)
	assert_almost_eq(stats.parts.part(&"grip", &"vertical").move_spread, 1.0, 1e-6)
	assert_almost_eq(stats.parts.part(&"laser", &"redLaser").hip, 1.0, 1e-6)
	assert_almost_eq(stats.parts.part(&"laser", &"redLaser").handling, 1.05, 1e-6, "the readable cell still counts")
	var said := "\n".join(stats.parts.problems)
	assert_eq(stats.parts.problems.size(), 2, said)
	assert_string_contains(said, "stats.md:5: Moving spread (×)")
	assert_string_contains(said, "stats.md:11: Hip spread (×)")


# --- Replicas: each its own strengths and weaknesses ---


func test_no_replica_is_at_least_as_good_as_another_at_everything() -> void:
	var scores: Dictionary[String, Dictionary] = {}
	for id in REPLICAS:
		scores[id] = _scores(_carried(id))
	for a in REPLICAS:
		for b in REPLICAS:
			if a == b:
				continue
			var wins := _better(scores[b], scores[a])
			assert_gt(wins.size(), 0, "%s does something better than %s" % [rules.pool.item(b).display_name,
					rules.pool.item(a).display_name])


func test_each_replica_leads_at_its_own_job() -> void:
	var by: Dictionary[String, ReplicaConfig] = {}
	for id in REPLICAS:
		by[id] = _carried(id)
	for id in REPLICAS:
		if id != PISTOL:
			assert_lt(by[PISTOL].draw_time, by[id].draw_time, "the GBB Pistol is the quickest to hand")
		if id != SMG:
			assert_gt(by[SMG].fire_rate, by[id].fire_rate, "the Compact SMG fires fastest")
			assert_lt(_run_hip(by[SMG]), _run_hip(by[id]), "and is the tightest on the run")
			assert_gte(by[SMG].pace, by[id].pace, "and the quickest on its feet")
		if id != SNIPER:
			assert_lt(by[SNIPER].spread_deg, by[id].spread_deg, "the Sniper Rifle is the tightest")
			assert_gt(by[SNIPER].muzzle_energy, by[id].muzzle_energy, "and shoots hardest")
			assert_lt(by[SNIPER].pace, by[id].pace, "and is the slowest on its feet")
		if id != AEG:
			assert_gt(by[AEG].mag_size * by[AEG].mags, by[id].mag_size * by[id].mags, "the AEG Rifle carries the most BBs")


func test_the_cyber_pistol_keeps_its_design_and_pays_in_bbs_and_on_the_run() -> void:
	var cyber := _carried(CYBER)
	var aeg := _carried(AEG)
	var smg := _carried(SMG)
	# The owner's design (docs/DECISIONS.md): rifle power with pistol handling, the tightest spread, almost no kick.
	assert_gte(cyber.muzzle_energy, aeg.muzzle_energy, "rifle power")
	assert_lt(cyber.spread_deg, aeg.spread_deg, "the tightest automatic")
	assert_lt(cyber.spread_deg, smg.spread_deg)
	assert_lt(cyber.recoil_deg, smg.recoil_deg, "almost no kick")
	assert_lt(cyber.draw_time, aeg.draw_time, "pistol handling")
	# Its costs (RP1).
	assert_lt(cyber.mag_size * cyber.mags, smg.mag_size * smg.mags, "fewer BBs than any other automatic")
	assert_lt(cyber.mag_size * cyber.mags, aeg.mag_size * aeg.mags)
	assert_gt(_run_hip(cyber), _run_hip(aeg), "wider on the run than the AEG Rifle")
	assert_gt(_run_hip(cyber), _run_hip(smg) * 1.3, "and far wider than the Compact SMG, whose job that is")


func test_walking_or_standing_the_cyber_pistol_is_as_tight_as_its_spread() -> void:
	var cyber := _carried(CYBER)
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, [cyber] as Array[ReplicaConfig])
	c.grounded = true
	var move := tuning.movement
	var still := Accuracy.target_spread_scale(c, move, tuning.accuracy)
	c.velocity.x = move.walk_speed
	assert_almost_eq(Accuracy.target_spread_scale(c, move, tuning.accuracy), tuning.accuracy.walk, 1e-6,
			"a walk adds nothing to double")
	c.velocity.x = move.run_speed
	var running := Accuracy.target_spread_scale(c, move, tuning.accuracy)
	assert_almost_eq(running, 1.0 + (tuning.accuracy.run - 1.0) * cyber.move_spread, 1e-6, "the run's extra, doubled")
	assert_gt(running, still)


# --- Parts and power: every one a trade ---


func test_every_part_gives_something_and_costs_something() -> void:
	for id in REPLICAS:
		var it := rules.pool.item(id)
		var plain := _part_scores(_carried(id, {}, _standard_power(it)))
		for slot: StringName in Pool.PART_TABLES.values():
			# A torch is fitted only at night, and lights; it changes nothing the replica shoots or handles as.
			if slot == Pool.LIGHT_SLOT:
				continue
			for part: Pool.Item in rules.pool.parts_for(it, slot, true):
				# The replica as it comes may wear a part in the slot (the Sniper Rifle's 2x Scope): judge against bare.
				var bare := _part_scores(_bare(id, slot))
				var with := _part_scores(_carried(id, {slot: part.id}))
				var name := "%s on the %s" % [part.display_name, it.display_name]
				assert_gt(_better(with, bare).size(), 0, "%s gives something" % name)
				assert_gt(_better(bare, with).size(), 0, "%s costs something" % name)
		for power: Pool.Item in rules.pool.powers_for(it, true):
			if STANDARD_POWER.has(power.id):
				continue
			var with_power := _part_scores(_carried(id, {}, power.id))
			var label := "%s on the %s" % [power.display_name, it.display_name]
			assert_gt(_better(with_power, plain).size(), 0, "%s gives something" % label)
			assert_gt(_better(plain, with_power).size(), 0, "%s costs something" % label)


## The power source `it` comes with ("" for a built-in one).
func _standard_power(it: Pool.Item) -> String:
	for power: Pool.Item in rules.pool.powers_for(it, true):
		if STANDARD_POWER.has(power.id):
			return power.id
	return ""


## Replica `id` with nothing in `slot`.
func _bare(id: String, slot: StringName) -> ReplicaConfig:
	var l := rules.default_loadout("B")
	assert_true(rules.equip(l, Loadout.Slot.PRIMARY, id))
	rules.set_part(l, id, slot, "")
	return rules.carried(l).replicas[0]


func test_no_two_parts_of_a_slot_do_the_same_job() -> void:
	for slot: StringName in [&"grip", &"barrel", &"magazine", &"optic"]:
		var aeg := rules.pool.item(AEG)
		var parts := rules.pool.parts_for(aeg, slot, true)
		for a: Pool.Item in parts:
			for b: Pool.Item in parts:
				if a == b:
					continue
				var sa := _part_scores(_carried(AEG, {slot: a.id}))
				var sb := _part_scores(_carried(AEG, {slot: b.id}))
				assert_gt(_better(sa, sb).size(), 0, "%s does something the %s doesn't" % [a.display_name, b.display_name])


func test_every_optic_is_slower_to_bring_up_than_the_iron_sights() -> void:
	# No part is free (the critic, RP1): the Red Dot is the quickest sight to the eye and pays in the draw.
	var irons := _bare(AEG, &"optic")
	var dot := _carried(AEG, {&"optic": RED_DOT})
	assert_lt(dot.raise_scale, irons.raise_scale, "the quick sight")
	assert_gt(dot.draw_time, irons.draw_time, "weight on the rail")
	var optics := rules.stats.parts
	assert_almost_eq(dot.draw_time, irons.draw_time * optics.part(&"optic", &"redDot").draw, 1e-6)
	assert_gte(optics.part(&"optic", &"scope2x").draw, optics.part(&"optic", &"redDot").draw,
			"a scope is no lighter than a red dot")
	assert_gt(optics.part(&"optic", &"scopeVar").draw, optics.part(&"optic", &"scope2x").draw, "the long one the most")
	# It stacks with a magazine's draw and the handling of the rest.
	var both := _carried(AEG, {&"optic": RED_DOT, &"grip": VERTICAL})
	var grip := _carried(AEG, {&"grip": VERTICAL})
	assert_almost_eq(both.draw_time, grip.draw_time * optics.part(&"optic", &"redDot").draw, 1e-6)


func test_an_optics_table_without_the_draw_column_changes_no_draw_and_says_so() -> void:
	var text := "## Optics\n\n| Key | Name | Zoom (×) | Raise time (×) | In the glass | Zoom to (×) |\n" \
			+ "|---|---|---|---|---|---|\n| redDot | Red Dot | 1.25 | 0.85 | no | 1.25 |\n"
	var stats := ReplicaStats.parse(text)
	var dot := stats.parts.part(&"optic", &"redDot")
	assert_almost_eq(dot.draw, 1.0, 1e-6)
	assert_almost_eq(dot.raise, 0.85, 1e-6, "the rest still reads")
	assert_string_contains("\n".join(stats.problems), "Draw (×)")


func test_the_red_dot_card_shows_its_slower_draw() -> void:
	var cards := _options(Loadout.Slot.PRIMARY, AEG, &"optic")
	var none := cards[0]
	var dot := cards[1]
	assert_false(none.figures_plain.contains("draw"), "no draw piece on the iron sights: %s" % none.figures_plain)
	assert_string_contains(dot.figures_plain, "draw")
	assert_true(dot.better.has(tr("PART_BETTER_AIM")), "better: %s" % [dot.better])
	assert_true(dot.worse.has(tr("PART_WORSE_DRAW")), "worse: %s" % [dot.worse])


func test_the_red_laser_tightens_only_the_hip_and_costs_handling() -> void:
	for id: String in [AEG, PISTOL, SMG]:
		var plain := _carried(id)
		var lit := _carried(id, {&"laser": LASER})
		assert_almost_eq(lit.spread_deg, plain.spread_deg, 1e-6, "the spread itself stays")
		assert_lt(lit.hip_spread, plain.hip_spread, "tighter with the sight down")
		assert_gt(lit.draw_time, plain.draw_time, "a touch slower to bring up")
		assert_gt(lit.raise_scale, plain.raise_scale, "and to raise the sight")
		var c := Character.new(1, 0, Vector3.ZERO, 0.0, [plain] as Array[ReplicaConfig])
		var d := Character.new(2, 0, Vector3.ZERO, 0.0, [lit] as Array[ReplicaConfig])
		for who: Character in [c, d]:
			who.grounded = true
			who.aim_raise = 1.0
		assert_almost_eq(Accuracy.target_spread_scale(d, tuning.movement, tuning.accuracy),
				Accuracy.target_spread_scale(c, tuning.movement, tuning.accuracy), 1e-6, "aimed, the laser changes nothing")
		c.aim_raise = 0.0
		d.aim_raise = 0.0
		assert_lt(Accuracy.target_spread_scale(d, tuning.movement, tuning.accuracy),
				Accuracy.target_spread_scale(c, tuning.movement, tuning.accuracy), "from the hip it does")


func test_the_laser_and_the_grip_stack_on_the_replicas_own() -> void:
	var stats := rules.stats
	var smg := _carried(SMG)
	var lit := _carried(SMG, {&"laser": LASER})
	assert_almost_eq(lit.hip_spread, smg.hip_spread * stats.parts.part(&"laser", &"redLaser").hip, 1e-6,
			"on top of the Compact SMG's own hip spread")
	assert_almost_eq(lit.move_spread, smg.move_spread, 1e-6)
	var aeg := _carried(AEG)
	var gripped := _carried(AEG, {&"grip": VERTICAL})
	assert_almost_eq(gripped.move_spread, aeg.move_spread * stats.parts.part(&"grip", &"vertical").move_spread, 1e-6)
	assert_gt(_run_hip(gripped), _run_hip(smg), "a gripped AEG Rifle still isn't the Compact SMG on the run")
	assert_almost_eq(_carried(AEG, {&"grip": ANGLED}).move_spread, aeg.move_spread, 1e-6, "the Angled Grip leaves it")


func test_the_vertical_grip_is_control_and_the_angled_grip_is_speed() -> void:
	var aeg := _carried(AEG)
	var vertical := _carried(AEG, {&"grip": VERTICAL})
	var angled := _carried(AEG, {&"grip": ANGLED})
	assert_lt(vertical.move_spread, aeg.move_spread)
	assert_lt(vertical.shake_scale, aeg.shake_scale)
	assert_gt(vertical.draw_time, aeg.draw_time)
	assert_lt(angled.draw_time, aeg.draw_time)
	assert_lt(angled.raise_scale, aeg.raise_scale)
	assert_gt(angled.shake_scale, aeg.shake_scale)


func test_each_spring_is_its_own_trade() -> void:
	var by: Dictionary[String, ReplicaConfig] = {}
	for spring in SPRINGS:
		by[spring] = _carried(SNIPER, {}, spring)
	for a in SPRINGS:
		for b in SPRINGS:
			if a != b:
				assert_gt(_better(_part_scores(by[a]), _part_scores(by[b])).size(), 0,
						"the %s does something the %s doesn't" % [rules.pool.item(a).display_name,
						rules.pool.item(b).display_name])
	var soft := by[SPRINGS[0]]
	var middle := by[SPRINGS[1]]
	var hard := by[SPRINGS[2]]
	assert_lt(soft.heard_scale, middle.heard_scale, "the M130 is the quiet one")
	assert_gt(soft.fire_rate, middle.fire_rate, "and the quick one")
	assert_gt(hard.muzzle_energy, middle.muzzle_energy, "the M150 shoots hardest")
	assert_gt(hard.heard_scale, middle.heard_scale, "and is heard furthest")
	assert_gt(hard.recoil_deg, middle.recoil_deg)
	assert_lt(hard.fire_rate, middle.fire_rate)
	assert_false(soft.muffled, "quieter, not muffled: that is a silencer's")
	# The steps are uneven on purpose: the last 10 % of energy costs more kick than the first, and the crack on top.
	assert_gt(hard.recoil_deg - middle.recoil_deg, middle.recoil_deg - soft.recoil_deg)


func test_a_springs_loudness_stacks_with_a_silencers() -> void:
	var plain := _carried(SNIPER, {}, SPRINGS[2])
	var quiet := _carried(SNIPER, {&"muzzle": SILENCER}, SPRINGS[2])
	var silencer := rules.stats.parts.part(&"muzzle", &"silencer")
	assert_almost_eq(quiet.heard_scale, plain.heard_scale * silencer.heard, 1e-6)
	assert_true(quiet.muffled)
	assert_almost_eq(_carried(AEG).heard_scale, 1.0, 1e-6, "a battery changes nothing there")


func test_a_click_after_the_bolt_handle_looks_home_fires_on_every_spring() -> void:
	# The Fire clip shows the handle home 0.71 s into the M130's cycle and is stretched with the cycle (ReplicaView);
	# a press within bolt_press_window of the cycle's end is kept (BP3).
	var base := _carried(SNIPER, {}, SPRINGS[0])
	var home_share := 0.71 * base.fire_rate
	for spring in SPRINGS:
		var cycle := 1.0 / _carried(SNIPER, {}, spring).fire_rate
		assert_gte(cycle * home_share, cycle - tuning.replica_rules.bolt_press_window,
				"%s: the window is open by the time the handle is home (cycle %.2f s)" % [spring, cycle])


func test_a_power_table_without_the_heard_column_reads_as_before() -> void:
	var text := "## Power sources\n\n| ID | Name | Energy % | Fire rate % | Recoil % |\n|---|---|---|---|---|\n" \
			+ "| 000024 | M150 Spring | 20 | -10 | 20 |\n"
	var stats := ReplicaStats.parse(text)
	var said := "\n".join(stats.problems)
	assert_false(said.contains("Heard"), "an older table is no problem: %s" % said)
	assert_almost_eq(stats.power("000024").heard, 0.0, 1e-6)
	assert_almost_eq(stats.power("000024").energy, 0.2, 1e-6)
	var bad := ReplicaStats.parse(text.replace("Recoil % |", "Recoil % | Heard from % |").replace("|---|---|---|---|---|",
			"|---|---|---|---|---|---|").replace("| 20 |\n", "| 20 | loud |\n"))
	assert_almost_eq(bad.power("000024").heard, 0.0, 1e-6, "an unreadable cell counts as 0")
	assert_string_contains("\n".join(bad.problems), "Heard from %")


# --- The part cards ---


func _options(slot: Loadout.Slot, replica: String, part_slot: StringName) -> Array[PartOptions.Option]:
	SaveFile.remove(LOADOUTS)
	var std := LoadoutRules.standard()
	std.dev_content = true
	var saved := SavedLoadouts.new(std)
	assert_true(std.equip(saved.carried(), slot, replica))
	var facts := LoadoutFacts.new(saved)
	return PartOptions.new(facts).options(slot, part_slot)


func test_the_laser_card_shows_the_hip_spread_and_its_slower_aim() -> void:
	var cards := _options(Loadout.Slot.PRIMARY, AEG, &"laser")
	assert_eq(cards.size(), 2, "nothing, and the Red Laser")
	var none := cards[0]
	var laser := cards[1]
	assert_string_contains(none.figures_plain, "0.45 °", "as it comes: the AEG's hip spread")
	assert_false(none.figures_plain.contains("aim in"), "no aim piece until a part changes it")
	assert_string_contains(laser.figures_plain.to_lower(), "from the hip")
	assert_string_contains(laser.figures_plain, "aim in")
	assert_true(laser.better.has(tr("PART_BETTER_HIP")), "better: %s" % [laser.better])
	assert_true(laser.worse.has(tr("PART_WORSE_AIM")), "worse: %s" % [laser.worse])


func test_the_grip_cards_show_the_moving_spread_only_where_it_changes() -> void:
	var cards := _options(Loadout.Slot.PRIMARY, AEG, &"grip")
	var by: Dictionary[String, PartOptions.Option] = {}
	for o in cards:
		by[o.id()] = o
	assert_string_contains(by[VERTICAL].figures_plain, "moving\u00a080\u00a0%")
	assert_true(by[VERTICAL].better.has(tr("PART_BETTER_MOVE")))
	assert_true(by[VERTICAL].worse.has(tr("PART_WORSE_AIM")))
	assert_false(by[ANGLED].figures_plain.contains("moving"), "the Angled Grip leaves it")
	assert_false(by[""].figures_plain.contains("moving"))


func test_the_cyber_pistols_moving_double_cannot_be_bought_off_with_a_grip_or_laser() -> void:
	var l := rules.default_loadout("T")
	assert_true(rules.equip(l, Loadout.Slot.PRIMARY, CYBER))
	assert_false(rules.set_part(l, CYBER, &"grip", VERTICAL), "no under-rail")
	assert_false(rules.set_part(l, CYBER, &"laser", LASER), "no laser rail")
	assert_almost_eq(rules.carried(l).replicas[0].move_spread, 2.0, 1e-6, "its own double stays")
