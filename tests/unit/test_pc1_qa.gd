extends GutTest
## PC1 QA: the order wheel's tap turns the view live and a hold gives it back, What got you's migration to a switch, and
## the sprint-first edges (aimed sensitivity, a holstered replica, a pause under the wheel).

const ACTIONS: Array[StringName] = [&"order_wheel", &"fire", &"aim", &"move_forward", &"sprint", &"walk", &"crouch",
		&"lean_left", &"lean_right"]

var input: PlayerInput = null
var controls: ControlsConfig = null
var cmd: PlayerCommand = PlayerCommand.new()


class Flat:
	extends CharacterMover

	func move(c: Character, d: Vector3) -> Vector3:
		var out := d
		if c.position.y + d.y <= 0.0:
			out.y = -c.position.y
		return out

	func probe_ground(c: Character, max_drop: float) -> float:
		return -c.position.y if c.position.y <= max_drop else NAN


func before_each() -> void:
	controls = ControlsConfig.new()
	input = PlayerInput.new()
	input.setup(controls, 1.5)
	add_child_autofree(input)
	input.active = true
	input.allow_orders(true, true)


func after_each() -> void:
	for action: StringName in ACTIONS:
		Input.action_release(action)


func _event(action: StringName, pressed: bool) -> void:
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)
	var e := InputEventAction.new()
	e.action = action
	e.pressed = pressed
	input._unhandled_input(e)


func _move(dx: float, dy: float) -> void:
	var e := InputEventMouseMotion.new()
	e.screen_relative = Vector2(dx, dy)
	input._unhandled_input(e)


func _hold_past_a_tap() -> void:
	input.wheel().opened_ms -= 1000


func test_the_view_turns_live_during_the_tap() -> void:
	_event(&"order_wheel", true)
	var yaw := input.view_yaw
	_move(50.0, 20.0)
	assert_ne(input.view_yaw, yaw, "turned at once, no freeze")
	assert_ne(input.view_pitch, 0.0)


func test_held_past_a_tap_the_view_stays_where_the_tap_left_it_to_the_release() -> void:
	input.view_yaw = 0.4
	input.view_pitch = -0.2
	_event(&"order_wheel", true)
	_move(80.0, 30.0)
	var yaw := input.view_yaw
	var pitch := input.view_pitch
	assert_ne(yaw, 0.4, "turned during the tap")
	_hold_past_a_tap()
	input.fill(cmd)
	assert_almost_eq(input.view_yaw, yaw, 0.0001, "no jump as the wheel comes up")
	assert_almost_eq(input.view_pitch, pitch, 0.0001)
	_move(500.0, 500.0)
	assert_almost_eq(input.view_yaw, yaw, 0.0001, "the mouse is the wheel's now")
	_event(&"order_wheel", false)
	assert_almost_eq(input.view_yaw, yaw, 0.0001, "no jump on release")
	assert_almost_eq(input.view_pitch, pitch, 0.0001)


func test_a_first_motion_event_after_the_tap_time_does_not_turn_the_view() -> void:
	input.view_yaw = 0.1
	_event(&"order_wheel", true)
	_hold_past_a_tap()
	_move(300.0, 0.0)
	assert_almost_eq(input.view_yaw, 0.1, 0.0001)


func test_a_pause_mid_tap_keeps_the_turn_and_leaves_no_wheel() -> void:
	_event(&"order_wheel", true)
	_move(40.0, 0.0)
	var yaw := input.view_yaw
	input.allow_orders(false, false)
	assert_false(input.wheel().open)
	assert_eq(input.view_yaw, yaw)
	input.fill(cmd)
	assert_eq(input.view_yaw, yaw, "an unseen release does not restore anything")


func test_release_after_the_wheel_was_taken_keeps_the_view_as_the_tap_left_it() -> void:
	input.view_yaw = -0.3
	_event(&"order_wheel", true)
	_move(60.0, 0.0)
	var yaw := input.view_yaw
	_hold_past_a_tap()
	input.fill(cmd)
	input.release()
	assert_false(input.wheel().open)
	assert_almost_eq(input.view_yaw, yaw, 0.0001)


func test_the_wheel_key_let_go_unseen_mid_tap_keeps_the_live_view() -> void:
	_event(&"order_wheel", true)
	_move(60.0, 0.0)
	var yaw := input.view_yaw
	Input.action_release(&"order_wheel")
	input.fill(cmd)
	assert_false(input.wheel().open)
	assert_eq(input.view_yaw, yaw)


func test_sprint_first_turns_at_the_plain_sensitivity_not_the_aimed_one() -> void:
	controls.aim_sensitivity = 0.25
	Input.action_press(&"move_forward")
	Input.action_press(&"aim")
	input.fill(cmd)
	var a := input.view_yaw
	_move(100.0, 0.0)
	var aimed_turn := absf(input.view_yaw - a)
	Input.action_press(&"sprint")
	input.fill(cmd)
	var b := input.view_yaw
	_move(100.0, 0.0)
	assert_gt(absf(input.view_yaw - b), aimed_turn * 2.0, "the sight is down for the sprint, so the turn is not slowed")


func test_a_press_of_aim_while_sprinting_forward_is_no_aim_command() -> void:
	# a holstered replica is drawn by an aim press (Armament); a sprint-first press must not command it
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	_event(&"aim", true)
	input.fill(cmd, 0, null, true)
	assert_false(cmd.aim)


func test_sprint_with_lean_held_in_movement_leaves_no_lean() -> void:
	var c := Character.new(0, 0, Vector3.ZERO, 0.0)
	c.grounded = true
	Input.action_press(&"move_forward")
	Input.action_press(&"lean_right")
	Input.action_press(&"sprint")
	for i in 30:
		input.fill(cmd)
		Movement.step(c, cmd, MovementConfig.new(), AccuracyConfig.new(), 1.0 / 60.0, Flat.new())
	assert_eq(c.lean, 0.0)


func test_inactive_input_clears_the_sprint_first_so_aim_sensitivity_returns() -> void:
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	input.fill(cmd)
	input.release()
	input.fill(cmd)
	input.active = true
	Input.action_release(&"sprint")
	Input.action_press(&"aim")
	input.fill(cmd)
	assert_true(cmd.aim)


func test_what_got_you_migrates_a_version_7_choice_to_a_switch() -> void:
	var expect := {0: true, 1: true, 2: false}
	for old: int in expect:
		var s := Settings.new()
		s.from_dict(Settings.migrate_defaults({"what_got_you": old}, 7))
		assert_eq(s.what_got_you, expect[old], "version 7 value %d" % old)
	for v: int in [1, 3, 6]:
		var s := Settings.new()
		s.from_dict(Settings.migrate_defaults({"what_got_you": 2.0}, v))
		assert_false(s.what_got_you, "an Off from version %d stays off" % v)


func test_what_got_you_current_version_bool_is_kept_and_junk_falls_back_on() -> void:
	for v: Variant in [true, false]:
		var s := Settings.new()
		s.from_dict(Settings.migrate_defaults({"what_got_you": v}, Settings.VERSION))
		assert_eq(s.what_got_you, v)
	for junk: Variant in ["off", null, 2, [], {}]:
		var s := Settings.new()
		s.from_dict({"what_got_you": junk})
		assert_true(s.what_got_you, "junk %s: the default, On" % str(junk))


func test_what_got_you_round_trips_as_a_bool() -> void:
	var s := Settings.new()
	s.what_got_you = false
	var d := s.to_dict()
	assert_true(d["what_got_you"] is bool)
	var t := Settings.new()
	t.from_dict(d)
	assert_false(t.what_got_you)


func test_a_session_shows_what_got_you_by_the_switch_whatever_the_difficulty() -> void:
	for diff: StringName in [&"easy", &"hard"]:
		for on: bool in [true, false]:
			var s := PlaySession.new()
			s.bots_active = false
			s.difficulty = diff
			s.settings = Settings.new()
			s.settings.what_got_you = on
			add_child_autofree(s)
			assert_eq(s.what_got_you_shown(), on, "%s %s" % [diff, on])
