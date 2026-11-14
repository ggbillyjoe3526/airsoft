class_name RailingMesh
extends RefCounted
## Draws a map's bar railings from their modelled pieces (SM2; RailingLook, tools/blender/maps/railing.py): each bar
## and rail of Railings.parts gets its piece fitted to its box, so the steel drawn is the steel a BB meets, and each
## run gets posts on its panels' end bars (as wide along the run as a bar, so they add none) with floor plates. Built
## once when the level loads; the colours are the models' own (linear).


## A piece's arrays and the box round them.
class Piece:
	var verts: PackedVector3Array
	var normals: PackedVector3Array
	var colours: PackedColorArray
	var indices: PackedInt32Array
	var box: AABB

	func _init(mesh: Mesh) -> void:
		var arrays := mesh.surface_get_arrays(0)
		verts = arrays[Mesh.ARRAY_VERTEX]
		normals = arrays[Mesh.ARRAY_NORMAL]
		# A model exported with no vertex colours or no index holds null there, which a typed array won't take: the
		# fallbacks below fill them in.
		var raw_colours: Variant = arrays[Mesh.ARRAY_COLOR]
		if raw_colours != null:
			colours = raw_colours
		var raw_indices: Variant = arrays[Mesh.ARRAY_INDEX]
		if raw_indices != null:
			indices = raw_indices
		if indices.is_empty():
			for i in verts.size():
				indices.append(i)
		if colours.size() != verts.size():
			colours.resize(verts.size())
			colours.fill(Color.WHITE)
		box = mesh.get_aabb()


## The mesh's arrays as they fill (members, so each append grows them in place).
class Arrays:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	var indices := PackedInt32Array()


## The railings' mesh: every run of `railings` (in the order MapLevel added them) in `look`'s pieces; null when a
## piece's model can't be read (MapLevel then draws the plain boxes).
static func build(railings: Railings, look: RailingLook) -> ArrayMesh:
	var bar := _piece(look.bar_model)
	var top := _piece(look.top_model)
	var foot := _piece(look.foot_model)
	var post := _piece(look.post_model)
	if bar == null or top == null or foot == null or post == null:
		return null
	# The posts' floor plates, in the post's paint a shade darker.
	var plate := Piece.new(_plate_mesh())
	var paint := post.colours[0]
	plate.colours.fill(Color(paint.r * 0.85, paint.g * 0.85, paint.b * 0.85))
	var out := Arrays.new()
	var boxes: Array[AABB] = []
	for run in railings.size():
		boxes.clear()
		railings.parts(run, boxes)
		var along_x := railings.along_x[run] == 1
		var bars := railings.gaps[run] + 1
		# Each bar's top stops halfway into the top rail: hidden there all the same, and its end never shows through
		# the rail's rounded top.
		var sink := minf(railings.config.rail_height, boxes[bars].size.y) * 0.5
		for k in bars:
			var b := boxes[k]
			b.size.y -= sink
			_add(out, bar, b, along_x)
		_add(out, top, boxes[bars], along_x)
		if boxes.size() > bars + 1:
			_add(out, foot, boxes[bars + 1], along_x)
		_add_posts(out, post, plate, boxes, railings, run, look)
	if out.verts.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = out.verts
	arrays[Mesh.ARRAY_NORMAL] = out.normals
	arrays[Mesh.ARRAY_COLOR] = out.colours
	arrays[Mesh.ARRAY_INDEX] = out.indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## The run's posts: on the bars ending each of its panels (about `post_spacing` long), from its foot to its top and as
## deep across it as the post model; each with a floor plate (`plate`) kept inside the run's box.
static func _add_posts(out: Arrays, post: Piece, plate: Piece, boxes: Array[AABB], railings: Railings, run: int,
		look: RailingLook) -> void:
	var lo := railings.mins[run]
	var hi := railings.maxs[run]
	var along_x := railings.along_x[run] == 1
	var a := 0 if along_x else 2
	var c := 2 - a
	var gaps := railings.gaps[run]
	var sink := minf(railings.config.rail_height, hi.y - lo.y) * 0.5
	var panels := maxi(1, roundi((hi[a] - lo[a]) / maxf(look.post_spacing, 0.1)))
	var across := minf(post.box.size.z, hi[c] - lo[c])
	var mid := (lo[c] + hi[c]) * 0.5
	for i in panels + 1:
		var k := roundi(float(i * gaps) / panels)
		var b: AABB = boxes[k]
		var p := b.position
		var s := b.size
		p[c] = mid - across * 0.5
		s[c] = across
		s.y -= sink
		_add(out, post, AABB(p, s), along_x)
		var side := minf(look.plate_side, hi[a] - lo[a])
		var centre := clampf(b.get_center()[a], lo[a] + side * 0.5, hi[a] - side * 0.5)
		var pp := lo
		pp[a] = centre - side * 0.5
		var plate_across := minf(look.plate_side, hi[c] - lo[c])
		pp[c] = mid - plate_across * 0.5
		var ps := Vector3.ZERO
		ps[a] = side
		ps[c] = plate_across
		ps.y = minf(look.plate_thickness, hi.y - lo.y)
		_add(out, plate, AABB(pp, ps), along_x)


## Appends `piece` fitted to `box` (its x along the run; turned a quarter about y for a run along z) to `out`.
static func _add(out: Arrays, piece: Piece, box: AABB, along_x: bool) -> void:
	var k := piece.box
	var t := Transform3D()
	if along_x:
		var s := box.size / k.size
		t.basis = Basis.from_scale(s)
		t.origin = box.position - k.position * s
	else:
		# The piece's x runs along +z and its z along -x: a turn, not a mirror, so the faces keep their winding.
		var sx := box.size.x / k.size.z
		var sz := box.size.z / k.size.x
		var sy := box.size.y / k.size.y
		t.basis = Basis(Vector3(0.0, 0.0, sz), Vector3(0.0, sy, 0.0), Vector3(-sx, 0.0, 0.0))
		t.origin = Vector3(box.position.x + k.end.z * sx, box.position.y - k.position.y * sy,
				box.position.z - k.position.x * sz)
	var n_basis := t.basis.inverse().transposed()
	var base := out.verts.size()
	for v in piece.verts:
		out.verts.append(t * v)
	for n in piece.normals:
		out.normals.append((n_basis * n).normalized())
	out.colours.append_array(piece.colours)
	for i in piece.indices:
		out.indices.append(base + i)


## A piece's mesh from its model, null if it can't be read.
static func _piece(path: String) -> Piece:
	var mesh := PropDressConfig.load_mesh(path)
	if mesh == null or mesh.get_surface_count() == 0:
		return null
	return Piece.new(mesh)


## A floor plate: a unit box without its foot (it lies on the floor).
static func _plate_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(Color.WHITE)
	for f in GreyboxFaces.box_faces(Vector3.ZERO, Vector3.ONE):
		var nrm := GreyboxFaces.face_normal(f)
		if nrm.y < -0.5:
			continue
		for i in range(1, f.size() - 1):
			st.set_normal(nrm)
			st.add_vertex(f[0])
			st.set_normal(nrm)
			st.add_vertex(f[i + 1])
			st.set_normal(nrm)
			st.add_vertex(f[i])
	st.index()
	return st.commit()
