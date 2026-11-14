extends GutTest
## HA1 QA, attempt 5: the closing passes keep the row of the four left fingers on the Sniper and the SMG, and no
## fingertip floats off the handguard: each lies within FLOAT_LIMIT of the replica's nearest triangle edge (which
## overstates the gap to a face, on the safe side).

const FINGERS: Array[String] = ["Index", "Middle", "Ring", "Pinky"]
const TIP_BONE := {"Index": 0.0247, "Middle": 0.0263, "Ring": 0.0260, "Pinky": 0.0217}
## The most (m) a left fingertip may stand from the replica's surface (a glove's thickness and the finger's own).
const FLOAT_LIMIT := 0.030


func _hands(id: StringName) -> ReplicaView:
	var lo: Array[ReplicaConfig] = [ReplicaStats.load_replica(id)]
	var hands := ReplicaView.new()
	add_child_autofree(hands)
	hands.setup(ViewModelConfig.new(), lo, BoxWorld.new())
	hands._show(0)
	hands._arms.follow(hands._held[0].anim, 0.0)
	return hands


func _surface_gap(p: Vector3, tris: PackedVector3Array) -> float:
	var best := INF
	for i in range(0, tris.size(), 3):
		var q := Geometry3D.get_closest_point_to_segment(p, tris[i], tris[i + 1])
		best = minf(best, p.distance_to(q))
		q = Geometry3D.get_closest_point_to_segment(p, tris[i + 1], tris[i + 2])
		best = minf(best, p.distance_to(q))
		q = Geometry3D.get_closest_point_to_segment(p, tris[i + 2], tris[i])
		best = minf(best, p.distance_to(q))
	return best


func test_no_left_fingertip_floats_off_the_handguard_on_the_sniper_and_the_smg() -> void:
	var helper: GutTest = load("res://tests/unit/test_ha1_rifle_hold.gd").new()
	for id: StringName in [&"sniper", &"smg"]:
		var hands := _hands(id)
		var held: ReplicaView.Held = hands._held[0]
		var sk := hands._arms._skeleton
		sk.force_update_all_bone_transforms()
		var to_root := held.root.global_transform.affine_inverse() * sk.global_transform
		var tris: PackedVector3Array = []
		helper._tris(held.root.get_child(0), held.root, tris)
		for f in FINGERS:
			var last := sk.get_bone_global_pose(sk.find_bone(f + "3_L"))
			var tip := to_root * (last.origin + last.basis.y.normalized() * (TIP_BONE[f] as float))
			var gap := _surface_gap(tip, tris)
			gut.p("%s %s tip gap %.1f mm" % [id, f, gap * 1000.0])
			assert_lt(gap, FLOAT_LIMIT, "%s: the %s fingertip is %.1f mm off the replica" % [id, f, gap * 1000.0])
	helper.free()
