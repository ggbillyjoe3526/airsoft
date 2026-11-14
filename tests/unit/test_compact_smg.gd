extends GutTest
## The Compact SMG (CS1; owner, 2026-11-10: "a compact electric smg" that feels and plays unlike the others; Dev
## content): a replica that plays by stats.md's `smg` row, the fastest trigger there is with a small magazine, semi and
## full auto, driven by the batteries, under the rifle site limit; 8 % quicker on your feet carried (ReplicaConfig.pace),
## half the spread moving adds (move_spread) and tighter from the hip (hip_spread 0.75); short on reach with its light
## BBs. It takes the optics, laser, silencer and torch, not the grips, barrels or AEG magazines; unlocks at level 10;
## the Breacher bot kit carries it; it is heard through its own stand-in sounds and drawn by its own model (the owner's
## reference pictures, 2026-11-10: tools/blender/replicas/smg.py), held in your arms' own SMG hold.

const DT := 1.0 / 60.0
const EYE := Vector3(0.0, 1.6, 0.0)
const AEG := "000002"
const SMG := "000026"
const RED_DOT := "000007"
const SCOPE := "000010"
const VERTICAL := "000006"
const RED_LASER := "000005"
const SILENCER := "000018"
const LONG_BARREL := "000017"
const HI_CAP := "000012"
const BATTERY := "000003"
const LIPO := "000015"

var rules: LoadoutRules


func before_each() -> void:
	rules = LoadoutRules.new(Pool.read_file(), ReplicaStats.read_file(), ReplicaRulesConfig.new())
	rules.dev_content = true


func _smg() -> ReplicaConfig:
	return rules.config(rules.pool.item(SMG))


func _aeg() -> ReplicaConfig:
	return rules.config(rules.pool.item(AEG))


## A character holding `r`, grounded, standing still.
func _holding(r: ReplicaConfig) -> Character:
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, [r] as Array[ReplicaConfig])
	c.grounded = true
	return c


func test_it_is_a_public_electric_rifle_in_the_pool() -> void:
	var it := rules.pool.item(SMG)
	assert_not_null(it)
	assert_eq(it.display_name, "Compact SMG")
	assert_eq(it.key, &"smg")
	assert_false(it.is_dev(), "public (owner, 2026-11-14)")
	for tag: String in ["rifle", "electric", "top-rail", "side-rail", "muzzle-thread"]:
		assert_true(it.tags.has(tag), tag)
	for tag: String in ["under-rail", "barrel-mount", "aeg-mag"]:
		assert_false(it.tags.has(tag), "no %s" % tag)
	var ids := func(list: Array[Pool.Item]) -> Array: return list.map(func(i: Pool.Item) -> String: return i.id)
	assert_eq(ids.call(rules.pool.powers_for(it, true)), [BATTERY, LIPO], "the batteries, the standard one first")
	assert_eq(ids.call(rules.pool.comes_with(it)), [], "iron sights as it comes")
	rules.dev_content = false
	assert_true(rules.is_offered(SMG), "offered without Dev content")


func test_it_plays_by_its_stats_row_semi_and_full_auto() -> void:
	var r := _smg()
	assert_not_null(r, "a built-in config since CS1")
	assert_eq(r.fire_modes, [ReplicaConfig.FireMode.SEMI, ReplicaConfig.FireMode.AUTO] as Array[ReplicaConfig.FireMode],
			"semi and full auto, no burst")
	assert_eq(r.default_fire_mode, ReplicaConfig.FireMode.AUTO)
	assert_eq(r.site_class, &"rifle")
	assert_eq(r.power, &"electric")
	assert_eq(r.sound_profile(), &"smg", "its own sounds")
	assert_false(r.bolt_action)
	assert_almost_eq(r.muzzle_energy, 0.85, 1e-6)
	assert_almost_eq(r.bb_weight, 0.2, 1e-6)
	assert_almost_eq(r.fire_rate, 18.0, 1e-6)
	assert_eq([r.mag_size, r.mags], [45, 5])
	assert_almost_eq(r.reload_time, 1.4, 1e-6)
	assert_almost_eq(r.draw_time, 0.32, 1e-6)
	assert_almost_eq(r.spread_deg, 0.6, 1e-6)
	assert_almost_eq(r.recoil_deg, 0.14, 1e-6)
	assert_almost_eq(r.hip_spread, 0.75, 1e-6)
	assert_almost_eq(r.pace, 1.08, 1e-6)
	assert_almost_eq(r.move_spread, 0.5, 1e-6)
	var aeg := _aeg()
	assert_almost_eq(aeg.pace, 1.0, 1e-6, "every other replica as before")
	assert_almost_eq(aeg.move_spread, 1.0, 1e-6)
	assert_gt(r.fire_rate, aeg.fire_rate, "a faster trigger than the AEG")
	assert_lt(float(r.mag_size) / r.fire_rate, float(aeg.mag_size) / aeg.fire_rate, "and empty sooner")
	assert_lt(r.draw_time, aeg.draw_time)
	assert_lt(r.reload_time, aeg.reload_time)
	assert_gt(r.spread_deg, aeg.spread_deg, "wider than the AEG with the sight up")


func test_it_stays_under_the_rifle_limit_and_falls_short_of_the_aeg() -> void:
	var tuning := SimTuning.new()
	var smg := _smg()
	var aeg := _aeg()
	assert_lt(Ballistics.muzzle_energy(smg, tuning.replica_rules), 1.2, "under the rifle limit as it comes")
	var reach := Ballistics.hop_up_reach(smg, smg.hop_up_dial, tuning, DT, 0.15, 80.0).on_target_to
	var aeg_reach := Ballistics.hop_up_reach(aeg, aeg.hop_up_dial, tuning, DT, 0.15, 80.0).on_target_to
	assert_between(reach, 24.0, 31.0, "about 27 m on target as it comes")
	assert_lt(reach, aeg_reach - 8.0, "well short of the AEG's 39 m")
	var best := 0.0
	for i in 21:
		best = maxf(best, Ballistics.hop_up_reach(smg, i / 20.0, tuning, DT, 0.15, 80.0).on_target_to)
	assert_lt(best, aeg_reach, "short of the AEG even at its best hop-up")
	assert_gt(Ballistics.flight_time(smg, smg.hop_up_dial, 30.0, tuning, DT),
			Ballistics.flight_time(aeg, aeg.hop_up_dial, 30.0, tuning, DT), "slower to 30 m: more lead")


func test_full_auto_puts_out_eighteen_a_second_and_empties_the_magazine() -> void:
	var c := _holding(_smg())
	var cmd := PlayerCommand.new()
	cmd.fire = true
	var pool := BBPool.new(64)
	var events := SimEvents.new()
	var tuning := SimTuning.new()
	var shots := 0
	for tick in 60:
		events.clear()
		Armament.step(c, cmd, EYE, 1.0, true, pool, Seeds.stream(3), events, tuning, DT)
		for k in events.count:
			if events.items[k].kind == GameEvent.Kind.SHOT:
				shots += 1
	assert_between(shots, 17, 19, "18 BBs in a second of trigger")
	assert_eq(c.armament.mag(), 45 - shots)


func test_carried_you_run_and_sprint_eight_percent_quicker_but_not_as_holstered() -> void:
	var cfg := MovementConfig.new()
	var smg := _holding(_smg())
	var aeg := _holding(_aeg())
	assert_almost_eq(Movement.target_speed(smg, cfg, false), cfg.run_speed * 1.08, 1e-4, "the run")
	assert_almost_eq(Movement.target_speed(aeg, cfg, false), cfg.run_speed, 1e-4)
	smg.sprinting = true
	assert_almost_eq(Movement.target_speed(smg, cfg, false), cfg.sprint_speed * 1.08, 1e-4, "the sprint")
	smg.sprinting = false
	smg.walking = true
	assert_almost_eq(Movement.target_speed(smg, cfg, false), cfg.walk_speed, 1e-4, "walking and aiming as ever")
	smg.walking = false
	smg.armament.holstered = true
	assert_almost_eq(Movement.target_speed(smg, cfg, false), cfg.holster_run_speed, 1e-4, "holstered: the holster's")
	assert_gt(cfg.holster_run_speed, cfg.run_speed * 1.08, "holstered is quicker still")


func test_moving_adds_half_the_spread_and_the_hip_is_tighter() -> void:
	var cfg := MovementConfig.new()
	var acc := AccuracyConfig.new()
	var smg := _holding(_smg())
	var aeg := _holding(_aeg())
	var still_smg := Accuracy.target_spread_scale(smg, cfg, acc)
	var still_aeg := Accuracy.target_spread_scale(aeg, cfg, acc)
	assert_almost_eq(still_smg / still_aeg, 0.75, 1e-4, "standing, from the hip: 0.75 times as wide")
	assert_almost_eq(_smg().spread_deg * still_smg, _aeg().spread_deg * still_aeg, 1e-4,
			"so it hip-fires as tight as the AEG standing")
	for c: Character in [smg, aeg]:
		c.velocity = Vector3(cfg.run_speed, 0.0, 0.0)
	var run_smg := Accuracy.target_spread_scale(smg, cfg, acc)
	var run_aeg := Accuracy.target_spread_scale(aeg, cfg, acc)
	assert_almost_eq(run_smg, 0.75 * (1.0 + (acc.run - 1.0) * 0.5), 1e-4, "half of what running adds")
	assert_almost_eq(run_aeg, acc.run, 1e-4)
	assert_lt(_smg().spread_deg * run_smg, 0.75 * _aeg().spread_deg * run_aeg, "on the run, over a quarter tighter")
	for c: Character in [smg, aeg]:
		c.velocity = Vector3.ZERO
		c.still_time = 1.0
		c.aim_raise = 1.0
	assert_almost_eq(Accuracy.target_spread_scale(smg, cfg, acc), Accuracy.target_spread_scale(aeg, cfg, acc), 1e-6,
			"held still with the sight up: the same rule as everything")
	assert_gt(_smg().spread_deg * Accuracy.target_spread_scale(smg, cfg, acc),
			_aeg().spread_deg * Accuracy.target_spread_scale(aeg, cfg, acc), "and its wider spread shows")


func test_its_parts_are_the_optics_laser_silencer_and_torch() -> void:
	var l := rules.default_loadout("L")
	assert_true(rules.equip(l, Loadout.Slot.PRIMARY, SMG), "on offer with Dev content")
	assert_true(rules.set_part(l, SMG, &"optic", RED_DOT))
	assert_true(rules.set_part(l, SMG, &"optic", SCOPE), "a scope on its top rail")
	assert_true(rules.set_part(l, SMG, &"laser", RED_LASER), "the laser on its side rail")
	assert_true(rules.set_part(l, SMG, &"muzzle", SILENCER))
	assert_false(rules.set_part(l, SMG, &"grip", VERTICAL), "no under rail")
	assert_false(rules.set_part(l, SMG, &"barrel", LONG_BARREL), "no barrel mount")
	assert_false(rules.set_part(l, SMG, &"magazine", HI_CAP), "no AEG magazines")
	assert_true(rules.set_power(l, SMG, LIPO))
	var carried := rules.carried(l)
	assert_almost_eq(carried.replicas[0].fire_rate, 18.0 * 1.15, 1e-4, "the LiPo's rate on top")
	assert_almost_eq(carried.replicas[0].pace, 1.08, 1e-6, "its pace carried with its parts")
	assert_almost_eq(carried.replicas[0].move_spread, 0.5, 1e-6)


func test_it_unlocks_at_level_12_with_its_parts_already_there() -> void:
	var table := LevelTable.read_file(rules.pool)
	assert_eq(table.problems, [] as Array[String])
	assert_eq(table.unlock_level(SMG), 12, "swapped with the Pump Shotgun (owner, 2026-11-14)")
	for part: String in [RED_DOT, RED_LASER, SILENCER, BATTERY]:
		assert_lt(table.unlock_level(part), 12, "%s before it" % part)


func test_the_breacher_kit_carries_it_with_a_red_dot_in_every_match() -> void:
	var k := BotKits.read_file(rules.pool)
	var plan: BotKits.Plan = null
	for p in k.kits:
		if p.kit_name == "Breacher":
			plan = p
	assert_not_null(plan)
	assert_true(BotKits.offers(rules, plan), "with Dev content")
	var kit := BotKits.kit_of(plan, rules)
	assert_eq(kit.replicas[0].id, &"smg")
	assert_eq(kit.parts[0].get(&"optic"), &"redDot")
	assert_false(kit.dev, "public gear: the match counts for the records")
	rules.dev_content = false
	assert_true(BotKits.offers(rules, plan), "and without it")


func test_its_sounds_are_there() -> void:
	for cue: String in ["shot_smg", "power_smg", "magIn_smg", "magOut_smg", "dryFire"]:
		for n in 5:
			assert_true(ResourceLoader.exists("%s%s_%d.wav" % [SoundConfig.CUE_DIR, cue, n + 1]), "%s_%d" % [cue, n + 1])
	assert_true(SoundConfig.new().power_gains.has(&"smg"), "its motor lifted as the AEG's")


func test_it_is_drawn_held_and_fitted_by_its_own_model() -> void:
	var r := _smg()
	assert_eq(r.model, &"", "no stand-in any more")
	assert_eq(r.model_id(), &"smg", "drawn as itself")
	assert_eq(ReplicaConfig.model_of(&"smg"), &"smg")
	assert_eq(ReplicaConfig.model_of(&"sniper"), &"sniper")
	assert_eq(ReplicaConfig.model_of(&"nothing"), &"nothing", "no built-in config: the key itself")
	assert_true(ResourceLoader.exists("res://assets/models/replicas/smg.glb"), "its own model")
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, [r] as Array[ReplicaConfig])
	var view := ReplicaView.new()
	add_child_autofree(view)
	view.setup(ViewModelConfig.new(), c.armament.replicas, BoxWorld.new())
	var held: ReplicaView.Held = view._held[0]
	assert_eq(held.id, &"smg", "held and posed as itself")
	assert_not_null(held.muzzle, "its model loaded, with its muzzle")
	assert_not_null(held.anim)
	for clip: StringName in [&"Fire", &"Reload", &"Selector", &"Inspect"]:
		assert_true(held.anim.has_animation(clip), "its %s clip" % clip)
	var taken := ReplicaParts.take(&"smg", {&"optic": &"redDot", &"laser": &"redLaser", &"light": &"weaponTorch",
			&"muzzle": &"silencer"}, false)
	for slot: StringName in [&"optic", &"laser", &"light", &"muzzle"]:
		assert_true(taken.has(slot), "its %s from its own parts file" % slot)
	for n: Node3D in taken.values():
		n.free()


func test_its_model_keeps_the_replica_contract() -> void:
	var model := (load("res://assets/models/replicas/smg.glb") as PackedScene).instantiate() as Node3D
	for node: String in ["Body", "Magazine", "FlashHider", "Figure", "Figure_Magazine", "Figure_FlashHider",
			"Figure_Sights", "Muzzle", "BarrelEnd", "FrontSight", "RearSight", "MagWell", "OpticMount", "TorchMount"]:
		assert_not_null(model.find_child(node, true, false), node)
	var muzzle := model.find_child("Muzzle", true, false) as Node3D
	var end := model.find_child("BarrelEnd", true, false) as Node3D
	assert_lt(end.position.z, 0.0, "the barrel's end ahead of the origin (-z forward)")
	assert_lt(muzzle.position.z, end.position.z, "the muzzle ahead of the barrel's end")
	var rear := model.find_child("RearSight", true, false) as Node3D
	var front := model.find_child("FrontSight", true, false) as Node3D
	assert_almost_eq(rear.position.y, front.position.y, 1e-4, "the iron sights' line parallel to the bore")
	model.free()
