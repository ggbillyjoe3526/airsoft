class_name TrainDressing
extends RefCounted
## A train standing in a station (SM1; `dressing.trains` in the map file, tools/subway/build_map.py): the box its
## room's walls, slabs and car ends fill, its cars and its open gangways, drawn by TrainView in Subway's train models
## (tools/blender/maps/train.py) instead of StationSurface's painted boxes. Look only: the boxes are still what BBs,
## bodies and the bots meet.

## What can stand at a car's end: a cab front, its door shut or open; a blank car end, its outside drawn too where the
## train stands uncoupled; or nothing of the car's own (the open gangway to the next car, drawn at its joint).
const CAB := &"cab"
const CAB_OPEN := &"cab_open"
const BLANK := &"blank"
const OUTER := &"outer"
const GANGWAY := &"gangway"
const ENDS: Array[StringName] = [CAB, CAB_OPEN, BLANK, OUTER, GANGWAY]
## The door holes along each side of a car.
const SLOTS := 4
## A floor whose top lies more than this under the cars' floor is the track bed in the open space under a train end
## (the bogie's pocket, tools/subway/layout.py UNDER_ENDS), left to the station to draw.
const BED_DROP := 0.5


## One car: its middle on its floor, its turn and doors and ends.
class Car:
	extends RefCounted
	var middle: Vector3 = Vector3.ZERO
	## Turned a half turn about up (its models' platform side, +z, faces -z).
	var turned: bool = false
	## The platform side's open door holes, by slot in the models' own order along x (0 to SLOTS - 1).
	var open: PackedInt32Array = PackedInt32Array()
	## What stands at its own -x end and its +x end (ENDS).
	var ends: Array[StringName] = [GANGWAY, GANGWAY]


## The box its walls, slabs and car ends fill.
var box: AABB = AABB()
var cars: Array[Car] = []
## Each open gangway's joint, on the floor at the train's middle line.
var gangways: PackedVector3Array = PackedVector3Array()


## The trains in a map file's `dressing` (none for a file without them), each warned of and left out when it isn't one.
static func read(dressing: Variant, warnings: Array[String]) -> Array[TrainDressing]:
	var out: Array[TrainDressing] = []
	var raw: Variant = (dressing as Dictionary).get("trains", []) if dressing is Dictionary else []
	if not raw is Array:
		warnings.append("dressing.trains is not a list; no trains")
		return out
	for i in (raw as Array).size():
		var item: Variant = (raw as Array)[i]
		var t := _train(item if item is Dictionary else {})
		if t == null:
			warnings.append(("dressing.trains %d needs a box [x0, x1, y0, y1, z0, z1], cars (x, y, z, turn 0 or 1, open"
					+ " slots under %d, two ends of %s) and gangways (x, y, z); left out") % [i, SLOTS, ENDS])
			continue
		out.append(t)
	return out


## Whether block `b` is one of this train's walls, slabs, car ends or window glass (a wall, floor, container or glass
## block inside its box, but not the track bed under an end), so its models draw it.
func holds(b: MapData.Block) -> bool:
	if b.kind != &"wall" and b.kind != &"floor" and b.kind != &"container" and b.kind != &"glass":
		return false
	var grown := box.grow(0.02)
	if not (grown.has_point(b.center - b.size * 0.5) and grown.has_point(b.center + b.size * 0.5)):
		return false
	return b.kind != &"floor" or cars.is_empty() or b.center.y + b.size.y * 0.5 >= _floor_y() - BED_DROP


## The lowest car floor.
func _floor_y() -> float:
	var y := INF
	for c in cars:
		y = minf(y, c.middle.y)
	return y


static func _train(d: Dictionary) -> TrainDressing:
	var b: Variant = d.get("box")
	if not b is Array or (b as Array).size() != 6 or not (b as Array).all(func(v: Variant) -> bool:
			return v is float or v is int):
		return null
	var nums: Array = b
	var lo := Vector3(float(nums[0]), float(nums[2]), float(nums[4]))
	var hi := Vector3(float(nums[1]), float(nums[3]), float(nums[5]))
	if not (hi.x > lo.x and hi.y > lo.y and hi.z > lo.z):
		return null
	var t := TrainDressing.new()
	t.box = AABB(lo, hi - lo)
	var cars: Variant = d.get("cars", [])
	var joints: Variant = d.get("gangways", [])
	if not cars is Array or not joints is Array:
		return null
	for c: Variant in cars:
		var car := _car(c if c is Dictionary else {})
		if car == null:
			return null
		t.cars.append(car)
	for j: Variant in joints:
		var at := _point(j if j is Dictionary else {})
		if is_nan(at.x):
			return null
		t.gangways.append(at)
	return t


static func _car(d: Dictionary) -> Car:
	var at := _point(d)
	var turn: Variant = d.get("turn", 0)
	var open: Variant = d.get("open", [])
	var ends: Variant = d.get("ends", [])
	if is_nan(at.x) or not (turn is int or turn is float) or not open is Array or not ends is Array \
			or (ends as Array).size() != 2:
		return null
	var car := Car.new()
	car.middle = at
	car.turned = int(turn) == 1
	for s: Variant in open:
		if not (s is int or s is float) or int(s) < 0 or int(s) >= SLOTS:
			return null
		car.open.append(int(s))
	for k in 2:
		var e := StringName(str((ends as Array)[k]))
		if not ENDS.has(e):
			return null
		car.ends[k] = e
	return car


## A point's x, y and z, or NAN in x when it has none.
static func _point(d: Dictionary) -> Vector3:
	var v := [d.get("x"), d.get("y"), d.get("z")]
	for n: Variant in v:
		if not (n is float or n is int):
			return Vector3(NAN, 0.0, 0.0)
	return Vector3(float(v[0]), float(v[1]), float(v[2]))
