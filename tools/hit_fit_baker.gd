class_name HitFitBaker
extends RefCounted
## Bakes HitFit (HV1) from a kind's rigged figure: a FigureBody posed from a Character through its own FigurePose and
## animation graph, as in play, with FigureBend switched off (Hitbox applies the crouch limit, the lean and the aim lean
## itself, as FigureBend does), and its joints read on every sample HitFit holds. Dev only (tools/ never ships):
## tools/hit_fit_bake.gd writes the file, test_hit_fit.gd bakes again to catch a stale one.

## The kind baked: the human (robots are a Dev easter egg, measured against the same fit).
const KIND := FigureMix.HUMAN

var _models: FigureModels = null
var _hits: HitConfig = null
var _moves: MovementConfig = null
var _body: FigureBody = null
var _hips: int = -1
var _bones: PackedInt32Array = PackedInt32Array()


## Bakes `models`' human against `hits` and `moves`' speeds; the figure is built under `parent` (it must be in the tree)
## and freed before this returns.
func bake(models: FigureModels, hits: HitConfig, moves: MovementConfig, parent: Node) -> HitFit:
	_models = models
	_hits = hits
	_moves = moves
	var cfg := models.config
	_body = FigureBody.new()
	_body.setup(models, KIND, 0, 0, Color.RED, 0.0, cfg.lod_high)
	parent.add_child(_body)
	_body.bend.active = false
	var sk := _body.skeleton
	_hips = sk.find_bone(cfg.hips_bone)
	_bones = PackedInt32Array()
	for bone_name: String in ["Thigh_L", "Shin_L", "Foot_L", "Toe_L", "Thigh_R", "Shin_R", "Foot_R", "Toe_R",
			"Spine", "Spine1", "Chest", "Neck", "Head", "UpperArm_L", "UpperArm_R"]:
		_bones.append(sk.find_bone(bone_name))
	var fit := HitFit.new()
	fit.jump_from = cfg.jump_from
	fit.jump_to = cfg.jump_to
	fit.vault_top = cfg.vault_top
	fit.aim_pitch = cfg.aim_pitch
	fit.aim_reach = cfg.aim_reach
	fit.crouch_top_max = cfg.crouch_top_max
	fit.forward_phase = FigureGraph.FORWARD_PHASE
	fit.back_share = cfg.back_share
	fit.back_crouched = cfg.back_crouched
	fit.source = "%s%s.glb; gait %s; crouch %s" % [cfg.models_dir, cfg.kinds[KIND], ",".join(cfg.gait_clips),
			cfg.crouch_walk_clip]
	_blend_spaces(fit)
	fit.leg_offsets = _offsets()
	var rests := PackedFloat32Array()
	_turn(rests, (_frame() * sk.get_bone_global_rest(_hips)).basis.get_rotation_quaternion())
	for side in 2:
		for k in 3:
			_turn(rests, sk.get_bone_rest(_bones[side * 4 + k]).basis.get_rotation_quaternion())
	fit.rests = rests
	var jumps := PackedFloat32Array()
	for i in fit.jump_samples:
		var c := _character()
		c.grounded = false
		c.air_time = (fit.jump_to - fit.jump_from) * float(i) / float(fit.jump_samples - 1)
		_pose(c)
		_lower(jumps)
	fit.jump = jumps
	var vault_lower := PackedFloat32Array()
	var vault_upper := PackedVector3Array()
	for i in fit.vault_samples:
		var c := _character()
		c.grounded = false
		_vault_at(c, float(i) / float(fit.vault_samples - 1), fit.vault_top)
		_pose(c)
		_lower(vault_lower)
		_upper(vault_upper)
	fit.vault_lower = vault_lower
	fit.vault_upper = vault_upper
	var pistol := _pistol_slot(_character())
	for hold in 2:
		var aims := PackedVector3Array()
		for a in HitFit.AIMS:
			var c := _character()
			c.pitch = float(a - 1) * fit.aim_pitch
			if hold == 1 and pistol >= 0:
				c.armament.active = pistol
			_pose(c)
			_upper(aims)
		if hold == 0:
			fit.aim_rifle = aims
		else:
			fit.aim_pistol = aims
	var away := _character()
	away.armament.holstered = true
	_pose(away)
	var holstered := PackedVector3Array()
	_upper(holstered)
	fit.holster = holstered
	var running := _character()
	running.velocity = Vector3(0.0, 0.0, -moves.sprint_speed)
	running.sprinting = true
	running.armament.holstered = true
	_pose(running)
	var sprinting := PackedVector3Array()
	_upper(sprinting)
	fit.sprint = sprinting
	_body.queue_free()
	_body = null
	return fit


## The lower body still (standing, then crouched: the graph's first run also triangulates the gait space), then each
## blend space point's clip at each phase, posed through the graph's own parameters.
func _blend_spaces(fit: HitFit) -> void:
	var still := _character()
	_pose(still)
	var stand_still := PackedFloat32Array()
	_lower(stand_still)
	fit.stand_still = stand_still
	still.crouch_amount = 1.0
	_pose(still)
	var crouch_still := PackedFloat32Array()
	_lower(crouch_still)
	fit.crouch_still = crouch_still
	var graph := _body.tree.tree_root as AnimationNodeBlendTree
	var gait := graph.get_node(FigureGraph.GAIT) as AnimationNodeBlendSpace2D
	var crouch := graph.get_node(FigureGraph.CROUCH_SPACE) as AnimationNodeBlendSpace1D
	var points := PackedVector2Array()
	for i in gait.get_blend_point_count():
		points.append(gait.get_blend_point_position(i))
	fit.gait_points = points
	var triangles := PackedInt32Array()
	for t in gait.get_triangle_count():
		for k in 3:
			triangles.append(gait.get_triangle_point(t, k))
	fit.gait_triangles = triangles
	var speeds := PackedFloat32Array()
	for i in crouch.get_blend_point_count():
		speeds.append(crouch.get_blend_point_position(i))
	fit.crouch_points = speeds
	var stepped := PackedFloat32Array()
	for i in points.size():
		for phase in fit.phases:
			_pose_clip(points[i], 0.0, 0.0, TAU * float(phase) / float(fit.phases))
			_lower(stepped)
	fit.gait = stepped
	var crouched := PackedFloat32Array()
	for i in speeds.size():
		for phase in fit.phases:
			_pose_clip(Vector2.ZERO, speeds[i], 1.0, TAU * float(phase) / float(fit.phases))
			_lower(crouched)
	fit.crouch = crouched


## Poses the legs at gait blend position `step`, crouch blend position `speed` and crouch `crouch`, both stepped to
## walk cycle `cycle`: a still figure's parameters overridden, so each blend space plays its point's clip alone.
func _pose_clip(step: Vector2, speed: float, crouch: float, cycle: float) -> void:
	var c := _character()
	c.crouch_amount = crouch
	_pose(c)
	var tree := _body.tree
	tree.set(FigureGraph.P_GAIT, step)
	tree.set(FigureGraph.P_CROUCH_SPACE, speed)
	tree.set(FigureGraph.P_CROUCH, crouch)
	tree.set(FigureGraph.P_GAIT_SEEK, cycle)
	tree.set(FigureGraph.P_CROUCH_SEEK, cycle)
	tree.advance(0.0)
	_body.skeleton.notification(Skeleton3D.NOTIFICATION_UPDATE_SKELETON)


## A Character standing on the origin facing -Z with the default loadout, everything at rest.
func _character() -> Character:
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	c.grounded = true
	return c


## Puts `c` `share` (0..1) of the way through the Vault clip (HitFit's vault samples).
static func _vault_at(c: Character, share: float, top: float) -> void:
	c.vault.active = true
	c.vault.rise_end = 1.0
	c.vault.end = 2.0
	c.vault.time = share / top if share < top else 1.0 + (share - top) / (1.0 - top)


func _pistol_slot(c: Character) -> int:
	for i in c.armament.replicas.size():
		if c.armament.replicas[i].site_class == &"pistol":
			return i
	return -1


## Poses the figure as `c`, its blends snapped, and updates the skeleton (no bend: FigureBend is off).
func _pose(c: Character) -> void:
	c.prev_position = c.position
	c.prev_yaw = c.yaw
	c.prev_pitch = c.pitch
	c.prev_lean = c.lean
	c.prev_crouch_amount = c.crouch_amount
	c.prev_walk_cycle = c.walk_cycle
	var pose := FigurePose.new(_models.config)
	pose.read(c, 1.0, _hits)
	pose.snap()
	_body.animate(pose, _hits, 0.0)
	_body.animate(pose, _hits, 0.0)
	_body.skeleton.notification(Skeleton3D.NOTIFICATION_UPDATE_SKELETON)


## The figure's frame: the skeleton's place (the figure stands on the origin at yaw 0, so it is the figure's frame).
func _frame() -> Transform3D:
	return _body.skeleton.global_transform


func _point(bone: int) -> Vector3:
	return _frame() * _body.skeleton.get_bone_global_pose(bone).origin


## Appends the lower body's sample (HitFit.SAMPLE floats) to `into`: the hips' place and turn in the figure's frame,
## then each leg bone's turn on its parent.
func _lower(into: PackedFloat32Array) -> void:
	var sk := _body.skeleton
	var hips := _frame() * sk.get_bone_global_pose(_hips)
	into.append(hips.origin.x)
	into.append(hips.origin.y)
	into.append(hips.origin.z)
	_turn(into, hips.basis.get_rotation_quaternion())
	for side in 2:
		for k in 3:
			_turn(into, sk.get_bone_pose_rotation(_bones[side * 4 + k]))


static func _turn(into: PackedFloat32Array, q: Quaternion) -> void:
	into.append(q.x)
	into.append(q.y)
	into.append(q.z)
	into.append(q.w)


## Each leg bone's offset on its parent (HitFit.leg_offsets): the thigh, shin, foot and toe, left then right.
func _offsets() -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in 8:
		out.append(_body.skeleton.get_bone_pose_position(_bones[i]))
	return out


## Appends the upper body's points (HitFit.UPPER) in the Hips bone's frame to `into`.
func _upper(into: PackedVector3Array) -> void:
	var sk := _body.skeleton
	var to_hips := (_frame() * sk.get_bone_global_pose(_hips)).affine_inverse()
	for i in range(8, 13):
		into.append(to_hips * _point(_bones[i]))
	var head := sk.get_bone_global_pose(_bones[12])
	into.append(to_hips * (_frame() * (head * Vector3(0.0, _models.config.head_top, 0.0))))
	into.append(to_hips * _point(_bones[13]))
	into.append(to_hips * _point(_bones[14]))
