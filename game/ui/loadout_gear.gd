class_name LoadoutGear
extends Control
## The Loadout tab's gear page body (UI concept B v2, `loadout.png`, owner 2026-11-02): LOADOUT and its line (the loadout
## carried and what is in it), then the glass panels: the PRIMARY card (its replica large, its name and what it carries,
## CUSTOMISE on the picked card), the SECONDARY card beside the GRENADES carried every round (SF1), the SWAP row (every
## replica to carry in the picked slot: the ones carried tagged with their slot, the ones the game can't play yet greyed
## LATER, the ones not unlocked yet greyed with their level) and the Performance sheet at the right.
## Every replica on the page is drawn at one scale (owner, 2026-10-19 and 2026-11-02: replicas to scale), the cards'
## sized so the longest fits a card's picture box and the swap row's so it fits a row's: a rifle in either slot is the
## same size, a pistol beside it true to size. The page owner reads `slot_picked`, `replica_picked` and
## `customise_requested` and calls `refresh`. LoadoutPage puts the saved loadouts' strip in the row under the title.

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
## The swap row: its label's width, the gap between its cards, a card's height and padding, and the picture box the
## longest replica fits there.
const SWAP_LABEL_WIDTH := 170.0
const SWAP_GAP := 12
const REPLICA_HEIGHT := 72.0
const REPLICA_PAD := Vector2(12.0, 8.0)
const LIST_BOX := Vector2(120.0, 52.0)
const REPLICA_NAME_SIZE := 17
const REPLICA_SUB_SIZE := 13
## What a swap card says under its name: the slot it is carried in, or nothing (the rest is its tooltip).
const REPLICA_TEXT_GAP := 2
const REPLICA_TAG_GAP := 6
const REPLICA_PIC_GAP := 12
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
## Pixels per metre of replica in the carried cards and in the swap row.
var _carried_scale: float = 1.0
var _list_scale: float = 1.0
var _carried_name: Array[Label] = []
var _carried_sub: Array[Label] = []
var _rows: Dictionary[String, MenuCard] = {}
var _row_pic: Dictionary[String, TextureRect] = {}
var _row_slot: Dictionary[String, Label] = {}
var _row_rest: Dictionary[String, Label] = {}
## The swap cards that can be carried now: their tooltip adds how to pick, swap and customise.
var _row_hint: Dictionary[String, bool] = {}
## A swap card's line under its name, and whether it has tags: the line hides when it has neither tags nor a slot, so
## the name sits in the middle.
var _row_sub: Dictionary[String, HBoxContainer] = {}
var _row_tagged: Dictionary[String, bool] = {}
var _sheet: PerformanceSheet = null
var _line_name: Label = null
var _line_rest: Label = null
var _swap_label: Label = null
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
	left.add_child(_build_swap())
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


func carried_card(slot: Loadout.Slot) -> MenuCard:
	return _carried[slot]


func replica_card(id: String) -> MenuCard:
	return _rows.get(id)


func sheet() -> PerformanceSheet:
	return _sheet


## CUSTOMISE: on the picked carried card.
func customise_button() -> Button:
	return _carried_customise[_picked]


## The title's line ("CQB Rush · AEG Rifle and GBB Pistol · carried into every match").
func foot_text() -> String:
	return _line_name.text + _line_rest.text


func replica_ids() -> PackedStringArray:
	return PackedStringArray(_rows.keys())


## Shows the carried loadout, with `slot` picked and the paint names as the Realistic colours switch says.
func refresh(slot: Loadout.Slot, realistic: bool) -> void:
	var f := _facts
	_picked = slot
	_swap_label.text = tr("LOADOUT_SWAP") % tr(LoadoutFacts.SLOT_KEYS[slot]).to_upper()
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
	for id: String in _rows:
		var item := f.pool().item(id)
		var t := f.rules().tune_of(f.saved.carried(), id)
		_row_pic[id].texture = _pictures.texture(item.key, t.paint, realistic, f.fitted_keys(item))
		var carried_in := f.slot_of(id)
		_row_slot[id].visible = carried_in >= 0
		_row_sub[id].visible = carried_in >= 0 or _row_tagged[id]
		if carried_in >= 0:
			_row_slot[id].text = tr(LoadoutFacts.SLOT_KEYS[carried_in])
		var config := f.rules().config(item)
		if config != null:
			var rest := tr("LOADOUT_REPLICA_SUB") % [_class_word(config.site_class), roundi(config.fire_rate)]
			_row_rest[id].text = (" · " + rest) if carried_in >= 0 else rest
		elif carried_in < 0:
			_row_rest[id].text = tr("LOADOUT_COMES_WITH_LEVELS") % _class_word(_site_class(item))
		var about := _row_rest[id].text.trim_prefix(" · ")
		_rows[id].tooltip_text = about + ("\n" + tr("LOADOUT_HINT") if _row_hint.has(id) else "")
	_line_name.text = f.saved.carried().name
	_line_rest.text = " · " + tr("LOADOUT_FOOT") % " and ".join(names) if not names.is_empty() else ""
	_sheet.show_sheet(f.sheet(slot), tr("LOADOUT_SHEET_SUB") % f.item(slot).display_name)
	_sheet.set_replica(f.item(slot).display_name)
	# the pictures now hold the parts fitted: one scale again for every replica, sized to the longest
	_set_scales()
	for s in LoadoutFacts.SLOTS:
		if f.has(s):
			_carried_pic[s].custom_minimum_size = _pictures.extent(f.item(s).key) * _carried_scale
	for id: String in _rows:
		_row_pic[id].custom_minimum_size = _list_size(f.pool().item(id))


## The two scales: each lets the longest replica listed fill its box (and no replica be taller than the box).
func _set_scales() -> void:
	var longest := Vector2.ZERO
	var rules := _facts.rules()
	for item in _listed():
		# a replica the game can't play yet has no model to measure (its extent is a stand-in), so it sets no scale
		if rules.config(item) == null:
			continue
		var e := _pictures.extent(item.key)
		longest = Vector2(maxf(longest.x, e.x), maxf(longest.y, e.y))
	if longest == Vector2.ZERO:
		return
	_carried_scale = minf(CARRIED_BOX.x / longest.x, CARRIED_BOX.y / longest.y)
	_list_scale = minf(LIST_BOX.x / longest.x, LIST_BOX.y / longest.y)


## A replica's picture size in the swap row: at the row's scale, and never past its box (a replica the game can't play
## yet has only a stand-in extent, so it is fitted to the box instead).
func _list_size(item: Pool.Item) -> Vector2:
	var want := _pictures.extent(item.key) * _list_scale
	var fit := minf(1.0, minf(LIST_BOX.x / want.x, LIST_BOX.y / want.y)) if want.x > 0.0 and want.y > 0.0 else 1.0
	return want * fit


## The picture in a carried card, and in a list row (for the tests).
func carried_picture(slot: Loadout.Slot) -> TextureRect:
	return _carried_pic[slot]


func list_picture(id: String) -> TextureRect:
	return _row_pic[id]


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
		# the card lets the mouse through its insides; CUSTOMISE takes its own clicks
		customise.mouse_filter = Control.MOUSE_FILTER_STOP
		card.pressed.connect(func() -> void: slot_picked.emit(s))
		card.gui_input.connect(_double_click.bind(s))
		_carried.append(card)
		_carried_pic.append(pic)
		_carried_name.append(item_name)
		_carried_sub.append(sub)
		_carried_customise.append(customise)


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


## SWAP PRIMARY (or SECONDARY): every replica to carry in the picked slot, in a row, at the row's one scale.
func _build_swap() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", SWAP_GAP)
	_swap_label = MenuParts.heading("")
	_swap_label.custom_minimum_size = Vector2(SWAP_LABEL_WIDTH, 0.0)
	_swap_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_swap_label)
	var rules := _facts.rules()
	for item in _listed():
		var later := rules.config(item) == null
		var lock := rules.unlock_level(item.id) if not later and rules.is_locked(item.id) else -1
		row.add_child(_replica_row(item, later, lock))
	var panel := MenuParts.glass(row)
	panel.name = "Swap"
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


## The replicas to list: the ones a new player carries first (ReplicaStats.DEFAULT_LOADOUT), then the rest in the pool's
## order; dev replicas only with Dev content on. The order stays put as replicas are swapped.
func _listed() -> Array[Pool.Item]:
	var rules := _facts.rules()
	var out: Array[Pool.Item] = []
	for key in ReplicaStats.DEFAULT_LOADOUT:
		var it := rules.pool.replica_by_key(key)
		if it != null and not (it.is_dev() and not rules.dev_content):
			out.append(it)
	for it in rules.pool.replicas:
		if not out.has(it) and not (it.is_dev() and not rules.dev_content):
			out.append(it)
	return out


## A replica's row; `lock_level` >= 0: not unlocked yet, greyed with the level that unlocks it.
func _replica_row(item: Pool.Item, later: bool, lock_level: int) -> MenuCard:
	var card := MenuCard.new()
	card.name = "Replica_%s" % item.id
	card.custom_minimum_size = Vector2(0.0, REPLICA_HEIGHT)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# how to pick, swap and customise: the card's tooltip (UI1: it was a paragraph under the list)
	if not later and lock_level < 0:
		_row_hint[item.id] = true
	var pad := MenuParts.padded(REPLICA_PAD.x, REPLICA_PAD.y, REPLICA_PAD.x, REPLICA_PAD.y)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", REPLICA_PIC_GAP)
	var stage := CenterContainer.new()
	stage.custom_minimum_size = Vector2(LIST_BOX.x, 0.0)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pic := MenuParts.picture(_list_size(item))
	stage.add_child(pic)
	row.add_child(stage)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", REPLICA_TEXT_GAP)
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", 10)
	var item_name := MenuParts.text(item.display_name, REPLICA_NAME_SIZE, 700, GameTheme.TEXT)
	item_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	item_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(item_name)
	text.add_child(title)
	# under the name: the slot it is carried in, or its tags (LATER, the level that unlocks it, DEV), so the name keeps
	# the card's width
	var sub := HBoxContainer.new()
	sub.add_theme_constant_override("separation", REPLICA_TAG_GAP)
	if later:
		sub.add_child(MenuTag.later())
	if lock_level >= 0:
		sub.add_child(MenuTag.level(lock_level))
	if item.is_dev():
		sub.add_child(MenuTag.dev())
	_row_sub[item.id] = sub
	_row_tagged[item.id] = sub.get_child_count() > 0
	var slot_label := MenuParts.text("", REPLICA_SUB_SIZE, 700, GameTheme.ACCENT)
	# the class and fire rate: the card's tooltip, not a line cut short (the concept's cards show the name only)
	var rest := MenuParts.text("", REPLICA_SUB_SIZE, 500, GameTheme.MUTED)
	rest.visible = false
	sub.add_child(slot_label)
	sub.add_child(rest)
	text.add_child(sub)
	row.add_child(text)
	pad.add_child(row)
	card.add_content(pad)
	card.set_greyed(later or lock_level >= 0)
	card.pressed.connect(func() -> void: replica_picked.emit(item.id))
	card.gui_input.connect(_double_click_replica.bind(item.id))
	_rows[item.id] = card
	_row_pic[item.id] = pic
	_row_slot[item.id] = slot_label
	_row_rest[item.id] = rest
	return card


## LOADOUT in condensed capitals and its line beside it: the loadout carried and what is in it.
func _build_title() -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 0)
	_line_name = MenuParts.text("", MenuParts.PAGE_LINE_SIZE, 700, GameTheme.TEXT)
	_line_rest = MenuParts.page_line("")
	line.add_child(_line_name)
	line.add_child(_line_rest)
	return MenuParts.page_title(tr("MENU_TAB_LOADOUT"), line)


## A double click on a carried card opens Customise for it.
func _double_click(event: InputEvent, slot: Loadout.Slot) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.double_click and click.button_index == MOUSE_BUTTON_LEFT and click.pressed:
		slot_picked.emit(slot)
		customise_requested.emit()


## A double click on a replica card that is carried does the same for its slot.
func _double_click_replica(event: InputEvent, id: String) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.double_click and click.button_index == MOUSE_BUTTON_LEFT and click.pressed:
		var slot := _facts.slot_of(id)
		if slot >= 0:
			slot_picked.emit(slot as Loadout.Slot)
			customise_requested.emit()


func _class_word(site_class: StringName) -> String:
	return tr("LOADOUT_CLASS_" + String(site_class).to_upper())


## The class a replica the game can't play yet belongs to: from its pool tags.
func _site_class(item: Pool.Item) -> StringName:
	return &"pistol" if item.tags.has("pistol") else &"rifle"
