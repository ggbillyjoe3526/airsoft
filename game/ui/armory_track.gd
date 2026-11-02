class_name ArmoryTrack
extends VBoxContainer
## The Armory's levels (concept armory.png): the heading with its note, then a row for the starting kit and each level, each
## with its items' pictures and names, marked unlocked (green), next (yellow, lit) or locked (dimmed). The rows scroll when
## the cap goes up past what the window holds.

const ROW_GAP := 6
const ROW_HEIGHT := 76.0
const HEAD_WIDTH := 190.0
const HEAD_PAD := 16
const NAME_SIZE := 19
const STATE_SIZE := 13
const ITEMS_GAP := 8
const ITEMS_PAD := 8
const CHIP_SIZE := Vector2(230.0, 60.0)
const CHIP_PICTURE := Vector2(96.0, 56.0)
const CHIP_PICTURE_MAX := Vector2(86.0, 46.0)
const CHIP_NAME_SIZE := 15
const CHIP_KIND_SIZE := 12
const CHIP_FILL := Color(1.0, 1.0, 1.0, 0.03)
const LOCKED_ALPHA := 0.4
const NEXT_EDGE := 7
const NOTE_GAP := 12
const HEAD_BOTTOM := 12

var _facts: ArmoryFacts = null
var _pictures: ItemPictures = null
var _rows: Dictionary[int, Control] = {}


func _init(facts: ArmoryFacts, pictures: ItemPictures) -> void:
	name = "ArmoryTrack"
	_facts = facts
	_pictures = pictures
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", HEAD_BOTTOM)
	add_child(_heading())
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", ROW_GAP)
	scroll.add_child(list)
	for row in _facts.rows:
		var view := _row(row)
		_rows[row.number] = view
		list.add_child(view)


## The row of level `number` (0: the starting kit).
func row(number: int) -> Control:
	return _rows.get(number)


func _heading() -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", NOTE_GAP)
	line.add_child(MenuParts.heading(tr("ARMORY_LEVELS_HEAD")))
	# that unlocks stay, and the Dev switch that unlocks all: the heading's tooltip (UI1)
	line.mouse_filter = Control.MOUSE_FILTER_PASS
	line.tooltip_text = tr("ARMORY_LEVELS_NOTE")
	return line


func _row(r: ArmoryFacts.Row) -> Control:
	var next := r.state == ArmoryFacts.State.NEXT
	var panel := PanelContainer.new()
	panel.name = "Level%d" % r.number
	panel.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	var face := GameTheme.box(GameTheme.CARD_HI if next else GameTheme.CARD,
			GameTheme.ACCENT if next else GameTheme.LINE, 0, 0)
	if next:
		face.border_width_left = NEXT_EDGE
	panel.add_theme_stylebox_override("panel", face)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 0)
	panel.add_child(line)
	line.add_child(_head(r))
	# a row of more items than fit wraps onto a second line (the starting kit ran off the window's right edge)
	var items := HFlowContainer.new()
	items.name = "Items"
	items.add_theme_constant_override("h_separation", ITEMS_GAP)
	items.add_theme_constant_override("v_separation", ITEMS_GAP)
	items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if r.state == ArmoryFacts.State.LOCKED:
		items.modulate.a = LOCKED_ALPHA
	var room := MenuParts.padded(ITEMS_PAD, ITEMS_PAD, ITEMS_PAD, ITEMS_PAD)
	room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room.add_child(items)
	line.add_child(room)
	for it in r.items:
		items.add_child(_chip(it))
	return panel


## "LEVEL 4" over "1,300 XP · NEXT".
func _head(r: ArmoryFacts.Row) -> Control:
	var pad := MenuParts.padded(HEAD_PAD, 0.0, 0.0, 0.0)
	pad.custom_minimum_size = Vector2(HEAD_WIDTH, 0.0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pad.add_child(column)
	var locked := r.state == ArmoryFacts.State.LOCKED
	var title := tr("ARMORY_START") if r.number == 0 else tr("ARMORY_ROW_LEVEL") % r.number
	column.add_child(MenuParts.spaced(title, NAME_SIZE, 800, GameTheme.MUTED if locked else GameTheme.TEXT, 0.04))
	var state_key: String = "ARMORY_STATE_" + ArmoryFacts.State.keys()[r.state]
	var colour := GameTheme.MUTED
	if r.state == ArmoryFacts.State.UNLOCKED:
		colour = GameTheme.GOOD
	elif r.state == ArmoryFacts.State.NEXT:
		colour = GameTheme.ACCENT
	var words := tr(state_key) if r.number == 0 else tr("ARMORY_ROW_STATE") % [ArmoryFacts.grouped(r.total), tr(state_key)]
	column.add_child(MenuParts.spaced(words, STATE_SIZE, 700, colour, 0.02))
	return pad


## One item: its picture, name and kind.
func _chip(item: Pool.Item) -> Control:
	var chip := PanelContainer.new()
	chip.name = "Item_%s" % item.id
	chip.custom_minimum_size = CHIP_SIZE
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var face := GameTheme.box(CHIP_FILL, GameTheme.LINE, 0, 0)
	face.set_border_width_all(1)
	chip.add_theme_stylebox_override("panel", face)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 0)
	chip.add_child(line)
	var box := CenterContainer.new()
	box.custom_minimum_size = CHIP_PICTURE
	var pic := MenuParts.picture(CHIP_PICTURE_MAX)
	pic.name = "Picture"
	pic.texture = _pictures.texture(item)
	box.add_child(pic)
	line.add_child(box)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var name_label := MenuParts.text(item.display_name, CHIP_NAME_SIZE, 700, GameTheme.TEXT)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_constant_override("line_spacing", -2)
	text.add_child(name_label)
	text.add_child(MenuParts.spaced(ArmoryFacts.kind_label(item), CHIP_KIND_SIZE, 700, GameTheme.MUTED, 0.06))
	var pad := MenuParts.padded(0.0, 0.0, 8.0, 0.0)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_child(text)
	line.add_child(pad)
	return chip
