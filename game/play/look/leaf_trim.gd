class_name LeafTrim
extends RefCounted
## A tree crown's leaf cards cut down to the leaves they draw (WF1). A card is a quad of one of the leaf sheet's cells
## (look_foliage.gdshader), and a spray fills only a part of its cell: the rest is cut out texel by texel, but the GPU
## still rasterises it and runs the cut-out test on it, layer under layer through a crown (BP12: Woodland's frame took
## about twice Beta 1's GPU time once the crowns were cards). Each card here is cut to its cell's rectangle
## (LeafTrimSheet: every texel the shader draws up to the sheet's `max_mip`), its corners moved along the card itself,
## each with its colour and normal at its new place; how far each corner moved (in the model and on the sheet) goes in
## its CUSTOM0 and CUSTOM1, with the card's own facing, and the shader opens the card back out to its whole cell as the
## card grows small enough on screen for its cut-out to read a coarser level (far crowns keep the fill their coarse mips
## give them). So every leaf is drawn where it was, at every distance; only the near cards' empty margins go.
##
## The solid faces (bark, the crowns' cores) are moved ahead of the cards in each surface's index list, so a crown's
## core is in the depth buffer before the cards behind it are tested. Cards of a cell drawn whole, cards that aren't
## one flat axis-aligned quad on the sheet (a spruce tier's kites, a fern's fronds) and every other face are kept as they
## are. The mesh keeps its box (custom_aabb, as the opened cards reach it), its material and its levels of detail (the
## importer's, whose cards open the same way, solid faces first too). A card sharing a corner with any other face is
## kept whole (moving the corner would move that face). Built once a model (allocates).

## What trimming changed in a surface: nothing, only its faces' order (solid first), or its cards too.
enum Change { NONE, ORDER, TRIMMED }

## A leaf face's UV x is 0 or more (the sheet); a bark face's is under this (look_foliage.gdshader).
const BARK_BELOW := -1.0
## A card trimmed to more than this share of its area is kept whole (it would save next to nothing).
const KEEP_OVER := 0.9
## How near (on the sheet) a corner must be to its card's rectangle's corner to count as one.
const CORNER := 1e-4
## How far (a share of the card's size) a card's fourth corner may lie off the plane of the other three.
const FLAT := 1e-3
## The arrays a trimmed surface may carry (anything else, bones or custom data of its own, and it is kept as it is).
const ARRAYS_KNOWN: Array[int] = [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR,
		Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_INDEX]
## Each corner's way back out: CUSTOM0 xyz the model-space move, CUSTOM1 xy the sheet's, zw the card's facing
## (octahedral), all floats.
const CUSTOM_FORMAT := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) \
		| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
## A card's corners by their place on its rectangle: low-low, high-low, low-high, high-high (x, y on the sheet).
const SIDES: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]


## `mesh` with its cards trimmed to `sheet` and its solid faces drawn first; `mesh` itself when neither changes it.
static func trimmed(mesh: Mesh, sheet: LeafTrimSheet) -> Mesh:
	if mesh == null or sheet == null or sheet.rects.is_empty():
		return mesh
	var out := ArrayMesh.new()
	var any := false
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var lods := _lods(mesh, s)
		var change := _trim_surface(arrays, sheet)
		any = any or change != Change.NONE
		if change != Change.NONE:
			for error: float in lods:
				lods[error] = _solid_first(lods[error], arrays[Mesh.ARRAY_TEX_UV], sheet)
		var flags: int = mesh.surface_get_format(s) & Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES
		if change == Change.TRIMMED:
			flags |= CUSTOM_FORMAT
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], lods, flags)
		out.surface_set_material(s, mesh.surface_get_material(s))
		if mesh is ArrayMesh:
			out.surface_set_name(s, (mesh as ArrayMesh).surface_get_name(s))
	if not any:
		return mesh
	out.custom_aabb = mesh.get_aabb()
	out.resource_name = mesh.resource_name
	return out


## Surface `s`'s levels of detail as the importer made them {error: indices}.
static func _lods(mesh: Mesh, s: int) -> Dictionary:
	var lods := {}
	var d := RenderingServer.mesh_get_surface(mesh.get_rid(), s)
	var count: int = d.get("index_count", 0)
	var data: PackedByteArray = d.get("index_data", PackedByteArray())
	if count <= 0 or data.is_empty():
		return lods
	var wide := data.size() / count >= 4
	for lod: Dictionary in d.get("lods", []):
		var bytes: PackedByteArray = lod["index_data"]
		var idx := PackedInt32Array()
		if wide:
			idx = bytes.to_int32_array()
		else:
			idx.resize(bytes.size() / 2)
			for i in idx.size():
				idx[i] = bytes.decode_u16(i * 2)
		lods[lod["edge_length"]] = idx
	return lods


## Trims `arrays`' cards in place (their corners moved, CUSTOM0 and CUSTOM1 added) and puts the solid faces first in
## the index list; what changed.
static func _trim_surface(arrays: Array, sheet: LeafTrimSheet) -> Change:
	if arrays[Mesh.ARRAY_INDEX] == null or arrays[Mesh.ARRAY_TEX_UV] == null or arrays[Mesh.ARRAY_NORMAL] == null:
		return Change.NONE
	for a in Mesh.ARRAY_MAX:
		if arrays[a] != null and not ARRAYS_KNOWN.has(a):
			return Change.NONE
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var count := (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var before: PackedVector3Array = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()
	var tris := idx.size() / 3
	# the leaf faces, and each card: two of them sharing an edge
	var leaf := PackedByteArray()
	leaf.resize(tris)
	var by_edge := {}
	var partner := PackedInt32Array()
	partner.resize(tris)
	partner.fill(-1)
	for t in tris:
		leaf[t] = 1 if _on_sheet(uv, idx, t) else 0
		if leaf[t] == 0:
			continue
		for k in 3:
			var a := idx[t * 3 + k]
			var b := idx[t * 3 + (k + 1) % 3]
			var key := Vector2i(mini(a, b), maxi(a, b))
			if by_edge.has(key):
				var o: int = by_edge[key]
				if o >= 0 and partner[o] < 0 and partner[t] < 0:
					partner[o] = t
					partner[t] = o
				by_edge[key] = -1 # an edge of more than two faces pairs no more
			else:
				by_edge[key] = t
	var grow := PackedFloat32Array()
	grow.resize(count * 4)
	var grow_uv := PackedFloat32Array()
	grow_uv.resize(count * 4)
	var moved := PackedByteArray()
	moved.resize(count)
	var uses := PackedInt32Array() # the faces each corner is in
	uses.resize(count)
	for i in idx:
		uses[i] += 1
	var trimmed_any := false
	for t in tris:
		var o := partner[t]
		if o > t and _own_corners(idx, t, o, uses) \
				and _trim_card(arrays, sheet, _corners(idx, t, o), grow, grow_uv, moved):
			trimmed_any = true
	var ordered := _solid_first(idx, uv, sheet)
	if not trimmed_any:
		if ordered == idx:
			return Change.NONE
		arrays[Mesh.ARRAY_INDEX] = ordered
		return Change.ORDER
	arrays[Mesh.ARRAY_INDEX] = ordered
	arrays[Mesh.ARRAY_CUSTOM0] = grow
	arrays[Mesh.ARRAY_CUSTOM1] = grow_uv
	_hold_box(arrays, before)
	return Change.TRIMMED


## A copy (no face uses it) of each corner the trim moved off the surface's box, where it was, so the surface keeps the
## box its positions are packed against (ARRAY_FLAG_COMPRESS_ATTRIBUTES: each position kept as a share of the
## surface's box) and every corner the trim didn't move lands exactly where it did. Each copy is a point of the model
## as built, so the mesh's corners still all lie inside it.
static func _hold_box(arrays: Array, before: PackedVector3Array) -> void:
	var at: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var ends := PackedInt32Array()
	for axis in 3:
		var low := 0
		var high := 0
		for i in before.size():
			low = i if before[i][axis] < before[low][axis] else low
			high = i if before[i][axis] > before[high][axis] else high
		for i: int in [low, high]:
			if not ends.has(i) and not at[i].is_equal_approx(before[i]):
				ends.append(i)
	for i in ends:
		at.append(before[i])
		for a: int in [Mesh.ARRAY_NORMAL, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_COLOR]:
			if arrays[a] != null:
				var values: Variant = arrays[a]
				values.append(values[i])
				arrays[a] = values
		if arrays[Mesh.ARRAY_TANGENT] != null:
			var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
			tangents.append_array(tangents.slice(i * 4, i * 4 + 4))
			arrays[Mesh.ARRAY_TANGENT] = tangents
		for a: int in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1]:
			arrays[a] = (arrays[a] as PackedFloat32Array) + PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	arrays[Mesh.ARRAY_VERTEX] = at


## `idx`'s solid faces (bark, cells drawn whole) ahead of its cards, each kept in its own order.
static func _solid_first(idx: PackedInt32Array, uv: PackedVector2Array, sheet: LeafTrimSheet) -> PackedInt32Array:
	var solid := PackedInt32Array()
	var cards := PackedInt32Array()
	for t in idx.size() / 3:
		var face := idx.slice(t * 3, t * 3 + 3)
		if _on_sheet(uv, idx, t) and not _cell_solid(uv, idx, t, sheet):
			cards.append_array(face)
		else:
			solid.append_array(face)
	return solid + cards


## Whether no face but triangles `t` and `o` (a card) uses any of their corners, so moving one moves only that card.
static func _own_corners(idx: PackedInt32Array, t: int, o: int, uses: PackedInt32Array) -> bool:
	var own := {}
	for k in 3:
		own[idx[t * 3 + k]] = own.get(idx[t * 3 + k], 0) + 1
		own[idx[o * 3 + k]] = own.get(idx[o * 3 + k], 0) + 1
	for c: int in own:
		if uses[c] != own[c]:
			return false
	return true


## Whether triangle `t` lies on the leaf sheet (not bark).
static func _on_sheet(uv: PackedVector2Array, idx: PackedInt32Array, t: int) -> bool:
	for k in 3:
		if uv[idx[t * 3 + k]].x < BARK_BELOW:
			return false
	return true


## Whether triangle `t` (on the sheet) is drawn from a cell drawn whole: a crown's core, a twig's bark.
static func _cell_solid(uv: PackedVector2Array, idx: PackedInt32Array, t: int, sheet: LeafTrimSheet) -> bool:
	var mid := (uv[idx[t * 3]] + uv[idx[t * 3 + 1]] + uv[idx[t * 3 + 2]]) / 3.0 * float(sheet.grid)
	return not sheet.rect_of(Vector2i(floori(mid.x), floori(mid.y))).has_area()


## The four corners (vertex ids) of triangles `t` and `o` joined across their shared edge; empty when they share none.
static func _corners(idx: PackedInt32Array, t: int, o: int) -> PackedInt32Array:
	var out := PackedInt32Array([idx[t * 3], idx[t * 3 + 1], idx[t * 3 + 2]])
	for k in 3:
		var v := idx[o * 3 + k]
		if not out.has(v):
			out.append(v)
	return out if out.size() == 4 else PackedInt32Array()


## Trims one card (its four corner ids): when they are the corners of one axis-aligned rectangle on the sheet, inside
## one cell drawn trimmed, on one flat face, and no corner is another card's, each corner moves in to the cell's
## rectangle, its way back written to `grow` and `grow_uv`; whether it was trimmed.
static func _trim_card(arrays: Array, sheet: LeafTrimSheet, corners: PackedInt32Array, grow: PackedFloat32Array,
		grow_uv: PackedFloat32Array, moved: PackedByteArray) -> bool:
	if corners.size() != 4:
		return false
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var at: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var box := Rect2(uv[corners[0]], Vector2.ZERO)
	for c in corners:
		if moved[c] == 1:
			return false
		box = box.expand(uv[c])
	if box.size.x <= 0.0 or box.size.y <= 0.0:
		return false
	# each corner on a corner of the box
	var by_side := {}
	for c in corners:
		var s := Vector2i(_end(uv[c].x, box.position.x, box.end.x), _end(uv[c].y, box.position.y, box.end.y))
		if s.x < 0 or s.y < 0 or by_side.has(s):
			return false
		by_side[s] = c
	var cell := Vector2i(floori(box.get_center().x * sheet.grid), floori(box.get_center().y * sheet.grid))
	var local := sheet.rect_of(cell)
	if not local.has_area():
		return false
	var keep := Rect2((Vector2(cell) + local.position) / float(sheet.grid), local.size / float(sheet.grid))
	keep = keep.intersection(box)
	if not keep.has_area() or keep.get_area() > box.get_area() * KEEP_OVER:
		return false
	# the card's frame from its low-low corner along the box's x and y; it must be flat
	var o := at[by_side[SIDES[0]]]
	var ax := at[by_side[SIDES[1]]] - o
	var ay := at[by_side[SIDES[2]]] - o
	var far := at[by_side[SIDES[3]]] - o
	var face := ax.cross(ay)
	if face.length_squared() <= 0.0 or (far - ax - ay).length() > FLAT * far.length():
		return false
	var facing := _oct(face.normalized())
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var n4: Array[Vector3] = []
	for s in SIDES:
		n4.append(normals[by_side[s]])
	var colours := PackedColorArray()
	var c4: Array[Color] = []
	if arrays[Mesh.ARRAY_COLOR] != null:
		colours = arrays[Mesh.ARRAY_COLOR]
		for s in SIDES:
			c4.append(colours[by_side[s]])
	for s in SIDES:
		var c: int = by_side[s]
		var to := Vector2(keep.end.x if s.x == 1 else keep.position.x, keep.end.y if s.y == 1 else keep.position.y)
		var f := (to - box.position) / box.size # where on the card, 0 to 1 each way
		var p := o + ax * f.x + ay * f.y
		var d := at[c] - p
		grow[c * 4] = d.x
		grow[c * 4 + 1] = d.y
		grow[c * 4 + 2] = d.z
		grow_uv[c * 4] = uv[c].x - to.x
		grow_uv[c * 4 + 1] = uv[c].y - to.y
		grow_uv[c * 4 + 2] = facing.x
		grow_uv[c * 4 + 3] = facing.y
		at[c] = p
		uv[c] = to
		normals[c] = n4[0].lerp(n4[1], f.x).lerp(n4[2].lerp(n4[3], f.x), f.y).normalized()
		if not c4.is_empty():
			colours[c] = c4[0].lerp(c4[1], f.x).lerp(c4[2].lerp(c4[3], f.x), f.y)
		moved[c] = 1
	arrays[Mesh.ARRAY_VERTEX] = at
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_NORMAL] = normals
	if not colours.is_empty():
		arrays[Mesh.ARRAY_COLOR] = colours
	return true


## 0 when `x` is at `lo`, 1 at `hi`, -1 at neither.
static func _end(x: float, lo: float, hi: float) -> int:
	if absf(x - lo) <= CORNER:
		return 0
	if absf(x - hi) <= CORNER:
		return 1
	return -1


## Unit vector `n` folded onto an octahedron (two numbers, -1 to 1; look_foliage.gdshader unfolds it).
static func _oct(n: Vector3) -> Vector2:
	var p := Vector2(n.x, n.z) / (absf(n.x) + absf(n.y) + absf(n.z))
	if n.y < 0.0:
		p = Vector2((1.0 - absf(p.y)) * (1.0 if p.x >= 0.0 else -1.0), (1.0 - absf(p.x)) * (1.0 if p.y >= 0.0 else -1.0))
	return p
