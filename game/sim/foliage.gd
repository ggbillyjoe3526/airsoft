class_name Foliage
extends RefCounted
## A map's bushes (the browser game's map/foliage.ts, M33e and FO1): upright ellipsoids of leaves standing on the
## ground, `radius` across and `height` tall from the foot. No collider, no level-ray surface and no nav obstacle:
## people walk straight through them. What they do is count leaves along a line: bots see no one through more than
## BotConfig.foliage_see_through of them, and a BB stops once it has crossed BallisticsConfig.leaf_stop_depth (BBStep,
## Leaves). The simulation gets them through WorldQuery.foliage (Contracts 4); MapData reads them from the map's
## `foliage` list; BushView draws them and the minimap marks them. Queries allocate nothing: bushes are filed in a grid
## of INDEX_CELL squares by their middles, built once on the first query after the last `add`.

## Leaves crossed for less than this (m) count as none (first_leaves): a BB that came out of a bush on its surface last
## tick, or one grazing a rim, would otherwise "cross" a sliver of leaf again and again.
const MIN_LEAVES := 1e-3
## A line shorter than this (m) crosses no leaves.
const MIN_LINE := 1e-6
## How far out of a bush (in its radii across, and metres up and down) a point still counts as on it (leaf_floor).
const FLOOR_REACH := 1.05
const FLOOR_SLACK := 0.05
## The index's square (m): about two of Woodland's bushes across, and two ticks of a fast BB's travel.
const INDEX_CELL := 4.0


## Where a line meets leaves (first_leaves): metres along it to where it goes in (0 when it starts inside), and to where
## it comes out or, when it ends among the leaves (`through` false), to its end.
class Crossing:
	extends RefCounted
	var enter: float = 0.0
	var exit: float = 0.0
	var through: bool = false


## Each bush's foot (the middle of its base, on the ground), radius across and height, parallel lists in the map's order.
var feet: PackedVector3Array = PackedVector3Array()
var radii: PackedFloat32Array = PackedFloat32Array()
var heights: PackedFloat32Array = PackedFloat32Array()

var _indexed: bool = false
## The index: the plan corner of square (0, 0), its columns and rows, and each square's bushes as one list
## (_cell_items[_cell_start[s] ..< _cell_start[s + 1]]).
var _origin: Vector2 = Vector2.ZERO
var _cols: int = 0
var _rows: int = 0
var _cell_start: PackedInt32Array = PackedInt32Array()
var _cell_items: PackedInt32Array = PackedInt32Array()
## The widest radius: a line's squares are widened by it, as a bush is filed only by its middle.
var _reach: float = 0.0
## The squares a query covers (_squares), inclusive.
var _c0: int = 0
var _c1: int = -1
var _r0: int = 0
var _r1: int = -1

## Where the last _span puts a line in a bush, as shares of it: in at _t0, out at _t1 (both clipped to the line), and
## whether it comes out within it.
static var _t0: float = 0.0
static var _t1: float = 0.0
static var _out: bool = false
## leaf_surface's crossing back.
static var _back: Crossing = Crossing.new()


## Adds a bush standing on `foot`, `radius` across and `height` tall.
func add(foot: Vector3, radius: float, height: float) -> void:
	feet.append(foot)
	radii.append(radius)
	heights.append(height)
	_indexed = false


func size() -> int:
	return feet.size()


func is_empty() -> bool:
	return feet.is_empty()


## How far the line from `a` to `b` runs through leaves (m), summed over every bush it crosses. Stops counting once past
## `limit` (pass it when only "more than this?" matters). A line that only grazes a bush, or starts just inside one,
## crosses little leaf: someone at the edge of a bush is seen and can see out; deeper in they are hidden.
func depth(a: Vector3, b: Vector3, limit: float = INF) -> float:
	if feet.is_empty():
		return 0.0
	var d := b - a
	var length := d.length()
	if length < MIN_LINE:
		return 0.0
	var lo := a.min(b)
	var hi := a.max(b)
	var total := 0.0
	if _squares(lo, hi):
		for r in range(_r0, _r1 + 1):
			for c in range(_c0, _c1 + 1):
				var s := r * _cols + c
				for k in range(_cell_start[s], _cell_start[s + 1]):
					var i := _cell_items[k]
					if not _outside(i, lo, hi) and _span(i, a, d):
						total += (_t1 - _t0) * length
						if total > limit:
							return total
		return total
	for i in feet.size():
		if not _outside(i, lo, hi) and _span(i, a, d):
			total += (_t1 - _t0) * length
			if total > limit:
				return total
	return total


## The first bush the line from `origin` along unit `dir` runs into within `length` m (or starts inside), into `out`:
## where along it the line goes in, and where it comes out or, still among the leaves at `length`, `length` with
## `through` false. False if it meets no leaves (or only a sliver: MIN_LEAVES). The BBs' leaves (BBStep): each tick a
## BB takes on one bush at a time.
func first_leaves(origin: Vector3, dir: Vector3, length: float, out: Crossing) -> bool:
	if not (length > MIN_LEAVES) or feet.is_empty():
		return false
	var d := dir * length
	var end := origin + d
	var lo := origin.min(end)
	var hi := origin.max(end)
	var best := INF
	if _squares(lo, hi):
		for r in range(_r0, _r1 + 1):
			for c in range(_c0, _c1 + 1):
				var s := r * _cols + c
				for k in range(_cell_start[s], _cell_start[s + 1]):
					best = _nearer(_cell_items[k], origin, d, lo, hi, length, best, out)
	else:
		for i in feet.size():
			best = _nearer(i, origin, d, lo, hi, length, best, out)
	return best < INF


## Where leaves knocked out by a BB that stopped at `at` show (presentation): where the line back from `at` along unit
## `back` leaves the bush round `at`, so the side the BB went in, where they can be seen; `at` itself when that line is
## still among the leaves `reach` m back (a BB fired from inside the bush: `reach` is the leaves it crossed) or `at` is
## in no bush.
func leaf_surface(at: Vector3, back: Vector3, reach: float) -> Vector3:
	if feet.is_empty() or not first_leaves(at, back, reach, _back) or _back.enter > MIN_LEAVES or not _back.through:
		return at
	return at + back * _back.exit


## Whether `at` is among a bush's leaves (inside its ellipsoid), through the index: allocates nothing. Someone is in a
## bush when a point over their feet is (Character.in_bush, BP8).
func holds(at: Vector3) -> bool:
	if feet.is_empty():
		return false
	if _squares(at, at):
		for r in range(_r0, _r1 + 1):
			for c in range(_c0, _c1 + 1):
				var s := r * _cols + c
				for k in range(_cell_start[s], _cell_start[s + 1]):
					if _inside(_cell_items[k], at):
						return true
		return false
	for i in feet.size():
		if _inside(i, at):
			return true
	return false


## Whether `at` is inside bush `i`'s ellipsoid.
func _inside(i: int, at: Vector3) -> bool:
	var f := feet[i]
	var r := radii[i]
	var half := heights[i] * 0.5
	var dx := (at.x - f.x) / r
	var dy := (at.y - f.y - half) / half
	var dz := (at.z - f.z) / r
	return dx * dx + dy * dy + dz * dz <= 1.0


## The ground under the bush `at` is in or on (its foot), for the leaves a BB knocks out of it to come to rest on; -INF
## when `at` is in no bush. The lowest foot of those it is in, as bushes overlap.
func leaf_floor(at: Vector3) -> float:
	var floor_y := INF
	for i in feet.size():
		var f := feet[i]
		var r := radii[i]
		var dx := (at.x - f.x) / r
		var dz := (at.z - f.z) / r
		if dx * dx + dz * dz <= FLOOR_REACH * FLOOR_REACH and at.y >= f.y - FLOOR_SLACK \
				and at.y <= f.y + heights[i] + FLOOR_SLACK:
			floor_y = minf(floor_y, f.y)
	return floor_y if floor_y < INF else -INF


## Bush `i` if the line from `origin` along `d` (`length` m) goes into it before `best` (a share of the line) with more
## than a sliver of leaf: `out` filled and its share returned; else `best`.
func _nearer(i: int, origin: Vector3, d: Vector3, lo: Vector3, hi: Vector3, length: float, best: float,
		out: Crossing) -> float:
	if _outside(i, lo, hi) or not _span(i, origin, d):
		return best
	if (_t1 - _t0) * length < MIN_LEAVES or _t0 >= best:
		return best
	out.enter = _t0 * length
	out.exit = _t1 * length
	out.through = _out
	return _t0


## Whether the line from `a` along `d` (t from 0 to 1) runs through bush `i`, setting _t0, _t1 and _out. In the bush's
## own space it is a unit sphere: solve |p + t q|² = 1.
func _span(i: int, a: Vector3, d: Vector3) -> bool:
	var f := feet[i]
	var r := radii[i]
	var half := heights[i] * 0.5
	var p := Vector3((a.x - f.x) / r, (a.y - f.y - half) / half, (a.z - f.z) / r)
	var q := Vector3(d.x / r, d.y / half, d.z / r)
	var qq := q.dot(q)
	var pq := p.dot(q)
	var disc := pq * pq - qq * (p.dot(p) - 1.0)
	if disc <= 0.0:
		return false
	var root := sqrt(disc)
	var t1 := (-pq + root) / qq
	_t0 = maxf(0.0, (-pq - root) / qq)
	_t1 = minf(1.0, t1)
	_out = t1 <= 1.0
	return _t1 > _t0


## True if bush `i`'s box misses the box from `lo` to `hi`.
func _outside(i: int, lo: Vector3, hi: Vector3) -> bool:
	var f := feet[i]
	var r := radii[i]
	return f.x + r < lo.x or f.x - r > hi.x or f.z + r < lo.z or f.z - r > hi.z or f.y + heights[i] < lo.y \
			or f.y > hi.y


## The index's squares the plan box from `lo` to `hi` (widened by _reach) covers, into _c0.._c1 and _r0.._r1 (an empty
## range when it misses them all). False when they outnumber the bushes: then a pass over every bush is quicker.
func _squares(lo: Vector3, hi: Vector3) -> bool:
	if not _indexed:
		_index()
	_c0 = maxi(floori((lo.x - _reach - _origin.x) / INDEX_CELL), 0)
	_c1 = mini(floori((hi.x + _reach - _origin.x) / INDEX_CELL), _cols - 1)
	_r0 = maxi(floori((lo.z - _reach - _origin.y) / INDEX_CELL), 0)
	_r1 = mini(floori((hi.z + _reach - _origin.y) / INDEX_CELL), _rows - 1)
	if _c1 < _c0 or _r1 < _r0:
		_c1 = _c0 - 1
		return true
	return (_c1 - _c0 + 1) * (_r1 - _r0 + 1) <= feet.size()


## Files every bush in the square under its middle (a counting sort into one list).
func _index() -> void:
	_indexed = true
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	_reach = 0.0
	for i in feet.size():
		lo = lo.min(Vector2(feet[i].x, feet[i].z))
		hi = hi.max(Vector2(feet[i].x, feet[i].z))
		_reach = maxf(_reach, radii[i])
	if feet.is_empty():
		lo = Vector2.ZERO
		hi = Vector2.ZERO
	_origin = lo
	_cols = floori((hi.x - lo.x) / INDEX_CELL) + 1
	_rows = floori((hi.y - lo.y) / INDEX_CELL) + 1
	_cell_start.resize(_cols * _rows + 1)
	_cell_start.fill(0)
	_cell_items.resize(feet.size())
	for i in feet.size():
		_cell_start[_square_of(i) + 1] += 1
	for s in _cols * _rows:
		_cell_start[s + 1] += _cell_start[s]
	var filled := _cell_start.duplicate()
	for i in feet.size():
		var s := _square_of(i)
		_cell_items[filled[s]] = i
		filled[s] += 1


func _square_of(i: int) -> int:
	var c := clampi(floori((feet[i].x - _origin.x) / INDEX_CELL), 0, _cols - 1)
	var r := clampi(floori((feet[i].z - _origin.y) / INDEX_CELL), 0, _rows - 1)
	return r * _cols + c
