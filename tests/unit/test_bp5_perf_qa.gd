extends GutTest
## QA for BP5 performance: the quick tests only ever skip what the full tests would skip, and an unseen figure keeps
## its trigger press until its next pose.

var config: FigureConfig = null
var models: FigureModels = null
var hits: HitConfig = HitConfig.new()


func before_all() -> void:
	config = FigureConfig.new()
	models = FigureModels.new(config)
	models.load_kinds()


func test_flight_time_never_shrinks_with_distance() -> void:
	var rules := ReplicaRulesConfig.new()
	var ball := BallisticsConfig.new()
	var replica := ReplicaConfig.new()
	var v := Ballistics.muzzle_velocity(replica, rules)
	var m := Ballistics.bb_mass(replica)
	var last := 0.0
	for d in range(0, 400, 5):
		var t := Ballistics.flight_time_estimate(float(d), v, m, ball)
		assert_gte(t, last, "flight to %d m" % d)
		last = t


func test_a_wider_margin_never_loses_a_touch() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	var lost := 0
	for i in 3000:
		c.position = Vector3(rng.randf_range(-8.0, 8.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-8.0, 8.0))
		var o := Vector3(rng.randf_range(-4.0, 4.0), rng.randf_range(0.0, 2.5), rng.randf_range(-4.0, 4.0))
		var d := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.3, 0.3), rng.randf_range(-1.0, 1.0)).normalized()
		var near := rng.randf_range(0.0, 2.0)
		var max_t := rng.randf_range(0.0, 15.0)
		if Hitbox.may_touch(c, o, d, max_t, hits, near) and not Hitbox.may_touch(c, o, d, max_t, hits, near + 1.0):
			lost += 1
		# a longer segment never loses a touch either
		if Hitbox.may_touch(c, o, d, max_t, hits, near) and not Hitbox.may_touch(c, o, d, max_t + 3.0, hits, near):
			lost += 1
	assert_eq(lost, 0)


func test_an_infinite_segment_still_answers_by_the_capsule() -> void:
	var c := Character.new(1, 0, Vector3(0.0, 0.0, -5.0), 0.0, ReplicaStats.default_loadout())
	assert_true(Hitbox.may_touch(c, Vector3(0.0, 1.0, 0.0), Vector3(0.0, 0.0, -1.0), INF, hits))
	assert_false(Hitbox.may_touch(c, Vector3(0.0, 1.0, 0.0), Vector3(0.0, 0.0, 1.0), INF, hits))


func test_a_shot_during_a_skipped_unseen_frame_is_not_lost() -> void:
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.position = Vector3(0.0, 1.6, 3.0)
	camera.rotation.y = PI
	camera.current = true
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	c.grounded = true
	var v := FigureView.new()
	add_child_autofree(v)
	v.setup(c, Color.RED, hits, null)
	v.set_body(models, FigureMix.HUMAN, config.lod_high)
	v.update(c, 1.0)
	var eye := camera.position
	for i in config.hold_view_stride + 4:
		v.animate(c, 1.0, 0.016, eye)
	assert_false(v.body().seen)
	# land on a skipped frame: the press must still be there for the pose that follows
	var skipped := false
	for i in 4:
		v.on_shot()
		v.animate(c, 1.0, 0.016, eye)
		if v._fired:
			skipped = true
			break
	assert_true(skipped, "a skipped frame keeps the press")
	v.animate(c, 1.0, 0.016, eye)
	assert_false(v._fired, "and the next pose uses it")
