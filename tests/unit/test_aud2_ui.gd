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
