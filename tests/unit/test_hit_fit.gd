extends GutTest
## HV1: the fitted hit volume's joints (HitFit, Hitbox._fit_pose) are the drawn figure's. The committed bake is current
## (a fresh one from the figures matches it), and for characters in every kind of state the joints Hitbox poses from it
## (the blend spaces' blends, the legs posed from the blended turns, FigureBend's crouch limit, lean and aim lean) sit on
## the drawn skeleton's, bend and all.

## How close a fresh bake must match the file (it is written to 1 mm), and Hitbox's joints the drawn ones (m).
const BAKE_CLOSE := 0.002
const JOINT_CLOSE := 0.04
## How far over the drawn head's highest crouched top (FigureConfig.crouch_top_max, 1.15 m) the volume may reach: a
## crouch cover is 1.2 m.
const CROUCH_TOP_SLACK := 0.03
## States tried, and the seed that makes them.
const STATES := 60
const SEED := 20261103
## The drawn bones matching HitFit's lower points (after the hips' place and axes) and upper points (the head's top is
## measured separately, along the Head bone).
const LOWER_BONES: PackedStringArray = ["Thigh_L", "Shin_L", "Foot_L", "Toe_L", "Thigh_R", "Shin_R", "Foot_R", "Toe_R"]
const UPPER_BONES: PackedStringArray = ["Spine", "Spine1", "Chest", "Neck", "Head", "", "UpperArm_L", "UpperArm_R"]

var models: FigureModels = null
var hits: HitConfig = null
var moves: MovementConfig = null
var holder: Node3D = null


func before_all() -> void:
	models = FigureModels.new(FigureConfig.new())
	models.load_kinds()
	hits = HitConfig.new()
	moves = MovementConfig.new()
	holder = Node3D.new()
	add_child(holder)


func after_all() -> void:
	holder.free()


func test_the_committed_bake_is_complete_and_current() -> void:
	var fit := hits.fit
	assert_not_null(fit, "HitConfig carries the fit")
	assert_true(fit.is_complete(), "every sample baked")
	var fresh := HitFitBaker.new().bake(models, HitConfig.new(), moves, holder)
	assert_true(fresh.is_complete(), "a fresh bake is complete")
	for field: String in ["leg_offsets", "stand_still", "crouch_still", "gait_points", "gait", "crouch_points",
			"crouch", "jump", "vault_lower", "vault_upper", "aim_rifle", "aim_pistol", "holster", "sprint"]:
		var got: Variant = fit.get(field)
		var want: Variant = fresh.get(field)
		assert_eq(_size(got), _size(want), "%s: as many samples as a fresh bake (re-run tools/hit_fit_bake.gd)" % field)
		assert_lte(_worst(got, want), BAKE_CLOSE, "%s matches a fresh bake (re-run tools/hit_fit_bake.gd)" % field)
	assert_eq(fit.gait_triangles, fresh.gait_triangles, "the gait space triangulated the same")


func test_the_fitted_joints_sit_on_the_drawn_skeleton() -> void:
	var body := FigureBody.new()
	body.setup(models, FigureMix.HUMAN, 0, 0, Color.RED, 0.0, models.config.lod_high)
	holder.add_child(body)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var lower := PackedVector3Array()
	var upper := PackedVector3Array()
	var volume := Hitbox.Volume.new()
	var worst := 0.0
	var worst_at := ""
	for i in STATES:
		var c := _state(rng, i)
		var drawn := _drawn(body, c)
		Hitbox.fitted_joints(c, hits, lower, upper)
		for k in LOWER_BONES.size():
			var e := lower[HitFit.THIGH_L + k].distance_to(drawn[LOWER_BONES[k]])
			if e > worst:
				worst = e
				worst_at = "state %d %s" % [i, LOWER_BONES[k]]
		for k in UPPER_BONES.size():
			var bone := UPPER_BONES[k] if UPPER_BONES[k] != "" else "HeadTop"
			var e := upper[k].distance_to(drawn[bone])
			if e > worst:
				worst = e
				worst_at = "state %d %s" % [i, bone]
		Hitbox.build_volume(c, hits, volume)
		assert_lte(volume.bound.r, hits.volume_reach, "state %d: the volume within volume_reach across" % i)
		assert_lte(volume.bound.b.y + volume.bound.r, c.position.y + hits.volume_top + hits.volume_reach,
				"state %d: and under its top" % i)
		assert_gte(volume.bound.a.y - volume.bound.r, c.position.y - hits.volume_reach, "state %d: and over its foot" % i)
		var hips_error := lower[HitFit.HIPS].distance_to(drawn["Hips"])
		assert_lte(hips_error, JOINT_CLOSE, "state %d: the hips where they're drawn" % i)
	assert_lte(worst, JOINT_CLOSE, "every joint within %.0f cm of the drawn one (worst %.1f cm, %s)" % [
			JOINT_CLOSE * 100.0, worst * 100.0, worst_at])
	body.free()


func test_a_crouched_volume_stays_under_crouch_cover() -> void:
	# DECISIONS 2026-09-30: a crouched head's top stays at or below crouch_top_max, because crouch cover is 1.2 m.
	var volume := Hitbox.Volume.new()
	for pitch: float in [-1.0, 0.0, 1.0]:
		for speed: float in [0.0, moves.crouch_speed]:
			var c := Character.new(1, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
			c.grounded = true
			c.crouch_amount = 1.0
			c.pitch = pitch
			c.velocity = Vector3(0.0, 0.0, -speed)
			Hitbox.build_volume(c, hits, volume)
			assert_lte(volume.bound.b.y, hits.fit.crouch_top_max + CROUCH_TOP_SLACK,
					"crouched, pitch %.1f, at %.1f m/s: the volume's top under crouch cover" % [pitch, speed])


## State `i` of the seeded run: still, stepping any way at any speed, crouched or between, leaning, aiming up or down,
## with the pistol, holstered, sprinting, in the air or vaulting.
func _state(rng: RandomNumberGenerator, i: int) -> Character:
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	c.grounded = true
	var way := rng.randf() * TAU
	var speed := 0.0 if i % 6 == 0 else rng.randf_range(0.3, moves.sprint_speed)
	c.velocity = Vector3(sin(way), 0.0, -cos(way)) * speed
	c.walk_cycle = rng.randf() * 4.0 * TAU
	c.crouch_amount = [0.0, 1.0, 0.0, rng.randf(), 1.0][i % 5]
	if c.crouch_amount > 0.5:
		# Crouched, no faster than a crouched walk (Movement holds it there).
		c.velocity = c.velocity.limit_length(moves.crouch_speed)
	c.lean = rng.randf_range(-1.0, 1.0) if i % 3 == 0 else 0.0
	c.pitch = rng.randf_range(-1.2, 1.2)
	match i % 10:
		3:
			for s in c.armament.replicas.size():
				if c.armament.replicas[s].site_class == &"pistol":
					c.armament.active = s
		5:
			c.armament.holstered = true
		7:
			c.sprinting = true
			c.crouch_amount = 0.0
			c.velocity = Vector3(sin(way * 0.2), 0.0, -cos(way * 0.2)) * moves.sprint_speed
		8:
			c.grounded = false
			c.lean = 0.0
			c.air_time = rng.randf_range(0.0, 0.4)
		9:
			c.grounded = false
			c.lean = 0.0
			c.vault.active = true
			c.vault.rise_end = 0.3
			c.vault.end = 0.6
			c.vault.time = rng.randf_range(0.0, 0.6)
	c.prev_position = c.position
	c.prev_yaw = c.yaw
	c.prev_pitch = c.pitch
	c.prev_lean = c.lean
	c.prev_crouch_amount = c.crouch_amount
	c.prev_walk_cycle = c.walk_cycle
	return c


## The drawn skeleton's joints for `c`, FigureBend's bend in (read inside the skeleton's update, as HitAreaProbe does):
## bone name to its place in the figure's frame, with the head's top as "HeadTop".
func _drawn(body: FigureBody, c: Character) -> Dictionary[String, Vector3]:
	var pose := FigurePose.new(models.config)
	pose.read(c, 1.0, hits)
	pose.snap()
	body.animate(pose, hits, 0.0)
	body.animate(pose, hits, 0.0)
	var sk := body.skeleton
	var out: Dictionary[String, Vector3] = {}
	var read := func() -> void:
		for bone: String in ["Hips"] + Array(LOWER_BONES) + Array(UPPER_BONES):
			if bone != "":
				out[bone] = sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bone)).origin
		var head := sk.get_bone_global_pose(sk.find_bone("Head"))
		out["HeadTop"] = sk.global_transform * (head * Vector3(0.0, models.config.head_top, 0.0))
	sk.skeleton_updated.connect(read, CONNECT_ONE_SHOT)
	sk.notification(Skeleton3D.NOTIFICATION_UPDATE_SKELETON)
	return out


static func _size(v: Variant) -> int:
	var n: int = v.size()
	return n


## The largest difference between two packed arrays of the same kind, element by element (INF if their sizes differ).
static func _worst(a: Variant, b: Variant) -> float:
	if _size(a) != _size(b):
		return INF
	var worst := 0.0
	var n: int = a.size()
	for i: int in n:
		var x: Variant = a[i]
		var y: Variant = b[i]
		if x is float:
			worst = maxf(worst, absf(float(x) - float(y)))
		elif x is Vector3:
			worst = maxf(worst, (x as Vector3).distance_to(y as Vector3))
		elif x is Vector2:
			worst = maxf(worst, (x as Vector2).distance_to(y as Vector2))
	return worst
