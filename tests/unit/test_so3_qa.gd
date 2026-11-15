extends GutTest
## QA for SO3 (order keys, the order wheel's input, the radio click): the input edge cases the player will hit (a mouse
## button as the wheel's key, the key held across a pause, aiming and reloading as it opens, alt-tab, an empty wheel, a
## click pick with the key still down) and the radio click end to end through SimAudio.on_order.

const ACTIONS: Array[StringName] = [&"order_wheel", &"order_follow", &"fire", &"aim", &"reload", &"move_forward"]

var input: PlayerInput = null
var controls: ControlsConfig = ControlsConfig.new()
var cmd: PlayerCommand = PlayerCommand.new()
var _saved_wheel_events: Array[InputEvent] = []


func before_each() -> void:
	_saved_wheel_events = InputMap.action_get_events(&"order_wheel")
	input = PlayerInput.new()
	input.setup(controls, 1.5)
	add_child_autofree(input)
	input.active = true


func after_each() -> void:
	for action: StringName in ACTIONS:
		Input.action_release(action)
	InputMap.action_erase_events(&"order_wheel")
	for e in _saved_wheel_events:
		InputMap.action_add_event(&"order_wheel", e)


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


func test_a_mouse_button_works_as_the_wheels_key() -> void:
	InputMap.action_erase_events(&"order_wheel")
	var middle := InputEventMouseButton.new()
	middle.button_index = MOUSE_BUTTON_MIDDLE
	InputMap.action_add_event(&"order_wheel", middle)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_MIDDLE
	down.pressed = true
	Input.action_press(&"order_wheel")
	input._unhandled_input(down)
	assert_true(input.wheel().open, "the button opens it")
	_move(200.0, -29.0)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_MIDDLE
	up.pressed = false
	Input.action_release(&"order_wheel")
	input._unhandled_input(up)
	assert_false(input.wheel().open)
	input.fill(cmd)
	assert_eq(cmd.squad_order, SquadOrder.Kind.FOLLOW, "letting go of the button gave the order pointed at")
	assert_almost_eq(input.view_yaw, 0.0, 1e-6, "the view stayed put")


func test_the_key_held_across_a_pause_does_not_reopen_the_wheel() -> void:
	_event(&"order_wheel", true)
	_move(0.0, -200.0)
	input.release() # the pause menu opens
	assert_false(input.wheel().open)
	input.active = true # resumed, Z still down
	input.fill(cmd)
	assert_false(input.wheel().open, "no press, no wheel")
	assert_eq(cmd.squad_order, SquadOrder.Kind.NONE)
	_move(100.0, 0.0)
	assert_ne(input.view_yaw, 0.0, "the mouse turns the view again")
	_event(&"order_wheel", false)
	input.fill(cmd)
	assert_eq(cmd.squad_order, SquadOrder.Kind.NONE, "letting go after the pause gives nothing")
	assert_false(cmd.fire, "and no shot")


func test_alt_tab_with_the_key_held_then_a_fresh_press_opens_it_in_the_middle() -> void:
	_event(&"order_wheel", true)
	_move(0.0, -200.0)
	input.release() # focus out: play pauses
	input.active = true
	_event(&"order_wheel", false)
	_event(&"order_wheel", true)
	assert_true(input.wheel().open)
	assert_eq(input.wheel().at, Vector2.ZERO, "a new wheel starts in the middle")
	_event(&"order_wheel", false)
	input.fill(cmd)
	assert_eq(cmd.squad_order, SquadOrder.Kind.NONE)


func test_opening_the_wheel_while_aiming_keeps_the_sight_up_and_a_new_aim_press_waits() -> void:
	_event(&"aim", true)
	_event(&"order_wheel", true)
	input.fill(cmd)
	assert_true(cmd.aim, "aim held before the wheel stays up (the browser game)")
	_event(&"aim", false)
	_event(&"aim", true)
	input.fill(cmd)
	assert_false(cmd.aim, "a press while it is open waits")
	_event(&"order_wheel", false)
	input.fill(cmd)
	assert_false(cmd.aim, "still waiting for a fresh press")
	_event(&"aim", false)
	input.fill(cmd)
	_event(&"aim", true)
	input.fill(cmd)
	assert_true(cmd.aim)


func test_a_reload_pressed_before_or_during_the_wheel_still_reloads() -> void:
	_event(&"reload", true)
	_event(&"order_wheel", true)
	input.fill(cmd)
	assert_true(cmd.reload, "pressed before the wheel opened")
	_event(&"reload", false)
	_event(&"reload", true)
	input.fill(cmd)
	assert_true(cmd.reload, "the keys that move you go on while it is open")


func test_a_click_pick_with_the_key_still_down_gives_one_order_and_letting_go_adds_none() -> void:
	_event(&"order_wheel", true)
	_move(200.0, -29.0)
	_event(&"fire", true)
	_event(&"fire", false)
	input.fill(cmd)
	assert_eq(cmd.squad_order, SquadOrder.Kind.FOLLOW)
	_event(&"order_wheel", false)
	input.fill(cmd)
	assert_eq(cmd.squad_order, SquadOrder.Kind.NONE, "the key's release after the click gives nothing more")
	assert_false(cmd.fire)


func test_an_order_key_pressed_with_the_wheel_open_is_still_given_when_letting_go_in_the_middle() -> void:
	_event(&"order_wheel", true)
	_event(&"order_follow", true)
	_event(&"order_follow", false)
	_event(&"order_wheel", false)
	input.fill(cmd)
	assert_eq(cmd.squad_order, SquadOrder.Kind.FOLLOW, "an order key is immediate, wheel open or not")
	assert_false(cmd.order_from_wheel)


func test_a_wheel_with_no_orders_opens_and_closes_giving_nothing() -> void:
	var bare := ControlsConfig.new()
	bare.wheel_orders = [] as Array[SquadOrder.Kind]
	bare.wheel_keys = [] as Array[StringName]
	bare.wheel_labels = PackedStringArray()
	input.setup(bare, 1.5)
	_event(&"order_wheel", true)
	_move(0.0, -200.0)
	_event(&"fire", true)
	_event(&"fire", false)
	_event(&"order_follow", true)
	_event(&"order_wheel", false)
	input.fill(cmd)
	assert_eq(cmd.squad_order, SquadOrder.Kind.NONE)


func test_a_huge_sensitivity_flick_stays_on_the_wheel() -> void:
	controls.sensitivity = 1000.0
	_event(&"order_wheel", true)
	_move(1.0e6, 1.0e6)
	controls.sensitivity = 1.0
	var half := OrderWheelLayout.new(controls).half_extent()
	assert_lte(absf(input.wheel().at.x), half.x + 0.001)
	assert_lte(absf(input.wheel().at.y), half.y + 0.001)
	assert_false(is_nan(input.wheel().at.x))


func test_the_radio_click_plays_once_in_your_ear_for_a_taken_order_only() -> void:
	var audio := SimAudio.new()
	add_child_autofree(audio)
	audio.setup(SoundConfig.new(), [] as Array[StringName], BodyConfig.new(), null, null)
	var o := SquadOrders.Outcome.new()
	var heard := func() -> int:
		var n := 0
		for v in audio._own:
			if v.stream != null and (audio._streams[&"radio_ack"] as Array).has(v.stream):
				n += 1
		return n
	audio.on_order(o, 0)
	assert_eq(heard.call(), 0, "no order yet")
	o.record(1, SquadOrder.Kind.FOLLOW, SquadOrders.Notice.NONE)
	audio.on_order(o, 0)
	assert_eq(heard.call(), 0, "a teammate's order is not heard as yours")
	o.record(0, SquadOrder.Kind.NONE, SquadOrders.Notice.NOT_NOW)
	audio.on_order(o, 0)
	assert_eq(heard.call(), 0, "a refusal plays nothing")
	o.record(0, SquadOrder.Kind.FOLLOW, SquadOrders.Notice.NONE)
	audio.on_order(o, 0)
	assert_eq(heard.call(), 1, "taken: one click")
	var voice: AudioStreamPlayer = null
	for v in audio._own:
		if v.stream != null and (audio._streams[&"radio_ack"] as Array).has(v.stream):
			voice = v
	assert_eq(voice.bus, SimAudio.BUS_INTERFACE, "on the Interface bus")
	audio.on_order(o, 0)
	assert_eq(heard.call(), 1, "the same outcome read again plays nothing more")


func test_a_second_wheel_key_pressed_while_open_keeps_the_pointer() -> void:
	_event(&"order_wheel", true)
	_move(0.0, -200.0)
	var at := input.wheel().at
	var again := InputEventAction.new()
	again.action = &"order_wheel"
	again.pressed = true
	input._unhandled_input(again)
	assert_true(input.wheel().open)
	assert_eq(input.wheel().at, at, "a second key bound to the wheel doesn't recentre it")
