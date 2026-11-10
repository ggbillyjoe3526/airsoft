class_name NavRail
extends PanelContainer
## The rail down the left of every menu page (UI concept B, owner 2026-11-02; docs/records/UR1.md): words only, each
## centred: the AIRSOFT wordmark, the tabs MATCH, LOADOUT, ARMORY and SETTINGS, then at the foot the player's level with
## a thin bar of the XP into it (`set_level`; greyed while levelling is off, owner 2026-11-10: it is never hidden) and
## QUIT. The current tab is lit with a
## card and an accent rule on its left edge. A tab press is sent as `tab_pressed`; the page decides what to show and calls
## `set_current`. QUIT is sent as `quit_pressed` (the game asks QUIT GAME?). From practice (`set_practice`) the rail
## shows only the LOADOUT tab and, under the wordmark, the accent BACK TO PRACTICE button with the Loadout's key; it is
## sent as `practice_pressed`, and QUIT is hidden (the range has its own way out). The four tabs are one width.

signal tab_pressed(tab: Tab)
## The BACK TO PRACTICE button was pressed.
signal practice_pressed
## QUIT was pressed.
signal quit_pressed

enum Tab { MATCH, LOADOUT, ARMORY, SETTINGS }

## The rail's width and its padding (top and foot, px at 1080p).
const WIDTH := 136
const PAD_Y := 26
## The wordmark's size and spacing, and the room under it.
const MARK_SIZE := 25
const MARK_SPACING := 0.1
const MARK_AFTER := 36
## A tab: its words' size and spacing, its button's size, the gap between tabs, and the lit tab's rule.
const TAB_SIZE := 22
const TAB_SPACING := 0.08
const TAB_BUTTON := Vector2(116.0, 62.0)
const TAB_GAP := 6
const RULE_WIDTH := 4
const RULE_INSET := 16
## The level's words, its bar (size) and the gap before QUIT.
const LEVEL_SIZE := 20
const LEVEL_SPACING := 0.08
const LEVEL_BAR := Vector2(76.0, 5.0)
const LEVEL_GAP := 7
const QUIT_SIZE := 19
## BACK TO PRACTICE: its words' size, its padding, the key's size and padding, and the room after it.
const BACK_SIZE := 17
const BACK_PAD := Vector2i(8, 10)
const BACK_KEY_SIZE := 13
const BACK_KEY_PAD := Vector2i(6, 1)
const BACK_GAP := 6
const BACK_AFTER := 18
## The rail's own fill: a darker glass than the panels, so it reads as the frame.
const FILL := Color(GameTheme.DEEP, 0.8)
const TAB_KEYS: Dictionary[Tab, String] = {
	Tab.MATCH: "MENU_TAB_MATCH",
	Tab.LOADOUT: "MENU_TAB_LOADOUT",
	Tab.ARMORY: "MENU_TAB_ARMORY",
	Tab.SETTINGS: "MENU_TAB_SETTINGS",
}

var _tabs: Dictionary[Tab, Button] = {}
var _rules: Dictionary[Tab, ColorRect] = {}
var _back: Button = null
var _back_key: Label = null
var _back_after: Control = null
var _quit: Button = null
var _practice: bool = false
var _current: Tab = Tab.MATCH
var _level_box: VBoxContainer = null
var _level: Label = null
var _level_fill: ColorRect = null
var _levelling_off: bool = false


func _init() -> void:
	name = "NavRail"
	custom_minimum_size = Vector2(WIDTH, 0.0)
	var face := GameTheme.box(FILL, Color(0.0, 0.0, 0.0, 0.0), 0, PAD_Y)
	face.set_corner_radius_all(0)
	face.border_width_right = 1
	face.border_color = GameTheme.LINE
	add_theme_stylebox_override("panel", face)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_BEGIN
	column.add_theme_constant_override("separation", TAB_GAP)
	add_child(column)
	var mark := MenuParts.head_text(tr("BOOT_TITLE"), MARK_SIZE, 700, GameTheme.TEXT, MARK_SPACING)
	mark.name = "Wordmark"
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(mark)
	column.add_child(_gap(MARK_AFTER - TAB_GAP))
	_back = _build_back()
	column.add_child(_back)
	_back_after = _gap(BACK_AFTER)
	_back_after.visible = false
	column.add_child(_back_after)
	for tab: Tab in TAB_KEYS:
		column.add_child(_build_tab(tab))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	_level_box = _build_level()
	column.add_child(_level_box)
	_quit = _flat_button(tr("MENU_QUIT"), QUIT_SIZE, GameTheme.DIM)
	_quit.name = "Quit"
	_quit.pressed.connect(func() -> void: quit_pressed.emit())
	column.add_child(_quit)
	set_current(Tab.MATCH)


## From practice: only the LOADOUT tab and BACK TO PRACTICE (with the Loadout's key as bound now), no QUIT; off, the
## whole rail.
func set_practice(on: bool) -> void:
	_practice = on
	for tab: Tab in _tabs:
		_tabs[tab].visible = not on or tab == Tab.LOADOUT
	_back.visible = on
	_back_after.visible = on
	_quit.visible = not on
	_back_key.text = KeyNames.of_action(&"loadout")


func is_practice() -> bool:
	return _practice


## The BACK TO PRACTICE button, for tests.
func back_button() -> Button:
	return _back


func back_key_text() -> String:
	return _back_key.text


## The QUIT button, for tests.
func quit_button() -> Button:
	return _quit


## Shows the player's level and how far into it they are (0 to 1). With `levelling_off` (Settings › Dev › Disable
## levelling) it still shows the level kept for when it comes back, greyed, and its tooltip says why (owner,
## 2026-11-10: the chip was hidden then, and read as missing).
func set_level(level: int, into: float = 0.0, levelling_off: bool = false) -> void:
	_levelling_off = levelling_off
	_level.text = tr("MENU_LEVEL_SHORT") % maxi(0, level)
	_level_fill.custom_minimum_size.x = LEVEL_BAR.x * clampf(into, 0.0, 1.0)
	_level.add_theme_color_override("font_color", GameTheme.DIM if levelling_off else GameTheme.TEXT)
	_level_fill.color = GameTheme.DIM if levelling_off else GameTheme.ACCENT
	_level_box.tooltip_text = tr("MENU_LEVEL_OFF_TIP") if levelling_off else ""


func level_text() -> String:
	return _level.text


## Whether the level shows greyed, levelling being off.
func level_greyed() -> bool:
	return _levelling_off


## The tab's button.
func tab_button(tab: Tab) -> Button:
	return _tabs[tab]


func current() -> Tab:
	return _current


## Lights `tab`; the others go out.
func set_current(tab: Tab) -> void:
	_current = tab
	for t: Tab in _tabs:
		_style_tab(t)


func _build_tab(tab: Tab) -> Control:
	var button := _flat_button(tr(TAB_KEYS[tab]), TAB_SIZE, GameTheme.MUTED)
	button.custom_minimum_size = TAB_BUTTON
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(func() -> void: tab_pressed.emit(tab))
	_tabs[tab] = button
	# the lit tab's rule, on the lit card's left edge and centred on its height (offsets only: setting `position` on a
	# rule anchored top to bottom before the button had a size pushed it RULE_INSET past the card's foot)
	var rule := ColorRect.new()
	rule.name = "Rule"
	rule.color = GameTheme.ACCENT
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.anchor_top = 0.0
	rule.anchor_bottom = 1.0
	rule.offset_left = 0.0
	rule.offset_right = RULE_WIDTH
	rule.offset_top = RULE_INSET
	rule.offset_bottom = -RULE_INSET
	button.add_child(rule)
	_rules[tab] = rule
	return button


func _style_tab(tab: Tab) -> void:
	var b := _tabs[tab]
	var lit := tab == _current
	var face := GameTheme.box(GameTheme.CARD_HI if lit else Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), 0, 0)
	var hover := GameTheme.box(GameTheme.CARD_HI if lit else GameTheme.CARD, Color(0.0, 0.0, 0.0, 0.0), 0, 0)
	GameTheme.dress(b, face, hover, face)
	var colour := GameTheme.TEXT if lit else GameTheme.MUTED
	for c: String in ["font_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, colour)
	b.add_theme_color_override("font_hover_color", GameTheme.TEXT)
	_rules[tab].visible = lit


## A button of centred words in Barlow Condensed capitals with no box (a faint card under the pointer).
func _flat_button(words: String, size: int, colour: Color) -> Button:
	var b := Button.new()
	b.text = words.to_upper()
	b.focus_mode = Control.FOCUS_ALL
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_font_override("font", GameTheme.heading_font(600, TAB_SPACING, size))
	b.add_theme_font_size_override("font_size", size)
	var none := GameTheme.box(Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), 0, 0)
	GameTheme.dress(b, none, GameTheme.box(GameTheme.CARD, Color(0.0, 0.0, 0.0, 0.0), 0, 0), none)
	b.add_theme_stylebox_override("focus", GameTheme.focus_box())
	for c: String in ["font_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, colour)
	b.add_theme_color_override("font_hover_color", GameTheme.TEXT)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


## BACK TO PRACTICE: an accent button with its words over the Loadout's key cap, both centred.
func _build_back() -> Button:
	var b := Button.new()
	b.name = "BackToPractice"
	b.theme_type_variation = GameTheme.MAIN_BUTTON
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(TAB_BUTTON.x, 0.0)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var pad := MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["margin_left", "margin_right"]:
		pad.add_theme_constant_override(side, BACK_PAD.x)
	for side: String in ["margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(side, BACK_PAD.y)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", BACK_GAP)
	var words := MenuParts.head_text(tr("MENU_BACK_TO_PRACTICE"), BACK_SIZE, 700, GameTheme.ACCENT_INK, TAB_SPACING)
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.autowrap_mode = TextServer.AUTOWRAP_WORD
	column.add_child(words)
	var cap := MenuParts.key_chip(KeyNames.of_action(&"loadout"), BACK_KEY_SIZE, GameTheme.ACCENT_INK, BACK_KEY_PAD)
	cap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back_key = cap.get_child(0) as Label
	column.add_child(cap)
	pad.add_child(column)
	b.add_child(pad)
	# the button is as tall as its words (wrapped as they are laid out) and key: a Button doesn't size to its children
	pad.minimum_size_changed.connect(_fit_back.bind(b, pad))
	_fit_back.call_deferred(b, pad)
	b.pressed.connect(func() -> void: practice_pressed.emit())
	b.visible = false
	return b


func _fit_back(b: Button, pad: Control) -> void:
	if is_instance_valid(b) and is_instance_valid(pad):
		b.custom_minimum_size.y = pad.get_combined_minimum_size().y


## The level: "LVL 3" over a thin bar of the XP into it.
func _build_level() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "Level"
	# the pointer stops on it for the tooltip while levelling is off
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", LEVEL_GAP)
	_level = MenuParts.text("", LEVEL_SIZE, 700, GameTheme.TEXT)
	_level.add_theme_font_override("font", GameTheme.spaced_font(700, LEVEL_SPACING, LEVEL_SIZE))
	_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_level)
	var track := ColorRect.new()
	track.color = GameTheme.CARD_HI
	track.custom_minimum_size = LEVEL_BAR
	track.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level_fill = ColorRect.new()
	_level_fill.color = GameTheme.ACCENT
	_level_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level_fill.anchor_bottom = 1.0
	track.add_child(_level_fill)
	box.add_child(track)
	box.add_child(_gap(LEVEL_GAP))
	return box


func _gap(height: int) -> Control:
	var g := Control.new()
	g.custom_minimum_size = Vector2(0.0, height)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g
