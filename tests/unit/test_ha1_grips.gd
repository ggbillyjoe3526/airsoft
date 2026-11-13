extends GutTest
## HA1, the owner's fourth look (2026-11-12): "With a vertical grip the index finger should be under the replica and
## around the grip. Angled grip should be held similar to the vertical grip": on each foregrip's hold in the arms
## model the left hand is a fist, and both grips are held alike. His fifth look (2026-11-13): "Move the hand up the
## vertical grip a bit more so more fingers grip it": the ring finger holds the vertical grip's body too. His sixth
## (04:22): "the hand should be further up the grip (with fingers wrapped around the grip and the thumb resting on the
## near side)": on the vertical grip the thumb lies forward along the grip's left side, not round its back.

const MODEL_PATH := "res://assets/models/arms/arms.glb"
const GRIPPED: Array[StringName] = [&"aeg", &"sniper"]
const GRIPS: Array[String] = ["vertical", "angled"]
## The fingers that close round the grip, and how far (degrees) each one's tip bone at least turns from its first.
const ROUND: Array[String] = ["Index", "Middle"]
## The fingers that hold the vertical grip's body (64 mm; the angled grip's tall end is 48 mm, so there the ring
## finger closes under its foot).
const ROUND_VERTICAL: Array[String] = ["Index", "Middle", "Ring"]
const CLOSED := 55.0
## How far (degrees) the two grips' fists may differ, hand against forearm aside: each finger's tip bone in the
## hand's own frame.
const ALIKE := 45.0
## How far (m) the index finger's tip at least comes back toward the thumb's side of the grip from its knuckle,
## measured along the palm's facing: round the grip, not lying open beside it.
const WRAPPED := 0.015
## The thumb's last bone (m), root to tip, and how far (m) forward of the thumb's root its tip at least lies on the
## vertical grip.
const THUMB_TIP := 0.025
const THUMB_FORWARD := 0.025


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
		for finger in ROUND:
			var a := _bone(vertical, "Hand_L").basis.orthonormalized().inverse() * _bone(vertical, finger + "3_L").basis.y
			var b := _bone(angled, "Hand_L").basis.orthonormalized().inverse() * _bone(angled, finger + "3_L").basis.y
			var off := rad_to_deg(a.angle_to(b))
			assert_lt(off, ALIKE, "%s: the %s finger closed as on the vertical grip (%.0f degrees off)" % [id, finger, off])


func test_three_fingers_hold_the_vertical_grip() -> void:
	for id in GRIPPED:
		var clip := StringName("%s_grip_vertical_Hold" % id)
		var skeleton := _posed(clip)
		for finger in ROUND_VERTICAL:
			var turned := _closed(skeleton, finger)
			assert_gt(turned, CLOSED, "%s: the %s finger closed round the grip (%.0f degrees)" % [clip, finger, turned])
		# Closed round the grip as the middle finger is, not curled away under its foot: the two tips point alike.
		var hand := _bone(skeleton, "Hand_L").basis.orthonormalized().inverse()
		var off := rad_to_deg((hand * _bone(skeleton, "Ring3_L").basis.y).angle_to(hand * _bone(skeleton, "Middle3_L").basis.y))
		assert_lt(off, ALIKE, "%s: the ring finger lies as the middle finger does (%.0f degrees off)" % [clip, off])


func test_the_thumb_rests_on_the_vertical_grips_near_side() -> void:
	for id in GRIPPED:
		var clip := StringName("%s_grip_vertical_Hold" % id)
		var skeleton := _posed(clip)
		var last := _bone(skeleton, "Thumb3_L")
		var tip := last.origin + last.basis.y.normalized() * THUMB_TIP
		# The arms' own space: x to your right, -z forward. The fingers go round the grip's front onto its right
		# side; the thumb stays left of the index knuckle, which sits beside the grip's left face.
		var knuckle := _bone(skeleton, "Index1_L").origin
		assert_lt(tip.x, knuckle.x, "%s: the thumb's tip on the grip's near side (%.3f left of the knuckle)" % [
				clip, knuckle.x - tip.x])
		assert_lt(tip.x, _bone(skeleton, "Index3_L").origin.x, "%s: and not round the back with the fingertips" % clip)
		var forward := _bone(skeleton, "Thumb1_L").origin.z - tip.z
		assert_gt(forward, THUMB_FORWARD, "%s: the thumb lies forward along the grip (%.3f m)" % [clip, forward])
