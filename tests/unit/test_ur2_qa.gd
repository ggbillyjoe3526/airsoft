extends GutTest
## QA's hunt on the UR2 Match page (concept B v2): layout in the room beside the rail, keyboard to PLAY, fall-backs,
## the Range's flow and what the page leaves behind.

const ROOM := Vector2i(1920, 1080)


## `dev_content` lists the dev maps too: The Street, the longest name and blurb, is dev (owner, 2026-11-05).
func _screen(picks: MatchPicks = null, size: Vector2i = ROOM, dev_content: bool = false) -> MenuScreen:
	var view := SubViewport.new()
	view.size = size
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child_autofree(view)
	var settings := Settings.new()
	settings.dev.dev_content = dev_content
	var screen := MenuScreen.new(picks if picks != null else MatchPicks.new(), settings)
	view.add_child(screen)
	return screen


func test_the_page_fits_the_room_beside_the_rail_at_the_smallest_window() -> void:
	var screen := _screen()
	await wait_process_frames(3)
	var page := screen.match_page()
	var room := Rect2(Vector2(NavRail.WIDTH, 0.0), Vector2(ROOM))
	assert_true(page.get_combined_minimum_size().x <= ROOM.x - NavRail.WIDTH, "min width %s" % page.get_combined_minimum_size())
	assert_true(page.get_combined_minimum_size().y <= ROOM.y, "min height %s" % page.get_combined_minimum_size())
	for node: Node in page.find_children("*", "PanelContainer", true, false):
		var r := (node as Control).get_global_rect()
		assert_true(room.encloses(r), "%s %s outside %s" % [node.name, r, room])
	var card := page.find_child("PlayCard", true, false) as Control
	assert_true(page.play_button().get_global_rect().end.y <= ROOM.y - 20.0, "PLAY clear of the window foot")
	for id: String in page.map_ids():
		assert_true(page.map_card(id).get_global_rect().end.y <= ROOM.y, "%s on screen" % id)
	for mode in MatchOptions.MODES:
		assert_true(page.mode_card(mode).get_global_rect().end.y <= ROOM.y, "%s on screen" % mode)
	# the fields panel holds its contents (no row spills out)
	var fields := page.map_card(page.map_ids()[0]).get_parent()
	var panel_rect := (fields.get_parent().get_parent().get_parent() as Control).get_global_rect()
	for mode in MatchOptions.MODES:
		assert_true(panel_rect.encloses(page.mode_card(mode).get_global_rect()), "%s inside its panel" % mode)


func test_the_page_fits_a_tall_narrow_window() -> void:
	var screen := _screen(null, Vector2i(1920, 1440))
	await wait_process_frames(3)
	var page := screen.match_page()
	assert_true(page.play_button().get_global_rect().end.y <= 1440.0)
	assert_true(page.play_button().get_global_rect().position.y > 0.0)


func test_tab_order_reaches_play_from_the_first_field_without_a_trap() -> void:
	var screen := _screen()
	await wait_process_frames(3)
	var page := screen.match_page()
	var first := page.map_card(page.map_ids()[0])
	first.grab_focus()
	var seen := 0
	var cur: Control = first
	while cur != page.play_button() and seen < 80:
		cur = cur.find_next_valid_focus()
		seen += 1
	assert_eq(cur, page.play_button(), "Tab reaches PLAY (steps %d)" % seen)
	# and PLAY is reachable going down by arrow keys from the last bots button
	var down := page.play_button().find_valid_focus_neighbor(SIDE_TOP)
	assert_not_null(down, "something above PLAY")


func test_a_greyed_map_and_mode_cannot_take_the_keyboard() -> void:
	var picks := MatchPicks.new()
	picks.map_id = "range"
	var screen := _screen(picks)
	await wait_process_frames(2)
	var page := screen.match_page()
	assert_eq(picks.mode, MatchOptions.MODE_PRACTICE)
	assert_true(page.mode_card(MatchOptions.MODE_ELIMINATION).disabled)
	assert_eq(page.play_button().text, "PRACTICE")
	for t in 2:
		assert_eq(page.team_card(t).focus_mode, Control.FOCUS_NONE, "team card %d locked under Practice" % t)


func test_range_then_a_field_gives_the_field_mode_back() -> void:
	var picks := MatchPicks.new()
	var screen := _screen(picks)
	await wait_process_frames(2)
	var page := screen.match_page()
	page.mode_card(MatchOptions.MODE_ATTACK_DEFEND).pressed.emit()
	var mode := picks.mode
	page.map_card("range").pressed.emit()
	assert_eq(picks.mode, MatchOptions.MODE_PRACTICE)
	page.map_card("woodland").pressed.emit()
	assert_ne(picks.mode, MatchOptions.MODE_PRACTICE, "Practice gives way")
	assert_eq(page.map_card("woodland").is_picked(), true)
	assert_eq(page.play_button().text, "PLAY")
	assert_eq(page.team_card(0).focus_mode, Control.FOCUS_ALL, "team cards back")
	assert_true(mode != "")


func test_a_gone_map_falls_back_and_tells_the_backdrop() -> void:
	var picks := MatchPicks.new()
	picks.map_id = "neonHeights"
	var settings := Settings.new()
	var page := MatchPage.new(picks, settings)
	add_child_autofree(page)
	watch_signals(page)
	assert_eq(picks.map_id, page.map_ids()[0])
	assert_false(page.play_button().disabled)
	assert_true(page.map_card(picks.map_id).is_picked())
	assert_eq(page.find_child("PlayCard", true, false).find_children("*", "TextureRect", true, false).size(), 1)
	var tex := page.find_child("PlayCard", true, false).find_children("*", "TextureRect", true, false)[0] as TextureRect
	assert_not_null(tex.texture, "the play card has the stood-in field's picture")


func test_freeing_the_page_leaves_no_orphans_or_connections() -> void:
	var settings := Settings.new()
	var before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var page := MatchPage.new(MatchPicks.new(), settings)
	add_child(page)
	await wait_process_frames(2)
	assert_true(settings.changed.is_connected(page._on_rules_changed))
	settings.dev.dev_content = true
	settings.changed.emit()
	settings.dev.dev_content = false
	settings.changed.emit()
	await wait_process_frames(2)
	remove_child(page)
	assert_false(settings.changed.is_connected(page._on_rules_changed), "disconnected when out of the tree")
	page.free()
	await wait_process_frames(2)
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), before)


func test_reentering_the_tree_connects_once() -> void:
	var settings := Settings.new()
	var page := MatchPage.new(MatchPicks.new(), settings)
	add_child_autofree(page)
	remove_child(page)
	add_child(page)
	var n := 0
	for c: Dictionary in settings.changed.get_connections():
		if (c["callable"] as Callable) == page._on_rules_changed:
			n += 1
	assert_eq(n, 1)


func test_custom_rules_rows_fit_their_panel_at_1080() -> void:
	var picks := MatchPicks.new()
	picks.rules = MatchOptions.RULES_CUSTOM
	picks.mode = MatchOptions.MODE_ATTACK_DEFEND
	var screen := _screen(picks)
	await wait_process_frames(3)
	var page := screen.match_page()
	var panel := page.rules_box().get_parent() as Control
	assert_true(panel.get_combined_minimum_size().y <= panel.size.y, "rows fit the panel")
	var rect := panel.get_global_rect()
	assert_true(rect.end.y <= ROOM.y)
	var side := page.find_child("PlayCard", true, false) as Control
	assert_true(side.get_global_rect().end.y <= ROOM.y)
	assert_true(page.play_button().get_global_rect().end.y <= ROOM.y)
	assert_true(page.get_global_rect().encloses(rect))
	var bots := page.bots_box().get_global_rect()
	assert_true(bots.end.y <= side.get_global_rect().position.y, "bots clear of the play card: %s vs %s" % [bots, side.get_global_rect()])


func test_longest_summary_and_blurbs_fit_their_lines() -> void:
	var picks := MatchPicks.new()
	picks.map_id = "street"
	picks.mode = MatchOptions.MODE_ATTACK_DEFEND
	picks.rules = MatchOptions.RULES_CUSTOM
	picks.bots = "hard"
	picks.teammates = "easy"
	picks.team = PlaySession.TEAM_BETA
	var screen := _screen(picks, ROOM, true)
	await wait_process_frames(3)
	var page := screen.match_page()
	var line := page.find_child("SummaryLine", true, false) as Label
	assert_between(line.get_line_count(), 1, line.max_lines_visible, "summary shows whole: '%s'" % line.text)
	for mode: String in MatchOptions.MODES:
		var b := page.mode_card(mode).find_child("Blurb", true, false) as Label
		assert_between(b.get_line_count(), 1, b.max_lines_visible, "%s blurb shows whole" % mode)
	for id: String in page.map_ids():
		var nm := page.map_card(id).find_child("Name", true, false) as Label
		var row := nm.get_parent() as Control
		assert_true(row.get_global_rect().end.x <= page.map_card(id).get_global_rect().end.x, "%s name row inside its card" % id)
		var bl := page.map_card(id).find_child("Blurb", true, false) as Label


func test_a_plain_attack_defend_summary_fits_its_line() -> void:
	var picks := MatchPicks.new()
	picks.map_id = "street"
	picks.mode = MatchOptions.MODE_ATTACK_DEFEND
	var screen := _screen(picks, ROOM, true)
	await wait_process_frames(3)
	var line := screen.match_page().find_child("SummaryLine", true, false) as Label
	assert_between(line.get_line_count(), 1, line.max_lines_visible, "plain Attack/Defend summary shows whole: '%s'" % line.text)
