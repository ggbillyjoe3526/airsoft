extends GutTest
## HC1: the hit call's raised arm, read from both figures' HitCall and WalkOff clips (the bones posed by the clips'
## own tracks over the skeleton's rest): held straight up with the elbow nearly straight, the wrist in line and the
## hand open, and on the way up the wrist never cocked and the elbow never folded.

## The held arm (deg): the elbow's bend, the wrist's bend and the most any finger joint is curled.
const HELD_ELBOW := 20.0
const HELD_WRIST := 10.0
const HELD_CURL := 30.0
## On the way up (deg).
const RAISE_WRIST := 30.0
const RAISE_ELBOW := 90.0
## HitCall's raise ends by this time (s; call.py RAISE_TO is 14 frames at 30 a second); every 30th of a second checked.
const RAISED_BY := 0.5
## The hand is open by this time (s; call.py OPEN_BY is 7 frames), every finger joint then RAISE_CURL or less (deg).
const OPENED_BY := 7.0 / 30.0
const RAISE_CURL := 20.0
const STEP := 1.0 / 30.0
## The phalanx past the third finger joint (m along that bone): its tip.
const TIP := 0.025
const FINGERS: PackedStringArray = ["Index", "Middle", "Ring", "Pinky"]

var config: FigureConfig = null
var models: FigureModels = null


func before_all() -> void:
	config = FigureConfig.new()
	models = FigureModels.new(config)
	models.load_kinds()


func test_the_hit_call_holds_the_arm_straight_and_the_hand_open() -> void:
	for kind: int in [FigureMix.HUMAN, FigureMix.ROBOT]:
		var anim := models.library(kind).get_animation(config.call_clip)
		var sk := _skeleton(kind)
		var t := 0.0
		while t <= anim.length + 1e-4:
			var arm := _arm(sk, anim, t)
			var at := "kind %d HitCall at %.2f s" % [kind, t]
			assert_lte(arm.y, RAISE_WRIST, "%s: the wrist never cocked on the way up (%.0f°)" % [at, arm.y])
			assert_lte(arm.x, RAISE_ELBOW, "%s: the elbow never folded (%.0f°)" % [at, arm.x])
			if t >= OPENED_BY - 1e-4:
				assert_lte(arm.z, RAISE_CURL, "%s: the hand open on the way up (%.0f°)" % [at, arm.z])
			if t >= RAISED_BY:
				_assert_held(arm, at)
			t += STEP
		sk.free()


func test_the_walk_off_holds_the_arm_straight_and_the_hand_open() -> void:
	for kind: int in [FigureMix.HUMAN, FigureMix.ROBOT]:
		var anim := models.library(kind).get_animation(config.walk_off_clip)
		var sk := _skeleton(kind)
		var t := 0.0
		while t <= anim.length + 1e-4:
			_assert_held(_arm(sk, anim, t), "kind %d WalkOff at %.2f s" % [kind, t])
			t += STEP
		sk.free()


func _assert_held(arm: Vector3, at: String) -> void:
	assert_lte(arm.x, HELD_ELBOW, "%s: the elbow nearly straight (%.0f°)" % [at, arm.x])
	assert_lte(arm.y, HELD_WRIST, "%s: the wrist in line (%.0f°)" % [at, arm.y])
	assert_lte(arm.z, HELD_CURL, "%s: the hand open (%.0f°)" % [at, arm.z])


## A free copy of the figure's skeleton (the caller frees it).
func _skeleton(kind: int) -> Skeleton3D:
	var probe := models.scene(kind).instantiate()
	var sk := probe.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for bone: String in ["UpperArm_L", "Forearm_L", "Hand_L", "Middle1_L", "Index3_L", "Pinky3_L"]:
		assert_gt(sk.find_bone(bone), -1, "kind %d has %s (a renamed bone would leave the arm at rest)" % [kind, bone])
	sk.owner = null
	sk.get_parent().remove_child(sk)
	probe.free()
	return sk


## The left arm at time t of `anim`: the elbow's bend, the wrist's bend and the most curled finger joint, the knuckle
## (from the hand's line, the wrist to the middle finger's root) and the two joints along it (deg).
func _arm(sk: Skeleton3D, anim: Animation, t: float) -> Vector3:
	var g := _globals(sk, anim, t)
	var shoulder: Vector3 = g["UpperArm_L"].origin
	var elbow: Vector3 = g["Forearm_L"].origin
	var wrist: Vector3 = g["Hand_L"].origin
	var knuckle: Vector3 = g["Middle1_L"].origin
	var curl := 0.0
	for f in FINGERS:
		var a: Transform3D = g["%s1_L" % f]
		var b: Transform3D = g["%s2_L" % f]
		var c: Transform3D = g["%s3_L" % f]
		var tip := c.origin + c.basis.y.normalized() * TIP
		curl = maxf(curl, rad_to_deg((knuckle - wrist).angle_to(b.origin - a.origin)))
		curl = maxf(curl, rad_to_deg((b.origin - a.origin).angle_to(c.origin - b.origin)))
		curl = maxf(curl, rad_to_deg((c.origin - b.origin).angle_to(tip - c.origin)))
	return Vector3(rad_to_deg((elbow - shoulder).angle_to(wrist - elbow)),
			rad_to_deg((wrist - elbow).angle_to(knuckle - wrist)), curl)


## Every bone's place in the skeleton's frame at time t: the clip's turns and moves, the rest where it has none.
func _globals(sk: Skeleton3D, anim: Animation, t: float) -> Dictionary[String, Transform3D]:
	var local: Array[Transform3D] = []
	for b in sk.get_bone_count():
		local.append(sk.get_bone_rest(b))
	for i in anim.get_track_count():
		var bone := sk.find_bone(String(anim.track_get_path(i).get_concatenated_subnames()))
		if bone < 0:
			continue
		match anim.track_get_type(i):
			Animation.TYPE_ROTATION_3D:
				local[bone].basis = Basis(anim.rotation_track_interpolate(i, t)).scaled(local[bone].basis.get_scale())
			Animation.TYPE_POSITION_3D:
				local[bone].origin = anim.position_track_interpolate(i, t)
	var out: Dictionary[String, Transform3D] = {}
	for b in sk.get_bone_count():
		out[sk.get_bone_name(b)] = _placed(sk, local, b)
	return out


## Bone `b`'s place in the skeleton's frame from every bone's local transform.
static func _placed(sk: Skeleton3D, local: Array[Transform3D], b: int) -> Transform3D:
	var parent := sk.get_bone_parent(b)
	return _placed(sk, local, parent) * local[b] if parent >= 0 else local[b]
