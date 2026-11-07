extends GutTest
## QA probes for the UR5 Armory: window sizes, empty levels, dev content, the cap, levelling off, arrow focus.

var pool: Pool
var table: LevelTable


func before_all() -> void:
	pool = Pool.read_file()
	table = LevelTable.read_file(pool)


func after_each() -> void:
	await wait_process_frames(2)


func _page(xp: int, off: bool = false, dev: bool = false, win: Vector2 = Vector2(1920.0, 1080.0)) -> ArmoryPage:
	var settings := Settings.new()
	settings.dev.disable_levelling = off
	settings.dev.dev_content = dev
	var p := Progress.new(table)
	p.from_dict({"xp": xp})
	p.grant_reached()
	var holder := Control.new()
	holder.size = win
	add_child_autofree(holder)
	var page := ArmoryPage.new(settings, p, Records.new(), pool)
	page.offset_left = NavRail.WIDTH
	holder.add_child(page)
	return page


func _fit(page: ArmoryPage) -> Vector2:
	var margin := page.get_child(1) as Control
	return margin.get_combined_minimum_size()


func test_small_window_fits_for_every_level() -> void:
	for xp: int in [0, 100, 920, 4000, 99999]:
		var page := _page(xp)
		await wait_process_frames(2)
		var need := _fit(page)
		var avail := Vector2(1920.0 - NavRail.WIDTH, 1080.0)
		assert_lte(need.y, avail.y, "xp %d: needs %s of %s" % [xp, need, avail])
		assert_lte(need.x, avail.x, "xp %d wide: needs %s of %s" % [xp, need, avail])


func test_small_window_fits_with_dev_content() -> void:
	for xp: int in [0, 920]:
		var page := _page(xp, false, true)
		await wait_process_frames(2)
		var need := _fit(page)
		assert_lte(need.y, 1080.0, "dev xp %d needs %s" % [xp, need])


func test_levelling_off_fits_and_opens_on_last() -> void:
	var page := _page(0, true)
	await wait_process_frames(2)
	assert_lte(_fit(page).y, 1080.0)
	assert_eq(page.track().first(), page.track().last_first())
	assert_true(page.on_arrow().disabled)
	assert_false(page.back_arrow().disabled)


func test_huge_window_cards_do_not_overflow() -> void:
	var page := _page(920, false, false, Vector2(3840.0, 2160.0))
	await wait_process_frames(3)
	var margin := page.get_child(1) as Control
	assert_lte(margin.get_combined_minimum_size().y, 2160.0)
	for r in page.facts().rows:
		var card := page.track().row(r.number)
		if card.visible:
			assert_lte(card.get_global_rect().end.x, 3840.0 + 1.0, "card %d inside window" % r.number)
			assert_lte(card.get_global_rect().end.y, 2160.0 + 1.0, "card %d bottom" % r.number)


func test_every_level_has_items_or_is_reported() -> void:
	var page := _page(0)
	var empty: Array[int] = []
	for r in page.facts().rows:
		if r.items.is_empty():
			empty.append(r.number)
	var dev := _page(0, false, true)
	var empty_dev: Array[int] = []
	for r in dev.facts().rows:
		if r.items.is_empty():
			empty_dev.append(r.number)
	gut.p("empty levels (dev off): %s, dev on: %s" % [empty, empty_dev])
	pass_test("reported")


func test_level_zero_dots_and_cards() -> void:
	var page := _page(0)
	await wait_process_frames(2)
	assert_eq(page.track().first(), 0)
	assert_true(page.back_arrow().disabled)
	assert_eq(page.summary().bar().fraction(), 0.0)


func test_exact_level_boundary_fraction() -> void:
	# xp exactly at level 1 threshold: into 0
	var page := _page(100)
	assert_eq(page.summary().bar().fraction(), 0.0)


func test_arrow_focus_when_it_becomes_disabled() -> void:
	var page := _page(920)
	await wait_process_frames(2)
	var on := page.on_arrow()
	on.grab_focus()
	assert_true(on.has_focus())
	for i in 10:
		on.pressed.emit()
	await wait_process_frames(2)
	assert_true(on.disabled)
	var owner_focus := get_viewport().gui_get_focus_owner()
	gut.p("focus after disable: %s" % [owner_focus])
	assert_not_null(owner_focus, "keyboard focus is lost when the focused arrow disables")


func test_arrows_and_the_dots_are_keyboard_focusable() -> void:
	var page := _page(920)
	assert_ne(page.back_arrow().focus_mode, Control.FOCUS_NONE)
	# BP6: the track takes focus too, left and right picking a level (test_bp6_menus)
	assert_eq(page.summary().bar().focus_mode, Control.FOCUS_ALL, "the dots have a keyboard path")


func test_dot_click_ignores_right_button_and_release() -> void:
	var page := _page(920)
	await wait_process_frames(2)
	var dots := page.summary().bar()
	var before := page.track().first()
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT
	ev.pressed = true
	ev.position = dots.dot_position(0)
	dots._gui_input(ev)
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	dots._gui_input(ev)
	assert_eq(page.track().first(), before)


func test_no_orphans_after_free() -> void:
	var before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var page := _page(920)
	await wait_process_frames(2)
	page.get_parent().queue_free()
	await wait_process_frames(3)
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), before)


func test_dots_with_one_count_and_far_level() -> void:
	var d := ArmoryDots.new(1, 5, 0.5)
	add_child_autofree(d)
	d.size = Vector2(400.0, 64.0)
	await wait_process_frames(2)
	assert_eq(d.dot_at(10.0), 0)
	var e := ArmoryDots.new(3, 9, 2.0)
	add_child_autofree(e)
	e.size = Vector2(400.0, 64.0)
	await wait_process_frames(2)
	assert_eq(e.fraction(), 1.0)
