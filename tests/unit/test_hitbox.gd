extends GutTest
## A character's hit volume and the ray tests against it (game/sim/hitbox.gd; the browser game's sim/hitbox.test.ts,
## the built-in figure's cases; lean in test_lean.gd, the rigged figures with their task). A miss is INF here (-1 in the
## browser game). Godot's Vector3 is 32-bit, so distances compare to 1e-5 m, not the browser's 1e-9.

const CLOSE := 1e-5

## The built-in volume (HitConfig.fit null): the practice range's plywood figures, and a character's when there is no
## fit. test_hit_fit, test_hit_registration and test_figure_hit_area hold the fitted one (HV1).
var hits: HitConfig = _built_in()
var volume: Hitbox.Volume = Hitbox.Volume.new()


## The browser tests' body-sized vertical capsule.
func body_capsule() -> Hitbox.Capsule:
	return capsule(Vector3(0.0, 0.26, 0.0), Vector3(0.0, 1.54, 0.0), 0.26)


func capsule(a: Vector3, b: Vector3, r: float) -> Hitbox.Capsule:
	var c := Hitbox.Capsule.new()
	c.a = a
	c.b = b
	c.r = r
	return c


func character(at: Vector3 = Vector3.ZERO, yaw: float = 0.0) -> Character:
	return Character.new(0, 0, at, yaw)


## A BB along -Z at (x, y) from z = 10: it meets a character facing -Z (yaw 0), whose right is +X.
func shoot(c: Character, x: float, y: float) -> float:
	Hitbox.build_volume(c, hits, volume)
	return Hitbox.ray_character(Vector3(x, y, 10.0), Vector3.FORWARD, 20.0, volume)


## A BB along -X at height y, `z` in front of (negative) or behind the character's axis.
func from_side(c: Character, z: float, y: float) -> float:
	Hitbox.build_volume(c, hits, volume)
	return Hitbox.ray_character(Vector3(10.0, y, z), Vector3.LEFT, 20.0, volume)


func test_vertical_capsule_side_length_and_edges() -> void:
	var cap := body_capsule()
	assert_almost_eq(Hitbox.ray_vertical_capsule(Vector3(0, 1, 10), Vector3.FORWARD, 20.0, cap), 10.0 - 0.26, CLOSE)
	assert_eq(Hitbox.ray_vertical_capsule(Vector3(0, 1, 10), Vector3.FORWARD, 9.0, cap), INF, "past the segment")
	assert_eq(Hitbox.ray_vertical_capsule(Vector3(0.27, 1, 10), Vector3.FORWARD, 20.0, cap), INF, "just beside")
	assert_lt(Hitbox.ray_vertical_capsule(Vector3(0.25, 1, 10), Vector3.FORWARD, 20.0, cap), 20.0, "grazing")


func test_vertical_capsule_ends() -> void:
	var cap := body_capsule()
	var top := cap.b.y + cap.r
	assert_lt(Hitbox.ray_vertical_capsule(Vector3(0, top - 0.01, 10), Vector3.FORWARD, 20.0, cap), 20.0)
	assert_eq(Hitbox.ray_vertical_capsule(Vector3(0, top + 0.01, 10), Vector3.FORWARD, 20.0, cap), INF)
	assert_almost_eq(Hitbox.ray_vertical_capsule(Vector3(0, 5, 0), Vector3.DOWN, 10.0, cap), 5.0 - top, CLOSE,
			"dropping onto the head")
	assert_lt(Hitbox.ray_vertical_capsule(Vector3(0, 1.1, 1.1), Vector3(0, -1, -1).normalized(), 5.0, cap), 5.0,
			"the feet on a downward diagonal")


func test_vertical_capsule_inside_and_behind() -> void:
	var cap := body_capsule()
	assert_eq(Hitbox.ray_vertical_capsule(Vector3(0, 1, 0), Vector3.RIGHT, 1.0, cap), 0.0, "starts inside")
	assert_eq(Hitbox.ray_vertical_capsule(Vector3(0, 1, 5), Vector3.BACK, 20.0, cap), INF, "behind the ray")


func test_segment_capsule_agrees_with_the_vertical_one_from_all_around() -> void:
	var cap := body_capsule()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 500:
		var o := Vector3(rng.randf_range(-3, 3), rng.randf_range(-1, 3), rng.randf_range(-3, 3))
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		var max_t := rng.randf_range(0.5, 6.0)
		var expected := Hitbox.ray_vertical_capsule(o, d, max_t, cap)
		var got := Hitbox.ray_segment_capsule(o, d, max_t, cap)
		if is_inf(expected):
			assert_eq(got, INF, "ray %d" % i)
		else:
			assert_almost_eq(got, expected, CLOSE, "ray %d" % i)


func test_slanted_segment_capsule() -> void:
	# From (0, 0, 0) to (1, 1, 0), radius 0.1: a BB along -Z through its axis hits its front.
	var seg := capsule(Vector3.ZERO, Vector3(1, 1, 0), 0.1)
	for s: float in [0.0, 0.25, 0.5, 1.0]:
		assert_almost_eq(Hitbox.ray_segment_capsule(Vector3(s, s, 5), Vector3.FORWARD, 10.0, seg), 4.9, CLOSE, str(s))
	assert_lt(Hitbox.ray_segment_capsule(Vector3(0.5, 0.63, 5), Vector3.FORWARD, 10.0, seg), 10.0, "0.092 off the axis")
	assert_eq(Hitbox.ray_segment_capsule(Vector3(0.5, 0.65, 5), Vector3.FORWARD, 10.0, seg), INF, "0.106 off it")
	assert_eq(Hitbox.ray_segment_capsule(Vector3(1.08, 1.08, 5), Vector3.FORWARD, 10.0, seg), INF, "past the end")
	assert_eq(Hitbox.ray_segment_capsule(Vector3(0.5, 0.5, 5), Vector3.BACK, 10.0, seg), INF, "behind the ray")
	assert_eq(Hitbox.ray_segment_capsule(Vector3(0.5, 0.5, 0.05), Vector3.BACK, 10.0, seg), 0.0, "starts inside")


func test_segment_capsule_along_its_axis() -> void:
	var seg := capsule(Vector3.ZERO, Vector3(0, 0, -1), 0.1)
	assert_almost_eq(Hitbox.ray_segment_capsule(Vector3(0, 0, 3), Vector3.FORWARD, 10.0, seg), 2.9, CLOSE)
	assert_almost_eq(Hitbox.ray_segment_capsule(Vector3(0, 0, -3), Vector3.BACK, 10.0, seg), 1.9, CLOSE)


func test_sphere() -> void:
	assert_almost_eq(Hitbox.ray_sphere(Vector3(0, 0, 5), Vector3.FORWARD, Vector3.ZERO, 0.5), 4.5, CLOSE)
	assert_eq(Hitbox.ray_sphere(Vector3(0, 0.6, 5), Vector3.FORWARD, Vector3.ZERO, 0.5), INF)


func test_tops_out_at_the_head_standing_and_under_crouch_cover_crouched() -> void:
	assert_almost_eq(Hitbox.hit_top(0.0, hits), 1.75, 1e-9)
	assert_lte(Hitbox.hit_top(1.0, hits), 1.15)
	var c := character()
	assert_lt(shoot(c, 0.0, Hitbox.hit_top(0.0, hits) - 0.01), INF)
	assert_eq(shoot(c, 0.0, Hitbox.hit_top(0.0, hits) + 0.01), INF)
	c.crouch_amount = 1.0
	assert_eq(shoot(c, 0.0, 1.2), INF)
	assert_lt(shoot(c, 0.0, 1.0), INF)


func test_follows_the_figure() -> void:
	var c := character()
	assert_eq(shoot(c, 0.16, hits.head_height), INF, "beside the head")
	assert_lt(shoot(c, 0.1, hits.head_height), INF, "grazing the head")
	assert_eq(shoot(c, 0.22, 0.5), INF, "beside the legs")
	assert_lt(shoot(c, 0.15, 0.5), INF, "on a leg")
	assert_lt(shoot(c, 0.18, 1.2), INF, "on the torso edge")
	assert_almost_eq(shoot(c, 0.0, 1.3), 10.0 - hits.body_radius, CLOSE, "the chest's front")


func test_two_legs_not_one_round_volume() -> void:
	var c := character()
	assert_lt(from_side(c, 0.0, 0.5), INF)
	assert_eq(from_side(c, -0.12, 0.5), INF, "just in front of the shins")
	assert_lt(from_side(c, -0.15, 0.05), INF, "the boot's toe")


func test_legs_swing_on_the_walk_cycle_one_forward_one_back() -> void:
	var c := character()
	c.velocity.z = -2.0
	c.walk_cycle = PI / 2.0
	assert_almost_eq(Hitbox.leg_swing(c.walk_cycle, c, hits), hits.leg_swing, 1e-9)
	# At full stride the feet are ~0.4 m in front and behind: a BB along the ground there hits a boot.
	var reach := sin(hits.leg_swing) * hits.leg_ankle
	assert_lt(from_side(c, -reach, 0.12), INF)
	assert_lt(from_side(c, reach, 0.12), INF)
	c.velocity.z = 0.0
	assert_eq(from_side(c, -reach, 0.12), INF, "standing still, the legs hang straight")


func test_walk_cycle_moves_with_the_ground_covered_but_not_across_a_teleport() -> void:
	var c := character()
	c.position.z = -0.5
	c.velocity = Vector3(0.0, 0.0, -hits.cycle_speeds[2])
	Hitbox.step_walk_cycle(c, hits)
	assert_almost_eq(c.walk_cycle, 0.5 / hits.cycle_metres[2] * TAU, 1e-6)
	var before := c.walk_cycle
	c.prev_position.z = c.position.z
	c.position.x = 30.0
	Hitbox.step_walk_cycle(c, hits)
	assert_eq(c.walk_cycle, before, "a move to the dead zone")
	c.prev_position = c.position
	c.position.z -= hits.max_stride + 1.0
	Hitbox.step_walk_cycle(c, hits)
	assert_eq(c.walk_cycle, before, "a stride longer than max_stride")


func test_crouching_squashes_the_legs_towards_the_hips() -> void:
	var c := character()
	c.crouch_amount = 1.0
	Hitbox.build_volume(c, hits, volume)
	var hip_y := hits.pivot_height - hits.crouch_drop
	assert_almost_eq(volume.parts[Hitbox.THIGH_L].a.y, hip_y + hits.leg_hip_lift * (hip_y / hits.pivot_height), CLOSE)
	assert_gt(volume.parts[Hitbox.BOOT_L].a.y, 0.0)


func test_the_volume_turns_and_moves_with_the_character() -> void:
	# Facing -X (yaw π/2): the figure's right (+x) is world -z.
	var c := character(Vector3(3, 0.5, -2), PI / 2.0)
	Hitbox.build_volume(c, hits, volume)
	var hip := volume.parts[Hitbox.HIP_R]
	assert_almost_eq(hip.a.x, 3.0, CLOSE)
	assert_almost_eq(hip.a.z, -2.0 - hits.hips_half_width, CLOSE)
	assert_almost_eq(hip.a.y, 0.5 + hits.hips_bottom, CLOSE)
	var boot := volume.parts[Hitbox.BOOT_L]
	assert_lt(boot.b.x, boot.a.x, "the toe points the way it faces")
	assert_almost_eq(volume.head.a, Vector3(3, 0.5 + hits.head_height, -2), Vector3.ONE * CLOSE)
	# Shot from the side it now faces, along +X at chest height: the chest's front.
	assert_almost_eq(Hitbox.ray_character(Vector3(-7, 1.8, -2), Vector3.RIGHT, 20.0, volume), 10.0 - hits.body_radius, CLOSE)


func test_the_bound_holds_every_part() -> void:
	var c := character(Vector3(1, 0, 1), 0.7)
	c.velocity.x = 3.0
	c.walk_cycle = 1.0
	c.crouch_amount = 0.4
	Hitbox.build_volume(c, hits, volume)
	var b := volume.bound
	for k in Hitbox.PART_COUNT:
		var p := volume.parts[k]
		for end: Vector3 in [p.a, p.b]:
			assert_lte(Vector2(end.x - b.a.x, end.z - b.a.z).length() + p.r, b.r + CLOSE, "part %d" % k)
			assert_gte(end.y - p.r, b.a.y - CLOSE, "part %d" % k)
			assert_lte(end.y + p.r, b.b.y + CLOSE, "part %d" % k)


static func _built_in() -> HitConfig:
	var h := HitConfig.new()
	h.fit = null
	return h
