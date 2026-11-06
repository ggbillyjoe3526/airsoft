extends GutTest
## BP5, the second bug and performance pass: Hitbox.may_touch's bounding test first (it answers as the capsule test
## alone does).

var hits: HitConfig = HitConfig.new()


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

