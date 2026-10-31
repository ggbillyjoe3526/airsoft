extends GutTest
## Squad order keys and the order wheel's input (SO3; the browser game's orderWheel.test.ts and playerInput.ts): an
## order key fills the next tick's squad order once; held, the wheel's key moves its own pointer instead of the view
## (slices clockwise from the top, within reach, nothing in the middle), feet still move, fire and aim need a fresh
## press after; Hover gives the pointed order on letting go, a click on one either way; the wheel closes giving nothing
## on pause, once you are out and in practice. The wheel's data, the saved Hover / Click and the radio click's rule.

const ACTIONS: Array[StringName] = [&"order_wheel", &"order_follow", &"fire", &"aim", &"move_forward", &"ping"]

var input: PlayerInput = null
var controls: ControlsConfig = ControlsConfig.new()
var cmd: PlayerCommand = PlayerCommand.new()


func before_each() -> void:
	controls.wheel_pick = ControlsConfig.WheelPick.HOVER
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


func _tap(action: StringName) -> void:
	_event(action, true)
	_event(action, false)


func _move(dx: float, dy: float) -> void:
	var e := InputEventMouseMotion.new()
	e.screen_relative = Vector2(dx, dy)
	input._unhandled_input(e)


## Opens the wheel and points (by mouse counts) at the order `dx, dy` way.
func _point(dx: float, dy: float) -> void:
	_event(&"order_wheel", true)
	_move(dx, dy)


# --- the pointer's math (orderWheel.test.ts) ---

func test_slices_are_numbered_clockwise_from_the_top() -> void:
	assert_eq(OrderWheelPointer.slice(Vector2(0, -50), 4, 10.0), 0, "up")
	assert_eq(OrderWheelPointer.slice(Vector2(50, 0), 4, 10.0), 1, "right")
	assert_eq(OrderWheelPointer.slice(Vector2(0, 50), 4, 10.0), 2, "down")
	assert_eq(OrderWheelPointer.slice(Vector2(-50, 0), 4, 10.0), 3, "left")


func test_each_order_owns_an_equal_slice_round_its_own_direction() -> void:
	assert_eq(OrderWheelPointer.slice(Vector2(30, -50), 4, 10.0), 0, "up and a little right: still the top")
	assert_eq(OrderWheelPointer.slice(Vector2(50, -49), 4, 10.0), 1, "just past the diagonal: the right")
	assert_eq(OrderWheelPointer.slice(Vector2(-50, -51), 4, 10.0), 0)
	assert_eq(OrderWheelPointer.slice(Vector2(-50, -40), 5, 10.0), 4, "five slices: the top left one")


func test_the_middle_points_at_nothing() -> void:
	assert_eq(OrderWheelPointer.slice(Vector2.ZERO, 4, 10.0), OrderWheelPointer.NONE)
	assert_eq(OrderWheelPointer.slice(Vector2(6, -6), 4, 10.0), OrderWheelPointer.NONE)
	assert_eq(OrderWheelPointer.slice(Vector2(0, -50), 0, 10.0), OrderWheelPointer.NONE, "no orders")


func test_the_pointer_stays_within_reach_and_opens_again_in_the_middle() -> void:
	var w := OrderWheelPointer.new(90.0, 24.0, 4)
	assert_eq(w.pick(), OrderWheelPointer.NONE, "closed")
	w.start()
	assert_eq(w.pick(), OrderWheelPointer.NONE, "opens in the middle")
	w.move(Vector2(0, -1000))
	assert_almost_eq(w.at.y, -90.0, 1e-4, "a flick stops at the reach")
	assert_eq(w.pick(), 0)
	w.move(Vector2(0, 90))
	assert_eq(w.pick(), OrderWheelPointer.NONE, "coming back is no more than the reach")
	w.move(Vector2(80, 0))
	w.close()
	assert_eq(w.pick(), OrderWheelPointer.NONE)
	w.start()
	assert_eq(w.at, Vector2.ZERO)


# --- the keys ---

func test_an_order_key_fills_the_next_ticks_order_once() -> void:
	var keyed: Array[SquadOrder.Kind] = []
	for key: StringName in [&"order_follow", &"order_hold", &"order_regroup"]:
		_tap(key)
		input.fill(cmd)
		keyed.append(cmd.squad_order)
		assert_false(cmd.order_from_wheel, "%s is a key, not the wheel (so again it cancels)" % key)
		input.fill(cmd)
		assert_eq(cmd.squad_order, SquadOrder.Kind.NONE, "%s counts for one tick" % key)
	assert_eq(keyed, [SquadOrder.Kind.FOLLOW, SquadOrder.Kind.HOLD, SquadOrder.Kind.REGROUP])


func test_the_keys_and_the_wheel_do_nothing_with_nobody_to_order() -> void:
	input.allow_orders(false, true)
	_tap(&"order_follow")
	_point(0.0, -200.0)
	assert_false(input.wheel().open, "practice: no wheel")
	_event(&"order_wheel", false)
	input.fill(cmd)
	assert_eq(cmd.squad_order, SquadOrder.Kind.NONE)


# --- the wheel ---

func test_held_the_wheel_takes_the_mouse_and_letting_go_gives_the_order_pointed_at() -> void:
	Input.action_press(&"move_forward")
	_point(173.0, -100.0)
	assert_true(input.wheel().open)
	assert_almost_eq(input.view_yaw, 0.0, 1e-6, "the view stays put")
	assert_almost_eq(input.view_pitch, 0.0, 1e-6)
	input.fill(cmd)
	assert_eq(cmd.forward, 1.0, "feet still move")
	assert_eq(cmd.squad_order, SquadOrder.Kind.NONE, "nothing given while it is open")
	_event(&"order_wheel", false)
	assert_false(input.wheel().open)
	input.fill(cmd)
	assert_eq(cmd.squad_order, SquadOrder.Kind.HOLD, "the upper right slice: Hold Here")
	assert_true(cmd.order_from_wheel)
	_move(10.0, 0.0)
	assert_lt(input.view_yaw, 0.0, "closed, the mouse turns the view again")


func test_the_pointer_moves_by_the_gain_times_the_sensitivity() -> void:
	controls.sensitivity = 2.0
	_point(30.0, 0.0)
	controls.sensitivity = 1.0
	assert_almost_eq(input.wheel().at.x, 30.0 * controls.wheel_gain * 2.0, 1e-4)


func test_letting_go_in_the_middle_or_in_click_mode_gives_nothing() -> void:
	_point(2.0, 0.0)
	_event(&"order_wheel", false)
	input.fill(cmd)
	assert_eq(cmd.squad_order, SquadOrder.Kind.NONE, "in the middle")
	controls.wheel_pick = ControlsConfig.WheelPick.CLICK
	_point(0.0, -200.0)
	_event(&"order_wheel", false)
	input.fill(cmd)
	assert_eq(cmd.squad_order, SquadOrder.Kind.NONE, "Click: letting go gives nothing")


func test_a_click_gives_the_order_either_way_and_is_no_shot() -> void:
	for pick: ControlsConfig.WheelPick in [ControlsConfig.WheelPick.CLICK, ControlsConfig.WheelPick.HOVER]:
		controls.wheel_pick = pick
		_point(-120.0, 165.0)
		_event(&"fire", true)
		assert_false(input.wheel().open, "the click closed it")
		input.fill(cmd)
		assert_eq(cmd.squad_order, SquadOrder.Kind.TEAM_PLAN, "the lower left slice: Team Plan")
		assert_true(cmd.order_from_wheel)
		assert_false(cmd.fire, "the click is the wheel's")
		_event(&"order_wheel", false)
		input.fill(cmd)
		assert_false(cmd.fire, "still held: no shot")
		_event(&"fire", false)
		input.fill(cmd)
		_event(&"fire", true)
		input.fill(cmd)
		assert_true(cmd.fire, "a fresh pull fires")
		_event(&"fire", false)


func test_fire_and_aim_need_a_fresh_press_after_the_wheel() -> void:
	_point(2.0, 0.0)
	_event(&"fire", true)
	_event(&"aim", true)
	input.fill(cmd)
	assert_false(cmd.fire, "a click in the middle is not a shot")
	assert_false(cmd.aim, "nor raises the sight")
	assert_true(input.wheel().open, "nor gives anything")
	_event(&"order_wheel", false)
	input.fill(cmd)
	assert_false(cmd.fire, "held through the wheel: still no shot")
	assert_false(cmd.aim)
	_event(&"fire", false)
	_event(&"aim", false)
	input.fill(cmd)
	_event(&"aim", true)
	input.fill(cmd)
	assert_true(cmd.aim, "a fresh press aims")


func test_the_mouse_wheel_switches_nothing_while_the_order_wheel_is_open() -> void:
	_point(0.0, 0.0)
	_tap(&"slot_next")
	_event(&"order_wheel", false)
	input.fill(cmd)
	assert_eq(cmd.switch_to, -1)


func test_a_ping_press_while_the_wheel_is_open_pings_nothing() -> void:
	_point(0.0, 0.0)
	_tap(&"ping")
	_event(&"order_wheel", false)
	input.fill(cmd)
	assert_false(cmd.ping, "the wheel holds the view still, so no ping where it was left")
	_tap(&"ping")
	input.fill(cmd)
	assert_true(cmd.ping, "the wheel closed, a press pings")


func test_the_wheel_closes_giving_nothing_on_pause_and_once_you_are_out() -> void:
	_point(0.0, -200.0)
	input.release()
	assert_false(input.wheel().open, "pause or focus loss")
	input.active = true
	input.fill(cmd)
	assert_eq(cmd.squad_order, SquadOrder.Kind.NONE)
	_point(0.0, -200.0)
	input.allow_orders(true, false)
	assert_false(input.wheel().open, "out")
	_event(&"order_wheel", false)
	input.fill(cmd)
	assert_eq(cmd.squad_order, SquadOrder.Kind.NONE)
	_point(0.0, -200.0)
	assert_false(input.wheel().open, "out: it doesn't open again")
	_tap(&"order_follow")
	input.fill(cmd)
	assert_eq(cmd.squad_order, SquadOrder.Kind.FOLLOW, "out, a key still asks (refused: next round)")


func test_the_wheel_closes_giving_nothing_when_its_key_is_let_go_unseen() -> void:
	_point(0.0, -200.0)
	Input.action_release(&"order_wheel")
	input.fill(cmd)
	assert_false(input.wheel().open)
	input.fill(cmd)
	assert_eq(cmd.squad_order, SquadOrder.Kind.NONE)


# --- data, settings and the radio click ---

func test_the_wheels_orders_keys_and_names_are_data() -> void:
	var c := ControlsConfig.new()
	assert_eq(c.wheel_pick, ControlsConfig.WheelPick.HOVER, "Hover by default")
	assert_eq(c.wheel_orders.size(), c.wheel_keys.size())
	assert_eq(c.wheel_orders.size(), c.wheel_labels.size())
	assert_has(c.wheel_orders, SquadOrder.Kind.TEAM_PLAN, "Team Plan included")
	var po := FileAccess.get_file_as_string("res://game/ui/text/en.po")
	for i in c.wheel_orders.size():
		assert_true(po.contains('msgid "%s"' % c.wheel_labels[i]), "%s has its name" % c.wheel_labels[i])
		var key := c.wheel_keys[i]
		if key != &"":
			assert_has(KeyBindings.ACTIONS, key, "%s is rebindable" % key)
	for action: StringName in [&"order_wheel", &"order_follow", &"order_hold", &"order_regroup"]:
		assert_has(KeyBindings.ACTIONS, action)
		assert_true(po.contains('msgid "%s"' % KeyBindingList.label_key(action)), "%s is named" % action)


func test_hover_or_click_is_saved_and_an_old_settings_file_loads() -> void:
	var s := Settings.new(PlayTuning.new())
	assert_eq(s.wheel_pick, ControlsConfig.WheelPick.HOVER)
	s.wheel_pick = ControlsConfig.WheelPick.CLICK
	var again := Settings.new(s.tuning)
	again.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	assert_eq(again.wheel_pick, ControlsConfig.WheelPick.CLICK, "JSON round trip")
	SettingsApply.apply_controls(again)
	assert_eq(again.tuning.controls.wheel_pick, ControlsConfig.WheelPick.CLICK, "applied to the controls")
	again.from_dict({"sensitivity": 1.5})
	assert_eq(again.wheel_pick, ControlsConfig.WheelPick.HOVER, "a file from before the wheel: Hover")
	again.from_dict({"wheel_pick": 7})
	assert_eq(again.wheel_pick, ControlsConfig.WheelPick.HOVER, "a bad value keeps the default")
	var keys := KeyBindings.new()
	assert_true(keys.load_dict({"reload": [KEY_F]}), "an old save with F taken loads")
	assert_eq(Array(keys.codes(&"order_follow")), [], "F stays the player's")
	assert_eq(Array(keys.codes(&"order_wheel")), [KEY_Z])


func test_the_radio_click_is_for_an_order_of_yours_taken() -> void:
	var o := SquadOrders.Outcome.new()
	o.record(0, SquadOrder.Kind.FOLLOW, SquadOrders.Notice.NONE)
	assert_true(SimAudio.order_taken(o, 0), "taken")
	assert_false(SimAudio.order_taken(o, 1), "someone else's")
	o.record(0, SquadOrder.Kind.NONE, SquadOrders.Notice.CANCELLED)
	assert_false(SimAudio.order_taken(o, 0), "cancelled")
	o.record(0, SquadOrder.Kind.NONE, SquadOrders.Notice.NOBODY)
	assert_false(SimAudio.order_taken(o, 0), "nobody to take it")
	o.record(0, SquadOrder.Kind.HOLD, SquadOrders.Notice.NOT_NOW)
	assert_false(SimAudio.order_taken(o, 0), "refused")
	o.record(0, SquadOrder.Kind.NONE, SquadOrders.Notice.ON_PLAN)
	assert_false(SimAudio.order_taken(o, 0), "Team Plan with none in force")
