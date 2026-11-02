extends GutTest
## The Loadout from practice (RG5; concepts step16-range `loadout-practice.png`, `pause-practice.png`): the Loadout key
## and its place in Settings, the pause menu's row, the menus as the Loadout alone with BACK TO PRACTICE, the spot the
## range comes back on, the key doing nothing in a match, and the picks being the one loadout the next match carries.

## Seconds a staged build may take (its nav grid builds on a worker thread, so frames are no measure).
const LOAD_LIMIT := 20.0
const MAIN := preload("res://game/main.tscn")
const LOADOUTS := "user://test_rg5_loadouts.save"
const SETTINGS := "user://test_rg5_settings.save"
const AEG := "000002"
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
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _action(action: StringName) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	return e


func _page() -> LoadoutPage:
	var page := LoadoutPage.new(saved, settings)
	page.save_path = LOADOUTS
	page.settings_path = SETTINGS
	add_child_autofree(page)
	return page


# --- the key ---

func test_the_loadout_key_is_l_rebindable_and_named_in_settings() -> void:
	assert_has(KeyBindings.ACTIONS, &"loadout")
	assert_eq(Array(KeyBindings.new().codes(&"loadout")), [KEY_L])
	assert_eq(TranslationServer.translate(KeyBindingList.label_key(&"loadout")), "LOADOUT (PRACTICE)")
	var keys := KeyBindings.new()
	assert_eq(keys.rebind(&"loadout", KEY_K), KeyBindings.Result.BOUND)
	assert_eq(Array(keys.codes(&"loadout")), [KEY_K])
	var back := KeyBindings.new()
	back.load_dict(keys.to_dict())
	assert_eq(Array(back.codes(&"loadout")), [KEY_K], "kept in the settings file")
	var older := KeyBindings.new()
	older.load_dict({"move_forward": [KEY_I]})
	assert_eq(Array(older.codes(&"loadout")), [KEY_L], "a file from before it keeps the default")


# --- the pause menu's row ---

func test_the_pause_menu_has_a_loadout_row_in_practice_only_and_its_key_works() -> void:
	var menu := PauseMenu.new()
	add_child_autofree(menu)
	watch_signals(menu)
	menu.set_match("Depot", "Elimination", 1, 5)
	assert_false(menu.loadout_button().visible, "no Loadout in a match")
	menu.open()
	menu._unhandled_input(_action(&"loadout"))
	assert_signal_not_emitted(menu, "loadout_requested")
	menu.set_practice("Range", false, 0)
	assert_true(menu.loadout_button().visible)
	assert_eq(menu.loadout_button().text, "LOADOUT")
	assert_eq(menu.loadout_key_text(), "L")
	menu.loadout_button().pressed.emit()
	assert_signal_emit_count(menu, "loadout_requested", 1)
	menu._unhandled_input(_action(&"loadout"))
	assert_signal_emit_count(menu, "loadout_requested", 2, "L asks as the row does")


# --- the menus as the Loadout alone ---

func test_the_menus_open_as_the_loadout_alone_on_the_slot_in_hand_with_back_to_practice() -> void:
	var menus := MenuScreen.new(MatchPicks.new(), settings)
	add_child_autofree(menus)
	menus.open_practice_loadout(Loadout.Slot.SECONDARY)
	var bar := menus.nav_rail()
	assert_true(bar.is_practice())
	assert_true(bar.back_button().is_visible_in_tree())
	assert_eq(bar.back_key_text(), "L")
	for tab: NavRail.Tab in [NavRail.Tab.MATCH, NavRail.Tab.ARMORY, NavRail.Tab.SETTINGS]:
		assert_false(bar.tab_button(tab).is_visible_in_tree(), "only the Loadout tab is left")
	assert_true(bar.tab_button(NavRail.Tab.LOADOUT).is_visible_in_tree())
	var page := menus.loadout_page()
	assert_eq(page.slot(), Loadout.Slot.SECONDARY, "on the slot in hand")
	assert_true(page.gear().range_note_visible())
	assert_true(menus.from_practice())
	menus.leave_loadout()


func test_the_loadout_from_the_menus_has_no_note_and_the_whole_bar() -> void:
	var menus := MenuScreen.new(MatchPicks.new(), settings)
	add_child_autofree(menus)
	menus.show_loadout()
	assert_false(menus.loadout_page().gear().range_note_visible())
	assert_false(menus.from_practice())
	assert_false(menus.nav_rail().is_practice())
	assert_false(menus.nav_rail().back_button().is_visible_in_tree())
	assert_true(menus.nav_rail().tab_button(NavRail.Tab.MATCH).is_visible_in_tree())
	menus.leave_loadout()


func test_back_to_practice_comes_from_the_button_l_and_escape_and_l_does_nothing_in_the_menus() -> void:
	var menus := MenuScreen.new(MatchPicks.new(), settings)
	add_child_autofree(menus)
	watch_signals(menus)
	menus._unhandled_input(_action(&"loadout"))
	assert_signal_not_emitted(menus, "practice_requested")
	menus._unhandled_input(_action(&"ui_cancel"))
	assert_signal_not_emitted(menus, "practice_requested", "Esc in the menus is Main's quit question")
	menus.open_practice_loadout(Loadout.Slot.PRIMARY)
	menus.nav_rail().back_button().pressed.emit()
	assert_signal_emit_count(menus, "practice_requested", 1)
	menus._unhandled_input(_action(&"loadout"))
	assert_signal_emit_count(menus, "practice_requested", 2)
	menus._unhandled_input(_action(&"ui_cancel"))
	assert_signal_emit_count(menus, "practice_requested", 3)
	menus.leave_loadout()


func test_a_page_rebuilt_under_changed_levelling_keeps_the_practice_slot_and_note() -> void:
	var menus := MenuScreen.new(MatchPicks.new(), settings)
	add_child_autofree(menus)
	menus.open_practice_loadout(Loadout.Slot.SECONDARY)
	var page := menus.loadout_page()
	settings.dev.disable_levelling = true
	menus.show_level()
	assert_ne(menus.loadout_page(), page)
	assert_eq(menus.loadout_page().slot(), Loadout.Slot.SECONDARY)
	assert_true(menus.loadout_page().gear().range_note_visible())
	menus.leave_loadout()


# --- the readout's first panel ---

func test_the_first_readout_names_the_loadout_key_as_bound() -> void:
	var readout := HudRangeReadout.new()
	readout.setup(RangeConfig.new(), PlaySession.PLAYER_ID)
	add_child_autofree(readout)
	assert_true(readout.loadout_line_visible())
	assert_eq(readout.loadout_key_text(), "L")
	var e := GameEvent.new()
	e.kind = GameEvent.Kind.BB_IMPACT
	e.actor = PlaySession.PLAYER_ID
	e.position = Vector3(0.0, 0.0, -10.0)
	readout.note(e, [] as Array[RangeTarget])
	readout.on_tick(GameState.new(1, SimTuning.load_default()))
	assert_false(readout.loadout_line_visible(), "only before the first shot")


# --- the spot ---

func test_a_spot_keeps_place_view_stance_slot_and_holster() -> void:
	var kit := saved.carried_kit(false)
	var c := Character.new(0, 0, Vector3(1.0, 0.0, 2.0), 0.0, kit.replicas, kit.bb_weights)
	c.position = Vector3(3.0, 0.5, -4.0)
	c.crouch_amount = 1.0
	c.armament.active = 1
	c.armament.holstered = true
	var spot := PracticeSpot.of(c, 0.7, -0.2, true, true, 99)
	var fresh := Character.new(0, 0, Vector3.ZERO, 0.0, kit.replicas, kit.bb_weights)
	spot.restore(fresh)
	assert_eq(fresh.position, Vector3(3.0, 0.5, -4.0))
	assert_eq(fresh.prev_position, fresh.position, "drawn there at once")
	assert_almost_eq(fresh.yaw, 0.7, 0.0001)
	assert_almost_eq(fresh.pitch, -0.2, 0.0001)
	assert_eq(fresh.crouch_amount, 1.0)
	assert_eq(fresh.armament.active, 1)
	assert_true(fresh.armament.holstered)
	assert_true(spot.challenge_on)
	assert_eq(spot.match_seed, 99)
	spot.slot = 7
	spot.restore(fresh)
	assert_eq(fresh.armament.active, 0, "a slot the kit hasn't falls back to the first")


# --- the range, put back where you stood, with the picks; the key in a match ---

func test_the_range_comes_back_on_the_spot_with_the_picks_and_l_asks_for_the_loadout_there() -> void:
	# a pick made from practice: the primary loaded with 0.3 g BBs
	var page := _page()
	page.open_from_practice(Loadout.Slot.PRIMARY)
	page._set_weight(0.3)
	var kit := saved.carried_kit(false)
	var spot := PracticeSpot.new()
	spot.position = Vector3(2.5, 0.0, -6.0)
	spot.yaw = 0.9
	spot.pitch = 0.1
	spot.crouched = true
	spot.slot = 1
	spot.holstered = true
	spot.challenge_on = true
	spot.match_seed = 31
	var play := PlaySession.new()
	play.practice = true
	play.map_id = "range"
	play.settings = settings
	play.kit = kit
	play.match_seed = spot.match_seed
	play.challenge_on = spot.challenge_on
	play.resume = spot
	add_child_autofree(play)
	# built in _ready: before any tick has moved you
	var c := play.player
	assert_almost_eq(c.armament.bb_weights[0], 0.3, 0.0001, "the new replica comes up")
	assert_eq(c.position, spot.position, "where you stood")
	assert_almost_eq(c.yaw, 0.9, 0.0001)
	assert_eq(c.crouch_amount, 1.0)
	assert_eq(c.armament.active, 1)
	assert_true(c.armament.holstered)
	assert_true(play.challenge_on, "the switch comes back")
	assert_ne(play.state.challenge.phase, RangeChallenge.Phase.RUNNING, "a run is dropped: the challenge starts afresh")
	watch_signals(play)
	play._unhandled_input(_action(&"loadout"))
	assert_signal_emit_count(play, "loadout_requested", 1)
	var again := play.practice_spot()
	assert_eq(again.position, spot.position)
	assert_eq(again.slot, 1)
	assert_true(again.holstered)
	assert_true(again.challenge_on)
	assert_eq(again.match_seed, 31)
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE, "the mouse is let go for the menus")


func test_l_does_nothing_in_a_match() -> void:
	var play := PlaySession.new()
	play.map_id = "depot"
	play.settings = settings
	add_child_autofree(play)
	await wait_physics_frames(2)
	watch_signals(play)
	play._unhandled_input(_action(&"loadout"))
	assert_signal_not_emitted(play, "loadout_requested")
	play._request_loadout()
	assert_signal_not_emitted(play, "loadout_requested", "nor does the pause menu's row reach it")


# --- the whole way there and back ---

func test_the_entry_scene_takes_you_to_the_loadout_and_back_to_the_same_spot() -> void:
	var main: Node = add_child_autofree(MAIN.instantiate())
	await wait_process_frames(2)
	main._picks.map_id = "range"
	main._picks.mode = MatchOptions.MODE_PRACTICE
	main._start_play()
	assert_true(await wait_until(func() -> bool: return main._loading == null, LOAD_LIMIT), "the match loads within LOAD_LIMIT s")
	var play: PlaySession = main._play
	assert_true(play.practice)
	play.player.position = Vector3(1.5, 0.0, -3.0)
	play.player.armament.active = 1
	play._unhandled_input(_action(&"loadout"))
	assert_null(main._play, "the range is freed")
	assert_not_null(main._menus)
	assert_true(main._menus.from_practice())
	assert_true(main._menus.visible)
	assert_eq(main._menus.loadout_page().slot(), Loadout.Slot.SECONDARY, "on the slot in hand")
	main._menus._unhandled_input(_action(&"loadout"))
	assert_not_null(main._play, "the range is built again")
	assert_true(main._play.practice)
	assert_eq(main._play.resume.position, Vector3(1.5, 0.0, -3.0))
	assert_eq(main._play.resume.slot, 1)
	assert_null(main._menus, "no menu nodes live in play")
	main._end_play()


# --- the picks are the one loadout ---

func test_picks_made_with_levelling_off_stay_in_the_sandbox() -> void:
	var progress := Progress.new(LevelTable.read_file(Pool.read_file()))
	saved.rules.follow_progress(progress, true)
	var page := _page()
	page.open_from_practice(Loadout.Slot.SECONDARY)
	page._pick_replica(CYBER)
	assert_eq(saved.carried().replica_id(Loadout.Slot.SECONDARY), CYBER, "the pick is carried")
	assert_eq(saved.carried_kit(false).replicas[1].id, saved.rules.config(saved.rules.pool.item(CYBER)).id,
			"and plays, while levelling is off")
	saved.rules.follow_progress(progress, false)
	assert_eq(saved.carried().replica_id(Loadout.Slot.SECONDARY), CYBER, "kept as picked")
	assert_ne(saved.carried_kit(false).replicas[1].id, saved.rules.config(saved.rules.pool.item(CYBER)).id,
			"but with levelling on it plays as the slot's default: the unlock was never earned")
	page.close()
