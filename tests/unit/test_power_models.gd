extends GutTest
## The four power-source menu models (BL7): inside the file budget, the `Label` material only where ReplicaPictures
## paints it, the bottle upright and the batteries and spring lying along Z.

const DIR := "res://assets/models/powerSources/"
const MAX_TRIANGLES := 6000
const MAX_BYTES := 120 * 1024
const WITH_LABEL: Array[String] = ["gasBottle", "spring"]
const WITHOUT_LABEL: Array[String] = ["lipoBattery", "standardBattery"]
const LYING: Array[String] = ["lipoBattery", "standardBattery", "spring"]


func _meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		out.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		_meshes(child, out)


func _load(file: String) -> Node3D:
	var scene := load(DIR + file + ".glb") as PackedScene
	assert_not_null(scene, file)
	var root := scene.instantiate() as Node3D
	add_child_autofree(root)
	return root


func _triangles(root: Node) -> int:
	var meshes: Array[MeshInstance3D] = []
	_meshes(root, meshes)
	var total := 0
	for m: MeshInstance3D in meshes:
		total += m.mesh.get_faces().size() / 3
	return total


func _has_label(root: Node) -> bool:
	var meshes: Array[MeshInstance3D] = []
	_meshes(root, meshes)
	for m: MeshInstance3D in meshes:
		for s in m.mesh.get_surface_count():
			var mat := m.mesh.surface_get_material(s)
			if mat != null and mat.resource_name == "Label":
				return true
	return false


## The model's bounds in the root's space (the glb root carries no transform of its own in the menus' tips).
func _bounds(root: Node3D) -> AABB:
	var meshes: Array[MeshInstance3D] = []
	_meshes(root, meshes)
	var box := AABB()
	var first := true
	for m: MeshInstance3D in meshes:
		var b := root.global_transform.affine_inverse() * m.global_transform * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func test_every_power_model_is_inside_the_budget() -> void:
	for file: String in WITH_LABEL + WITHOUT_LABEL:
		var root := _load(file)
		var tris := _triangles(root)
		assert_gt(tris, 0, file)
		assert_lte(tris, MAX_TRIANGLES, "%s triangles" % file)
		var f := FileAccess.open(DIR + file + ".glb", FileAccess.READ)
		assert_not_null(f, file)
		if f:
			assert_lte(f.get_length(), MAX_BYTES, "%s bytes" % file)


func test_no_power_model_has_a_texture() -> void:
	for file: String in WITH_LABEL + WITHOUT_LABEL:
		var meshes: Array[MeshInstance3D] = []
		_meshes(_load(file), meshes)
		for m: MeshInstance3D in meshes:
			for s in m.mesh.get_surface_count():
				var mat := m.mesh.surface_get_material(s) as BaseMaterial3D
				if mat:
					assert_null(mat.albedo_texture, "%s %s" % [file, mat.resource_name])


func test_label_material_is_on_the_bottle_and_spring_only() -> void:
	for file: String in WITH_LABEL:
		assert_true(_has_label(_load(file)), "%s keeps its Label material" % file)
	for file: String in WITHOUT_LABEL:
		assert_false(_has_label(_load(file)), "%s has no Label material" % file)


func test_bottle_stands_up_with_its_tip_at_zero() -> void:
	var box := _bounds(_load("gasBottle"))
	assert_gt(box.size.y, box.size.x, "taller than wide")
	assert_gt(box.size.y, box.size.z, "taller than deep")
	assert_almost_eq(box.position.y, 0.0, 0.02, "stands on y = 0")


func test_batteries_and_spring_lie_along_z() -> void:
	for file: String in LYING:
		var box := _bounds(_load(file))
		assert_gt(box.size.z, box.size.x, "%s longer along Z than X" % file)
		assert_gt(box.size.z, box.size.y, "%s longer along Z than Y" % file)
