class_name PauseMenu
extends Control
## The menu Esc opens in play (concept `pause.png`): the match stops (the tree is paused) and the mouse is freed. PAUSED,
## the map, mode and round, then Resume, Settings and Quit match, and the match's seed at the foot. In practice (concept
## `pause-practice.png`, `set_practice`): "Practice · Range", Resume, the Timed challenge's On / Off switch, Loadout (with
## its key, L as bound; the key works here too), Settings and Leave practice, with no seed. Works while the tree is paused.
## The foot (SV5, concept step22 `pause-report.png`): the seed and REPORT A BUG (Report a Bug alone in practice), which
## opens the ReportPanel over the menu, the match still paused; and, once an error has been logged since the match
## started (`errors`), a line saying so under it.

signal resumed
signal left
## Skip to next round was pressed (shown only while you are out and the round plays on).
signal skipped
## Practice's Timed challenge was switched: on or off.
signal challenge_toggled(on: bool)
## Practice's Loadout row, or its key, was pressed.
signal loadout_requested

## The shade over the match, the panel's width and margins, and the sizes of its words (px at 1080p; concept `pause.png`).
const BACKDROP := Color(GameTheme.DEEP, 0.72)
## The panel is as wide as its words and buttons need; these are its least width (px).
const PANEL_WIDTH := 0.0
const PANEL_SIDE := 48
const PANEL_TOP := 44
const PANEL_BOTTOM := 30
const TITLE_SIZE := 46
const TITLE_SPACING := 0.04
const SUBTITLE_SIZE := 18
const SUBTITLE_TOP := 6
const BUTTONS_TOP := 34
const BUTTON_GAP := 12
const BUTTON_PAD_X := 22
const BUTTON_PAD_Y := 17
const BUTTON_SIZE := 22
const SEED_TOP := 28
const SEED_PAD := 18
const SEED_SIZE := 16
## The seed's gap after its word; Report a Bug's chip (type size, padding); the error line (its gap above, type size,
## colours, and its dot's size, gap and drop; concept step22 `pause-report.png`).
const SEED_NUMBER_GAP := 10
const REPORT_SIZE := 14
const REPORT_PAD := Vector2i(12, 6)
const ERROR_TOP := 12
const ERROR_SIZE := 14
const ERROR_INK := Color("ffb366")
const ERROR_DOT := GraphicsNotice.WARN
const ERROR_DOT_SIZE := 8.0
const ERROR_DOT_GAP := 8
const ERROR_DOT_TOP := 5.0
## In practice (concept `pause-practice.png`): a wider panel, the gap above Leave practice and the Timed challenge
## switch's chips (type size, padding, gap; px at 1080p).
const PRACTICE_WIDTH := 0.0
const PRACTICE_LEAVE_GAP := 10
## ... and the gaps above the title, the subtitle and the buttons there (the concept's text sits a little lower).
const PRACTICE_TOP := 46
const PRACTICE_SUBTITLE_TOP := 7
const PRACTICE_BUTTONS_TOP := 35
const SWITCH_SIZE := 15
const SWITCH_PAD := Vector2i(12, 3)
const SWITCH_GAP := 6
## The Loadout row's key chip: type size, padding (px at 1080p).
const KEY_SIZE := 14
const KEY_PAD := Vector2i(7, 2)

## The match's End the round now (returns false when no round is live), handed to the settings' Dev tab.
var end_round: Callable = Callable()
## This run's ErrorLog: the foot says when it has logged an error since it was handed over, as the match started
## (null: none kept).
var errors: ErrorLog = null:
	set(value):
		errors = value
		_errors_before = value.errors_this_run() if value != null else 0
## The bug report's facts as the match stands (PlaySession.report_info): () -> BugReport.ReportInfo. Unset, the report
## has the machine's facts alone.
var report_info: Callable = Callable()

var _resume: Button = null
var _settings_button: Button = null
var _skip: Button = null
var _panel: PanelContainer = null
var _subtitle_lead: Label = null
var _subtitle: Label = null
var _seed: Label = null
var _seed_word: Label = null
var _report_button: Button = null
var _error_line: HBoxContainer = null
var _error_text: Label = null
## Report a Bug's panel, built when asked for and freed once closed.
var _report: ReportPanel = null
## The run's errors before this match.
var _errors_before: int = 0
var _leave: Button = null
var _leave_gap: Control = null
var _top_gap: Control = null
var _subtitle_gap: Control = null
var _buttons_gap: Control = null
## Practice: the Timed challenge's row and its chips, and whether it is on.
var _challenge: Button = null
var _chip_on: PanelContainer = null
var _chip_off: PanelContainer = null
var _challenge_on: bool = false
## Practice's Loadout row and its key chip's words.
var _loadout: Button = null
var _loadout_key: Label = null
var _practice: bool = false
## The settings screen, built the first time it is asked for.
var _screen: SettingsScreen = null


## "Depot · Elimination · Round 3".
static func subtitle(map_name: String, mode_name: String, round_number: int) -> String:
	return TranslationServer.translate("PAUSE_SUBTITLE") % [map_name, mode_name, round_number]


func _ready() -> void:
	name = "PauseMenu"
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = GameTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = BACKDROP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var panel := PanelContainer.new()
	_panel = panel
	panel.name = "Panel"
	panel.add_theme_stylebox_override("panel", GameTheme.box(GameTheme.PANEL, GameTheme.LINE, PANEL_SIDE, 0))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	_top_gap = _gap(PANEL_TOP)
	box.add_child(_top_gap)
	var title := Label.new()
	title.text = tr("PAUSE_TITLE").to_upper()
	title.add_theme_font_override("font", GameTheme.spaced_font(800, TITLE_SPACING, TITLE_SIZE))
	title.add_theme_font_size_override("font_size", TITLE_SIZE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_subtitle_gap = _gap(SUBTITLE_TOP)
	box.add_child(_subtitle_gap)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 0)
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	_subtitle_lead = Label.new()
	_subtitle_lead.add_theme_font_override("font", GameTheme.font(700))
	_subtitle_lead.add_theme_font_size_override("font_size", SUBTITLE_SIZE)
	_subtitle_lead.add_theme_color_override("font_color", GameTheme.TEXT)
	_subtitle_lead.visible = false
	line.add_child(_subtitle_lead)
	_subtitle = Label.new()
	_subtitle.add_theme_font_size_override("font_size", SUBTITLE_SIZE)
	_subtitle.add_theme_color_override("font_color", GameTheme.MUTED)
	line.add_child(_subtitle)
	box.add_child(line)
	_buttons_gap = _gap(BUTTONS_TOP)
	box.add_child(_buttons_gap)
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", BUTTON_GAP)
	box.add_child(buttons)
	_resume = _button(buttons, tr("PAUSE_RESUME"), true)
	_resume.pressed.connect(func() -> void: resumed.emit())
	_challenge = _challenge_row(buttons)
	_challenge.visible = false
	_loadout = _loadout_row(buttons)
	_loadout.visible = false
	_skip = _button(buttons, tr("PAUSE_SKIP_ROUND"), false)
	_skip.pressed.connect(func() -> void: skipped.emit())
	_skip.visible = false
	_settings_button = _button(buttons, tr("PAUSE_SETTINGS"), false)
	_settings_button.pressed.connect(open_settings)
	_leave_gap = _gap(PRACTICE_LEAVE_GAP)
	_leave_gap.visible = false
	buttons.add_child(_leave_gap)
	_leave = _button(buttons, tr("PAUSE_QUIT"), false)
	_leave.pressed.connect(func() -> void: left.emit())
	# the buttons are one width, the widest one's (owner, 2026-10-29)
	ButtonWidth.group([_resume, _challenge, _loadout, _skip, _settings_button, _leave], Control.SIZE_SHRINK_CENTER)
	box.add_child(_gap(SEED_TOP))
	box.add_child(_seed_row_box())
	box.add_child(_gap(PANEL_BOTTOM))
	panel.add_child(box)
	visible = false


## The match this menu is over, shown on it: the map's and mode's names, the round under way and the match's seed.
func set_match(map_name: String, mode_name: String, round_number: int, match_seed: int) -> void:
	_set_practice(false)
	_subtitle.text = subtitle(map_name, mode_name, round_number)
	_seed.text = str(match_seed)


## Practice, on the map `map_name`: "Practice · Range", with " · timed challenge" while the challenge is `on` and
## " · best N" once it has a best (`best` above 0). Shows the Timed challenge switch (unless the map has no room for its
## START plate: `can_challenge` false) and Leave practice, and no seed.
func set_practice(map_name: String, on: bool, best: int, can_challenge: bool = true) -> void:
	_set_practice(true)
	_challenge.visible = can_challenge
	_challenge_on = on
	_subtitle_lead.text = tr("MODE_PRACTICE")
	_subtitle.text = practice_line(map_name, on, best)
	_show_switch()


## The practice line after its lead: " · Range · timed challenge · best 14".
static func practice_line(map_name: String, on: bool, best: int) -> String:
	var line := " · " + map_name
	if on:
		line += TranslationServer.translate("PAUSE_PRACTICE_CHALLENGE")
		if best > 0:
			line += TranslationServer.translate("PAUSE_PRACTICE_BEST") % best
	return line


## Whether the Timed challenge reads On.
func challenge_on() -> bool:
	return _challenge_on


## The Timed challenge row, for tests.
func challenge_button() -> Button:
	return _challenge


func leave_button() -> Button:
	return _leave


## The Loadout row, for tests.
func loadout_button() -> Button:
	return _loadout


## The Loadout row's key as shown (the Loadout action's main key as bound now).
func loadout_key_text() -> String:
	return _loadout_key.text


func is_practice() -> bool:
	return _practice


func _set_practice(on: bool) -> void:
	_practice = on
	_subtitle_lead.visible = on
	_challenge.visible = on
	_loadout.visible = on
	_leave_gap.visible = on
	_leave.text = tr("PAUSE_LEAVE_PRACTICE" if on else "PAUSE_QUIT").to_upper()
	_seed_word.visible = not on
	_seed.visible = not on
	_top_gap.custom_minimum_size.y = PRACTICE_TOP if on else PANEL_TOP
	_subtitle_gap.custom_minimum_size.y = PRACTICE_SUBTITLE_TOP if on else SUBTITLE_TOP
	_buttons_gap.custom_minimum_size.y = PRACTICE_BUTTONS_TOP if on else BUTTONS_TOP
	_panel.custom_minimum_size.x = PRACTICE_WIDTH if on else PANEL_WIDTH
	_panel.reset_size()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	if not on:
		_subtitle_lead.text = ""


## Whether Skip to next round shows: only while you are out and the round plays on.
func set_can_skip(can: bool) -> void:
	_skip.visible = can


func can_skip() -> bool:
	return _skip.visible


func subtitle_text() -> String:
	return _subtitle_lead.text + _subtitle.text


func seed_text() -> String:
	return _seed.text


## "Something went wrong in this match (2 errors). …", for `count` errors.
static func error_line(count: int) -> String:
	if count == 1:
		return TranslationServer.translate("PAUSE_ERRORS_ONE")
	return TranslationServer.translate("PAUSE_ERRORS") % count


## The foot's error line as shown, or "" while it is hidden.
func error_text() -> String:
	return _error_text.text if _error_line.visible else ""


func report_button() -> Button:
	return _report_button


## Report a Bug's panel while it is open, else null.
func report_panel() -> ReportPanel:
	return _report


## Whether Report a Bug's panel is showing.
func report_open() -> bool:
	return _report != null and _report.visible


func _unhandled_input(event: InputEvent) -> void:
	if not visible or settings_open() or report_open():
		return
	if event.is_action_pressed(&"pause") and not event.is_echo():
		get_viewport().set_input_as_handled()
		resumed.emit()
	elif _practice and event.is_action_pressed(&"loadout") and not event.is_echo():
		get_viewport().set_input_as_handled()
		loadout_requested.emit()


func open() -> void:
	visible = true
	# the settings may have rebound it since the menu last showed
	_loadout_key.text = KeyNames.of_action(&"loadout")
	_show_errors()
	_resume.grab_focus()


func close() -> void:
	if _screen != null:
		_screen.close()
	if _report != null:
		_report.close()
	visible = false


## Report a Bug over the menu: the panel on the match's facts as they stand now; Back or Esc closes it alone and gives
## the focus back to Report a Bug.
func open_report() -> void:
	if report_open():
		return
	if _report == null:
		_report = ReportPanel.new()
		_report.closed.connect(_report_closed)
		add_child(_report)
	var info: BugReport.ReportInfo = null
	if report_info.is_valid():
		info = report_info.call()
	else:
		var place := ReportFacts.PLACES[RunRecord.PRACTICE if _practice else RunRecord.MATCH]
		info = ReportFacts.live(null, Settings.shared(), errors, place, "", _report.config,
				ReportScrub.for_this_machine(_report.config))
	_report.open(info)


func _report_closed() -> void:
	_report.queue_free()
	_report = null
	if visible:
		_report_button.grab_focus()


## The error line, shown once an error has been logged since the match started.
func _show_errors() -> void:
	var count := errors.errors_this_run() - _errors_before if errors != null else 0
	_error_line.visible = count > 0
	_error_text.text = error_line(count) if count > 0 else ""


## Shows the settings over the menu, built when asked for and freed once closed; closing them gives the focus back to
## the Settings button.
func open_settings() -> void:
	if _screen == null:
		_screen = SettingsScreen.new()
		_screen.esc_closes = true
		_screen.end_round = end_round
		_screen.closed.connect(_settings_closed)
		add_child(_screen)
	# The menu's buttons sit under the settings: out of the focus ring, so Tab can't reach Resume or Quit unseen (BP3).
	_buttons_focusable(false)
	_screen.open()


func _settings_closed() -> void:
	_screen.queue_free()
	_screen = null
	_buttons_focusable(true)
	# the settings may have rebound it
	_loadout_key.text = KeyNames.of_action(&"loadout")
	_settings_button.grab_focus()


## Whether the menu's own buttons take the keyboard focus (off while the settings show over them).
func _buttons_focusable(on: bool) -> void:
	for b: Button in [_resume, _challenge, _loadout, _skip, _settings_button, _leave, _report_button]:
		if b != null:
			b.focus_mode = Control.FOCUS_ALL if on else Control.FOCUS_NONE


## Whether the settings are showing.
func settings_open() -> bool:
	return _screen != null and _screen.visible


## The foot: a rule, then "Match seed", the seed and Report a Bug at the right; the error line under them.
func _seed_row_box() -> Control:
	var rule := GameTheme.box(Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), 0, 0)
	rule.border_width_top = GameTheme.BORDER
	rule.border_color = GameTheme.LINE
	rule.content_margin_top = SEED_PAD
	var holder := PanelContainer.new()
	holder.add_theme_stylebox_override("panel", rule)
	var foot := VBoxContainer.new()
	foot.add_theme_constant_override("separation", ERROR_TOP)
	holder.add_child(foot)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", SEED_NUMBER_GAP)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_child(row)
	_seed_word = Label.new()
	_seed_word.text = tr("PAUSE_SEED")
	_seed = Label.new()
	for l: Label in [_seed_word, _seed]:
		l.add_theme_font_size_override("font_size", SEED_SIZE)
		l.add_theme_color_override("font_color", GameTheme.MUTED)
	_seed.add_theme_font_override("font", GameTheme.font(700))
	_seed.add_theme_color_override("font_color", GameTheme.TEXT)
	row.add_child(_seed_word)
	row.add_child(_seed)
	_report_button = Button.new()
	_report_button.name = "ReportBug"
	_report_button.text = tr("REPORT_BUG").to_upper()
	_report_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_report_button.add_theme_font_override("font", GameTheme.spaced_font(800, GameTheme.SPACING_HEADING, REPORT_SIZE))
	_report_button.add_theme_font_size_override("font_size", REPORT_SIZE)
	var chip := GameTheme.box(GameTheme.CARD, GameTheme.LINE, REPORT_PAD.x, REPORT_PAD.y)
	GameTheme.dress(_report_button, chip, GameTheme.box(GameTheme.CARD_HI, GameTheme.LINE, REPORT_PAD.x, REPORT_PAD.y),
			chip)
	_report_button.pressed.connect(open_report)
	row.add_child(_report_button)
	foot.add_child(_error_row())
	return holder


## The error line: an orange dot and the words beside it, hidden until this run has logged an error.
func _error_row() -> HBoxContainer:
	_error_line = HBoxContainer.new()
	_error_line.name = "Errors"
	_error_line.add_theme_constant_override("separation", ERROR_DOT_GAP)
	var dot_box := Control.new()
	dot_box.custom_minimum_size = Vector2(ERROR_DOT_SIZE, 0.0)
	dot_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dot := Panel.new()
	var face := GameTheme.box(ERROR_DOT, Color(0.0, 0.0, 0.0, 0.0), 0, 0)
	face.set_corner_radius_all(int(ERROR_DOT_SIZE / 2.0))
	dot.add_theme_stylebox_override("panel", face)
	dot.position = Vector2(0.0, ERROR_DOT_TOP)
	dot.size = Vector2(ERROR_DOT_SIZE, ERROR_DOT_SIZE)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot_box.add_child(dot)
	_error_line.add_child(dot_box)
	_error_text = MenuParts.text("", ERROR_SIZE, 600, ERROR_INK)
	_error_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_error_line.add_child(_error_text)
	_error_line.visible = false
	return _error_line


## The Timed challenge row: its words, and the ON and OFF chips at the right, the lit one in the text colour.
func _challenge_row(parent: Control) -> Button:
	var b := _button(parent, tr("PAUSE_CHALLENGE"), false)
	b.name = "Challenge"
	var chips := HBoxContainer.new()
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chips.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chips.offset_right = -float(BUTTON_PAD_X)
	chips.alignment = BoxContainer.ALIGNMENT_END
	chips.add_theme_constant_override("separation", SWITCH_GAP)
	b.add_child(chips)
	ButtonWidth.overlay(b, chips)
	_chip_on = _chip(chips, tr("RULE_ON").to_upper())
	_chip_off = _chip(chips, tr("RULE_OFF").to_upper())
	b.pressed.connect(_toggle_challenge)
	return b


## The Loadout row: its words and, at the right, its key in a small outlined chip (practice only).
func _loadout_row(parent: Control) -> Button:
	var b := _button(parent, tr("PAUSE_LOADOUT"), false)
	b.name = "Loadout"
	var holder := HBoxContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.offset_right = -float(BUTTON_PAD_X)
	holder.alignment = BoxContainer.ALIGNMENT_END
	b.add_child(holder)
	var chip := MenuParts.key_chip(KeyNames.of_action(&"loadout"), KEY_SIZE, GameTheme.MUTED, KEY_PAD)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.add_child(chip)
	ButtonWidth.overlay(b, holder)
	_loadout_key = chip.get_child(0) as Label
	b.pressed.connect(func() -> void: loadout_requested.emit())
	return b


func _chip(parent: Control, words: String) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var label := MenuParts.spaced(words, SWITCH_SIZE, 800, GameTheme.MUTED, GameTheme.SPACING_MAIN)
	chip.add_child(label)
	parent.add_child(chip)
	return chip


## Lights the chip of the switch's state.
func _show_switch() -> void:
	for pair: Array in [[_chip_on, _challenge_on], [_chip_off, not _challenge_on]]:
		var chip: PanelContainer = pair[0]
		var lit: bool = pair[1]
		var face := GameTheme.box(GameTheme.TEXT if lit else Color(0.0, 0.0, 0.0, 0.0),
				GameTheme.TEXT if lit else GameTheme.LINE, SWITCH_PAD.x, SWITCH_PAD.y)
		chip.add_theme_stylebox_override("panel", face)
		(chip.get_child(0) as Label).add_theme_color_override("font_color", GameTheme.BG if lit else GameTheme.MUTED)


func _toggle_challenge() -> void:
	_challenge_on = not _challenge_on
	_show_switch()
	challenge_toggled.emit(_challenge_on)


## A menu button, its words centred in capitals; `main` is the yellow one.
func _button(parent: Control, text: String, main: bool) -> Button:
	var b := Button.new()
	b.text = text.to_upper()
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_font_override("font", GameTheme.spaced_font(800, GameTheme.SPACING_MAIN, BUTTON_SIZE))
	b.add_theme_font_size_override("font_size", BUTTON_SIZE)
	if main:
		var ink := GameTheme.ACCENT_INK
		var solid := GameTheme.box(GameTheme.ACCENT, GameTheme.ACCENT, BUTTON_PAD_X, BUTTON_PAD_Y)
		GameTheme.dress(b, solid, GameTheme.box(GameTheme.ACCENT.lightened(0.15), GameTheme.ACCENT, BUTTON_PAD_X,
				BUTTON_PAD_Y), solid)
		for colour: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(colour, ink)
		b.add_theme_stylebox_override("focus", GameTheme.focus_box())
	else:
		var plain := GameTheme.box(GameTheme.CARD, GameTheme.LINE, BUTTON_PAD_X, BUTTON_PAD_Y)
		GameTheme.dress(b, plain, GameTheme.box(GameTheme.CARD_HI, GameTheme.LINE, BUTTON_PAD_X, BUTTON_PAD_Y), plain)
	parent.add_child(b)
	return b


func _gap(height: int) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, height)
	return gap
