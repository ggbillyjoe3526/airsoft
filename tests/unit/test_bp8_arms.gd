extends GutTest
## BP8 (the owner's playtest notes 6, 9 and 11): your first-person arms hold a fitted foregrip with the left hand
## (each replica that takes one, each grip; without one the approved handguard hold stays), change the magazine with
## the left hand through a reload in step with the replica's own Reload clip (the magazine riding in the hand while it
## is out), and can be shown skin only from the Dev tab, switched live.

const DT := 1.0 / 60.0
const GRIPS: Array[StringName] = [&"vertical", &"angled"]
## The replicas that take a grip (data/pool.md: under-rail), and every replica you reload.
const GRIPPED: Array[StringName] = [&"aeg", &"sniper"]
const HELD: Array[StringName] = [&"aeg", &"pistol", &"cyber", &"sniper", &"smg", &"shotgun"]
## How far (m) the magazine may sit from its place in the left hand while the hand carries it, and may jump as the
## hand takes it or lets it go.
const CARRY_SLACK := 0.004
const CARRY_STEPS := 16
const EDGE := 1e-4
## How far (m) the magazine may move as the hand takes it or lets it go (the hand eased off the replica a little).
const EDGE_SLACK := 0.008
## Through a reload, your arm (upper arm and forearm, ARM_CUFF m short of the wrist: the hand, the glove's cuff and
## the sleeve's banded hem, tools/blender/arms/glove.py, may show at the screen's edge) stays off the screen, ARM_R m
## clear of its edges along its middle line, at every key of every reload clip (the standing ruling: in first person
## only your hand and part of your wrist show), or no more than HOLD_SLACK m more than the replica's approved hold
## shows.
const ARM_CUFF := 0.07
const ARM_R := 0.02
const HOLD_SLACK := 0.015
const ARM_SAMPLES := 24
const UPPER_FROM := 0.4
const EYE := Vector3(0.0, 1.6, 0.0)
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
		# A pistol's is from its hold in both hands (HA1).
		var clip := StringName(hands._arms.clip_base(held.id, &"") + ArmsView.RELOAD_SUFFIX)
		assert_true(anim.has_animation(clip), "%s: the left hand changes the magazine" % held.id)
		assert_almost_eq(anim.get_animation(clip).length, held.anim.get_animation(ReplicaView.RELOAD_CLIP).length,
				1.0 / 60.0, "%s: as long as the replica's Reload clip (played at the same share)" % held.id)


func test_a_pistols_left_hand_leaves_its_hold_for_the_reload_and_comes_back() -> void:
	var hands := _hands([&"pistol"])
	hands._show(0)
	var held: ReplicaView.Held = hands._held[0]
	var left := _mesh(hands, ArmsView.LEFT_ARM)
	assert_true(left.visible, "control: held in both hands (HA1)")
	assert_eq(_anim(hands).assigned_animation, &"pistol_two_Hold")
	hands._arms.follow(held.anim, DT, 0.5)
	assert_eq(_anim(hands).assigned_animation, &"pistol_two_Reload", "changing the magazine")
	assert_true(hands._arms.reloading())
	assert_true(left.visible, "the left hand shows while it does")
	assert_almost_eq(_anim(hands).current_animation_position, 0.5 * _anim(hands).current_animation_length, 1e-3,
			"at the reload's share")
	hands._arms.follow(held.anim, DT)
	assert_eq(_anim(hands).assigned_animation, &"pistol_two_Hold", "the reload over: back on the hold")
	assert_true(left.visible, "both hands on it again")


func test_a_one_handed_replica_shows_its_left_hand_only_through_the_reload() -> void:
	# No replica is one-handed now (the bombs are: GrenadeView); the config still can list one.
	cfg.one_hand.append(&"pistol")
	var hands := _hands([&"pistol"])
	hands._show(0)
	var held: ReplicaView.Held = hands._held[0]
	var left := _mesh(hands, ArmsView.LEFT_ARM)
	assert_false(left.visible, "listed one-handed: the left arm hidden")
	hands._arms.follow(held.anim, DT, 0.5)
	assert_true(left.visible, "the left hand shows while it changes the magazine")
	hands._arms.follow(held.anim, DT)
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


## The magazine at `share` of the reload, posed as the game poses it (its clip, the arms' clip, the carry), and the
## left hand: [magazine, hand], in the replica's space.
func _mag_and_hand(hands: ReplicaView, held: ReplicaView.Held, share: float) -> Array[Transform3D]:
	hands._seek(held, ReplicaView.RELOAD_CLIP, share)
	hands._arms.follow(held.anim, DT, share)
	hands._carry_magazine(held, share)
	var hand := hands._arms.left_hand(held.root)
	var mag := held.root.find_child(ReplicaParts.MAGAZINE_ATTACHMENT, true, false) as BoneAttachment3D
	(mag.get_parent() as Skeleton3D).force_update_all_bone_transforms()
	mag.on_skeleton_update()
	return [held.root.global_transform.affine_inverse() * mag.global_transform, hand]


func test_the_magazine_rides_in_the_left_hand() -> void:
	var hands := _hands(HELD)
	for slot in HELD.size():
		hands._show(slot)
		var held: ReplicaView.Held = hands._held[slot]
		var span: Vector2 = cfg.reload_carry[held.id]
		# From taking the old one to letting the fresh one go: out of view and back, the magazine stays in the hand.
		var start := _mag_and_hand(hands, held, span.x)
		var in_hand := start[1].affine_inverse() * start[0].origin
		for k in range(1, CARRY_STEPS + 1):
			var share := lerpf(span.x, span.y, k / float(CARRY_STEPS))
			var now := _mag_and_hand(hands, held, share)
			assert_almost_eq(now[1].affine_inverse() * now[0].origin, in_hand, Vector3.ONE * CARRY_SLACK,
					"%s at %.3f: the magazine in the hand" % [held.id, share])


func test_the_magazine_goes_into_and_out_of_the_hand_without_a_jump() -> void:
	var hands := _hands(HELD)
	for slot in HELD.size():
		hands._show(slot)
		var held: ReplicaView.Held = hands._held[slot]
		var span: Vector2 = cfg.reload_carry[held.id]
		# Just inside the carry, the hand has the magazine where the replica's own clip has it then.
		for edge: float in [span.x + EDGE, span.y - EDGE]:
			var carried := _mag_and_hand(hands, held, edge)[0].origin
			hands._seek(held, ReplicaView.RELOAD_CLIP, edge)
			var mag := held.root.find_child(ReplicaParts.MAGAZINE_ATTACHMENT, true, false) as BoneAttachment3D
			(mag.get_parent() as Skeleton3D).force_update_all_bone_transforms()
			mag.on_skeleton_update()
			var own := held.root.global_transform.affine_inverse() * mag.global_position
			assert_almost_eq(carried, own, Vector3.ONE * EDGE_SLACK, "%s at %.3f: taken or let go in place" % [
					held.id, edge])


## Where `world` is on the screen of the eye ReplicaView `hands` draws for (its own frame: the game's eye camera,
## ViewConfig's field of view): x and y in -1..1 across it, z its depth (m; below the near plane, behind the eye).
func _on_screen(hands: ReplicaView, world: Vector3) -> Vector3:
	var view := ViewConfig.new()
	var tan_h := tan(deg_to_rad(view.horizontal_fov_16x9) * 0.5)
	var p := hands.global_transform.affine_inverse() * world
	var depth := -p.z
	if depth < view.near:
		return Vector3(INF, INF, depth)
	return Vector3(p.x / (depth * tan_h), p.y / (depth * tan_h * 9.0 / 16.0), depth)


## How far from the wrist (m) your arm on `side` ("L" or "R") shows on screen as posed now (0: none of it past the hand).
func _arm_shown(hands: ReplicaView, side: String = "L") -> float:
	var skeleton := hands._arms._skeleton
	skeleton.force_update_all_bone_transforms()
	var joints: Array[Vector3] = []
	for bone: String in ["UpperArm_", "Forearm_", "Hand_"]:
		joints.append(skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(bone + side)).origin)
	var tan_h := tan(deg_to_rad(ViewConfig.new().horizontal_fov_16x9) * 0.5)
	var shown := 0.0
	for part in 2:
		# The upper arm from UPPER_FROM of the way down it: above that it is beside your head, behind the screen.
		var a := joints[part].lerp(joints[part + 1], UPPER_FROM if part == 0 else 0.0)
		var b := joints[part + 1]
		for k in ARM_SAMPLES + 1:
			var q := a.lerp(b, k / float(ARM_SAMPLES))
			var from_wrist := q.distance_to(joints[1]) + joints[1].distance_to(joints[2]) if part == 0 \
					else q.distance_to(joints[2])
			var s := _on_screen(hands, q)
			var edge := ARM_R / (s.z * tan_h)
			if s.z > 0.0 and absf(s.x) < 1.0 + edge and absf(s.y) < 1.0 + edge * 16.0 / 9.0:
				shown = maxf(shown, from_wrist)
	return shown


func test_only_the_hand_and_wrist_show_through_a_reload() -> void:
	for grip: StringName in [&"", &"vertical", &"angled"]:
		for id: StringName in (HELD if grip == &"" else GRIPPED):
			var hands := _hands([id], grip)
			var c := Character.new(0, 0, Vector3.ZERO, 0.0, [ReplicaStats.load_replica(id)] as Array[ReplicaConfig])
			hands.update(c, 0.0, 0.0, EYE, Vector3.FORWARD, DT, 0.0)
			# No more than the approved hold shows, where it shows a sliver of sleeve at the screen's edge; your right
			# arm too, the replica canted in it. A foregrip's fist shows less arm than the replica's own hold (HA1:
			# the straight forearm beside the rifle), and the magazine is changed the same way from either, so the
			# replica's own hold sets the limit there too.
			var most := ARM_CUFF if cfg.one_hand.has(id) else maxf(ARM_CUFF, _arm_shown(hands) + HOLD_SLACK)
			if grip != &"":
				var plain := _hands([id])
				plain.update(c, 0.0, 0.0, EYE, Vector3.FORWARD, DT, 0.0)
				most = maxf(most, _arm_shown(plain) + HOLD_SLACK)
			var most_right := maxf(ARM_CUFF, _arm_shown(hands, "R") + HOLD_SLACK)
			var clip := _anim(hands).get_animation(hands._arms.reload_clip())
			var track := clip.find_track(NodePath("%s:Forearm_L" % _skeleton_path(hands)), Animation.TYPE_ROTATION_3D)
			assert_true(track >= 0, "%s: the forearm is keyed" % hands._arms.reload_clip())
			var time := c.armament.replica().reload_time
			for k in clip.track_get_key_count(track):
				var share := clip.track_get_key_time(track, k) / clip.length
				c.armament.reload_left = maxf(time * (1.0 - share), 1e-4)
				hands.update(c, 0.0, 0.0, EYE, Vector3.FORWARD, DT, 0.0)
				assert_lt(_arm_shown(hands), most, "%s at %.2f: no left arm past the wrist on screen" % [
						hands._arms.reload_clip(), share])
				assert_lt(_arm_shown(hands, "R"), most_right, "%s at %.2f: no right arm past the wrist on screen" % [
						hands._arms.reload_clip(), share])


func _skeleton_path(hands: ReplicaView) -> String:
	var anim := _anim(hands)
	return String(anim.get_node(anim.root_node).get_path_to(hands._arms._skeleton))


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
	# HA1: the bare hand is a mesh of its own in the model's painted skin (the nails' material), shown in place of the
	# glove's cloth over the hand; the sleeve keeps its own cloth.
	var hand := _mesh(hands, ArmsView.HAND_PREFIX + "R")
	var bare := _mesh(hands, ArmsView.SKIN_PREFIX + "R")
	assert_false(hand.visible, "the glove's cloth hidden")
	assert_true(bare.visible, "the bare hand shown")
	var skin := nails.mesh.surface_get_material(0) as BaseMaterial3D
	for i in bare.mesh.get_surface_count():
		var worn := bare.get_surface_override_material(i) as BaseMaterial3D
		assert_true(worn.use_z_clip_scale, "still pressed")
		assert_eq(worn.resource_name, skin.resource_name, "the bare hand is skin")
		assert_eq(worn.albedo_texture, skin.albedo_texture, "painted, not tinted")
		assert_not_null(worn.albedo_texture)
		assert_true(worn.normal_enabled, "with the skin's own relief")
	for i in arm.mesh.get_surface_count():
		var worn := arm.get_surface_override_material(i) as BaseMaterial3D
		assert_eq(worn.resource_name, arm.mesh.surface_get_material(i).resource_name, "the sleeve stays cloth")
	hands.arms_kind = FigureMix.ROBOT
	assert_true(kit.visible, "a robot's arms keep their plates")
	assert_true(hand.visible, "and the glove's shell over the hand")
	assert_false(nails.visible)
	assert_false(bare.visible)
	for i in hand.mesh.get_surface_count():
		var key := StringName(hand.mesh.surface_get_material(i).resource_name)
		var worn := hand.get_surface_override_material(i) as BaseMaterial3D
		assert_eq(worn.albedo_color, cfg.robot_arms[key], "a robot's plain shell")
		assert_null(worn.albedo_texture, "no painted cloth on it")
	hands.arms_kind = FigureMix.HUMAN
	hands.skin_arms = false
	assert_true(kit.visible, "gloves again")
	assert_false(nails.visible)


func test_skin_only_keeps_a_one_handed_left_arm_hidden() -> void:
	cfg.one_hand.append(&"pistol")
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
