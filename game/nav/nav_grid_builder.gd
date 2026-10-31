class_name NavGridBuilder
## Fills a NavGrid from a map's blocks and sloping ground (the browser game's buildNavGrid). Each cell gets a node per
## floor over it (the terrain's ground at its centre, with nothing under it, and each floor or ramp top), each node is
## blocked within the clearance of a block standing in the way on its floor or of a drop off its floor, and the walkable
## nodes are linked for the route search by the step rules: the eight neighbouring cells, floors at most max_step apart,
## no squeezing diagonally past a blocked node or a drop.

## The eight steps to a neighbouring cell (x, z): the four straight ones, then the diagonals. Step d's way back is
## OPPOSITE[d]; a diagonal step d passes the straight steps SIDE_A[d] and SIDE_B[d].
const DI: Array[int] = [1, -1, 0, 0, 1, 1, -1, -1]
const DJ: Array[int] = [0, 0, 1, -1, 1, -1, 1, -1]
const OPPOSITE: Array[int] = [1, 0, 3, 2, 7, 6, 5, 4]
const SIDE_A: Array[int] = [0, 1, 2, 3, 0, 0, 1, 1]
const SIDE_B: Array[int] = [0, 1, 2, 3, 2, 3, 2, 3]
## The steps whose links the build makes (the other four are their ways back).
const FORWARD: Array[int] = [0, 2, 4, 6]
const DIRECTIONS := 8
const SQRT_2 := 1.4142135623730951
## The furthest open distance a cell records (cells; NavGrid.open is bytes).
const OPEN_MAX := 255


## Fills `g` (a new grid) from `map`; false, with the grid left empty, when the map has no floor, ramp or terrain to
## stand on.
static func fill(g: NavGrid, map: MapData, cfg: NavConfig, body: BodyConfig) -> bool:
	if not _frame(g, map, cfg):
		return false
	_floors(g, map, body)
	var r := cfg.clearance(body)
	_stamp_blocks(g, map, r, body)
	_stamp_low(g, map, r, body)
	_stamp_drops(g, r, body.height * 0.5)
	_stamp_outer_edge(g, r)
	_link(g, 1.0 / maxf(cfg.search_greed, 1.0))
	_open(g)
	return true


static func is_surface(b: MapData.Block) -> bool:
	return b.kind == &"floor" or b.kind == &"ramp"


## The height of surface block `b`'s top at (x, z), or NAN outside its footprint.
static func surface_height_at(b: MapData.Block, x: float, z: float) -> float:
	var h := b.size * 0.5
	if absf(x - b.center.x) > h.x or absf(z - b.center.z) > h.z:
		return NAN
	if b.kind == &"ramp" and b.rise != MapData.Rise.NONE:
		return MapData.ramp_top(b, x, z)
	return b.center.y + h.y


## The grid's bounds (the surfaces' footprints and the terrain's) and cell counts.
static func _frame(g: NavGrid, map: MapData, cfg: NavConfig) -> bool:
	# Plain floats, not a Vector2: its components are single precision.
	var t := map.terrain
	var lo_x := t.min_x if t != null else INF
	var lo_z := t.min_z if t != null else INF
	var hi_x := t.max_x() if t != null else -INF
	var hi_z := t.max_z() if t != null else -INF
	for b in map.blocks:
		if not is_surface(b):
			continue
		lo_x = minf(lo_x, b.center.x - b.size.x * 0.5)
		hi_x = maxf(hi_x, b.center.x + b.size.x * 0.5)
		lo_z = minf(lo_z, b.center.z - b.size.z * 0.5)
		hi_z = maxf(hi_z, b.center.z + b.size.z * 0.5)
	if not is_finite(lo_x):
		return false
	g.cell = cfg.cell
	g.min_x = lo_x
	g.min_z = lo_z
	g.max_x = hi_x
	g.max_z = hi_z
	g.cols = ceili((hi_x - lo_x) / cfg.cell)
	g.rows = ceili((hi_z - lo_z) / cfg.cell)
	return true


## The cells (i0, j0, i1, j1) whose centres lie within block `b`'s footprint grown by `grow`.
static func _cells_under(g: NavGrid, b: MapData.Block, grow: float) -> Vector4i:
	var hx := b.size.x * 0.5 + grow
	var hz := b.size.z * 0.5 + grow
	return Vector4i(
		maxi(0, ceili((b.center.x - hx - g.min_x) / g.cell - 0.5)),
		maxi(0, ceili((b.center.z - hz - g.min_z) / g.cell - 0.5)),
		mini(g.cols - 1, floori((b.center.x + hx - g.min_x) / g.cell - 0.5)),
		mini(g.rows - 1, floori((b.center.z + hz - g.min_z) / g.cell - 0.5)))


## Every cell's floors: each surface over its centre (the terrain's ground first, with nothing under it) with headroom
## above it (no other surface's solid within a crouched body's height over it, CT1), lowest first; of two floors closer
## than a crouched body's height, the higher.
static func _floors(g: NavGrid, map: MapData, body: BodyConfig) -> void:
	var n := g.cols * g.rows
	# The surfaces over each cell's centre as (height there, the bottom of the solid under it), packed per cell.
	var surf_start := PackedInt32Array()
	surf_start.resize(n + 1)
	var surf_y := PackedFloat64Array()
	var surf_bottom := PackedFloat64Array()
	var surfaces: Array[MapData.Block] = []
	for b in map.blocks:
		if is_surface(b):
			surfaces.append(b)
	var ground := _ground(g, map.terrain)
	for pass_fill in 2:
		var fill := PackedInt32Array()
		if pass_fill == 1:
			for c in n:
				surf_start[c + 1] += surf_start[c]
			fill = surf_start.slice(0, n)
			surf_y.resize(surf_start[n])
			surf_bottom.resize(surf_start[n])
		for c in ground.size():
			if is_nan(ground[c]):
				continue
			if pass_fill == 0:
				surf_start[c + 1] += 1
			else:
				surf_y[fill[c]] = ground[c]
				surf_bottom[fill[c]] = -INF
				fill[c] += 1
		for b in surfaces:
			var box := _cells_under(g, b, 0.0)
			var bottom := b.center.y - b.size.y * 0.5
			var flat := b.kind == &"floor" or b.rise == MapData.Rise.NONE
			var top := b.center.y + b.size.y * 0.5
			for j in range(box.y, box.w + 1):
				var z := g.cell_z(j)
				for i in range(box.x, box.z + 1):
					# A floor's top is level: only a ramp's needs working out.
					var y := top if flat else surface_height_at(b, g.cell_x(i), z)
					if is_nan(y):
						continue
					var c := j * g.cols + i
					if pass_fill == 0:
						surf_start[c + 1] += 1
					else:
						surf_y[fill[c]] = y
						surf_bottom[fill[c]] = bottom
						fill[c] += 1
	var total := surf_start[n]
	var cell_start := PackedInt32Array()
	cell_start.resize(n + 1)
	var floor_y := PackedFloat32Array()
	floor_y.resize(total)
	var node_cell := PackedInt32Array()
	node_cell.resize(total)
	var kept := PackedFloat64Array()
	var count := 0
	var layers := 0
	for c in n:
		cell_start[c] = count
		var s0 := surf_start[c]
		var s1 := surf_start[c + 1]
		if s1 - s0 == 1:
			floor_y[count] = surf_y[s0]
			node_cell[count] = c
			count += 1
			layers = maxi(layers, 1)
			continue
		if s0 == s1:
			continue
		kept.clear()
		for k in range(s0, s1):
			var f := surf_y[k]
			var free := true
			for o in range(s0, s1):
				if o != k and surf_bottom[o] < f + body.crouch_height and surf_y[o] > f + body.max_step:
					free = false
					break
			if free:
				kept.append(f)
		kept.sort()
		var first := count
		for k in kept.size():
			if k + 1 < kept.size() and kept[k + 1] - kept[k] < body.crouch_height:
				continue
			floor_y[count] = kept[k]
			node_cell[count] = c
			count += 1
		layers = maxi(layers, count - first)
	cell_start[n] = count
	floor_y.resize(count)
	node_cell.resize(count)
	g.cell_start = cell_start
	g.floor_y = floor_y
	g.node_cell = node_cell
	g.layers = layers
	g.walkable = PackedByteArray()
	g.walkable.resize(count)
	g.walkable.fill(1)
	g.low = PackedByteArray()
	g.low.resize(count)


## The terrain's height at each cell's centre (NAN off it), row by row; empty without terrain.
static func _ground(g: NavGrid, t: TerrainGrid) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	if t == null:
		return out
	out.resize(g.cols * g.rows)
	for j in g.rows:
		var z := g.cell_z(j)
		for i in g.cols:
			out[j * g.cols + i] = t.height_at(g.cell_x(i), z)
	return out


## Blocks every node a block stands in the way on, grown by the clearance `r`: one whose floor it stands on or above
## (higher than a step) without passing over a crouched body's head.
static func _stamp_blocks(g: NavGrid, map: MapData, r: float, body: BodyConfig) -> void:
	for b in map.blocks:
		if is_surface(b):
			continue
		var top := b.center.y + b.size.y * 0.5
		var bottom := b.center.y - b.size.y * 0.5
		var box := _cells_under(g, b, r)
		for j in range(box.y, box.w + 1):
			for i in range(box.x, box.z + 1):
				var c := j * g.cols + i
				for k in range(g.cell_start[c], g.cell_start[c + 1]):
					var f := g.floor_y[k]
					if bottom < f + body.crouch_height and top > f + body.max_step:
						g.walkable[k] = 0


## Marks low every node something passes over lower than a standing body but not a crouched one (a block or a floor
## over it, CT1), grown by the clearance `r`: only a crouched body walks there.
static func _stamp_low(g: NavGrid, map: MapData, r: float, body: BodyConfig) -> void:
	for b in map.blocks:
		var bottom := b.center.y - b.size.y * 0.5
		var box := _cells_under(g, b, r)
		for j in range(box.y, box.w + 1):
			for i in range(box.x, box.z + 1):
				var c := j * g.cols + i
				for k in range(g.cell_start[c], g.cell_start[c + 1]):
					var f := g.floor_y[k]
					if bottom >= f + body.crouch_height and bottom < f + body.height:
						g.low[k] = 1


## Drops inside the level (a platform's edge, a gap between floors) keep the clearance on both sides, as walls do.
## Cells past the outer edge (the last row or column can overhang it) are left to the outer-edge rule.
static func _stamp_drops(g: NavGrid, r: float, level: float) -> void:
	var cols := g.cols
	var cell_start := g.cell_start
	var floor_y := g.floor_y
	for j in g.rows:
		if g.cell_z(j) > g.max_z:
			continue
		var below := j + 1 < g.rows and g.cell_z(j + 1) <= g.max_z
		for i in cols:
			if g.cell_x(i) > g.max_x:
				continue
			var c := j * cols + i
			var k := cell_start[c]
			var one := cell_start[c + 1] - k == 1
			if i + 1 < cols and g.cell_x(i + 1) <= g.max_x:
				# One floor each side (most cells): a drop only if they differ by more than a step.
				if not one or cell_start[c + 2] - cell_start[c + 1] != 1 \
						or absf(floor_y[k] - floor_y[k + 1]) > g.max_step:
					_drops_between(g, r, c, c + 1, level)
			if below:
				var b := cell_start[c + cols]
				if not one or cell_start[c + cols + 1] - b != 1 or absf(floor_y[k] - floor_y[b]) > g.max_step:
					_drops_between(g, r, c, c + cols, level)


## Neighbouring cells `a` and `b`: every floor of either with no floor within max_step across the edge between them is
## a drop at that floor's height, blocking within `r` of the edge each cell's floor of the same storey (within `level`).
static func _drops_between(g: NavGrid, r: float, a: int, b: int, level: float) -> void:
	for k in range(g.cell_start[a], g.cell_start[a + 1]):
		if g.step_node(k, b) < 0:
			_block_near_edge(g, r, a, b, g.floor_y[k], level)
	for k in range(g.cell_start[b], g.cell_start[b + 1]):
		if g.step_node(k, a) < 0:
			_block_near_edge(g, r, a, b, g.floor_y[k], level)


static func _block_near_edge(g: NavGrid, r: float, a: int, b: int, y: float, level: float) -> void:
	var ai := a % g.cols
	var aj := a / g.cols
	var ex := (g.cell_x(ai) + g.cell_x(b % g.cols)) * 0.5
	var ez := (g.cell_z(aj) + g.cell_z(b / g.cols)) * 0.5
	var reach := ceili(r / g.cell)
	for j in range(maxi(0, aj - reach), mini(g.rows - 1, aj + reach) + 1):
		for i in range(maxi(0, ai - reach), mini(g.cols - 1, ai + reach) + 1):
			var dx := g.cell_x(i) - ex
			var dz := g.cell_z(j) - ez
			if sqrt(dx * dx + dz * dz) >= r:
				continue
			var k := g.nearest_node(j * g.cols + i, y)
			if k >= 0 and absf(g.floor_y[k] - y) < level:
				g.walkable[k] = 0


## The floor's own outer edge: no node within `r` of it is walkable.
static func _stamp_outer_edge(g: NavGrid, r: float) -> void:
	for j in g.rows:
		var z := g.cell_z(j)
		var near_z := z - g.min_z < r or g.max_z - z < r
		for i in g.cols:
			var x := g.cell_x(i)
			if near_z or x - g.min_x < r or g.max_x - x < r:
				var c := j * g.cols + i
				for k in range(g.cell_start[c], g.cell_start[c + 1]):
					g.walkable[k] = 0


## Each walkable node's eight steps (the node each neighbouring cell steps onto, walkable or not, or -1), which of them
## land on a walkable node (`step_mask`), the route search's points and links, each point weighted `weight` (below 1 the
## search's estimate counts for more than the steps it has taken: NavConfig), and each node's region (NavGrid.region).
static func _link(g: NavGrid, weight: float) -> void:
	var count := g.floor_y.size()
	var cols := g.cols
	var rows := g.rows
	var steps := PackedInt32Array()
	steps.resize(count * DIRECTIONS)
	steps.fill(-1)
	var masks := PackedByteArray()
	masks.resize(count)
	var walkable := g.walkable
	var cell_start := g.cell_start
	var floor_y := g.floor_y
	var node_cell := g.node_cell
	var max_step := g.max_step
	var offsets := PackedInt32Array()
	for d in DIRECTIONS:
		offsets.append(DJ[d] * cols + DI[d])
	for k in count:
		if walkable[k] == 0:
			continue
		var c := node_cell[k]
		var ci := c % cols
		var cj := c / cols
		var inside := ci > 0 and cj > 0 and ci + 1 < cols and cj + 1 < rows
		var mask := 0
		var f := floor_y[k]
		for d in DIRECTIONS:
			if not inside:
				var ni := ci + DI[d]
				var nj := cj + DJ[d]
				if ni < 0 or nj < 0 or ni >= cols or nj >= rows:
					continue
			var nc := c + offsets[d]
			var n := cell_start[nc]
			# One floor (most cells): no search.
			if cell_start[nc + 1] - n != 1:
				n = g.nearest_node(nc, f)
			if n >= 0 and (absf(floor_y[n] - f) <= max_step or d >= 4 and _sloped_diagonal(g, c, d, f, floor_y[n])):
				steps[k * DIRECTIONS + d] = n
				if walkable[n] == 1:
					mask |= 1 << d
		masks[k] = mask
	g.steps = steps
	g.step_mask = masks
	var astar := AStar3D.new()
	astar.reserve_space(count)
	for k in count:
		if walkable[k] == 1:
			astar.add_point(k, g.node_position(k), weight)
	# Union-find over the links, taken either way: a node's parent is never above it, so one pass in order flattens it.
	var parent := PackedInt32Array()
	parent.resize(count)
	for k in count:
		parent[k] = k
	# The links: each walkable node's four forward steps (east, south and the two diagonals ahead), both ways where a
	# step's way back can be taken too. A diagonal needs both straight steps it passes walkable, from where it starts.
	for k in count:
		if walkable[k] == 0:
			continue
		var mask := masks[k]
		for d: int in FORWARD:
			if mask & (1 << d) == 0:
				continue
			var n := steps[k * DIRECTIONS + d]
			var sides := (1 << SIDE_A[d]) | (1 << SIDE_B[d])
			var there := mask & sides == sides
			var back_sides := (1 << SIDE_A[OPPOSITE[d]]) | (1 << SIDE_B[OPPOSITE[d]])
			var back := masks[n] & back_sides == back_sides
			if there:
				astar.connect_points(k, n, back)
			elif back:
				astar.connect_points(n, k, false)
			else:
				continue
			var ra := k
			while parent[ra] != ra:
				parent[ra] = parent[parent[ra]]
				ra = parent[ra]
			var rb := n
			while parent[rb] != rb:
				parent[rb] = parent[parent[rb]]
				rb = parent[rb]
			if ra < rb:
				parent[rb] = ra
			elif rb < ra:
				parent[ra] = rb
	g.astar = astar
	for k in count:
		parent[k] = parent[parent[k]] if walkable[k] == 1 else -1
	g.region = parent


## Each cell's distance to the nearest cell that isn't open (NavGrid.open), in two sweeps (a chamfer transform with
## unit steps, which is the Chebyshev distance).
static func _open(g: NavGrid) -> void:
	var cols := g.cols
	var rows := g.rows
	var dist := PackedByteArray()
	dist.resize(cols * rows)
	for c in cols * rows:
		var k := g.cell_start[c]
		if g.cell_start[c + 1] - k == 1 and g.step_mask[k] == NavGrid.ALL_STEPS:
			dist[c] = OPEN_MAX
	for j in rows:
		for i in cols:
			var c := j * cols + i
			if dist[c] == 0:
				continue
			var d := 0
			if i > 0 and j > 0:
				d = mini(mini(dist[c - 1], dist[c - cols]), dist[c - cols - 1])
				if i + 1 < cols:
					d = mini(d, dist[c - cols + 1])
			dist[c] = mini(dist[c], d + 1)
	for j in range(rows - 1, -1, -1):
		for i in range(cols - 1, -1, -1):
			var c := j * cols + i
			if dist[c] == 0:
				continue
			var d := 0
			if i + 1 < cols and j + 1 < rows:
				d = mini(mini(dist[c + 1], dist[c + cols]), dist[c + cols + 1])
				if i > 0:
					d = mini(d, dist[c + cols - 1])
			dist[c] = mini(dist[c], d + 1)
	g.open = dist


## Whether diagonal step `d` from cell `c` at floor `f` onto floor `to` climbs or descends a smooth slope (WR1): further
## than max_step, as a diagonal on ground steeper than 0.53 is, but no further than max_step * sqrt(2), and each straight
## step it passes is within max_step of both ends. A kerb or a box's edge fails a straight step, so it stays a drop.
static func _sloped_diagonal(g: NavGrid, c: int, d: int, f: float, to: float) -> bool:
	var max_step := g.max_step
	if absf(to - f) > max_step * SQRT_2:
		return false
	return _between(g, c + DI[d], f, to, max_step) and _between(g, c + DJ[d] * g.cols, f, to, max_step)


## Whether cell `side` has a floor within `max_step` of both `f` (its floor nearest `f`) and `to`.
static func _between(g: NavGrid, side: int, f: float, to: float, max_step: float) -> bool:
	var m := g.nearest_node(side, f)
	return m >= 0 and absf(g.floor_y[m] - f) <= max_step and absf(to - g.floor_y[m]) <= max_step
