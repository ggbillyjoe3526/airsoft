extends GutTest
## FB4 (the owner's 0.1 Dev 1 playtest, note 11): a white BB is easy to see and never seems to pass a wall. It is drawn
## with a darker rim, never under EffectsConfig.bb_min_angle on screen, with a faint short trail fading back along its
## flight (pooled: nothing made while drawing); your own BB joins its path from the muzzle's side, never ahead along it,
## so it is never drawn past the wall its true one stops on.

const DT := 1.0 / 60.0
const SPEED := 90.0
const MASS := 0.25e-3

var cfg: EffectsConfig = null


func before_each() -> void:
	cfg = EffectsConfig.new()


func _view(pool_size: int) -> BBView:
	var view := BBView.new()
	add_child_autofree(view)
	view.setup(cfg, pool_size)
	return view


func _fire(pool: BBPool, from: Vector3, dir: Vector3) -> BB:
	return pool.spawn(0, from, dir, SPEED, 0.0, MASS, 0.0)


func test_a_white_bb_is_rimmed_and_never_under_its_least_size_on_screen() -> void:
	var view := _view(4)
	var white := view.drawn_material() as ShaderMaterial
	assert_not_null(white, "drawn by bb_ball.gdshader")
	assert_eq(white.get_shader_parameter(&"colour"), cfg.bb_colour)
	assert_eq(white.get_shader_parameter(&"rim"), cfg.bb_rim_colour)
	for metres: float in [5.0, 20.0, 40.0]:
		var t := BBView.ball(cfg, Vector3(0.0, 0.0, -metres), Vector3.ZERO, cfg.bb_min_angle)
		assert_almost_eq(t.basis.get_scale().x * 0.5 / metres, cfg.bb_min_angle, 1e-7, "%s m" % metres)
	var close := BBView.ball(cfg, Vector3(0.0, 0.0, -0.5), Vector3.ZERO, cfg.bb_min_angle)
	assert_almost_eq(close.basis.get_scale().x, cfg.bb_size, 1e-6, "point-blank, a BB's size")
	var pool := BBPool.new(4)
	_fire(pool, Vector3(-5.0, 1.0, -20.0), Vector3.RIGHT)
	view.update(pool, 9, Vector3.ZERO, 0.0, DT, Vector3(0.0, 1.0, 0.0))
	assert_eq(view.multimesh.visible_instance_count, 1, "drawn")


func test_a_white_bb_leaves_a_faint_short_fading_trail() -> void:
	var view := _view(4)
	var draws := view.draws()
	assert_eq(draws.size(), 4, "white BBs, glowing balls, their streaks and the white trails")
	var trail := draws[3].multimesh.mesh.surface_get_material(0) as StandardMaterial3D
	assert_almost_eq(trail.albedo_color.a, cfg.bb_trail_opacity, 1e-6, "faint")
	assert_eq(trail.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA)
	assert_not_null(trail.albedo_texture, "fading to its tail")
	assert_lte(cfg.bb_trail_time, 0.02, "short: a BB's, not a tracer's")
	var pool := BBPool.new(4)
	var bb := _fire(pool, Vector3(-5.0, 1.0, -20.0), Vector3.RIGHT)
	bb.age = 1.0
	view.update(pool, 9, Vector3.ZERO, 0.0, DT, Vector3(0.0, 1.0, 0.0))
	assert_eq(draws[3].multimesh.visible_instance_count, 1, "one trail")
	assert_true(draws[3].visible)
	var t := BBView.streak_of(cfg, Vector3(0.0, 1.0, -20.0), Vector3.RIGHT * SPEED, 1.0, Vector3(0.0, 1.0, 0.0),
			cfg.bb_trail_time, cfg.bb_trail_angle)
	assert_almost_eq(t.basis.y.length(), SPEED * cfg.bb_trail_time, 1e-3, "bb_trail_time of its flight")
	assert_almost_eq(t.basis.x.length(), cfg.bb_trail_angle * t.origin.distance_to(Vector3(0.0, 1.0, 0.0)), 1e-4,
			"bb_trail_angle wide")
	assert_lt(t.origin.x, 0.0, "back along its flight")
	pool.bbs[0].active = false
	view.update(pool, 9, Vector3.ZERO, 0.0, DT, Vector3.ZERO)
	assert_false(draws[3].visible, "hidden with none in flight")


func test_no_trail_drawn_at_no_opacity() -> void:
	cfg.bb_trail_opacity = 0.0
	var view := _view(4)
	assert_eq(view.draws().size(), 3)
	assert_null(view.trail_material())


func test_drawing_makes_nothing() -> void:
	var view := _view(64)
	var pool := BBPool.new(64)
	for i in 60:
		# Flying away ahead of the muzzle: your own BBs show only once past it (BP8).
		_fire(pool, Vector3(-5.0 + 0.1 * i, 1.0, -10.0), Vector3.FORWARD.rotated(Vector3.UP, 0.01 * i))
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var objects := Performance.get_monitor(Performance.OBJECT_COUNT)
	for frame in 30:
		view.update(pool, 0, Vector3(0.1, -0.1, -0.3), frame / 30.0, DT, Vector3.ZERO)
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes, "no node made while drawing")
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), objects, "no object made while drawing")
	assert_eq(view.draws()[3].multimesh.visible_instance_count, 60, "a trail each")


func test_your_bb_is_never_drawn_past_the_wall_it_stops_on() -> void:
	# A wall 3 m in front of your eye; your muzzle 0.9 m ahead of the eye, to the right and below.
	var tuning := SimTuning.new()
	var world := BoxWorld.new(tuning.body)
	world.add_box(Vector3(0.0, 1.6, -3.2), Vector3(4.0, 4.0, 0.4))
	var eye := Vector3(0.0, 1.6, 0.0)
	var muzzle := Vector3(0.12, -0.19, -0.9)
	var pool := BBPool.new(4)
	var bb := _fire(pool, eye, Vector3.FORWARD)
	var events := SimEvents.new()
	var nobody: Array[Character] = []
	var ends: Array[MapEnd] = []
	var deepest := -INF
	for tick in 10:
		BBStep.step(pool, nobody, world, tuning, -10.0, false, ends, events, DT)
		for k in 5:
			deepest = maxf(deepest, -BBView.drawn_at(cfg, bb, 7, muzzle, k / 4.0, DT).z)
		if events.count_of(GameEvent.Kind.BB_IMPACT) > 0:
			break
	assert_eq(events.count_of(GameEvent.Kind.BB_IMPACT), 1, "control: it met the wall")
	assert_gt(deepest, 1.0, "control: it was drawn on its way")
	assert_lte(deepest, 3.0 + 1e-4, "never drawn past the wall's face")


func test_the_muzzle_join_keeps_only_the_offset_across_the_flight() -> void:
	var off := BBView.across_flight(Vector3(0.12, -0.19, -0.9), Vector3.FORWARD * SPEED)
	assert_almost_eq(off, Vector3(0.12, -0.19, 0.0), Vector3.ONE * 1e-6)
	assert_eq(BBView.across_flight(Vector3.ONE, Vector3.ZERO), Vector3.ONE, "no flight: all of it")


func test_every_bb_is_the_blender_ball_in_its_own_material() -> void:
	var view := _view(4)
	var mesh := view.multimesh.mesh
	assert_false(mesh is PrimitiveMesh, "BM1: the Blender BB, not a code-made ball")
	assert_same(view.draws()[1].multimesh.mesh, mesh, "white and glowing BBs share the one mesh")
	var tris := mesh.get_faces().size() / 3
	assert_between(tris, 200, 400, "round up close, cheap with the whole pool in the air")
	var box := mesh.get_aabb()
	assert_almost_eq(box.size.x, 1.0, 0.02, "modelled 1 m across: drawn bb_size wide")
	assert_almost_eq(box.get_center().length(), 0.0, 1e-3, "centred")
	assert_true(view.draws()[0].material_override is ShaderMaterial, "white: rimmed")
	assert_true(view.draws()[1].material_override is StandardMaterial3D, "glowing: lit itself")


func test_an_unreadable_bb_model_still_draws_a_ball() -> void:
	var mesh := BBView.bb_mesh("res://assets/models/effects/missing.glb")
	assert_true(mesh is SphereMesh, "a code-made ball of the same size")
	assert_almost_eq(mesh.get_aabb().get_longest_axis_size(), 1.0, 1e-3)
