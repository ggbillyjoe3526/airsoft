extends GutTest
## BP2 (the 0.1 Dev 2 bug pass): one test or more for each bug it fixed.


func _wheel_input() -> PlayerInput:
	var input := PlayerInput.new()
	add_child_autofree(input)
	input.setup(ControlsConfig.new(), 1.5)
	input.active = true
	return input


func _notch(input: PlayerInput, button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	input._unhandled_input(event)


func test_a_wheel_notch_with_the_replica_holstered_draws_the_other_replica_not_a_bomb() -> void:
	var input := _wheel_input()
	var hand := Grenades.Hand.new()
	hand.carry(1, 1)
	var cmd := PlayerCommand.new()
	_notch(input, MOUSE_BUTTON_WHEEL_DOWN)
	input.fill(cmd, 1, hand, true)
	assert_eq(cmd.ready_grenade, Grenade.Kind.NONE, "no smoke taken from the holster")
	assert_eq(cmd.switch_to, 0, "past the bombs, round to the first replica")
	_notch(input, MOUSE_BUTTON_WHEEL_UP)
	input.fill(cmd, 0, hand, true)
	assert_eq(cmd.ready_grenade, Grenade.Kind.NONE, "no flash taken from the holster")
	assert_eq(cmd.switch_to, 1, "back past the bombs to the pistol")
	input.active = false


func test_a_wheel_notch_with_a_bomb_in_hand_still_steps_the_bombs() -> void:
	var input := _wheel_input()
	var hand := Grenades.Hand.new()
	hand.carry(1, 1)
	hand.readied = Grenade.Kind.SMOKE
	var cmd := PlayerCommand.new()
	_notch(input, MOUSE_BUTTON_WHEEL_DOWN)
	# a bomb in hand puts the replica down, so the armament reads holstered
	input.fill(cmd, 1, hand, true)
	assert_eq(cmd.ready_grenade, Grenade.Kind.FLASH, "smoke on to the flash")
	input.active = false
