extends GutTest
## SR1 · QA's own hunt around the bar railings: the bar test against the drawn boxes over runs of every shape and rays of
## every kind (axis-aligned, grazing, starting inside), the nearer of a bar and the level, a mixed level of glass and
## railings, a ramp of the railing kind, movers meeting the box, BBs that bounce off bars, and what a query or a built
## level leaves behind.

const DT := 1.0 / 60.0
const MASS := 0.25e-3
const SPEED := 90.0
const EPS := 1e-3

var play: PlayTuning = PlayTuning.load_default()
var tuning: SimTuning = SimTuning.load_default()


## The nearest entry (share of a→b) into any of `boxes` along the segment, INF if none.
func _reference(boxes: Array[AABB], a: Vector3, b: Vector3) -> float:
	var best := INF
	var len := a.distance_to(b)
	for box in boxes:
		if box.has_point(a):
			return 0.0
		var p: Variant = box.intersects_segment(a, b)
		if p != null:
			best = minf(best, a.distance_to(p as Vector3) / len)
	return best


func _shapes() -> Railings:
	var r := Railings.new()
	r.add(Vector3(0.0, 0.5, 0.0), Vector3(4.0, 1.0, 0.08))        # along x
	r.add(Vector3(5.0, 0.5, 1.0), Vector3(0.08, 1.0, 6.0))        # along z
	r.add(Vector3(-6.0, 0.6, -3.0), Vector3(3.0, 1.2, 0.3))       # deep
	r.add(Vector3(-6.0, 0.075, 3.0), Vector3(2.0, 0.15, 0.08))    # too low for a foot rail
	r.add(Vector3(2.0, 0.5, -4.0), Vector3(0.1, 1.0, 0.06))       # shorter than two bars
	r.add(Vector3(-2.0, 0.5, 5.0), Vector3(0.5, 1.0, 0.5))        # square
	return r


func test_the_bars_agree_with_the_drawn_boxes_over_every_shape_and_kind_of_ray() -> void:
	var r := _shapes()
	var boxes: Array[AABB] = []
	for i in r.size():
		r.parts(i, boxes)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var hit := RayHit.new()
	var wrong := 0
	var worst := 0.0
	var met := 0
	for i in 8000:
		var a := Vector3(rng.randf_range(-8.0, 7.0), rng.randf_range(-0.1, 1.4), rng.randf_range(-6.0, 6.0))
		var d := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.4, 0.4), rng.randf_range(-1.0, 1.0))
		match i % 6:
			0:
				d = Vector3(signf(d.x), 0.0, 0.0)   # exactly along x
			1:
				d = Vector3(0.0, 0.0, signf(d.z))   # exactly along z
			2:
				d = Vector3(0.0, signf(d.y), 0.0)   # straight up or down
			3:
				d = Vector3(d.x, 0.0, d.z * 0.001)  # grazing along a run
		d = d.normalized()
		var reach := rng.randf_range(0.02, 3.0)     # a tick's travel and longer
		var want := _reference(boxes, a, a + d * reach)
		var got := INF
		if r.first_bar(a, d, reach, hit):
			got = hit.fraction
			met += 1
		if is_inf(want) != is_inf(got):
			wrong += 1
		elif not is_inf(want):
			worst = maxf(worst, absf(want - got) * reach)
	assert_eq(wrong, 0, "a bar met where a drawn bar is, and only there")
	assert_lt(worst, EPS, "at the same distance")
	assert_gt(met, 60, "enough met to mean something")


func test_a_hits_point_and_normal_are_on_the_face_it_crossed() -> void:
	var r := _shapes()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var hit := RayHit.new()
	var bad := 0
	for i in 3000:
		var a := Vector3(rng.randf_range(-8.0, 7.0), rng.randf_range(0.0, 1.2), rng.randf_range(-6.0, 6.0))
		var d := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.3, 0.3), rng.randf_range(-1.0, 1.0)).normalized()
		if r.first_bar(a, d, 3.0, hit):
			if hit.fraction > 0.0 and (not is_equal_approx(hit.normal.length(), 1.0) or hit.normal.dot(d) > EPS):
				bad += 1
			if absf(hit.position.distance_to(a) - hit.fraction * 3.0) > EPS:
				bad += 1
	assert_eq(bad, 0, "the normal faces the shooter and the point is where the fraction says")


func test_a_bb_meets_the_nearer_of_a_bar_and_the_level() -> void:
	var w := BoxWorld.new(tuning.body)
	w.add_floor(40.0, 40.0)
	w.add_railing(Vector3(0.0, 0.5, 0.0), Vector3(4.0, 1.0, 0.08))
	w.add_box(Vector3(0.0, 1.0, -3.0), Vector3(6.0, 2.0, 0.3))   # a wall in front of the railing, face at z -2.85
	w.add_box(Vector3(0.0, 1.0, 3.0), Vector3(6.0, 2.0, 0.3))    # and one behind, face at z 2.85
	var r := w.railings
	var x := r.mins[0].x + r.config.bar_width * 0.5 + 10.0 * r.pitches[0]
	var hit := RayHit.new()
	assert_true(w.bb_ray(Vector3(x, 0.5, -6.0), Vector3(x, 0.5, 6.0), hit))
	assert_almost_eq(hit.position.z, -3.15, EPS, "the wall in front stops it, the bars behind it never asked")
	assert_almost_eq(hit.fraction, (6.0 - 3.15) / 12.0, EPS)
	assert_true(w.bb_ray(Vector3(x, 0.5, -2.0), Vector3(x, 0.5, 6.0), hit))
	assert_almost_eq(hit.position.z, -r.config.bar_width * 0.5, EPS, "from between the walls it meets the bar first")
	assert_almost_eq(hit.fraction, (2.0 - r.config.bar_width * 0.5) / 8.0, EPS, "a share of the whole segment")
	assert_true(w.bb_ray(Vector3(x, 0.5, 1.0), Vector3(x, 0.5, 6.0), hit))
	assert_almost_eq(hit.position.z, 2.85, EPS, "past the railing the wall is the next thing")


func test_degenerate_segments_meet_nothing_and_do_not_fault() -> void:
	var w := BoxWorld.new(tuning.body)
	w.add_floor(40.0, 40.0)
	w.add_railing(Vector3(0.0, 0.5, 0.0), Vector3(4.0, 1.0, 0.08))
	var hit := RayHit.new()
	var at := Vector3(0.0, 0.5, -1.0)
	assert_false(w.bb_ray(at, at, hit), "a segment of no length")
	assert_false(w.bb_ray(at, at + Vector3(0.0, 0.0, 0.0005), hit), "or a speck of one")
	var empty := Railings.new()
	assert_false(empty.first_bar(at, Vector3.BACK, 5.0, hit), "no railings")
	var r := Railings.new()
	r.add(Vector3.ZERO, Vector3(4.0, 1.0, 0.08))
	assert_false(r.first_bar(at, Vector3.BACK, 0.0, hit), "no length")
	assert_false(r.first_bar(at, Vector3.BACK, -1.0, hit), "negative length")
	assert_false(r.first_bar(at, Vector3.BACK, NAN, hit), "no number")
	r.add(Vector3(100.0, 0.0, 100.0), Vector3(4.0, 1.0, 0.08))
	assert_false(r.first_bar(Vector3(-900.0, 0.5, -900.0), Vector3.BACK, 5.0, hit), "far outside the index")


func test_a_bb_starting_inside_a_runs_box_flies_out_of_a_gap_and_stops_in_a_bar() -> void:
	var r := Railings.new()
	r.add(Vector3(0.0, 0.5, 0.0), Vector3(4.0, 1.0, 0.08))
	var hit := RayHit.new()
	var gap := r.mins[0].x + r.config.bar_width + r.pitches[0] * 0.5 - r.config.bar_width * 0.5 + 2.0 * r.pitches[0]
	assert_false(r.first_bar(Vector3(gap, 0.5, 0.0), Vector3.BACK, 1.0, hit), "out of a gap")
	var bar := r.mins[0].x + r.config.bar_width * 0.5 + 5.0 * r.pitches[0]
	assert_true(r.first_bar(Vector3(bar, 0.5, 0.0), Vector3.BACK, 1.0, hit), "in a bar: stopped where it is")
	assert_almost_eq(hit.fraction, 0.0, EPS)


func test_bbs_that_bounce_off_bars_come_to_rest_and_never_stick_in_a_loop() -> void:
	var w := BoxWorld.new(tuning.body)
	w.add_floor(40.0, 40.0)
	w.add_railing(Vector3(0.0, 0.5, 0.0), Vector3(4.0, 1.0, 0.08))
	var events := SimEvents.new()
	var ends: Array[MapEnd] = []
	var pool := BBPool.new(1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var worst_impacts := 0
	var alive := 0
	for shot in 300:
		var from := Vector3(rng.randf_range(-2.0, 2.0), rng.randf_range(0.05, 1.0), rng.randf_range(-3.0, -1.0))
		var aim := Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.1, 0.1), 1.0).normalized()
		var bb := pool.spawn(1, from, aim, SPEED, 0.0, MASS, 0.0)
		events.count = 0
		var ticks := 0
		while bb.active and ticks < 600:
			BBStep.step(pool, [] as Array[Character], w, tuning, -10.0, false, ends, events, DT, Vector3.ZERO, rng)
			ticks += 1
		var impacts := 0
		for i in events.count:
			if events.items[i].kind == GameEvent.Kind.BB_IMPACT:
				impacts += 1
		worst_impacts = maxi(worst_impacts, impacts)
		if bb.active:
			alive += 1
	assert_eq(alive, 0, "every BB comes to rest or is lost within ten seconds")
	assert_lt(worst_impacts, 8, "no BB lands again and again on the bar it left")


func test_glass_beside_a_railing_still_stops_a_bb_and_the_railing_stays_see_through() -> void:
	var glass := '{"kind": "glass", "center": {"x": 0, "y": 1, "z": 2}, "size": {"x": 6, "y": 2, "z": 0.05}}'
	var railing := '{"kind": "railing", "center": {"x": 0, "y": 0.5, "z": 0}, "size": {"x": 4, "y": 1, "z": 0.08}}'
	var wall := '{"kind": "wall", "center": {"x": 0, "y": 1, "z": 4}, "size": {"x": 6, "y": 2, "z": 0.3}}'
	var floor_block := '{"kind": "floor", "center": {"x": 0, "y": -0.5, "z": 0}, "size": {"x": 12, "y": 1, "z": 12}}'
	var level := _level([glass, railing, wall, floor_block] as Array[String])
	var q := level.query()
	var r := q.railings
	var gap := r.mins[0].x + r.config.bar_width + r.pitches[0] * 0.5 - r.config.bar_width * 0.5 + 2.0 * r.pitches[0]
	var a := Vector3(gap, 0.5, -2.0)
	var b := Vector3(gap, 0.5, 6.0)
	var hit := RayHit.new()
	assert_true(q.sight_ray(a, b, hit), "sight reaches the wall")
	assert_almost_eq(hit.position.z, 3.85, 0.02, "through the railing and the glass")
	assert_true(q.ray_past_railings(a, b, hit), "the ray past the railings meets the glass")
	assert_almost_eq(hit.position.z, 1.975, 0.02)
	assert_true(q.bb_ray(a, b, hit), "so does a BB through the gap")
	assert_almost_eq(hit.position.z, 1.975, 0.02, "glass stops BBs")
	assert_true(q.ray(a, b, hit))
	assert_almost_eq(hit.position.z, -0.04, 0.02, "and the level ray meets the railing's box")


func test_a_ramp_of_the_railing_kind_is_an_ordinary_solid_block() -> void:
	var ramp := '{"kind": "railing", "center": {"x": 0, "y": 0.5, "z": 0}, "size": {"x": 2, "y": 1, "z": 2}, "rise": "+z"}'
	var floor_block := '{"kind": "floor", "center": {"x": 0, "y": -0.5, "z": 0}, "size": {"x": 12, "y": 1, "z": 12}}'
	var level := _level([ramp, floor_block] as Array[String])
	var q := level.query()
	assert_true(q.railings.is_empty(), "not a run of bars")
	assert_null(level.get_node_or_null(^"Railings"), "nothing drawn as bars")
	var hit := RayHit.new()
	assert_true(q.sight_ray(Vector3(0.0, 0.6, -3.0), Vector3(0.0, 0.6, 3.0), hit), "the wedge hides what is behind it")


func test_a_built_levels_mover_cannot_walk_through_a_railing() -> void:
	var railing := '{"kind": "railing", "center": {"x": 0, "y": 0.5, "z": 0}, "size": {"x": 4, "y": 1, "z": 0.08}}'
	var floor_block := '{"kind": "floor", "center": {"x": 0, "y": -0.5, "z": 0}, "size": {"x": 12, "y": 1, "z": 12}}'
	var level := _level([railing, floor_block] as Array[String])
	await wait_physics_frames(3)
	var c := Character.new(0, 0, Vector3(0.7, 0.0, -1.0), 0.0, ReplicaStats.default_loadout())
	var mover: CharacterMover = level.mover(tuning.body)
	var moved: Vector3 = mover.move(c, Vector3(0.0, 0.0, 2.0))
	assert_lt(moved.z, 1.0, "stopped by the railing's box, in a gap or not")
	c.position += moved
	assert_lt(c.position.z, 0.0, "still on its side")


func test_queries_allocate_no_objects_and_a_built_level_frees_its_nodes() -> void:
	var w := BoxWorld.new(tuning.body)
	w.add_floor(40.0, 40.0)
	for i in 40:
		w.add_railing(Vector3(i * 5.0, 0.5, 0.0), Vector3(4.0, 1.0, 0.08))
	var hit := RayHit.new()
	w.bb_ray(Vector3(0.0, 0.5, -1.0), Vector3(0.0, 0.5, 1.0), hit)
	var before := Performance.get_monitor(Performance.OBJECT_COUNT)
	for i in 5000:
		w.bb_ray(Vector3(i * 0.04, 0.3, -1.0), Vector3(i * 0.04 + 0.2, 0.7, 1.0), hit)
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), before, "5,000 BB rays leave no new objects")
	var railing := '{"kind": "railing", "center": {"x": 0, "y": 0.5, "z": 0}, "size": {"x": 4, "y": 1, "z": 0.08}}'
	var floor_block := '{"kind": "floor", "center": {"x": 0, "y": -0.5, "z": 0}, "size": {"x": 12, "y": 1, "z": 12}}'
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	for round in 3:
		var level := _level([railing, floor_block] as Array[String])
		level.queue_free()
		await wait_physics_frames(2)
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), 0.0, "no orphan nodes")
	assert_lte(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes + 1.0, "the level's nodes all freed")


func _level(blocks: Array[String]) -> MapLevel:
	var m := MapData.parse('{"blocks": [%s]}' % ",".join(blocks), play.map_style, 1)
	var level := MapLevel.new()
	add_child_autofree(level)
	level.build(m, play.map_style, tuning.body)
	return level
