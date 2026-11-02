class_name LoadoutGear
extends Control
## The Loadout tab's gear page body (concept `gear.png`): CARRIED (the primary and the secondary, the picked slot ringed in
## yellow, and the grenades carried every round: a smoke and a flash, SF1), YOUR REPLICAS (each replica to carry, the
## cards of those carried tagged with their slot, the ones the game can't play yet greyed LATER and the ones not
## unlocked yet greyed with their level), the hint, the Performance sheet and the slanted CUSTOMISE.
## A replica's picture sits inside its card with room round it, kept in shape, so it can't touch the card's lines at any
## window size. The page owner reads `slot_picked`, `replica_picked` and `customise_requested` and calls `refresh`.

signal slot_picked(slot: Loadout.Slot)
signal replica_picked(id: String)
signal customise_requested

# beside the side rail (UR1): 48 + 700 + 32 + 424 + 32 + 500 + 48 fills the 1784 px the rail leaves of 1920
const MARGIN_X := 48
const TOP := 116
const BOTTOM := 120
const COLUMN_GAP := 32
const CARRIED_WIDTH := 700.0
const SIDE_WIDTH := 500.0
const CARD_GAP := 18
## A carried card's picture area is as tall in both slots, so a rifle fits either.
const IMAGE_HEIGHT := 230.0
## Room round a carried picture: below the slot's name and key (the label ends about 30 px down) and at the sides and foot.
const PICTURE_TOP := 46.0
const PICTURE_SIDE := 16.0
const PICTURE_BOTTOM := 16.0
## The room the longest replica's picture takes in a carried card and in the list. Every replica in the cards is drawn at
## the scale that fills the first, and every one in the list at the list's, so replicas read true to size against each
## other (owner, 2026-10-19).
const CARRIED_BOX := Vector2(CARRIED_WIDTH - 2.0 * GameTheme.BORDER - 2.0 * PICTURE_SIDE,
		IMAGE_HEIGHT - PICTURE_TOP - PICTURE_BOTTOM)
const LIST_BOX := Vector2(168.0, 72.0)
const TITLE_PAD := Vector4(18.0, 12.0, 18.0, 16.0)
const TITLE_HEIGHT := 62.0
const LABEL_SIZE := 15
const LABEL_SPACING := 0.1
const LABEL_POS := Vector2(18.0, 14.0)
const NAME_SIZE := 24
const SUB_SIZE := 16
const KEY_SIZE := 13
const OFF_HEIGHT := 48.0
## The grenades row: each bomb's words (Grenade.Kind order, NONE unused) and its colour dot's size (px).
const GRENADE_KEYS: Array[String] = ["", "LOADOUT_SMOKE", "LOADOUT_FLASH"]
const GRENADE_DOT := 10.0
const REPLICA_GAP := 12
const REPLICA_HEIGHT := 92.0
const REPLICA_PICTURE := Vector2(188.0, 0.0)
const REPLICA_PICTURE_PAD := Vector2(10.0, 8.0)
const REPLICA_NAME_SIZE := 20
const REPLICA_SUB_SIZE := 15
const REPLICA_TEXT_GAP := 4
## The list is never narrower than a picture and a name, in a window too small for the page (its old, larger heading
## used to hold it this wide).
const REPLICAS_MIN_WIDTH := 320.0
## The range's note under the list (concept `loadout-practice.png`): the gap above, the padding (left past the rule, top,
## right, bottom; the left is past the rule), the rule's width, the kicker's and the words' sizes and the words' extra line spacing (px at 1080p).
const NOTE_GAP := 28
const NOTE_PAD := Vector4(18.0, 14.0, 18.0, 16.0)
const NOTE_RULE := 4
const NOTE_KICKER_SIZE := 13
const NOTE_SIZE := 17
const NOTE_LINE := 3
const FOOT_LEFT := 56.0
const FOOT_BOTTOM := 58.0
const FOOT_SIZE := 18
const CUSTOMISE_RIGHT := 56.0
const CUSTOMISE_BOTTOM := 44.0
## The range note: the gap between its kicker and its words, and the kicker's letter spacing (share of its size).
const NOTE_WORDS_GAP := 6
const NOTE_KICKER_SPACING := 0.1

var _pictures: ReplicaPictures = null
var _glow: GradientTexture2D = null
var _carried: Array[MenuCard] = []
var _carried_pic: Array[TextureRect] = []
## Pixels per metre of replica in the carried cards and in the list.
var _carried_scale: float = 1.0
var _list_scale: float = 1.0
var _carried_name: Array[Label] = []
var _carried_sub: Array[Label] = []
var _rows: Dictionary[String, MenuCard] = {}
var _row_pic: Dictionary[String, TextureRect] = {}
var _row_slot: Dictionary[String, Label] = {}
var _row_rest: Dictionary[String, Label] = {}
var _sheet: PerformanceSheet = null
var _foot_name: Label = null
var _foot_rest: Label = null
var _customise: Button = null
var _facts: LoadoutFacts = null
var _note: Control = null


func _init(pictures: ReplicaPictures, facts: LoadoutFacts) -> void:
	name = "LoadoutGear"
	_pictures = pictures
	_facts = facts
	_glow = MenuParts.glow(GameTheme.CARD)
	_set_scales()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", MARGIN_X)
	margin.add_theme_constant_override("margin_right", MARGIN_X)
	margin.add_theme_constant_override("margin_top", TOP)
	margin.add_theme_constant_override("margin_bottom", BOTTOM)
	add_child(margin)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", COLUMN_GAP)
	margin.add_child(columns)
	columns.add_child(_build_carried())
	columns.add_child(_build_replicas())
	_sheet = PerformanceSheet.new()
	_sheet.custom_minimum_size = Vector2(SIDE_WIDTH, 0.0)
	# as tall as its rows: filling the column took it down onto CUSTOMISE (UI1)
	_sheet.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	columns.add_child(_sheet)
	_build_foot()


func carried_card(slot: Loadout.Slot) -> MenuCard:
	return _carried[slot]


func replica_card(id: String) -> MenuCard:
	return _rows.get(id)


func sheet() -> PerformanceSheet:
	return _sheet


func customise_button() -> Button:
	return _customise


## The line under the cards ("CQB Rush · AEG Rifle and GBB Pistol · carried into every match").
func foot_text() -> String:
	return _foot_name.text + _foot_rest.text


func replica_ids() -> PackedStringArray:
	return PackedStringArray(_rows.keys())


## Shows the carried loadout, with `slot` picked and the paint names as the Realistic colours switch says.
func refresh(slot: Loadout.Slot, realistic: bool) -> void:
	var f := _facts
	var names := PackedStringArray()
	for s in LoadoutFacts.SLOTS:
		var card := _carried[s]
		card.set_picked(s == slot)
		if not f.has(s):
			continue
		var item := f.item(s)
		var t := f.tune(s)
		names.append(item.display_name)
		_carried_name[s].text = item.display_name
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
		if carried_in >= 0:
			_row_slot[id].text = tr(LoadoutFacts.SLOT_KEYS[carried_in])
		var config := f.rules().config(item)
		if config != null:
			var rest := tr("LOADOUT_REPLICA_SUB") % [_class_word(config.site_class), roundi(config.fire_rate)]
			_row_rest[id].text = (" · " + rest) if carried_in >= 0 else rest
		elif carried_in < 0:
			_row_rest[id].text = tr("LOADOUT_COMES_WITH_LEVELS") % _class_word(_site_class(item))
	_foot_name.text = f.saved.carried().name
	_foot_rest.text = " · " + tr("LOADOUT_FOOT") % " and ".join(names) if not names.is_empty() else ""
	_sheet.show_sheet(f.sheet(slot), tr("LOADOUT_SHEET_SUB") % f.item(slot).display_name)
	# the pictures now hold the parts fitted: one scale again for every replica, sized to the longest
	_set_scales()
	for s in LoadoutFacts.SLOTS:
		if f.has(s):
			_carried_pic[s].custom_minimum_size = _pictures.extent(f.item(s).key) * _carried_scale
	for id: String in _rows:
		_row_pic[id].custom_minimum_size = _pictures.extent(f.pool().item(id).key) * _list_scale


## The two scales: each lets the longest replica listed fill its box (and no replica be taller than the box).
func _set_scales() -> void:
	var longest := Vector2.ZERO
	for item in _listed():
		var e := _pictures.extent(item.key)
		longest = Vector2(maxf(longest.x, e.x), maxf(longest.y, e.y))
	if longest == Vector2.ZERO:
		return
	_carried_scale = minf(CARRIED_BOX.x / longest.x, CARRIED_BOX.y / longest.y)
	_list_scale = minf(LIST_BOX.x / longest.x, LIST_BOX.y / longest.y)


## The picture in a carried card, and in a list row (for the tests).
func carried_picture(slot: Loadout.Slot) -> TextureRect:
	return _carried_pic[slot]


func list_picture(id: String) -> TextureRect:
	return _row_pic[id]


func _build_carried() -> Control:
	var column := MenuParts.section(MenuParts.heading(tr("LOADOUT_CARRIED")))
	column.custom_minimum_size = Vector2(CARRIED_WIDTH, 0.0)
	var cards := VBoxContainer.new()
	cards.add_theme_constant_override("separation", CARD_GAP)
	column.add_child(cards)
	for s in LoadoutFacts.SLOTS:
		var card := MenuCard.new()
		card.name = "Carried_%d" % (s + 1)
		card.ring = true
		var image := IMAGE_HEIGHT
		card.custom_minimum_size = Vector2(0.0, image + TITLE_HEIGHT + GameTheme.BORDER)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		var stage := Control.new()
		stage.custom_minimum_size = Vector2(0.0, image)
		stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var glow := TextureRect.new()
		glow.texture = _glow
		glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(glow)
		var pad := MenuParts.padded(PICTURE_SIDE, PICTURE_TOP, PICTURE_SIDE, PICTURE_BOTTOM)
		pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var pic := MenuParts.picture(CARRIED_BOX)
		pad.add_child(pic)
		stage.add_child(pad)
		var label := MenuParts.spaced(tr(LoadoutFacts.SLOT_KEYS[s]), LABEL_SIZE, 800, GameTheme.MUTED, LABEL_SPACING)
		label.position = LABEL_POS
		stage.add_child(label)
		stage.add_child(_key_chip(s + 1))
		box.add_child(stage)
		var title := PanelContainer.new()
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rule := GameTheme.box(Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), int(TITLE_PAD.x),
				int(TITLE_PAD.y))
		rule.border_width_top = GameTheme.BORDER
		rule.border_color = GameTheme.LINE
		rule.content_margin_bottom = TITLE_PAD.w
		title.add_theme_stylebox_override("panel", rule)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var item_name := MenuParts.text("", NAME_SIZE, 800, GameTheme.TEXT)
		item_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(item_name)
		var sub := MenuParts.text("", SUB_SIZE, 600, GameTheme.MUTED)
		sub.size_flags_vertical = Control.SIZE_SHRINK_END
		row.add_child(sub)
		title.add_child(row)
		box.add_child(title)
		card.add_content(box)
		card.pressed.connect(func() -> void: slot_picked.emit(s))
		card.gui_input.connect(_double_click.bind(s))
		cards.add_child(card)
		_carried.append(card)
		_carried_pic.append(pic)
		_carried_name.append(item_name)
		_carried_sub.append(sub)
	cards.add_child(_build_grenades())
	return column


## The key chip at a card's top right (the concept's `.key`).
func _key_chip(number: int) -> Control:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override("panel", GameTheme.box(Color(0.0, 0.0, 0.0, 0.0), GameTheme.LINE, 7, 1))
	chip.add_child(MenuParts.text(str(number), KEY_SIZE, 800, GameTheme.DIM))
	chip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	chip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	chip.offset_right = -LABEL_POS.x
	chip.offset_top = LABEL_POS.y
	return chip


## The grenades every loadout carries each round (SF1): the label, then each bomb's count and name in its canister's
## colour (GrenadeView). Nothing to pick yet: chest rigs and pouches decide what you carry in a later version.
func _build_grenades() -> Control:
	var box := PanelContainer.new()
	box.name = "Grenades"
	box.custom_minimum_size = Vector2(0.0, OFF_HEIGHT)
	box.add_theme_stylebox_override("panel", GameTheme.box(GameTheme.CARD, GameTheme.LINE, int(LABEL_POS.x), 10))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", CARD_GAP)
	row.add_child(MenuParts.spaced(tr("LOADOUT_GRENADES"), LABEL_SIZE, 800, GameTheme.MUTED, LABEL_SPACING))
	var bombs := SimTuning.load_default().grenades
	var carried: Array[int] = [0, bombs.smoke_carried, bombs.flash_carried]
	for kind: int in [Grenade.Kind.SMOKE, Grenade.Kind.FLASH]:
		var item := MenuParts.text(tr(GRENADE_KEYS[kind]) % carried[kind], LABEL_SIZE, 700, GameTheme.TEXT)
		item.name = GRENADE_KEYS[kind]
		var dot := ColorRect.new()
		dot.color = GrenadeView.BODY_COLOURS[kind]
		dot.custom_minimum_size = Vector2(GRENADE_DOT, GRENADE_DOT)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(dot)
		row.add_child(item)
	box.tooltip_text = tr("LOADOUT_GRENADES_TIP")
	box.add_child(row)
	return box


func _build_replicas() -> Control:
	var column := MenuParts.section(MenuParts.heading(tr("LOADOUT_REPLICAS")))
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.custom_minimum_size.x = REPLICAS_MIN_WIDTH
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", REPLICA_GAP)
	column.add_child(list)
	var rules := _facts.rules()
	for item in _listed():
		var later := rules.config(item) == null
		var lock := rules.unlock_level(item.id) if not later and rules.is_locked(item.id) else -1
		list.add_child(_replica_row(item, later, lock))
	_note = _build_range_note()
	column.add_child(_note)
	return column


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
	gap.custom_minimum_size = Vector2(0.0, NOTE_GAP - MenuParts.HEADING_GAP)
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
	# how to pick, swap and customise: the card's tooltip (UI1: it was a paragraph under the list)
	if not later and lock_level < 0:
		card.tooltip_text = tr("LOADOUT_HINT")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	var pad := MenuParts.padded(REPLICA_PICTURE_PAD.x, REPLICA_PICTURE_PAD.y, REPLICA_PICTURE_PAD.x,
			REPLICA_PICTURE_PAD.y)
	pad.custom_minimum_size = Vector2(REPLICA_PICTURE.x, 0.0)
	var pic := MenuParts.picture(_pictures.extent(item.key) * _list_scale)
	pad.add_child(pic)
	row.add_child(pad)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", REPLICA_TEXT_GAP)
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", 10)
	title.add_child(MenuParts.text(item.display_name, REPLICA_NAME_SIZE, 800, GameTheme.TEXT))
	if later:
		title.add_child(MenuTag.later())
	if lock_level >= 0:
		title.add_child(MenuTag.level(lock_level))
	if item.is_dev():
		title.add_child(MenuTag.dev())
	text.add_child(title)
	var sub := HBoxContainer.new()
	sub.add_theme_constant_override("separation", 0)
	var slot_label := MenuParts.text("", REPLICA_SUB_SIZE, 800, GameTheme.ACCENT)
	var rest := MenuParts.text("", REPLICA_SUB_SIZE, 600, GameTheme.MUTED)
	sub.add_child(slot_label)
	sub.add_child(rest)
	text.add_child(sub)
	row.add_child(text)
	card.add_content(row)
	card.set_greyed(later or lock_level >= 0)
	card.pressed.connect(func() -> void: replica_picked.emit(item.id))
	card.gui_input.connect(_double_click_replica.bind(item.id))
	_rows[item.id] = card
	_row_pic[item.id] = pic
	_row_slot[item.id] = slot_label
	_row_rest[item.id] = rest
	return card


func _build_foot() -> void:
	var foot := HBoxContainer.new()
	foot.name = "Foot"
	foot.add_theme_constant_override("separation", 0)
	foot.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	foot.grow_vertical = Control.GROW_DIRECTION_BEGIN
	foot.offset_left = FOOT_LEFT
	foot.offset_bottom = -FOOT_BOTTOM
	_foot_name = MenuParts.text("", FOOT_SIZE, 800, GameTheme.TEXT)
	_foot_rest = MenuParts.text("", FOOT_SIZE, 600, GameTheme.MUTED)
	foot.add_child(_foot_name)
	foot.add_child(_foot_rest)
	add_child(foot)
	_customise = Button.new()
	_customise.name = "Customise"
	_customise.theme_type_variation = GameTheme.MAIN_BUTTON
	_customise.text = tr("LOADOUT_CUSTOMISE")
	_customise.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_customise.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_customise.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_customise.offset_right = -CUSTOMISE_RIGHT
	_customise.offset_bottom = -CUSTOMISE_BOTTOM
	_customise.pressed.connect(func() -> void: customise_requested.emit())
	add_child(_customise)


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
