extends GutTest
## QA for BP8 arms (notes 6, 9, 11): edges the worker's tests leave: grips that cannot fit or are unknown, a reload cut
## short, the left hand's way back to the hold, skin only switched mid-reload, and what the toggle creates.

const DT := 1.0 / 60.0
const GRIPS: Array[StringName] = [&"vertical", &"angled"]
const GRIPPED: Array[StringName] = [&"aeg", &"sniper"]
const HELD: Array[StringName] = [&"aeg", &"pistol", &"cyber", &"sniper"]
const EYE := Vector3(0.0, 1.6, 0.0)
## How far (rad or m) a key may sit from the hold's for "back on the hold".
const BACK_SLACK := 1e-3

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


func _character(id: StringName) -> Character:
	var loadout: Array[ReplicaConfig] = [ReplicaStats.load_replica(id)]
	return Character.new(0, 0, Vector3.ZERO, 0.0, loadout)


func _step(hands: ReplicaView, c: Character, aim: float = 0.0) -> void:
	hands.update(c, 0.0, 0.0, EYE, Vector3.FORWARD, DT, aim)


func test_a_grip_a_replica_cannot_take_leaves_its_hold() -> void:
	for grip in GRIPS:
		for id: StringName in [&"pistol", &"cyber"]:
			var hands := _hands([id], grip)
			hands._show(0)
			assert_eq(_anim(hands).assigned_animation, StringName(String(id) + "_Hold"), "%s with a %s grip" % [id, grip])
			assert_false(_mesh(hands, ArmsView.LEFT_ARM).visible, "%s stays one-handed" % id)


func test_an_unknown_grip_key_falls_back_to_the_plain_hold() -> void:
	var hands := _hands(GRIPPED, &"stubby")
	for slot in GRIPPED.size():
		hands._show(slot)
		assert_eq(_anim(hands).assigned_animation, StringName(String(GRIPPED[slot]) + "_Hold"))
		assert_eq(hands._arms._reload, StringName(String(GRIPPED[slot]) + "_Reload"), "and its reload")


func test_every_gripped_reload_and_hold_track_resolves_on_the_model() -> void:
	var hands := _hands(GRIPPED)
	var anim := _anim(hands)
	var root := anim.get_node(anim.root_node)
	for id in GRIPPED:
		for grip in GRIPS:
			for suffix: String in ["_Hold", "_Reload", "_Fire"]:
				var name := StringName("%s_grip_%s%s" % [id, grip, suffix])
				if not anim.has_animation(name):
					assert_ne(suffix, "_Hold", "%s missing" % name)
					assert_ne(suffix, "_Reload", "%s missing" % name)
					continue
				var clip := anim.get_animation(name)
				for t in clip.get_track_count():
					var path := clip.track_get_path(t)
					assert_not_null(root.get_node_or_null(NodePath(path.get_concatenated_names())),
							"%s: track %s has a node" % [name, path])


func test_a_reload_ends_on_the_hold_it_began_from() -> void:
	var anim := _anim(_hands([&"aeg"]))
	var clips: Array[String] = []
	for id in HELD:
		clips.append(String(id))
	for id in GRIPPED:
		for grip in GRIPS:
			clips.append("%s_grip_%s" % [id, grip])
	for base in clips:
		var hold := anim.get_animation(StringName(base + "_Hold"))
		var reload := anim.get_animation(StringName(base + "_Reload"))
		for t in reload.get_track_count():
			var other := hold.find_track(reload.track_get_path(t), reload.track_get_type(t))
			if other < 0:
				continue
			var from: Variant = reload.track_get_key_value(t, 0)
			var to: Variant = reload.track_get_key_value(t, reload.track_get_key_count(t) - 1)
			var rest: Variant = hold.track_get_key_value(other, 0)
			if from is Vector3 or from is Quaternion:
				assert_almost_eq(_dist(from, rest), 0.0, BACK_SLACK, "%s starts on the hold (%s)" % [base, reload.track_get_path(t)])
				assert_almost_eq(_dist(to, rest), 0.0, BACK_SLACK, "%s ends on the hold (%s)" % [base, reload.track_get_path(t)])


func _dist(a: Variant, b: Variant) -> float:
	if a is Quaternion:
		return 1.0 - absf((a as Quaternion).dot(b as Quaternion))
	return (a as Vector3).distance_to(b as Vector3)


func test_a_cut_reload_on_a_gripped_rifle_returns_to_the_grip_hold() -> void:
	for grip in GRIPS:
		var hands := _hands([&"aeg"], grip)
		var c := _character(&"aeg")
		_step(hands, c)
		c.armament.reload_left = c.armament.replica().reload_time * 0.5
		_step(hands, c)
		assert_eq(_anim(hands).assigned_animation, StringName("aeg_grip_%s_Reload" % grip), "mid-reload")
		c.armament.reload_left = 0.0
		_step(hands, c)
		assert_eq(_anim(hands).assigned_animation, StringName("aeg_grip_%s_Hold" % grip), "cut: the grip hold, not the plain one")
		assert_true(_mesh(hands, ArmsView.LEFT_ARM).visible)


func test_a_cut_pistol_reload_hides_the_left_arm_at_once() -> void:
	var hands := _hands([&"pistol"])
	var c := _character(&"pistol")
	_step(hands, c)
	c.armament.reload_left = c.armament.replica().reload_time * 0.3
	_step(hands, c)
	assert_true(_mesh(hands, ArmsView.LEFT_ARM).visible)
	c.armament.reload_left = 0.0
	_step(hands, c)
	assert_false(_mesh(hands, ArmsView.LEFT_ARM).visible, "sprint, grenade or switch cut it: hand gone")
	assert_false(hands._arms.reloading())


func test_switching_replica_mid_reload_puts_each_hand_right() -> void:
	var loadout: Array[ReplicaConfig] = [ReplicaStats.load_replica(&"aeg"), ReplicaStats.load_replica(&"pistol")]
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, loadout)
	var hands := ReplicaView.new()
	add_child_autofree(hands)
	hands.setup(cfg, loadout, BoxWorld.new())
	_step(hands, c)
	c.armament.reload_left = loadout[0].reload_time * 0.5
	_step(hands, c)
	hands._show(1)
	assert_false(hands._arms.reloading(), "the new replica is on its hold")
	assert_false(_mesh(hands, ArmsView.LEFT_ARM).visible, "the pistol is one-handed again")
	hands._arms.follow(hands._held[1].anim, DT, -1.0)
	assert_eq(_anim(hands).assigned_animation, &"pistol_Hold")
	hands._show(0)
	assert_true(_mesh(hands, ArmsView.LEFT_ARM).visible)
	assert_eq(_anim(hands).assigned_animation, &"aeg_Hold")


func test_a_reload_while_aimed_still_follows_its_share() -> void:
	var hands := _hands([&"aeg"], &"vertical")
	var c := _character(&"aeg")
	_step(hands, c, 1.0)
	c.armament.reload_left = c.armament.replica().reload_time * 0.75
	_step(hands, c, 1.0)
	var anim := _anim(hands)
	assert_eq(anim.assigned_animation, &"aeg_grip_vertical_Reload")
	assert_almost_eq(anim.current_animation_position / anim.current_animation_length, 0.25, 1e-3)


func test_a_reload_out_of_view_ends_on_the_hold_when_seen_again() -> void:
	var hands := _hands([&"aeg"])
	var c := _character(&"aeg")
	_step(hands, c)
	c.armament.reload_left = c.armament.replica().reload_time * 0.5
	_step(hands, c)
	c.status = Character.Status.OUT
	_step(hands, c)
	c.status = Character.Status.ALIVE
	c.armament.reload_left = 0.0
	_step(hands, c)
	assert_eq(_anim(hands).assigned_animation, &"aeg_Hold", "a new round: the hold, not a frozen reload")


func test_two_reloads_in_a_row_each_run_the_clip() -> void:
	var hands := _hands([&"aeg"])
	var c := _character(&"aeg")
	_step(hands, c)
	for round in 2:
		c.armament.reload_left = c.armament.replica().reload_time * 0.5
		_step(hands, c)
		assert_true(hands._arms.reloading(), "reload %d" % round)
		c.armament.reload_left = 0.0
		_step(hands, c)
		assert_false(hands._arms.reloading())


func test_skin_switched_mid_reload_on_a_pistol_shows_the_left_nails() -> void:
	var hands := _hands([&"pistol"])
	hands._show(0)
	var held: ReplicaView.Held = hands._held[0]
	hands._arms.follow(held.anim, DT, 0.5)
	hands.skin_arms = true
	assert_true(_mesh(hands, ArmsView.NAILS_PREFIX + "L").visible, "left nails while the hand works")
	assert_false(_mesh(hands, ArmsView.KIT_PREFIX + "L").visible)
	hands.skin_arms = false
	assert_true(_mesh(hands, ArmsView.KIT_PREFIX + "L").visible)
	assert_false(_mesh(hands, ArmsView.NAILS_PREFIX + "L").visible)
	hands._arms.follow(held.anim, DT)
	for m: String in [ArmsView.LEFT_ARM, ArmsView.KIT_PREFIX + "L", ArmsView.NAILS_PREFIX + "L"]:
		assert_false(_mesh(hands, m).visible, "%s hidden once the reload is over" % m)


func test_skin_set_before_setup_is_worn_at_setup() -> void:
	var hands := ReplicaView.new()
	hands.skin_arms = true
	add_child_autofree(hands)
	var loadout: Array[ReplicaConfig] = [ReplicaStats.load_replica(&"aeg")]
	hands.setup(cfg, loadout, BoxWorld.new())
	hands._show(0)
	assert_true(hands._arms.skin_worn())
	assert_false(_mesh(hands, ArmsView.KIT_PREFIX + "R").visible)
	assert_true(_mesh(hands, ArmsView.NAILS_PREFIX + "R").visible)


func test_toggling_skin_creates_no_new_materials() -> void:
	var hands := _hands([&"aeg"])
	var before := hands._arms.materials().size()
	for i in 6:
		hands.skin_arms = i % 2 == 0
		hands.arms_kind = FigureMix.ROBOT if i % 3 == 0 else FigureMix.HUMAN
	assert_eq(hands._arms.materials().size(), before, "the three looks are made once")
	assert_eq(before % 3, 0, "human, robot and skin of each")


func test_a_robot_with_skin_on_keeps_robot_colours_then_skin_returns() -> void:
	var hands := _hands([&"aeg"])
	hands.skin_arms = true
	hands.arms_kind = FigureMix.ROBOT
	assert_false(hands._arms.skin_worn())
	var arm := _mesh(hands, "Arm_R")
	for i in arm.mesh.get_surface_count():
		var key := StringName(arm.mesh.surface_get_material(i).resource_name)
		if cfg.skin_arms.has(key):
			assert_ne((arm.get_surface_override_material(i) as BaseMaterial3D).albedo_color, cfg.skin_arms[key], "robot colour")
	hands.arms_kind = FigureMix.HUMAN
	assert_true(hands._arms.skin_worn())
	assert_false(_mesh(hands, ArmsView.KIT_PREFIX + "R").visible)


func test_a_corrupt_or_older_save_leaves_skin_arms_off() -> void:
	var d := DevSettings.new()
	d.from_dict({"robots": true})
	assert_false(d.skin_arms, "an older file without the key")
	d.from_dict({"skin_arms": "yes"})
	assert_false(d.skin_arms, "a string is not a switch")
	d.from_dict({"skin_arms": 1})
	assert_false(d.skin_arms, "nor a number")
	d.from_dict({"skin_arms": true})
	assert_true(d.skin_arms)
	d.from_dict({})
	assert_false(d.skin_arms, "an empty file falls back to off")
