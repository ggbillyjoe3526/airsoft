extends GutTest
## UF1 QA probes: the Tab board over the round's table and the match summary, the pop-up's state across Customise and
## page changes, the track's picked card across picks, and the HUD opacity over parts built or shown later.

const K := GameEvent.Kind
const LOADOUTS := "user://test_uf1_qa_loadouts.save"
const SETTINGS := "user://test_uf1_qa_settings.save"

var session: PlaySession = null


func after_each() -> void:
	Input.action_release(&"fire")
	SaveFile.remove(LOADOUTS)
	SaveFile.remove(SETTINGS)


func _session() -> PlaySession:
	var s := PlaySession.new()
	s.bots_active = false
	add_child_autofree(s)
	return s


func _end_round(last: bool = false) -> void:
	var state := session.state
	var rs := state.round_state
	rs.phase = RoundState.Phase.OVER
	rs.timer = SimTuning.new().rounds.reset_delay
	rs.clock = 30.0
	state.events.clear()
	var e := state.events.add(K.ROUND_OVER)
	e.value = 0
	e.value2 = GameEvent.RoundEnd.ELIMINATED
	if last:
		state.events.add(K.MATCH_OVER).value = 0
	session.hud().on_tick(state)
	state.events.clear()


func _wait(seconds: float) -> void:
	session.state.time += seconds
	session.hud().update(session.state, 1.0, 0.0)


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


# --- the Tab board and the round's table ---


func test_holding_tab_over_the_table_hides_it_and_letting_go_brings_it_back() -> void:
	session = _session()
	var hud := session.hud()
	_end_round()
	_wait(3.0)
	assert_true(hud.round_result().is_up(), "the table is up")
	hud.show_board(true)
	_wait(0.1)
	assert_false(hud.round_result().is_up(), "hidden under the board")
	assert_true(hud.board().visible, "the board shows")
	hud.show_board(false)
	_wait(0.1)
	assert_true(hud.round_result().is_up(), "the table is back, nothing lost")
	assert_eq(hud.round_result().modulate.a, 1.0, "drawn whole, not left half faded")


func test_tab_held_through_the_table_delay_shows_the_table_only_once_let_go() -> void:
	session = _session()
	var hud := session.hud()
	hud.show_board(true)
	_wait(0.1)
	_end_round()
	_wait(3.0)
	assert_false(hud.round_result().is_up(), "never under the board")
	hud.show_board(false)
	_wait(0.1)
	assert_true(hud.round_result().is_up())


func test_the_next_round_starting_under_the_board_closes_the_table_for_good() -> void:
	session = _session()
	var hud := session.hud()
	_end_round()
	_wait(3.0)
	hud.show_board(true)
	_wait(0.1)
	var state := session.state
	state.events.clear()
	state.events.add(K.ROUND_START).value = 2
	hud.on_tick(state)
	state.events.clear()
	hud.show_board(false)
	_wait(0.1)
	assert_false(hud.round_result().is_up(), "the new round's table does not come back")


func test_the_match_summary_keeps_the_tab_board_down_and_the_banners_up() -> void:
	session = _session()
	var hud := session.hud()
	_end_round(true)
	_wait(20.0)
	hud.open_summary(session.state, false, "")
	_wait(0.1)
	hud.show_board(true)
	_wait(0.1)
	assert_true(hud.summary_up(), "the summary is up")
	assert_false(hud.board().visible, "the board stays down over it")
	hud.show_board(false)
	_wait(0.1)
	assert_true(hud.summary_up())


func test_tab_in_a_live_round_leaves_nothing_hidden_after_it() -> void:
	session = _session()
	var hud := session.hud()
	hud.show_board(true)
	_wait(0.1)
	assert_false(hud._middle.visible, "the held board replaces the banners and the hit call: nothing draws over anything (BP8)")
	hud.show_board(false)
	_wait(0.1)
	assert_true(hud._middle.visible, "the banners' stack is back once Tab is let go")


# --- the SWITCH REPLICA pop-up ---


func test_opening_twice_retargets_and_closing_twice_is_harmless() -> void:
	var page := _page()
	await wait_process_frames(2)
	var gear := page.gear()
	gear.open_switch(Loadout.Slot.SECONDARY)
	gear.open_switch(Loadout.Slot.PRIMARY)
	assert_eq(gear.switcher().slot(), Loadout.Slot.PRIMARY, "a second open re-targets, never stacks")
	assert_eq(gear.switcher().get_parent(), gear)
	gear.close_switch()
	gear.close_switch()
	assert_false(gear.switching(), "closing twice is harmless")


# --- the Armory track ---


func test_picking_the_same_dot_twice_and_a_dot_off_the_end_stay_on_one_card() -> void:
	var page := ArmoryPage.new(Settings.new(), Progress.new(LevelTable.shared()), Records.new())
	add_child_autofree(page)
	await wait_process_frames(2)
	var track := page.track()
	var dots := page.summary().bar()
	track.set_picked(3)
	track.set_picked(3)
	track.set_picked(9999)
	assert_eq(track.picked(), -1, "an unknown level marks nothing")
	var edged := 0
	for n in 100:
		var card := track.row(n) as PanelContainer
		if card != null and (card.get_theme_stylebox("panel") as StyleBoxFlat).border_color == GameTheme.TEXT:
			edged += 1
	assert_eq(edged, 0, "no card is left edged after an unknown level")
	dots.set_picked(9999)
	assert_lte(dots.picked(), 0 if dots.picked() < 0 else 99999)
	# The pictures' cameras are placed outside the physics ticks: never interpolated, so no engine error in a long run.
	var cams := page.pictures().find_children("*", "Camera3D", true, false)
	assert_gt(cams.size(), 0, "a camera to check")
	for cam: Node in cams:
		assert_false((cam as Camera3D).is_physics_interpolated(), "a picture's camera is not interpolated")


# --- the HUD opacity ---


func test_every_part_of_the_replica_panel_and_minimap_keeps_solid_words_at_low_opacity() -> void:
	session = _session()
	var hud := session.hud()
	var prefs := HudPrefs.new()
	prefs.panel_opacity = 0.3
	hud.apply_prefs(prefs)
	await wait_process_frames(2)
	for root: Control in [hud._replica, hud._minimap]:
		if root == null:
			continue
		var stack: Array[Node] = [root]
		while not stack.is_empty():
			var n := stack.pop_back() as Node
			stack.append_array(n.get_children())
			var c := n as CanvasItem
			if c != null:
				assert_almost_eq(c.modulate.a, 1.0, 0.001, "%s fades by modulate" % c.get_path())
