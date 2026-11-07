class_name TerrainGrid
extends RefCounted
## Ground that rises and falls (the browser game's map/terrain.ts, M33c, and map/groundSurfaces.ts, M33i): a heightfield
## over a map's footprint and what its ground is made of. Heights sit on a regular grid of vertices `cell` m apart; each
## cell is two triangles split along the diagonal from its (x0, z0) corner to its (x1, z1) corner, and everything that
## reads the ground (the mesh, Jolt's trimesh, the nav grid, `height_at`) uses those triangles, so what you see is what
## you stand on and what stops a BB. The ground (`paint`) gives each `ground_cell` square a RayHit.Surface: the base,
## the under-trees surface where the trees close overhead, then each patch over that. Pure data: no nodes, no physics.

## The terrain's corner (m): vertex (0, 0) is at (min_x, min_z).
var min_x: float = 0.0
var min_z: float = 0.0
## Distance between neighbouring vertices (m), and the cells along x and z: (cols + 1) x (rows + 1) vertices.
var cell: float = 1.0
var cols: int = 0
var rows: int = 0
## Vertex heights (m), row by row along z: vertex (i, j) is heights[j * (cols + 1) + i].
var heights: PackedFloat64Array = PackedFloat64Array()
## The ground's squares: `per` to a cell's side, each `ground_cell` m, ground_cols x ground_rows over the terrain, and
## each square's surface (a RayHit.Surface), row by row along z. Earth everywhere until `paint`.
var per: int = 1
var ground_cell: float = 1.0
var ground_cols: int = 0
var ground_rows: int = 0
var surfaces: PackedByteArray = PackedByteArray()


## A terrain over [min_x, min_x + cols x cell] x [min_z, min_z + rows x cell] from `height` (x, z) -> m.
static func create(x0: float, z0: float, size: float, nx: int, nz: int, height: Callable) -> TerrainGrid:
	var t := TerrainGrid.new()
	t.min_x = x0
	t.min_z = z0
	t.cell = size
	t.cols = nx
	t.rows = nz
	t.heights.resize((nx + 1) * (nz + 1))
	for j in nz + 1:
		for i in nx + 1:
			t.heights[j * (nx + 1) + i] = float(height.call(x0 + i * size, z0 + j * size))
	t._plain_ground(1)
	return t


## The terrain in a map file's `terrain` ({minX, minZ, cell, cols, rows, heights}), or null with the reason in
## `problems` when it is malformed.
static func read(raw: Variant, problems: Array[String]) -> TerrainGrid:
	if not raw is Dictionary:
		problems.append("terrain is not an object")
		return null
	var d: Dictionary = raw
	for key: String in ["minX", "minZ", "cell", "cols", "rows"]:
		if not (d.get(key) is float or d.get(key) is int):
			problems.append("terrain's %s is not a number" % key)
			return null
	for key: String in ["cols", "rows"]:
		if float(d[key]) != floorf(float(d[key])):
			problems.append("terrain's %s is not a whole number" % key)
			return null
	var t := TerrainGrid.new()
	t.min_x = float(d["minX"])
	t.min_z = float(d["minZ"])
	t.cell = float(d["cell"])
	t.cols = int(d["cols"])
	t.rows = int(d["rows"])
	if not (t.cell > 0.0) or t.cols < 1 or t.rows < 1:
		problems.append("terrain has no cells (cell %s m, %d x %d)" % [d["cell"], t.cols, t.rows])
		return null
	var list: Variant = d.get("heights")
	var count := (t.cols + 1) * (t.rows + 1)
	if not list is Array or (list as Array).size() != count:
		problems.append("terrain's heights are not a list of its %d vertices" % count)
		return null
	t.heights.resize(count)
	for k in count:
		var h: Variant = (list as Array)[k]
		if not (h is float or h is int):
			problems.append("terrain height %d is not a number" % k)
			return null
		t.heights[k] = float(h)
	t._plain_ground(1)
	return t


func max_x() -> float:
	return min_x + cols * cell


func max_z() -> float:
	return min_z + rows * cell


## The height of vertex (i, j).
func vertex_height(i: int, j: int) -> float:
	return heights[j * (cols + 1) + i]


## The ground's height at (x, z), on its cell's triangles; NAN outside the terrain (its edges count as inside).
## Allocates nothing.
func height_at(x: float, z: float) -> float:
	var fx := (x - min_x) / cell
	var fz := (z - min_z) / cell
	if not (fx >= 0.0 and fz >= 0.0 and fx <= cols and fz <= rows):
		return NAN
	var i := mini(cols - 1, floori(fx))
	var j := mini(rows - 1, floori(fz))
	var u := fx - i
	var v := fz - j
	var k := j * (cols + 1) + i
	var h00 := heights[k]
	var h11 := heights[k + cols + 2]
	# Split along (0, 0) to (1, 1): the triangle with (1, 0) where u >= v, the one with (0, 1) where v > u.
	if u >= v:
		var h10 := heights[k + 1]
		return h00 + u * (h10 - h00) + v * (h11 - h10)
	var h01 := heights[k + cols + 1]
	return h00 + v * (h01 - h00) + u * (h11 - h01)


## The height at (x, z), or past the terrain's edge the edge's.
func height_clamped(x: float, z: float) -> float:
	return height_at(clampf(x, min_x, max_x()), clampf(z, min_z, max_z()))


## The lowest and highest vertex heights (x, y).
func height_range() -> Vector2:
	var lo := INF
	var hi := -INF
	for h in heights:
		lo = minf(lo, h)
		hi = maxf(hi, h)
	return Vector2(lo, hi)


## The steepest slope (rise over run) of any of the terrain's triangles.
func steepest_slope() -> float:
	var worst := 0.0
	for j in rows:
		for i in cols:
			var h00 := vertex_height(i, j)
			var h10 := vertex_height(i + 1, j)
			var h01 := vertex_height(i, j + 1)
			var h11 := vertex_height(i + 1, j + 1)
			worst = maxf(worst, Vector2(h10 - h00, h11 - h10).length() / cell)
			worst = maxf(worst, Vector2(h11 - h01, h01 - h00).length() / cell)
	return worst


## The terrain as one triangle mesh (two per cell, the split height_at uses), wound clockwise seen from above so the
## faces point up in Godot: the vertex positions and the triangles' indices into them.
func mesh_positions() -> PackedVector3Array:
	var out := PackedVector3Array()
	for j in rows + 1:
		for i in cols + 1:
			out.append(Vector3(min_x + i * cell, vertex_height(i, j), min_z + j * cell))
	return out


func mesh_indices() -> PackedInt32Array:
	var out := PackedInt32Array()
	var vx := cols + 1
	for j in rows:
		for i in cols:
			var a := j * vx + i
			_quad_indices(out, a, a + 1, a + vx, a + vx + 1)
	return out


## The two triangles of a square with corners a (x0, z0), b (x1, z0), c (x0, z1) and d (x1, z1), split along a to d and
## wound clockwise seen from above (Godot's front faces).
static func _quad_indices(out: PackedInt32Array, a: int, b: int, c: int, d: int) -> void:
	out.append(a)
	out.append(b)
	out.append(d)
	out.append(a)
	out.append(d)
	out.append(c)


## The heights at the ground squares' corners, (ground_cols + 1) x (ground_rows + 1), row by row along z.
func ground_lattice() -> PackedFloat64Array:
	var out := PackedFloat64Array()
	out.resize((ground_cols + 1) * (ground_rows + 1))
	fill_lattice(out, 0, ground_rows + 1)
	return out


## Rows `from_row` to `to_row` (not included) of ground_lattice() written into `out`, already sized as it is: a
## loading screen's slice of it (MapLevel).
func fill_lattice(out: PackedFloat64Array, from_row: int, to_row: int) -> void:
	for j in range(from_row, mini(to_row, ground_rows + 1)):
		for i in ground_cols + 1:
			out[j * (ground_cols + 1) + i] = height_at(min_x + i * ground_cell, min_z + j * ground_cell)


## The ground's triangles on each surface (indexed by RayHit.Surface, `count` of them), three vertices a triangle:
## each ground square two, split as its cell is (a square lies inside one of its cell's triangles or across the
## diagonal, so these are the very triangles height_at reads) and wound as `mesh_indices`. Jolt's trimesh, a body per
## surface. `given` is ground_lattice() when it is already worked out. In slices: `faces_begin`, `fill_faces` over
## every row, then `faces_cut`.
func surface_faces(count: int, given: PackedFloat64Array = PackedFloat64Array()) -> Array[PackedVector3Array]:
	var faces := faces_begin(count)
	fill_faces(faces, given if not given.is_empty() else ground_lattice(), 0, ground_rows)
	return faces_cut(faces)


## surface_faces under way: each surface's triangles written into one array at its own offset (counted first), then
## cut apart.
class Faces:
	extends RefCounted
	var count: int = 0
	var start: PackedInt32Array = PackedInt32Array()
	var fill: PackedInt32Array = PackedInt32Array()
	var all: PackedVector3Array = PackedVector3Array()


## surface_faces' start: the squares counted on each of `count` surfaces.
func faces_begin(count: int) -> Faces:
	var f := Faces.new()
	f.count = count
	f.start.resize(count + 1)
	for s in surfaces:
		if s < count:
			f.start[s + 1] += 6
	for s in count:
		f.start[s + 1] += f.start[s]
	f.all.resize(f.start[count])
	f.fill = f.start.slice(0, count)
	return f


## Ground rows `from_row` to `to_row` (not included) of squares written into `f`, their corners from `lattice`
## (ground_lattice()).
func fill_faces(f: Faces, lattice: PackedFloat64Array, from_row: int, to_row: int) -> void:
	var vx := ground_cols + 1
	for j in range(from_row, mini(to_row, ground_rows)):
		var z0 := min_z + j * ground_cell
		var z1 := z0 + ground_cell
		for i in ground_cols:
			var s := surfaces[j * ground_cols + i]
			if s >= f.count:
				continue
			var x0 := min_x + i * ground_cell
			var x1 := x0 + ground_cell
			var k := j * vx + i
			var a := Vector3(x0, lattice[k], z0)
			var d := Vector3(x1, lattice[k + vx + 1], z1)
			var at := f.fill[s]
			f.all[at] = a
			f.all[at + 1] = Vector3(x1, lattice[k + 1], z0)
			f.all[at + 2] = d
			f.all[at + 3] = a
			f.all[at + 4] = d
			f.all[at + 5] = Vector3(x0, lattice[k + vx], z1)
			f.fill[s] = at + 6


## surface_faces' end: `f`'s triangles, a surface's array each.
func faces_cut(f: Faces) -> Array[PackedVector3Array]:
	var out: Array[PackedVector3Array] = []
	for s in f.count:
		out.append(f.all.slice(f.start[s], f.start[s + 1]))
	return out


## The surface (RayHit.Surface) of the ground at (x, z); past the terrain's edge, the edge's. Allocates nothing.
func surface_at(x: float, z: float) -> int:
	var i := clampi(floori((x - min_x) / ground_cell), 0, ground_cols - 1)
	var j := clampi(floori((z - min_z) / ground_cell), 0, ground_rows - 1)
	return surfaces[j * ground_cols + i]


## Paints the ground from a map file's `ground` ({base, underTrees, patches}: names in `names`): `base` everywhere, then
## `underTrees` where at least `canopy_trees` of `trees` (trunk centres, x and z) stand within `canopy_radius` m of the
## middle of the `canopy_cell` square holding a ground square's middle (night sight's canopy rule, on squares from
## `canopy_origin`), then each patch in order (a later one wins): its box, or within half its width of its path. Squares
## are `square` m, or a whole cell where that doesn't divide one. What can't be read is left out with a warning.
func paint(raw: Variant, names: Dictionary[String, RayHit.Surface], trees: PackedVector2Array,
		canopy_origin: Vector2, style: MapStyle, warnings: Array[String]) -> void:
	var n := roundi(cell / style.ground_cell)
	_plain_ground(n if n >= 1 and is_equal_approx(n * style.ground_cell, cell) else 1)
	if raw == null:
		return
	if not raw is Dictionary:
		warnings.append("ground is not an object; the terrain is earth")
		return
	var g: Dictionary = raw
	var base := _surface_named(g.get("base"), names, "ground's base", warnings)
	if base != RayHit.Surface.NONE:
		surfaces.fill(base)
	if g.has("underTrees"):
		var under := _surface_named(g.get("underTrees"), names, "ground's underTrees", warnings)
		if under != RayHit.Surface.NONE:
			_paint_canopy(under, trees, canopy_origin, style)
	var patches: Variant = g.get("patches", [])
	if not patches is Array:
		warnings.append("ground's patches are not a list")
		return
	for p: Variant in patches:
		_paint_patch(p, names, warnings)


## Every square earth, `squares` to a cell's side.
func _plain_ground(squares: int) -> void:
	per = squares
	ground_cell = cell / squares
	ground_cols = cols * squares
	ground_rows = rows * squares
	surfaces.resize(ground_cols * ground_rows)
	surfaces.fill(RayHit.Surface.EARTH)


func _paint_canopy(under: RayHit.Surface, trees: PackedVector2Array, origin: Vector2, style: MapStyle) -> void:
	var size := style.canopy_cell
	var reach := style.canopy_radius
	# The canopy squares over the ground, each counting the trunks within reach of its middle.
	var c0 := floori((min_x - origin.x) / size)
	var r0 := floori((min_z - origin.y) / size)
	var nc := floori((max_x() - origin.x) / size) - c0 + 1
	var nr := floori((max_z() - origin.y) / size) - r0 + 1
	var count := PackedInt32Array()
	count.resize(nc * nr)
	for t in trees:
		for r in range(maxi(0, floori((t.y - reach - origin.y) / size) - r0), mini(nr, ceili((t.y + reach - origin.y)
				/ size) - r0 + 1)):
			var cz := origin.y + (r + r0 + 0.5) * size
			for c in range(maxi(0, floori((t.x - reach - origin.x) / size) - c0), mini(nc, ceili((t.x + reach
					- origin.x) / size) - c0 + 1)):
				var cx := origin.x + (c + c0 + 0.5) * size
				if (cx - t.x) * (cx - t.x) + (cz - t.y) * (cz - t.y) <= reach * reach:
					count[r * nc + c] += 1
	for j in ground_rows:
		var z := min_z + (j + 0.5) * ground_cell
		var r := floori((z - origin.y) / size) - r0
		for i in ground_cols:
			var x := min_x + (i + 0.5) * ground_cell
			var c := floori((x - origin.x) / size) - c0
			# Off the canopy squares (below the blocks' corner), no trees close overhead.
			if x >= origin.x and z >= origin.y and count[r * nc + c] >= style.canopy_trees:
				surfaces[j * ground_cols + i] = under


func _paint_patch(raw: Variant, names: Dictionary[String, RayHit.Surface], warnings: Array[String]) -> void:
	if not raw is Dictionary:
		warnings.append("a ground patch is not an object")
		return
	var p: Dictionary = raw
	var s := _surface_named(p.get("surface"), names, "a ground patch's surface", warnings)
	if s == RayHit.Surface.NONE:
		return
	var box: Variant = p.get("box")
	if box != null:
		if not (box is Array and (box as Array).size() == 4 and _all_numbers(box as Array)):
			warnings.append("a ground patch's box is not four numbers")
			return
		var b: Array = box
		_paint_box(s, minf(float(b[0]), float(b[1])), maxf(float(b[0]), float(b[1])), minf(float(b[2]), float(b[3])),
				maxf(float(b[2]), float(b[3])))
	var path: Variant = p.get("path")
	if path == null:
		return
	if not path is Array or (path as Array).is_empty():
		warnings.append("a ground patch's path is not a list of points")
		return
	var width: Variant = p.get("width", 0.0)
	if not (width is float or width is int):
		warnings.append("a ground patch's width is not a number")
		return
	var points := PackedVector2Array()
	for q: Variant in path:
		var x: Variant = (q as Dictionary).get("x") if q is Dictionary else null
		var z: Variant = (q as Dictionary).get("z") if q is Dictionary else null
		if not ((x is float or x is int) and (z is float or z is int)):
			warnings.append("a ground patch's path point is not an x and z")
			return
		points.append(Vector2(float(x), float(z)))
	var half := float(width) * 0.5
	if points.size() == 1:
		points.append(points[0])
	for k in range(1, points.size()):
		_paint_segment(s, points[k - 1], points[k], half)


## True if every entry of `list` is a number.
static func _all_numbers(list: Array) -> bool:
	for v: Variant in list:
		if not (v is float or v is int):
			return false
	return true


## Squares whose middle lies in the box [x0, x1] x [z0, z1].
func _paint_box(s: int, x0: float, x1: float, z0: float, z1: float) -> void:
	for j in range(maxi(0, ceili((z0 - min_z) / ground_cell - 0.5)), mini(ground_rows - 1, floori((z1 - min_z)
			/ ground_cell - 0.5)) + 1):
		for i in range(maxi(0, ceili((x0 - min_x) / ground_cell - 0.5)), mini(ground_cols - 1, floori((x1 - min_x)
				/ ground_cell - 0.5)) + 1):
			surfaces[j * ground_cols + i] = s


## Squares whose middle lies within `half` of the segment a to b.
func _paint_segment(s: int, a: Vector2, b: Vector2, half: float) -> void:
	var lo := a.min(b) - Vector2(half, half)
	var hi := a.max(b) + Vector2(half, half)
	for j in range(maxi(0, floori((lo.y - min_z) / ground_cell)), mini(ground_rows - 1, floori((hi.y - min_z)
			/ ground_cell)) + 1):
		var z := min_z + (j + 0.5) * ground_cell
		for i in range(maxi(0, floori((lo.x - min_x) / ground_cell)), mini(ground_cols - 1, floori((hi.x - min_x)
				/ ground_cell)) + 1):
			var x := min_x + (i + 0.5) * ground_cell
			if _segment_distance2(x, z, a, b) <= half * half:
				surfaces[j * ground_cols + i] = s


## The squared distance from (x, z) to the segment a to b.
static func _segment_distance2(x: float, z: float, a: Vector2, b: Vector2) -> float:
	var dx := b.x - a.x
	var dz := b.y - a.y
	var len2 := dx * dx + dz * dz
	var t := clampf(((x - a.x) * dx + (z - a.y) * dz) / len2, 0.0, 1.0) if len2 > 0.0 else 0.0
	var ex := x - a.x - t * dx
	var ez := z - a.y - t * dz
	return ex * ex + ez * ez


static func _surface_named(raw: Variant, names: Dictionary[String, RayHit.Surface], what: String,
		warnings: Array[String]) -> RayHit.Surface:
	var s: RayHit.Surface = names.get(str(raw), RayHit.Surface.NONE)
	if s == RayHit.Surface.NONE:
		warnings.append("%s %s is not one of %s; left out" % [what, raw, names.keys()])
	return s
