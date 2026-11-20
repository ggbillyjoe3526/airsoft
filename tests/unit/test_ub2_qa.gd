extends GutTest
## QA for UB2 (Beta 1 playtest: menus, settings, HUD): the Armory line's focus ring, the vault prompt's words, the clock of
## a round that is over, ButtonWidth's room for a centred overlay, hidden tooltips, the settings' version 6 and the frame
## limit's pick, the kept Loadout, Armory and Settings pages, and the bomb's quiet line.

const MAIN := preload("res://game/main.tscn")

var settings: Settings


func before_each() -> void:
	settings = Settings.new()


func after_each() -> void:
	TooltipWrap.enabled = true
	InputMap.load_from_project_settings()
	await wait_process_frames(2)


func _hud() -> Array:
	var you := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	var hud := Hud.new()
	add_child_autofree(hud)
	hud.size = Vector2(1920.0, 1080.0)
	hud.setup(HudConfig.new(), TeamConfig.new(), ViewConfig.new(), SimTuning.new(), you)
	return [hud, you]


# --- the Armory line's focus ring ---

func test_a_mouse_click_on_the_armory_line_gives_focus_the_ring_does_not_draw_for() -> void:
	# _draw shows the ring only while has_focus(true); a spy StyleBox cannot see the draw (StyleBoxFlat draws natively)
	var dots := ArmoryDots.new(12, 3)
	dots.custom_minimum_size = Vector2(600.0, ArmoryDots.HEIGHT)
	dots.position = Vector2(20.0, 20.0)
	add_child_autofree(dots)
	await wait_process_frames(2)
	dots.grab_focus(true) # what a mouse click does (a pushed click does not focus in a headless window)
	assert_true(dots.has_focus(), "the click focuses the line")
	assert_false(dots.has_focus(true), "but with the ring hidden")
	dots.release_focus()
	dots.grab_focus()
	assert_true(dots.has_focus(true), "keyboard focus shows it")


# --- the vault prompt ---

func test_the_vault_prompt_is_vault_and_the_jump_key_in_capitals_and_follows_a_rebind() -> void:
	# UB3 (owner, 2026-11-20): "VAULT [SPACE]" and "CLIMB [SPACE]", as every prompt; UB2's was the key alone.
	var h := _hud()
	var hud: Hud = h[0]
	assert_eq(Hud.vault_words(), Hud.vault_words().to_upper())
	assert_eq(Hud.vault_words(), "VAULT [%s]" % KeyNames.of_action(&"jump").to_upper())
	hud.set_vault_ready(true, false)
	assert_eq(hud.vault_prompt_text(), Hud.vault_words())
	InputMap.action_erase_events(&"jump")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_V
	InputMap.action_add_event(&"jump", ev)
	assert_eq(Hud.vault_words(), "VAULT [%s]" % KeyNames.of_action(&"jump").to_upper(), "the rebound key")
	assert_ne(Hud.vault_words(), "VAULT [SPACE]")
	hud.set_vault_ready(true, true) # a climb says so
	assert_eq(hud.vault_prompt_text(), Hud.vault_words(true))
	assert_eq(hud.vault_prompt_text(), "CLIMB [%s]" % KeyNames.of_action(&"jump").to_upper())


func test_a_vault_prompt_held_through_the_pause_takes_a_rebound_jump_on_resume() -> void:
	# BP11: up when you paused, it kept the old key after a rebind until you stepped away (its hold is reset each tick).
	var h := _hud()
	var hud: Hud = h[0]
	hud.set_vault_ready(true, false)
	var before := hud.vault_prompt_text()
	InputMap.action_erase_events(&"jump")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_V
	InputMap.action_add_event(&"jump", ev)
	hud.set_vault_ready(true, false)
	assert_eq(hud.vault_prompt_text(), before, "the prompt still up keeps its words")
	hud.refresh_door_prompt() # PlaySession._resume
	assert_eq(hud.vault_prompt_text(), Hud.vault_words())
	assert_ne(hud.vault_prompt_text(), before)


# --- the clock ---

func test_the_clock_reads_zero_once_the_round_is_not_live() -> void:
	var h := _hud()
	var hud: Hud = h[0]
	var you: Character = h[1]
	var state := GameState.new(1, SimTuning.new())
	state.characters.append(you)
	state.round_state.mode = RoundState.Mode.ELIMINATION
	state.round_state.phase = RoundState.Phase.LIVE
	state.round_state.clock = 2.4
	hud.update(state, 1.0, 0.016)
	assert_eq(hud._score._clock_label.text, "0:03", "live: the seconds left, rounded up")
	for phase: RoundState.Phase in [RoundState.Phase.OVER, RoundState.Phase.MATCH_OVER]:
		state.round_state.phase = phase
		state.round_state.clock = 2.4 # a round won with seconds left
		hud.update(state, 1.0, 0.016)
		assert_eq(hud._score._clock_label.text, "0:00", "phase %d reads 0:00" % phase)


# --- ButtonWidth ---

func _button(words: String, align: HorizontalAlignment) -> Button:
	var b := Button.new()
	b.text = words
	b.alignment = align
	var over := Label.new()
	over.text = "OFF"
	b.add_child(over)
	ButtonWidth.overlay(b, over)
	add_child_autofree(b)
	return b


func test_a_centred_button_leaves_the_overlays_room_on_both_sides() -> void:
	var centred := _button("TIMED CHALLENGE", HORIZONTAL_ALIGNMENT_CENTER)
	var left := _button("TIMED CHALLENGE", HORIZONTAL_ALIGNMENT_LEFT)
	await wait_process_frames(2)
	var over := centred.get_meta(ButtonWidth.OVERLAY_META) as Control
	var room := ButtonWidth.OVERLAY_GAP + over.get_combined_minimum_size().x
	var words := centred.get_minimum_size().x
	assert_almost_eq(ButtonWidth._natural(left), words + room, 0.01, "left words: room on the right only")
	assert_almost_eq(ButtonWidth._natural(centred), words + room * 2.0, 0.01, "centred words: both sides")
	var g := ButtonWidth.group([centred, left])
	assert_almost_eq(g.width(), words + room * 2.0, 0.01, "the group takes the widest")


# --- tooltips ---

func test_tooltips_off_hide_a_new_tooltip_label_and_on_leave_it_shown() -> void:
	var popup := Window.new()
	popup.visible = false
	add_child_autofree(popup)
	var label := Label.new()
	label.theme_type_variation = TooltipWrap.LABEL_TYPE
	TooltipWrap.enabled = false
	TooltipWrap._on_node_added(label)
	assert_false(label.visible, "kept hidden with tooltips off")
	popup.add_child(label)
	TooltipWrap.keep_hidden(label)
	await wait_process_frames(2)
	assert_false(popup.visible, "its popup closed")
	var other := Label.new()
	other.theme_type_variation = TooltipWrap.LABEL_TYPE
	other.visible = true
	TooltipWrap.enabled = true
	TooltipWrap._on_node_added(other)
	assert_true(other.visible, "on: untouched")
	other.free()


func test_apply_tooltips_follows_the_setting_and_a_plain_label_is_left_alone() -> void:
	settings.tooltips = false
	SettingsApply.apply_tooltips(settings)
	assert_false(TooltipWrap.enabled)
	var plain := Label.new()
	TooltipWrap._on_node_added(plain)
	assert_true(plain.visible, "only tooltip labels are hidden")
	plain.free()
	settings.tooltips = true
	SettingsApply.apply_tooltips(settings)
	assert_true(TooltipWrap.enabled)


# --- settings version 6 ---

func test_a_v5_save_on_the_old_defaults_moves_to_the_new_ones() -> void:
	var old := {"gauge_patterns": true, "hud": {"panel_opacity": 1.0}}
	var moved := Settings.migrate_defaults(old, 5)
	assert_eq(moved["gauge_patterns"], false)
	assert_eq((moved["hud"] as Dictionary)["panel_opacity"], HudPrefs.PANEL_OPACITY_DEFAULT)
	assert_eq(HudPrefs.PANEL_OPACITY_DEFAULT, 0.6)
	assert_true(old["gauge_patterns"], "the file's own dictionary is not changed")
	assert_eq((old["hud"] as Dictionary)["panel_opacity"], 1.0)


func test_a_v5_save_keeps_a_value_the_player_chose_and_v6_is_left_alone() -> void:
	var chosen := {"gauge_patterns": false, "hud": {"panel_opacity": 0.8}}
	var moved := Settings.migrate_defaults(chosen, 5)
	assert_eq(moved["gauge_patterns"], false)
	assert_eq((moved["hud"] as Dictionary)["panel_opacity"], 0.8, "chosen 80 % stays")
	var v6 := {"gauge_patterns": true, "hud": {"panel_opacity": 1.0}}
	var same := Settings.migrate_defaults(v6, 6)
	assert_eq(same["gauge_patterns"], true, "a v6 save's chosen patterns stay")
	assert_eq((same["hud"] as Dictionary)["panel_opacity"], 1.0, "and solid HUD")
	# odd shapes in an old file do not crash it
	var odd := Settings.migrate_defaults({"gauge_patterns": "yes", "hud": 7}, 3)
	assert_eq(odd["gauge_patterns"], "yes")
	assert_eq(Settings.migrate_defaults({}, 1).size() >= 0, true)


func test_an_old_file_on_disk_loads_with_the_new_defaults_and_a_v6_file_keeps_its_picks() -> void:
	var dir := "user://ub2_qa"
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("old.save")
	var src := Settings.new()
	src.gauge_patterns = true
	src.hud.panel_opacity = 1.0
	assert_true(src.save(path))
	# the current version keeps what was chosen
	var back := Settings.new()
	back.load_file(path)
	assert_true(back.gauge_patterns)
	assert_eq(back.hud.panel_opacity, 1.0)
	# the same values in a version 5 file are the old defaults
	var data := src.to_dict()
	assert_true(SaveFile.write(path, Settings.KIND, 5, data))
	var old := Settings.new()
	old.load_file(path)
	assert_false(old.gauge_patterns)
	assert_eq(old.hud.panel_opacity, HudPrefs.PANEL_OPACITY_DEFAULT)
	DirAccess.remove_absolute(path)


func test_the_defaults_are_the_new_ones() -> void:
	var s := Settings.new()
	assert_false(s.gauge_patterns)
	assert_true(s.tooltips)
	assert_eq(s.frame_limit, Settings.UNLIMITED)
	assert_eq(s.frame_limit_pick, 240)
	assert_eq(Settings.VERSION, 7, "UB3 made the haze one switch")


func test_the_frame_limit_pick_is_saved_read_and_clamped() -> void:
	settings.frame_limit_pick = 144
	var t := Settings.new()
	t.from_dict(settings.to_dict())
	assert_eq(t.frame_limit_pick, 144)
	var low := Settings.new()
	low.from_dict({"frame_limit_pick": 30.0000001, "frame_limit": 0})
	assert_eq(low.frame_limit_pick, 30)
	var wild := Settings.new()
	wild.from_dict({"frame_limit_pick": 9000, "frame_limit": 0})
	assert_eq(wild.frame_limit_pick, 240, "a typo reads as the default, as every other number does")
	var frac := Settings.new()
	frac.from_dict({"frame_limit_pick": 99.6})
	assert_eq(frac.frame_limit_pick, 100)
	var junk := Settings.new()
	junk.from_dict({"frame_limit_pick": "fast", "frame_limit": 120})
	assert_eq(junk.frame_limit_pick, 120, "unreadable: the limit in force")
	var none := Settings.new()
	none.from_dict({"frame_limit": 0})
	assert_eq(none.frame_limit_pick, 240, "no pick and no limit: 240")
	assert_eq(Settings.nearest_frame_limit(0.0), Settings.UNLIMITED)
	assert_eq(Settings.nearest_frame_limit(-5.0), Settings.UNLIMITED)
	assert_eq(Settings.nearest_frame_limit(INF), 360)
	assert_eq(Settings.nearest_frame_limit(1.0), 30)
	assert_eq(Settings.nearest_frame_limit(NAN), Settings.UNLIMITED)


# --- kept pages ---

func _menus() -> MenuScreen:
	var m := MenuScreen.new(MatchPicks.new(), settings)
	add_child_autofree(m)
	return m


func test_prepared_pages_are_hidden_and_the_tabs_show_the_same_instances() -> void:
	var m := _menus()
	assert_null(m.kept_loadout())
	m.prepare_pages()
	var loadout := m.kept_loadout()
	var armory := m.kept_armory()
	assert_not_null(loadout)
	assert_not_null(armory)
	assert_false(loadout.visible)
	assert_false(armory.visible)
	assert_true(m.match_page().visible)
	assert_null(m.loadout_page(), "not the current tab")
	assert_null(m.armory_page())
	m.prepare_pages() # again: nothing is built twice
	assert_same(m.kept_loadout(), loadout)
	m.show_loadout()
	assert_same(m.loadout_page(), loadout)
	assert_true(loadout.visible)
	assert_false(armory.visible)
	assert_false(m.match_page().visible)
	m.show_armory()
	assert_same(m.armory_page(), armory)
	assert_false(loadout.visible, "saved and hidden")
	assert_null(m.loadout_page())
	m.show_loadout()
	assert_same(m.loadout_page(), loadout, "the same page the next time")
	m.show_match()
	assert_true(m.match_page().visible)
	assert_false(loadout.visible)
	assert_eq(m.page_tab(), NavRail.Tab.MATCH)


func test_leaving_frees_the_kept_pages_and_a_hidden_one_takes_no_focus_or_keys() -> void:
	var m := _menus()
	m.prepare_pages()
	var loadout := m.kept_loadout()
	var armory := m.kept_armory()
	var before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	# a hidden Loadout answers no number key
	var saved := SavedLoadouts.shared()
	var key := InputEventKey.new()
	key.keycode = KEY_2
	key.pressed = true
	var current := saved.current
	loadout._unhandled_input(key)
	assert_eq(saved.current, current, "hidden: the 2 key picks nothing")
	m.leave_loadout()
	m.leave_armory()
	await wait_process_frames(2)
	assert_null(m.kept_loadout())
	assert_null(m.kept_armory())
	assert_false(is_instance_valid(loadout))
	assert_false(is_instance_valid(armory))
	assert_lt(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), before, "their nodes went")
	m.show_loadout()
	assert_not_null(m.loadout_page(), "built again when asked for")
	m.leave_loadout()
	assert_eq(m.page_tab(), NavRail.Tab.MATCH, "leaving the shown page falls back to Match")


func test_the_menus_free_their_kept_pages_with_themselves() -> void:
	var m := MenuScreen.new(MatchPicks.new(), settings)
	add_child(m)
	m.prepare_pages()
	var loadout := m.kept_loadout()
	var armory := m.kept_armory()
	m.queue_free()
	await wait_process_frames(2)
	assert_false(is_instance_valid(loadout))
	assert_false(is_instance_valid(armory))


func test_settings_are_kept_between_openings_start_on_the_first_tab_and_go_with_the_menus() -> void:
	var main: Node = add_child_autofree(MAIN.instantiate())
	await wait_process_frames(2)
	main._open_settings()
	var first: SettingsScreen = main._settings_screen
	assert_not_null(first)
	first.show_display_colour()
	assert_ne(first.current_tab(), 0)
	first.close()
	assert_null(main._settings_screen)
	assert_same(main._settings_kept, first, "kept hidden")
	assert_false(first.visible)
	main._open_settings()
	assert_same(main._settings_screen, first, "the same screen")
	assert_null(main._settings_kept)
	assert_eq(first.current_tab(), 0, "back on the first tab")
	assert_true(first.visible)
	first.close()
	main._start_play.call_deferred()
	await wait_process_frames(3)
	assert_null(main._settings_kept, "freed with the menus on play")
	assert_false(is_instance_valid(first))


# --- retheme ---

func test_a_colour_pick_leaves_the_old_theme_and_retheme_hands_over_the_new_one() -> void:
	var before := GameTheme.accent
	var old := GameTheme.get_theme()
	var holder := Control.new()
	holder.theme = old
	var inner := Label.new()
	inner.theme = old
	holder.add_child(inner)
	var own := Control.new()
	var mine := Theme.new()
	own.theme = mine
	holder.add_child(own)
	add_child_autofree(holder)
	var pick := UiColours.Pick.values()[0] as UiColours.Pick
	for p in UiColours.ACCENTS.size():
		if UiColours.ACCENTS[p] != before:
			pick = p as UiColours.Pick
			break
	assert_true(GameTheme.use_colour(pick))
	var now := GameTheme.get_theme()
	assert_ne(now, old, "a new Theme, the old one not mutated")
	GameTheme.retheme(holder)
	assert_same(holder.theme, now)
	assert_same(inner.theme, now, "a child too")
	assert_same(own.theme, mine, "a theme of its own stays")
	assert_false(GameTheme.use_colour(pick), "the same colour again changes nothing")
	# restore the colour for later tests
	for p in UiColours.ACCENTS.size():
		if UiColours.ACCENTS[p] == before:
			GameTheme.use_colour(p as UiColours.Pick)


# --- the bomb's quiet line ---

func test_the_quiet_line_shows_for_its_time_and_a_new_pick_up_resets_it() -> void:
	var p := HudPlantPrompt.new(2.5)
	add_child_autofree(p)
	p.show_for(HudPlant.Prompt.NONE, true, 0.0)
	assert_true(p.visible, "on pick-up")
	p.show_for(HudPlant.Prompt.NONE, true, 2.0)
	assert_true(p.visible, "still 0.5 s left")
	p.show_for(HudPlant.Prompt.NONE, true, 0.6)
	assert_false(p.visible, "gone after 2.5 s")
	p.show_for(HudPlant.Prompt.NONE, true, 1.0)
	assert_false(p.visible, "stays gone while carried")
	p.show_for(HudPlant.Prompt.NONE, false, 0.016) # dropped
	p.show_for(HudPlant.Prompt.NONE, true, 0.016) # picked up again
	assert_true(p.visible, "a new pick-up shows it again")
	# a prompt over it hides the line while its time runs on: the line comes back for what is left, then goes
	p.show_for(HudPlant.Prompt.PLANT, true, 0.5)
	assert_eq(p.quiet_text(), "", "hidden under the prompt")
	assert_ne(p.text(), "", "the prompt shows")
	p.show_for(HudPlant.Prompt.NONE, true, 0.016)
	assert_ne(p.quiet_text(), "", "back once the prompt goes, with time left")
	p.show_for(HudPlant.Prompt.NONE, true, 2.0)
	assert_eq(p.quiet_text(), "", "the prompt's 0.5 s counted: gone by 2.5 s from the pick-up")


func test_a_bomb_carried_with_no_notice_time_shows_no_quiet_line() -> void:
	var p := HudPlantPrompt.new(0.0)
	add_child_autofree(p)
	p.show_for(HudPlant.Prompt.NONE, true, 0.016)
	assert_false(p.visible)
	var cfg := HudConfig.new()
	assert_eq(cfg.bomb_carry_notice_time, 2.5)


# --- stale kept pages ---

func test_a_stale_kept_armory_is_built_again_hidden_and_one_never_prepared_stays_gone() -> void:
	var m := _menus()
	m.prepare_pages()
	var old := m.kept_armory()
	settings.dev.disable_levelling = not settings.dev.disable_levelling
	assert_true(old.stale())
	m.show_level()
	assert_null(m.kept_armory(), "freed at once")
	await wait_process_frames(2)
	var fresh := m.kept_armory()
	assert_not_null(fresh, "built again, a frame on")
	assert_ne(fresh, old)
	assert_false(fresh.visible, "hidden")
	assert_null(m.armory_page())
	assert_true(m.match_page().visible)
	# a menus that never prepared its pages builds none for a stale one
	var lazy := _menus()
	lazy.show_armory()
	settings.dev.disable_levelling = not settings.dev.disable_levelling
	lazy.show_match()
	lazy.show_level()
	await wait_process_frames(2)
	assert_null(lazy.kept_armory())


func test_a_stale_armory_being_shown_is_rebuilt_shown() -> void:
	var m := _menus()
	m.prepare_pages()
	m.show_armory()
	settings.dev.disable_levelling = not settings.dev.disable_levelling
	m.show_level()
	await wait_process_frames(2)
	assert_not_null(m.armory_page())
	assert_true(m.armory_page().visible)
	assert_eq(m.page_tab(), NavRail.Tab.ARMORY)
	assert_eq(m.get_children().filter(func(c: Node) -> bool: return c is ArmoryPage).size(), 1, "never two")


func test_the_colour_change_rebuild_prepares_pages_only_if_the_menus_still_stand() -> void:
	var main: Node = add_child_autofree(MAIN.instantiate())
	await wait_process_frames(2)
	var before: MenuScreen = main._menus
	main._prepare_menu_pages_soon()
	main._free_screens() # menus gone inside the wait
	main._build_screens()
	await wait_process_frames(main.PREPARE_WAIT_FRAMES + 2)
	assert_not_same(main._menus, before)
	assert_true(is_instance_valid(main._menus), "no error from the old menus; headless builds no pages")
