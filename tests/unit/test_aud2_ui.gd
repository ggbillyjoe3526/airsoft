extends GutTest
## The second audit's fixes to the menus and reports (AUD2, group ui): the Match rules retune the page once a click and
## save a dragged round-time slider once, on release.

const SAVE := "user://test-aud2-ui.save"

var _heard: int = 0


func after_each() -> void:
	DirAccess.remove_absolute(SAVE)


func _count() -> void:
	_heard += 1


func _page(settings: Settings) -> MatchPage:
	var page := MatchPage.new(MatchPicks.new(), settings)
	page.rules_box().save_path = SAVE
	add_child_autofree(page)
	page.rules_box().rules_button(MatchOptions.RULES_CUSTOM).pressed.emit()
	return page


func _saved_time() -> float:
	var back := Settings.new()
	back.load_file(SAVE)
	return back.custom_rules.round_time


# --- row 133: one retune a click, one save a drag ---

func test_a_custom_click_tells_the_page_once() -> void:
	var settings := Settings.new()
	var page := _page(settings)
	var box := page.rules_box()
	box.changed.connect(_count)
	settings.changed.connect(_count)
	_heard = 0
	box.ricochets_choice().button(1).pressed.emit()
	assert_eq(_heard, 1, "the settings' change only: the box sends none of its own for a Custom switch")
	assert_true(settings.custom_rules.ricochets_count)


func test_a_rule_set_pick_still_sends_the_boxs_changed() -> void:
	var settings := Settings.new()
	var page := MatchPage.new(MatchPicks.new(), settings)
	page.rules_box().save_path = SAVE
	add_child_autofree(page)
	page.rules_box().changed.connect(_count)
	_heard = 0
	page.rules_box().rules_button(MatchOptions.RULES_CUSTOM).pressed.emit()
	assert_eq(_heard, 1)


func test_a_dragged_round_time_is_saved_once_on_release() -> void:
	var settings := Settings.new()
	var page := _page(settings)
	var slider := page.rules_box().round_time_slider()
	slider.value = 120.0
	assert_eq(_saved_time(), 120.0, "a step with no drag (a key) saves at once")
	slider.drag_started.emit()
	slider.value = 180.0
	slider.value = 240.0
	assert_eq(settings.custom_rules.round_time, 240.0, "the settings follow the knob")
	assert_eq(page.rules_box().clock_text(), "4:00", "and the readout")
	assert_true(settings.dirty, "nothing written while the knob is held")
	assert_eq(_saved_time(), 120.0)
	slider.drag_ended.emit(true)
	assert_false(settings.dirty)
	assert_eq(_saved_time(), 240.0, "one write, on release")
	slider.value = 270.0
	assert_eq(_saved_time(), 270.0, "a step after the release saves again")


# --- row 28: a field's own flag raise is said on the Match page ---

func _note_page(map_id: String, mode: String) -> MatchPage:
	var picks := MatchPicks.new()
	picks.map_id = map_id
	picks.mode = mode
	var page := MatchPage.new(picks, Settings.new())
	add_child_autofree(page)
	return page


func test_field_raise_is_the_fields_own_only_where_it_differs_in_attack_defend() -> void:
	var woodland := MapCatalog.shared().find("woodland")
	var depot := MapCatalog.shared().find("depot")
	assert_eq(MatchOptions.field_raise(MatchOptions.MODE_ATTACK_DEFEND, woodland, 7.0), 9.0)
	assert_eq(MatchOptions.field_raise(MatchOptions.MODE_ATTACK_DEFEND, depot, 7.0), 0.0, "Depot plays the game's")
	assert_eq(MatchOptions.field_raise("elimination", woodland, 7.0), 0.0, "no flag in Elimination")
	assert_eq(MatchOptions.field_raise(MatchOptions.MODE_ATTACK_DEFEND, null, 7.0), 0.0)
	assert_eq(MatchOptions.field_raise(MatchOptions.MODE_ATTACK_DEFEND, woodland, 9.0), 0.0, "nothing to say at the game's own")


func test_the_match_page_says_woodlands_nine_seconds() -> void:
	var page := _note_page("woodland", MatchOptions.MODE_ATTACK_DEFEND)
	assert_eq(page.rules_box().flag_note_text(), "The flag takes 9 s to raise on this field (7 s on the others).")
	page.rules_box().rules_button(MatchOptions.RULES_CUSTOM).pressed.emit()
	assert_ne(page.rules_box().flag_note_text(), "", "under Custom too: the raise is Woodland's in both")


func test_the_match_page_says_nothing_on_depot_or_in_other_modes() -> void:
	assert_eq(_note_page("depot", MatchOptions.MODE_ATTACK_DEFEND).rules_box().flag_note_text(), "")
	var page := _note_page("woodland", MatchOptions.MODE_ATTACK_DEFEND)
	page._pick_mode("elimination")
	assert_eq(page.rules_box().flag_note_text(), "", "a mode with no flag")
	page._pick_mode(MatchOptions.MODE_ATTACK_DEFEND)
	assert_ne(page.rules_box().flag_note_text(), "")
