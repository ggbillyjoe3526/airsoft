extends GutTest
## HA1 (the owner: "go over all first person view animations and make them higher quality"): the life in the replica in
## your hands (HandsMotion, HandsLifeConfig). It bobs with your steps and breathes while you stand, leans into a strafe,
## dips as you land, flicks on a spring with each shot and settles, keeps a small share with the sight raised and
## none with motion reduced to nothing; ReplicaView draws it by moving its own node about the replica's place, so the
## pose under it (the hip, the sight line) is what it always was.

const DT := 1.0 / 60.0
const EPS := 1e-5
const AHEAD := Vector3(0.0, 0.0, -1.0)

var cfg: HandsLifeConfig = null
var whole: MotionScale = null


func before_each() -> void:
	cfg = HandsLifeConfig.new()
	whole = MotionScale.new()


func _character() -> Character:
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	c.grounded = true
	return c


## The widest `life` swings in each of shift's and turn's parts over `frames` frames (x, y, z of shift, then of turn).
func _swing(life: HandsMotion, c: Character, frames: int, raise: float = 0.0, motion: MotionScale = null) -> Array[float]:
	var most: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	for i in frames:
		life.step(cfg, c, AHEAD, DT, raise, motion if motion != null else whole)
		for k in 3:
			most[k] = maxf(most[k], absf(life.shift[k]))
			most[3 + k] = maxf(most[3 + k], absf(life.turn[k]))
	return most


func test_a_spring_settles_on_its_mark_and_never_gains_at_any_step() -> void:
	for dt: float in [1.0 / 240.0, DT, 0.1, 1.0]:
		var at := Vector2(0.0, 5.0)
		var most := 0.0
		for i in ceili(3.0 / dt):
			at = HandsMotion.spring(at.x, at.y, 0.2, cfg.lift_spring, dt)
			most = maxf(most, absf(at.x))
		assert_almost_eq(at.x, 0.2, 1e-3, "settled at a step of %s s" % dt)
		assert_lt(most, 1.0, "never ran away at a step of %s s" % dt)


func test_standing_still_it_only_breathes() -> void:
	var life := HandsMotion.new()
	var most := _swing(life, _character(), ceili(2.0 * cfg.breath_period / DT))
	assert_between(most[1], cfg.breath_lift * 0.9, cfg.breath_lift + EPS, "a breath's lift, no more")
	assert_lte(most[0], cfg.breath_drift + EPS, "its drift")
	assert_almost_eq(most[2], 0.0, EPS, "nothing to or fro")
	assert_between(most[3], cfg.breath_tip * 0.9, cfg.breath_tip + EPS, "its tip")
	assert_almost_eq(most[5], 0.0, EPS, "no roll")


func test_walking_it_bobs_with_the_ground_covered_and_stops_when_you_do() -> void:
	var life := HandsMotion.new()
	var c := _character()
	c.velocity = AHEAD * cfg.bob_speed
	var most := _swing(life, c, 180)
	assert_between(most[0], cfg.bob_side * 0.8, cfg.bob_side + EPS, "a whole bob to each side at bob_speed")
	assert_gt(most[5], cfg.bob_roll * 0.8, "rolling with it")
	assert_gt(life.shift.z, cfg.lean_back * 0.9, "and sat a touch nearer, moving ahead")
	c.velocity = Vector3.ZERO
	_swing(life, c, 120)
	most = _swing(life, c, ceili(cfg.breath_period / DT))
	assert_lte(most[0], cfg.breath_drift + EPS, "stopped: back to breathing")
	# In the air nothing steps.
	c.velocity = AHEAD * cfg.bob_speed
	c.grounded = false
	var air := HandsMotion.new()
	air.rest(c)
	_swing(air, c, 60)
	assert_almost_eq(air._bob, 0.0, EPS, "no bob off the ground")


func test_a_sprint_bobs_more_but_never_past_bob_most() -> void:
	var life := HandsMotion.new()
	var c := _character()
	c.velocity = AHEAD * cfg.bob_speed * 10.0
	_swing(life, c, 240)
	assert_almost_eq(life._bob, cfg.bob_most, 1e-3)
	assert_almost_eq(life._lean.length(), cfg.bob_most, 1e-3, "nor the lean")


func test_a_strafe_rolls_it_into_the_move_and_trails_it_behind() -> void:
	for way: float in [1.0, -1.0]:
		var life := HandsMotion.new()
		var c := _character()
		# Too slow to step, so the lean shows alone: right is +x looking down -z.
		cfg.bob_from = 100.0
		c.velocity = Vector3(way * cfg.lean_speed, 0.0, 0.0)
		_swing(life, c, 120)
		var breath := cfg.breath_drift + EPS
		assert_almost_eq(life.shift.x, -way * cfg.lean_trail, breath, "trailing a strafe %s" % way)
		assert_almost_eq(life.turn.z, -way * cfg.lean_roll, 1e-4, "its top leant the way you go")


func test_a_landing_knocks_it_down_and_it_comes_back() -> void:
	var life := HandsMotion.new()
	var c := _character()
	cfg.breath_lift = 0.0
	c.grounded = false
	c.velocity = Vector3(0.0, -6.0, 0.0)
	_swing(life, c, 30)
	assert_almost_eq(life.shift.y, cfg.air_most, 1e-3, "falling, it trails above (air_most at most)")
	c.grounded = true
	c.velocity = Vector3.ZERO
	var low := 0.0
	for i in 20:
		life.step(cfg, c, AHEAD, DT, 0.0, whole)
		low = minf(low, life.shift.y)
	assert_lt(low, -0.005, "knocked down by the landing")
	assert_gt(low, -0.05, "but never out of the hands")
	_swing(life, c, 120)
	assert_almost_eq(life.shift.y, 0.0, 2e-4, "and back")
	# A step off a kerb (slower than land_from) knocks nothing.
	var soft := HandsMotion.new()
	c.grounded = false
	c.velocity = Vector3(0.0, -cfg.land_from * 0.5, 0.0)
	soft.rest(c)
	soft.step(cfg, c, AHEAD, DT, 0.0, whole)
	c.grounded = true
	c.velocity = Vector3.ZERO
	soft.step(cfg, c, AHEAD, DT, 0.0, whole)
	assert_gte(soft._lift_speed, 0.0, "no knock from a small drop")


func test_a_crouch_pushes_it_and_it_settles() -> void:
	var life := HandsMotion.new()
	var c := _character()
	cfg.breath_lift = 0.0
	var high := 0.0
	for i in 60:
		c.crouch_amount = minf(1.0, c.crouch_amount + DT / 0.2)
		life.step(cfg, c, AHEAD, DT, 0.0, whole)
		high = maxf(high, life.shift.y)
	assert_between(high, 0.002, 0.02, "it trails your body down")
	_swing(life, c, 120)
	assert_almost_eq(life.shift.y, 0.0, 2e-4)


func test_each_shot_flicks_the_muzzle_up_rolls_it_side_to_side_and_settles() -> void:
	var life := HandsMotion.new()
	var c := _character()
	cfg.breath_tip = 0.0
	var rolls: Array[float] = []
	for shot in 2:
		life.shot(cfg)
		var up := 0.0
		var roll := 0.0
		for i in 90:
			life.step(cfg, c, AHEAD, DT, 0.0, whole)
			up = maxf(up, life.turn.x)
			if absf(life.turn.z) > absf(roll):
				roll = life.turn.z
		assert_between(up, 0.005, 0.03, "a light flick up (a toy's): shot %d" % shot)
		assert_almost_eq(life.turn.x, 0.0, 2e-4, "settled")
		rolls.append(roll)
	assert_lt(rolls[0] * rolls[1], 0.0, "one side, then the other")


func test_a_draw_arrives_rolled_and_tipped_and_settles() -> void:
	var life := HandsMotion.new()
	var c := _character()
	cfg.breath_tip = 0.0
	life.drawn(cfg)
	var most := _swing(life, c, 20)
	assert_gt(most[5], 0.01)
	assert_gt(most[3], 0.008)
	_swing(life, c, 120)
	assert_almost_eq(life.turn.z, 0.0, 2e-4)
	assert_almost_eq(life.turn.x, 0.0, 2e-4)


func test_with_the_sight_raised_only_a_small_share_is_left_and_it_cants_on_the_way_up() -> void:
	var c := _character()
	c.velocity = AHEAD * cfg.bob_speed
	var hip := _swing(HandsMotion.new(), c, 180)
	var aimed := _swing(HandsMotion.new(), c, 180, 1.0)
	assert_almost_eq(aimed[0], hip[0] * cfg.aimed, 1e-4, "the bob")
	assert_almost_eq(aimed[5], hip[5] * cfg.aimed, 1e-4, "its roll, and no cant once up")
	var life := HandsMotion.new()
	life.step(cfg, _character(), AHEAD, DT, 0.5, whole)
	assert_almost_eq(life.turn.z, cfg.aim_cant, 1e-4, "canted at the middle of the way")


func test_reduced_motion_takes_its_shares_and_none_at_nothing() -> void:
	var c := _character()
	c.velocity = AHEAD * cfg.bob_speed
	var none := MotionScale.new()
	none.sway = 0.0
	none.kick = 0.0
	var life := HandsMotion.new()
	life.shot(cfg)
	var most := _swing(life, c, 120, 0.5, none)
	for k in 6:
		assert_almost_eq(most[k], 0.0, EPS, "part %d" % k)
	var half := MotionScale.new()
	half.sway = 0.5
	var all := _swing(HandsMotion.new(), c, 180)
	var some := _swing(HandsMotion.new(), c, 180, 0.0, half)
	assert_almost_eq(some[0], all[0] * 0.5, 1e-5, "half the sway share: half the bob")


func test_rest_stills_it_and_a_hitch_moves_it_no_further_than_a_short_step() -> void:
	var life := HandsMotion.new()
	var c := _character()
	c.velocity = Vector3(3.0, 0.0, -3.0)
	life.shot(cfg)
	_swing(life, c, 30)
	life.rest(c)
	assert_eq(life.shift, Vector3.ZERO)
	assert_eq(life.turn, Vector3.ZERO)
	life.shot(cfg)
	life.step(cfg, c, AHEAD, 30.0, 0.0, whole)
	assert_lt(life.turn.length(), 0.2, "a half-minute hitch")
	assert_lt(life.shift.length(), 0.05)
	# Looking straight up or down there is no way ahead: nothing leans, nothing breaks.
	life.step(cfg, c, Vector3.UP, DT, 0.0, whole)
	assert_false(is_nan(life.shift.x) or is_nan(life.turn.z))


func test_the_view_draws_it_about_the_replica_and_leaves_the_pose_alone() -> void:
	var view_cfg := ViewModelConfig.new()
	var c := _character()
	var hands := ReplicaView.new()
	add_child_autofree(hands)
	hands.setup(view_cfg, c.armament.replicas, BoxWorld.new())
	for i in 120:
		hands.update(c, 0.0, 0.0, Vector3.ZERO, AHEAD, DT, 0.0)
	var held := hands._held[hands._active]
	var hip: Vector3 = view_cfg.hip.get(held.id, view_cfg.hip_default)
	assert_almost_eq(held.root.position, hip, Vector3.ONE * 1e-4, "the pose is the hip's")
	assert_almost_eq(hands.transform * held.root.position, hip + hands._life.shift, Vector3.ONE * 1e-5,
			"turned about the replica's own place: only the shift moves it")
	hands.on_shot()
	hands.update(c, 0.0, 0.0, Vector3.ZERO, AHEAD, DT, 0.0)
	hands.update(c, 0.0, 0.0, Vector3.ZERO, AHEAD, DT, 0.0)
	assert_gt(hands.rotation.x, 0.0, "a shot flicks the muzzle up")
	# Out of play and out of view, the node is square again.
	c.status = Character.Status.CALLING
	hands.update(c, 0.0, 0.0, Vector3.ZERO, AHEAD, DT, 0.0)
	assert_false(hands.visible)
	assert_eq(hands.transform, Transform3D.IDENTITY)
