extends GutTest
## HA1 QA, attempt 5 re-run 9: each foregrip's fist stays closed round the grip on the AEG and the Sniper. Every left
## finger's three joints' bends sum to at least FLOOR degrees, on the skinned model, so a build that leaves the
## fingers loose (ring and middle not closed, little half closed) fails.

const MODEL_PATH := "res://assets/models/arms/arms.glb"
const FINGERS: Array[String] = ["Index", "Middle", "Ring", "Pinky"]
const GRIPPED: Array[StringName] = [&"aeg", &"sniper"]
const GRIPS: Array[String] = ["vertical", "angled"]
## The least (degrees) each finger's three joints bend in all, each against the bone before it (the hand's first).
const FLOOR := {"Index": 110.0, "Middle": 140.0, "Ring": 330.0, "Pinky": 330.0}


func _posed(clip: StringName) -> Skeleton3D:
	var model := (load(MODEL_PATH) as PackedScene).instantiate()
	add_child_autofree(model)
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert_true(player.has_animation(clip), "the model has %s" % clip)
	player.play(clip)
	player.pause()
	player.seek(0.0, true)
	var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	skeleton.force_update_all_bone_transforms()
	return skeleton


func test_every_left_finger_is_closed_round_each_foregrip() -> void:
	for id in GRIPPED:
		for key in GRIPS:
			var clip := StringName("%s_grip_%s_Hold" % [id, key])
			var sk := _posed(clip)
			for f in FINGERS:
				var turned := 0.0
				var parent := sk.get_bone_global_pose(sk.find_bone("Hand_L")).basis.y.normalized()
				for n: String in ["1", "2", "3"]:
					var axis := sk.get_bone_global_pose(sk.find_bone(f + n + "_L")).basis.y.normalized()
					turned += rad_to_deg(parent.angle_to(axis))
					parent = axis
				gut.p("%s %s %.0f" % [clip, f, turned])
				assert_gt(turned, FLOOR[f] as float, "%s: the %s finger closed round the grip (%.0f degrees)" % [clip, f, turned])
