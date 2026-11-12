extends GutTest
## QA for PH1: the edges of the moving-body sweep (BBStep._first_body), a kit's gas energy across fields, the maps'
## weather cells and the BB weight share at the ends of the range.

const DT := 1.0 / 60.0
const KILL_Y := -10.0
const MASS := 0.25e-3
const CHEST := 1.3

var tuning: SimTuning = null
var events: SimEvents = null
var no_wall: WorldQuery = WorldQuery.new()
var ends: Array[MapEnd] = []


## A wall `at` m down -Z of the BB's start: the level the BB meets nearer than a body behind it.
class WallQuery:
	extends WorldQuery
	var at: float = 0.5

	func bb_ray(from: Vector3, to: Vector3, hit: RayHit) -> bool:
		var length := from.distance_to(to)
		if from.z > -at and to.z <= -at and length > 0.0:
			hit.fraction = (from.z + at) / (from.z - to.z)
			hit.surface = 0
			return true
		return false


func before_each() -> void:
	tuning = SimTuning.new()
	tuning.hits.fit = null
	events = SimEvents.new()


func rules() -> LoadoutRules:
	return LoadoutRules.new(Pool.read_file(), ReplicaStats.read_file(), tuning.replica_rules)


func shot(pool: BBPool, speed: float, owner_id: int = 1) -> BB:
	return pool.spawn(owner_id, Vector3(0.0, CHEST, 0.0), Vector3.FORWARD, speed, 0.0, MASS,
			tuning.ballistics.spin_per_hop)


## A body (id 2, the other team) at `at` at the tick's end, having stepped `step` this tick; the shooter is id 1.
func roster(at: Vector3, step: Vector3) -> Array[Character]:
	var body := Character.new(2, 1, at - step, 0.0)
	body.prev_position = body.position
	body.position = at
	return [Character.new(1, 0, Vector3(0.0, 0.0, 5.0), 0.0), body]


func fly(pool: BBPool, characters: Array[Character], world: WorldQuery = null) -> void:
	BBStep.step(pool, characters, world if world != null else no_wall, tuning, KILL_Y, false, ends, events, DT)


func kinds() -> Array:
	var out := []
	for i in events.count:
		out.append(events.items[i].kind)
	return out


# --- The moving-body sweep ---


func test_a_bb_meets_a_body_walking_at_it_where_both_were_at_that_moment() -> void:
	# The BB flies 1.5 m this tick; the body, 1.1 m ahead, walks 0.1 m towards it. They meet when the BB has gone
	# (1.1 - r) * 1.5 / 1.6 m, not at the (1.0 - r) the body's end-of-tick spot would give.
	var r := tuning.hits.body_radius
	var pool := BBPool.new(2)
	var bb := shot(pool, 90.0)
	var chars := roster(Vector3(0.0, 0.0, -1.0), Vector3(0.0, 0.0, 0.1))
	fly(pool, chars)
	assert_false(bb.active)
	assert_true(kinds().has(GameEvent.Kind.CHARACTER_HIT))
	var flown := bb.position.distance_to(Vector3(0.0, CHEST, 0.0))
	assert_almost_eq(flown, (1.1 - r) * 1.5 / 1.6, 0.01, "the distance is rescaled by the BB's travel per body-frame metre")


func test_a_bb_that_keeps_pace_with_a_body_walking_away_never_hits_it_or_errors() -> void:
	# 6 m/s is 0.1 m a tick: the body steps away exactly as far as the BB flies, so in its frame the BB stands still.
	var pool := BBPool.new(2)
	var bb := shot(pool, 6.0)
	var chars := roster(Vector3(0.0, 0.0, -0.45), Vector3(0.0, 0.0, -0.1))
	for t in 3:
		fly(pool, chars)
		chars[1].prev_position = chars[1].position
		chars[1].position += Vector3(0.0, 0.0, -0.1)
	assert_true(bb.active)
	assert_false(kinds().has(GameEvent.Kind.CHARACTER_HIT))


func test_the_shooter_stepping_across_its_own_bb_is_never_hit_but_a_bounced_bb_can_hit_it() -> void:
	var pool := BBPool.new(2)
	var bb := shot(pool, 90.0)
	var chars: Array[Character] = [Character.new(1, 0, Vector3(0.0, 0.0, -0.5), 0.0),
			Character.new(2, 1, Vector3(5.0, 0.0, 5.0), 0.0)]
	chars[0].prev_position = chars[0].position - Vector3(0.1, 0.0, 0.0)
	fly(pool, chars)
	assert_true(bb.active, "its own BB passes through the shooter")
	bb.bounces = 1
	bb.position = Vector3(0.0, CHEST, 0.0)
	bb.velocity = Vector3(0.0, 0.0, -90.0)
	fly(pool, chars)
	assert_false(bb.active, "once bounced it hits whoever is there, the shooter too")


func test_a_ghost_walking_into_the_line_is_not_hit() -> void:
	var pool := BBPool.new(2)
	var bb := shot(pool, 90.0)
	var chars := roster(Vector3(0.0, 0.0, -0.8), Vector3(0.1, 0.0, 0.0))
	chars[1].ghost = true
	fly(pool, chars)
	assert_true(bb.active)


func test_a_wall_nearer_than_a_moving_body_stops_the_bb_first() -> void:
	var wall := WallQuery.new()
	wall.at = 0.4
	var pool := BBPool.new(2)
	var bb := shot(pool, 90.0)
	var chars := roster(Vector3(0.0, 0.0, -1.2), Vector3(0.1, 0.0, 0.0))
	fly(pool, chars, wall)
	assert_false(bb.active)
	assert_false(kinds().has(GameEvent.Kind.CHARACTER_HIT), "the wall is nearer than the body")


func test_a_body_that_moved_a_stride_or_more_is_met_where_it_stands_not_swept() -> void:
	# At exactly max_stride the body is a teleport: tested as it stands (the BB on its line hits).
	var pool := BBPool.new(2)
	shot(pool, 90.0)
	var chars := roster(Vector3(0.0, 0.0, -0.8), Vector3(tuning.hits.max_stride, 0.0, 0.0))
	chars[1].position.x = 0.0
	chars[1].prev_position = Vector3(-tuning.hits.max_stride, 0.0, -0.8)
	fly(pool, chars)
	assert_true(kinds().has(GameEvent.Kind.CHARACTER_HIT))


func test_a_sweep_gives_the_same_result_every_time() -> void:
	var results := []
	for run in 2:
		var pool := BBPool.new(2)
		var bb := shot(pool, 90.0)
		var chars := roster(Vector3(0.1, 0.0, -0.9), Vector3(0.11, 0.0, 0.03))
		events.clear()
		fly(pool, chars)
		results.append([bb.position, bb.active, kinds()])
	assert_eq(results[0], results[1])


# --- Gas, weather and weights ---


func test_a_capped_gas_replica_in_the_cold_never_shoots_past_its_limit_and_is_repeatable() -> void:
	var r := rules()
	var l := r.default_loadout("x")
	var kit := r.carried(l)
	assert_eq(kit.replicas[1].power, &"gas")
	# A site that would have capped it: the limit under the energy as built.
	kit.limits[1] = kit.energies[1] * 0.9
	kit.replicas[1].muzzle_energy = kit.limits[1]
	var limit := kit.limits[1]
	for temp: float in [-30.0, 0.0, 20.0, 35.0, 80.0]:
		kit.set_temperature(tuning.weather, temp, 20.0)
		var want := minf(kit.energies[1] * tuning.weather.gas_energy_scale(temp, 20.0), limit)
		assert_almost_eq(kit.replicas[1].muzzle_energy, want, 1e-9, "at %s" % temp)
		assert_lte(kit.replicas[1].muzzle_energy, limit + 1e-9)
	kit.set_temperature(tuning.weather, 20.0, 20.0)
	assert_almost_eq(kit.replicas[1].muzzle_energy, limit, 1e-9, "back at the rated air it is at its limit again")


func test_a_kit_without_energies_or_with_fewer_slots_than_energies_is_left_alone() -> void:
	var r := rules()
	var kit := r.carried(r.default_loadout("x"))
	var pistol := kit.replicas[1].muzzle_energy
	kit.replicas.resize(1)
	kit.set_temperature(tuning.weather, 0.0, 20.0)
	assert_eq(kit.size(), 1)
	var bare := Kit.new()
	bare.replicas.append(ReplicaStats.default_loadout()[1].duplicate() as ReplicaConfig)
	var before := bare.replicas[0].muzzle_energy
	bare.set_temperature(tuning.weather, 0.0, 20.0)
	assert_eq(bare.replicas[0].muzzle_energy, before, "no energies recorded: nothing to work from")
	assert_gt(pistol, 0.0)


func test_one_kit_chilled_does_not_chill_the_next_one_carried() -> void:
	var r := rules()
	var l := r.default_loadout("x")
	var first := r.carried(l)
	var rated := first.replicas[1].muzzle_energy
	first.set_temperature(tuning.weather, -10.0, 20.0)
	var second := r.carried(l)
	assert_almost_eq(second.replicas[1].muzzle_energy, rated, 1e-9)


func test_the_weight_share_is_one_at_the_factory_weight_and_grows_with_the_bb() -> void:
	var replica := ReplicaStats.default_loadout()[0]
	var rr := tuning.replica_rules
	assert_almost_eq(Ballistics.weight_energy_share(replica, rr, replica.bb_weight), 1.0, 1e-12)
	assert_almost_eq(Ballistics.weight_energy_share(replica, rr), 1.0, 1e-12, "no weight given: the factory's")
	var last := 0.0
	for g: float in [rr.bb_weight_min, 0.25, 0.3, 0.35, rr.bb_weight_max]:
		var share := Ballistics.weight_energy_share(replica, rr, g)
		assert_gt(share, 0.0)
		assert_gt(share, last, "heavier loads take more of the push at %s g" % g)
		last = share
	assert_lt(Ballistics.weight_energy_share(replica, rr, rr.bb_weight_min), 1.0)
	assert_gt(Ballistics.weight_energy_share(replica, rr, rr.bb_weight_max), 1.0)


func test_a_weather_cell_at_the_edge_of_its_range_reads_and_just_outside_it_does_not() -> void:
	var text := """## Maps
| Id | Name | Kind | Tag | Min | Standard | Max | Wind (×) | Air (°C) | Blurb |
|---|---|---|---|---|---|---|---|---|---|
| lo | Lo | field | public | 1 | 3 | 3 | 0 | -10 | Edge. |
| hi | Hi | field | public | 1 | 3 | 3 | 2 | 40 | Edge. |
| neg | Neg | field | public | 1 | 3 | 3 | -0.5 | -10.5 | Under. |
| big | Big | field | public | 1 | 3 | 3 | 2.1 | 41 | Over. |
| junk | Junk | field | public | 1 | 3 | 3 | 1.5x | warm | Words. |
| inf | Inf | field | public | 1 | 3 | 3 | inf | nan | Not finite. |
"""
	var m := MapCatalog.parse(text)
	assert_eq(m.find("lo").wind, 0.0)
	assert_eq(m.find("lo").air, -10.0)
	assert_eq(m.find("hi").wind, 2.0)
	assert_eq(m.find("hi").air, 40.0)
	for id: String in ["neg", "big", "junk", "inf"]:
		assert_eq(m.find(id).wind, 1.0, "%s keeps the built-in wind" % id)
		assert_true(is_nan(m.find(id).air), "%s keeps the built-in air" % id)
		assert_eq(m.find(id).air_or(20.0), 20.0)
	assert_eq(m.problems.size(), 8, str(m.problems))


func test_a_breeze_scaled_by_a_negative_share_is_still_not_reversed() -> void:
	var sim := Simulation.new(tuning, no_wall, CharacterMover.new(), ends, KILL_Y)
	var state := GameState.new(5, tuning)
	sim.set_weather(state, -1.0, 12.0)
	assert_eq(state.wind_share, 0.0)
	sim.start_match(state)
	assert_eq(state.wind.speed, 0.0)
	# A new match on the same state keeps the field's share and air.
	sim.start_match(state)
	assert_eq(state.wind.speed, 0.0)
	assert_eq(state.air_temperature, 12.0)
	assert_not_same(state.air, AirModel.of(tuning.ballistics))


func test_the_same_seed_draws_the_same_breeze_in_the_same_weather() -> void:
	var speeds := []
	for run in 2:
		var sim := Simulation.new(tuning, no_wall, CharacterMover.new(), ends, KILL_Y)
		var state := GameState.new(77, tuning)
		sim.set_weather(state, 1.5, 3.0)
		sim.start_match(state)
		speeds.append([state.wind.speed, state.wind.yaw])
		assert_lte(state.wind.speed, tuning.wind.max_speed * 1.5 + 1e-9)
	assert_eq(speeds[0], speeds[1])
