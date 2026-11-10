class_name Water
extends RefCounted
## A map's shallow streams (WS1, Woodland's stream in its old dry bed): each a line of points along its middle, every
## point the water's surface there (x, level, z), and a half width either side of the line. Over the line, out to
## the half width, ground lower than the level is under water; the banks rise out of it of themselves. No collider and
## no ray surface: people wade through it (Movement: slower), every stride splashes (Footsteps: heard further, walking
## and crouched too), a BB landing in it lands on the bed and shows and sounds as water (BBStep), and the bots' route
## search prices a step in it (NavGridBuilder: they take a dry crossing where one is near). The simulation gets it
## through WorldQuery.water (Contracts 4); MapData reads it from the map's `water` list; WaterView draws it. Queries
## allocate nothing.

## A point less deep than this (m) under the surface is dry: a damp rim, not water to wade.
const MIN_DEPTH := 0.02

## Every stream's points one after another (x, level, z); stream s is points _start[s] ..< _start[s + 1].
var _points: PackedVector3Array = PackedVector3Array()
var _start: PackedInt32Array = PackedInt32Array([0])
## Each stream's half width (m) and its plan bounds grown by it, for a quick miss.
var _halves: PackedFloat32Array = PackedFloat32Array()
var _bounds: Array[Rect2] = []


## Adds a stream along `points` (x, level, z: at least two), `half_width` m either side of its line; false, and none
## added, when it has under two points or no width.
func add(points: PackedVector3Array, half_width: float) -> bool:
	if points.size() < 2 or half_width <= 0.0:
		return false
	var r := Rect2(points[0].x, points[0].z, 0.0, 0.0)
	for p: Vector3 in points:
		_points.append(p)
		r = r.expand(Vector2(p.x, p.z))
	_start.append(_points.size())
	_halves.append(half_width)
	_bounds.append(r.grow(half_width))
	return true


## How many streams it has.
func size() -> int:
	return _halves.size()


func is_empty() -> bool:
	return _halves.is_empty()


## Stream `s`'s points (x, level, z) and its half width, for drawing it.
func points_of(s: int) -> PackedVector3Array:
	return _points.slice(_start[s], _start[s + 1])


func half_width_of(s: int) -> float:
	return _halves[s]


## The water's surface over (x, z), or NAN where no stream reaches: the level at the nearest point of the nearest
## stream's line within its half width, between that segment's two points' levels.
func level_at(x: float, z: float) -> float:
	var best := INF
	var level := NAN
	for s in _halves.size():
		var half := _halves[s]
		var r := _bounds[s]
		if x < r.position.x or z < r.position.y or x > r.end.x or z > r.end.y:
			continue
		for i in range(_start[s], _start[s + 1] - 1):
			var a := _points[i]
			var b := _points[i + 1]
			var dx := b.x - a.x
			var dz := b.z - a.z
			var len2 := dx * dx + dz * dz
			var t := 0.0 if len2 <= 0.0 else clampf(((x - a.x) * dx + (z - a.z) * dz) / len2, 0.0, 1.0)
			var ox := a.x + dx * t - x
			var oz := a.z + dz * t - z
			var d2 := ox * ox + oz * oz
			if d2 <= half * half and d2 < best:
				best = d2
				level = a.y + (b.y - a.y) * t
	return level


## How deep (m) a point stands under the water: the level over it less its height, 0 out of the water or less than
## MIN_DEPTH under it.
func depth_at(p: Vector3) -> float:
	if _halves.is_empty():
		return 0.0
	var level := level_at(p.x, p.z)
	if is_nan(level):
		return 0.0
	var depth := level - p.y
	return depth if depth >= MIN_DEPTH else 0.0
