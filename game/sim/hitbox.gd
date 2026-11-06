class_name Hitbox
## What a BB can hit on a character, and ray tests against it (the browser game's sim/hitbox.ts, M85; HV1): a head
## sphere, the torso's four capsules, two hip capsules side by side, and each leg's thigh, shin and boot. A character's
## volume hangs on its drawn figure's own joints (HitConfig.fit, HitFit: baked from the figure's clips for its gait,
## crouch, walk cycle, aim, hold, jump and vault), then crouch-limited, leaned and aim-leaned as FigureBend draws it, so
## a BB is a hit where it meets the figure you see. Arms and replicas aren't part of it (owner, DECISIONS 2026-10-01).
## test_figure_hit_area.gd measures it against the drawn figure in every pose. A practice range plywood figure keeps the
## built-in volume it is drawn from (build_figure), as does a character when HitConfig.fit is null. Every ray test
## returns the distance along a unit ray to where it first touches, or INF for a miss; a ray that starts inside touches
## at 0.

## The shortest walk cycle (m): a guard against a zero length in the tables.
const MIN_CYCLE := 0.1

## Where each part sits in Volume.parts: the torso's four capsules, side by side and front and back (one chest capsule
## four times in the built-in volume), the hips, then each leg's thigh, shin and boot.
const CHEST_L := 0
const CHEST_R := 1
const CHEST_FRONT := 2
const CHEST_BACK := 3
const HIP_L := 4
const HIP_R := 5
const THIGH_L := 6
const SHIN_L := 7
const BOOT_L := 8
const THIGH_R := 9
const SHIN_R := 10
const BOOT_R := 11
const PART_COUNT := 12
## Below this, a squared length or a ray's squared reach across an axis counts as none (a point capsule, a ray along
## the axis).
const EPSILON := 1e-12

## may_touch's capsule (used only within one call).
static var _coarse: Capsule = Capsule.new()


## A capsule: the sphere centres a and b and the radius. A sphere has a == b; a vertical capsule (the head, the bound)
## has a straight below b.
class Capsule:
	extends RefCounted
	var a: Vector3 = Vector3.ZERO
	var b: Vector3 = Vector3.ZERO
	var r: float = 0.0


## A character's hit volume (build_volume): the head, the parts (CHEST … BOOT_R) and a vertical capsule round all of
## it, so a ray that misses the bound misses everything. Make one per caller and reuse it: building and testing it
## allocates nothing.
class Volume:
	extends RefCounted
	var head: Capsule = Capsule.new()
	var parts: Array[Capsule] = []
	var bound: Capsule = Capsule.new()

	func _init() -> void:
		for i in Hitbox.PART_COUNT:
			parts.append(Capsule.new())


## Distance along the unit ray `o + t·d` to where it enters the sphere at `center` of radius `r`, or INF.
static func ray_sphere(o: Vector3, d: Vector3, center: Vector3, r: float) -> float:
	var ox := o.x - center.x
	var oy := o.y - center.y
	var oz := o.z - center.z
	var c := ox * ox + oy * oy + oz * oz - r * r
	if c <= 0.0:
		return 0.0
	var b := ox * d.x + oy * d.y + oz * d.z
	if b > 0.0:
		return INF
	var disc := b * b - c
	if disc < 0.0:
		return INF
	return -b - sqrt(disc)


## Distance along the unit ray (0 ≤ t ≤ max_t) to where it first touches the vertical capsule `cap` (its axis at
## cap.a's x and z, from cap.a.y up to cap.b.y), or INF. The side of the cylinder, solved across, then the end spheres.
static func ray_vertical_capsule(o: Vector3, d: Vector3, max_t: float, cap: Capsule) -> float:
	var best := INF
	var ox := o.x - cap.a.x
	var oz := o.z - cap.a.z
	var a := d.x * d.x + d.z * d.z
	var c := ox * ox + oz * oz - cap.r * cap.r
	if c <= 0.0 and o.y >= cap.a.y and o.y <= cap.b.y:
		return 0.0
	if a > EPSILON:
		var b := ox * d.x + oz * d.z
		var disc := b * b - a * c
		if disc >= 0.0:
			var t := (-b - sqrt(disc)) / a
			if t >= 0.0:
				var y := o.y + d.y * t
				if y >= cap.a.y and y <= cap.b.y:
					best = t
	best = minf(best, ray_sphere(o, d, cap.a, cap.r))
	best = minf(best, ray_sphere(o, d, cap.b, cap.r))
	return best if best <= max_t else INF


## Distance along the unit ray (0 ≤ t ≤ max_t) to where it first touches the capsule `cap` along any segment, or INF.
## The same scheme as ray_vertical_capsule, with the side worked across the segment's axis.
static func ray_segment_capsule(o: Vector3, d: Vector3, max_t: float, cap: Capsule) -> float:
	var ux := cap.b.x - cap.a.x
	var uy := cap.b.y - cap.a.y
	var uz := cap.b.z - cap.a.z
	var len2 := ux * ux + uy * uy + uz * uz
	var ox := o.x - cap.a.x
	var oy := o.y - cap.a.y
	var oz := o.z - cap.a.z
	var r2 := cap.r * cap.r
	# Starts inside: the segment's closest point to `o` is within r.
	var s0 := clampf((ox * ux + oy * uy + oz * uz) / len2, 0.0, 1.0) if len2 > EPSILON else 0.0
	var ix := ox - ux * s0
	var iy := oy - uy * s0
	var iz := oz - uz * s0
	if ix * ix + iy * iy + iz * iz <= r2:
		return 0.0
	var best := INF
	if len2 > EPSILON:
		# The side: the parts of `o` and `d` across the axis, scaled by len2 to save a square root.
		var du := d.x * ux + d.y * uy + d.z * uz
		var ou := ox * ux + oy * uy + oz * uz
		var a := len2 - du * du
		if a > EPSILON:
			var b := len2 * (ox * d.x + oy * d.y + oz * d.z) - ou * du
			var c := len2 * (ox * ox + oy * oy + oz * oz) - ou * ou - r2 * len2
			var disc := b * b - a * c
			if disc >= 0.0:
				var t := (-b - sqrt(disc)) / a
				var along := ou + du * t
				if t >= 0.0 and along >= 0.0 and along <= len2:
					best = t
	best = minf(best, ray_sphere(o, d, cap.a, cap.r))
	best = minf(best, ray_sphere(o, d, cap.b, cap.r))
	return best if best <= max_t else INF


## Distance along the unit ray to the character's hit volume `v` (≤ max_t), or INF.
static func ray_character(o: Vector3, d: Vector3, max_t: float, v: Volume) -> float:
	if is_inf(ray_vertical_capsule(o, d, max_t, v.bound)):
		return INF
	var nearest := ray_vertical_capsule(o, d, max_t, v.head)
	for s: Capsule in v.parts:
		nearest = minf(nearest, ray_segment_capsule(o, d, minf(nearest, max_t), s))
	return nearest


## Whether the unit ray `o + t·d` (0 ≤ t ≤ max_t) passes within `margin` m of the room `c`'s hit volume could take
## (HitConfig.volume_reach and volume_top round its feet): false means it misses the volume, so there is no need to
## build it. Allocates nothing. A bounding-sphere test first (BP5): a character far from the whole segment is out at
## once, without the capsule test (most of them, for most BBs: a BB's tick passed every body through the capsule).
static func may_touch(c: Character, o: Vector3, d: Vector3, max_t: float, hits: HitConfig, margin: float = 0.0) -> bool:
	if is_finite(max_t):
		var half := 0.5 * max_t
		var up := 0.5 * hits.volume_top
		var reach := half + up + hits.volume_reach + margin
		var dx := o.x + d.x * half - c.position.x
		var dy := o.y + d.y * half - c.position.y - up
		var dz := o.z + d.z * half - c.position.z
		if dx * dx + dy * dy + dz * dz > reach * reach:
			return false
	_coarse.a = c.position
	_coarse.b = c.position + Vector3(0.0, hits.volume_top, 0.0)
	_coarse.r = hits.volume_reach + margin
	return not is_inf(ray_vertical_capsule(o, d, max_t, _coarse))


## Top of the hit volume (the top of the head) above the feet for a crouch of `crouch` (0..1).
static func hit_top(crouch: float, hits: HitConfig) -> float:
	return hits.head_height + hits.head_radius - hits.crouch_drop * crouch


## The legs' swing now (rad; the left leg's, the right swings the other way): the walk cycle `cycle`'s while moving
## faster than walking_speed, else 0. The drawn legs use it with the cycle interpolated between ticks.
static func leg_swing(cycle: float, c: Character, hits: HitConfig) -> float:
	if Vector2(c.velocity.x, c.velocity.z).length() > hits.walking_speed:
		return sin(cycle) * hits.leg_swing
	return 0.0


## Moves the walk cycle on by the ground covered since last tick (c.prev_position), a cycle every cycle_length of it;
## a jump of max_stride or more (a respawn, a move to the dead zone) is no step. Once a tick, after the movement step.
## Never wrapped, so the drawn legs can interpolate from last tick's.
static func step_walk_cycle(c: Character, hits: HitConfig) -> void:
	var moved := Vector2(c.position.x - c.prev_position.x, c.position.z - c.prev_position.z).length()
	if moved >= hits.max_stride or moved <= 0.0:
		return
	var speed := Vector2(c.velocity.x, c.velocity.z).length()
	# The step in the character's frame (FigurePose.read): ahead and to the right.
	var sin_yaw := sin(c.yaw)
	var cos_yaw := cos(c.yaw)
	var step := Vector2(c.velocity.x * cos_yaw - c.velocity.z * sin_yaw, -c.velocity.x * sin_yaw - c.velocity.z * cos_yaw)
	c.walk_cycle += moved / cycle_length(speed, c.crouch_amount, hits, step) * TAU


## The ground (m) one walk cycle (two steps) covers at `speed` (m/s), crouched `crouch` (0..1), stepping `step` (the
## character's frame: x to its right, y ahead; any length): HitConfig's standing lengths, in line between their speeds
## and shortened stepping back or aside (back_cycle_share, side_cycle_share by the step's share each way), and its
## crouched lengths, blended by the crouch.
static func cycle_length(speed: float, crouch: float, hits: HitConfig, step: Vector2 = Vector2(0.0, 1.0)) -> float:
	var standing := _by_speed(speed, hits.cycle_speeds, hits.cycle_metres) * way_share(step, hits)
	var crouched := _by_speed(speed, hits.crouch_cycle_speeds, hits.crouch_cycle_metres)
	return maxf(lerpf(standing, crouched, clampf(crouch, 0.0, 1.0)), MIN_CYCLE)


## The standing cycle's share for a step `step` (x right, y ahead): 1 ahead, back_cycle_share back, side_cycle_share
## aside, weighted by how much of the step goes each way; 1 for no step.
static func way_share(step: Vector2, hits: HitConfig) -> float:
	var ahead := maxf(step.y, 0.0)
	var back := maxf(-step.y, 0.0)
	var side := absf(step.x)
	var total := ahead + back + side
	if total <= 0.0:
		return 1.0
	return (ahead + back * hits.back_cycle_share + side * hits.side_cycle_share) / total


## `metres` at `speed` in line between the `speeds` (ascending) either side, held past the ends.
static func _by_speed(speed: float, speeds: PackedFloat32Array, metres: PackedFloat32Array) -> float:
	var last := mini(speeds.size(), metres.size()) - 1
	if last < 0:
		return MIN_CYCLE
	if speed <= speeds[0]:
		return metres[0]
	for k in last:
		if speed <= speeds[k + 1]:
			var span := speeds[k + 1] - speeds[k]
			var share := (speed - speeds[k]) / span if span > 0.0 else 1.0
			return lerpf(metres[k], metres[k + 1], share)
	return metres[last]


## Writes the character's hit volume now into `v`: standing on its feet, turned by its yaw, posed as its figure is
## drawn (HitConfig.fit), or the built-in volume crouched, leaned and on the walk cycle when there is no fit.
static func build_volume(c: Character, hits: HitConfig, v: Volume) -> void:
	if hits.fit != null:
		_build_fitted(c, hits, hits.fit, v)
		return
	_build(c.position, c.yaw, c.crouch_amount, c.lean, leg_swing(c.walk_cycle, c, hits), hits, v)


## Writes a still figure's hit volume into `v`: a character's standing on `feet`, turned by `yaw`, crouched by `crouch`
## (0..1), upright, legs at rest (a practice range figure, RangeTargets). It is the built-in plywood shape: a match's
## characters use the volume fitted to the drawn figure since HV1 (HitFit), a little different at the head and chest.
static func build_figure(feet: Vector3, yaw: float, crouch: float, hits: HitConfig, v: Volume) -> void:
	_build(feet, yaw, crouch, 0.0, 0.0, hits, v)


## The hit volume of a figure on `feet` turned by `yaw`, crouched by `crouch`, leaned by `lean` (-1..1), its legs swung
## by `swing` (rad), into `v`.
static func _build(feet: Vector3, yaw: float, crouch: float, lean: float, swing: float, hits: HitConfig,
		v: Volume) -> void:
	var drop := hits.crouch_drop * crouch
	var cos_yaw := cos(yaw)
	var sin_yaw := sin(yaw)
	# The upper body rolls about the hip pivot by the lean (Lean.offset's geometry: right is +x, so a lean right moves
	# the head along the character's right).
	var hip_y := hits.pivot_height - drop
	var roll := lean * hits.lean_max_angle
	var cr := cos(roll)
	var sr := sin(roll)
	var head_at := _upper(feet, cos_yaw, sin_yaw, 0.0, hits.head_height - drop, cr, sr, hip_y)
	_fill(v.head, head_at, head_at, hits.head_radius)
	_fill(v.parts[CHEST_L], _upper(feet, cos_yaw, sin_yaw, 0.0, hits.torso_bottom - drop, cr, sr, hip_y),
			_upper(feet, cos_yaw, sin_yaw, 0.0, hits.torso_top - drop, cr, sr, hip_y), hits.body_radius)
	# One chest: the fitted volume's other torso capsules sit on it (CHEST_R to CHEST_BACK, in order).
	for k: int in range(CHEST_R, CHEST_BACK + 1):
		_fill(v.parts[k], v.parts[CHEST_L].a, v.parts[CHEST_L].b, hits.body_radius)
	for i in 2:
		var side := 2 * i - 1
		var hx := side * hits.hips_half_width
		_fill(v.parts[HIP_L if side < 0 else HIP_R],
				_upper(feet, cos_yaw, sin_yaw, hx, hits.hips_bottom - drop, cr, sr, hip_y),
				_upper(feet, cos_yaw, sin_yaw, hx, hits.hips_top - drop, cr, sr, hip_y), hits.hips_radius)

	# The legs hang from the hip pivot, squashed towards it by a crouch as the drawn legs are, and swing about it.
	var squash := hip_y / hits.pivot_height
	for i in 2:
		var side := 2 * i - 1
		var hx := side * hits.leg_hip_spread
		# The left leg swings forward as the right goes back (the drawn legs: left rotation.x = swing, right = -swing).
		var angle := swing if side < 0 else -swing
		var cs := cos(angle)
		var sn := sin(angle)
		var first := THIGH_L if side < 0 else THIGH_R
		var hip := _leg(feet, cos_yaw, sin_yaw, hits.leg_hip_lift, 0.0, squash, cs, sn, hx, hip_y)
		var knee := _leg(feet, cos_yaw, sin_yaw, -hits.leg_knee, hits.leg_knee_z, squash, cs, sn, hx, hip_y)
		var ankle := _leg(feet, cos_yaw, sin_yaw, -hits.leg_ankle, 0.0, squash, cs, sn, hx, hip_y)
		_fill(v.parts[first], hip, knee, hits.leg_thigh_radius)
		_fill(v.parts[first + 1], knee, ankle, hits.leg_shin_radius)
		_fill(v.parts[first + 2], _leg(feet, cos_yaw, sin_yaw, -hits.boot_drop, hits.boot_heel, squash, cs, sn, hx, hip_y),
				_leg(feet, cos_yaw, sin_yaw, -hits.boot_drop, hits.boot_toe, squash, cs, sn, hx, hip_y), hits.boot_radius)
	_bound(v, feet)


## A figure-frame point (x right, y up from the feet, z forward-negative) in world space: turned by the yaw, at the feet.
static func _place(feet: Vector3, cos_yaw: float, sin_yaw: float, x: float, y: float, z: float) -> Vector3:
	return Vector3(feet.x + x * cos_yaw + z * sin_yaw, feet.y + y, feet.z - x * sin_yaw + z * cos_yaw)


## An upper-body point (`x` across, `y` up from the feet, crouch already taken off) rolled about the hip pivot at
## `pivot` by the lean's roll (cosine `cr`, sine `sr`), placed.
static func _upper(feet: Vector3, cos_yaw: float, sin_yaw: float, x: float, y: float, cr: float, sr: float,
		pivot: float) -> Vector3:
	var h := y - pivot
	return _place(feet, cos_yaw, sin_yaw, x * cr + h * sr, pivot + h * cr - x * sr, 0.0)


## A leg's point (`y` up from the hip pivot, `z` forward-negative), squashed by `squash` towards the hip, swung by the
## angle whose cosine and sine are `cs`, `sn` about it, at the hip (`hx` across, `hip_y` up), placed.
static func _leg(feet: Vector3, cos_yaw: float, sin_yaw: float, y: float, z: float, squash: float, cs: float,
		sn: float, hx: float, hip_y: float) -> Vector3:
	var sy := y * squash
	return _place(feet, cos_yaw, sin_yaw, hx, hip_y + sy * cs - z * sn, sy * sn + z * cs)


static func _fill(cap: Capsule, a: Vector3, b: Vector3, r: float) -> void:
	cap.a = a
	cap.b = b
	cap.r = r


## Sets v.bound round the rest of `v`: a vertical capsule on the feet's axis whose spheres sit at the lowest and highest
## point, reaching as far out as anything does (a capsule lies within its two end spheres).
static func _bound(v: Volume, feet: Vector3) -> void:
	var reach := 0.0
	var lo := INF
	var hi := -INF
	# The head, then each part, both ends (no array of points: building the bound allocates nothing).
	for k in PART_COUNT + 1:
		var cap: Capsule = v.head if k == 0 else v.parts[k - 1]
		var a := cap.a
		var b := cap.b
		var r := cap.r
		var ax := a.x - feet.x
		var az := a.z - feet.z
		var bx := b.x - feet.x
		var bz := b.z - feet.z
		reach = maxf(reach, sqrt(maxf(ax * ax + az * az, bx * bx + bz * bz)) + r)
		lo = minf(lo, minf(a.y, b.y) - r)
		hi = maxf(hi, maxf(a.y, b.y) + r)
	v.bound.a = Vector3(feet.x, lo, feet.z)
	v.bound.b = Vector3(feet.x, hi, feet.z)
	v.bound.r = reach


## The fitted volume of `c` (HV1) from `fit`'s joints: the lower body for its gait, crouch and walk cycle (in the air
## the Jump clip's, vaulting the Vault clip's), the upper body on the hips for its aim and hold, then FigureBend's crouch
## limit, lean and aim lean, and the capsules on the joints, turned by its yaw onto its feet.
static func _build_fitted(c: Character, hits: HitConfig, fit: HitFit, v: Volume) -> void:
	HitPose.pose(c, hits, fit)
	var cos_yaw := cos(c.yaw)
	var sin_yaw := sin(c.yaw)
	var feet := c.position
	var hips := HitPose.lower[HitFit.HIPS]
	var up := HitPose.lower[HitFit.HIPS_Y]
	var head := HitPose.upper[HitFit.HEAD].lerp(HitPose.upper[HitFit.HEAD_TOP], hits.fit_head_centre)
	_fit_fill(v.head, feet, cos_yaw, sin_yaw, head, head, hits.fit_head_radius)
	# The torso: the spine's line, with the hips' forward square to it and the side square to both.
	var low := hips.lerp(HitPose.upper[HitFit.SPINE1], hits.fit_chest_low)
	var high := HitPose.upper[HitFit.CHEST].lerp(HitPose.upper[HitFit.NECK], hits.fit_chest_high)
	var axis := (high - low).normalized()
	var ahead := HitPose.lower[HitFit.HIPS_Z] - axis * HitPose.lower[HitFit.HIPS_Z].dot(axis)
	ahead = ahead.normalized() if ahead.length_squared() > EPSILON else Vector3.FORWARD
	var side := axis.cross(ahead) * hits.fit_chest_half_width
	var front := ahead * hits.fit_chest_front
	var back := ahead * -hits.fit_chest_back
	ahead *= hits.fit_chest_ahead
	_fit_fill(v.parts[CHEST_L], feet, cos_yaw, sin_yaw, low - side + ahead, high - side + ahead, hits.fit_chest_radius)
	_fit_fill(v.parts[CHEST_R], feet, cos_yaw, sin_yaw, low + side + ahead, high + side + ahead, hits.fit_chest_radius)
	_fit_fill(v.parts[CHEST_FRONT], feet, cos_yaw, sin_yaw, low + front, high + front, hits.fit_chest_depth_radius)
	var back_high := HitPose.upper[HitFit.CHEST].lerp(HitPose.upper[HitFit.NECK], hits.fit_chest_back_high)
	_fit_fill(v.parts[CHEST_BACK], feet, cos_yaw, sin_yaw, low.lerp(back_high, hits.fit_chest_back_low) + back,
			back_high + back, hits.fit_chest_back_radius)
	var lift := up.normalized() * hits.fit_pelvis_up
	var drop := Vector3(0.0, -hits.fit_boot_drop, 0.0)
	for i in 2:
		var first := HitFit.THIGH_L if i == 0 else HitFit.THIGH_R
		var part := THIGH_L if i == 0 else THIGH_R
		var thigh := HitPose.lower[first]
		var knee := HitPose.lower[first + 1]
		var ankle := HitPose.lower[first + 2]
		var toe := HitPose.lower[first + 3]
		_fit_fill(v.parts[HIP_L + i], feet, cos_yaw, sin_yaw, thigh, thigh + lift, hits.fit_hips_radius)
		_fit_fill(v.parts[part], feet, cos_yaw, sin_yaw, thigh, knee, hits.fit_thigh_radius)
		_fit_fill(v.parts[part + 1], feet, cos_yaw, sin_yaw, knee, ankle, hits.fit_shin_radius)
		_fit_fill(v.parts[part + 2], feet, cos_yaw, sin_yaw, ankle + (ankle - toe) * hits.fit_boot_heel + drop,
				toe + drop, hits.fit_boot_radius)
	_bound(v, feet)


## The fitted joints of `c` in its figure's frame (HitFit's lower and upper points, as FigureBend leaves them) copied
## into `lower` and `upper` (resized to HitFit.LOWER and UPPER): for tests and tools.
static func fitted_joints(c: Character, hits: HitConfig, lower: PackedVector3Array, upper: PackedVector3Array) -> void:
	HitPose.pose(c, hits, hits.fit)
	lower.resize(HitFit.LOWER)
	upper.resize(HitFit.UPPER)
	for k in HitFit.LOWER:
		lower[k] = HitPose.lower[k]
	for k in HitFit.UPPER:
		upper[k] = HitPose.upper[k]


## A capsule from the figure-frame points `a` to `b` of radius `r`, turned by the yaw onto `feet`.
static func _fit_fill(cap: Capsule, feet: Vector3, cos_yaw: float, sin_yaw: float, a: Vector3, b: Vector3,
		r: float) -> void:
	cap.a = feet + Vector3(a.x * cos_yaw + a.z * sin_yaw, a.y, a.z * cos_yaw - a.x * sin_yaw)
	cap.b = feet + Vector3(b.x * cos_yaw + b.z * sin_yaw, b.y, b.z * cos_yaw - b.x * sin_yaw)
	cap.r = r
