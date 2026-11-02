class_name ArmoryTrack
extends HBoxContainer
## The Armory's level cards (UI concept B v2 `armory.png`): CARDS levels side by side from the one `first()` names, each
## a glass card with LEVEL n (or KIT) and its state (UNLOCKED in teal; NEXT, edged in teal; else the XP that reaches it),
## then a tile an item: its picture, name and kind, its words in the tooltip; a locked level's tiles dimmed. Every card
## is built; `browse` and `show_from` choose which show. It opens on the player's level.

## The level shown first changed (the page's arrows follow).
signal moved

const CARDS := 4
const GAP := 26
const CARD_PAD := Vector2i(22, 20)
const HEAD_SIZE := 30
const STATE_SIZE := 15
const STATE_SPACING := 0.12
const HEAD_GAP := 16
const TILE_GAP := 12
const TILE_PAD := Vector2i(12, 10)
const TILE_PICTURE := Vector2(220.0, 96.0)
const TILE_PICTURE_SMALL := Vector2(110.0, 52.0)
const TILE_NAME_SIZE := 18
const TILE_KIND_SIZE := 14
const TILE_LINE_GAP := 2
## More items than this on a level: the tiles go two to a row with smaller pictures.
const ONE_COLUMN_MAX := 3
const LOCKED_ALPHA := 0.45
const NEXT_EDGE := 2

var _facts: ArmoryFacts = null
var _pictures: ItemPictures = null
var _rows: Dictionary[int, Control] = {}
var _first: int = 0


func _init(facts: ArmoryFacts, pictures: ItemPictures) -> void:
	name = "ArmoryTrack"
	_facts = facts
	_pictures = pictures
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", GAP)
	for row in _facts.rows:
		var card := _card(row)
		_rows[row.number] = card
		add_child(card)
	var reached := _facts.table.cap() if _facts.levelling_off else _facts.level
	show_from(reached)


## The card of level `number` (0: the starting kit).
func row(number: int) -> Control:
	return _rows.get(number)


## The level shown first.
func first() -> int:
	return _first


## The most `first()` can be (the last CARDS levels show).
func last_first() -> int:
	return maxi(_facts.rows.size() - CARDS, 0)


## Shows CARDS levels from `number`, kept inside the track.
func show_from(number: int) -> void:
	_first = clampi(number, 0, last_first())
	for n: int in _rows:
		_rows[n].visible = n >= _first and n < _first + CARDS
	moved.emit()


## One level along (`step` -1 or 1).
func browse(step: int) -> void:
	show_from(_first + step)


func _card(r: ArmoryFacts.Row) -> Control:
	var next := r.state == ArmoryFacts.State.NEXT
	var locked := r.state == ArmoryFacts.State.LOCKED
	var panel := PanelContainer.new()
	panel.name = "Level%d" % r.number
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0
	var face := GameTheme.panel_box(CARD_PAD.x, CARD_PAD.y)
	if next:
		face.border_color = GameTheme.ACCENT
		face.set_border_width_all(NEXT_EDGE)
	panel.add_theme_stylebox_override("panel", face)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", HEAD_GAP)
	panel.add_child(column)
	column.add_child(_head(r))
	var tiles: Container = null
	if r.items.size() > ONE_COLUMN_MAX:
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", TILE_GAP)
		grid.add_theme_constant_override("v_separation", TILE_GAP)
		tiles = grid
	else:
		var list := VBoxContainer.new()
		list.add_theme_constant_override("separation", TILE_GAP)
		tiles = list
	tiles.name = "Items"
	tiles.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if locked:
		tiles.modulate.a = LOCKED_ALPHA
	column.add_child(tiles)
	var small := r.items.size() > ONE_COLUMN_MAX
	for it in r.items:
		tiles.add_child(_tile(it, small))
	return panel


## "LEVEL 4" and, at the right, "NEXT".
func _head(r: ArmoryFacts.Row) -> Control:
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_PASS
	# that unlocks stay, and that the Dev switch unlocks all, is the heading's tooltip (UI1)
	line.tooltip_text = tr("ARMORY_LEVELS_NOTE")
	var locked := r.state == ArmoryFacts.State.LOCKED
	var title := tr("ARMORY_START") if r.number == 0 else tr("ARMORY_ROW_LEVEL") % r.number
	var head := MenuParts.head_text(title, HEAD_SIZE, 700, GameTheme.MUTED if locked else GameTheme.TEXT, 0.02)
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(head)
	var words := ""
	var colour := GameTheme.DIM
	match r.state:
		ArmoryFacts.State.UNLOCKED:
			words = tr("ARMORY_STATE_UNLOCKED")
			colour = GameTheme.ACCENT
		ArmoryFacts.State.NEXT:
			words = tr("ARMORY_ROW_NEXT") % ArmoryFacts.grouped(r.total)
			colour = GameTheme.TEXT
		_:
			words = tr("ARMORY_ROW_XP") % ArmoryFacts.grouped(r.total)
	var state := MenuParts.head_text(words, STATE_SIZE, 600, colour, STATE_SPACING)
	state.name = "State"
	state.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(state)
	return line


## One item: its picture over its name and kind; its words in the tooltip.
func _tile(item: Pool.Item, small: bool) -> Control:
	var tile := PanelContainer.new()
	tile.name = "Item_%s" % item.id
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tile.add_theme_stylebox_override("panel", GameTheme.box(GameTheme.CARD, GameTheme.LINE, TILE_PAD.x, TILE_PAD.y))
	tile.tooltip_text = ArmoryFacts.blurb(item)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", TILE_LINE_GAP)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(column)
	var pic := MenuParts.picture(TILE_PICTURE_SMALL if small else TILE_PICTURE)
	pic.name = "Picture"
	pic.texture = _pictures.texture(item)
	column.add_child(pic)
	var name_label := MenuParts.text(item.display_name, TILE_NAME_SIZE, 700, GameTheme.TEXT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(name_label)
	var kind := MenuParts.text(ArmoryFacts.capitalised(ArmoryFacts.kind_label(item).to_lower()), TILE_KIND_SIZE, 500, GameTheme.MUTED)
	kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(kind)
	return tile
