extends GutTest
## TP3 (QA): the right fist closes on the grip while a replica is in hand, both hands for a pistol (not in a reload),
## nothing held out when holstered or hanging.

const EYE := Vector3(0.0, 1.6, 3.0)
const FRAME := 1.0 / 60.0

var config: FigureConfig = null
var models: FigureModels = null
var hits: HitConfig = null


func before_all() -> void:
	config = FigureConfig.new()
	models = FigureModels.new(config)
	models.load_kinds()
	hits = HitConfig.new()


func _view(slot: int, kind: int = FigureMix.HUMAN) -> Array:
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	c.grounded = true
	c.armament.active = slot
	var v := FigureView.new()
	add_child_autofree(v)
	v.setup(c, Color.RED, hits, null)
	v.set_body(models, kind, config.lod_high)
	return [v, c]


func _pose(v: FigureView, c: Character, frames: int = 40) -> void:
	for i in frames:
		v.update(c, 1.0)
		v.animate(c, 1.0, FRAME, EYE)
	await wait_process_frames(1)


func test_a_rifle_in_hand_fits_the_right_hand_only_and_a_pistol_both() -> void:
	var r := _view(0)
	await _pose(r[0], r[1])
	var rb: FigureBend = (r[0] as FigureView).body().bend
	assert_ne(rb.grip_fit, Vector3.ZERO, "rifle: the fist reaches the grip")
	assert_false(rb.grip_fit_both, "rifle: the left stays on the handguard")
	var p := _view(1)
	await _pose(p[0], p[1])
	var pb: FigureBend = (p[0] as FigureView).body().bend
	assert_ne(pb.grip_fit, Vector3.ZERO)
	assert_true(pb.grip_fit_both, "pistol: both hands")


func test_holstered_hanging_and_reloading_pistol_do_not_fit() -> void:
	var p := _view(1)
	var v: FigureView = p[0]
	var c: Character = p[1]
	await _pose(v, c)
	c.armament.holstered = true
	await _pose(v, c)
	assert_eq(v.body().bend.grip_fit, Vector3.ZERO, "holstered")
	assert_false(v.body().bend.grip_fit_both, "holstered: no both")
	c.armament.holstered = false
	c.status = Character.Status.CALLING
	await _pose(v, c, 60)
	assert_eq(v.body().bend.grip_fit, Vector3.ZERO, "hanging")


## The right and left hands' joints and the held replica's frame as `slot` is drawn at rest (the skeleton's frame),
## `reloading` halfway through a reload; with FigureConfig.grip_fit as `fit`.
func _drawn(slot: int, fit: Dictionary[StringName, Vector3], reloading: bool = false) -> Dictionary:
	var kept := config.grip_fit
	config.grip_fit = fit
	var p := _view(slot)
	config.grip_fit = kept
	var v: FigureView = p[0]
	var c: Character = p[1]
	var sk := v.body().skeleton
	var hands := v.body().hands
	var out := {}
	sk.skeleton_updated.connect(func() -> void:
		out["right"] = sk.get_bone_global_pose(sk.find_bone("Hand_R")).origin
		out["left"] = sk.get_bone_global_pose(sk.find_bone("Hand_L")).origin
		var r := hands.replica(hands.in_hand)
		if r != null:
			out["replica"] = r.transform)
	await _pose(v, c)
	if reloading:
		var a := c.armament
		a.reload_left = a.replicas[slot].reload_time
		await _pose(v, c, 1)
		a.reload_left = a.replicas[slot].reload_time * 0.5
		await _pose(v, c, 1)
	return out


func test_the_fist_reaches_the_grip_and_the_replica_stays() -> void:
	# Critic (TP3): each fails with grip_fit empty. In view the hands take the first-person hold's places instead (HG1),
	# so the fit is checked with the figure out of the camera's view, where the clips' hands stand.
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.global_position = EYE
	camera.global_rotation = Vector3(0.0, PI, 0.0)
	camera.make_current()
	var none: Dictionary[StringName, Vector3] = {}
	for slot: int in [0, 1]:
		var cls := &"rifle" if slot == 0 else &"pistol"
		var fitted := await _drawn(slot, config.grip_fit)
		var bare := await _drawn(slot, none)
		var reach: float = (fitted["right"] as Vector3).distance_to(bare["right"])
		assert_almost_eq(reach, config.grip_fit[cls].length(), 0.005, "%s: the fist reaches grip_fit" % cls)
		var held: Transform3D = fitted["replica"]
		var was: Transform3D = bare["replica"]
		assert_lt(held.origin.distance_to(was.origin), 0.005, "%s: the replica stays where the clips put it" % cls)
		assert_lt((held.basis.z - was.basis.z).length(), 0.01, "%s: and keeps its aim" % cls)
		var left: Vector3 = (fitted["left"] as Vector3) - bare["left"]
		if slot == 0:
			assert_lt(left.length(), 0.002, "rifle: the left hand stays on the handguard")
		else:
			var right: Vector3 = (fitted["right"] as Vector3) - bare["right"]
			assert_lt(left.distance_to(right), 0.005, "pistol: the left hand goes with the right")
	var reload_fit := await _drawn(1, config.grip_fit, true)
	var reload_bare := await _drawn(1, none, true)
	assert_lt((reload_fit["left"] as Vector3).distance_to(reload_bare["left"]), 0.002,
			"pistol in a reload: the left hand takes the magazine as its clip does")
