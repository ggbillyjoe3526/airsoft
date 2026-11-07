extends GutTest
## HG1: the figures' hands hold the replica as the first-person arms do (BL4's approved holds): the right hand high on
## the grip, index on the trigger, thumb round the grip's left side; the left under a rifle's handguard (behind a fitted
## grip). The left lets go in a reload, and a pistol has no handguard to hold.

const EYE := Vector3(0.0, 1.6, 3.0)
const FRAME := 1.0 / 60.0
## How near (m) a hand sits to the arms' place on the replica, and how near (rad) a hand or finger turns to theirs.
const PLACE := 0.005
const TURN := 0.05
## How near (m) the thumb's tip comes to the line of the arms' last thumb bone (the figures' shorter thumb reaches
## along it as far as it can).
const THUMB := 0.01

var config: FigureConfig = null
var models: FigureModels = null
var hits: HitConfig = null


func before_all() -> void:
	config = FigureConfig.new()
	models = FigureModels.new(config)
	models.load_kinds()
	hits = HitConfig.new()


func _view(slot: int, parts: Array[Dictionary] = [], first: StringName = &"") -> Array:
	var loadout := ReplicaStats.default_loadout()
	if first != &"":
		loadout = [ReplicaStats.load_replica(first), ReplicaStats.load_replica(&"pistol")] as Array[ReplicaConfig]
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, loadout)
	c.grounded = true
	c.armament.active = slot
	var v := FigureView.new()
	add_child_autofree(v)
	v.setup(c, Color.RED, hits, null, false, parts, 0.0, config)
	v.set_body(models, FigureMix.HUMAN, config.lod_high)
	return [v, c]


## Poses `v` for `frames` frames, then returns each named bone's frame as drawn (in the skeleton's frame) and, under
## &"replica", the held replica's; seen from `eye`.
func _drawn(v: FigureView, c: Character, bones: PackedStringArray, frames: int = 40, eye: Vector3 = EYE) -> Dictionary:
	var sk := v.body().skeleton
	var out := {}
	var grab := func() -> void:
		for b: String in bones:
			out[b] = sk.get_bone_global_pose(sk.find_bone(b))
	for i in frames:
		v.update(c, 1.0)
		v.animate(c, 1.0, FRAME, eye)
	sk.skeleton_updated.connect(grab)
	v.update(c, 1.0)
	v.animate(c, 1.0, FRAME, eye)
	await wait_process_frames(1)
	sk.skeleton_updated.disconnect(grab)
	var hands := v.body().hands
	out[&"replica"] = hands.replica(hands.in_hand).transform
	return out


## Each of `suffix`'s hand bone and fingers (FigureConfig.hold_fingers).
func _hand_bones(suffix: String) -> PackedStringArray:
	var out := PackedStringArray([config.hold_hand + suffix])
	for f in config.hold_fingers:
		out.append(f + suffix)
	return out


## Checks the hand `suffix` in `drawn` against `on` (its place in the replica's frame) and its fingers against the
## arms' (`joints` and `tips`, FigureArmsHold's, in the replica's frame): each finger bone points at the arms' next joint
## (the figures' fingers are shorter), and the thumb's tip comes to rest where the arms' does.
func _held_as(drawn: Dictionary, suffix: String, on: Transform3D, joints: PackedVector3Array,
		tips: PackedVector3Array, what: String) -> void:
	var replica: Transform3D = drawn[&"replica"]
	var hand: Transform3D = drawn[config.hold_hand + suffix]
	var in_replica := replica.affine_inverse() * hand
	assert_lt(in_replica.origin.distance_to(on.origin), PLACE, "%s: the hand where the arms' is" % what)
	var turned := Quaternion(in_replica.basis.orthonormalized()).angle_to(Quaternion(on.basis.orthonormalized()))
	assert_lt(turned, TURN, "%s: the hand turned as the arms' is (%.3f rad)" % [what, turned])
	var at: Array[Transform3D] = []
	for f in config.hold_fingers:
		at.append(replica.affine_inverse() * (drawn[f + suffix] as Transform3D))
	for i in range(3, at.size()):
		var next := at[i + 1].origin if i % 3 != 2 else at[i].origin + at[i].basis.y.normalized() * 0.02
		var aim := (joints[i + 1] if i % 3 != 2 else tips[i / 3]) - at[i].origin
		var off := (next - at[i].origin).angle_to(aim)
		assert_lt(off, TURN, "%s: %s toward the arms' (%.3f rad)" % [what, config.hold_fingers[i], off])
	var tip := at[2].origin + at[2].basis.y.normalized() * at[1].origin.distance_to(at[2].origin)
	var off_line := tip.distance_to(Geometry3D.get_closest_point_to_segment_uncapped(tip, joints[2], tips[0]))
	assert_lt(off_line, THUMB, "%s: the thumb's tip on the arms' last thumb bone (%.3f m off)" % [what, off_line])


## `points` each moved by `by`.
func _moved(points: PackedVector3Array, by: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p in points:
		out.append(p + by)
	return out


func test_the_arms_model_has_a_hold_for_every_replica() -> void:
	for id: StringName in [&"aeg", &"sniper", &"pistol", &"cyber"]:
		var hold := models.arms_hold(id)
		assert_not_null(hold, "%s: a hold" % id)
		if hold != null:
			assert_eq(hold.right.size(), config.hold_fingers.size(), "%s: every right finger" % id)
			assert_eq(hold.left.size(), config.hold_fingers.size(), "%s: every left finger" % id)
	assert_null(models.arms_hold(&"no_such_replica"), "none for a replica the arms don't hold")


func test_the_right_hand_holds_each_replica_as_the_arms_do() -> void:
	for id: StringName in [&"aeg", &"sniper", &"pistol", &"cyber"]:
		var r := _view(0, [], id)
		var v: FigureView = r[0]
		var drawn := await _drawn(v, r[1], _hand_bones("_R"))
		var hands := v.body().hands
		var slot := hands.in_hand
		assert_almost_eq(v.body().bend.grasp, 1.0, 0.01, "%s: held" % id)
		var hold := hands.held(slot).arms
		_held_as(drawn, "_R", hands.held(slot).right, hold.right_joints, hold.right_tips, String(id))
		var thumb: Transform3D = (drawn[&"replica"] as Transform3D).affine_inverse() \
				* (drawn[config.hold_fingers[2] + "_R"] as Transform3D)
		assert_lt((thumb.origin + thumb.basis.y.normalized() * 0.02).x, -0.015,
				"%s: the thumb round the grip's left side" % id)


func test_the_left_hand_holds_each_rifle_s_handguard_as_the_arms_do() -> void:
	for id: StringName in [&"aeg", &"sniper"]:
		var r := _view(0, [], id)
		var v: FigureView = r[0]
		var drawn := await _drawn(v, r[1], _hand_bones("_L"))
		var hands := v.body().hands
		var slot := hands.in_hand
		assert_not_null(hands.held(slot), "%s: a handguard to hold" % id)
		assert_almost_eq(v.body().bend.support, 1.0, 0.01, "%s: held" % id)
		_held_as(drawn, "_L", hands.held(slot).left, hands.held(slot).arms.left_joints, hands.held(slot).arms.left_tips,
				String(id))


func test_a_pistol_is_held_in_one_hand_and_a_reload_lets_go() -> void:
	var p := _view(1)
	var pv: FigureView = p[0]
	var drawn := await _drawn(pv, p[1], _hand_bones("_L"))
	var hands := pv.body().hands
	var slot := hands.in_hand
	assert_not_null(hands.held(slot), "the left hand takes the arms' pistol hold")
	assert_almost_eq(pv.body().bend.support, 1.0, 0.01, "held")
	var left: Transform3D = (drawn[&"replica"] as Transform3D).affine_inverse() \
			* (drawn[config.hold_hand + "_L"] as Transform3D)
	assert_lt(left.origin.distance_to(hands.held(slot).left.origin), PLACE, "the left hand lowered as the arms' is")
	assert_gt(left.origin.distance_to(hands.held(slot).right.origin), 0.2, "one hand on the pistol")
	var r := _view(0)
	var v: FigureView = r[0]
	var c: Character = r[1]
	await _drawn(v, c, PackedStringArray())
	assert_almost_eq(v.body().bend.support, 1.0, 0.01, "held")
	c.armament.reload_left = c.armament.replicas[0].reload_time * 0.5
	await _drawn(v, c, PackedStringArray(), 30)
	assert_eq(v.body().bend.support, 0.0, "the left hand fetches the magazine")


func test_a_switch_lets_go_of_both() -> void:
	var r := _view(0)
	var v: FigureView = r[0]
	var c: Character = r[1]
	await _drawn(v, c, PackedStringArray())
	assert_almost_eq(v.body().bend.grasp, 1.0, 0.01, "held")
	c.armament.active = 1
	c.armament.draw_left = c.armament.replicas[1].draw_time
	c.armament.draw_total = c.armament.draw_left
	await _drawn(v, c, PackedStringArray(), 12)
	assert_eq(v.body().bend.grasp, 0.0, "the right hand lets go of the grip to switch")
	assert_eq(v.body().bend.support, 0.0, "and the left of the handguard")


func test_behind_a_fitted_grip() -> void:
	var grip := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.02, 0.06, 0.03)
	grip.mesh = box
	grip.position = Vector3(0.0, -0.01, -0.215)
	var mount := Vector3(0.0, 0.022, -0.215)
	var mark := FigureView.support_mark(mount, grip, config)
	assert_almost_eq(mark.z, -0.2 + config.support_behind_grip, 0.0001, "behind the grip's back end")
	assert_eq(FigureView.support_mark(mount, null, config), mount, "at the mount with none")
	assert_false(FigureView.support_mark(Vector3.INF, grip, config).is_finite(), "no mount: no support")
	grip.free()
	var bare := _view(0)
	var bv: FigureView = bare[0]
	await _drawn(bv, bare[1], PackedStringArray())
	var held := models.arms_hold(&"aeg")
	for kind: StringName in [&"vertical", &"angled"]:
		var fitted := _view(0, [{&"grip": kind}])
		var v: FigureView = fitted[0]
		var drawn := await _drawn(v, fitted[1], _hand_bones("_L"))
		var hands := v.body().hands
		var slot := hands.in_hand
		var back := hands.held(slot).left.origin - bv.body().hands.held(slot).left.origin
		assert_gt(back.z, 0.01, "%s: the hand moved back behind the grip (%.3f m)" % [kind, back.z])
		assert_almost_eq(back.x, 0.0, 0.0001, "%s: straight back" % kind)
		var by := hands.held(slot).left_shift
		assert_almost_eq(by, back, Vector3.ONE * 0.0001, "%s: its fingers moved back with it" % kind)
		_held_as(drawn, "_L", hands.held(slot).left, _moved(held.left_joints, by), _moved(held.left_tips, by),
				"%s grip" % kind)


func test_past_the_near_line_the_hand_holds_but_the_fingers_keep_the_clips() -> void:
	var bones := _hand_bones("_R")
	var r := _view(0)
	var near: Dictionary = await _drawn(r[0], r[1], bones)
	var far_view := _view(0)
	var past := config.lod_high.x + config.lod_margin + 2.0
	var far: Dictionary = await _drawn(far_view[0], far_view[1], bones, 40, EYE + Vector3(0.0, 0.0, past))
	assert_true(r[0].body().near, "within the near line")
	assert_false(far_view[0].body().near, "past it")
	var hand: Transform3D = near[bones[0]]
	var held: Transform3D = far[bones[0]]
	assert_lt(hand.origin.distance_to(held.origin), PLACE, "the hand still sits on the grip out there")
	var tip := bones[bones.size() - 1]
	var closed: Transform3D = hand.affine_inverse() * near[tip]
	var kept: Transform3D = held.affine_inverse() * far[tip]
	assert_gt(closed.origin.distance_to(kept.origin), PLACE, "but its fingers are the clips', not closed on the replica")


func test_out_of_the_camera_s_view_the_hands_keep_the_clips() -> void:
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.global_position = EYE
	camera.make_current()
	var r := _view(0)
	var v: FigureView = r[0]
	await _drawn(v, r[1], PackedStringArray())
	assert_true(v.body().seen, "in front of the camera")
	assert_eq(v.body().bend.held, v.body().hands.held(0), "the hands hold the replica")
	camera.global_rotation = Vector3(0.0, PI, 0.0)
	await _drawn(v, r[1], PackedStringArray(), config.hold_view_stride + 1)
	assert_false(v.body().seen, "behind it (looked at every hold_view_stride-th frame)")
	assert_null(v.body().bend.held, "the hands keep the clips'")
	assert_eq(v.body().hands.grasp, 0.0, "and the replica the clips' place")
	assert_gt(v.body().bend.grasp, 0.9, "the hold stays eased in, ready for when it shows")


func test_a_fast_turn_or_a_camera_cut_looks_at_the_view_at_once() -> void:
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.global_position = EYE
	camera.global_rotation = Vector3(0.0, PI, 0.0)
	camera.make_current()
	var r := _view(0)
	var v: FigureView = r[0]
	var stride := config.hold_view_stride
	config.hold_view_stride = 1000
	await _drawn(v, r[1], PackedStringArray(), 2)
	assert_false(v.body().seen, "behind the camera")
	camera.global_rotation = Vector3.ZERO
	await _drawn(v, r[1], PackedStringArray(), 0)
	assert_true(v.body().seen, "turned to it: held on the next frame, not after the stride")
	var cut := Camera3D.new()
	add_child_autofree(cut)
	cut.global_position = EYE
	cut.global_rotation = Vector3(0.0, PI, 0.0)
	cut.make_current()
	await _drawn(v, r[1], PackedStringArray(), 0)
	config.hold_view_stride = stride
	assert_false(v.body().seen, "cut to another camera looking away: at once too")


func test_in_view_is_a_cone_round_the_view_s_corners() -> void:
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.fov = 75.0
	assert_true(FigureView.in_view(null, Vector3(0.0, 0.0, 50.0), 1.0), "no camera: always")
	assert_true(FigureView.in_view(camera, Vector3(0.0, 0.0, -10.0), 1.0), "ahead")
	assert_false(FigureView.in_view(camera, Vector3(0.0, 0.0, 10.0), 1.0), "behind")
	assert_true(FigureView.in_view(camera, Vector3(0.0, 0.0, 0.5), 1.0), "round the camera")
	assert_false(FigureView.in_view(camera, Vector3(10.0, 0.0, 0.0), 1.0), "square to the side")
	assert_true(FigureView.in_view(camera, Vector3(10.0, 0.0, 0.0), 10.0), "unless the ball reaches into the view")
