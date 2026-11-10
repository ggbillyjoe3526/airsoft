class_name WearMark
extends RefCounted
## A worn mark on a field's floor (WM1; `dressing.wearMarks` in the map file): an oil stain, a pair of tyre tracks or a
## trail of boot prints, drawn by WearMarks as decals over the floor's own procedural wear (SL1, SL2), which they add to
## rather than repeat: the floor's wear is broad grime and dust, these are the marks of something that was there.
## Scenery only: nothing reads them but WearMarks.

const OIL := &"oil"
const TYRES := &"tyres"
const BOOTS := &"boots"
const KINDS: Array[StringName] = [OIL, TYRES, BOOTS]
## The longest a mark may be (m) and the most it may bend (degrees), so a typo can't spread one over a map.
const MOST_LENGTH := 30.0
const MOST_BEND := 180.0

var kind: StringName = OIL
## Where it starts (a stain's centre) on the floor, x and z; and the floor's height there, NAN to take the ground's.
var at: Vector2 = Vector2.ZERO
var y: float = NAN
## Its heading (degrees, 0 towards -z, turning towards +x): the way the tracks or the trail run.
var yaw: float = 0.0
## A stain's size across (m), or the tracks' or the trail's length (m).
var length: float = 1.0
## How far (degrees) the tracks or the trail turn by their end, evenly along them (a stain ignores it).
var bend: float = 0.0
## Muddy prints (boots) or tracks: the mud colour instead of the dust or the rubber.
var mud: bool = false


## The marks in a map file's `dressing` (none for a file without them), each warned of and left out when it isn't one.
static func read(dressing: Variant, warnings: Array[String]) -> Array[WearMark]:
	var out: Array[WearMark] = []
	var raw: Variant = (dressing as Dictionary).get("wearMarks", []) if dressing is Dictionary else []
	if not raw is Array:
		warnings.append("dressing.wearMarks is not a list; no marks")
		return out
	for i in (raw as Array).size():
		var item: Variant = (raw as Array)[i]
		var d: Dictionary = item if item is Dictionary else {}
		var m := WearMark.new()
		m.kind = StringName(str(d.get("kind", "")))
		m.at = Vector2(_number(d.get("x"), NAN), _number(d.get("z"), NAN))
		m.y = _number(d.get("y"), NAN)
		m.yaw = _number(d.get("yaw"), 0.0)
		m.length = _number(d.get("length"), NAN)
		m.bend = _number(d.get("bend"), 0.0)
		var mud: Variant = d.get("mud", false)
		if not KINDS.has(m.kind) or is_nan(m.at.x) or is_nan(m.at.y) or not (m.length > 0.0) \
				or m.length > MOST_LENGTH or absf(m.bend) > MOST_BEND or not mud is bool:
			warnings.append(("dressing.wearMarks %d needs a kind (oil, tyres, boots), x, z and a length over 0 up to %d m"
					+ " (yaw, bend up to %d degrees, y, mud true or false); left out") % [i, MOST_LENGTH, MOST_BEND])
			continue
		m.mud = mud
		out.append(m)
	return out


## The points (x, z) along the tracks or the trail, `steps` + 1 of them from its start to its end, turning `bend`
## evenly; a stain's one point is its centre.
func path(steps: int) -> PackedVector2Array:
	var points := PackedVector2Array([at])
	if kind == OIL or steps < 1:
		return points
	var step := length / steps
	var turn := deg_to_rad(bend) / steps
	var heading := deg_to_rad(yaw) + turn * 0.5
	var p := at
	for i in steps:
		p += Vector2(sin(heading), -cos(heading)) * step
		points.append(p)
		heading += turn
	return points


static func _number(raw: Variant, otherwise: float) -> float:
	return float(raw) if raw is float or raw is int else otherwise
