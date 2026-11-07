class_name BodyMerge
extends RefCounted
## A figure's opaque parts at one level folded into one mesh of one surface a material (BP6), so the human's Kit, pack
## and radio share their Gear draw (11 draws a level to 9) and the robot's Body, Neck and Head their materials (13 to
## 7). Exact: the surfaces' stored bytes (positions, normals, tangents, UVs, colours, bones, weights) are copied as
## they are, only the indices offset, and each mesh LOD the engine would pick for a part at a distance is the one the
## merged surface picks there (its LODs are every part's edge lengths, each holding the coarsest LOD a part has at or
## under it). A part with a see-through material keeps its own draw (merged, its sort by depth would change).
## It reads and writes ArrayMesh's private `_surfaces` (the engine's stored surface data: positions, then normals and
## tangents, as one stream; attributes and skin per vertex), a layout pinned by tests/unit/test_bp6_graphics.gd on
## Godot 4.7.2: a new engine version must pass those tests before this is trusted.

const INDEX_BYTES := 2
## A position's bytes: three floats. The vertex data holds every position, then every normal and tangent.
const POSITION_BYTES := 12
## Formats folded as stored: the 3D positions uncompressed.
const UNFOLDABLE_FORMAT := Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES | Mesh.ARRAY_FLAG_USE_2D_VERTICES
## The most vertices a merged surface takes: 16-bit indices, as the engine stores them below 2^16.
const MAX_VERTICES := 65535


## Whether `mesh` can be folded: every surface opaque, of triangles, with no blend shapes.
static func foldable(mesh: Mesh) -> bool:
	var am := mesh as ArrayMesh
	if am == null or am.get_blend_shape_count() > 0:
		return false
	for s in am.get_surface_count():
		var m := am.surface_get_material(s) as BaseMaterial3D
		if m == null or m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			return false
		if am.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			return false
	return true


## `sources` (foldable meshes on one skin) as one mesh, one surface a material in the order they first show; null when
## two surfaces of a material differ in their format or there are too many vertices for one.
static func merge(sources: Array[Mesh]) -> ArrayMesh:
	var materials: Array[Material] = []
	var groups: Array[Array] = []
	for mesh in sources:
		for d: Dictionary in mesh.get("_surfaces") as Array:
			var m := d.get("material") as Material
			var at := materials.find(m)
			if at < 0:
				materials.append(m)
				groups.append([])
				at = groups.size() - 1
			groups[at].append(d)
	var out: Array[Dictionary] = []
	for g in groups:
		var made := _merge_group(g)
		if made.is_empty():
			return null
		out.append(made)
	var merged := ArrayMesh.new()
	merged.set("_surfaces", out)
	return merged


static func _merge_group(group: Array) -> Dictionary:
	var first: Dictionary = group[0]
	if group.size() == 1:
		return first.duplicate()
	var count := 0
	for d: Dictionary in group:
		if d.get("format") != first.get("format") or d.get("uv_scale", Vector4.ZERO) != first.get("uv_scale", Vector4.ZERO):
			return {}
		if not (d.get("blend_shapes", []) as Array).is_empty() or (d.get("format", 0) as int) & UNFOLDABLE_FORMAT:
			return {}
		count += d.get("vertex_count", 0) as int
	if count > MAX_VERTICES:
		return {}
	var positions := PackedByteArray()
	var normals := PackedByteArray()
	var attribute := PackedByteArray()
	var skin := PackedByteArray()
	var index := PackedByteArray()
	var aabb := first.get("aabb") as AABB
	var bone_aabbs: Array = []
	# Every part's LOD edge lengths, ascending, each once.
	var edges := PackedFloat32Array()
	for d: Dictionary in group:
		var lods := d.get("lods", []) as Array
		for i in range(0, lods.size(), 2):
			if not edges.has(lods[i] as float):
				edges.append(lods[i] as float)
	edges.sort()
	var lod_index: Array[PackedByteArray] = []
	for e in edges:
		lod_index.append(PackedByteArray())
	var base := 0
	for d: Dictionary in group:
		# Its positions apart from its normals and tangents, each stream after the last part's (the attribute and skin
		# data hold each vertex's together).
		var vertex := d.get("vertex_data", PackedByteArray()) as PackedByteArray
		var split := (d.get("vertex_count", 0) as int) * POSITION_BYTES
		positions.append_array(vertex.slice(0, split))
		normals.append_array(vertex.slice(split))
		attribute.append_array(d.get("attribute_data", PackedByteArray()) as PackedByteArray)
		skin.append_array(d.get("skin_data", PackedByteArray()) as PackedByteArray)
		var own := d.get("index_data", PackedByteArray()) as PackedByteArray
		index.append_array(_offset(own, base))
		aabb = aabb.merge(d.get("aabb") as AABB)
		_merge_bones(bone_aabbs, d.get("bone_aabbs", []) as Array)
		# For each merged edge, the coarsest LOD of this part at or under it (its full indices under its first).
		var lods := d.get("lods", []) as Array
		var shifted: Array[PackedByteArray] = []
		for i in range(1, lods.size(), 2):
			shifted.append(_offset(lods[i] as PackedByteArray, base))
		var full := index.slice(index.size() - own.size())
		for j in edges.size():
			var pick := -1
			for i in range(0, lods.size(), 2):
				if (lods[i] as float) <= edges[j]:
					pick = i / 2
			lod_index[j].append_array(full if pick < 0 else shifted[pick])
		base += d.get("vertex_count", 0) as int
	var lods_out: Array = []
	for j in edges.size():
		lods_out.append(edges[j])
		lods_out.append(lod_index[j])
	var made := first.duplicate()
	positions.append_array(normals)
	made["vertex_data"] = positions
	made["attribute_data"] = attribute
	made["skin_data"] = skin
	made["vertex_count"] = base
	made["index_data"] = index
	made["index_count"] = index.size() / INDEX_BYTES
	made["aabb"] = aabb
	made["bone_aabbs"] = bone_aabbs
	made["lods"] = lods_out
	return made


## `indices` (16-bit) with `base` added to each.
static func _offset(indices: PackedByteArray, base: int) -> PackedByteArray:
	if base == 0:
		return indices
	var out := PackedByteArray()
	out.resize(indices.size())
	for i in range(0, indices.size(), INDEX_BYTES):
		out.encode_u16(i, indices.decode_u16(i) + base)
	return out


## Each bone's box in `into` widened by `more`'s (a negative size: the bone holds no vertex).
static func _merge_bones(into: Array, more: Array) -> void:
	for i in more.size():
		var b := more[i] as AABB
		if i >= into.size():
			into.append(b)
		elif b.size.x >= 0.0:
			var a := into[i] as AABB
			into[i] = b if a.size.x < 0.0 else a.merge(b)
