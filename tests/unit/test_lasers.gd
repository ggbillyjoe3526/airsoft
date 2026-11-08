extends GutTest
## Dev › Lasers (LZ1, the owner's Easter egg): the switch, off by default and a cheat; a laser's instant hit through
## the BBs' own rules (game/sim/bb_step.gd); the bots' aim with no flight to lead (game/ai/bot_combat.gd); the beam's
## flashes (game/play/laser_beams.gd); and, above all, BBs exactly as they were with the switch off.

const DT := 1.0 / 60.0
const KILL_Y := -10.0
const MASS := 0.25e-3
const SPEED := 88.0
const CHEST := 1.3
const END_X := 10.0
const DEAD_ZONE_X := 14.0

var tuning: SimTuning = SimTuning.new()
var events: SimEvents = SimEvents.new()
var ends: Array[MapEnd] = []
var loadout: Array[ReplicaConfig] = []
## The most BBs in flight at once over the last _scripted match.
var _most_in_flight: int = 0


func before_all() -> void:
	loadout = ReplicaStats.default_loadout()


func before_each() -> void:
	tuning = SimTuning.new()
	# The built-in volume's known shape (a chest 0.2 m round), as test_bb_step.gd.
	tuning.hits.fit = null
	events = SimEvents.new()


## A wall filling the plane z = wall_z (BBs and lasers travel towards -Z), of `surface`.
class WallAt:
	extends WorldQuery
	var wall_z: float = 0.0
	var surface: RayHit.Surface = RayHit.Surface.METAL

	func _init(z: float) -> void:
		wall_z = z

	func ray(from: Vector3, to: Vector3, hit: RayHit) -> bool:
		if to.z >= from.z:
			return false
		var f := (wall_z - from.z) / (to.z - from.z)
		if f < 0.0 or f > 1.0:
			return false
		hit.fraction = f
		hit.position = from.lerp(to, f)
		hit.normal = Vector3.BACK
		hit.surface = surface
		return true


## Shooter (team 0, id 0) at the origin and a character of `team` (id 1, 2 …) at each z of `zs`.
func line_up(zs: Array[float], team: int = 1) -> Array[Character]:
	var roster: Array[Character] = [Character.new(0, 0, Vector3.ZERO, 0.0)]
	for z: float in zs:
		roster.append(Character.new(roster.size(), team, Vector3(0.0, 0.0, z), 0.0))
	return roster


## A laser `height` m up (chest-high) from character 0 along -Z, resolved by one BBStep tick.
func laser(roster: Array[Character], query: WorldQuery = WorldQuery.new(), cease_fire: bool = false,
		height: float = CHEST) -> BB:
	var pool := BBPool.new(4)
	var bb := pool.spawn(0, Vector3(0.0, height, 0.0), Vector3.FORWARD, SPEED, 0.0, MASS, tuning.ballistics.spin_per_hop, 0)
	bb.laser = true
	BBStep.step(pool, roster, query, tuning, KILL_Y, cease_fire, ends, events, DT)
	return bb


# --- The switch ---


func test_lasers_are_off_by_default_everywhere() -> void:
	assert_false(DevSettings.new().lasers, "the Dev tab's switch")
	assert_false(DevCheats.new().lasers, "the simulation's cheat")
	assert_false(Character.new().lasers, "every character")
	var pool := BBPool.new(1)
	var bb := pool.spawn(0, Vector3.ZERO, Vector3.FORWARD, SPEED, 0.0, MASS, 1.0)
	assert_false(bb.laser, "a BB")
	assert_true(SettingsScreen.DEV_SWITCHES.has(&"lasers"), "a Dev tab switch")


func test_the_switch_is_saved_and_read_back_and_is_a_cheat() -> void:
	var dev := DevSettings.new()
	dev.lasers = true
	var again := DevSettings.new()
	again.from_dict(dev.to_dict())
	assert_true(again.lasers)
	assert_true(again.cheats().lasers)
	assert_true(again.cheats().any(), "a match with lasers stays out of the records")
	var stale := DevSettings.new()
	stale.from_dict({"lasers": "yes"})
	assert_false(stale.lasers, "only a saved true turns it on")


func test_switching_it_on_gives_everyone_lasers_and_off_takes_them_away() -> void:
	var state := GameState.new(1, tuning)
	for i in 4:
		state.characters.append(Character.new(i, i % 2, Vector3.ZERO, 0.0, loadout))
	var cheats := DevCheats.new()
	cheats.lasers = true
	DevCheats.apply(state, cheats, 0)
	for c in state.characters:
		assert_true(c.lasers, "the player and every bot")
	assert_true(state.off_record)
	cheats.lasers = false
	DevCheats.apply(state, cheats, 0)
	for c in state.characters:
		assert_false(c.lasers)


func test_a_recycled_bb_slot_is_a_bb_again() -> void:
	var pool := BBPool.new(1)
	pool.spawn(0, Vector3.ZERO, Vector3.FORWARD, SPEED, 0.0, MASS, 1.0).laser = true
	var bb := pool.spawn(0, Vector3.ZERO, Vector3.FORWARD, SPEED, 0.0, MASS, 1.0)
	assert_false(bb.laser, "spawn clears it")


# --- A laser's hit ---


func test_a_laser_knocks_out_a_body_40_m_off_in_the_tick_it_is_fired() -> void:
	var roster := line_up([-40.0])
	var bb := laser(roster)
	assert_false(bb.active, "free again at once")
	assert_eq(events.count_of(GameEvent.Kind.CHARACTER_HIT), 1)
	assert_ne(roster[1].status, Character.Status.ALIVE, "out and calling it")
	var beam := events.first(GameEvent.Kind.LASER)
	assert_not_null(beam)
	assert_eq(beam.actor, 0)
	assert_eq(beam.slot, 0)
	assert_almost_eq(beam.position.z, -39.8, 0.05, "the beam ends on the chest")
	assert_almost_eq(beam.reach, 39.8, 0.05)
	assert_almost_eq(beam.position.y, CHEST, 1e-5, "straight: no drop, no hop-up")


func test_a_laser_stops_on_a_wall_without_bouncing_or_ringing_a_prop() -> void:
	var roster := line_up([-40.0])
	var bb := laser(roster, WallAt.new(-12.0))
	assert_false(bb.active)
	assert_eq(bb.bounces, 0, "metal bounces a BB, never a laser")
	assert_eq(roster[1].status, Character.Status.ALIVE, "behind the wall")
	var impact := events.first(GameEvent.Kind.BB_IMPACT)
	assert_not_null(impact)
	assert_almost_eq(impact.position.z, -12.0, 1e-4)
	assert_eq(impact.value2, RayHit.Surface.METAL)
	assert_eq(impact.direction, Vector3.ZERO, "no speed: it rings no noisy prop (PropNoise.ring)")
	assert_almost_eq(events.first(GameEvent.Kind.LASER).position.z, -12.0, 1e-4)


func test_a_laser_past_its_reach_ends_in_the_air() -> void:
	var roster := line_up([-(tuning.lasers.reach + 5.0)])
	laser(roster)
	assert_eq(events.count_of(GameEvent.Kind.CHARACTER_HIT), 0)
	assert_eq(events.count_of(GameEvent.Kind.BB_IMPACT), 0)
	assert_almost_eq(events.first(GameEvent.Kind.LASER).reach, tuning.lasers.reach, 1e-3)


func test_a_laser_spares_its_shooter_teammates_and_ghosts_as_a_bb_does() -> void:
	tuning.hits.friendly_fire = false
	var mates := line_up([-10.0], 0)
	laser(mates)
	assert_eq(mates[0].status, Character.Status.ALIVE, "never its own shooter")
	assert_eq(mates[1].status, Character.Status.ALIVE, "friendly fire is off")
	assert_eq(events.first(GameEvent.Kind.BB_IMPACT).target, 1, "it stops on the teammate")
	events.clear()
	var ghosted := line_up([-10.0, -20.0])
	ghosted[1].ghost = true
	laser(ghosted)
	assert_eq(ghosted[1].status, Character.Status.ALIVE, "a ghost lets it through")
	assert_ne(ghosted[2].status, Character.Status.ALIVE, "to whoever is behind")


func test_a_laser_in_a_cease_fire_knocks_nobody_out() -> void:
	var roster := line_up([-20.0])
	laser(roster, WorldQuery.new(), true)
	assert_eq(roster[1].status, Character.Status.ALIVE)
	assert_eq(events.count_of(GameEvent.Kind.CHARACTER_HIT), 0)
	assert_eq(events.first(GameEvent.Kind.BB_IMPACT).target, 1)


func test_a_laser_goes_through_as_much_bush_as_a_bb_and_no_more() -> void:
	var thin := BoxWorld.new()
	# At the bush's middle height, through the edge 0.8 of a radius off its middle: 0.36 m of leaves, under the 0.6 m
	# that stops a BB.
	thin.add_bush(Vector3(0.24, 0.0, -10.0), 0.3, 2.0)
	var roster := line_up([-20.0])
	laser(roster, thin, false, 1.0)
	assert_ne(roster[1].status, Character.Status.ALIVE, "through a thin bush")
	events.clear()
	var two := BoxWorld.new()
	# Two such edges: 0.72 m of leaves over the line, past the BB's 0.6 m.
	two.add_bush(Vector3(0.24, 0.0, -6.0), 0.3, 2.0)
	two.add_bush(Vector3(0.24, 0.0, -12.0), 0.3, 2.0)
	roster = line_up([-20.0])
	laser(roster, two, false, 1.0)
	assert_eq(roster[1].status, Character.Status.ALIVE, "stopped in the second bush")
	var stop := events.first(GameEvent.Kind.BB_IMPACT)
	assert_eq(stop.value, BBStep.IN_LEAVES)
	assert_almost_eq(stop.position.z, -12.0, 0.2, "in the second bush")


# --- Unchanged with the switch off ---


func test_with_lasers_off_a_bb_flies_its_ballistic_path_tick_by_tick() -> void:
	var pool := BBPool.new(2)
	var bb := pool.spawn(0, Vector3(0.0, 1.5, 0.0), Vector3.FORWARD, SPEED, 0.6, MASS, tuning.ballistics.spin_per_hop)
	var twin := BB.new()
	twin.position = bb.position
	twin.velocity = bb.velocity
	twin.spin = bb.spin
	twin.spin_axis = bb.spin_axis
	twin.mass = bb.mass
	var air := AirModel.of(tuning.ballistics)
	for t in 30:
		BBStep.step(pool, [] as Array[Character], WorldQuery.new(), tuning, KILL_Y, false, ends, events, DT)
		Ballistics.step_flight(twin, air, DT, Vector3.ZERO)
		assert_true(bb.active, "still in flight at tick %d" % t)
		assert_eq(bb.position, twin.position, "exactly the ballistic step at tick %d" % t)
	assert_eq(events.count_of(GameEvent.Kind.LASER), 0)


## End 0 in the west facing east, end 1 in the east facing west (as test_simulation.gd).
func _ends() -> Array[MapEnd]:
	var out: Array[MapEnd] = []
	for e in 2:
		var side := -1.0 if e == 0 else 1.0
		var facing := -PI / 2.0 if e == 0 else PI / 2.0
		var end := MapEnd.new()
		for i in 3:
			end.spawns.append(SpawnPoint.new(Vector3(side * END_X, 0.0, (i - 1) * 2.0), facing))
			end.dead_zone.append(SpawnPoint.new(Vector3(side * DEAD_ZONE_X, 0.0, 10.0 + i), facing))
		out.append(end)
	return out


## A busy 3v3 of `ticks` on seed 1234, everyone strafing and firing auto at someone across, with `lasers` given to
## DevCheats.apply before the start (null: never applied) and taken away after `off_after` ticks (-1: kept).
func _scripted(ticks: int, lasers: Variant, off_after: int = -1) -> GameState:
	var w := BoxWorld.new(tuning.body)
	w.add_floor(60.0, 30.0)
	var sim := Simulation.new(tuning, w, w.mover(), _ends(), KILL_Y)
	var state := GameState.new(1234, tuning)
	for i in 6:
		state.characters.append(Character.new(i, i % 2, Vector3.ZERO, 0.0, loadout))
	var cheats := DevCheats.new()
	if lasers != null:
		cheats.lasers = lasers
		DevCheats.apply(state, cheats, 0)
	sim.start_match(state)
	var cmds: Array[PlayerCommand] = []
	for c in state.characters:
		var cmd := PlayerCommand.new()
		cmd.reset(c.yaw, c.pitch)
		cmds.append(cmd)
	for t in ticks:
		if t == off_after:
			cheats.lasers = false
			DevCheats.apply(state, cheats, 0)
		for c in state.characters:
			var cmd := cmds[c.id]
			var foe := state.characters[(c.id + 1) % state.characters.size()]
			var d := foe.position + Vector3(0.0, CHEST, 0.0) - c.eye(tuning.body)
			cmd.yaw = atan2(-d.x, -d.z)
			cmd.pitch = atan2(d.y, Vector2(d.x, d.z).length())
			cmd.right = 1.0 if (t / 90) % 2 == 0 else -1.0
			cmd.fire = t > 30
			cmd.reload = c.armament.mag() == 0
		sim.step(state, cmds, DT)
		_most_in_flight = maxi(_most_in_flight, state.bbs.active_count())
	return state


func _same_match(a: GameState, b: GameState) -> void:
	for i in a.characters.size():
		assert_eq(a.characters[i].position, b.characters[i].position, "character %d where it was" % i)
		assert_eq(a.characters[i].status, b.characters[i].status, "character %d as it was" % i)
	for i in a.bbs.bbs.size():
		assert_eq(a.bbs.bbs[i].active, b.bbs.bbs[i].active, "BB %d" % i)
		assert_eq(a.bbs.bbs[i].position, b.bbs.bbs[i].position, "BB %d" % i)
		assert_eq(a.bbs.bbs[i].velocity, b.bbs.bbs[i].velocity, "BB %d" % i)
	assert_eq(a.round_state.score, b.round_state.score)
	assert_eq(a.rng.state, b.rng.state, "the same draws from the match's stream")


func test_with_lasers_off_a_match_plays_exactly_as_one_never_switched() -> void:
	for ticks: int in [300, 900]:
		_most_in_flight = 0
		_same_match(_scripted(ticks, null), _scripted(ticks, false))
		assert_gt(_most_in_flight, 1, "BBs flew: the comparison covers flight")


func test_lasers_switched_off_leave_every_shot_after_a_bb() -> void:
	var on_then_off := _scripted(900, true, 600)
	assert_false(on_then_off.characters[0].lasers)
	var flown := 0
	for bb in on_then_off.bbs.bbs:
		assert_false(bb.laser and bb.active, "no laser left in flight")
		if bb.active:
			flown += 1
	assert_gt(flown, 0, "BBs in flight again")


func test_a_laser_takes_the_same_spread_draw_as_the_bb_it_replaces() -> void:
	# Everyone's first shot is tick 31; a laser's hit lands after every shot of that tick is fired.
	var bbs := _scripted(32, false)
	var lasers := _scripted(32, true)
	assert_eq(bbs.rng.state, lasers.rng.state, "the same shots drew the same spread")


func test_a_busy_laser_tick_allocates_no_objects_once_warm() -> void:
	var w := BoxWorld.new(tuning.body)
	w.add_floor(60.0, 30.0)
	var sim := Simulation.new(tuning, w, w.mover(), _ends(), KILL_Y)
	var state := GameState.new(7, tuning)
	for i in 6:
		state.characters.append(Character.new(i, i % 2, Vector3.ZERO, 0.0, loadout))
	var cheats := DevCheats.new()
	cheats.lasers = true
	DevCheats.apply(state, cheats, 0)
	sim.start_match(state)
	var cmds: Array[PlayerCommand] = []
	for c in state.characters:
		var cmd := PlayerCommand.new()
		cmd.reset(c.yaw, c.pitch)
		cmds.append(cmd)
	var steps := func(ticks: int) -> void:
		for t in ticks:
			for c in state.characters:
				var foe := state.characters[(c.id + 1) % state.characters.size()]
				var d := foe.position + Vector3(0.0, CHEST, 0.0) - c.eye(tuning.body)
				cmds[c.id].yaw = atan2(-d.x, -d.z)
				cmds[c.id].pitch = atan2(d.y, Vector2(d.x, d.z).length())
				cmds[c.id].fire = true
				cmds[c.id].right = 1.0
				cmds[c.id].reload = c.armament.mag() == 0
			sim.step(state, cmds, DT)
	steps.call(240)
	var before := Performance.get_monitor(Performance.OBJECT_COUNT)
	steps.call(600)
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), before)


# --- The bots ---


func _bot(lasers: bool) -> Array:
	var me := Character.new(0, 0, Vector3.ZERO, 0.0, loadout)
	me.lasers = lasers
	var w := BotWorld.new()
	w.tuning = tuning
	w.cfg = BotConfig.load_default()
	w.characters = [me]
	return [Bot.new(me, 1, w.cfg.skill_for(&"normal"), 1), w]


func test_a_bot_leads_by_its_bbs_flight_and_not_at_all_with_a_laser() -> void:
	var with_bbs := _bot(false)
	var b: Bot = with_bbs[0]
	var a := b.character.armament
	var r := a.replica()
	var grams := a.bb_weights[a.active]
	var expected := Ballistics.flight_time_estimate(30.0, Ballistics.muzzle_velocity(r, tuning.replica_rules, grams),
			Ballistics.bb_mass(r, grams), tuning.ballistics)
	assert_eq(BotCombat.flight_time(b, with_bbs[1], 30.0), expected, "with BBs, as before")
	assert_gt(expected, 0.0)
	var with_lasers := _bot(true)
	assert_eq(BotCombat.flight_time(with_lasers[0], with_lasers[1], 30.0), 0.0, "a laser has no flight")


# --- The beam ---


func test_full_auto_keeps_the_beam_on_between_every_shot() -> void:
	var cfg := EffectsConfig.new()
	for rate: float in [7.0, 13.0, 14.0, 15.0]:
		# Shots land on whole ticks: the longest gap is the rate's gap rounded up to the next tick.
		var longest := ceilf((1.0 / rate) / DT) * DT
		assert_gt(LaserBeams.hold_time(cfg, ReplicaConfig.FireMode.AUTO, rate), longest, "%d a second" % rate)


func test_a_burst_flashes_three_times_apart_and_a_single_shot_once() -> void:
	var cfg := EffectsConfig.new()
	for rate: float in [7.0, 13.0, 14.0, 15.0]:
		var shortest := floorf((1.0 / rate) / DT) * DT
		var flash := LaserBeams.hold_time(cfg, ReplicaConfig.FireMode.BURST, rate)
		assert_gt(flash, 0.0)
		assert_lt(flash, shortest, "off before the next shot of the burst at %d a second" % rate)
	assert_eq(LaserBeams.hold_time(cfg, ReplicaConfig.FireMode.SEMI, 0.8), cfg.laser_flash_time, "a spring rifle")
	assert_lt(LaserBeams.hold_time(cfg, ReplicaConfig.FireMode.SEMI, 14.0), 1.0 / 14.0, "fast clicks flash apart")
