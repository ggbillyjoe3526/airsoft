class_name WorldQuery
extends RefCounted
## What the simulation asks the level (docs/ARCHITECTURE.md › Contracts 4): ray casts, what is underfoot, what its
## boxes are and where its bushes stand. BoxWorld answers it for headless tests; the map's Jolt implementation answers it in the game. Only
## implementations touch the physics engine.

## The level's boxes by what they are (a skip, a crate, a wall), for the rules that ask what a thing is rather than
## where a ray stops: the noisy props (PropNoise, NP1). Parallel lists in the level's order, filled once by whoever
## builds the level (MapLevel from its map's blocks; tests through add_block or BoxWorld.add_prop). A ramp's wedge is
## left out: nothing on a ramp makes a noise.
var block_kinds: Array[StringName] = []
var block_centers: PackedVector3Array = PackedVector3Array()
## Half each box's size along each axis.
var block_halves: PackedVector3Array = PackedVector3Array()
## What each is made of (RayHit.Surface), for the dust a knock shakes off it.
var block_surfaces: PackedInt32Array = PackedInt32Array()
## The level's bushes (WL5, FO1): no surface a ray meets or a mover is stopped by, only leaves a BB pushes through and
## a bot can't see far through. Empty unless whoever builds the level hands it the map's (MapLevel from MapData.foliage;
## tests through BoxWorld.add_bush).
var foliage: Foliage = Foliage.new()
## The level's bar railings (SR1): solid boxes to `ray` and movers, but sight and BBs pass between their bars. Empty
## unless whoever builds the level adds the map's (MapLevel from its railing blocks; tests through BoxWorld.add_railing).
var railings: Railings = Railings.new()
## The level's hinged doors (DO1), parallel lists in the map's order: each shut leaf's centre, half its size, and whether
## it starts a round shut. Filled once by whoever builds the level (MapLevel from MapData.doors; tests through
## add_door). Whether each is shut now is the game's (DoorState); the simulation tells the level with set_door_shut.
var door_centers: PackedVector3Array = PackedVector3Array()
var door_halves: PackedVector3Array = PackedVector3Array()
var door_starts_shut: PackedByteArray = PackedByteArray()
## bb_ray's bar, reused.
var _bar_hit: RayHit = RayHit.new()


## The nearest level surface on the segment from `from` to `to`, written into `hit`; false if there is none.
func ray(_from: Vector3, _to: Vector3, _hit: RayHit) -> bool:
	return false


## As `ray`, for sight (BQ1): the nearest surface that hides what is behind it, passing through the clear ones (The
## Street's glass, MapStyle.clear_kinds), which stop BBs, bodies and bombs but not the eye, and the railings' boxes
## (SR1), seen through between their bars. A level with neither answers as `ray`.
func sight_ray(from: Vector3, to: Vector3, hit: RayHit) -> bool:
	return ray(from, to, hit)


## As `ray`, passing the railings' boxes (Railings): what a BB's path meets besides their bars, and the line a bot
## checks for a shot (no railing is cover). A level with no railings answers as `ray`.
func ray_past_railings(from: Vector3, to: Vector3, hit: RayHit) -> bool:
	return ray(from, to, hit)


## The nearest surface a BB flying the segment from `from` to `to` meets, written into `hit`: the level past the
## railings' boxes (ray_past_railings), or the first of their bars and rails it actually crosses (Railings.first_bar);
## false if there is none. Allocates nothing.
func bb_ray(from: Vector3, to: Vector3, hit: RayHit) -> bool:
	var found := ray_past_railings(from, to, hit)
	if railings.is_empty():
		return found
	var length := from.distance_to(to)
	if not (length > 0.0):
		return found
	var reach := hit.fraction * length if found else length
	if railings.first_bar(from, (to - from) / length, reach, _bar_hit):
		hit.position = _bar_hit.position
		hit.normal = _bar_hit.normal
		hit.fraction = _bar_hit.fraction * reach / length
		hit.surface = _bar_hit.surface
		return true
	return found


## What the ground under `feet` is made of (RayHit.Surface.NONE when it can't tell).
func surface_under(_feet: Vector3) -> RayHit.Surface:
	return RayHit.Surface.NONE


## Lists a box of `kind` centred at `center` measuring `size`, made of `surface` (block_kinds). It records what the box
## is; it adds nothing a ray or a mover meets.
func add_block(kind: StringName, center: Vector3, size: Vector3, surface: RayHit.Surface) -> void:
	block_kinds.append(kind)
	block_centers.append(center)
	block_halves.append(size * 0.5)
	block_surfaces.append(surface)


## Lists a door whose shut leaf is the box centred at `center` measuring `size`, starting each round shut if `shut`.
## Implementations add its leaf, solid while shut (`set_door_shut`).
func add_door(center: Vector3, size: Vector3, shut: bool) -> void:
	door_centers.append(center)
	door_halves.append(size * 0.5)
	door_starts_shut.append(1 if shut else 0)


## How many doors the level has.
func door_count() -> int:
	return door_centers.size()


## Makes door `i`'s leaf solid (shut) or nothing at all (open) to rays and movers, from this call on.
func set_door_shut(_i: int, _shut: bool) -> void:
	pass
