extends SceneTree
## Dumps every drawn triangle of a field as a match builds it (a whole PlaySession, headless), for the coplanar-face
## check (tools/coplanar_check.py): faces lying in one plane over one another flicker ("z-fighting"), so the pass that
## hunts them needs every mesh's triangles in world space. Writes `<folder>/<map>.bin` (per triangle: nine float32
## positions, the source's index as float32, the mean vertex colour as four float32) and `<folder>/<map>.json` (each
## source: its node's path, its mesh, its surface and its material). Leaves out what is hidden, what is drawn only
## from afar (a far detail level stands where its near one does on purpose), what only casts a shadow, the players and
## the first-person view. Each source also carries the least and most its model is stretched along its own axes over
## its placements (`scale_min`, `scale_max`), which tools/coplanar_models.py's lift is sized by; with `scales` as the
## fourth word only the sources are written, not the triangles.
##   godot --path . -s res://tools/coplanar_dump.gd -- <folder> <map> [preset] [scales]
## Run it with a real renderer (under xvfb in a cloud session): headless, a MultiMesh's placements read as identity.
## Dev only: tools/ never ships.

## A MultiMesh's instances past this many triangles in all are left out (a wood's leaves): no flat faces to compare.
const MOST_INSTANCED := 3_000_000
const FLOATS := 14
## A placement shrunk under this on any axis is parked out of sight (a pool's spare piece), not a stretch to count.
const PARKED := 0.001

var _sources: Array[Dictionary] = []
var _out: FileAccess = null
var _triangles: int = 0
var _skipped: Array[String] = []
var _scales_only: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("coplanar_dump: give a folder and a map id")
		quit(1)
		return
	var folder := args[0]
	var map_id := args[1]
	var preset := StringName(args[2]) if args.size() > 2 else &"ultra"
	_scales_only = args.size() > 3 and args[3] == "scales"
	DirAccess.make_dir_recursive_absolute(folder)
	var session := PlaySession.new()
	session.settings = Settings.new(PlayTuning.new())
	session.settings.choose_graphics(preset, preset)
	session.map_id = map_id
	session.match_seed = 3
	session.autopilot = true
	root.add_child(session)
	if session.state == null:
		push_error("coplanar_dump: %s refused" % map_id)
		quit(1)
		return
	for i in 4:
		await process_frame
	session.set_physics_process(false)
	session.set_process(false)
	if not _scales_only:
		_out = FileAccess.open("%s/%s.bin" % [folder, map_id], FileAccess.WRITE)
	_walk(session)
	if _out != null:
		_out.close()
	var meta := FileAccess.open("%s/%s.json" % [folder, map_id], FileAccess.WRITE)
	meta.store_string(JSON.stringify({"sources": _sources, "skipped": _skipped, "triangles": _triangles}))
	meta.close()
	print("coplanar_dump: %s %d triangles from %d sources, %d left out" % [map_id, _triangles, _sources.size(),
			_skipped.size()])
	quit()


func _walk(node: Node) -> void:
	if node is FigureView or node is CanvasItem or node is CanvasLayer or node is Camera3D:
		return
	if node is Node3D and not (node as Node3D).visible:
		return
	if node is GeometryInstance3D:
		var g := node as GeometryInstance3D
		if g.visibility_range_begin <= 0.0 and g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			if g is MeshInstance3D and (g as MeshInstance3D).mesh != null:
				_mesh(g, (g as MeshInstance3D).mesh, [g.global_transform])
			elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh != null:
				var mm := (g as MultiMeshInstance3D).multimesh
				if mm.mesh != null:
					var count := mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
					var xforms: Array[Transform3D] = []
					for i in count:
						xforms.append(g.global_transform * mm.get_instance_transform(i))
					_mesh(g, mm.mesh, xforms)
	for child in node.get_children():
		_walk(child)


func _mesh(node: GeometryInstance3D, mesh: Mesh, xforms: Array[Transform3D]) -> void:
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null:
			continue
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null \
				else PackedInt32Array()
		var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null \
				else PackedColorArray()
		var tris := (index.size() if not index.is_empty() else verts.size()) / 3
		var material: Material = node.material_override
		if material == null and node is MeshInstance3D:
			material = (node as MeshInstance3D).get_surface_override_material(s)
		if material == null:
			material = mesh.surface_get_material(s)
		var where := "%s|%s|%d" % [node.get_path(), mesh.resource_path, s]
		if tris * xforms.size() > MOST_INSTANCED:
			_skipped.append("%s (%d x %d)" % [where, tris, xforms.size()])
			continue
		var id := _sources.size()
		var least := Vector3.INF
		var most := Vector3.ZERO
		for xf in xforms:
			var stretch := xf.basis.get_scale().abs()
			if stretch.x > PARKED and stretch.y > PARKED and stretch.z > PARKED:
				least = least.min(stretch)
				most = most.max(stretch)
		_sources.append({"node": str(node.get_path()), "mesh": mesh.resource_path, "name": mesh.resource_name,
				"surface": s, "material": _material_name(material), "instances": xforms.size(), "triangles": tris,
				"cull": _cull(material), "blend": _blend(material),
				"scale_min": [least.x, least.y, least.z] if most != Vector3.ZERO else [],
				"scale_max": [most.x, most.y, most.z] if most != Vector3.ZERO else []})
		if _scales_only:
			continue
		var buffer := PackedFloat32Array()
		buffer.resize(tris * FLOATS)
		for xf in xforms:
			var world := PackedVector3Array()
			world.resize(verts.size())
			for i in verts.size():
				world[i] = xf * verts[i]
			# Written counter-clockwise seen from the face's front (the check's cross product then points out of it):
			# Godot's front is clockwise, so the last two corners swap, but for a mirrored placement, which turns
			# every face over once more.
			var second := 1 if xf.basis.determinant() < 0.0 else 2
			var at := 0
			for t in tris:
				var a := index[t * 3] if not index.is_empty() else t * 3
				var b := index[t * 3 + second] if not index.is_empty() else t * 3 + second
				var c := index[t * 3 + 3 - second] if not index.is_empty() else t * 3 + 3 - second
				for v: int in [a, b, c]:
					var p := world[v]
					buffer[at] = p.x
					buffer[at + 1] = p.y
					buffer[at + 2] = p.z
					at += 3
				buffer[at] = id
				var col := Color.WHITE
				if not colours.is_empty():
					col = (colours[a] + colours[b] + colours[c]) / 3.0
				buffer[at + 1] = col.r
				buffer[at + 2] = col.g
				buffer[at + 3] = col.b
				buffer[at + 4] = col.a
				at += 5
			_out.store_buffer(buffer.to_byte_array())
			_triangles += tris


static func _material_name(material: Material) -> String:
	if material == null:
		return "none"
	if material is ShaderMaterial and (material as ShaderMaterial).shader != null:
		var shader := (material as ShaderMaterial).shader
		return "shader:%s:%s" % [shader.resource_path.get_file(), material.resource_name]
	return "%s:%s:%s" % [material.get_class(), material.resource_name, material.resource_path.get_file()]


static func _cull(material: Material) -> String:
	if material is BaseMaterial3D:
		return ["back", "front", "off"][(material as BaseMaterial3D).cull_mode]
	if material is ShaderMaterial and (material as ShaderMaterial).shader != null:
		return "off" if (material as ShaderMaterial).shader.code.contains("cull_disabled") else "back"
	return "back"


static func _blend(material: Material) -> String:
	if material is BaseMaterial3D:
		return ["opaque", "alpha", "scissor", "hash", "depth"][(material as BaseMaterial3D).transparency]
	if material is ShaderMaterial and (material as ShaderMaterial).shader != null:
		var code := (material as ShaderMaterial).shader.code
		if code.contains("blend_add") or code.contains("ALPHA =") or code.contains("ALPHA="):
			return "alpha"
	return "opaque"
