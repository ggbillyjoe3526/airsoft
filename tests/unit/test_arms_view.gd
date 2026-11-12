extends GutTest
## BL4: your arms in first person hold the replica in hand. They ride its node (so they follow its sway, kick and drop),
## are posed by that replica's hold clip with its hold mark on the replica's origin, hide the left arm on one-handed
## replicas, press their depth and stay out of shadows and the optic's view, and wear the robot's colours for a robot. On a
## bolt-action replica the right hand works the bolt: the arms' `<id>_Fire` clip plays in step with the replica's Fire,
## then runs on as the hand goes back to the grip.

const DT := 1.0 / 60.0
const EPS := 1e-4
const HELD := [&"aeg", &"pistol", &"cyber", &"sniper", &"smg"]
## Held in both hands (HA1).
const TWO := [&"pistol", &"cyber"]

var cfg: ViewModelConfig = null


func before_each() -> void:
	cfg = ViewModelConfig.new()


func _hands(ids: Array) -> ReplicaView:
	var loadout: Array[ReplicaConfig] = []
	for id: StringName in ids:
		loadout.append(ReplicaStats.load_replica(id))
	var hands := ReplicaView.new()
	add_child_autofree(hands)
	hands.setup(cfg, loadout, BoxWorld.new())
	return hands


func _model(hands: ReplicaView) -> Node3D:
	return hands._arms._model


func _show(hands: ReplicaView, slot: int) -> void:
	hands._show(slot)


func test_every_replica_has_a_hold() -> void:
	var hands := _hands(HELD)
	for slot in HELD.size():
		_show(hands, slot)
		var held: ReplicaView.Held = hands._held[slot]
		assert_eq(hands._arms.holding(), held.id, "%s: the arms hold it" % held.id)
		assert_eq(_model(hands).get_parent(), held.root, "%s: on the replica's node" % held.id)
		assert_true(_model(hands).visible, "%s: shown" % held.id)
		var anim := _model(hands).find_child("AnimationPlayer", true, false) as AnimationPlayer
		# A pistol is held in both hands (HA1): its own clip, the bots keeping `<id>_Hold`.
		var both := ArmsView.TWO_HANDS if TWO.has(held.id) else ""
		assert_eq(anim.assigned_animation, StringName(String(held.id) + both + "_Hold"), "%s: its hold clip" % held.id)
		assert_true(anim.has_animation(StringName(String(held.id) + "_Hold")), "%s: the hold the bots copy" % held.id)


func test_the_hold_mark_sits_on_the_replica_origin() -> void:
	var hands := _hands(HELD)
	for slot in HELD.size():
		_show(hands, slot)
		var held: ReplicaView.Held = hands._held[slot]
		var mark := _model(hands).find_child("Hold_" + String(held.id), true, false) as Node3D
		var at := held.root.global_transform.affine_inverse() * mark.global_position
		assert_almost_eq(at, Vector3.ZERO, Vector3.ONE * EPS, "%s: hold mark on the origin" % held.id)


func test_the_arms_follow_the_replica() -> void:
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	var hands := ReplicaView.new()
	add_child_autofree(hands)
	hands.setup(cfg, c.armament.replicas, BoxWorld.new())
	for i in 60:
		hands.update(c, 0.0, 0.0, Vector3(0.0, 1.6, 0.0), Vector3.FORWARD, DT, 0.0)
	var held: ReplicaView.Held = hands._held[c.armament.active]
	var mark := _model(hands).find_child("Hold_" + String(held.id), true, false) as Node3D
	assert_almost_eq(mark.global_position, held.root.global_position, Vector3.ONE * EPS, "at the hip")
	hands.on_shot()
	hands.update(c, 0.3, 0.0, Vector3(0.0, 1.6, 0.0), Vector3.FORWARD, DT, 0.0)
	assert_almost_eq(mark.global_position, held.root.global_position, Vector3.ONE * EPS, "kicked and swayed")


func test_the_hand_works_the_sniper_bolt_in_step() -> void:
	var hands := _hands([&"sniper"])
	_show(hands, 0)
	var held: ReplicaView.Held = hands._held[0]
	var anim := _model(hands).find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert_true(anim.has_animation(&"sniper_Fire"), "the arms have a clip working the bolt")
	var fire := held.anim.get_animation(&"Fire").length
	var work := anim.get_animation(&"sniper_Fire").length
	assert_gt(work, fire + 0.1, "it runs on past the replica's Fire clip: the hand goes back to the grip after")
	hands.on_shot()
	held.anim.seek(0.4, true)
	hands._arms.follow(held.anim, DT)
	assert_eq(anim.assigned_animation, &"sniper_Fire", "working the bolt after a shot")
	assert_almost_eq(anim.current_animation_position, 0.4, 0.001, "in step with the replica's clip")
	# The replica's clip ends: the arms' runs on.
	held.anim.seek(fire - 0.05, true)
	hands._arms.follow(held.anim, DT)
	held.anim.pause()
	hands._arms.follow(held.anim, 0.1)
	assert_eq(anim.assigned_animation, &"sniper_Fire", "still on its way back to the grip")
	var speed := held.fire_speed
	assert_almost_eq(speed, cfg.bolt_cycle_end * ReplicaStats.load_replica(&"sniper").fire_rate, 1e-4,
			"the bolt's cycle stretched to the rifle's ready time (row 19)")
	assert_almost_eq(anim.current_animation_position, fire - 0.05 + 0.1 * speed, 0.001,
			"running on at the stretched clip's pace")
	hands._arms.follow(held.anim, work)
	hands._arms.follow(held.anim, DT)
	assert_eq(anim.assigned_animation, &"sniper_Hold", "back on the grip once its clip ends")


func test_a_clip_cutting_in_ends_the_bolts_working() -> void:
	var hands := _hands([&"sniper"])
	_show(hands, 0)
	var held: ReplicaView.Held = hands._held[0]
	var anim := _model(hands).find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert_true(held.anim.has_animation(ReplicaView.RELOAD_CLIP), "control: the rifle has a reload clip")
	hands.on_shot()
	held.anim.seek(0.4, true)
	hands._arms.follow(held.anim, DT)
	assert_eq(anim.assigned_animation, &"sniper_Fire", "control: working the bolt")
	held.anim.play(ReplicaView.RELOAD_CLIP)
	held.anim.pause()
	hands._arms.follow(held.anim, DT)
	assert_eq(anim.assigned_animation, &"sniper_Hold", "a reload takes the hand back to the grip")


func test_replicas_without_a_bolt_keep_their_hold_through_a_shot() -> void:
	var hands := _hands([&"aeg", &"pistol", &"cyber"])
	for slot in 3:
		_show(hands, slot)
		var held: ReplicaView.Held = hands._held[slot]
		var anim := _model(hands).find_child("AnimationPlayer", true, false) as AnimationPlayer
		hands.on_shot()
		hands._arms.follow(held.anim, DT)
		assert_eq(anim.assigned_animation, StringName(hands._arms.clip_base(held.id, &"") + "_Hold"),
				"%s: still its hold" % held.id)


func test_switching_moves_the_arms() -> void:
	var hands := _hands([&"aeg", &"pistol"])
	_show(hands, 0)
	_show(hands, 1)
	assert_eq(_model(hands).get_parent(), hands._held[1].root)
	assert_false(hands._held[0].root.is_ancestor_of(_model(hands)), "gone from the one put away")
	_show(hands, 0)
	assert_eq(_model(hands).get_parent(), hands._held[0].root)


func test_one_handed_replicas_hide_the_left_arm() -> void:
	var hands := _hands(HELD)
	var left := _model(hands).find_child("Arm_L", true, false) as MeshInstance3D
	var right := _model(hands).find_child("Arm_R", true, false) as MeshInstance3D
	for slot in HELD.size():
		_show(hands, slot)
		var id: StringName = HELD[slot]
		assert_eq(left.visible, not cfg.one_hand.has(id), "%s: left arm" % id)
		assert_true(right.visible, "%s: right arm" % id)


func test_a_replica_with_no_hold_shows_no_arms() -> void:
	var hands := _hands([&"aeg"])
	_show(hands, 0)
	assert_true(_model(hands).visible, "control: the rifle is held")
	assert_eq(hands._arms.holding(), &"aeg")
	hands._arms.hold(&"nothing", hands._held[0].root)
	assert_false(_model(hands).visible, "no hold: no arms")
	assert_eq(hands._arms.holding(), &"")


func test_the_arms_draw_as_the_replica_does() -> void:
	var hands := _hands([&"aeg"])
	_show(hands, 0)
	for node: Node in _model(hands).find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		assert_eq(mesh_node.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "no shadow")
		assert_eq(mesh_node.layers, OpticGlass.HANDS_LAYER, "out of the glass's view")
		for i in mesh_node.mesh.get_surface_count():
			var worn := mesh_node.get_surface_override_material(i) as BaseMaterial3D
			assert_not_null(worn, "a copy of its own")
			assert_true(worn.use_z_clip_scale, "depth pressed")
			assert_true(worn.disable_receive_shadows, "no shadow falls on them (pressed depth would streak it)")
			assert_almost_eq(worn.z_clip_scale, cfg.depth_scale, EPS)


func test_a_robot_wears_the_robot_colours() -> void:
	var hands := _hands([&"aeg"])
	_show(hands, 0)
	var arm := _model(hands).find_child("Arm_R", true, false) as MeshInstance3D
	var human := {}
	for i in arm.mesh.get_surface_count():
		human[arm.mesh.surface_get_material(i).resource_name] = (arm.get_surface_override_material(i) as BaseMaterial3D)
	hands.arms_kind = FigureMix.ROBOT
	for i in arm.mesh.get_surface_count():
		var name := StringName(arm.mesh.surface_get_material(i).resource_name)
		var worn := arm.get_surface_override_material(i) as BaseMaterial3D
		assert_true(cfg.robot_arms.has(name), "%s has a robot colour" % name)
		assert_eq(worn.albedo_color, cfg.robot_arms[name], "%s in the robot's colour" % name)
		assert_true(worn.use_z_clip_scale, "%s: still pressed" % name)
	hands.arms_kind = FigureMix.HUMAN
	for i in arm.mesh.get_surface_count():
		var name: String = arm.mesh.surface_get_material(i).resource_name
		assert_eq(arm.get_surface_override_material(i), human[name], "%s back to the glove" % name)


func test_every_arms_material_is_offered_to_the_prewarm() -> void:
	var hands := _hands([&"aeg"])
	var offered := hands.arms_materials()
	var own := {}
	for node: Node in _model(hands).find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		for i in mesh_node.mesh.get_surface_count():
			own[mesh_node.mesh.surface_get_material(i)] = true
	assert_eq(own.size(), 4, "the model's four materials (the budget): glove, its armour, sleeve and skin")
	assert_eq(offered.size(), 4 * own.size(), "each one's human and robot copies, and their fading copies (HA1)")
	_show(hands, 0)
	var arm := _model(hands).find_child("Arm_R", true, false) as MeshInstance3D
	for i in arm.mesh.get_surface_count():
		assert_has(offered, arm.get_surface_override_material(i), "the human one worn is prewarmed")
	hands.arms_kind = FigureMix.ROBOT
	for i in arm.mesh.get_surface_count():
		assert_has(offered, arm.get_surface_override_material(i), "the robot one worn is prewarmed")
	hands.arms_kind = FigureMix.HUMAN
	hands.skin_arms = true
	for i in arm.mesh.get_surface_count():
		assert_has(offered, arm.get_surface_override_material(i), "the skin one worn is prewarmed")


func test_the_arms_are_freed_with_the_view() -> void:
	var hands := _hands([&"aeg", &"pistol"])
	_show(hands, 1)
	var model := _model(hands)
	hands.free()
	assert_false(is_instance_valid(model))
