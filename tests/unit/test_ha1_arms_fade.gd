extends GutTest
## HA1 (the owner: "When aiming down sight no hands should be visible … on a pistol the hand should only be slightly
## visible"; then "the hands should not fade out of view. When the animation plays to ADS (except for pistols) the
## hands are simply out of view"): a rifle's arms are never faded or hidden, the replica hides them (ArmsTuck draws the
## left arm in under it: test_ha1_arms_tuck.gd); a pistol's keep the tops of the hands, what lies further under the
## sight line faded out (ArmsView.aim, ArmsFade, arms_fade.gdshader) through ViewModelConfig.aim_hint_span's span.

const DT := 1.0 / 60.0
const EPS := 1e-4
const RIFLES := [&"aeg", &"sniper", &"smg"]
const PISTOLS := [&"pistol", &"cyber"]

var cfg: ViewModelConfig = null


func before_each() -> void:
	cfg = ViewModelConfig.new()


func _hands(ids: Array) -> ReplicaView:
	var loadout: Array[ReplicaConfig] = []
	for id: StringName in ids:
		loadout.append(ReplicaStats.load_replica(id))
	var hands := ReplicaView.new()
	add_child_autofree(hands)
	hands.setup(cfg, loadout, BoxWorld.new())
	return hands


## Every material the arms' shown meshes are drawn with.
func _drawn(hands: ReplicaView) -> Array[Material]:
	var out: Array[Material] = []
	for mesh: MeshInstance3D in hands._arms._meshes:
		if not mesh.visible:
			continue
		for i in mesh.mesh.get_surface_count():
			out.append(mesh.get_surface_override_material(i))
	return out


func _all_fading(hands: ReplicaView) -> bool:
	var drawn := _drawn(hands)
	return not drawn.is_empty() and drawn.all(func(m: Material) -> bool: return m is ShaderMaterial)


func _none_fading(hands: ReplicaView) -> bool:
	var drawn := _drawn(hands)
	return not drawn.is_empty() and drawn.all(func(m: Material) -> bool: return m is BaseMaterial3D)


func test_at_the_hip_the_arms_wear_their_own_materials() -> void:
	var hands := _hands(RIFLES + PISTOLS)
	for slot in hands._held.size():
		hands._show(slot)
		hands._arms.aim(0.0)
		assert_true(_none_fading(hands), "%s: no fading copy at the hip" % hands._held[slot].id)
		assert_eq(hands._arms.hinted(), 0.0)
		# Nor until the hint's span starts.
		hands._arms.aim(cfg.aim_hint_span.x)
		assert_true(_none_fading(hands), "%s: nor before the span starts" % hands._held[slot].id)


func test_a_rifles_arms_never_fade_and_are_never_hidden() -> void:
	for id: StringName in RIFLES:
		var hands := _hands([id])
		hands._show(0)
		var model := hands._arms._model
		for raise: float in [0.0, 0.3, 0.55, 0.8, 1.0, 0.4, 0.0]:
			hands._arms.aim(raise)
			assert_true(model.visible, "%s raised %s: drawn" % [id, raise])
			assert_true(_none_fading(hands), "%s raised %s: in its own materials" % [id, raise])
			assert_eq(hands._arms.hinted(), 0.0)


func test_a_pistols_hands_keep_their_tops_under_the_sight_line() -> void:
	for id: StringName in PISTOLS:
		var hands := _hands([id])
		hands._show(0)
		var middle := (cfg.aim_hint_span.x + cfg.aim_hint_span.y) * 0.5
		hands._arms.aim(middle)
		assert_almost_eq(hands._arms.hinted(), 0.5, EPS, "%s: half way through the span" % id)
		hands._arms.aim(1.0)
		assert_true(hands._arms._model.visible, "%s: never hidden" % id)
		assert_true(_all_fading(hands), "%s: in its fading copies" % id)
		assert_almost_eq(hands._arms.hinted(), 1.0, EPS, "%s: all that lies below the line" % id)
		for m: Material in _drawn(hands):
			var fading := m as ShaderMaterial
			assert_almost_eq(float(fading.get_shader_parameter(ArmsFade.HINT)), 1.0, EPS)
			assert_almost_eq(float(fading.get_shader_parameter(ArmsFade.HINT_FROM)), cfg.aim_hint_below.x, EPS)
			assert_almost_eq(float(fading.get_shader_parameter(ArmsFade.HINT_TO)), cfg.aim_hint_below.y, EPS)
		# The sight comes down: their own materials again.
		hands._arms.aim(0.0)
		assert_true(_none_fading(hands), "%s: back at the hip" % id)


func test_a_fading_copy_draws_as_the_material_it_copies() -> void:
	var hands := _hands([&"pistol"])
	hands._show(0)
	var own := _drawn(hands)
	hands._arms.aim(0.5)
	var fading := _drawn(hands)
	assert_eq(fading.size(), own.size())
	for i in own.size():
		var base := own[i] as BaseMaterial3D
		var copy := fading[i] as ShaderMaterial
		assert_eq(copy.get_shader_parameter(&"albedo_map"), base.albedo_texture, "its colour map")
		assert_eq(copy.get_shader_parameter(&"roughness_map"), base.roughness_texture, "its roughness map")
		assert_eq(copy.get_shader_parameter(&"metallic_map"), base.metallic_texture, "its metal map (none of it)")
		assert_eq(copy.get_shader_parameter(&"normal_map"), base.normal_texture, "its normal map")
		assert_almost_eq(float(copy.get_shader_parameter(&"z_clip_scale")), base.z_clip_scale, EPS, "its depth press")
		assert_true(base.use_z_clip_scale)
	# One copy a material, made once: raising the sight again makes none.
	var first := hands._arms.materials().size()
	hands._arms.aim(0.0)
	hands._arms.aim(0.6)
	assert_eq(hands._arms.materials().size(), first, "no new material with each raise")
	for i in own.size():
		assert_eq(_drawn(hands)[i], fading[i], "the same copy")


func test_skin_only_and_a_robots_arms_fade_too() -> void:
	var hands := _hands([&"pistol"])
	hands._show(0)
	hands._arms.set_skin(true)
	hands._arms.aim((cfg.aim_hint_span.x + cfg.aim_hint_span.y) * 0.5)
	assert_true(_all_fading(hands), "skin only")
	var skin := _drawn(hands)
	hands._arms.set_skin(false)
	assert_true(_all_fading(hands), "gloves back on mid fade: still fading")
	assert_ne(_drawn(hands), skin, "in the gloves' copies")
	hands._arms.set_kind(FigureMix.ROBOT)
	assert_true(_all_fading(hands), "a robot's")
	for m: Material in _drawn(hands):
		assert_almost_eq(float((m as ShaderMaterial).get_shader_parameter(ArmsFade.HINT)), 0.5, EPS,
				"a look put on mid fade is as faded as the one before it")
		assert_null((m as ShaderMaterial).get_shader_parameter(&"albedo_map"), "plain colours, no painted map")


func test_in_play_the_raised_sight_leaves_a_rifles_arms_whole_and_a_pistols_tops() -> void:
	for id: StringName in [&"aeg", &"pistol"]:
		var c := Character.new(0, 0, Vector3.ZERO, 0.0, [ReplicaStats.load_replica(id)] as Array[ReplicaConfig])
		c.grounded = true
		var hands := _hands([id])
		for i in 90:
			hands.update(c, 0.0, 0.0, Vector3.ZERO, Vector3.FORWARD, DT, 1.0)
		assert_true(hands._arms._model.visible, "%s aimed: the arms are drawn" % id)
		if PISTOLS.has(id):
			assert_almost_eq(hands._arms.hinted(), 1.0, 1e-3, "%s aimed: the tops of the hands" % id)
		else:
			assert_true(_none_fading(hands), "%s aimed: nothing fades" % id)
		for i in 90:
			hands.update(c, 0.0, 0.0, Vector3.ZERO, Vector3.FORWARD, DT, 0.0)
		assert_true(hands._arms._model.visible, "%s: back at the hip" % id)
		assert_true(_none_fading(hands), "%s: in their own materials" % id)
