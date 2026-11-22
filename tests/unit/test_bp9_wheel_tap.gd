extends GutTest
## BP9: a tap of the order wheel's key (a Spotted) while you are busy. A tap is told by its time alone, so the mouse
## following someone no longer turns it into a side order; the trigger, aim and the mouse wheel stay yours until the
## key is held past a tap, so a tap stops no burst; and the view turns by what the mouse moved during the tap.

const ACTIONS: Array[StringName] = [&"order_wheel", &"fire", &"aim", &"slot_next"]

var input: PlayerInput = null
var controls: ControlsConfig = null
var cmd: PlayerCommand = PlayerCommand.new()


func before_each() -> void:
	controls = ControlsConfig.new()
	input = PlayerInput.new()
	input.setup(controls, 1.5)
	add_child_autofree(input)
	input.active = true


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


## The wheel's key has been down a second: past any tap.
func _hold_past_a_tap() -> void:
	input.wheel().opened_ms -= 1000


func test_a_tap_with_the_mouse_moving_spots_whatever_button_the_pointer_reached() -> void:
	var layout := OrderWheelLayout.new(controls)
	for pick: ControlsConfig.WheelPick in [ControlsConfig.WheelPick.HOVER, ControlsConfig.WheelPick.CLICK]:
		controls.wheel_pick = pick
		for slot in controls.wheel_orders.size():
			var at := layout.box(slot).get_center() / controls.wheel_gain
			_event(&"order_wheel", true)
			_move(at.x, at.y)
			assert_eq(input.wheel().pick(), slot, "the pointer is on button %d" % slot)
			_event(&"order_wheel", false)
			input.fill(cmd)
			assert_true(cmd.ping and cmd.ping_spot, "a Spotted (button %d, pick %d)" % [slot, pick])
			assert_eq(cmd.squad_order, SquadOrder.Kind.NONE, "no order (button %d)" % slot)
			assert_false(cmd.ping_move or cmd.ping_watch or cmd.mag_hand_off, "nor that button's ping or hand-off")


func test_a_tap_turns_the_view_as_the_mouse_moves_and_past_a_tap_the_pointer_takes_it() -> void:
	var counts := Vector2(120.0, -40.0)
	_move(counts.x, counts.y)
	var free_yaw := input.view_yaw
	var free_pitch := input.view_pitch
	assert_ne(free_yaw, 0.0)
	input.face(0.0)
	_event(&"order_wheel", true)
	_move(counts.x * 0.5, counts.y * 0.5)
	assert_almost_eq(input.view_yaw, free_yaw * 0.5, 1e-6, "the key down: the view turns at once (no hitch, 2026-11-22)")
	_move(counts.x * 0.5, counts.y * 0.5)
	_event(&"order_wheel", false)
	assert_almost_eq(input.view_yaw, free_yaw, 1e-6, "a tap: the view as if the key was never down")
	assert_almost_eq(input.view_pitch, free_pitch, 1e-6)
	input.fill(cmd)
	assert_almost_eq(cmd.yaw, free_yaw, 1e-6, "and the Spotted goes out along it")
	assert_true(cmd.ping_spot)
	input.face(0.0)
	_event(&"order_wheel", true)
	_move(counts.x, counts.y)
	_hold_past_a_tap()
	_move(counts.x, counts.y)
	_event(&"order_wheel", false)
	assert_almost_eq(input.view_yaw, 0.0, 1e-6, "held: the mouse was the wheel's, the view is back where it was")
	assert_almost_eq(input.view_pitch, 0.0, 1e-6)


func test_a_tap_with_the_trigger_held_stops_no_burst() -> void:
	_event(&"fire", true)
	input.fill(cmd)
	assert_true(cmd.fire)
	_event(&"order_wheel", true)
	input.fill(cmd)
	assert_true(cmd.fire, "the key just down: still firing")
	_event(&"order_wheel", false)
	input.fill(cmd)
	assert_true(cmd.fire, "the tap over: still firing, no fresh pull needed")
	assert_true(cmd.ping_spot, "and the tap spotted")
	input.fill(cmd)
	assert_true(cmd.fire)


func test_a_pull_inside_a_tap_is_a_shot_and_aim_and_the_mouse_wheel_go_on() -> void:
	_event(&"order_wheel", true)
	_event(&"fire", true)
	_event(&"aim", true)
	_event(&"slot_next", true)
	_event(&"slot_next", false)
	assert_true(input.wheel().open, "the pull picked nothing off a wheel not yet up")
	input.fill(cmd)
	assert_true(cmd.fire, "a shot")
	assert_true(cmd.aim, "the sight comes up")
	assert_ne(cmd.switch_to, -1, "the mouse wheel switches")
	_event(&"order_wheel", false)
	input.fill(cmd)
	assert_true(cmd.ping_spot, "the tap spots")
	assert_true(cmd.fire, "the trigger still held")
	assert_true(cmd.aim)


func test_held_past_a_tap_the_wheel_takes_the_trigger_until_it_is_let_go() -> void:
	_event(&"fire", true)
	_event(&"order_wheel", true)
	input.fill(cmd)
	assert_true(cmd.fire, "inside a tap: firing")
	_hold_past_a_tap()
	input.fill(cmd)
	assert_false(cmd.fire, "the wheel is up: the trigger is its own, with no event in between")
	_event(&"order_wheel", false)
	input.fill(cmd)
	assert_false(cmd.fire, "closed with the trigger still held: no shot")
	assert_true(cmd.ping_spot, "Hover: let go in the middle spots")
	_event(&"fire", false)
	input.fill(cmd)
	_event(&"fire", true)
	input.fill(cmd)
	assert_true(cmd.fire, "a fresh pull fires")


func test_a_wheel_shut_inside_a_tap_by_a_pause_or_being_out_holds_no_trigger_back() -> void:
	_event(&"fire", true)
	_event(&"order_wheel", true)
	input.allow_orders(true, false)
	assert_false(input.wheel().open)
	input.fill(cmd)
	assert_true(cmd.fire, "the wheel never came up: the trigger was never its own")
	assert_false(cmd.ping, "and it gave nothing")
	input.allow_orders(true, true)
	_event(&"order_wheel", false)
	input.fill(cmd)
	assert_false(cmd.ping, "the release after spots nothing")


func test_a_wheel_shut_inside_a_tap_gives_the_view_the_turn_the_mouse_made() -> void:
	var counts := Vector2(90.0, 30.0)
	_move(counts.x, counts.y)
	var free_yaw := input.view_yaw
	var free_pitch := input.view_pitch
	# A pause (or being hit) with the key just down.
	input.face(0.0)
	_event(&"order_wheel", true)
	_move(counts.x, counts.y)
	input.allow_orders(true, false)
	assert_almost_eq(input.view_yaw, free_yaw, 1e-6, "shut by a pause inside a tap: the mouse was never the wheel's")
	assert_almost_eq(input.view_pitch, free_pitch, 1e-6)
	input.allow_orders(true, true)
	_event(&"order_wheel", false)
	assert_almost_eq(input.view_yaw, free_yaw, 1e-6, "and the release after turns nothing more")
	# The key let go unseen (the window lost it) inside a tap.
	input.face(0.0)
	_event(&"order_wheel", true)
	_move(counts.x, counts.y)
	Input.action_release(&"order_wheel")
	input.fill(cmd)
	assert_false(input.wheel().open)
	assert_almost_eq(input.view_yaw, free_yaw, 1e-6, "let go unseen inside a tap: the same")
	assert_false(cmd.ping, "giving nothing")
	# Held past a tap, then shut: the mouse was the wheel's, the view stays.
	input.face(0.0)
	_event(&"order_wheel", true)
	_hold_past_a_tap()
	_move(counts.x, counts.y)
	input.allow_orders(true, false)
	assert_almost_eq(input.view_yaw, 0.0, 1e-6, "shut past a tap: the view stays")
	input.allow_orders(true, true)


func test_the_wheel_is_not_drawn_inside_a_tap_wherever_the_pointer_went() -> void:
	var hud_wheel := HudOrderWheel.new()
	add_child_autofree(hud_wheel)
	hud_wheel.setup(HudConfig.new(), controls, Color.WHITE)
	var outcome := SquadOrders.Outcome.new()
	_event(&"order_wheel", true)
	_move(200.0, -29.0)
	var opened := input.wheel().opened_ms
	var tap_ms := roundi(controls.wheel_tap * 1000.0)
	hud_wheel.update(input.wheel(), SquadOrder.Kind.NONE, outcome, 0, 0.016, opened + tap_ms - 1)
	assert_false(hud_wheel.draws_wheel(), "inside a tap: a tap never flashes the wheel up")
	hud_wheel.update(input.wheel(), SquadOrder.Kind.NONE, outcome, 0, 0.016, opened + tap_ms)
	assert_true(hud_wheel.draws_wheel(), "held past a tap: up, the pointer where the flick took it")
	assert_eq(hud_wheel.lit_slice(), 1, "on Follow Me")
