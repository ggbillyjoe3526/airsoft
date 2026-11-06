extends GutTest
## The Customise part tabs (AT2; concepts step10-attachments `optic.png` and `magazine.png`): each tab turns on for the
## replicas whose mount takes parts and is greyed with the mount it needs on the rest, a card picks a part into the saved
## loadout and the carried kit, the slot as it comes takes it off, a part that doesn't fit is not offered, the Performance
## sheet's Zoom aimed, Aim in and Moving rows, the pictures with the parts on, and nothing left behind when the page is freed.

const LOADOUTS := "user://test_at2_loadouts.save"
const SETTINGS := "user://test_at2_settings.save"
const AEG := "000002"
const PISTOL := "000001"
const CYBER := "000019"
const RED_DOT := "000007"
const SCOPE := "000010"
const VERTICAL := "000006"
const LASER := "000005"
const HI_CAP := "000012"
const LOW_CAP := "000013"
const EXTENDED := "000014"
const LONG_BARREL := "000017"
const SILENCER := "000018"
const OPTIC := CustomiseView.Tab.OPTIC
const GRIP := CustomiseView.Tab.GRIP
const BARREL := CustomiseView.Tab.BARREL
const MUZZLE := CustomiseView.Tab.MUZZLE
const MAGAZINE := CustomiseView.Tab.MAGAZINE
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


## Picks card `index` of part tab `t`.
func _pick(page: LoadoutPage, t: CustomiseView.Tab, index: int) -> void:
	page.customise().show_tab(t)
	page.customise().part_page(t).card(index).pressed.emit()


func _tune(id: String) -> ReplicaTune:
	return saved.rules.tune_of(saved.carried(), id)


# --- which tabs are on ---

func test_the_rifle_takes_an_optic_grip_barrel_muzzle_and_magazine_but_no_laser() -> void:
	var view := _page(0).customise()
	for t: CustomiseView.Tab in [OPTIC, GRIP, BARREL, MUZZLE, MAGAZINE]:
		assert_true(view.part_available(t), CustomiseView.Tab.keys()[t])
		assert_eq(view.part_mount_text(t), "")
		assert_false(view.part_card(t).disabled)
	assert_false(view.part_available(LASER_TAB))
	assert_true(view.part_card(LASER_TAB).disabled)
	assert_eq(view.part_mount_text(LASER_TAB), "PISTOL RAIL", "greyed with the mount it needs")
	assert_eq(view.later_count(), 1, "the laser: the light is on offer")


func test_the_pistol_takes_a_laser_muzzle_part_and_magazine_and_greys_the_rest_with_their_mounts() -> void:
	var view := _page(1).customise()
	for t: CustomiseView.Tab in [LASER_TAB, MUZZLE, MAGAZINE]:
		assert_true(view.part_available(t), CustomiseView.Tab.keys()[t])
	assert_eq(view.part_mount_text(OPTIC), "TOP RAIL")
	assert_eq(view.part_mount_text(GRIP), "UNDER RAIL")
	assert_eq(view.part_mount_text(BARREL), "BARREL MOUNT")
	assert_eq(view.later_count(), 3, "the optic, grip and barrel")


func test_what_fits_comes_from_the_pool_and_the_cyber_pistol_takes_only_the_light() -> void:
	var rules := saved.rules
	for slot: StringName in Pool.PART_TABLES.values():
		if slot != &"light":
			assert_true(rules.parts_for(CYBER, slot).is_empty(), "the Cyber Pistol takes no %s" % slot)
	assert_eq(rules.parts_for(CYBER, &"light").size(), 1, "the Weapon Torch fits it (RM8)")
	assert_eq(rules.parts_for(PISTOL, &"magazine").size(), 1, "the pistol's magazine is the extended one")
	assert_true(rules.parts_for(AEG, &"laser").is_empty())


func test_the_light_is_on_offer_since_the_torch_went_public() -> void:
	var view := _page(0).customise()
	assert_true(_words(view).has("LIGHT"))
	assert_false(view.part_later(CustomiseView.Tab.LIGHT), "the Weapon Torch is public since 2026-10-29")
	assert_true(view.part_available(CustomiseView.Tab.LIGHT))


func test_a_tab_the_next_replica_cant_take_falls_back_to_colour() -> void:
	var page := _page(0)
	page.customise().show_tab(OPTIC)
	page.show_gear()
	page.gear().carried_card(Loadout.Slot.SECONDARY).pressed.emit()
	page.show_customise()
	assert_eq(page.customise().tab, CustomiseView.Tab.COLOUR, "the pistol has no optic")
	assert_true(page.customise().part_card(CustomiseView.Tab.COLOUR).is_picked())


# --- the cards ---

func test_each_tab_offers_the_slot_as_it_comes_then_each_part_that_fits() -> void:
	var view := _page(0).customise()
	view.show_tab(OPTIC)
	var page := view.part_page(OPTIC)
	assert_eq(page.card_count(), 4, "iron sights, the red dot, the scope and the Variable Scope (public 2026-11-05)")
	assert_true(page.card_text(0).begins_with("Zoom 1.2×"))
	assert_true(page.card_text(0).contains("Nothing on the rail."))
	assert_true(page.card_text(1).begins_with("Zoom 1.25× · aim in 0.15 s"))
	assert_true(page.card_text(2).begins_with("Zoom 2× · aim in 0.24 s"))
	assert_true(page.card_text(3).begins_with("Zoom 6× · aim in 0.28 s"), "the Variable Scope names its top zoom")
	assert_true(page.card(0).is_picked(), "nothing fitted: as it comes is picked")
	assert_null(page.card_picture(0).texture, "the slot as it comes has words, not a picture")
	assert_not_null(page.card_picture(1).texture)
	view.show_tab(MAGAZINE)
	var mags := view.part_page(MAGAZINE)
	assert_eq(mags.card_count(), 3)
	assert_true(mags.card_text(0).begins_with("60 × 4 · reload 1.8 s"))
	assert_true(mags.card_text(1).begins_with("120 × 2 · reload 1.8 s"))
	assert_true(mags.card_text(1).contains("Rattles: bots close by hear you walk."))
	assert_true(mags.card_text(2).begins_with("30 × 6 · reload 1.35 s"))
	assert_false(mags.card_text(2).contains("Rattles"))


func test_a_part_that_doesnt_fit_isnt_offered() -> void:
	var view := _page(1).customise()
	view.show_tab(MAGAZINE)
	var mags := view.part_page(MAGAZINE)
	assert_eq(mags.card_count(), 2, "the pistol's own magazine and the standard one")
	assert_eq(mags.card(1).name, "Option_%s" % EXTENDED)
	assert_false(mags.card_text(1).contains("Rattles"))
	# the rifle's red dot sent for the pistol is refused
	view.part_picked.emit(&"optic", RED_DOT)
	assert_false(_tune(PISTOL).parts.has(&"optic"))
	view.part_picked.emit(&"magazine", HI_CAP)
	assert_false(_tune(PISTOL).parts.has(&"magazine"))


func test_the_numbers_are_better_and_worse_in_colour_with_the_words_under_them() -> void:
	var page := _page(0)
	_pick(page, OPTIC, 2)
	var optic := page.customise().part_page(OPTIC)
	assert_true(optic.card_text(2).contains("Zoom 2×"))
	assert_true(optic.card(2).is_picked())
	assert_eq(optic.words_text(), "Better: more zoom. Worse: slower aim in.")
	var markup := page.customise().part_page(OPTIC).find_children("*", "RichTextLabel", true, false)
	var scope_text := markup[2] as RichTextLabel
	assert_true(scope_text.text.contains("[color=#%s]2[/color]" % GameTheme.GOOD.to_html(false)), "zoom in the good colour")
	assert_true(scope_text.text.contains("[color=#%s]0.24[/color]" % GameTheme.BAD.to_html(false)), "aim in in the bad one")
	_pick(page, MAGAZINE, 1)
	assert_eq(page.customise().part_page(MAGAZINE).words_text(),
			"Better: more BBs a magazine. Worse: fewer magazines, rattles while you move.")
	_pick(page, MAGAZINE, 0)
	assert_eq(page.customise().part_page(MAGAZINE).words_text(), "", "nothing to say about the slot as it comes")


func test_a_part_adds_the_figures_it_changes_to_its_card() -> void:
	var view := _page(0).customise()
	view.show_tab(BARREL)
	var barrels := view.part_page(BARREL)
	assert_true(barrels.card_text(0).begins_with("0.97 J · spread 0.45 °"), "the energy keeps its decimals")
	assert_false(barrels.card_text(0).contains("aim in"))
	assert_true(barrels.card_text(1).begins_with("1.00 J · spread 0.38 °"), "a tight bore handles as it comes")
	assert_false(barrels.card_text(1).contains("aim in"))
	assert_true(barrels.card_text(2).contains("aim in 0.17 s"), "a long barrel is front-heavy")
	view.show_tab(MUZZLE)
	var muzzles := view.part_page(MUZZLE)
	assert_true(muzzles.card_text(1).begins_with("0.92 J · heard from 50 % · aim in 0.17 s"))
	view.show_tab(GRIP)
	assert_true(view.part_page(GRIP).card_text(1).begins_with("Aim in 0.19 s · shake 60 %"))
	assert_true(view.part_page(GRIP).card_text(2).begins_with("Aim in 0.12 s · shake 130 %"))


func test_the_tab_list_says_what_is_fitted() -> void:
	var page := _page(0)
	var view := page.customise()
	view.show_tab(OPTIC)
	assert_eq(view.part_sub_text(OPTIC), "Iron sights")
	assert_eq(view.part_sub_text(GRIP), "None")
	assert_eq(view.part_sub_text(BARREL), "Standard")
	assert_eq(view.part_sub_text(MUZZLE), "Flash hider")
	assert_eq(view.part_sub_text(MAGAZINE), "Standard")
	_pick(page, OPTIC, 1)
	_pick(page, MAGAZINE, 1)
	assert_eq(view.part_sub_text(OPTIC), "Red Dot")
	assert_eq(view.part_sub_text(MAGAZINE), "Hi-Cap", "the magazine's own word is left off")
	assert_eq(_page(1).customise().part_sub_text(MUZZLE), "Standard", "the pistol has no flash hider")


# --- picking ---

func test_a_picked_part_reaches_the_saved_loadout_and_the_carried_kit() -> void:
	var page := _page(0)
	watch_signals(saved)
	_pick(page, OPTIC, 1)
	assert_signal_emitted(saved, "changed")
	assert_true(saved.dirty)
	assert_eq(_tune(AEG).parts[&"optic"], RED_DOT)
	var kit := saved.rules.carried(saved.carried())
	assert_eq(kit.parts[0][&"optic"], &"redDot")
	assert_almost_eq(kit.replicas[0].aim_zoom, 1.25, 1e-6)
	assert_true(page.customise().part_page(OPTIC).card(1).is_picked())
	_pick(page, MAGAZINE, 1)
	_pick(page, GRIP, 1)
	_pick(page, BARREL, 2)
	_pick(page, MUZZLE, 1)
	assert_eq(_tune(AEG).parts.size(), 5)
	kit = saved.rules.carried(saved.carried())
	assert_eq(kit.replicas[0].mag_size, 120)
	assert_true(kit.replicas[0].rattles)
	assert_true(kit.replicas[0].muffled)
	assert_eq(kit.parts[0], {&"optic": &"redDot", &"magazine": &"hiCap", &"grip": &"vertical", &"barrel": &"long",
			&"muzzle": &"silencer"})
	page.close()
	var back := SavedLoadouts.new(LoadoutRules.standard())
	back.load_file(LOADOUTS)
	assert_eq(back.rules.tune_of(back.carried(), AEG).parts[&"muzzle"], SILENCER, "saved with the loadout")


func test_taking_a_part_off_returns_the_slot_to_as_it_comes() -> void:
	var page := _page(0)
	_pick(page, OPTIC, 2)
	_pick(page, OPTIC, 0)
	assert_false(_tune(AEG).parts.has(&"optic"))
	assert_eq(saved.rules.carried(saved.carried()).replicas[0].aim_zoom, 0.0, "the iron sights again")
	assert_true(page.customise().part_page(OPTIC).card(0).is_picked())
	assert_eq(page.customise().part_sub_text(OPTIC), "Iron sights")


func test_picking_the_part_already_fitted_changes_nothing() -> void:
	var page := _page(0)
	_pick(page, OPTIC, 1)
	saved.dirty = false
	_pick(page, OPTIC, 1)
	assert_false(saved.dirty)


func test_picking_a_card_keeps_the_keyboard_on_it() -> void:
	var page := _page(0)
	page.customise().show_tab(OPTIC)
	var card := page.customise().part_page(OPTIC).card(1)
	card.grab_focus()
	card.pressed.emit()
	await wait_process_frames(2)
	assert_true(page.customise().part_page(OPTIC).card(1).has_focus(), "the card stays, so the keys keep working")


func test_the_pistol_picks_its_laser_and_each_replica_keeps_its_own_parts() -> void:
	var page := _page(1)
	_pick(page, LASER_TAB, 1)
	assert_eq(_tune(PISTOL).parts[&"laser"], LASER)
	assert_false(_tune(AEG).parts.has(&"laser"))
	assert_almost_eq(saved.rules.carried(saved.carried()).replicas[1].spread_deg, 0.8 * 0.8, 1e-6)


# --- the Performance sheet ---

func test_zoom_aimed_and_aim_in_show_on_the_optic_tab() -> void:
	var page := _page(0)
	var sheet := page.customise().sheet()
	assert_false(sheet.row_shown(&"zoom"), "colour tab")
	assert_false(sheet.row_shown(&"aim"))
	_pick(page, OPTIC, 1)
	assert_true(sheet.row_shown(&"zoom"))
	assert_true(sheet.row_shown(&"aim"))
	assert_eq(sheet.value_label(&"zoom").text, "1.25")
	assert_eq(sheet.value_label(&"zoom").get_theme_color("font_color"), GameTheme.GOOD)
	assert_eq(sheet.value_label(&"aim").text, "0.15")
	assert_eq(sheet.value_label(&"aim").get_theme_color("font_color"), GameTheme.TEXT)
	_pick(page, OPTIC, 2)
	assert_eq(sheet.value_label(&"zoom").text, "2.00")
	assert_eq(sheet.value_label(&"aim").text, "0.24")
	assert_eq(sheet.value_label(&"aim").get_theme_color("font_color"), GameTheme.BAD)
	_pick(page, OPTIC, 0)
	assert_eq(sheet.value_label(&"zoom").text, "1.20", "iron sights: the view's own zoom")
	page.customise().show_tab(CustomiseView.Tab.BBS)
	assert_false(sheet.row_shown(&"zoom"), "only the tabs it belongs to")
	page.customise().show_tab(GRIP)
	assert_true(sheet.row_shown(&"aim"), "the grip changes how fast the sight comes up")
	assert_false(sheet.row_shown(&"zoom"))


func test_moving_shows_rattles_in_red_only_with_a_rattling_magazine() -> void:
	var page := _page(0)
	var sheet := page.customise().sheet()
	page.customise().show_tab(MAGAZINE)
	assert_false(sheet.row_shown(&"moving"))
	_pick(page, MAGAZINE, 1)
	assert_true(sheet.row_shown(&"moving"))
	assert_eq(sheet.value_label(&"moving").text, "Rattles")
	assert_eq(sheet.value_label(&"moving").get_theme_color("font_color"), GameTheme.BAD)
	assert_eq(sheet.value_label(&"magazines").text, "120 × 2")
	_pick(page, MAGAZINE, 2)
	assert_false(sheet.row_shown(&"moving"), "the low-cap is quiet")
	assert_eq(sheet.value_label(&"reload").get_theme_color("font_color"), GameTheme.GOOD)
	page.show_gear()
	assert_false(page.gear().sheet().row_shown(&"zoom"), "the gear page keeps its usual rows")


func test_the_sheet_counts_the_barrels_and_the_silencers_energy() -> void:
	var page := _page(0)
	var sheet := page.customise().sheet()
	var comes := float(sheet.value_label(&"energy").text)
	_pick(page, BARREL, 2)
	assert_gt(float(sheet.value_label(&"energy").text), comes, "a long barrel adds to it")
	assert_eq(sheet.value_label(&"energy").get_theme_color("font_color"), GameTheme.GOOD)
	_pick(page, BARREL, 0)
	_pick(page, MUZZLE, 1)
	assert_lt(float(sheet.value_label(&"energy").text), comes, "a silencer takes a little")
	assert_eq(sheet.value_label(&"energy").get_theme_color("font_color"), GameTheme.BAD)


func test_the_sheets_line_names_the_parts_carried() -> void:
	var page := _page(0)
	page.customise().show_tab(MAGAZINE)
	assert_true(page.customise().sheet().sub_text().contains("only barrels and silencers touch its energy"))
	_pick(page, OPTIC, 1)
	assert_true(page.customise().sheet().sub_text().contains("only barrels and silencers"), "one part: still what parts do")
	_pick(page, GRIP, 1)
	_pick(page, BARREL, 2)
	_pick(page, MUZZLE, 1)
	assert_eq(page.customise().sheet().sub_text(),
			"AEG Rifle as carried with Red Dot, Vertical Grip, Long Barrel and Silencer, against it as it comes.")
	assert_eq(page.customise().sheet().better_line(), "", "a part tab says it under its cards")


# --- the pictures ---

## The gear page's picture (Customise shows the turntable).
func test_the_replica_picture_shows_the_parts_and_returns_when_they_come_off() -> void:
	var page := _page(0)
	var pictures := page.pictures()
	var bare := pictures.bare_extent(&"aeg")
	assert_eq(pictures.extent(&"aeg"), bare)
	var port := pictures.find_child("Picture_aeg", true, false) as SubViewport
	var model := port.get_child(0) as Node3D
	var plain := model.get_child_count()
	_pick(page, MUZZLE, 1)
	_pick(page, MAGAZINE, 1)
	page.show_gear()
	assert_gt(pictures.extent(&"aeg").x, bare.x, "the silencer is longer than the flash hider")
	assert_eq(model.get_child_count(), plain + 1, "the silencer on the model")
	assert_not_null(model.find_child("magazine", true, false).get_node_or_null("magazine_hiCap"),
			"the Hi-Cap on the magazine bone, as in hand (AT3)")
	assert_not_null(model.get_node_or_null("muzzle_silencer"))
	assert_null(model.get_node_or_null("muzzle_silencer/muzzle_silencer_Figure"), "the figure copy is left out")
	assert_false((model.find_child("FlashHider", true, false) as Node3D).visible)
	for mag in model.find_children("Magazine", "Node3D", true, false):
		assert_false((mag as Node3D).visible, "the standard magazine is hidden for the Hi-Cap")
	page.show_customise(0)
	_pick(page, MUZZLE, 0)
	_pick(page, MAGAZINE, 0)
	page.show_gear()
	assert_eq(model.get_child_count(), plain, "the parts that were replaced are freed")
	assert_true((model.find_child("FlashHider", true, false) as Node3D).visible)
	assert_eq(pictures.extent(&"aeg"), bare)


func test_the_cards_pictures_share_one_scale_within_a_tab_and_only_this_tab_is_kept() -> void:
	var page := _page(0)
	var pictures := page.pictures()
	page.customise().show_tab(OPTIC)
	assert_eq(pictures.part_count(), 3, "the red dot and the two scopes")
	var optic := page.customise().part_page(OPTIC)
	var dot := optic.card_picture(1).custom_minimum_size
	var scope := optic.card_picture(2).custom_minimum_size
	assert_gt(scope.x, dot.x, "a scope is longer than a red dot")
	assert_almost_eq(dot.x / pictures.part_extent(&"aeg", &"optic", &"redDot").x,
			scope.x / pictures.part_extent(&"aeg", &"optic", &"scope2x").x, 0.01, "the same pixels a metre")
	assert_lte(scope.x, PartPage.PICTURE_BOX.x + 0.5)
	assert_lte(scope.y, PartPage.PICTURE_BOX.y + 0.5)
	page.customise().show_tab(MAGAZINE)
	assert_eq(pictures.part_count(), 2, "the optic pictures were let go")


func test_the_cards_on_the_gear_page_show_the_parts_at_one_shared_scale() -> void:
	var page := _page(0)
	page.show_gear()
	var gear := page.gear()
	var rifle := gear.carried_picture(Loadout.Slot.PRIMARY).custom_minimum_size
	var pistol := gear.carried_picture(Loadout.Slot.SECONDARY).custom_minimum_size
	var ratio := rifle.x / pistol.x
	page.show_customise(0)
	_pick(page, MUZZLE, 1)
	_pick(page, BARREL, 2)
	_pick(page, OPTIC, 1)
	page.show_gear()
	var longer := gear.carried_picture(Loadout.Slot.PRIMARY).custom_minimum_size
	var same_pistol := gear.carried_picture(Loadout.Slot.SECONDARY).custom_minimum_size
	assert_lte(longer.x, GameTheme.BORDER + LoadoutGear.CARRIED_BOX.x + 0.5, "inside the card")
	assert_lte(longer.y, LoadoutGear.CARRIED_BOX.y + 0.5)
	assert_gt(longer.x / same_pistol.x, ratio, "the rifle with its parts is longer against the pistol")
	assert_almost_eq(gear.list_picture(AEG).custom_minimum_size.x / gear.list_picture(PISTOL).custom_minimum_size.x,
			longer.x / same_pistol.x, 0.05, "the list thumbnails keep the same relation")


func test_the_turntable_keeps_the_rifles_frame_when_parts_are_fitted() -> void:
	var page := _page(0)
	var table := page.customise().turntable()
	var model := table.model()
	var holder := model.get_parent() as Node3D
	var distance := table.camera_distance()
	var centre := holder.position
	var plain := model.get_child_count()
	_pick(page, MUZZLE, 1)
	_pick(page, BARREL, 2)
	_pick(page, OPTIC, 1)
	assert_same(table.model(), model, "the same model, refitted")
	assert_not_null(model.get_node_or_null("muzzle_silencer"), "the silencer on the turntable's rifle")
	assert_eq(model.get_child_count(), plain + 3)
	assert_eq(table.camera_distance(), distance, "the camera never moves for a part")
	assert_eq(holder.position, centre, "nor does the rifle")
	_pick(page, MUZZLE, 0)
	_pick(page, BARREL, 0)
	_pick(page, OPTIC, 0)
	assert_eq(model.get_child_count(), plain, "the parts come off again")
	assert_true((model.find_child("FlashHider", true, false) as Node3D).visible)


# --- freeing ---

func test_freeing_the_page_with_parts_fitted_leaves_no_orphan_nodes() -> void:
	var before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var page := LoadoutPage.new(saved, settings)
	page.save_path = LOADOUTS
	add_child(page)
	page.show_customise(0)
	_pick(page, OPTIC, 1)
	_pick(page, MAGAZINE, 1)
	_pick(page, MUZZLE, 1)
	page.customise().show_tab(GRIP)
	page.show_gear()
	page.show_customise(0)
	_pick(page, OPTIC, 0)
	remove_child(page)
	page.free()
	assert_eq(saved.changed.get_connections().size(), 0)
	await wait_process_frames(2)
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), before, "no orphan nodes")


func _words(root: Node) -> PackedStringArray:
	var out := PackedStringArray()
	for l in root.find_children("*", "Label", true, false):
		out.append((l as Label).text)
	return out
