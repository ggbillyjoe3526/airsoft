class_name GreyboxFaces
extends RefCounted
## The greybox's geometry as plain data (DP2): each block's faces in one order (`faces_of`), the ground beyond the walls,
## the faces cut into tiles for the baked light (`tile`, and `tile_count` without making them), and sloping ground's
## squares in their surfaces' colours (`add_terrain`, or cut into tiles that cull, `terrain_tiles`). MapLevel builds
## its meshes and ramp colliders from it; tools/bake_light.gd casts its rays at the same faces and bakes the same
## tiles, so their orders can't drift. Static functions only.

## A length this close under a whole number of tiles (m) takes that number, not one more.
const TILE_SLACK := 1e-4


## A level's faces cut into tiles for the baked light (`tile`): each block's faces in the greybox's order, a grid of
## vertices on each face (shared within the face), then the triangles as indices.
class Tiles:
	extends RefCounted
	var positions: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	## Each vertex's block, an index into MapData.blocks.
	var blocks: PackedInt32Array = PackedInt32Array()
	var indices: PackedInt32Array = PackedInt32Array()


## Block `b`'s faces, each a convex polygon given anticlockwise as seen from outside: a box's top, bottom, +z, -z, +x and
## -x; a ramp's bottom, tall end, slope and two sides. The greybox, the tiles and the bake all take them in this order.
static func faces_of(b: MapData.Block) -> Array[PackedVector3Array]:
	if b.rise != MapData.Rise.NONE:
		return _wedge_faces(b)
	return box_faces(b.center - b.size * 0.5, b.center + b.size * 0.5)


## The faces of the box from corner `lo` to `hi`, in faces_of's order (a railing's bars and rails, SR1, too).
static func box_faces(lo: Vector3, hi: Vector3) -> Array[PackedVector3Array]:
	var c := PackedVector3Array([
		Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z),
		Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z),
	])
	return [
		PackedVector3Array([c[7], c[6], c[5], c[4]]), # top
		PackedVector3Array([c[0], c[1], c[2], c[3]]), # bottom
		PackedVector3Array([c[3], c[2], c[6], c[7]]), # +z
		PackedVector3Array([c[1], c[0], c[4], c[5]]), # -z
		PackedVector3Array([c[2], c[1], c[5], c[6]]), # +x
		PackedVector3Array([c[0], c[3], c[7], c[4]]), # -x
	]


## A ramp's faces: its bottom, the tall end, the slope and the two sides.
static func _wedge_faces(b: MapData.Block) -> Array[PackedVector3Array]:
	var p := wedge_points(b, b.center)
	var tall := _tall_end(b.rise)
	var along_x := b.rise == MapData.Rise.POS_X or b.rise == MapData.Rise.NEG_X
	var a := p[tall[0]]
	var d := p[tall[1]]
	var low_a := p[_low_partner(tall[0], along_x)]
	var low_d := p[_low_partner(tall[1], along_x)]
	var top_a := p[4]
	var top_d := p[5]
	return [
		PackedVector3Array([p[0], p[1], p[2], p[3]]), # bottom
		PackedVector3Array([a, d, top_d, top_a]), # tall end
		PackedVector3Array([top_a, top_d, low_d, low_a]), # slope
		PackedVector3Array([a, top_a, low_a]), # side
		PackedVector3Array([d, low_d, top_d]), # side
	]


## The ground beyond the walls, one face up, just under `top` (m: a floor at 0, or sloping ground's lowest point).
static func ground_face(style: MapStyle, top: float = 0.0) -> PackedVector3Array:
	var e := style.ground_extent
	var y := top - style.ground_drop
	return PackedVector3Array([Vector3(-e, y, e), Vector3(e, y, e), Vector3(e, y, -e), Vector3(-e, y, -e)])


## The top of the ground beyond the walls on `m`: 0, or under sloping ground its lowest point (so the terrain's dips
## don't sink under it).
static func ground_top(m: MapData) -> float:
	return minf(0.0, m.terrain.height_range().x) if m.terrain != null else 0.0


## Appends sloping ground `t` to mesh arrays `arrays` (Mesh.ARRAY_MAX long, holding vertices, normals and colours, and
## indices or none for a plain list): each ground square its four corners in its surface's colour (`style`), lit as the
## ground slopes there (smooth across squares), and its two triangles split and wound as TerrainGrid's.
static func add_terrain(arrays: Array, t: TerrainGrid, style: MapStyle) -> void:
	_add_squares(arrays, t, _palette(style), t.ground_lattice(), lattice_normals(t),
			Rect2i(0, 0, t.ground_cols, t.ground_rows))


## Sloping ground `t` cut into meshes of whole squares at most `size` m a side (WL4), row by row from its (min_x, min_z)
## corner, so each can be culled on its own: every square exactly as `add_terrain` draws it (the same corners, normals,
## colours and split), so together they are the whole ground's very faces.
static func terrain_tiles(t: TerrainGrid, style: MapStyle, size: float) -> Array[ArrayMesh]:
	var out: Array[ArrayMesh] = []
	var per := maxi(1, floori(size / t.ground_cell + TILE_SLACK))
	var palette := _palette(style)
	var lattice := t.ground_lattice()
	var normals := lattice_normals(t)
	for j0 in range(0, t.ground_rows, per):
		for i0 in range(0, t.ground_cols, per):
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array()
			arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array()
			arrays[Mesh.ARRAY_COLOR] = PackedColorArray()
			arrays[Mesh.ARRAY_INDEX] = PackedInt32Array()
			_add_squares(arrays, t, palette, lattice, normals,
					Rect2i(i0, j0, mini(per, t.ground_cols - i0), mini(per, t.ground_rows - j0)))
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			out.append(mesh)
	return out


## Each ground lattice corner's normal, from the heights a square either side of it (the edge's own past the edge).
static func lattice_normals(t: TerrainGrid) -> PackedVector3Array:
	var lattice := t.ground_lattice()
	var vx := t.ground_cols + 1
	var vz := t.ground_rows + 1
	var gc := t.ground_cell
	var out := PackedVector3Array()
	out.resize(lattice.size())
	for j in vz:
		var up := (j - 1 if j > 0 else j) * vx
		var down := (j + 1 if j + 1 < vz else j) * vx
		for i in vx:
			var west := i - 1 if i > 0 else i
			var east := i + 1 if i + 1 < vx else i
			out[j * vx + i] = Vector3(lattice[j * vx + west] - lattice[j * vx + east], 2.0 * gc,
					lattice[up + i] - lattice[down + i]).normalized()
	return out


static func _palette(style: MapStyle) -> PackedColorArray:
	var palette := PackedColorArray()
	for surface in RayHit.Surface.size():
		palette.append(style.terrain_colour(surface))
	return palette


## The ground squares in `squares` (columns and rows of them) appended to `arrays`.
static func _add_squares(arrays: Array, t: TerrainGrid, palette: PackedColorArray, lattice: PackedFloat64Array,
		corner_normals: PackedVector3Array, squares: Rect2i) -> void:
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var base := positions.size()
	var indices := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null:
		indices = arrays[Mesh.ARRAY_INDEX]
	else:
		indices.resize(base)
		for i in base:
			indices[i] = i
	var vx := t.ground_cols + 1
	var gc := t.ground_cell
	var count := squares.size.x * squares.size.y
	positions.resize(base + count * 4)
	normals.resize(base + count * 4)
	colours.resize(base + count * 4)
	var first := indices.size()
	indices.resize(first + count * 6)
	var q := 0
	for j in range(squares.position.y, squares.end.y):
		var z0 := t.min_z + j * gc
		var z1 := z0 + gc
		for i in range(squares.position.x, squares.end.x):
			var colour := palette[t.surfaces[j * t.ground_cols + i]]
			var x0 := t.min_x + i * gc
			var x1 := x0 + gc
			var k := j * vx + i
			var v := base + q * 4
			# a (x0, z0), b (x1, z0), c (x0, z1), d (x1, z1).
			positions[v] = Vector3(x0, lattice[k], z0)
			positions[v + 1] = Vector3(x1, lattice[k + 1], z0)
			positions[v + 2] = Vector3(x0, lattice[k + vx], z1)
			positions[v + 3] = Vector3(x1, lattice[k + vx + 1], z1)
			normals[v] = corner_normals[k]
			normals[v + 1] = corner_normals[k + 1]
			normals[v + 2] = corner_normals[k + vx]
			normals[v + 3] = corner_normals[k + vx + 1]
			colours[v] = colour
			colours[v + 1] = colour
			colours[v + 2] = colour
			colours[v + 3] = colour
			# a b d and a d c, as TerrainGrid._quad_indices.
			var n := first + q * 6
			indices[n] = v
			indices[n + 1] = v + 1
			indices[n + 2] = v + 3
			indices[n + 3] = v
			indices[n + 4] = v + 3
			indices[n + 5] = v + 2
			q += 1
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_INDEX] = indices


## A face's outward normal, from its winding.
static func face_normal(f: PackedVector3Array) -> Vector3:
	return (f[1] - f[0]).cross(f[2] - f[0]).normalized()


## `m`'s block faces (`faces_of`) cut into tiles no larger than `cell` m a side, each face a grid of its own vertices;
## a face lying on the ground (no higher than `ground_y`) facing down, which no one sees, stays one tile.
static func tile(m: MapData, cell: float, ground_y: float) -> Tiles:
	var t := Tiles.new()
	for i in m.blocks.size():
		for f in faces_of(m.blocks[i]):
			var n := face_normal(f)
			if f.size() == 4:
				_tile_quad(t, f, n, i, INF if _hidden(f, n, ground_y) else cell)
			else:
				_tile_triangle(t, f, n, i, cell)
	return t


## How many vertices `tile` makes, worked out without making them (so a bake is checked before a mesh is built).
static func tile_count(m: MapData, cell: float, ground_y: float) -> int:
	var count := 0
	for b in m.blocks:
		for f in faces_of(b):
			if f.size() == 4:
				var c := INF if _hidden(f, face_normal(f), ground_y) else cell
				count += (_cuts((f[1] - f[0]).length(), c) + 1) * (_cuts((f[3] - f[0]).length(), c) + 1)
			else:
				var k := _cuts(maxf((f[1] - f[0]).length(), (f[2] - f[0]).length()), cell)
				count += (k + 1) * (k + 2) / 2
	return count


## A face lying on the ground facing down, which no one sees: one tile.
static func _hidden(f: PackedVector3Array, normal: Vector3, ground_y: float) -> bool:
	return normal.y < -0.5 and f[0].y <= ground_y


## A parallelogram face (a, b, c, d) as a grid of cells, each two triangles wound as MapLevel winds the whole face.
static func _tile_quad(t: Tiles, f: PackedVector3Array, n: Vector3, block: int, cell: float) -> void:
	var a := f[0]
	var u := f[1] - a
	var v := f[3] - a
	var nu := _cuts(u.length(), cell)
	var nv := _cuts(v.length(), cell)
	var base := t.positions.size()
	for j in nv + 1:
		for i in nu + 1:
			t.positions.append(a + u * (float(i) / nu) + v * (float(j) / nv))
			t.normals.append(n)
			t.blocks.append(block)
	var row := nu + 1
	for j in nv:
		for i in nu:
			var q00 := base + j * row + i
			var q01 := q00 + row
			t.indices.append(q00)
			t.indices.append(q01 + 1)
			t.indices.append(q00 + 1)
			t.indices.append(q00)
			t.indices.append(q01)
			t.indices.append(q01 + 1)


## A triangle face (a, b, c) as rows of small triangles, k to a side, wound as the whole face.
static func _tile_triangle(t: Tiles, f: PackedVector3Array, n: Vector3, block: int, cell: float) -> void:
	var a := f[0]
	var u := f[1] - a
	var v := f[2] - a
	var k := _cuts(maxf(u.length(), v.length()), cell)
	var base := t.positions.size()
	var row_start := PackedInt32Array()
	for j in k + 1:
		row_start.append(t.positions.size())
		for i in k + 1 - j:
			t.positions.append(a + u * (float(i) / k) + v * (float(j) / k))
			t.normals.append(n)
			t.blocks.append(block)
	for j in k:
		for i in k - j:
			var p := row_start[j] + i
			var up := row_start[j + 1] + i
			t.indices.append(p)
			t.indices.append(up)
			t.indices.append(p + 1)
			if i < k - j - 1:
				t.indices.append(p + 1)
				t.indices.append(up)
				t.indices.append(up + 1)
	assert(t.positions.size() - base == (k + 1) * (k + 2) / 2)


## How many tiles a side `length` m long takes, none larger than `cell`.
static func _cuts(length: float, cell: float) -> int:
	return 1 if is_inf(cell) else maxi(1, ceili(length / cell - TILE_SLACK))


## The tall end's bottom corners, as indices into a wedge's bottom corners (lo-x lo-z, hi-x lo-z, hi-x hi-z, lo-x hi-z),
## ordered so the end's face winds outwards.
static func _tall_end(rise: MapData.Rise) -> PackedInt32Array:
	match rise:
		MapData.Rise.POS_X:
			return PackedInt32Array([2, 1])
		MapData.Rise.NEG_X:
			return PackedInt32Array([0, 3])
		MapData.Rise.POS_Z:
			return PackedInt32Array([3, 2])
	return PackedInt32Array([1, 0])


## The bottom corner at the low end across from bottom corner `i`, along x or along z.
static func _low_partner(i: int, along_x: bool) -> int:
	return [1, 0, 3, 2][i] if along_x else [3, 2, 1, 0][i]


## A ramp's corners round `origin` (its centre for the mesh, zero for its collider, which sits at the centre): the four
## bottom corners, then the two top corners above the tall end.
static func wedge_points(b: MapData.Block, origin: Vector3) -> PackedVector3Array:
	var h := b.size * 0.5
	var pts := PackedVector3Array([
		origin + Vector3(-h.x, -h.y, -h.z), origin + Vector3(h.x, -h.y, -h.z), origin + Vector3(h.x, -h.y, h.z),
		origin + Vector3(-h.x, -h.y, h.z),
	])
	var tall := _tall_end(b.rise)
	pts.append(pts[tall[0]] + Vector3(0.0, b.size.y, 0.0))
	pts.append(pts[tall[1]] + Vector3(0.0, b.size.y, 0.0))
	return pts
