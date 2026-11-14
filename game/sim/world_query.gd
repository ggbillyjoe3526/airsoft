class_name WorldQuery
extends RefCounted
## What the simulation asks the level (docs/ARCHITECTURE.md › Contracts 4): ray casts, what is underfoot, what its
## boxes are and where its bushes stand. BoxWorld answers it for headless tests; the map's Jolt implementation answers it in the game. Only
## implementations touch the physics engine.

## How near (m) the level ray's stop must be to an ajar doorway's face to be that doorway's, and how far past it a BB's
## path goes on through its gap: a geometric tolerance, not tuning.
const AJAR_FACE := 0.001

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
## The noisy prop's sound each box makes over its kind's (NoiseConfig.SOUND_NAMES; empty for its kind's: Depot's
## steel lockers are plywood boxes that clank, MapData.Block.noise).
var block_noises: Array[StringName] = []
## The level's bushes (WL5, FO1): no surface a ray meets or a mover is stopped by, only leaves a BB pushes through and
## a bot can't see far through. Empty unless whoever builds the level hands it the map's (MapLevel from MapData.foliage;
## tests through BoxWorld.add_bush).
var foliage: Foliage = Foliage.new()
## The level's shallow streams (WS1): no surface a ray meets or a mover is stopped by, only water a body wades and
## splashes in and a BB lands in. Empty unless whoever builds the level hands it the map's (MapLevel from MapData.water;
## tests through BoxWorld.add_stream).
var water: Water = Water.new()
## The level's bar railings (SR1): solid boxes to `ray` and movers, but sight and BBs pass between their bars. Empty
## unless whoever builds the level adds the map's (MapLevel from its railing blocks; tests through BoxWorld.add_railing).
var railings: Railings = Railings.new()
## The level's hinged doors (DO1), parallel lists in the map's order: each shut leaf's centre, half its size, and whether
## it starts a round shut. Filled once by whoever builds the level (MapLevel from MapData.doors; tests through
## add_door). Whether each is shut now is the game's (DoorState); the simulation tells the level with set_door_shut.
var door_centers: PackedVector3Array = PackedVector3Array()
var door_halves: PackedVector3Array = PackedVector3Array()
var door_starts_shut: PackedByteArray = PackedByteArray()
## The level's lifts (MT2), in the map's order: each car's well, door and stops (LiftSpec). Filled once by whoever
## builds the level (MapLevel from MapData.lifts; tests through add_lift). Where each car is now is the game's
## (LiftState); the simulation tells the level with set_lift_car and set_lift_door.
var lifts: Array[LiftSpec] = []
## Each lift's doorway whose leaves stand ajar (shutting or opening: its stop, -1 for none) and how far apart they
## stand there (0 shut, 1 open), told each tick by the simulation (set_lift_ajar). The doorway is a whole box to rays
## and movers until fully open (set_lift_door), so nobody steps into a gap the leaves shut on; a BB's path
## (bb_ray) meets only the two leaves, each its jamb's half of the doorway less half the gap, and flies the gap.
var lift_ajar_stop: PackedInt32Array = PackedInt32Array()
var lift_ajar_open: PackedFloat32Array = PackedFloat32Array()
## bb_ray's bar, reused.
var _bar_hit: RayHit = RayHit.new()
## How many lifts stand ajar this tick, so bb_ray skips the doorways when none does.
var _ajar: int = 0


## The nearest level surface on the segment from `from` to `to`, written into `hit`; false if there is none.
func ray(_from: Vector3, _to: Vector3, _hit: RayHit) -> bool:
	return false


## As `ray`, for sight (BQ1): the nearest surface that hides what is behind it, passing through the clear ones (window
## glass, MapStyle.clear_kinds), which stop BBs, bodies and bombs but not the eye, and the railings' boxes
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
	if found and _ajar > 0:
		found = _past_ajar_gaps(from, to, hit)
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


## `hit`, the level ray's first stop from `from` to `to`, or, where that is the face of an ajar lift doorway
## (lift_ajar_stop) and the segment flies its gap, the first leaf it meets inside the doorway or what the level ray
## meets past it; false if it meets nothing. Allocates nothing.
func _past_ajar_gaps(from: Vector3, to: Vector3, hit: RayHit) -> bool:
	var seg := to - from
	var length := seg.length()
	if not (length > 0.0):
		return true
	# Each pass gets past one doorway's gap; there are no more doorways than lifts ajar.
	for _pass in _ajar:
		var crossed := false
		for i in lift_ajar_stop.size():
			var k := lift_ajar_stop[i]
			if k < 0:
				continue
			var spec := lifts[i]
			var c := spec.door_center(k)
			var h := spec.door_size() * 0.5
			# Where the whole segment is inside the doorway's box (its entry must be the stop just found).
			var t0 := 0.0
			var t1 := 1.0
			for a in 3:
				var d := seg[a]
				if is_zero_approx(d):
					if absf(from[a] - c[a]) > h[a]:
						t0 = INF
					continue
				var ta := (c[a] - h[a] - from[a]) / d
				var tb := (c[a] + h[a] - from[a]) / d
				t0 = maxf(t0, minf(ta, tb))
				t1 = minf(t1, maxf(ta, tb))
			# The stop found is this doorway's face: where the segment goes in, or (starting in it, as a BB that ended
			# its last tick in the gap) where it comes out.
			if t0 > t1 or (absf(t0 - hit.fraction) * length > AJAR_FACE
					and not (t0 <= 0.0 and absf(t1 - hit.fraction) * length <= AJAR_FACE)):
				continue
			# Across the door: x for a door along x, z else; the gap is the middle `open` of its width.
			var w := 0 if spec.along_x() else 2
			var gap := lift_ajar_open[i] * h[w]
			var off := from[w] + seg[w] * t0 - c[w]
			if absf(off) >= gap:
				return true
			var dw := seg[w]
			var t_leaf := (c[w] + signf(dw) * gap - from[w]) / dw if not is_zero_approx(dw) else INF
			if t_leaf < t1:
				hit.position = from + seg * t_leaf
				hit.normal = Vector3.ZERO
				hit.normal[w] = -signf(dw)
				hit.fraction = t_leaf
				hit.surface = RayHit.Surface.METAL
				return true
			# Through the gap: on from just past the doorway.
			var start := t1 + AJAR_FACE / length
			if start >= 1.0 or not ray_past_railings(from + seg * start, to, hit):
				return false
			hit.fraction = start + (1.0 - start) * hit.fraction
			crossed = true
			break
		if not crossed:
			return true
	return true


## What the ground under `feet` is made of (RayHit.Surface.NONE when it can't tell).
func surface_under(_feet: Vector3) -> RayHit.Surface:
	return RayHit.Surface.NONE


## Lists a box of `kind` centred at `center` measuring `size`, made of `surface` (block_kinds), sounding as `noise`
## (block_noises; empty for its kind's). It records what the box is; it adds nothing a ray or a mover meets.
func add_block(kind: StringName, center: Vector3, size: Vector3, surface: RayHit.Surface,
		noise: StringName = &"") -> void:
	block_kinds.append(kind)
	block_noises.append(noise)
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


## Lists lift `spec` (MT2) with LiftConfig `cfg`'s car. Implementations add its car's floor and roof, steel, and a
## steel leaf in each stop's doorway, solid until told (set_lift_car, set_lift_door).
func add_lift(spec: LiftSpec, _cfg: LiftConfig) -> void:
	lifts.append(spec)
	lift_ajar_stop.append(-1)
	lift_ajar_open.append(0.0)


## How many lifts the level has.
func lift_count() -> int:
	return lifts.size()


## Moves lift `i`'s car (its floor and roof) so its floor's top is at `y`, for rays and movers from this call on.
func set_lift_car(_i: int, _y: float) -> void:
	pass


## Tells the level lift `i`'s leaves stand `open` of the way apart (0 shut, 1 open) in its doorway at stop `k`, shutting
## or opening, or (`k` -1) that none of its doorways is ajar (lift_ajar_stop): what a BB's path meets there (bb_ray).
func set_lift_ajar(i: int, k: int, open: float) -> void:
	var was := lift_ajar_stop[i] >= 0
	lift_ajar_stop[i] = k
	lift_ajar_open[i] = clampf(open, 0.0, 1.0) if k >= 0 else 0.0
	_ajar += int(k >= 0) - int(was)


## Makes lift `i`'s doorway at stop `k` solid (shut) or nothing at all (open) to rays and movers, from this call on.
func set_lift_door(_i: int, _k: int, _shut: bool) -> void:
	pass
