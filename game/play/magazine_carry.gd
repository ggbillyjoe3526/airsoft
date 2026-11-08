class_name MagazineCarry
extends RefCounted
## Puts a replica's magazine bone in your left hand while the hand carries it through a reload (BP8, the owner's
## playtest note 9; ViewModelConfig.reload_carry). ReplicaView seeks the replica's Reload clip each frame of a reload,
## then places the bone here over the clip's pose; the magazine's part, on the bone's attachment, goes with it.

const BONE := "magazine"

var _skeleton: Skeleton3D = null
var _bone: int = -1


## A MagazineCarry for the skeleton under `model` that holds the magazine bone (its attachment named `attachment`);
## null for a model without one.
static func attach(model: Node, attachment: String) -> MagazineCarry:
	var mark := model.find_child(attachment, true, false) as BoneAttachment3D
	if mark == null:
		return null
	var skeleton := mark.get_parent() as Skeleton3D
	if skeleton == null or skeleton.find_bone(BONE) < 0:
		return null
	var carry := MagazineCarry.new()
	carry._skeleton = skeleton
	carry._bone = skeleton.find_bone(BONE)
	return carry


## The magazine bone's pose as the skeleton has it now, in `root`'s space (`root` an ancestor of the skeleton).
func in_root(root: Node3D) -> Transform3D:
	_skeleton.force_update_all_bone_transforms()
	return _skeleton_in(root) * _skeleton.get_bone_global_pose(_bone)


## Puts the magazine bone at `pose`, in `root`'s space, until the clip is posed again.
func place(root: Node3D, pose: Transform3D) -> void:
	_skeleton.set_bone_global_pose(_bone, _skeleton_in(root).affine_inverse() * pose)


func _skeleton_in(root: Node3D) -> Transform3D:
	return root.global_transform.affine_inverse() * _skeleton.global_transform
