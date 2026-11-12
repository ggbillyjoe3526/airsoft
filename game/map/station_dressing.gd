class_name StationDressing
extends RefCounted
## A map's station dress (MT3, Subway; `dressing.station` in its file, written by tools/subway/build_map.py): the
## rooms' air as boxes, each with its style (StationLook's floors, walls and ceilings), the platforms' edge strips and
## painted words, the track's centre lines and the platform tunnels' vaults. Plain data, look only: no collider, no nav
## cell (a vault's colliders are the map's blocks). A map without `dressing.station` has none (null); a malformed zone,
## strip, words, track or vault is left out with a warning.

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


## Words painted on a floor (TB1: MIND THE GAP on a platform's coping): `text` in letters `height` m tall across
## `area` (x, z) at height `y`, one every `every` m along x, their tops facing `up` (-1 or 1 along z) so they read from
## the side facing away.
class Words:
	extends RefCounted
	var text: String = ""
	var area: Rect2 = Rect2()
	var y: float = 0.0
	var height: float = 0.0
	var every: float = 0.0
	var up: float = 1.0


## A platform tunnel's barrel vault (TB1): an arc over `area` (x along, z across), springing from both long sides at
## height `y` and rising `rise` m at its middle; its colliders (blocks) fill above the arc up to `thick` m over the
## crown and close its ends `thick` m deep. Drawn curved by StationSurface in place of those blocks.
class TunnelVault:
	extends RefCounted
	var area: Rect2 = Rect2()
	var y: float = 0.0
	var rise: float = 0.0
	var thick: float = 0.0

	## The arc's circle: its middle's z and y and its radius.
	func circle() -> Vector3:
		var half := area.size.y * 0.5
		var radius := (half * half + rise * rise) / (2.0 * rise)
		return Vector3(area.get_center().y, y + rise - radius, radius)

	## Half the angle (radians) the arc spans, from its middle to a springing.
	func half_angle() -> float:
		return asin(clampf(area.size.y * 0.5 / circle().z, 0.0, 1.0))

	## The arc's point (z, y) at angle `a` from its crown (positive towards +z).
	func point(a: float) -> Vector2:
		var c := circle()
		return Vector2(c.x + c.z * sin(a), c.y + c.z * cos(a))

	## The space its colliders fill, over its springing (a block inside it is drawn as the arc, not as itself).
	func lid() -> AABB:
		var lo := Vector3(area.position.x - thick, y, area.position.y) - Vector3.ONE * LEVEL_GAP
		var hi := Vector3(area.end.x + thick, y + rise + thick, area.end.y) + Vector3.ONE * LEVEL_GAP
		return AABB(lo, hi - lo)


## A look-only box laid on the shell (TB1: a frieze under a vault's springing, a cable run, a platform edge's face),
## drawn in `finish`.
class Trim:
	extends RefCounted
	var finish: StringName = &""
	var box: AABB = AABB()


var zones: Array[Zone] = []
var trims: Array[Trim] = []
var words: Array[Words] = []
var vaults: Array[TunnelVault] = []
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
	var said: Variant = d.get("words", [])
	for i in (said as Array).size() if said is Array else 0:
		var w := _words((said as Array)[i])
		if w == null:
			warnings.append("dressing.station.words %d needs text, x0, x1, z0, z1, y, height, every and up; left out" % i)
			continue
		out.words.append(w)
	var arcs: Variant = d.get("vaults", [])
	for i in (arcs as Array).size() if arcs is Array else 0:
		var v := _vault((arcs as Array)[i])
		if v == null:
			warnings.append("dressing.station.vaults %d needs x0, x1, z0, z1, y, rise and thick; left out" % i)
			continue
		out.vaults.append(v)
	var laid: Variant = d.get("trims", [])
	for i in (laid as Array).size() if laid is Array else 0:
		var t := _trim((laid as Array)[i])
		if t == null:
			warnings.append("dressing.station.trims %d needs a finish and a box [x0, x1, y0, y1, z0, z1]; left out" % i)
			continue
		out.trims.append(t)
	out._index()
	return out


## Whether block box `box` lies in a vault's colliders (drawn as its arc instead).
func in_vault(box: AABB) -> bool:
	for v in vaults:
		if v.lid().encloses(box):
			return true
	return false


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


static func _trim(raw: Variant) -> Trim:
	if not raw is Dictionary:
		return null
	var finish: Variant = (raw as Dictionary).get("finish")
	# A zone's reading of a finish and a box is a trim's too.
	var z := _zone({"style": finish, "box": (raw as Dictionary).get("box")})
	if z == null:
		return null
	var t := Trim.new()
	t.finish = z.style
	t.box = z.box
	return t


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


static func _words(raw: Variant) -> Words:
	var r := _rect(raw)
	if r.size == Vector2.ZERO:
		return null
	var d: Dictionary = raw
	var text: Variant = d.get("text")
	if not text is String or (text as String).strip_edges().is_empty() or not _numbers(d, ["height", "every", "up"]):
		return null
	var w := Words.new()
	w.text = text
	w.area = r
	w.y = float(d["y"])
	w.height = float(d["height"])
	w.every = float(d["every"])
	w.up = signf(float(d["up"]))
	if w.height <= 0.0 or w.every <= 0.0 or w.up == 0.0:
		return null
	return w


static func _vault(raw: Variant) -> TunnelVault:
	var r := _rect(raw)
	if r.size == Vector2.ZERO or not _numbers(raw as Dictionary, ["rise", "thick"]):
		return null
	var v := TunnelVault.new()
	v.area = r
	v.y = float((raw as Dictionary)["y"])
	v.rise = float((raw as Dictionary)["rise"])
	v.thick = float((raw as Dictionary)["thick"])
	if v.rise <= 0.0 or v.thick < 0.0:
		return null
	return v


static func _numbers(d: Dictionary, keys: Array[String]) -> bool:
	for k in keys:
		if not (d.get(k) is float or d.get(k) is int):
			return false
	return true


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
