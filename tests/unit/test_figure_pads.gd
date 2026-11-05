extends GutTest
## BL13: the human figure's knee and elbow pads (tools/blender/figures/pads.py), the `Kit_Pads` part of human.glb:
## listed in the sidecar's parts, within their budget at each level, skinned to the figure's own skeleton (each pad
## riding its shin or forearm, its straps and buckles the limb under them), in their own `Pads` material, and drawn by
## every human figure.

const PARTS: Array[String] = ["Kit_Pads", "Kit_Pads_LOD1", "Kit_Pads_LOD2"]
## Triangles at LOD0, LOD1, LOD2, all four pads (agreed with the body rebuild, BL10).
const BUDGET: Array[int] = [3000, 1000, 300]
## The pads ride these bones; the straps and buckles lying on the body also take its weights there: the thigh, the
## upper arm, the elbow's helper and the forearm's first twist bone.
const RIDDEN: Array[String] = ["Shin_L", "Shin_R", "Forearm_L", "Forearm_R"]
const BONES: Array[String] = ["Shin_L", "Shin_R", "Forearm_L", "Forearm_R", "Thigh_L", "Thigh_R", "UpperArm_L",
		"UpperArm_R", "ElbowHelper_L", "ElbowHelper_R", "ForearmTwist1_L", "ForearmTwist1_R"]
const MATERIAL := "Pads"

var config: FigureConfig = null
var models: FigureModels = null


func before_all() -> void:
	config = FigureConfig.new()
	models = FigureModels.new(config)
	models.load_kinds()


func _human() -> Node:
	var root := models.scene(0).instantiate()
	add_child_autofree(root)
	return root


static func _tris(mesh: Mesh) -> int:
	var n := 0
	for s in mesh.get_surface_count():
		n += (mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return n


func test_the_sidecar_lists_the_pads() -> void:
	var parts := models.sidecar(0).parts
	for part in PARTS:
		assert_true(parts.has(part), part)


func test_each_level_is_within_its_budget() -> void:
	var root := _human()
	for i in PARTS.size():
		var mi := root.find_child(PARTS[i], true, false) as MeshInstance3D
		assert_not_null(mi, PARTS[i])
		if mi == null:
			continue
		var tris := _tris(mi.mesh)
		assert_gt(tris, 0, PARTS[i])
		assert_lte(tris, BUDGET[i], PARTS[i])


func test_the_pads_ride_the_limbs_bones() -> void:
	var root := _human()
	var skeleton := root.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for part in PARTS:
		var mi := root.find_child(part, true, false) as MeshInstance3D
		assert_not_null(mi, part)
		if mi == null:
			continue
		assert_not_null(mi.skin, part)
		if mi.skin == null:
			continue
		for b in mi.skin.get_bind_count():
			var bone := mi.skin.get_bind_name(b)
			assert_gt(skeleton.find_bone(bone), -1, "%s binds %s" % [part, bone])
		var arrays := mi.mesh.surface_get_arrays(0)
		var bones := arrays[Mesh.ARRAY_BONES] as PackedInt32Array
		var weights := arrays[Mesh.ARRAY_WEIGHTS] as PackedFloat32Array
		var used := {}
		for k in bones.size():
			if weights[k] > 0.0:
				used[String(mi.skin.get_bind_name(bones[k]))] = true
		for bone: String in used:
			assert_true(BONES.has(bone), "%s weighted to %s" % [part, bone])
		for bone in RIDDEN:
			assert_true(used.has(bone), "%s rides %s" % [part, bone])


func test_the_pads_wear_their_own_textured_material() -> void:
	var root := _human()
	var body := root.find_child("Body", true, false) as MeshInstance3D
	for part in PARTS:
		var mi := root.find_child(part, true, false) as MeshInstance3D
		assert_not_null(mi, part)
		if mi == null:
			continue
		var mat := mi.mesh.surface_get_material(0) as BaseMaterial3D
		assert_not_null(mat, part)
		if mat == null:
			continue
		assert_eq(mat.resource_name, MATERIAL, part)
		assert_false(mat.resource_name.to_lower().begins_with(config.team_material_prefix), part)
		assert_not_null(mat.albedo_texture, part)
		assert_true(mat.normal_enabled and mat.normal_texture != null, part)
		for s in body.mesh.get_surface_count():
			assert_ne(body.mesh.surface_get_material(s), mat, "%s shares nothing with the body" % part)


func test_every_human_figure_draws_the_pads() -> void:
	var body := FigureBody.new()
	assert_true(body.setup(models, 0, 3, 0, Color.RED, 0.0, config.lod_high))
	add_child_autofree(body)
	var drawn := PackedStringArray()
	for mi in body.meshes:
		drawn.append(String(mi.name))
	for part in PARTS:
		assert_true(drawn.has(part), part)
