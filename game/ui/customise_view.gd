class_name CustomiseView
extends Control
## The Customise page body (concepts `colour.png`, `bbs.png`, `optic.png` and `magazine.png`; UI concept B v2
## `customise.png`): the way back and the replica's name as the page's title with its slot beside it, the parts down the
## left (COLOUR, BBs, POWER, then OPTIC, GRIP, BARREL, MUZZLE, MAGAZINE, LASER and LIGHT,
## each greyed with the mount it needs on a replica that can't take one; LIGHT greyed LATER while no light is on offer,
## WL7), the replica on its turntable (ReplicaTurntable: one fixed frame whatever is fitted, turned by drag or a view
## button) with the tab's controls under it and the Performance sheet on the right. COLOUR: the eight bold schemes, the four plain colours and
## the Realistic colours switch. BBs: the weight slider with Glowing BBs under it (At Night, Always, Off: WL8), and the
## hop-up's slider with its flight. POWER: the power sources that
## fit. A part tab (PartPage): the slot as it comes and each part that fits, with its figures. The picture shows the parts
## fitted. Each control only sends a signal (`paint_picked`, `bb_weight_set`, `glow_picked`, `hop_up_set`, `power_picked`,
## `part_picked`, `realistic_toggled`); the page owner makes the edit and calls `refresh`.

signal back_requested
signal paint_picked(paint: StringName)
signal bb_weight_set(grams: float)
## A Glowing BBs choice was picked (Loadout.Glow).
signal glow_picked(choice: Loadout.Glow)
signal hop_up_set(dial: float)
signal power_picked(id: String)
## A part card was picked: the part slot (Pool.PART_TABLES) and the part's ID, "" for the slot as it comes.
signal part_picked(part_slot: StringName, part_id: String)
signal realistic_toggled(on: bool)
## A part's tab was shown: the page refreshes what that tab draws.
signal tab_shown(tab: Tab)

enum Tab { COLOUR, BBS, POWER, OPTIC, GRIP, BARREL, MUZZLE, MAGAZINE, LASER, LIGHT }

const TAB_KEYS: Dictionary[Tab, String] = {
	Tab.COLOUR: "CUSTOMISE_COLOUR",
	Tab.BBS: "CUSTOMISE_BBS",
	Tab.POWER: "CUSTOMISE_POWER",
	Tab.OPTIC: "PART_OPTIC",
	Tab.GRIP: "PART_GRIP",
	Tab.BARREL: "PART_BARREL",
	Tab.MUZZLE: "PART_MUZZLE",
	Tab.MAGAZINE: "PART_MAGAZINE",
	Tab.LASER: "PART_LASER",
	Tab.LIGHT: "PART_LIGHT",
}
## The part tabs and the part slot each edits (Pool.PART_TABLES).
const PART_SLOTS: Dictionary[Tab, StringName] = {
	Tab.OPTIC: &"optic",
	Tab.GRIP: &"grip",
	Tab.BARREL: &"barrel",
	Tab.MUZZLE: &"muzzle",
	Tab.MAGAZINE: &"magazine",
	Tab.LASER: &"laser",
	Tab.LIGHT: &"light",
}
## The Performance sheet's tab-only rows each part tab adds (LoadoutPerformance.TAB_ROWS).
const TAB_SHEET_ROWS: Dictionary[Tab, Array] = {
	Tab.OPTIC: [&"zoom", &"aim"],
	Tab.GRIP: [&"aim"],
	Tab.BARREL: [&"aim"],
	Tab.MUZZLE: [&"aim"],
}
## The part tabs shown greyed LATER in the concept's place while no part of their slot is on offer (PartOptions.offered),
## by their name's key.
const LATER_TABS: Dictionary[String, Tab] = {"PART_LIGHT": Tab.LIGHT}
const COLUMN_GAP := 32
const PARTS_WIDTH := 300.0
const SIDE_WIDTH := 500.0
const PART_GAP := 8
const PART_PAD := Vector2(16.0, 12.0)
const PART_NAME_SIZE := 18
const PART_SUB_SIZE := 14
const PART_LATER_HEIGHT := 44.0
const PART_LATER_SIZE := 16
const PART_MOUNT_SIZE := 13
const PART_SUB_GAP := 3
const PART_OFF_PAD := 9.0
const MOUNT_JOIN := " / "
## From this many parts fitted a part tab's sheet line lists them instead of saying what parts do.
const SHEET_LIST_PARTS := 2
const BACK_SIZE := 16
const BACK_PAD := Vector2i(16, 8)
const CRUMB_GAP := 20
## The turntable's panel: one height on every tab (the frame never moves), its padding, the views row's gap and the
## hints' size.
const STAGE_HEIGHT := 400.0
const STAGE_PAD := Vector2i(16, 14)
const STAGE_ROW_GAP := 10
const HINT_SIZE := 14
const HINT_GAP := 18
const HINT_KEY_GAP := 6
const HINT_KEY_PAD := Vector2i(6, 1)
const OPTS_TOP := 18
const SUB_HEAD_SIZE := 16
const SUB_HEAD_SPACING := 0.1
const SUB_NOTE_SIZE := 14
const SUB_GAP := 10
const TILE_GAP := 10
const TILE_PAD := 8.0
const SWATCH_HEIGHT := 46.0
const TILE_NAME_SIZE := 13
const TILE_NAME_GAP := 7
## A paint's name too long for its tile ("Ranger green") is set smaller to fit, keeping this much room each side, down
## to TILE_NAME_MIN (BP6: it ran to the tile's edges).
const TILE_NAME_ROOM := 3.0
const TILE_NAME_MIN := 10
const BOLD_COLUMNS := 8
const PLAIN_COLUMNS := 4
const TOGGLE_TOP := 22
const SPLIT_GAP := 36
const SLIDER_TOP := 6
const BIG_SIZE := 40
const BIG_NOTE_SIZE := 18
const TICK_SIZE := 14
const BLURB_SIZE := 15
const BLURB_GAP := 8
const ARC_GAP := 16
const POWER_GAP := 12
const POWER_HEIGHT := 76.0
const POWER_PAD := Vector2(20.0, 14.0)
const POWER_NAME_SIZE := 20
const POWER_SUB_SIZE := 15
const POWER_STAT_SIZE := 15
const POWER_STAT_GAP := 18
## The weight slider's and the dial's ticks (the concept's three marks under each).
const HOP_TICKS: Array[String] = ["CUSTOMISE_HOP_OFF", "CUSTOMISE_HOP_HALF", "CUSTOMISE_HOP_FULL"]
## Each Glowing BBs choice's words and the line under them, in Loadout.Glow's order.
const GLOW_KEYS: Array[String] = ["CUSTOMISE_GLOW_NIGHT", "CUSTOMISE_GLOW_ALWAYS", "CUSTOMISE_GLOW_OFF"]
const GLOW_BLURBS: Array[String] = ["CUSTOMISE_GLOW_NIGHT_BLURB", "CUSTOMISE_GLOW_ALWAYS_BLURB",
		"CUSTOMISE_GLOW_OFF_BLURB"]

var tab: Tab = Tab.COLOUR

var _pictures: ReplicaPictures = null
var _facts: LoadoutFacts = null
var _back: Button = null
var _crumb_name: Label = null
var _crumb_sub: Label = null
var _parts_column: VBoxContainer = null
var _parts: Dictionary[Tab, MenuCard] = {}
var _later: Dictionary[Tab, MenuCard] = {}
var _part_sub: Dictionary[Tab, Label] = {}
var _part_name: Dictionary[Tab, Label] = {}
var _part_mount: Dictionary[Tab, Label] = {}
var _part_pad: Dictionary[Tab, MarginContainer] = {}
var _part_pages: Dictionary[Tab, PartPage] = {}
var _options: PartOptions = null
var _turntable: ReplicaTurntable = null
var _views: MenuChoice = null
var _pages: Dictionary[Tab, Control] = {}
var _tiles: Dictionary[StringName, MenuCard] = {}
var _own_note: Label = null
var _tile_boxes: Array[Control] = []
var _realistic: MenuToggle = null
var _weight: LoadoutSlider = null
var _weight_big: Label = null
var _weight_note: Label = null
var _glow_bbs: MenuChoice = null
## The glow choice's words for its pick: its buttons' tooltip, so a pick rewrites no line on the page (UI1 round 3).
var _glow_blurb: String = ""
var _hop: LoadoutSlider = null
var _hop_big: Label = null
var _hop_note: Label = null
var _arc: HopArc = null
var _power_box: VBoxContainer = null
var _power_note: Label = null
var _power_cards: Dictionary[String, MenuCard] = {}
var _sheet: PerformanceSheet = null
var _slot: Loadout.Slot = Loadout.Slot.PRIMARY


func _init(pictures: ReplicaPictures, facts: LoadoutFacts) -> void:
	name = "CustomiseView"
	_pictures = pictures
	_facts = facts
	_options = PartOptions.new(facts)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# the body's box fills the whole view, the crumb's corner included: it must not catch the clicks meant for the
	# LOADOUT button under it (FB1: the button did nothing)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", int(MenuParts.PAGE_MARGIN.x))
	margin.add_theme_constant_override("margin_right", int(MenuParts.PAGE_MARGIN.z))
	margin.add_theme_constant_override("margin_bottom", int(MenuParts.PAGE_MARGIN.w))
	add_child(margin)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", COLUMN_GAP)
	margin.add_child(columns)
	columns.add_child(_build_parts())
	columns.add_child(_build_stage())
	_sheet = PerformanceSheet.new()
	_sheet.custom_minimum_size = Vector2(SIDE_WIDTH, 0.0)
	_sheet.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	columns.add_child(_sheet)
	# the crumb last, so it is drawn and hit above the body; the body starts under it
	var crumb := _build_crumb()
	var place_body := func() -> void:
		margin.add_theme_constant_override("margin_top", roundi(MenuParts.PAGE_MARGIN.y
				+ crumb.get_combined_minimum_size().y + MenuParts.PAGE_TITLE_AFTER))
	crumb.minimum_size_changed.connect(place_body)
	place_body.call()
	show_tab(Tab.COLOUR)


func back_button() -> Button:
	return _back


func part_card(t: Tab) -> MenuCard:
	return _parts[t]


## The line under a part's name ("Cobalt", "0.25 g · hop-up 65 %", "11.1 V LiPo Battery").
func part_sub_text(t: Tab) -> String:
	return _part_sub[t].text


## The page of part tab `t`.
func part_page(t: Tab) -> PartPage:
	return _part_pages[t]


## True if the replica shown can take parts in tab `t` (a slot it can't is greyed with its mount).
func part_available(t: Tab) -> bool:
	return not _parts[t].disabled


## The mount a greyed part tab says it needs ("PISTOL RAIL"); "" on one that is on.
func part_mount_text(t: Tab) -> String:
	return _part_mount[t].text if _part_mount[t].visible else ""


func paint_tile(paint: StringName) -> MenuCard:
	return _tiles[paint]


func realistic_toggle() -> MenuToggle:
	return _realistic


func weight_slider() -> LoadoutSlider:
	return _weight


func glow_choice() -> MenuChoice:
	return _glow_bbs


func glow_blurb() -> String:
	return _glow_blurb


func hop_slider() -> LoadoutSlider:
	return _hop


func hop_arc() -> HopArc:
	return _arc


func power_card(id: String) -> MenuCard:
	return _power_cards.get(id)


func power_ids() -> PackedStringArray:
	return PackedStringArray(_power_cards.keys())


func sheet() -> PerformanceSheet:
	return _sheet


## The replica on its turntable, and the row of views over it.
func turntable() -> ReplicaTurntable:
	return _turntable


func view_choice() -> MenuChoice:
	return _views


## Lets go of the turntable's model (the page is closed).
func let_go() -> void:
	_turntable.let_go()


## The title's replica name and its "PRIMARY · CQB RUSH".
func crumb_text() -> String:
	return _crumb_name.text + " " + _crumb_sub.text


## The parts listed greyed: with the mount they need, or LATER.
func later_count() -> int:
	var n := 0
	for child in _parts_column.get_children():
		if child is MenuCard and (child as MenuCard).disabled and (child as MenuCard).visible:
			n += 1
	return n


## True while part tab `t` shows greyed LATER in place of its card (none of its parts on offer).
func part_later(t: Tab) -> bool:
	return _later.has(t) and _later[t].visible


## Shows tab `t`: its controls and its part lit.
func show_tab(t: Tab) -> void:
	tab = t
	for id: Tab in _pages:
		_pages[id].visible = id == t
		_parts[id].set_picked(id == t)
	# A part picture's viewport is held only while its tab is on.
	if not PART_SLOTS.has(t) and _pictures != null:
		_pictures.let_go_parts()
	tab_shown.emit(t)


## Shows the setup of the replica carried in `slot`.
func refresh(slot: Loadout.Slot, realistic: bool) -> void:
	_slot = slot
	var f := _facts
	if not f.has(slot):
		return
	var item := f.item(slot)
	var t := f.tune(slot)
	var r := f.replica(slot)
	var base := f.as_it_comes(slot)
	_crumb_name.text = item.display_name.to_upper()
	_crumb_sub.text = "%s · %s" % [tr(LoadoutFacts.SLOT_KEYS[slot]), f.saved.carried().name.to_upper()]
	_part_sub[Tab.COLOUR].text = f.paint_name(slot, realistic)
	_part_sub[Tab.BBS].text = f.bbs_line(slot)
	var power := f.power_name(slot)
	_part_sub[Tab.POWER].text = power if power != "" else tr("CUSTOMISE_POWER_BUILT_IN")
	_turntable.show_replica(item.key, t.paint, realistic, _facts.fitted_keys(item))
	# colour
	var own := t.paint == ReplicaSchemes.OWN
	for box in _tile_boxes:
		box.visible = not own
	_own_note.visible = own
	for paint: StringName in _tiles:
		_tiles[paint].set_picked(paint == t.paint)
	_realistic.put(realistic)
	# BBs
	_weight.put(t.bb_weight)
	_weight_big.text = tr("LOADOUT_GRAMS") % t.bb_weight
	_weight_note.text = tr("CUSTOMISE_AS_IT_COMES") % (tr("LOADOUT_GRAMS") % base.bb_weight)
	var glow := f.saved.carried().glow_of(item.id)
	_glow_bbs.put(glow)
	_glow_blurb = tr(GLOW_BLURBS[glow])
	for i in GLOW_KEYS.size():
		_glow_bbs.button(i).tooltip_text = _glow_blurb
	_hop.put(t.hop_up)
	_hop_big.text = tr("CUSTOMISE_PERCENT") % roundi(t.hop_up * 100.0)
	_hop_note.text = tr("CUSTOMISE_AS_IT_COMES") % (tr("CUSTOMISE_PERCENT") % roundi(base.hop_up_dial * 100.0))
	# power
	_refresh_power(item, t)
	# the parts: which slots the replica takes, and the tab on show
	for pt: Tab in PART_SLOTS:
		_refresh_part_tab(pt, slot)
	if PART_SLOTS.has(tab) and not part_available(tab):
		show_tab(Tab.COLOUR)
	if PART_SLOTS.has(tab):
		_part_pages[tab].show_options(_options.options(slot, PART_SLOTS[tab]), item, t.paint, realistic, _pictures)
	# the sheet, and the flight under the hop-up when that tab shows
	var sheet_now := f.sheet(slot)
	_sheet.show_sheet(sheet_now, _sheet_sub(slot, item), PackedStringArray(TAB_SHEET_ROWS.get(tab, [])),
			not PART_SLOTS.has(tab))
	if tab == Tab.BBS:
		var on_target := sheet_now.row(&"on_target")
		_arc.show_shot(r, r.hop_up_dial, t.bb_weight, f.tuning, f.hud.hop_range, _on_target_metres(r, t), tr(
				"CUSTOMISE_ON_TARGET") % on_target.text)


## The line under PERFORMANCE: the colour tab's own, a part tab's (the parts carried, or what parts do), else the usual.
func _sheet_sub(slot: Loadout.Slot, item: Pool.Item) -> String:
	if tab == Tab.COLOUR:
		return tr("CUSTOMISE_COLOUR_SUB")
	if PART_SLOTS.has(tab):
		var names := _options.fitted_names(slot)
		if names.size() < SHEET_LIST_PARTS:
			return tr("PART_SHEET_SUB") % item.display_name
		return tr("PART_SHEET_SUB_FITTED") % [item.display_name, _join_words(names)]
	return tr("LOADOUT_SHEET_SUB") % item.display_name


## "A, B and C".
func _join_words(names: PackedStringArray) -> String:
	if names.size() < 2:
		return "".join(names)
	return "%s %s %s" % [", ".join(names.slice(0, names.size() - 1)), tr("PART_AND"), names[names.size() - 1]]


## Part tab `t`: on with what is fitted under its name, or greyed with the mount its parts need.
func _refresh_part_tab(t: Tab, slot: Loadout.Slot) -> void:
	var part_slot := PART_SLOTS[t]
	var on := _options.takes(slot, part_slot)
	var card := _parts[t]
	if _later.has(t):
		var offered := _options.offered(part_slot)
		_later[t].visible = not offered
		card.visible = offered
	card.set_greyed(not on)
	card.focus_mode = Control.FOCUS_ALL if on else Control.FOCUS_NONE
	_part_sub[t].visible = on
	_part_mount[t].visible = not on
	var pad := _part_pad[t]
	var vertical := PART_PAD.y if on else PART_OFF_PAD
	pad.add_theme_constant_override("margin_top", int(vertical))
	pad.add_theme_constant_override("margin_bottom", int(vertical))
	card.custom_minimum_size.y = PART_NAME_SIZE + PART_SUB_SIZE + PART_PAD.y * 2.0 + 14.0 if on else PART_LATER_HEIGHT
	var size := PART_NAME_SIZE if on else PART_LATER_SIZE
	_part_name[t].add_theme_font_override("font", GameTheme.spaced_font(800, GameTheme.SPACING_TAB, size))
	_part_name[t].add_theme_font_size_override("font_size", size)
	_part_name[t].add_theme_color_override("font_color", GameTheme.TEXT if on else GameTheme.MUTED)
	if on:
		_part_sub[t].text = _options.tab_line(slot, part_slot)
		var empty := _facts.fitted_part(_facts.item(slot), part_slot) == null and PartOptions.EMPTY_SLOTS.has(part_slot)
		_part_sub[t].add_theme_color_override("font_color", GameTheme.DIM if empty else GameTheme.MUTED)
	else:
		var words := PackedStringArray()
		for tag in _options.mounts_of(part_slot):
			words.append(_mount_words(tag))
		_part_mount[t].text = MOUNT_JOIN.join(words)


## A mount tag ("pistol-rail") as the tab says it ("PISTOL RAIL").
func _mount_words(tag: String) -> String:
	var key := "PART_MOUNT_" + tag.to_upper().replace("-", "_")
	var words := tr(key)
	return words if words != key else tag.replace("-", " ").to_upper()


func _on_target_metres(r: ReplicaConfig, t: ReplicaTune) -> float:
	return Ballistics.hop_up_reach(r, r.hop_up_dial, _facts.tuning, 1.0 / float(Engine.physics_ticks_per_second),
			_facts.hud.hop_band, _facts.hud.hop_range, t.bb_weight).on_target_to



## The title row: the way back, then the replica's name as the page's title with its slot beside it.
func _build_crumb() -> Control:
	var row := HBoxContainer.new()
	row.name = "Crumb"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", CRUMB_GAP)
	row.position = Vector2(MenuParts.PAGE_MARGIN.x, MenuParts.PAGE_MARGIN.y)
	_back = Button.new()
	_back.name = "Back"
	_back.text = tr("CUSTOMISE_BACK")
	_back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_back.add_theme_font_override("font", GameTheme.spaced_font(700, GameTheme.SPACING_TAB, BACK_SIZE))
	_back.add_theme_font_size_override("font_size", BACK_SIZE)
	# every state its own box with the same margins: the pressed box was the theme's, 2 px wider each side, and a press
	# cut the last letter (UI1: "LOADOU")
	GameTheme.dress(_back, GameTheme.box(GameTheme.CARD, GameTheme.LINE, BACK_PAD.x, BACK_PAD.y),
			GameTheme.box(GameTheme.CARD_HI, GameTheme.LINE, BACK_PAD.x, BACK_PAD.y),
			GameTheme.box(GameTheme.CARD_HI, GameTheme.ACCENT, BACK_PAD.x, BACK_PAD.y))
	_back.pressed.connect(func() -> void: back_requested.emit())
	row.add_child(_back)
	_crumb_sub = MenuParts.page_line("")
	var title := MenuParts.page_title("", _crumb_sub)
	_crumb_name = title.get_node("Title") as Label
	row.add_child(title)
	add_child(row)
	return row


func _build_parts() -> Control:
	_parts_column = VBoxContainer.new()
	_parts_column.name = "Parts"
	_parts_column.custom_minimum_size = Vector2(PARTS_WIDTH, 0.0)
	_parts_column.add_theme_constant_override("separation", PART_GAP)
	for t: Tab in TAB_KEYS:
		var card := MenuCard.new()
		card.name = "Part_%s" % Tab.keys()[t].capitalize()
		card.bar = GameTheme.ACCENT
		card.bar_idle = 0.0
		card.refresh()
		var pad := MenuParts.padded(PART_PAD.x, PART_PAD.y, PART_PAD.x, PART_PAD.y)
		var row := HBoxContainer.new()
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		column.add_theme_constant_override("separation", PART_SUB_GAP)
		var title := MenuParts.spaced(tr(TAB_KEYS[t]), PART_NAME_SIZE, 800, GameTheme.TEXT, GameTheme.SPACING_TAB)
		column.add_child(title)
		var sub := MenuParts.text("", PART_SUB_SIZE, 600, GameTheme.MUTED)
		column.add_child(sub)
		row.add_child(column)
		if PART_SLOTS.has(t):
			var mount := MenuParts.text("", PART_MOUNT_SIZE, 700, GameTheme.DIM)
			mount.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			mount.visible = false
			row.add_child(mount)
			_part_mount[t] = mount
			_part_name[t] = title
			_part_pad[t] = pad
		pad.add_child(row)
		card.add_content(pad)
		card.custom_minimum_size = Vector2(0.0, PART_NAME_SIZE + PART_SUB_SIZE + PART_PAD.y * 2.0 + 14.0)
		card.pressed.connect(show_tab.bind(t))
		_parts_column.add_child(card)
		_parts[t] = card
		_part_sub[t] = sub
	for key: String in LATER_TABS:
		var card := MenuCard.new()
		card.name = "Later_%s" % key.trim_prefix("PART_").capitalize()
		card.custom_minimum_size = Vector2(0.0, PART_LATER_HEIGHT)
		var pad := MenuParts.padded(PART_PAD.x, 0, PART_PAD.x, 0)
		var row := HBoxContainer.new()
		var label := MenuParts.spaced(tr(key), PART_LATER_SIZE, 800, GameTheme.MUTED, GameTheme.SPACING_TAB)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(label)
		row.add_child(MenuTag.later())
		pad.add_child(row)
		card.add_content(pad)
		card.set_greyed(true)
		card.focus_mode = Control.FOCUS_NONE
		_parts_column.add_child(card)
		_later[LATER_TABS[key]] = card
	return _parts_column


func _build_stage() -> Control:
	var stage := VBoxContainer.new()
	stage.name = "Stage"
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.add_theme_constant_override("separation", 0)
	stage.add_child(_build_turntable())
	var opts := MarginContainer.new()
	opts.add_theme_constant_override("margin_top", OPTS_TOP)
	opts.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.add_child(opts)
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	opts.add_child(holder)
	_pages[Tab.COLOUR] = _build_colour()
	_pages[Tab.BBS] = _build_bbs()
	_pages[Tab.POWER] = _build_power()
	for t: Tab in PART_SLOTS:
		var page := PartPage.new(PART_SLOTS[t])
		page.part_picked.connect(func(part_slot: StringName, id: String) -> void: part_picked.emit(part_slot, id))
		_part_pages[t] = page
		_pages[t] = page
	for t: Tab in _pages:
		_pages[t].set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		holder.add_child(_pages[t])
	return stage


## The turntable on its glass panel, one height on every tab: the views over it on the left, the hints on the right.
func _build_turntable() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", STAGE_ROW_GAP)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var words := PackedStringArray()
	for key: String in ReplicaTurntable.VIEW_KEYS:
		words.append(tr(key))
	_views = MenuChoice.new(words, true)
	_views.name = "Views"
	row.add_child(_views)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	row.add_child(_hints())
	column.add_child(row)
	_turntable = ReplicaTurntable.new()
	column.add_child(_turntable)
	_views.picked.connect(_turntable.set_view)
	_turntable.view_changed.connect(_views.put)
	_views.put(_turntable.view())
	var panel := MenuParts.glass(column, STAGE_PAD)
	panel.name = "Stage"
	panel.custom_minimum_size = Vector2(0.0, STAGE_HEIGHT)
	return panel


## "Drag to rotate · Scroll to zoom  [R] Reset view".
func _hints() -> Control:
	var row := HBoxContainer.new()
	row.name = "Hints"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", HINT_GAP)
	for key: String in ["CUSTOMISE_HINT_DRAG", "CUSTOMISE_HINT_ZOOM"]:
		var hint := MenuParts.text(tr(key), HINT_SIZE, 500, GameTheme.MUTED)
		hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(hint)
	var reset := HBoxContainer.new()
	reset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reset.add_theme_constant_override("separation", HINT_KEY_GAP)
	var chip := MenuParts.key_chip("R", HINT_SIZE - 2, GameTheme.MUTED, HINT_KEY_PAD)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reset.add_child(chip)
	var words := MenuParts.text(tr("CUSTOMISE_HINT_RESET"), HINT_SIZE, 500, GameTheme.MUTED)
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reset.add_child(words)
	row.add_child(reset)
	return row


func _sub_head(words: String, note: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", SUB_GAP)
	row.add_child(MenuParts.spaced(words, SUB_HEAD_SIZE, 800, GameTheme.MUTED, SUB_HEAD_SPACING))
	# what the group is: its tooltip (UI1: the tiles say it)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.tooltip_text = note
	return row


func _build_colour() -> Control:
	var page := VBoxContainer.new()
	page.name = "ColourPage"
	page.add_theme_constant_override("separation", SUB_GAP)
	_own_note = MenuParts.text(tr("CUSTOMISE_OWN_NOTE"), SUB_HEAD_SIZE, 700, GameTheme.MUTED)
	_own_note.visible = false
	page.add_child(_own_note)
	var bold_head := _sub_head(tr("CUSTOMISE_BOLD"), tr("CUSTOMISE_BOLD_NOTE"))
	page.add_child(bold_head)
	var bold := _tile_grid(ReplicaSchemes.SCHEMES.keys(), BOLD_COLUMNS)
	page.add_child(bold)
	var plain_head := _sub_head(tr("CUSTOMISE_REALISTIC"), tr("CUSTOMISE_REALISTIC_NOTE"))
	page.add_child(plain_head)
	var plain := _tile_grid(ReplicaSchemes.FAMILIES.keys(), PLAIN_COLUMNS)
	# the four plain colours take the left half
	var plain_row := HBoxContainer.new()
	plain_row.add_theme_constant_override("separation", TILE_GAP)
	plain.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plain_row.add_child(plain)
	var other_half := Control.new()
	other_half.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	other_half.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plain_row.add_child(other_half)
	page.add_child(plain_row)
	_tile_boxes = [bold_head, bold, plain_head, plain_row]
	_realistic = MenuToggle.new(tr("CUSTOMISE_REALISTIC_EVERYWHERE"), tr("CUSTOMISE_REALISTIC_EVERYWHERE_NOTE"))
	_realistic.name = "RealisticColours"
	_realistic.toggled.connect(func(on: bool) -> void: realistic_toggled.emit(on))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, TOGGLE_TOP - SUB_GAP)
	page.add_child(gap)
	page.add_child(_realistic)
	return page


## A grid of paint tiles: each its two main colours over its name.
func _tile_grid(paints: Array, columns: int) -> Control:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", TILE_GAP)
	grid.add_theme_constant_override("v_separation", TILE_GAP)
	for paint: StringName in paints:
		grid.add_child(_tile(paint))
	return grid


func _tile(paint: StringName) -> MenuCard:
	var card := MenuCard.new()
	card.name = "Paint_%s" % paint
	card.accessibility_name = ReplicaSchemes.paint_name(paint, false)
	card.ring = true
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0.0, SWATCH_HEIGHT + TILE_NAME_SIZE * 1.4 + TILE_PAD * 2.0 + TILE_NAME_GAP +
			GameTheme.BORDER * 2)
	var pad := MenuParts.padded(TILE_PAD, TILE_PAD, TILE_PAD, TILE_PAD)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", TILE_NAME_GAP)
	var colours := ReplicaSchemes.colours(paint, false)
	var swatch := HBoxContainer.new()
	swatch.add_theme_constant_override("separation", 0)
	swatch.custom_minimum_size = Vector2(0.0, SWATCH_HEIGHT)
	for i in 2:
		var c := ColorRect.new()
		c.color = colours[i]
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		swatch.add_child(c)
	column.add_child(swatch)
	var label := MenuParts.text(ReplicaSchemes.paint_name(paint, false), TILE_NAME_SIZE, 700, GameTheme.TEXT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# its width is the tile's, not the name's: `fit_name` sizes the name to it
	label.clip_text = true
	label.resized.connect(fit_name.bind(label))
	column.add_child(label)
	pad.add_child(column)
	card.add_content(pad)
	card.pressed.connect(func() -> void: paint_picked.emit(paint))
	_tiles[paint] = card
	return card


## A tile's name at TILE_NAME_SIZE, or smaller where that would run past the label (never cut).
static func fit_name(label: Label) -> void:
	var room := label.size.x - TILE_NAME_ROOM * 2.0
	if room <= 0.0:
		return
	var font := label.get_theme_font("font")
	var fitted := TILE_NAME_SIZE
	while fitted > TILE_NAME_MIN and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x > room:
		fitted -= 1
	if label.get_theme_font_size("font_size") != fitted:
		label.add_theme_font_size_override("font_size", fitted)


func _build_bbs() -> Control:
	var page := HBoxContainer.new()
	page.name = "BbsPage"
	page.add_theme_constant_override("separation", SPLIT_GAP)
	var weight_column := VBoxContainer.new()
	weight_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weight_column.add_theme_constant_override("separation", 0)
	weight_column.add_child(_sub_head(tr("CUSTOMISE_BB_WEIGHT"), ""))
	var rules := _facts.rules().rules
	_weight = LoadoutSlider.new(rules.bb_weight_min, rules.bb_weight_max, rules.bb_weight_step)
	_weight.name = "BbWeight"
	var weight_ticks: Array[String] = [tr("LOADOUT_GRAMS_PLAIN") % rules.bb_weight_min,
			tr("LOADOUT_GRAMS_PLAIN") % ((rules.bb_weight_min + rules.bb_weight_max) * 0.5),
			tr("LOADOUT_GRAMS_PLAIN") % rules.bb_weight_max]
	_slider_block(weight_column, _weight, weight_ticks, "CUSTOMISE_WEIGHT_BLURB")
	_weight_big = weight_column.get_node("Big/Value") as Label
	_weight_note = weight_column.get_node("Big/Note") as Label
	_weight.value_changed.connect(func(v: float) -> void: bb_weight_set.emit(v))
	var glow_gap := Control.new()
	glow_gap.custom_minimum_size = Vector2(0.0, TOGGLE_TOP)
	weight_column.add_child(glow_gap)
	weight_column.add_child(_sub_head(tr("CUSTOMISE_GLOW_BBS"), ""))
	var words := PackedStringArray()
	for key in GLOW_KEYS:
		words.append(tr(key))
	_glow_bbs = MenuChoice.new(words)
	_glow_bbs.name = "GlowBbs"
	_glow_bbs.picked.connect(func(i: int) -> void: glow_picked.emit(i as Loadout.Glow))
	var choice_wrap := MenuParts.padded(0, SUB_GAP, 0, 0)
	choice_wrap.add_child(_glow_bbs)
	weight_column.add_child(choice_wrap)
	page.add_child(weight_column)
	var hop_column := VBoxContainer.new()
	hop_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hop_column.add_theme_constant_override("separation", 0)
	hop_column.add_child(_sub_head(tr("CUSTOMISE_HOP_UP"), ""))
	_hop = LoadoutSlider.new(rules.hop_up_min_dial, rules.hop_up_max_dial, rules.hop_up_dial_step)
	_hop.name = "HopUp"
	var hop_ticks: Array[String] = []
	for key in HOP_TICKS:
		hop_ticks.append(tr(key))
	_slider_block(hop_column, _hop, hop_ticks, "CUSTOMISE_HOP_BLURB", "CUSTOMISE_HOP_KEYS")
	_hop_big = hop_column.get_node("Big/Value") as Label
	_hop_note = hop_column.get_node("Big/Note") as Label
	_hop.value_changed.connect(func(v: float) -> void: hop_up_set.emit(v))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, ARC_GAP)
	hop_column.add_child(gap)
	_arc = HopArc.new()
	hop_column.add_child(_arc)
	page.add_child(hop_column)
	return page


## The big readout with its note, the slider and its three ticks, added to `column`; `blurb_key`'s words are the
## readout's and the slider's tooltip (UI1 round 3: no paragraph under a slider), and `line_key`'s, if any, the one short
## line kept under it.
func _slider_block(column: VBoxContainer, slider: LoadoutSlider, ticks: Array[String], blurb_key: String,
		line_key: String = "") -> void:
	var big := HBoxContainer.new()
	big.name = "Big"
	big.add_theme_constant_override("separation", SUB_GAP)
	var value := MenuParts.text("", BIG_SIZE, 800, GameTheme.TEXT)
	value.name = "Value"
	big.add_child(value)
	var note := MenuParts.text("", BIG_NOTE_SIZE, 700, GameTheme.MUTED)
	note.name = "Note"
	note.size_flags_vertical = Control.SIZE_SHRINK_END
	big.add_child(note)
	column.add_child(big)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, SLIDER_TOP + SUB_GAP)
	column.add_child(gap)
	column.add_child(slider)
	var row := HBoxContainer.new()
	for i in ticks.size():
		var l := MenuParts.text(ticks[i], TICK_SIZE, 700, GameTheme.DIM)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.horizontal_alignment = [HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_CENTER, HORIZONTAL_ALIGNMENT_RIGHT][i]
		row.add_child(l)
	column.add_child(row)
	var tip := tr(blurb_key)
	slider.tooltip_text = tip
	big.tooltip_text = tip
	big.mouse_filter = Control.MOUSE_FILTER_PASS
	if line_key != "":
		var line := MenuParts.text(tr(line_key), BLURB_SIZE, 600, GameTheme.MUTED)
		var wrap := MenuParts.padded(0, BLURB_GAP, 0, 0)
		wrap.add_child(line)
		column.add_child(wrap)


func _build_power() -> Control:
	_power_box = VBoxContainer.new()
	_power_box.name = "PowerPage"
	_power_box.add_theme_constant_override("separation", POWER_GAP)
	_power_box.add_child(_sub_head(tr("CUSTOMISE_POWER_HEAD"), tr("CUSTOMISE_POWER_NOTE")))
	_power_note = MenuParts.text("", SUB_HEAD_SIZE, 700, GameTheme.MUTED)
	_power_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_power_note.visible = false
	_power_box.add_child(_power_note)
	return _power_box


## The power sources that fit `item`, as cards: built the first time and when the replica changes.
func _refresh_power(item: Pool.Item, t: ReplicaTune) -> void:
	var rules := _facts.rules()
	var fitting := rules.pool.powers_for(item, rules.dev_content)
	# the cards are rebuilt only when the batteries that fit change (a slider's refresh builds no list: BP6)
	var same := fitting.size() == _power_cards.size()
	for pw in fitting:
		if not same:
			break
		same = _power_cards.has(pw.id)
	if not same:
		for id: String in _power_cards:
			_power_box.remove_child(_power_cards[id])
			_power_cards[id].queue_free()
		_power_cards.clear()
		for pw in fitting:
			var card := _power_card(pw)
			_power_box.add_child(card)
			_power_cards[pw.id] = card
	for id: String in _power_cards:
		_power_cards[id].set_picked(id == t.power_id)
	_power_note.visible = fitting.is_empty()
	_power_note.text = tr("CUSTOMISE_POWER_NONE")


func _power_card(pw: Pool.Item) -> MenuCard:
	var stats := _facts.rules().stats.power(pw.id)
	var card := MenuCard.new()
	card.name = "Power_%s" % pw.id
	card.custom_minimum_size = Vector2(0.0, POWER_HEIGHT)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pad := MenuParts.padded(POWER_PAD.x, POWER_PAD.y, POWER_PAD.x, POWER_PAD.y)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", POWER_STAT_GAP)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 3)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", SUB_GAP)
	title.add_child(MenuParts.text(LoadoutFacts.power_label(pw), POWER_NAME_SIZE, 800, GameTheme.TEXT))
	var rules := _facts.rules()
	if rules.is_locked(pw.id):
		title.add_child(MenuTag.level(rules.unlock_level(pw.id)))
	if pw.is_dev():
		title.add_child(MenuTag.dev())
	text.add_child(title)
	text.add_child(MenuParts.text(tr("CUSTOMISE_POWER_TYPE_" + String(pw.type).to_upper()), POWER_SUB_SIZE, 600,
			GameTheme.MUTED))
	row.add_child(text)
	for stat: Array in [["CUSTOMISE_POWER_ENERGY", stats.energy], ["CUSTOMISE_POWER_RATE", stats.fire_rate],
			["CUSTOMISE_POWER_RECOIL", stats.recoil]]:
		row.add_child(_power_stat(stat[0], stat[1]))
	pad.add_child(row)
	card.add_content(pad)
	card.pressed.connect(func() -> void: power_picked.emit(pw.id))
	card.set_greyed(rules.is_locked(pw.id))
	return card


func _power_stat(key: String, share: float) -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := MenuParts.text(tr(key), SUB_NOTE_SIZE, 600, GameTheme.DIM)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(name_label)
	var percent := roundi(share * 100.0)
	var value := MenuParts.text(tr("CUSTOMISE_POWER_PERCENT") % percent if percent != 0 else tr("CUSTOMISE_POWER_ZERO"),
			POWER_STAT_SIZE, 800, GameTheme.TEXT)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(value)
	return column
