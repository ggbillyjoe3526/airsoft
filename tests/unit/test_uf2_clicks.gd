extends GutTest
## UF2: the Loadout's buttons answer a real mouse click (the owner's playtest, 2026-11-03: SWITCH REPLICA did nothing,
## its clicks picked the card), and a double click on a carried card no longer opens Customise. The clicks go through
## the viewport as the mouse's would, not as an emitted `pressed`.

const LOADOUTS := "user://test_uf2_loadouts.save"
const SETTINGS := "user://test_uf2_settings.save"
const AEG := "000002"
const PISTOL := "000001"
const CYBER := "000019"


func after_all() -> void:
	for path: String in [LOADOUTS, SETTINGS]:
		SaveFile.remove(path)


func _page() -> LoadoutPage:
	SaveFile.remove(LOADOUTS)
	var view := SubViewport.new()
	view.size = Vector2i(1920, 1080)
	add_child_autofree(view)
	var page := LoadoutPage.new(SavedLoadouts.new(LoadoutRules.standard()), Settings.new())
	page.save_path = LOADOUTS
	page.settings_path = SETTINGS
	view.add_child(page)
	return page


func _press(view: Viewport, at: Vector2, down: bool, twice: bool = false) -> void:
	var b := InputEventMouseButton.new()
	b.button_index = MOUSE_BUTTON_LEFT
	b.pressed = down
	b.double_click = twice
	b.position = at
	b.global_position = at
	view.push_input(b)


## A click (or the second click of a double click) in the middle of `target`, as the mouse makes it.
func _click(target: Control, twice: bool = false) -> void:
	var view := target.get_viewport()
	var at := target.get_global_rect().get_center()
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	view.push_input(move)
	await wait_process_frames(1)
	_press(view, at, true, twice)
	await wait_process_frames(1)
	_press(view, at, false)
	await wait_process_frames(1)


func test_the_card_s_buttons_take_their_own_clicks() -> void:
	var page := _page()
	await wait_process_frames(2)
	var gear := page.gear()
	for slot: Loadout.Slot in LoadoutFacts.SLOTS:
		assert_eq(gear.switch_button(slot).mouse_filter, Control.MOUSE_FILTER_STOP, "SWITCH REPLICA %d" % slot)
	assert_eq(gear.customise_button().mouse_filter, Control.MOUSE_FILTER_STOP, "CUSTOMISE")


func test_a_click_on_switch_replica_opens_the_pop_up_for_its_slot() -> void:
	var page := _page()
	await wait_process_frames(2)
	var gear := page.gear()
	for slot: Loadout.Slot in LoadoutFacts.SLOTS:
		await _click(gear.switch_button(slot))
		assert_true(gear.switching(), "slot %d opens" % slot)
		assert_eq(gear.switcher().slot(), slot)
		await _click(gear.switcher().close_button())
		assert_false(gear.switching(), "CLOSE takes a click")


func test_a_click_on_a_replica_in_the_pop_up_carries_it() -> void:
	var page := _page()
	await wait_process_frames(2)
	var gear := page.gear()
	await _click(gear.switch_button(Loadout.Slot.SECONDARY))
	await _click(gear.replica_card(CYBER))
	assert_false(gear.switching())
	assert_eq(page.saved.carried().equipped, PackedStringArray([AEG, CYBER]))
	await _click(gear.switch_button(Loadout.Slot.PRIMARY))
	await _click(gear.replica_card(CYBER))
	assert_eq(page.saved.carried().equipped, PackedStringArray([CYBER, AEG]), "the other slot's replica swaps")


func test_a_double_click_on_a_carried_card_does_not_open_customise() -> void:
	var page := _page()
	await wait_process_frames(2)
	var card := page.gear().carried_card(Loadout.Slot.SECONDARY)
	await _click(card)
	await _click(card, true)
	assert_false(page.customising(), "only CUSTOMISE opens it")
	assert_eq(page.slot(), Loadout.Slot.SECONDARY, "the clicks still pick the card")
	await _click(page.gear().customise_button())
	assert_true(page.customising(), "CUSTOMISE takes a click")
