extends GutTest
## FI2: the legs' targets from a character (game/play/figures/figure_pose.gd): the step in the figure's frame against
## the walk, run and sprint paces, still below the walking speed, the crouched walk backwards, the jump, the vault, the
## hit call and the walk-off; each blend eased about two thirds of the way in its settle time; nothing allocated.

const EPS := 1e-4

var cfg: FigureConfig = null
var hits: HitConfig = null
var moves: MovementConfig = null
var pose: FigurePose = null


func before_each() -> void:
	cfg = FigureConfig.new()
	hits = HitConfig.new()
	moves = MovementConfig.new()
	pose = FigurePose.new(cfg)


## A character on the ground facing `yaw`, moving at `velocity`, its last tick the same.
func _character(velocity: Vector3 = Vector3.ZERO, yaw: float = 0.0) -> Character:
	var c := Character.new(1, 0, Vector3.ZERO, yaw)
	c.velocity = velocity
	c.yaw = yaw
	c.prev_yaw = yaw
	c.grounded = true
	return c


func _gait(velocity: Vector3, yaw: float = 0.0) -> Vector2:
	pose.read(_character(velocity, yaw), 1.0, hits)
	return pose.gait


func test_standing_and_below_the_walking_speed_is_still() -> void:
	assert_eq(_gait(Vector3.ZERO), Vector2.ZERO)
	assert_eq(_gait(Vector3(0.0, 0.0, -hits.walking_speed * 0.9)), Vector2.ZERO, "below walking_speed")
	pose.snap()
	assert_false(pose.stepping())
	assert_eq(pose.jump + pose.vault + pose.call + pose.walk_off, 0.0, "no layer on")


func test_walking_each_way_is_the_step_in_the_figures_frame() -> void:
	var w := moves.walk_speed
	assert_almost_eq(_gait(Vector3(0.0, 0.0, -w)), Vector2(0.0, w), Vector2.ONE * EPS, "ahead, facing -Z")
	assert_almost_eq(_gait(Vector3(0.0, 0.0, w)), Vector2(0.0, -w), Vector2.ONE * EPS, "back")
	assert_almost_eq(_gait(Vector3(-w, 0.0, 0.0)), Vector2(-w, 0.0), Vector2.ONE * EPS, "left")
	assert_almost_eq(_gait(Vector3(w, 0.0, 0.0)), Vector2(w, 0.0), Vector2.ONE * EPS, "right")
	# Turned a quarter left (facing -X), a step down -X is ahead and one down -Z is to its right.
	assert_almost_eq(_gait(Vector3(-w, 0.0, 0.0), PI * 0.5), Vector2(0.0, w), Vector2.ONE * EPS, "turned, ahead")
	assert_almost_eq(_gait(Vector3(0.0, 0.0, -w), PI * 0.5), Vector2(w, 0.0), Vector2.ONE * EPS, "turned, right")
	pose.snap()
	assert_true(pose.stepping())
	assert_false(pose.backward, "standing, a step back plays Run_B, not a reversed clip")


func test_running_and_sprinting_reach_their_paces() -> void:
	assert_almost_eq(_gait(Vector3(0.0, 0.0, -moves.run_speed)).y, moves.run_speed, EPS)
	assert_almost_eq(_gait(Vector3(0.0, 0.0, -moves.sprint_speed)).y, moves.sprint_speed, EPS)
	pose.snap()
	assert_almost_eq(pose.gait_position(), Vector2(0.0, moves.sprint_speed), Vector2.ONE * EPS, "the gait blend's spot")


func test_crouch_walking_backwards_reverses_past_the_share_and_the_crouch() -> void:
	var c := _character(Vector3(0.0, 0.0, moves.crouch_speed))
	c.crouch_amount = 1.0
	c.prev_crouch_amount = 1.0
	pose.read(c, 1.0, hits)
	assert_true(pose.backward, "crouched, stepping back")
	assert_eq(pose.crouch, 1.0)
	c.crouch_amount = cfg.back_crouched * 0.8
	c.prev_crouch_amount = c.crouch_amount
	pose.read(c, 1.0, hits)
	assert_false(pose.backward, "not crouched far enough")
	c.crouch_amount = 1.0
	c.prev_crouch_amount = 1.0
	# Sideways with a backward part under back_share of the speed: not backwards.
	c.velocity = Vector3(moves.crouch_speed, 0.0, moves.crouch_speed * cfg.back_share * 0.5)
	pose.read(c, 1.0, hits)
	assert_false(pose.backward, "under the share")
	c.velocity = Vector3(moves.crouch_speed, 0.0, moves.crouch_speed * cfg.back_share * 2.0)
	pose.read(c, 1.0, hits)
	assert_true(pose.backward, "past the share")


func test_between_ticks_crouch_cycle_and_lean_are_interpolated() -> void:
	var c := _character()
	c.prev_crouch_amount = 0.0
	c.crouch_amount = 1.0
	c.prev_walk_cycle = 1.0
	c.walk_cycle = 2.0
	c.prev_lean = -1.0
	c.lean = 1.0
	pose.read(c, 0.25, hits)
	assert_almost_eq(pose.crouch, 0.25, EPS)
	assert_almost_eq(pose.cycle, 1.25, EPS)
	assert_almost_eq(pose.lean, -0.5, EPS)


func test_mid_jump_plays_the_jumps_span_over_the_time_in_the_air() -> void:
	var c := _character()
	c.grounded = false
	c.air_time = 0.1
	pose.read(c, 1.0, hits)
	assert_eq(pose.jump, 1.0)
	assert_almost_eq(pose.jump_time, cfg.jump_from + 0.1, EPS)
	c.air_time = 5.0
	pose.read(c, 1.0, hits)
	assert_almost_eq(pose.jump_time, cfg.jump_to, EPS, "held at the span's end")
	c.grounded = true
	pose.read(c, 1.0, hits)
	assert_eq(pose.jump, 0.0, "landed")


func test_mid_vault_plays_the_vault_by_its_progress() -> void:
	var c := _character()
	c.grounded = false
	c.vault.active = true
	c.vault.rise_end = 0.2
	c.vault.end = 0.6
	c.vault.time = 0.1
	pose.read(c, 1.0, hits)
	assert_eq(pose.vault, 1.0)
	assert_eq(pose.jump, 0.0, "a vault is no jump")
	assert_almost_eq(pose.vault_share, cfg.vault_top * 0.5, EPS, "halfway up the rise")
	c.vault.time = 0.4
	pose.read(c, 1.0, hits)
	assert_almost_eq(pose.vault_share, cfg.vault_top + (1.0 - cfg.vault_top) * 0.5, EPS, "halfway across")
	c.vault.time = 0.9
	pose.read(c, 1.0, hits)
	assert_almost_eq(pose.vault_share, 1.0, EPS, "held at the end")


func test_calling_the_hit_plays_hitcall_by_the_time_calling() -> void:
	var c := _character()
	c.status = Character.Status.CALLING
	c.status_time = 0.5
	c.grounded = false
	pose.read(c, 1.0, hits)
	assert_eq(pose.call, 1.0)
	assert_almost_eq(pose.call_time, 0.5, EPS)
	assert_eq(pose.jump, 0.0, "the call, not the jump")
	assert_eq(pose.walk_off, 0.0)


func test_walking_off_plays_walkoff_at_the_walk_off_speed() -> void:
	var c := _character(Vector3(0.0, 0.0, -hits.walk_off_speed))
	for status: Character.Status in [Character.Status.WALKING_OFF, Character.Status.LEAVING]:
		c.status = status
		pose.read(c, 1.0, hits)
		assert_eq(pose.walk_off, 1.0, str(status))
		assert_eq(pose.call, 0.0)
		assert_almost_eq(pose.walk_off_speed, hits.walk_off_speed, EPS)


func test_each_blend_reaches_63_percent_in_its_settle_time() -> void:
	var share := 1.0 - exp(-1.0)
	# Moving: the speed, in one step and in sixty.
	pose.read(_character(Vector3(0.0, 0.0, -moves.run_speed)), 1.0, hits)
	pose.settle(cfg.settle_move)
	assert_almost_eq(pose.speed, moves.run_speed * share, 1e-3, "move, one step")
	var many := FigurePose.new(cfg)
	many.read(_character(Vector3(0.0, 0.0, -moves.run_speed)), 1.0, hits)
	for i in 60:
		many.settle(cfg.settle_move / 60.0)
	assert_almost_eq(many.speed, moves.run_speed * share, 1e-3, "move, sixty steps")
	# The way: from ahead towards the right.
	var turn := FigurePose.new(cfg)
	turn.read(_character(Vector3(moves.run_speed, 0.0, 0.0)), 1.0, hits)
	turn.settle(cfg.settle_direction)
	assert_almost_eq(turn.way, Vector2(share, 1.0 - share).normalized(), Vector2.ONE * 1e-3, "direction")
	# The layers.
	var layers := FigurePose.new(cfg)
	var c := _character()
	c.status = Character.Status.CALLING
	layers.read(c, 1.0, hits)
	layers.settle(cfg.settle_mode)
	assert_almost_eq(layers.call_weight, share, 1e-3, "mode")
	var air := FigurePose.new(cfg)
	c = _character()
	c.grounded = false
	air.read(c, 1.0, hits)
	air.settle(cfg.settle_jump)
	assert_almost_eq(air.jump_weight, share, 1e-3, "jump")
	var hop := FigurePose.new(cfg)
	c.vault.active = true
	hop.read(c, 1.0, hits)
	hop.settle(cfg.settle_vault)
	assert_almost_eq(hop.vault_weight, share, 1e-3, "vault")


func test_snap_sets_the_blends_to_the_targets() -> void:
	var c := _character(Vector3(0.0, 0.0, -moves.walk_speed))
	c.status = Character.Status.WALKING_OFF
	pose.read(c, 1.0, hits)
	pose.snap()
	assert_almost_eq(pose.speed, moves.walk_speed, EPS)
	assert_eq(pose.walk_off_weight, 1.0)


func test_reading_and_settling_allocate_nothing() -> void:
	var c := _character(Vector3(1.0, 0.0, -3.0), 0.3)
	c.vault.active = true
	c.vault.rise_end = 0.2
	c.vault.end = 0.6
	pose.read(c, 0.5, hits)
	pose.settle(0.016)
	var before := Performance.get_monitor(Performance.OBJECT_COUNT)
	for i in 1000:
		c.walk_cycle += 0.05
		c.vault.time = fmod(i * 0.01, 0.6)
		pose.read(c, 0.5, hits)
		pose.settle(0.016)
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), before)


## FI3: the upper body's targets.

## A character holding the default loadout (a rifle, then a pistol), standing.
func _armed() -> Character:
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	c.grounded = true
	return c


func test_the_aim_blends_by_pitch_and_the_spine_leans_the_rest() -> void:
	var c := _armed()
	c.prev_pitch = deg_to_rad(20.0)
	c.pitch = deg_to_rad(40.0)
	pose.read(c, 0.5, hits)
	assert_almost_eq(pose.pitch, deg_to_rad(30.0), EPS, "between the ticks")
	assert_almost_eq(pose.aim_blend(), 0.5, EPS, "half way to AimUp's 60°")
	assert_almost_eq(pose.aim_lean(), deg_to_rad(30.0) * (1.0 - cfg.aim_reach), EPS, "the spine leans 0.45 of it")
	c.prev_pitch = deg_to_rad(-80.0)
	c.pitch = c.prev_pitch
	pose.read(c, 1.0, hits)
	assert_eq(pose.aim_blend(), -1.0, "AimDown at most")
	assert_almost_eq(pose.aim_lean(), deg_to_rad(-80.0) + cfg.aim_reach * cfg.aim_pitch, EPS, "past the clips' reach")


func test_the_rifle_in_hand_and_the_pistol_held_by_its_class() -> void:
	var c := _armed()
	pose.read(c, 1.0, hits)
	pose.snap()
	assert_eq(pose.in_hand, 0)
	assert_eq(pose.on_back, -1)
	assert_eq(pose.pistol_weight, 0.0)
	c.armament.active = 1
	pose.read(c, 1.0, hits)
	assert_eq(pose.pistol, 1.0, "the pistol's aim")
	pose.settle(cfg.settle_hold)
	assert_almost_eq(pose.pistol_weight, 1.0 - exp(-1.0), 1e-3, "eased at hold")


func test_out_of_the_hand_the_rifle_rides_on_the_back_and_the_pistol_in_the_holster() -> void:
	var c := _armed()
	pose.read(c, 1.0, hits)
	assert_eq(pose.in_hand, 0)
	assert_eq(pose.on_back, -1, "the rifle in the hand isn't on the back")
	assert_eq(pose.in_holster, 1, "the pistol in the holster")
	c.armament.active = 1
	pose.read(c, 1.0, hits)
	assert_eq(pose.in_hand, 1)
	assert_eq(pose.on_back, 0, "the rifle on the back")
	assert_eq(pose.in_holster, -1, "the pistol in the hand")
	c.armament.holstered = true
	pose.read(c, 1.0, hits)
	assert_eq(pose.in_hand, -1)
	assert_eq(pose.on_back, 0, "holstered: both stowed")
	assert_eq(pose.in_holster, 1)
	var loadout: Array[ReplicaConfig] = [ReplicaStats.load_replica(&"pistol")]
	var pistol_only := Character.new(1, 0, Vector3.ZERO, 0.0, loadout)
	pistol_only.armament.holstered = true
	pose.read(pistol_only, 1.0, hits)
	assert_eq(pose.on_back, -1, "no rifle")
	assert_eq(pose.in_holster, 0, "the only pistol, put away")


func test_a_switch_starts_once_and_hands_over_at_its_share() -> void:
	var c := _armed()
	pose.read(c, 1.0, hits)
	var a := c.armament
	a.active = 1
	a.draw_total = 0.3
	a.draw_left = 0.3
	pose.read(c, 1.0, hits)
	assert_true(pose.switch_started, "begun")
	assert_true(pose.switching)
	assert_false(pose.switch_back, "to a pistol: forwards")
	assert_eq(pose.draw_seconds, 0.3)
	assert_eq(pose.in_hand, 0, "the rifle still in the hand")
	a.draw_left = 0.3 * (1.0 - cfg.switch_pistol_from) + 0.001
	pose.read(c, 1.0, hits)
	assert_false(pose.switch_started, "once")
	assert_eq(pose.in_hand, 0, "just before 0.35")
	a.draw_left = 0.3 * (1.0 - cfg.switch_pistol_from) - 0.001
	pose.read(c, 1.0, hits)
	assert_eq(pose.in_hand, 1, "the pistol past 0.35")
	a.draw_left = 0.0
	pose.read(c, 1.0, hits)
	assert_false(pose.switching, "done")
	# Back to the rifle: backwards, the rifle in the hand from 0.65.
	a.active = 0
	a.draw_left = 0.3
	pose.read(c, 1.0, hits)
	assert_true(pose.switch_started)
	assert_true(pose.switch_back)
	a.draw_left = 0.3 * cfg.switch_pistol_from + 0.001
	pose.read(c, 1.0, hits)
	assert_eq(pose.in_hand, 1, "the pistol until 0.65")
	a.draw_left = 0.3 * cfg.switch_pistol_from - 0.001
	pose.read(c, 1.0, hits)
	assert_eq(pose.in_hand, 0)


func test_holstered_the_rifle_is_on_the_back_and_a_draw_brings_it_to_the_hand_at_half() -> void:
	var c := _armed()
	var a := c.armament
	a.active = 1
	a.holstered = true
	pose.read(c, 1.0, hits)
	assert_eq(pose.in_hand, -1, "nothing in the hand")
	assert_eq(pose.on_back, 0, "the rifle on the back, even with the pistol put away")
	assert_eq(pose.holster, 1.0)
	a.holstered = false
	a.active = 0
	a.draw_total = 1.0
	a.draw_left = 0.8
	pose.read(c, 1.0, hits)
	assert_false(pose.switch_started, "out of the holster isn't a switch")
	assert_eq(pose.on_back, 0, "still on the back at 0.2")
	assert_eq(pose.holster, 1.0, "the arms still hang")
	a.draw_left = 0.25
	pose.read(c, 1.0, hits)
	assert_eq(pose.in_hand, 0, "in the hand at 0.75")
	assert_eq(pose.on_back, -1)
	assert_almost_eq(pose.holster, 0.5, EPS, "the arms half way up to the aim")
	a.draw_left = 0.0
	pose.read(c, 1.0, hits)
	assert_eq(pose.holster, 0.0)


func test_calling_the_hit_the_replica_hangs_and_the_upper_body_gives_way() -> void:
	var c := _armed()
	c.status = Character.Status.CALLING
	pose.read(c, 1.0, hits)
	pose.snap()
	assert_true(pose.hanging)
	assert_eq(pose.in_hand, 0)
	assert_eq(pose.upper_weight(), 0.0, "HitCall's whole body")
	c.status = Character.Status.WALKING_OFF
	pose.read(c, 1.0, hits)
	assert_true(pose.hanging, "still hanging on the walk off")
	c.armament.holstered = true
	pose.read(c, 1.0, hits)
	assert_false(pose.hanging, "holstered: it stays on the back")
	assert_eq(pose.on_back, 0)


func test_reading_the_upper_body_allocates_nothing() -> void:
	var c := _armed()
	var a := c.armament
	pose.read(c, 0.5, hits)
	var before := Performance.get_monitor(Performance.OBJECT_COUNT)
	for i in 1000:
		a.active = int(i / 50.0) % 2
		a.draw_total = 0.3
		a.draw_left = 0.3 - fmod(i * 0.01, 0.3)
		a.holstered = int(i / 200.0) % 2 == 1
		c.pitch = sin(i * 0.1)
		pose.read(c, 0.5, hits)
		pose.settle(0.016)
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), before)
