class_name IronSights
extends RefCounted
## A replica's iron sights, which an optic removes completely, never folds (owner, 2026-11-05: so they don't get in the
## optic's way; a standing rule for every replica, later ones too). A model hangs every piece of its iron sights (base,
## leaf, ears, post) from a bone whose name ends in "Sight" (frontSight, rearSight; docs/CC0_ASSETS.md › Replica
## models), so hiding those bones' attachments hides the sights whole, whatever the clips do to the bones.

## A sight bone's name ends in this, in any case.
const BONE_SUFFIX := "sight"


## `model`'s iron sights: its bone attachments on sight bones (none for a replica without iron sights).
static func of(model: Node) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for node in model.find_children("*", "BoneAttachment3D", true, false):
		var attachment := node as BoneAttachment3D
		if attachment.bone_name.to_lower().ends_with(BONE_SUFFIX):
			out.append(attachment)
	return out
