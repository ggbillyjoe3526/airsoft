class_name ThrownMagazines
extends Node3D
## The old magazines the rigged figures throw in their reloads (step 23, FI4; the browser game's FIGURE_RIG
## thrownMagazines): a fixed pool of `size` MeshInstance3D built once a session, so a throw allocates nothing. A throw
## takes a free copy (or the oldest out) and gives it the thrower's magazine mesh and paint, flies it from the hand
## with the sidecar's velocity and spin plus the figure's own velocity, falls under gravity and comes to rest on its
## side where it comes down: the thrower's feet, or with a world (set_world) the floor one ray finds under where it
## would land at the feet's height (BP7: a ledge's foot below, a step up), at most `drop` m under the feet; it goes after
## its lifetime (from the throw). At most `size` are out: the oldest goes first. Cleared at ROUND_START.
## Presentation only, in the world's frame (top level), moved on each frame's time by `update`.

## The copies and each one's flight: its mesh's box (read once a throw), velocity and spin (rad/s, axis times rate) in
## the world, the ground it lands on, gravity, lifetime, time out, out at all, landed.
var _pool: Array[MeshInstance3D] = []
var _size: int = 0
var _box: Array[AABB] = []
var _velocity: PackedVector3Array = PackedVector3Array()
var _spin: PackedVector3Array = PackedVector3Array()
var _ground: PackedFloat64Array = PackedFloat64Array()
var _gravity: PackedFloat64Array = PackedFloat64Array()
var _lifetime: PackedFloat64Array = PackedFloat64Array()
var _age: PackedFloat64Array = PackedFloat64Array()
var _out: PackedByteArray = PackedByteArray()
var _landed: PackedByteArray = PackedByteArray()
## The copies out, oldest first (indices into the pool); `_count` of them.
var _order: PackedInt32Array = PackedInt32Array()
var _count: int = 0
## The level the landing ray reads (none: every magazine lands at its thrower's feet), how far under the feet it reaches
## (m) and over them it starts (m), and its hit, kept.
var _world: WorldQuery = null
var _drop: float = 0.0
var _above: float = 0.0
var _hit: RayHit = null


## Builds the `size` copies, hidden, with no mesh until thrown.
func setup(size: int) -> void:
	name = "ThrownMagazines"
	top_level = true
	_size = maxi(size, 0)
	_order.resize(_size)
	for i in _size:
		var m := MeshInstance3D.new()
		m.visible = false
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
		_pool.append(m)
	var n := _pool.size()
	_box.resize(n)
	_velocity.resize(n)
	_spin.resize(n)
	_ground.resize(n)
	_gravity.resize(n)
	_lifetime.resize(n)
	_age.resize(n)
	_out.resize(n)
	_landed.resize(n)


## Each throw from now on lands on the floor `world` has under where it comes down, from `above` m over the thrower's
## feet to `drop` m under them (null: at the feet).
func set_world(world: WorldQuery, drop: float, above: float) -> void:
	_world = world
	_drop = maxf(drop, 0.0)
	_above = maxf(above, 0.0)
	if _hit == null:
		_hit = RayHit.new()


## Throws a copy of `source` (a figure's magazine in the hand: its mesh and paint are worn) from `at` (the world's)
## with `velocity` and `spin`, to land at height `ground` (the feet's; with a world, the floor under where it would
## land there: landing_height) under `gravity` and go after `lifetime` (s). The oldest goes first when `size` are out.
## False without a source mesh or a pool.
func throw(source: MeshInstance3D, at: Transform3D, velocity: Vector3, spin: Vector3, ground: float, gravity: float,
		lifetime: float) -> bool:
	if source == null or source.mesh == null or _size == 0:
		return false
	if _count >= _size:
		_retire(0)
	var at_index := _out.find(0)
	var m := _pool[at_index]
	if m.mesh != source.mesh:
		m.mesh = source.mesh
	_box[at_index] = source.mesh.get_aabb()
	for s in m.get_surface_override_material_count():
		m.set_surface_override_material(s, source.get_surface_override_material(s))
	m.transform = at
	m.visible = true
	_velocity[at_index] = velocity
	_spin[at_index] = spin
	_ground[at_index] = landing_height(at.origin, velocity, ground, gravity)
	_gravity[at_index] = gravity
	_lifetime[at_index] = lifetime
	_age[at_index] = 0.0
	_out[at_index] = 1
	_landed[at_index] = 0
	_order[_count] = at_index
	_count += 1
	return true


## Moves every magazine out `delta` seconds on: flying ones fall and turn, landing on their side; old ones go.
func update(delta: float) -> void:
	var k := 0
	while k < _count:
		var i := _order[k]
		_age[i] += delta
		if _age[i] >= _lifetime[i]:
			_retire(k)
			continue
		if _landed[i] == 0:
			_fly(i, delta)
		k += 1


## Every magazine gone (a new round).
func clear() -> void:
	while _count > 0:
		_retire(0)


## How many magazines are out.
func count() -> int:
	return _count


## The copy thrown `k`-th of those out (0 the oldest), or null.
func thrown_at(k: int) -> MeshInstance3D:
	return _pool[_order[k]] if k >= 0 and k < _count else null


## Whether the `k`-th of those out (0 the oldest) has landed.
func landed_at(k: int) -> bool:
	return k >= 0 and k < _count and _landed[_order[k]] == 1


## How many copies the pool holds in all (tests).
func pool_size() -> int:
	return _pool.size()


func _fly(i: int, delta: float) -> void:
	var m := _pool[i]
	var v := _velocity[i]
	v.y -= _gravity[i] * delta
	_velocity[i] = v
	var t := m.transform
	t.origin += v * delta
	var spin := _spin[i]
	var rate := spin.length()
	if rate > 0.0:
		t.basis = Basis(spin / rate, rate * delta) * t.basis
	if t.origin.y + _lowest(t.basis, _box[i]) <= _ground[i]:
		t = _lying(t, _box[i], _ground[i])
		_landed[i] = 1
	m.transform = t


## The height (m) a magazine let go at `from` with `velocity` comes to rest on: without a world, `ground` (the feet's);
## with one, the floor one ray finds from `above` over `ground` down to `drop` under it, under the point where it would
## come down to `ground` under `gravity` (one ray a throw; a lower floor found lands it there, a little short of where
## its longer fall would carry it). A table or a crate's top over the feet is never taken (the ray starts under it), so
## at a step up it lands at the feet's height, inside the step, as before BP7. Nothing found: `ground`.
func landing_height(from: Vector3, velocity: Vector3, ground: float, gravity: float) -> float:
	if _world == null or gravity <= 0.0:
		return ground
	var fall := maxf(from.y - ground, 0.0)
	var t := (velocity.y + sqrt(velocity.y * velocity.y + 2.0 * gravity * fall)) / gravity
	var at := Vector3(from.x + velocity.x * t, ground + _above, from.z + velocity.z * t)
	if not _world.ray(at, Vector3(at.x, ground - _drop, at.z), _hit):
		return ground
	return _hit.position.y


## Copy `k` of those out goes (hidden), the rest kept in order.
func _retire(k: int) -> void:
	var i := _order[k]
	_pool[i].visible = false
	_out[i] = 0
	for j in range(k, _count - 1):
		_order[j] = _order[j + 1]
	_count -= 1


## How far below its origin (m) a box `box` turned by `b` reaches.
static func _lowest(b: Basis, box: AABB) -> float:
	var low := 0.0
	for axis in 3:
		var up := b[axis].y
		low += minf(up * box.position[axis], up * box.end[axis])
	return low


## `t` brought to rest on its side (its thin X axis upright, the way it pointed kept) with box `box` on `ground`.
static func _lying(t: Transform3D, box: AABB, ground: float) -> Transform3D:
	var side := 1.0 if t.basis.x.y >= 0.0 else -1.0
	var along := Vector3(t.basis.y.x, 0.0, t.basis.y.z)
	if along.length_squared() < 1e-6:
		along = Vector3(t.basis.z.x, 0.0, t.basis.z.z)
	if along.length_squared() < 1e-6:
		along = Vector3.FORWARD
	along = along.normalized()
	var up := Vector3.UP * side
	var b := Basis(up, along, up.cross(along))
	var height := ground - box.position.x if side > 0.0 else ground + box.end.x
	return Transform3D(b, Vector3(t.origin.x, height, t.origin.z))
