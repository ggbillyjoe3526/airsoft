extends GutTest
## The key binding rules (game/input/key_bindings.gd), ported from the browser game's keyBindings.test.ts: a key belongs
## to one action, a taken key swaps or is removed, essential actions are never stranded, some keys can't be bound, and
## saved bindings are checked key by key.

var b: KeyBindings = null


func before_each() -> void:
	b = KeyBindings.new()


func after_each() -> void:
	InputMap.load_from_project_settings()


func _codes(action: StringName) -> Array:
	return Array(b.codes(action))


func test_defaults_match_the_input_map_in_project_godot() -> void:
	InputMap.load_from_project_settings()
	for action: StringName in KeyBindings.ACTIONS:
		var want: Array = []
		for e in InputMap.action_get_events(action):
			want.append(KeyBindings.code_of_event(e))
		assert_eq(_codes(action), want, "%s keeps project.godot's keys" % action)


func test_rebinding_the_main_key_keeps_the_second() -> void:
	assert_eq(b.rebind(&"move_forward", KEY_I), KeyBindings.Result.BOUND)
	assert_eq(_codes(&"move_forward"), [KEY_I, KEY_UP])
	assert_eq(b.action_of(KEY_W), &"")
	assert_eq(b.action_of(KEY_UP), &"move_forward")


func test_a_second_key_goes_in_slot_1_and_an_own_second_key_swaps_places() -> void:
	assert_eq(b.rebind(&"reload", KEY_J, 1), KeyBindings.Result.BOUND)
	assert_eq(_codes(&"reload"), [KEY_R, KEY_J])
	b.rebind(&"reload", KEY_J, 0)
	assert_eq(_codes(&"reload"), [KEY_J, KEY_R])
	assert_eq(b.rebind(&"reload", KEY_Y, 2), KeyBindings.Result.REFUSED_KEY, "two slots only")


func test_taking_another_actions_main_key_swaps_the_two() -> void:
	assert_eq(b.rebind(&"reload", KEY_C), KeyBindings.Result.SWAPPED)
	assert_eq(b.last_other, &"crouch")
	assert_eq(_codes(&"reload"), [KEY_C])
	assert_eq(_codes(&"crouch"), [KEY_R, KEY_CTRL], "crouch gets reload's old key in the slot it lost")


func test_walk_and_sprint_swap_on_shift() -> void:
	b.rebind(&"sprint", KEY_SHIFT)
	assert_eq(_codes(&"sprint"), [KEY_SHIFT])
	assert_eq(_codes(&"walk"), [KEY_ALT])


func test_taking_an_extra_key_just_removes_it_there() -> void:
	b.rebind(&"jump", KEY_UP)
	assert_eq(_codes(&"jump"), [KEY_UP])
	assert_eq(_codes(&"move_forward"), [KEY_W])
	assert_eq(b.action_of(KEY_SPACE), &"")


func test_a_second_key_taken_from_an_only_key_leaves_that_action_unbound_unless_essential() -> void:
	assert_eq(b.rebind(&"jump", KEY_Q, 1), KeyBindings.Result.SWAPPED)
	assert_eq(_codes(&"jump"), [KEY_SPACE, KEY_Q])
	assert_eq(_codes(&"lean_left"), [], "lean left is not essential")
	# fire's only button can't go to an empty second slot: fire would have none
	assert_eq(b.strands(&"aim", -MOUSE_BUTTON_LEFT, 1), &"fire")
	assert_eq(b.rebind(&"aim", -MOUSE_BUTTON_LEFT, 1), KeyBindings.Result.REFUSED_STRANDS)
	assert_eq(b.last_other, &"fire")
	assert_eq(_codes(&"fire"), [-MOUSE_BUTTON_LEFT], "a refusal changes nothing")
	# into the main slot it swaps as always, so fire keeps a button
	assert_eq(b.strands(&"aim", -MOUSE_BUTTON_LEFT, 0), &"")
	b.rebind(&"aim", -MOUSE_BUTTON_LEFT, 0)
	assert_eq(_codes(&"fire"), [-MOUSE_BUTTON_RIGHT])


func test_an_essential_move_key_is_never_stranded() -> void:
	b.unbind(&"move_forward", 1)
	assert_eq(b.rebind(&"jump", KEY_W, 1), KeyBindings.Result.REFUSED_STRANDS)
	assert_eq(_codes(&"move_forward"), [KEY_W])


func test_unbind_moves_the_second_key_up_and_keeps_the_last_key_of_an_essential_action() -> void:
	assert_true(b.unbind(&"move_forward", 0))
	assert_eq(_codes(&"move_forward"), [KEY_UP])
	assert_false(b.unbind(&"move_forward", 0), "the last key of an essential action")
	assert_true(b.unbind(&"jump", 0))
	assert_eq(_codes(&"jump"), [])
	assert_false(b.unbind(&"jump", 0), "nothing to clear")
	assert_false(b.unbind(&"pause", 0), "not an action the settings list")


func test_keys_that_cannot_be_bound_are_refused() -> void:
	for code: int in [KEY_ESCAPE, KEY_PRINT, KEY_PAUSE, KEY_F11, KEY_F3, KEY_META, KeyBindings.NONE,
			-MOUSE_BUTTON_WHEEL_LEFT]:
		assert_eq(b.rebind(&"jump", code), KeyBindings.Result.REFUSED_KEY, "code %d" % code)
	assert_eq(_codes(&"jump"), [KEY_SPACE])


func test_mouse_buttons_bind_like_keys() -> void:
	assert_eq(b.rebind(&"reload", -MOUSE_BUTTON_XBUTTON2), KeyBindings.Result.BOUND)
	assert_eq(_codes(&"reload"), [-MOUSE_BUTTON_XBUTTON2])
	var e := KeyBindings.event_of(-MOUSE_BUTTON_XBUTTON2) as InputEventMouseButton
	assert_eq(e.button_index, MOUSE_BUTTON_XBUTTON2)
	assert_eq(KeyBindings.code_of_event(e), -MOUSE_BUTTON_XBUTTON2)


func test_saved_bindings_round_trip() -> void:
	b.rebind(&"reload", KEY_X)
	b.unbind(&"jump", 0)
	var again := KeyBindings.new()
	assert_true(again.load_dict(JSON.parse_string(JSON.stringify(b.to_dict()))), "JSON turns the ints into floats")
	assert_eq(Array(again.codes(&"reload")), [KEY_X])
	assert_eq(Array(again.codes(&"jump")), [], "a cleared action stays cleared")
	assert_eq(Array(again.codes(&"move_forward")), [KEY_W, KEY_UP])


func test_malformed_saved_actions_keep_their_defaults() -> void:
	var data := {
		"reload": "R", "jump": [KEY_ESCAPE], "holster": [1.5], "fire_mode": [KEY_B, KEY_N, KEY_M],
		"aim": [KEY_Z], "nonsense": [KEY_Q],
	}
	assert_false(b.load_dict(data), "told that something was not used")
	assert_eq(_codes(&"reload"), [KEY_R])
	assert_eq(_codes(&"jump"), [KEY_SPACE])
	assert_eq(_codes(&"holster"), [KEY_3])
	assert_eq(_codes(&"fire_mode"), [KEY_B])
	assert_eq(_codes(&"aim"), [KEY_Z], "a good one is kept")
	assert_false(b.load_dict("not a dictionary"))
	assert_eq(_codes(&"aim"), [-MOUSE_BUTTON_RIGHT], "defaults after a bad set")


func test_a_key_on_two_actions_resets_everything_and_a_keyless_essential_action_keeps_its_default() -> void:
	assert_false(b.load_dict({"reload": [KEY_X], "jump": [KEY_X]}))
	assert_eq(_codes(&"reload"), [KEY_R])
	assert_false(b.load_dict({"fire": [], "reload": [KEY_X]}))
	assert_eq(_codes(&"fire"), [-MOUSE_BUTTON_LEFT], "fire keeps a button")
	assert_eq(_codes(&"reload"), [KEY_X], "the rest of the set stands")


func test_an_action_missing_from_a_save_gives_way_to_the_players_keys() -> void:
	# a save made before holster existed, in which the player put reload on 3
	assert_true(b.load_dict({"reload": [KEY_3]}))
	assert_eq(_codes(&"reload"), [KEY_3])
	assert_eq(_codes(&"holster"), [], "unbound until they pick a key")


func test_apply_writes_the_input_map_and_lets_go_of_a_held_action() -> void:
	b.rebind(&"reload", KEY_X)
	b.rebind(&"fire", -MOUSE_BUTTON_MIDDLE)
	Input.action_press(&"reload")
	b.apply()
	var events := InputMap.action_get_events(&"reload")
	assert_eq(events.size(), 1)
	assert_eq((events[0] as InputEventKey).physical_keycode, KEY_X as Key)
	assert_eq(InputMap.action_get_events(&"fire").size(), 1)
	assert_eq((InputMap.action_get_events(&"fire")[0] as InputEventMouseButton).button_index, MOUSE_BUTTON_MIDDLE)
	assert_false(Input.is_action_pressed(&"reload"), "a key held across a rebind doesn't stay pressed")
	# a press of the new key is the action now
	var press := InputEventKey.new()
	press.physical_keycode = KEY_X
	press.pressed = true
	assert_true(press.is_action(&"reload"))
	var old := InputEventKey.new()
	old.physical_keycode = KEY_R
	old.pressed = true
	assert_false(old.is_action(&"reload"))


func test_key_names_follow_the_layout_and_name_mouse_buttons() -> void:
	assert_ne(KeyNames.name_of(KEY_W), "")
	assert_eq(KeyNames.name_of(KeyBindings.NONE), KeyNames.NO_KEY)
	assert_eq(KeyNames.name_of(-MOUSE_BUTTON_LEFT), "Left mouse")
	assert_eq(KeyNames.name_of(-MOUSE_BUTTON_WHEEL_UP), "Wheel up")
	assert_eq(KeyNames.name_of(-MOUSE_BUTTON_XBUTTON2), "Mouse 5")
	assert_eq(KeyNames.describe(PackedInt32Array([KEY_SPACE, -MOUSE_BUTTON_RIGHT])).count(" / "), 1)
	assert_eq(KeyNames.describe(PackedInt32Array()), KeyNames.NO_KEY)


func test_a_hint_names_the_key_an_action_has_now() -> void:
	InputMap.load_from_project_settings()
	assert_eq(KeyNames.of_action(&"jump"), "Space")
	b.rebind(&"jump", KEY_X)
	b.apply()
	assert_eq(KeyNames.of_action(&"jump"), "X", "the vault prompt follows a rebind")
	assert_eq(KeyNames.of_action(&"no_such_action"), KeyNames.NO_KEY)
