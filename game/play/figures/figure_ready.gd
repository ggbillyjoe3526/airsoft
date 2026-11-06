class_name FigureReady
extends RefCounted
## The high ready at a wall (FB5), drawn after FigureBend's aim: the replica, with both hands on it, turned muzzle up
## about the grip (FigureConfig.raise_angle), canted with its magazine out to the figure's right (raise_cant) and drawn
## in to the chest (raise_back, raise_down), each by `amount`; each arm then reaches its hand's new place by two-bone
## IK (the upper arm and the forearm turned in the elbow's own plane) and the hand turns with the replica, so the
## replica on Grip_R and a reload's magazine on Hand_L follow. In the skeleton's frame (the file's, facing +Z; the
## figure's right is -X). Presentation only; allocation-free.

## Below this (m) a length counts as none.
const EPSILON := 0.0001
## The right arm's bones: the first three of raise_arm_bones (FigureConfig lists the right arm first).
const RIGHT_ARM := 3

## Each arm's upper arm, forearm and hand, one arm after another (FigureConfig.raise_arm_bones); the bone turned about.
var _arms: PackedInt32Array = PackedInt32Array()
var _grip: int = -1
var _shoulder: int = -1
## The chest: the shoulder pocket turns with it (a lean, the aim's pitch, the upper body's steadying).
var _chest: int = -1
var _config: FigureConfig = null


## Finds `config`'s bones in `skeleton`; with any missing (or not three an arm), nothing is ever moved.
func _init(skeleton: Skeleton3D, config: FigureConfig) -> void:
	_config = config
	_grip = skeleton.find_bone(config.grip_bone)
	_shoulder = skeleton.find_bone(config.shoulder_bone)
	_chest = skeleton.find_bone(config.chest_bone)
	for bone_name in config.raise_arm_bones:
		var index := skeleton.find_bone(bone_name)
		if index < 0:
			push_warning("FigureReady: no bone %s" % bone_name)
			_arms.clear()
			return
		_arms.append(index)
	if _arms.size() % 3 != 0:
		push_warning("FigureReady: raise_arm_bones is not three bones an arm")
		_arms.clear()
		return
	for k in range(0, _arms.size(), 3):
		if not chained(skeleton, _arms[k], _arms[k + 1], _arms[k + 2]):
			push_warning("FigureReady: %s's arm bones don't hang from each other" % skeleton.get_bone_name(_arms[k]))
			_arms.clear()
			return


## Whether `fore` hangs from `upper` and `hand` from `fore` (what reach sets each bone over).
static func chained(skeleton: Skeleton3D, upper: int, fore: int, hand: int) -> bool:
	return skeleton.get_bone_parent(fore) == upper and skeleton.get_bone_parent(hand) == fore


## Draws the replica `amount` (0..1) of the way to the shoulder: `butt_on_grip` (its butt, in the grip bone's frame)
## onto the shoulder pocket (`pocket`), the replica's aim kept, both hands moved with it.
func shoulder(skeleton: Skeleton3D, amount: float, butt_on_grip: Vector3) -> void:
	if amount <= 0.0 or _grip < 0 or _shoulder < 0 or _arms.is_empty():
		return
	var butt := skeleton.get_bone_global_pose(_grip) * butt_on_grip
	_move_hands(skeleton, Transform3D(Basis.IDENTITY, (pocket(skeleton) - butt) * amount))


## The shoulder pocket in `skeleton`'s frame: FigureConfig.shoulder_pocket from the shoulder's joint, turned as the
## chest is from its rest (so it stays on the shoulder through a lean, the aim's pitch and the upper body's steadying).
func pocket(skeleton: Skeleton3D) -> Vector3:
	var offset := _config.shoulder_pocket
	if _chest >= 0:
		offset = skeleton.get_bone_global_pose(_chest).basis * (skeleton.get_bone_global_rest(_chest).basis.inverse()
				* offset)
	return skeleton.get_bone_global_pose(_shoulder).origin + offset


## Moves the right hand (`both`: and the left) by `fit` (the grip bone's frame) along the replica in it, to its grip
## (TP3); the replica's place in the hand (FigureHands) is shifted the other way, so it stays where it was.
func fit_grip(skeleton: Skeleton3D, fit: Vector3, both: bool) -> void:
	if fit == Vector3.ZERO or _grip < 0 or _arms.is_empty():
		return
	var move := skeleton.get_bone_global_pose(_grip).basis * fit
	_move_hands(skeleton, Transform3D(Basis.IDENTITY, move), _arms.size() if both else RIGHT_ARM)


## Brings `skeleton`'s arms and replica `amount` (0..1) of the way to the high ready from the pose they have.
func hold(skeleton: Skeleton3D, amount: float) -> void:
	if amount <= 0.0 or _grip < 0 or _arms.is_empty():
		return
	var grip := skeleton.get_bone_global_pose(_grip).origin
	var turn := Basis(Vector3.RIGHT, -_config.raise_angle * amount) \
			* Basis(Vector3.BACK, -_config.raise_cant * amount)
	var shift := Vector3(0.0, -_config.raise_down, -_config.raise_back) * amount
	_move_hands(skeleton, Transform3D(turn, grip - turn * grip + shift))


## Moves the hands of the first `bones` of raise_arm_bones (all of them: both hands) by `move` (the skeleton's frame),
## each arm reaching for its hand's new place.
func _move_hands(skeleton: Skeleton3D, move: Transform3D, bones: int = -1) -> void:
	# One arm at a time: each reaches from its own shoulder, so the other's hand stays where it was posed.
	var last := _arms.size() if bones < 0 else mini(bones, _arms.size())
	var k := 0
	while k + 2 < last:
		var hand := skeleton.get_bone_global_pose(_arms[k + 2])
		reach(skeleton, _arms[k], _arms[k + 1], _arms[k + 2], move * hand)
		k += 3


## Turns `upper` and `fore` so the `hand` bone's joint lands on `target`'s origin, the elbow bending in the plane it
## bends in now (down, when the arm is straight), then gives the hand `target` (a hand out of reach stretches to it).
## The arm's frames are read once and each bone set over its parent's new frame, so the skeleton works its frames out
## once an arm rather than after each bone (the three bones hang from each other: FigureConfig.raise_arm_bones).
static func reach(skeleton: Skeleton3D, upper: int, fore: int, hand: int, target: Transform3D) -> void:
	var parent := skeleton.get_bone_parent(upper)
	var above := skeleton.get_bone_global_pose(parent) if parent >= 0 else Transform3D.IDENTITY
	var shoulder := skeleton.get_bone_global_pose(upper)
	var fore_pose := skeleton.get_bone_global_pose(fore)
	var elbow := fore_pose.origin
	var wrist := skeleton.get_bone_global_pose(hand).origin
	var a := shoulder.origin.distance_to(elbow)
	var b := elbow.distance_to(wrist)
	var to := target.origin - shoulder.origin
	if to.length() < EPSILON or a < EPSILON or b < EPSILON:
		return
	var way := to.normalized()
	var d := clampf(to.length(), absf(a - b) + EPSILON, a + b - EPSILON)
	var side := elbow - shoulder.origin
	side -= way * way.dot(side)
	side = side.normalized() if side.length() > EPSILON else Vector3.DOWN
	var along := (a * a + d * d - b * b) / (2.0 * d)
	var bent := shoulder.origin + way * along + side * sqrt(maxf(a * a - along * along, 0.0))
	var arm := Basis(Quaternion((elbow - shoulder.origin).normalized(), (bent - shoulder.origin).normalized()))
	var upper_at := Transform3D(arm * shoulder.basis, shoulder.origin)
	# The wrist where the upper arm's turn carries it, then the forearm turned from there onto the target.
	var carried := bent + arm * (wrist - elbow)
	var forearm := Basis(Quaternion((carried - bent).normalized(), (target.origin - bent).normalized()))
	var fore_at := Transform3D(forearm * arm * fore_pose.basis, bent)
	skeleton.set_bone_pose(upper, above.affine_inverse() * upper_at)
	skeleton.set_bone_pose(fore, upper_at.affine_inverse() * fore_at)
	skeleton.set_bone_pose(hand, fore_at.affine_inverse() * target)
