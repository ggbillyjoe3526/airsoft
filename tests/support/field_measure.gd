class_name FieldMeasure
extends RefCounted
## One field's layout, measured (FC2; the browser game's content/mapLayout.ts and mapLayoutChecks.ts figures): what a
## player standing anywhere on it sees, and how far they walk. Built over the field's MapData, the NavGrid the bots walk
## and a WorldQuery: in the game's tests the field's MapLevel and its JoltQuery (the BBs' own ray, ramps as wedges),
## BoxWorld for a fault fixture. Each figure is measured the first time it is asked for, then kept. Allocates while it
## measures, so it is for tests, never play. Test-only (tests/ never ships); FieldChecks judges its figures.

## A square's floors are told apart by their height, in bands this tall (m): a storey is far more, a stair's step less.
const FLOOR_BAND := 1.5
## A sightline found on the stand points is stretched over every cell within this many spacings of each end, at most
## STRETCH_ROUNDS times (a grid of spacing s can miss about 2s of a line).
const STRETCH_REACH := 2.0
const STRETCH_ROUNDS := 4
## The middle, where its own cell is not walkable, is the nearest walkable ground within this (m).
const MIDDLE_REACH := 10.0
## Distances are sorted as whole millimetres packed above a point's index, so one native sort orders them.
const SORT_MM := 1000.0
const SORT_SLOTS := 1 << 24
## The stand points are bucketed in squares this wide (m), so a far end of the field is reached without every pair.
const BUCKET := 4.0


## A clear line between two standing eyes, and how long it is across the ground (m), floor point to floor point.
class Sightline:
	extends RefCounted
	var metres: float = 0.0
	var from: Vector3 = Vector3.ZERO
	var to: Vector3 = Vector3.ZERO

	func _init(d: float, a: Vector3, b: Vector3) -> void:
		metres = d
		from = a
		to = b


## A line from someone in end 0's spawn yard to someone in end 1's, and whether they were standing or crouched.
class YardLine:
	extends RefCounted
	var from: Vector3 = Vector3.ZERO
	var to: Vector3 = Vector3.ZERO
	var eye: String = ""

	func _init(a: Vector3, b: Vector3, posture: String) -> void:
		from = a
		to = b
		eye = posture


var map: MapData = null
var nav: NavGrid = null
var world: WorldQuery = null
## Where an eye is over the floor (m): a body stands rest_gap above it.
var stand_eye: float = 0.0
var crouch_eye: float = 0.0
## The walkable ground's extent (m, x then z), its area (m²) and the spacing its stand points are sampled at (m).
var size_x: float = 0.0
var size_z: float = 0.0
var area: float = 0.0
var spacing: float = 0.0

var _x0: float = INF
var _z0: float = INF
var _x1: float = -INF
var _z1: float = -INF
var _hit := RayHit.new()
var _route := PackedVector3Array()
var _measured: Dictionary[String, Variant] = {}


func _init(m: MapData, n: NavGrid, w: WorldQuery, body: BodyConfig) -> void:
	map = m
	nav = n
	world = w
	stand_eye = body.rest_gap + body.stand_eye_height
	crouch_eye = body.rest_gap + body.crouch_eye_height
	var count := 0
	for k in nav.node_count():
		if nav.walkable[k] != 1:
			continue
		count += 1
		var p := nav.node_position(k)
		_x0 = minf(_x0, p.x)
		_x1 = maxf(_x1, p.x)
		_z0 = minf(_z0, p.z)
		_z1 = maxf(_z1, p.z)
	area = count * nav.cell * nav.cell
	if count > 0:
		size_x = _x1 - _x0
		size_z = _z1 - _z0
	spacing = maxf(FieldStandard.SIGHT_SPACING, sqrt(area / FieldStandard.SIGHT_POINTS))


## Places a player can stand, one per `step` square on each floor (the first walkable node in it), as floor points.
func stand_points(step: float) -> PackedVector3Array:
	var per := maxi(1, roundi(step / nav.cell))
	var out := PackedVector3Array()
	var taken: Dictionary[Vector3i, bool] = {}
	for k in nav.node_count():
		if nav.walkable[k] != 1:
			continue
		var c := nav.node_cell[k]
		var i := c % nav.cols
		@warning_ignore("integer_division")
		var j := c / nav.cols
		@warning_ignore("integer_division")
		var key := Vector3i(i / per, j / per, roundi(nav.floor_y[k] / FLOOR_BAND))
		if taken.has(key):
			continue
		taken[key] = true
		out.append(nav.node_position(k))
	return out


## Whether an eye `eye_a` over floor point `a` has a clear line to one `eye_b` over `b`.
func sees(a: Vector3, b: Vector3, eye_a: float, eye_b: float) -> bool:
	var from := Vector3(a.x, a.y + eye_a, a.z)
	var to := Vector3(b.x, b.y + eye_b, b.z)
	if from.is_equal_approx(to):
		return true
	return not world.ray(from, to, _hit)


## The longest clear line from a standing eye to a standing eye between any two of `points` (across the ground), or
## null. Each point, taken far from the middle first so a long line turns up early, tries the points before it farthest
## first and stops at its first clear one (so each pair is tried once); a square of points no farther than the longest
## found is never looked at.
func longest_sightline(points: PackedVector3Array) -> Sightline:
	var n := points.size()
	var bx := maxi(1, ceili((_x1 - _x0) / BUCKET) + 1)
	var bz := maxi(1, ceili((_z1 - _z0) / BUCKET) + 1)
	var buckets: Array[PackedInt32Array] = []
	buckets.resize(bx * bz)
	var eyes := PackedVector3Array()
	var keys := PackedInt64Array()
	var cx := (_x0 + _x1) * 0.5
	var cz := (_z0 + _z1) * 0.5
	for i in n:
		eyes.append(points[i] + Vector3(0.0, stand_eye, 0.0))
		keys.append(_sort_key(Vector2(points[i].x - cx, points[i].z - cz).length(), i))
	keys.sort()
	var best: Sightline = null
	var least := 0.0
	var cand := PackedInt64Array()
	for r in range(n - 1, -1, -1):
		var i := keys[r] % SORT_SLOTS
		var a := points[i]
		cand.clear()
		for b in bx * bz:
			if buckets[b].is_empty():
				continue
			var lo_x := _x0 + (b % bx) * BUCKET
			@warning_ignore("integer_division")
			var lo_z := _z0 + (b / bx) * BUCKET
			var fx := maxf(absf(a.x - lo_x), absf(a.x - lo_x - BUCKET))
			var fz := maxf(absf(a.z - lo_z), absf(a.z - lo_z - BUCKET))
			if fx * fx + fz * fz <= least * least:
				continue
			for j in buckets[b]:
				var d := Vector2(a.x - points[j].x, a.z - points[j].z).length()
				if d > least:
					cand.append(_sort_key(d, j))
		cand.sort()
		for c in range(cand.size() - 1, -1, -1):
			var j := cand[c] % SORT_SLOTS
			if not world.ray(eyes[i], eyes[j], _hit):
				least = Vector2(a.x - points[j].x, a.z - points[j].z).length()
				best = Sightline.new(least, a, points[j])
				break
		buckets[_bucket_of(a, bx, bz)].append(i)
	return best


## `line` stretched to its full length: every walkable cell within `reach` of either end (on its floor) tried against
## every one near the other, longest first, the best clear pair the new line; until it stops growing, at most `rounds`.
func stretch(line: Sightline, reach: float, rounds: int) -> Sightline:
	var best := line
	for _round in rounds:
		var near_a := _cells_near(best.from, reach)
		var near_b := _cells_near(best.to, reach)
		var pairs := PackedInt64Array()
		var nb := near_b.size()
		assert(near_a.size() * nb < SORT_SLOTS, "stretch: too many pairs to pack in a sort key")
		for i in near_a.size():
			for j in nb:
				var d := Vector2(near_a[i].x - near_b[j].x, near_a[i].z - near_b[j].z).length()
				if d > best.metres:
					pairs.append(_sort_key(d, i * nb + j))
		pairs.sort()
		var found: Sightline = null
		for c in range(pairs.size() - 1, -1, -1):
			var ij := pairs[c] % SORT_SLOTS
			@warning_ignore("integer_division")
			var a := near_a[ij / nb]
			var b := near_b[ij % nb]
			if sees(a, b, stand_eye, stand_eye):
				found = Sightline.new(Vector2(a.x - b.x, a.z - b.z).length(), a, b)
				break
		if found == null:
			break
		best = found
	return best


## The field's longest standing sightline (found on the stand points, then stretched), or null on no ground.
func sightline() -> Sightline:
	if not _measured.has("sightline"):
		var coarse := longest_sightline(stand_points(spacing))
		_measured["sightline"] = stretch(coarse, STRETCH_REACH * spacing, STRETCH_ROUNDS) if coarse != null else null
	return _measured["sightline"]


## The places a player can stand within FieldStandard.SPAWN_YARD_RADIUS of any of `spawns` on their floor, on a
## FieldStandard.SIGHT_SPACING grid.
func spawn_yard(spawns: Array[SpawnPoint]) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p in stand_points(FieldStandard.SIGHT_SPACING):
		for s in spawns:
			if Vector2(p.x - s.position.x, p.z - s.position.z).length() <= FieldStandard.SPAWN_YARD_RADIUS \
					and absf(p.y - s.position.y) < FLOOR_BAND:
				out.append(p)
				break
	return out


## The first line found from end 0's spawn yard into end 1's, standing or crouched; null when there is none.
func spawns_seen() -> YardLine:
	if not _measured.has("spawns_seen"):
		var west := spawn_yard(map.ends[0].spawns)
		var east := spawn_yard(map.ends[1].spawns)
		var seen: YardLine = null
		for posture: String in ["standing", "crouched"]:
			var eye := stand_eye if posture == "standing" else crouch_eye
			for a in west:
				for b in east:
					if sees(a, b, eye, eye):
						seen = YardLine.new(a, b, posture)
						break
				if seen != null:
					break
			if seen != null:
				break
		_measured["spawns_seen"] = seen
	return _measured["spawns_seen"]


## The length of the walk on foot from `a` to `b` (m): NavGrid.find_route's legs from `a`, the walk a bot takes; INF
## where there is no route or it stops more than the route snap short of `b`.
func walk(a: Vector3, b: Vector3) -> float:
	if not nav.find_route(a, b, _route):
		return INF
	var last := _route[_route.size() - 1] if not _route.is_empty() else a
	if Vector2(last.x - b.x, last.z - b.z).length() >= nav.snap:
		return INF
	var metres := 0.0
	var here := a
	for p in _route:
		metres += here.distance_to(p)
		here = p
	return metres


## The centre of the walkable ground's bounds, on the lowest floor there (the street, not a balcony over it), or the
## nearest walkable ground to it; where that is ground nobody reaches on foot (a garden behind a shut gate, ST1), the
## nearest ground the first spawn of end 0 reaches.
func middle() -> Vector3:
	if not _measured.has("middle"):
		var cx := (_x0 + _x1) * 0.5
		var cz := (_z0 + _z1) * 0.5
		var lowest := nav.node_at(Vector3(cx, -INF, cz))
		var ground := lowest
		if lowest < 0 or nav.walkable[lowest] != 1:
			var y := nav.floor_y[lowest] if lowest >= 0 else 0.0
			ground = nav.nearest_walkable(Vector3(cx, y, cz), MIDDLE_REACH)
		var from := _spawn_node()
		if ground >= 0 and from >= 0 and not nav.linked(from, ground):
			ground = _nearest_linked(from, Vector3(cx, nav.floor_y[ground], cz))
		_measured["middle"] = nav.node_position(ground) if ground >= 0 else Vector3(cx, 0.0, cz)
	return _measured["middle"]


## The nav node under end 0's first spawn, or -1.
func _spawn_node() -> int:
	if map.ends.is_empty() or map.ends[0].spawns.is_empty():
		return -1
	var p := map.ends[0].spawns[0].position
	var k := nav.node_at(p)
	return k if k >= 0 and nav.walkable[k] == 1 else nav.nearest_walkable(p, MIDDLE_REACH)


## The walkable node nearest `p` on the plan that node `from` reaches on foot, or -1.
func _nearest_linked(from: int, p: Vector3) -> int:
	var best := -1
	var best_d := INF
	for k in nav.node_count():
		if nav.walkable[k] != 1 or not nav.linked(from, k):
			continue
		var q := nav.node_position(k)
		var d := Vector2(q.x - p.x, q.z - p.z).length_squared() + absf(q.y - p.y)
		if d < best_d:
			best_d = d
			best = k
	return best


## Each end's walks from its spawns to `p`, spawn by spawn (m, INF where there is no way).
func walks_to(p: Vector3) -> Array[PackedFloat64Array]:
	var out: Array[PackedFloat64Array] = []
	for end in map.ends:
		var row := PackedFloat64Array()
		for s in end.spawns:
			row.append(walk(s.position, p))
		out.append(row)
	return out


## Each end's walks from its spawns to the middle.
func middle_walks() -> Array[PackedFloat64Array]:
	if not _measured.has("middle_walks"):
		_measured["middle_walks"] = walks_to(middle())
	return _measured["middle_walks"]


## Each end's walks from its spawns to the flag (end 0 attacks); empty on a field without one.
func flag_walks() -> Array[PackedFloat64Array]:
	if not _measured.has("flag_walks"):
		var none: Array[PackedFloat64Array] = []
		_measured["flag_walks"] = walks_to(map.pole) if map.has_pole else none
	return _measured["flag_walks"]


## Each end's walks from its spawns to the overtime flag (OV1); empty on a field without one.
func overtime_walks() -> Array[PackedFloat64Array]:
	if not _measured.has("overtime_walks"):
		var none: Array[PackedFloat64Array] = []
		_measured["overtime_walks"] = walks_to(map.overtime_flag) if map.has_overtime_flag else none
	return _measured["overtime_walks"]


## Whether a standing eye in the attackers' (end 0) spawn yard sees standing eye height over the flag's foot.
func flag_seen() -> bool:
	if not _measured.has("flag_seen"):
		var seen := false
		if map.has_pole:
			for p in spawn_yard(map.ends[0].spawns):
				if sees(p, map.pole, stand_eye, stand_eye):
					seen = true
					break
		_measured["flag_seen"] = seen
	return _measured["flag_seen"]


## Every figure measured, in a line for the record and the test's log.
func summary() -> String:
	var line := sightline()
	var seen := spawns_seen()
	var mw := middle_walks()
	var out := "walkable %s x %s m, %s m², spacing %s m; %d lanes" % [FieldChecks.num(size_x, 1),
			FieldChecks.num(size_z, 1), FieldChecks.num(area, 0), FieldChecks.num(spacing), map.lanes.size()]
	if line != null:
		out += "; sightline %s m from %s to %s" % [FieldChecks.num(line.metres, 1), FieldChecks.at(line.from),
				FieldChecks.at(line.to)]
	out += "; spawn yards %s" % ("seen %s from %s to %s" % [seen.eye, FieldChecks.at(seen.from),
			FieldChecks.at(seen.to)] if seen != null else "unseen")
	out += "; middle %s, walks %s and %s m" % [FieldChecks.at(middle()), FieldChecks.num(mean(mw[0]), 1),
			FieldChecks.num(mean(mw[1]), 1)]
	if map.has_pole:
		var fw := flag_walks()
		out += "; flag walks %s and %s m (%s times), %s" % [FieldChecks.num(mean(fw[0]), 1),
				FieldChecks.num(mean(fw[1]), 1), FieldChecks.num(mean(fw[0]) / mean(fw[1])),
				"seen" if flag_seen() else "unseen"]
	if map.has_overtime_flag:
		var ow := overtime_walks()
		out += "; overtime flag %s, walks %s and %s m" % [FieldChecks.at(map.overtime_flag),
				FieldChecks.num(mean(ow[0]), 1), FieldChecks.num(mean(ow[1]), 1)]
	return out


## The mean of `walks` (INF if any is, or there are none).
static func mean(walks: PackedFloat64Array) -> float:
	if walks.is_empty():
		return INF
	var total := 0.0
	for w in walks:
		total += w
	return total / walks.size()


## Every walkable cell within `reach` of `p` on its floor, one per cell and floor band, as floor points.
func _cells_near(p: Vector3, reach: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var i0 := maxi(0, floori((p.x - reach - nav.min_x) / nav.cell))
	var i1 := mini(nav.cols - 1, floori((p.x + reach - nav.min_x) / nav.cell))
	var j0 := maxi(0, floori((p.z - reach - nav.min_z) / nav.cell))
	var j1 := mini(nav.rows - 1, floori((p.z + reach - nav.min_z) / nav.cell))
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var c := j * nav.cols + i
			var bands := PackedInt32Array()
			for k in range(nav.cell_start[c], nav.cell_start[c + 1]):
				if nav.walkable[k] != 1:
					continue
				var band := roundi(nav.floor_y[k] / FLOOR_BAND)
				if bands.has(band):
					continue
				bands.append(band)
				var q := nav.node_position(k)
				if absf(q.x - p.x) <= reach and absf(q.z - p.z) <= reach and absf(q.y - p.y) < FLOOR_BAND:
					out.append(q)
	return out


## The bucket point `p` falls in, of a grid `bx` by `bz` from the ground's corner.
func _bucket_of(p: Vector3, bx: int, bz: int) -> int:
	var i := clampi(floori((p.x - _x0) / BUCKET), 0, bx - 1)
	var j := clampi(floori((p.z - _z0) / BUCKET), 0, bz - 1)
	return j * bx + i


## Distance `d` (m) and index `i` as one sortable integer: whole millimetres above the index.
static func _sort_key(d: float, i: int) -> int:
	return roundi(d * SORT_MM) * SORT_SLOTS + i
