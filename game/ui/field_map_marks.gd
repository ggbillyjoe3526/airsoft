class_name FieldMapMarks
extends RefCounted
## What the full-screen map marks on a field that never moves (FM2), read once a match from its MapData: the named
## areas' words, the flags' spots, Elimination's overtime flag's spot, each end's start and dead zone, and the doors.
## Plain data in world metres (x, z); FieldMapOverlay puts them on the screen. Also the pure rule that lays out words
## so none covers another.

## One named area's words over the map: the name, where (the world's x, z: the middle of its biggest box), the feet
## heights it holds, its biggest box (m²) and all its boxes (m²: which names win room first).
class AreaWords:
	extends RefCounted
	var name: String = ""
	var at: Vector2 = Vector2.ZERO
	var floor_from: float = -INF
	var floor_to: float = INF
	var box: float = 0.0
	var total: float = 0.0


var words: Array[AreaWords] = []
## The flags' spots (x, z), flag A first, as the file has them (Flag.LETTERS); empty on a map without.
var flags: PackedVector2Array = PackedVector2Array()
var has_overtime: bool = false
var overtime: Vector2 = Vector2.ZERO
## Each end's start (round its spawns, `pad` m out) and dead zone (round its spots, as far out), end 0 first; a zero
## box for an end without any.
var starts: Array[Rect2] = []
var dead_zones: Array[Rect2] = []
## Each door's doorway as a line across it (from, to; x, z), two points a door.
var doors: PackedVector2Array = PackedVector2Array()


## The marks of `map`, its zones `pad` m round their spots.
static func of(map: MapData, pad: float) -> FieldMapMarks:
	var m := FieldMapMarks.new()
	m.words = areas_of(map.areas)
	for p in map.poles:
		m.flags.append(Vector2(p.x, p.z))
	m.has_overtime = map.has_overtime_flag
	m.overtime = Vector2(map.overtime_flag.x, map.overtime_flag.z)
	for e in map.ends:
		m.starts.append(_round(e.spawns, pad))
		m.dead_zones.append(_round(e.dead_zone, pad))
	for d in map.doors:
		var c := Vector2(d.center.x, d.center.z)
		var along := Vector2(d.size.x * 0.5, 0.0) if d.size.x >= d.size.z else Vector2(0.0, d.size.z * 0.5)
		m.doors.append(c - along)
		m.doors.append(c + along)
	return m


## The words for `areas`: one for each name on each band of floors, over the biggest of its boxes, biggest name first
## (by all its boxes).
static func areas_of(areas: Array[MapAreas.Area]) -> Array[AreaWords]:
	var out: Array[AreaWords] = []
	for a in areas:
		var box := (a.x1 - a.x0) * (a.z1 - a.z0)
		var name := a.name.to_upper()
		var same: AreaWords = null
		for w in out:
			if w.name == name and w.floor_from == a.floor_from and w.floor_to == a.floor_to:
				same = w
				break
		if same == null:
			same = AreaWords.new()
			same.name = name
			same.floor_from = a.floor_from
			same.floor_to = a.floor_to
			out.append(same)
		same.total += box
		if box <= same.box:
			continue
		same.box = box
		same.at = Vector2((a.x0 + a.x1) * 0.5, (a.z0 + a.z1) * 0.5)
	out.sort_custom(func(a: AreaWords, b: AreaWords) -> bool: return a.total > b.total)
	return out


## Lays out words: each of `wants` (a word's box on the screen where it would sit, in the order that wins room) goes
## there, or just above or below it, or half its width to either side, or twice as far above or below, wherever it
## keeps `room` px clear of every word placed before it and of `blocked`, slid inside `bounds`; with no such place it is
## left out (a zero box). Returns where each went.
static func lay_out(wants: Array[Rect2], blocked: Array[Rect2], bounds: Rect2, room: float) -> Array[Rect2]:
	var placed: Array[Rect2] = []
	var out: Array[Rect2] = []
	for want in wants:
		var step_y := want.size.y + room
		var step_x := want.size.x * 0.5 + room
		var tries: Array[Vector2] = [Vector2.ZERO, Vector2(0.0, -step_y), Vector2(0.0, step_y), Vector2(-step_x, 0.0),
				Vector2(step_x, 0.0), Vector2(0.0, -step_y * 2.0), Vector2(0.0, step_y * 2.0)]
		var got := Rect2()
		for t in tries:
			var r := _inside(Rect2(want.position + t, want.size), bounds)
			if _clear(r.grow(room), placed) and _clear(r.grow(room), blocked):
				got = r
				break
		if got.has_area():
			placed.append(got)
		out.append(got)
	return out


## `r` slid inside `bounds` (as far as it fits).
static func _inside(r: Rect2, bounds: Rect2) -> Rect2:
	var p := r.position.clamp(bounds.position, (bounds.end - r.size).max(bounds.position))
	return Rect2(p, r.size)


static func _clear(r: Rect2, others: Array[Rect2]) -> bool:
	for o in others:
		if o.has_area() and r.intersects(o):
			return false
	return true


## The box round `spots` (x, z), `pad` m out; a zero box for none.
static func _round(spots: Array[SpawnPoint], pad: float) -> Rect2:
	if spots.is_empty():
		return Rect2()
	var r := Rect2(Vector2(spots[0].position.x, spots[0].position.z), Vector2.ZERO)
	for s in spots:
		r = r.expand(Vector2(s.position.x, s.position.z))
	return r.grow(pad)
