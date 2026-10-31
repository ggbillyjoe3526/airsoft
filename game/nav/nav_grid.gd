class_name NavGrid
extends RefCounted
## Where a body can walk, for bots and walk-offs (the browser game's nav/navGrid.ts), built once per map from its blocks
## (NavGridBuilder). Layered: each cell holds a node per floor over it (the walkable surfaces under its centre with
## headroom above them, lowest first), stored flat, so a hall and the floor over it are two nodes of the same cells. A
## node is walkable if a body standing on it keeps the clearance from every block in its way and every drop off its
## floor. Neighbouring nodes connect if their floors are at most max_step apart, with no squeezing diagonally past a
## blocked node; routes are searched by Godot's AStar3D over those links, then string-pulled into straight legs.
##
## Every query that names a point answers for the floor at that point's height: the highest floor at most pick_above
## above it (the one a body standing, crouching or jumping there is over), or the cell's lowest if it is below them all.
## Pure data: no nodes, no physics (docs/ARCHITECTURE.md › Contracts 1).

## Eight unit directions (x, z) round a point, for the leg probes.
const PROBE_X: Array[float] = [1.0, -1.0, 0.0, 0.0, 0.70710678, 0.70710678, -0.70710678, -0.70710678]
const PROBE_Z: Array[float] = [0.0, 0.0, 1.0, -1.0, 0.70710678, -0.70710678, 0.70710678, -0.70710678]
## The step (NavGridBuilder.DI, DJ) to the neighbouring cell (di, dj), indexed (di + 1) * 3 + dj + 1; -1 is no step.
const STEP_OF: Array[int] = [7, 1, 6, 3, -1, 2, 5, 0, 4]
## A line's skip over open ground stops this far (m) short of the open square's edge, against rounding.
const OPEN_MARGIN := 1e-4
## step_mask with all eight steps walkable.
const ALL_STEPS := 255
## Half a diagonal's share of each axis: the diagonal probes' reach along x and z.
const DIAGONAL := 0.70710678

## The frame: cell size (m), cells across x and z, and the floor's bounds (cells past max_x or max_z overhang it).
var cell: float = 0.0
var cols: int = 0
var rows: int = 0
var min_x: float = 0.0
var min_z: float = 0.0
var max_x: float = 0.0
var max_z: float = 0.0
## Cell c's floors are nodes cell_start[c] .. cell_start[c + 1] - 1, lowest first; c = row * cols + col.
var cell_start: PackedInt32Array = PackedInt32Array([0])
## Per node: its cell, whether it is walkable (1) or blocked (0), and its floor's height at the cell's centre.
var node_cell: PackedInt32Array = PackedInt32Array()
var walkable: PackedByteArray = PackedByteArray()
var floor_y: PackedFloat32Array = PackedFloat32Array()
## Per node: 1 where only a crouched body fits (something over the floor lower than a standing body, within the
## clearance: a tunnel, CR1), else 0.
var low: PackedByteArray = PackedByteArray()
## Per walkable node and step d (NavGridBuilder.DI, DJ): the node of that neighbouring cell it steps onto (walkable or
## not), or -1; and a bit per step (1 << d) that lands on a walkable node (ALL_STEPS: no leg probe round it can fail).
var steps: PackedInt32Array = PackedInt32Array()
var step_mask: PackedByteArray = PackedByteArray()
## Per cell: 0 unless it is open (one floor, all its node's steps walkable), else its distance in cells (Chebyshev, at
## most 255) to the nearest cell that isn't, past the grid's edge counting as not open: every cell within open - 1 of it
## is open.
var open: PackedByteArray = PackedByteArray()
## The route search: a point per walkable node (id = node), linked by the step rules.
var astar: AStar3D = null
## Vault links (NavVaults): node k's lead to nodes vault_to[vault_start[k]] .. vault_to[vault_start[k + 1] - 1]; link l
## is search point vault_base + l. vault_base -1: not linked yet.
var vault_start: PackedInt32Array = PackedInt32Array()
var vault_to: PackedInt32Array = PackedInt32Array()
var vault_base: int = -1
## Each node's region: the lowest node it is linked to on foot, either way, or -1 for a blocked node. Two nodes in
## different regions have no route on foot, so a search between them is refused before it starts (a whole-grid search
## that fails took 182 to 202 ms on Woodland).
var region: PackedInt32Array = PackedInt32Array()
## Regions joined by vault links (NavVaults.link): a region's own entry is the lowest region it reaches by foot and
## vaults, either way; a region no link touches has none.
var vault_region: Dictionary[int, int] = {}
## Most floors any one cell has: 1 on a map with no floor over another.
var layers: int = 0
## From NavConfig and BodyConfig when built. The largest floor height difference between neighbouring nodes a body
## walks across (m).
var max_step: float = 0.0
## The headroom a floor needs (the body's height): a route end never snaps to a floor further below it than this.
var headroom: float = 0.0
## A route end snaps to a floor further below it than this only when none nearer its height is in reach (G11).
var snap_drop: float = 0.0
var pick_above: float = 0.0
## Route ends snap to the nearest walkable node within this (m); route legs are probed this far round (m).
var snap: float = 0.0
var leg_probe: float = 0.0
## Lines are walked in samples this far apart at most (m).
var sample_step: float = 0.0
var hunt_tries: int = 0
## Route searches run so far (find_route calls that reached the search), for the search budget's checks and figures.
var searches: int = 0


## The grid for `map`: an empty one (every query off the grid, no route) if it has no floor or ramp.
static func build(map: MapData, cfg: NavConfig, body: BodyConfig) -> NavGrid:
	var g := NavGrid.new()
	g.cell = cfg.cell
	g.max_step = body.max_step
	g.headroom = body.height
	g.snap_drop = body.height * cfg.snap_drop_share
	g.pick_above = cfg.pick_above
	g.snap = cfg.snap
	g.leg_probe = cfg.leg_probe(body)
	g.sample_step = cfg.cell * cfg.line_sample_share
	g.hunt_tries = cfg.hunt_tries
	if not NavGridBuilder.fill(g, map, cfg, body):
		push_warning("NavGrid: map %s has no floor; bots have nowhere to walk" % map.id)
		g.astar = AStar3D.new()
	return g


## How many nodes (floors of cells) the grid has.
func node_count() -> int:
	return floor_y.size()


## The centre of column `i` (x) and of row `j` (z).
func cell_x(i: int) -> float:
	return min_x + (i + 0.5) * cell


func cell_z(j: int) -> float:
	return min_z + (j + 0.5) * cell


## The cell containing (x, z), or -1 outside the grid.
func cell_index(x: float, z: float) -> int:
	var i := floori((x - min_x) / cell)
	var j := floori((z - min_z) / cell)
	if i < 0 or j < 0 or i >= cols or j >= rows:
		return -1
	return j * cols + i


## Whether a body at `p` walking `ahead` (m, along the level unit vector `dir`) meets a floor only a crouched body fits
## under (low): at the point, half way or at the end, each on the floor at its height.
func low_ahead(p: Vector3, dir: Vector3, ahead: float) -> bool:
	for s in 3:
		var at := p + dir * (ahead * s * 0.5)
		var k := node_at(at)
		if k >= 0 and low[k] != 0:
			return true
	return false


## The node under the point: its cell's floor under that height, or -1 off the grid or where there is none.
func node_at(p: Vector3) -> int:
	var c := cell_index(p.x, p.z)
	return pick_node(c, p.y) if c >= 0 else -1


## The floor's height under the point, or NAN off the grid or where there is no walkable surface.
func floor_at(p: Vector3) -> float:
	var k := node_at(p)
	return floor_y[k] if k >= 0 else NAN


## True if the floor under the point is walkable there.
func is_walkable_at(p: Vector3) -> bool:
	var k := node_at(p)
	return k >= 0 and walkable[k] == 1


## Node `k`'s cell centre on its floor.
func node_position(k: int) -> Vector3:
	var c := node_cell[k]
	return Vector3(cell_x(c % cols), floor_y[k], cell_z(c / cols))


## The node of cell `c` whose floor is nearest height `y`, or -1 if the cell has none.
func nearest_node(c: int, y: float) -> int:
	var best := -1
	var best_d := INF
	for k in range(cell_start[c], cell_start[c + 1]):
		var d := absf(floor_y[k] - y)
		if d < best_d:
			best_d = d
			best = k
	return best


## The node of cell `c` a body on node `k` steps onto (floors at most max_step apart, walkable or not), or -1.
func step_node(k: int, c: int) -> int:
	var s := cell_start[c]
	var n := s if cell_start[c + 1] - s == 1 else nearest_node(c, floor_y[k])
	return n if n >= 0 and absf(floor_y[n] - floor_y[k]) <= max_step else -1


## The nearest walkable node to the point within `max_radius` (m), each cell judged at its floor under the point's
## height, or -1. A floor more than a storey's headroom below doesn't count (from a balcony's edge the nearest spot is
## on the balcony, not in the street under it); nor, where one in reach is, does a floor more than snap_drop below (G11:
## a body on the dock's lip, its middle past the edge, is over the road, whose cells were the nearest walkable ones).
func nearest_walkable(p: Vector3, max_radius: float) -> int:
	var k := _nearest_walkable_from(p, max_radius, snap_drop)
	return k if k >= 0 else _nearest_walkable_from(p, max_radius, INF)


## True if a body can walk the straight line from `a` to (b.x, b.z) on foot, from the floor under `a`: every cell under
## it (sampled finely) has a walkable floor a step from the last. With `probe` > 0 every sample must also have walkable
## nodes on its floor `probe` metres away in eight directions (browser audit AI-12: leg_probe keeps the body's radius
## from corners).
func clear_line(a: Vector3, b: Vector3, probe: float = 0.0) -> bool:
	return walk_line(a.x, a.y, a.z, b.x, b.z, probe) >= 0


## True if walking the straight line from `a` to (b.x, b.z) would step off a floor: some cell under it has no floor
## within max_step of the one before (a platform's edge, a ramp's side; past the grid's edge counts). Walls don't count.
## A cell whose every floor is more than `wall_above` over the one before is a wall the body is stopped by, not a
## ledge: the line goes on past it on its own floor (G11). A diagonal on a slope is the steps table's (WR1).
func drop_on_line(a: Vector3, b: Vector3, wall_above: float = INF) -> bool:
	var dx := b.x - a.x
	var dz := b.z - a.z
	var samples := maxi(1, ceili(sqrt(dx * dx + dz * dz) / sample_step))
	var node := node_at(a)
	var at := cell_index(a.x, a.z)
	for s in range(1, samples + 1):
		var t := float(s) / samples
		var c := cell_index(a.x + dx * t, a.z + dz * t)
		if c < 0 or cell_start[c] == cell_start[c + 1]:
			return true
		if c == at:
			continue
		# Starting off any floor, the first floor met is where the line is.
		var next := step_node(node, c) if node >= 0 else pick_node(c, a.y)
		if next < 0 and node >= 0:
			# A diagonal up or down a smooth slope a straight step at a time (NavGridBuilder._sloped_diagonal).
			var di := c % cols - at % cols
			var dj := c / cols - at / cols
			if absi(di) == 1 and absi(dj) == 1:
				next = steps[node * NavGridBuilder.DIRECTIONS + STEP_OF[(di + 1) * 3 + dj + 1]]
		if next < 0 and node >= 0 and floor_y[cell_start[c]] > floor_y[node] + wall_above:
			continue
		if next < 0:
			return true
		node = next
		at = c
	return false


## A short walkable route from `start` to `goal` (the search's greed: NavConfig.search_greed; each snapped to the
## nearest walkable node within `snap`, on the floor at its height), smoothed into straight legs probed by leg_probe,
## written into `out` as waypoints on their floors: the start excluded, ending exactly on the goal where it is walkable
## and in a straight line on foot from the leg before, else on the node nearest it. With `vaults` (a bot's route) it may
## go over a low obstacle by a vault link, a leg of its own from the node before it to the node past it (is_vault_leg);
## without (a walk-off), only on foot. False, with `out` emptied, when there is no route.
func find_route(start: Vector3, goal: Vector3, out: PackedVector3Array, vaults: bool = false) -> bool:
	var a := nearest_walkable(start, snap)
	var b := nearest_walkable(goal, snap)
	if a < 0 or b < 0:
		out.clear()
		return false
	if not linked(a, b, vaults):
		out.clear()
		return false
	var off := not vaults and not vault_to.is_empty()
	if off:
		_set_vaults(false)
	if a != b:
		searches += 1
	var ids := PackedInt64Array([a]) if a == b else astar.get_id_path(a, b)
	if off:
		_set_vaults(true)
	if ids.is_empty():
		out.clear()
		return false
	NavRoute.pull(self, ids, start, goal, out)
	return true


## False if nodes `a` and `b` lie in regions no route joins (on foot, or with `vaults` by vault links too). True
## doesn't promise a route: a region may be joined only by a one-way step.
func linked(a: int, b: int, vaults: bool = false) -> bool:
	var ra := region[a]
	var rb := region[b]
	if ra == rb:
		return true
	return vaults and vault_region.get(ra, ra) == vault_region.get(rb, rb)


## True if the leg from `a` to `b` (waypoints on node centres) is a vault link: over a low obstacle, not on foot.
func is_vault_leg(a: Vector3, b: Vector3) -> bool:
	if vault_to.is_empty():
		return false
	var from := node_at(a)
	if from < 0 or vault_start[from] == vault_start[from + 1]:
		return false
	var land := node_at(b)
	for l in range(vault_start[from], vault_start[from + 1]):
		if vault_to[l] == land:
			return true
	return false


## Turns every vault link in the search on or off.
func _set_vaults(on: bool) -> void:
	for l in vault_to.size():
		astar.set_point_disabled(vault_base + l, not on)


## A walkable floor point within `radius` (m) of `p`, drawn from `rng` (bots' hunting); `p` itself if hunt_tries draws
## find none.
func random_walkable_near(p: Vector3, radius: float, rng: RandomNumberGenerator) -> Vector3:
	for i in hunt_tries:
		var angle := rng.randf() * TAU
		var d := radius * sqrt(rng.randf())
		var x := p.x + cos(angle) * d
		var z := p.z + sin(angle) * d
		var c := cell_index(x, z)
		if c < 0:
			continue
		var k := pick_node(c, p.y)
		if k >= 0 and walkable[k] == 1:
			return Vector3(x, floor_y[k], z)
	return p


## Walks the straight line from (ax, ay, az) to (bx, bz) on foot from the floor under the start, stepping floor to floor
## as it crosses cells; returns the node it ends on, or -1 if a step is not one a body can take (no floor within
## max_step, or a blocked node) or, with `probe` > 0, a sample's probes find one (see clear_line). Over open ground it
## skips the samples that can't meet anything (`open`), so a line across open ground costs a few samples, not two a
## cell.
func walk_line(ax: float, ay: float, az: float, bx: float, bz: float, probe: float) -> int:
	var dx := bx - ax
	var dz := bz - az
	var length := sqrt(dx * dx + dz * dz)
	var samples := maxi(1, ceili(length / sample_step))
	var c := cell_index(ax, az)
	if c < 0:
		return -1
	var node := pick_node(c, ay)
	if node < 0 or walkable[node] == 0:
		return -1
	# Locals: a member read costs more than a local one in the loop.
	var w := cols
	var h := rows
	var x0 := min_x
	var z0 := min_z
	var size := cell
	var inv := 1.0 / cell
	var table := steps
	var walk := walkable
	var masks := step_mask
	var open_round := open
	var sx := dx / samples
	var sz := dz / samples
	var spacing := length / samples
	var ci := c % w
	var cj := c / w
	var s := 0
	while s <= samples:
		var x := bx if s == samples else ax + sx * s
		var z := bz if s == samples else az + sz * s
		if x < x0 or z < z0:
			return -1
		# Truncation is floor here: both are at least 0.
		var i := int((x - x0) * inv)
		var j := int((z - z0) * inv)
		if i >= w or j >= h:
			return -1
		if i != ci or j != cj:
			# A sample is at most half a cell on, so the next cell is a neighbour: its step is in the table.
			var next := table[node * NavGridBuilder.DIRECTIONS + STEP_OF[(i - ci + 1) * 3 + j - cj + 1]]
			if next < 0 or walk[next] == 0:
				return -1
			node = next
			ci = i
			cj = j
		if masks[node] != ALL_STEPS:
			if probe <= 0.0:
				pass
			elif probe < size:
				if _probe_steps(x - x0 - ci * size, z - z0 - cj * size, probe, size) & ~masks[node] != 0:
					return -1
			elif not _probes_walkable(node, ci, cj, x, z, probe):
				return -1
		elif s < samples and spacing > 0.0:
			var reach := open_round[cj * w + ci] - 1
			if reach > 0:
				# Every cell within `reach` of this one is open (one floor, all eight steps walkable), and so is every
				# sample less than reach cells on: land on the last of them, on its cell's only floor.
				var jump := floori((reach * size - OPEN_MARGIN) / spacing)
				if jump > 0:
					s = mini(samples, s + jump)
					x = bx if s == samples else ax + sx * s
					z = bz if s == samples else az + sz * s
					ci = int((x - x0) * inv)
					cj = int((z - z0) * inv)
					node = cell_start[cj * w + ci]
		s += 1
	return node


## The steps (bits 1 << d) into the neighbouring cells that the eight points `probe` from a point reach, the point at
## (fx, fz) inside its cell of side `size`; `probe` less than a cell, so a probe reaches no further than a neighbour.
static func _probe_steps(fx: float, fz: float, probe: float, size: float) -> int:
	var lo_x := fx < probe
	var hi_x := fx >= size - probe
	var lo_z := fz < probe
	var hi_z := fz >= size - probe
	var need := (1 if hi_x else 0) | (2 if lo_x else 0) | (4 if hi_z else 0) | (8 if lo_z else 0)
	var q := probe * DIAGONAL
	if fx >= size - q or fx < q or fz >= size - q or fz < q:
		var qx_hi := fx >= size - q
		var qx_lo := fx < q
		var qz_hi := fz >= size - q
		var qz_lo := fz < q
		need |= _diagonal_step(qx_hi, qz_hi, 16, 1, 4) | _diagonal_step(qx_hi, qz_lo, 32, 1, 8)
		need |= _diagonal_step(qx_lo, qz_hi, 64, 2, 4) | _diagonal_step(qx_lo, qz_lo, 128, 2, 8)
	return need


## The step a diagonal probe makes: into the diagonal cell when it crosses both edges, else the straight one it crosses.
static func _diagonal_step(cross_x: bool, cross_z: bool, both: int, x_only: int, z_only: int) -> int:
	if cross_x:
		return both if cross_z else x_only
	return z_only if cross_z else 0


## True if every one of the eight points `probe` from (x, z), on node `node` in cell (ci, cj), has a walkable floor a
## step from the node's.
func _probes_walkable(node: int, ci: int, cj: int, x: float, z: float, probe: float) -> bool:
	for d in PROBE_X.size():
		var i := floori((x + PROBE_X[d] * probe - min_x) / cell)
		var j := floori((z + PROBE_Z[d] * probe - min_z) / cell)
		if i < 0 or j < 0 or i >= cols or j >= rows:
			return false
		if i == ci and j == cj:
			continue
		var n := -1
		if absi(i - ci) <= 1 and absi(j - cj) <= 1:
			n = steps[node * NavGridBuilder.DIRECTIONS + STEP_OF[(i - ci + 1) * 3 + j - cj + 1]]
		else:
			n = step_node(node, j * cols + i)
		if n < 0 or walkable[n] == 0:
			return false
	return true


## The floor of cell `c` under height `y` (the highest at most pick_above over it, else the lowest), or -1 if none.
func pick_node(c: int, y: float) -> int:
	var s := cell_start[c]
	var e := cell_start[c + 1]
	if s == e:
		return -1
	for k in range(e - 1, s, -1):
		if floor_y[k] <= y + pick_above:
			return k
	return s


## nearest_walkable's ring search (row by row round each ring), counting only floors at most `level` below the point.
func _nearest_walkable_from(p: Vector3, max_radius: float, level: float) -> int:
	if cols == 0:
		return -1
	var ci := clampi(floori((p.x - min_x) / cell), 0, cols - 1)
	var cj := clampi(floori((p.z - min_z) / cell), 0, rows - 1)
	var lowest := p.y - minf(level, headroom)
	var max_ring := ceili(max_radius / cell)
	var best := -1
	var best_d := INF
	for ring in max_ring + 1:
		for j in range(cj - ring, cj + ring + 1):
			if j < 0 or j >= rows:
				continue
			var edge_row := j == cj - ring or j == cj + ring
			var i := ci - ring
			while i <= ci + ring:
				if i >= 0 and i < cols:
					var k := pick_node(j * cols + i, p.y)
					if k >= 0 and walkable[k] == 1 and floor_y[k] >= lowest:
						var dx := cell_x(i) - p.x
						var dz := cell_z(j) - p.z
						var d := sqrt(dx * dx + dz * dz)
						if d < best_d:
							best_d = d
							best = k
				# Inside the ring's square only its two side cells are on it.
				i += 1 if edge_row or ring == 0 else 2 * ring
		# Anything in a later ring is at least ring * cell away.
		if best >= 0 and best_d <= ring * cell:
			break
	return best if best_d <= max_radius else -1
