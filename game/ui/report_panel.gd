class_name ReportPanel
extends Control
## Report a Bug (SV5, concept step22 `report-bug.png`), from the title and the pause menu: WHAT WENT WRONG?, the note box
## (cut to ReportConfig.note_chars in script, with its count), and beside it the whole report as BugReport writes it,
## read-only and rebuilt as the note changes. REPORT ON GITHUB opens IssueLink's address through `opener` and puts the
## whole report on `clipboard` too (a cut address needs it); COPY REPORT copies it alone; BACK or Esc closes the panel
## only. The facts are gathered once, as the panel opens (ReportFacts), so typing rebuilds only the text. The opener and
## the clipboard are injected: headless, OS.shell_open answers OK with nothing opened and the clipboard is unsupported.

## Hidden again (Back or Esc), so whoever opened it can take the focus back.
signal closed

## The shade over what is under the panel, and the report box's own colours (concept `report-bug.png`).
const SHADE := Color(0.055, 0.054, 0.05, 0.8)
const REPORT_FILL := Color("121210")
const REPORT_INK := Color("c8d0dc")
## The toast's edge and fill: the good colour at these opacities.
const TOAST_EDGE_ALPHA := 0.5
const TOAST_FILL_ALPHA := 0.08
const CHECK := "✓ "
## How much lighter the yellow button is under the mouse.
const HOVER_LIGHTEN := 0.15
## Sizes in px at 1080p: the panel, its padding, its columns and the gaps between its parts.
const PANEL_WIDTH := 1380.0
const TOP_RULE := 6.0
const PAD_X := 36
const PAD_TOP := 30
const PAD_BOTTOM := 28
const LEFT_WIDTH := 560.0
const COLUMN_GAP := 40
const KICK_SIZE := 13
const KICK_SPACING := 0.14
const TITLE_SIZE := 40
const TITLE_SPACING := 0.04
const TITLE_TOP := 6.0
const TITLE_BOTTOM := 12.0
const LEAD_SIZE := 17
const LABEL_TOP := 22.0
const LABEL_SIZE := 14
const LABEL_SPACING := 0.12
const LABEL_GAP := 8.0
const NOTE_HEIGHT := 130.0
const NOTE_SIZE := 17
const NOTE_PAD := Vector2i(14, 12)
const COUNT_SIZE := 13
const COUNT_INSET := Vector2(12.0, 8.0)
const BUTTONS_TOP := 18.0
const BUTTON_GAP := 12
const BUTTON_HEIGHT := 52.0
const BUTTON_PAD_X := 28
const BUTTON_SIZE := 17
const BUTTON_SPACING := 0.08
const TOAST_TOP := 14.0
const TOAST_SIZE := 15
const TOAST_PAD := Vector2i(12, 8)
const FINE_SIZE := 15
const REPORT_LABEL_TOP := 6.0
const REPORT_HEIGHT := 560.0
const REPORT_SIZE := 14
const REPORT_PAD := Vector2i(14, 12)

## The report's numbers (the note's length, the address's limit and cuts).
var config: ReportConfig = ReportConfig.load_default()
## Opens an address in the player's browser: (url: String) -> Error. Tests replace it.
var opener: Callable = Callable(OS, &"shell_open")
## Puts text on the system clipboard: (text: String) -> void. Tests replace it.
var clipboard: Callable = Callable(DisplayServer, &"clipboard_set")

var _info: BugReport.ReportInfo = null
var _note: TextEdit = null
var _count: Label = null
var _report_view: TextEdit = null
var _report: Button = null
var _copy: Button = null
var _back: Button = null
var _toast: PanelContainer = null
var _toast_text: Label = null


func _init() -> void:
	name = "ReportPanel"
	theme = GameTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = SHADE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	panel.add_theme_stylebox_override("panel", GameTheme.box(GameTheme.PANEL, GameTheme.LINE, 0, 0))
	centre.add_child(panel)
	var whole := VBoxContainer.new()
	whole.add_theme_constant_override("separation", 0)
	panel.add_child(whole)
	var rule := ColorRect.new()
	rule.color = GameTheme.ACCENT
	rule.custom_minimum_size = Vector2(0.0, TOP_RULE)
	whole.add_child(rule)
	var pad := MenuParts.padded(PAD_X, PAD_TOP - TOP_RULE, PAD_X, PAD_BOTTOM)
	whole.add_child(pad)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", COLUMN_GAP)
	pad.add_child(columns)
	columns.add_child(_left_column())
	columns.add_child(_right_column())
	_trap_focus()
	visible = false


## Shows the panel over whatever is open, on the report `info` (ReportFacts.live: its note is the box's), the note box
## empty and focused.
func open(info: BugReport.ReportInfo) -> void:
	_info = info
	_note.text = ""
	_toast.visible = false
	_note_changed()
	visible = true
	_note.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## REPORT ON GITHUB: the whole report on the clipboard, then the issue's address (cut to fit when it must) in the
## browser, and the line saying which happened.
func report() -> void:
	if _info == null:
		return
	var link := IssueLink.make(_info, config)
	clipboard.call(BugReport.write(_info))
	var answer: Variant = opener.call(link.url)
	var opened: bool = answer is int and answer == OK
	var key := "REPORT_NOT_OPENED"
	if opened:
		key = "REPORT_OPENED_CUT" if link.cut else "REPORT_OPENED"
	_show_toast(tr(key), opened)


## COPY REPORT: the whole report on the clipboard.
func copy() -> void:
	if _info == null:
		return
	clipboard.call(BugReport.write(_info))
	_show_toast(tr("REPORT_COPIED"), true)


## The note as typed (cut to its length).
func note_text() -> String:
	return _note.text


## Types `text` into the note box, as a player's typing or pasting would (it is cut to its length the same way).
func set_note(text: String) -> void:
	_note.text = text
	_note_changed()
	_caret_to_end()


## The report as shown beside the note.
func report_text() -> String:
	return _report_view.text


## The note box's count, "64 / 500".
func count_text() -> String:
	return _count.text


## The line after Report or Copy, or "" before either.
func status_text() -> String:
	return _toast_text.text if _toast.visible else ""


func note_box() -> TextEdit:
	return _note


func report_button() -> Button:
	return _report


func copy_button() -> Button:
	return _copy


func back_button() -> Button:
	return _back


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		close()


## Keys the focused control left stop here, so none reaches a menu or the match underneath (the debug keys and the
## like excepted, as the settings).
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and visible and not KeyBindings.UNBINDABLE.has(int(key.physical_keycode)):
		get_viewport().set_input_as_handled()


## The note cut to its length (TextEdit has none of its own), its count, and the report written again with it.
## Typing or a paste into a full box loses what went past the length, just before the caret, and the caret stays there;
## the report keeps its scroll.
func _note_changed() -> void:
	var most := config.note_chars
	var over := _note.text.length() - most
	if over > 0:
		var at := _caret_offset()
		if at >= over:
			_note.text = _note.text.left(at - over) + _note.text.substr(at)
			_set_caret_offset(at - over)
		else:
			_note.text = _note.text.left(most)
			_caret_to_end()
	_count.text = tr("REPORT_NOTE_COUNT") % [_note.text.length(), most]
	if _info != null:
		_info.note = _note.text
		var scroll := _report_view.scroll_vertical
		_report_view.text = BugReport.write(_info)
		_report_view.scroll_vertical = scroll


## The caret's place in the note as a count of characters from its start.
func _caret_offset() -> int:
	var at := _note.get_caret_column()
	for line in _note.get_caret_line():
		at += _note.get_line(line).length() + 1
	return at


func _set_caret_offset(at: int) -> void:
	var left := at
	for line in _note.get_line_count():
		var length := _note.get_line(line).length()
		if left <= length:
			_note.set_caret_line(line)
			_note.set_caret_column(left)
			return
		left -= length + 1
	_caret_to_end()


## Keyboard focus stays in the panel: Tab and Shift+Tab go round its parts, and each arrow points at one of them, so
## nothing under the shade (the pause menu's buttons) can take the focus.
func _trap_focus() -> void:
	var ring: Array[Control] = [_note, _report, _copy, _back, _report_view]
	for i in ring.size():
		var c := ring[i]
		c.focus_next = c.get_path_to(ring[(i + 1) % ring.size()])
		c.focus_previous = c.get_path_to(ring[(i - 1 + ring.size()) % ring.size()])
	# left, top, right, bottom: each arrow from each part
	var arrows: Dictionary[Control, Array] = {
		_note: [_note, _note, _report_view, _report],
		_report: [_report, _note, _copy, _report],
		_copy: [_report, _note, _back, _copy],
		_back: [_copy, _note, _report_view, _back],
		_report_view: [_back, _report_view, _report_view, _report_view],
	}
	for c: Control in arrows:
		var to: Array = arrows[c]
		for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			c.set_focus_neighbor(side, c.get_path_to(to[side] as Control))


func _caret_to_end() -> void:
	var last := _note.get_line_count() - 1
	_note.set_caret_line(last)
	_note.set_caret_column(_note.get_line(last).length())


func _show_toast(words: String, good: bool) -> void:
	var ink := GameTheme.GOOD if good else GameTheme.BAD
	_toast.add_theme_stylebox_override("panel", GameTheme.box(Color(ink, TOAST_FILL_ALPHA), Color(ink, TOAST_EDGE_ALPHA),
			TOAST_PAD.x, TOAST_PAD.y))
	_toast_text.add_theme_color_override("font_color", ink)
	_toast_text.text = (CHECK if good else "") + words
	_toast.visible = true


func _left_column() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(LEFT_WIDTH, 0.0)
	box.add_theme_constant_override("separation", 0)
	box.add_child(MenuParts.spaced(tr("REPORT_BUG").to_upper(), KICK_SIZE, 800, GameTheme.ACCENT, KICK_SPACING))
	box.add_child(_gap(TITLE_TOP))
	box.add_child(MenuParts.spaced(tr("REPORT_TITLE").to_upper(), TITLE_SIZE, 800, GameTheme.TEXT, TITLE_SPACING))
	box.add_child(_gap(TITLE_BOTTOM))
	var lead := MenuParts.text(tr("REPORT_LEAD"), LEAD_SIZE, 600, GameTheme.MUTED)
	lead.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(lead)
	box.add_child(_gap(LABEL_TOP))
	box.add_child(_label_row(tr("REPORT_NOTE_LABEL"), tr("REPORT_NOTE_HINT")))
	box.add_child(_gap(LABEL_GAP))
	_note = TextEdit.new()
	_note.name = "Note"
	_note.custom_minimum_size = Vector2(0.0, NOTE_HEIGHT)
	_note.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	# Tab moves round the panel; a note has no use for a tab character
	_note.tab_input_mode = false
	_note.add_theme_font_override("font", GameTheme.font(600))
	_note.add_theme_font_size_override("font_size", NOTE_SIZE)
	_note.add_theme_stylebox_override("normal", GameTheme.box(GameTheme.BG, GameTheme.LINE, NOTE_PAD.x, NOTE_PAD.y))
	var lit := GameTheme.box(GameTheme.BG, GameTheme.ACCENT, NOTE_PAD.x, NOTE_PAD.y)
	lit.draw_center = false
	_note.add_theme_stylebox_override("focus", lit)
	_note.text_changed.connect(_note_changed)
	box.add_child(_note)
	_count = MenuParts.text("", COUNT_SIZE, 700, GameTheme.DIM)
	_count.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_count.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_count.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_count.offset_right = -COUNT_INSET.x
	_count.offset_bottom = -COUNT_INSET.y
	_note.add_child(_count)
	box.add_child(_gap(BUTTONS_TOP))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", BUTTON_GAP)
	box.add_child(row)
	_report = _button(row, tr("REPORT_ON_GITHUB"), GameTheme.ACCENT, true)
	_report.pressed.connect(report)
	_copy = _button(row, tr("REPORT_COPY"), GameTheme.ACCENT, false)
	_copy.pressed.connect(copy)
	_back = _button(row, tr("REPORT_BACK"), GameTheme.LINE, false)
	_back.pressed.connect(close)
	# one width, the widest's (owner, 2026-10-29)
	ButtonWidth.group([_report, _copy, _back])
	box.add_child(_gap(TOAST_TOP))
	_toast = PanelContainer.new()
	_toast.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_toast_text = MenuParts.text("", TOAST_SIZE, 700, GameTheme.GOOD)
	_toast.add_child(_toast_text)
	_toast.visible = false
	box.add_child(_toast)
	box.add_child(_gap(TOAST_TOP))
	box.add_child(_fine_print())
	return box


func _right_column() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 0)
	box.add_child(_gap(REPORT_LABEL_TOP))
	box.add_child(_label_row(tr("REPORT_REPORT_LABEL"), tr("REPORT_REPORT_HINT")))
	box.add_child(_gap(LABEL_GAP))
	_report_view = TextEdit.new()
	_report_view.name = "Report"
	_report_view.editable = false
	_report_view.custom_minimum_size = Vector2(0.0, REPORT_HEIGHT)
	_report_view.add_theme_font_override("font", GameTheme.font(500))
	_report_view.add_theme_font_size_override("font_size", REPORT_SIZE)
	_report_view.add_theme_color_override("font_readonly_color", REPORT_INK)
	_report_view.add_theme_stylebox_override("read_only",
			GameTheme.box(REPORT_FILL, GameTheme.LINE, REPORT_PAD.x, REPORT_PAD.y))
	var lit := GameTheme.box(REPORT_FILL, GameTheme.ACCENT, REPORT_PAD.x, REPORT_PAD.y)
	lit.draw_center = false
	_report_view.add_theme_stylebox_override("focus", lit)
	box.add_child(_report_view)
	return box


## A label in spaced capitals at the left and its hint at the right (the concept's `.lab2`).
func _label_row(words: String, hint: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var head := MenuParts.spaced(words.to_upper(), LABEL_SIZE, 800, GameTheme.MUTED, LABEL_SPACING)
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(head)
	row.add_child(MenuParts.text(hint, LABEL_SIZE, 600, GameTheme.MUTED))
	return row


## The fine print: muted, its [b]bold[/b] words in the text colour.
func _fine_print() -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_override("normal_font", GameTheme.font(600))
	r.add_theme_font_override("bold_font", GameTheme.font(800))
	r.add_theme_font_size_override("normal_font_size", FINE_SIZE)
	r.add_theme_font_size_override("bold_font_size", FINE_SIZE)
	r.add_theme_color_override("default_color", GameTheme.MUTED)
	r.text = tr("REPORT_FINE").replace("[b]", "[b][color=#%s]" % GameTheme.TEXT.to_html(false)) \
			.replace("[/b]", "[/color][/b]")
	return r


## A button in spaced capitals: `solid` filled in `edge` (the yellow one), else outlined in it.
func _button(parent: Control, words: String, edge: Color, solid: bool) -> Button:
	var b := Button.new()
	b.text = words.to_upper()
	b.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	b.add_theme_font_override("font", GameTheme.spaced_font(800, BUTTON_SPACING, BUTTON_SIZE))
	b.add_theme_font_size_override("font_size", BUTTON_SIZE)
	var fill := edge if solid else GameTheme.CARD
	var plain := GameTheme.box(fill, edge, BUTTON_PAD_X, 0)
	GameTheme.dress(b, plain, GameTheme.box(fill.lightened(HOVER_LIGHTEN) if solid else GameTheme.CARD_HI, edge,
			BUTTON_PAD_X, 0), plain)
	if solid:
		for colour: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(colour, GameTheme.ACCENT_INK)
	parent.add_child(b)
	return b


func _gap(height: float) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, height)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap
