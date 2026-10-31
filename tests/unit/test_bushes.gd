extends GutTest
## Bushes hide you and stop BBs (WL5; the browser game's map/foliage.test.ts, sim/leaves.test.ts, ai/bushSight.test.ts,
## ai/botLeavesFire.test.ts and ai/woodlandBushMatch.test.ts): the leaves a line crosses (Foliage), a BB pushing
## through them (Leaves, BBStep), what bots see and shoot through (BotSenses, BotCombat), the map's bushes (MapData,
## MapLevel) and how they are drawn, heard and marked (BushView, PuffView, SimAudio, Hud, MinimapField). Written against
## the first Woodland's 70 bushes, kept as OldWoodland since WR1.

const DT := 1.0 / 60.0
const KILL_Y := -10.0
const MASS := 0.25e-3
const EPS := 1e-4
## A BB's speed off the muzzle in these tests (m/s), fast enough that drag over a few ticks hardly matters.
const SPEED := 90.0

var tuning: SimTuning = SimTuning.new()
var events: SimEvents = SimEvents.new()
var ends: Array[MapEnd] = []
var nobody: Array[Character] = []


func before_each() -> void:
	tuning = SimTuning.new()
	events = SimEvents.new()


## One bush standing on (x, 0, z), `radius` across and `height` tall.
static func _bush(x: float, z: float, radius: float, height: float) -> Foliage:
	var f := Foliage.new()
	f.add(Vector3(x, 0.0, z), radius, height)
	return f


## The leaves the line from `a` to `b` crosses, worked out bush by bush with no index (the reference for the index).
static func _reference_depth(f: Foliage, a: Vector3, b: Vector3) -> float:
	var total := 0.0
	var d := b - a
	for i in f.size():
		var r := f.radii[i]
		var half := f.heights[i] * 0.5
		var c := f.feet[i] + Vector3(0.0, half, 0.0)
		var p := Vector3((a.x - c.x) / r, (a.y - c.y) / half, (a.z - c.z) / r)
		var q := Vector3(d.x / r, d.y / half, d.z / r)
		var qq := q.dot(q)
		var pq := p.dot(q)
		var disc := pq * pq - qq * (p.dot(p) - 1.0)
		if disc <= 0.0:
			continue
		var t0 := maxf(0.0, (-pq - sqrt(disc)) / qq)
		var t1 := minf(1.0, (-pq + sqrt(disc)) / qq)
		if t1 > t0:
			total += (t1 - t0) * d.length()
	return total


# --- the leaves a line crosses ---

func test_a_line_crosses_a_bush_s_full_width_through_its_middle_and_its_height_straight_down() -> void:
	var f := _bush(0.0, 0.0, 1.0, 2.0)
	assert_almost_eq(f.depth(Vector3(-5.0, 1.0, 0.0), Vector3(5.0, 1.0, 0.0)), 2.0, EPS)
	assert_almost_eq(f.depth(Vector3(0.0, 5.0, 0.0), Vector3(0.0, -1.0, 0.0)), 2.0, EPS)


func test_a_line_over_beside_or_short_of_a_bush_crosses_none() -> void:
	var f := _bush(0.0, 0.0, 1.0, 2.0)
	assert_eq(f.depth(Vector3(-5.0, 2.5, 0.0), Vector3(5.0, 2.5, 0.0)), 0.0, "over")
	assert_eq(f.depth(Vector3(-5.0, 1.0, 1.5), Vector3(5.0, 1.0, 1.5)), 0.0, "beside")
	assert_eq(f.depth(Vector3(-5.0, 1.0, 0.0), Vector3(-2.0, 1.0, 0.0)), 0.0, "short")


func test_only_the_part_inside_counts_from_the_middle_out_is_one_radius() -> void:
	var f := _bush(0.0, 0.0, 1.0, 2.0)
	assert_almost_eq(f.depth(Vector3(0.0, 1.0, 0.0), Vector3(5.0, 1.0, 0.0)), 1.0, EPS)


func test_bushes_in_a_row_add_up_and_counting_stops_past_the_limit() -> void:
	var f := _bush(0.0, 0.0, 1.0, 2.0)
	f.add(Vector3(3.0, 0.0, 0.0), 1.0, 2.0)
	assert_almost_eq(f.depth(Vector3(-5.0, 1.0, 0.0), Vector3(10.0, 1.0, 0.0)), 4.0, EPS)
	var partial := f.depth(Vector3(-5.0, 1.0, 0.0), Vector3(10.0, 1.0, 0.0), 1.0)
	assert_gt(partial, 1.0, "past the limit")
	assert_lt(partial, 4.0, "stopped counting there")


func test_no_bushes_or_no_line_cross_no_leaves() -> void:
	assert_eq(Foliage.new().depth(Vector3.ZERO, Vector3(10.0, 0.0, 0.0)), 0.0)
	assert_eq(_bush(0.0, 0.0, 1.0, 2.0).depth(Vector3(0.0, 1.0, 0.0), Vector3(0.0, 1.0, 0.0)), 0.0)


func test_the_index_gives_what_every_bush_one_by_one_gives_for_short_and_long_lines() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 26
	var f := Foliage.new()
	for i in 80:
		f.add(Vector3(rng.randf_range(-60.0, 60.0), rng.randf_range(0.0, 3.0), rng.randf_range(-40.0, 40.0)),
				rng.randf_range(0.5, 0.85), rng.randf_range(0.9, 1.25))
	var worst := 0.0
	var crossed := 0
	for i in 2000:
		var a := Vector3(rng.randf_range(-62.0, 62.0), rng.randf_range(0.0, 4.0), rng.randf_range(-42.0, 42.0))
		var reach := 2.0 if i % 2 == 0 else 50.0
		var b := a + Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.2, 0.2), rng.randf_range(-1.0, 1.0)) \
				.normalized() * reach
		var want := _reference_depth(f, a, b)
		if want > 0.0:
			crossed += 1
		worst = maxf(worst, absf(f.depth(a, b) - want))
	assert_lt(worst, EPS, "the same leaves whichever way they're found")
	assert_gt(crossed, 30, "enough lines cross a bush to mean something")


# --- where a path meets leaves ---

func test_a_path_s_crossing_gives_where_it_goes_in_and_comes_out() -> void:
	var f := _bush(0.0, 0.0, 1.0, 2.0)
	var x := Foliage.Crossing.new()
	assert_true(f.first_leaves(Vector3(-5.0, 1.0, 0.0), Vector3.RIGHT, 10.0, x))
	assert_almost_eq(x.enter, 4.0, EPS)
	assert_almost_eq(x.exit, 6.0, EPS)
	assert_true(x.through)


func test_a_crossing_is_clipped_to_the_path() -> void:
	var f := _bush(0.0, 0.0, 1.0, 2.0)
	var x := Foliage.Crossing.new()
	assert_true(f.first_leaves(Vector3(-5.0, 1.0, 0.0), Vector3.RIGHT, 4.5, x))
	assert_almost_eq(x.exit, 4.5, EPS)
	assert_false(x.through, "ends among the leaves")
	assert_true(f.first_leaves(Vector3(0.0, 1.0, 0.0), Vector3.RIGHT, 5.0, x))
	assert_eq(x.enter, 0.0, "starts inside")
	assert_almost_eq(x.exit, 1.0, EPS)


func test_the_nearest_bush_of_a_row_comes_first_whatever_the_map_s_order() -> void:
	var f := _bush(6.0, 0.0, 1.0, 2.0)
	f.add(Vector3(2.0, 0.0, 0.0), 1.0, 2.0)
	var x := Foliage.Crossing.new()
	assert_true(f.first_leaves(Vector3(-5.0, 1.0, 0.0), Vector3.RIGHT, 20.0, x))
	assert_almost_eq(x.enter, 6.0, EPS)


func test_a_sliver_at_the_rim_or_leaving_from_the_surface_is_no_leaves() -> void:
	var f := _bush(0.0, 0.0, 1.0, 2.0)
	var x := Foliage.Crossing.new()
	assert_false(f.first_leaves(Vector3(-5.0, 1.0, 0.9999999), Vector3.RIGHT, 10.0, x), "grazing the rim")
	assert_false(f.first_leaves(Vector3(1.0, 1.0, 0.0), Vector3.RIGHT, 10.0, x), "leaving from the surface")
	assert_false(f.first_leaves(Vector3(-5.0, 1.0, 0.0), Vector3.RIGHT, 0.0005, x), "no path")


func test_leaves_knocked_out_show_on_the_side_the_bb_went_in() -> void:
	var f := _bush(0.0, 0.0, 1.0, 2.0)
	var at := Vector3(-0.4, 1.0, 0.0)
	assert_almost_eq(f.leaf_surface(at, Vector3.LEFT, 0.6 + EPS), Vector3(-1.0, 1.0, 0.0), Vector3.ONE * EPS,
			"back where it went in")
	assert_eq(f.leaf_surface(at, Vector3.LEFT, 0.3), at, "fired from inside the bush: stays where it stopped")
	assert_eq(f.leaf_surface(Vector3(5.0, 1.0, 0.0), Vector3.LEFT, 10.0), Vector3(5.0, 1.0, 0.0), "in no bush")


func test_leaves_come_to_rest_on_the_lowest_foot_of_the_bushes_a_point_is_in() -> void:
	var f := _bush(0.0, 0.0, 1.0, 2.0)
	f.add(Vector3(0.5, -0.3, 0.0), 1.0, 2.0)
	assert_almost_eq(f.leaf_floor(Vector3(0.2, 1.0, 0.0)), -0.3, EPS)
	assert_almost_eq(f.leaf_floor(Vector3(-0.9, 1.0, 0.0)), 0.0, EPS)
	assert_eq(f.leaf_floor(Vector3(5.0, 1.0, 0.0)), -INF)


# --- a BB in the leaves ---

func _bb(velocity: Vector3, spin: float = 900.0) -> BB:
	var bb := BB.new()
	bb.active = true
	bb.velocity = velocity
	bb.spin = spin
	bb.mass = MASS
	return bb


func test_leaves_slow_a_bb_and_scrub_its_spin_by_the_share_kept_a_metre() -> void:
	var cfg := BallisticsConfig.new()
	var bb := _bb(Vector3(0.0, 0.0, -SPEED))
	Leaves.deflect(bb, 0.3, cfg, null)
	var kept := pow(cfg.leaf_kept_per_metre, 0.3)
	assert_almost_eq(bb.velocity.length(), SPEED * kept, EPS)
	assert_almost_eq(bb.spin, 900.0 * kept, EPS)
	assert_almost_eq(bb.velocity.normalized(), Vector3.FORWARD, Vector3.ONE * EPS, "no stream: kept on its line")
	var full := _bb(Vector3(0.0, 0.0, -SPEED))
	Leaves.deflect(full, 1.0, cfg, null)
	assert_almost_eq(full.velocity.length() / SPEED, 0.35, EPS, "0.35 over a metre")


func test_leaves_throw_a_bb_off_its_line_within_the_scatter_and_the_same_way_from_one_seed() -> void:
	var cfg := BallisticsConfig.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var most := 0.0
	var sides := {}
	for i in 400:
		var bb := _bb(Vector3(0.0, 0.0, -SPEED))
		Leaves.deflect(bb, 0.4, cfg, rng)
		var off := bb.velocity.normalized().angle_to(Vector3.FORWARD)
		most = maxf(most, off)
		sides[Vector2i(signi(roundi(bb.velocity.x * 10.0)), signi(roundi(bb.velocity.y * 10.0)))] = true
	assert_lte(most, cfg.leaf_scatter_per_metre * 0.4 + EPS, "no more than 0.5 rad a metre")
	assert_gt(most, cfg.leaf_scatter_per_metre * 0.4 * 0.9, "and up to it")
	assert_gte(sides.size(), 4, "any way round its line")
	var again := [RandomNumberGenerator.new(), RandomNumberGenerator.new()]
	var lines: Array[Vector3] = []
	for r: RandomNumberGenerator in again:
		r.seed = 9
		var bb := _bb(Vector3(3.0, 1.0, -SPEED))
		Leaves.deflect(bb, 0.25, cfg, r)
		lines.append(bb.velocity)
	assert_eq(lines[0], lines[1], "one seed, one way")


func test_leaves_turn_a_bb_flying_straight_up_and_leave_one_alone_for_no_leaves() -> void:
	var cfg := BallisticsConfig.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var up := _bb(Vector3(0.0, SPEED, 0.0))
	Leaves.deflect(up, 0.5, cfg, rng)
	assert_true(up.velocity.is_finite())
	assert_lte(up.velocity.normalized().angle_to(Vector3.UP), cfg.leaf_scatter_per_metre * 0.5 + EPS)
	var none := _bb(Vector3(0.0, 0.0, -SPEED))
	Leaves.deflect(none, 0.0, cfg, rng)
	assert_eq(none.velocity, Vector3(0.0, 0.0, -SPEED))
	assert_eq(none.spin, 900.0)


func test_what_stops_a_bb_is_what_a_bot_can_t_see_through() -> void:
	var sim := SimTuning.load_default()
	var bots := BotConfig.load_default()
	assert_eq(sim.ballistics.leaf_stop_depth, bots.foliage_see_through,
			"if you can't see through it, a BB can't get through")
	assert_eq(sim.ballistics.leaf_stop_depth, 0.6)
	assert_eq(bots.foliage_fire_through, 0.25)
	assert_almost_eq(sim.ballistics.leaf_kept_per_metre, 0.35, EPS)
	assert_almost_eq(sim.ballistics.leaf_scatter_per_metre, 0.5, EPS)


# --- BBs through bushes, a tick at a time ---

## Fires one BB from `origin` along -Z into `world` and flies it until it stops or `ticks` pass; the events of every
## tick are gathered into `seen` (kind → count) and the last BB_IMPACT or BB_LEAVES copied into `last`.
func _fly(world: WorldQuery, origin: Vector3, ticks: int, rng: RandomNumberGenerator, seen: Dictionary,
		last: Dictionary) -> BB:
	var pool := BBPool.new(4)
	var bb := pool.spawn(0, origin, Vector3.FORWARD, SPEED, 0.0, MASS, tuning.ballistics.spin_per_hop)
	for t in ticks:
		events.clear()
		BBStep.step(pool, nobody, world, tuning, KILL_Y, false, ends, events, DT, Vector3.ZERO, rng)
		for i in events.count:
			var e := events.items[i]
			seen[e.kind] = int(seen.get(e.kind, 0)) + 1
			if e.kind == GameEvent.Kind.BB_IMPACT or e.kind == GameEvent.Kind.BB_LEAVES:
				last[e.kind] = [e.position, e.direction, e.value, e.value2, e.reach]
		if not bb.active:
			break
	return bb


func test_a_bb_into_a_deep_bush_stops_0_6_m_in_as_leaves() -> void:
	var world := BoxWorld.new()
	world.add_bush(Vector3(0.0, 0.0, -10.0), 1.0, 2.0)
	var seen := {}
	var last := {}
	var bb := _fly(world, Vector3(0.0, 1.0, 0.0), 30, null, seen, last)
	assert_false(bb.active, "stopped")
	assert_almost_eq(bb.position.z, -9.0 - 0.6, 5e-3, "0.6 m into the leaves (its path drops a little)")
	assert_almost_eq(bb.leaf, 0.6, 1e-4)
	var stop: Array = last[GameEvent.Kind.BB_IMPACT]
	assert_eq(stop[2], BBStep.IN_LEAVES, "a stop in the leaves")
	assert_eq(stop[3], RayHit.Surface.LEAVES)
	assert_almost_eq((stop[1] as Vector3).length(), 1.0, EPS, "its unit path, slower than any prop's ring")
	assert_almost_eq(float(stop[4]), 0.6, 1e-4, "the leaves it crossed")
	assert_false(seen.has(GameEvent.Kind.BB_LEAVES), "it never came out")


func test_a_bb_through_a_thin_edge_flies_on_slowed_and_turned_from_where_it_came_out() -> void:
	var world := BoxWorld.new()
	# Through the edge 0.8 of a radius off the middle: a chord of 2 × sqrt(1 - 0.64) = 1.2 radii, 0.36 m at 0.3 m.
	world.add_bush(Vector3(0.24, 0.0, -10.0), 0.3, 2.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var seen := {}
	var last := {}
	var pool := BBPool.new(4)
	var bb := pool.spawn(0, Vector3(0.0, 1.0, 0.0), Vector3.FORWARD, SPEED, 0.0, MASS, tuning.ballistics.spin_per_hop)
	# Its twin in the open: the speed it would have had without the leaves.
	var open_pool := BBPool.new(4)
	var twin := open_pool.spawn(0, Vector3(0.0, 1.0, 0.0), Vector3.FORWARD, SPEED, 0.0, MASS,
			tuning.ballistics.spin_per_hop)
	var open_events := SimEvents.new()
	for t in 20:
		events.clear()
		BBStep.step(pool, nobody, world, tuning, KILL_Y, false, ends, events, DT, Vector3.ZERO, rng)
		BBStep.step(open_pool, nobody, WorldQuery.new(), tuning, KILL_Y, false, ends, open_events, DT)
		if events.count_of(GameEvent.Kind.BB_LEAVES) > 0:
			var e := events.first(GameEvent.Kind.BB_LEAVES)
			last[GameEvent.Kind.BB_LEAVES] = e.position
			break
	assert_true(last.has(GameEvent.Kind.BB_LEAVES), "it came out of the edge")
	assert_true(bb.active, "and flies on")
	assert_almost_eq(bb.leaf, 0.36, 5e-3)
	var out: Vector3 = last[GameEvent.Kind.BB_LEAVES]
	assert_almost_eq(bb.position, out, Vector3.ONE * EPS, "from where it came out, the rest of the tick dropped")
	assert_almost_eq(out.z, -10.0 - 0.18, 5e-3)
	var kept := pow(tuning.ballistics.leaf_kept_per_metre, bb.leaf)
	assert_almost_eq(bb.velocity.length() / twin.velocity.length(), kept, 1e-3, "slowed by 0.35 a metre of leaves")
	assert_lte(bb.velocity.normalized().angle_to(Vector3.FORWARD), tuning.ballistics.leaf_scatter_per_metre * bb.leaf
			+ EPS, "turned by up to 0.5 rad a metre")


func test_leaves_count_over_the_whole_flight_two_edges_add_up() -> void:
	var world := BoxWorld.new()
	# Two edges of 0.36 m each: 0.72 m together, past the 0.6 that stops a BB.
	world.add_bush(Vector3(0.24, 0.0, -5.0), 0.3, 2.0)
	world.add_bush(Vector3(0.24, 0.0, -12.0), 0.3, 2.0)
	var seen := {}
	var last := {}
	var bb := _fly(world, Vector3(0.0, 1.0, 0.0), 40, null, seen, last)
	assert_eq(seen.get(GameEvent.Kind.BB_LEAVES, 0), 1, "through the first")
	assert_false(bb.active, "stopped in the second")
	assert_eq((last[GameEvent.Kind.BB_IMPACT] as Array)[2], BBStep.IN_LEAVES)
	assert_almost_eq(bb.leaf, 0.6, 1e-4)


func test_a_world_without_bushes_or_with_one_off_the_path_flies_bbs_as_before() -> void:
	var plain := BoxWorld.new()
	plain.add_box(Vector3(0.0, 1.0, -40.0), Vector3(4.0, 4.0, 1.0), RayHit.Surface.CONCRETE)
	var leafy := BoxWorld.new()
	leafy.add_box(Vector3(0.0, 1.0, -40.0), Vector3(4.0, 4.0, 1.0), RayHit.Surface.CONCRETE)
	leafy.add_bush(Vector3(6.0, 0.0, -20.0), 1.0, 2.0)
	var trails: Array[PackedVector3Array] = []
	var draws: Array[int] = []
	for world: BoxWorld in [plain, leafy]:
		var rng := RandomNumberGenerator.new()
		rng.seed = 4
		var pool := BBPool.new(4)
		pool.spawn(0, Vector3(0.0, 1.0, 0.0), Vector3(0.02, 0.0, -1.0).normalized(), SPEED, 0.2, MASS,
				tuning.ballistics.spin_per_hop)
		var trail := PackedVector3Array()
		for t in 60:
			events.clear()
			BBStep.step(pool, nobody, world, tuning, KILL_Y, false, ends, events, DT, Vector3(0.5, 0.0, 0.0), rng)
			trail.append(pool.bbs[0].position)
		trails.append(trail)
		draws.append(rng.randi())
	assert_eq(trails[0], trails[1], "the same flight, bounce and all")
	assert_eq(draws[0], draws[1], "and no draw from the match's stream")


func test_a_bb_still_among_the_leaves_at_a_wall_lands_slowed() -> void:
	var world := BoxWorld.new()
	world.add_box(Vector3(0.0, 1.0, -10.2), Vector3(4.0, 4.0, 0.2), RayHit.Surface.WOOD)
	# The bush stands through the wall: 0.5 m of its leaves in front of the wall's face (z = -10.1).
	world.add_bush(Vector3(0.0, 0.0, -10.4), 0.8, 2.0)
	var seen := {}
	var last := {}
	var bb := _fly(world, Vector3(0.0, 1.0, 0.0), 30, null, seen, last)
	assert_false(bb.active)
	var landed: Array = last[GameEvent.Kind.BB_IMPACT]
	assert_eq(landed[2], 0, "on the wall, not in the leaves")
	assert_eq(landed[3], RayHit.Surface.WOOD)
	assert_almost_eq(bb.leaf, 0.5, 5e-3, "the leaves on the way counted")
	assert_lt((landed[1] as Vector3).length(), SPEED * pow(0.35, 0.5) + 1.0, "and slowed it before it landed")


func test_a_bb_in_flight_allocates_nothing_among_bushes() -> void:
	var world := BoxWorld.new()
	for i in 40:
		world.add_bush(Vector3((i % 8) * 3.0 - 12.0, 0.0, -float(i / 8) * 6.0 - 4.0), 0.7, 1.1)
	var pool := BBPool.new(64)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	for k in 3:
		for i in 48:
			pool.spawn(0, Vector3(rng.randf_range(-12.0, 12.0), rng.randf_range(0.3, 1.4), 2.0),
					Vector3(rng.randf_range(-0.1, 0.1), 0.0, -1.0).normalized(), SPEED, 0.2, MASS,
					tuning.ballistics.spin_per_hop)
		for t in 30:
			events.clear()
			BBStep.step(pool, nobody, world, tuning, KILL_Y, false, ends, events, DT, Vector3.ZERO, rng)
	var objects := Performance.get_monitor(Performance.OBJECT_COUNT)
	for i in 48:
		pool.spawn(0, Vector3(rng.randf_range(-12.0, 12.0), rng.randf_range(0.3, 1.4), 2.0),
				Vector3(rng.randf_range(-0.1, 0.1), 0.0, -1.0).normalized(), SPEED, 0.2, MASS,
				tuning.ballistics.spin_per_hop)
	for t in 30:
		events.clear()
		BBStep.step(pool, nobody, world, tuning, KILL_Y, false, ends, events, DT, Vector3.ZERO, rng)
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), objects, "no object made a tick")


# --- no collider, no nav change ---

func test_a_body_walks_through_a_bush_as_through_open_ground() -> void:
	var trails: Array[PackedVector3Array] = []
	for leafy: bool in [false, true]:
		var world := BoxWorld.new(tuning.body)
		world.add_floor(40.0, 40.0)
		if leafy:
			world.add_bush(Vector3(0.0, 0.0, -4.0), 0.8, 1.2)
		var mover := world.mover()
		var c := Character.new(0, 0, Vector3(0.0, tuning.body.rest_gap, 0.0), 0.0, ReplicaStats.default_loadout())
		var cmd := PlayerCommand.new()
		cmd.forward = 1.0
		cmd.sprint = true
		var trail := PackedVector3Array()
		for t in 120:
			Movement.step(c, cmd, tuning.movement, tuning.accuracy, DT, mover)
			trail.append(c.position)
		trails.append(trail)
	assert_eq(trails[0], trails[1], "the same steps, at the same pace, bush or none")
	assert_lt(trails[1][119].z, -8.0, "right through it")


func test_woodland_reads_its_bushes_and_hands_them_to_the_simulation() -> void:
	var t := SimTuning.load_default()
	var map := OldWoodland.load_map(MapStyle.new(), t.rounds.team_size)
	assert_true(map.ok(), "; ".join(map.problems))
	assert_eq(map.foliage.size(), 70, "the browser's 70 bushes")
	for i in map.foliage.size():
		assert_between(map.foliage.heights[i], 0.9, 1.26, "small and decorative (MS1)")
	for id: String in ["depot", "range"]:
		assert_true(MapData.load_map(id, MapStyle.new(), t.rounds.team_size).foliage.is_empty(), id + " has none")


func test_a_malformed_bush_is_left_out_with_a_warning() -> void:
	var text := JSON.stringify({"blocks": [{"kind": "floor", "x": 0, "y": -0.5, "z": 0, "w": 20, "h": 1, "d": 20}],
			"foliage": [{"x": 1, "y": 0, "z": 2, "radius": 0.6, "height": 1.0}, {"x": 1, "z": 2, "radius": 0.6,
			"height": 1.0}, {"x": 1, "y": 0, "z": 2, "radius": 0, "height": 1.0}, "bush"]})
	var map := MapData.parse(text, MapStyle.new(), 1)
	assert_eq(map.foliage.size(), 1, "one good bush")
	var left := 0
	for w in map.warnings:
		if w.begins_with("bush "):
			left += 1
	assert_eq(left, 3, "each bad one named")


func test_woodland_s_grid_and_level_rays_are_the_same_with_and_without_its_bushes() -> void:
	var t := SimTuning.load_default()
	var style := MapStyle.new()
	var with := OldWoodland.load_map(style, t.rounds.team_size)
	var without := OldWoodland.load_map(style, t.rounds.team_size)
	without.foliage = Foliage.new()
	var a := NavGrid.build(with, t.nav, t.body)
	var b := NavGrid.build(without, t.nav, t.body)
	assert_eq(a.walkable, b.walkable, "the same walkable cells")
	assert_eq(a.floor_y, b.floor_y, "at the same heights")
	assert_eq(a.steps, b.steps, "with the same steps between them")
	# One level at a time: two in one physics space would meet each other's colliders.
	var seen: Array[Array] = []
	for m: MapData in [with, without]:
		var level := MapLevel.new()
		add_child(level)
		level.build(m, style, t.body)
		assert_eq(level.query().foliage, m.foliage, "the simulation gets the map's bushes")
		seen.append(_rays_through(level.query(), with.foliage))
		level.free()
	assert_eq(seen[0].size(), with.foliage.size() * 4)
	assert_eq(seen[0], seen[1], "every ray through every bush, and the ground under each, as without them")
	var clear := 0
	for r: Array in seen[0]:
		if r.size() == 2 and (not r[0] or r[1] > 0.55):
			clear += 1
	assert_gt(clear, with.foliage.size(), "and most pass a bush's middle untouched")


## What `query` answers for three rays through the middle of each of `bushes` (whether one meets the level, and where)
## and what is under each bush's foot.
static func _rays_through(query: WorldQuery, bushes: Foliage) -> Array[Array]:
	var hit := RayHit.new()
	var out: Array[Array] = []
	for i in bushes.size():
		var f := bushes.feet[i]
		var mid := f + Vector3(0.0, bushes.heights[i] * 0.5, 0.0)
		for dir: Vector3 in [Vector3.RIGHT, Vector3.BACK, Vector3(1.0, -0.3, 1.0).normalized()]:
			var did := query.ray(mid - dir * 3.0, mid + dir * 3.0, hit)
			out.append([did, snappedf(hit.fraction, 1e-5) if did else -1.0])
		out.append([query.surface_under(f + Vector3(0.0, 0.05, 0.0))])
	return out


# --- bots ---

var _w: BotWorld = null


## An Easy (or `level`) bot at the origin facing -Z, its enemy `away` m in front, standing, in `query`.
func _duel(query: WorldQuery, away: float, level: StringName = &"easy") -> Bot:
	var cfg := BotConfig.load_default()
	var loadout := ReplicaStats.default_loadout()
	var me := Character.new(0, 0, Vector3.ZERO, 0.0, loadout)
	var foe := Character.new(1, 1, Vector3(0.0, 0.0, -away), 0.0, loadout)
	_w = BotWorld.new()
	_w.tuning = SimTuning.load_default()
	_w.cfg = cfg
	_w.query = query
	_w.planner = RoundPlanner.new(1)
	_w.characters = [me, foe]
	_w.time = 10.0
	return Bot.new(me, 1, cfg.skill_for(level), 2)


## A world with a bush whose line from the bot's eye to its enemy's chest crosses `crossing` m of leaves, `away` m out.
func _bushy(crossing: float, away: float) -> BoxWorld:
	var world := BoxWorld.new()
	_duel(world, away)
	var eye := BotSenses.eye_of(_w.characters[0], _w.tuning)
	var chest := BotSenses.body_point(_w.characters[1], _w.tuning.hits, _w.cfg.aim_height_fraction)
	var head := BotSenses.body_point(_w.characters[1], _w.tuning.hits, _w.cfg.head_height_fraction)
	# A tall bush (so the head's line crosses as much), its middle on the sight line halfway, its width the crossing.
	var mid := eye.lerp(chest, 0.5)
	var tall := 8.0 + absf(head.y - chest.y) * 4.0
	world.add_bush(Vector3(mid.x, mid.y - tall * 0.5, mid.z), crossing * 0.5, tall)
	return world


func test_a_bot_sees_through_up_to_0_6_m_of_leaves_and_no_further() -> void:
	var b := _duel(_bushy(0.55, 15.0), 15.0)
	assert_gt(BotSenses.visible_part(b.character, _w.characters[1], _w), 0.0, "0.55 m: seen")
	b = _duel(_bushy(0.65, 15.0), 15.0)
	assert_eq(BotSenses.visible_part(b.character, _w.characters[1], _w), 0.0, "0.65 m: hidden")
	assert_false(BotSenses.sees_spot(b.character, _w.characters[1].position, 30.0, _w), "nor the spot seen empty")


func test_a_bush_hides_no_one_within_close_awareness() -> void:
	var cfg := BotConfig.load_default()
	var near := cfg.close_awareness * 0.8
	var b := _duel(_bushy(1.0, near), near)
	assert_gt(BotSenses.visible_part(b.character, _w.characters[1], _w), 0.0, "noticed through a whole bush")


func test_bots_at_every_level_hold_fire_through_more_than_0_25_m() -> void:
	# The old Easy fired through what a BB crosses; no level does since TL1.
	var cases := [[0.2, &"easy", false], [0.3, &"easy", true], [0.3, &"hard", true], [0.2, &"hard", false],
			[0.7, &"normal", true]]
	for c: Array in cases:
		var world := _bushy(c[0], 15.0)
		var b := _duel(world, 15.0, c[1])
		var eye := BotSenses.eye_of(b.character, _w.tuning)
		var chest := BotSenses.body_point(_w.characters[1], _w.tuning.hits, _w.cfg.aim_height_fraction)
		assert_eq(BotCombat.leaves_in_line(_w, eye, chest), c[2], "%s through %.2f m" % [c[1], c[0]])
	_duel(BoxWorld.new(), 15.0)
	assert_false(BotCombat.leaves_in_line(_w, Vector3.ZERO, Vector3(0.0, 0.0, -15.0)), "no bushes, no leaves")


func test_a_5v5_woodland_match_never_sees_through_more_than_0_6_m_of_leaves_and_finishes_its_rounds() -> void:
	var t := SimTuning.load_default().duplicate() as SimTuning
	t.rounds = t.rounds.duplicate() as RoundConfig
	t.rounds.team_size = 5
	t.rounds.wins_needed = 2
	t.rounds.half_time_after = 1
	var runner := MatchRunner.new(self, "woodland", t, null, OldWoodland.load_map(MapStyle.new(), t.rounds.team_size))
	assert_eq(runner.level.query().foliage.size(), 70, "its bushes in the bots' world")
	var watch := {"sampled": 0, "worst": 0.0, "leafy": 0}
	runner.each_tick = func(state: GameState, bots: BotController) -> void:
		if not state.round_state.is_live() or roundi(state.time / DT) % 6 != 0:
			return
		var w := bots.world
		var leaves := w.query.foliage
		for b in w.bots:
			var me := b.character
			if not Elimination.is_in_play(me):
				continue
			var eye := BotSenses.eye_of(me, w.tuning)
			for other in w.characters:
				if other.team == me.team or not Elimination.is_in_play(other):
					continue
				var flat := Vector2(other.position.x - me.position.x, other.position.z - me.position.z).length()
				if flat > w.cfg.view_distance:
					continue
				watch.sampled += 1
				var part := BotSenses.visible_part(me, other, w)
				if part > 0.0 and flat > w.cfg.close_awareness:
					var d := leaves.depth(eye, BotSenses.body_point(other, w.tuning.hits, part))
					watch.worst = maxf(watch.worst, d)
					if d > 0.0:
						watch.leafy += 1
	var tally := runner.play(3, 900.0)
	runner.free_level()
	gut.p("Woodland 5v5: %d rounds in %.0f s, %d hits; %d sightings sampled (%d through some leaves), worst %.3f m"
			% [tally.rounds.size(), tally.ticks * DT, tally.hits, watch.sampled, watch.leafy, watch.worst])
	assert_gt(watch.sampled, 500, "enough sightings checked")
	assert_lte(watch.worst, 0.6 + 1e-6, "nobody seen through more than 0.6 m of leaves")
	assert_true(tally.finished, "the match is won")
	assert_gte(tally.rounds.size(), 2, "its rounds finish")
	assert_gt(tally.hits, 0, "BBs land")


# --- how bushes are drawn, heard and marked ---

## The old Woodland and its 70 bushes (OldWoodland), as the game reads a map.
static func _woodland() -> MapData:
	return OldWoodland.load_map(PlayTuning.load_default().map_style, SimTuning.load_default().rounds.team_size)


func test_woodland_s_bushes_are_one_draw_of_placeholder_ellipsoids_standing_on_their_feet() -> void:
	var map := _woodland()
	var view := BushView.build(map, PlayTuning.load_default().woods)
	add_child_autofree(view)
	assert_eq(view.get_child_count(), 0, "one node")
	assert_eq(view.multimesh.instance_count, 70, "one draw of every bush")
	for i in map.foliage.size():
		var xf := BushView.placed(map.foliage, i)
		var half := map.foliage.heights[i] * 0.5
		assert_almost_eq(xf.origin, map.foliage.feet[i] + Vector3.UP * half, Vector3.ONE * EPS, "on its foot")
		assert_almost_eq(xf.basis.get_scale(), Vector3(map.foliage.radii[i], half, map.foliage.radii[i]),
				Vector3.ONE * EPS, "its own size")
	assert_null(BushView.build(MapData.load_map("depot", MapStyle.new(), 3), PlayTuning.load_default().woods),
			"nothing on a map without bushes")


func test_the_map_cards_picture_draws_woodlands_bushes() -> void:
	var pictures: GDScript = load("res://tools/map_pictures.gd")
	var port := Node3D.new()
	add_child_autofree(port)
	pictures.add_woods(port, _woodland(), PlayTuning.load_default())
	var bushes := port.find_children("*", "BushView", false, false)
	assert_eq(bushes.size(), 1, "the card's render dresses Woodland as a match does, bushes and all")
	if not bushes.is_empty():
		assert_eq((bushes[0] as BushView).multimesh.instance_count, _woodland().foliage.size())


func test_the_bushes_leaves_and_marks_are_off_every_team_s_hue() -> void:
	var play := PlayTuning.load_default()
	var teams: Array[Color] = AccessibilityTable.read_file().colours
	teams.append_array(play.teams.colours)
	var greens: Dictionary[Color, String] = {play.effects.leaves_puff_colour: "leaves puff",
			play.minimap.bush_colour: "minimap bush"}
	for c in play.woods.bush_colours:
		greens[c] = "bush"
	for c in play.effects.leaf_colours:
		greens[c] = "leaf"
	var drawn := BushView.colours_of(_woodland(), play.woods)
	assert_eq(drawn.size(), 70)
	for i in drawn.size():
		greens[drawn[i]] = "bush %d as drawn" % i
	var near: Array[String] = []
	for c: Color in greens:
		if FieldChecks.hue_gap(c, teams) <= 20.0:
			near.append("%s %s" % [greens[c], c.to_html(false)])
	assert_eq(near, [] as Array[String], "nothing within 20 degrees of a team's hue")


func test_a_bb_stopped_in_leaves_puffs_green_with_4_to_6_leaves_at_the_side_it_went_in() -> void:
	var f := _bush(0.0, 0.0, 1.0, 2.0)
	var cfg := EffectsConfig.new()
	var puffs := PuffView.new()
	add_child_autofree(puffs)
	puffs.setup(cfg, f)
	assert_not_null(puffs.leaves(), "the leaves' own draw")
	for k in 20:
		puffs.clear()
		puffs.leaves_stop(Vector3(0.0, 1.0, 0.4), Vector3.FORWARD, 0.6)
		assert_between(puffs.leaves_showing(), cfg.leaf_stop_count.x, cfg.leaf_stop_count.y)
	assert_almost_eq(puffs._at[puffs._next - 1], Vector3(0.0, 1.0, 1.0), Vector3.ONE * EPS,
			"the puff where the line back leaves the bush")
	assert_eq(puffs._colour[puffs._next - 1], cfg.leaves_puff_colour, "green")
	for k in 20:
		puffs.clear()
		puffs.leaves_brush(Vector3(0.0, 1.0, -1.0), Vector3.FORWARD)
		assert_between(puffs.leaves_showing(), cfg.leaf_brush_count.x, cfg.leaf_brush_count.y, "a leaf or two")
	puffs.clear()
	puffs.leaves_stop(Vector3(0.0, 1.0, 0.4), Vector3.FORWARD, 0.6)
	for t in roundi(cfg.leaf_life * 0.9 / DT):
		puffs.update(DT)
	for i in puffs._leaf_age.size():
		if puffs._leaf_age[i] < cfg.leaf_life:
			assert_almost_eq(puffs._leaf_at[i].y, 0.0, EPS, "come to rest on the ground under the bush")
	for t in roundi(cfg.leaf_life * 0.2 / DT):
		puffs.update(DT)
	assert_eq(puffs.leaves_showing(), 0, "and gone")


func test_without_bushes_the_puffs_have_no_leaves_to_draw() -> void:
	var puffs := PuffView.new()
	add_child_autofree(puffs)
	puffs.setup(EffectsConfig.new())
	assert_null(puffs.leaves())
	puffs.leaves_stop(Vector3.ZERO, Vector3.FORWARD, 0.6)
	puffs.leaves_brush(Vector3.ZERO, Vector3.FORWARD)
	assert_eq(puffs.leaves_showing(), 0)


func test_the_minimap_marks_every_bush() -> void:
	var map := _woodland()
	var cfg := PlayTuning.load_default().minimap
	var field := MinimapField.build(map, cfg)
	var img := field.layers[0]
	for i in map.foliage.size():
		var f := map.foliage.feet[i]
		var px := field.pixel_of(f.x, f.z)
		assert_eq(img.get_pixel(floori(px.x), floori(px.y)).to_rgba32(), cfg.bush_colour.to_rgba32(),
				"bush %d marked" % i)


func test_leaves_in_the_way_shows_when_your_own_bb_stops_in_leaves_close_in_front_of_you() -> void:
	var you := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	var hud := Hud.new()
	add_child_autofree(hud)
	var sim := SimTuning.new()
	var cfg := HudConfig.new()
	hud.setup(cfg, TeamConfig.new(), ViewConfig.new(), sim, you)
	var state := GameState.new(1)
	state.characters.append(you)
	var eye := Lean.eye(you, sim.body, sim.hits)
	var cases := [[0, eye + Vector3(0.0, 0.0, -1.5), BBStep.IN_LEAVES, true], [0, eye + Vector3(0.0, 0.0, -3.0),
			BBStep.IN_LEAVES, false], [1, eye + Vector3(0.0, 0.0, -1.0), BBStep.IN_LEAVES, false],
			[0, eye + Vector3(0.0, 0.0, -1.0), 0, false]]
	for c: Array in cases:
		hud.update(state, 1.0, cfg.leaves_notice_time + 0.1)
		state.events.clear()
		var e := state.events.add(GameEvent.Kind.BB_IMPACT)
		e.actor = c[0]
		e.position = c[1]
		e.value = c[2]
		hud.on_tick(state)
		hud.update(state, 1.0, DT)
		assert_eq(hud.leaves_notice_shown(), c[3], "shooter %d, %.1f m off, value %d" % [c[0],
				(c[1] as Vector3).distance_to(eye), c[2]])
	hud.update(state, 1.0, cfg.leaves_notice_time)
	assert_false(hud.leaves_notice_shown(), "gone after its time")
	assert_eq(tr("HUD_LEAVES_IN_THE_WAY"), "Leaves in the way · step clear to shoot")


func test_a_bb_in_leaves_rustles_and_one_through_an_edge_rustles_quieter() -> void:
	var cfg := SoundConfig.new()
	var audio := SimAudio.new()
	add_child_autofree(audio)
	audio.setup(cfg, [] as Array[StringName], BodyConfig.new(), null, null)
	var state := GameState.new(1)
	var you := Character.new(0, 0, Vector3.ZERO)
	state.characters.append(you)
	var levels: Array[float] = []
	for kind: GameEvent.Kind in [GameEvent.Kind.BB_IMPACT, GameEvent.Kind.BB_LEAVES]:
		state.time += 1.0
		state.events.clear()
		var e := state.events.add(kind)
		e.actor = 1
		e.position = Vector3(0.0, 1.0, -6.0)
		e.value = BBStep.IN_LEAVES if kind == GameEvent.Kind.BB_IMPACT else 0
		audio.on_tick(state, 0, you)
		var voice: AudioStreamPlayer3D = null
		for v: AudioStreamPlayer3D in audio._field:
			if v.playing and v.stream != null and v.stream.resource_path.contains("impact_leaves"):
				voice = v
		assert_not_null(voice, "impact_leaves plays for %s" % GameEvent.Kind.keys()[kind])
		if voice != null:
			levels.append(voice.volume_db)
			voice.stop()
	if levels.size() == 2:
		assert_almost_eq(levels[1] - levels[0], linear_to_db(cfg.leaf_brush_gain / cfg.impact_gain),
				cfg.impact_spread_db * 2.0 + 0.01, "the edge's rustle half the stop's")
