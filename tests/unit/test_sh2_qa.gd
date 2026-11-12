extends GutTest
## QA for SH2 (the Pump Shotgun's own model, hold and pump): the model's replica contract, its parts on their mounts,
## the pump home before the next shot at every spring, the cant its arms draw, the arms' clips and the pump's cue.

const SHOTGUN := "000027"
const SPRINGS: Array[String] = ["000022", "000023", "000024"]
const DT := 1.0 / 60.0
const MODEL := "res://assets/models/replicas/shotgun.glb"
const PARTS := "res://assets/models/replicaParts/shotgun.glb"
const ARMS := "res://assets/models/arms/arms.glb"
const EYE := Vector3(0.0, 1.6, 0.0)

var rules: LoadoutRules


func before_each() -> void:
	rules = LoadoutRules.new(Pool.read_file(), ReplicaStats.read_file(), ReplicaRulesConfig.new())
	rules.dev_content = true


func _scene(path: String) -> Node3D:
	var n := (load(path) as PackedScene).instantiate() as Node3D
	add_child_autofree(n)
	return n


func _skeleton(root: Node) -> Skeleton3D:
	return root.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D


## The shotgun with spring `power` fitted, as the loadout carries it.
func _with_spring(power: String) -> ReplicaConfig:
	var l := Loadout.new()
	assert_true(rules.equip(l, Loadout.Slot.PRIMARY, SHOTGUN))
	assert_true(rules.set_power(l, SHOTGUN, power))
	return rules.carried(l).replicas[0]


func test_its_model_has_the_replica_contract_bones_clips_and_empties() -> void:
	var model := _scene(MODEL)
	var sk := _skeleton(model)
	for bone: String in ["root", "trigger", "selector", "magRelease", "magazine", "pump"]:
		assert_gt(sk.find_bone(bone), -1, "bone %s" % bone)
	var anim := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for clip: StringName in [&"Fire", &"Reload", &"Selector", &"Inspect"]:
		assert_true(anim.has_animation(clip), clip)
	for empty: String in ["Muzzle", "BarrelEnd", "FrontSight", "RearSight", "MagWell", "OpticMount", "TorchMount"]:
		assert_not_null(model.find_child(empty, true, false), empty)


func test_the_aim_line_lies_along_its_rail_just_over_the_optic_mount() -> void:
	var model := _scene(MODEL)
	var mount := model.find_child("OpticMount", true, false) as Node3D
	var front := model.find_child("FrontSight", true, false) as Node3D
	var rear := model.find_child("RearSight", true, false) as Node3D
	assert_almost_eq(front.position.y - mount.position.y, 0.0095, 1e-3, "9.5 mm over the rail")
	assert_almost_eq(rear.position.y, front.position.y, 1e-4)
	assert_lt(front.position.z, rear.position.z, "front ahead of rear")


func test_every_part_in_its_file_sits_on_its_mount_and_the_laser_is_the_torchs_mirror() -> void:
	var model := _scene(MODEL)
	var parts := _scene(PARTS)
	var optic_mount := model.find_child("OpticMount", true, false) as Node3D
	var torch_mount := model.find_child("TorchMount", true, false) as Node3D
	for optic: String in ["optic_redDot", "optic_scope2x", "optic_scopeVar"]:
		var p := parts.find_child(optic, true, false) as Node3D
		assert_not_null(p, optic)
		assert_true(p.position.is_equal_approx(optic_mount.position), "%s on the optic mount" % optic)
	var laser := parts.find_child("laser_redLaser", true, false) as Node3D
	var torch := parts.find_child("light_weaponTorch", true, false) as Node3D
	assert_not_null(laser)
	assert_not_null(torch)
	assert_true(torch.position.is_equal_approx(torch_mount.position), "the torch on its mount")
	assert_lt(laser.position.x, 0.0, "the laser on the left rail")
	assert_almost_eq(laser.position.x, -torch.position.x, 1e-4, "mirroring the torch")
	assert_almost_eq(laser.position.y, torch.position.y, 1e-4)
	assert_almost_eq(laser.position.z, torch.position.z, 1e-4)
	for refused: String in ["grip_vertical", "grip_angled", "muzzle_silencer", "barrel_long", "magazine_hiCap"]:
		assert_null(parts.find_child(refused, true, false), "%s isn't made for it" % refused)


func test_fitted_parts_come_off_cleanly_and_the_model_needs_no_sights_hidden() -> void:
	var model := _scene(MODEL)
	assert_eq(IronSights.of(model).size(), 0, "no sight bones to hide")
	var before := model.get_child_count()
	var fit := ReplicaParts.fit(model, &"shotgun", {&"optic": &"redDot", &"laser": &"redLaser", &"light": &"weaponTorch"})
	assert_not_null(fit.optic)
	assert_eq(fit.nodes.size(), 3)
	assert_eq(fit.hidden.size(), 0, "nothing of the replica's own is hidden by an optic")
	ReplicaParts.unfit(fit)
	assert_eq(model.get_child_count(), before, "taken off again, no part left on the model")


func test_the_red_laser_fits_and_grips_barrels_and_silencers_do_not() -> void:
	var l := Loadout.new()
	assert_true(rules.equip(l, Loadout.Slot.PRIMARY, SHOTGUN))
	assert_true(rules.set_part(l, SHOTGUN, &"laser", "000005"))
	assert_false(rules.set_part(l, SHOTGUN, &"grip", "000006"))
	assert_false(rules.set_part(l, SHOTGUN, &"muzzle", "000018"))
	assert_false(rules.set_part(l, SHOTGUN, &"barrel", "000017"))
	assert_false(rules.set_part(l, SHOTGUN, &"magazine", "000012"))


func test_the_pump_is_home_in_its_fire_clip_before_it_can_fire_again_at_every_spring() -> void:
	var model := _scene(MODEL)
	var fire := (model.find_child("AnimationPlayer", true, false) as AnimationPlayer).get_animation(&"Fire")
	var track := -1
	for t in fire.get_track_count():
		if String(fire.track_get_path(t).get_concatenated_subnames()).begins_with("pump") \
				and fire.track_get_type(t) == Animation.TYPE_POSITION_3D:
			track = t
	assert_gt(track, -1, "a pump position track")
	# The first moment after the stroke's depth where the pump is back at its start.
	var rest: Vector3 = fire.position_track_interpolate(track, 0.0)
	var deepest := 0.0
	var home_at := -1.0
	var t := 0.0
	while t <= fire.length:
		var d := (fire.position_track_interpolate(track, t) - rest).length()
		if d > deepest:
			deepest = d
		elif deepest > 0.005 and d < 0.0005 and home_at < 0.0:
			home_at = t
		t += 0.002
	assert_gt(deepest, 0.01, "the pump travels")
	assert_gt(home_at, 0.0, "and comes home inside the clip")
	var vm := ViewModelConfig.new()
	for spring in SPRINGS:
		var r := _with_spring(spring)
		var speed := vm.bolt_cycle_end * r.fire_rate
		assert_lt(home_at / speed, 1.0 / r.fire_rate, "spring %s: home before the next pull" % spring)


func test_a_held_shotgun_plays_its_fire_clip_stretched_to_its_ready_time() -> void:
	var view := ReplicaView.new()
	add_child_autofree(view)
	var r := _with_spring(SPRINGS[2])
	view.setup(ViewModelConfig.new(), [r] as Array[ReplicaConfig], BoxWorld.new())
	var held: ReplicaView.Held = view._held[0]
	assert_almost_eq(held.fire_speed, ViewModelConfig.new().bolt_cycle_end * r.fire_rate, 1e-5)


func test_work_cant_leaves_the_sniper_as_it_was_and_gives_the_shotgun_a_quarter() -> void:
	var vm := ViewModelConfig.new()
	assert_false(vm.work_cant.has(&"sniper"), "unlisted: all of it")
	assert_almost_eq(float(vm.work_cant.get(&"sniper", 1.0)), 1.0, 1e-9)
	assert_almost_eq(float(vm.work_cant[&"shotgun"]), 0.25, 1e-9)
	var rolls := {}
	for key: StringName in [&"sniper", &"shotgun"]:
		var loadout: Array[ReplicaConfig] = [ReplicaStats.load_replica(key)]
		var hands := ReplicaView.new()
		add_child_autofree(hands)
		hands.setup(vm, loadout, BoxWorld.new())
		var c := Character.new(1, 0, Vector3.ZERO, 0.0, loadout)
		c.grounded = true
		for aim: float in [0.0, 1.0]:
			for i in 3:
				hands.update(c, 0.0, 0.0, EYE, Vector3.FORWARD, DT, aim)
			var held: ReplicaView.Held = hands._held[0]
			var still := held.root.rotation.z
			hands.on_shot()
			held.anim.seek(held.anim.get_animation(&"Fire").length * 0.5, true)
			hands.update(c, 0.0, 0.0, EYE, Vector3.FORWARD, DT, aim)
			rolls["%s_%s" % [key, aim]] = held.root.rotation.z - still
			held.anim.stop()
			hands._arms.follow(held.anim, 10.0)
			hands._arms.follow(held.anim, DT)
	assert_gt(rolls["sniper_0.0"], 0.0, "the sniper still cants at the hip")
	assert_gt(rolls["shotgun_0.0"], 0.0, "and the shotgun a little")
	assert_lt(rolls["shotgun_0.0"], rolls["sniper_0.0"] * 0.6, "the shotgun's far less")
	assert_almost_eq(float(rolls["shotgun_1.0"]), 0.0, 1e-3, "aimed: none")
	assert_almost_eq(float(rolls["sniper_1.0"]), 0.0, 1e-3)


func test_the_arms_have_the_shotguns_hold_fire_and_reload_clips() -> void:
	var arms := _scene(ARMS)
	var anim := arms.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for clip: StringName in [&"shotgun_Hold", &"shotgun_Fire", &"shotgun_Reload"]:
		assert_true(anim.has_animation(clip), clip)
	assert_not_null(arms.find_child("Hold_shotgun", true, false), "its hold mark")
	assert_almost_eq(anim.get_animation(&"shotgun_Fire").length, 1.0, 0.01, "in step with the replica's Fire clip")
	assert_almost_eq(anim.get_animation(&"shotgun_Reload").length, 1.8, 0.01, "and its Reload")


func _left_hand_pose(anim: AnimationPlayer, sk: Skeleton3D, clip: StringName, at: float) -> PackedVector3Array:
	anim.play(clip)
	anim.seek(at, true)
	sk.force_update_all_bone_transforms()
	var out := PackedVector3Array()
	for b in sk.get_bone_count():
		var n := sk.get_bone_name(b)
		if n.ends_with("_L") and (n.begins_with("Hand") or n.begins_with("Index") or n.begins_with("Thumb")):
			out.append(sk.get_bone_global_pose(b).origin)
	return out


func test_the_left_hand_comes_back_to_where_it_began_after_a_fire_and_a_reload() -> void:
	var arms := _scene(ARMS)
	var anim := arms.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var sk := _skeleton(arms)
	for clip: StringName in [&"shotgun_Fire", &"shotgun_Reload"]:
		var length := anim.get_animation(clip).length
		var start := _left_hand_pose(anim, sk, clip, 0.0)
		var end := _left_hand_pose(anim, sk, clip, length)
		assert_gt(start.size(), 3, "left hand bones found")
		for i in start.size():
			assert_lt(start[i].distance_to(end[i]), 0.003, "%s: left bone %d ends where it began" % [clip, i])


func test_the_inspect_clip_and_pose_leave_the_pump_and_the_hand_alone() -> void:
	var model := _scene(MODEL)
	var clip := (model.find_child("AnimationPlayer", true, false) as AnimationPlayer).get_animation(&"Inspect")
	for t in clip.get_track_count():
		if String(clip.track_get_path(t).get_concatenated_subnames()).begins_with("pump"):
			var first: Variant = clip.track_get_key_value(t, 0)
			for k in clip.track_get_key_count(t):
				assert_true(first.is_equal_approx(clip.track_get_key_value(t, k)) if first is Vector3
						else is_equal_approx(first, clip.track_get_key_value(t, k)), "pump key %d unmoved" % k)
	var pose := ViewModelConfig.new().inspect_poses.get(&"shotgun") as InspectPose
	assert_not_null(pose)
	assert_eq(pose.sound_at.size(), 0, "no clicks: nothing on it moves")
	assert_eq(pose.sound_cue.size(), 0)


func test_reduced_motion_draws_a_share_of_the_shotguns_cant() -> void:
	var vm := ViewModelConfig.new()
	var loadout: Array[ReplicaConfig] = [ReplicaStats.load_replica(&"shotgun")]
	var rolls: Array[float] = []
	for scale: float in [1.0, 0.0]:
		var hands := ReplicaView.new()
		add_child_autofree(hands)
		hands.setup(vm, loadout, BoxWorld.new())
		var m := MotionScale.new()
		m.reload_cant = scale
		hands.set_motion(m)
		var c := Character.new(1, 0, Vector3.ZERO, 0.0, loadout)
		c.grounded = true
		for i in 3:
			hands.update(c, 0.0, 0.0, EYE, Vector3.FORWARD, DT, 0.0)
		var held: ReplicaView.Held = hands._held[0]
		var still := held.root.rotation.z
		hands.on_shot()
		held.anim.seek(held.anim.get_animation(&"Fire").length * 0.5, true)
		hands.update(c, 0.0, 0.0, EYE, Vector3.FORWARD, DT, 0.0)
		rolls.append(held.root.rotation.z - still)
	assert_gt(rolls[0], rolls[1], "less cant with Reduced motion")
	assert_almost_eq(rolls[1], 0.0, 1e-3)


func test_the_pumps_cue_runs_as_long_as_its_stretched_fire_clip_at_the_default_spring() -> void:
	# The cue is cut over the clip as the game plays it (clip length / (bolt_cycle_end * 1.7 a second)).
	var stretched := 1.0 / (ViewModelConfig.new().bolt_cycle_end * 1.7)
	for i: int in [1, 2, 3]:
		var wav := load("%scycle_shotgun_%d.wav" % [SoundConfig.CUE_DIR, i]) as AudioStreamWAV
		assert_not_null(wav, "cue %d" % i)
		assert_almost_eq(wav.get_length(), stretched, 0.02, "cue %d matches the stretched pump stroke" % i)


func test_a_repeated_swap_to_the_shotgun_and_back_leaves_no_nodes_behind() -> void:
	var view := ReplicaView.new()
	add_child_autofree(view)
	var loadout: Array[ReplicaConfig] = [ReplicaStats.load_replica(&"shotgun"), ReplicaStats.load_replica(&"aeg")]
	view.setup(ViewModelConfig.new(), loadout, BoxWorld.new())
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, loadout)
	c.grounded = true
	view.update(c, 0.0, 0.0, EYE, Vector3.FORWARD, DT, 0.0)
	var before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	for i in 6:
		view.on_shot()
		view.update(c, 0.0, 0.0, EYE, Vector3.FORWARD, DT, 0.0)
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), before, "shots add no nodes")
