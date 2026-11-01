class_name Railings
extends RefCounted
## A map's bar railings (SR1; The Street's waist-high metal railings): upright square bars between a top rail and a
## bottom rail, each run filling a level block's box along its long side (RailingConfig). A run's box is still solid to
## movers and the level ray (no one walks or throws a bomb through it), but sight and the BBs' level ray pass it
## (WorldQuery.sight_ray, ray_past_railings): here a BB meets only the bars and rails its path actually crosses, and
## flies on through the gaps. The simulation gets them through WorldQuery.railings (Contracts 4); MapLevel fills them
## from the map's railing blocks (MapStyle.railing_kinds) and draws each run's `parts`. Queries allocate nothing: runs
## are filed in a grid of INDEX_CELL squares by every square their footprint covers, built once on the first query
## after the last `add`.

## The index's square (m): about two ticks of a fast BB's travel.
const INDEX_CELL := 4.0
## A path this close to parallel with an axis (|dir| along it) never crosses that axis's faces.
const PARALLEL := 1e-12

## The bars' and rails' measurements.
var config: RailingConfig = null
## Each run's box (its corners), what it is made of (RayHit.Surface), whether its length runs along x (1) or z (0),
## its bar spacing (m) and its number of gaps between bars: parallel lists in the order added.
var mins: PackedVector3Array = PackedVector3Array()
var maxs: PackedVector3Array = PackedVector3Array()
var surfaces: PackedInt32Array = PackedInt32Array()
var along_x: PackedByteArray = PackedByteArray()
var pitches: PackedFloat32Array = PackedFloat32Array()
var gaps: PackedInt32Array = PackedInt32Array()

var _indexed: bool = false
## The index: the plan corner of square (0, 0), its columns and rows, and each square's runs as one list
## (_cell_items[_cell_start[s] ..< _cell_start[s + 1]]).
var _origin: Vector2 = Vector2.ZERO
var _cols: int = 0
var _rows: int = 0
var _cell_start: PackedInt32Array = PackedInt32Array()
var _cell_items: PackedInt32Array = PackedInt32Array()

## The last _run_hit's way in: the axis whose face it crossed to meet the bar or rail (-1 when it starts inside one).
static var _axis: int = -1
## The last _enter's start came from the interval's own bound (not the window's).
static var _own: bool = false


func _init(cfg: RailingConfig = null) -> void:
	config = cfg if cfg != null else RailingConfig.new()


## Adds a run filling the box centred at `center` measuring `size`, made of `surface`; its length runs along its
## longer side on the floor.
func add(center: Vector3, size: Vector3, surface: RayHit.Surface = RayHit.Surface.METAL) -> void:
	var lo := center - size * 0.5
	var hi := center + size * 0.5
	var x := size.x >= size.z
	var length := size.x if x else size.z
	var bar := minf(config.bar_width, length)
	var count := maxi(1, roundi((length - bar) / config.bar_pitch))
	mins.append(lo)
	maxs.append(hi)
	surfaces.append(surface)
	along_x.append(1 if x else 0)
	pitches.append((length - bar) / count)
	gaps.append(count)
	_indexed = false


func size() -> int:
	return mins.size()


func is_empty() -> bool:
	return mins.is_empty()


## The first bar or rail the path from `origin` along unit `dir` meets within `length` m, into `hit` (its point, the
## face's normal, its share of `length` and its surface); false if it goes through every run's gaps, or meets none.
func first_bar(origin: Vector3, dir: Vector3, length: float, hit: RayHit) -> bool:
	if mins.is_empty() or not (length > 0.0):
		return false
	if not _indexed:
		_index()
	var end := origin + dir * length
	var lo := origin.min(end)
	var hi := origin.max(end)
	var best := INF
	var best_run := -1
	var best_axis := -1
	var c0 := clampi(floori((lo.x - _origin.x) / INDEX_CELL), 0, _cols - 1)
	var c1 := clampi(floori((hi.x - _origin.x) / INDEX_CELL), 0, _cols - 1)
	var r0 := clampi(floori((lo.z - _origin.y) / INDEX_CELL), 0, _rows - 1)
	var r1 := clampi(floori((hi.z - _origin.y) / INDEX_CELL), 0, _rows - 1)
	for r in range(r0, r1 + 1):
		for c in range(c0, c1 + 1):
			var s := r * _cols + c
			for k in range(_cell_start[s], _cell_start[s + 1]):
				var i := _cell_items[k]
				var t := _run_hit(i, origin, dir, minf(length, best))
				if t < best:
					best = t
					best_run = i
					best_axis = _axis
	if best_run < 0:
		return false
	hit.position = origin + dir * best
	hit.fraction = best / length
	hit.surface = surfaces[best_run] as RayHit.Surface
	if best_axis < 0:
		hit.normal = -dir
	else:
		var n := Vector3.ZERO
		n[best_axis] = -signf(dir[best_axis])
		hit.normal = n
	return true


## Run `i`'s bars and rails as boxes, appended to `out`: what MapLevel draws.
func parts(i: int, out: Array[AABB]) -> void:
	var lo := mins[i]
	var hi := maxs[i]
	var a := 0 if along_x[i] == 1 else 2
	var c := 2 - a
	var bar := minf(config.bar_width, hi[a] - lo[a])
	var depth := minf(config.bar_width, hi[c] - lo[c])
	var mid := (lo[c] + hi[c]) * 0.5
	for k in gaps[i] + 1:
		var p := lo
		p[a] = lo[a] + k * pitches[i]
		p[c] = mid - depth * 0.5
		var s := hi - lo
		s[a] = bar
		s[c] = depth
		out.append(AABB(p, s))
	var rail := minf(config.rail_height, hi.y - lo.y)
	out.append(AABB(Vector3(lo.x, hi.y - rail, lo.z), Vector3(hi.x - lo.x, rail, hi.z - lo.z)))
	var foot := lo.y + config.foot_gap
	if foot + rail < hi.y - rail:
		out.append(AABB(Vector3(lo.x, foot, lo.z), Vector3(hi.x - lo.x, rail, hi.z - lo.z)))


## How far along the path (m, from `o` along unit `d`, short of `reach`) it meets a bar or rail of run `i`, INF if it
## meets none; _axis says through which face.
func _run_hit(i: int, o: Vector3, d: Vector3, reach: float) -> float:
	var lo := mins[i]
	var hi := maxs[i]
	# The stretch of the path inside the run's box: t_in to t_out.
	var t_in := 0.0
	var t_out := reach
	var box_axis := -1
	for k in 3:
		if absf(d[k]) < PARALLEL:
			if o[k] < lo[k] or o[k] > hi[k]:
				return INF
			continue
		var t1 := (lo[k] - o[k]) / d[k]
		var t2 := (hi[k] - o[k]) / d[k]
		if t1 > t2:
			var swap := t1
			t1 = t2
			t2 = swap
		if t1 > t_in:
			t_in = t1
			box_axis = k
		t_out = minf(t_out, t2)
		if t_in > t_out:
			return INF
	var best := INF
	var axis := -1
	# The rails: bands across the whole run.
	var rail := minf(config.rail_height, hi.y - lo.y)
	var top := _enter(o.y, d.y, hi.y - rail, hi.y, t_in, t_out)
	if top < best:
		best = top
		axis = 1 if _own else box_axis
	var foot := lo.y + config.foot_gap
	if foot + rail < hi.y - rail:
		var low := _enter(o.y, d.y, foot, foot + rail, t_in, t_out)
		if low < best:
			best = low
			axis = 1 if _own else box_axis
	# The bars: where the path is within a bar's depth, the first bar along its way it overlaps.
	var a := 0 if along_x[i] == 1 else 2
	var c := 2 - a
	var half := minf(config.bar_width, hi[a] - lo[a]) * 0.5
	var half_depth := minf(config.bar_width, hi[c] - lo[c]) * 0.5
	var mid := (lo[c] + hi[c]) * 0.5
	var w_in := _enter(o[c], d[c], mid - half_depth, mid + half_depth, t_in, minf(t_out, best))
	if w_in < INF:
		var w_axis := c if _own else box_axis
		var w_out := _leave(o[c], d[c], mid - half_depth, mid + half_depth, t_out)
		var first := lo[a] + half
		var pitch := pitches[i]
		var u := o[a] + d[a] * w_in
		var k := 0
		if d[a] >= 0.0:
			k = ceili((u - half - first) / pitch)
		else:
			k = floori((u + half - first) / pitch)
		k = clampi(k, 0, gaps[i])
		var centre := first + k * pitch
		var t := _enter(o[a], d[a], centre - half, centre + half, w_in, minf(w_out, minf(t_out, best)))
		if t < best:
			best = t
			axis = a if _own else w_axis
	_axis = axis
	return best


## The first t in [`t0`, `t1`] at which `o + d·t` lies in [`a`, `b`], INF if none; _own says whether that is where it
## crosses into the interval (rather than `t0`, already inside it).
static func _enter(o: float, d: float, a: float, b: float, t0: float, t1: float) -> float:
	_own = false
	if absf(d) < PARALLEL:
		return t0 if o >= a and o <= b and t0 <= t1 else INF
	var s := (a - o) / d
	var e := (b - o) / d
	if s > e:
		var swap := s
		s = e
		e = swap
	if s > t0:
		_own = true
	else:
		s = t0
	return s if s <= minf(e, t1) else INF


## The last t (no later than `t1`) at which `o + d·t` still lies in [`a`, `b`] (`t1` when it never leaves).
static func _leave(o: float, d: float, a: float, b: float, t1: float) -> float:
	if absf(d) < PARALLEL:
		return t1
	return minf(t1, maxf((a - o) / d, (b - o) / d))


## Files every run in each square its footprint covers.
func _index() -> void:
	_indexed = true
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for i in mins.size():
		lo = lo.min(Vector2(mins[i].x, mins[i].z))
		hi = hi.max(Vector2(maxs[i].x, maxs[i].z))
	_origin = lo
	_cols = maxi(1, ceili((hi.x - lo.x) / INDEX_CELL) + 1)
	_rows = maxi(1, ceili((hi.y - lo.y) / INDEX_CELL) + 1)
	var lists: Array[PackedInt32Array] = []
	lists.resize(_cols * _rows)
	for i in mins.size():
		var c0 := clampi(floori((mins[i].x - lo.x) / INDEX_CELL), 0, _cols - 1)
		var c1 := clampi(floori((maxs[i].x - lo.x) / INDEX_CELL), 0, _cols - 1)
		var r0 := clampi(floori((mins[i].z - lo.y) / INDEX_CELL), 0, _rows - 1)
		var r1 := clampi(floori((maxs[i].z - lo.y) / INDEX_CELL), 0, _rows - 1)
		for r in range(r0, r1 + 1):
			for c in range(c0, c1 + 1):
				lists[r * _cols + c].append(i)
	_cell_start = PackedInt32Array()
	_cell_items = PackedInt32Array()
	_cell_start.append(0)
	for l in lists:
		_cell_items.append_array(l)
		_cell_start.append(_cell_items.size())
