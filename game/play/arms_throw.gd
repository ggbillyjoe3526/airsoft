class_name ArmsThrow
extends RefCounted
## Your arms throwing the bomb in first person (GT3), drawn over the bomb's hold (ArmsView, BL4's `<id>_Hold` clip):
## the left hand comes up to the pin's ring, hooks it and pulls it away out of view, while the right arm goes back past
## the side of the view, comes over the top and lets the bomb go ahead, then follows through down across. Each hand
## reaches its key (ViewModelConfig's bomb_* keys, in the eyes' frame) by two-bone IK (ArmReach) from the hold's pose,
## its elbow bent towards its pole; the hand turns with its forearm, so the bomb in the fist (and the pin in the left
## hand's) goes with it (`bomb_moved`, `pin_moved`). `share` runs 0..1 over the windup and 1..2 over the recovery
## (FigureThrow's measure); 0 is the hold. In the arms model's frame (its origin the eyes, BL4). Presentation only;
## allocation-free once made.

## The arms model's bones (tools/blender/arms/arms.py, named as the figures' skeleton names them): each arm's upper arm,
## forearm and hand, and the left hand's fingers, which curl round the ring (the first joint less, the thumb least).
const RIGHT_ARM: Array[String] = ["UpperArm_R", "Forearm_R", "Hand_R"]
const LEFT_ARM: Array[String] = ["UpperArm_L", "Forearm_L", "Hand_L"]
const LEFT_FINGERS: Array[String] = ["Index1_L", "Index2_L", "Index3_L", "Middle1_L", "Middle2_L", "Middle3_L",
		"Ring1_L", "Ring2_L", "Ring3_L", "Pinky1_L", "Pinky2_L", "Pinky3_L", "Thumb1_L", "Thumb2_L", "Thumb3_L"]
const FINGER_CURL: Array[float] = [0.5, 1.0, 0.8, 0.6, 1.1, 0.9, 0.7, 1.2, 0.9, 0.8, 1.2, 0.9, 0.3, 0.6, 0.5]
## The axis each left finger joint curls about towards the palm, in its own frame, and the axis the thumb turns about
## across to the index finger, as the model's bones lie.
const CURL_AXIS := Vector3(-1.0, 0.0, 0.0)
const THUMB_AXIS := Vector3(0.0, 0.0, 1.0)
const THUMB_FIRST := 12
## The right hand's fingers, which open off the bomb as it leaves (by FINGER_CURL's weights, the thumb's less).
const RIGHT_FINGERS: Array[String] = ["Index1_R", "Index2_R", "Index3_R", "Middle1_R", "Middle2_R", "Middle3_R",
		"Ring1_R", "Ring2_R", "Ring3_R", "Pinky1_R", "Pinky2_R", "Pinky3_R", "Thumb1_R", "Thumb2_R", "Thumb3_R"]
const EPSILON := 0.0001

var _cfg: ViewModelConfig = null
## The right arm's three bones, then the left's (none found: nothing is ever moved), and the left hand's fingers.
var _arms := PackedInt32Array()
var _fingers := PackedInt32Array()
var _right_fingers := PackedInt32Array()
## The hold's own pose of every bone the throw moves (the arms', then the fingers'), put back before each pose.
var _moved := PackedInt32Array()
var _at := PackedVector3Array()
var _turns: Array[Quaternion] = []
## The right hand on the hold, and both hands as the left grips the ring (its share bomb_pin_grab), in the model's
## frame; the ring's middle there.
var _right_hold := Transform3D.IDENTITY
var _right_grab := Transform3D.IDENTITY
var _left_grab := Transform3D.IDENTITY
var _ring := Vector3.ZERO
## Whether the skeleton is off the hold now (a pose past 0 drawn since).
var _posed := false


## Finds the throw's bones in `skeleton`; with any missing, nothing is ever moved.
func _init(skeleton: Skeleton3D, cfg: ViewModelConfig) -> void:
	_cfg = cfg
	for bone_name in RIGHT_ARM + LEFT_ARM:
		var index := skeleton.find_bone(bone_name)
		if index < 0:
			push_warning("ArmsThrow: no bone %s" % bone_name)
			_arms.clear()
			return
		_arms.append(index)
	for bone_name in LEFT_FINGERS:
		_fingers.append(skeleton.find_bone(bone_name))
	for bone_name in RIGHT_FINGERS:
		_right_fingers.append(skeleton.find_bone(bone_name))
	_moved.append_array(_arms)
	for index in _fingers + _right_fingers:
		if index >= 0:
			_moved.append(index)
	_at.resize(_moved.size())
	_turns.resize(_moved.size())


## Takes `skeleton`'s pose now (its bones' turns, just put on by the hold's clip) as the hold the throw starts from, the
## pin's ring's middle at `ring` (the model's frame). Called once each time the hold is put on.
func capture(skeleton: Skeleton3D, ring: Vector3) -> void:
	if _arms.is_empty():
		return
	for k in _moved.size():
		# The holds key only the bones' turns: each sits at its rest place (a throw moves the upper arms').
		_at[k] = skeleton.get_bone_rest(_moved[k]).origin
		_turns[k] = skeleton.get_bone_pose_rotation(_moved[k])
	_ring = ring
	restore(skeleton)
	_right_hold = skeleton.get_bone_global_pose(_arms[2])
	pose(skeleton, _cfg.bomb_pin_grab)
	_right_grab = skeleton.get_bone_global_pose(_arms[2])
	_left_grab = skeleton.get_bone_global_pose(_arms[5])
	restore(skeleton)
	_posed = false


## Puts the hold's own pose back.
func restore(skeleton: Skeleton3D) -> void:
	for k in _moved.size():
		skeleton.set_bone_pose_position(_moved[k], _at[k])
		skeleton.set_bone_pose_rotation(_moved[k], _turns[k])


## Poses `skeleton` `share` of the way through the throw, from the hold.
func pose(skeleton: Skeleton3D, share: float) -> void:
	if _arms.is_empty():
		return
	if share <= 0.0 and not _posed:
		return
	restore(skeleton)
	_posed = share > 0.0
	if not _posed:
		return
	if left_shown(share, _cfg):
		var grip := smoothstep(0.0, maxf(_cfg.bomb_pin_grab, EPSILON), share)
		_turn_fingers(skeleton, _fingers, _cfg.bomb_pin_curl * grip, CURL_AXIS, THUMB_AXIS)
		_shoulder(skeleton, 3, _cfg.bomb_left_shoulder)
		ArmReach.reach(skeleton, _arms[3], _arms[4], _arms[5], left_key(share, _ring, _cfg), _cfg.bomb_left_pole,
				1.0, Basis.IDENTITY, 0.0)
		_turn_left(skeleton, grip)
	var w := right_weight(share, _cfg)
	if w > 0.0:
		var shoulder := skeleton.get_bone_global_pose(_arms[0]).origin
		_shoulder(skeleton, 0, shoulder + shoulder_shift(share, _cfg))
		ArmReach.reach(skeleton, _arms[0], _arms[1], _arms[2], right_key(share, _cfg), right_pole(share, _cfg), w,
				Basis.IDENTITY, 0.0)
		_flex(skeleton, wrist_flex(share, _cfg))
	if share > 1.0:
		var open := -_cfg.bomb_let_go * smoothstep(1.0, maxf(_cfg.bomb_let_go_by, 1.0 + EPSILON), share)
		_turn_fingers(skeleton, _right_fingers, open, CURL_AXIS, -THUMB_AXIS)


## How the right hand (and the bomb in it) has moved from the hold, in the model's frame.
func bomb_moved(skeleton: Skeleton3D) -> Transform3D:
	if _arms.is_empty():
		return Transform3D.IDENTITY
	return skeleton.get_bone_global_pose(_arms[2]) * _right_hold.affine_inverse()


## How the pin has moved from the hold, in the model's frame `share` of the way through: with the bomb until the left
## hand grips the ring, then with the left hand, slipping down to hang bomb_pin_hang from the fist as it comes out
## (so the ring shows under the fingers).
func pin_moved(skeleton: Skeleton3D, share: float) -> Transform3D:
	if _arms.is_empty() or share < _cfg.bomb_pin_grab:
		return bomb_moved(skeleton)
	var hang := _cfg.bomb_pin_hang * smoothstep(_cfg.bomb_pin_grab, maxf(_cfg.bomb_pull_at, _cfg.bomb_pin_grab), share)
	return Transform3D(Basis.IDENTITY, hang) * skeleton.get_bone_global_pose(_arms[5]) * _left_grab.affine_inverse() \
			* _right_grab * _right_hold.affine_inverse()


## Whether the left arm shows `share` of the way through: from the windup's start until the pin is away.
static func left_shown(share: float, cfg: ViewModelConfig) -> bool:
	return share > 0.0 and share < cfg.bomb_pin_out


## The left wrist's key: up from bomb_left_in to the ring (`ring`) by bomb_pin_grab, drawing the pin out by
## bomb_pull_at, then away with it.
static func left_key(share: float, ring: Vector3, cfg: ViewModelConfig) -> Vector3:
	var grab := clampf(cfg.bomb_pin_grab, EPSILON, 1.0)
	var pull := maxf(cfg.bomb_pull_at, grab + EPSILON)
	var at_ring := ring + cfg.bomb_left_ring
	if share <= grab:
		return cfg.bomb_left_in.lerp(at_ring, smoothstep(0.0, 1.0, share / grab))
	var pulled := at_ring + cfg.bomb_left_pulled
	if share <= pull:
		return at_ring.lerp(pulled, smoothstep(grab, pull, share))
	return pulled.lerp(cfg.bomb_left_away, smoothstep(pull, maxf(cfg.bomb_pin_out, pull + EPSILON), share))


## How much of the right arm's throw is drawn: none until the left hand grips the ring, coming in as the hand goes out
## to bomb_aside (the hold's elbow swinging to its pole with it), then all.
static func right_weight(share: float, cfg: ViewModelConfig) -> float:
	var grab := clampf(cfg.bomb_pin_grab, 0.0, 1.0 - 2.0 * EPSILON)
	var cock := clampf(cfg.bomb_cock, grab + EPSILON, 1.0 - EPSILON)
	return smoothstep(grab, lerpf(grab, cock, clampf(cfg.bomb_aside_at, EPSILON, 1.0)), share)


## The right wrist's key (drawn right_weight of the way from the hold): out aside (bomb_aside) and back to bomb_cocked
## by bomb_cock, then quickening over the top (bomb_over) and ahead to bomb_release at the release, then down across to
## bomb_follow over the recovery.
static func right_key(share: float, cfg: ViewModelConfig) -> Vector3:
	var cock := clampf(cfg.bomb_cock, EPSILON, 1.0 - EPSILON)
	if share <= cock:
		var grab := clampf(cfg.bomb_pin_grab, 0.0, cock - EPSILON)
		var t := (share - grab) / (cock - grab)
		var aside := clampf(cfg.bomb_aside_at, EPSILON, 1.0 - EPSILON)
		if t <= aside:
			return cfg.bomb_aside
		return cfg.bomb_aside.lerp(cfg.bomb_cocked, smoothstep(aside, 1.0, t))
	if share <= 1.0:
		var t := (share - cock) / (1.0 - cock)
		t *= t
		var over := clampf(cfg.bomb_over_at, EPSILON, 1.0 - EPSILON)
		if t <= over:
			return cfg.bomb_cocked.lerp(cfg.bomb_over, smoothstep(0.0, 1.0, t / over))
		return cfg.bomb_over.lerp(cfg.bomb_release, (t - over) / (1.0 - over))
	return cfg.bomb_release.lerp(cfg.bomb_follow, smoothstep(1.0, maxf(cfg.bomb_follow_by, 1.0 + EPSILON), share))


## The right wrist's bend (rad; negative cocks it back): back to bomb_wrist_cocked as the arm goes back, then snapping
## forward to bomb_wrist_release at the release, and held.
static func wrist_flex(share: float, cfg: ViewModelConfig) -> float:
	var grab := cfg.bomb_pin_grab
	var cock := maxf(cfg.bomb_cock, grab + EPSILON)
	if share <= cock:
		return cfg.bomb_wrist_cocked * smoothstep(grab, cock, share)
	var t := clampf((share - cock) / (1.0 - cock), 0.0, 1.0)
	return lerpf(cfg.bomb_wrist_cocked, cfg.bomb_wrist_release, t * t)


## Where the right elbow bends: out and down while the arm goes back, swinging ahead as it comes over.
static func right_pole(share: float, cfg: ViewModelConfig) -> Vector3:
	if share <= cfg.bomb_cock:
		return cfg.bomb_right_pole
	return cfg.bomb_right_pole.lerp(cfg.bomb_over_pole, smoothstep(cfg.bomb_cock, 1.0, minf(share, 1.0)))


## How far the right shoulder has moved from the hold: back as the arm cocks, forward to the release, and held there.
static func shoulder_shift(share: float, cfg: ViewModelConfig) -> Vector3:
	var grab := cfg.bomb_pin_grab
	var cock := maxf(cfg.bomb_cock, grab + EPSILON)
	if share <= grab:
		return Vector3.ZERO
	if share <= cock:
		return cfg.bomb_shoulder_back * smoothstep(grab, cock, share)
	return cfg.bomb_shoulder_back.lerp(cfg.bomb_shoulder_ahead, smoothstep(cock, 1.0, minf(share, 1.0)))


## Arm `first`'s upper arm (0 right, 3 left) moved to `at`, the arm with it.
func _shoulder(skeleton: Skeleton3D, first: int, at: Vector3) -> void:
	var upper := skeleton.get_bone_global_pose(_arms[first])
	skeleton.set_bone_global_pose(_arms[first], Transform3D(upper.basis, at))


## The right hand bent `angle` (rad) at the wrist towards the palm (as its fingers curl).
func _flex(skeleton: Skeleton3D, angle: float) -> void:
	var hand := skeleton.get_bone_global_pose(_arms[2])
	skeleton.set_bone_global_pose(_arms[2], Transform3D(hand.basis * Basis(CURL_AXIS, angle), hand.origin))


## The left hand turned `w` of the way to grip the ring: its fingers (its bone's +Y) pointing from its wrist to the
## ring, its palm (-Z: the thumb's side of the knuckles) facing bomb_left_palm.
func _turn_left(skeleton: Skeleton3D, w: float) -> void:
	var along := -_cfg.bomb_left_ring
	var palm := _cfg.bomb_left_palm
	palm -= along * along.dot(palm) / maxf(along.length_squared(), EPSILON)
	if along.length() < EPSILON or palm.length() < EPSILON:
		return
	var y := along.normalized()
	var z := -palm.normalized()
	var hand := skeleton.get_bone_global_pose(_arms[5])
	var grip := Basis(y.cross(z), y, z)
	skeleton.set_bone_global_pose(_arms[5], Transform3D(hand.basis.orthonormalized().slerp(grip, w), hand.origin))


## The fingers `bones` (LEFT_FINGERS' order) curled `angle` (rad, by FINGER_CURL's weights; negative opens them)
## about `axis`, the thumb about `thumb`.
static func _turn_fingers(skeleton: Skeleton3D, bones: PackedInt32Array, angle: float, axis: Vector3,
		thumb: Vector3) -> void:
	for k in bones.size():
		var bone := bones[k]
		if bone < 0:
			continue
		var turn := Quaternion(thumb if k >= THUMB_FIRST else axis, angle * FINGER_CURL[k])
		skeleton.set_bone_pose_rotation(bone, skeleton.get_bone_pose_rotation(bone) * turn)
