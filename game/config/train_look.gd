class_name TrainLook
extends Resource
## How a station's trains are drawn (SM1, TrainDressing; TrainView): the models of a car's body, its shut doors, its
## ends and the gangways between cars, each one vertex-coloured mesh built in Blender by tools/blender/maps/train.py
## and drawn in the props' material (PropDress). A car's models fill its room's walls, slabs and car ends exactly, so
## StationSurface leaves those boxes to them (`loads`); with any model missing the train is drawn as its boxes.

@export var body: String = "res://assets/models/props/train_body.glb"
## A shut pair of doors: the far side's (dark glass, against the tunnel wall), and the platform side's (`door_glazed`,
## its windows open through, their glass `door_glass`).
@export var door: String = "res://assets/models/props/train_door.glb"
@export var door_glazed: String = "res://assets/models/props/train_door_glazed.glb"
@export var door_glass: String = "res://assets/models/props/train_door_glass.glb"
## The platform side's window glass, a car's (the owner, 2026-11-12: "can the player see through them?"): drawn
## see-through in the clear material (`glass_opacity`, `glass_roughness`) over the body's open windows. The map's
## `glass` blocks in the holes stop BBs and bodies but not the eye (MapStyle.clear_kinds), so bots see through too.
@export var windows: String = "res://assets/models/props/train_windows.glb"
@export_range(0.0, 1.0) var glass_opacity: float = 0.3
@export_range(0.0, 1.0) var glass_roughness: float = 0.1
@export var gangway: String = "res://assets/models/props/train_gangway.glb"
## Half a car's ceiling lamp strips (its +x half), drawn glowing in `lamp_colour` (sRGB) at `lamp_energy`, laid twice
## a car (the second turned about); a half under a flickering station lamp (MapData.LAMP_FLICKER) flickers with it.
## Cool white (the owner, 2026-11-12); the station's lights inside the cars shine in it too (RoofView.hide_lamps_in).
@export var lights: String = "res://assets/models/props/train_lights.glb"
@export var lamp_colour: Color = Color(0.88, 0.94, 1.0)
@export var lamp_energy: float = 1.6
## The white LED lamps at a train's ends (the owner, 2026-11-12), by what stands at the end (TrainDressing.ENDS): their
## emitters, laid with the end's model and drawn glowing in `led_colour` (sRGB) at `led_energy`.
@export var leds: Dictionary[StringName, String] = {
	&"cab": "res://assets/models/props/train_cab_leds.glb",
	&"cab_open": "res://assets/models/props/train_cab_leds.glb",
	&"outer": "res://assets/models/props/train_end_leds.glb",
}
@export var led_colour: Color = Color(0.93, 0.96, 1.0)
@export var led_energy: float = 4.0
## The model at a car's end, by what stands there (TrainDressing.ENDS; the gangway is drawn at its joint instead).
@export var ends: Dictionary[StringName, String] = {
	&"cab": "res://assets/models/props/train_cab.glb",
	&"cab_open": "res://assets/models/props/train_cab_open.glb",
	&"blank": "res://assets/models/props/train_end.glb",
	&"outer": "res://assets/models/props/train_end_outer.glb",
}
## A car's half length, joint to joint, and its ends' thickness (m, as train.py builds them): an end model stands at
## the car's middle plus (half_length - end_depth) along it.
@export var half_length: float = 7.5
@export var end_depth: float = 0.15
## The door holes' middles along a car, in its models' own order (train.py DOOR_SLOTS; TrainDressing.SLOTS of them).
@export var door_slots: PackedFloat32Array = PackedFloat32Array([-5.3, -1.8, 1.8, 5.3])
@export var roughness: float = 0.6
## The props' world-space wear (SL2: foot grime, streaks, stains) at a share: low, the cars clean white (the owner,
## 2026-11-12: "more clean white than the grey"; the full streaks banded the white sides).
@export_range(0.0, 1.0) var wear: float = 0.3

var _meshes: Dictionary[String, Mesh] = {}


## Every model's path.
func paths() -> PackedStringArray:
	var out := PackedStringArray([body, door, door_glazed, door_glass, windows, gangway, lights])
	for k: StringName in ends:
		out.append(ends[k])
	for k: StringName in leds:
		if not out.has(leds[k]):
			out.append(leds[k])
	return out


## Whether every model loads (else the trains are drawn as their boxes, with a warning a model).
func loads() -> bool:
	for p in paths():
		if mesh(p) == null:
			return false
	return door_slots.size() == TrainDressing.SLOTS


## The model at `path`, or null (warned once) when it won't load.
func mesh(path: String) -> Mesh:
	if not _meshes.has(path):
		_meshes[path] = PropDressConfig.load_mesh(path)
		if _meshes[path] == null:
			push_warning("TrainLook: the train model \"%s\" won't load; the trains are drawn as their boxes" % path)
	return _meshes[path]
