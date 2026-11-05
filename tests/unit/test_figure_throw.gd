extends GutTest
## GT1: a figure throwing a bomb (game/play/figures/figure_throw.gd, figure_pose.gd's read_throw, figure_hands.gd's
## bomb, figure_view.gd's set_bombs). The pose's keys and weights; the throw read from the character's hand (the windup,
## the recovery, a bomb held in hand, none once out of play); on both kinds, the bomb's model in the right hand from the
## pin to the release and gone after it, the right hand cocked up by the head and out ahead high at the release, the
## left hand out ahead while the right cocks, and the arms back to the holster's after the throw. Read as the skeleton
## finishes updating (test_figure_hands.gd).

const EYE := Vector3(0.0, 1.6, 3.0)
const FRAME := 1.0 / 60.0

var config: FigureConfig = null
var models: FigureModels = null
var hits: HitConfig = null
var grenades: GrenadeConfig = null
var meshes: Array[Mesh] = []
## The bones' places in the figure's frame as last drawn, by figure: each hand, the head, the right shoulder.
var _drawn: Dictionary[FigureView, Dictionary] = {}


func before_all() -> void:
	config = FigureConfig.new()
	models = FigureModels.new(config)
	models.load_kinds()
	hits = HitConfig.new()
	grenades = GrenadeConfig.new()
	for kind in 3:
		var box := BoxMesh.new()
		box.size = Vector3(0.06, 0.12 + 0.01 * kind, 0.06)
		meshes.append(box)


func _character() -> Character:
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	c.grounded = true
	return c


func _view(kind: int, c: Character) -> FigureView:
	var v := FigureView.new()
	add_child_autofree(v)
	v.setup(c, Color.RED, hits, null)
	v.set_body(models, kind, config.lod_high)
	v.set_bombs(meshes, grenades)
	var sk := v.body().skeleton
	sk.skeleton_updated.connect(func() -> void:
		var drawn: Dictionary = {}
		for bone: String in ["Hand_R", "Hand_L", "Head", "UpperArm_R", "UpperArm_L", "Grip_R"]:
			drawn[bone] = v.global_transform.affine_inverse() \
					* (sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bone)).origin)
		var head := sk.get_bone_global_pose(sk.find_bone("Head"))
		drawn["HeadMiddle"] = v.global_transform.affine_inverse() \
				* (sk.global_transform * (head * Vector3(0.0, config.head_top * 0.5, 0.0)))
		_drawn[v] = drawn)
	return v


func _pose(v: FigureView, c: Character, frames: int = 40) -> void:
	for i in frames:
		v.update(c, 1.0)
		v.animate(c, 1.0, FRAME, EYE)
	await wait_process_frames(1)


## `c`'s throw `share` of the way through (0..1 the windup, 1..2 the recovery), its replica put down as a throw does.
func _throwing(c: Character, share: float) -> void:
	var hand := c.grenades
	hand.stop()
	c.armament.put_down()
	hand.throwing = Grenade.Kind.SMOKE
	hand.released = share >= 1.0
	hand.windup_left = grenades.windup * (1.0 - minf(share, 1.0))
	hand.recover_left = grenades.recover * (1.0 - clampf(share - 1.0, 0.0, 1.0)) if hand.released \
			else grenades.recover


func test_the_pose_is_drawn_in_and_out_over_the_throw() -> void:
	assert_eq(FigureThrow.weight(-1.0, false, config), 0.0, "no throw: none")
	assert_eq(FigureThrow.weight(0.0, false, config), 0.0, "at the pin: none yet")
	assert_eq(FigureThrow.weight(config.throw_in, false, config), 1.0, "all of it by throw_in")
	assert_eq(FigureThrow.weight(1.0, false, config), 1.0, "at the release")
	assert_eq(FigureThrow.weight(2.0 - config.throw_out, false, config), 1.0, "until the recovery's last throw_out")
	assert_eq(FigureThrow.weight(2.0, false, config), 0.0, "back to the holster's arms at the redraw")
	assert_eq(FigureThrow.weight(-1.0, true, config), 1.0, "a bomb held in hand: all of it")


func test_the_keys_run_ready_cocked_release_follow_through() -> void:
	assert_eq(FigureThrow.right_key(0.0, false, config), config.throw_ready)
	assert_almost_eq(FigureThrow.right_key(config.throw_cock, false, config), config.throw_cocked,
			Vector3.ONE * 0.0001)
	assert_almost_eq(FigureThrow.right_key(1.0, false, config), config.throw_release, Vector3.ONE * 0.0001)
	assert_almost_eq(FigureThrow.right_key(2.0, false, config), config.throw_follow, Vector3.ONE * 0.0001)
	assert_eq(FigureThrow.right_key(0.7, true, config), config.throw_ready, "held in hand: at the chest")
	# Out to the side on the way back, never through the chest.
	var lifted := FigureThrow.right_key(config.throw_cock * 0.5, false, config)
	assert_gt(lifted.x, config.throw_ready.x + 0.1, "the hand swings out to the right on its way back")
	assert_eq(FigureThrow.left_key(0.0, config), config.throw_pin, "the left hand at the pin first")
	assert_almost_eq(FigureThrow.left_key(config.throw_cock, config), config.throw_point, Vector3.ONE * 0.0001)
	assert_almost_eq(FigureThrow.right_key(config.throw_cock + (1.0 - config.throw_cock) * sqrt(config.throw_over_at),
			false, config), config.throw_over, Vector3.ONE * 0.0001, "over beside the head on the way")
	assert_eq(FigureThrow.weight(0.0, false, config, true), 1.0, "from the hand: the arm already up")
	assert_almost_eq(FigureThrow.left_key(1.0, config), config.throw_tuck, Vector3.ONE * 0.0001)
	assert_lt(FigureThrow.twist(config.throw_cock, false, config), 0.0, "turned away as the arm cocks")
	assert_almost_eq(FigureThrow.twist(1.0, false, config), 0.0, 0.0001, "square at the release")
	assert_gt(FigureThrow.twist(2.0, false, config), 0.0, "across on the follow-through")


func test_the_throw_is_read_from_the_hand() -> void:
	var pose := FigurePose.new(config)
	var hand := Grenades.Hand.new()
	pose.read_throw(hand, true)
	assert_eq(pose.bomb, Grenade.Kind.NONE, "no grenades config: nothing")
	pose.grenades = grenades
	pose.read_throw(hand, true)
	assert_eq(pose.throw_share, -1.0)
	assert_eq(pose.bomb, Grenade.Kind.NONE)
	hand.throwing = Grenade.Kind.FLASH
	hand.windup_left = grenades.windup * 0.25
	pose.read_throw(hand, true)
	assert_almost_eq(pose.throw_share, 0.75, 0.0001, "three quarters through the windup")
	assert_eq(pose.bomb, Grenade.Kind.FLASH, "in the hand until the release")
	hand.released = true
	hand.recover_left = grenades.recover * 0.5
	pose.read_throw(hand, true)
	assert_almost_eq(pose.throw_share, 1.5, 0.0001, "half through the recovery")
	assert_eq(pose.bomb, Grenade.Kind.NONE, "gone from the hand once released")
	pose.read_throw(hand, false)
	assert_eq(pose.throw_share, -1.0, "out of play: no throw drawn")
	hand.stop()
	hand.readied = Grenade.Kind.SMOKE
	pose.read_throw(hand, true)
	assert_true(pose.bomb_held, "held in hand (MC1)")
	assert_eq(pose.bomb, Grenade.Kind.SMOKE)


func test_both_kinds_throw_with_the_bomb_in_the_right_hand() -> void:
	for kind: int in [FigureMix.HUMAN, FigureMix.ROBOT]:
		var c := _character()
		c.armament.put_down()
		var v := _view(kind, c)
		var hands := v.body().hands
		await _pose(v, c)
		var hanging: Dictionary = _drawn[v]
		assert_false(hands.bomb().visible, "kind %d: no bomb before the throw" % kind)
		# Cocked: the bomb in the right hand, up by the head; the left hand out ahead.
		_throwing(c, config.throw_cock)
		await _pose(v, c, 1)
		var cocked: Dictionary = _drawn[v]
		assert_true(hands.bomb().visible, "kind %d: the bomb in the hand" % kind)
		assert_eq(hands.bomb().mesh, meshes[Grenade.Kind.SMOKE], "kind %d: the smoke's model" % kind)
		var grip: Vector3 = cocked["Grip_R"]
		var in_figure := v.global_transform.affine_inverse() * hands.bomb().global_transform.origin
		assert_lt(in_figure.distance_to(grip), 0.02, "kind %d: centred on the grip" % kind)
		var head: Vector3 = cocked["Head"]
		var right: Vector3 = cocked["Hand_R"]
		var left: Vector3 = cocked["Hand_L"]
		assert_gt(right.y, (cocked["UpperArm_R"] as Vector3).y, "kind %d: the right hand above the shoulder" % kind)
		assert_lt(absf(right.y - head.y), 0.35, "kind %d: cocked by the head" % kind)
		assert_lt(left.z, (hanging["Hand_L"] as Vector3).z - 0.2, "kind %d: the left hand out ahead" % kind)
		# The release: the right hand high and out ahead; the bomb gone from it.
		_throwing(c, 1.0)
		await _pose(v, c, 1)
		var released: Dictionary = _drawn[v]
		assert_false(hands.bomb().visible, "kind %d: the bomb gone at the release" % kind)
		assert_lt((released["Hand_R"] as Vector3).z, (released["UpperArm_R"] as Vector3).z - 0.3,
				"kind %d: the right hand out ahead at the release" % kind)
		assert_gt((released["Hand_R"] as Vector3).y, (released["UpperArm_R"] as Vector3).y,
				"kind %d: and above the shoulder" % kind)
		# After the recovery: no throw, the arms back as they hung.
		c.grenades.stop()
		await _pose(v, c)
		assert_lt((_drawn[v]["Hand_R"] as Vector3).distance_to(hanging["Hand_R"]), 0.01,
				"kind %d: the right hand back where it hung" % kind)
		assert_false(hands.bomb().visible)


func test_a_bomb_held_in_hand_sits_at_the_chest() -> void:
	var c := _character()
	c.armament.put_down()
	c.grenades.readied = Grenade.Kind.FLASH
	var v := _view(FigureMix.HUMAN, c)
	await _pose(v, c)
	var hands := v.body().hands
	assert_true(hands.bomb().visible)
	assert_eq(hands.bomb().mesh, meshes[Grenade.Kind.FLASH])
	var right: Vector3 = _drawn[v]["Hand_R"]
	var shoulder: Vector3 = _drawn[v]["UpperArm_R"]
	assert_lt(right.z, shoulder.z - 0.15, "ahead of the body")
	assert_lt(right.y, shoulder.y, "below the shoulder")


func test_out_of_play_or_fading_no_bomb_shows() -> void:
	var c := _character()
	_throwing(c, 0.5)
	var v := _view(FigureMix.HUMAN, c)
	await _pose(v, c)
	assert_true(v.body().hands.bomb().visible)
	c.status = Character.Status.LEAVING
	c.status_time = hits.vanish_time * 0.5
	await _pose(v, c, 1)
	assert_false(v.body().hands.bomb().visible, "fading out: put away")


func test_without_bombs_given_the_hand_draws_none() -> void:
	var c := _character()
	_throwing(c, 0.5)
	var v := FigureView.new()
	add_child_autofree(v)
	v.setup(c, Color.RED, hits, null)
	v.set_body(models, FigureMix.HUMAN, config.lod_high)
	await _pose(v, c)
	assert_null(v.body().hands.bomb(), "no bomb node made")


func test_the_hand_and_bomb_pass_beside_the_head_never_across_the_face() -> void:
	for kind: int in [FigureMix.HUMAN, FigureMix.ROBOT]:
		var c := _character()
		c.armament.put_down()
		var v := _view(kind, c)
		await _pose(v, c)
		var share := config.throw_cock
		while share <= 1.0:
			_throwing(c, share)
			await _pose(v, c, 1)
			var middle: Vector3 = _drawn[v]["HeadMiddle"]
			for bone: String in ["Hand_R", "Grip_R"]:
				assert_gt((_drawn[v][bone] as Vector3).distance_to(middle), 0.15,
						"kind %d, share %.2f: %s clear of the head" % [kind, share, bone])
			share += 0.05


func test_a_throw_from_a_bomb_held_in_hand_keeps_the_arm_up() -> void:
	var c := _character()
	c.armament.put_down()
	c.grenades.readied = Grenade.Kind.SMOKE
	var v := _view(FigureMix.HUMAN, c)
	await _pose(v, c)
	var held: Vector3 = _drawn[v]["Hand_R"]
	# The trigger pull: the throw begins at share 0 from the hand.
	c.grenades.readied = Grenade.Kind.NONE
	c.grenades.throwing = Grenade.Kind.SMOKE
	c.grenades.windup_left = grenades.windup
	c.grenades.recover_left = grenades.recover
	await _pose(v, c, 1)
	assert_lt((_drawn[v]["Hand_R"] as Vector3).distance_to(held), 0.02, "the arm doesn't drop to hanging first")
	assert_true(v.body().hands.bomb().visible)
