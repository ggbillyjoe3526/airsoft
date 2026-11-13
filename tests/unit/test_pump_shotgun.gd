extends GutTest
## The Pump Shotgun (SH1; owner, 2026-11-12: "a shotgun replica" that feels and plays unlike the others; Dev content):
## a spring replica that plays by stats.md's `shotgun` row. One pull sends three BBs, one from each barrel, spaced
## evenly round the shot's line (ReplicaConfig.shot_bbs, pattern_deg), then the pump is worked by hand; single shots
## only. Its shell is a 30 BB box swapped like a magazine (ten pulls), it shares the Sniper Rifle's springs, takes an
## optic on its top rail and nothing else until its own model brings its side rail, unlocks at level 12, and the
## Clearer bot kit carries it. Until that model it is drawn as the Sniper Rifle and heard through stand-in sounds.

const DT := 1.0 / 60.0
const EYE := Vector3(0.0, 1.6, 0.0)
const KILL_Y := -10.0
const AEG := "000002"
const SNIPER := "000021"
const SMG := "000026"
const SHOTGUN := "000027"
const RED_DOT := "000007"
const SCOPE := "000010"
const VERTICAL := "000006"
const RED_LASER := "000005"
const TORCH := "000020"
const SILENCER := "000018"
const LONG_BARREL := "000017"
const HI_CAP := "000012"
const M130 := "000022"
const M140 := "000023"
const M150 := "000024"
const BATTERY := "000003"
## The pattern as shipped (stats.md): each BB this far off the shot's line.
const PATTERN := 1.2

var rules: LoadoutRules


func before_each() -> void:
	rules = LoadoutRules.new(Pool.read_file(), ReplicaStats.read_file(), ReplicaRulesConfig.new())
	rules.dev_content = true


func _shotgun() -> ReplicaConfig:
	return rules.config(rules.pool.item(SHOTGUN))


func _replica(id: String) -> ReplicaConfig:
	return rules.config(rules.pool.item(id))


## A character holding `r`, grounded, standing still.
func _holding(r: ReplicaConfig) -> Character:
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, [r] as Array[ReplicaConfig])
	c.grounded = true
	return c


## One tick of `c`'s replica with the trigger `down`; returns the SHOT events it made.
func _tick(c: Character, down: bool, pool: BBPool, events: SimEvents, tuning: SimTuning) -> int:
	var cmd := PlayerCommand.new()
	cmd.fire = down
	events.clear()
	Armament.step(c, cmd, EYE, 1.0, true, pool, Seeds.stream(3), events, tuning, DT)
	return events.count_of(GameEvent.Kind.SHOT)


## The BBs in flight in `pool`.
func _flying(pool: BBPool) -> Array[BB]:
	var out: Array[BB] = []
	for bb in pool.bbs:
		if bb.active:
			out.append(bb)
	return out


func test_it_is_a_dev_spring_rifle_in_the_pool_with_the_snipers_springs() -> void:
	var it := rules.pool.item(SHOTGUN)
	assert_not_null(it)
	assert_eq(it.display_name, "Pump Shotgun")
	assert_eq(it.key, &"shotgun")
	assert_true(it.is_dev(), "Dev content until the owner says make it public")
	for tag: String in ["rifle", "spring", "top-rail", "side-rail"]:
		assert_true(it.tags.has(tag), tag)
	for tag: String in ["under-rail", "barrel-mount", "aeg-mag", "muzzle-thread", "electric", "gas"]:
		assert_false(it.tags.has(tag), "no %s" % tag)
	var ids := func(list: Array[Pool.Item]) -> Array: return list.map(func(i: Pool.Item) -> String: return i.id)
	assert_eq(ids.call(rules.pool.powers_for(it, true)), [M130, M140, M150],
			"the Sniper Rifle's springs (owner, 2026-11-12), the M130 as it comes")
	assert_eq(ids.call(rules.pool.comes_with(it)), [], "iron sights as it comes")
	rules.dev_content = false
	assert_false(rules.is_offered(SHOTGUN), "hidden without Dev content")


func test_it_plays_by_its_stats_row_single_shots_and_a_pump() -> void:
	var r := _shotgun()
	assert_not_null(r, "a built-in config since SH1")
	assert_eq(r.fire_modes, [ReplicaConfig.FireMode.SEMI] as Array[ReplicaConfig.FireMode], "single shots only")
	assert_eq(r.default_fire_mode, ReplicaConfig.FireMode.SEMI)
	assert_eq(r.site_class, &"rifle")
	assert_eq(r.power, &"spring")
	assert_eq(r.sound_profile(), &"shotgun", "its own sounds")
	assert_true(r.bolt_action, "worked by hand after every shot")
	assert_eq(r.shot_bbs, 3, "three barrels")
	assert_almost_eq(r.pattern_deg, PATTERN, 1e-6)
	assert_almost_eq(r.muzzle_energy, 0.65, 1e-6)
	assert_almost_eq(r.bb_weight, 0.2, 1e-6)
	assert_almost_eq(r.fire_rate, 1.7, 1e-6)
	assert_eq([r.mag_size, r.mags], [30, 5], "a 30 BB shell, ten pulls, and five carried")
	assert_almost_eq(r.reload_time, 1.2, 1e-6)
	assert_almost_eq(r.draw_time, 0.5, 1e-6)
	assert_almost_eq(r.spread_deg, 0.5, 1e-6)
	assert_almost_eq(r.recoil_deg, 0.45, 1e-6)
	assert_almost_eq(r.hip_spread, 0.7, 1e-6)
	assert_almost_eq(r.pace, 1.0, 1e-6)
	assert_almost_eq(r.move_spread, 1.0, 1e-6)
	for id: String in [AEG, SNIPER, SMG]:
		var other := _replica(id)
		assert_eq(other.shot_bbs, 1, "%s: one BB a shot, as before" % other.id)
		assert_almost_eq(other.pattern_deg, 0.0, 1e-6)
		assert_lt(r.reload_time, other.reload_time, "the quickest change of the long replicas (%s)" % other.id)
	assert_lt(r.hip_spread, 1.0, "tighter from the hip")


func test_it_stays_under_the_rifle_limit_and_is_the_shortest_reach_of_the_long_replicas() -> void:
	var tuning := SimTuning.new()
	var r := _shotgun()
	assert_lt(Ballistics.muzzle_energy(r, tuning.replica_rules), 1.2, "under the rifle limit as it comes")
	var reach := Ballistics.hop_up_reach(r, r.hop_up_dial, tuning, DT, 0.15, 80.0).on_target_to
	assert_between(reach, 21.0, 27.0, "about 24 m on target as it comes")
	var best := 0.0
	for i in 21:
		best = maxf(best, Ballistics.hop_up_reach(r, i / 20.0, tuning, DT, 0.15, 80.0).on_target_to)
	for id: String in [AEG, SNIPER, SMG]:
		var other := _replica(id)
		var theirs := Ballistics.hop_up_reach(other, other.hop_up_dial, tuning, DT, 0.15, 80.0).on_target_to
		assert_lt(reach, theirs, "short of the %s as it comes" % other.id)
	var aeg := _replica(AEG)
	assert_lt(best, Ballistics.hop_up_reach(aeg, aeg.hop_up_dial, tuning, DT, 0.15, 80.0).on_target_to,
			"short of the AEG even at its best hop-up")


func test_one_pull_sends_three_bbs_off_the_shell_with_one_shot_event() -> void:
	var c := _holding(_shotgun())
	var pool := BBPool.new(16)
	var events := SimEvents.new()
	var tuning := SimTuning.new()
	assert_eq(_tick(c, true, pool, events, tuning), 1, "one shot heard and counted")
	assert_eq(_flying(pool).size(), 3, "three BBs in the air")
	assert_eq(c.armament.mag(), 27, "three off the shell")
	var shot := events.first(GameEvent.Kind.SHOT)
	assert_almost_eq(shot.direction, _flying(pool)[0].velocity.normalized(), Vector3.ONE * 1e-6,
			"the shot's direction is its first BB's")
	var speed := _flying(pool)[0].velocity.length()
	for bb in _flying(pool):
		assert_almost_eq(bb.velocity.length(), speed, 1e-6, "each at the replica's muzzle speed")
		assert_eq(bb.owner_id, c.id)


func test_the_three_bbs_leave_evenly_round_the_line_the_first_straight_up() -> void:
	var r := _shotgun()
	r.spread_deg = 0.0
	var c := _holding(r)
	var pool := BBPool.new(16)
	_tick(c, true, pool, SimEvents.new(), SimTuning.new())
	var aim := Vector3.FORWARD
	var dirs: Array[Vector3] = []
	for bb in _flying(pool):
		dirs.append(bb.velocity.normalized())
	assert_eq(dirs.size(), 3)
	for d in dirs:
		assert_almost_eq(rad_to_deg(d.angle_to(aim)), PATTERN, 0.02, "each %.1f° off the line" % PATTERN)
	assert_almost_eq(dirs[0].x, 0.0, 1e-6, "the first straight up")
	assert_gt(dirs[0].y, 0.0)
	assert_lt(dirs[1].y, 0.0, "the other two below it")
	assert_lt(dirs[2].y, 0.0)
	assert_almost_eq(dirs[1].x, -dirs[2].x, 1e-6, "one each side")
	assert_almost_eq(dirs[1].y, dirs[2].y, 1e-6)
	var apart := rad_to_deg(dirs[0].angle_to(dirs[1]))
	assert_almost_eq(rad_to_deg(dirs[1].angle_to(dirs[2])), apart, 0.02, "an even triangle")
	# At 10 m the BBs are about 36 cm apart: a body wide. At 25 m, 52 cm off the line each: round a body.
	assert_between(10.0 * tan(deg_to_rad(apart)), 0.3, 0.42)
	assert_gt(25.0 * tan(deg_to_rad(PATTERN)), 0.45)


func test_each_bb_has_its_own_scatter() -> void:
	var c := _holding(_shotgun())
	var pool := BBPool.new(16)
	_tick(c, true, pool, SimEvents.new(), SimTuning.new())
	var dirs := _flying(pool)
	var offs: Array[float] = []
	for bb in dirs:
		offs.append(rad_to_deg(bb.velocity.normalized().angle_to(Vector3.FORWARD)))
	assert_false(is_equal_approx(offs[0], offs[1]) and is_equal_approx(offs[1], offs[2]),
			"with spread, the three are not a rigid triangle")
	for off in offs:
		assert_between(off, 0.0, PATTERN + 3.0, "pattern plus a few degrees of spread at most")


func test_the_pump_holds_the_next_pull_and_a_shell_is_ten_pulls() -> void:
	var c := _holding(_shotgun())
	var pool := BBPool.new(64)
	var events := SimEvents.new()
	var tuning := SimTuning.new()
	var shots := 0
	var shot_ticks: Array[int] = []
	# Clicking as fast as a finger can (every other tick) for six seconds.
	for tick in 360:
		var made := _tick(c, tick % 2 == 0, pool, events, tuning)
		if made > 0:
			shot_ticks.append(tick)
		shots += made
		for bb in pool.bbs:
			bb.active = false
	assert_eq(shots, 10, "ten pulls, then it is empty")
	assert_eq(c.armament.mag(), 0)
	for i in range(1, shot_ticks.size()):
		assert_between((shot_ticks[i] - shot_ticks[i - 1]) * DT, 1.0 / 1.7 - 2.0 * DT, 1.0 / 1.7 + 3.0 * DT,
				"a pump between pulls: 1.7 a second")


func test_a_shell_with_fewer_bbs_left_sends_what_it_has() -> void:
	var c := _holding(_shotgun())
	c.armament.ammo[0].mag = 2
	var pool := BBPool.new(16)
	var events := SimEvents.new()
	assert_eq(_tick(c, true, pool, events, SimTuning.new()), 1)
	assert_eq(_flying(pool).size(), 2)
	assert_eq(c.armament.mag(), 0, "never below empty")


func test_bottomless_magazines_still_send_three() -> void:
	var c := _holding(_shotgun())
	c.armament.bottomless = true
	var pool := BBPool.new(16)
	_tick(c, true, pool, SimEvents.new(), SimTuning.new())
	assert_eq(_flying(pool).size(), 3)
	assert_eq(c.armament.mag(), 30)


func test_every_other_replica_still_sends_one_bb_where_its_spread_puts_it() -> void:
	for id: String in [AEG, SNIPER, SMG]:
		var c := _holding(_replica(id))
		var pool := BBPool.new(16)
		var events := SimEvents.new()
		assert_eq(_tick(c, true, pool, events, SimTuning.new()), 1, id)
		assert_eq(_flying(pool).size(), 1, "%s: one BB" % id)
		var rng := Seeds.stream(3)
		var gx := rng.randfn(0.0, 1.0)
		var gy := rng.randfn(0.0, 1.0)
		var r := c.armament.replica()
		var want := Armament.spread_direction(c.yaw, c.pitch, deg_to_rad(r.spread_deg) * c.spread_scale, gx, gy,
				deg_to_rad(ReplicaRulesConfig.new().max_shot_pitch_deg))
		assert_almost_eq(_flying(pool)[0].velocity.normalized(), want, Vector3.ONE * 1e-6, "%s: as before SH1" % id)


func test_two_bbs_of_one_pull_on_one_body_are_one_hit() -> void:
	var tuning := SimTuning.new()
	tuning.hits.fit = null
	var r := _shotgun()
	r.spread_deg = 0.0
	var shooter := _holding(r)
	shooter.pitch = deg_to_rad(-2.0)
	var target := Character.new(2, 1, Vector3(0.0, 0.0, -3.0), 0.0)
	var roster: Array[Character] = [shooter, target]
	var pool := BBPool.new(16)
	var events := SimEvents.new()
	var cmd := PlayerCommand.new()
	cmd.fire = true
	Armament.step(shooter, cmd, EYE, 1.0, true, pool, Seeds.stream(3), events, tuning, DT)
	assert_eq(_flying(pool).size(), 3)
	var hits := 0
	var ends: Array[MapEnd] = []
	for i in 30:
		events.clear()
		BBStep.step(pool, roster, WorldQuery.new(), tuning, KILL_Y, false, ends, events, DT)
		hits += events.count_of(GameEvent.Kind.CHARACTER_HIT)
	assert_eq(hits, 1, "one hit is one hit, however many of the three land")
	assert_eq(target.status, Character.Status.CALLING)
	assert_eq(_flying(pool).size(), 0, "at 3 m all three stop on the body")


func test_it_takes_the_optics_and_the_springs_and_nothing_else_yet() -> void:
	var l := rules.default_loadout("L")
	assert_true(rules.equip(l, Loadout.Slot.PRIMARY, SHOTGUN), "on offer with Dev content")
	assert_true(rules.set_part(l, SHOTGUN, &"optic", SCOPE), "a scope on its top rail")
	assert_true(rules.set_part(l, SHOTGUN, &"optic", RED_DOT))
	assert_true(rules.set_part(l, SHOTGUN, &"laser", RED_LASER), "its side rail (SH2)")
	assert_true(rules.set_part(l, SHOTGUN, &"light", TORCH), "the Weapon Torch fits any rifle")
	assert_false(rules.set_part(l, SHOTGUN, &"muzzle", SILENCER), "three barrels: no thread")
	assert_false(rules.set_part(l, SHOTGUN, &"grip", VERTICAL), "the pump is the grip")
	assert_false(rules.set_part(l, SHOTGUN, &"barrel", LONG_BARREL), "no barrel mount")
	assert_false(rules.set_part(l, SHOTGUN, &"magazine", HI_CAP), "no AEG magazines")
	assert_false(rules.set_power(l, SHOTGUN, BATTERY), "no battery")
	var tuning := SimTuning.new()
	var as_it_comes := rules.carried(l).replicas[0]
	assert_almost_eq(as_it_comes.muzzle_energy, 0.65, 1e-4, "the M130 it comes with changes nothing")
	assert_almost_eq(as_it_comes.fire_rate, 1.7, 1e-4)
	assert_eq(as_it_comes.shot_bbs, 3, "three a pull with its parts")
	assert_almost_eq(as_it_comes.pattern_deg, PATTERN, 1e-6)
	assert_lt(as_it_comes.heard_scale, 1.0, "the quiet spring")
	assert_true(rules.set_power(l, SHOTGUN, M150))
	var strong := rules.carried(l).replicas[0]
	assert_almost_eq(strong.muzzle_energy, 0.65 * 1.2, 1e-4, "the M150: a fifth more energy")
	assert_almost_eq(strong.fire_rate, 1.7 * 0.9, 1e-4, "and a slower pump")
	assert_gt(strong.recoil_deg, as_it_comes.recoil_deg)
	assert_lt(Ballistics.muzzle_energy(strong, tuning.replica_rules, 0.4), 1.2, "under the rifle limit at its strongest")
	assert_lt(Ballistics.hop_up_reach(strong, strong.hop_up_dial, tuning, DT, 0.15, 80.0).on_target_to,
			Ballistics.hop_up_reach(_replica(AEG), _replica(AEG).hop_up_dial, tuning, DT, 0.15, 80.0).on_target_to,
			"still short of the AEG")


func test_it_unlocks_at_level_12_with_a_spring_and_a_sight_already_there() -> void:
	var table := LevelTable.read_file(rules.pool)
	assert_eq(table.problems, [] as Array[String])
	assert_eq(table.unlock_level(SHOTGUN), 12, "owner, 2026-11-12")
	for part: String in [RED_DOT, SCOPE, M130, M140]:
		assert_lt(table.unlock_level(part), 12, "%s before it" % part)
	assert_gt(table.unlock_level(M150), 12, "the strongest spring after it")


func test_the_clearer_kit_carries_it_with_a_red_dot_with_dev_content_only() -> void:
	var k := BotKits.read_file(rules.pool)
	var plan: BotKits.Plan = null
	for p in k.kits:
		if p.kit_name == "Clearer":
			plan = p
	assert_not_null(plan)
	assert_true(BotKits.offers(rules, plan), "with Dev content")
	var kit := BotKits.kit_of(plan, rules)
	assert_eq(kit.replicas[0].id, &"shotgun")
	assert_eq(kit.parts[0].get(&"optic"), &"redDot")
	assert_true(kit.dev, "dev gear: the match stays out of the records")
	rules.dev_content = false
	assert_false(BotKits.offers(rules, plan), "never without Dev content")


func test_its_sounds_are_there_with_a_pump_of_its_own() -> void:
	for cue: String in ["shot_shotgun", "magIn_shotgun", "magOut_shotgun", "dryFire"]:
		for n in 5:
			assert_true(ResourceLoader.exists("%s%s_%d.wav" % [SoundConfig.CUE_DIR, cue, n + 1]), "%s_%d" % [cue, n + 1])
	for n in 3:
		assert_true(ResourceLoader.exists("%scycle_shotgun_%d.wav" % [SoundConfig.CUE_DIR, n + 1]), "its pump")
	assert_false(ResourceLoader.exists("%spower_shotgun_1.wav" % SoundConfig.CUE_DIR), "a spring thump, no power part")


func test_it_is_drawn_held_and_fitted_by_its_own_model() -> void:
	var r := _shotgun()
	assert_eq(r.model, &"", "no stand-in any more (SH2)")
	assert_eq(r.model_id(), &"shotgun", "drawn as itself")
	assert_eq(ReplicaConfig.model_of(&"shotgun"), &"shotgun")
	assert_true(ResourceLoader.exists("res://assets/models/replicas/shotgun.glb"), "its own model")
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, [r] as Array[ReplicaConfig])
	var view := ReplicaView.new()
	add_child_autofree(view)
	view.setup(ViewModelConfig.new(), c.armament.replicas, BoxWorld.new())
	var held: ReplicaView.Held = view._held[0]
	assert_eq(held.id, &"shotgun", "held and posed as itself")
	assert_not_null(held.muzzle, "its model loaded, with its muzzle")
	assert_not_null(held.anim)
	for clip: StringName in [&"Fire", &"Reload", &"Selector", &"Inspect"]:
		assert_true(held.anim.has_animation(clip), "its %s clip" % clip)
	var taken := ReplicaParts.take(&"shotgun", {&"optic": &"redDot", &"laser": &"redLaser", &"light": &"weaponTorch"},
			false)
	for slot: StringName in [&"optic", &"laser", &"light"]:
		assert_true(taken.has(slot), "its %s from its own parts file" % slot)
	for n: Node3D in taken.values():
		n.free()


func test_its_model_keeps_the_replica_contract_and_has_no_sights() -> void:
	var model := (load("res://assets/models/replicas/shotgun.glb") as PackedScene).instantiate() as Node3D
	for node: String in ["Body", "Magazine", "FlashHider", "Pump", "Trigger", "Figure", "Figure_Magazine",
			"Figure_FlashHider", "Muzzle", "BarrelEnd", "FrontSight", "RearSight", "MagWell", "OpticMount", "TorchMount"]:
		assert_not_null(model.find_child(node, true, false), node)
	assert_null(model.find_child("Sights", true, false), "no sights of its own (owner, 2026-11-12)")
	assert_null(model.find_child("Figure_Sights", true, false))
	var muzzle := model.find_child("Muzzle", true, false) as Node3D
	var end := model.find_child("BarrelEnd", true, false) as Node3D
	assert_lt(end.position.z, 0.0, "the barrel's end ahead of the origin (-z forward)")
	assert_lt(muzzle.position.z, end.position.z, "the muzzle ahead of the barrel's end")
	var rear := model.find_child("RearSight", true, false) as Node3D
	var front := model.find_child("FrontSight", true, false) as Node3D
	assert_almost_eq(rear.position.y, front.position.y, 1e-4, "the sight line along its rail, parallel to the bore")
	model.free()


func test_a_bot_holds_a_pull_past_its_pattern_and_never_waits_to_settle() -> void:
	var cfg := BotConfig.new()
	var shotgun := Bot.new(_holding(_shotgun()), 1, BotSkill.new(), 2)
	assert_false(BotCombat.pattern_too_wide(shotgun, cfg, 15.0), "fought close")
	assert_false(BotCombat.pattern_too_wide(shotgun, cfg, 25.0))
	assert_true(BotCombat.pattern_too_wide(shotgun, cfg, 32.0), "past 29 m the BBs land round a body")
	var rifle := Bot.new(_holding(_replica(AEG)), 1, BotSkill.new(), 2)
	assert_false(BotCombat.pattern_too_wide(rifle, cfg, 60.0), "one BB a shot: never held for it")
