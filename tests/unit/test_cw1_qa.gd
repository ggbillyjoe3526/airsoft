extends GutTest
## QA's hunt for CW1 (Spotted, Cover me, the new wheel): tap and hold timing on the wheel key, Click against Hover,
## the wheel shut by a pause or by orders going away, odd wheel numbers, Cover me meeting other orders or an out
## helper or giver, and the spot book's out-of-range ids.

const ACTIONS: Array[StringName] = [&"order_wheel", &"fire", &"aim"]

var input: PlayerInput = null
var controls: ControlsConfig = ControlsConfig.new()
var cmd: PlayerCommand = PlayerCommand.new()


func before_each() -> void:
	controls.wheel_pick = ControlsConfig.WheelPick.HOVER
	controls.wheel_tap = ControlsConfig.new().wheel_tap # a test that makes every press a hold doesn't leak it
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


# --- the wheel key: tap, hold, Click, Hover ---

func test_a_quick_tap_spots_in_click_mode_too() -> void:
	controls.wheel_pick = ControlsConfig.WheelPick.CLICK
	_event(&"order_wheel", true)
	_event(&"order_wheel", false)
	input.fill_order(cmd)
	assert_true(cmd.ping_spot)
	assert_true(cmd.ping)


func test_a_long_hold_on_the_middle_spots_nothing_in_click_mode() -> void:
	controls.wheel_pick = ControlsConfig.WheelPick.CLICK
	controls.wheel_tap = 0.0
	_event(&"order_wheel", true)
	_event(&"order_wheel", false)
	input.fill_order(cmd)
	assert_false(cmd.ping_spot, "held past a tap: Click mode gives nothing on letting go")


## BP9: a tap with the mouse moving (following someone with the sight) left the circle inside the tap and gave the
## button it reached (Follow Me), or nothing between the columns. A tap spots, wherever the pointer went.
func test_a_quick_tap_that_moved_onto_a_button_still_spots_and_gives_no_order() -> void:
	for pick: ControlsConfig.WheelPick in [ControlsConfig.WheelPick.HOVER, ControlsConfig.WheelPick.CLICK]:
		controls.wheel_pick = pick
		_event(&"order_wheel", true)
		_move(200.0, -29.0)
		_event(&"order_wheel", false)
		input.fill_order(cmd)
		assert_true(cmd.ping and cmd.ping_spot, "a tap is a Spotted (%d)" % pick)
		assert_eq(cmd.squad_order, SquadOrder.Kind.NONE, "and no order")


func test_a_quick_tap_between_the_columns_spots_too() -> void:
	_event(&"order_wheel", true)
	_move(0.0, -90.0)
	_event(&"order_wheel", false)
	input.fill_order(cmd)
	assert_true(cmd.ping_spot)
	assert_eq(cmd.squad_order, SquadOrder.Kind.NONE)


func test_held_past_a_tap_the_button_reached_inside_it_is_given_in_hover() -> void:
	_event(&"order_wheel", true)
	_move(200.0, -29.0)
	input.wheel().opened_ms -= 1000
	_event(&"order_wheel", false)
	input.fill_order(cmd)
	assert_false(cmd.ping_spot, "held: no spot")
	assert_eq(cmd.squad_order, SquadOrder.Kind.FOLLOW, "a flick made at once still lands once the wheel is up")


func test_a_tap_with_no_teammates_to_order_spots_nothing() -> void:
	input.allow_orders(false, true)
	_event(&"order_wheel", true)
	_event(&"order_wheel", false)
	input.fill_order(cmd)
	assert_false(cmd.ping_spot)
	assert_false(cmd.ping)


func test_pausing_with_the_wheel_open_gives_no_spot_and_the_release_after_gives_none() -> void:
	_event(&"order_wheel", true)
	input.allow_orders(true, false)
	assert_false(input.wheel().open)
	input.allow_orders(true, true)
	_event(&"order_wheel", false)
	input.fill_order(cmd)
	assert_false(cmd.ping_spot, "a release after the wheel was shut spots nothing")
	assert_false(cmd.ping)


func test_a_spot_by_click_on_the_middle_does_not_also_spot_on_the_keys_release() -> void:
	controls.wheel_pick = ControlsConfig.WheelPick.CLICK
	_event(&"order_wheel", true)
	input.wheel().opened_ms -= 1000 # held past a tap: the wheel is up
	_event(&"fire", true)
	input.fill_order(cmd)
	assert_true(cmd.ping_spot)
	var cmd2 := PlayerCommand.new()
	_event(&"order_wheel", false)
	_event(&"fire", false)
	input.fill_order(cmd2)
	assert_false(cmd2.ping_spot, "one spot")
	assert_false(cmd2.fire, "and no shot")


func test_a_spot_latch_does_not_leak_into_a_later_go_there() -> void:
	_event(&"order_wheel", true)
	_event(&"order_wheel", false)
	input.fill_order(cmd)
	assert_true(cmd.ping_spot)
	var next := PlayerCommand.new()
	input.fill_order(next)
	assert_false(next.ping_spot, "counts for one tick")
	assert_false(next.ping)


# --- odd wheel numbers ---

func test_a_wheel_with_no_rows_or_no_pitch_still_picks_something_valid() -> void:
	for rows: int in [0, -3, 1]:
		var c := ControlsConfig.new()
		c.wheel_rows = rows
		var l := OrderWheelLayout.new(c)
		for p: Vector2 in [Vector2(200, 0), Vector2(-200, 50), Vector2(0, 0), Vector2(300, -900)]:
			var r := l.pick(p)
			assert_true(r == OrderWheelLayout.NONE or r == OrderWheelLayout.SPOT or (r >= 0 and r < l.count),
					"rows %d, %s -> %d" % [rows, p, r])
	var flat := ControlsConfig.new()
	flat.wheel_row_pitch = 0.0
	var l2 := OrderWheelLayout.new(flat)
	var r2 := l2.pick(Vector2(200, 10))
	assert_true(r2 == OrderWheelLayout.NONE or (r2 >= 0 and r2 < l2.count), "zero pitch: %d" % r2)


func test_a_wheel_with_fewer_orders_than_buttons_gives_nothing_on_the_spare_ones() -> void:
	controls.wheel_orders.resize(2)
	_event(&"order_wheel", true)
	input.wheel().opened_ms -= 1000 # held past a tap: the wheel is up
	_move(-200.0, 87.0)
	_event(&"order_wheel", false)
	input.fill_order(cmd)
	assert_eq(cmd.squad_order, SquadOrder.Kind.NONE)
	assert_false(cmd.ping_spot)


# --- the spot book ---

func test_the_spot_book_answers_ids_it_does_not_hold() -> void:
	var cs: Array[Character] = [Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())]
	var s := Spots.new(cs, SimTuning.load_default().pings)
	for id: int in [-1, 7, 99999]:
		assert_false(s.is_spotted(id, 0.0))
		assert_eq(s.spotted_by(id), -1)
		assert_eq(s.time_left(id, 0.0), 0.0)
	var empty: Array[Character] = []
	var none := Spots.new(empty, SimTuning.load_default().pings)
	assert_false(none.is_spotted(0, 0.0))
