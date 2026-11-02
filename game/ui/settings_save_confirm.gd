class_name SettingsSaveConfirm
extends Control
## The Save file tab's question before a restore, an Undo or a delete (concepts `save-restore-confirm.png` and
## `save-delete-confirm.png`): over a shade, a panel with a coloured rule on top, a kicker, the question and what
## happens, then either Now against the save that comes back, row by row (a figure lower than now in red), or the tiles
## that go; a line after, what is kept, and the yes button beside CANCEL. CANCEL or Esc closes it; yes sends `confirmed`
## (the page does the rest). Built once, hidden, and filled each time it asks; the focus stays on its two buttons.

## Yes was pressed.
signal confirmed
## It closed (CANCEL, Esc, yes, or the tab left).
signal closed

## The look: a calm question (restore, Undo: yellow) or a red one (delete).
enum Tone { CALM, DANGER }


## What to ask: words already translated (`lead` and `after` may hold BBCode bold). With `tiles` the rows are tiles:
## `labels` over `now`; else a table of `labels` with Now against `then` under `then_head`, a `then` cell in red where
## `lower` says it is less than now.
class Ask:
	extends RefCounted
	var tone: Tone = Tone.CALM
	var kicker: String = ""
	var title: String = ""
	var lead: String = ""
	var tiles: bool = false
	var then_head: String = ""
	var labels: PackedStringArray = PackedStringArray()
	var now: PackedStringArray = PackedStringArray()
	var then: PackedStringArray = PackedStringArray()
	var lower: Array[bool] = []
	var after: String = ""
	var keeps: String = ""
	var yes: String = ""


## The shade over the screen (the page colour, this opaque), the panel's width, its inner margins and the rule on top
## (px at 1080p; the concepts' `.modal`).
const SHADE_ALPHA := 0.72
const WIDTH := 880.0
const PAD := Vector2i(36, 30)
const RULE := 5
## The words' sizes (px): kicker, question, lead and after lines, the table's head and rows, the tiles' labels and
## figures, the buttons.
const KICKER_SIZE := 15
const TITLE_SIZE := 40
const LEAD_SIZE := 19
const AFTER_SIZE := 16
const HEAD_SIZE := 14
const ROW_SIZE := 19
const TILE_LABEL_SIZE := 13
const TILE_VALUE_SIZE := 24
const BUTTON_SIZE := 18
## The parts' gaps, the table's first two columns' widths, a row's and a tile's inner margins and the buttons' margins
## (px).
const GAP := 14
const ROW_GAP := 0
const LABEL_WIDTH := 220.0
const NOW_WIDTH := 243.0
const ROW_PAD := Vector2i(14, 7)
const TILE_GAP := 10
const TILE_PAD := Vector2i(14, 10)
const BUTTON_PAD := Vector2i(26, 12)

var _rule: ColorRect = null
var _kicker: Label = null
var _title: Label = null
var _lead: RichTextLabel = null
var _table: VBoxContainer = null
var _now_head: Label = null
var _then_head: Label = null
## The table's lines and each one's cells [label, now, then].
var _lines: Array[Control] = []
var _rows: Array[Array] = []
var _tiles: HBoxContainer = null
## The tiles and each one's [label, figure].
var _tile_boxes: Array[Control] = []
var _tile_parts: Array[Array] = []
var _after: RichTextLabel = null
var _keeps: Label = null
var _yes: Button = null
var _cancel: Button = null


func _init() -> void:
	name = "SettingsSaveConfirm"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(GameTheme.BG, SHADE_ALPHA)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	# the rule on top in the tone's colour, then the panel lined on its other three sides
	var frame := VBoxContainer.new()
	frame.custom_minimum_size.x = WIDTH
	frame.add_theme_constant_override("separation", 0)
	centre.add_child(frame)
	_rule = ColorRect.new()
	_rule.custom_minimum_size.y = RULE
	frame.add_child(_rule)
	var panel := PanelContainer.new()
	var box := GameTheme.box(GameTheme.PANEL, GameTheme.LINE, PAD.x, PAD.y)
	box.border_width_top = 0
	panel.add_theme_stylebox_override("panel", box)
	frame.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", GAP)
	panel.add_child(col)
	_kicker = MenuParts.spaced("", KICKER_SIZE, 800, GameTheme.ACCENT, GameTheme.SPACING_HEADING)
	col.add_child(_kicker)
	_title = MenuParts.spaced("", TITLE_SIZE, 800, GameTheme.TEXT, GameTheme.SPACING_TAB)
	col.add_child(_title)
	_lead = _words(LEAD_SIZE)
	col.add_child(_lead)
	_table = VBoxContainer.new()
	_table.add_theme_constant_override("separation", ROW_GAP)
	col.add_child(_table)
	_tiles = HBoxContainer.new()
	_tiles.add_theme_constant_override("separation", TILE_GAP)
	col.add_child(_tiles)
	_after = _words(AFTER_SIZE)
	col.add_child(_after)
	_keeps = MenuParts.text("", AFTER_SIZE, 600, GameTheme.TEXT)
	_keeps.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_keeps)
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", GAP)
	col.add_child(acts)
	_yes = Button.new()
	_yes.name = "Yes"
	_yes.pressed.connect(func() -> void: confirmed.emit())
	acts.add_child(_yes)
	_cancel = Button.new()
	_cancel.name = "Cancel"
	_cancel.text = tr("SAVE_CANCEL").to_upper()
	_cancel.pressed.connect(close)
	SettingsSavePage.paint(_cancel, Color(0.0, 0.0, 0.0, 0.0), GameTheme.ACCENT, GameTheme.TEXT, BUTTON_SIZE, BUTTON_PAD)
	acts.add_child(_cancel)
	# the two are one width, so the long yes words don't leave CANCEL a small box beside a big one (FB1)
	ButtonWidth.group([_yes, _cancel])


func _ready() -> void:
	# Esc is listened for only while it shows (Godot turns _input on at ready)
	set_process_input(visible)
	# the focus goes between the two buttons only, never to the tab under the shade
	for b: Button in [_yes, _cancel]:
		var other := _cancel if b == _yes else _yes
		for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			b.set_focus_neighbor(side, b.get_path_to(other))
		b.focus_next = b.get_path_to(other)
		b.focus_previous = b.get_path_to(other)


## Fills the question from `a` and shows it, the focus on CANCEL.
func ask(a: Ask) -> void:
	var edge := GameTheme.BAD if a.tone == Tone.DANGER else GameTheme.ACCENT
	_rule.color = edge
	_kicker.text = a.kicker.to_upper()
	_kicker.add_theme_color_override("font_color", edge)
	_title.text = a.title.to_upper()
	_lead.text = a.lead
	_table.visible = not a.tiles
	_tiles.visible = a.tiles
	if a.tiles:
		_fill_tiles(a)
	else:
		_fill_table(a)
	_after.text = a.after
	_after.visible = a.after != ""
	_keeps.text = a.keeps
	_keeps.visible = a.keeps != ""
	_yes.text = a.yes.to_upper()
	SettingsSavePage.paint(_yes, edge, edge, GameTheme.ACCENT_INK, BUTTON_SIZE, BUTTON_PAD)
	visible = true
	set_process_input(true)
	_cancel.grab_focus()


## Hides it, sending `closed` if it was showing.
func close() -> void:
	if not visible:
		return
	visible = false
	set_process_input(false)
	closed.emit()


func _input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed(&"ui_cancel") and not event.is_echo():
		close()
		get_viewport().set_input_as_handled()


## The question's words as shown, for tests: kicker, title, lead, every cell or tile, after, keeps and the buttons.
func words() -> String:
	var out := PackedStringArray([_kicker.text, _title.text, _lead.get_parsed_text()])
	if _table.visible:
		out.append_array([_now_head.text, _then_head.text])
		for i in _rows.size():
			if _lines[i].visible:
				for cell: Label in _rows[i]:
					out.append(cell.text)
	else:
		for i in _tile_parts.size():
			if _tile_boxes[i].visible:
				for part: Label in _tile_parts[i]:
					out.append(part.text)
	out.append_array([_after.get_parsed_text(), _keeps.text, _yes.text, _cancel.text])
	return " ".join(out)


## The yes button and CANCEL, for tests.
func yes_button() -> Button:
	return _yes


func cancel_button() -> Button:
	return _cancel


## The `then` cells' colours, top to bottom (tests: red where lower).
func then_colours() -> Array[Color]:
	var out: Array[Color] = []
	for row: Array in _rows:
		out.append((row[2] as Label).get_theme_color("font_color"))
	return out


func _fill_table(a: Ask) -> void:
	if _then_head == null:
		_table.add_child(_head_row())
	_then_head.text = a.then_head.to_upper()
	while _rows.size() < a.labels.size():
		_table.add_child(_row())
	for i in _rows.size():
		var cells: Array = _rows[i]
		_lines[i].visible = i < a.labels.size()
		if not _lines[i].visible:
			continue
		(cells[0] as Label).text = a.labels[i]
		(cells[1] as Label).text = a.now[i]
		(cells[2] as Label).text = a.then[i]
		var red := i < a.lower.size() and a.lower[i]
		(cells[2] as Label).add_theme_color_override("font_color", GameTheme.BAD if red else GameTheme.TEXT)


func _fill_tiles(a: Ask) -> void:
	while _tile_parts.size() < a.labels.size():
		_tiles.add_child(_tile())
	for i in _tile_parts.size():
		var parts: Array = _tile_parts[i]
		_tile_boxes[i].visible = i < a.labels.size()
		if _tile_boxes[i].visible:
			(parts[0] as Label).text = a.labels[i].to_upper()
			(parts[1] as Label).text = a.now[i]


## The table's head: an empty cell, NOW and the other column's name (in yellow), over a rule.
func _head_row() -> Control:
	var line := _ruled(GameTheme.LINE)
	var row := line.get_child(0) as HBoxContainer
	row.add_child(_cell("", LABEL_WIDTH, HEAD_SIZE, GameTheme.MUTED, true))
	_now_head = _cell(tr("SAVE_NOW").to_upper(), NOW_WIDTH, HEAD_SIZE, GameTheme.MUTED, true)
	row.add_child(_now_head)
	_then_head = _cell("", 0.0, HEAD_SIZE, GameTheme.ACCENT, true)
	row.add_child(_then_head)
	return line


func _row() -> Control:
	var line := _ruled(GameTheme.CARD)
	var row := line.get_child(0) as HBoxContainer
	var cells: Array[Label] = [_cell("", LABEL_WIDTH, ROW_SIZE, GameTheme.MUTED.lightened(0.3), false),
			_cell("", NOW_WIDTH, ROW_SIZE, GameTheme.TEXT, false), _cell("", 0.0, ROW_SIZE, GameTheme.TEXT, false)]
	for c: Label in cells:
		row.add_child(c)
	_lines.append(line)
	_rows.append(cells)
	return line


## A table line: a row of cells over a rule in `rule`.
func _ruled(rule: Color) -> PanelContainer:
	var line := PanelContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := GameTheme.box(Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), ROW_PAD.x, ROW_PAD.y)
	box.border_width_bottom = GameTheme.BORDER
	box.border_color = rule
	line.add_theme_stylebox_override("panel", box)
	line.add_child(HBoxContainer.new())
	return line


func _cell(words: String, width: float, size: int, colour: Color, spaced: bool) -> Label:
	var cell := MenuParts.spaced(words, size, 800, colour, GameTheme.SPACING_HEADING) if spaced \
			else MenuParts.text(words, size, 600, colour)
	cell.custom_minimum_size.x = width
	if width == 0.0:
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return cell


## A tile that goes: its label over its figure, in a lined box.
func _tile() -> Control:
	var tile := PanelContainer.new()
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.add_theme_stylebox_override("panel", GameTheme.box(GameTheme.CARD, GameTheme.LINE, TILE_PAD.x, TILE_PAD.y))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	tile.add_child(col)
	var label := MenuParts.spaced("", TILE_LABEL_SIZE, 800, GameTheme.MUTED.lightened(0.3), GameTheme.SPACING_HEADING)
	var figure := MenuParts.text("", TILE_VALUE_SIZE, 800, GameTheme.TEXT)
	col.add_child(label)
	col.add_child(figure)
	_tile_boxes.append(tile)
	_tile_parts.append([label, figure])
	return tile


func _words(size: int) -> RichTextLabel:
	var note := RichTextLabel.new()
	note.bbcode_enabled = true
	note.fit_content = true
	note.scroll_active = false
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.add_theme_font_override("normal_font", GameTheme.font(600))
	note.add_theme_font_override("bold_font", GameTheme.font(800))
	note.add_theme_font_size_override("normal_font_size", size)
	note.add_theme_font_size_override("bold_font_size", size)
	note.add_theme_color_override("default_color", GameTheme.MUTED.lightened(0.3))
	return note
