extends GutTest
## BP5, the second bug and performance pass: Hitbox.may_touch's bounding test first (it answers as the capsule test
## alone does) and a figure out of the camera's view posed every unseen_stride-th frame, posed again at once in view.

var config: FigureConfig = null
var models: FigureModels = null
var hits: HitConfig = HitConfig.new()
var moves: MovementConfig = MovementConfig.new()


func before_all() -> void:
	config = FigureConfig.new()
	models = FigureModels.new(config)
	models.load_kinds()


func test_the_bounding_test_answers_as_the_capsule_test_alone() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	var cap := Hitbox.Capsule.new()
	var touched := 0
	for i in 4000:
		c.position = Vector3(rng.randf_range(-6.0, 6.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-6.0, 6.0))
		var o := Vector3(rng.randf_range(-4.0, 4.0), rng.randf_range(0.0, 2.5), rng.randf_range(-4.0, 4.0))
		var d := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.3, 0.3), rng.randf_range(-1.0, 1.0)).normalized()
		var max_t := rng.randf_range(0.0, 12.0)
		var margin := rng.randf_range(0.0, 1.5)
		cap.a = c.position
		cap.b = c.position + Vector3(0.0, hits.volume_top, 0.0)
		cap.r = hits.volume_reach + margin
		var want := not is_inf(Hitbox.ray_vertical_capsule(o, d, max_t, cap))
		if want:
			touched += 1
		if Hitbox.may_touch(c, o, d, max_t, hits, margin) != want:
			assert_eq(Hitbox.may_touch(c, o, d, max_t, hits, margin), want, "ray %d from %s along %s" % [i, o, d])
			return
	assert_gt(touched, 200, "both answers come up")
	assert_lt(touched, 3800)


func test_a_figure_out_of_view_is_posed_every_unseen_stride_frames_and_at_once_in_view() -> void:
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.position = Vector3(0.0, 1.6, 3.0)
	camera.rotation.y = PI
	camera.current = true
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	c.velocity = Vector3(0.0, 0.0, -moves.run_speed)
	c.grounded = true
	var v := FigureView.new()
	add_child_autofree(v)
	v.setup(c, Color.RED, hits, null)
	v.set_body(models, FigureMix.HUMAN, config.lod_high)
	v.update(c, 1.0)
	var eye := camera.position
	v.animate(c, 1.0, 0.016, eye)
	for i in config.hold_view_stride + 1:
		v.animate(c, 1.0, 0.016, eye)
	assert_false(v.body().seen, "behind the camera")
	var moved := 0
	var frames := config.unseen_stride * 4
	for i in frames:
		var before := _thigh(v)
		c.walk_cycle += 0.7
		c.prev_walk_cycle = c.walk_cycle
		v.animate(c, 1.0, 0.016, eye)
		if _thigh(v) != before:
			moved += 1
	assert_eq(moved, 4, "one frame in unseen_stride")
	camera.rotation.y = 0.0
	for i in config.hold_view_stride:
		v.animate(c, 1.0, 0.016, eye)
	assert_true(v.body().seen, "in view again")
	var before := _thigh(v)
	c.walk_cycle += 0.7
	c.prev_walk_cycle = c.walk_cycle
	v.animate(c, 1.0, 0.016, eye)
	assert_ne(_thigh(v), before, "posed every frame in view")


func _thigh(v: FigureView) -> Quaternion:
	var sk := v.body().skeleton
	return sk.get_bone_pose_rotation(sk.find_bone(config.swing_hip))
