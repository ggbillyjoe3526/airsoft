extends GutTest
## QA's hunt on the UR3 Loadout gear page (concept B v2): CUSTOMISE by mouse and keyboard, a rifle in the secondary slot,
## the swap row as the pool grows, the load notice, layout in the room beside the rail and what the page leaves behind.

const LOADOUTS := "user://test_ur3_loadouts.save"
const SETTINGS := "user://test_ur3_settings.save"
const AEG := "000002"
const PISTOL := "000001"
const ROOM := Vector2i(1920, 1080)

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


## The page in a viewport of `size`, offset by the rail as the menus put it.
func _page(size: Vector2i = ROOM, with: SavedLoadouts = null) -> LoadoutPage:
	var view := SubViewport.new()
	view.size = size
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child_autofree(view)
	var page := LoadoutPage.new(with if with != null else saved, settings)
	page.save_path = LOADOUTS
	page.settings_path = SETTINGS
	view.add_child(page)
	page.offset_left = NavRail.WIDTH
	return page


## A pool with `extra` more replica rows after the shipped ones (each "id|name|key|tags|access").
func _grown_saved(extra: PackedStringArray) -> SavedLoadouts:
	var text := FileAccess.get_file_as_string(Pool.PATH)
	var anchor := "| 000019 | Cyber Pistol | cyber | pistol, built-in-power | | public |\n"
	assert_true(text.contains(anchor), "pool.md anchor")
	var rows := ""
	for e: String in extra:
		var p := e.split("|")
		rows += "| %s | %s | %s | %s | | %s |\n" % [p[0], p[1], p[2], p[3], p[4]]
	var pool := Pool.parse(text.replace(anchor, anchor + rows))
	var stats := ReplicaStats.read_file()
	return SavedLoadouts.new(LoadoutRules.new(pool, stats, SimTuning.load_default().replica_rules))


func _click(view: Viewport, at: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	view.push_input(move, true)
	for down: bool in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.position = at
		e.global_position = at
		e.pressed = down
		e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		view.push_input(e, true)


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e


# --- CUSTOMISE ---

func test_clicking_customise_with_the_mouse_opens_customise() -> void:
	var page := _page()
	await wait_process_frames(3)
	var button := page.gear().customise_button()
	assert_ne(button.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the button takes the mouse")
	_click(page.get_viewport(), button.get_global_rect().get_center())
	await wait_process_frames(2)
	assert_true(page.customising(), "a click on CUSTOMISE opens Customise")


func test_clicking_customise_on_the_secondary_card_opens_customise_for_the_secondary() -> void:
	var page := _page()
	await wait_process_frames(3)
	page.gear().carried_card(Loadout.Slot.SECONDARY).pressed.emit()
	await wait_process_frames(2)
	var button := page.gear().customise_button()
	_click(page.get_viewport(), button.get_global_rect().get_center())
	await wait_process_frames(2)
	assert_true(page.customising())
	assert_eq(page.slot(), Loadout.Slot.SECONDARY)


func test_keyboard_enter_on_customise_opens_it_and_focus_returns_after_back() -> void:
	var page := _page()
	await wait_process_frames(2)
	page.focus_default()
	var button := page.gear().customise_button()
	assert_true(button.has_focus())
	button.pressed.emit()
	assert_true(page.customising())
	page.back_out()
	assert_false(page.customising())
	assert_true(page.gear().customise_button().has_focus(), "focus back on the picked card's CUSTOMISE")
	assert_true(page.gear().customise_button().is_visible_in_tree())


func test_focus_after_customise_closes_on_the_secondary_is_on_its_button() -> void:
	var page := _page()
	await wait_process_frames(2)
	page.show_customise(Loadout.Slot.SECONDARY)
	page.show_gear()
	assert_eq(page.slot(), Loadout.Slot.SECONDARY)
	assert_true(page.gear().customise_button().has_focus())
	assert_true(page.gear().carried_card(Loadout.Slot.SECONDARY).is_ancestor_of(page.gear().customise_button()))


func test_keys_one_to_five_pick_saved_loadouts_and_escape_in_rename_cancels() -> void:
	var page := _page()
	await wait_process_frames(2)
	saved.create()
	saved.use(0)
	await wait_process_frames(1)
	page._unhandled_input(_key(KEY_2))
	assert_eq(saved.current, 1, "2 picks the second loadout")
	page.strip().start_rename()
	assert_eq(page.strip().mode, LoadoutStrip.Mode.RENAMING)
	page._unhandled_input(_key(KEY_1))
	assert_eq(saved.current, 1, "keys do nothing while typing a name")
	assert_true(page.back_out(), "Esc leaves rename")
	assert_false(page.back_out(), "and then there is nothing to leave")


# --- a rifle in the secondary slot ---

func test_a_rifle_in_the_secondary_slot_fits_inside_its_card() -> void:
	var page := _page()
	await wait_process_frames(2)
	assert_true(saved.rules.equip(saved.carried(), Loadout.Slot.SECONDARY, AEG))
	saved.mark_changed()
	await wait_process_frames(4)
	var gear := page.gear()
	var card := gear.carried_card(Loadout.Slot.SECONDARY)
	var pic := gear.carried_picture(Loadout.Slot.SECONDARY)
	assert_true(card.get_global_rect().encloses(pic.get_global_rect()), "pic %s in card %s" % [pic.get_global_rect(),
			card.get_global_rect()])
	assert_gte(pic.get_global_rect().position.x, card.get_global_rect().position.x + LoadoutGear.CARD_PAD.x,
			"clear of the card's padding left")
	assert_lte(pic.get_global_rect().end.x, card.get_global_rect().end.x - LoadoutGear.CARD_PAD.x,
			"clear of the card's padding right")


func test_swapping_the_rifle_to_the_secondary_swaps_the_two_slots_and_their_pictures() -> void:
	var page := _page()
	await wait_process_frames(2)
	var gear := page.gear()
	gear.carried_card(Loadout.Slot.SECONDARY).pressed.emit()
	gear.replica_card(AEG).pressed.emit()
	await wait_process_frames(3)
	assert_eq(saved.carried().equipped[Loadout.Slot.SECONDARY], AEG)
	assert_eq(saved.carried().equipped[Loadout.Slot.PRIMARY], PISTOL, "the pistol took the primary")
	assert_eq(page.slot(), Loadout.Slot.SECONDARY, "the ring stays on the picked slot")
	var rifle := gear.carried_picture(Loadout.Slot.SECONDARY).custom_minimum_size.x
	var pistol := gear.carried_picture(Loadout.Slot.PRIMARY).custom_minimum_size.x
	assert_almost_eq(pistol, rifle * page.pictures().extent(&"pistol").x / page.pictures().extent(&"aeg").x, 0.5)


# --- the swap row ---

func test_the_swap_row_fits_the_page_with_the_shipped_replicas() -> void:
	var page := _page()
	await wait_process_frames(3)
	await _assert_room(page, "shipped")


func test_the_switch_pop_up_fits_with_five_replicas_and_the_sheet_stays_on_screen() -> void:
	var grown := _grown_saved(PackedStringArray(["000101|Alpha Pistol|pistol|pistol, gas|public",
			"000102|Beta Rifle|aeg|rifle, electric, aeg-mag|public"]))
	var page := _page(ROOM, grown)
	await wait_process_frames(3)
	assert_eq(page.gear().replica_ids().size(), 5)
	await _assert_room(page, "five replicas")


func test_the_switch_pop_up_fits_with_four_replicas() -> void:
	var grown := _grown_saved(PackedStringArray(["000101|Alpha Pistol|pistol|pistol, gas|public"]))
	var page := _page(ROOM, grown)
	await wait_process_frames(3)
	assert_eq(page.gear().replica_ids().size(), 4)
	await _assert_room(page, "four replicas")


func test_dev_replicas_listed_with_dev_content_still_fit_the_page() -> void:
	var grown := _grown_saved(PackedStringArray(["000101|Alpha Pistol|pistol|pistol, gas|dev"]))
	grown.rules.dev_content = true
	settings.dev.dev_content = true
	var page := _page(ROOM, grown)
	await wait_process_frames(3)
	# the three public replicas, the Sniper Rifle (dev for now) and the added one
	assert_eq(page.gear().replica_ids().size(), 5)
	await _assert_room(page, "dev replica")


func test_a_dev_replica_is_hidden_with_dev_content_off() -> void:
	var grown := _grown_saved(PackedStringArray(["000101|Alpha Pistol|pistol|pistol, gas|dev"]))
	var page := _page(ROOM, grown)
	await wait_process_frames(2)
	assert_eq(page.gear().replica_ids().size(), 3)


func _assert_room(page: LoadoutPage, what: String) -> void:
	var room := Rect2(Vector2(NavRail.WIDTH, 0.0), Vector2(ROOM))
	var gear := page.gear()
	# the replicas' cards are in SWITCH REPLICA's pop-up (UF1): open, they all fit the screen
	gear.open_switch(Loadout.Slot.PRIMARY)
	await wait_process_frames(2)
	var min_size := gear.get_combined_minimum_size()
	assert_lte(min_size.x, float(ROOM.x - NavRail.WIDTH), "%s: min width %s" % [what, min_size])
	assert_lte(min_size.y, float(ROOM.y), "%s: min height %s" % [what, min_size])
	for node: Node in gear.find_children("*", "PanelContainer", true, false):
		if not (node as Control).is_visible_in_tree():
			continue
		var r := (node as Control).get_global_rect()
		assert_true(room.grow(1.0).encloses(r), "%s: %s %s outside %s" % [what, node.name, r, room])
	for id: String in gear.replica_ids():
		var card := gear.replica_card(id)
		assert_true(room.grow(1.0).encloses(card.get_global_rect()), "%s: %s card %s" % [what, id, card.get_global_rect()])
		var pic := gear.list_picture(id)
		assert_true(card.get_global_rect().encloses(pic.get_global_rect()), "%s: %s picture inside its card" % [what, id])
	var sheet := gear.sheet().get_global_rect()
	assert_true(room.grow(1.0).encloses(sheet), "%s: the sheet %s in the room" % [what, sheet])


# --- notice, range note, layout ---

func test_the_load_notice_does_not_cover_the_title_line_or_leave_the_page() -> void:
	saved.load_message = TranslationServer.translate("LOADOUTS_NEWER")
	var page := _page()
	await wait_process_frames(3)
	assert_ne(page.notice_text(), "")
	var notice := page.find_children("*", "Label", false, false).filter(
			func(n: Node) -> bool: return (n as Label).text == page.notice_text())
	assert_eq(notice.size(), 1)
	var r := (notice[0] as Label).get_global_rect()
	assert_gte(r.position.x, float(NavRail.WIDTH), "the notice stays right of the rail: %s" % r)
	var line := page.gear().find_child("TitleRow", true, false) as Control
	assert_false(r.intersects(line.get_global_rect()), "notice %s clear of the title row %s" % [r, line.get_global_rect()])
	assert_lte(r.end.y, page.strip().get_global_rect().position.y + 1.0, "notice above the strip")


func test_the_range_note_fits_under_the_sheet_in_the_room() -> void:
	var page := _page()
	page.open_from_practice(Loadout.Slot.SECONDARY)
	await wait_process_frames(3)
	assert_true(page.gear().range_note_visible())
	assert_eq(page.slot(), Loadout.Slot.SECONDARY)
	var note := page.gear().find_child("RangeNote", true, false) as Control
	var room := Rect2(Vector2(NavRail.WIDTH, 0.0), Vector2(ROOM))
	assert_true(room.encloses(note.get_global_rect()), "note %s" % note.get_global_rect())
	assert_gte(note.get_global_rect().position.y, page.gear().sheet().get_global_rect().end.y - 1.0, "under the sheet")


func test_the_page_fits_a_four_by_three_window() -> void:
	var page := _page(Vector2i(1920, 1440))
	await wait_process_frames(3)
	var room := Rect2(Vector2(NavRail.WIDTH, 0.0), Vector2(1920, 1440))
	var gear := page.gear()
	for slot: Loadout.Slot in LoadoutFacts.SLOTS:
		var c := gear.carried_card(slot).get_global_rect()
		assert_true(room.encloses(c), "card %s" % c)
		assert_true(c.encloses(gear.carried_picture(slot).get_global_rect()), "picture inside card %d" % slot)
	assert_true(room.encloses(gear.sheet().get_global_rect()))
	assert_null(gear.find_child("Swap", true, false), "no SWAP row (UF1: SWITCH REPLICA's pop-up instead)")
	for slot: Loadout.Slot in LoadoutFacts.SLOTS:
		var b := gear.switch_button(slot).get_global_rect()
		assert_true(gear.carried_card(slot).get_global_rect().encloses(b), "SWITCH REPLICA %s inside its card" % b)


# --- what the page leaves behind ---

func test_opening_and_closing_customise_repeatedly_leaves_no_nodes_behind() -> void:
	var page := _page()
	await wait_process_frames(3)
	for i in 3:
		page.show_customise(1)
		await wait_process_frames(2)
		page.show_gear()
		await wait_process_frames(2)
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var orphans := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	for i in 6:
		page.show_customise(1)
		await wait_process_frames(2)
		page.show_gear()
		await wait_process_frames(2)
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes, "no nodes gained")
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), orphans, "no orphans")
	assert_eq(page.gear().carried_card(Loadout.Slot.PRIMARY).pressed.get_connections().size(), 1,
			"the card's one connection, not more")


func test_swapping_replicas_many_times_adds_no_connections_or_nodes() -> void:
	var page := _page()
	await wait_process_frames(3)
	var gear := page.gear()
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var conns := saved.changed.get_connections().size()
	for i in 8:
		gear.carried_card(i % 2 as Loadout.Slot).pressed.emit()
		gear.replica_card(AEG if i % 2 == 0 else PISTOL).pressed.emit()
	await wait_process_frames(3)
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes)
	assert_eq(saved.changed.get_connections().size(), conns)
