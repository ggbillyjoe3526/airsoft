extends GutTest
## HA2 (the owner, 2026-11-15): the pistols sit low on the right at about the rifles' share of the screen and angle,
## turned a little in at the hip; and turned over in an inspect, your shoulders stay where your body has them, so an
## arm's cut-off end never turns into view, while both hands keep their hold on the replica.

const DT := 1.0 / 60.0
const PISTOLS: Array[StringName] = [&"pistol", &"cyber"]
const HELD: Array[StringName] = [&"aeg", &"sniper", &"smg", &"shotgun", &"pistol", &"cyber"]
const SIDES: Array[String] = ["_L", "_R"]
## The pistols' hip before HA1 (34 cm from the eye) and their reload move there.
const OLD_HIP := Vector3(0.05, -0.07, -0.34)
const OLD_MOVE := Vector3(0.1, 0.06, 0.0)
## The left shoulder held still moves less than this (m: within reach of the hand on the handguard it doesn't move;
## the Sniper Rifle's turn takes the hand a few mm past the arm's reach); a hand on its hold, less than this.
const STILL := 0.01
const HOLD := 0.001
## The widest screen drawn (21:9), and how far outside the view's edge an arm's cut-off end stays (1: on the edge).
const WIDEST := 21.0 / 9.0
const OUT_OF_VIEW := 1.05

var cfg: ViewModelConfig = null


func before_each() -> void:
	cfg = ViewModelConfig.new()


func _view(id: StringName) -> Array:
	var loadout: Array[ReplicaConfig] = [ReplicaStats.load_replica(id)]
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, loadout)
	var view := ReplicaView.new()
	add_child_autofree(view)
	view.setup(cfg, loadout, BoxWorld.new())
	return [view, c]


func _frames(view: ReplicaView, c: Character, n: int, aim: float = 0.0) -> void:
	for i in n:
		view.update(c, 0.0, 0.0, Vector3(0.0, 1.6, 0.0), Vector3.FORWARD, DT, aim)


## Bone `bone`'s place in the view's own space (the camera's, without its life).
func _in_view(view: ReplicaView, bone: String) -> Vector3:
	var skeleton := view._arms._skeleton
	skeleton.force_update_all_bone_transforms()
	var at := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin
	return view.global_transform.affine_inverse() * at


## Bone `bone`'s place in the replica's own space.
func _in_replica(view: ReplicaView, bone: String) -> Vector3:
	var skeleton := view._arms._skeleton
	skeleton.force_update_all_bone_transforms()
	var at := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin
	return view._held[0].root.global_transform.affine_inverse() * at


func test_the_pistols_sit_low_on_the_right_further_off_and_turned_a_little_in() -> void:
	for id: StringName in PISTOLS:
		var hip: Vector3 = cfg.hip[id]
		assert_gt(hip.x, 0.05, "%s: on the right" % id)
		assert_lt(hip.y, -0.05, "%s: low" % id)
		assert_almost_eq(-hip.z, 0.35, 1e-4, "%s: 35 cm from the eye (was 25: less of the screen)" % id)
		var turn: Vector3 = cfg.hip_turn[id]
		assert_between(turn.y, 0.05, 0.3, "%s: the muzzle turned a little left, its side to the eye" % id)
		var k := hip.z / OLD_HIP.z
		assert_lt((cfg.reload_move(id) - OLD_MOVE * k).length(), 2e-3, "%s: the reload scaled with its distance" % id)
		# The reload peak stays in front of the eye and inside a 75 degree half-field.
		var peak := hip + cfg.reload_move(id)
		assert_lt(peak.z, -0.1)
		assert_lt(maxf(absf(peak.x), absf(peak.y)) / -peak.z, tan(deg_to_rad(37.5)))
	assert_false(cfg.hip_turn.has(&"aeg"), "the rifles' hip is as it was")


func test_the_hip_turn_holds_at_the_hip_and_is_gone_aimed() -> void:
	for id: StringName in PISTOLS:
		var vc := _view(id)
		var view: ReplicaView = vc[0]
		var c: Character = vc[1]
		_frames(view, c, 30)
		var root := view._held[0].root
		assert_almost_eq(root.rotation, cfg.hip_turn[id], Vector3.ONE * 1e-3, "%s: turned at the hip" % id)
		_frames(view, c, 30, 1.0)
		assert_almost_eq(root.rotation, Vector3.ZERO, Vector3.ONE * 1e-3, "%s: square to the eye aimed" % id)


func test_through_an_inspect_the_arms_cut_off_ends_stay_out_of_view_and_the_hands_keep_hold() -> void:
	# The widest view the game draws: the settings' widest field of view on a 21:9 screen.
	var view_cfg := ViewConfig.new()
	view_cfg.horizontal_fov_16x9 = Settings.FOV_MAX
	var up := tan(deg_to_rad(view_cfg.vertical_fov()) * 0.5)
	var across := up * WIDEST
	for id: StringName in HELD:
		var vc := _view(id)
		var view: ReplicaView = vc[0]
		var c: Character = vc[1]
		_frames(view, c, 30)
		var shoulders: Array[Vector3] = []
		var hands: Array[Vector3] = []
		for side: String in SIDES:
			shoulders.append(_in_view(view, ArmsTuck.UPPER + side))
			hands.append(_in_replica(view, ArmsTuck.HAND + side))
		view.inspect()
		_frames(view, c, 1)
		var frames := ceili(view._inspect_length / DT)
		var nearest := INF
		var worst_hand := 0.0
		var left_moved := 0.0
		for f in frames:
			_frames(view, c, 1)
			for i in SIDES.size():
				var end := _in_view(view, ArmsTuck.UPPER + SIDES[i])
				# How far inside the view's edge the arm's end is (under 1: on screen), if in front of the eye at all.
				if end.z < 0.0:
					nearest = minf(nearest, maxf(absf(end.x) / -end.z / across, absf(end.y) / -end.z / up))
				worst_hand = maxf(worst_hand, _in_replica(view, ArmsTuck.HAND + SIDES[i]).distance_to(hands[i]))
			left_moved = maxf(left_moved, _in_view(view, ArmsTuck.UPPER + SIDES[0]).distance_to(shoulders[0]))
		assert_gt(nearest, OUT_OF_VIEW, "%s: neither arm's cut-off end turns into view" % id)
		assert_lt(worst_hand, HOLD, "%s: both hands keep their hold" % id)
		assert_lt(left_moved, STILL, "%s: the left shoulder stays where your body has it" % id)
		_frames(view, c, 10)
		assert_false(view.inspecting(), "%s: over" % id)
		assert_false(view._arms._tucked, "%s: the arms back on their clip alone" % id)
