class_name BBPool
extends RefCounted
## Every BB in flight: a fixed pool (BallisticsConfig.max_bbs), so firing allocates nothing.

var bbs: Array[BB] = []
var next_serial: int = 1


func _init(size: int = 0) -> void:
	for i in size:
		bbs.append(BB.new())


## Fires a BB of `mass` kg from `origin` along the unit vector `dir` at `speed` m/s, with the backspin a hop-up lift of
## `hop_up` gives (× `spin_per_hop`), from the replica in its owner's loadout slot `slot`. Takes a free slot, else the
## oldest BB in flight. Returns null for a pool with no slots or a mass that isn't positive (it would fill the flight
## with NaN).
func spawn(owner_id: int, origin: Vector3, dir: Vector3, speed: float, hop_up: float, mass: float, spin_per_hop: float,
		slot: int = -1) -> BB:
	if not (mass > 0.0):
		push_error("BBPool.spawn: BB mass must be positive (kg), got %s" % mass)
		return null
	var bb: BB = null
	var oldest: BB = null
	for b in bbs:
		if not b.active:
			bb = b
			break
		if oldest == null or b.serial < oldest.serial:
			oldest = b
	if bb == null:
		bb = oldest
	if bb == null:
		return null
	bb.active = true
	bb.serial = next_serial
	next_serial += 1
	bb.owner_id = owner_id
	bb.slot = slot
	bb.position = origin
	bb.prev_position = origin
	bb.velocity = dir * speed
	bb.age = 0.0
	bb.spin = hop_up * spin_per_hop
	# The spin axis: the barrel's direction crossed with world up (to its right), level. Straight up or down has no
	# level right-hand side; any level axis will do, as the lift is then sideways and tiny.
	var axis := Vector3(-dir.z, 0.0, dir.x)
	bb.spin_axis = axis.normalized() if axis.length() > 1e-6 else Vector3.RIGHT
	bb.mass = mass
	bb.bounces = 0
	bb.leaf = 0.0
	bb.laser = false
	return bb


## BBs in flight now.
func active_count() -> int:
	var n := 0
	for b in bbs:
		if b.active:
			n += 1
	return n
