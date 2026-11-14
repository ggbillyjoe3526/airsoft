extends GutTest
## UF1: the seven UI fixes from the owner's playtest (2026-11-03): the HUD opacity fades only backgrounds, the HUD tab
## shows whole without scrolling, the Armory marks the level clicked, the rail's teal rule sits on the lit tab's card,
## SWITCH REPLICA's pop-up replaces the Loadout's SWAP row, nothing sounds under the loading screen, and the scoreboard
## is compact and never draws over the round's table or the match's summary.

const LOADOUTS := "user://test_uf1_loadouts.save"
const SETTINGS := "user://test_uf1_settings.save"
const SAVE := "user://test_uf1_settings_screen.save"
const AEG := "000002"
const PISTOL := "000001"
const CYBER := "000019"

var map: MapData = null
var you: Character = null


func before_all() -> void:
	map = MapData.load_map("depot", MapStyle.new(), 1)
	you = Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())


func after_all() -> void:
	for path: String in [LOADOUTS, SETTINGS, SAVE]:
		SaveFile.remove(path)


func _hud() -> Hud:
	var hud := Hud.new()
	add_child_autofree(hud)
	hud.setup(HudConfig.new(), TeamConfig.new(), ViewConfig.new(), SimTuning.new(), you)
	var cfg := MinimapConfig.new()
	hud.setup_minimap(map, cfg, MinimapHearing.new(cfg), "Depot", 1)
	return hud


func _faded(p: float) -> Hud:
	var hud := _hud()
	var prefs := HudPrefs.new()
	prefs.panel_opacity = p
	hud.apply_prefs(prefs)
	return hud


# --- 1. HUD opacity: backgrounds only ---


func test_the_opacity_fades_the_panel_s_background_not_its_words() -> void:
	var hud := _faded(0.3)
	var panel := hud._replica
	assert_almost_eq(panel.modulate.a, 1.0, 0.001, "the panel's words, numbers and icons draw solid")
	var frame := panel.find_child("Frame", false, false) as PanelContainer
	var box := frame.get_theme_stylebox("panel") as StyleBoxFlat
	assert_almost_eq(box.bg_color.a, HudStyle.BACKING_PANEL * 0.3, 0.001, "the glass fades")
	for l: Label in [panel._mag, panel._spare]:
		assert_almost_eq(l.modulate.a, 1.0, 0.001, l.name)
	var count := panel._mag.get_theme_color("font_color")
	assert_almost_eq(count.a, GameTheme.TEXT.a, 0.001, "the count keeps its own colour")


func test_the_opacity_fades_the_minimap_s_picture_and_backing_not_its_marks() -> void:
	var hud := _faded(0.4)
	var mini := hud._minimap
	assert_almost_eq(mini.modulate.a, 1.0, 0.001, "the minimap's marks and caption words draw solid")
	assert_almost_eq(HudStyle.opacity_of(mini._view), 0.4, 0.001, "its field picture and backing fade")
	assert_almost_eq(HudStyle.backing_on(mini._view, 1.0).a, 0.4, 0.001)
	assert_almost_eq(HudStyle.opacity_of(mini), 0.4, 0.001, "the ring fades")
	assert_almost_eq(mini._area.modulate.a, 1.0, 0.001, "the area's name stays solid")


func test_back_to_full_the_backgrounds_are_as_built() -> void:
	var hud := _faded(0.25)
	var prefs := HudPrefs.new()
	prefs.panel_opacity = 1.0
	hud.apply_prefs(prefs)
	var frame := hud._replica.find_child("Frame", false, false) as PanelContainer
	assert_almost_eq((frame.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a, HudStyle.BACKING_PANEL, 0.001)
	assert_almost_eq(HudStyle.opacity_of(hud._minimap._view), 1.0, 0.001)


func test_the_preview_fades_its_panel_s_background_only() -> void:
	var preview := HudPreview.new()
	add_child_autofree(preview)
	var prefs := HudPrefs.new()
	prefs.panel_opacity = 0.5
	preview.show_prefs(prefs)
	assert_almost_eq(preview._panel.modulate.a, 1.0, 0.001)
	assert_almost_eq(HudStyle.opacity_of(preview._panel), 0.5, 0.001)


# --- 2. the HUD tab shows whole ---


func test_the_hud_tab_needs_no_scrolling_at_1080p() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(1920, 1080)
	add_child_autofree(view)
	var holder := Control.new()
	holder.size = Vector2(1920.0 - NavRail.WIDTH, 1080.0)
	view.add_child(holder)
	var screen := SettingsScreen.new()
	screen.settings = Settings.new(PlayTuning.new())
	screen.save_path = SAVE
	screen.in_menus = true
	holder.add_child(screen)
	screen.open()
	var page := screen._hud_page
	screen._tabs.current_tab = page.get_parent().get_parent().get_index()
	await wait_process_frames(4)
	var scroll := page.get_parent().get_parent() as ScrollContainer
	assert_not_null(scroll)
	assert_lte(page.get_parent().get_combined_minimum_size().y, scroll.size.y + 0.5,
			"the tab's rows fit its height: nothing to scroll to")
	assert_false(scroll.get_v_scroll_bar().visible, "no scroll bar")
	var room := scroll.get_global_rect().grow(1.0)
	assert_true(room.encloses(page._thumbs_row.get_global_rect()), "the minimap's samples show")
	assert_true(room.encloses(page.minimap_zoom().get_global_rect()), "the minimap's zoom shows")
	assert_true(room.encloses(page._panels.get_global_rect()), "the HUD opacity shows")


# --- 3. the Armory marks the level clicked ---


func test_a_click_on_a_dot_marks_it_and_its_card() -> void:
	var page := ArmoryPage.new(Settings.new(), Progress.new(LevelTable.shared()), Records.new())
	add_child_autofree(page)
	await wait_process_frames(2)
	var dots := page.summary().bar()
	var track := page.track()
	assert_eq(dots.picked(), -1, "none picked at first")
	assert_eq(track.picked(), -1)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = dots.dot_position(6)
	dots._gui_input(click)
	assert_eq(dots.picked(), 6, "the dot clicked is marked")
	assert_eq(track.picked(), 6)
	var face := (track.row(6) as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat
	assert_eq(face.border_color, GameTheme.TEXT, "its card is edged in white")
	assert_eq(face.border_width_left, ArmoryTrack.PICKED_EDGE)
	click.position = dots.dot_position(2)
	dots._gui_input(click)
	assert_eq(dots.picked(), 2)
	var before := (track.row(6) as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat
	assert_ne(before.border_color, GameTheme.TEXT, "the card picked before goes back to its own face")
	assert_eq(((track.row(2) as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat).border_color, GameTheme.TEXT)


# --- 4. the rail's rule ---


func test_the_lit_tab_s_rule_sits_on_its_card() -> void:
	var rail := NavRail.new()
	rail.size = Vector2(NavRail.WIDTH, 1080.0)
	add_child_autofree(rail)
	await wait_process_frames(2)
	for tab: NavRail.Tab in [NavRail.Tab.MATCH, NavRail.Tab.SETTINGS]:
		rail.set_current(tab)
		var b := rail.tab_button(tab)
		var rule := b.find_child("Rule", false, false) as ColorRect
		assert_true(rule.visible)
		var r := rule.get_global_rect()
		var card := b.get_global_rect()
		assert_true(card.encloses(r), "the rule %s inside the card %s" % [r, card])
		assert_almost_eq(r.position.x, card.position.x, 0.5, "on the card's left edge")
		assert_almost_eq(r.position.y - card.position.y, card.end.y - r.end.y, 0.5, "centred on its height")


# --- 5. SWITCH REPLICA ---


func _page() -> LoadoutPage:
	SaveFile.remove(LOADOUTS)
	var view := SubViewport.new()
	view.size = Vector2i(1920, 1080)
	add_child_autofree(view)
	var saved := SavedLoadouts.new(LoadoutRules.standard())
	var page := LoadoutPage.new(saved, Settings.new())
	page.save_path = LOADOUTS
	page.settings_path = SETTINGS
	view.add_child(page)
	return page


func test_the_swap_row_is_gone_and_each_card_has_switch_replica() -> void:
	var page := _page()
	await wait_process_frames(2)
	var gear := page.gear()
	assert_null(gear.find_child("Swap", true, false))
	for slot: Loadout.Slot in LoadoutFacts.SLOTS:
		var b := gear.switch_button(slot)
		assert_true(b.is_visible_in_tree())
		assert_eq(b.text, tr("LOADOUT_SWITCH_REPLICA").to_upper())
	assert_false(gear.switching(), "the pop-up starts closed")


func test_switch_replica_opens_the_pop_up_for_its_slot() -> void:
	var page := _page()
	await wait_process_frames(2)
	var gear := page.gear()
	gear.switch_button(Loadout.Slot.SECONDARY).pressed.emit()
	assert_true(gear.switching())
	assert_eq(page.slot(), Loadout.Slot.SECONDARY, "the card's slot is picked")
	assert_eq(gear.switcher().slot(), Loadout.Slot.SECONDARY)
	assert_true(gear.replica_card(PISTOL).is_picked(), "the replica carried there is ringed")
	assert_false(gear.replica_card(AEG).is_picked())
	assert_eq(gear.replica_ids().size(), 6,
			"every public replica, the Compact SMG and the Pump Shotgun since 2026-11-14")


func test_picking_a_replica_carries_it_and_closes() -> void:
	var page := _page()
	await wait_process_frames(2)
	var gear := page.gear()
	gear.open_switch(Loadout.Slot.SECONDARY)
	gear.replica_card(CYBER).pressed.emit()
	assert_false(gear.switching(), "closed")
	assert_eq(page.saved.carried().equipped, PackedStringArray([AEG, CYBER]))


func test_picking_the_other_slot_s_replica_swaps_the_two() -> void:
	var page := _page()
	await wait_process_frames(2)
	var gear := page.gear()
	gear.open_switch(Loadout.Slot.PRIMARY)
	gear.replica_card(PISTOL).pressed.emit()
	assert_eq(page.saved.carried().equipped, PackedStringArray([PISTOL, AEG]), "the rifle went to the secondary")
	gear.open_switch(Loadout.Slot.SECONDARY)
	gear.replica_card(PISTOL).pressed.emit()
	assert_eq(page.saved.carried().equipped, PackedStringArray([AEG, PISTOL]), "and back")


func test_close_esc_and_the_shade_close_it_with_nothing_changed() -> void:
	var page := _page()
	await wait_process_frames(2)
	var gear := page.gear()
	var before := page.saved.carried().equipped.duplicate()
	gear.open_switch(Loadout.Slot.PRIMARY)
	gear.switcher().close_button().pressed.emit()
	assert_false(gear.switching())
	gear.open_switch(Loadout.Slot.PRIMARY)
	assert_true(page.back_out(), "Esc leaves the pop-up first")
	assert_false(gear.switching())
	assert_false(page.back_out(), "then nothing is left to leave")
	gear.open_switch(Loadout.Slot.PRIMARY)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	gear.switcher()._on_shade_input(click)
	assert_false(gear.switching())
	assert_eq(page.saved.carried().equipped, before)


func test_the_pop_up_fits_the_screen_with_its_cards_inside() -> void:
	var page := _page()
	await wait_process_frames(2)
	var gear := page.gear()
	gear.open_switch(Loadout.Slot.PRIMARY)
	await wait_process_frames(3)
	var screen := Rect2(Vector2.ZERO, Vector2(1920.0, 1080.0))
	var panel := gear.switcher().find_child("Panel", true, false) as Control
	assert_true(screen.encloses(panel.get_global_rect()), "panel %s" % panel.get_global_rect())
	for id: String in gear.replica_ids():
		var card := gear.replica_card(id).get_global_rect()
		assert_true(panel.get_global_rect().encloses(card), "%s card %s" % [id, card])
		assert_true(card.encloses(gear.list_picture(id).get_global_rect()), "%s picture inside its card" % id)


func test_loadout_keys_wait_while_the_pop_up_is_open() -> void:
	var page := _page()
	page.saved.create()
	page.saved.use(0)
	await wait_process_frames(2)
	var gear := page.gear()
	gear.open_switch(Loadout.Slot.PRIMARY)
	var key := InputEventKey.new()
	key.keycode = KEY_2
	key.pressed = true
	page._unhandled_input(key)
	assert_eq(page.saved.current, 0, "a number key changes no loadout under the pop-up")
	gear.close_switch()
	page._unhandled_input(key)
	assert_eq(page.saved.current, 1, "and does once it is closed")


func test_opening_and_closing_the_pop_up_leaves_no_nodes_behind() -> void:
	var page := _page()
	await wait_process_frames(2)
	var gear := page.gear()
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	for i in 6:
		gear.open_switch(i % 2 as Loadout.Slot)
		await wait_process_frames(1)
		gear.close_switch()
	await wait_process_frames(2)
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes)


# --- 6. silent loading screen ---


func test_the_ambience_waits_for_start_ambience() -> void:
	var audio := SimAudio.new()
	add_child_autofree(audio)
	var cfg := (load("res://game/config/play_tuning.tres") as PlayTuning).sound
	audio.setup(cfg, [] as Array[StringName], BodyConfig.new(), null, map)
	assert_false(audio._beds.is_empty())
	for bed in audio._beds:
		assert_false(bed.playing, "nothing plays once set up")
	assert_false(audio.ambience_started())
	audio.start_ambience()
	for bed in audio._beds:
		assert_true(bed.playing)
	audio.start_ambience()
	assert_true(audio.ambience_started(), "a second call changes nothing")


func test_nothing_sounds_behind_the_loading_screen_until_continue() -> void:
	var main: Node = add_child_autofree(preload("res://game/main.tscn").instantiate())
	await wait_process_frames(2)
	main.continue_after_loading = true
	main._picks.mode = MatchOptions.MODE_PRACTICE
	main._start_play()
	var play: PlaySession = main._play
	assert_true(await wait_until(func() -> bool: return play.ready_for_go(), 40.0), "fully loaded")
	assert_true(play.holding())
	assert_false(play._audio.ambience_started(), "the loading screen is silent")
	main._loading.continue_button().pressed.emit()
	assert_true(play._audio.ambience_started(), "Continue starts the ambience")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# --- 7. the scoreboard ---


func test_tab_over_the_round_s_table_hides_the_table_and_its_stamp() -> void:
	var hud := _hud()
	var rr := hud.round_result()
	rr.set_covered(true)
	assert_false(rr.visible)
	assert_true(rr.covered())
	rr.set_covered(false)
	assert_false(rr.covered())


func test_a_6v6_board_ends_above_the_replica_panel_at_1080p() -> void:
	var rows := 2 * (HudTable.TEAM_HEIGHT + HudTable.HEAD_HEIGHT + 6.0 * HudTable.ROW_HEIGHT) + HudTable.SECTION_GAP
	var board := Hud.BOARD_TOP + HudTable.PAD.y * 2.0 + HudTable.HEADING_SIZE + HudTable.HEADING_BELOW + rows
	assert_lt(board, 1080.0 - 220.0, "the board's foot (%d px) clears the replica panel's top" % roundi(board))
	assert_eq(HudTable.ROW_HEIGHT, 30.0, "compact rows")


## QA (attempt 1, advisory): the pop-up never stays open behind Customise or across a hidden page.
func test_customise_and_hiding_the_page_close_the_pop_up() -> void:
	var page := _page()
	await wait_process_frames(2)
	var gear := page.gear()
	gear.open_switch(Loadout.Slot.PRIMARY)
	page.show_customise()
	assert_false(gear.switching(), "Customise closes it")
	page.show_gear()
	gear.open_switch(Loadout.Slot.SECONDARY)
	page.visible = false
	assert_false(gear.switching(), "another tab closes it")
