class_name FigureThrow
extends RefCounted
## A bomb thrown (GT1), drawn after FigureReady over the holster's hanging arms: the upper chain turned away about the
## spine as the right arm cocks, and back across as it follows through (FigureConfig.throw_twist); then each arm reaches
## its key (FigureConfig.throw_*: the wrist from its shoulder, in the figure's frame turned with the chest) by two-bone
## IK, its elbow bent towards its pole, and its hand turned with its forearm, so the bomb on Grip_R
## (FigureHands) follows. `share` runs 0..1 over the windup and 1..2 over the recovery; a bomb held in hand (MC1) keeps
## the right hand at throw_ready. The arms take the pose over throw_in of the windup and give it back over throw_out of
## the recovery. In the skeleton's frame (the file's, facing +Z; the figure's right is -X). Presentation only;
## allocation-free.

## Below this (m) a length counts as none; under this weight nothing is moved.
const EPSILON := 0.0001
## The right elbow's pole swings ahead over this first share of the arm coming over.
const POLE_SWING := 0.5

var _config: FigureConfig = null
var _spine: int = -1
var _chest: int = -1
## The right arm's upper arm, forearm and hand, then the left's (FigureConfig.throw_arm_bones).
var _arms: PackedInt32Array = PackedInt32Array()


## Finds `config`'s bones in `skeleton`; with any missing, nothing is ever moved.
func _init(skeleton: Skeleton3D, config: FigureConfig) -> void:
	_config = config
	_spine = skeleton.find_bone(config.lean_bone)
	_chest = skeleton.find_bone(config.chest_bone)
	for bone_name in config.throw_arm_bones:
		var index := skeleton.find_bone(bone_name)
		if index < 0:
			push_warning("FigureThrow: no bone %s" % bone_name)
			_arms.clear()
			return
		_arms.append(index)
	if _arms.size() != 6:
		push_warning("FigureThrow: throw_arm_bones is not three bones for each arm")
		_arms.clear()


## Poses `skeleton` `share` of the way through a throw (below 0: none), or holding a bomb in hand when `held`;
## `from_hand`: the throw began from a bomb held in hand.
func pose(skeleton: Skeleton3D, share: float, held: bool, from_hand: bool = false) -> void:
	var w := weight(share, held, _config, from_hand)
	if w <= EPSILON or _arms.is_empty() or _spine < 0 or _chest < 0:
		return
	var turn := twist(share, held, _config) * w
	if absf(turn) > EPSILON:
		var spine := skeleton.get_bone_global_pose(_spine)
		skeleton.set_bone_global_pose(_spine, Transform3D(Basis(Vector3.UP, turn) * spine.basis, spine.origin))
	var chest := (skeleton.get_bone_global_pose(_chest).basis
			* skeleton.get_bone_global_rest(_chest).basis.inverse()).orthonormalized()
	var right := right_key(share, held, _config)
	_reach(skeleton, 0, chest * in_skeleton(right), chest * in_skeleton(right_pole(share, held, _config)), w, chest)
	if not held:
		# The left arm comes in over throw_in even from a bomb held in hand (it hung while the right held the bomb).
		_reach(skeleton, 3, chest * in_skeleton(left_key(share, _config)),
				chest * in_skeleton(_config.throw_left_pole), weight(share, false, _config), chest)


## How much of the throw's pose is drawn `share` of the way through it: in over throw_in of the windup, out over the
## last throw_out of the recovery; all of it holding a bomb in hand (`held`), and through the windup of a throw from
## the hand (`from_hand`: the arm is already up); none with no throw (`share` < 0).
static func weight(share: float, held: bool, config: FigureConfig, from_hand: bool = false) -> float:
	if held or (from_hand and share >= 0.0 and share <= 1.0):
		return 1.0
	if share < 0.0:
		return 0.0
	if share <= 1.0:
		return smoothstep(0.0, maxf(config.throw_in, EPSILON), share)
	return 1.0 - smoothstep(1.0 - config.throw_out, 1.0, share - 1.0)


## The right wrist's key from its shoulder (the figure's frame) `share` of the way through the throw: ready, out to the
## lift and up to cocked by throw_cock of the windup, then accelerating over to the release, then down to the
## follow-through.
static func right_key(share: float, held: bool, config: FigureConfig) -> Vector3:
	var cock := clampf(config.throw_cock, EPSILON, 1.0 - EPSILON)
	if held or share <= 0.0:
		return config.throw_ready
	if share <= cock:
		var t := smoothstep(0.0, 1.0, share / cock)
		var lift := clampf(config.throw_lift_at, EPSILON, 1.0 - EPSILON)
		if t <= lift:
			return config.throw_ready.lerp(config.throw_lift, t / lift)
		return config.throw_lift.lerp(config.throw_cocked, (t - lift) / (1.0 - lift))
	if share <= 1.0:
		var t := (share - cock) / (1.0 - cock)
		t *= t
		var over := clampf(config.throw_over_at, EPSILON, 1.0 - EPSILON)
		if t <= over:
			return config.throw_cocked.lerp(config.throw_over, smoothstep(0.0, 1.0, t / over))
		return config.throw_over.lerp(config.throw_release, (t - over) / (1.0 - over))
	return config.throw_release.lerp(config.throw_follow, smoothstep(0.0, 1.0, minf(share - 1.0, 1.0)))


## Where the right elbow bends towards (the figure's frame): out and down while the arm cocks, swinging to ahead and
## down as it comes over (the elbow leads the throw, so the upper arm never stands out sideways over the shoulder).
static func right_pole(share: float, held: bool, config: FigureConfig) -> Vector3:
	var cock := clampf(config.throw_cock, EPSILON, 1.0 - EPSILON)
	if held or share <= cock:
		return config.throw_right_pole
	var t := clampf((share - cock) / (1.0 - cock), 0.0, 1.0)
	return config.throw_right_pole.lerp(config.throw_over_pole, smoothstep(0.0, 1.0, minf(t / POLE_SWING, 1.0)))


## The left wrist's key: at the right hand pulling the pin, then pointing out while the right arm cocks, tucked in as
## it comes over.
static func left_key(share: float, config: FigureConfig) -> Vector3:
	var cock := clampf(config.throw_cock, EPSILON, 1.0 - EPSILON)
	var pin := clampf(config.throw_pin_until, 0.0, cock - EPSILON)
	if share <= pin:
		return config.throw_pin
	if share <= cock:
		return config.throw_pin.lerp(config.throw_point, smoothstep(pin, cock, share))
	return config.throw_point.lerp(config.throw_tuck, smoothstep(cock, 1.0, minf(share, 1.0)))


## The upper chain's turn about the spine (rad, about the skeleton's up; negative turns the right shoulder back):
## away as the arm cocks, back through square at the release, across on the follow-through.
static func twist(share: float, held: bool, config: FigureConfig) -> float:
	var cock := clampf(config.throw_cock, EPSILON, 1.0 - EPSILON)
	if held or share <= 0.0:
		return 0.0
	if share <= cock:
		return -config.throw_twist * smoothstep(0.0, 1.0, share / cock)
	if share <= 1.0:
		return lerpf(-config.throw_twist, 0.0, (share - cock) / (1.0 - cock))
	return config.throw_twist * smoothstep(0.0, 1.0, minf(share - 1.0, 1.0))


## A way in the figure's frame (x right, y up, z ahead) in the skeleton's (facing +Z, the figure's right -X).
static func in_skeleton(v: Vector3) -> Vector3:
	return Vector3(-v.x, v.y, v.z)


## Arm `first` (0 right, 3 left) reaching `w` of the way from its pose to its wrist at `key` from its shoulder by
## two-bone IK, its elbow towards `pole` as far. The upper arm turns the shortest way from its rest pose carried by the
## chest (`chest`), not from the clip's hanging pose: from hanging, the shortest way up over the shoulder rolls the arm
## about itself and drags the side of the chest with it. The forearm then points the wrist at its place, and the hand
## turns as the forearm turned.
func _reach(skeleton: Skeleton3D, first: int, key: Vector3, pole: Vector3, w: float, chest: Basis) -> void:
	var upper := _arms[first]
	var fore := _arms[first + 1]
	var hand := _arms[first + 2]
	var upper_pose := skeleton.get_bone_global_pose(upper)
	var shoulder := upper_pose.origin
	var was_fore := skeleton.get_bone_global_pose(fore)
	var was_hand := skeleton.get_bone_global_pose(hand)
	var target := was_hand.origin.lerp(shoulder + key, w)
	var a := shoulder.distance_to(was_fore.origin)
	var b := was_fore.origin.distance_to(was_hand.origin)
	var to := target - shoulder
	if to.length() < EPSILON or a < EPSILON or b < EPSILON:
		return
	var way := to.normalized()
	var d := clampf(to.length(), absf(a - b) + EPSILON, a + b - EPSILON)
	var side := was_fore.origin - shoulder
	side -= way * way.dot(side)
	var bend := pole - way * way.dot(pole)
	if side.length() > EPSILON and bend.length() > EPSILON:
		side = side.normalized().lerp(bend.normalized(), w)
	elif bend.length() > EPSILON:
		side = bend
	side = side.normalized() if side.length() > EPSILON else Vector3.DOWN
	var along := (a * a + d * d - b * b) / (2.0 * d)
	var elbow := shoulder + way * along + side * sqrt(maxf(a * a - along * along, 0.0))
	var aim := (elbow - shoulder).normalized()
	var from_pose := Basis(Quaternion((was_fore.origin - shoulder).normalized(), aim)) * upper_pose.basis
	var rest := skeleton.get_bone_global_rest(upper)
	var rest_way := chest * (skeleton.get_bone_global_rest(fore).origin - rest.origin).normalized()
	var from_rest := Basis(Quaternion(rest_way, aim)) * chest * rest.basis
	# Both point the upper arm at the elbow; between them only its roll about itself differs.
	skeleton.set_bone_global_pose(upper, Transform3D(from_pose.slerp(from_rest, w), shoulder))
	var fore_pose := skeleton.get_bone_global_pose(fore)
	var wrist := skeleton.get_bone_global_pose(hand).origin
	var forearm := Basis(Quaternion((wrist - fore_pose.origin).normalized(), (target - fore_pose.origin).normalized()))
	skeleton.set_bone_global_pose(fore, Transform3D(forearm * fore_pose.basis, fore_pose.origin))
	var turn := (skeleton.get_bone_global_pose(fore).basis * was_fore.basis.inverse()).orthonormalized()
	skeleton.set_bone_global_pose(hand, Transform3D(turn * was_hand.basis, target))
