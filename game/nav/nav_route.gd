class_name NavRoute
## String-pulls a route search's node path into straight legs (the browser game's pullRoute). From each anchor the route
## goes on to the furthest node still in a clear straight line on foot, probed by the grid's leg_probe, trying nodes in
## order until one is out of sight. The browser tried every second node; this tries the path's corners (where a straight
## run drawn in cells ends), where a leg's end lies, and only when the next corner is out of sight its turns, then every
## second node. Each try walks a line in GDScript, so fewer tries keep the smoothing cheap.
##
## Smoke clouds standing (NavSmoke) are kept the same way. On a field with bushes a leg may run through no more leaves
## than the path it straightens does (a cell's diagonal
## more at most, for a rim): the search went round a bush where that is quicker (NavConfig.bush_cost), so the pull keeps
## it round.
##
## A vault or lift link in the path (a search point past the grid's nodes, NavVaults, NavLifts) ends the pulling at its
## takeoff node: the route goes to the takeoff, then straight to the landing, a leg of its own, and pulls on from there.


## Writes the route along node path `ids` (start node first, goal node last) into `out`, from `start` (where the walker
## is; the first node's centre when that isn't walkable): the waypoints after the start, each on its floor, ending
## exactly on `goal` when it is walkable and in a straight line on foot from the waypoint before.
static func pull(g: NavGrid, ids: PackedInt64Array, start: Vector3, goal: Vector3, out: PackedVector3Array) -> void:
	out.clear()
	var last := ids.size() - 1
	var ax := start.x
	var ay := start.y
	var az := start.z
	if not g.is_walkable_at(start):
		var c0 := g.node_cell[ids[0]]
		ax = g.cell_x(c0 % g.cols)
		ay = g.floor_y[ids[0]]
		az = g.cell_z(c0 / g.cols)
	# Per index of the path, how many of the nodes before it are in a bush; empty on a field with none.
	var bushes := PackedInt32Array()
	if not g.slow.is_empty():
		bushes.resize(ids.size())
		var n := 0
		for t in ids.size():
			bushes[t] = n
			if ids[t] < g.slow.size() and g.slow[ids[t]] == 1:
				n += 1
	# The same for the smoke clouds standing now (NavSmoke); empty while none does.
	var smoked := PackedInt32Array()
	if g.smoke != null and g.smoke.live():
		smoked.resize(ids.size())
		var n := 0
		for t in ids.size():
			smoked[t] = n
			if g.smoke.priced(ids[t]):
				n += 1
	var k := 0
	var end := _segment_end(g, ids, k)
	while k < last:
		var next := k + 2 if k == end else _furthest(g, ids, ax, ay, az, k, end, bushes, smoked)
		if k == end:
			if out.is_empty():
				out.append(g.node_position(ids[k]))
			end = _segment_end(g, ids, next)
		var c := g.node_cell[ids[next]]
		ax = g.cell_x(c % g.cols)
		ay = g.floor_y[ids[next]]
		az = g.cell_z(c / g.cols)
		out.append(Vector3(ax, ay, az))
		k = next
	if out.is_empty():
		out.append(g.node_position(ids[last]))
	# End exactly on the goal when it's walkable and in a straight line on foot (the search works in cell centres).
	var n := out.size()
	var from := out[n - 2] if n > 1 else start
	var goal_node := g.node_at(goal)
	if goal_node >= 0 and g.walkable[goal_node] == 1 \
			and g.walk_line(from.x, from.y, from.z, goal.x, goal.z, g.leg_probe) == goal_node:
		out[n - 1] = Vector3(goal.x, g.floor_y[goal_node], goal.z)


## The index of the node in `ids` from `k` on that a vault or lift link's search point follows (its takeoff: every
## link's id is past the grid's nodes), or the last index.
static func _segment_end(g: NavGrid, ids: PackedInt64Array, k: int) -> int:
	var last := ids.size() - 1
	if g.vault_base < 0 and g.lift_base < 0:
		return last
	var nodes := g.node_count()
	for t in range(k, last):
		if ids[t + 1] >= nodes:
			return t
	return last


## The index of the furthest node after `k`, up to `last`, in a clear straight line from the anchor (ax, ay, az), else
## k + 1: the corners up to the first out of sight (a corner ends a run of at most two neighbouring directions, a straight line
## drawn in cells); if the first is out of sight, the turns short of it; if the first turn is, every second node.
static func _furthest(g: NavGrid, ids: PackedInt64Array, ax: float, ay: float, az: float, k: int, last: int,
		bushes: PackedInt32Array, smoked: PackedInt32Array) -> int:
	var next := k + 1
	var m := _next_corner(g, ids, k, last)
	while _in_line(g, ax, ay, az, ids, k, m, bushes, smoked):
		next = m
		if m == last:
			return m
		m = _next_corner(g, ids, m, last)
	if next > k + 1:
		return next
	var t := _next_turn(g, ids, k, last)
	var first_turn := t
	while t < m and _in_line(g, ax, ay, az, ids, k, t, bushes, smoked):
		next = t
		t = _next_turn(g, ids, t, last)
	if next == k + 1:
		var s := k + 2
		while s < first_turn and _in_line(g, ax, ay, az, ids, k, s, bushes, smoked):
			next = s
			s += 2
	return next


## True if the straight line from the anchor (the path's node `from`) reaches its node `to` on foot, probed by
## leg_probe, and (with `bushes`, pull's counts) through no more leaves than the path between them.
static func _in_line(g: NavGrid, ax: float, ay: float, az: float, ids: PackedInt64Array, from: int, to: int,
		bushes: PackedInt32Array, smoked: PackedInt32Array) -> bool:
	var k := ids[to]
	var c := g.node_cell[k]
	var bx := g.cell_x(c % g.cols)
	var bz := g.cell_z(c / g.cols)
	if g.walk_line(ax, ay, az, bx, bz, g.leg_probe) != k:
		return false
	if not bushes.is_empty():
		var most := (bushes[to] - bushes[from] + 1) * g.cell * sqrt(2.0)
		if g.leaves.depth(Vector3(ax, ay + g.bush_probe, az), Vector3(bx, g.floor_y[k] + g.bush_probe, bz), most) \
				> most:
			return false
	if not smoked.is_empty():
		var most := (smoked[to] - smoked[from] + 1) * g.cell * sqrt(2.0)
		var eye := g.smoke.eye
		if g.smoke.depth(Vector3(ax, ay + eye, az), Vector3(bx, g.floor_y[k] + eye, bz), most) > most:
			return false
	return true


## The index after `m` where the path turns (its step there differs from the step before), or `last`.
static func _next_turn(g: NavGrid, ids: PackedInt64Array, m: int, last: int) -> int:
	var t := m + 1
	while t < last:
		var here := g.node_cell[ids[t]]
		if here - g.node_cell[ids[t - 1]] != g.node_cell[ids[t + 1]] - here:
			return t
		t += 1
	return last


## The index after `m` where a run of steps in at most two neighbouring directions (45 degrees apart) ends, or the last
## index (`last`): a straight line at any angle drawn in cells is such a run.
static func _next_corner(g: NavGrid, ids: PackedInt64Array, m: int, last: int) -> int:
	# Steps compared as cell index differences (one per neighbouring direction, never 0), decoded into directions only
	# when a new one turns up: the comparisons a step were most of this walk's time.
	var cols := g.cols
	var cells := g.node_cell
	var c := cells[ids[m]]
	var first := 0
	var second := 0
	var t := m
	while t < last:
		var n := cells[ids[t + 1]]
		var d := n - c
		c = n
		if first == 0:
			first = d
		elif d != first and d != second:
			if second != 0 or not _beside(d, first, cols):
				return t
			second = d
		t += 1
	return last


## Whether the steps `a` and `b` (cell index differences between neighbouring cells, on a grid `cols` wide) are 45
## degrees apart: one of their two cell offsets differs by one, the other not at all.
static func _beside(a: int, b: int, cols: int) -> bool:
	var aj := (a + cols + 1) / cols - 1
	var bj := (b + cols + 1) / cols - 1
	return absi((a - aj * cols) - (b - bj * cols)) + absi(aj - bj) == 1
