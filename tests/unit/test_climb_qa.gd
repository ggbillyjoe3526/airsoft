extends GutTest
## QA hunt for CL1 (climbing and stairs): where a climb must not start, what a respawn leaves of it, and when the legs'
## stairs share is on (Hitbox.step_stairs, Hitbox.stairs_blend).

const DT := 1.0 / 60.0

var tuning: SimTuning = SimTuning.new()
var hits: HitConfig = tuning.hits
var feet: Vector3 = Vector3(0.0, tuning.body.rest_gap, 0.0)


func _world(boxes: Array) -> BoxWorld:
	var w := BoxWorld.new(tuning.body)
	w.add_box(Vector3(0.0, -0.25, 0.0), Vector3(40.0, 0.5, 40.0))
	for b: Array in boxes:
		w.add_box(b[0], b[1])
	return w


func _plan(boxes: Array) -> bool:
	return Vault.plan(feet, Vector2(0.0, -1.0), 0.0, tuning.vault, tuning.body, _world(boxes), VaultState.new())


## A 0.9 m platform, edge 0.7 m ahead, 6 m deep.
func _platform() -> Array:
	return [Vector3(0.0, 0.45, -3.7), Vector3(6.0, 0.9, 6.0)]


func _runner(slope: float, step: Vector2 = Vector2(0.0, -0.05)) -> Character:
	var c := Character.new(4, 0, feet, 0.0)
	c.grounded = true
	c.prev_position = feet
	c.position = feet + Vector3(step.x, slope * step.length(), step.y)
	return c


func test_no_climb_onto_a_platform_with_no_headroom_on_top() -> void:
	assert_true(_plan([_platform()]), "control: the open platform is climbed")
	# A ceiling 0.6 m over the top: the body would be inside it standing up there.
	var low := [Vector3(0.0, 1.5 + 0.5, -3.7), Vector3(6.0, 1.0, 6.0)]
	assert_false(_plan([_platform(), low]), "a low ceiling over the top")


func test_respawn_mid_climb_ends_it_and_clears_the_stairs_share() -> void:
	var c := Character.new(4, 0, feet, 0.0)
	c.vault.active = true
	c.vault.climb = true
	c.stairs = 0.8
	c.prev_stairs = 0.7
	c.respawn()
	assert_false(c.vault.active)
	assert_eq(c.stairs, 0.0)
	assert_eq(c.prev_stairs, 0.0)


func test_stairs_share_rises_on_a_steep_climb_and_is_negative_going_down() -> void:
	var up := _runner(0.5)
	for i in 30:
		up.prev_position = up.position - Vector3(0.0, 0.5 * 0.05, -0.05)
		Hitbox.step_stairs(up, hits, DT)
	assert_almost_eq(up.stairs, 1.0, 1e-3)
	var down := _runner(-0.5)
	for i in 30:
		down.prev_position = down.position - Vector3(0.0, -0.5 * 0.05, -0.05)
		Hitbox.step_stairs(down, hits, DT)
	assert_almost_eq(down.stairs, -1.0, 1e-3)


func test_a_gentle_slope_or_a_jump_or_a_vault_is_not_stairs() -> void:
	var hill := _runner(0.1)
	for i in 30:
		Hitbox.step_stairs(hill, hits, DT)
	assert_eq(hill.stairs, 0.0, "a 10 percent hill")
	var air := _runner(0.5)
	air.grounded = false
	Hitbox.step_stairs(air, hits, DT)
	assert_eq(air.stairs, 0.0, "airborne")
	var vaulting := _runner(0.5)
	vaulting.vault.active = true
	Hitbox.step_stairs(vaulting, hits, DT)
	assert_eq(vaulting.stairs, 0.0, "vaulting or climbing")


func test_a_teleport_is_not_stairs() -> void:
	var c := _runner(0.5, Vector2(0.0, -5.0))
	Hitbox.step_stairs(c, hits, DT)
	assert_eq(c.stairs, 0.0, "a respawn jump covers more than a stride")


func test_stairs_show_in_the_legs_only_when_stepping_ahead() -> void:
	var c := Character.new(4, 0, feet, 0.0)
	c.velocity = Vector3(0.0, 0.0, -3.0) # yaw 0 faces -Z
	assert_almost_eq(Hitbox.stairs_blend(c, 1.0), 1.0, 1e-4, "ahead")
	c.velocity = Vector3(0.0, 0.0, 3.0)
	assert_eq(Hitbox.stairs_blend(c, 1.0), 0.0, "backing up the stairs")
	c.velocity = Vector3(3.0, 0.0, 0.0)
	assert_almost_eq(Hitbox.stairs_blend(c, 1.0), 0.0, 1e-4, "strafing across them")
	c.velocity = Vector3.ZERO
	assert_eq(Hitbox.stairs_blend(c, 1.0), 0.0, "standing still on them")
	c.velocity = Vector3(0.0, 0.0, -3.0)
	assert_almost_eq(Hitbox.stairs_blend(c, -1.0), -1.0, 1e-4, "ahead going down")
