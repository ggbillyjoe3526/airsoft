extends GutTest
## The Loadout and Customise screens (LO2; concepts step9-loadout): the tab opens the gear page, keys 1 to 5 pick a saved
## loadout, an edit reaches the loadout carried and is saved, the Performance sheet says when the site limit capped the
## energy, the Realistic colours switch writes the setting, every replica's picture sits inside its card, and the page frees
## everything it made.

const MAIN := preload("res://game/main.tscn")
const LOADOUTS := "user://test_lo2_loadouts.save"
const SETTINGS := "user://test_lo2_settings.save"
const AEG := "000002"
const PISTOL := "000001"
const CYBER := "000019"
const LIPO := "000015"
const RED_GAS := "000008"

var saved: SavedLoadouts
var settings: Settings


func before_each() -> void:
	SaveFile.remove(LOADOUTS)
	SaveFile.remove(SETTINGS)
	saved = SavedLoadouts.new(LoadoutRules.standard())
	settings = Settings.new()


func after_each() -> void:
	# nodes a page rebuilt or freed are let go at the end of a frame
	await wait_process_frames(2)
	SaveFile.remove(LOADOUTS)
	SaveFile.remove(SETTINGS)


func _page() -> LoadoutPage:
	var page := LoadoutPage.new(saved, settings)
	page.save_path = LOADOUTS
	page.settings_path = SETTINGS
	add_child_autofree(page)
	return page


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e


func _escape() -> InputEventAction:
	var e := InputEventAction.new()
	e.action = &"ui_cancel"
	e.pressed = true
	return e


func _words(root: Node) -> PackedStringArray:
	var out := PackedStringArray()
	for l in root.find_children("*", "Label", true, false):
		out.append((l as Label).text)
	return out


# --- the tab ---

func test_the_loadout_tab_is_on_and_opens_the_gear_page() -> void:
	var menus := MenuScreen.new(MatchPicks.new(), settings)
	add_child_autofree(menus)
	assert_false(menus.nav_rail().tab_button(NavRail.Tab.LOADOUT).disabled)
	assert_false(menus.nav_rail().tab_button(NavRail.Tab.ARMORY).disabled, "the Armory is built (AR1)")
	assert_null(menus.loadout_page(), "built when asked for")
	menus.show_loadout()
	var page := menus.loadout_page()
	assert_not_null(page)
	assert_false(menus.match_page().visible)
	assert_eq(menus.nav_rail().current(), NavRail.Tab.LOADOUT)
	assert_eq(menus.page_tab(), NavRail.Tab.LOADOUT)
	assert_true(page.gear().visible)
	assert_false(page.customising())
	var words := _words(page)
	for expected: String in ["LOADOUT", "PERFORMANCE", "PRIMARY", "SECONDARY", "GRENADES"]:
		assert_true(words.has(expected), expected)
	assert_eq(page.gear().switch_button(Loadout.Slot.PRIMARY).text, "SWITCH REPLICA", "UF1: no SWAP row")
	assert_eq(page.gear().customise_button().text, "CUSTOMISE")


func test_the_match_tab_brings_the_match_page_back_and_frees_the_loadout_page() -> void:
	var menus := MenuScreen.new(MatchPicks.new(), settings)
	add_child_autofree(menus)
	menus.show_loadout()
	var page := menus.loadout_page()
	menus.show_match()
	assert_null(menus.loadout_page())
	assert_true(page.is_queued_for_deletion())
	assert_true(menus.match_page().visible)
	assert_eq(menus.nav_rail().current(), NavRail.Tab.MATCH)


func test_the_entry_scene_shows_the_page_for_the_tab_and_the_match_tab_goes_back() -> void:
	var main: Node = add_child_autofree(MAIN.instantiate())
	await wait_process_frames(2)
	main._on_tab(NavRail.Tab.LOADOUT)
	var menus: MenuScreen = main._menus
	assert_not_null(menus.loadout_page())
	main._on_tab(NavRail.Tab.MATCH)
	assert_null(menus.loadout_page(), "the Match tab frees the Loadout")
	assert_eq(menus.nav_rail().current(), NavRail.Tab.MATCH)


func test_escape_in_customise_goes_back_to_the_gear_page_not_to_the_quit_question() -> void:
	var main: Node = add_child_autofree(MAIN.instantiate())
	await wait_process_frames(2)
	main._on_tab(NavRail.Tab.LOADOUT)
	var menus: MenuScreen = main._menus
	var page := menus.loadout_page()
	page.show_customise(0)
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	Input.parse_input_event(cancel)
	await wait_process_frames(2)
	assert_false(page.customising(), "the first Esc leaves Customise")
	assert_true(menus.visible, "and stays in the menus")
	cancel = InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	Input.parse_input_event(cancel)
	await wait_process_frames(2)
	assert_not_null(main._quit_prompt, "the next one asks QUIT GAME? (owner, 2026-10-29)")


# --- keys 1 to 5 and the strip ---

func test_keys_1_to_5_carry_the_loadout_in_that_place() -> void:
	saved.create()
	saved.create()
	var page := _page()
	assert_eq(saved.current, 2)
	page._unhandled_input(_key(KEY_1))
	assert_eq(saved.current, 0)
	page._unhandled_input(_key(KEY_3))
	assert_eq(saved.current, 2)
	# BP3: with QUIT GAME? up the keys wait (the prompt stops keys only after every _unhandled_input has had them).
	var prompt := QuitPrompt.new()
	add_child_autofree(prompt)
	page._unhandled_input(_key(KEY_1))
	assert_eq(saved.current, 2, "the prompt holds the number keys")
	prompt.close()
	await wait_process_frames(2)
	page._unhandled_input(_key(KEY_1))
	assert_eq(saved.current, 0, "and lets them go once it closes")
	page._unhandled_input(_key(KEY_3))
	page._unhandled_input(_key(KEY_5))
	assert_eq(saved.current, 2, "no fifth loadout: nothing changes")
	page._unhandled_input(_key(KEY_2))
	assert_eq(saved.current, 1)
	assert_true(page.strip().card(1).is_picked(), "the strip follows")
	assert_false(page.strip().card(2).is_picked())


func test_the_strip_creates_renames_duplicates_replaces_and_removes() -> void:
	var page := _page()
	var strip := page.strip()
	strip.new_card().pressed.emit()
	assert_eq(saved.slots.size(), 2)
	assert_eq(saved.current, 1)
	strip.action(&"rename").pressed.emit()
	assert_eq(strip.mode, LoadoutStrip.Mode.RENAMING)
	strip.edit().text = "Long Lanes"
	strip.edit().text_submitted.emit("Long Lanes")
	assert_eq(saved.slots[1].name, "Long Lanes")
	assert_eq(strip.mode, LoadoutStrip.Mode.NORMAL)
	strip.action(&"duplicate").pressed.emit()
	assert_eq(saved.slots.size(), 3)
	assert_eq(saved.current, 1, "the copy is not carried")
	saved.rules.set_bb_weight(saved.carried(), AEG, 0.3)
	strip.action(&"replace").pressed.emit()
	assert_eq(strip.mode, LoadoutStrip.Mode.REPLACING)
	strip.card(2).pressed.emit()
	assert_eq(saved.rules.tune_of(saved.slots[2], AEG).bb_weight, 0.3, "the carried loadout took its place")
	strip.action(&"remove").pressed.emit()
	assert_eq(strip.mode, LoadoutStrip.Mode.REMOVING)
	strip.action(&"keep").pressed.emit()
	assert_eq(saved.slots.size(), 3)
	strip.action(&"remove").pressed.emit()
	strip.action(&"remove_yes").pressed.emit()
	assert_eq(saved.slots.size(), 2)


func test_escape_leaves_replace_then_customise_and_the_menus_keep_theirs_for_the_quit_question() -> void:
	saved.create()
	var page := _page()
	page.strip().start_replace()
	assert_true(page.back_out())
	assert_eq(page.strip().mode, LoadoutStrip.Mode.NORMAL)
	page.show_customise(0)
	assert_true(page.customising())
	assert_true(page.back_out())
	assert_false(page.customising())
	assert_false(page.back_out(), "nothing left: Esc goes to the menus")
	page.show_customise(0)
	page._unhandled_input(_escape())
	assert_false(page.customising())


func test_a_load_message_is_shown_once() -> void:
	saved.load_message = "Your saved loadouts could not be read."
	var page := _page()
	assert_eq(page.notice_text(), "Your saved loadouts could not be read.")
	assert_eq(saved.load_message, "", "said once")
	var again := LoadoutPage.new(saved, settings)
	add_child_autofree(again)
	assert_eq(again.notice_text(), "")


# --- edits ---

func test_an_edit_goes_straight_to_the_loadout_carried_and_is_saved_on_leaving() -> void:
	var page := _page()
	page.show_customise(0)
	var view := page.customise()
	watch_signals(saved)
	view.paint_tile(&"signal").pressed.emit()
	assert_eq(saved.carried().tunes[AEG].paint, &"signal")
	assert_signal_emitted(saved, "changed")
	assert_true(saved.dirty)
	view.show_tab(CustomiseView.Tab.BBS)
	view.weight_slider().value = 0.28
	view.hop_slider().value = 0.8
	assert_almost_eq(saved.carried().tunes[AEG].bb_weight, 0.28, 1e-6)
	assert_almost_eq(saved.carried().tunes[AEG].hop_up, 0.8, 1e-6)
	assert_true(view.part_card(CustomiseView.Tab.BBS).is_picked())
	assert_eq(view.crumb_text(), "AEG RIFLE PRIMARY · LOADOUT 1", "the name is the page's title")
	view.show_tab(CustomiseView.Tab.POWER)
	assert_eq(view.power_ids(), PackedStringArray([saved.rules.pool.powers_for(saved.rules.pool.item(AEG), false)[0].id,
			LIPO]))
	view.power_card(LIPO).pressed.emit()
	assert_eq(saved.rules.tune_of(saved.carried(), AEG).power_id, LIPO)
	assert_eq(page.facts().replica(Loadout.Slot.PRIMARY).fire_rate, 13.0 * 1.15, "the carried replica plays with it")
	page.close()
	assert_false(saved.dirty)
	var back := SavedLoadouts.new(LoadoutRules.standard())
	back.load_file(LOADOUTS)
	assert_eq(back.rules.tune_of(back.carried(), AEG).power_id, LIPO)
	assert_eq(back.rules.tune_of(back.carried(), AEG).paint, &"signal")


func test_picking_a_replica_for_a_slot_swaps_one_already_carried() -> void:
	var page := _page()
	assert_eq(saved.carried().equipped, PackedStringArray([AEG, PISTOL]))
	page.gear().replica_card(PISTOL).pressed.emit()
	assert_eq(saved.carried().equipped, PackedStringArray([PISTOL, AEG]), "the pistol took the primary: they swap")
	page.gear().carried_card(Loadout.Slot.SECONDARY).pressed.emit()
	assert_eq(page.slot(), Loadout.Slot.SECONDARY)
	page.gear().replica_card(PISTOL).pressed.emit()
	assert_eq(saved.carried().equipped, PackedStringArray([AEG, PISTOL]))
	assert_false(page.gear().replica_card(CYBER).disabled, "the Cyber Pistol plays (CP1); no levels in this test")
	assert_false(_words(page.gear().replica_card(CYBER)).has("LATER"))
	page.gear().replica_card(CYBER).pressed.emit()
	assert_eq(saved.carried().equipped, PackedStringArray([AEG, CYBER]))


func test_the_laser_is_greyed_and_power_lists_what_fits() -> void:
	var page := _page()
	page.show_customise(0)
	assert_eq(page.customise().later_count(), 1, "the rifle takes the other parts and the light: the laser greyed")
	var words := _words(page.customise())
	for part: String in ["OPTIC", "GRIP", "LASER", "BARREL", "MUZZLE", "MAGAZINE", "LIGHT"]:
		assert_true(words.has(part), part)
	page.show_gear()
	page.gear().carried_card(Loadout.Slot.SECONDARY).pressed.emit()
	page.show_customise()
	page.customise().show_tab(CustomiseView.Tab.POWER)
	assert_eq(page.customise().power_ids().size(), 3, "Green, Red and Black Gas fit the pistol")
	assert_false(page.customise().power_ids().has(LIPO))


func test_dev_content_follows_the_dev_settings() -> void:
	settings.dev.dev_content = true
	_page()
	assert_true(saved.rules.dev_content)
	settings.dev.dev_content = false
	_page()
	assert_false(saved.rules.dev_content)


# --- the Performance sheet ---

func test_the_sheet_marks_better_and_worse_against_the_replica_as_it_comes() -> void:
	var page := _page()
	var plain := page.facts().sheet(Loadout.Slot.PRIMARY)
	for row in plain.rows:
		assert_eq(row.verdict, 0, "as it comes: %s" % row.field)
	saved.rules.set_power(saved.carried(), AEG, LIPO)
	saved.rules.set_bb_weight(saved.carried(), AEG, 0.3)
	saved.mark_changed()
	var sheet := page.facts().sheet(Loadout.Slot.PRIMARY)
	assert_eq(sheet.row(&"rate").verdict, 1, "the LiPo fires faster")
	assert_eq(sheet.row(&"energy").verdict, 1, "a heavier BB keeps more energy")
	assert_eq(sheet.row(&"time").verdict, -1, "and takes longer to 20 m")
	assert_eq(sheet.row(&"bb_weight").verdict, 0, "the weight itself is neither")
	assert_eq(sheet.row(&"rate").text, "15")
	assert_eq(page.gear().sheet().value_label(&"rate").get_theme_color("font_color"), GameTheme.GOOD)
	assert_eq(page.gear().sheet().value_label(&"time").get_theme_color("font_color"), GameTheme.BAD)
	assert_true(page.gear().sheet().better_line().contains("Rate of fire"))
	assert_true(page.gear().sheet().worse_line().contains("Time to 20 m"))


func test_the_sheet_reads_the_chrono_on_a_0_20_g_bb_and_the_figures_as_carried() -> void:
	var page := _page()
	var sheet := page.facts().sheet(Loadout.Slot.PRIMARY)
	assert_eq(sheet.row(&"speed").text, "318", "the AEG's 0.97 J on 0.20 g BBs, in fps")
	assert_eq(sheet.row(&"energy").text, "0.97")
	assert_eq(sheet.row(&"magazines").text, "60 × 4")
	assert_eq(sheet.row(&"reload").text, "1.8")
	assert_eq(sheet.row(&"draw").text, "0.45")
	assert_between(sheet.row(&"on_target").bar, 0.0, 1.0)
	assert_eq(page.gear().sheet().sub_text().substr(0, 25), "AEG Rifle as carried, aga")


func test_the_sheet_says_when_the_site_limit_capped_the_energy() -> void:
	saved.rules.stats.site_limits[&"rifle"] = 0.9
	var page := _page()
	assert_true(page.facts().capped(Loadout.Slot.PRIMARY))
	assert_true(page.facts().sheet(Loadout.Slot.PRIMARY).capped)
	assert_true(page.gear().sheet().capped_tag().visible, "the CAPPED tag on the energy row")
	assert_eq(page.gear().sheet().capped_line(), "Capped at the site limit: 0.90 J on the chrono with the replica's own BBs. Heavier BBs carry a little more.")
	assert_eq(page.gear().sheet().value_label(&"energy").text, "0.90", "the energy shown is the limit's")
	var calm := _page_with_default_limits()
	assert_false(calm.gear().sheet().capped_tag().visible)
	assert_eq(calm.gear().sheet().capped_line(), "")


func _page_with_default_limits() -> LoadoutPage:
	var other := SavedLoadouts.new(LoadoutRules.standard())
	var page := LoadoutPage.new(other, settings)
	page.save_path = LOADOUTS
	add_child_autofree(page)
	return page


func test_the_hop_up_flight_is_drawn_from_the_replica_as_carried() -> void:
	var page := _page()
	page.show_customise(0)
	page.customise().show_tab(CustomiseView.Tab.BBS)
	var arc := page.customise().hop_arc()
	assert_gt(arc.heights().size(), 20, "a path out to the readout's range")
	assert_true(arc.label().begins_with("on target to "))
	var before := arc.heights()[arc.heights().size() - 1]
	page.customise().hop_slider().value = 0.0
	assert_lt(arc.heights()[arc.heights().size() - 1], before, "no hop-up: it drops further")


# --- Realistic colours ---

func test_the_realistic_colours_switch_writes_the_setting_and_saves_it() -> void:
	var page := _page()
	page.show_customise(0)
	assert_false(settings.realistic_colours)
	assert_false(page.customise().realistic_toggle().button_pressed)
	page.customise().realistic_toggle().button_pressed = true
	assert_true(settings.realistic_colours)
	var back := Settings.new()
	back.load_file(SETTINGS)
	assert_true(back.realistic_colours, "saved the way the Settings screen saves")
	assert_eq(page.customise().part_sub_text(CustomiseView.Tab.COLOUR), "Black", "a Cobalt rifle shows as its plain family")
	page.customise().realistic_toggle().button_pressed = false
	assert_false(settings.realistic_colours)


# --- the pictures ---

func test_each_paint_is_built_once_and_a_replica_has_one_picture() -> void:
	var page := _page()
	page.pictures().texture(&"aeg", &"cobalt", false)
	var first := ReplicaPaint.materials(&"cobalt", false)[0]
	page.pictures().texture(&"aeg", &"cobalt", false)
	assert_same(ReplicaPaint.materials(&"cobalt", false)[0], first, "the same paint asked again builds nothing")
	assert_eq(page.pictures().count(), 4, "the rifle, the pistol, the Cyber Pistol and the Sniper Rifle")
	assert_eq(ReplicaPaint.materials(&"cobalt", true)[1].albedo_color, ReplicaSchemes.colours(&"cobalt", true)[1],
			"Realistic colours: the plain family")
	assert_eq(ReplicaPaint.materials(ReplicaSchemes.OWN, false).size(), 0, "the Cyber Pistol keeps the model's own")


func test_the_painted_model_wears_the_five_colours_and_hides_the_figure() -> void:
	var pictures := ReplicaPictures.new()
	add_child_autofree(pictures)
	pictures.texture(&"aeg", &"signal", false)
	var port := pictures.find_child("Picture_aeg", true, false) as SubViewport
	var figure := port.find_child("Figure", true, false) as Node3D
	assert_false(figure.visible)
	var seen := {}
	for node in port.find_children("*", "MeshInstance3D", true, false):
		var m := node as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var own := m.mesh.surface_get_material(i)
			var over := m.get_surface_override_material(i) as StandardMaterial3D
			if over != null and own != null:
				seen[own.resource_name] = over.albedo_color
	var colours := ReplicaSchemes.colours(&"signal", false)
	for i in ReplicaSchemes.PARTS.size():
		assert_eq(seen.get(String(ReplicaSchemes.PARTS[i])), colours[i], String(ReplicaSchemes.PARTS[i]))


func test_every_replica_picture_sits_inside_its_card_clear_of_its_lines_at_any_size() -> void:
	for window: Vector2 in [Vector2(1920.0, 1080.0), Vector2(1280.0, 720.0), Vector2(960.0, 540.0)]:
		var holder := Control.new()
		holder.size = window
		add_child_autofree(holder)
		var page := LoadoutPage.new(saved, settings)
		page.save_path = LOADOUTS
		holder.add_child(page)
		page.gear().open_switch(Loadout.Slot.PRIMARY) # the replicas' cards are in its pop-up (UF1)
		await wait_process_frames(3)
		var cards: Array[MenuCard] = [page.gear().carried_card(Loadout.Slot.PRIMARY),
				page.gear().carried_card(Loadout.Slot.SECONDARY)]
		for id: String in page.gear().replica_ids():
			cards.append(page.gear().replica_card(id))
		for card in cards:
			for pic in card.find_children("*", "TextureRect", true, false):
				if (pic as TextureRect).texture is GradientTexture2D:
					continue
				var inside := card.get_global_rect().grow(-float(GameTheme.BORDER))
				var box := (pic as TextureRect).get_global_rect()
				assert_true(inside.encloses(box), "%s at %s: the picture's box is inside the card" % [card.name, window])
				assert_gt(box.position.x - card.get_global_rect().position.x, float(GameTheme.BORDER),
						"%s: clear of the left line" % card.name)
				assert_gt(box.position.y - card.get_global_rect().position.y, float(GameTheme.BORDER),
						"%s: clear of the top line" % card.name)
		page.queue_free()
		await wait_process_frames(1)


func test_replicas_in_the_slots_and_the_list_are_drawn_to_one_scale() -> void:
	var page := _page()
	await wait_process_frames(2)
	var gear := page.gear()
	var pictures := page.pictures()
	var rifle := pictures.extent(&"aeg")
	var pistol := pictures.extent(&"pistol")
	var model_ratio := pistol.x / rifle.x
	assert_lt(model_ratio, 0.5, "a pistol is much shorter than the rifle")
	var in_primary := gear.carried_picture(Loadout.Slot.PRIMARY).custom_minimum_size
	var in_secondary := gear.carried_picture(Loadout.Slot.SECONDARY).custom_minimum_size
	assert_almost_eq(in_secondary.x / in_primary.x, model_ratio, model_ratio * 0.03, "slots: the pistol to the rifle")
	var rifle_row := gear.list_picture(AEG).custom_minimum_size
	var pistol_row := gear.list_picture(PISTOL).custom_minimum_size
	assert_almost_eq(pistol_row.x / rifle_row.x, model_ratio, model_ratio * 0.03, "list: the same ratio")
	assert_almost_eq(in_primary.x / rifle_row.x, in_primary.y / rifle_row.y, 0.01, "each scale keeps the shape")
	# swapping puts the rifle in the second card at the same size
	page.gear().replica_card(PISTOL).pressed.emit()
	await wait_process_frames(2)
	assert_almost_eq(gear.carried_picture(Loadout.Slot.SECONDARY).custom_minimum_size.x, in_primary.x, 0.5)
	assert_almost_eq(gear.carried_picture(Loadout.Slot.PRIMARY).custom_minimum_size.x, in_secondary.x, 0.5)


# --- freeing ---

func test_freeing_the_page_leaves_no_orphan_nodes_and_no_connections() -> void:
	var before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var page := LoadoutPage.new(saved, settings)
	page.save_path = LOADOUTS
	add_child(page)
	page.show_customise(0)
	page.customise().show_tab(CustomiseView.Tab.BBS)
	saved.create()
	saved.rename(1, "Other")
	page.strip().start_rename()
	assert_gt(saved.changed.get_connections().size(), 0)
	remove_child(page)
	page.free()
	assert_eq(saved.changed.get_connections().size(), 0, "the page let go of the store")
	await wait_process_frames(2)
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), before, "no orphan nodes")


# --- UR3: concept B v2's Loadout ---

func test_customise_sits_on_the_picked_card_and_switch_replica_on_both() -> void:
	var page := _page()
	var gear := page.gear()
	for slot: Loadout.Slot in LoadoutFacts.SLOTS:
		assert_true(gear.carried_card(slot).is_ancestor_of(gear.switch_button(slot)), "SWITCH REPLICA on each card (UF1)")
	assert_true(gear.carried_card(Loadout.Slot.PRIMARY).is_ancestor_of(gear.customise_button()))
	assert_true(gear.customise_button().visible)
	gear.carried_card(Loadout.Slot.SECONDARY).pressed.emit()
	assert_true(gear.carried_card(Loadout.Slot.SECONDARY).is_ancestor_of(gear.customise_button()),
			"CUSTOMISE moves with the ring")
	assert_true(gear.customise_button().visible)
	assert_true(gear.switch_button(Loadout.Slot.PRIMARY).visible, "SWITCH REPLICA stays on the card not picked")
	var shown := 0
	for b: Node in gear.find_children("Customise", "Button", true, false):
		shown += 1 if (b as Button).visible else 0
	assert_eq(shown, 1, "one CUSTOMISE on the page")


func test_the_title_line_names_the_loadout_and_what_it_carries() -> void:
	var page := _page()
	var title := page.gear().find_child("TitleRow", true, false) as Control
	assert_not_null(title)
	assert_string_contains(page.gear().foot_text(), "AEG Rifle and GBB Pistol")
	assert_lt(title.get_global_rect().end.y, page.strip().get_global_rect().position.y + 1.0, "the strip under it")


func test_the_carried_cards_draw_a_pistol_true_to_size_against_a_rifle() -> void:
	var page := _page()
	var gear := page.gear()
	var rifle := gear.carried_picture(Loadout.Slot.PRIMARY).custom_minimum_size
	var pistol := gear.carried_picture(Loadout.Slot.SECONDARY).custom_minimum_size
	var pictures := page.pictures()
	assert_almost_eq(rifle.x / pistol.x, pictures.extent(&"aeg").x / pictures.extent(&"pistol").x, 0.02)
	assert_lte(rifle.x, LoadoutGear.CARRIED_BOX.x + 0.5)
	assert_lte(rifle.y, LoadoutGear.CARRIED_BOX.y + 0.5)


func test_a_rebound_throw_key_shows_on_the_grenades_when_the_page_is_shown_again() -> void:
	var page := _page()
	var grenades := page.gear().find_child("Grenades", true, false) as Control
	assert_true(_words(grenades).has(KeyNames.of_action(&"throw_smoke")))
	var nine := InputEventKey.new()
	nine.physical_keycode = KEY_9
	InputMap.action_erase_events(&"throw_smoke")
	InputMap.action_add_event(&"throw_smoke", nine)
	var shown := KeyNames.of_action(&"throw_smoke")
	page.visible = false
	page.visible = true
	assert_true(_words(grenades).has(shown), "the new key, as on the way back from Settings")
	InputMap.load_from_project_settings()
