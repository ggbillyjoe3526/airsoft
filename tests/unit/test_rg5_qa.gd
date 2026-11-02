extends GutTest
## RG5 QA: what the worker's tests leave out. The spot taken mid-vault, Esc and typed keys through the real input path
## in the practice Loadout (a rename, Customise), the range held on its spot over ticks (toggled crouch, holster, slot),
## the challenge's switch and a run dropped, the pause menu's Settings and the building range ignoring the key, the key
## rebound (or lost), a locked pick, and several trips there and back from the entry scene.

## Seconds a staged build may take (its nav grid builds on a worker thread, so frames are no measure).
const LOAD_LIMIT := 20.0
const MAIN := preload("res://game/main.tscn")
const LOADOUTS := "user://test_rg5_qa_loadouts.save"
const SETTINGS := "user://test_rg5_qa_settings.save"
const CYBER := "000019"

var saved: SavedLoadouts
var settings: Settings


func before_each() -> void:
	SaveFile.remove(LOADOUTS)
	SaveFile.remove(SETTINGS)
	saved = SavedLoadouts.new(LoadoutRules.standard())
	settings = Settings.new()


func after_each() -> void:
	await wait_process_frames(2)
	SaveFile.remove(LOADOUTS)
	SaveFile.remove(SETTINGS)
	KeyBindings.new().apply()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _key(code: Key, unicode: int = 0) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.unicode = unicode
	e.pressed = true
	return e


## Through the viewport as a real key goes: the GUI first (a focused line edit eats its letters), then the nodes'
## `_unhandled_input`, last child first.
func _press(code: Key, unicode: int = 0) -> void:
	get_viewport().push_input(_key(code, unicode))


func _action(action: StringName) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	return e


func _practice_menus() -> MenuScreen:
	var menus := MenuScreen.new(MatchPicks.new(), settings)
	add_child_autofree(menus)
	menus.open_practice_loadout(Loadout.Slot.PRIMARY)
	return menus


func _range(spot: PracticeSpot, records: Records = null) -> PlaySession:
	var play := PlaySession.new()
	play.practice = true
	play.map_id = "range"
	play.settings = settings
	play.kit = saved.carried_kit(false)
	play.match_seed = spot.match_seed
	play.challenge_on = spot.challenge_on
	play.resume = spot
	play.records = records
	add_child_autofree(play)
	return play


# --- the spot ---

func test_a_spot_taken_mid_vault_is_not_a_crouch() -> void:
	# A vault tucks the body (VaultConfig.tuck, 0.6, a crouch the figure follows); that is not a stance you chose, and
	# with the crouch toggle the range would come back with you crouched until you pressed the key again.
	var kit := saved.carried_kit(false)
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, kit.replicas, kit.bb_weights)
	c.vault.active = true
	c.crouch_amount = 0.6 * 0.95
	var spot := PracticeSpot.of(c, 0.0, 0.0, false, false, 1)
	assert_false(spot.crouched, "a vault's tuck is not a crouch: the spot keeps the stance you chose, not the body's")
	c.vault.active = false
	c.crouch_amount = 1.0
	assert_false(PracticeSpot.of(c, 0.0, 0.0, false, false, 1).crouched, "a body still rising from a crouch you left")


# --- Esc and typing in the practice Loadout, through the real input path ---

func test_escape_leaves_a_rename_then_customise_before_it_goes_back_to_practice() -> void:
	var menus := _practice_menus()
	watch_signals(menus)
	await wait_process_frames(1)
	var page := menus.loadout_page()
	page.strip().start_rename()
	assert_eq(page.strip().mode, LoadoutStrip.Mode.RENAMING)
	await wait_process_frames(1)
	# the name field takes the first Esc itself (it stops editing), the page the next: never the menus' own
	for press in 2:
		if page.strip().mode == LoadoutStrip.Mode.RENAMING:
			_press(KEY_ESCAPE)
			await wait_process_frames(2)
	assert_signal_not_emitted(menus, "practice_requested", "Esc leaves the rename first")
	assert_eq(page.strip().mode, LoadoutStrip.Mode.NORMAL)
	page.show_customise()
	assert_true(page.customising())
	_press(KEY_ESCAPE)
	assert_signal_not_emitted(menus, "practice_requested", "Esc leaves Customise first")
	assert_false(page.customising())
	_press(KEY_ESCAPE)
	assert_signal_emit_count(menus, "practice_requested", 1, "then back to the range")
	menus.leave_loadout()


func test_the_loadout_key_typed_in_a_rename_is_a_letter_and_does_not_leave() -> void:
	var menus := _practice_menus()
	watch_signals(menus)
	await wait_process_frames(1)
	var page := menus.loadout_page()
	page.strip().start_rename()
	await wait_process_frames(1)
	var edit := page.strip().edit()
	assert_true(edit.has_focus(), "the name field has the keys")
	_press(KEY_L, 108)
	assert_signal_not_emitted(menus, "practice_requested", "L is a letter in a name")
	assert_true(edit.text.ends_with("l"), "and it is typed")
	page.strip().cancel()
	menus.leave_loadout()


func test_the_loadout_key_in_customise_goes_back_to_practice() -> void:
	var menus := _practice_menus()
	watch_signals(menus)
	await wait_process_frames(1)
	menus.loadout_page().show_customise()
	_press(KEY_L)
	assert_signal_emit_count(menus, "practice_requested", 1)
	menus.leave_loadout()


# --- the range held on its spot ---

func test_the_range_holds_the_spot_over_ticks_with_a_toggled_crouch_a_holstered_replica_and_the_slot() -> void:
	var spot := PracticeSpot.new()
	spot.position = Vector3(2.0, 0.0, -5.0)
	spot.yaw = 1.2
	spot.pitch = -0.1
	spot.crouched = true
	spot.slot = 1
	spot.holstered = true
	spot.match_seed = 5
	var play := _range(spot)
	play._play.controls.crouch_toggle = true
	await wait_physics_frames(30)
	var c := play.player
	assert_almost_eq(c.position.x, 2.0, 0.01, "stays where you stood")
	assert_almost_eq(c.position.z, -5.0, 0.01)
	assert_almost_eq(c.yaw, 1.2, 0.001, "and looking the same way")
	assert_eq(c.armament.active, 1, "the same slot in hand")
	assert_true(c.armament.holstered, "still holstered")
	assert_almost_eq(c.crouch_amount, 1.0, 0.001, "a toggled crouch holds: no standing up by itself")
	assert_true(play._input.active, "the keys and mouse are yours again")


func test_the_spot_taken_in_play_keeps_the_toggled_crouch_you_chose_not_the_body() -> void:
	var play := _range(PracticeSpot.new())
	play._play.controls.crouch_toggle = true
	await wait_physics_frames(2)
	play._input.set_crouched(true)
	play.player.crouch_amount = 0.3 # still going down
	assert_true(play.practice_spot().crouched, "crouched as you chose, though the body is still on its way")
	play._input.set_crouched(false)
	play.player.crouch_amount = 0.9 # still coming up
	assert_false(play.practice_spot().crouched, "standing as you chose")


func test_without_the_crouch_toggle_the_range_comes_back_standing_once_the_key_is_not_held() -> void:
	var spot := PracticeSpot.new()
	spot.position = Vector3(0.0, 0.0, -3.0)
	spot.crouched = true
	var play := _range(spot)
	play._play.controls.crouch_toggle = false
	await wait_physics_frames(60)
	assert_lt(play.player.crouch_amount, 0.5, "the held key decides: not held, you stand")


# --- the challenge ---

func test_a_run_under_way_is_dropped_and_the_switch_comes_back_as_it_was() -> void:
	var records := Records.new()
	var first := PlaySession.new()
	first.practice = true
	first.map_id = "range"
	first.settings = settings
	first.records = records
	first.challenge_on = true
	first.match_seed = 9
	add_child_autofree(first)
	await wait_physics_frames(2)
	first.state.challenge.phase = RangeChallenge.Phase.RUNNING
	first.state.challenge.hits = 7
	watch_signals(first)
	first._unhandled_input(_action(&"loadout"))
	assert_signal_emit_count(first, "loadout_requested", 1, "mid-run the key still asks")
	var spot := first.practice_spot()
	assert_true(spot.challenge_on)
	assert_eq(records.challenge_best("range"), 0, "nothing kept for a dropped run")
	var back := _range(spot, records)
	await wait_physics_frames(2)
	assert_eq(back.state.challenge.phase, RangeChallenge.Phase.READY, "ready, not running")
	assert_eq(back.state.challenge.hits, 0, "the run's count starts over")
	assert_eq(records.challenge_best("range"), 0, "and still nothing kept")
	var off := PracticeSpot.new()
	off.challenge_on = false
	var plain := _range(off)
	await wait_physics_frames(2)
	assert_eq(plain.state.challenge.phase, RangeChallenge.Phase.OFF, "an off switch stays off")


func test_the_key_in_the_challenges_countdown_asks_and_the_countdown_is_dropped() -> void:
	var first := PlaySession.new()
	first.practice = true
	first.map_id = "range"
	first.settings = settings
	first.challenge_on = true
	add_child_autofree(first)
	await wait_physics_frames(2)
	first.state.challenge.phase = RangeChallenge.Phase.COUNTDOWN
	watch_signals(first)
	first._unhandled_input(_action(&"loadout"))
	assert_signal_emit_count(first, "loadout_requested", 1)
	var back := _range(first.practice_spot())
	await wait_physics_frames(2)
	assert_eq(back.state.challenge.phase, RangeChallenge.Phase.READY, "no countdown carried over")


func test_the_pause_menus_loadout_row_unpauses_the_tree_and_lets_go_of_the_keys() -> void:
	var main: Node = add_child_autofree(MAIN.instantiate())
	await wait_process_frames(2)
	main._picks.map_id = "range"
	main._picks.mode = MatchOptions.MODE_PRACTICE
	main._start_play()
	assert_true(await wait_until(func() -> bool: return main._loading == null, LOAD_LIMIT), "the match loads within LOAD_LIMIT s")
	var play: PlaySession = main._play
	play._open_pause()
	assert_true(get_tree().paused)
	play._pause.loadout_button().pressed.emit()
	assert_false(get_tree().paused, "the menus run on a tree that is not paused")
	assert_null(main._play)
	await wait_process_frames(2)
	main._menus.nav_rail().back_button().pressed.emit()
	assert_true(await wait_until(func() -> bool: return main._loading == null, LOAD_LIMIT), "the match loads within LOAD_LIMIT s")
	await wait_process_frames(2)
	assert_false(get_tree().paused, "and neither is the range built again")
	assert_false(main._play._pause.visible, "with its pause menu shut")
	main._end_play()


# --- when the key must do nothing ---

func test_the_loadout_key_does_nothing_while_the_range_is_still_building() -> void:
	var play := PlaySession.new()
	play.practice = true
	play.map_id = "range"
	play.settings = settings
	play.staged = true
	add_child_autofree(play)
	watch_signals(play)
	play._unhandled_input(_action(&"loadout"))
	assert_signal_not_emitted(play, "loadout_requested", "nothing to take a spot from yet")
	play._request_loadout()
	assert_signal_not_emitted(play, "loadout_requested")


func test_the_pause_menus_loadout_key_does_nothing_while_its_settings_are_open() -> void:
	var menu := PauseMenu.new()
	add_child_autofree(menu)
	menu.set_practice("Range", false, 0)
	watch_signals(menu)
	menu.open()
	menu.open_settings()
	assert_true(menu.settings_open())
	menu._unhandled_input(_action(&"loadout"))
	assert_signal_not_emitted(menu, "loadout_requested", "L belongs to the settings (a key being bound) there")


func test_an_autopiloted_range_ignores_the_key() -> void:
	var play := PlaySession.new()
	play.practice = true
	play.autopilot = true
	play.map_id = "range"
	play.settings = settings
	add_child_autofree(play)
	await wait_physics_frames(2)
	watch_signals(play)
	play._unhandled_input(_action(&"loadout"))
	assert_signal_not_emitted(play, "loadout_requested", "the smoke test's pilot never leaves for the Loadout")


# --- the key rebound ---

func test_a_rebound_loadout_key_is_the_one_that_asks_and_the_old_one_does_not() -> void:
	var keys := KeyBindings.new()
	assert_eq(keys.rebind(&"loadout", KEY_K), KeyBindings.Result.BOUND)
	keys.apply()
	var play := _range(PracticeSpot.new())
	await wait_physics_frames(2)
	watch_signals(play)
	_press(KEY_L)
	assert_signal_not_emitted(play, "loadout_requested", "L is nothing now")
	_press(KEY_K)
	assert_signal_emit_count(play, "loadout_requested", 1)
	assert_eq(KeyNames.of_action(&"loadout"), "K")


func test_a_loadout_left_without_a_key_still_has_escape_as_the_way_back() -> void:
	var keys := KeyBindings.new()
	assert_eq(keys.rebind(&"reload", KEY_L), KeyBindings.Result.SWAPPED, "reload takes L; the Loadout gets R")
	keys.apply()
	assert_eq(KeyNames.of_action(&"loadout"), "R")
	var menus := _practice_menus()
	watch_signals(menus)
	await wait_process_frames(1)
	assert_ne(menus.nav_rail().back_key_text(), "")
	_press(KEY_ESCAPE)
	assert_signal_emit_count(menus, "practice_requested", 1, "Esc is always a way back")
	menus.leave_loadout()


# --- a locked pick ---

func test_a_locked_replica_cannot_be_picked_from_practice_with_levelling_on() -> void:
	var progress := Progress.new(LevelTable.read_file(Pool.read_file()))
	saved.rules.follow_progress(progress, false)
	assert_true(saved.rules.is_locked(CYBER), "locked at the start")
	var page := LoadoutPage.new(saved, settings)
	page.save_path = LOADOUTS
	page.settings_path = SETTINGS
	add_child_autofree(page)
	page.open_from_practice(Loadout.Slot.SECONDARY)
	var before := saved.carried().replica_id(Loadout.Slot.SECONDARY)
	page._pick_replica(CYBER)
	assert_eq(saved.carried().replica_id(Loadout.Slot.SECONDARY), before, "the lock holds from the range too")
	page.close()


# --- several trips from the entry scene ---

func test_three_trips_to_the_loadout_and_back_leave_nothing_behind_and_keep_the_spot() -> void:
	var main: Node = add_child_autofree(MAIN.instantiate())
	await wait_process_frames(2)
	main._picks.map_id = "range"
	main._picks.mode = MatchOptions.MODE_PRACTICE
	main._start_play()
	assert_true(await wait_until(func() -> bool: return main._loading == null, LOAD_LIMIT), "the match loads within LOAD_LIMIT s")
	var captured_first := Input.mouse_mode
	main._play.player.position = Vector3(1.0, 0.0, -2.0)
	var nodes_in_range := -1
	var orphans := -1
	for trip in 3:
		main._play._unhandled_input(_action(&"loadout"))
		assert_null(main._play, "trip %d: the range is freed" % trip)
		assert_true(main._menus.from_practice())
		assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE, "trip %d: the mouse is free in the menus" % trip)
		await wait_process_frames(2)
		main._menus._unhandled_input(_action(&"loadout"))
		assert_true(await wait_until(func() -> bool: return main._loading == null, LOAD_LIMIT), "the match loads within LOAD_LIMIT s")
		await wait_process_frames(2)
		assert_not_null(main._play, "trip %d: the range is back" % trip)
		assert_null(main._spot, "the spot is used up")
		assert_almost_eq(main._play.player.position.x, 1.0, 0.05, "trip %d: where you stood" % trip)
		assert_eq(Input.mouse_mode, captured_first, "trip %d: the mouse is taken as on a first start" % trip)
		var plays := main.get_children().filter(func(n: Node) -> bool: return n is PlaySession)
		assert_eq(plays.size(), 1, "one range")
		var screens := main.get_children().filter(func(n: Node) -> bool: return n is MenuScreen)
		assert_eq(screens.size(), 0, "no menu nodes in play")
		var n := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		var o := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
		if nodes_in_range < 0:
			nodes_in_range = n
			orphans = o
		else:
			assert_eq(n, nodes_in_range, "trip %d: the node count is the range's again" % trip)
			assert_eq(o, orphans, "trip %d: no orphan nodes grow" % trip)
	assert_eq(main._play.loadout_requested.get_connections().size(), 1, "one listener on the key's signal")
	main._end_play()


# --- a spot taken mid-vault, over the sandbags ---

func test_a_spot_taken_mid_vault_comes_back_settled_on_the_sandbags_or_the_floor_not_inside_them() -> void:
	var first := PlaySession.new()
	first.practice = true
	first.map_id = "range"
	first.settings = settings
	add_child_autofree(first)
	await wait_physics_frames(2)
	var c := first.player
	c.position = Vector3(4.6, c.position.y, 4.0)
	c.prev_position = c.position
	c.velocity = Vector3.ZERO
	await wait_physics_frames(10)
	var floor_y := c.position.y
	assert_true(c.grounded, "standing before the sandbags")
	assert_true(Vault.find_along(c, Vector2(0.0, -1.0), first._tuning, first._level.query(), c.vault), "a vault there")
	c.vault.active = true
	var guard := 0
	while c.vault.active and c.vault.time < c.vault.rise_end * 0.95 and guard < 120:
		await wait_physics_frames(1)
		guard += 1
	assert_true(c.vault.active, "caught mid-vault")
	assert_gt(c.position.y, floor_y + 0.5, "in the air over the sandbags")
	var spot := first.practice_spot()
	assert_false(spot.crouched, "the tuck is no stance")
	var back := _range(spot)
	await wait_physics_frames(90)
	var p := back.player
	assert_true(p.grounded, "settled, not hanging or falling")
	assert_false(p.vault.active)
	var on_top := floor_y + 0.9
	var settled := absf(p.position.y - floor_y) < 0.05 or absf(p.position.y - on_top) < 0.05
	assert_true(settled, "on the floor or on top of the sandbags (y %.3f; floor %.3f)" % [p.position.y, floor_y])
	assert_gt(p.position.y, floor_y - 0.05, "never through the floor")
