class_name PlantState
extends RefCounted
## Plant The Bomb's device and sites as plain data (PB1). Plant writes it; the HUD, the views and the bots read it.

## DOWN: on the ground (at the attackers' start, or where its carrier was hit). CARRIED: on an attacker. PLANTED: armed
## in a site, its fuse running. DEFUSED and GONE_OFF: the round's end.
enum Status { DOWN, CARRIED, PLANTED, DEFUSED, GONE_OFF }

## The sites (map data, A first): each one's middle on its floor and its radius (m). Set before Round.start_match.
var sites: PackedVector3Array = PackedVector3Array()
var radii: PackedFloat32Array = PackedFloat32Array()
## Where the bomb lies as each round starts (map data: ahead of the attackers' spawns).
var start: Vector3 = Vector3.ZERO

var status: Status = Status.DOWN
## Where it lies or stands armed; while carried, its carrier's feet.
var position: Vector3 = Vector3.ZERO
## Who carries it (a character id), or -1.
var carrier: int = -1
## It has left the start: picked up at least once this round (a bomb DOWN and moved was dropped by a carrier who was hit).
var moved: bool = false
## The site it is being armed in or stands armed in (an index into `sites`), or -1.
var site: int = -1
## Who is arming it (-1 nobody) and how far along (0 to 1).
var planter: int = -1
var planting: float = 0.0
## Seconds of fuse left once armed.
var fuse_left: float = 0.0
## Who is disarming it (-1 nobody) and how far along (0 to 1).
var defuser: int = -1
var defusing: float = 0.0
## Seconds to its next beep.
var beep_in: float = 0.0


## Back on the ground at the start for a new round.
func reset() -> void:
	status = Status.DOWN
	position = start
	carrier = -1
	moved = false
	site = -1
	planter = -1
	planting = 0.0
	fuse_left = 0.0
	defuser = -1
	defusing = 0.0
	beep_in = 0.0


## Armed, its fuse running.
func planted() -> bool:
	return status == Status.PLANTED


## The sites and their radii from map data: `spots` and each one's radius in `spot_radii` (0 or missing: `fallback`).
func set_sites(spots: PackedVector3Array, spot_radii: PackedFloat32Array, fallback: float) -> void:
	sites = spots.duplicate()
	radii.resize(sites.size())
	for i in sites.size():
		radii[i] = spot_radii[i] if i < spot_radii.size() and spot_radii[i] > 0.0 else fallback
