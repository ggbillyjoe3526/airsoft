class_name StationDetailConfig
extends Resource
## A station's small fittings along its rooms' walls, floors and ceilings (StationDetail, SD2): skirting, a tile dado
## and frieze, cable conduit, wall vents, pipework, ceiling hatches, floor drains and service doors. Look only. Heights
## are over the room's floor; the signs' and posters' band (0.85 to 2.35 m, SM5's fixtures) is left clear. Colours are
## sRGB, off the teams' hues.

## The room styles (StationDressing.Zone.style) fitted out; rooms narrower than `min_room` m (a stair's slices, a
## doorway's) are left bare.
@export var rooms: Array[StringName] = [&"hall", &"passage", &"plant", &"service"]
@export var min_room: float = 1.6
## A room's air (StationDressing.Zone.box) starts this far (m) under its floor (tools/subway/station_dress.py UNDER).
@export var zone_under: float = 0.1
## Block kinds that stand as a room's walls, columns and ceilings.
@export var solid_kinds: Array[StringName] = [&"wall", &"pillar", &"floor"]
## A solid standing inside a room no wider than this (m) is a column, skirted and banded round.
@export var column_max: float = 2.0
## A wall is sought this often (m) along a room's side, this far (m) beyond it and this high (m) over its floor.
@export var step: float = 0.25
@export var probe: float = 0.05
@export var probe_height: float = 0.3
## A vent or a service door keeps this far (m) from any of SM5's fixtures (a sign, a poster, a clock, a camera).
@export var fixture_clear: float = 0.5

@export_group("Wall bands")
## The skirting: its height and how far it stands off the wall (m).
@export var skirting: Vector2 = Vector2(0.14, 0.018)
@export var skirting_colour: Color = Color8(0x3a, 0x3b, 0x3d)
## The dado's tile band and the frieze's over the posters: bottom, height (m) and how far they stand off the wall.
@export var dado: Vector3 = Vector3(0.7, 0.06, 0.006)
@export var frieze: Vector3 = Vector3(2.45, 0.1, 0.006)
@export var band_colour: Color = Color8(0x2f, 0x5a, 0x46)

@export_group("Conduit and pipes")
## Cable conduit this far (m) under the ceiling, its depth and height, a saddle clip every `clip_pitch` m. Runs shorter
## than `min_run` m get none.
@export var conduit_drop: float = 0.2
## A room lower than this (m, a doorway's) has no conduit: it would hang in the signs' band.
@export var conduit_room: float = 2.6
@export var conduit: Vector2 = Vector2(0.05, 0.04)
@export var clip_pitch: float = 1.2
@export var min_run: float = 2.0
@export var conduit_colour: Color = Color8(0x8e, 0x91, 0x94)
@export var clip_colour: Color = Color8(0x5c, 0x5e, 0x61)
## Pipes along a plant room's walls (and one along a passage's): each (drop under the ceiling, radius, gap off the
## wall), a bracket every `bracket_pitch` m.
@export var plant_pipes: Array[Vector3] = [Vector3(0.45, 0.06, 0.06), Vector3(0.65, 0.04, 0.08)]
@export var passage_pipe: Vector3 = Vector3(0.36, 0.035, 0.07)
@export var pipe_rooms: Array[StringName] = [&"plant", &"service"]
@export var bracket_pitch: float = 1.5
@export var pipe_colours: Array[Color] = [Color8(0x5f, 0x74, 0x68), Color8(0xb9, 0xb3, 0x9a)]
@export var bracket_colour: Color = Color8(0x45, 0x47, 0x4a)

@export_group("Vents, hatches and drains")
## Wall vents: width and height (m), their bottom over the floor, one every `vent_pitch` m on rooms at least
## `vent_room` m tall.
@export var vent: Vector2 = Vector2(0.6, 0.3)
@export var vent_bottom: float = 2.62
@export var vent_pitch: float = 8.0
@export var vent_room: float = 3.4
@export var vent_colour: Color = Color8(0x7a, 0x7d, 0x80)
@export var louvre_colour: Color = Color8(0x2a, 0x2b, 0x2d)
## Ceiling access hatches: their side (m), one every `hatch_pitch` m, kept `lamp_clear` m from a lamp and `edge_clear`
## m from the room's sides.
@export var hatch: float = 0.6
@export var hatch_pitch: float = 4.5
@export var lamp_clear: float = 1.2
@export var edge_clear: float = 0.9
@export var hatch_colour: Color = Color8(0xc9, 0xc8, 0xc2)
@export var seam_colour: Color = Color8(0x55, 0x56, 0x5a)
## Floor drains in the halls: their side (m), one every `drain_pitch` m along a wall, `drain_off` m from it.
@export var drain: float = 0.3
@export var drain_pitch: float = 12.0
@export var drain_off: float = 0.35
@export var drain_colour: Color = Color8(0x3b, 0x3a, 0x38)

@export_group("Service doors")
## A plant room's longest wall gets a service door at its middle: width, height (m) and how far it stands off.
@export var door: Vector3 = Vector3(0.9, 2.05, 0.03)
@export var door_rooms: Array[StringName] = [&"plant", &"service"]
## A room narrower than this (m) gets no door: a doorway between rooms.
@export var door_room_min: float = 3.0
@export var door_colour: Color = Color8(0x56, 0x64, 0x5c)
@export var frame_colour: Color = Color8(0x3f, 0x45, 0x42)
@export var handle_colour: Color = Color8(0x9a, 0x9a, 0x9a)
@export var plate_colour: Color = Color8(0xd8, 0xd4, 0xc8)

@export_group("Finish")
@export var roughness: float = 0.75
@export var wear: float = 1.0
