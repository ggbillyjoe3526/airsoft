extends GutTest
## HA1, the owner's fourth look (2026-11-12): "With a vertical grip the index finger should be under the replica and
## around the grip. Angled grip should be held similar to the vertical grip": on each foregrip's hold in the arms
## model the left hand is a fist, and both grips are held alike.

const MODEL_PATH := "res://assets/models/arms/arms.glb"
const GRIPPED: Array[StringName] = [&"aeg", &"sniper"]
const GRIPS: Array[String] = ["vertical", "angled"]
## The fingers that close round the grip, and how far (degrees) each one's tip bone at least turns from its first.
const ROUND: Array[String] = ["Index", "Middle"]
const CLOSED := 55.0
## How far (degrees) the two grips' fists may differ, hand against forearm aside: each finger's tip bone in the
## hand's own frame.
const ALIKE := 45.0
## How far (m) the index finger's tip at least comes back toward the thumb's side of the grip from its knuckle,
## measured along the palm's facing: round the grip, not lying open beside it.
const WRAPPED := 0.015


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


func _bone(skeleton: Skeleton3D, bone_name: String) -> Transform3D:
	return skeleton.get_bone_global_pose(skeleton.find_bone(bone_name))


## How far (degrees) `finger`'s tip bone is turned from its first bone: 0 lying straight, about 180 a closed fist.
func _closed(skeleton: Skeleton3D, finger: String) -> float:
	var first := _bone(skeleton, finger + "1_L").basis.y.normalized()
	var last := _bone(skeleton, finger + "3_L").basis.y.normalized()
	return rad_to_deg(first.angle_to(last))


func test_the_index_and_middle_fingers_close_round_each_foregrip() -> void:
	for id in GRIPPED:
		for key in GRIPS:
			var clip := StringName("%s_grip_%s_Hold" % [id, key])
			var skeleton := _posed(clip)
			for finger in ROUND:
				var turned := _closed(skeleton, finger)
				assert_gt(turned, CLOSED, "%s: the %s finger closed round the grip (%.0f degrees)" % [clip, finger, turned])
			# The index finger's tip has come round the grip's front, back across the palm's side of its knuckle.
			var knuckle := _bone(skeleton, "Index1_L")
			var tip := _bone(skeleton, "Index3_L")
			var along := knuckle.basis.y.normalized()
			var back := (tip.origin + tip.basis.y.normalized() * 0.02 - knuckle.origin)
			var across := back - along * back.dot(along)
			assert_gt(across.length(), WRAPPED, "%s: the index finger's tip %.3f m round from its knuckle's line" % [
					clip, across.length()])


func test_the_angled_grip_is_held_as_the_vertical_grip_is() -> void:
	for id in GRIPPED:
		var vertical := _posed(StringName("%s_grip_vertical_Hold" % id))
		var angled := _posed(StringName("%s_grip_angled_Hold" % id))
		for finger: String in ["Index", "Middle", "Ring", "Pinky"]:
			var a := _bone(vertical, "Hand_L").basis.orthonormalized().inverse() * _bone(vertical, finger + "3_L").basis.y
			var b := _bone(angled, "Hand_L").basis.orthonormalized().inverse() * _bone(angled, finger + "3_L").basis.y
			var off := rad_to_deg(a.angle_to(b))
			assert_lt(off, ALIKE, "%s: the %s finger closed as on the vertical grip (%.0f degrees off)" % [id, finger, off])
