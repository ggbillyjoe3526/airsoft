class_name HeldMerge
extends RefCounted
## A figure's held replica drawn in as few draws as it has materials (BP5). A figure's version of a replica is its
## `Figure` mesh with pieces under it (iron sights, flash hider, magazine, the parts' copies), each piece its own draw
## of the same few materials: a rifle 12 draws and a holstered pistol 9, at every distance, for every bot. Once it is
## fitted and painted, every piece that shows and doesn't move is merged into the replica's own mesh, one surface a
## material, and hidden; the magazine in its well stays apart, since a reload hides and shows it. The merged mesh is
## made once for each replica, paint and set of parts (`key`) and shared by every figure holding the same.

## One finish's surface of a far version as it is gathered: the first material with that finish and its triangles.
class Painted:
	extends RefCounted
	var like: BaseMaterial3D
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	var indices := PackedInt32Array()

	func _init(material: BaseMaterial3D) -> void:
		like = material


## Where `merge` keeps the replica's own `Figure` mesh, for figure_mesh.
const FIGURE_MESH := &"held_merge_figure_mesh"

static var _made: Dictionary[String, ArrayMesh] = {}
static var _far: Dictionary[String, ArrayMesh] = {}
## The far versions' paints, one a finish (`_finish`), kept for a session: a handful, shared by every far version.
static var _far_paints: Dictionary[String, StandardMaterial3D] = {}


## Merges `held`'s showing pieces (itself included) but `keep` into its own mesh, by material, `key` naming what it is
## fitted and painted with, and returns the name it is kept by: `key` and the materials it was made of, so a paint made
## again (ReplicaPaint's cache let go, or full) makes it again rather than handing on the old one. Pieces it can't merge
## (skinned, with blend shapes, or with a piece under them it can't) stay as they are ("": nothing merged).
static func merge(held: MeshInstance3D, keep: MeshInstance3D, key: String) -> String:
	if held.mesh == null or not _mergeable(held):
		return ""
	var pieces: Array[MeshInstance3D] = []
	var places: Array[Transform3D] = []
	for child: Node in held.get_children():
		_gather(child, Transform3D.IDENTITY, keep, pieces, places)
	key += _materials_named(held, pieces)
	var merged: ArrayMesh = _made.get(key)
	if merged == null:
		merged = _build(held, pieces, places)
		_made[key] = merged
	held.set_meta(FIGURE_MESH, held.mesh)
	held.mesh = merged
	for i in held.get_surface_override_material_count():
		held.set_surface_override_material(i, null)
	for piece in pieces:
		piece.visible = false
	return key


## `held` merged as `merge` would merge it with `leave` (one of its pieces) and what is under it left out, made once for
## `key` and shared, `held` itself unchanged; null if it can't be merged. Called before `merge`: a bot's holstered
## pistol and every far version draw this, without the night torch (BP7, row 69).
static func merged_without(held: MeshInstance3D, keep: MeshInstance3D, key: String, leave: Node3D) -> ArrayMesh:
	if held.mesh == null or not _mergeable(held):
		return null
	var was := leave.visible
	leave.visible = false
	var pieces: Array[MeshInstance3D] = []
	var places: Array[Transform3D] = []
	for child: Node in held.get_children():
		_gather(child, Transform3D.IDENTITY, keep, pieces, places)
	leave.visible = was
	key += _materials_named(held, pieces)
	var merged: ArrayMesh = _made.get(key)
	if merged == null:
		merged = _build(held, pieces, places)
		_made[key] = merged
	return merged


## `held`'s own `Figure` mesh, as it was before `merge` (its own mesh if never merged): where a figure's hands set it
## on the back, in the holster and against the shoulder is worked out from this, not the pieces merged in.
static func figure_mesh(held: MeshInstance3D) -> Mesh:
	return held.get_meta(FIGURE_MESH, held.mesh)


## Lets every merged mesh go (a session's end, as ReplicaPaint.clear: the paints they hold go with it).
static func clear() -> void:
	_made.clear()
	_far.clear()
	_far_paints.clear()


## The far version of `held` (merged) for beyond the far line, named by `key`: every plain painted surface (a
## BaseMaterial3D's colour, no texture or normal map, no glow, opaque) in one surface of vertex colours for each finish
## (its roughness and metallic) they have, the rest (a lens, a glow, a stippled grip) kept as they are. A rifle's 8 draws
## are 2 or 3 at a size of a few dozen pixels. The magazine in its well stays its own node, as up close: a reload
## hides it there too.
static func far_version(held: MeshInstance3D, key: String) -> ArrayMesh:
	var made: ArrayMesh = _far.get(key)
	if made != null:
		return made
	if held.mesh == null:
		return null
	var out := ArrayMesh.new()
	var finishes: Dictionary[String, Painted] = {}
	for surface in held.mesh.get_surface_count():
		var material := _material_of(held, surface)
		var arrays := held.mesh.surface_get_arrays(surface)
		var plain := material as BaseMaterial3D
		if not _plain(plain):
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			out.surface_set_material(out.get_surface_count() - 1, material)
			continue
		var finish := _finish(plain)
		if not finishes.has(finish):
			finishes[finish] = Painted.new(plain)
		var into := finishes[finish]
		_append_painted(arrays, plain, into.verts, into.normals, into.colours, into.indices)
	for finish: String in finishes:
		var into := finishes[finish]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = into.verts
		arrays[Mesh.ARRAY_NORMAL] = into.normals
		arrays[Mesh.ARRAY_COLOR] = into.colours
		arrays[Mesh.ARRAY_INDEX] = into.indices
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(out.get_surface_count() - 1, _far_paint(into.like))
	_far[key] = out
	return out


## Every far versions' paint made so far (one a finish), for ShaderPrewarm: the first figure past the far line
## compiles nothing.
static func far_materials() -> Array[Material]:
	var out: Array[Material] = []
	for m: StandardMaterial3D in _far_paints.values():
		out.append(m)
	return out


## How many replica meshes are kept made (for tests and the debug overlay).
static func made_count() -> int:
	return _made.size()


## Gathers `node` and what is under it into `pieces` (each with its place in the replica, `places`) when all of it can
## be merged; true if it could (or nothing of it shows).
static func _gather(node: Node, parent: Transform3D, keep: MeshInstance3D, pieces: Array[MeshInstance3D],
		places: Array[Transform3D]) -> bool:
	var spatial := node as Node3D
	if spatial == null:
		return true
	if not spatial.visible:
		return true
	if node == keep:
		return false
	var place := parent * spatial.transform
	var mesh_node := node as MeshInstance3D
	if mesh_node == null and node is VisualInstance3D:
		return false
	if mesh_node != null and mesh_node.mesh != null and not _mergeable(mesh_node):
		return false
	var mark := pieces.size()
	var whole := true
	for child: Node in node.get_children():
		whole = _gather(child, place, keep, pieces, places) and whole
	if not whole:
		# something under it stays: it stays too, and so does what was gathered under it
		pieces.resize(mark)
		places.resize(mark)
		return false
	if mesh_node != null and mesh_node.mesh != null:
		pieces.append(mesh_node)
		places.append(place)
	return true


## The material surface `surface` of `node` draws with: its override, else the mesh's.
static func _material_of(node: MeshInstance3D, surface: int) -> Material:
	if node.material_override != null:
		return node.material_override
	var material := node.get_surface_override_material(surface)
	return material if material != null else node.mesh.surface_get_material(surface)


## The materials `held` and `pieces` draw with, by instance, as a name ("/" and their ids).
static func _materials_named(held: MeshInstance3D, pieces: Array[MeshInstance3D]) -> String:
	var ids := PackedStringArray()
	for node: MeshInstance3D in [held] + pieces:
		for s in node.mesh.get_surface_count():
			var material := _material_of(node, s)
			ids.append(str(material.get_instance_id()) if material != null else "-")
	return "/" + ",".join(ids)


## Appends a plainly painted surface's triangles, each vertex coloured as `material` paints it.
static func _append_painted(arrays: Array, material: BaseMaterial3D, verts: PackedVector3Array,
		normals: PackedVector3Array, colours: PackedColorArray, indices: PackedInt32Array) -> void:
	var points := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var own_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null \
			else PackedVector3Array()
	var own_colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null \
			and material.vertex_color_use_as_albedo else PackedColorArray()
	var base := verts.size()
	var albedo := material.albedo_color
	for i in points.size():
		verts.append(points[i])
		normals.append(own_normals[i] if i < own_normals.size() else Vector3.UP)
		if i < own_colours.size():
			var own := own_colours[i] if material.vertex_color_is_srgb else own_colours[i].linear_to_srgb()
			colours.append(own * albedo)
		else:
			colours.append(albedo)
	if arrays[Mesh.ARRAY_INDEX] != null:
		for i: int in arrays[Mesh.ARRAY_INDEX] as PackedInt32Array:
			indices.append(base + i)
	else:
		for i in points.size():
			indices.append(base + i)


## Whether `material` paints with its colour alone (no texture or normal map, no glow, opaque): a far version can
## carry it as vertex colours.
static func _plain(material: BaseMaterial3D) -> bool:
	if material == null or material.emission_enabled or material.normal_enabled \
			or material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return false
	for slot in BaseMaterial3D.TEXTURE_MAX:
		if material.get_texture(slot) != null:
			return false
	return true


## The finish `material` shines with (its roughness, metallic and specular) and the sides it draws (an open shell
## drawn from both), as a name.
static func _finish(material: BaseMaterial3D) -> String:
	return "%.3f/%.3f/%.3f/%d" % [material.roughness, material.metallic, material.metallic_specular, material.cull_mode]


## The far versions' paint for `like`'s finish: each vertex's own colour (sRGB, as the paints' albedo is), shared.
static func _far_paint(like: BaseMaterial3D) -> StandardMaterial3D:
	var finish := _finish(like)
	var made: StandardMaterial3D = _far_paints.get(finish)
	if made == null:
		made = StandardMaterial3D.new()
		made.resource_name = "HeldFar_%s" % finish
		made.vertex_color_use_as_albedo = true
		made.vertex_color_is_srgb = true
		made.roughness = like.roughness
		made.metallic = like.metallic
		made.metallic_specular = like.metallic_specular
		made.cull_mode = like.cull_mode
		_far_paints[finish] = made
	return made


## Whether `node`'s mesh can go into a merged one: not skinned, no blend shapes, triangles only.
static func _mergeable(node: MeshInstance3D) -> bool:
	if node.skin != null or node.mesh.get_blend_shape_count() > 0:
		return false
	for s in node.mesh.get_surface_count():
		if node.mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			return false
	return true


## The merged mesh: `held`'s own surfaces and each piece's at its place, one surface a material, in first-met order.
static func _build(held: MeshInstance3D, pieces: Array[MeshInstance3D], places: Array[Transform3D]) -> ArrayMesh:
	var tools: Array[SurfaceTool] = []
	var materials: Array[Material] = []
	_add(held, Transform3D.IDENTITY, tools, materials)
	for i in pieces.size():
		_add(pieces[i], places[i], tools, materials)
	var out := ArrayMesh.new()
	for i in tools.size():
		tools[i].commit(out)
		out.surface_set_material(i, materials[i])
	return out


static func _add(node: MeshInstance3D, place: Transform3D, tools: Array[SurfaceTool], materials: Array[Material]) -> void:
	var mesh := node.mesh
	for s in mesh.get_surface_count():
		var material := node.material_override
		if material == null:
			material = node.get_surface_override_material(s)
		if material == null:
			material = mesh.surface_get_material(s)
		var at := materials.find(material)
		if at < 0:
			at = materials.size()
			materials.append(material)
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools.append(tool)
		tools[at].append_from(mesh, s, place)
