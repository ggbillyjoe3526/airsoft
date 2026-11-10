extends GutTest
## CN1: the heads' neck vertices inside the shirt collar carry non-Head weights; the face and crown stay Head-only.

const GLB := "res://assets/models/characters/human.glb"
const NECK_TOP := 1.50
const CROWN_BOTTOM := 1.60

func _head_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and node.name.begins_with("Head_"):
		out.append(node as MeshInstance3D)
	for c in node.get_children():
		_head_meshes(c, out)

func test_head_neck_vertices_blend_joints_and_crown_is_head_only() -> void:
	var packed := load(GLB) as PackedScene
	assert_not_null(packed, "human.glb loads")
	var root := packed.instantiate()
	add_child_autofree(root)
	var heads: Array[MeshInstance3D] = []
	_head_meshes(root, heads)
	assert_gt(heads.size(), 0, "head meshes found")
	for mi in heads:
		var skin := mi.skin
		assert_not_null(skin, "%s skinned" % mi.name)
		var head_bind := -1
		for b in skin.get_bind_count():
			if skin.get_bind_name(b) == "Head":
				head_bind = b
		assert_ne(head_bind, -1, "%s skin binds Head" % mi.name)
		var neck_mixed := 0
		var crown_bad := 0
		var crown_n := 0
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var v := arr[Mesh.ARRAY_VERTEX] as PackedVector3Array
			var bones := arr[Mesh.ARRAY_BONES] as PackedInt32Array
			var weights := arr[Mesh.ARRAY_WEIGHTS] as PackedFloat32Array
			if bones.is_empty():
				continue
			var per := bones.size() / v.size()
			for i in v.size():
				var head_w := 0.0
				for k in per:
					if bones[i * per + k] == head_bind:
						head_w += weights[i * per + k]
				# Mesh is in the skeleton's rest space, y up: its own height is what the heads' tests measure by.
				if v[i].y > CROWN_BOTTOM:
					crown_n += 1
					if head_w < 0.999:
						crown_bad += 1
				elif v[i].y < NECK_TOP and head_w < 0.999:
					neck_mixed += 1
		assert_eq(crown_bad, 0, "%s crown vertices are Head-only" % mi.name)
		assert_gt(neck_mixed, 0, "%s has neck vertices blended with other joints" % mi.name)
