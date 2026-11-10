extends GutTest
## SG1 QA: the hip glass looks down the scope's own axis; its edges (straight up or down, a scaled model, switching
## between aimed and the hip, the eye's own near and far, a red dot, Low).

const AEG := "000002"
const SCOPE := "000010"
const RED_DOT := "000007"
const HIP_AT := Vector3(0.13, -0.16, -0.32)


func _hands(optic: String = SCOPE) -> ReplicaView:
	var rules := LoadoutRules.new(Pool.read_file(), ReplicaStats.read_file(), ReplicaRulesConfig.new())
	var l := rules.default_loadout("Test")
	if l.equipped[0] != AEG:
		rules.equip(l, 0 as Loadout.Slot, AEG)
	assert_true(rules.set_part(l, AEG, &"optic", optic))
	var kit := rules.carried(l)
	var eyes := Camera3D.new()
	add_child_autofree(eyes)
	eyes.rotation = Vector3(0.1, 0.7, 0.0)
	var hands := ReplicaView.new()
	eyes.add_child(hands)
	hands.setup(ViewModelConfig.new(), kit.replicas, null, kit.paints, false, kit.parts, ViewConfig.new(), eyes)
	hands._show(0)
	(hands._held[0] as ReplicaView.Held).root.position = HIP_AT
	return hands


func _sound(cam: Camera3D) -> bool:
	var b := cam.global_transform
	return b.origin.is_finite() and b.basis.x.is_finite() and b.basis.y.is_finite() and b.basis.z.is_finite() \
			and is_finite(cam.fov) and cam.fov > 0.0 and cam.fov < 179.0 \
			and absf(b.basis.z.length() - 1.0) < 1e-3 and absf(b.basis.x.dot(b.basis.z)) < 1e-3


func test_a_scope_pointing_straight_up_or_down_keeps_the_glass_camera_sound_and_on_the_axis() -> void:
	var hands := _hands()
	var held: ReplicaView.Held = hands._held[0]
	var glass := hands._glass
	for pitch: float in [PI * 0.5, -PI * 0.5, PI * 0.5 - 0.02, -PI * 0.5 + 0.02, PI * 0.5 - 0.06]:
		held.root.rotation = Vector3(pitch, 0.0, 0.0)
		glass.update(held.window, 0.0)
		if not held.window.disc.visible:
			continue
		var cam := glass._camera
		assert_true(_sound(cam), "pitch %s: finite, orthonormal" % pitch)
		var ahead := -held.window.model.global_basis.z.normalized()
		assert_almost_eq(-cam.global_basis.z.dot(ahead), 1.0, 1e-4, "pitch %s: down the axis" % pitch)
	glass.update(null, 0.0)


func test_a_scaled_model_still_gives_a_unit_camera_down_the_axis() -> void:
	var hands := _hands()
	var held: ReplicaView.Held = hands._held[0]
	var glass := hands._glass
	for s: float in [0.25, 3.0]:
		held.window.model.scale = Vector3.ONE * s
		glass.update(held.window, 0.0)
		assert_true(_sound(glass._camera), "scale %s" % s)
		var ahead := -held.window.model.global_basis.z.normalized()
		assert_almost_eq(-glass._camera.global_basis.z.dot(ahead), 1.0, 1e-4, "scale %s: down the axis" % s)
	held.window.model.scale = Vector3.ONE
	glass.update(null, 0.0)


func test_the_hip_glass_never_starts_further_from_the_eye_than_the_reach_wherever_the_replica_is() -> void:
	var hands := _hands()
	var held: ReplicaView.Held = hands._held[0]
	var glass := hands._glass
	var reach := ViewModelConfig.new().hip_glass_eye_reach
	for at: Vector3 in [Vector3(1.0, 0.5, -0.4), Vector3(-0.6, -0.5, -0.1), Vector3(0.0, 0.0, -1.5), HIP_AT]:
		for turn: Vector3 in [Vector3.ZERO, Vector3(0.4, 1.0, 0.3), Vector3(-1.2, 0.0, 0.0)]:
			held.root.position = at
			held.root.rotation = turn
			glass.update(held.window, 0.0)
			if held.window.disc.visible:
				assert_lte(glass._camera.global_position.distance_to(glass._eyes.global_position), reach + 1e-4,
						"%s %s" % [at, turn])
	glass.update(null, 0.0)


func test_aimed_hip_aimed_restores_the_aimed_picture_exactly() -> void:
	var hands := _hands()
	var held: ReplicaView.Held = hands._held[0]
	var glass := hands._glass
	var aimed_at := Vector3(0.0, 0.0, ViewModelConfig.new().aim_forward[&"aeg"]) - held.rear_sight
	held.root.position = aimed_at
	glass.update(held.window, 1.0)
	var fov := glass._camera.fov
	var xf := glass._camera.global_transform
	var near := glass._camera.near
	held.root.position = HIP_AT
	glass.update(held.window, 0.0)
	assert_ne(glass._camera.global_transform, xf, "the hip moved the camera")
	held.root.position = aimed_at
	glass.update(held.window, 1.0)
	assert_eq(glass._camera.projection, Camera3D.PROJECTION_PERSPECTIVE)
	assert_almost_eq(glass._camera.fov, fov, 1e-4, "aimed fov back")
	assert_almost_eq(glass._camera.near, near, 1e-6)
	assert_true(glass._camera.global_transform.is_equal_approx(xf), "aimed camera back where it was")
	assert_eq(glass._camera.environment, glass._env_aimed, "and its environment")
	glass.update(null, 0.0)


func test_the_glass_camera_follows_the_eyes_near_and_far_at_the_hip_and_aimed() -> void:
	var hands := _hands()
	var held: ReplicaView.Held = hands._held[0]
	var glass := hands._glass
	var aimed_at := Vector3(0.0, 0.0, ViewModelConfig.new().aim_forward[&"aeg"]) - held.rear_sight
	for raise: float in [0.0, 1.0]:
		held.root.position = HIP_AT if raise == 0.0 else aimed_at
		glass._eyes.near = 0.07
		glass._eyes.far = 321.0
		glass.update(held.window, raise)
		assert_almost_eq(glass._camera.near, 0.07, 1e-6, "raise %s near" % raise)
		assert_almost_eq(glass._camera.far, 321.0, 1e-3, "raise %s far" % raise)
		glass._eyes.near = 0.05
		glass._eyes.far = 500.0
		glass.update(held.window, raise)
		assert_almost_eq(glass._camera.near, 0.05, 1e-6, "raise %s near again" % raise)
		assert_almost_eq(glass._camera.far, 500.0, 1e-3, "raise %s far again" % raise)
	glass.update(null, 0.0)


func test_the_glass_camera_is_not_physics_interpolated() -> void:
	var hands := _hands()
	assert_eq(hands._glass._camera.physics_interpolation_mode, Node.PHYSICS_INTERPOLATION_MODE_OFF)


func test_a_red_dot_has_no_hip_glass_and_draws_no_camera_at_the_hip() -> void:
	var hands := _hands(RED_DOT)
	var held: ReplicaView.Held = hands._held[0]
	var glass := hands._glass
	assert_false(OpticGlass.hip_glass(held.window, 0.0))
	glass.update(held.window, 0.0)
	assert_ne(glass._port.render_target_update_mode, SubViewport.UPDATE_ALWAYS, "no second camera at the hip")
	glass.update(null, 0.0)


func test_on_low_the_hip_glass_is_still_and_the_camera_is_left_alone() -> void:
	var hands := _hands()
	var held: ReplicaView.Held = hands._held[0]
	var glass := hands._glass
	glass._follow(GraphicsTable.shared().preset(&"low"))
	var xf := glass._camera.transform
	glass.update(held.window, 0.0)
	assert_true(held.window.disc.visible)
	assert_eq(held.window.hip_material.get_shader_parameter(&"see_through"), false)
	assert_ne(glass._port.render_target_update_mode, SubViewport.UPDATE_ALWAYS)
	assert_eq(glass._camera.transform, xf, "not placed on Low")
	glass.update(null, 0.0)


func test_many_hip_updates_in_many_poses_stay_finite() -> void:
	var hands := _hands()
	var held: ReplicaView.Held = hands._held[0]
	var glass := hands._glass
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 200:
		held.root.position = HIP_AT + Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.4, 0.4), rng.randf_range(-0.3, 0.3))
		held.root.rotation = Vector3(rng.randf_range(-PI, PI), rng.randf_range(-PI, PI), rng.randf_range(-PI, PI))
		glass.update(held.window, 0.0)
		if held.window.disc.visible and glass._port.render_target_update_mode == SubViewport.UPDATE_ALWAYS:
			assert_true(_sound(glass._camera), "pose %d" % i)
			assert_true(is_finite(float(held.window.hip_material.get_shader_parameter(&"span"))))
	glass.update(null, 0.0)
