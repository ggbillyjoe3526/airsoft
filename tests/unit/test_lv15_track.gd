extends GutTest
## The Armory's level track ten levels at a time (owner, 2026-11-10; LV15): the starting kit and levels 1 to 10 on the
## first page, 11 to 15 on the second, with ‹ › arrows at the track's ends to turn the pages; the track opens on the page
## with your next level, a click or a key on the second page picks its levels, and the keys turn the page at its ends.

const CYBER := "000019"

var pool: Pool
var table: LevelTable


func before_all() -> void:
	pool = Pool.read_file()
	table = LevelTable.read_file(pool)


func after_each() -> void:
	await wait_process_frames(2)


func _page(xp: int) -> ArmoryPage:
	var p := Progress.new(table)
	p.from_dict({"xp": xp})
	p.grant_reached()
	var page := ArmoryPage.new(Settings.new(), p, Records.new(), pool)
	add_child_autofree(page)
	return page


func _key(action: StringName) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	return ev


func test_a_new_player_sees_the_kit_and_levels_1_to_10_with_the_arrows_to_turn_on() -> void:
	var page := _page(0)
	await wait_process_frames(2)
	var dots := page.summary().bar()
	assert_eq(dots.page_count(), 2, "15 levels, ten to a page")
	assert_eq([dots.page(), dots.first_shown(), dots.last_shown()], [0, 0, 10])
	assert_true(page.summary().page_back_arrow().visible and page.summary().page_on_arrow().visible)
	assert_true(page.summary().page_back_arrow().disabled, "nothing before the starting kit")
	assert_false(page.summary().page_on_arrow().disabled)
	assert_eq(dots.dot_at(dots.dot_position(10).x + 2.0), 10)


func test_the_arrow_turns_to_levels_11_to_15_and_back() -> void:
	var page := _page(0)
	await wait_process_frames(2)
	var dots := page.summary().bar()
	var turned: Array[int] = []
	dots.page_changed.connect(func(p: int) -> void: turned.append(p))
	page.summary().page_on_arrow().pressed.emit()
	assert_eq([dots.page(), dots.first_shown(), dots.last_shown()], [1, 11, 15])
	assert_eq(turned, [1] as Array[int])
	assert_false(page.summary().page_back_arrow().disabled)
	assert_true(page.summary().page_on_arrow().disabled, "no page after the cap's")
	assert_eq(dots.dot_at(-100.0), 11, "a click left of the page picks its first level, never one off it")
	assert_eq(dots.dot_at(10000.0), 15)
	assert_lt(dots.dot_position(15).x, dots.size.x - ArmoryDots.END_ROOM - 1.0,
			"a part page keeps a full page's steps, so 15 sits short of the end")
	page.summary().page_back_arrow().pressed.emit()
	assert_eq(dots.page(), 0)


func test_the_track_opens_on_the_page_with_your_next_level() -> void:
	var at_9 := _page(table.levels[9].total)
	var at_10 := _page(table.levels[10].total)
	var at_cap := _page(table.levels[table.cap()].total)
	await wait_process_frames(2)
	assert_eq(at_9.summary().bar().page(), 0, "level 10 next: the first page")
	assert_eq(at_10.summary().bar().page(), 1, "level 11 next: the second page")
	assert_eq(at_cap.summary().bar().page(), 1, "at the cap: its page")


func test_a_click_on_the_second_page_picks_that_level_and_shows_its_card() -> void:
	var page := _page(0)
	await wait_process_frames(2)
	var dots := page.summary().bar()
	page.summary().page_on_arrow().pressed.emit()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = dots.dot_position(12)
	dots._gui_input(click)
	assert_eq(dots.picked(), 12)
	assert_eq(page.track().picked(), 12)
	assert_true(page.track().row(12).visible)


func test_the_keys_turn_the_page_at_its_ends() -> void:
	var page := _page(table.levels[9].total)
	await wait_process_frames(2)
	var dots := page.summary().bar()
	dots._gui_input(_key(&"ui_right"))
	assert_eq([dots.picked(), dots.page()], [10, 0], "the next level first, on its page")
	dots._gui_input(_key(&"ui_right"))
	assert_eq([dots.picked(), dots.page()], [11, 1], "past 10 the page turns")
	dots._gui_input(_key(&"ui_left"))
	assert_eq([dots.picked(), dots.page()], [10, 0], "and back")


func test_a_key_on_a_page_without_the_pick_starts_from_its_end() -> void:
	var page := _page(0)
	await wait_process_frames(2)
	var dots := page.summary().bar()
	dots.show_page(1)
	dots._gui_input(_key(&"ui_right"))
	assert_eq(dots.picked(), 11, "right on the second page starts at its first level")
	dots.set_picked(-1)
	dots.show_page(1)
	dots._gui_input(_key(&"ui_left"))
	assert_eq(dots.picked(), 15, "left starts at its last")


func test_ten_levels_or_fewer_have_one_page_and_no_arrows() -> void:
	var small := LevelTable.parse("""## Levels
| Level | XP | Unlocks |
|---|---|---|
| 0 | | AEG Rifle, GBB Pistol, Standard Battery, Green Gas |
| 1 | 100 | Red Dot |
""", pool)
	var facts := ArmoryFacts.new(small, pool, 0, false, false)
	var summary := ArmorySummary.new(facts)
	add_child_autofree(summary)
	await wait_process_frames(2)
	assert_eq(summary.bar().page_count(), 1)
	assert_false(summary.page_back_arrow().visible)
	assert_false(summary.page_on_arrow().visible)


func test_show_page_keeps_inside_the_pages_there_are() -> void:
	var dots := ArmoryDots.new(16, 3, 0.5)
	dots.size = Vector2(800.0, ArmoryDots.HEIGHT)
	add_child_autofree(dots)
	assert_eq(dots.page(), 0)
	dots.show_page(1)
	assert_eq(dots.page(), 1)
	dots.show_page(5)
	assert_eq(dots.page(), 1, "kept inside the pages there are")
	dots.show_page(-3)
	assert_eq(dots.page(), 0)


func test_page_counts_at_the_ten_level_edges() -> void:
	var expected := {1: 1, 2: 1, 11: 1, 12: 2, 21: 2, 22: 3}
	for count: int in expected:
		var dots := ArmoryDots.new(count, 0, 0.0)
		assert_eq(dots.page_count(), expected[count], "%d dots" % count)
		dots.free()


func test_every_page_dot_lies_inside_the_track_and_dot_at_never_leaves_the_page() -> void:
	for count: int in [1, 2, 11, 12, 21, 22]:
		var dots := ArmoryDots.new(count, count - 1, 0.0)
		dots.size = Vector2(800.0, ArmoryDots.HEIGHT)
		add_child_autofree(dots)
		for p in dots.page_count():
			dots.show_page(p)
			for x: float in [-500.0, 0.0, 400.0, 800.0, 5000.0]:
				var at := dots.dot_at(x)
				assert_between(at, dots.first_shown(), dots.last_shown(), "%d dots, page %d, x %f" % [count, p, x])
			assert_lte(dots.dot_position(dots.last_shown()).x, 800.0 - ArmoryDots.END_ROOM + 0.01)
			assert_gte(dots.dot_position(dots.first_shown()).x, ArmoryDots.END_ROOM - 0.01)


func test_a_level_beyond_the_count_opens_on_the_last_page_and_draws() -> void:
	var dots := ArmoryDots.new(16, 99, 0.0)
	dots.size = Vector2(800.0, ArmoryDots.HEIGHT)
	add_child_autofree(dots)
	await wait_process_frames(2)
	assert_eq(dots.page(), 1)


func test_with_levelling_off_the_track_opens_on_the_cap_page_and_the_arrows_work() -> void:
	var facts := ArmoryFacts.new(table, pool, 0, true, false)
	var summary := ArmorySummary.new(facts)
	add_child_autofree(summary)
	await wait_process_frames(2)
	var dots := summary.bar()
	assert_eq(dots.page(), dots.page_count() - 1)
	assert_true(summary.page_on_arrow().disabled, "on the last page there is nothing further on")
	assert_true(summary.page_back_arrow().disabled == (dots.page() == 0))
	summary.page_back_arrow().pressed.emit()
	assert_eq(dots.page(), maxi(dots.page_count() - 2, 0))


func test_freeing_the_summary_leaves_no_orphan_nodes() -> void:
	var before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	for i in 3:
		var page := _page(0)
		await wait_process_frames(1)
		page.summary().page_on_arrow().pressed.emit()
		page.queue_free()
		await wait_process_frames(2)
	assert_lte(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), before)


func test_page_changed_fires_once_per_turn_and_not_when_nothing_moves() -> void:
	var dots := ArmoryDots.new(16, 0, 0.0)
	add_child_autofree(dots)
	watch_signals(dots)
	dots.show_page(0)
	assert_signal_not_emitted(dots, "page_changed")
	dots.show_page(1)
	dots.show_page(1)
	assert_signal_emit_count(dots, "page_changed", 1)


func test_an_item_you_own_reads_unlocked_on_a_level_you_have_not_reached() -> void:
	# PP1: a 0.1 Dev 2 save at the old cap (level 10) kept the Cyber Pistol, now at level 15. The Armory read unlocks
	# from the level alone, so it showed the pistol locked while the Loadout let you carry it.
	var p := Progress.new(table)
	p.from_dict({"xp": table.levels[10].total, "unlocked": [CYBER]})
	p.grant_reached()
	assert_true(p.has(CYBER))
	var plain := ArmoryFacts.new(table, pool, p.xp, false, false)
	var owned := ArmoryFacts.new(table, pool, p.xp, false, false, p.unlocked)
	assert_eq(owned.unlocked_count, plain.unlocked_count + 1, "the pistol counts as unlocked")
	var fifteen: ArmoryFacts.Row = owned.rows[owned.rows.size() - 1]
	assert_eq(fifteen.state, ArmoryFacts.State.LOCKED, "the level itself is still ahead")
	assert_true(owned.is_unlocked(fifteen, pool.item(CYBER)))
	var page := ArmoryPage.new(Settings.new(), p, Records.new(), pool)
	add_child_autofree(page)
	await wait_process_frames(1)
	var tile := page.find_child("Item_" + CYBER, true, false) as Control
	if tile == null:
		page.track().show_from(owned.rows.size() - 1)
		await wait_process_frames(1)
		tile = page.find_child("Item_" + CYBER, true, false) as Control
	assert_not_null(tile, "the pistol's tile is on the track")
	if tile != null:
		assert_eq(tile.modulate.a, 1.0, "its tile isn't dimmed")
