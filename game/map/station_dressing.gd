class_name StationDressing
extends RefCounted
## A map's station dress (MT3, Subway; `dressing.station` in its file, written by tools/subway/build_map.py): the
## rooms' air as boxes, each with its style (StationLook's floors, walls and ceilings), the platforms' edge strips and
## the track's centre lines. Plain data, look only: no collider, no nav cell. A map without `dressing.station` has none
## (null); a malformed zone, strip or track is left out with a warning.

## The zones are looked up in columns this many metres wide (x).
const COLUMN := 8.0
## A room's edge closer than this (m) to a face's top or bottom doesn't cut it.
const LEVEL_GAP := 0.05


## A room's air (or a slice of a ramp room's): any point inside it faces that room. `owns` marks a room whose blocks
## inside it are drawn in its style (a train's sides and car ends).
class Zone:
	extends RefCounted
	var style: StringName = &""
	var box: AABB = AABB()
	var owns: bool = false


## A strip laid on a floor: a finish over the rectangle `area` (x, z) at height `y`.
class Strip:
	extends RefCounted
	var finish: StringName = &""
	var area: Rect2 = Rect2()
	var y: float = 0.0


## A stretch of track: its centre line from `from` to `to` (x, z) on the ballast at height `y`.
class Track:
	extends RefCounted
	var from: Vector2 = Vector2.ZERO
	var to: Vector2 = Vector2.ZERO
	var y: float = 0.0


var zones: Array[Zone] = []
var strips: Array[Strip] = []
var tracks: Array[Track] = []
## Zone indices by column (floor(x / COLUMN)), in the file's order; built by `read`.
var _columns: Dictionary[int, PackedInt32Array] = {}


## The station dress of a map's `dressing`, or null when it names none.
static func read(dressing: Variant, warnings: Array[String]) -> StationDressing:
	var raw: Variant = (dressing as Dictionary).get("station") if dressing is Dictionary else null
	if raw == null:
		return null
	if not raw is Dictionary:
		warnings.append("dressing.station is not an object; drawn as greybox")
		return null
	var d: Dictionary = raw
	var out := StationDressing.new()
	var list: Variant = d.get("zones", [])
	for i in (list as Array).size() if list is Array else 0:
		var z := _zone((list as Array)[i])
		if z == null:
			warnings.append("dressing.station.zones %d needs a style and a box [x0, x1, y0, y1, z0, z1]; left out" % i)
			continue
		out.zones.append(z)
	var strips: Variant = d.get("strips", [])
	for i in (strips as Array).size() if strips is Array else 0:
		var s := _strip((strips as Array)[i])
		if s == null:
			warnings.append("dressing.station.strips %d needs a finish, x0, x1, z0, z1 and y; left out" % i)
			continue
		out.strips.append(s)
	var tracks: Variant = d.get("tracks", [])
	for i in (tracks as Array).size() if tracks is Array else 0:
		var t := _track((tracks as Array)[i])
		if t == null:
			warnings.append("dressing.station.tracks %d needs x0, x1, z0, z1 and y; left out" % i)
			continue
		out.tracks.append(t)
	out._index()
	return out


## The zone point `p` lies in (the first the file lists), or null.
func zone_at(p: Vector3) -> Zone:
	var column: PackedInt32Array = _columns.get(floori(p.x / COLUMN), PackedInt32Array())
	for i in column:
		if zones[i].box.has_point(p):
			return zones[i]
	return null


## The heights (y) where a zone touching `box` starts or ends strictly inside `box`'s height, low to high, each once:
## where a face spanning several rooms (a lift shaft's wall, every storey high) changes room.
func levels_across(box: AABB) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var lo := box.position.y
	var hi := box.end.y
	for c in range(floori(box.position.x / COLUMN), floori(box.end.x / COLUMN) + 1):
		for i: int in _columns.get(c, PackedInt32Array()):
			var zb := zones[i].box
			if not zb.intersects(box):
				continue
			for y: float in [zb.position.y, zb.end.y]:
				if y > lo + LEVEL_GAP and y < hi - LEVEL_GAP and not out.has(y):
					out.append(y)
	out.sort()
	return out


## The style of the room point `p` lies in, &"" in none.
func style_at(p: Vector3) -> StringName:
	var z := zone_at(p)
	return z.style if z != null else &""


## The style of the room owning block `b` (one whose air holds the block's centre and owns its blocks), else &"".
func owner_of(b: MapData.Block) -> StringName:
	var z := zone_at(b.center)
	return z.style if z != null and z.owns else &""


func _index() -> void:
	_columns.clear()
	for i in zones.size():
		var box := zones[i].box
		for c in range(floori(box.position.x / COLUMN), floori(box.end.x / COLUMN) + 1):
			if not _columns.has(c):
				_columns[c] = PackedInt32Array()
			_columns[c].append(i)


static func _zone(raw: Variant) -> Zone:
	if not raw is Dictionary:
		return null
	var d: Dictionary = raw
	var style: Variant = d.get("style")
	var box: Variant = d.get("box")
	if not style is String or (style as String).is_empty() or not box is Array or (box as Array).size() != 6:
		return null
	var v := PackedFloat64Array()
	for n: Variant in box:
		if not (n is float or n is int):
			return null
		v.append(float(n))
	if v[1] <= v[0] or v[3] <= v[2] or v[5] <= v[4]:
		return null
	var z := Zone.new()
	z.style = StringName(style)
	z.box = AABB(Vector3(v[0], v[2], v[4]), Vector3(v[1] - v[0], v[3] - v[2], v[5] - v[4]))
	z.owns = d.get("owns", false) == true
	return z


static func _strip(raw: Variant) -> Strip:
	var r := _rect(raw)
	if r.size == Vector2.ZERO:
		return null
	var finish: Variant = (raw as Dictionary).get("finish")
	if not finish is String or (finish as String).is_empty():
		return null
	var s := Strip.new()
	s.finish = StringName(finish)
	s.area = r
	s.y = float((raw as Dictionary)["y"])
	return s


static func _track(raw: Variant) -> Track:
	var r := _rect(raw)
	if r.size == Vector2.ZERO:
		return null
	var t := Track.new()
	var mid := r.position.y + r.size.y * 0.5
	t.from = Vector2(r.position.x, mid)
	t.to = Vector2(r.end.x, mid)
	t.y = float((raw as Dictionary)["y"])
	return t


## x0, x1, z0, z1 as a rectangle (x, z) with a y beside it; an empty one when malformed.
static func _rect(raw: Variant) -> Rect2:
	if not raw is Dictionary:
		return Rect2()
	var d: Dictionary = raw
	for k: String in ["x0", "x1", "z0", "z1", "y"]:
		if not (d.get(k) is float or d.get(k) is int):
			return Rect2()
	var lo := Vector2(float(d["x0"]), float(d["z0"]))
	var hi := Vector2(float(d["x1"]), float(d["z1"]))
	if hi.x <= lo.x or hi.y <= lo.y:
		return Rect2()
	return Rect2(lo, hi - lo)
