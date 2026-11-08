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
		# A one-handed replica's left arm is hidden on the hold: its reload starts and ends below the view instead.
		var hidden_left := cfg.one_hand.has(StringName(base.get_slice("_", 0)))
		for t in reload.get_track_count():
			var other := hold.find_track(reload.track_get_path(t), reload.track_get_type(t))
			if other < 0:
				continue
			var from: Variant = reload.track_get_key_value(t, 0)
			var to: Variant = reload.track_get_key_value(t, reload.track_get_key_count(t) - 1)
			var rest: Variant = hold.track_get_key_value(other, 0)
			if hidden_left and String(reload.track_get_path(t)).ends_with("_L"):
				assert_almost_eq(_dist(from, to), 0.0, BACK_SLACK, "%s ends where it began (%s)" % [base, reload.track_get_path(t)])
				continue
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


# ---- Run 2: the magazine carried in the left hand, and what cuts it short ----

const CARRY_AT := 0.4


## The magazine bone's pose in the replica's space, as the skeleton has it now.
func _mag(hands: ReplicaView, slot: int) -> Transform3D:
	var held: ReplicaView.Held = hands._held[slot]
	return held.carry.in_root(held.root)


## The magazine bone's pose with the replica's reload clip home (share 1), the pose a cut must leave it in.
func _mag_home(hands: ReplicaView, slot: int) -> Transform3D:
	var held: ReplicaView.Held = hands._held[slot]
	hands._seek(held, ReplicaView.RELOAD_CLIP, 1.0)
	return _mag(hands, slot)


func _into_carry(hands: ReplicaView, c: Character, share: float = CARRY_AT) -> void:
	c.armament.reload_left = c.armament.replica().reload_time * (1.0 - share)
	_step(hands, c)


func _same(a: Transform3D, b: Transform3D, msg: String) -> void:
	assert_almost_eq(a.origin, b.origin, Vector3.ONE * 1e-3, msg)


func test_every_cut_of_a_reload_in_the_carry_puts_the_magazine_back_in_the_well() -> void:
	for id in HELD:
		var hands := _hands([id])
		var c := _character(id)
		_step(hands, c)
		var home := _mag_home(hands, 0)
		_step(hands, c)
		# Sprint, a grenade, a switch, a round's end and a pause all end in the armament's reload_left = 0.
		_into_carry(hands, c)
		var carried := _mag(hands, 0)
		assert_gt(carried.origin.distance_to(home.origin), 0.01, "%s: the magazine is out of the well at %.1f" % [id, CARRY_AT])
		c.armament.reload_left = 0.0
		_step(hands, c)
		_same(_mag(hands, 0), home, "%s: back in the well after the cut" % id)
		assert_false(hands._arms.reloading(), "%s: hand back on the hold" % id)
		assert_eq(_anim(hands).assigned_animation, StringName(String(id) + "_Hold"))


func test_a_cut_at_the_edges_of_the_carry_leaves_nothing_in_the_hand() -> void:
	for id in HELD:
		var span: Vector2 = cfg.reload_carry[id]
		for share: float in [span.x, span.y, span.x + 1e-4, span.y - 1e-4, 0.0, 1.0]:
			var hands := _hands([id])
			var c := _character(id)
			_step(hands, c)
			var home := _mag_home(hands, 0)
			_into_carry(hands, c, share)
			c.armament.reload_left = 0.0
			_step(hands, c)
			_same(_mag(hands, 0), home, "%s cut at %.4f" % [id, share])


func test_a_reload_finishing_by_itself_leaves_the_magazine_home() -> void:
	var hands := _hands([&"aeg"])
	var c := _character(&"aeg")
	_step(hands, c)
	var home := _mag_home(hands, 0)
	c.armament.reload_left = c.armament.replica().reload_time
	for i in 400:
		c.armament.reload_left = maxf(c.armament.reload_left - DT, 0.0)
		_step(hands, c)
		if c.armament.reload_left <= 0.0:
			break
	assert_eq(c.armament.reload_left, 0.0)
	_same(_mag(hands, 0), home, "the magazine home")
	assert_false(hands._arms.reloading())


func test_switching_away_mid_carry_and_back_finds_the_magazine_home() -> void:
	var loadout: Array[ReplicaConfig] = [ReplicaStats.load_replica(&"aeg"), ReplicaStats.load_replica(&"pistol")]
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, loadout)
	var hands := ReplicaView.new()
	add_child_autofree(hands)
	hands.setup(cfg, loadout, BoxWorld.new())
	_step(hands, c)
	var home := _mag_home(hands, 0)
	_step(hands, c)
	_into_carry(hands, c)
	assert_gt(_mag(hands, 0).origin.distance_to(home.origin), 0.01, "in the hand")
	# The switch ends the reload (armament.reload_left = 0, a new active), then the first one is drawn again.
	c.armament.reload_left = 0.0
	c.armament.active = 1
	_step(hands, c)
	assert_false(hands._arms.reloading(), "the pistol is on its hold")
	assert_false(_mesh(hands, ArmsView.LEFT_ARM).visible, "the pistol's left arm hidden")
	c.armament.active = 0
	_step(hands, c)
	_same(_mag(hands, 0), home, "the rifle's magazine is in its well when it comes back")
	assert_true(_mesh(hands, ArmsView.LEFT_ARM).visible)


func test_the_magazine_part_goes_with_the_hand_and_home_again() -> void:
	var fits: Array = [[&"aeg", &"hiCap"], [&"aeg", &"lowCap"], [&"pistol", &"extended"]]
	for fit: Array in fits:
		var id: StringName = fit[0]
		var loadout: Array[ReplicaConfig] = [ReplicaStats.load_replica(id)]
		var hands := ReplicaView.new()
		add_child_autofree(hands)
		var parts: Array[Dictionary] = [{ReplicaParts.MAGAZINE_SLOT: fit[1]}]
		hands.setup(cfg, loadout, BoxWorld.new(), [], false, parts)
		var c := _character(id)
		_step(hands, c)
		var held: ReplicaView.Held = hands._held[0]
		var mark := held.root.find_child(ReplicaParts.MAGAZINE_ATTACHMENT, true, false) as Node3D
		assert_not_null(held.carry, "%s %s: the bone is carried" % [id, fit[1]])
		assert_gt(mark.get_child_count(), 0, "%s %s: the part rides the bone's attachment" % [id, fit[1]])
		var part := mark.get_child(0) as Node3D
		var home := _mag_home(hands, 0)
		_into_carry(hands, c)
		var hand := hands._arms.left_hand(held.root)
		var carried := held.carry.in_root(held.root)
		# The part is on the bone: its place in the hand does not drift while the bone moves.
		(mark.get_parent() as Skeleton3D).force_update_all_bone_transforms()
		(mark as BoneAttachment3D).on_skeleton_update()
		var at: Vector3 = held.root.global_transform.affine_inverse() * part.global_position
		assert_almost_eq(at.distance_to(carried.origin), mark.transform.origin.length() + part.position.length(), 0.5,
				"%s %s: part near the bone" % [id, fit[1]])
		assert_lt(hand.origin.distance_to(carried.origin), 0.5, "%s %s: bone near the hand" % [id, fit[1]])
		c.armament.reload_left = 0.0
		_step(hands, c)
		_same(held.carry.in_root(held.root), home, "%s %s: home after the cut" % [id, fit[1]])


func test_a_reload_with_the_carry_follows_while_aimed_and_comes_home() -> void:
	var hands := _hands([&"aeg"], &"vertical")
	var c := _character(&"aeg")
	_step(hands, c, 1.0)
	var home := _mag_home(hands, 0)
	_step(hands, c, 1.0)
	_into_carry(hands, c)
	var held: ReplicaView.Held = hands._held[0]
	var hand := hands._arms.left_hand(held.root)
	var in_hand := hand.affine_inverse() * _mag(hands, 0).origin
	c.armament.reload_left = c.armament.replica().reload_time * 0.45
	hands.update(c, 0.0, 0.0, EYE, Vector3.FORWARD, DT, 1.0)
	hand = hands._arms.left_hand(held.root)
	assert_almost_eq(hand.affine_inverse() * _mag(hands, 0).origin, in_hand, Vector3.ONE * 0.01, "aimed: still in the hand")
	c.armament.reload_left = 0.0
	hands.update(c, 0.0, 0.0, EYE, Vector3.FORWARD, DT, 1.0)
	_same(_mag(hands, 0), home, "aimed: home after the reload")


func test_two_reloads_in_a_row_carry_the_same_way() -> void:
	var hands := _hands([&"aeg"])
	var c := _character(&"aeg")
	_step(hands, c)
	var home := _mag_home(hands, 0)
	_step(hands, c)
	var first := Transform3D.IDENTITY
	for round in 2:
		_into_carry(hands, c)
		var held: ReplicaView.Held = hands._held[0]
		var rel := hands._arms.left_hand(held.root).affine_inverse() * _mag(hands, 0).origin
		if round == 0:
			first = Transform3D(Basis.IDENTITY, rel)
		else:
			assert_almost_eq(rel, first.origin, Vector3.ONE * 1e-3, "the second reload takes it the same place")
		c.armament.reload_left = 0.0
		_step(hands, c)
		_same(_mag(hands, 0), home, "reload %d ends home" % round)


func test_skin_only_switched_mid_carry_keeps_the_carry_and_the_left_arm() -> void:
	var hands := _hands([&"pistol"])
	var c := _character(&"pistol")
	_step(hands, c)
	var home := _mag_home(hands, 0)
	_step(hands, c)
	_into_carry(hands, c)
	var before := _mag(hands, 0)
	hands.skin_arms = true
	_into_carry(hands, c)
	_same(_mag(hands, 0), before, "the same place in the hand")
	assert_true(_mesh(hands, ArmsView.LEFT_ARM).visible, "the left arm shows through the reload")
	assert_false(_mesh(hands, "GloveKit_L").visible, "no glove kit in skin only")
	c.armament.reload_left = 0.0
	_step(hands, c)
	_same(_mag(hands, 0), home, "home after")
	assert_false(_mesh(hands, ArmsView.LEFT_ARM).visible, "one-handed again")
	assert_false(_mesh(hands, "Nails_L").visible, "and no left nails either")
	hands.skin_arms = false
	assert_false(_mesh(hands, ArmsView.LEFT_ARM).visible, "gloves back: the left arm stays hidden")


func test_a_red_laser_fitted_does_not_break_the_reload_or_the_carry() -> void:
	var loadout: Array[ReplicaConfig] = [ReplicaStats.load_replica(&"aeg")]
	var hands := ReplicaView.new()
	add_child_autofree(hands)
	var parts: Array[Dictionary] = [{&"laser": &"redLaser", ReplicaParts.GRIP_SLOT: &"angled"}]
	hands.setup(cfg, loadout, BoxWorld.new(), [], false, parts)
	var c := _character(&"aeg")
	_step(hands, c)
	var home := _mag_home(hands, 0)
	_step(hands, c)
	_into_carry(hands, c)
	assert_true(hands._arms.reloading())
	assert_gt(_mag(hands, 0).origin.distance_to(home.origin), 0.01, "carried")
	c.armament.reload_left = 0.0
	_step(hands, c)
	_same(_mag(hands, 0), home, "home")
	assert_eq(_anim(hands).assigned_animation, &"aeg_grip_angled_Hold")


func test_both_dev_switches_are_saved_and_read_back_together() -> void:
	var d := DevSettings.new()
	d.lasers = true
	d.skin_arms = true
	var again := DevSettings.new()
	again.from_dict(d.to_dict())
	assert_true(again.lasers, "lasers kept")
	assert_true(again.skin_arms, "skin only kept")
	var only_skin := DevSettings.new()
	only_skin.from_dict({"skin_arms": true})
	assert_true(only_skin.skin_arms)
	assert_false(only_skin.lasers, "a save with one switch leaves the other off")
	assert_true(again.cheats().any(), "lasers is still a cheat")
	var skin := DevSettings.new()
	skin.skin_arms = true
	assert_false(skin.cheats().any(), "skin only alone is not")


func test_an_inspect_after_a_reload_starts_with_the_magazine_home() -> void:
	var hands := _hands([&"aeg"])
	var c := _character(&"aeg")
	_step(hands, c)
	var home := _mag_home(hands, 0)
	_step(hands, c)
	_into_carry(hands, c)
	c.armament.reload_left = 0.0
	_step(hands, c)
	hands.inspect()
	_step(hands, c)
	var held: ReplicaView.Held = hands._held[0]
	var anim := held.anim
	assert_true(hands.inspecting(), "the inspect runs")
	assert_eq(anim.assigned_animation, ReplicaView.INSPECT_CLIP, "the replica plays its inspect clip")
	assert_false(hands._arms.reloading())
	anim.seek(0.0, true)
	_same(held.carry.in_root(held.root), home, "the magazine home at the inspect's start")
	# A reload cutting the inspect short, then the carry again: the magazine still goes home after.
	_into_carry(hands, c)
	assert_true(hands._arms.reloading(), "a reload ends the inspect and runs")
	c.armament.reload_left = 0.0
	_step(hands, c)
	_same(held.carry.in_root(held.root), home, "home after the second reload")
