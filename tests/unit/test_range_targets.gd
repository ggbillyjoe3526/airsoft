extends GutTest
## Practice range targets (game/sim/range_targets.gd; the browser game's sim/rangeTargets.test.ts, M21 and M94): the
## range's layout from data/maps/range.json, none hiding another from where you start, steel rung only from the front,
## posts stopping BBs as a miss, figures knocked down and stood up again with a player's hit volume, full spares, and
## targets turned to stand on a map.

const DT := 1.0 / 60.0
const KILL_Y := -10.0
const MASS := 0.25e-3
const Replicas := preload("res://tests/unit/replica_fixtures.gd")

var tuning: SimTuning = SimTuning.new()
var cfg: RangeConfig = tuning.targets
var specs: Array[RangeTarget.Spec] = []
var events: SimEvents = SimEvents.new()
var no_wall: WorldQuery = WorldQuery.new()
var nobody: Array[Character] = []
var ends: Array[MapEnd] = []
var hit: RangeTargets.Hit = RangeTargets.Hit.new()


func before_all() -> void:
	specs = MapData.load_map("range", MapStyle.new(), 1).targets


func before_each() -> void:
	events = SimEvents.new()


func _targets() -> Array[RangeTarget]:
	return RangeTargets.create(specs, tuning)


func _first(targets: Array[RangeTarget], kind: RangeTarget.Kind, crouched: bool = false) -> RangeTarget:
	for t in targets:
		if t.kind == kind and t.crouched == crouched:
			return t
	return null


## A spec from the fields that matter for it (config/range.ts targetSpec): a still target facing +z unless told.
static func spec(kind: RangeTarget.Kind, at: Vector3, label: String, distance: float, yaw: float = 0.0) \
		-> RangeTarget.Spec:
	var s := RangeTarget.Spec.new()
	s.kind = kind
	s.position = at
	s.label = label
	s.distance = distance
	s.yaw = yaw
	s.radius = RangeConfig.new().plate_radius if kind == RangeTarget.Kind.STEEL else 0.0
	return s


## Flies a 80 m/s BB from `from` along -z through `targets` for ten ticks.
func _shoot(from: Vector3, targets: Array[RangeTarget]) -> void:
	var pool := BBPool.new(2)
	pool.spawn(0, from, Vector3.FORWARD, 80.0, 0.0, MASS, tuning.ballistics.spin_per_hop)
	for i in 10:
		BBStep.step(pool, nobody, no_wall, tuning, KILL_Y, false, ends, events, DT, Vector3.ZERO, null, targets)
		if not pool.bbs[0].active:
			return


func _events_of(kind: GameEvent.Kind) -> Array[GameEvent]:
	var out: Array[GameEvent] = []
	for i in events.count:
		if events.items[i].kind == kind:
			out.append(events.items[i])
	return out


func test_lays_out_every_lane_at_every_distance_steel_at_chest_height_figures_on_the_floor() -> void:
	var targets := _targets()
	var lane_count := cfg.lane_x.size() * cfg.distances.size()
	assert_eq(targets.size(), 30, "the lanes, eleven other targets and the START plate")
	for i in targets.size():
		assert_eq(targets[i].id, i)
	for i in lane_count:
		var t := targets[i]
		assert_eq(t.motion, RangeTarget.Motion.STILL)
		assert_eq(t.position.z, -t.distance)
		assert_eq(t.position.y, cfg.plate_height if t.kind == RangeTarget.Kind.STEEL else 0.0)
	for t in targets:
		assert_lt(absf(t.position.x), cfg.half_width - 1.0, t.label)
		if t.crouched:
			assert_eq(t.kind, RangeTarget.Kind.FIGURE, "only figures crouch")


func test_never_hides_one_target_behind_another_from_where_you_start_moving_or_not() -> void:
	var targets := _targets()
	for t in targets:
		if t.motion == RangeTarget.Motion.POPUP:
			t.down = 0.0 # every pop-up standing at once
		t.hidden = false # the START plate too
	var eye := Vector3(0.0, tuning.body.stand_eye_height, cfg.spawn_back)
	var wrong: Array[String] = []
	# Over two of the slowest cycles, every 0.1 s: movers along their tracks, swingers through their swing.
	for step in 120:
		for i in targets.size():
			var t := targets[i]
			# Aim at the middle of what can be hit: the plate's centre, a figure's chest (or a crouched one's).
			var lift := 0.0 if t.kind == RangeTarget.Kind.STEEL else (0.7 if t.crouched else 1.2)
			var aim := Vector3(t.position.x, t.position.y + lift, t.position.z)
			RangeTargets.first_hit(eye, (aim - eye).normalized(), 100.0, targets, cfg, hit)
			if hit.index != i or hit.post:
				wrong.append("%s %d m at %.1f s: hit %d%s" % [t.label, t.distance, step * 0.1, hit.index,
						" (post)" if hit.post else ""])
		RangeTargets.step(targets, tuning, 0.1)
		for t in targets:
			if t.motion == RangeTarget.Motion.POPUP:
				t.down = 0.0
	assert_eq(wrong, [] as Array[String])


func test_rings_steel_only_from_the_front_inside_the_plate() -> void:
	var plate := _first(_targets(), RangeTarget.Kind.STEEL)
	var p := plate.position
	var front := Vector3(p.x, p.y, p.z + 5.0)
	assert_almost_eq(RangeTargets.ray_target(front, Vector3.FORWARD, 10.0, plate), 5.0, 1e-6)
	var beside := Vector3(p.x + cfg.plate_radius + 0.01, p.y, p.z + 5.0)
	assert_eq(RangeTargets.ray_target(beside, Vector3.FORWARD, 10.0, plate), INF)
	assert_eq(RangeTargets.ray_target(Vector3(p.x, p.y, p.z - 5.0), Vector3.BACK, 10.0, plate), INF, "from behind")
	assert_eq(RangeTargets.ray_target(front, Vector3.FORWARD, 4.0, plate), INF, "out of reach this tick")


func test_stops_a_bb_on_a_plates_post_as_a_miss_without_ringing_the_plate() -> void:
	var targets := _targets()
	var plate := _first(targets, RangeTarget.Kind.STEEL)
	_shoot(Vector3(plate.position.x, 0.5, plate.position.z + 5.0), targets) # under the plate, at the post
	assert_eq(_events_of(GameEvent.Kind.TARGET_HIT).size(), 0)
	var impacts := _events_of(GameEvent.Kind.BB_IMPACT)
	assert_eq(impacts.size(), 1)
	if impacts.size() == 1:
		assert_almost_eq(impacts[0].position.z, plate.position.z - cfg.post_behind + cfg.post_width / 2.0, 0.005)
		assert_eq(impacts[0].value2, RayHit.Surface.METAL, "the post is steel")
		assert_eq(impacts[0].target, -1, "no body")


func test_knocks_a_figure_down_for_a_while_then_stands_it_up_again() -> void:
	var targets := _targets()
	var figure := _first(targets, RangeTarget.Kind.FIGURE)
	var p := figure.position
	var from := Vector3(p.x, 1.2, p.z + 5.0)
	assert_gt(RangeTargets.ray_target(from, Vector3.FORWARD, 10.0, figure), 4.5)
	_shoot(from, targets)
	var hits := _events_of(GameEvent.Kind.TARGET_HIT)
	assert_eq(hits.size(), 1)
	if hits.size() == 1:
		assert_eq([hits[0].target, hits[0].actor, hits[0].value, hits[0].value2],
				[figure.id, 0, RangeTarget.Kind.FIGURE, 0], "target, shooter, kind, not a ricochet")
		assert_almost_eq(hits[0].position.z, p.z, 0.3, "where it met the figure")
	assert_eq(figure.down, cfg.figure_down_time)
	assert_eq(RangeTargets.ray_target(from, Vector3.FORWARD, 10.0, figure), INF, "down: BBs fly past it")
	var t := 0.0
	while t < cfg.figure_down_time + DT:
		RangeTargets.step(targets, tuning, DT)
		t += DT
	assert_eq(figure.down, 0.0)
	assert_gt(RangeTargets.ray_target(from, Vector3.FORWARD, 10.0, figure), 4.5)


func test_a_plate_hit_rings_and_stops_the_bb_on_its_face() -> void:
	var targets := _targets()
	var plate := _first(targets, RangeTarget.Kind.STEEL)
	_shoot(Vector3(plate.position.x, plate.position.y, plate.position.z + 5.0), targets)
	var hits := _events_of(GameEvent.Kind.TARGET_HIT)
	assert_eq(hits.size(), 1)
	if hits.size() == 1:
		assert_eq([hits[0].target, hits[0].value], [plate.id, RangeTarget.Kind.STEEL])
		assert_almost_eq(hits[0].position.z, plate.position.z, 1e-4)
	assert_eq(plate.down, 0.0, "steel never goes down")


func test_a_bb_stops_on_the_nearer_of_a_body_and_a_target() -> void:
	var targets := _targets()
	var plate := _first(targets, RangeTarget.Kind.STEEL)
	var p := plate.position
	var shooter := Character.new(0, 0, Vector3(p.x, 0.0, p.z + 6.0), 0.0)
	var someone := Character.new(1, 0, Vector3(p.x, 0.0, p.z + 2.0), 0.0)
	var roster: Array[Character] = [shooter, someone]
	var pool := BBPool.new(2)
	pool.spawn(0, Vector3(p.x, p.y, p.z + 5.0), Vector3.FORWARD, 80.0, 0.0, MASS, tuning.ballistics.spin_per_hop)
	for i in 10:
		BBStep.step(pool, roster, no_wall, tuning, KILL_Y, false, ends, events, DT, Vector3.ZERO, null, targets)
		if not pool.bbs[0].active:
			break
	assert_eq(_events_of(GameEvent.Kind.TARGET_HIT).size(), 0, "the body in front took it")
	assert_eq(_events_of(GameEvent.Kind.CHARACTER_HIT).size(), 1)


func test_down_and_hidden_targets_and_a_cease_fire_let_bbs_through() -> void:
	var targets := _targets()
	var plate := _first(targets, RangeTarget.Kind.STEEL)
	var pool := BBPool.new(2)
	pool.spawn(0, plate.position + Vector3(0.0, 0.0, 5.0), Vector3.FORWARD, 80.0, 0.0, MASS,
			tuning.ballistics.spin_per_hop)
	for i in 10:
		BBStep.step(pool, nobody, no_wall, tuning, KILL_Y, true, ends, events, DT, Vector3.ZERO, null, targets)
	assert_eq(_events_of(GameEvent.Kind.TARGET_HIT).size(), 0, "a cease-fire: no target hits")
	plate.hidden = true
	events = SimEvents.new()
	var only: Array[RangeTarget] = [plate]
	_shoot(plate.position + Vector3(0.0, 0.0, 5.0), only)
	assert_eq(_events_of(GameEvent.Kind.TARGET_HIT).size(), 0, "hidden")
	assert_eq(_events_of(GameEvent.Kind.BB_IMPACT).size(), 0, "nor its post")


func test_stands_its_figures_exactly_as_tall_as_a_character_on_the_same_floor() -> void:
	# A plywood figure is Hitbox's built-in volume to the centimetre (audit SIM-12): level rays from in front, from the
	# floor to over the head, agree at every height. A match's characters wear the fit to the drawn figure instead (HV1).
	var plywood := tuning.hits.duplicate() as HitConfig
	plywood.fit = null
	for crouched: bool in [false, true]:
		var figure := _first(_targets(), RangeTarget.Kind.FIGURE, crouched)
		var p := figure.position
		var c := Character.new(0, 0, p + Vector3(0.0, tuning.body.rest_gap, 0.0), PI) # facing the firing line
		c.crouch_amount = 1.0 if crouched else 0.0
		var v := Hitbox.Volume.new()
		Hitbox.build_volume(c, plywood, v)
		var differ: Array[float] = []
		var y := p.y
		while y <= 1.9:
			var o := Vector3(p.x, y, p.z + 5.0)
			var on_range := not is_inf(RangeTargets.ray_target(o, Vector3.FORWARD, 10.0, figure))
			var in_match := not is_inf(Hitbox.ray_character(o, Vector3.FORWARD, 10.0, v))
			if on_range != in_match:
				differ.append(y)
			y += 0.005
		assert_eq(differ, [] as Array[float], "crouched" if crouched else "standing")


func test_gives_a_crouched_figure_a_crouched_hit_volume() -> void:
	var crouched := _first(_targets(), RangeTarget.Kind.FIGURE, true)
	var p := crouched.position
	assert_eq(RangeTargets.ray_target(Vector3(p.x, 1.4, p.z + 5.0), Vector3.FORWARD, 10.0, crouched), INF,
			"a BB at standing chest height flies over it")
	assert_gt(RangeTargets.ray_target(Vector3(p.x, 0.7, p.z + 5.0), Vector3.FORWARD, 10.0, crouched), 4.5)


func test_keeps_the_spare_magazines_full_but_leaves_the_loaded_one_to_you() -> void:
	var loadout: Array[ReplicaConfig] = [Replicas.aeg(), Replicas.pistol()]
	for r in loadout:
		r.mag_size = 30
		r.mags = 4
	var a := Armament.create(loadout)
	a.ammo[0].mag = 3
	for ammo in a.ammo:
		ammo.pouch.fill(0)
	RangeTargets.refill_spares(a)
	assert_eq(a.ammo[0].mag, 3)
	for i in a.ammo.size():
		assert_gt(a.ammo[i].pouch.size(), 0)
		for m in a.ammo[i].pouch:
			assert_eq(m, a.replicas[i].mag_size)


# Targets stood on a map (M94): a plate on a floor 3 m up at (10, 3, -4) turned to face +x, a figure beside it facing
# -x.

func _turned() -> Array[RangeTarget]:
	var on_map: Array[RangeTarget.Spec] = [
		spec(RangeTarget.Kind.STEEL, Vector3(10.0, 3.0 + cfg.plate_height, -4.0), "Steel", 20.0, PI / 2.0),
		spec(RangeTarget.Kind.FIGURE, Vector3(14.0, 3.0, -4.0), "Figure", 24.0, -PI / 2.0),
	]
	return RangeTargets.create(on_map, tuning)


func test_rings_a_turned_plate_only_from_the_side_it_faces() -> void:
	var plate := _turned()[0]
	var p := plate.position
	assert_eq(p.y, 3.0 + cfg.plate_height)
	assert_almost_eq(plate.floor_y, 3.0, 1e-9)
	assert_almost_eq(plate.face_x, 1.0, 1e-9)
	assert_almost_eq(plate.face_z, 0.0, 1e-9)
	assert_eq(plate.distance, 20.0)
	assert_almost_eq(RangeTargets.ray_target(p + Vector3(5.0, 0.0, 0.0), Vector3.LEFT, 10.0, plate), 5.0, 1e-6)
	assert_eq(RangeTargets.ray_target(p + Vector3(-5.0, 0.0, 0.0), Vector3.RIGHT, 10.0, plate), INF, "from behind")
	var beside := p + Vector3(5.0, 0.0, cfg.plate_radius + 0.01)
	assert_eq(RangeTargets.ray_target(beside, Vector3.LEFT, 10.0, plate), INF)
	# From in front and off to one side, at a slant: still the plate.
	var o := p + Vector3(4.0, 0.0, 3.0)
	var d := Vector3(p.x - o.x, 0.0, p.z - o.z).normalized()
	assert_almost_eq(RangeTargets.ray_target(o, d, 10.0, plate), 5.0, 1e-6)


func test_puts_a_turned_plates_post_behind_it_from_its_floor_up() -> void:
	var plate := _turned()[0]
	var p := plate.position
	var only: Array[RangeTarget] = [plate]
	# Level, along the plate's face, under the plate: the post is post_behind behind it (-x), standing on its floor.
	RangeTargets.first_hit(Vector3(p.x + 5.0, 3.3, p.z), Vector3.LEFT, 10.0, only, cfg, hit)
	assert_true(hit.post)
	assert_almost_eq(hit.at, 5.0 + cfg.post_behind - cfg.post_width / 2.0, 0.005)
	RangeTargets.first_hit(Vector3(p.x + 5.0, 2.9, p.z), Vector3.LEFT, 10.0, only, cfg, hit)
	assert_eq(hit.index, -1, "below its floor there's no post")


func test_knocks_a_figure_down_from_any_side_hit_at_a_players_height_above_its_own_floor() -> void:
	var figure := _turned()[1]
	var p := figure.position
	assert_eq(p.y, 3.0)
	assert_gt(RangeTargets.ray_target(Vector3(p.x - 5.0, 4.2, p.z), Vector3.RIGHT, 10.0, figure), 4.5)
	assert_gt(RangeTargets.ray_target(Vector3(p.x + 5.0, 4.2, p.z), Vector3.LEFT, 10.0, figure), 4.5)
	var over := 3.0 + tuning.body.rest_gap + Hitbox.hit_top(0.0, tuning.hits) + 0.01
	assert_eq(RangeTargets.ray_target(Vector3(p.x - 5.0, over, p.z), Vector3.RIGHT, 10.0, figure), INF, "over its head")


func test_stands_the_range_just_as_before_every_target_facing_the_firing_line_from_the_floor() -> void:
	for t in _targets():
		assert_almost_eq(t.face_x, 0.0, 1e-12, t.label)
		assert_eq(t.face_z, 1.0, t.label)
		assert_almost_eq(t.floor_y, 0.0, 1e-6, t.label) # Vector3 is single precision


func test_skipping_targets_a_bb_cant_reach_never_changes_what_it_meets() -> void:
	# The reach spheres are first_hit's broadphase: with them off (every reach endless) every ray meets the same target
	# at the same distance, moving targets anywhere on their track or swing included.
	var targets := _targets()
	var open := _targets()
	for t in open:
		t.reach = INF
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var other := RangeTargets.Hit.new()
	var met := 0
	for tick in 900:
		RangeTargets.step(targets, tuning, DT * 3.0)
		RangeTargets.step(open, tuning, DT * 3.0)
		for n in 8:
			var aim := targets[rng.randi_range(0, targets.size() - 1)]
			var o := Vector3(rng.randf_range(-6.0, 6.0), rng.randf_range(0.5, 2.0), rng.randf_range(-4.0, 2.0))
			var to := aim.position + Vector3(rng.randf_range(-0.8, 0.8), rng.randf_range(-0.2, 1.9),
					rng.randf_range(-0.8, 0.8))
			var d := (to - o).normalized()
			var max_t := rng.randf_range(0.5, 80.0)
			RangeTargets.first_hit(o, d, max_t, targets, cfg, hit)
			RangeTargets.first_hit(o, d, max_t, open, cfg, other)
			assert_eq([hit.index, hit.post], [other.index, other.post])
			assert_almost_eq(hit.at, other.at, 1e-5)
			if hit.index >= 0:
				met += 1
	assert_gt(met, 500, "plenty of rays meet something, so the test reaches the narrow phase")


func test_a_mover_waiting_at_a_track_end_keeps_its_hit_volume() -> void:
	var targets := _targets()
	var mover: RangeTarget = null
	for t in targets:
		if t.motion == RangeTarget.Motion.MOVER and t.kind == RangeTarget.Kind.FIGURE:
			mover = t
	mover.clock = 0.0
	RangeTargets.step(targets, tuning, DT)
	var built := mover.volume.head.a
	var at := mover.position
	RangeTargets.step(targets, tuning, DT)
	assert_eq(mover.position, at, "still waiting out its dwell")
	assert_eq(mover.volume.head.a, built)
	mover.clock = cfg.mover_dwell + 0.5
	RangeTargets.step(targets, tuning, DT)
	assert_ne(mover.position, at)
	assert_almost_eq(mover.volume.head.a.x - built.x, mover.position.x - at.x, 1e-4, "its volume went with it")
