extends GutTest
## HA1 QA (attempt 2): the bare hand's own meshes (Skin_, Nails_) against the glove's (HandSurface_, GloveKit_): one look
## at a time on every hold, live switches, fades and the pistols at 25 cm from the eye.

const IDS: Array[StringName] = [&"aeg", &"sniper", &"smg", &"shotgun", &"pistol", &"cyber", &"smoke", &"flash"]
const BUDGET := 40000

var cfg: ViewModelConfig = null


func before_each() -> void:
	cfg = ViewModelConfig.new()


## Every (id, grip) the model has a hold for, grips from its `<id>_grip_<key>_Hold` clips.
func _holds() -> Array[Array]:
	var out: Array[Array] = []
	for id: StringName in IDS:
		out.append([id, &""])
	var scene := load(ArmsView.MODEL) as PackedScene
	var model := scene.instantiate()
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for clip: Variant in player.get_animation_list():
		var s := String(clip)
		var at := s.find("_grip_")
		if at > 0 and s.ends_with("_Hold"):
			out.append([StringName(s.substr(0, at)), StringName(s.substr(at + 6, s.length() - at - 11))])
	model.free()
	return out


func _arms() -> ArmsView:
	var root := Node3D.new()
	add_child_autofree(root)
	var arms := ArmsView.new()
	root.add_child(arms)
	arms.setup(cfg)
	return arms


func _vis(arms: ArmsView) -> Dictionary:
	var out := {}
	for m: MeshInstance3D in arms._meshes:
		out[String(m.name)] = m.visible
	return out


func _tris(arms: ArmsView) -> int:
	var n := 0
	for m: MeshInstance3D in arms._meshes:
		if not m.visible:
			continue
		for i in m.mesh.get_surface_count():
			n += (m.mesh.surface_get_arrays(i)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return n


func _check(arms: ArmsView, skin: bool, left: bool, tag: String) -> void:
	var v := _vis(arms)
	for side: Variant in ["R", "L"]:
		var on: bool = left or side == "R"
		assert_eq(v["Arm_" + side], on, "%s Arm_%s" % [tag, side])
		assert_eq(v["Skin_" + side], on and skin, "%s Skin_%s" % [tag, side])
		assert_eq(v["Nails_" + side], on and skin, "%s Nails_%s" % [tag, side])
		assert_eq(v["HandSurface_" + side], on and not skin, "%s HandSurface_%s" % [tag, side])
		assert_eq(v["GloveKit_" + side], on and not skin, "%s GloveKit_%s" % [tag, side])


func test_every_hold_shows_exactly_one_hand_look_and_stays_in_the_triangle_budget() -> void:
	var arms := _arms()
	for h: Variant in _holds():
		var root := arms.get_parent() as Node3D
		for skin: Variant in [false, true]:
			arms.set_skin(skin)
			arms.hold(h[0], root, h[1])
			var tag := "%s/%s skin %s" % [h[0], h[1], skin]
			assert_true(arms._model.visible or arms.holding() == &"", tag)
			if arms.holding() == &"":
				continue
			_check(arms, skin, not cfg.one_hand.has(h[0]), tag)
			assert_lte(_tris(arms), BUDGET, "%s: triangles drawn" % tag)
			assert_gt(_tris(arms), 0, tag)


func test_switching_the_look_mid_hold_and_mid_hold_changes_keeps_one_look() -> void:
	var arms := _arms()
	var root := arms.get_parent() as Node3D
	arms.hold(&"aeg", root)
	for i in 6:
		arms.set_skin(i % 2 == 0)
		arms.hold(IDS[i], root)
		arms.set_skin(i % 2 == 1)
		_check(arms, i % 2 == 1, not cfg.one_hand.has(IDS[i]), "step %d" % i)


func test_robot_arms_keep_the_glove_shell_and_never_the_bare_hand() -> void:
	var arms := _arms()
	arms.set_kind(FigureMix.ROBOT)
	arms.set_skin(true)
	for id: StringName in IDS:
		arms.hold(id, arms.get_parent() as Node3D)
		_check(arms, false, not cfg.one_hand.has(id), "robot %s" % id)
	arms.set_kind(FigureMix.HUMAN)
	_check(arms, true, not cfg.one_hand.has(IDS[-1]), "back to a human, skin only")


func test_the_aimed_pistols_fade_reaches_the_bare_hand_and_its_nails() -> void:
	for id: Variant in [&"pistol", &"cyber"]:
		var arms := _arms()
		arms.hold(id, arms.get_parent() as Node3D)
		arms.set_skin(true)
		arms.aim(0.5 * (cfg.aim_hint_span.x + cfg.aim_hint_span.y))
		var seen := 0
		for m: MeshInstance3D in arms._meshes:
			if not (String(m.name).begins_with("Skin_") or String(m.name).begins_with("Nails_")):
				continue
			assert_true(m.visible, String(m.name))
			for i in m.mesh.get_surface_count():
				var mat := m.get_surface_override_material(i) as ShaderMaterial
				assert_not_null(mat, "%s %s fades" % [id, m.name])
				if mat != null:
					assert_almost_eq(float(mat.get_shader_parameter(ArmsFade.HINT)), 0.5, 1e-4)
					seen += 1
		assert_gt(seen, 0)
		arms.aim(0.0)
		for m: MeshInstance3D in arms._meshes:
			for i in m.mesh.get_surface_count():
				assert_true(m.get_surface_override_material(i) is BaseMaterial3D, "whole again: %s" % m.name)


func test_a_rifles_tuck_leaves_the_bare_hand_drawn_and_unfaded() -> void:
	var arms := _arms()
	arms.hold(&"aeg", arms.get_parent() as Node3D)
	arms.set_skin(true)
	arms.aim(1.0)
	assert_eq(arms.hinted(), 0.0)
	_check(arms, true, true, "rifle aimed")
	for m: MeshInstance3D in arms._meshes:
		for i in m.mesh.get_surface_count():
			assert_true(m.get_surface_override_material(i) is BaseMaterial3D, String(m.name))


func test_the_bomb_in_hand_arms_follow_the_dev_setting_live() -> void:
	var v := GrenadeView.new()
	add_child_autofree(v)
	v.setup(1, GrenadeConfig.new(), false)
	v.setup_arms(cfg, FigureMix.HUMAN)
	var arms: ArmsView = v._arms
	arms.hold(&"smoke", arms.get_parent() as Node3D)
	for skin: Variant in [true, false, true]:
		v.set_arms_skin(skin)
		_check(arms, skin, not cfg.one_hand.has(&"smoke"), "grenade skin %s" % skin)


func test_the_pistols_hip_is_the_old_place_drawn_in_along_the_same_line() -> void:
	var old := Vector3(0.05, -0.07, -0.34)
	var old_move := Vector3(0.1, 0.06, 0.0)
	for id: Variant in [&"pistol", &"cyber"]:
		var hip: Vector3 = cfg.hip[id]
		assert_almost_eq(-hip.z, 0.25, 1e-4, "25 cm")
		var k := hip.z / old.z
		assert_lt((hip - old * k).length(), 2e-3, "%s: on the old line from the eye" % id)
		assert_lt((cfg.reload_move(id) - old_move * k).length(), 2e-3, "%s: the reload scaled with it" % id)
		# The reload peak stays in front of the eye and inside a 75 degree half-field.
		var peak := hip + cfg.reload_move(id)
		assert_lt(peak.z, -0.1)
		assert_lt(maxf(absf(peak.x), absf(peak.y)) / -peak.z, tan(deg_to_rad(37.5)) * 1.0)

