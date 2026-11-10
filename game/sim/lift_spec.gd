class_name LiftSpec
extends RefCounted
## One lift (MT2; `lifts` in a map's file, MapData.lifts): the well its car runs in (a box on the ground, inside the
## shaft's walls), the door in one face of the well's wall (its span along that face, its height, the wall's depth),
## the floor heights it stops at, lowest first, each stop's name, and the stop its car waits at as each round starts.
## The car is a floor and a roof the level moves (WorldQuery.set_lift_car); each stop's doorway is shut by a leaf the
## level switches (WorldQuery.set_lift_door). Pure geometry: where the car, the doorways, the buttons and the landings
## are. Allocates nothing but the Vector3 it returns.

## The faces a door may be in, as the file names them: n (-z), s (+z), w (-x), e (+x).
const FACES: Array[String] = ["n", "s", "w", "e"]

var name: String = ""
## The well, on the ground: x from well.position.x to well.end.x, z from well.position.y to well.end.y.
var well: Rect2 = Rect2()
## The door's face, outwards (level): (0, -1) for n, (0, 1) for s, (-1, 0) for w, (1, 0) for e.
var out: Vector2 = Vector2(0.0, -1.0)
## The door's span along its face (x for n and s, z for w and e), its height and the wall's depth it goes through (m).
var door_from: float = 0.0
var door_to: float = 0.0
var door_height: float = 2.1
var door_depth: float = 0.3
## Each stop's floor height (the car's floor's top there), lowest first, and its name.
var stops: PackedFloat32Array = PackedFloat32Array()
var stop_names: PackedStringArray = PackedStringArray()
## The stop the car waits at, doors open, as each round starts.
var start: int = 0


## How many stops it has.
func stop_count() -> int:
	return stops.size()


## Whether the door's face runs along x (n or s).
func along_x() -> bool:
	return out.x == 0.0


## The well's edge on the door's face (its z for n and s, its x for w and e).
func face_at() -> float:
	if along_x():
		return well.position.y if out.y < 0.0 else well.end.y
	return well.position.x if out.x < 0.0 else well.end.x


## A point `along` the door's face (x or z), `off` m out from the well's edge (negative: into the car), `y` high.
func on_face(along: float, off: float, y: float) -> Vector3:
	var at := face_at()
	if along_x():
		return Vector3(along, y, at + out.y * off)
	return Vector3(at + out.x * off, y, along)


## The doorway at stop `k`: its leaf's box, the wall's whole depth through, from the stop's floor up (centre, size).
func door_center(k: int) -> Vector3:
	return on_face((door_from + door_to) * 0.5, door_depth * 0.5, stops[k] + door_height * 0.5)


func door_size() -> Vector3:
	var w := door_to - door_from
	return Vector3(w, door_height, door_depth) if along_x() else Vector3(door_depth, door_height, w)


## The car's floor and roof boxes with its floor's top at `y` (centre; their size is `slab_size`).
func floor_center(y: float, cfg: LiftConfig) -> Vector3:
	var c := well.get_center()
	return Vector3(c.x, y - cfg.floor_thickness * 0.5, c.y)


func roof_center(y: float, cfg: LiftConfig) -> Vector3:
	var c := well.get_center()
	return Vector3(c.x, y + cfg.car_height + cfg.roof_thickness * 0.5, c.y)


func slab_size(thickness: float) -> Vector3:
	return Vector3(well.size.x, thickness, well.size.y)


## Whether feet at `feet` stand in the car with its floor's top at `y`: over its floor, from LiftConfig.ride_below
## under it up to its roof.
func holds(feet: Vector3, y: float, cfg: LiftConfig) -> bool:
	return well.has_point(Vector2(feet.x, feet.z)) and feet.y >= y - cfg.ride_below and feet.y < y + cfg.car_height


## Where a body waits on stop `k`'s landing and walks out to (on its floor, LiftConfig.landing_out from the face).
func landing_point(k: int, cfg: LiftConfig) -> Vector3:
	return on_face((door_from + door_to) * 0.5, door_depth + cfg.landing_out, stops[k])


## The middle of the car's floor with its floor's top at `y`.
func car_point(y: float) -> Vector3:
	var c := well.get_center()
	return Vector3(c.x, y, c.y)


## Stop `k`'s call button on its landing: on the wall's outside, LiftConfig.call_beside past the door's far jamb.
func call_button(k: int, cfg: LiftConfig) -> Vector3:
	return on_face(door_to + cfg.call_beside, door_depth, stops[k] + cfg.call_height)


## The car panel's button for stop `k` with the car's floor at `y`: on the door wall's inside, beside its far jamb.
func panel_button(k: int, y: float, cfg: LiftConfig) -> Vector3:
	return on_face(door_to + cfg.panel_beside, 0.0, y + cfg.panel_low + cfg.panel_step * k)
