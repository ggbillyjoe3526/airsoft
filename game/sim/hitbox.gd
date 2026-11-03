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
## A point this little outside a gait triangle (a share of its weights) still counts as in it: on a shared edge.
const BARYCENTRIC_EDGE := 1e-6

## may_touch's capsule (used only within one call).
static var _coarse: Capsule = Capsule.new()
## The fitted build's joints (_fit_pose: HitFit's lower and upper points), reused by every build.
static var _low: PackedVector3Array = PackedVector3Array()
static var _up: PackedVector3Array = PackedVector3Array()
## The lower body's samples blended, before _legs poses them into _low: the hips' place, and each turn's blended
## step from its rest (the hips', then each leg bone's).
static var _acc: PackedFloat32Array = PackedFloat32Array()
static var _turns: Array[Quaternion] = []
## The gait blend space's points weighted (_add_gait) and their weights.
static var _blend_point: PackedInt32Array = PackedInt32Array([0, 0, 0])
static var _blend_weight: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0])


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
## build it. Allocates nothing.
static func may_touch(c: Character, o: Vector3, d: Vector3, max_t: float, hits: HitConfig, margin: float = 0.0) -> bool:
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


## Moves the walk cycle on by the ground covered since last tick (c.prev_position); a jump of max_stride or more (a
## respawn, a move to the dead zone) is no step. Once a tick, after the movement step. Never wrapped, so the drawn legs
## can interpolate from last tick's.
static func step_walk_cycle(c: Character, hits: HitConfig) -> void:
	var moved := Vector2(c.position.x - c.prev_position.x, c.position.z - c.prev_position.z).length()
	if moved >= hits.max_stride:
		return
	c.walk_cycle += moved * hits.strides_per_metre * TAU


## Writes the character's hit volume now into `v`: standing on its feet, turned by its yaw, posed as its figure is
## drawn (HitConfig.fit), or the built-in volume crouched, leaned and on the walk cycle when there is no fit.
static func build_volume(c: Character, hits: HitConfig, v: Volume) -> void:
	if hits.fit != null:
		_build_fitted(c, hits, hits.fit, v)
		return
	_build(c.position, c.yaw, c.crouch_amount, c.lean, leg_swing(c.walk_cycle, c, hits), hits, v)


## Writes a still figure's hit volume into `v`: a character's standing on `feet`, turned by `yaw`, crouched by `crouch`
## (0..1), upright, legs at rest (a practice range figure, RangeTargets: a hit there is a hit in a match).
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
	for k: int in [CHEST_R, CHEST_FRONT, CHEST_BACK]:
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
	_fit_pose(c, hits, fit)
	var cos_yaw := cos(c.yaw)
	var sin_yaw := sin(c.yaw)
	var feet := c.position
	var hips := _low[HitFit.HIPS]
	var up := _low[HitFit.HIPS_Y]
	var head := _up[HitFit.HEAD].lerp(_up[HitFit.HEAD_TOP], hits.fit_head_centre)
	_fit_fill(v.head, feet, cos_yaw, sin_yaw, head, head, hits.fit_head_radius)
	# The torso: the spine's line, with the hips' forward square to it and the side square to both.
	var low := hips.lerp(_up[HitFit.SPINE1], hits.fit_chest_low)
	var high := _up[HitFit.CHEST].lerp(_up[HitFit.NECK], hits.fit_chest_high)
	var axis := (high - low).normalized()
	var ahead := _low[HitFit.HIPS_Z] - axis * _low[HitFit.HIPS_Z].dot(axis)
	ahead = ahead.normalized() if ahead.length_squared() > EPSILON else Vector3.FORWARD
	var side := axis.cross(ahead) * hits.fit_chest_half_width
	var front := ahead * hits.fit_chest_front
	var back := ahead * -hits.fit_chest_back
	ahead *= hits.fit_chest_ahead
	_fit_fill(v.parts[CHEST_L], feet, cos_yaw, sin_yaw, low - side + ahead, high - side + ahead, hits.fit_chest_radius)
	_fit_fill(v.parts[CHEST_R], feet, cos_yaw, sin_yaw, low + side + ahead, high + side + ahead, hits.fit_chest_radius)
	_fit_fill(v.parts[CHEST_FRONT], feet, cos_yaw, sin_yaw, low + front, high + front, hits.fit_chest_depth_radius)
	_fit_fill(v.parts[CHEST_BACK], feet, cos_yaw, sin_yaw, low + back, high + back, hits.fit_chest_depth_radius)
	var lift := up.normalized() * hits.fit_pelvis_up
	var drop := Vector3(0.0, -hits.fit_boot_drop, 0.0)
	for i in 2:
		var first := HitFit.THIGH_L if i == 0 else HitFit.THIGH_R
		var part := THIGH_L if i == 0 else THIGH_R
		var thigh := _low[first]
		var knee := _low[first + 1]
		var ankle := _low[first + 2]
		var toe := _low[first + 3]
		_fit_fill(v.parts[HIP_L + i], feet, cos_yaw, sin_yaw, thigh, thigh + lift, hits.fit_hips_radius)
		_fit_fill(v.parts[part], feet, cos_yaw, sin_yaw, thigh, knee, hits.fit_thigh_radius)
		_fit_fill(v.parts[part + 1], feet, cos_yaw, sin_yaw, knee, ankle, hits.fit_shin_radius)
		_fit_fill(v.parts[part + 2], feet, cos_yaw, sin_yaw, ankle + (ankle - toe) * hits.fit_boot_heel + drop,
				toe + drop, hits.fit_boot_radius)
	_bound(v, feet)


## The fitted joints of `c` in its figure's frame (HitFit's lower and upper points, as FigureBend leaves them) copied
## into `lower` and `upper` (resized to HitFit.LOWER and UPPER): for tests and tools.
static func fitted_joints(c: Character, hits: HitConfig, lower: PackedVector3Array, upper: PackedVector3Array) -> void:
	_fit_pose(c, hits, hits.fit)
	lower.resize(HitFit.LOWER)
	upper.resize(HitFit.UPPER)
	for k in HitFit.LOWER:
		lower[k] = _low[k]
	for k in HitFit.UPPER:
		upper[k] = _up[k]


## A capsule from the figure-frame points `a` to `b` of radius `r`, turned by the yaw onto `feet`.
static func _fit_fill(cap: Capsule, feet: Vector3, cos_yaw: float, sin_yaw: float, a: Vector3, b: Vector3,
		r: float) -> void:
	cap.a = feet + Vector3(a.x * cos_yaw + a.z * sin_yaw, a.y, a.z * cos_yaw - a.x * sin_yaw)
	cap.b = feet + Vector3(b.x * cos_yaw + b.z * sin_yaw, b.y, b.z * cos_yaw - b.x * sin_yaw)
	cap.r = r


## The fitted joints of `c` in its figure's frame (feet on the origin, facing -Z) into _low and _up (HitFit's points;
## the upper body's placed on the hips), as FigureBend leaves them: crouch-limited, leaned and aim-leaned.
static func _fit_pose(c: Character, hits: HitConfig, fit: HitFit) -> void:
	if _low.size() != HitFit.LOWER:
		_low.resize(HitFit.LOWER)
		_up.resize(HitFit.UPPER)
		_acc.resize(HitFit.HIPS_TURN)
		_turns.resize((HitFit.SAMPLE - HitFit.HIPS_TURN) / 4)
	_acc.fill(0.0)
	_turns.fill(Quaternion.IDENTITY)
	_up.fill(Vector3.ZERO)
	var alive := c.status == Character.Status.ALIVE
	var vaulting := alive and c.vault.active
	var crouch := clampf(c.crouch_amount, 0.0, 1.0)
	# The aim clips' blend (-1 down .. 1 up, FigurePose.aim_blend).
	var blend := clampf(c.pitch / fit.aim_pitch, -1.0, 1.0) if fit.aim_pitch > 0.0 else 0.0
	if vaulting:
		var vault := fit.table(&"vault_lower")
		var share := c.vault.clip_share(fit.vault_top) * float(fit.vault_samples - 1)
		var k := mini(int(share), fit.vault_samples - 2)
		var t := share - float(k)
		_add_lower(vault, k, 1.0 - t)
		_add_lower(vault, k + 1, t)
		_add_upper(fit.vault_upper, HitFit.UPPER * k, 1.0 - t)
		_add_upper(fit.vault_upper, HitFit.UPPER * (k + 1), t)
	else:
		if alive and not c.grounded:
			var jump := fit.table(&"jump")
			var span := fit.jump_to - fit.jump_from
			var share := clampf(maxf(c.air_time, 0.0) / span, 0.0, 1.0) if span > 0.0 else 1.0
			share *= float(fit.jump_samples - 1)
			var k := mini(int(share), fit.jump_samples - 2)
			var t := share - float(k)
			_add_lower(jump, k, 1.0 - t)
			_add_lower(jump, k + 1, t)
		else:
			# The step in the figure's frame (FigurePose.read): ahead and to the right; the legs step above the
			# walking speed, else the still clips play.
			var sin_yaw := sin(c.yaw)
			var cos_yaw := cos(c.yaw)
			var ahead := -c.velocity.x * sin_yaw - c.velocity.z * cos_yaw
			var right := c.velocity.x * cos_yaw - c.velocity.z * sin_yaw
			var moving := Vector2(c.velocity.x, c.velocity.z).length()
			var stepping := moving > hits.walking_speed
			if crouch < 1.0:
				if stepping:
					_add_gait(fit, Vector2(right, ahead), c.walk_cycle, 1.0 - crouch)
				else:
					_add_lower(fit.table(&"stand_still"), 0, 1.0 - crouch)
			if crouch > 0.0:
				if stepping:
					# Backwards, the crouched walk mirrored about its forward swing (FigureBody.animate).
					var back := crouch > fit.back_crouched and ahead < -fit.back_share * moving
					var cycle := fit.forward_phase * 2.0 - c.walk_cycle if back else c.walk_cycle
					_add_crouch(fit, Vector2(right, ahead).length(), cycle, crouch)
				else:
					_add_lower(fit.table(&"crouch_still"), 0, crouch)
		var a := c.armament
		if a != null and a.holstered:
			# Put away, the arms hang, or pump on a sprint (the holster's mix, FigureBody._animate_upper).
			_add_upper(fit.sprint if c.sprinting else fit.holster, 0, 1.0)
		else:
			var r := a.replica() if a != null else null
			var aims := fit.aim_pistol if r != null and r.site_class == &"pistol" else fit.aim_rifle
			var lo := 0 if blend < 0.0 else 1
			var t := blend + 1.0 if blend < 0.0 else blend
			_add_upper(aims, HitFit.UPPER * lo, 1.0 - t)
			_add_upper(aims, HitFit.UPPER * (lo + 1), t)
	_legs(fit)
	# The upper body on the blended hips.
	var o := _low[HitFit.HIPS]
	var x := _low[HitFit.HIPS_X]
	var y := _low[HitFit.HIPS_Y]
	var z := _low[HitFit.HIPS_Z]
	for k in HitFit.UPPER:
		var l := _up[k]
		_up[k] = o + x * l.x + y * l.y + z * l.z
	# FigureBend: the head's top held under the crouch's line (the whole figure lowered), then the upper body rolled
	# about the hip pivot by the lean, then pitched about the spine's joint by what the aim clips leave of the pitch.
	var limit := lerpf(hit_top(0.0, hits), fit.crouch_top_max, crouch)
	var sink := maxf(0.0, _up[HitFit.HEAD_TOP].y - limit)
	if sink > 0.0:
		for k in HitFit.LOWER:
			if k < HitFit.HIPS_X or k > HitFit.HIPS_Z:
				_low[k].y -= sink
		for k in HitFit.UPPER:
			_up[k].y -= sink
	if c.lean != 0.0:
		var pivot := hits.pivot_height - hits.crouch_drop * crouch
		var roll := c.lean * hits.lean_max_angle
		var cr := cos(roll)
		var sr := sin(roll)
		for k in HitFit.UPPER:
			var p := _up[k]
			var h := p.y - pivot
			_up[k] = Vector3(p.x * cr + h * sr, pivot + h * cr - p.x * sr, p.z)
	# The aim clips show, and the spine leans with them, unless vaulting, holstered or out (FigureBody.animate).
	var aiming := alive and not vaulting and not (c.armament != null and c.armament.holstered)
	if aiming:
		var bend := c.pitch - fit.aim_reach * fit.aim_pitch * blend
		if bend != 0.0:
			var spine := _up[HitFit.SPINE]
			var cb := cos(bend)
			var sb := sin(bend)
			for k in HitFit.UPPER:
				var d := _up[k] - spine
				_up[k] = spine + Vector3(d.x, d.y * cb - d.z * sb, d.y * sb + d.z * cb)


## Adds `w` of the gait blend space at `step` (m/s, the figure's frame) on walk cycle `cycle` to _low, weighted as
## AnimationNodeBlendSpace2D's interpolated mode weights its points: by the triangle the step lies in, else by the
## nearest point on the triangles' edges.
static func _add_gait(fit: HitFit, step: Vector2, cycle: float, w: float) -> void:
	var points := fit.gait_points
	var triangles := fit.gait_triangles
	var found := false
	for t in range(0, triangles.size(), 3):
		if _barycentric(step, points[triangles[t]], points[triangles[t + 1]], points[triangles[t + 2]]):
			for k in 3:
				_blend_point[k] = triangles[t + k]
			found = true
			break
	if not found:
		var best := INF
		for t in range(0, triangles.size(), 3):
			for j in 3:
				var s0 := points[triangles[t + j]]
				var s1 := points[triangles[t + (j + 1) % 3]]
				var closest := Geometry2D.get_closest_point_to_segment(step, s0, s1)
				var d := closest.distance_squared_to(step)
				if d < best:
					best = d
					var span := s0.distance_to(s1)
					var share := s0.distance_to(closest) / span if span > 0.0 else 0.0
					_blend_point[0] = triangles[t + j]
					_blend_point[1] = triangles[t + (j + 1) % 3]
					_blend_point[2] = triangles[t + j]
					_blend_weight[0] = 1.0 - share
					_blend_weight[1] = share
					_blend_weight[2] = 0.0
		if is_inf(best):
			_add_lower(fit.table(&"stand_still"), 0, w)
			return
	var steps := fit.table(&"gait")
	for k in 3:
		_add_stepped(fit, steps, _blend_point[k], cycle, w * _blend_weight[k])


## Whether `p` lies in the triangle `a`, `b`, `c` (its edges included), with its barycentric weights into
## _blend_weight (AnimationNodeBlendSpace2D's).
static func _barycentric(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var v0 := b - a
	var v1 := c - a
	var v2 := p - a
	var d00 := v0.dot(v0)
	var d01 := v0.dot(v1)
	var d11 := v1.dot(v1)
	var d20 := v2.dot(v0)
	var d21 := v2.dot(v1)
	var denom := d00 * d11 - d01 * d01
	if denom == 0.0:
		return false
	var v := (d11 * d20 - d01 * d21) / denom
	var u := (d00 * d21 - d01 * d20) / denom
	if v < -BARYCENTRIC_EDGE or u < -BARYCENTRIC_EDGE or v + u > 1.0 + BARYCENTRIC_EDGE:
		return false
	_blend_weight[0] = 1.0 - v - u
	_blend_weight[1] = v
	_blend_weight[2] = u
	return true


## Adds `w` of the crouch blend space at `speed` (m/s) on walk cycle `cycle` to _low: between the two points either
## side, held at the ends (AnimationNodeBlendSpace1D's interpolated mode).
static func _add_crouch(fit: HitFit, speed: float, cycle: float, w: float) -> void:
	var points := fit.crouch_points
	var last := points.size() - 1
	if speed <= points[0]:
		_add_stepped(fit, fit.table(&"crouch"), 0, cycle, w)
		return
	if speed >= points[last]:
		_add_stepped(fit, fit.table(&"crouch"), last, cycle, w)
		return
	var i := 0
	while points[i + 1] < speed:
		i += 1
	var t := (speed - points[i]) / (points[i + 1] - points[i])
	_add_stepped(fit, fit.table(&"crouch"), i, cycle, w * (1.0 - t))
	_add_stepped(fit, fit.table(&"crouch"), i + 1, cycle, w * t)


## Adds `w` of blend point `point`'s clip in `samples` on walk cycle `cycle`: the two phases either side.
static func _add_stepped(fit: HitFit, samples: HitFit.Table, point: int, cycle: float, w: float) -> void:
	if w == 0.0:
		return
	var q := fposmod(cycle, TAU) / TAU * float(fit.phases)
	var p0 := int(q) % fit.phases
	var g := q - floorf(q)
	_add_lower(samples, fit.clip_at(point, p0), w * (1.0 - g))
	_add_lower(samples, fit.clip_at(point, (p0 + 1) % fit.phases), w * g)


## Adds `w` of lower body sample `sample` of `table` (nothing when `w` is 0), as the animation graph blends a clip in
## (AnimationMixer): the hips' place by its weight into _acc, and each turn's step from its rest taken `w` of the way,
## after the steps already added, into _turns.
static func _add_lower(table: HitFit.Table, sample: int, w: float) -> void:
	if w == 0.0:
		return
	var place := table.places[sample] * w
	_acc[0] += place.x
	_acc[1] += place.y
	_acc[2] += place.z
	var at := sample * _turns.size()
	for j in _turns.size():
		_turns[j] = (_turns[j] * Quaternion.IDENTITY.slerp(table.steps[at + j], w)).normalized()


## The blended lower body (_acc, _turns) posed into _low: the hips, then each leg's bones down from them, each turned
## on its parent at its offset (HitFit.leg_offsets).
static func _legs(fit: HitFit) -> void:
	var hips := Transform3D(Basis(_turn(fit, 0)), Vector3(_acc[0], _acc[1], _acc[2]))
	_low[HitFit.HIPS] = hips.origin
	_low[HitFit.HIPS_X] = hips.basis.x
	_low[HitFit.HIPS_Y] = hips.basis.y
	_low[HitFit.HIPS_Z] = hips.basis.z
	var offsets := fit.leg_offsets
	for side in 2:
		var at := HitFit.THIGH_L if side == 0 else HitFit.THIGH_R
		var bone := hips
		for k in 3:
			bone = bone * Transform3D(Basis(_turn(fit, 1 + side * 3 + k)), offsets[side * 4 + k])
			_low[at + k] = bone.origin
		_low[at + 3] = bone * offsets[side * 4 + 3]


## Turn `j` blended: its rest, then the steps blended from it.
static func _turn(fit: HitFit, j: int) -> Quaternion:
	return (fit.rest(j) * _turns[j]).normalized()


## Adds `w` of the upper-body sample starting at `at` in `samples` to _up.
static func _add_upper(samples: PackedVector3Array, at: int, w: float) -> void:
	if w == 0.0:
		return
	for k in HitFit.UPPER:
		_up[k] += samples[at + k] * w
