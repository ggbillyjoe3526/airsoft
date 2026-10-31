class_name BoxWorld
extends WorldQuery
## A level made of axis-aligned boxes, answering the simulation's questions without a physics engine: BB rays
## (WorldQuery, a slab test like the browser game's sim/levelRay.ts) and character movement (it is also handed out as a
## CharacterMover by `mover()`). Used headless by the tests and tools; the game's maps answer through Jolt.
##
## A character is a vertical cylinder (BodyConfig radius and height) standing rest_gap above the floor. It slides along
## walls, walks up anything no taller than max_step and is stopped by ceilings.

## A ray this close to parallel with a face (|dir| along its axis) never meets it.
const PARALLEL := 1e-12
## Push-out passes per horizontal move: corners where two boxes meet need more than one.
const PUSH_PASSES := 3
## Contact tolerance (m): a head touching a ceiling, or feet a floor, isn't overlapping it (Vector3 is 32-bit).
const SKIN := 1e-4

var box_min: PackedVector3Array = PackedVector3Array()
var box_max: PackedVector3Array = PackedVector3Array()
var box_surface: PackedInt32Array = PackedInt32Array()
## 1 for a box that is no box now: an open door's leaf (DO1).
var box_off: PackedByteArray = PackedByteArray()
## Each door's box (WorldQuery.add_door), by door.
var _door_box: PackedInt32Array = PackedInt32Array()
var body: BodyConfig = null


func _init(body_config: BodyConfig = null) -> void:
	body = body_config if body_config != null else BodyConfig.new()


## Adds a solid box centred at `center` measuring `size`, made of `surface`.
func add_box(center: Vector3, size: Vector3, surface: RayHit.Surface = RayHit.Surface.CONCRETE) -> void:
	box_min.append(center - size * 0.5)
	box_max.append(center + size * 0.5)
	box_surface.append(surface)
	box_off.append(0)


## Adds a solid box of `kind` (a skip, a crate) centred at `center` measuring `size`, made of `surface`, and lists it as
## that kind (WorldQuery.block_kinds), as a map's block is.
func add_prop(kind: StringName, center: Vector3, size: Vector3, surface: RayHit.Surface) -> void:
	add_box(center, size, surface)
	add_block(kind, center, size, surface)


## Adds a door's leaf as a wooden box, solid while shut (WorldQuery.add_door).
func add_door(center: Vector3, size: Vector3, shut: bool) -> void:
	super(center, size, shut)
	_door_box.append(box_min.size())
	add_box(center, size, RayHit.Surface.WOOD)
	box_off[box_off.size() - 1] = 0 if shut else 1


func set_door_shut(i: int, shut: bool) -> void:
	box_off[_door_box[i]] = 0 if shut else 1


## Adds a bush standing on `foot`, `radius` across and `height` tall (WorldQuery.foliage): nothing a ray or a mover
## meets.
func add_bush(foot: Vector3, radius: float, height: float) -> void:
	foliage.add(foot, radius, height)


## A floor whose top is at y = 0, `width` by `depth`, centred on the origin.
func add_floor(width: float, depth: float, thickness: float = 0.5) -> void:
	add_box(Vector3(0.0, -thickness * 0.5, 0.0), Vector3(width, thickness, depth), RayHit.Surface.EARTH)


## This world as a CharacterMover (a new one each call; the world keeps no reference to it, so nothing cycles).
func mover() -> CharacterMover:
	return BoxMover.new(self)


func ray(from: Vector3, to: Vector3, hit: RayHit) -> bool:
	var dir := to - from
	var best := INF
	var best_box := -1
	var best_axis := 0
	for b in box_min.size():
		if box_off[b] != 0:
			continue
		var t_enter := -INF
		var t_exit := INF
		var axis := -1
		var exit_axis := -1
		var missed := false
		for i in 3:
			var d := dir[i]
			var o := from[i]
			var lo := box_min[b][i]
			var hi := box_max[b][i]
			if absf(d) < PARALLEL:
				if o < lo or o > hi:
					missed = true
					break
				continue
			var t1 := (lo - o) / d
			var t2 := (hi - o) / d
			if t1 > t2:
				var tmp := t1
				t1 = t2
				t2 = tmp
			if t1 > t_enter:
				t_enter = t1
				axis = i
			if t2 < t_exit:
				t_exit = t2
				exit_axis = i
		if missed or t_enter > t_exit or t_exit < 0.0 or t_enter > 1.0:
			continue
		# A ray starting inside a box meets its far side.
		var t := t_enter if t_enter >= 0.0 else t_exit
		var a := axis if t_enter >= 0.0 else exit_axis
		if t <= 1.0 and t < best:
			best = t
			best_box = b
			best_axis = a
	if best_box < 0:
		return false
	hit.fraction = best
	hit.position = from + dir * best
	var n := Vector3.ZERO
	n[best_axis] = -signf(dir[best_axis]) if dir[best_axis] != 0.0 else 1.0
	hit.normal = n
	hit.surface = box_surface[best_box] as RayHit.Surface
	return true


func surface_under(feet: Vector3) -> RayHit.Surface:
	var top := ground_box(feet, body.radius, feet.y + body.max_step, INF)
	return RayHit.Surface.NONE if top < 0 else box_surface[top] as RayHit.Surface


## The box with the highest top at or below `max_top` under a circle of `radius` round `feet` (x, z), that top no
## further than `max_drop` below the feet; -1 if none.
func ground_box(feet: Vector3, radius: float, max_top: float, max_drop: float) -> int:
	var best := -1
	var best_top := -INF
	for b in box_min.size():
		if box_off[b] != 0:
			continue
		var top := box_max[b].y
		if top > max_top or top < feet.y - body.rest_gap - max_drop or top <= best_top:
			continue
		if _circle_overlaps(feet.x, feet.z, radius, b):
			best = b
			best_top = top
	return best


func _circle_overlaps(x: float, z: float, radius: float, b: int) -> bool:
	var cx := clampf(x, box_min[b].x, box_max[b].x)
	var cz := clampf(z, box_min[b].z, box_max[b].z)
	var dx := x - cx
	var dz := z - cz
	return dx * dx + dz * dz < radius * radius


## Moves a cylinder `height` tall (the body's standing height without one) with its feet at `feet` by `desired`,
## stopping at boxes: vertically first, then level with a slide along walls and a step up onto anything no taller than
## max_step. Returns where the feet end up.
func sweep(feet: Vector3, desired: Vector3, height: float = NAN) -> Vector3:
	var p := feet
	var r := body.radius
	var tall := body.height if is_nan(height) else height
	# Vertical: land on a top crossed going down; stop under a bottom crossed going up.
	var y_to := p.y + desired.y
	if desired.y < 0.0:
		var land := ground_box(Vector3(p.x, p.y, p.z), r, p.y - body.rest_gap + 1e-6, p.y - y_to)
		if land >= 0:
			y_to = maxf(y_to, box_max[land].y + body.rest_gap)
	elif desired.y > 0.0:
		for b in box_min.size():
			if box_off[b] != 0:
				continue
			var bottom := box_min[b].y
			if bottom >= p.y + tall - SKIN and bottom < y_to + tall and _circle_overlaps(p.x, p.z, r, b):
				y_to = minf(y_to, bottom - tall)
	p.y = y_to
	# Level: move, then push out of every box the body overlaps above step height.
	p.x += desired.x
	p.z += desired.z
	for _pass in PUSH_PASSES:
		var pushed := false
		for b in box_min.size():
			if box_off[b] != 0 or box_max[b].y <= p.y + body.max_step or box_min[b].y >= p.y + tall - SKIN:
				continue
			var cx := clampf(p.x, box_min[b].x, box_max[b].x)
			var cz := clampf(p.z, box_min[b].z, box_max[b].z)
			var dx := p.x - cx
			var dz := p.z - cz
			var d2 := dx * dx + dz * dz
			if d2 >= r * r:
				continue
			pushed = true
			if d2 > 0.0:
				var d := sqrt(d2)
				p.x = cx + dx / d * r
				p.z = cz + dz / d * r
			else:
				# The centre is inside the box's footprint: out by the nearest side.
				var out_x := minf(p.x - box_min[b].x, box_max[b].x - p.x)
				var out_z := minf(p.z - box_min[b].z, box_max[b].z - p.z)
				if out_x < out_z:
					p.x = box_min[b].x - r if p.x - box_min[b].x < box_max[b].x - p.x else box_max[b].x + r
				else:
					p.z = box_min[b].z - r if p.z - box_min[b].z < box_max[b].z - p.z else box_max[b].z + r
		if not pushed:
			break
	# Step up onto a low top the body now stands in.
	var step := ground_box(p, r, p.y + body.max_step, 0.0)
	if step >= 0 and box_max[step].y + body.rest_gap > p.y:
		p.y = box_max[step].y + body.rest_gap
	return p


## The offset that puts feet at `feet` at rest on the ground below within `max_drop`, or NAN.
func probe(feet: Vector3, max_drop: float) -> float:
	var b := ground_box(feet, body.radius, feet.y + body.max_step, max_drop)
	if b < 0:
		return NAN
	return box_max[b].y + body.rest_gap - feet.y


## BoxWorld's CharacterMover face.
class BoxMover:
	extends CharacterMover

	var world: BoxWorld = null

	func _init(box_world: BoxWorld) -> void:
		world = box_world

	func move(c: Character, desired: Vector3) -> Vector3:
		return world.sweep(c.position, desired, c.body_height(world.body)) - c.position

	func room_to_stand(c: Character) -> bool:
		var b := world.body
		var up := b.height - b.crouch_height
		return world.sweep(c.position, Vector3(0.0, up, 0.0), b.crouch_height).y >= c.position.y + up - 1e-4

	func probe_ground(c: Character, max_drop: float) -> float:
		return world.probe(c.position, max_drop)
