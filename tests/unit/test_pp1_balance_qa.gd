extends GutTest
## QA for PP1 part 3 (balance): the changed data rows read as written (a negative Energy % included) and reach the
## carried replica; the Compact SMG's factory hop-up kept while its best is cut; and BotBombs._judge_flash's edges
## (its own flash, a teammate's, one behind it, the reset). Headless, on a BoxWorld floor.

const DT := 1.0 / 60.0
const AEG := "000002"
const SMG := "000026"
const LIPO := "000015"
const RED_DOT := "000007"
const TIGHT_BORE := "000016"

var tuning: SimTuning = SimTuning.new()
var g: GrenadeConfig = tuning.grenades
var bots: BotConfig = BotConfig.load_default()
var loadout: Array[ReplicaConfig] = []
var rules: LoadoutRules


func before_all() -> void:
	loadout = ReplicaStats.default_loadout()


func before_each() -> void:
	rules = LoadoutRules.new(Pool.read_file(), ReplicaStats.read_file(), ReplicaRulesConfig.new())
	rules.dev_content = true


# --- The data rows ---


func test_the_changed_rows_read_as_written_a_negative_energy_too() -> void:
	var stats := ReplicaStats.read_file()
	assert_eq(stats.problems.size(), 0, "stats.md reads clean: %s" % [stats.problems])
	var bore := stats.parts.part(&"barrel", &"tightBore")
	assert_almost_eq(bore.energy, -0.05, 1e-6, "the tight bore's -5 %")
	assert_almost_eq(bore.spread, 0.8, 1e-6, "RP1: a fifth tighter (0.85 in PP1)")
	assert_almost_eq(stats.power(LIPO).recoil, 0.30, 1e-6, "the LiPo's recoil (RP1: 30 %; 10 % in PP1)")
	assert_almost_eq(stats.power(LIPO).fire_rate, 0.15, 1e-6)
	assert_almost_eq(stats.parts.part(&"optic", &"redDot").raise, 0.85, 1e-6, "the red dot's quick raise")
	assert_almost_eq(stats.replica_config(&"sniper").hip_spread, 10.0, 1e-6)


func test_a_tight_bore_carries_five_percent_less_energy_and_a_lipo_more_recoil() -> void:
	var bare := rules.default_loadout("A")
	assert_true(rules.equip(bare, Loadout.Slot.PRIMARY, AEG))
	var plain := rules.carried(bare).replicas[0]
	var fitted := rules.default_loadout("B")
	assert_true(rules.equip(fitted, Loadout.Slot.PRIMARY, AEG))
	assert_true(rules.set_part(fitted, AEG, &"barrel", TIGHT_BORE))
	assert_true(rules.set_power(fitted, AEG, LIPO))
	var r := rules.carried(fitted).replicas[0]
	assert_almost_eq(r.muzzle_energy, plain.muzzle_energy * 0.95, 1e-4, "less energy for the tighter groups")
	assert_almost_eq(r.recoil_deg, plain.recoil_deg * (1.0 + rules.stats.power(LIPO).recoil), 1e-5,
			"the LiPo's recoil on top")
	assert_gt(r.recoil_deg, plain.recoil_deg)
	assert_almost_eq(r.fire_rate, plain.fire_rate * 1.15, 1e-4)


func test_a_red_dot_raises_quicker_than_the_iron_sights() -> void:
	var irons := rules.default_loadout("A")
	assert_true(rules.equip(irons, Loadout.Slot.PRIMARY, AEG))
	var dot := rules.default_loadout("B")
	assert_true(rules.equip(dot, Loadout.Slot.PRIMARY, AEG))
	assert_true(rules.set_part(dot, AEG, &"optic", RED_DOT))
	assert_almost_eq(rules.carried(dot).replicas[0].raise_scale,
			rules.carried(irons).replicas[0].raise_scale * 0.85, 1e-5)


func test_the_smg_keeps_its_factory_hop_up_and_loses_its_best() -> void:
	var smg := rules.config(rules.pool.item(SMG))
	var old := smg.duplicate() as ReplicaConfig
	old.hop_up_max = 0.2
	old.hop_up_dial = 0.65
	var rr := tuning.replica_rules
	assert_almost_eq(Ballistics.hop_up_lift(smg, smg.hop_up_dial, rr), Ballistics.hop_up_lift(old, old.hop_up_dial, rr),
			0.005, "factory lift about as before")
	assert_almost_eq(snappedf(smg.hop_up_dial, rr.hop_up_dial_step), smg.hop_up_dial, 1e-6, "on a dial notch")
	var now := Ballistics.hop_up_reach(smg, smg.hop_up_dial, tuning, DT, 0.15, 80.0).on_target_to
	var was := Ballistics.hop_up_reach(old, old.hop_up_dial, tuning, DT, 0.15, 80.0).on_target_to
	assert_almost_eq(now, was, 0.5, "factory reach unchanged (%.2f m, was %.2f m)" % [now, was])
	var best := 0.0
	var best_was := 0.0
	for i in 21:
		best = maxf(best, Ballistics.hop_up_reach(smg, i / 20.0, tuning, DT, 0.15, 80.0).on_target_to)
		best_was = maxf(best_was, Ballistics.hop_up_reach(old, i / 20.0, tuning, DT, 0.15, 80.0).on_target_to)
	assert_lt(best, best_was - 2.0, "its best reach cut (%.1f m, was %.1f m)" % [best, best_was])
	assert_gt(best, now, "the dial still has some reach above factory")


# --- Someone else's flash ---


## A floor 60 m by 60 m.
func _world() -> BoxWorld:
	var w := BoxWorld.new(tuning.body)
	w.add_floor(60.0, 60.0)
	return w


## The bot (character 0, team 0, facing -Z at the origin), a teammate (1) far off and an enemy (2) at `foe_at`:
## [Simulation, GameState, Bot, BotWorld]. The bot's skill turns from every flash it judges.
func _match(foe_at: Vector3) -> Array:
	var world := _world()
	var ends: Array[MapEnd] = []
	for e in 2:
		var end := MapEnd.new()
		end.spawns.append(SpawnPoint.new(Vector3(-20.0 if e == 0 else 20.0, 0.0, 20.0), 0.0))
		end.dead_zone.append(SpawnPoint.new(Vector3(-25.0 if e == 0 else 25.0, 0.0, 25.0), 0.0))
		ends.append(end)
	var sim := Simulation.new(tuning, world, world.mover(), ends, -10.0)
	var s := GameState.new(5, tuning)
	s.characters.append(Character.new(0, 0, Vector3.ZERO, 0.0, loadout))
	s.characters.append(Character.new(1, 0, Vector3.ZERO, 0.0, loadout))
	s.characters.append(Character.new(2, 1, Vector3.ZERO, 0.0, loadout))
	sim.start_match(s)
	_place(s.characters[0], Vector3(0.0, tuning.body.rest_gap, 0.0), 0.0)
	_place(s.characters[1], Vector3(-25.0, tuning.body.rest_gap, 25.0), 0.0)
	_place(s.characters[2], foe_at + Vector3(0.0, tuning.body.rest_gap, 0.0), PI)
	var w := BotWorld.new()
	w.tuning = tuning
	w.cfg = bots
	w.query = world
	w.planner = RoundPlanner.new(1)
	w.characters = s.characters
	w.grenades = s.grenades
	w.time = s.time
	var skill := bots.skill_for(&"hard").duplicate() as BotSkill
	skill.smoke_chance = 0.0
	skill.flash_chance = 0.0
	skill.flash_dodge_chance = 1.0
	var b := Bot.new(s.characters[0], 11, skill, s.characters.size())
	return [sim, s, b, w]


static func _place(c: Character, at: Vector3, yaw: float) -> void:
	c.position = at
	c.prev_position = at
	c.velocity = Vector3.ZERO
	c.yaw = yaw
	c.pitch = 0.0


## A flash bomb of `owner`'s lying at `at`, its fuse just lit.
func _flash_at(m: Array, at: Vector3, owner: int) -> void:
	var s: GameState = m[1]
	for bomb in s.grenades:
		if bomb.active:
			continue
		bomb.active = true
		bomb.kind = Grenade.Kind.FLASH
		bomb.owner = owner
		bomb.position = at
		bomb.prev_position = at
		bomb.velocity = Vector3.ZERO
		bomb.age = 0.0
		bomb.resting = true
		bomb.popped = false
		return


## `ticks` ticks of the bot's bombs only; returns how many of them it was busy with a bomb.
func _run(m: Array, ticks: int) -> int:
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var b: Bot = m[2]
	var w: BotWorld = m[3]
	var cmds: Array[PlayerCommand] = []
	for c in s.characters:
		cmds.append(PlayerCommand.new())
	var busy := 0
	for t in ticks:
		w.time = s.time
		for i in cmds.size():
			cmds[i].reset(s.characters[i].yaw, s.characters[i].pitch)
		BotBombs.step(b, w, s.characters[2], cmds[0], DT)
		if BotBombs.busy(b, w):
			busy += 1
		sim.step(s, cmds, DT)
	return busy


func _fuse_ticks() -> int:
	return roundi((g.flash_fuse + 0.4) / DT)


func test_its_own_flash_is_not_judged_and_takes_no_roll() -> void:
	var m := _match(Vector3(0.0, 0.0, -30.0))
	var b: Bot = m[2]
	var state := b.bomb_rng.state
	_flash_at(m, Vector3(0.0, 0.1, -5.0), 0)
	assert_eq(_run(m, _fuse_ticks()), 0, "never busy with its own flash lying there")
	assert_eq(b.bomb_rng.state, state, "no roll taken")


func test_a_teammate_s_flash_is_turned_from_as_someone_else_s() -> void:
	var m := _match(Vector3(0.0, 0.0, -30.0))
	var s: GameState = m[1]
	_flash_at(m, Vector3(0.0, 0.1, -5.0), 1)
	_run(m, _fuse_ticks())
	assert_eq(s.characters[0].dazzle_left, 0.0, "looked away from its mate's bang")


func test_a_flash_past_the_reach_is_not_judged() -> void:
	var m := _match(Vector3(0.0, 0.0, -30.0))
	var b: Bot = m[2]
	_flash_at(m, Vector3(0.0, 0.1, -(bots.flash_dodge_reach + 1.0)), 2)
	assert_eq(_run(m, _fuse_ticks()), 0)
	assert_eq(b.flash_judged_until, -INF)


func test_a_flash_behind_it_does_not_freeze_it() -> void:
	# Behind (behind_share 0) a bang can't dazzle it and it can't see it: winning the roll must not leave it standing
	# still, its trigger let go, for the whole fuse.
	var m := _match(Vector3(0.0, 0.0, -10.0))
	_flash_at(m, Vector3(0.0, 0.1, 5.0), 2)
	assert_eq(_run(m, _fuse_ticks()), 0, "not busy with a flash behind it")


func test_reset_forgets_a_judged_flash() -> void:
	var m := _match(Vector3(0.0, 0.0, -30.0))
	var b: Bot = m[2]
	_flash_at(m, Vector3(0.0, 0.1, -5.0), 2)
	_run(m, 5)
	assert_gt(b.flash_judged_until, 0.0, "judged")
	b.reset(0, 0, 0.0, bots)
	assert_eq(b.flash_judged_until, -INF)
	assert_eq(b.bomb_away_until, -INF)



## Between close_awareness and flash_dodge_reach, so only the view cone decides whether it sees one.
func _mid_reach() -> float:
	return (bots.close_awareness + bots.flash_dodge_reach) * 0.5


func test_a_sooner_flash_out_of_view_does_not_hide_a_later_one_in_view() -> void:
	var m := _match(Vector3(0.0, 0.0, -30.0))
	var b: Bot = m[2]
	var s: GameState = m[1]
	var d := _mid_reach()
	assert_gt(d, bots.close_awareness, "precondition: past close awareness")
	_flash_at(m, Vector3(0.0, 0.1, d), 2)
	s.grenades[0].age = 1.0
	_flash_at(m, Vector3(0.0, 0.1, -d), 2)
	_run(m, 1)
	assert_almost_eq(b.flash_judged_until, g.flash_fuse, 0.05, "the one in view judged, the sooner one behind skipped")
	assert_gt(b.bomb_away_until, g.flash_fuse, "and turned from")


func test_of_two_flashes_in_view_it_turns_from_the_sooner_one_s_bearing() -> void:
	var m := _match(Vector3(0.0, 0.0, -30.0))
	var b: Bot = m[2]
	var s: GameState = m[1]
	var d := _mid_reach()
	var off := deg_to_rad(bots.fov_deg) * 0.25
	var right := Vector3(d * sin(off), 0.1, -d * cos(off))
	var left := Vector3(-d * sin(off), 0.1, -d * cos(off))
	_flash_at(m, right, 2)
	_flash_at(m, left, 2)
	s.grenades[1].age = 1.0
	_run(m, 1)
	var eye := BotSenses.eye_of(s.characters[0], tuning)
	assert_almost_eq(b.bomb_away_yaw, atan2(left.x - eye.x, left.z - eye.z), 0.01, "the sooner (second in the pool)")
	assert_ne(snappedf(b.bomb_away_yaw, 0.01), snappedf(atan2(right.x - eye.x, right.z - eye.z), 0.01))


func test_two_flashes_banging_together_take_one_roll() -> void:
	var m := _match(Vector3(0.0, 0.0, -30.0))
	var b: Bot = m[2]
	var d := _mid_reach()
	_flash_at(m, Vector3(1.0, 0.1, -d), 2)
	_flash_at(m, Vector3(-1.0, 0.1, -d), 2)
	var state := b.bomb_rng.state
	_run(m, 1)
	var once := RandomNumberGenerator.new()
	once.state = state
	once.randf()
	assert_eq(b.bomb_rng.state, once.state, "one roll for the pair, not one each")
	assert_almost_eq(b.flash_judged_until, g.flash_fuse, 0.05)
