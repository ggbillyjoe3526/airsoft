extends GutTest
## SR1 · The Street's metal railings are bars you can see and shoot through: a BB meets only the bars and rails its
## path crosses (Railings, WorldQuery.bb_ray, BBStep) and flies on through the gaps; sight and a bot's shot pass the
## railing's box (sight_ray, ray_past_railings), so it is no cover; movers and the level ray still meet the box. On
## BoxWorld, on a built MapLevel's Jolt colliders, and on The Street, whose bars are drawn from the same numbers.

const DT := 1.0 / 60.0
const KILL_Y := -10.0
const MASS := 0.25e-3
const SPEED := 90.0
const EPS := 1e-3
## Yaw that looks along +X.
const EAST := -PI * 0.5
## A 4 m run along x at z 0, 1 m tall and 0.08 m deep, standing on the floor (y 0).
const RUN_CENTER := Vector3(0.0, 0.5, 0.0)
const RUN_SIZE := Vector3(4.0, 1.0, 0.08)
const RAILING := '{"kind": "railing", "center": {"x": 0, "y": 0.5, "z": 0}, "size": {"x": 4, "y": 1, "z": 0.08}}'
const WALL := '{"kind": "wall", "center": {"x": 0, "y": 1, "z": 3}, "size": {"x": 6, "y": 2, "z": 0.3}}'
const FLOOR := '{"kind": "floor", "center": {"x": 0, "y": -0.5, "z": 0}, "size": {"x": 12, "y": 1, "z": 12}}'

var play: PlayTuning = PlayTuning.load_default()
var tuning: SimTuning = SimTuning.load_default()
var config: BotConfig = BotConfig.load_default()


func _run() -> Railings:
	var r := Railings.new()
	r.add(RUN_CENTER, RUN_SIZE)
	return r


## The middle of bar `k` of `r`'s run 0 along x.
static func _bar_x(r: Railings, k: int) -> float:
	return r.mins[0].x + r.config.bar_width * 0.5 + k * r.pitches[0]


## A shot along +z from z -1 at (x, y) through run 0.
static func _straight(r: Railings, x: float, y: float, hit: RayHit) -> bool:
	return r.first_bar(Vector3(x, y, -1.0), Vector3.BACK, 2.0, hit)


func test_a_bb_between_two_bars_flies_on_and_one_at_a_bar_stops_on_its_face() -> void:
	var r := _run()
	var hit := RayHit.new()
	var gap := (_bar_x(r, 10) + _bar_x(r, 11)) * 0.5
	assert_false(_straight(r, gap, 0.5, hit), "through the gap")
	assert_true(_straight(r, _bar_x(r, 10), 0.5, hit), "on the bar")
	assert_almost_eq(hit.position.z, -r.config.bar_width * 0.5, EPS, "on the bar's near face")
	assert_almost_eq(hit.normal, Vector3.FORWARD, Vector3.ONE * EPS, "facing the shooter")
	assert_eq(hit.surface, RayHit.Surface.METAL)
	assert_almost_eq(hit.fraction, (1.0 - r.config.bar_width * 0.5) / 2.0, EPS, "a share of the path")


func test_the_top_and_bottom_rails_stop_a_bb_and_the_gap_under_the_bottom_rail_does_not() -> void:
	var r := _run()
	var cfg := r.config
	var hit := RayHit.new()
	var gap := (_bar_x(r, 3) + _bar_x(r, 4)) * 0.5
	assert_true(_straight(r, gap, 1.0 - cfg.rail_height * 0.5, hit), "the top rail")
	assert_almost_eq(hit.position.z, -RUN_SIZE.z * 0.5, EPS, "on the rail's face: it runs the run's depth")
	assert_true(_straight(r, gap, cfg.foot_gap + cfg.rail_height * 0.5, hit), "the bottom rail")
	assert_false(_straight(r, gap, cfg.foot_gap * 0.5, hit), "under it, between the bars' feet")
	assert_true(r.first_bar(Vector3(gap, 2.0, 0.0), Vector3.DOWN, 2.0, hit), "dropping onto the top rail")
	assert_almost_eq(hit.position.y, 1.0, EPS)
	assert_almost_eq(hit.normal, Vector3.UP, Vector3.ONE * EPS)


func test_most_straight_shots_go_through() -> void:
	var r := _run()
	var hit := RayHit.new()
	var through := 0
	var shots := 0
	var x := -1.9
	while x < 1.9:
		for y: float in [0.05, 0.3, 0.5, 0.7, 0.9]:
			shots += 1
			if not _straight(r, x, y, hit):
				through += 1
		x += 0.003
	var share := float(through) / shots
	assert_between(share, 0.7, 0.85, "most BBs go through, a bar's width in every pitch stops (%.2f)" % share)


func test_a_bb_along_the_run_meets_the_next_bar_side_on() -> void:
	var r := _run()
	var hit := RayHit.new()
	var from := Vector3((_bar_x(r, 7) + _bar_x(r, 8)) * 0.5, 0.5, 0.0)
	assert_true(r.first_bar(from, Vector3.RIGHT, 1.0, hit))
	assert_almost_eq(hit.position.x, _bar_x(r, 8) - r.config.bar_width * 0.5, EPS, "bar 8's near side")
	assert_almost_eq(hit.normal, Vector3.LEFT, Vector3.ONE * EPS)
	assert_true(r.first_bar(from, Vector3.LEFT, 1.0, hit), "and the other way")
	assert_almost_eq(hit.position.x, _bar_x(r, 7) + r.config.bar_width * 0.5, EPS, "bar 7's near side")


## The first of `boxes` the segment from `a` to `b` meets, as a share of it (INF for none): the reference.
static func _reference(boxes: Array[AABB], a: Vector3, b: Vector3) -> float:
	var best := INF
	for box in boxes:
		var p: Variant = box.intersects_segment(a, b)
		if p != null:
			best = minf(best, a.distance_to(p as Vector3) / a.distance_to(b))
	return best


func test_the_bars_a_bb_meets_are_the_bars_drawn() -> void:
	var r := Railings.new()
	r.add(RUN_CENTER, RUN_SIZE)
	r.add(Vector3(5.0, 0.5, 1.0), Vector3(0.08, 1.0, 6.0))
	r.add(Vector3(-6.0, 0.6, -3.0), Vector3(3.0, 1.2, 0.08))
	var boxes: Array[AABB] = []
	for i in r.size():
		r.parts(i, boxes)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var hit := RayHit.new()
	var worst := 0.0
	var met := 0
	var missed := 0
	for i in 3000:
		var a := Vector3(rng.randf_range(-8.0, 7.0), rng.randf_range(-0.2, 1.4), rng.randf_range(-5.0, 5.0))
		var dir := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.3, 0.3), rng.randf_range(-1.0, 1.0)) \
				.normalized()
		var reach := rng.randf_range(0.5, 6.0)
		var want := _reference(boxes, a, a + dir * reach)
		var got := INF
		if r.first_bar(a, dir, reach, hit):
			got = hit.fraction
			met += 1
		if is_inf(want) != is_inf(got):
			missed += 1
		elif not is_inf(want):
			worst = maxf(worst, absf(want - got) * reach)
	assert_eq(missed, 0, "met where a drawn bar or rail is, and only there")
	assert_lt(worst, EPS, "at the same point (m)")
	assert_gt(met, 100, "enough paths meet one to mean something")


func test_a_runs_parts_are_its_bars_evenly_spaced_end_to_end_and_its_two_rails() -> void:
	var r := _run()
	var boxes: Array[AABB] = []
	r.parts(0, boxes)
	assert_eq(boxes.size(), r.gaps[0] + 1 + 2, "a bar each side of every gap, and two rails")
	assert_almost_eq(boxes[0].position.x, -2.0, EPS, "the first bar at the run's end")
	assert_almost_eq(boxes[r.gaps[0]].end.x, 2.0, EPS, "the last at the other")
	assert_between(r.pitches[0], r.config.bar_pitch * 0.95, r.config.bar_pitch * 1.05, "as near the pitch as fits")


## A floor, a railing (`run`'s box) and a wall 3 m behind it.
func _box_world() -> BoxWorld:
	var w := BoxWorld.new(tuning.body)
	w.add_floor(40.0, 40.0)
	w.add_railing(RUN_CENTER, RUN_SIZE)
	w.add_box(Vector3(0.0, 1.0, 3.0), Vector3(6.0, 2.0, 0.3))
	return w


func test_a_box_worlds_railing_is_solid_to_ray_but_not_to_sight_and_bbs_meet_only_its_bars() -> void:
	var w := _box_world()
	var r := w.railings
	var hit := RayHit.new()
	var gap := (_bar_x(r, 10) + _bar_x(r, 11)) * 0.5
	var a := Vector3(gap, 0.5, -2.0)
	var b := Vector3(gap, 0.5, 5.0)
	assert_true(w.ray(a, b, hit), "the level ray meets the box")
	assert_almost_eq(hit.position.z, -0.04, EPS)
	assert_true(w.sight_ray(a, b, hit), "sight goes on to the wall")
	assert_almost_eq(hit.position.z, 2.85, EPS)
	assert_true(w.ray_past_railings(a, b, hit), "as does the ray past the railings")
	assert_almost_eq(hit.position.z, 2.85, EPS)
	assert_true(w.bb_ray(a, b, hit), "a BB through the gap lands on the wall")
	assert_almost_eq(hit.position.z, 2.85, EPS)
	var on_bar := Vector3(_bar_x(r, 10), 0.5, -2.0)
	assert_true(w.bb_ray(on_bar, on_bar + Vector3(0.0, 0.0, 7.0), hit), "one at a bar stops on it")
	assert_almost_eq(hit.position.z, -r.config.bar_width * 0.5, EPS)
	assert_almost_eq(hit.fraction, (2.0 - r.config.bar_width * 0.5) / 7.0, EPS, "its share of the whole path")
	assert_false(w.bb_ray(a, Vector3(gap, 0.5, 2.0), hit), "short of the wall it meets nothing")


## One BB fired along +z at (x, 0.5) from z -2, flown until it stops: where.
func _fly(w: BoxWorld, x: float) -> Vector3:
	var events := SimEvents.new()
	var ends: Array[MapEnd] = []
	var pool := BBPool.new(1)
	var bb := pool.spawn(1, Vector3(x, 0.5, -2.0), Vector3.BACK, SPEED, 0.0, MASS, 0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var ticks := 0
	while bb.active and ticks < 60:
		BBStep.step(pool, [] as Array[Character], w, tuning, KILL_Y, false, ends, events, DT, Vector3.ZERO, rng)
		ticks += 1
	for i in events.count:
		var e := events.items[i]
		if e.kind == GameEvent.Kind.BB_IMPACT:
			return e.position
	return Vector3.INF


func test_a_flying_bb_goes_through_a_gap_to_the_wall_and_stops_on_a_bar() -> void:
	var w := _box_world()
	var r := w.railings
	var through := _fly(w, (_bar_x(r, 10) + _bar_x(r, 11)) * 0.5)
	assert_almost_eq(through.z, 2.85, 0.01, "its first impact is the wall behind")
	var stopped := _fly(w, _bar_x(r, 10))
	assert_almost_eq(stopped.z, -r.config.bar_width * 0.5, 0.01, "its first impact is the bar")


func _level(blocks: Array[String]) -> MapLevel:
	var m := MapData.parse('{"blocks": [%s]}' % ",".join(blocks), play.map_style, 1)
	var level := MapLevel.new()
	add_child_autofree(level)
	level.build(m, play.map_style, tuning.body)
	return level


func test_a_built_levels_railing_is_solid_to_its_ray_and_its_bars_are_drawn() -> void:
	var level := _level([RAILING, WALL, FLOOR] as Array[String])
	var q := level.query()
	var r := q.railings
	assert_eq(r.size(), 1, "the railing is a run")
	var hit := RayHit.new()
	var gap := (_bar_x(r, 10) + _bar_x(r, 11)) * 0.5
	var a := Vector3(gap, 0.5, -2.0)
	var b := Vector3(gap, 0.5, 5.0)
	assert_true(q.ray(a, b, hit), "the level ray meets the box (bombs and bodies)")
	assert_almost_eq(hit.position.z, -0.04, 0.02)
	assert_eq(hit.surface, RayHit.Surface.METAL, "of the railing's surface")
	assert_true(q.sight_ray(a, b, hit), "sight passes it")
	assert_almost_eq(hit.position.z, 2.85, 0.02, "to the wall")
	assert_true(q.bb_ray(a, b, hit), "so does a BB through a gap")
	assert_almost_eq(hit.position.z, 2.85, 0.02)
	var on_bar := Vector3(_bar_x(r, 10), 0.5, -2.0)
	assert_true(q.bb_ray(on_bar, on_bar + Vector3(0.0, 0.0, 7.0), hit), "a BB at a bar stops on it")
	assert_almost_eq(hit.position.z, -r.config.bar_width * 0.5, 0.02)
	var bars := level.get_node_or_null(^"Railings") as MeshInstance3D
	assert_not_null(bars, "the bars drawn as a mesh of their own")
	if bars != null:
		var boxes: Array[AABB] = []
		r.parts(0, boxes)
		assert_eq(bars.mesh.surface_get_array_len(0), boxes.size() * 36, "every bar and rail, six faces each")


func test_a_level_with_no_railings_has_no_rays_or_mesh_for_them() -> void:
	var level := _level([WALL, FLOOR] as Array[String])
	assert_null(level.get_node_or_null(^"PastRailingsRay"))
	assert_null(level.get_node_or_null(^"Railings"))
	assert_true(level.query().railings.is_empty())


## A BotWorld on `query`: a viewer at the origin looking east, a target 6 m east.
func _sight_world(query: WorldQuery) -> BotWorld:
	var w := BotWorld.new()
	w.cfg = config
	w.tuning = tuning
	w.query = query
	var loadout := ReplicaStats.default_loadout()
	w.characters.append(Character.new(0, 0, Vector3.ZERO, EAST, loadout))
	w.characters.append(Character.new(1, 1, Vector3(6.0, 0.0, 0.0), -EAST, loadout))
	return w


func test_a_bot_sees_and_shoots_through_a_railing_and_it_is_no_cover() -> void:
	var box := BoxWorld.new(tuning.body)
	box.add_floor(40.0, 40.0)
	# Taller than anyone, so only its gaps let the eye through.
	box.add_railing(Vector3(3.0, 1.0, 0.0), Vector3(0.08, 2.0, 4.0))
	box.add_box(Vector3(-3.0, 1.0, 0.0), Vector3(0.08, 2.0, 4.0))
	var w := _sight_world(box)
	var viewer := w.characters[0]
	var target := w.characters[1]
	var eye := BotSenses.eye_of(viewer, tuning)
	var chest := BotSenses.body_point(target, tuning.hits, config.aim_height_fraction)
	assert_gt(BotSenses.visible_part(viewer, target, w), 0.0, "seen through the bars")
	assert_true(BotSenses.shot_clear(w.query, eye, chest), "and a shot it takes")
	assert_false(BotSenses.line_clear(w.query, eye, chest), "though the box is there to walk into")
	var threat := Vector3(10.0, tuning.body.stand_eye_height, 0.0)
	assert_false(BotCover.hides_from(Vector3(2.0, 0.0, 0.0), threat, w), "behind the railing you are still seen")
	assert_true(BotCover.hides_from(Vector3(-2.0, 0.0, 0.0), Vector3(-10.0, threat.y, 0.0), w),
			"behind the same box solid you are hidden")


func test_every_railing_on_the_street_is_bars_and_its_garden_fences_stay_solid() -> void:
	var map := MapData.load_map("street", play.map_style, 5)
	var level := MapLevel.new()
	add_child_autofree(level)
	level.build(map, play.map_style, tuning.body)
	var q := level.query()
	var railings := 0
	var fence: MapData.Block = null
	for b in map.blocks:
		if b.kind == &"railing":
			railings += 1
		elif b.kind == &"fence" and b.size.y > tuning.body.height and fence == null:
			fence = b
	assert_gt(railings, 0)
	assert_eq(q.railings.size(), railings, "every railing a run of bars")
	assert_not_null(level.get_node_or_null(^"Railings"), "drawn as bars")
	assert_not_null(fence, "a 6 ft garden fence")
	if fence != null:
		var thin := Vector3(1.0, 0.0, 0.0) if fence.size.x < fence.size.z else Vector3(0.0, 0.0, 1.0)
		var at := fence.center
		var hit := RayHit.new()
		assert_true(q.sight_ray(at - thin, at + thin, hit), "the wooden fence still hides (owner, 2026-11-01)")
		assert_true(q.bb_ray(at - thin, at + thin, hit), "and stops BBs")
