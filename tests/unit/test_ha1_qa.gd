extends GutTest
## HA1 QA: the edges of ArmsView.aim and ArmsTuck (raise outside 0..1, ids missing from a table, a switch while raised,
## hide and show, the bolt's and a reload's clips, a grip, a bomb), the pistols' two-handed holds in the model, the
## bots' rifle holds, the model's budgets, and what a raised sight leaves behind when the view is freed.

const DT := 1.0 / 60.0
const EPS := 1e-4
## The arms' own float noise through a tuck and back (up to a few 1e-3 of a unit vector, a quarter of a degree).
const LOOSE := 5e-3
const RIFLES := [&"aeg", &"sniper", &"smg"]
const PISTOLS := [&"pistol", &"cyber"]
const MODEL_PATH := "res://assets/models/arms/arms.glb"
const THUMB_R := ["Thumb1_R", "Thumb2_R", "Thumb3_R", "Heel_R"]
const LEFT_ARM_BONES := ["UpperArm_L", "Forearm_L", "Hand_L"]

var cfg: ViewModelConfig = null


func before_each() -> void:
	cfg = ViewModelConfig.new()


func _hands(ids: Array, grip: StringName = &"") -> ReplicaView:
	var loadout: Array[ReplicaConfig] = []
	var parts: Array[Dictionary] = []
	for id: StringName in ids:
		loadout.append(ReplicaStats.load_replica(id))
		parts.append({ReplicaParts.GRIP_SLOT: grip} if grip != &"" else {})
	var hands := ReplicaView.new()
	add_child_autofree(hands)
	hands.setup(cfg, loadout, BoxWorld.new(), [], false, parts)
	return hands


## A bare ArmsView holding `id` under its own root (for ids the replica view doesn't carry, a bomb).
func _bare(id: StringName) -> ArmsView:
	var root := Node3D.new()
	add_child_autofree(root)
	var arms := ArmsView.new()
	root.add_child(arms)
	arms.setup(cfg)
	arms.hold(id, root)
	return arms


func _pose(arms: ArmsView, bone_name: String) -> Transform3D:
	var skeleton := arms._skeleton
	skeleton.force_update_all_bone_transforms()
	return skeleton.get_bone_global_pose(skeleton.find_bone(bone_name))


func _same(a: Transform3D, b: Transform3D, eps: float = EPS) -> bool:
	return a.origin.distance_to(b.origin) < eps and a.basis.x.distance_to(b.basis.x) < eps \
			and a.basis.y.distance_to(b.basis.y) < eps and a.basis.z.distance_to(b.basis.z) < eps


func _finite(t: Transform3D) -> bool:
	return t.origin.is_finite() and t.basis.x.is_finite() and t.basis.y.is_finite() and t.basis.z.is_finite()


func _left_bones(arms: ArmsView) -> Array[String]:
	var out: Array[String] = []
	for i in arms._skeleton.get_bone_count():
		var n := arms._skeleton.get_bone_name(i)
		if n.ends_with("_L"):
			out.append(n)
	return out


## Every left-arm bone of `a` equals `b`'s.
func _left_equal(a: ArmsView, b: ArmsView) -> bool:
	for n: String in _left_bones(a):
		if not _same(_pose(a, n), _pose(b, n), LOOSE):
			return false
	return true


func _arm_length_kept(arms: ArmsView, clean: ArmsView) -> bool:
	var ok := true
	for pair: Array in [["UpperArm_L", "Forearm_L"], ["Forearm_L", "Hand_L"]]:
		var d := _pose(arms, pair[0]).origin.distance_to(_pose(arms, pair[1]).origin)
		var d0 := _pose(clean, pair[0]).origin.distance_to(_pose(clean, pair[1]).origin)
		ok = ok and absf(d - d0) < 1e-3
	return ok


# --- aim() edges ---------------------------------------------------------------------------------------------------


func test_a_raise_outside_0_to_1_or_at_the_spans_ends_breaks_no_bone() -> void:
	for id: StringName in RIFLES:
		var hands := _hands([id])
		hands._show(0)
		var clean := _hands([id])
		clean._show(0)
		for raise: float in [-3.0, -0.5, 0.0, cfg.aim_slide_span.x, cfg.aim_slide_span.y, 1.0, 1.5, 4.0]:
			hands._arms.aim(raise)
			for n: String in _left_bones(hands._arms):
				assert_true(_finite(_pose(hands._arms, n)), "%s raise %s: %s finite" % [id, raise, n])
			assert_true(_arm_length_kept(hands._arms, clean._arms), "%s raise %s: both bone lengths kept" % [id, raise])
		hands._arms.aim(0.0)
		assert_true(_left_equal(hands._arms, clean._arms), "%s: back at 0 nothing is left of the extremes" % id)


func test_an_id_in_aim_slide_but_not_in_aim_tuck_slides_the_hand_and_moves_no_shoulder() -> void:
	cfg.aim_tuck.erase(&"aeg")
	var hands := _hands([&"aeg"])
	hands._show(0)
	var upper := _pose(hands._arms, "UpperArm_L")
	var hand := _pose(hands._arms, "Hand_L")
	hands._arms.aim(1.0)
	assert_true(_finite(_pose(hands._arms, "Forearm_L")))
	assert_gt(_pose(hands._arms, "Hand_L").origin.distance_to(hand.origin), 0.1, "the hand still slides")
	assert_almost_eq(_pose(hands._arms, "UpperArm_L").origin, upper.origin, Vector3.ONE * EPS, "the shoulder stays")
	hands._arms.aim(0.0)
	assert_true(_same(_pose(hands._arms, "Hand_L"), hand), "and comes back")


func test_an_id_in_aim_tuck_but_not_in_aim_slide_tucks_and_the_hand_holds_still() -> void:
	cfg.aim_slide.erase(&"aeg")
	var hands := _hands([&"aeg"])
	hands._show(0)
	var upper := _pose(hands._arms, "UpperArm_L")
	var hand := _pose(hands._arms, "Hand_L")
	hands._arms.aim(1.0)
	assert_gt(_pose(hands._arms, "UpperArm_L").origin.distance_to(upper.origin), 0.05, "the shoulder moved")
	assert_true(_same(_pose(hands._arms, "Hand_L"), hand), "the hand stayed where the clip has it")
	hands._arms.aim(0.0)
	assert_true(_same(_pose(hands._arms, "UpperArm_L"), upper), "the shoulder comes back")


func test_rifle_to_pistol_to_rifle_while_raised_leaves_no_slid_hand_or_moved_shoulder() -> void:
	var hands := _hands([&"aeg", &"pistol", &"smg"])
	var fresh := [_hands([&"aeg"]), _hands([&"pistol"]), _hands([&"smg"])]
	for f: ReplicaView in fresh:
		f._show(0)
	var order := [0, 1, 2, 1, 0]
	for slot: int in order:
		hands._show(slot)
		# Switched with the sight still up for a frame, then at the hip: nothing of the last replica's tuck.
		hands._arms.aim(0.0)
		assert_true(_left_equal(hands._arms, (fresh[slot] as ReplicaView)._arms), "slot %d: the clip's pose alone" % slot)
		hands._arms.aim(1.0)
		hands._arms.aim(0.0)
		assert_true(_left_equal(hands._arms, (fresh[slot] as ReplicaView)._arms), "slot %d after a raise" % slot)


func test_a_bomb_after_a_raised_rifle_is_posed_by_its_clip_alone() -> void:
	var bomb := _bare(&"smoke")
	if bomb.holding() == &"":
		pending("no smoke hold in the model")
		return
	var clean := _bare(&"smoke")
	var hands := _hands([&"aeg"])
	hands._show(0)
	hands._arms.aim(1.0)
	hands._arms.hold(&"smoke", hands._held[0].root)
	assert_eq(hands._arms.holding(), &"smoke")
	hands._arms.aim(1.0)
	assert_true(_left_equal(hands._arms, clean), "a one-handed bomb is not tucked when aimed")
	bomb.aim(1.0)
	assert_true(_left_equal(bomb, clean), "nor on its own")


func test_hide_and_show_while_raised_keeps_the_tuck_and_only_toggles_the_model() -> void:
	var hands := _hands([&"aeg"])
	hands._show(0)
	hands._arms.aim(1.0)
	var fore := _pose(hands._arms, "Forearm_L")
	hands._arms.set_shown(false)
	assert_false(hands._arms._model.visible)
	hands._arms.aim(1.0)
	assert_true(_same(_pose(hands._arms, "Forearm_L"), fore), "still tucked while away")
	hands._arms.aim(0.0)
	hands._arms.set_shown(true)
	assert_true(hands._arms._model.visible)
	var clean := _hands([&"aeg"])
	clean._show(0)
	assert_true(_left_equal(hands._arms, clean._arms), "shown again at the hip: the clip's pose")


func test_the_snipers_bolt_clip_runs_with_the_sight_going_down_and_leaves_no_residue() -> void:
	var hands := _hands([&"sniper"])
	hands._show(0)
	var arms := hands._arms
	assert_true(arms._anim.has_animation(&"sniper_Fire"))
	var clean := _hands([&"sniper"])
	clean._show(0)
	for step in 12:
		var at := arms._anim.get_animation(&"sniper_Fire").length * float(step) / 11.0
		for a: ArmsView in [arms, clean._arms]:
			a._anim.play(&"sniper_Fire")
			a._anim.pause()
			a._anim.seek(at, true)
		arms.aim(1.0 - float(step) / 11.0)
		for n: String in _left_bones(arms):
			assert_true(_finite(_pose(arms, n)), "step %d: %s finite" % [step, n])
	arms.aim(0.0)
	assert_true(_left_equal(arms, clean._arms), "at the end of the clip with the sight down: the clip alone")
	assert_eq(arms._anim.assigned_animation, &"sniper_Fire")


func test_a_grip_hold_is_tucked_and_comes_back_whole() -> void:
	for grip: StringName in [&"vertical", &"angled"]:
		var hands := _hands([&"aeg"], grip)
		hands._show(0)
		var clean := _hands([&"aeg"], grip)
		clean._show(0)
		if not String(hands._arms._anim.assigned_animation).contains("grip_"):
			pending("no %s grip hold in the model" % grip)
			continue
		var hand := _pose(hands._arms, "Hand_L")
		hands._arms.aim(1.0)
		assert_gt(_pose(hands._arms, "Hand_L").origin.distance_to(hand.origin), 0.1, "%s: the hand slid" % grip)
		assert_true(_arm_length_kept(hands._arms, clean._arms), "%s: lengths kept" % grip)
		hands._arms.aim(0.0)
		assert_true(_left_equal(hands._arms, clean._arms), "%s: whole again" % grip)


func test_no_residue_frame_after_frame_and_the_hand_keeps_the_clips_turn_while_raised() -> void:
	for id: StringName in RIFLES:
		var hands := _hands([id])
		hands._show(0)
		var clean := _hands([id])
		clean._show(0)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for frame in 90:
			var raise := rng.randf()
			hands._arms.aim(raise)
			var turned := _pose(hands._arms, "Hand_L").basis
			var held := _pose(clean._arms, "Hand_L").basis
			assert_lt(turned.x.distance_to(held.x) + turned.y.distance_to(held.y) + turned.z.distance_to(held.z), LOOSE,
					"%s frame %d: the hand's turn is the clip's" % [id, frame])
			assert_true(_arm_length_kept(hands._arms, clean._arms), "%s frame %d: lengths" % [id, frame])
			if frame % 10 == 9:
				hands._arms.aim(0.0)
				assert_true(_left_equal(hands._arms, clean._arms), "%s frame %d: sight down, no residue" % [id, frame])
		# Right arm never touched.
		for i in hands._arms._skeleton.get_bone_count():
			var n := hands._arms._skeleton.get_bone_name(i)
			if n.ends_with("_R"):
				assert_true(_same(_pose(hands._arms, n), _pose(clean._arms, n)), "%s: %s untouched" % [id, n])


# --- the pistols' two-handed holds ---------------------------------------------------------------------------------


func test_pistol_and_cyber_have_both_hands_clips_in_the_model() -> void:
	var arms := _bare(&"pistol")
	for id: StringName in PISTOLS:
		for suffix: String in ["_Hold", "_two_Hold", "_two_Reload"]:
			assert_true(arms._anim.has_animation(StringName(String(id) + suffix)), "%s%s" % [id, suffix])
		assert_not_null(arms._model.find_child("Hold_" + String(id), true, false), "%s: its hold mark" % id)


func test_two_handed_pistol_hold_keeps_the_right_arm_but_the_thumb_and_the_thumb_lies_on_the_left_hand() -> void:
	for id: StringName in PISTOLS:
		var both := _bare(id)
		assert_eq(both._hold_clip, StringName(String(id) + "_two_Hold"), "%s: the two-handed clip is the one held" % id)
		var one := _bare(id)
		one._anim.play(StringName(String(id) + "_Hold"))
		one._anim.pause()
		one._anim.seek(0.0, true)
		for i in both._skeleton.get_bone_count():
			var n := both._skeleton.get_bone_name(i)
			if not n.ends_with("_R") or THUMB_R.has(n):
				continue
			assert_true(_same(_pose(both, n), _pose(one, n), 2e-3), "%s: %s as the one-handed hold has it" % [id, n])
		var moved := false
		for n: String in THUMB_R:
			moved = moved or not _same(_pose(both, n), _pose(one, n), 2e-3)
		assert_true(moved, "%s: the right thumb is laid on the left hand" % id)
		var tip := _pose(both, "Thumb3_R").origin
		var near := 10.0
		for n: String in _left_bones(both):
			near = minf(near, tip.distance_to(_pose(both, n).origin))
		assert_lt(near, 0.05, "%s: the thumb is within 5 cm of a left-hand bone (%.3f)" % [id, near])
		assert_lt(tip.distance_to(_pose(both, "Hand_L").origin), 0.12, "%s: and of the left hand's wrist" % id)


func test_the_hint_reaches_its_values_at_the_spans_ends_and_the_arms_wear_their_own_again_at_0() -> void:
	for id: StringName in PISTOLS:
		var hands := _hands([id])
		hands._show(0)
		var arms := hands._arms
		arms.aim(cfg.aim_hint_span.y)
		assert_almost_eq(arms.hinted(), 1.0, 1e-5, "%s: all of it at the span's end" % id)
		arms.aim(2.0)
		assert_almost_eq(arms.hinted(), 1.0, 1e-5, "%s: no more past it" % id)
		arms.aim((cfg.aim_hint_span.x + cfg.aim_hint_span.y) * 0.5)
		assert_almost_eq(arms.hinted(), 0.5, 1e-5, "%s: half at the middle" % id)
		arms.aim(cfg.aim_hint_span.x)
		assert_eq(arms.hinted(), 0.0)
		arms.aim(1.0)
		arms.aim(0.0)
		assert_eq(arms.hinted(), 0.0)
		for mesh: MeshInstance3D in arms._meshes:
			for i in mesh.mesh.get_surface_count():
				assert_true(mesh.get_surface_override_material(i) is BaseMaterial3D, "%s: %s wears its own" % [id, mesh.name])
		for m in arms._fade_now:
			assert_almost_eq(float(m.get_shader_parameter(ArmsFade.HINT)), 0.0, 1e-6)


func test_fading_copies_are_made_once_per_material_and_not_per_frame() -> void:
	var hands := _hands([&"pistol", &"aeg"])
	hands._show(0)
	var arms := hands._arms
	var before := arms.materials()
	for frame in 120:
		arms.aim(float(frame % 11) / 10.0)
	var after := arms.materials()
	assert_eq(after.size(), before.size(), "the same number of materials")
	for m in before:
		assert_true(after.has(m), "the same objects")
	hands._show(1)
	hands._show(0)
	for frame in 30:
		arms.aim(float(frame % 5) / 4.0)
	assert_eq(arms.materials().size(), before.size(), "a switch and back makes none either")


# --- the bots ------------------------------------------------------------------------------------------------------


func test_every_rifle_hold_the_bots_copy_has_the_left_hand_forward_on_the_replica_and_near_it() -> void:
	var scene := load(MODEL_PATH) as PackedScene
	var model := scene.instantiate()
	var holds := FigureArmsHold.read_all(model, FigureConfig.new())
	for id: StringName in RIFLES:
		assert_true(holds.has(id), "%s has a hold" % id)
		var hold: FigureArmsHold = holds[id]
		var right := hold.right_hand.origin
		var left := hold.left_hand.origin
		assert_lt(left.z, right.z - 0.08, "%s: the left hand is further forward than the right" % id)
		assert_lt(left.length(), 0.6, "%s: and within 60 cm of the replica's origin" % id)
		assert_lt(right.length(), 0.3, "%s: the right on the grip" % id)
		assert_true(left.is_finite() and hold.left_hand.basis.is_finite())
		for tip in hold.left_tips:
			assert_lt(tip.distance_to(left), 0.2, "%s: a left fingertip within 20 cm of its hand" % id)
	model.free()


# --- the model's budgets -------------------------------------------------------------------------------------------


func test_the_model_as_imported_stays_in_its_budgets() -> void:
	assert_lte(FileAccess.get_file_as_bytes(MODEL_PATH).size(), 8 * 1024 * 1024, "the file: 8 MB")
	var hands := _hands([&"aeg"])
	hands._show(0)
	for skin: bool in [false, true]:
		hands.skin_arms = skin
		var tris := 0
		var materials: Array[Material] = []
		var texels := 0
		for mesh_node: MeshInstance3D in hands._arms._meshes:
			if not mesh_node.visible:
				continue
			for i in mesh_node.mesh.get_surface_count():
				var index: PackedInt32Array = mesh_node.mesh.surface_get_arrays(i)[Mesh.ARRAY_INDEX]
				tris += index.size() / 3
				var m := mesh_node.mesh.surface_get_material(i)
				if not materials.has(m):
					materials.append(m)
		assert_lte(tris, 40000, "skin %s: %d triangles drawn" % [skin, tris])
		assert_lte(materials.size(), 4, "skin %s: %d materials" % [skin, materials.size()])
		texels += tris
	# The whole model, every mesh at once, too.
	var all := 0
	var every: Array[Material] = []
	var widest := 0
	for mesh_node: MeshInstance3D in hands._arms._meshes:
		for i in mesh_node.mesh.get_surface_count():
			var m := mesh_node.mesh.surface_get_material(i) as BaseMaterial3D
			if m == null:
				continue
			if not every.has(m):
				every.append(m)
			for tex: Texture2D in [m.albedo_texture, m.normal_texture, m.roughness_texture, m.metallic_texture,
					m.ao_texture, m.emission_texture]:
				if tex != null:
					widest = maxi(widest, maxi(tex.get_width(), tex.get_height()))
		all += 1
	assert_lte(every.size(), 4, "four materials in the whole model")
	assert_lte(widest, 2048, "textures at most 2048 px")
	assert_gt(widest, 0, "the textures were found")


# --- what a raised sight leaves behind -----------------------------------------------------------------------------


func test_a_view_freed_with_the_sight_raised_leaves_no_orphans() -> void:
	var before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	for ids: Array in [[&"aeg"], [&"pistol"], [&"sniper", &"cyber"]]:
		var loadout: Array[ReplicaConfig] = []
		for id: StringName in ids:
			loadout.append(ReplicaStats.load_replica(id))
		var hands := ReplicaView.new()
		add_child(hands)
		hands.setup(cfg, loadout, BoxWorld.new())
		hands._show(0)
		for f in 5:
			hands._arms.aim(1.0)
		hands.set_physics_process(false)
		remove_child(hands)
		hands.free()
	await wait_process_frames(2)
	assert_lte(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), before, "no orphans left by the views")
