extends GutTest
## BL4: your arms in first person hold the replica in hand. They ride its node (so they follow its sway, kick and drop),
## are posed by that replica's hold clip with its hold mark on the replica's origin, hide the left arm on one-handed
## replicas, press their depth and stay out of shadows and the optic's view, and wear the robot's colours for a robot.

const DT := 1.0 / 60.0
const EPS := 1e-4
const HELD := [&"aeg", &"pistol", &"cyber", &"sniper"]

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
		assert_eq(anim.assigned_animation, StringName(String(held.id) + "_Hold"), "%s: its hold clip" % held.id)


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
	hands._arms.hold(&"nothing", hands._held[0].root)
	assert_false(_model(hands).visible)
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


func test_the_arms_are_freed_with_the_view() -> void:
	var hands := _hands([&"aeg", &"pistol"])
	_show(hands, 1)
	var model := _model(hands)
	hands.free()
	assert_false(is_instance_valid(model))
