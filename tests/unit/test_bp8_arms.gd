extends GutTest
## BP8 (the owner's playtest notes 6, 9 and 11): your first-person arms hold a fitted foregrip with the left hand
## (each replica that takes one, each grip; without one the approved handguard hold stays), change the magazine with
## the left hand through a reload in step with the replica's own Reload clip (the magazine riding in the hand while it
## is out), and can be shown skin only from the Dev tab, switched live.

const DT := 1.0 / 60.0
const GRIPS: Array[StringName] = [&"vertical", &"angled"]
## The replicas that take a grip (data/pool.md: under-rail), and every replica you reload.
const GRIPPED: Array[StringName] = [&"aeg", &"sniper"]
const HELD: Array[StringName] = [&"aeg", &"pistol", &"cyber", &"sniper"]
## How far (m) the left hand may drift from the magazine it carries between the clip's keys.
const CARRY_SLACK := 0.004
## Where each replica's left hand carries a magazine (shares of the reload, from its Reload clip): the old one pulled
## out (from the hand taking it to it out of the well), then the fresh one pushed up (from it showing to the hand
## letting it slide home; tools/blender/arms/magazine.py phases, CATCH and PUSH_SHARE or the replica's own).
const CARRIES := {
	&"aeg": [[0.12, 0.18, 0.235], [0.52, 0.6, 0.67]],
	&"sniper": [[0.12, 0.18, 0.235], [0.52, 0.6, 0.67]],
	&"pistol": [[0.24, 0.26, 0.28], [0.54, 0.56]],
	&"cyber": [[0.26, 0.28, 0.3], [0.54, 0.58]],
}
## How far (m) the left hand may be from its hold as a reload starts (no jump into the clip).
const START_SLACK := 0.002

var cfg: ViewModelConfig = null


func before_each() -> void:
	cfg = ViewModelConfig.new()


func _hands(ids: Array[StringName], grip: StringName = &"") -> ReplicaView:
	var loadout: Array[ReplicaConfig] = []
	var parts: Array[Dictionary] = []
	for id in ids:
		loadout.append(ReplicaStats.load_replica(id))
		parts.append({ReplicaParts.GRIP_SLOT: grip} if grip != &"" else {})
	var hands := ReplicaView.new()
	add_child_autofree(hands)
	hands.setup(cfg, loadout, BoxWorld.new(), [], false, parts)
	return hands


func _anim(hands: ReplicaView) -> AnimationPlayer:
	return hands._arms._model.find_child("AnimationPlayer", true, false) as AnimationPlayer


func _mesh(hands: ReplicaView, mesh_name: String) -> MeshInstance3D:
	return hands._arms._model.find_child(mesh_name, true, false) as MeshInstance3D


func test_a_fitted_grip_takes_the_left_hand() -> void:
	for grip in GRIPS:
		var hands := _hands(GRIPPED, grip)
		for slot in GRIPPED.size():
			hands._show(slot)
			var id := GRIPPED[slot]
			assert_eq(_anim(hands).assigned_animation, StringName("%s_grip_%s_Hold" % [id, grip]),
					"%s with the %s grip: the hold round it" % [id, grip])
			assert_true(_anim(hands).has_animation(StringName("%s_grip_%s_Reload" % [id, grip])),
					"%s with the %s grip: a reload from that hold" % [id, grip])


func test_without_a_grip_the_handguard_hold_stays() -> void:
	var hands := _hands(GRIPPED)
	for slot in GRIPPED.size():
		hands._show(slot)
		assert_eq(_anim(hands).assigned_animation, StringName(String(GRIPPED[slot]) + "_Hold"), "%s" % GRIPPED[slot])


func test_a_grip_moves_only_the_left_hand() -> void:
	var anim := _anim(_hands([&"aeg"]))
	for id in GRIPPED:
		var plain := anim.get_animation(StringName(String(id) + "_Hold"))
		for grip in GRIPS:
			var held := anim.get_animation(StringName("%s_grip_%s_Hold" % [id, grip]))
			var moved_left := false
			for t in plain.get_track_count():
				var path := String(plain.track_get_path(t))
				var other := held.find_track(plain.track_get_path(t), plain.track_get_type(t))
				if other < 0:
					continue
				var same: bool = plain.track_get_key_value(t, 0) == held.track_get_key_value(other, 0)
				if path.ends_with("_R") or path.contains("_R:"):
					assert_true(same, "%s %s: the right hand as approved (%s)" % [id, grip, path])
				elif not same:
					moved_left = true
			assert_true(moved_left, "%s %s: the left hand moved onto the grip" % [id, grip])


func test_the_sniper_works_its_bolt_from_a_grip_hold_too() -> void:
	var hands := _hands([&"sniper"], &"vertical")
	hands._show(0)
	assert_eq(hands._arms._work, &"sniper_grip_vertical_Fire", "the bolt clip from the grip's hold")
	var anim := _anim(hands)
	assert_almost_eq(anim.get_animation(&"sniper_grip_vertical_Fire").length,
			anim.get_animation(&"sniper_Fire").length, 1e-4, "as long as the plain one")


func test_each_reload_clip_lasts_as_the_replicas_own() -> void:
	var hands := _hands(HELD)
	var anim := _anim(hands)
	for slot in HELD.size():
		var held: ReplicaView.Held = hands._held[slot]
		var clip := StringName(String(held.id) + ArmsView.RELOAD_SUFFIX)
		assert_true(anim.has_animation(clip), "%s: the left hand changes the magazine" % held.id)
		assert_almost_eq(anim.get_animation(clip).length, held.anim.get_animation(ReplicaView.RELOAD_CLIP).length,
				1.0 / 60.0, "%s: as long as the replica's Reload clip (played at the same share)" % held.id)


func test_a_reload_shows_the_left_hand_on_a_pistol_then_hides_it() -> void:
	var hands := _hands([&"pistol"])
	hands._show(0)
	var held: ReplicaView.Held = hands._held[0]
	var left := _mesh(hands, ArmsView.LEFT_ARM)
	assert_false(left.visible, "control: one-handed, the left arm hidden")
	hands._arms.follow(held.anim, DT, 0.5)
	assert_eq(_anim(hands).assigned_animation, &"pistol_Reload", "changing the magazine")
	assert_true(hands._arms.reloading())
	assert_true(left.visible, "the left hand shows while it does")
	assert_almost_eq(_anim(hands).current_animation_position, 0.5 * _anim(hands).current_animation_length, 1e-3,
			"at the reload's share")
	hands._arms.follow(held.anim, DT)
	assert_eq(_anim(hands).assigned_animation, &"pistol_Hold", "the reload over: back on the hold")
	assert_false(left.visible, "the left arm hidden again")


func test_a_reload_in_play_drives_the_left_hand() -> void:
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	var hands := ReplicaView.new()
	add_child_autofree(hands)
	hands.setup(cfg, c.armament.replicas, BoxWorld.new())
	hands.update(c, 0.0, 0.0, Vector3(0.0, 1.6, 0.0), Vector3.FORWARD, DT, 0.0)
	var r := c.armament.replica()
	c.armament.reload_left = r.reload_time * 0.4
	hands.update(c, 0.0, 0.0, Vector3(0.0, 1.6, 0.0), Vector3.FORWARD, DT, 0.0)
	var anim := _anim(hands)
	assert_eq(anim.assigned_animation, StringName(String(r.id) + ArmsView.RELOAD_SUFFIX), "mid-reload")
	assert_almost_eq(anim.current_animation_position / anim.current_animation_length, 0.6, 1e-3, "at its share")
	c.armament.reload_left = 0.0
	hands.update(c, 0.0, 0.0, Vector3(0.0, 1.6, 0.0), Vector3.FORWARD, DT, 0.0)
	assert_eq(anim.assigned_animation, StringName(String(r.id) + ArmsView.CLIP_SUFFIX), "done: the hold")


## The left hand bone's place in the arms' model.
func _left_hand(hands: ReplicaView) -> Vector3:
	var skeleton := hands._arms._skeleton
	skeleton.force_update_all_bone_transforms()
	return skeleton.get_bone_global_pose(skeleton.find_bone("Hand_L")).origin


## Where the left hand is against the magazine at `share` of the reload, in the replica's frame.
func _hand_on_mag(hands: ReplicaView, held: ReplicaView.Held, share: float) -> Vector3:
	hands._seek(held, ReplicaView.RELOAD_CLIP, share)
	hands._arms.follow(held.anim, DT, share)
	var skeleton := hands._arms._skeleton
	skeleton.force_update_all_bone_transforms()
	var hand := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("Hand_L")).origin
	var mag := held.root.find_child(ReplicaParts.MAGAZINE_ATTACHMENT, true, false) as Node3D
	var replica_skeleton := mag.get_parent() as Skeleton3D
	replica_skeleton.force_update_all_bone_transforms()
	(mag as BoneAttachment3D).on_skeleton_update()
	# In the magazine's own frame, so a magazine that tips as it comes out still reads as held.
	return mag.global_transform.affine_inverse() * hand


func test_the_magazine_rides_in_the_left_hand() -> void:
	var hands := _hands(HELD)
	for slot in HELD.size():
		hands._show(slot)
		var held: ReplicaView.Held = hands._held[slot]
		# The old magazine pulled out, then the fresh one pushed up: the hand keeps its place on it each way.
		for stretch: Array in CARRIES[held.id]:
			var first := _hand_on_mag(hands, held, stretch[0])
			for share: float in stretch.slice(1):
				var now := _hand_on_mag(hands, held, share)
				assert_almost_eq(now, first, Vector3.ONE * CARRY_SLACK, "%s at %.2f: the hand with the magazine" % [
						held.id, share])


func test_a_reload_starts_from_the_hold() -> void:
	for id: StringName in GRIPPED:
		var hands := _hands([id])
		hands._show(0)
		var held: ReplicaView.Held = hands._held[0]
		hands._arms.follow(held.anim, DT)
		var holding := _left_hand(hands)
		hands._arms.follow(held.anim, DT, 0.0)
		assert_almost_eq(_left_hand(hands), holding, Vector3.ONE * START_SLACK, "%s: no jump as it starts" % id)


func test_skin_only_arms_switch_live() -> void:
	var hands := _hands([&"aeg"])
	hands._show(0)
	var kit := _mesh(hands, ArmsView.KIT_PREFIX + "R")
	var nails := _mesh(hands, ArmsView.NAILS_PREFIX + "R")
	var arm := _mesh(hands, "Arm_R")
	assert_true(kit.visible, "gloves by default: the glove's kit shows")
	assert_false(nails.visible, "and no fingernails")
	hands.skin_arms = true
	assert_false(kit.visible, "skin only: the kit hidden")
	assert_true(nails.visible, "the fingernails shown")
	var skinned := 0
	for i in arm.mesh.get_surface_count():
		var key := StringName(arm.mesh.surface_get_material(i).resource_name)
		var worn := arm.get_surface_override_material(i) as BaseMaterial3D
		assert_true(worn.use_z_clip_scale, "%s: still pressed" % key)
		if cfg.skin_arms.has(key):
			skinned += 1
			assert_eq(worn.albedo_color, cfg.skin_arms[key], "%s in skin" % key)
			assert_false(worn.normal_enabled, "%s: no cloth weave" % key)
	assert_gt(skinned, 0, "the hand's surface is skin")
	hands.arms_kind = FigureMix.ROBOT
	assert_true(kit.visible, "a robot's arms keep their plates")
	assert_false(nails.visible)
	hands.arms_kind = FigureMix.HUMAN
	hands.skin_arms = false
	assert_true(kit.visible, "gloves again")
	assert_false(nails.visible)


func test_skin_only_keeps_a_one_handed_left_arm_hidden() -> void:
	var hands := _hands([&"pistol"])
	hands.skin_arms = true
	hands._show(0)
	for side_mesh: String in [ArmsView.LEFT_ARM, ArmsView.NAILS_PREFIX + "L", ArmsView.KIT_PREFIX + "L"]:
		assert_false(_mesh(hands, side_mesh).visible, "%s hidden" % side_mesh)
	assert_true(_mesh(hands, ArmsView.NAILS_PREFIX + "R").visible, "the right hand's nails show")


func test_the_dev_switch_is_off_by_default_and_saved() -> void:
	var s := Settings.new(PlayTuning.new())
	assert_false(s.dev.skin_arms, "gloves by default")
	assert_true(SettingsScreen.DEV_SWITCHES.has(&"skin_arms"), "a Dev tab switch")
	s.dev.skin_arms = true
	var again := DevSettings.new()
	again.from_dict(s.dev.to_dict())
	assert_true(again.skin_arms, "saved and read back")
	assert_false(again.cheats().watching, "only a look: no cheat")
	assert_ne(tr("DEV_SKIN_ARMS"), "DEV_SKIN_ARMS", "labelled")
	assert_ne(tr("DEV_SKIN_ARMS_HELP"), "DEV_SKIN_ARMS_HELP", "explained")


func test_the_arms_stay_in_their_triangle_budget() -> void:
	var hands := _hands([&"aeg"])
	for skin: bool in [false, true]:
		hands.skin_arms = skin
		var tris := 0
		for node: Node in hands._arms._model.find_children("*", "MeshInstance3D", true, false):
			var mesh_node := node as MeshInstance3D
			if not mesh_node.visible:
				continue
			for i in mesh_node.mesh.get_surface_count():
				var arrays := mesh_node.mesh.surface_get_arrays(i)
				var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				tris += index.size() / 3
		assert_lt(tris, 40000, "skin only %s: %d triangles drawn" % [skin, tris])
