class_name FigureArmsHold
extends RefCounted
## How the first-person arms (BL4, assets/models/arms/arms.glb, the owner's approved holds) hold one replica, for the
## figures' hands to take (HG1): each hand's place in the replica's own frame (its turn, and its knuckles' point) and
## each finger bone's turn against its hand and its joint's point (FigureConfig.hold_fingers' order). The right hand
## high on the grip, index on the trigger, thumb round the grip's left side; the left under a rifle's handguard,
## fingers on its right side, thumb along its left (lowered from a pistol, held one-handed). Read once a session by
## FigureModels.arms_hold; plain data.

## The right hand's frame in the replica's (orthonormal), and its knuckles' point there (FigureConfig.hold_knuckle's
## root, where the fingers start).
var right_hand: Transform3D = Transform3D.IDENTITY
var right_knuckle: Vector3 = Vector3.ZERO
## Each right finger bone's turn against the right hand (FigureConfig.hold_fingers with `_R`), and its root's point in
## the replica's frame (where the arms' finger joints are).
var right: Array[Basis] = []
var right_joints: PackedVector3Array = PackedVector3Array()
## Each right finger's tip in the replica's frame (past its last bone by that bone's length, as the one before's).
var right_tips: PackedVector3Array = PackedVector3Array()
var left_hand: Transform3D = Transform3D.IDENTITY
var left_knuckle: Vector3 = Vector3.ZERO
var left: Array[Basis] = []
var left_joints: PackedVector3Array = PackedVector3Array()
var left_tips: PackedVector3Array = PackedVector3Array()
## The right thumb's root (FigureConfig.hold_fingers' first) in the replica's frame, and the left's.
var right_thumb: Vector3 = Vector3.ZERO
var left_thumb: Vector3 = Vector3.ZERO


## Every hold `model` (the arms scene, not in the tree) carries, by replica id: its clip `<id>_Hold` read at its first
## frame onto the skeleton's rest, in the frame of its empty `Hold_<id>` (where the replica's origin sits). A hold
## missing a bone it needs is left out with a warning.
static func read_all(model: Node, config: FigureConfig) -> Dictionary[StringName, FigureArmsHold]:
	var out: Dictionary[StringName, FigureArmsHold] = {}
	var skeleton: Skeleton3D = null
	for n: Node in model.find_children("*", "Skeleton3D", true, false):
		skeleton = n as Skeleton3D
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if skeleton == null or player == null:
		push_warning("FigureArmsHold: the arms model has no skeleton or clips")
		return out
	var on_model := _to_model(skeleton, model)
	for n: Node in model.find_children(ArmsView.HOLD_PREFIX + "*", "Node3D", true, false):
		var id := StringName(String(n.name).trim_prefix(ArmsView.HOLD_PREFIX))
		var clip_name := StringName(String(id) + ArmsView.CLIP_SUFFIX)
		if not player.has_animation(clip_name):
			continue
		var clip := player.get_animation(clip_name)
		var bones := _posed(skeleton, clip)
		var in_hold := _to_model(n as Node3D, model).affine_inverse() * on_model
		var hold := FigureArmsHold.new()
		if hold._side(skeleton, bones, in_hold, "_R", config) and hold._side(skeleton, bones, in_hold, "_L", config):
			out[id] = hold
		else:
			push_warning("FigureArmsHold: the arms' %s hold is missing a hand bone" % id)
	return out


## Fills one side (`suffix` `_R` or `_L`) from `bones` (each bone's frame in the skeleton's), `in_hold` taking the
## skeleton's frame to the replica's. False when a bone is missing.
func _side(skeleton: Skeleton3D, bones: Array[Transform3D], in_hold: Transform3D, suffix: String,
		config: FigureConfig) -> bool:
	var hand := skeleton.find_bone(config.hold_hand + suffix)
	var knuckle := skeleton.find_bone(config.hold_knuckle + suffix)
	if hand < 0 or knuckle < 0:
		return false
	var at := in_hold * bones[hand]
	var frame := Transform3D(at.basis.orthonormalized(), at.origin)
	var turns: Array[Basis] = []
	var joints := PackedVector3Array()
	for finger in config.hold_fingers:
		var bone := skeleton.find_bone(finger + suffix)
		if bone < 0:
			return false
		var at_bone := in_hold * bones[bone]
		turns.append(frame.basis.inverse() * at_bone.basis.orthonormalized())
		joints.append(at_bone.origin)
	var tips := PackedVector3Array()
	var k := 0
	var per := FigureGrasp.BONES
	while k + per <= joints.size():
		var end := k + per - 1
		var last := frame.basis * turns[end]
		tips.append(joints[end] + last.y.normalized() * joints[end - 1].distance_to(joints[end]))
		k += per
	if suffix == "_R":
		right_hand = frame
		right_knuckle = (in_hold * bones[knuckle]).origin
		right = turns
		right_joints = joints
		right_tips = tips
		right_thumb = joints[0]
	else:
		left_hand = frame
		left_knuckle = (in_hold * bones[knuckle]).origin
		left = turns
		left_joints = joints
		left_tips = tips
		left_thumb = joints[0]
	return true


## Each bone's frame in `skeleton`'s, posed by `clip` at its start over the rest.
static func _posed(skeleton: Skeleton3D, clip: Animation) -> Array[Transform3D]:
	var local: Array[Transform3D] = []
	for i in skeleton.get_bone_count():
		local.append(skeleton.get_bone_rest(i))
	for t in clip.get_track_count():
		var bone := skeleton.find_bone(String(clip.track_get_path(t)).get_slice(":", 1))
		if bone < 0:
			continue
		var at := local[bone]
		match clip.track_get_type(t):
			Animation.TYPE_ROTATION_3D:
				at.basis = Basis(clip.rotation_track_interpolate(t, 0.0)) * Basis.from_scale(at.basis.get_scale())
			Animation.TYPE_POSITION_3D:
				at.origin = clip.position_track_interpolate(t, 0.0)
			Animation.TYPE_SCALE_3D:
				at.basis = at.basis.orthonormalized() * Basis.from_scale(clip.scale_track_interpolate(t, 0.0))
		local[bone] = at
	var out: Array[Transform3D] = []
	for i in skeleton.get_bone_count():
		var parent := skeleton.get_bone_parent(i)
		out.append(local[i] if parent < 0 else out[parent] * local[i])
	return out


## `node`'s frame in `model`'s (its parents' transforms up to it).
static func _to_model(node: Node3D, model: Node) -> Transform3D:
	var t := node.transform
	var up := node.get_parent()
	while up != null and up != model:
		if up is Node3D:
			t = (up as Node3D).transform * t
		up = up.get_parent()
	return t
