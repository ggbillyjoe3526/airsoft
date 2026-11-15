extends GutTest
## HA2 QA: an inspect cut short (sprint, reload, switch) leaves no arm bone drawn in, and the arms ease back from it
## without a snap.

const DT := 1.0 / 60.0
const HELD: Array[StringName] = [&"aeg", &"sniper", &"smg", &"shotgun", &"pistol", &"cyber"]
const SIDES: Array[String] = ["_L", "_R"]
## The most a shoulder may move in the replica's space in one frame of the ease-back (m; the turn eases back over
## 0.13 s from up to a turn of a radian: about 5 cm a frame).
const SNAP := 0.08
## A bone back at its rest place, within this (m).
const BACK := 0.002


func _view(id: StringName, extra: StringName = &"") -> Array:
	var loadout: Array[ReplicaConfig] = [ReplicaStats.load_replica(id)]
	if extra != &"":
		loadout.append(ReplicaStats.load_replica(extra))
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, loadout)
	var view := ReplicaView.new()
	add_child_autofree(view)
	view.setup(ViewModelConfig.new(), loadout, BoxWorld.new())
	return [view, c]


func _frames(view: ReplicaView, c: Character, n: int, aim: float = 0.0) -> void:
	for i in n:
		view.update(c, 0.0, 0.0, Vector3(0.0, 1.6, 0.0), Vector3.FORWARD, DT, aim)


func _in_replica(view: ReplicaView, bone: String) -> Vector3:
	var skeleton := view._arms._skeleton
	skeleton.force_update_all_bone_transforms()
	var at := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin
	return view._held[view._active].root.global_transform.affine_inverse() * at


func _in_view(view: ReplicaView, bone: String) -> Vector3:
	var skeleton := view._arms._skeleton
	skeleton.force_update_all_bone_transforms()
	var at := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin
	return view.global_transform.affine_inverse() * at


func test_an_inspect_cut_by_a_sprint_leaves_no_arm_drawn_in_and_eases_back_without_a_snap() -> void:
	for id: StringName in HELD:
		var vc := _view(id)
		var view: ReplicaView = vc[0]
		var c: Character = vc[1]
		_frames(view, c, 30)
		var rest: Array[Vector3] = []
		for side: String in SIDES:
			rest.append(_in_replica(view, "UpperArm" + side))
		view.inspect()
		_frames(view, c, 1)
		_frames(view, c, int(view._inspect_length / DT * 0.4))
		assert_true(view.inspecting(), "%s: under way" % id)
		c.sprinting = true
		var last: Array[Vector3] = [_in_replica(view, "UpperArm_L"), _in_replica(view, "UpperArm_R")]
		var worst := 0.0
		for f in 90:
			_frames(view, c, 1)
			for i in SIDES.size():
				var now := _in_replica(view, "UpperArm" + SIDES[i])
				worst = maxf(worst, now.distance_to(last[i]))
				last[i] = now
		assert_lt(worst, SNAP, "%s: the shoulders ease back, no snap" % id)
		assert_false(view.inspecting(), "%s: cut" % id)
		assert_false(view._arms._tucked, "%s: no bone left drawn in" % id)
		for i in SIDES.size():
			assert_lt(_in_replica(view, "UpperArm" + SIDES[i]).distance_to(rest[i]), BACK,
					"%s%s: the shoulder back at rest" % [id, SIDES[i]])


func test_an_inspect_cut_by_a_reload_leaves_no_arm_drawn_in() -> void:
	for id: StringName in HELD:
		var vc := _view(id)
		var view: ReplicaView = vc[0]
		var c: Character = vc[1]
		_frames(view, c, 30)
		view.inspect()
		_frames(view, c, 1)
		_frames(view, c, int(view._inspect_length / DT * 0.5))
		c.armament.reload_left = c.armament.replica().reload_time
		_frames(view, c, 60)
		assert_false(view._arms._tucked, "%s: the reload's arms are the clip's alone" % id)


func test_a_switch_mid_inspect_leaves_the_new_hold_on_its_clip_alone() -> void:
	var vc := _view(&"aeg", &"pistol")
	var view: ReplicaView = vc[0]
	var c: Character = vc[1]
	_frames(view, c, 30)
	view.inspect()
	_frames(view, c, 40)
	c.armament.active = 1
	_frames(view, c, 60)
	assert_false(view.inspecting(), "ended with the switch")
	assert_false(view._arms._tucked, "the new hold's arms are on their clip alone")
