extends GutTest
## The Armory as UI concept B v2 `armory.png` (UR5): the level track's dots, the four level cards from your level on,
## the arrows and a dot browsing them, and the cards kept inside the levels.

var pool: Pool
var table: LevelTable
var settings: Settings


func before_all() -> void:
	pool = Pool.read_file()
	table = LevelTable.read_file(pool)


func before_each() -> void:
	settings = Settings.new()


func after_each() -> void:
	await wait_process_frames(2)


func _page(xp: int) -> ArmoryPage:
	var p := Progress.new(table)
	p.from_dict({"xp": xp})
	p.grant_reached()
	var page := ArmoryPage.new(settings, p, Records.new(), pool)
	add_child_autofree(page)
	return page


func _shown(page: ArmoryPage) -> Array[int]:
	var out: Array[int] = []
	for r in page.facts().rows:
		if page.track().row(r.number).visible:
			out.append(r.number)
	return out


func test_four_cards_show_from_your_level_and_the_next_is_edged() -> void:
	var page := _page(920)
	assert_eq(_shown(page), [3, 4, 5, 6] as Array[int])
	var next := page.track().row(4).get_theme_stylebox("panel") as StyleBoxFlat
	assert_eq(next.border_color, GameTheme.ACCENT, "the next level is edged in teal")
	assert_lt((page.track().row(5).find_child("Items", true, false) as Control).modulate.a, 1.0, "a locked level dims")
	assert_eq((page.track().row(3).find_child("Items", true, false) as Control).modulate.a, 1.0)


func test_the_arrows_browse_and_stop_at_the_ends() -> void:
	var page := _page(920)
	page.on_arrow().pressed.emit()
	assert_eq(_shown(page), [4, 5, 6, 7] as Array[int])
	for i in 20:
		page.on_arrow().pressed.emit()
	assert_eq(page.track().first(), page.track().last_first(), "the last four levels")
	assert_true(page.on_arrow().disabled)
	assert_false(page.back_arrow().disabled)
	for i in 20:
		page.back_arrow().pressed.emit()
	assert_eq(_shown(page), [0, 1, 2, 3] as Array[int])
	assert_true(page.back_arrow().disabled)


func test_a_click_on_a_dot_shows_that_level_first() -> void:
	var page := _page(920)
	await wait_process_frames(2)
	var dots := page.summary().bar()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = dots.dot_position(1)
	dots._gui_input(click)
	assert_eq(_shown(page), [1, 2, 3, 4] as Array[int])
	click.position = dots.dot_position(10)
	dots._gui_input(click)
	assert_eq(page.track().first(), page.track().last_first(), "a level near the end keeps four cards")


func test_the_dots_fill_to_your_level_and_on_by_the_xp_earned() -> void:
	var page := _page(920)
	var dots := page.summary().bar()
	assert_almost_eq(dots.fraction(), 120.0 / 500.0, 0.001)
	await wait_process_frames(2)
	assert_eq(dots.dot_at(dots.dot_position(4).x + 2.0), 4)
	assert_eq(dots.dot_at(-100.0), 0)


func test_a_level_with_many_items_puts_them_two_to_a_row() -> void:
	var page := _page(100)
	var kit := page.track().row(0).find_child("Items", true, false)
	assert_true(kit is GridContainer, "the starting kit's five items")
	assert_eq((kit as GridContainer).columns, 2)
	assert_true(page.track().row(4).find_child("Items", true, false) is VBoxContainer)
