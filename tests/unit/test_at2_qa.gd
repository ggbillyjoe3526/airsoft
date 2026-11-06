extends GutTest
## QA hunt for AT2: edge cases of the Customise part tabs (greyed fallback, other loadouts, saved parts that no longer fit,
## the pictures' cache, text keys, sizes).

const LOADOUTS := "user://test_at2qa_loadouts.save"
const SETTINGS := "user://test_at2qa_settings.save"
const AEG := "000002"
const PISTOL := "000001"
const CYBER := "000019"
const TORCH := "000020"
const LASER_ID := "000005"
const SILENCER := "000018"
const OPTIC := CustomiseView.Tab.OPTIC
const MAGAZINE := CustomiseView.Tab.MAGAZINE
const MUZZLE := CustomiseView.Tab.MUZZLE
const LASER_TAB := CustomiseView.Tab.LASER

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


func _page(slot: int = 0) -> LoadoutPage:
	var page := LoadoutPage.new(saved, settings)
	page.save_path = LOADOUTS
	page.settings_path = SETTINGS
	add_child_autofree(page)
	page.show_customise(slot)
	return page


func _pick(page: LoadoutPage, t: CustomiseView.Tab, index: int) -> void:
	page.customise().show_tab(t)
	page.customise().part_page(t).card(index).pressed.emit()


func _tune(id: String) -> ReplicaTune:
	return saved.rules.tune_of(saved.carried(), id)


func test_a_greyed_tab_clicked_does_nothing_but_land_on_colour() -> void:
	var page := _page(1)
	page.customise().show_tab(OPTIC)
	assert_eq(page.customise().tab, CustomiseView.Tab.COLOUR)
	assert_true(page.customise().part_card(CustomiseView.Tab.COLOUR).is_picked())
	assert_false(page.customise().part_card(OPTIC).is_picked(), "the greyed tab is not shown picked")
	assert_false(page.customise().part_page(OPTIC).visible)


func test_a_saved_part_that_no_longer_fits_is_not_drawn_or_picked() -> void:
	var page := _page(0)
	_tune(AEG).parts[&"optic"] = TORCH
	_tune(AEG).parts[&"muzzle"] = "999999"
	saved.mark_changed()
	page.customise().show_tab(OPTIC)
	assert_true(page.customise().part_page(OPTIC).card(0).is_picked(), "as it comes")
	var pictures := page.pictures()
	var model := (pictures.find_child("Picture_aeg", true, false) as SubViewport).get_child(0)
	assert_null(model.get_node_or_null("optic_weaponTorch"))
	assert_eq(pictures.extent(&"aeg"), pictures.bare_extent(&"aeg"))
	var kit := saved.rules.carried(saved.carried())
	assert_false(kit.parts[0].has(&"optic"), "plays as not fitted")


func test_a_part_of_one_replica_on_another_replicas_tune_is_ignored_in_the_picture() -> void:
	var page := _page(0)
	_tune(AEG).parts[&"laser"] = LASER_ID
	saved.mark_changed()
	assert_eq(page.facts().fitted_keys(page.facts().item(Loadout.Slot.PRIMARY)).size(), 0)
	assert_eq(page.pictures().extent(&"aeg"), page.pictures().bare_extent(&"aeg"))


func test_duplicate_and_remove_keep_parts_on_the_copy_and_leave_no_orphans() -> void:
	var before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var page := _page(0)
	_pick(page, OPTIC, 1)
	_pick(page, MUZZLE, 1)
	var copy := saved.duplicate_slot(saved.current)
	assert_eq(saved.rules.tune_of(saved.slots[copy], AEG).parts[&"muzzle"], SILENCER)
	saved.rename(copy, "Parts")
	saved.use(copy)
	assert_eq(page.customise().part_page(MUZZLE).card(1).is_picked(), true)
	_pick(page, MUZZLE, 0)
	assert_true(saved.rules.tune_of(saved.slots[0], AEG).parts.has(&"muzzle"), "the original keeps its own")
	saved.remove(copy)
	assert_eq(page.customise().tab, MUZZLE)
	assert_true(page.customise().part_page(MUZZLE).card(1).is_picked())
	page.show_gear()
	await wait_process_frames(2)
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), before)


func test_many_picks_leave_the_node_and_viewport_counts_flat() -> void:
	var page := _page(0)
	for t: CustomiseView.Tab in [OPTIC, CustomiseView.Tab.GRIP, CustomiseView.Tab.BARREL, MUZZLE, MAGAZINE]:
		for i in 3:
			_pick(page, t, 0)
			_pick(page, t, i % page.customise().part_page(t).card_count())
	_pick(page, OPTIC, 0)
	await wait_process_frames(3)
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var orphans := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	for round_i in 6:
		for t: CustomiseView.Tab in [OPTIC, CustomiseView.Tab.GRIP, CustomiseView.Tab.BARREL, MUZZLE, MAGAZINE]:
			var n := page.customise().part_page(t).card_count()
			for i in n:
				_pick(page, t, i)
			_pick(page, t, 0)
	page.customise().show_tab(OPTIC)
	await wait_process_frames(3)
	assert_lte(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes, "no node grows with every pick")
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), orphans)
	assert_eq(page.pictures().part_count(), 3, "the optic tab's three optics, nothing kept from the other tabs")


func test_part_pictures_are_let_go_when_leaving_for_a_non_part_tab() -> void:
	var page := _page(0)
	page.customise().show_tab(OPTIC)
	assert_gt(page.pictures().part_count(), 0)
	page.customise().show_tab(CustomiseView.Tab.COLOUR)
	await wait_process_frames(2)
	assert_eq(page.pictures().part_count(), 0, "a viewport per part picture is held only while its tab is on")


func test_a_missing_part_model_gives_no_picture_and_no_crash() -> void:
	var page := _page(0)
	var pictures := page.pictures()
	assert_null(pictures.part_texture(&"aeg", &"optic", &"nope", &"", false))
	assert_eq(pictures.part_extent(&"aeg", &"optic", &"nope"), Vector2.ONE)
	assert_eq(pictures.part_count(), 0)
	var tex := pictures.texture(&"aeg", &"", false, {&"optic": &"nope"})
	assert_not_null(tex)
	assert_eq(pictures.extent(&"aeg"), pictures.bare_extent(&"aeg"))


func test_esc_on_a_part_tab_goes_back_to_the_gear_page_and_keys_1_to_5_do_nothing_there() -> void:
	saved.create()
	saved.use(0)
	var page := _page(0)
	page.customise().show_tab(OPTIC)
	var key := InputEventKey.new()
	key.keycode = KEY_2
	key.pressed = true
	page._unhandled_input(key)
	assert_eq(saved.current, 0, "no loadout switch while customising")
	assert_true(page.back_out())
	assert_false(page.customising())
	assert_false(page.back_out())


func test_the_optic_sheet_without_an_optic_shows_the_iron_zoom_and_with_one_the_parts_zoom() -> void:
	var page := _page(0)
	page.customise().show_tab(OPTIC)
	var sheet := page.customise().sheet()
	assert_eq(sheet.value_label(&"zoom").text, "%.2f" % page.facts().iron_zoom)
	_pick(page, OPTIC, 2)
	assert_eq(sheet.value_label(&"zoom").text, "2.00")
	# Cyber: a tab it has no optic for must not leave the rows on
	assert_true(sheet.row_shown(&"zoom"))
	page.show_gear()
	assert_false(page.gear().sheet().row_shown(&"zoom"))
	assert_false(page.gear().sheet().row_shown(&"aim"))


func test_every_part_text_key_is_translated() -> void:
	var page := _page(0)
	var view := page.customise()
	var bad := PackedStringArray()
	for t: CustomiseView.Tab in CustomiseView.PART_SLOTS:
		view.show_tab(t)
		for l in view.part_page(t).find_children("*", "Label", true, false):
			var s := (l as Label).text
			if s.begins_with("PART_") or s.begins_with("CUSTOMISE_"):
				bad.append(s)
		for i in view.part_page(t).card_count():
			var s := view.part_page(t).card_text(i)
			if s.contains("PART_") or s.contains("CUSTOMISE_"):
				bad.append(s)
		assert_false(view.part_page(t).words_text().contains("PART_"))
	view.show_tab(CustomiseView.Tab.COLOUR)
	for t: CustomiseView.Tab in CustomiseView.PART_SLOTS:
		var s := view.part_sub_text(t)
		if s.contains("PART_"):
			bad.append(s)
	assert_eq(bad, PackedStringArray(), "untranslated keys shown")
	var pistol := _page(1)
	for t: CustomiseView.Tab in CustomiseView.PART_SLOTS:
		if pistol.customise().part_available(t):
			pistol.customise().show_tab(t)
			for i in pistol.customise().part_page(t).card_count():
				assert_false(pistol.customise().part_page(t).card_text(i).contains("PART_"))
		else:
			assert_false(pistol.customise().part_mount_text(t).contains("PART_MOUNT"))


func test_the_page_lays_out_at_small_and_4k_sizes() -> void:
	var page := _page(0)
	var host := page.get_parent() as Node
	for size: Vector2 in [Vector2(1280, 720), Vector2(1920, 1080), Vector2(3840, 2160), Vector2(1024, 600)]:
		page.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		page.size = size
		for t: CustomiseView.Tab in CustomiseView.PART_SLOTS:
			if not page.customise().part_available(t):
				continue
			page.customise().show_tab(t)
			await wait_process_frames(2)
			var pp := page.customise().part_page(t)
			for i in pp.card_count():
				var c := pp.card(i)
				assert_gt(c.size.x, 60.0, "card wide enough at %s" % size)
				assert_true(Rect2(Vector2.ZERO, pp.size).grow(2.0).encloses(Rect2(c.position, c.size)),
						"card %d of %s inside its page at %s" % [i, t, size])
	assert_not_null(host)


func test_the_cyber_pistol_can_be_carried_but_no_part_fits_it_but_the_torch() -> void:
	settings.dev.dev_content = true
	saved.rules.dev_content = true
	assert_true(saved.rules.equip(saved.carried(), Loadout.Slot.SECONDARY, CYBER), "playable since CP1")
	for t: StringName in Pool.PART_TABLES.values():
		# The weapon torch fits every replica (WL7; RM8 modelled the Cyber Pistol's).
		assert_eq(saved.rules.parts_for(CYBER, t).size(), 1 if t == Pool.LIGHT_SLOT else 0, str(t))


func test_switching_loadouts_with_a_part_tab_open_keeps_the_tab_and_shows_that_loadouts_parts() -> void:
	var other := saved.create()
	saved.use(0)
	var page := _page(0)
	_pick(page, OPTIC, 2)
	saved.use(other)
	assert_eq(page.customise().tab, OPTIC)
	assert_true(page.customise().part_page(OPTIC).card(0).is_picked(), "the other loadout has no optic")
	saved.use(0)
	assert_true(page.customise().part_page(OPTIC).card(2).is_picked(), "back on the loadout with the scope")
