class_name SightFold
extends SkeletonModifier3D
## Holds a replica's iron sights out of the way while an optic is fitted (ReplicaParts): its front and rear sight bones
## turned FOLD_ANGLE about x from their rest, over whatever its clips pose (the Fire and Reload clips key them upright),
## and the HIDDEN ones also shrunk to nothing at their bone's head (owner, 2026-11-04: "iron sights … should fold or
## disappear when a scope or optic is fitted"). A child of the replica's Skeleton3D; freeing it lets the clips' pose
## stand again.

const BONES: PackedStringArray = ["frontSight", "rearSight"]
## Folded flat along the rail, tipping forward (rad about the bone's x).
const FOLD_ANGLE := -PI * 0.5
## Sights that disappear as well as fold, on every replica that has them (today the AEG Rifle's and the Sniper Rifle's
## built from it): the front sight (ears and post on an A-frame base can't fold flat) and the rear leaf (folded, it
## would lie under an optic's mount). A sight bone left out of this list only folds.
const HIDDEN: PackedStringArray = ["frontSight", "rearSight"]
## A hidden sight's scale: too small to see, but not zero, so the bone's transform stays invertible.
const HIDDEN_SCALE := Vector3(0.001, 0.001, 0.001)

var _bones: PackedInt32Array = PackedInt32Array()
var _folded: Array[Quaternion] = []
var _scales: PackedVector3Array = PackedVector3Array()


## Holds `skeleton`'s sight bones (a replica without them folds nothing) folded from now on.
func setup(skeleton: Skeleton3D) -> void:
	name = "SightFold"
	for bone_name in BONES:
		var b := skeleton.find_bone(bone_name)
		if b >= 0:
			_bones.append(b)
			_folded.append(folded(skeleton, b))
			_scales.append(folded_scale(skeleton, b))


## Folds `skeleton`'s sight bones now (a picture, which nothing else poses; or before the modifier's first update).
static func fold(skeleton: Skeleton3D) -> void:
	for bone_name in BONES:
		var b := skeleton.find_bone(bone_name)
		if b >= 0:
			skeleton.set_bone_pose_rotation(b, folded(skeleton, b))
			skeleton.set_bone_pose_scale(b, folded_scale(skeleton, b))


## Bone `b`'s rotation folded down from its rest.
static func folded(skeleton: Skeleton3D, b: int) -> Quaternion:
	return skeleton.get_bone_rest(b).basis.get_rotation_quaternion() * Quaternion(Vector3.RIGHT, FOLD_ANGLE)


## Bone `b`'s scale out of the way: HIDDEN_SCALE for a hidden sight, its rest scale for one that folds.
static func folded_scale(skeleton: Skeleton3D, b: int) -> Vector3:
	if skeleton.get_bone_name(b) in HIDDEN:
		return HIDDEN_SCALE
	return skeleton.get_bone_rest(b).basis.get_scale()


## Puts `skeleton`'s sight bones back to their rest (the modifier gone, nothing else poses them in a picture).
static func unfold(skeleton: Skeleton3D) -> void:
	for bone_name in BONES:
		var b := skeleton.find_bone(bone_name)
		if b >= 0:
			skeleton.set_bone_pose_rotation(b, skeleton.get_bone_rest(b).basis.get_rotation_quaternion())
			skeleton.set_bone_pose_scale(b, skeleton.get_bone_rest(b).basis.get_scale())


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	for i in _bones.size():
		skeleton.set_bone_pose_rotation(_bones[i], _folded[i])
		skeleton.set_bone_pose_scale(_bones[i], _scales[i])
