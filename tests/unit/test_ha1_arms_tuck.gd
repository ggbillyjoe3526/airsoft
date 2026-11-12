extends GutTest
## HA1 (the owner: "the hands should not fade out of view. When the animation plays to ADS (except for pistols) the
## hands are simply out of view. At most a small tip of the players left hand thumb can be visible"): as the sight
## comes up your left arm is drawn in under the replica (ArmsTuck, ViewModelConfig.aim_tuck): the shoulder moves, the
## elbow hangs under the line from it to the wrist, and the hand, holding as the clip posed it until the replica is in
## front of it, slides back along the replica behind the receiver (aim_slide, aim_slide_span), so neither forearm nor
## hand shows past the replica as the eye sees it. Back at the hip the clip's pose is whole again.

const DT := 1.0 / 60.0
const EPS := 1e-4
const RIFLES := [&"aeg", &"sniper", &"smg"]
const PISTOLS := [&"pistol", &"cyber"]
const UPPER := "UpperArm_L"
const FORE := "Forearm_L"
const HAND := "Hand_L"
const TIP := "Index3_L"

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


## Bone `bone_name` of the arms `hands` wears, in the skeleton's space, as posed now.
func _bone(hands: ReplicaView, bone_name: String) -> Transform3D:
	var skeleton := hands._arms._skeleton
	skeleton.force_update_all_bone_transforms()
	return skeleton.get_bone_global_pose(skeleton.find_bone(bone_name))


func _same(a: Transform3D, b: Transform3D, eps: float = EPS) -> bool:
	return a.origin.distance_to(b.origin) < eps and a.basis.x.distance_to(b.basis.x) < eps \
			and a.basis.y.distance_to(b.basis.y) < eps and a.basis.z.distance_to(b.basis.z) < eps


func test_every_rifle_has_its_arm_drawn_in_and_no_pistol() -> void:
	for id: StringName in RIFLES:
		assert_true(cfg.aim_tuck.has(id), "%s: listed" % id)
		assert_true(cfg.aim_slide.has(id), "%s: its hand slides" % id)
		assert_gt(cfg.aim_slide[id].z, 0.0, "%s: back, toward the receiver" % id)
	for id: StringName in PISTOLS:
		assert_false(cfg.aim_tuck.has(id), "%s: its hands stay as they hold" % id)
		assert_false(cfg.aim_slide.has(id), "%s" % id)
	assert_between(cfg.aim_slide_span.x, 0.0, cfg.aim_slide_span.y - 0.1, "the slide starts before it ends")
	assert_lte(cfg.aim_slide_span.y, 1.0, "and is over by the time the sight is up")


func test_aimed_the_elbow_is_in_under_the_replica_and_the_hand_has_slid_back_as_it_held() -> void:
	for id: StringName in RIFLES:
		var hands := _hands([id])
		hands._show(0)
		var upper := _bone(hands, UPPER)
		var fore := _bone(hands, FORE)
		var hand := _bone(hands, HAND)
		var tip := _bone(hands, TIP)
		hands._arms.aim(1.0)
		var upper_in := _bone(hands, UPPER)
		var fore_in := _bone(hands, FORE)
		var hand_in := _bone(hands, HAND)
		# The replica's axes in the skeleton's: shoulder and hand moved as the config says, the elbow lower and
		# further in.
		var to_bones: Basis = hands._arms._skeleton.global_basis.inverse() * hands._held[0].root.global_basis
		var slide: Vector3 = to_bones * cfg.aim_slide[id]
		assert_almost_eq(hand_in.origin, hand.origin + slide, Vector3.ONE * EPS, "%s: the hand slid back" % id)
		assert_true(hand_in.basis.is_equal_approx(hand.basis), "%s: turned as the clip turned it" % id)
		assert_almost_eq(_bone(hands, TIP).origin, tip.origin + slide, Vector3.ONE * EPS,
				"%s: its fingers closed as they were" % id)
		var shift: Vector3 = cfg.aim_tuck[id]
		assert_almost_eq(upper_in.origin, upper.origin + to_bones * shift, Vector3.ONE * EPS, "%s: the shoulder" % id)
		var moved := to_bones.inverse() * (fore_in.origin - fore.origin)
		assert_gt(moved.x, 0.03, "%s: the elbow in toward the replica" % id)
		assert_lt(moved.y, -0.02, "%s: and down" % id)
		assert_almost_eq(upper_in.origin.distance_to(fore_in.origin), upper.origin.distance_to(fore.origin), EPS,
				"%s: the upper arm as long as it was" % id)
		assert_almost_eq(fore_in.origin.distance_to(hand_in.origin), fore.origin.distance_to(hand.origin), EPS,
				"%s: the forearm too" % id)
		# The forearm still runs to the wrist.
		assert_gt(fore_in.basis.y.normalized().dot((hand_in.origin - fore_in.origin).normalized()), 0.999)


func test_the_hand_holds_the_handguard_until_the_replica_is_in_front_of_it() -> void:
	for id: StringName in RIFLES:
		var hands := _hands([id])
		hands._show(0)
		var hand := _bone(hands, HAND)
		var fore := _bone(hands, FORE)
		hands._arms.aim(cfg.aim_slide_span.x)
		assert_true(_same(_bone(hands, HAND), hand), "%s: where the clip put it, the sight part way up" % id)
		assert_false(_same(_bone(hands, FORE), fore), "%s: the elbow already coming in" % id)
		var last := 0.0
		for share: float in [0.25, 0.5, 0.75, 1.0]:
			hands._arms.aim(lerpf(cfg.aim_slide_span.x, cfg.aim_slide_span.y, share))
			var slid := _bone(hands, HAND).origin.distance_to(hand.origin)
			assert_gt(slid, last, "%s: further back, %s of the way" % [id, share])
			last = slid
		assert_almost_eq(last, cfg.aim_slide[id].length(), EPS, "%s: all of it by the span's end" % id)


func test_it_comes_in_with_the_raise_and_goes_back_whole() -> void:
	var hands := _hands([&"aeg"])
	hands._show(0)
	var fore := _bone(hands, FORE)
	var upper := _bone(hands, UPPER)
	var last := 0.0
	for raise: float in [0.25, 0.5, 0.75, 1.0]:
		hands._arms.aim(raise)
		var moved := _bone(hands, UPPER).origin.distance_to(upper.origin)
		assert_gt(moved, last, "raised %s: the shoulder further in" % raise)
		assert_false(_same(_bone(hands, FORE), fore), "raised %s: and the elbow with it" % raise)
		last = moved
	# Held aimed, frame after frame, it stays where it is: each frame starts from the clip's pose.
	var held := _bone(hands, FORE)
	for i in 30:
		hands._arms.aim(1.0)
	assert_true(_same(_bone(hands, FORE), held), "no drift while aimed")
	hands._arms.aim(0.0)
	assert_true(_same(_bone(hands, FORE), fore), "the sight down: the clip's elbow")
	assert_true(_same(_bone(hands, UPPER), upper), "and its shoulder")
	hands._arms.aim(0.0)
	assert_true(_same(_bone(hands, FORE), fore))


func test_a_pistols_arms_stay_as_the_clip_has_them() -> void:
	for id: StringName in PISTOLS:
		var hands := _hands([id])
		hands._show(0)
		var fore := _bone(hands, FORE)
		hands._arms.aim(1.0)
		assert_true(_same(_bone(hands, FORE), fore), "%s" % id)


func test_through_a_reload_the_hand_follows_the_clip_drawn_in_or_not() -> void:
	var hands := _hands([&"aeg"])
	hands._show(0)
	var held: ReplicaView.Held = hands._held[0]
	hands._arms.follow(held.anim, DT, 0.5)
	var hand := _bone(hands, HAND)
	var fore := _bone(hands, FORE)
	# A reload lowers the sight (Aiming.can_aim): as it comes down the hand is the clip's again.
	hands._arms.aim(cfg.aim_slide_span.x)
	assert_true(_same(_bone(hands, HAND), hand), "the hand at the magazine, as the clip has it")
	assert_false(_same(_bone(hands, FORE), fore), "the elbow in")
	# The next frame's share of the reload poses afresh.
	hands._arms.follow(held.anim, DT, 0.6)
	hands._arms.aim(0.0)
	hands._arms.follow(held.anim, DT, 0.5)
	hands._arms.aim(0.0)
	assert_true(_same(_bone(hands, FORE), fore), "nothing of it left with the sight down")


func test_switching_replica_starts_from_its_own_clip() -> void:
	var hands := _hands([&"aeg", &"pistol"])
	hands._show(0)
	hands._arms.aim(1.0)
	hands._show(1)
	var clean := _hands([&"pistol"])
	clean._show(0)
	hands._arms.aim(1.0)
	for bone: String in [UPPER, FORE, HAND]:
		assert_true(_same(_bone(hands, bone), _bone(clean, bone)), "%s as a pistol drawn fresh has it" % bone)


func test_a_new_hold_starts_from_its_clip_before_the_sight_is_read_again() -> void:
	var hands := _hands([&"aeg", &"pistol"])
	hands._show(0)
	hands._arms.aim(1.0)
	hands._show(1)
	var clean := _hands([&"pistol"])
	clean._show(0)
	for bone: String in [UPPER, FORE, HAND]:
		assert_true(_same(_bone(hands, bone), _bone(clean, bone)), "%s, with no aim() since the switch" % bone)


func test_a_reach_too_far_draws_the_arm_out_straight_and_breaks_nothing() -> void:
	var hands := _hands([&"aeg"])
	hands._show(0)
	var skeleton := hands._arms._skeleton
	var hand := _bone(hands, HAND)
	var tuck := ArmsTuck.new(skeleton)
	assert_true(tuck.fits())
	var reach := _bone(hands, UPPER).origin.distance_to(_bone(hands, FORE).origin) \
			+ _bone(hands, FORE).origin.distance_to(hand.origin)
	tuck.draw_in(skeleton, Vector3(-2.0, 0.0, 0.0), Vector3(2.0, 0.0, 0.0), Vector3.DOWN, 1.0)
	for bone: String in [UPPER, FORE, HAND]:
		var at := _bone(hands, bone)
		assert_true(at.origin.is_finite() and at.basis.x.is_finite() and at.basis.y.is_finite(), "%s is finite" % bone)
	assert_true(_bone(hands, HAND).basis.is_equal_approx(hand.basis), "the hand keeps its turn")
	# The wrist ends the forearm: the hand goes as far as the arm reaches, no further, and never off its end.
	assert_almost_eq(_bone(hands, HAND).origin.distance_to(_bone(hands, UPPER).origin), reach * ArmsTuck.REACH_MOST,
			1e-3)
	# Nothing to turn about: down along the arm's own line.
	hands._show(0)
	var line := (hand.origin - _bone(hands, UPPER).origin).normalized()
	tuck.draw_in(skeleton, Vector3.ZERO, Vector3.ZERO, line, 1.0)
	assert_true(_bone(hands, FORE).origin.is_finite())


func test_a_skeleton_without_the_arm_is_left_alone() -> void:
	var bare := Skeleton3D.new()
	add_child_autofree(bare)
	bare.add_bone("Root")
	var tuck := ArmsTuck.new(bare)
	assert_false(tuck.fits())
	tuck.clear(bare)
	tuck.draw_in(bare, Vector3.RIGHT, Vector3.BACK, Vector3.DOWN, 1.0)
	assert_eq(bare.get_bone_pose(0), Transform3D.IDENTITY)
