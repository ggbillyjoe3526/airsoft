extends GutTest
## QA for SH2 (the Pump Shotgun's own model, hold and pump): the model's replica contract, its parts on their mounts,
## the pump home before the next shot at every spring, the cant its arms draw, the arms' clips and the pump's cue.

const SHOTGUN := "000027"
## Where the arms model holds the AEG, Sniper and Compact SMG as their holds are solved (arms.py RIFLE_HIP).
const RIFLES_SOLVED_AT := Vector3(0.12, -0.19, -0.26)
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


# --- attempt 2: the hold's place, the stock out of the aimed view, the toe loop, budgets ---

const NEAR := 0.05
const ARM_CUFF := 0.07
const ARM_R := 0.02
const HOLD_SLACK := 0.015
const ARM_SAMPLES := 24
const UPPER_FROM := 0.4
## The sling loop (tools/blender/replicas/shotgun.py TOE_LOOP): centre z (m, behind the origin), lowest point y.
const TOE_Z := 0.2616
const TOE_Y_LOW := -0.0626
const TRIS_HANDS := 40000
const TRIS_FIGURE := 3000


func _hands(id: StringName) -> ReplicaView:
	var hands := ReplicaView.new()
	add_child_autofree(hands)
	hands.setup(ViewModelConfig.new(), [ReplicaStats.load_replica(id)] as Array[ReplicaConfig], BoxWorld.new())
	return hands


func _character(id: StringName) -> Character:
	return Character.new(0, 0, Vector3.ZERO, 0.0, [ReplicaStats.load_replica(id)] as Array[ReplicaConfig])


func _step(hands: ReplicaView, c: Character, aim: float, frames: int = 90) -> void:
	for i in frames:
		hands.update(c, 0.0, 0.0, EYE, Vector3.FORWARD, DT, aim)


## The body mesh's vertices in the replica's own space.
func _body_vertices(model: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	var inv := model.global_transform.affine_inverse()
	for n: Node in model.find_children("Body", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var to_model := inv * mi.global_transform
		for s in mi.mesh.get_surface_count():
			var verts := mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array
			for v in verts:
				out.append(to_model * v)
	return out


func _tris(root: Node, skip: String) -> int:
	var total := 0
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or mi.name.begins_with(skip) or (skip != "" and mi.get_parent().name == skip):
			continue
		total += mi.mesh.get_faces().size() / 3
	return total


func test_the_arms_hold_mark_is_where_the_view_holds_the_shotgun() -> void:
	var cfg := ViewModelConfig.new()
	var arms := _scene(ARMS)
	var mark := arms.find_child("Hold_shotgun", true, false) as Node3D
	var hip: Vector3 = cfg.hip[&"shotgun"]
	assert_almost_eq(mark.global_position, hip, Vector3.ONE * 1e-4, "the hold is built for the hip place")
	# The other long replicas' holds stay where they were solved (arms.py RIFLE_HIP): since HA1 the game draws them
	# nearer and lower (ViewModelConfig.hip) and the arms ride the replica from this mark (ArmsView).
	for id: StringName in [&"aeg", &"sniper", &"smg"]:
		var other := arms.find_child("Hold_%s" % id, true, false) as Node3D
		assert_almost_eq(other.global_position, RIFLES_SOLVED_AT, Vector3.ONE * 1e-4, "%s" % id)


func test_aimed_with_no_optic_no_stock_is_in_front_of_the_near_plane_on_screen() -> void:
	var hands := _hands(&"shotgun")
	var c := _character(&"shotgun")
	_step(hands, c, 1.0)
	var held: ReplicaView.Held = hands._held[0]
	var rear := held.rear_sight
	var model := held.root.get_child(0) as Node3D
	var to_eye := hands.global_transform.affine_inverse() * model.global_transform
	var tan_h := tan(deg_to_rad(ViewConfig.new().horizontal_fov_16x9) * 0.5)
	var shown := 0
	var rail_back := INF
	for v in _body_vertices(model):
		var p := to_eye * v
		if v.z > rear.z + 0.05:
			var depth := -p.z
			if depth >= NEAR and absf(p.x / (depth * tan_h)) < 1.0 and absf(p.y / (depth * tan_h * 9.0 / 16.0)) < 1.0:
				shown += 1
		elif v.y > rear.y - 0.012:
			rail_back = minf(rail_back, -p.z)
	assert_eq(shown, 0, "no vertex of the stock (behind the receiver) is on screen aimed")
	assert_gt(rail_back, NEAR, "the top rail is not clipped by the near plane")


func test_the_top_rail_stays_past_the_near_plane_through_the_raise_and_the_kick() -> void:
	var hands := _hands(&"shotgun")
	var c := _character(&"shotgun")
	var held: ReplicaView.Held = hands._held[0]
	for aim: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
		_step(hands, c, aim)
		for shots in 6:
			hands.on_shot()
			_step(hands, c, aim, 1)
			var to_eye := hands.global_transform.affine_inverse() * (held.root.get_child(0) as Node3D).global_transform
			var rear_eye: Vector3 = to_eye * held.rear_sight
			assert_gt(-rear_eye.z, NEAR, "aim %.2f, shot %d: the rear sight past the near plane" % [aim, shots])


func test_the_model_has_its_toe_loop_hung_below_the_stock_and_stays_in_budget() -> void:
	var model := _scene(MODEL)
	var low := INF
	for v in _body_vertices(model):
		if absf(v.x) < 0.006 and absf(v.z - TOE_Z) < 0.006:
			low = minf(low, v.y)
	assert_almost_eq(low, TOE_Y_LOW, 0.003, "the sling loop's wire reaches its lowest point at the toe")
	assert_lt(_tris(model, "Figure"), TRIS_HANDS, "triangles in the hands")
	var figure := model.find_child(ReplicaParts.FIGURE_NODE, true, false) as Node3D
	var fig := 0
	for n: Node in figure.find_children("*", "MeshInstance3D", true, false) + [figure]:
		var mi := n as MeshInstance3D
		if mi != null and mi.mesh != null:
			fig += mi.mesh.get_faces().size() / 3
	assert_lt(fig, TRIS_FIGURE, "triangles on a figure")


## The left forearm's shown reach (m from the wrist) on a 16:9 screen as the hands are posed now (test_bp8_arms).
func _arm_shown(hands: ReplicaView) -> float:
	var skeleton := hands._arms._skeleton
	skeleton.force_update_all_bone_transforms()
	var joints: Array[Vector3] = []
	for bone: String in ["UpperArm_L", "Forearm_L", "Hand_L"]:
		joints.append(skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin)
	var tan_h := tan(deg_to_rad(ViewConfig.new().horizontal_fov_16x9) * 0.5)
	var shown := 0.0
	for part in 2:
		var a := joints[part].lerp(joints[part + 1], UPPER_FROM if part == 0 else 0.0)
		var b := joints[part + 1]
		for k in ARM_SAMPLES + 1:
			var q := a.lerp(b, k / float(ARM_SAMPLES))
			var from_wrist := q.distance_to(joints[1]) + joints[1].distance_to(joints[2]) if part == 0 \
					else q.distance_to(joints[2])
			var p := hands.global_transform.affine_inverse() * q
			var depth := -p.z
			if depth < NEAR:
				continue
			var edge := ARM_R / (depth * tan_h)
			if absf(p.x / (depth * tan_h)) < 1.0 + edge and absf(p.y / (depth * tan_h * 9.0 / 16.0)) < 1.0 + edge * 16.0 / 9.0:
				shown = maxf(shown, from_wrist)
	return shown


func test_at_the_hip_the_shotguns_left_forearm_shows_no_more_than_the_rifles_holds() -> void:
	var worst := 0.0
	for id: StringName in [&"aeg", &"smg", &"sniper"]:
		var hands := _hands(id)
		_step(hands, _character(id), 0.0, 30)
		worst = maxf(worst, _arm_shown(hands))
	var hands := _hands(&"shotgun")
	_step(hands, _character(&"shotgun"), 0.0, 30)
	assert_lt(_arm_shown(hands), maxf(ARM_CUFF, worst) + HOLD_SLACK, "left forearm shown at the hip")


func test_a_reload_shows_no_shotgun_forearm_past_the_cuff() -> void:
	var hands := _hands(&"shotgun")
	var c := _character(&"shotgun")
	_step(hands, c, 0.0, 30)
	var hold := _arm_shown(hands)
	var time := c.armament.replica().reload_time
	for k in 21:
		c.armament.reload_left = maxf(time * (1.0 - k / 20.0), 1e-4)
		hands.update(c, 0.0, 0.0, EYE, Vector3.FORWARD, DT, 0.0)
		assert_lt(_arm_shown(hands), maxf(ARM_CUFF, hold + HOLD_SLACK), "reload at %d/20" % k)


func test_pump_hold_view_leaves_no_nodes_after_the_view_is_freed() -> void:
	var before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	for i in 3:
		var hands := ReplicaView.new()
		add_child(hands)
		hands.setup(ViewModelConfig.new(), [ReplicaStats.load_replica(&"shotgun")] as Array[ReplicaConfig], BoxWorld.new())
		_step(hands, _character(&"shotgun"), 1.0, 3)
		hands.free()
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), before, "no nodes left")


func _hold_bend(anim: Animation, bone: String) -> float:
	for t in anim.get_track_count():
		if String(anim.track_get_path(t)).ends_with(":" + bone):
			return rad_to_deg((anim.track_get_key_value(t, 0) as Quaternion).get_angle())
	return -1.0


func test_the_shotguns_trigger_finger_is_curled_to_the_trigger_like_the_rifles_not_stuck_out() -> void:
	var anim := (_scene(ARMS).find_child("AnimationPlayer", true, false) as AnimationPlayer)
	var shotgun := anim.get_animation(&"shotgun_Hold")
	var rifle := anim.get_animation(&"aeg_Hold")
	var total := 0.0
	var rifle_total := 0.0
	for bone: String in ["Index1_R", "Index2_R", "Index3_R"]:
		assert_gt(_hold_bend(shotgun, bone), 8.0, bone + " bent")
		total += _hold_bend(shotgun, bone)
		rifle_total += _hold_bend(rifle, bone)
	assert_gt(total, 90.0, "the finger wraps the trigger")
	assert_almost_eq(total, rifle_total, 25.0, "within a rifle trigger finger's reach, not swung away")
