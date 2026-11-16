extends GutTest
## Squad order keys and the order wheel's input (SO3; CW1's shape): an order key fills the next tick's squad order once;
## held, the wheel's key moves its own pointer over the wheel instead of the view (Spotted in the middle, the right
## column's buttons then the left's, top to bottom, nothing between the columns, kept on the wheel), feet still move,
## fire and aim need a fresh press after; Hover gives what the pointer is on on letting go, a click either way, a tap
## spots either way; the wheel closes giving nothing on pause, once you are out and in practice. The wheel's data, the
## saved Hover / Click and the radio click's rule.

const ACTIONS: Array[StringName] = [&"order_wheel", &"order_follow", &"fire", &"aim", &"move_forward", &"ping"]

var input: PlayerInput = null
var controls: ControlsConfig = ControlsConfig.new()
var cmd: PlayerCommand = PlayerCommand.new()


func before_each() -> void:
	controls.wheel_pick = ControlsConfig.WheelPick.HOVER
	# Every press of the wheel's key here is a hold (the wheel up at once) unless a test sets the tap's time back.
	controls.wheel_tap = 0.0
	input = PlayerInput.new()
	input.setup(controls, 1.5)
	add_child_autofree(input)
	input.active = true


func after_each() -> void:
	controls.wheel_tap = ControlsConfig.new().wheel_tap
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


# --- the pointer's math (OrderWheelLayout, CW1) ---

## The default wheel's layout: buttons 236 x 48, 58 apart, the columns' inner edges 100 px out, the circle 66 px out.
func _layout() -> OrderWheelLayout:
	return OrderWheelLayout.new(ControlsConfig.new())


func test_the_buttons_are_the_right_column_then_the_left_each_top_to_bottom() -> void:
	var l := _layout()
	assert_eq(l.count, 8)
	assert_eq([l.pick(Vector2(200, -87)), l.pick(Vector2(200, -29)), l.pick(Vector2(200, 29)),
			l.pick(Vector2(200, 87))], [0, 1, 2, 3], "the right column, top to bottom")
	assert_eq([l.pick(Vector2(-200, -87)), l.pick(Vector2(-200, -29)), l.pick(Vector2(-200, 29)),
			l.pick(Vector2(-200, 87))], [4, 5, 6, 7], "the left column, top to bottom")
	for i in l.count:
		var mid := l.box(i).get_center()
		assert_eq(l.pick(mid), i, "the middle of button %d is on it" % i)
		assert_eq(l.box(i).size, Vector2(236, 48), "every button one size")


func test_the_middle_is_spotted_and_between_the_columns_is_nothing() -> void:
	var l := _layout()
	assert_eq(l.pick(Vector2.ZERO), OrderWheelLayout.SPOT)
	assert_eq(l.pick(Vector2(40, -40)), OrderWheelLayout.SPOT, "inside the circle")
	assert_eq(l.pick(Vector2(5, -100)), OrderWheelLayout.NONE, "straight above the circle")
	assert_eq(l.pick(Vector2(-10, 105)), OrderWheelLayout.NONE, "straight below it")
	assert_eq(l.pick(Vector2(60, -100)), 0, "above the circle and to the right: the top right button's row")
	assert_eq(l.pick(Vector2(120, -5)), 1, "beside the circle a little high: the second row")


func test_a_row_reaches_on_past_the_columns_ends_and_across_the_gaps() -> void:
	var l := _layout()
	assert_eq(l.pick(Vector2(200, -400)), 0, "far above: the top row")
	assert_eq(l.pick(Vector2(200, 400)), 3, "far below: the bottom row")
	assert_eq(l.pick(Vector2(200, -58)), 1, "in the gap between the first two rows: the row below the line")


func test_the_pointer_stays_on_the_wheel_and_opens_again_in_the_middle() -> void:
	var w := OrderWheelPointer.new(_layout())
	assert_eq(w.pick(), OrderWheelPointer.NONE, "closed")
	w.start(1000)
	assert_eq(w.pick(), OrderWheelPointer.SPOT, "opens on Spotted")
	w.move(Vector2(5000, 0))
	assert_almost_eq(w.at.x, 336.0, 1e-4, "a flick stops at the column's outer edge")
	assert_eq(w.pick(), 2, "on the middle line: the row below it")
	w.move(Vector2(0, -5000))
	assert_almost_eq(w.at.y, -111.0, 1e-4, "and at the top of the column")
	assert_eq(w.pick(), 0)
	w.move(Vector2(-336, 111))
	assert_eq(w.pick(), OrderWheelPointer.SPOT, "coming back is no more than the wheel")
	w.close()
	assert_eq(w.pick(), OrderWheelPointer.NONE)
	w.start(2000)
	assert_eq(w.at, Vector2.ZERO)


func test_a_tap_is_a_short_press_wherever_the_pointer_went() -> void:
	var w := OrderWheelPointer.new(_layout())
	w.start(1000)
	assert_false(w.held(1100, 0.2), "0.1 s: a tap")
	assert_true(w.held(1200, 0.2), "0.2 s: held")
	w.move(Vector2(200, 0))
	assert_false(w.held(1050, 0.2), "out of the circle inside a tap: a tap all the same (BP9)")
	assert_true(w.held(1200, 0.2), "and held once the time is up")
	w.close()
	assert_false(w.held(5000, 0.2), "closed")


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
	_point(200.0, -29.0)
	assert_true(input.wheel().open)
	assert_almost_eq(input.view_yaw, 0.0, 1e-6, "the view stays put")
	assert_almost_eq(input.view_pitch, 0.0, 1e-6)
	input.fill(cmd)
	assert_eq(cmd.forward, 1.0, "feet still move")
	assert_eq(cmd.squad_order, SquadOrder.Kind.NONE, "nothing given while it is open")
	_event(&"order_wheel", false)
	assert_false(input.wheel().open)
	input.fill(cmd)
	assert_eq(cmd.squad_order, SquadOrder.Kind.FOLLOW, "the right column's second button: Follow Me")
	assert_true(cmd.order_from_wheel)
	_move(10.0, 0.0)
	assert_lt(input.view_yaw, 0.0, "closed, the mouse turns the view again")


func test_the_pointer_moves_by_the_gain_times_the_sensitivity() -> void:
	controls.sensitivity = 2.0
	_point(30.0, 0.0)
	controls.sensitivity = 1.0
	assert_almost_eq(input.wheel().at.x, 30.0 * controls.wheel_gain * 2.0, 1e-4)


func test_letting_go_between_the_columns_or_in_click_mode_gives_nothing() -> void:
	_point(5.0, -100.0)
	_event(&"order_wheel", false)
	input.fill(cmd)
	assert_eq(cmd.squad_order, SquadOrder.Kind.NONE, "straight above the circle")
	assert_false(cmd.ping, "and no ping")
	controls.wheel_pick = ControlsConfig.WheelPick.CLICK
	_point(200.0, -29.0)
	_event(&"order_wheel", false)
	input.fill(cmd)
	assert_eq(cmd.squad_order, SquadOrder.Kind.NONE, "Click: letting go gives nothing")


func test_a_tap_of_the_key_spots_either_way_and_a_hold_in_the_middle_only_on_hover() -> void:
	controls.wheel_tap = ControlsConfig.new().wheel_tap
	for pick: ControlsConfig.WheelPick in [ControlsConfig.WheelPick.HOVER, ControlsConfig.WheelPick.CLICK]:
		controls.wheel_pick = pick
		_tap(&"order_wheel")
		input.fill(cmd)
		assert_true(cmd.ping and cmd.ping_spot, "a tap is a Spotted (%d)" % pick)
		assert_false(cmd.ping_move or cmd.ping_watch or cmd.ping_on_map, "and nothing else")
		assert_eq(cmd.squad_order, SquadOrder.Kind.NONE)
		input.fill(cmd)
		assert_false(cmd.ping, "for one tick")
	controls.wheel_pick = ControlsConfig.WheelPick.HOVER
	_event(&"order_wheel", true)
	input.wheel().opened_ms -= 1000
	_event(&"order_wheel", false)
	input.fill(cmd)
	assert_true(cmd.ping_spot, "Hover: held and let go in the middle spots")
	controls.wheel_pick = ControlsConfig.WheelPick.CLICK
	_event(&"order_wheel", true)
	input.wheel().opened_ms -= 1000
	_event(&"order_wheel", false)
	input.fill(cmd)
	assert_false(cmd.ping, "Click: held and let go in the middle gives nothing")
	_event(&"order_wheel", true)
	input.wheel().opened_ms -= 1000
	_event(&"fire", true)
	input.fill(cmd)
	assert_true(cmd.ping_spot, "Click: a click on Spotted spots")
	_event(&"order_wheel", false)
	_event(&"fire", false)


func test_cover_me_is_on_the_wheel_and_picked_there_is_its_order() -> void:
	_point(200.0, 29.0)
	assert_eq(input.wheel().pick(), 2, "the right column's third")
	_event(&"order_wheel", false)
	input.fill(cmd)
	assert_eq(cmd.squad_order, SquadOrder.Kind.COVER)
	assert_true(cmd.order_from_wheel)
	assert_false(cmd.ping or cmd.mag_hand_off, "an order, not a ping")


func test_a_free_button_gives_nothing() -> void:
	controls.wheel_orders[7] = SquadOrder.Kind.NONE
	controls.wheel_labels[7] = ""
	_point(-200.0, 87.0)
	assert_eq(input.wheel().pick(), 7)
	_event(&"order_wheel", false)
	input.fill(cmd)
	controls.wheel_orders[7] = SquadOrder.Kind.REGROUP
	controls.wheel_labels[7] = "ORDER_REGROUP"
	assert_eq(cmd.squad_order, SquadOrder.Kind.NONE)
	assert_false(cmd.ping or cmd.mag_hand_off, "nothing at all")


func test_a_click_gives_the_order_either_way_and_is_no_shot() -> void:
	for pick: ControlsConfig.WheelPick in [ControlsConfig.WheelPick.CLICK, ControlsConfig.WheelPick.HOVER]:
		controls.wheel_pick = pick
		_point(-200.0, -87.0)
		_event(&"fire", true)
		assert_false(input.wheel().open, "the click closed it")
		input.fill(cmd)
		assert_eq(cmd.squad_order, SquadOrder.Kind.TEAM_PLAN, "the left column's top button: Team Plan")
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
	_point(5.0, -100.0)
	_event(&"fire", true)
	_event(&"aim", true)
	input.fill(cmd)
	assert_false(cmd.fire, "a click on nothing is not a shot")
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
	_point(5.0, -100.0)
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
	assert_eq(c.wheel_orders.size(), c.wheel_rows * 2, "a button for every place on the wheel")
	assert_has(c.wheel_orders, SquadOrder.Kind.TEAM_PLAN, "Team Plan included")
	var po := FileAccess.get_file_as_string("res://game/ui/text/en.po")
	assert_true(po.contains('msgid "%s"' % c.wheel_spot_label), "Spotted has its name")
	for i in c.wheel_orders.size():
		assert_eq(c.wheel_labels[i].is_empty(), c.wheel_orders[i] == SquadOrder.Kind.NONE, "only a free button is blank")
		if not c.wheel_labels[i].is_empty():
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
