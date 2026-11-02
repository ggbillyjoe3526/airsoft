extends GutTest
## The Sniper Rifle (SN1; owner, 2026-11-02): a dev replica that plays by stats.md's `sniper` row, single shot, driven by
## the springs (the M130 as it comes, the M140 and M150 stronger, as the gases are), under the sniper class's site
## limit, comes with the 2x Scope fitted (pool.md › Comes with), is six times as wide from the hip, unlocks at level 5
## with the scope, is drawn from sniper.glb (the AEG's model with a longer barrel and a cocking Fire clip), is heard
## cocking after every shot, and is carried by the Sniper bot kit, whose bots fight it with the sight up.

const DT := 1.0 / 60.0
const EYE := Vector3(0.0, 1.6, 0.0)
const AEG := "000002"
const SNIPER := "000021"
const SCOPE := "000010"
const M130 := "000022"
const M140 := "000023"
const M150 := "000024"
const SILENCER := "000018"
const VERTICAL := "000006"
const LONG_BARREL := "000017"
const HI_CAP := "000012"

var rules: LoadoutRules


func before_each() -> void:
	rules = LoadoutRules.new(Pool.read_file(), ReplicaStats.read_file(), ReplicaRulesConfig.new())
	rules.dev_content = true


func _sniper() -> ReplicaConfig:
	return rules.config(rules.pool.item(SNIPER))


## A loadout carrying the Sniper Rifle as its primary.
func _loadout() -> Loadout:
	var l := rules.default_loadout("L")
	assert_true(rules.equip(l, Loadout.Slot.PRIMARY, SNIPER), "on offer with Dev content")
	return l


func test_it_is_a_dev_spring_rifle_in_the_pool() -> void:
	var it := rules.pool.item(SNIPER)
	assert_not_null(it)
	assert_eq(it.display_name, "Sniper Rifle")
	assert_eq(it.key, &"sniper")
	assert_true(it.is_dev(), "dev until the owner makes it public")
	for tag: String in ["rifle", "spring", "top-rail", "under-rail", "muzzle-thread"]:
		assert_true(it.tags.has(tag), tag)
	assert_false(it.tags.has("barrel-mount"), "its long barrel is fixed")
	assert_false(it.tags.has("aeg-mag"), "its magazines are its own")
	var ids := func(list: Array[Pool.Item]) -> Array: return list.map(func(i: Pool.Item) -> String: return i.id)
	assert_eq(ids.call(rules.pool.powers_for(it, true)), [M130, M140, M150], "the springs, the M130 first")
	assert_eq(ids.call(rules.pool.powers_for(rules.pool.item(AEG), true)).has(M130), false, "no spring in an AEG")
	assert_eq(ids.call(rules.pool.comes_with(it)), [SCOPE])
	rules.dev_content = false
	assert_false(rules.is_offered(SNIPER), "hidden without Dev content")


func test_it_plays_by_its_stats_row_single_shot() -> void:
	var r := _sniper()
	assert_not_null(r, "a built-in config since SN1")
	assert_eq(r.fire_modes, [ReplicaConfig.FireMode.SEMI] as Array[ReplicaConfig.FireMode], "single shot only")
	assert_eq(r.default_fire_mode, ReplicaConfig.FireMode.SEMI)
	assert_eq(r.site_class, &"sniper")
	assert_eq(r.sound_profile(), &"spring")
	assert_true(r.bolt_action)
	assert_almost_eq(r.muzzle_energy, 1.9, 1e-6)
	assert_almost_eq(r.bb_weight, 0.3, 1e-6)
	assert_almost_eq(r.fire_rate, 0.8, 1e-6)
	assert_eq([r.mag_size, r.mags], [25, 4])
	assert_almost_eq(r.spread_deg, 0.1, 1e-6)
	assert_almost_eq(r.hip_spread, 6.0, 1e-6)
	var aeg := rules.config(rules.pool.item(AEG))
	assert_almost_eq(aeg.hip_spread, 1.0, 1e-6, "the rest as before")
	assert_lt(r.spread_deg, aeg.spread_deg, "tighter than the AEG raised")
	assert_gt(r.spread_deg * r.hip_spread, aeg.spread_deg, "wider than the AEG from the hip")


func test_it_comes_with_the_2x_scope_and_the_m130_which_can_be_changed() -> void:
	var l := _loadout()
	var t := rules.tune_of(l, SNIPER)
	assert_eq(t.parts, {&"optic": SCOPE} as Dictionary[StringName, String], "the 2x Scope as it comes")
	assert_eq(t.power_id, M130)
	var kit := rules.carried(l)
	assert_eq(kit.replicas[0].id, &"sniper")
	assert_eq(kit.parts[0].get(&"optic"), &"scope2x")
	assert_true(kit.replicas[0].zoom_in_glass, "the scope zooms only its glass")
	assert_true(rules.set_part(l, SNIPER, &"optic", ""), "taken off")
	kit = rules.carried(l)
	assert_false(kit.parts[0].has(&"optic"), "iron sights")
	var saved := ReplicaTune.from_dict(rules.tune_of(l, SNIPER).to_dict(), rules.default_tune(rules.pool.item(SNIPER)))
	assert_false(saved.parts.has(&"optic"), "taken off stays off through a save")
	assert_true(rules.set_part(l, SNIPER, &"optic", "000007"), "a red dot instead")
	assert_true(rules.set_part(l, SNIPER, &"grip", VERTICAL), "the AEG's grips fit")
	assert_true(rules.set_part(l, SNIPER, &"muzzle", SILENCER))
	assert_false(rules.set_part(l, SNIPER, &"barrel", LONG_BARREL), "no barrel mount")
	assert_false(rules.set_part(l, SNIPER, &"magazine", HI_CAP), "no AEG magazines")


func test_each_spring_works_like_a_gas_and_stays_under_the_sniper_limit() -> void:
	var limit := rules.stats.energy_limit(&"sniper")
	assert_almost_eq(limit, 2.3, 1e-6)
	var energies: Array[float] = []
	for spring: String in [M130, M140, M150]:
		var l := _loadout()
		assert_true(rules.set_power(l, SNIPER, spring), spring)
		var kit := rules.carried(l)
		var r := kit.replicas[0]
		assert_false(kit.capped[0], "%s under the limit" % spring)
		assert_lt(r.muzzle_energy, limit)
		energies.append(r.muzzle_energy)
	assert_almost_eq(energies[1], 1.9 * 1.1, 1e-4, "the M140: 10 % more")
	assert_almost_eq(energies[2], 1.9 * 1.2, 1e-4, "the M150: 20 % more")
	var l := _loadout()
	rules.set_power(l, SNIPER, M150)
	var stiff := rules.carried(l).replicas[0]
	assert_lt(stiff.fire_rate, _sniper().fire_rate, "a stiffer spring is slower to cock")
	assert_gt(stiff.recoil_deg, _sniper().recoil_deg, "and kicks harder")


func test_it_unlocks_at_level_5_with_the_scope_it_comes_with() -> void:
	var table := LevelTable.read_file(rules.pool)
	assert_eq(table.unlock_level(SNIPER), 5)
	assert_eq(table.unlock_level(M130), 5)
	assert_eq(table.unlock_level(SCOPE), 5, "moved from 7 to come with it (owner, 2026-11-02)")
	assert_eq(table.unlock_level(M140), 7)
	assert_eq(table.unlock_level(M150), 9)
	var progress := Progress.new(table)
	rules.follow_progress(progress, false)
	var l := rules.default_loadout("L")
	assert_false(rules.equip(l, Loadout.Slot.PRIMARY, SNIPER), "locked at level 0")
	progress.add_xp(table.levels[5].total)
	assert_true(rules.equip(l, Loadout.Slot.PRIMARY, SNIPER), "unlocked at level 5")
	assert_eq(rules.carried(l).parts[0].get(&"optic"), &"scope2x", "with its scope on")


func test_one_shot_then_the_spring_is_cocked_before_the_next() -> void:
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, [_sniper()] as Array[ReplicaConfig])
	var cmd := PlayerCommand.new()
	var pool := BBPool.new(8)
	var events := SimEvents.new()
	var tuning := SimTuning.new()
	var shots: Array[int] = []
	for tick in 120:
		# A fresh pull every other tick: as fast as anyone can click.
		cmd.fire = tick % 2 == 0
		events.clear()
		Armament.step(c, cmd, EYE, 1.0, true, pool, Seeds.stream(3), events, tuning, DT)
		for k in events.count:
			if events.items[k].kind == GameEvent.Kind.SHOT:
				shots.append(tick)
	assert_eq(shots.size(), 2, "two shots in two seconds of clicking")
	assert_almost_eq((shots[1] - shots[0]) * DT, 1.0 / 0.8, 2.0 * DT, "1.25 s apart")
	assert_eq(c.armament.mag(), 23)


func test_from_the_hip_it_is_six_times_as_wide_and_raised_as_any_replica() -> void:
	var cfg := MovementConfig.new()
	var acc := AccuracyConfig.new()
	var sniper := Character.new(1, 0, Vector3.ZERO, 0.0, [_sniper()] as Array[ReplicaConfig])
	var aeg := Character.new(2, 0, Vector3.ZERO, 0.0, [rules.config(rules.pool.item(AEG))] as Array[ReplicaConfig])
	for c: Character in [sniper, aeg]:
		c.grounded = true
	var hip := Accuracy.target_spread_scale(sniper, cfg, acc)
	assert_almost_eq(hip / Accuracy.target_spread_scale(aeg, cfg, acc), 6.0, 1e-4)
	sniper.aim_raise = 1.0
	aeg.aim_raise = 1.0
	assert_almost_eq(Accuracy.target_spread_scale(sniper, cfg, acc), Accuracy.target_spread_scale(aeg, cfg, acc), 1e-6,
			"raised, the same rule as everything")
	sniper.aim_raise = 0.5
	aeg.aim_raise = 0.5
	assert_almost_eq(Accuracy.target_spread_scale(sniper, cfg, acc) / Accuracy.target_spread_scale(aeg, cfg, acc),
			3.5, 1e-4, "half up, half way")


func test_in_hand_it_is_the_aeg_with_a_longer_barrel_and_a_cocking_fire_clip() -> void:
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, [_sniper(), rules.config(rules.pool.item(AEG))] as Array[ReplicaConfig])
	var view := ReplicaView.new()
	add_child_autofree(view)
	view.setup(ViewModelConfig.new(), c.armament.replicas, BoxWorld.new())
	var sniper := view._held[0]
	var aeg := view._held[1]
	assert_eq(sniper.id, &"sniper")
	assert_not_null(sniper.muzzle)
	assert_almost_eq(sniper.muzzle.position.z - aeg.muzzle.position.z, -0.2, 1e-3, "the barrel 20 cm longer")
	assert_almost_eq(sniper.rear_sight, aeg.rear_sight, Vector3.ONE * 1e-4, "the AEG's sights")
	assert_not_null(sniper.anim)
	for clip: StringName in [&"Fire", &"Reload", &"Inspect"]:
		assert_true(sniper.anim.has_animation(clip), clip)
	assert_almost_eq(sniper.anim.get_animation(&"Fire").length, 1.0, 0.01, "the cocking: about a second")
	var vm := ViewModelConfig.new()
	assert_true(vm.hip.has(&"sniper") and vm.aim_forward.has(&"sniper"))


func test_its_parts_file_carries_the_optics_grips_silencer_and_torch() -> void:
	var parts := (load("res://assets/models/replicaParts/sniper.glb") as PackedScene).instantiate()
	add_child_autofree(parts)
	for name: String in ["optic_scope2x", "optic_redDot", "grip_vertical", "grip_angled", "muzzle_silencer",
			"light_weaponTorch"]:
		assert_not_null(parts.find_child(name, true, false), name)
	for name: String in ["barrel_long", "magazine_hiCap"]:
		assert_null(parts.find_child(name, true, false), "%s doesn't fit" % name)


func test_every_spring_has_a_picture_and_the_cocking_cue_is_there() -> void:
	for spring: String in [M130, M140, M150]:
		assert_eq(PowerModels.file(spring), PowerModels.SPRING_FILE, spring)
	assert_true(ResourceLoader.exists("res://assets/models/powerSources/spring.glb"))
	for n in 3:
		assert_true(ResourceLoader.exists("%s%s_%d.wav" % [SoundConfig.CUE_DIR, SimAudio.BOLT_CUE, n + 1]))
	for cue: String in ["shot_spring", "dryFire_spring", "magIn_spring", "magOut_spring", "power_spring"]:
		assert_true(ResourceLoader.exists("%s%s_1.wav" % [SoundConfig.CUE_DIR, cue]), cue)


func test_the_sniper_kit_carries_it_with_its_scope_and_its_bots_fight_aimed() -> void:
	var k := BotKits.read_file(rules.pool)
	var plan: BotKits.Plan = null
	for p in k.kits:
		if p.kit_name == "Sniper":
			plan = p
	assert_not_null(plan)
	assert_true(BotKits.offers(rules, plan), "with Dev content")
	var kit := BotKits.kit_of(plan, rules)
	assert_eq(kit.replicas[0].id, &"sniper")
	assert_eq(kit.parts[0].get(&"optic"), &"scope2x", "as it comes: scoped")
	assert_true(kit.dev, "a dev match: off the records")
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, kit.replicas)
	assert_true(BotCombat.fights_aimed(c))
	var aeg := Character.new(2, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	assert_false(BotCombat.fights_aimed(aeg))
	rules.dev_content = false
	assert_false(BotKits.offers(rules, plan), "never without Dev content")
