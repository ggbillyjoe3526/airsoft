class_name FigureGrasp
extends RefCounted
## The hands closed on what they hold as the first-person arms hold it (HG1; FigureArmsHold, the owner's approved
## holds), drawn after FigureReady's arms: each hand moved onto the replica where FigureHands puts it, by the arm's
## two-bone reach, and its fingers closed as the arms' are: each finger bone turned as the arms' is against the hand,
## then aimed at the arms' next joint (the figures' fingers are shorter), the thumb reaching along the arms' last thumb
## bone round the grip's left side. The right hand high on the grip, index on the trigger; the left under a rifle's
## handguard or lowered from a pistol. The replica stays where FigureReady left it: FigureHands hangs it from the moved
## grip bone by its held_on_grip. In the skeleton's frame. Presentation only; no allocation once a hand's fingers are
## worked out for a hold (Closed).

## Below this (m) a length counts as none.
const EPSILON := 0.0001
## Bones to a finger in FigureConfig.hold_fingers (the thumb's first, each parents first).
const BONES := 3
## How much of the thumb's length its tip is reached out to (a little short of straight), and FABRIK's passes.
const THUMB_REACH := 0.97
const THUMB_PASSES := 6

var _grip: int = -1
## Each arm's upper arm, forearm and hand (FigureConfig.raise_arm_bones: right three, then left three).
var _arm_r: PackedInt32Array = PackedInt32Array()
var _arm_l: PackedInt32Array = PackedInt32Array()
## Each hand's finger bones (FigureConfig.hold_fingers, parents first); empty when one is missing or a finger's bones
## don't hang from the hand and each other.
var _fingers_r: PackedInt32Array = PackedInt32Array()
var _fingers_l: PackedInt32Array = PackedInt32Array()
## Each hand's fingers as worked out for its hold.
var _closed_r: Closed = Closed.new()
var _closed_l: Closed = Closed.new()


## One hand's fingers closed on one hold at one place on it: each bone's turn over its parent's. A hand on the replica
## sits the same way on it whatever the body does, so these hold until the hold or the hand's place on it changes.
class Closed:
	extends RefCounted
	var hold: FigureArmsHold = null
	var place: Transform3D = Transform3D.IDENTITY
	var turns: Array[Quaternion] = []

	## Whether these are the fingers closed on `on_hold` with the hand at `at` on it.
	func fits(on_hold: FigureArmsHold, at: Transform3D) -> bool:
		return hold == on_hold and place == at and not turns.is_empty()

	## Turns `fingers` in `skeleton` `amount` (0..1) of the way from the clips' turns to these.
	func put(skeleton: Skeleton3D, fingers: PackedInt32Array, amount: float) -> void:
		for i in fingers.size():
			var to := turns[i]
			skeleton.set_bone_pose_rotation(fingers[i],
					to if amount >= 1.0 else skeleton.get_bone_pose_rotation(fingers[i]).slerp(to, amount))


## Finds `config`'s bones in `skeleton`; a hand whose arm is missing is never moved, and one whose fingers are missing
## keeps the clips' fingers.
func _init(skeleton: Skeleton3D, config: FigureConfig) -> void:
	_grip = skeleton.find_bone(config.grip_bone)
	_arm_r = _arm(skeleton, config.raise_arm_bones.slice(0, 3))
	_arm_l = _arm(skeleton, config.raise_arm_bones.slice(3, 6))
	var right := PackedStringArray()
	var left := PackedStringArray()
	for finger in config.hold_fingers:
		right.append(finger + "_R")
		left.append(finger + "_L")
	_fingers_r = _hand(skeleton, _arm_r, _bones(skeleton, right))
	_fingers_l = _hand(skeleton, _arm_l, _bones(skeleton, left))


## Moves the hands onto the replica held as `held` has them (FigureHands): the right `grasp` (0..1) of the way to its
## place on the replica, the left `support` of the way to its; `fingers` false leaves the clips' fingers (a figure past
## the near line).
func hold(skeleton: Skeleton3D, held: FigureHeld, grasp: float, support: float, fingers: bool) -> void:
	if held == null or _grip < 0:
		return
	var arms := held.arms
	var replica := skeleton.get_bone_global_pose(_grip) * held.on_grip
	if grasp > 0.0 and _arm_r.size() == 3:
		var hand := _place(skeleton, _arm_r, replica * held.right, grasp)
		if fingers and not _fingers_r.is_empty():
			if not _closed_r.fits(arms, held.right):
				_close(skeleton, hand, _fingers_r, arms.right, arms.right_joints, arms.right_tips, replica, _closed_r)
				_closed_r.hold = arms
				_closed_r.place = held.right
			_closed_r.put(skeleton, _fingers_r, grasp)
	if support > 0.0 and _arm_l.size() == 3:
		var hand := _place(skeleton, _arm_l, replica * held.left, support)
		if fingers and not _fingers_l.is_empty():
			if not _closed_l.fits(arms, held.left):
				_close(skeleton, hand, _fingers_l, arms.left, arms.left_joints, arms.left_tips,
						replica * Transform3D(Basis.IDENTITY, held.left_shift), _closed_l)
				_closed_l.hold = arms
				_closed_l.place = held.left
			_closed_l.put(skeleton, _fingers_l, support)


## Brings `arm`'s hand `amount` of the way to `to` (its turn and place; the hand keeps its own scale) by
## FigureReady's reach; returns the hand's frame at `to`.
static func _place(skeleton: Skeleton3D, arm: PackedInt32Array, to: Transform3D, amount: float) -> Transform3D:
	var now := skeleton.get_bone_global_pose(arm[2])
	var target := Transform3D(to.basis.orthonormalized() * Basis.from_scale(now.basis.get_scale()), to.origin)
	FigureReady.reach(skeleton, arm[0], arm[1], arm[2], target if amount >= 1.0 else now.interpolate_with(target, amount))
	return target


## Works out `fingers`' turns over their parents (into `closed`) for the hand at `hand_at` (on the replica, fully
## held): each bone turned as `turns` has it against the hand, then onto the line to the arms' next joint (`joints`;
## past a finger's last bone its tip in `tips`; both in the frame of `replica`). The figures' fingers are shorter and
## their roots a little off the arms', so each bone aims where the arms' finger goes and the fingertips come to rest
## where theirs do. The thumb (the first finger) is shorter still: its tip goes as far along the arms' last thumb bone
## as it reaches, and its two inner joints follow (FABRIK), so it lies along the grip's side instead of inside it.
static func _close(skeleton: Skeleton3D, hand_at: Transform3D, fingers: PackedInt32Array, turns: Array[Basis],
		joints: PackedVector3Array, tips: PackedVector3Array, replica: Transform3D, closed: Closed) -> void:
	var count := fingers.size()
	if turns.size() != count or joints.size() != count or tips.size() * BONES != count:
		return
	closed.turns.resize(count)
	var palm := Quaternion(hand_at.basis.orthonormalized())
	var first := hand_at * skeleton.get_bone_pose(fingers[0])
	var second := first * skeleton.get_bone_pose(fingers[1])
	var third := second * skeleton.get_bone_pose(fingers[2])
	var root := first.origin
	# The thumb's three lengths; its last bone has no next joint to measure to, so it is taken as long as the middle.
	var lengths := Vector3(root.distance_to(second.origin), second.origin.distance_to(third.origin),
			second.origin.distance_to(third.origin))
	var thumb_tip := _reached(root, replica * joints[2], replica * tips[0], (lengths.x + lengths.y + lengths.z)
			* THUMB_REACH)
	var thumb_mid := replica * joints[1]
	var thumb_end := replica * joints[2]
	for k in THUMB_PASSES:
		thumb_end = thumb_tip + (thumb_end - thumb_tip).normalized() * lengths.z
		thumb_mid = thumb_end + (thumb_mid - thumb_end).normalized() * lengths.y
		thumb_mid = root + (thumb_mid - root).normalized() * lengths.x
		thumb_end = thumb_mid + (thumb_end - thumb_mid).normalized() * lengths.y
	var parent_at := hand_at
	for i in count:
		var last := i % BONES == BONES - 1
		if i % BONES == 0:
			parent_at = hand_at
		var local := skeleton.get_bone_pose(fingers[i])
		var origin := (parent_at * local).origin
		var to := palm * Quaternion(turns[i])
		# The bone's own way to its next joint (its +Y for a finger's last, which has none).
		var along := Vector3.UP if last else skeleton.get_bone_pose_position(fingers[i + 1])
		var aim := (replica * (tips[i / BONES] if last else joints[i + 1])) - origin
		if i < BONES:
			aim = (thumb_mid if i == 0 else thumb_end if i == 1 else thumb_tip) - origin
		if along.length() > EPSILON and aim.length() > EPSILON:
			to = Quaternion((to * along).normalized(), aim.normalized()) * to
		# Its turn over its parent's, the parent's own scale left out (each bone keeps its pose's scale).
		var turn := Quaternion(parent_at.basis.orthonormalized()).inverse() * to
		closed.turns[i] = turn
		parent_at = parent_at * Transform3D(Basis(turn) * Basis.from_scale(local.basis.get_scale()), local.origin)


## `fingers` when each finger's first bone hangs from `arm`'s hand and each other bone from the one before it (what
## _close works down); empty otherwise.
static func _hand(skeleton: Skeleton3D, arm: PackedInt32Array, fingers: PackedInt32Array) -> PackedInt32Array:
	if arm.size() != 3 or fingers.is_empty() or fingers.size() % BONES != 0:
		return PackedInt32Array()
	for i in fingers.size():
		var parent := skeleton.get_bone_parent(fingers[i])
		if parent != (arm[2] if i % BONES == 0 else fingers[i - 1]):
			push_warning("FigureGrasp: %s doesn't hang from its hand as a finger" % skeleton.get_bone_name(fingers[i]))
			return PackedInt32Array()
	return fingers


## The point `reach` from `root` along the line `from` to `to` (past `from`; `to` itself when that is nearer), or
## toward `to` when the line is out of reach.
static func _reached(root: Vector3, from: Vector3, to: Vector3, reach: float) -> Vector3:
	if root.distance_to(to) <= reach:
		return to
	var way := to - from
	var off := from - root
	var a := way.length_squared()
	var b := off.dot(way)
	var under := b * b - a * (off.length_squared() - reach * reach)
	if a < EPSILON or under < 0.0:
		return root + (to - root).normalized() * reach
	return from + way * maxf(0.0, (-b + sqrt(under)) / a)


## `names`' three bones as an arm FigureReady.reach can move (each hanging from the one before); empty otherwise.
static func _arm(skeleton: Skeleton3D, names: PackedStringArray) -> PackedInt32Array:
	var arm := _bones(skeleton, names)
	return arm if arm.size() == 3 and FigureReady.chained(skeleton, arm[0], arm[1], arm[2]) else PackedInt32Array()


## `names`' bones; empty when any is missing.
static func _bones(skeleton: Skeleton3D, names: PackedStringArray) -> PackedInt32Array:
	var out := PackedInt32Array()
	for bone_name in names:
		var index := skeleton.find_bone(bone_name)
		if index < 0:
			return PackedInt32Array()
		out.append(index)
	return out
