class_name LoadoutGear
extends Control
## The Loadout tab's gear page body (UI concept B v2, `loadout.png`, owner 2026-11-02): LOADOUT and its line (the loadout
## carried and what is in it), then the glass panels: the PRIMARY card (its replica large, its name and what it carries,
## SWITCH REPLICA at its top right, CUSTOMISE on the picked card), the SECONDARY card the same beside the GRENADES carried
## every round (SF1), and the Performance sheet at the right. SWITCH REPLICA picks that card's slot and opens the
## pop-up of every replica to carry in it (LoadoutSwitch; owner, 2026-11-03: it replaced the SWAP row); the one carried
## in the other slot swaps the two.
## Every replica on the page is drawn at one scale (owner, 2026-10-19 and 2026-11-02: replicas to scale), the cards'
## sized so the longest fits a card's picture box: a rifle in either slot is the same size, a pistol beside it true to
## size. The page owner reads `slot_picked`, `replica_picked` and `customise_requested` and calls `refresh`.
## LoadoutPage puts the saved loadouts' strip in the row under the title.

signal slot_picked(slot: Loadout.Slot)
signal replica_picked(id: String)
signal customise_requested

## Where the panels start (the page's margins, title and panels are MenuParts'): under the title row and LoadoutPage's
## strip (its STRIP_TOP plus the strip's height and a gap). The Performance column's width.
const TOP := 186.0
const SIDE_WIDTH := 500.0
## A carried card: its padding, the room for its slot's label row above the picture and its name block below.
const CARD_PAD := Vector2(24.0, 18.0)
const CARD_HEAD := 40.0
const CARD_FOOT := 64.0
## The picture box both carried cards hold: the longest replica fits it, in either slot (a rifle carried as the secondary
## is as large as one carried as the primary), and every carried replica is drawn at that scale.
const CARRIED_BOX := Vector2(640.0, 170.0)
## The secondary card is as wide as the box needs; the grenades panel takes the rest of the row.
const SECONDARY_WIDTH := CARRIED_BOX.x + 2.0 * CARD_PAD.x
const SLOT_SIZE := 15
const SLOT_SPACING := 0.1
const KEY_SIZE := 13
const KEY_PAD := Vector2i(7, 1)
const SLOT_KEY_GAP := 12
const NAME_SIZE := 34
const NAME_SPACING := 0.02
const SUB_SIZE := 16
## CUSTOMISE's words: smaller than PLAY's, a button on a card.
const CUSTOMISE_SIZE := 20
const NAME_SUB_GAP := 2
## The grenades panel: a tile a bomb (its height and padding), its icon, the count and name, and its throw key.
const GRENADE_KEYS: Array[String] = ["", "LOADOUT_SMOKE", "LOADOUT_FLASH"]
const GRENADE_ACTIONS: Array[StringName] = [&"", &"throw_smoke", &"throw_flash"]
const GRENADE_ICON := 44.0
const GRENADE_GAP := 10
const GRENADE_TILE_GAP := 12
const GRENADE_TILE_HEIGHT := 160.0
const GRENADE_TILE_PAD := Vector2i(16, 14)
const GRENADE_SIZE := 17
const HEADING_GAP := 14
## SWITCH REPLICA on a carried card: its words' size and padding.
const SWITCH_SIZE := 14
const SWITCH_PAD := Vector2i(12, 5)
## The range's note under the Performance sheet (concept `loadout-practice.png`): the gap above, the padding (left past
## the rule, top, right, bottom), the rule's width, the kicker's and the words' sizes and the words' extra line spacing.
const NOTE_GAP := 18
const NOTE_PAD := Vector4(18.0, 14.0, 18.0, 16.0)
const NOTE_RULE := 4
const NOTE_KICKER_SIZE := 13
const NOTE_SIZE := 17
const NOTE_LINE := 3
const NOTE_WORDS_GAP := 6
const NOTE_KICKER_SPACING := 0.1

var _pictures: ReplicaPictures = null
var _carried: Array[MenuCard] = []
var _carried_pic: Array[TextureRect] = []
var _carried_customise: Array[Button] = []
var _carried_switch: Array[Button] = []
## Pixels per metre of replica in the carried cards.
var _carried_scale: float = 1.0
var _carried_name: Array[Label] = []
var _carried_sub: Array[Label] = []
var _switch: LoadoutSwitch = null
var _sheet: PerformanceSheet = null
var _line_name: Label = null
var _line_rest: Label = null
var _grenade_keys: Array[Label] = []
var _picked: Loadout.Slot = Loadout.Slot.PRIMARY
var _facts: LoadoutFacts = null
var _note: Control = null


func _init(pictures: ReplicaPictures, facts: LoadoutFacts) -> void:
	name = "LoadoutGear"
	_pictures = pictures
	_facts = facts
	_set_scales()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m := MenuParts.PAGE_MARGIN
	var title := _build_title()
	title.position = Vector2(m.x, m.y)
	add_child(title)
	var margin := MenuParts.padded(m.x, TOP, m.z, m.w)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", MenuParts.PANEL_GAP)
	margin.add_child(columns)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", MenuParts.PANEL_GAP)
	columns.add_child(left)
	_build_carried()
	_carried[Loadout.Slot.PRIMARY].size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_carried[Loadout.Slot.PRIMARY])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", MenuParts.PANEL_GAP)
	var secondary := _carried[Loadout.Slot.SECONDARY]
	secondary.custom_minimum_size.x = SECONDARY_WIDTH
	row.add_child(secondary)
	row.add_child(_build_grenades())
	left.add_child(row)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 0)
	side.custom_minimum_size = Vector2(SIDE_WIDTH, 0.0)
	_sheet = PerformanceSheet.new()
	# as tall as the column, as the panels beside it; the range's note under it when it shows
	_sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(_sheet)
	_note = _build_range_note()
	side.add_child(_note)
	columns.add_child(side)
	# over the whole page while it is open
	_switch = LoadoutSwitch.new(pictures, facts)
	_switch.picked.connect(func(id: String) -> void: replica_picked.emit(id))
	_switch.closed.connect(_on_switch_closed)
	add_child(_switch)


func carried_card(slot: Loadout.Slot) -> MenuCard:
	return _carried[slot]


## A replica's card in the SWITCH REPLICA pop-up.
func replica_card(id: String) -> MenuCard:
	return _switch.card(id)


## SWITCH REPLICA on the carried card of `slot`.
func switch_button(slot: Loadout.Slot) -> Button:
	return _carried_switch[slot]


## The SWITCH REPLICA pop-up, and whether it is open.
func switcher() -> LoadoutSwitch:
	return _switch


func switching() -> bool:
	return _switch.visible


## Picks `slot` and opens the pop-up of replicas to carry in it.
func open_switch(slot: Loadout.Slot) -> void:
	slot_picked.emit(slot)
	_switch.open(slot)


## Closes the pop-up with nothing changed.
func close_switch() -> void:
	_switch.close()


## The pop-up closed: the keyboard goes back to the SWITCH REPLICA it was opened from (BP4: it was left on nothing),
## unless the page itself is going away.
func _on_switch_closed() -> void:
	var back := _carried_switch[_switch.slot()] if _switch.slot() < _carried_switch.size() else null
	if back != null and back.is_visible_in_tree():
		back.grab_focus()


func sheet() -> PerformanceSheet:
	return _sheet


## CUSTOMISE: on the picked carried card.
func customise_button() -> Button:
	return _carried_customise[_picked]


## The title's line ("CQB Rush · AEG Rifle and GBB Pistol · carried into every match").
func foot_text() -> String:
	return _line_name.text + _line_rest.text


func replica_ids() -> PackedStringArray:
	return _switch.ids()


## Shows the carried loadout, with `slot` picked and the paint names as the Realistic colours switch says.
func refresh(slot: Loadout.Slot, realistic: bool) -> void:
	var f := _facts
	_picked = slot
	# a rebind in Settings › Controls shows when the page is shown again (LoadoutPage refreshes then)
	for kind: int in [Grenade.Kind.SMOKE, Grenade.Kind.FLASH]:
		_grenade_keys[kind].text = KeyNames.of_action(GRENADE_ACTIONS[kind])
	var names := PackedStringArray()
	for s in LoadoutFacts.SLOTS:
		var card := _carried[s]
		card.set_picked(s == slot)
		_carried_customise[s].visible = s == slot
		if not f.has(s):
			continue
		var item := f.item(s)
		var t := f.tune(s)
		names.append(item.display_name)
		_carried_name[s].text = item.display_name.to_upper()
		var bits := PackedStringArray([f.paint_name(s, realistic), tr("LOADOUT_GRAMS") % t.bb_weight])
		var power := f.power_name(s)
		if power != "":
			bits.append(power)
		_carried_sub[s].text = " · ".join(bits)
		_carried_pic[s].texture = _pictures.texture(item.key, t.paint, realistic, f.fitted_keys(item))
	_line_name.text = f.saved.carried().name
	_line_rest.text = " · " + tr("LOADOUT_FOOT") % " and ".join(names) if not names.is_empty() else ""
	_sheet.show_sheet(f.sheet(slot), tr("LOADOUT_SHEET_SUB") % f.item(slot).display_name)
	_sheet.set_replica(f.item(slot).display_name)
	# the pictures now hold the parts fitted: one scale again for every replica, sized to the longest
	_set_scales()
	for s in LoadoutFacts.SLOTS:
		if f.has(s):
			_carried_pic[s].custom_minimum_size = _pictures.extent(f.item(s).key) * _carried_scale
	_switch.refresh(realistic)


## The carried cards' scale: the longest replica listed fills the box (and no replica is taller than it).
func _set_scales() -> void:
	var longest := LoadoutSwitch.longest(_pictures, _facts.rules())
	if longest != Vector2.ZERO:
		_carried_scale = minf(CARRIED_BOX.x / longest.x, CARRIED_BOX.y / longest.y)


## The picture in a carried card, and on a replica's card in the pop-up (for the tests).
func carried_picture(slot: Loadout.Slot) -> TextureRect:
	return _carried_pic[slot]


func list_picture(id: String) -> TextureRect:
	return _switch.picture(id)


## The two carried cards (not yet placed): the slot's label and key at the top left, the replica in the middle in a
## box CARRIED_BOX holds, its name and what it carries at the foot, CUSTOMISE at the bottom right while it is picked.
func _build_carried() -> void:
	for s in LoadoutFacts.SLOTS:
		var card := MenuCard.new()
		card.name = "Carried_%d" % (s + 1)
		card.ring = true
		# glass like the panels beside them: the ring says which is picked
		card.fill = GameTheme.PANEL
		card.picked_fill = GameTheme.PANEL
		card.custom_minimum_size = Vector2(0.0, CARD_HEAD + CARRIED_BOX.y + CARD_FOOT + 2.0 * CARD_PAD.y)
		var pad := MenuParts.padded(CARD_PAD.x, CARD_PAD.y, CARD_PAD.x, CARD_PAD.y)
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var stack := VBoxContainer.new()
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_theme_constant_override("separation", 0)
		var head := HBoxContainer.new()
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.custom_minimum_size = Vector2(0.0, CARD_HEAD)
		head.alignment = BoxContainer.ALIGNMENT_BEGIN
		head.add_theme_constant_override("separation", SLOT_KEY_GAP)
		var label := MenuParts.head_text(tr(LoadoutFacts.SLOT_KEYS[s]), SLOT_SIZE, 600, GameTheme.MUTED, SLOT_SPACING)
		label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		head.add_child(label)
		var key := MenuParts.key_chip(str(s + 1), KEY_SIZE, GameTheme.DIM, KEY_PAD)
		key.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		head.add_child(key)
		var room := Control.new()
		room.mouse_filter = Control.MOUSE_FILTER_IGNORE
		room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(room)
		var switch := Button.new()
		switch.name = "SwitchReplica"
		switch.text = tr("LOADOUT_SWITCH_REPLICA").to_upper()
		SettingsSavePage.paint(switch, GameTheme.CARD_HI, GameTheme.LINE, GameTheme.TEXT, SWITCH_SIZE, SWITCH_PAD)
		switch.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		switch.pressed.connect(open_switch.bind(s))
		head.add_child(switch)
		stack.add_child(head)
		# the picture's room grows with the card (the primary fills the column), the picture stays at the one scale
		var stage := CenterContainer.new()
		stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
		stage.custom_minimum_size = Vector2(0.0, CARRIED_BOX.y)
		var pic := MenuParts.picture(CARRIED_BOX)
		stage.add_child(pic)
		stack.add_child(stage)
		var foot := HBoxContainer.new()
		foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		foot.custom_minimum_size = Vector2(0.0, CARD_FOOT)
		var words := VBoxContainer.new()
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		words.alignment = BoxContainer.ALIGNMENT_END
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_theme_constant_override("separation", NAME_SUB_GAP)
		var item_name := MenuParts.head_text("", NAME_SIZE, 700, GameTheme.TEXT, NAME_SPACING)
		item_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		words.add_child(item_name)
		var sub := MenuParts.text("", SUB_SIZE, 500, GameTheme.MUTED)
		sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		words.add_child(sub)
		foot.add_child(words)
		var customise := Button.new()
		customise.name = "Customise"
		customise.theme_type_variation = GameTheme.MAIN_BUTTON
		customise.text = tr("LOADOUT_CUSTOMISE")
		customise.add_theme_font_size_override("font_size", CUSTOMISE_SIZE)
		customise.size_flags_vertical = Control.SIZE_SHRINK_END
		customise.visible = false
		customise.pressed.connect(func() -> void: customise_requested.emit())
		foot.add_child(customise)
		stack.add_child(foot)
		pad.add_child(stack)
		card.add_content(pad)
		# add_content lets the mouse through the card's insides to the card, so the two buttons in it take their own
		# clicks again after it (set before, SWITCH REPLICA was turned off and its clicks picked the card: UF2)
		customise.mouse_filter = Control.MOUSE_FILTER_STOP
		switch.mouse_filter = Control.MOUSE_FILTER_STOP
		card.pressed.connect(func() -> void: slot_picked.emit(s))
		_carried.append(card)
		_carried_pic.append(pic)
		_carried_name.append(item_name)
		_carried_sub.append(sub)
		_carried_customise.append(customise)
		_carried_switch.append(switch)


## The grenades every loadout carries each round (SF1), on a glass panel: a tile a bomb, its canister (GrenadeGlyph),
## its count and name, and the key that throws it. Nothing to pick yet: chest rigs and pouches decide what you carry in a
## later version.
func _build_grenades() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", HEADING_GAP)
	box.add_child(MenuParts.heading(tr("LOADOUT_GRENADES")))
	var tiles := HBoxContainer.new()
	tiles.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tiles.add_theme_constant_override("separation", GRENADE_TILE_GAP)
	var bombs := SimTuning.load_default().grenades
	var carried: Array[int] = [0, bombs.smoke_carried, bombs.flash_carried]
	_grenade_keys.resize(GRENADE_KEYS.size())
	for kind: int in [Grenade.Kind.SMOKE, Grenade.Kind.FLASH]:
		var tile := PanelContainer.new()
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.custom_minimum_size = Vector2(0.0, GRENADE_TILE_HEIGHT)
		tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_theme_stylebox_override("panel", GameTheme.box(GameTheme.CARD, GameTheme.LINE, GRENADE_TILE_PAD.x,
				GRENADE_TILE_PAD.y))
		var column := VBoxContainer.new()
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_theme_constant_override("separation", GRENADE_GAP)
		var icon := GrenadeGlyph.new(kind, GRENADE_ICON)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(icon)
		var item := MenuParts.text(tr(GRENADE_KEYS[kind]) % carried[kind], GRENADE_SIZE, 700, GameTheme.TEXT)
		item.name = GRENADE_KEYS[kind]
		item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(item)
		var key := MenuParts.key_chip("", KEY_SIZE, GameTheme.DIM, KEY_PAD)
		key.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_grenade_keys[kind] = key.get_child(0) as Label
		column.add_child(key)
		tile.add_child(column)
		tiles.add_child(tile)
	box.add_child(tiles)
	var panel := MenuParts.glass(box)
	panel.name = "Grenades"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.tooltip_text = tr("LOADOUT_GRENADES_TIP")
	return panel


## Shows or hides the note from the range (Loadout opened from practice): what is carried here is the match loadout too.
func show_range_note(on: bool) -> void:
	_note.visible = on


func range_note_visible() -> bool:
	return _note.visible


## The note: a gap, then a yellow rule with a panel beside it (lined above, right and below), "FROM THE RANGE" and the
## words in it. Hidden until asked for.
func _build_range_note() -> Control:
	var holder := VBoxContainer.new()
	holder.name = "RangeNote"
	holder.add_theme_constant_override("separation", 0)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, NOTE_GAP)
	holder.add_child(gap)
	var plate := HBoxContainer.new()
	plate.add_theme_constant_override("separation", 0)
	var rule := ColorRect.new()
	rule.color = GameTheme.ACCENT
	rule.custom_minimum_size = Vector2(NOTE_RULE, 0.0)
	plate.add_child(rule)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var face := GameTheme.box(Color(GameTheme.PANEL, 0.96), GameTheme.LINE, int(NOTE_PAD.x),
			int(NOTE_PAD.y))
	face.border_width_left = 0
	face.content_margin_right = NOTE_PAD.z
	face.content_margin_bottom = NOTE_PAD.w
	panel.add_theme_stylebox_override("panel", face)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", NOTE_WORDS_GAP)
	words.add_child(MenuParts.spaced(tr("LOADOUT_RANGE_KICKER").to_upper(), NOTE_KICKER_SIZE, 800, GameTheme.ACCENT,
			NOTE_KICKER_SPACING))
	var text := MenuParts.text(tr("LOADOUT_RANGE_NOTE"), NOTE_SIZE, 600, GameTheme.TEXT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_constant_override("line_spacing", NOTE_LINE)
	words.add_child(text)
	panel.add_child(words)
	plate.add_child(panel)
	holder.add_child(plate)
	holder.visible = false
	return holder


## LOADOUT in condensed capitals and its line beside it: the loadout carried and what is in it.
func _build_title() -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 0)
	_line_name = MenuParts.text("", MenuParts.PAGE_LINE_SIZE, 700, GameTheme.TEXT)
	_line_rest = MenuParts.page_line("")
	line.add_child(_line_name)
	line.add_child(_line_rest)
	return MenuParts.page_title(tr("MENU_TAB_LOADOUT"), line)
