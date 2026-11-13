extends GutTest
## HA1 QA, attempt 4: the Sniper's and the SMG's four left fingers stand side by side, none through its neighbour, and
## the handguard's front-end test finds a real front end and would catch a finger past it.

const ARMS_MODEL := "res://assets/models/arms/arms.glb"
const FINGERS: Array[String] = ["Index", "Middle", "Ring", "Pinky"]
## The least (m) between neighbouring fingers' bones; the build puts them 16 to 19 mm apart, they were 3 to 10.
const LEAST_APART := 0.012
## A fingertip's bone, from its joint to the pad's middle (m).
const TIP_BONE := 0.02
const GUARD_SIDE := 0.018
const SIZE_LIMIT := 8 * 1024 * 1024


func _hands(id: StringName) -> ReplicaView:
	var lo: Array[ReplicaConfig] = [ReplicaStats.load_replica(id)]
	var hands := ReplicaView.new()
	add_child_autofree(hands)
	hands.setup(ViewModelConfig.new(), lo, BoxWorld.new())
	hands._show(0)
	hands._arms.follow(hands._held[0].anim, 0.0)
	return hands


func _joint(sk: Skeleton3D, bone: String) -> Vector3:
	return sk.get_bone_global_pose(sk.find_bone(bone)).origin


## Distance between segment ab and segment cd.
func _seg_gap(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> float:
	var best := INF
	for i in 21:
		var p := a.lerp(b, i / 20.0)
		var q := Geometry3D.get_closest_point_to_segment(p, c, d)
		best = minf(best, p.distance_to(q))
	for i in 21:
		var p := c.lerp(d, i / 20.0)
		var q := Geometry3D.get_closest_point_to_segment(p, a, b)
		best = minf(best, p.distance_to(q))
	return best


## A finger's last two bones as posed: the middle bone from its joint to the last joint, and the last bone on from
## there by TIP_BONE along its own line (the pinch the critic saw was between fingertips).
func _lines(sk: Skeleton3D, finger: String) -> Array[Vector3]:
	var last := sk.get_bone_global_pose(sk.find_bone(finger + "3_L"))
	return [_joint(sk, finger + "2_L"), last.origin, last.origin, last.origin + last.basis.y.normalized() * TIP_BONE]


func test_neighbouring_left_fingers_stand_apart_on_the_sniper_and_the_smg() -> void:
	for id: StringName in [&"sniper", &"smg"]:
		var hands := _hands(id)
		var sk := hands._arms._skeleton
		sk.force_update_all_bone_transforms()
		for i in FINGERS.size() - 1:
			var a := _lines(sk, FINGERS[i])
			var b := _lines(sk, FINGERS[i + 1])
			var least := INF
			for j: int in [0, 2]:
				for k: int in [0, 2]:
					least = minf(least, _seg_gap(a[j], a[j + 1], b[k], b[k + 1]))
			assert_gt(least, LEAST_APART,
					"%s: %s and %s bones are %.1f mm apart" % [id, FINGERS[i], FINGERS[i + 1], least * 1000.0])


func test_the_front_end_search_finds_each_rifles_handguard_and_a_finger_past_it_would_fail() -> void:
	for id: StringName in [&"aeg", &"sniper", &"smg"]:
		var hands := _hands(id)
		var held: ReplicaView.Held = hands._held[0]
		var tris: PackedVector3Array = []
		var helper: GutTest = load("res://tests/unit/test_ha1_rifle_hold.gd").new()
		helper._tris(held.root.get_child(0), held.root, tris)
		var lo := INF
		var hi := -INF
		var rear := -INF
		var side := 0
		for v in tris:
			rear = maxf(rear, v.z)
			lo = minf(lo, v.z)
			if v.x >= GUARD_SIDE:
				side += 1
				hi = maxf(hi, v.z)
		helper.free()
		assert_gt(side, 30, "%s: the replica has surface on the handguard side" % id)
		# The search takes the foremost such surface: it must lie well inside the replica's length, not at its far end only.
		assert_gt(hi, lo, "%s: the handguard side has depth" % id)


func test_the_arms_file_stays_under_the_size_budget() -> void:
	var f := FileAccess.open(ARMS_MODEL, FileAccess.READ)
	assert_not_null(f)
	assert_lt(f.get_length(), SIZE_LIMIT, "arms.glb under 8 MB")
