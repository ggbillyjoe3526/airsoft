extends GutTest
## A tick of every BB in flight: flight, then the level and the bodies (game/sim/bb_step.gd; the browser game's
## sim/bbs.test.ts, bbsFirstBody.test.ts and bodyStopAndAim.test.ts). Ghosts and leans come with their tasks, and their
## cases with them; bushes are in test_bushes.gd, ricochets and wind in test_ricochet.gd and test_wind.gd, range
## targets in test_range_targets.gd.

const DT := 1.0 / 60.0
const KILL_Y := -10.0
const MASS := 0.25e-3


## A wall filling the plane z = wall_z, facing +Z (BBs travel towards -Z): plywood unless told, which a BB never
## bounces off.
class WallAt:
	extends WorldQuery
	var wall_z: float = 0.0
	var surface: RayHit.Surface = RayHit.Surface.WOOD

	func _init(z: float, made_of: RayHit.Surface = RayHit.Surface.WOOD) -> void:
		wall_z = z
		surface = made_of

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


## A level that meets every segment at its first half metre (a wall right in front of the muzzle).
class CloseWall:
	extends WorldQuery

	func ray(from: Vector3, to: Vector3, hit: RayHit) -> bool:
		var length := from.distance_to(to)
		if length <= 0.5:
			return false
		hit.fraction = 0.5 / length
		hit.position = from.lerp(to, hit.fraction)
		return true


var tuning: SimTuning = SimTuning.new()
var events: SimEvents = SimEvents.new()
var no_wall: WorldQuery = WorldQuery.new()
var ends: Array[MapEnd] = []
var nobody: Array[Character] = []


func before_each() -> void:
	tuning = SimTuning.new()
	# BBStep's rules on the built-in volume's known shape (a chest 0.2 m round); test_hit_registration holds BBStep to
	# the fitted volume (HV1).
	tuning.hits.fit = null
	events = SimEvents.new()


func spawn(pool: BBPool, owner_id: int, origin: Vector3, dir: Vector3, speed: float, hop_up: float = 0.0) -> BB:
	return pool.spawn(owner_id, origin, dir, speed, hop_up, MASS, tuning.ballistics.spin_per_hop)


func step(pool: BBPool, characters: Array[Character], query: WorldQuery = no_wall, cease_fire: bool = false) -> void:
	BBStep.step(pool, characters, query, tuning, KILL_Y, cease_fire, ends, events, DT)


## Steps until `bb` stops, at most `ticks` times.
func run(pool: BBPool, bb: BB, characters: Array[Character], query: WorldQuery = no_wall, ticks: int = 60) -> void:
	for i in ticks:
		if not bb.active:
			return
		step(pool, characters, query)


## Shooter (team 0, id 1) at the origin and a character of `team` (id 2, 3 …) at each z of `zs`, on the line out.
func line_up(zs: Array[float], team: int = 1) -> Array[Character]:
	var roster: Array[Character] = [Character.new(1, 0, Vector3.ZERO, 0.0)]
	for z: float in zs:
		roster.append(Character.new(roster.size() + 1, team, Vector3(0.0, 0.0, z), 0.0))
	return roster


## A chest-high (1.3 m) BB at 88 m/s along -Z from the shooter, stepped until it stops.
func chest_shot(roster: Array[Character], query: WorldQuery = no_wall, cease_fire: bool = false) -> BB:
	var pool := BBPool.new(4)
	var bb := spawn(pool, 1, Vector3(0.0, 1.3, 0.0), Vector3.FORWARD, 88.0)
	for i in 60:
		if not bb.active:
			break
		step(pool, roster, query, cease_fire)
	return bb


func kinds() -> Array[GameEvent.Kind]:
	var out: Array[GameEvent.Kind] = []
	for i in events.count:
		out.append(events.items[i].kind)
	return out


func test_stops_exactly_where_its_path_meets_a_wall() -> void:
	var pool := BBPool.new(4)
	var bb := spawn(pool, 0, Vector3(0, 1.5, 0), Vector3.FORWARD, 80.0, 0.12)
	run(pool, bb, nobody, WallAt.new(-12.0))
	assert_false(bb.active)
	assert_almost_eq(bb.position.z, -12.0, 1e-5)
	assert_eq(events.count_of(GameEvent.Kind.BB_IMPACT), 1)
	var impact := events.first(GameEvent.Kind.BB_IMPACT)
	assert_almost_eq(impact.position.z, -12.0, 1e-5)
	assert_eq(impact.target, -1, "a wall names no body")
	assert_eq(impact.actor, 0)


func test_does_not_tunnel_through_thin_geometry() -> void:
	var pool := BBPool.new(1)
	var bb := spawn(pool, 0, Vector3(0, 1.5, 0), Vector3.FORWARD, 88.0)
	step(pool, nobody, WallAt.new(-1.4))
	assert_false(bb.active)
	assert_eq(events.count, 1)


func test_removes_bbs_that_fly_too_long_with_only_a_bb_lost() -> void:
	var pool := BBPool.new(2)
	var up := spawn(pool, 0, Vector3(0, 1.5, 0), Vector3.UP, 40.0)
	for i in ceili(tuning.ballistics.max_lifetime / DT) + 2:
		step(pool, nobody)
	assert_false(up.active)
	assert_eq(kinds(), [GameEvent.Kind.BB_LOST] as Array[GameEvent.Kind])
	assert_eq(events.items[0].actor, 0)


func test_removes_a_bb_below_kill_y_before_its_lifetime_ends() -> void:
	var pool := BBPool.new(1)
	var bb := spawn(pool, 0, Vector3(0, KILL_Y + 1.0, 0), Vector3.DOWN, 60.0)
	for i in 5:
		step(pool, nobody)
	assert_false(bb.active)
	assert_lt(bb.age, tuning.ballistics.max_lifetime)
	assert_eq(kinds(), [GameEvent.Kind.BB_LOST] as Array[GameEvent.Kind])


func test_records_the_previous_position() -> void:
	var pool := BBPool.new(1)
	var bb := spawn(pool, 0, Vector3(0, 1.5, 0), Vector3.FORWARD, 80.0, 0.12)
	step(pool, nobody)
	var before := bb.position
	step(pool, nobody)
	assert_eq(bb.prev_position, before)


func test_eliminates_the_first_character_in_the_path() -> void:
	var roster := line_up([-10.0, -20.0])
	var bb := chest_shot(roster)
	assert_false(bb.active)
	assert_almost_eq(bb.position.z, -10.0 + tuning.hits.body_radius, 1e-3)
	assert_eq(roster[1].status, Character.Status.CALLING)
	assert_eq(roster[1].hit_by, 1)
	assert_eq(roster[2].status, Character.Status.ALIVE)
	var hit := events.first(GameEvent.Kind.CHARACTER_HIT)
	assert_not_null(hit)
	assert_eq(hit.actor, 1)
	assert_eq(hit.target, 2)
	assert_almost_eq(hit.direction.z, -1.0, 0.01)
	assert_almost_eq(hit.position, bb.position, Vector3.ONE * 1e-6)
	assert_eq(events.count_of(GameEvent.Kind.BB_IMPACT), 0)


func test_never_hits_the_shooter_and_stops_on_a_body_already_hit() -> void:
	for status: Character.Status in [Character.Status.CALLING, Character.Status.WALKING_OFF,
			Character.Status.LEAVING, Character.Status.OUT]:
		events.clear()
		var roster := line_up([-10.0, -20.0])
		roster[1].status = status
		var bb := chest_shot(roster)
		var label := Character.Status.keys()[status] as String
		assert_eq(roster[0].status, Character.Status.ALIVE, label)
		assert_eq(roster[2].status, Character.Status.ALIVE, "%s: hit through the body in front" % label)
		assert_eq(events.count_of(GameEvent.Kind.CHARACTER_HIT), 0, label)
		assert_false(bb.active, label)
		assert_almost_eq(bb.position.z, -10.0 + tuning.hits.body_radius, 1e-3, label)
		assert_eq(events.count_of(GameEvent.Kind.BB_IMPACT), 1, label)
		assert_eq(events.first(GameEvent.Kind.BB_IMPACT).target, 2, "%s: it names the body" % label)


func test_stops_on_a_teammate_when_friendly_fire_is_off() -> void:
	tuning.hits.friendly_fire = false
	var roster := line_up([-10.0], 0)
	roster.append(Character.new(3, 1, Vector3(0, 0, -20), 0.0))
	var bb := chest_shot(roster)
	assert_eq(roster[1].status, Character.Status.ALIVE)
	assert_eq(roster[2].status, Character.Status.ALIVE)
	assert_almost_eq(bb.position.z, -10.0 + tuning.hits.body_radius, 1e-3)
	assert_eq(kinds(), [GameEvent.Kind.BB_IMPACT] as Array[GameEvent.Kind])


func test_counts_friendly_hits_by_default_and_can_be_told_not_to() -> void:
	var roster := line_up([-10.0], 0)
	chest_shot(roster)
	assert_eq(roster[1].status, Character.Status.CALLING)
	tuning.hits.friendly_fire = false
	var no_ff := line_up([-10.0], 0)
	chest_shot(no_ff)
	assert_eq(no_ff[1].status, Character.Status.ALIVE)


func test_in_a_cease_fire_stops_on_the_first_body_and_knocks_nobody_out() -> void:
	var roster := line_up([-10.0, -20.0])
	var bb := chest_shot(roster, no_wall, true)
	assert_eq(roster[1].status, Character.Status.ALIVE)
	assert_eq(roster[2].status, Character.Status.ALIVE)
	assert_almost_eq(bb.position.z, -10.0 + tuning.hits.body_radius, 1e-3)
	assert_eq(kinds(), [GameEvent.Kind.BB_IMPACT] as Array[GameEvent.Kind])


func test_stops_at_a_wall_in_front_of_a_character() -> void:
	var roster := line_up([-10.0])
	chest_shot(roster, WallAt.new(-6.0))
	assert_eq(roster[1].status, Character.Status.ALIVE)
	assert_eq(kinds(), [GameEvent.Kind.BB_IMPACT] as Array[GameEvent.Kind])


func test_hits_a_character_standing_right_in_front_of_a_wall() -> void:
	var roster := line_up([-10.0])
	chest_shot(roster, WallAt.new(-10.1))
	assert_eq(roster[1].status, Character.Status.CALLING)


func test_flies_over_a_crouched_character() -> void:
	var standing := line_up([-5.0])
	chest_shot(standing)
	assert_eq(standing[1].status, Character.Status.CALLING)
	var crouched := line_up([-5.0])
	crouched[1].crouch_amount = 1.0
	chest_shot(crouched)
	assert_eq(crouched[1].status, Character.Status.ALIVE)


func test_flies_over_a_crouched_bot_and_hits_the_standing_one_behind() -> void:
	var roster := line_up([-4.0, -9.0])
	roster[1].crouch_amount = 1.0
	var pool := BBPool.new(1)
	var bb := spawn(pool, 1, Vector3(0, 1.6, 0), Vector3.FORWARD, 88.0)
	run(pool, bb, roster, no_wall, 90)
	assert_eq(roster[1].status, Character.Status.ALIVE)
	assert_eq(roster[2].status, Character.Status.CALLING)
	assert_eq(events.count_of(GameEvent.Kind.CHARACTER_HIT), 1)


func test_two_bbs_reaching_someone_in_one_tick_give_one_hit_and_nobody_behind_is_hit() -> void:
	var roster := line_up([-10.0, -12.0])
	var pool := BBPool.new(4)
	var first := spawn(pool, 1, Vector3(0, 1.2, -9), Vector3.FORWARD, 88.0)
	var second := spawn(pool, 1, Vector3(0.05, 1.2, -9), Vector3.FORWARD, 88.0)
	step(pool, roster)
	assert_eq(events.count_of(GameEvent.Kind.CHARACTER_HIT), 1)
	assert_eq(events.count_of(GameEvent.Kind.BB_IMPACT), 1)
	assert_false(first.active)
	assert_false(second.active)
	assert_gt(second.position.z, -10.0)
	assert_eq(roster[2].status, Character.Status.ALIVE)


func test_a_bb_stopped_on_a_wall_names_no_body() -> void:
	var roster := line_up([])
	var pool := BBPool.new(1)
	var bb := spawn(pool, 1, Vector3(0, 1.3, 0), Vector3.FORWARD, 88.0)
	run(pool, bb, roster, CloseWall.new())
	assert_eq(events.first(GameEvent.Kind.BB_IMPACT).target, -1)


func test_a_stream_of_bbs_at_the_nearer_of_two_in_a_line_never_reaches_the_one_behind() -> void:
	# M85 (the owner's playtest note 17): full auto at a bot with another 6 m behind it on the line. A second of fire
	# from the eye at the nearer one's chest: the first BB knocks it out, the rest stop on its body as it calls the hit.
	var roster := line_up([-6.0, -12.0])
	roster.append(Character.new(4, 1, Vector3(50, 0, -50), 0.0))
	var pool := BBPool.new(tuning.ballistics.max_bbs)
	var eye := Vector3(0, tuning.body.stand_eye_height, 0)
	var aim := (Vector3(0, 1.2, -6) - eye).normalized()
	var shots := 0
	var hits := 0
	for i in 90:
		if i % 5 == 0 and i < 60:
			spawn(pool, 1, eye, aim, 88.0)
			shots += 1
		events.clear()
		step(pool, roster)
		hits += events.count_of(GameEvent.Kind.CHARACTER_HIT)
	assert_gt(shots, 10)
	assert_ne(roster[1].status, Character.Status.ALIVE)
	assert_eq(roster[2].status, Character.Status.ALIVE, "the bot behind was hit through the first")
	assert_eq(hits, 1)
	assert_eq(pool.active_count(), 0, "every BB stopped")


func test_a_warm_tick_makes_no_objects() -> void:
	# BBs flying past three characters and into a wall, a tick at a time: once the hit volumes and the event pool have
	# grown, a tick creates no objects (events, volumes, ray hits are all reused).
	var roster := line_up([-10.0, -20.0])
	roster[1].position.x = 2.0
	roster[2].position.x = -2.0
	var pool := BBPool.new(8)
	var wall := WallAt.new(-25.0)
	for i in 8:
		spawn(pool, 1, Vector3(0.1 * i, 1.3, 0), Vector3.FORWARD, 88.0, 0.2)
		events.add(GameEvent.Kind.BB_IMPACT)
	events.clear()
	step(pool, roster, wall)
	events.clear()
	var before := Performance.get_monitor(Performance.OBJECT_COUNT)
	for i in 60:
		step(pool, roster, wall)
		events.clear()
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), before)
	assert_eq(pool.active_count(), 0, "every BB reached the wall")
