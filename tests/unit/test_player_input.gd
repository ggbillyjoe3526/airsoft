extends GutTest
## The player's controller (game/input/player_input.gd): the mouse turns the view by the sensitivity, slower while
## zoomed, pitch kept short of straight up; a tick's command carries held keys and every press since the last tick, so
## a tap shorter than a tick is never dropped; and nothing reaches the command while it isn't active.

var input: PlayerInput = null
var controls: ControlsConfig = ControlsConfig.new()
var cmd: PlayerCommand = PlayerCommand.new()


func before_each() -> void:
	input = PlayerInput.new()
	input.setup(controls, 1.5)
	add_child_autofree(input)
	input.active = true


func after_each() -> void:
	for action: StringName in [&"fire", &"aim", &"move_forward", &"walk", &"crouch", &"sprint", &"lean_left",
			&"lean_right"]:
		Input.action_release(action)


func _move(dx: float, dy: float) -> void:
	var e := InputEventMouseMotion.new()
	e.screen_relative = Vector2(dx, dy)
	e.relative = e.screen_relative
	input._unhandled_input(e)


func _press(action: StringName) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	input._unhandled_input(e)


func test_the_mouse_turns_the_view_by_the_sensitivity() -> void:
	_move(100.0, 50.0)
	assert_almost_eq(input.view_yaw, -100.0 * controls.radians_per_count, 1e-6, "right turns yaw negative")
	assert_almost_eq(input.view_pitch, -50.0 * controls.radians_per_count, 1e-6, "down looks down")


func test_aiming_slows_the_mouse_by_the_zoom() -> void:
	input.zoom = 2.0
	_move(100.0, 0.0)
	assert_almost_eq(input.view_yaw, -50.0 * controls.radians_per_count, 1e-6)


func test_pitch_stops_short_of_straight_up_and_down() -> void:
	_move(0.0, -100000.0)
	assert_almost_eq(input.view_pitch, 1.5, 1e-6)
	_move(0.0, 200000.0)
	assert_almost_eq(input.view_pitch, -1.5, 1e-6)


func test_a_tap_between_ticks_still_fires_jumps_and_reloads_once() -> void:
	_press(&"fire")
	_press(&"jump")
	_press(&"reload")
	_press(&"fire_mode")
	_press(&"slot_2")
	input.fill(cmd)
	assert_true(cmd.fire, "the click is kept though the button is up again")
	assert_true(cmd.jump)
	assert_true(cmd.reload)
	assert_true(cmd.cycle_fire_mode)
	assert_eq(cmd.switch_to, 1)
	input.fill(cmd)
	assert_false(cmd.fire, "a press counts for one tick only")
	assert_false(cmd.jump)
	assert_false(cmd.reload)
	assert_false(cmd.cycle_fire_mode)
	assert_eq(cmd.switch_to, -1)


func test_held_keys_and_the_view_reach_the_command() -> void:
	Input.action_press(&"move_forward")
	Input.action_press(&"aim")
	Input.action_press(&"walk")
	input.face(0.7, 0.2)
	input.fill(cmd)
	assert_eq(cmd.forward, 1.0)
	assert_true(cmd.aim)
	assert_true(cmd.walk)
	assert_almost_eq(cmd.yaw, 0.7, 1e-6)
	assert_almost_eq(cmd.pitch, 0.2, 1e-6)


func test_nothing_reaches_the_command_while_inactive() -> void:
	input.release()
	Input.action_press(&"fire")
	_press(&"fire")
	_move(500.0, 0.0)
	input.fill(cmd)
	assert_false(cmd.fire, "a menu click never fires")
	assert_eq(input.view_yaw, 0.0, "the mouse doesn't turn the view")


func test_releasing_drops_presses_already_latched() -> void:
	_press(&"reload")
	input.release()
	input.active = true
	input.fill(cmd)
	assert_false(cmd.reload)


func _toggle_crouch() -> void:
	var toggled := ControlsConfig.new()
	toggled.crouch_toggle = true
	input.setup(toggled, 1.5)


func test_crouch_toggles_with_the_setting_and_a_sprint_press_standing_still_keeps_you_down() -> void:
	_toggle_crouch()
	_press(&"crouch")
	input.fill(cmd)
	assert_true(cmd.crouch, "down after one press, the key already up")
	input.fill(cmd)
	assert_true(cmd.crouch, "still down a tick later")
	# Alt is the sprint: Alt+Tab or Alt+Enter behind cover must not stand you up (BP13). Running forward does (PC1).
	_press(&"sprint")
	input.fill(cmd)
	assert_true(cmd.crouch, "a sprint press standing still keeps you down")
	_press(&"crouch")
	input.fill(cmd)
	assert_false(cmd.crouch, "a second press stands you up")
	_press(&"crouch")
	_press(&"crouch")
	input.fill(cmd)
	assert_false(cmd.crouch, "two presses in one tick leave you as you were")


func test_a_jump_press_while_toggled_down_only_stands_you_up() -> void:
	_toggle_crouch()
	_press(&"crouch")
	input.fill(cmd)
	_press(&"jump")
	input.fill(cmd)
	assert_false(cmd.crouch)
	assert_false(cmd.jump, "that press stands you up; the next one jumps")
	_press(&"jump")
	input.fill(cmd)
	assert_true(cmd.jump)


func test_crouch_is_held_by_default() -> void:
	assert_false(controls.crouch_toggle, "held by default (owner, 2026-10-18)")
	_press(&"crouch")
	input.fill(cmd)
	assert_false(cmd.crouch, "a press alone isn't a hold")
	Input.action_press(&"crouch")
	input.fill(cmd)
	assert_true(cmd.crouch)


func test_a_spawn_stands_you_up() -> void:
	_toggle_crouch()
	_press(&"crouch")
	input.face(0.0)
	input.fill(cmd)
	assert_false(cmd.crouch)


func test_the_mouse_wheel_steps_through_the_replicas() -> void:
	_press(&"slot_next")
	input.fill(cmd, 0)
	assert_eq(cmd.switch_to, 1)
	_press(&"slot_next")
	input.fill(cmd, 1)
	assert_eq(cmd.switch_to, 0, "past the last it wraps to the first")
	_press(&"slot_previous")
	input.fill(cmd, 0)
	assert_eq(cmd.switch_to, 1, "and back from the first to the last")
	_press(&"slot_next")
	_press(&"slot_next")
	input.fill(cmd, 0)
	assert_eq(cmd.switch_to, 0, "two steps before a tick go round twice")
	input.fill(cmd, 0)
	assert_eq(cmd.switch_to, -1)


func test_lean_is_held_q_left_and_e_right() -> void:
	Input.action_press(&"lean_right")
	input.fill(cmd)
	assert_eq(cmd.lean, 1.0, "E leans right")
	Input.action_release(&"lean_right")
	_press(&"lean_left")
	input.fill(cmd)
	assert_eq(cmd.lean, 0.0, "a press alone isn't a hold: lean never toggles")
	Input.action_press(&"lean_left")
	input.fill(cmd)
	assert_eq(cmd.lean, -1.0, "Q leans left")
	Input.action_press(&"lean_right")
	input.fill(cmd)
	assert_eq(cmd.lean, 0.0, "both held cancel out")


func test_aim_is_held_by_default_and_toggles_with_the_setting() -> void:
	assert_false(controls.aim_toggle, "held by default (owner, 2026-10-18)")
	_press(&"aim")
	input.fill(cmd)
	assert_false(cmd.aim, "held: a press alone isn't a hold")
	var toggled := ControlsConfig.new()
	toggled.aim_toggle = true
	input.setup(toggled, 1.5)
	_press(&"aim")
	input.fill(cmd)
	assert_true(cmd.aim, "up after one press, the button already up")
	input.fill(cmd)
	assert_true(cmd.aim, "still up a tick later")
	_press(&"aim")
	input.fill(cmd)
	assert_false(cmd.aim, "a second press lowers it")


func test_holster_then_a_slot_in_one_tick_draws_the_slot_and_the_reverse_holsters() -> void:
	_press(&"holster")
	_press(&"slot_1")
	input.fill(cmd)
	assert_false(cmd.holster, "the later slot press wins")
	assert_eq(cmd.switch_to, 0)
	_press(&"slot_1")
	_press(&"holster")
	input.fill(cmd)
	assert_true(cmd.holster, "the later holster press wins")
	assert_eq(cmd.switch_to, -1)
	input.fill(cmd)
	assert_false(cmd.holster, "one-shot: gone the next tick")


func test_holster_then_the_wheel_in_one_tick_switches_and_the_reverse_holsters() -> void:
	_press(&"holster")
	_press(&"slot_next")
	input.fill(cmd, 0)
	assert_false(cmd.holster)
	assert_eq(cmd.switch_to, 1)
	_press(&"slot_next")
	_press(&"holster")
	input.fill(cmd, 0)
	assert_true(cmd.holster)
	assert_eq(cmd.switch_to, -1, "the wheel notch is dropped")
