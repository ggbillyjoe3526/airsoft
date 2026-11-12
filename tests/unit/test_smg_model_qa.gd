extends GutTest
## QA for the Compact SMG's own model (CS2): its worn paint on the hands' meshes only, plain on every figure copy
## (bots, the tossed magazine), repainted between paints, and no stand-in left for model_of to fall back on.

const PATH := "res://assets/models/replicas/smg.glb"

var _models: Array[Node] = []


func before_each() -> void:
	ReplicaPaint.clear()


func after_each() -> void:
	for m in _models:
		m.free()
	_models.clear()
	ReplicaPaint.clear()


func _model() -> Node:
	var m := (load(PATH) as PackedScene).instantiate()
	_models.append(m)
	return m


func _surfaces(model: Node) -> Array:
	var out := []
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var own := mi.mesh.surface_get_material(i)
			if own != null and ReplicaSchemes.PARTS.has(StringName(own.resource_name)):
				out.append([mi, i])
	return out


func test_a_worn_smg_wears_its_hands_meshes_and_a_plain_apply_wears_none() -> void:
	var model := _model()
	ReplicaPaint.apply(model, &"cobalt", false)
	var worn := 0
	for s: Array in _surfaces(model):
		var mi := s[0] as MeshInstance3D
		if not String(mi.name).begins_with("Figure"):
			assert_true(ReplicaPaint.is_worn(mi.get_surface_override_material(s[1])), "%s is worn" % mi.name)
			worn += 1
	assert_gt(worn, 0, "the hands' meshes carry paint")
	ReplicaPaint.apply(model, &"cobalt", false, false)
	for s: Array in _surfaces(model):
		var mi := s[0] as MeshInstance3D
		assert_false(ReplicaPaint.is_worn(mi.get_surface_override_material(s[1])), "%s is plain" % mi.name)


func test_the_smgs_magazine_copy_applied_plain_is_never_worn() -> void:
	var model := _model()
	var mag := model.find_child("Figure_Magazine", true, false) as MeshInstance3D
	assert_not_null(mag)
	var copy := MeshInstance3D.new()
	copy.mesh = mag.mesh
	_models.append(copy)
	ReplicaPaint.apply(copy, &"ghost", true, false)
	for i in copy.mesh.get_surface_count():
		assert_false(ReplicaPaint.is_worn(copy.get_active_material(i)), "surface %d plain" % i)
	assert_eq(ReplicaPaint.surface_materials().size(), 0, "no worn material built for a figure copy")


func test_repainting_the_smg_swaps_colours_and_keeps_one_worn_material_per_part() -> void:
	var model := _model()
	ReplicaPaint.apply(model, &"cobalt", false)
	var before := ReplicaPaint.surface_materials().size()
	ReplicaPaint.apply(model, &"ghost", false)
	var after := ReplicaPaint.surface_materials().size()
	ReplicaPaint.apply(model, &"ghost", false)
	assert_eq(ReplicaPaint.surface_materials().size(), after, "a repeat builds nothing new")
	assert_lte(after, before * 2, "two paints, at most two sets")
	for s: Array in _surfaces(model):
		var mi := s[0] as MeshInstance3D
		if String(mi.name).begins_with("Figure"):
			continue
		var plain := ReplicaPaint.plain_of(mi.get_surface_override_material(s[1])) as StandardMaterial3D
		assert_same(plain, ReplicaPaint.materials(&"ghost", false)[
				ReplicaSchemes.PARTS.find(StringName(mi.mesh.surface_get_material(s[1]).resource_name))])


func test_the_smg_with_no_config_file_still_resolves_to_its_own_model() -> void:
	assert_eq(ReplicaConfig.model_of(&"smg"), &"smg")
	assert_true(ResourceLoader.exists(PATH))
