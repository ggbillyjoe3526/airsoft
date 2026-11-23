class_name JoltQuery
extends WorldQuery
## The simulation's WorldQuery on a map's Jolt colliders (docs/ARCHITECTURE.md › Contracts 4): BB rays and what is
## underfoot, through one RayCast3D the level owns, cast on demand (force_raycast_update allocates nothing, where
## intersect_ray returns a new Dictionary a call). Each surface's blocks are one static body, so the body a ray meets
## says what it is made of; each door's leaf (DO1) is a wooden body of its own, switched on and off with the door.
## Sight and a BB's path meet the props a map draws as drawn (DG1, DrawnRays): their faces, and their leaf cards where
## the leaf sheet's cut-out is solid; the level ray (`ray`: what is underfoot, vaults, leans, bombs, magazines) and the
## movers meet the boxes those props stand in for.

## What is underfoot is looked for from max_step above the feet down to this far below them (m), so a step's landing
## a little above the floor, or a ramp's slope, still counts (the browser game's map/underfoot.ts UNDERFOOT_REACH).
const UNDERFOOT_REACH := 0.35

var _cast: RayCast3D = null
## The ray sight casts (BQ1): the level ray's twin, blind to the clear bodies (null on a level with none: sight casts
## `_cast`).
var _sight_cast: RayCast3D = null
## The static body of each RayHit.Surface, by its value.
var _surface_bodies: Array[RID] = []
## The clear blocks' bodies (window glass, MapStyle.clear_kinds) and each one's RayHit.Surface: solid to BBs and
## movers, not to sight.
var _clear_bodies: Array[RID] = []
var _clear_surfaces: PackedInt32Array = PackedInt32Array()
## The railings' bodies (SR1, MapStyle.railing_kinds) and each one's RayHit.Surface: solid to movers and the level ray,
## not to sight nor `_past_cast`, the level ray's twin a BB's path and a bot's shot check cast (null on a level with
## no railings: they cast `_cast`); a BB meets the railings' bars through WorldQuery.railings.
var _railing_bodies: Array[RID] = []
var _railing_surfaces: PackedInt32Array = PackedInt32Array()
var _past_cast: RayCast3D = null
## The ray a thrown bomb casts (throw_ray), on the drawn props' faces and leaf cards, blind to nothing; null: `_cast`.
var _throw_cast: RayCast3D = null
## The drawn props (DG1; null on a level with none).
var _drawn: DrawnRays = null
## The tapering props' tiers' bodies (WH1: thickets and trunks, a body a surface beside the surface's own) and the
## boxes the drawn props stand in for (DG1), and each one's RayHit.Surface.
var _tier_surfaces: Dictionary[RID, int] = {}
var _body: BodyConfig = null
var _under: RayHit = RayHit.new()
## Each door's leaf (DO1), by door: the one shape of a wooden static body of its own, disabled while the door is open.
var _door_shapes: Array[CollisionShape3D] = []
var _door_bodies: Array[RID] = []
## Each lift's car (MT2): a steel static body holding its floor and roof, moved whole (its origin the middle of its
## floor's top); each lift's doorways, a shape a stop on a steel body of its own, disabled while open. The cars' and
## the doorways' bodies are steel to rays.
var _lift_cars: Array[StaticBody3D] = []
var _lift_doors: Array[Array] = []
var _lift_rids: Array[RID] = []


func _init(cast: RayCast3D, surface_bodies: Array[RID], body: BodyConfig) -> void:
	_cast = cast
	_surface_bodies = surface_bodies
	_body = body


func ray(from: Vector3, to: Vector3, hit: RayHit) -> bool:
	return _cast_on(_cast, from, to, hit)


func sight_ray(from: Vector3, to: Vector3, hit: RayHit) -> bool:
	return _cast_drawn(_sight_cast if _sight_cast != null else _cast, from, to, hit)


func ray_past_railings(from: Vector3, to: Vector3, hit: RayHit) -> bool:
	return _cast_drawn(_past_cast if _past_cast != null else _cast, from, to, hit)


func throw_ray(from: Vector3, to: Vector3, hit: RayHit) -> bool:
	return _cast_on(_cast, from, to, hit) if _throw_cast == null else _cast_drawn(_throw_cast, from, to, hit)


## The railings' bodies as the level built them (MapLevel), each made of `surfaces`' RayHit.Surface; `sight` (the ray
## sight casts, as set_clear_bodies) and `past` (the ray past the railings, in the level's tree with the drawn props'
## mask) are made blind to them here.
func set_railing_bodies(bodies: Array[RID], surfaces: PackedInt32Array, sight: RayCast3D, past: RayCast3D) -> void:
	_railing_bodies = bodies
	_railing_surfaces = surfaces
	_sight_cast = sight
	_past_cast = past
	for rid in bodies:
		sight.add_exception_rid(rid)
		past.add_exception_rid(rid)


## The drawn props (DG1) as the level built them (MapLevel), after set_clear_bodies (and set_railing_bodies on a level
## with railings): `past` the ray past the railings (in the level's tree with DrawnRays' masks; the one
## set_railing_bodies took on a level with railings). The sight ray and `past` meet the drawn props' faces and their
## leaf cards; `throw` (in the level's tree with the same masks, blind to nothing: glass and railings' boxes stop a
## bomb) is throw_ray's.
func set_drawn(drawn: DrawnRays, past: RayCast3D, throw: RayCast3D) -> void:
	_drawn = drawn
	_past_cast = past
	_throw_cast = throw


## As _cast_on along `cast`, through the drawn props' leaf cards (DG1) where their cut-out is cut away: a card met where
## its sheet is solid stops the line (LEAVES); one met where it isn't lets the line carry on just past it, up to
## DrawnRayConfig.leaf_tries cards, past which it counts as stopped in the leaves. Allocates nothing.
func _cast_drawn(cast: RayCast3D, from: Vector3, to: Vector3, hit: RayHit) -> bool:
	if _drawn == null:
		return _cast_on(cast, from, to, hit)
	var length := from.distance_to(to)
	if not (length > 0.0):
		return false
	var way := (to - from) / length
	var cfg := _drawn.config()
	var start := from
	var tries := maxi(cfg.leaf_tries, 1)
	for t in tries:
		cast.position = start
		cast.target_position = to - start
		cast.force_raycast_update()
		if not cast.is_colliding():
			return false
		var at := cast.get_collision_point()
		var rid := cast.get_collider_rid()
		var past_card := _drawn.is_leaf(rid) and t + 1 < tries \
				and not _drawn.opaque(rid, cast.get_collider_shape(), cast.get_collision_face_index(), at)
		if not past_card:
			hit.position = at
			hit.normal = cast.get_collision_normal()
			hit.fraction = clampf(from.distance_to(at) / length, 0.0, 1.0)
			hit.surface = _surface_of(rid)
			return true
		start = at + way * cfg.leaf_step
		if (to - start).dot(way) <= cfg.leaf_step:
			return false
	return false


## The tapering props' tiers' bodies and the boxes the drawn props stand in for (DG1) as the level built them
## (MapLevel), each made of `surfaces`' RayHit.Surface.
func set_tier_bodies(bodies: Array[RID], surfaces: PackedInt32Array) -> void:
	_tier_surfaces.clear()
	for t in bodies.size():
		_tier_surfaces[bodies[t]] = surfaces[t]


## The clear bodies as the level built them (MapLevel), each made of `surfaces`' RayHit.Surface, and `sight`: a ray in
## the level's tree with the drawn props' masks that sight casts, made blind to them here.
func set_clear_bodies(bodies: Array[RID], surfaces: PackedInt32Array, sight: RayCast3D) -> void:
	_clear_bodies = bodies
	_clear_surfaces = surfaces
	_sight_cast = sight
	for rid in bodies:
		sight.add_exception_rid(rid)


func _cast_on(cast: RayCast3D, from: Vector3, to: Vector3, hit: RayHit) -> bool:
	var segment := to - from
	var length := segment.length()
	if not (length > 0.0):
		return false
	cast.position = from
	cast.target_position = segment
	cast.force_raycast_update()
	if not cast.is_colliding():
		return false
	hit.position = cast.get_collision_point()
	hit.normal = cast.get_collision_normal()
	hit.fraction = clampf(from.distance_to(hit.position) / length, 0.0, 1.0)
	hit.surface = _surface_of(cast.get_collider_rid())
	return true


## Door `i`'s leaf and its body as the level built them (MapLevel), after add_door.
func set_door_shape(i: int, shape: CollisionShape3D, body: RID) -> void:
	if _door_shapes.size() <= i:
		_door_shapes.resize(i + 1)
		_door_bodies.resize(i + 1)
	_door_shapes[i] = shape
	_door_bodies[i] = body


## A shape's switch takes effect on the physics server at once, for the next ray and the next mover's sweep.
func set_door_shut(i: int, shut: bool) -> void:
	_door_shapes[i].disabled = not shut


## Lift `i`'s car body and its doorways' shapes (one a stop) and their body, as the level built them (MapLevel), after
## add_lift.
func set_lift_bodies(i: int, car: StaticBody3D, doors: Array[CollisionShape3D], doors_body: RID) -> void:
	if _lift_cars.size() <= i:
		_lift_cars.resize(i + 1)
		_lift_doors.resize(i + 1)
	_lift_cars[i] = car
	_lift_doors[i] = doors
	_lift_rids.append(car.get_rid())
	_lift_rids.append(doors_body)


## The car's body is placed on the physics server at once, for the next ray and the next mover's sweep (a node's own
## transform reaches the server only when the tree flushes its changes); its node follows.
func set_lift_car(i: int, y: float) -> void:
	var car := _lift_cars[i]
	car.position = Vector3(car.position.x, y, car.position.z)
	PhysicsServer3D.body_set_state(car.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, car.transform)


func set_lift_door(i: int, k: int, shut: bool) -> void:
	(_lift_doors[i][k] as CollisionShape3D).disabled = not shut


func surface_under(feet: Vector3) -> RayHit.Surface:
	var top := feet + Vector3(0.0, _body.max_step, 0.0)
	if not ray(top, feet - Vector3(0.0, UNDERFOOT_REACH, 0.0), _under):
		return RayHit.Surface.NONE
	return _under.surface


func _surface_of(rid: RID) -> RayHit.Surface:
	for s in _surface_bodies.size():
		if _surface_bodies[s] == rid:
			return s as RayHit.Surface
	if _tier_surfaces.has(rid):
		return _tier_surfaces[rid] as RayHit.Surface
	if _drawn != null and _drawn.surfaces.has(rid):
		return _drawn.surfaces[rid] as RayHit.Surface
	for c in _clear_bodies.size():
		if _clear_bodies[c] == rid:
			return _clear_surfaces[c] as RayHit.Surface
	for r in _railing_bodies.size():
		if _railing_bodies[r] == rid:
			return _railing_surfaces[r] as RayHit.Surface
	# A door's leaf is plywood.
	for b in _door_bodies:
		if b == rid:
			return RayHit.Surface.WOOD
	# A lift's car and doors are steel.
	for b in _lift_rids:
		if b == rid:
			return RayHit.Surface.METAL
	return RayHit.Surface.NONE
