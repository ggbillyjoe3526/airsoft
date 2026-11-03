extends GutTest
## UF2: the Loadout's buttons answer a real mouse click (the owner's playtest, 2026-11-03: SWITCH REPLICA did nothing,
## its clicks picked the card), and a double click on a carried card no longer opens Customise. The clicks go through
## the viewport as the mouse's would, not as an emitted `pressed`. Out of a round, the trigger skips it only after
## PlayTuning.skip_grace (the fight's own clicks skipped it at once).

const LOADOUTS := "user://test_uf2_loadouts.save"
const SETTINGS := "user://test_uf2_settings.save"
const AEG := "000002"
const PISTOL := "000001"
const CYBER := "000019"

var session: PlaySession = null


func after_each() -> void:
	Input.action_release(&"fire")
	get_tree().paused = false


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


# --- the skip's grace ---


func _session() -> PlaySession:
	var s := PlaySession.new()
	s.bots_active = false
	s.settings = Settings.new()
	add_child_autofree(s)
	return s


static func _fire() -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	return e


func test_the_grace_is_between_one_and_two_seconds() -> void:
	var grace := PlayTuning.new().skip_grace
	assert_between(grace, 1.0, 2.0, "the owner's 1 or 2 seconds")
	var shipped := load("res://game/config/play_tuning.tres") as PlayTuning
	assert_eq(shipped.skip_grace, grace, "the shipped tuning keeps it")


func test_clicks_in_the_grace_do_not_skip_and_one_after_it_does() -> void:
	session = _session()
	await wait_physics_frames(2)
	session._input.active = true
	session.player.status = Character.Status.OUT
	var grace := session._play.skip_grace
	session._follow_skip(0.0)
	session._unhandled_input(_fire())
	assert_false(session.skipping(), "the click of the fight that put you out")
	assert_false(session.hud().skip_hint_shown(), "no hint while a click can't skip")
	session._follow_skip(grace * 0.9)
	session._unhandled_input(_fire())
	assert_false(session.skipping(), "still in the grace")
	session._follow_skip(grace * 0.2)
	assert_true(session.hud().skip_hint_shown(), "the hint once a click can skip")
	session._unhandled_input(_fire())
	assert_true(session.skipping(), "a click after the grace skips")
	session._stop_skip()
	session._input.active = false
	session.player.status = Character.Status.ALIVE


func test_the_grace_starts_again_each_time_you_are_out() -> void:
	session = _session()
	await wait_physics_frames(2)
	session._input.active = true
	session.player.status = Character.Status.OUT
	session._follow_skip(session._play.skip_grace)
	assert_true(session.hud().skip_hint_shown())
	session.player.status = Character.Status.ALIVE
	session._follow_skip(0.1)
	session.player.status = Character.Status.OUT
	session._follow_skip(0.1)
	session._unhandled_input(_fire())
	assert_false(session.skipping(), "out again: a new grace")
	session._input.active = false
	session.player.status = Character.Status.ALIVE


func test_a_pause_does_not_count_toward_the_grace() -> void:
	session = _session()
	await wait_physics_frames(2)
	session.player.status = Character.Status.OUT
	session._follow_skip(0.0)
	session._open_pause()
	assert_false(session.can_process(), "the session's frames, which count the grace, stop with the tree")
	session._resume()
	assert_true(session.can_process())
	session.player.status = Character.Status.ALIVE
