extends GutTest
## RM2: the sandbag models carry custom split normals; every imported normal must be finite and unit length.

const MODELS: Array[String] = [
	"sandbags", "sandbags_b", "sandbags_c", "sandbags_start", "sandbags_end",
]


func _meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for c: Node in node.get_children():
		_meshes(c, out)


func test_every_sandbag_normal_is_finite_and_unit_length() -> void:
	for m: String in MODELS:
		var scene := load("res://assets/models/props/%s.glb" % m) as PackedScene
		assert_not_null(scene, m)
		var root: Node = scene.instantiate()
		var found: Array[MeshInstance3D] = []
		_meshes(root, found)
		assert_gt(found.size(), 0, "%s has a mesh" % m)
		var bad := 0
		var total := 0
		for mi: MeshInstance3D in found:
			for s in mi.mesh.get_surface_count():
				var arrays := mi.mesh.surface_get_arrays(s)
				var normals := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
				assert_gt(normals.size(), 0, "%s has normals" % m)
				for n: Vector3 in normals:
					total += 1
					if not n.is_finite() or absf(n.length() - 1.0) > 0.01:
						bad += 1
		assert_eq(bad, 0, "%s: %d of %d normals not unit length" % [m, bad, total])
		root.free()
