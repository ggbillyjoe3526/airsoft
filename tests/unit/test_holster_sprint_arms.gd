extends GutTest
## BP8 item 23 (William: the bots' running arms "too exaggerated"): the holstered sprint's arms (Holster_Sprint,
## tools/blender/bot-figure/gait/pump.py) on both figures, read from the clip's own tracks over the skeleton's rest:
## the elbows bent about a right angle all the way round, kept close to the sides, the fists below the chin and never
## out past the elbows, and the chest turning only a little. The bot shoulder's weights are not the clip's (33fa48b).

## The elbow's bend (deg) all through the swing.
const BEND_LEAST := 70.0
const BEND_MOST := 100.0
## The elbow at most this far (m) out from the shoulder's line, across the chest; the wrist no further out than the
## elbow is.
const ELBOW_OUT := 0.06
## The wrist at least this far (m) below the shoulder: the fists stay low (the old clip's reached the chin).
const WRIST_BELOW := 0.15
## The chest's turn from its mean, either way (deg; the old clip's was about 10).
const CHEST_TURN := 6.0
const STEP := 1.0 / 30.0

var config: FigureConfig = null
var models: FigureModels = null


func before_all() -> void:
	config = FigureConfig.new()
	models = FigureModels.new(config)
	models.load_kinds()


func test_the_holstered_sprint_keeps_the_elbows_bent_and_in_and_the_fists_low() -> void:
	for kind: int in [FigureMix.HUMAN, FigureMix.ROBOT]:
		var anim := models.library(kind).get_animation(config.holster_sprint_clip)
		assert_not_null(anim, "kind %d has the holstered sprint" % kind)
		if anim == null:
			continue
		var sk := _skeleton(kind)
		var t := 0.0
		while t <= anim.length + 1e-4:
			var g := _globals(sk, anim, t)
			var chest: Transform3D = g["Chest"]
			for side: String in ["L", "R"]:
				var at := "kind %d %s arm at %.2f s" % [kind, side, t]
				var shoulder := chest.affine_inverse() * g["UpperArm_" + side].origin
				var elbow := chest.affine_inverse() * g["Forearm_" + side].origin
				var wrist := chest.affine_inverse() * g["Hand_" + side].origin
				var bend := rad_to_deg((elbow - shoulder).angle_to(wrist - elbow))
				assert_between(bend, BEND_LEAST, BEND_MOST, "%s: the elbow bent about a right angle" % at)
				assert_lte(absf(elbow.x) - absf(shoulder.x), ELBOW_OUT, "%s: the elbow close to the side" % at)
				assert_lte(absf(wrist.x), absf(elbow.x) + 0.005, "%s: the fist no further out than the elbow" % at)
				assert_gte(shoulder.y - wrist.y, WRIST_BELOW, "%s: the fist low, below the chin" % at)
			t += STEP
		sk.free()


func test_the_holstered_sprint_turns_the_chest_only_a_little() -> void:
	for kind: int in [FigureMix.HUMAN, FigureMix.ROBOT]:
		var anim := models.library(kind).get_animation(config.holster_sprint_clip)
		var sk := _skeleton(kind)
		var least := INF
		var most := -INF
		var t := 0.0
		while t <= anim.length + 1e-4:
			var g := _globals(sk, anim, t)
			var hips: Transform3D = g["Hips"]
			var ahead: Vector3 = (hips.basis.inverse() * g["Chest"].basis) * Vector3(0.0, 0.0, 1.0)
			var yaw := rad_to_deg(atan2(ahead.x, ahead.z))
			least = minf(least, yaw)
			most = maxf(most, yaw)
			t += STEP
		assert_lte((most - least) * 0.5, CHEST_TURN, "kind %d: the chest turns a little (%.1f°)" % [kind,
				(most - least) * 0.5])
		sk.free()


func _skeleton(kind: int) -> Skeleton3D:
	var probe := models.scene(kind).instantiate()
	var sk := probe.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	sk.owner = null
	sk.get_parent().remove_child(sk)
	probe.free()
	return sk


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


static func _placed(sk: Skeleton3D, local: Array[Transform3D], b: int) -> Transform3D:
	var parent := sk.get_bone_parent(b)
	return _placed(sk, local, parent) * local[b] if parent >= 0 else local[b]
