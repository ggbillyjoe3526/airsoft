class_name HitPose
## The fitted hit volume's pose (HV1): the human figure's joints in its own frame (feet on the origin, facing -Z), posed
## from HitFit's samples as its animation graph blends them (the gait and crouch blend spaces, the crouch, the jump and
## the vault, each turn blended as AnimationMixer does, the legs posed down from the hips, the upper body for the aim
## and hold) and then bent as FigureBend draws it. Hitbox.build_volume hangs the capsules on them. Allocates nothing.

## A point this little outside a gait triangle (a share of its weights) still counts as in it: on a shared edge.
const BARYCENTRIC_EDGE := 1e-6

## The joints posed (HitFit's lower and upper points), reused by every pose(): read them before the next call.
static var lower: PackedVector3Array = PackedVector3Array()
static var upper: PackedVector3Array = PackedVector3Array()
## The lower body's samples blended, before _legs poses them into lower: the hips' place, and each turn's blended
## step from its rest (the hips', then each leg bone's).
static var _acc: PackedFloat32Array = PackedFloat32Array()
static var _turns: Array[Quaternion] = []
## The gait blend space's points weighted (_add_gait) and their weights.
static var _blend_point: PackedInt32Array = PackedInt32Array([0, 0, 0])
static var _blend_weight: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0])


## The fitted joints of `c` in its figure's frame (feet on the origin, facing -Z) into lower and upper (HitFit's points;
## the upper body's placed on the hips), as FigureBend leaves them: crouch-limited, leaned and aim-leaned.
static func pose(c: Character, hits: HitConfig, fit: HitFit) -> void:
	if lower.size() != HitFit.LOWER:
		lower.resize(HitFit.LOWER)
		upper.resize(HitFit.UPPER)
		_acc.resize(HitFit.HIPS_TURN)
		_turns.resize((HitFit.SAMPLE - HitFit.HIPS_TURN) / 4)
	_acc.fill(0.0)
	_turns.fill(Quaternion.IDENTITY)
	upper.fill(Vector3.ZERO)
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
	var o := lower[HitFit.HIPS]
	var x := lower[HitFit.HIPS_X]
	var y := lower[HitFit.HIPS_Y]
	var z := lower[HitFit.HIPS_Z]
	for k in HitFit.UPPER:
		var l := upper[k]
		upper[k] = o + x * l.x + y * l.y + z * l.z
	# FigureBend: the head's top held under the crouch's line (the whole figure lowered), then the upper body rolled
	# about the hip pivot by the lean, then pitched about the spine's joint by what the aim clips leave of the pitch.
	var limit := lerpf(Hitbox.hit_top(0.0, hits), fit.crouch_top_max, crouch)
	var sink := maxf(0.0, upper[HitFit.HEAD_TOP].y - limit)
	if sink > 0.0:
		for k in HitFit.LOWER:
			if k < HitFit.HIPS_X or k > HitFit.HIPS_Z:
				lower[k].y -= sink
		for k in HitFit.UPPER:
			upper[k].y -= sink
	if c.lean != 0.0:
		var pivot := hits.pivot_height - hits.crouch_drop * crouch
		var roll := c.lean * hits.lean_max_angle
		var cr := cos(roll)
		var sr := sin(roll)
		for k in HitFit.UPPER:
			var p := upper[k]
			var h := p.y - pivot
			upper[k] = Vector3(p.x * cr + h * sr, pivot + h * cr - p.x * sr, p.z)
	# The aim clips show, and the spine leans with them, unless vaulting, holstered or out (FigureBody.animate).
	var aiming := alive and not vaulting and not (c.armament != null and c.armament.holstered)
	if aiming:
		var bend := c.pitch - fit.aim_reach * fit.aim_pitch * blend
		if bend != 0.0:
			var spine := upper[HitFit.SPINE]
			var cb := cos(bend)
			var sb := sin(bend)
			for k in HitFit.UPPER:
				var d := upper[k] - spine
				upper[k] = spine + Vector3(d.x, d.y * cb - d.z * sb, d.y * sb + d.z * cb)


## Adds `w` of the gait blend space at `step` (m/s, the figure's frame) on walk cycle `cycle` to lower, weighted as
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


## Adds `w` of the crouch blend space at `speed` (m/s) on walk cycle `cycle` to lower: between the two points either
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


## The blended lower body (_acc, _turns) posed into lower: the hips, then each leg's bones down from them, each turned
## on its parent at its offset (HitFit.leg_offsets).
static func _legs(fit: HitFit) -> void:
	var hips := Transform3D(Basis(_turn(fit, 0)), Vector3(_acc[0], _acc[1], _acc[2]))
	lower[HitFit.HIPS] = hips.origin
	lower[HitFit.HIPS_X] = hips.basis.x
	lower[HitFit.HIPS_Y] = hips.basis.y
	lower[HitFit.HIPS_Z] = hips.basis.z
	var offsets := fit.leg_offsets
	for side in 2:
		var at := HitFit.THIGH_L if side == 0 else HitFit.THIGH_R
		var bone := hips
		for k in 3:
			bone = bone * Transform3D(Basis(_turn(fit, 1 + side * 3 + k)), offsets[side * 4 + k])
			lower[at + k] = bone.origin
		lower[at + 3] = bone * offsets[side * 4 + 3]


## Turn `j` blended: its rest, then the steps blended from it.
static func _turn(fit: HitFit, j: int) -> Quaternion:
	return (fit.rest(j) * _turns[j]).normalized()


## Adds `w` of the upper-body sample starting at `at` in `samples` to upper.
static func _add_upper(samples: PackedVector3Array, at: int, w: float) -> void:
	if w == 0.0:
		return
	for k in HitFit.UPPER:
		upper[k] += samples[at + k] * w
