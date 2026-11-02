class_name GameTheme
## The game's one look for menus and the HUD (docs/ART.md): Inter in four weights for every number and body line, with
## the "marks" faces as the fallback for the arrows and ticks the main faces lack, and Barlow Condensed for the menus'
## headings, tabs, rail and main buttons in words (assets/fonts/; never a number: the owner finds Barlow's figures hard
## to read, 2026-10-07). The palette is UI concept B's (owner, 2026-11-02; docs/records/UR1.md): frosted glass panels
## over the blurred field (MenuBackdrop), white words and one teal accent for the main button and the selection, never
## a team (the team colours are the HUD's own).

const FONT_DIR := "res://assets/fonts/"
## Sizes (px at 1080p; the window scales canvas items).
const BODY_SIZE := 22
const SMALL_SIZE := 17
const LARGE_SIZE := 40
const COUNT_SIZE := 64
const HUGE_SIZE := 88
const TAB_SIZE := 20
## A section heading: one size on every menu (UI1); Barlow Condensed reads small, so a step up from Inter's 16.
const HEADING_SIZE := 18
const MAIN_BUTTON_SIZE := 32

## The palette (concept B, b2.html): the night ink under everything, the glass panel, a card and a lit card on it,
## the hairline, and white words at three strengths; the teal accent and the ink on it.
const BG := Color("0b0e15")
const PANEL := Color(0.063, 0.071, 0.102, 0.74)
const CARD := Color(1.0, 1.0, 1.0, 0.06)
const CARD_HI := Color(1.0, 1.0, 1.0, 0.12)
const LINE := Color(1.0, 1.0, 1.0, 0.12)
const TEXT := Color("ffffff")
const MUTED := Color(1.0, 1.0, 1.0, 0.62)
const DIM := Color(1.0, 1.0, 1.0, 0.36)
const ACCENT := Color("25d0b8")
const ACCENT_INK := Color("05201c")
## Signal yellow, for warnings and the flags only (a low magazine, THEIR FLAG IS GOING UP!, a flag's marker), never as a
## theme colour (UR1).
const WARN := Color("ffd23f")
## Words on WARN (a flag's letter).
const WARN_INK := Color("1a1608")
## Better and worse (the Loadout's Performance sheet).
const GOOD := Color("5fd08a")
const BAD := Color("ff7a6b")

## Letter spacing in em (the concept's `letter-spacing`).
const SPACING_HEADING := 0.08
## A section heading's capitals in Barlow Condensed (concept B's `.cap`: 0.12 em).
const SPACING_HEADING_CAPS := 0.12
const SPACING_TAB := 0.06
const SPACING_MAIN := 0.06
const BORDER := 2
const FOCUS_BORDER := 2
## Every box's corner radius, and a panel's (px at 1080p).
const RADIUS := 8
## Settings' tab pills: their padding, the gap between them and the gap under them over the panel.
const TAB_PAD := Vector2i(18, 8)
const TAB_SEPARATION := 8
const TAB_GAP := 14
const PANEL_RADIUS := 14
const BUTTON_MARGIN_X := 18
const BUTTON_MARGIN_Y := 8
const MAIN_MARGIN_X := 56
const MAIN_MARGIN_Y := 18
const SLIDER_HEIGHT := 6
const SLIDER_GRABBER := 18
const SCROLL_WIDTH := 10
## The main button's variation of Button (PLAY, CUSTOMISE: a rounded teal plate).
const MAIN_BUTTON := &"MainButton"
## The quiet text button's variation (a plain link: Licences, Quit).
const LINK_BUTTON := &"QuietLink"
## The same with a rule under it (Licences).
const LINK_UNDERLINED := &"QuietLinkRuled"
const UNDERLINE_GAP := 4
## The main button's corners and how much lighter it is under the pointer.
const MAIN_RADIUS := 12
const MAIN_HOVER_LIGHTEN := 0.15
## Barlow Condensed's weights in the game.
const HEAD_WEIGHT_MIN := 500
const HEAD_WEIGHT_MAX := 700
## The menus' one compact scale (UI1): every choice, switch, field and small button is CONTROL_HEIGHT tall, its words
## CONTROL_SIZE capitals with CONTROL_PAD_X each side; a row's name is LABEL_SIZE capitals, a section's heading
## SECTION_SIZE, a help line NOTE_SIZE (px at 1080p).
const CONTROL_HEIGHT := 34
const CONTROL_SIZE := 14
const CONTROL_PAD_X := 14
const LABEL_SIZE := 16
const SECTION_SIZE := HEADING_SIZE
const NOTE_SIZE := 14
## A tooltip wraps at this width (px at 1080p; TooltipWrap): about sixty characters of body text, and room to sit
## beside the pointer on a 1080p screen.
const TOOLTIP_WIDTH := 640.0
const SPACING_LABEL := 0.04
const SPACING_SECTION := SPACING_HEADING
## The Button states a box is drawn in (focus is drawn over one of them).
const BUTTON_STATES: Array[String] = ["normal", "hover", "pressed", "hover_pressed", "disabled"]

static var _theme: Theme = null
static var _fonts: Dictionary[int, Font] = {}
static var _spaced: Dictionary[int, FontVariation] = {}
static var _heads: Dictionary[int, Font] = {}
static var _spaced_heads: Dictionary[int, FontVariation] = {}
static var _knob: Texture2D = null


## Inter at `weight` (500, 600, 700 or 800), with its marks face as the fallback.
static func font(weight: int) -> Font:
	if _fonts.has(weight):
		return _fonts[weight]
	var main := load("%sInter-%d.woff2" % [FONT_DIR, weight]) as FontFile
	var marks := load("%sInter-marks-%d.woff2" % [FONT_DIR, weight]) as FontFile
	var f: Font = ThemeDB.fallback_font
	if main != null:
		if marks != null:
			main.fallbacks = [marks]
		f = main
	_fonts[weight] = f
	return f


## Inter at `weight` with `em_spacing` (of a `size` px font) added between letters, as the concept's capitals.
static func spaced_font(weight: int, em_spacing: float, size: int) -> Font:
	var key := weight * 100000 + roundi(em_spacing * 1000.0) * 1000 + size
	if _spaced.has(key):
		return _spaced[key]
	var v := FontVariation.new()
	v.base_font = font(weight)
	v.spacing_glyph = roundi(em_spacing * size)
	_spaced[key] = v
	return v


## Barlow Condensed at `weight` (500, 600 or 700; a heavier weight takes 700), with Inter at that weight as the
## fallback; for words only, never a number.
static func heading_face(weight: int) -> Font:
	var w := clampi(weight, HEAD_WEIGHT_MIN, HEAD_WEIGHT_MAX)
	if _heads.has(w):
		return _heads[w]
	var main := load("%sBarlowCondensed-%d.woff2" % [FONT_DIR, w]) as FontFile
	var f: Font = font(weight)
	if main != null:
		main.fallbacks = [font(weight)]
		f = main
	_heads[w] = f
	return f


## Barlow Condensed at `weight` with `em_spacing` (of a `size` px font) between letters: a heading's capitals.
static func heading_font(weight: int, em_spacing: float, size: int) -> Font:
	var key := weight * 100000 + roundi(em_spacing * 1000.0) * 1000 + size
	if _spaced_heads.has(key):
		return _spaced_heads[key]
	var v := FontVariation.new()
	v.base_font = heading_face(weight)
	v.spacing_glyph = roundi(em_spacing * size)
	_spaced_heads[key] = v
	return v


## A box in `fill` with a `BORDER` px `edge` (none when `edge.a` is 0) and the given inner margins.
static func box(fill: Color, edge: Color = Color(0.0, 0.0, 0.0, 0.0), margin_x: int = BUTTON_MARGIN_X,
		margin_y: int = BUTTON_MARGIN_Y) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.set_corner_radius_all(RADIUS)
	s.anti_aliasing = true
	if edge.a > 0.0:
		s.set_border_width_all(BORDER)
		s.border_color = edge
	s.content_margin_left = margin_x
	s.content_margin_right = margin_x
	s.content_margin_top = margin_y
	s.content_margin_bottom = margin_y
	return s


## Gives `b` its own box for every state (`plain` when idle and disabled, `hover` under the pointer, `lit` pressed or
## picked, under the pointer or not), and has it measured by its largest box. Boxes of one button should share their
## margins: a button is not measured again as the pointer moves, so a state with wider margins cut its words (UI1:
## Customise's LOADOUT read LOADOU while pressed).
static func dress(b: Button, plain: StyleBox, hover: StyleBox, lit: StyleBox) -> void:
	b.add_theme_stylebox_override("normal", plain)
	b.add_theme_stylebox_override("disabled", plain)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", lit)
	b.add_theme_stylebox_override("hover_pressed", lit)
	b.add_theme_constant_override("align_to_largest_stylebox", 1)


## The menus' small button: CONTROL_HEIGHT tall, its words in CONTROL_SIZE capitals, a card box edged in `edge` (the
## line colour, or yellow for the one to press), lit yellow when pressed.
static func small_button(b: Button, edge: Color = LINE) -> void:
	var plain := box(CARD, edge, CONTROL_PAD_X, 0)
	dress(b, plain, box(CARD_HI, edge, CONTROL_PAD_X, 0), box(CARD_HI, ACCENT, CONTROL_PAD_X, 0))
	b.add_theme_font_override("font", spaced_font(800, SPACING_TAB, CONTROL_SIZE))
	b.add_theme_font_size_override("font_size", CONTROL_SIZE)
	b.custom_minimum_size.y = CONTROL_HEIGHT


## A row's name: capitals in LABEL_SIZE (owner, 2026-10-03: menu labels are capitals).
static func row_label(l: Label) -> void:
	l.text = l.text.to_upper()
	l.add_theme_font_override("font", spaced_font(700, SPACING_LABEL, LABEL_SIZE))
	l.add_theme_font_size_override("font_size", LABEL_SIZE)
	l.add_theme_color_override("font_color", TEXT)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


## A help line: NOTE_SIZE words in the muted colour.
static func note_label(l: Label) -> void:
	l.add_theme_font_override("font", font(600))
	l.add_theme_font_size_override("font_size", NOTE_SIZE)
	l.add_theme_color_override("font_color", MUTED)


## A slider's round yellow knob (`SLIDER_GRABBER` px, edge smoothed; the concept's `rules-custom.png` round time).
static func knob() -> Texture2D:
	if _knob != null:
		return _knob
	var image := Image.create(SLIDER_GRABBER, SLIDER_GRABBER, false, Image.FORMAT_RGBA8)
	var centre := Vector2.ONE * (SLIDER_GRABBER / 2.0)
	for y in SLIDER_GRABBER:
		for x in SLIDER_GRABBER:
			var reach := (Vector2(x + 0.5, y + 0.5) - centre).length()
			image.set_pixel(x, y, Color(ACCENT, clampf(SLIDER_GRABBER / 2.0 - reach + 0.5, 0.0, 1.0)))
	_knob = ImageTexture.create_from_image(image)
	return _knob


## A tab's pill: `fill`, rounded, its words padded (TAB_PAD).
static func pill_box(fill: Color) -> StyleBoxFlat:
	return box(fill, Color(0.0, 0.0, 0.0, 0.0), TAB_PAD.x, TAB_PAD.y)


## The shared Theme.
static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	_theme = Theme.new()
	_theme.default_font = font(600)
	_theme.default_font_size = BODY_SIZE
	_add_text(_theme)
	_add_buttons(_theme)
	_add_panels(_theme)
	_add_inputs(_theme)
	return _theme


static func _add_text(t: Theme) -> void:
	t.set_color("font_color", "Label", TEXT)
	for type: StringName in [&"CheckButton", &"CheckBox"]:
		t.set_color("font_color", type, TEXT)
		t.set_color("font_hover_color", type, TEXT)
		t.set_color("font_pressed_color", type, TEXT)
		t.set_color("font_hover_pressed_color", type, TEXT)
		t.set_color("font_focus_color", type, TEXT)
		t.set_color("font_disabled_color", type, DIM)


static func _add_buttons(t: Theme) -> void:
	# every state has a box with the same margins, hover_pressed included (a toggle that is down under the pointer: without
	# it Godot's own 4 px box was drawn and measured, and a switch shrank as it was clicked, UI1); and a button is
	# measured by its largest box, so no state can cut its words
	var states: Dictionary[String, Color] = {"normal": CARD, "hover": CARD_HI, "pressed": CARD_HI,
			"hover_pressed": CARD_HI, "disabled": CARD}
	t.set_constant("align_to_largest_stylebox", "Button", 1)
	for type: StringName in [&"Button", &"OptionButton", &"CheckButton", &"CheckBox"]:
		for state: String in states:
			var edge := ACCENT if state == "pressed" or state == "hover_pressed" else LINE
			t.set_stylebox(state, type, box(states[state], edge))
		t.set_stylebox("focus", type, focus_box())
		t.set_color("font_color", type, TEXT)
		t.set_color("font_hover_color", type, TEXT)
		t.set_color("font_pressed_color", type, TEXT)
		t.set_color("font_focus_color", type, TEXT)
		t.set_color("font_hover_pressed_color", type, TEXT)
		t.set_color("font_disabled_color", type, DIM)
		t.set_font("font", type, spaced_font(700, SPACING_TAB, BODY_SIZE))
	# The main button: a rounded teal plate, lighter under the pointer; the focus a white ring round it.
	t.set_type_variation(MAIN_BUTTON, "Button")
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var fill := ACCENT
		if state == "hover" or state == "pressed" or state == "hover_pressed":
			fill = ACCENT.lightened(MAIN_HOVER_LIGHTEN)
		if state == "disabled":
			fill = DIM
		var plate := box(fill, Color(0.0, 0.0, 0.0, 0.0), MAIN_MARGIN_X, MAIN_MARGIN_Y)
		plate.set_corner_radius_all(MAIN_RADIUS)
		if state == "focus":
			plate.draw_center = false
			plate.set_border_width_all(FOCUS_BORDER)
			plate.border_color = TEXT
			plate.set_expand_margin_all(FOCUS_BORDER)
		t.set_stylebox(state, MAIN_BUTTON, plate)
	for colour: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color",
			"font_focus_color"]:
		t.set_color(colour, MAIN_BUTTON, ACCENT_INK)
	t.set_font("font", MAIN_BUTTON, heading_font(700, SPACING_MAIN, MAIN_BUTTON_SIZE))
	t.set_font_size("font_size", MAIN_BUTTON, MAIN_BUTTON_SIZE)
	# The quiet text button.
	t.set_type_variation(LINK_BUTTON, "Button")
	var none := StyleBoxEmpty.new()
	for state: String in BUTTON_STATES:
		t.set_stylebox(state, LINK_BUTTON, none)
	t.set_stylebox("focus", LINK_BUTTON, focus_box())
	t.set_color("font_color", LINK_BUTTON, MUTED)
	t.set_color("font_hover_color", LINK_BUTTON, TEXT)
	t.set_color("font_pressed_color", LINK_BUTTON, TEXT)
	t.set_color("font_focus_color", LINK_BUTTON, TEXT)
	t.set_font("font", LINK_BUTTON, font(600))
	t.set_font_size("font_size", LINK_BUTTON, SMALL_SIZE)
	t.set_type_variation(LINK_UNDERLINED, LINK_BUTTON)
	for state: String in BUTTON_STATES:
		var rule := StyleBoxFlat.new()
		rule.draw_center = false
		rule.border_width_bottom = BORDER
		rule.border_color = MUTED
		rule.content_margin_bottom = UNDERLINE_GAP
		t.set_stylebox(state, LINK_UNDERLINED, rule)


## A glass panel: the PANEL fill, a hairline edge and the panel's rounder corners, with the given inner margins.
static func panel_box(margin_x: int, margin_y: int) -> StyleBoxFlat:
	var s := box(PANEL, LINE, margin_x, margin_y)
	s.set_border_width_all(1)
	s.set_corner_radius_all(PANEL_RADIUS)
	return s


## The outline a focused control gets.
static func focus_box() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.draw_center = false
	s.set_border_width_all(FOCUS_BORDER)
	s.border_color = ACCENT
	s.set_corner_radius_all(RADIUS)
	s.anti_aliasing = true
	return s


## The focus outline drawn just outside a control (a white pill's tab or choice), so it lies on the dark round it and
## not on the white, where teal would hardly show.
static func focus_ring_out() -> StyleBoxFlat:
	var s := focus_box()
	s.set_expand_margin_all(FOCUS_BORDER + 1)
	s.set_corner_radius_all(RADIUS + FOCUS_BORDER + 1)
	return s


static func _add_panels(t: Theme) -> void:
	t.set_stylebox("panel", "PanelContainer", panel_box(0, 0))
	t.set_stylebox("panel", "Panel", panel_box(0, 0))
	t.set_stylebox("panel", "PopupMenu", box(PANEL, LINE, BUTTON_MARGIN_X, BUTTON_MARGIN_Y))
	t.set_stylebox("hover", "PopupMenu", box(CARD_HI, Color(0.0, 0.0, 0.0, 0.0), 0, 2))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", TEXT)
	# Tabs: a row of pills over the panel, a gap between them (UI concept B v2 `settings.png`); the selected one white
	# with dark words.
	var tab_panel := panel_box(20, 12)
	tab_panel.expand_margin_top = -TAB_GAP
	tab_panel.content_margin_top += TAB_GAP
	t.set_stylebox("panel", "TabContainer", tab_panel)
	t.set_stylebox("tab_selected", "TabContainer", pill_box(TEXT))
	t.set_stylebox("tab_unselected", "TabContainer", pill_box(CARD))
	t.set_stylebox("tab_hovered", "TabContainer", pill_box(CARD_HI))
	t.set_stylebox("tab_disabled", "TabContainer", pill_box(CARD))
	t.set_stylebox("tab_focus", "TabContainer", focus_ring_out())
	t.set_stylebox("tabbar_background", "TabContainer", StyleBoxEmpty.new())
	t.set_constant("tab_separation", "TabContainer", TAB_SEPARATION)
	t.set_color("font_selected_color", "TabContainer", BG)
	t.set_color("font_unselected_color", "TabContainer", MUTED)
	t.set_color("font_hovered_color", "TabContainer", TEXT)
	t.set_color("font_disabled_color", "TabContainer", DIM)
	t.set_font("font", "TabContainer", heading_font(600, SPACING_TAB, TAB_SIZE))
	t.set_font_size("font_size", "TabContainer", TAB_SIZE)
	# Scrolling lists.
	for type: StringName in [&"VScrollBar", &"HScrollBar"]:
		t.set_stylebox("scroll", type, box(PANEL, Color(0.0, 0.0, 0.0, 0.0), SCROLL_WIDTH / 2, 0))
		t.set_stylebox("grabber", type, box(LINE, Color(0.0, 0.0, 0.0, 0.0), SCROLL_WIDTH / 2, 0))
		t.set_stylebox("grabber_highlight", type, box(MUTED, Color(0.0, 0.0, 0.0, 0.0), SCROLL_WIDTH / 2, 0))
		t.set_stylebox("grabber_pressed", type, box(ACCENT, Color(0.0, 0.0, 0.0, 0.0), SCROLL_WIDTH / 2, 0))


static func _add_inputs(t: Theme) -> void:
	for type: StringName in [&"LineEdit", &"TextEdit"]:
		t.set_stylebox("normal", type, box(CARD, LINE))
		t.set_stylebox("focus", type, box(CARD, ACCENT))
		t.set_stylebox("read_only", type, box(CARD, LINE))
		t.set_color("font_color", type, TEXT)
		t.set_color("font_readonly_color", type, TEXT)
		t.set_color("caret_color", type, ACCENT)
		t.set_color("selection_color", type, CARD_HI)
	var rail := StyleBoxFlat.new()
	rail.bg_color = LINE
	rail.content_margin_top = SLIDER_HEIGHT
	rail.content_margin_bottom = SLIDER_HEIGHT
	var filled := StyleBoxFlat.new()
	filled.bg_color = ACCENT
	filled.content_margin_top = SLIDER_HEIGHT
	filled.content_margin_bottom = SLIDER_HEIGHT
	t.set_stylebox("slider", "HSlider", rail)
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled)
