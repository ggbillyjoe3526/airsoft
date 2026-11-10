extends GutTest
## ButtonPress (the owner, 2026-11-10): every button pressed with the mouse or a key dips in and springs back while an
## accent outline flashes round it; with Reduced motion only the outline shows. The clicks go through the viewport as
## the mouse's would (UF2's lesson), not as an emitted `pressed`.

var _was_installed: bool = false


func before_all() -> void:
	_was_installed = get_tree().node_added.is_connected(ButtonPress._on_node_added)
	ButtonPress.install(get_tree())


func after_all() -> void:
	if not _was_installed and get_tree().node_added.is_connected(ButtonPress._on_node_added):
		get_tree().node_added.disconnect(ButtonPress._on_node_added)


func _button(words: String = "SWAP") -> Button:
	var view := SubViewport.new()
	view.size = Vector2i(800, 400)
	add_child_autofree(view)
	var root := Control.new()
	root.theme = GameTheme.get_theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.add_child(root)
	var b := Button.new()
	b.text = words
	b.position = Vector2(300.0, 150.0)
	b.size = Vector2(120.0, 34.0)
	root.add_child(b)
	return b


func _push(view: Viewport, at: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = at
	e.global_position = at
	view.push_input(e)


func _click(target: Control) -> void:
	var view := target.get_viewport()
	var at := target.get_global_rect().get_center()
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	view.push_input(move)
	await wait_process_frames(1)
	_push(view, at, true)
	await wait_process_frames(1)
	_push(view, at, false)


func _hooks(b: BaseButton) -> int:
	var n := 0
	for c: Dictionary in b.button_down.get_connections():
		if (c["callable"] as Callable).get_method() == &"_on_down":
			n += 1
	return n


func test_a_click_dips_the_button_and_flashes_its_outline() -> void:
	var b := _button()
	await wait_process_frames(1)
	assert_null(ButtonPress.ring_of(b), "no ring before the first press")
	var before := b.get_child_count()
	await _click(b)
	var ring := ButtonPress.ring_of(b)
	assert_not_null(ring, "pressed: the ring is made")
	assert_eq(b.get_child_count(), before, "the ring is internal: the button's own children are unchanged")
	assert_true(ring.visible and ring.playing())
	await wait_seconds(ButtonPress.DIP_IN * 0.8)
	assert_lt(b.scale.x, 1.0, "dipped in")
	assert_gte(b.scale.x, ButtonPress.PRESS_SCALE - 0.001, "never past PRESS_SCALE")
	assert_eq(b.pivot_offset_ratio, ButtonPress.PIVOT, "about its middle")
	await wait_seconds(ButtonPress.DIP_IN + ButtonPress.RING_FADE + 0.1)
	assert_almost_eq(b.scale.x, 1.0, 0.0001, "back to its size")
	assert_false(ring.visible, "the outline is gone")
	assert_false(ring.playing())


func test_a_big_card_dips_no_more_than_max_dip() -> void:
	var b := _button()
	b.size = Vector2(500.0, 300.0)
	await wait_process_frames(1)
	var low := 1.0
	await _click(b)
	for i: int in 12:
		low = minf(low, b.scale.x)
		await wait_process_frames(1)
	assert_gte(low, 1.0 - 2.0 * ButtonPress.MAX_DIP / 500.0 - 0.001, "at most MAX_DIP px at a side")
	assert_lt(low, 1.0)


func test_reduced_motion_keeps_the_outline_and_still_button() -> void:
	var b := _button()
	await wait_process_frames(1)
	var ring := ButtonPress.new()
	b.add_child(ring, false, Node.INTERNAL_MODE_BACK)
	ring.play(true)
	assert_true(ring.visible, "the outline shows")
	for i: int in 6:
		await wait_process_frames(1)
		assert_eq(b.scale, Vector2.ONE, "no dip with reduced motion")


func test_a_key_press_plays_it_too() -> void:
	var b := _button()
	await wait_process_frames(1)
	b.grab_focus()
	var key := InputEventAction.new()
	key.action = &"ui_accept"
	key.pressed = true
	b.get_viewport().push_input(key)
	await wait_process_frames(1)
	assert_not_null(ButtonPress.ring_of(b), "Enter on a focused button presses it as a click does")
	key.pressed = false
	b.get_viewport().push_input(key)


func test_a_button_hooks_once_however_often_it_enters_the_tree() -> void:
	var b := _button()
	await wait_process_frames(1)
	assert_eq(_hooks(b), 1)
	var parent := b.get_parent()
	parent.remove_child(b)
	parent.add_child(b)
	assert_eq(_hooks(b), 1, "moved: still one hook")


func test_a_disabled_button_stays_still() -> void:
	var b := _button()
	b.disabled = true
	await wait_process_frames(1)
	await _click(b)
	assert_null(ButtonPress.ring_of(b))
	assert_eq(b.scale, Vector2.ONE)


func test_buttons_already_in_the_tree_are_hooked_at_install() -> void:
	var b := _button()
	await wait_process_frames(1)
	b.button_down.disconnect(b.button_down.get_connections()[0]["callable"] as Callable)
	assert_eq(_hooks(b), 0)
	ButtonPress.install(get_tree())
	assert_eq(_hooks(b), 1)


func test_a_button_freed_mid_press_leaves_nothing_behind() -> void:
	var b := _button()
	await wait_process_frames(1)
	await _click(b)
	var ring := ButtonPress.ring_of(b)
	assert_not_null(ring)
	b.get_parent().remove_child(b)
	b.free()
	await wait_process_frames(2)
	assert_false(is_instance_valid(ring), "the ring goes with its button")


func test_a_button_pressed_twice_quickly_ends_at_full_size_with_one_ring() -> void:
	var b := _button()
	await wait_process_frames(1)
	await _click(b)
	await wait_process_frames(2)
	await _click(b)
	var rings := 0
	for c: Node in b.get_children(true):
		if c is ButtonPress:
			rings += 1
	assert_eq(rings, 1, "the second press reuses the ring")
	await wait_seconds(ButtonPress.DIP_IN + ButtonPress.RING_FADE + 0.15)
	assert_almost_eq(b.scale.x, 1.0, 0.0001)
	assert_false(ButtonPress.ring_of(b).visible)


func test_a_button_taken_out_of_the_tree_mid_press_is_not_left_dipped() -> void:
	var b := _button()
	await wait_process_frames(1)
	await _click(b)
	await wait_seconds(ButtonPress.DIP_IN * 0.8)
	var parent := b.get_parent()
	parent.remove_child(b)
	await wait_seconds(0.5)
	parent.add_child(b)
	await wait_seconds(0.5)
	assert_almost_eq(b.scale.x, 1.0, 0.0001, "back at full size after returning")
	assert_false(ButtonPress.ring_of(b).visible, "no outline stuck on")


func test_a_button_hidden_mid_press_comes_back_at_full_size() -> void:
	var b := _button()
	await wait_process_frames(1)
	await _click(b)
	b.hide()
	await wait_seconds(0.6)
	b.show()
	assert_almost_eq(b.scale.x, 1.0, 0.0001)
	assert_false(ButtonPress.ring_of(b).visible)


func test_the_ring_never_takes_the_mouse_and_a_click_beside_the_button_misses_it() -> void:
	var b := _button()
	var hits: Array[int] = [0]
	b.pressed.connect(func() -> void: hits[0] += 1)
	await wait_process_frames(1)
	await _click(b)
	assert_eq(hits[0], 1)
	var ring := ButtonPress.ring_of(b)
	assert_eq(ring.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(ring.focus_mode, Control.FOCUS_NONE)
	var at := b.get_global_rect().position - Vector2(3.0, 3.0) # inside the drawn outline, outside the button
	_push(b.get_viewport(), at, true)
	await wait_process_frames(1)
	_push(b.get_viewport(), at, false)
	await wait_process_frames(1)
	assert_eq(hits[0], 1, "the outline is not part of the button")


func test_toggle_and_check_buttons_play_and_keep_their_state() -> void:
	var b := _button()
	b.toggle_mode = true
	await wait_process_frames(1)
	await _click(b)
	assert_true(b.button_pressed, "toggled on by the click")
	assert_not_null(ButtonPress.ring_of(b))
	await wait_seconds(0.5)
	await _click(b)
	assert_false(b.button_pressed, "toggled off by the second")
	var c := CheckButton.new()
	c.text = "X"
	c.position = Vector2(300.0, 250.0)
	c.size = Vector2(160.0, 34.0)
	b.get_parent().add_child(c)
	await wait_process_frames(1)
	await _click(c)
	assert_true(c.button_pressed)
	assert_not_null(ButtonPress.ring_of(c))


func test_a_button_in_a_container_that_re_sorts_mid_press_still_ends_full_size() -> void:
	var b := _button()
	var box := VBoxContainer.new()
	var parent := b.get_parent()
	parent.add_child(box)
	b.reparent(box)
	await wait_process_frames(2)
	await _click(b)
	await wait_process_frames(2)
	box.queue_sort()
	await wait_seconds(ButtonPress.DIP_IN + ButtonPress.RING_FADE + 0.2)
	assert_almost_eq(b.scale.x, 1.0, 0.0001)
	assert_false(ButtonPress.ring_of(b).visible)


func test_a_menu_card_is_pressed_without_disturbing_its_children() -> void:
	var card := MenuCard.new()
	var view := SubViewport.new()
	view.size = Vector2i(800, 400)
	add_child_autofree(view)
	view.add_child(card)
	card.position = Vector2(100.0, 100.0)
	card.size = Vector2(300.0, 200.0)
	await wait_process_frames(2)
	var before := card.get_child_count()
	await _click(card)
	assert_eq(card.get_child_count(), before)
	assert_not_null(ButtonPress.ring_of(card))


func test_a_button_on_a_paused_tree_still_plays_and_finishes() -> void:
	var b := _button()
	b.process_mode = Node.PROCESS_MODE_ALWAYS
	await wait_process_frames(1)
	get_tree().paused = true
	await _click(b)
	var ring := ButtonPress.ring_of(b)
	var dipped := false
	for i: int in 30:
		await wait_process_frames(1)
		dipped = dipped or b.scale.x < 1.0
	get_tree().paused = false
	assert_not_null(ring)
	assert_true(dipped, "the pause menu's buttons dip while the game is paused")
	await wait_seconds(0.5)
	assert_almost_eq(b.scale.x, 1.0, 0.0001)
	assert_false(ring.visible)


func test_the_game_leaving_the_tree_takes_its_hook_with_it() -> void:
	ButtonPress.install(get_tree())
	ButtonPress.uninstall(get_tree())
	assert_false(get_tree().node_added.is_connected(ButtonPress._on_node_added), "no hook left behind")
	var b := _button()
	await wait_process_frames(1)
	assert_eq(_hooks(b), 0, "a button added after has no hook")
	ButtonPress.install(get_tree())
