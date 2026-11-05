extends GutTest
## GA1: the walk cycle's length by speed (Hitbox.cycle_length, HitConfig tables) against the gait clips' own speed and
## seconds in the figures' sidecars, and the steady upper body's turn (HitFit.steady_turn, HitPose, upper_steady).

const KINDS: Array[String] = ["human", "robot"]
## Sidecar clip -> crouched.
const GAITS: Dictionary[String, bool] = {"Walk_F": false, "Run_F": false, "Sprint": false, "CrouchWalk": true,
		"Run_B": false, "Run_L": false, "Run_R": false}
## The way each clip steps (x right, y ahead) where it isn't ahead.
const WAYS: Dictionary[String, Vector2] = {"Run_B": Vector2(0.0, -1.0), "Run_L": Vector2(-1.0, 0.0),
		"Run_R": Vector2(1.0, 0.0)}

var hits: HitConfig = null


func before_each() -> void:
	hits = HitConfig.new()


func _clip(kind: String, name: String) -> Dictionary:
	var text := FileAccess.get_file_as_string("res://assets/models/characters/%s.json" % kind)
	var data: Variant = JSON.parse_string(text)
	assert_true(data is Dictionary, "%s sidecar parses" % kind)
	for clip: Dictionary in (data as Dictionary).get("clips", []):
		if clip.get("name", "") == name:
			return clip
	return {}


func test_cycle_length_is_in_line_between_speeds_and_held_past_the_ends() -> void:
	var s := hits.cycle_speeds
	var m := hits.cycle_metres
	assert_almost_eq(Hitbox.cycle_length(s[1], 0.0, hits), m[1], 1e-5)
	var mid := (s[1] + s[2]) * 0.5
	assert_almost_eq(Hitbox.cycle_length(mid, 0.0, hits), (m[1] + m[2]) * 0.5, 1e-5)
	assert_almost_eq(Hitbox.cycle_length(s[3] + 10.0, 0.0, hits), m[3], 1e-5, "held past the fastest")
	assert_almost_eq(Hitbox.cycle_length(-1.0, 0.0, hits), m[0], 1e-5, "held below the slowest")


func test_cycle_length_blends_to_the_crouched_table() -> void:
	var speed := hits.crouch_cycle_speeds[1]
	var standing := Hitbox.cycle_length(speed, 0.0, hits)
	var crouched := Hitbox.cycle_length(speed, 1.0, hits)
	assert_almost_eq(crouched, hits.crouch_cycle_metres[1], 1e-5)
	assert_ne(standing, crouched)
	assert_almost_eq(Hitbox.cycle_length(speed, 0.5, hits), (standing + crouched) * 0.5, 1e-5)
	assert_almost_eq(Hitbox.cycle_length(speed, 7.0, hits), crouched, 1e-5, "crouch clamped to 1")


func test_cycle_length_never_below_the_minimum_even_with_bad_tables() -> void:
	hits.cycle_metres = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	hits.crouch_cycle_metres = PackedFloat32Array([-1.0, 0.0])
	assert_eq(Hitbox.cycle_length(3.0, 0.0, hits), Hitbox.MIN_CYCLE)
	assert_eq(Hitbox.cycle_length(3.0, 1.0, hits), Hitbox.MIN_CYCLE)


func test_cycle_length_with_empty_or_repeated_tables_is_finite() -> void:
	hits.cycle_speeds = PackedFloat32Array()
	hits.cycle_metres = PackedFloat32Array()
	hits.crouch_cycle_speeds = PackedFloat32Array()
	hits.crouch_cycle_metres = PackedFloat32Array()
	assert_eq(Hitbox.cycle_length(4.0, 0.3, hits), Hitbox.MIN_CYCLE)
	hits.cycle_speeds = PackedFloat32Array([2.0, 2.0])
	hits.cycle_metres = PackedFloat32Array([1.0, 2.0])
	var l := Hitbox.cycle_length(2.0, 0.0, hits)
	assert_false(is_nan(l) or is_inf(l))


func test_step_walk_cycle_advances_a_whole_cycle_over_the_cycle_length() -> void:
	var c := Character.new(0, 0, Vector3.ZERO, 0.0)
	c.velocity = Vector3(0.0, 0.0, -hits.cycle_speeds[1])
	c.position.z = -0.1
	var steps := int(ceil(hits.cycle_metres[1] / 0.1))
	var total := 0.0
	for i in steps:
		c.prev_position = c.position
		c.position.z -= 0.1
		Hitbox.step_walk_cycle(c, hits)
	total = c.walk_cycle
	assert_almost_eq(total / TAU, 0.1 * steps / hits.cycle_metres[1], 0.02)
	var before := c.walk_cycle
	c.prev_position = c.position
	Hitbox.step_walk_cycle(c, hits)
	assert_eq(c.walk_cycle, before, "standing still adds nothing")


func test_each_gait_clip_covers_the_cycle_length_at_its_speed() -> void:
	for kind in KINDS:
		for name in GAITS:
			var clip := _clip(kind, name)
			assert_false(clip.is_empty(), "%s has %s" % [kind, name])
			if clip.is_empty():
				continue
			var speed := float(clip["speed"])
			var metres := speed * float(clip["seconds"])
			var crouch := 1.0 if GAITS[name] else 0.0
			var want := Hitbox.cycle_length(speed, crouch, hits, WAYS.get(name, Vector2(0.0, 1.0)))
			assert_almost_eq(metres, want, want * 0.01, "%s %s: speed x seconds vs the HitConfig table" % [kind, name])


func test_steady_turn_wraps_to_the_short_way_round() -> void:
	assert_almost_eq(HitFit.steady_turn(0.3, Vector3.RIGHT), 0.3, 1e-5)
	var x := Vector3.RIGHT.rotated(Vector3.UP, 3.0)
	assert_almost_eq(HitFit.heading(x), 3.0, 1e-5)
	var turn := HitFit.steady_turn(-3.0, x)
	assert_almost_eq(turn, TAU - 6.0, 1e-5, "3 rad to -3 rad is the short way across the wrap, not 6 rad")
	assert_almost_eq(HitFit.steady_turn(3.0, Vector3.RIGHT.rotated(Vector3.UP, -3.0)), 6.0 - TAU, 1e-5)
	assert_almost_eq(HitFit.steady_turn(1.0, Vector3.RIGHT.rotated(Vector3.UP, 1.0)), 0.0, 1e-5)


func _strafer() -> Character:
	var c := Character.new(0, 0, Vector3.ZERO, 0.0)
	c.velocity = Vector3(hits.cycle_speeds[2], 0.0, 0.0)
	c.walk_cycle = 1.3
	c.prev_walk_cycle = 1.3
	return c


func test_upper_steady_changes_the_upper_body_only_while_it_is_on() -> void:
	var c := _strafer()
	hits.upper_steady = 0.0
	HitPose.pose(c, hits, hits.fit)
	var off := HitPose.upper.duplicate()
	hits.upper_steady = 1.0
	HitPose.pose(c, hits, hits.fit)
	var on := HitPose.upper.duplicate()
	var apart := 0.0
	for k in off.size():
		apart = maxf(apart, off[k].distance_to(on[k]))
	assert_gt(apart, 1e-3, "turning the upper body back to the still heading moves its joints in a strafe")
	hits.upper_steady = 0.0
	HitPose.pose(c, hits, hits.fit)
	for k in off.size():
		assert_almost_eq(HitPose.upper[k], off[k], Vector3.ONE * 1e-6, "0 is the old behaviour, repeatably")


func test_a_vaulting_or_out_character_keeps_the_hips_upper_body() -> void:
	var c := _strafer()
	c.status = Character.Status.OUT
	hits.upper_steady = 0.0
	HitPose.pose(c, hits, hits.fit)
	var off := HitPose.upper.duplicate()
	hits.upper_steady = 1.0
	HitPose.pose(c, hits, hits.fit)
	for k in off.size():
		assert_almost_eq(HitPose.upper[k], off[k], Vector3.ONE * 1e-6)


func test_stepping_back_or_aside_takes_the_shorter_cycle() -> void:
	var ahead := Hitbox.cycle_length(4.2, 0.0, hits, Vector2(0.0, 1.0))
	assert_almost_eq(Hitbox.cycle_length(4.2, 0.0, hits, Vector2(0.0, -4.2)), ahead * hits.back_cycle_share, 1e-5)
	assert_almost_eq(Hitbox.cycle_length(4.2, 0.0, hits, Vector2(-3.0, 0.0)), ahead * hits.side_cycle_share, 1e-5)
	var diagonal := Hitbox.cycle_length(4.2, 0.0, hits, Vector2(1.0, 1.0))
	assert_almost_eq(diagonal, ahead * (1.0 + hits.side_cycle_share) * 0.5, 1e-5, "half ahead, half aside")
	assert_almost_eq(Hitbox.cycle_length(4.2, 0.0, hits, Vector2.ZERO), ahead, 1e-5, "no step: the cycle ahead")
	assert_almost_eq(Hitbox.cycle_length(2.1, 1.0, hits, Vector2(0.0, -2.1)), Hitbox.cycle_length(2.1, 1.0, hits),
			1e-5, "crouched, the way doesn't change it")

