class_name SkylineSight
extends RefCounted
## Whether any player can see a skyline piece over the walls (owner, 2026-10-16, MS1: what no player can see is not
## built). A player's eye stands over every stand point: each lane's points, each spawn, and the corners and middle of
## each raised floor. A piece is seen when a straight line from one eye to one of its sample points passes through no
## block. Plain maths over the blocks' boxes (a ramp counts as its whole box), no physics, nothing kept per frame; the
## largest blocks are tried first, so a hidden line usually stops at the first wall it tries. A skyline piece already
## built hides what stands beyond it too (`add_box`: its solid boxes, SkylineShapes.hides_of), so a piece seen only
## past a nearer one is left out.

var _eyes: PackedVector3Array = PackedVector3Array()
var _lo: PackedVector3Array = PackedVector3Array()
var _hi: PackedVector3Array = PackedVector3Array()


## The eyes over `map`'s stand points, `eye_height` m up; a floor whose top is `raised_from` m or higher is raised,
## its corners taken `inset` m in.
static func of(map: MapData, eye_height: float, raised_from: float, inset: float) -> SkylineSight:
	var s := SkylineSight.new()
	for q in stands(map, raised_from, inset):
		s._eyes.append(q + Vector3.UP * eye_height)
	var lowest := INF
	for e in s._eyes:
		lowest = minf(lowest, e.y)
	# only a block reaching above the lowest eye can cut a line that rises from it (a line falling to a point lower
	# than the eye may pass a low block it would have met: that only builds a piece it need not)
	var blockers: Array[MapData.Block] = []
	for b in map.blocks:
		if b.center.y + b.size.y * 0.5 > lowest:
			blockers.append(b)
	blockers.sort_custom(func(a: MapData.Block, b: MapData.Block) -> bool:
		return maxf(a.size.x, a.size.z) * a.size.y > maxf(b.size.x, b.size.z) * b.size.y)
	for b in blockers:
		s._lo.append(b.center - b.size * 0.5)
		s._hi.append(b.center + b.size * 0.5)
	return s


## Where a player can stand to look: every lane point, every spawn and each raised floor's middle and inset corners
## (on its top).
static func stands(map: MapData, raised_from: float, inset: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for lane in map.lanes:
		out.append_array(lane)
	for e in map.ends:
		for spot in e.spawns:
			out.append(spot.position)
	for b in map.blocks:
		var top := b.center.y + b.size.y * 0.5
		if b.kind != &"floor" or top < raised_from:
			continue
		var half := Vector2(maxf(b.size.x * 0.5 - inset, 0.0), maxf(b.size.z * 0.5 - inset, 0.0))
		out.append(Vector3(b.center.x, top, b.center.z))
		for i in 4:
			out.append(Vector3(b.center.x + half.x * (1.0 if i & 1 else -1.0), top,
					b.center.z + half.y * (1.0 if i & 2 else -1.0)))
	return out


## Adds the box `lo`..`hi` as something no sight line passes through (a built skyline piece's solid part), tried
## after the map's blocks.
func add_box(lo: Vector3, hi: Vector3) -> void:
	_lo.append(lo)
	_hi.append(hi)


## The eyes it looks from.
func eyes() -> PackedVector3Array:
	return _eyes


## True if some eye sees one of `samples` with no block in the way.
func sees(samples: PackedVector3Array) -> bool:
	for e in _eyes:
		for q in samples:
			if clear(e, q):
				return true
	return false


## True if no block cuts the line from `from` to `to`; a line only grazing a face is not cut.
func clear(from: Vector3, to: Vector3) -> bool:
	var d := to - from
	for i in _lo.size():
		if _cuts(from, d, _lo[i], _hi[i]):
			return false
	return true


## The slab test: whether the segment `from` + t `d` (t in 0..1) passes inside the box `lo`..`hi`.
static func _cuts(from: Vector3, d: Vector3, lo: Vector3, hi: Vector3) -> bool:
	var t0 := 0.0
	var t1 := 1.0
	for axis in 3:
		var o := from[axis]
		var v := d[axis]
		if absf(v) < 1e-9:
			if o <= lo[axis] or o >= hi[axis]:
				return false
			continue
		var ta := (lo[axis] - o) / v
		var tb := (hi[axis] - o) / v
		t0 = maxf(t0, minf(ta, tb))
		t1 = minf(t1, maxf(ta, tb))
		if t0 >= t1:
			return false
	return true
