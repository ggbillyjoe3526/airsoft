extends GutTest
## FP1 (the owner: "the hands should not fade out of view. When the animation plays to ADS (except for pistols) the
## hands are simply out of view. At most a small tip of the players left hand thumb can be visible"): as the sight
## comes up your left arm is drawn in under the replica (ArmsTuck, ViewModelConfig.aim_tuck): the shoulder moves, the
## elbow hangs under the line from it to the wrist, and the hand holds where the clip put it, so the forearm lies
## behind the replica as the eye sees it. Back at the hip the clip's pose is whole again.

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
	for id: StringName in PISTOLS:
		assert_false(cfg.aim_tuck.has(id), "%s: its hands stay as they hold" % id)


func test_aimed_the_elbow_is_in_under_the_replica_and_the_hand_holds_where_it_held() -> void:
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
		assert_true(_same(_bone(hands, HAND), hand), "%s: the hand where the clip put it" % id)
		assert_true(_same(_bone(hands, TIP), tip), "%s: and its fingers" % id)
		# The replica's axes in the skeleton's: the shoulder moved as the config says, the elbow lower and further in.
		var to_bones: Basis = hands._arms._skeleton.global_basis.inverse() * hands._held[0].root.global_basis
		var shift: Vector3 = cfg.aim_tuck[id]
		assert_almost_eq(upper_in.origin, upper.origin + to_bones * shift, Vector3.ONE * EPS, "%s: the shoulder" % id)
		var moved := to_bones.inverse() * (fore_in.origin - fore.origin)
		assert_gt(moved.x, 0.03, "%s: the elbow in toward the replica" % id)
		assert_lt(moved.y, -0.02, "%s: and down" % id)
		assert_almost_eq(upper_in.origin.distance_to(fore_in.origin), upper.origin.distance_to(fore.origin), EPS,
				"%s: the upper arm as long as it was" % id)
		assert_almost_eq(fore_in.origin.distance_to(hand.origin), fore.origin.distance_to(hand.origin), EPS,
				"%s: the forearm too" % id)
		# The forearm still runs to the wrist.
		assert_gt(fore_in.basis.y.normalized().dot((hand.origin - fore_in.origin).normalized()), 0.999)


func test_it_comes_in_with_the_raise_and_goes_back_whole() -> void:
	var hands := _hands([&"aeg"])
	hands._show(0)
	var fore := _bone(hands, FORE)
	var upper := _bone(hands, UPPER)
	var last := 0.0
	for raise: float in [0.25, 0.5, 0.75, 1.0]:
		hands._arms.aim(raise)
		var moved := _bone(hands, FORE).origin.distance_to(fore.origin)
		assert_gt(moved, last, "raised %s: further in" % raise)
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
	hands._arms.aim(1.0)
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


func test_a_reach_too_far_draws_the_arm_out_straight_and_breaks_nothing() -> void:
	var hands := _hands([&"aeg"])
	hands._show(0)
	var skeleton := hands._arms._skeleton
	var hand := _bone(hands, HAND)
	var tuck := ArmsTuck.new(skeleton)
	assert_true(tuck.fits())
	tuck.draw_in(skeleton, Vector3(-2.0, 0.0, 0.0), Vector3.DOWN, 1.0)
	for bone: String in [UPPER, FORE, HAND]:
		var at := _bone(hands, bone)
		assert_true(at.origin.is_finite() and at.basis.x.is_finite() and at.basis.y.is_finite(), "%s is finite" % bone)
	assert_true(_bone(hands, HAND).basis.is_equal_approx(hand.basis), "the hand keeps its turn")
	# Nothing to turn about: down along the arm's own line.
	hands._show(0)
	var line := (hand.origin - _bone(hands, UPPER).origin).normalized()
	tuck.draw_in(skeleton, Vector3.ZERO, line, 1.0)
	assert_true(_bone(hands, FORE).origin.is_finite())


func test_a_skeleton_without_the_arm_is_left_alone() -> void:
	var bare := Skeleton3D.new()
	add_child_autofree(bare)
	bare.add_bone("Root")
	var tuck := ArmsTuck.new(bare)
	assert_false(tuck.fits())
	tuck.clear(bare)
	tuck.draw_in(bare, Vector3.RIGHT, Vector3.DOWN, 1.0)
	assert_eq(bare.get_bone_pose(0), Transform3D.IDENTITY)
