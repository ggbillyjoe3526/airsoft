class_name GraphicsNotice
extends PanelContainer
## A notice card on the title screen, bottom right (concept `graphics-problem.png`): a kicker, a title, a line with
## bold words, facts in two columns, a quieter foot and one or two buttons, the first solid yellow. START works under
## it. `safe_start` is the one after a start that closed while drawing (Keep safe graphics, or Try my settings again);
## `simpler_renderer` says once why the game is on the simpler renderer; `first_start` (concept `first-run.png`) names
## the automatic pick, the card and the screen once. `chosen` gives the button's index; the owner frees the notice.

signal chosen(index: int)

## Its width, and the warning one's (px), the inner margins and the edge on the left.
const WIDTH := 600.0
const WARN_WIDTH := 660.0
const PAD := Vector2i(24, 20)
const LEFT_EDGE := 6
## The warning's orange (the concept's #ff8a2a).
const WARN := Color("ff8a2a")
const FILL := Color(0.078, 0.125, 0.22, 0.96)
## Type sizes and the gaps between the parts (px).
const KICKER_SIZE := 13
const KICKER_SPACING := 0.14
const TITLE_SIZE := 30
const TITLE_SPACING := 0.04
const BODY_SIZE := 17
const FACT_SIZE := 15
const FOOT_SIZE := 15
const BUTTON_SIZE := 16
const FACT_KEY_WIDTH := 140.0
const GAP := 10
const ACTIONS_GAP := 12
const ACTIONS_TOP := 8.0
## The words for each preset and renderer (Settings › Graphics' keys).
const PRESET_KEY := "GRAPHICS_PRESET_%s"
const RENDERER_KEYS: Array[String] = ["GRAPHICS_FORWARD_PLUS", "GRAPHICS_COMPATIBILITY"]
## The window modes' words (Settings › Display's), by Settings.WindowMode.
const WINDOW_KEYS: Array[String] = ["SETTINGS_WINDOWED", "SETTINGS_BORDERLESS", "SETTINGS_EXCLUSIVE"]
## A refresh rate at or under this is one the screen didn't report.
const NO_RATE := 0.0
## The simpler renderer's line for each RendererOverride reason.
const REASON_KEYS: Dictionary[String, String] = {
	RendererOverride.REASON_SETTINGS: "NOTICE_SIMPLER_SETTINGS",
	RendererOverride.REASON_LAUNCH: "NOTICE_SIMPLER_LAUNCH",
	RendererOverride.REASON_FALLBACK: "NOTICE_SIMPLER_FALLBACK",
}

var _box: VBoxContainer = null
var _buttons: Array[Button] = []
var _edge_colour: Color = GameTheme.ACCENT


func _init(warn: bool = false) -> void:
	name = "GraphicsNotice"
	theme = GameTheme.get_theme()
	custom_minimum_size.x = WARN_WIDTH if warn else WIDTH
	_edge_colour = WARN if warn else GameTheme.ACCENT
	var panel := GameTheme.box(FILL, GameTheme.LINE, PAD.x, PAD.y)
	panel.border_width_left = LEFT_EDGE
	add_theme_stylebox_override("panel", panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", GAP)
	add_child(_box)


## The coloured edge on the left, over the panel's own.
func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, LEFT_EDGE, size.y), _edge_colour)


func edge_colour() -> Color:
	return _edge_colour


## The notice after a start that closed while drawing: `was` the player's graphics in words ("High · Forward+"), `now`
## the safe ones.
static func safe_start(was: String, now: String) -> GraphicsNotice:
	var n := GraphicsNotice.new(true)
	n.kicker(tr_static("NOTICE_SAFE_KICKER"), WARN)
	n.heading(tr_static("NOTICE_SAFE_TITLE"))
	n.line(tr_static("NOTICE_SAFE_BODY"))
	n.facts(PackedStringArray([tr_static("NOTICE_YOUR_SETTINGS"), tr_static("NOTICE_KEPT") % was,
			tr_static("NOTICE_NOW"), now]))
	n.foot(tr_static("NOTICE_SAFE_FOOT"))
	n.actions(PackedStringArray([tr_static("NOTICE_KEEP"), tr_static("NOTICE_TRY_AGAIN")]))
	return n


## The notice that says why the game is on the simpler renderer (`reason`, RendererOverride's), naming the card
## (`card`, its name and type) and the renderer (`renderer`, its name and driver).
static func simpler_renderer(reason: String, card: String, renderer: String) -> GraphicsNotice:
	var n := GraphicsNotice.new()
	n.kicker(tr_static("NOTICE_SIMPLER_KICKER"), GameTheme.ACCENT)
	n.heading(tr_static("NOTICE_SIMPLER_TITLE"))
	n.line(tr_static(REASON_KEYS.get(reason, "NOTICE_SIMPLER_FALLBACK")))
	n.facts(PackedStringArray([tr_static("GRAPHICS_CARD"), card, tr_static("GRAPHICS_RENDERER"), renderer]))
	n.actions(PackedStringArray([tr_static("NOTICE_OK")]))
	return n


## The first start's notice: the automatic pick (`preset`, a GraphicsTable preset), the card (`card`, its name and
## type) and the screen (`screen`, screen_words). OK (0) or Graphics settings (1).
static func first_start(preset: StringName, card: String, screen: String) -> GraphicsNotice:
	var n := GraphicsNotice.new()
	n.kicker(tr_static("NOTICE_FIRST_KICKER"), GameTheme.ACCENT)
	n.heading(tr_static("NOTICE_FIRST_TITLE") % tr_static(PRESET_KEY % String(preset).to_upper()))
	n.line(tr_static("NOTICE_FIRST_BODY"))
	n.facts(PackedStringArray([tr_static("GRAPHICS_CARD"), card, tr_static("GRAPHICS_SCREEN"), screen]))
	n.actions(PackedStringArray([tr_static("NOTICE_OK"), tr_static("NOTICE_GRAPHICS_SETTINGS")]))
	return n


## The screen in words: "2560 × 1440 · 144 Hz · borderless fullscreen", without the rate when the screen gives none.
static func screen_words(size: Vector2i, rate: float, mode: Settings.WindowMode) -> String:
	var window := tr_static(WINDOW_KEYS[mode]).to_lower()
	if rate > NO_RATE:
		return tr_static("NOTICE_FIRST_SCREEN") % [size.x, size.y, roundi(rate), window]
	return tr_static("NOTICE_FIRST_SCREEN_NO_RATE") % [size.x, size.y, window]


## A player's graphics in words: the preset (`choice`, or the card's pick `picked` while automatic, or Custom) and the
## renderer ("High · Forward+").
static func graphics_words(choice: StringName, picked: StringName, renderer: Settings.Renderer) -> String:
	var preset := picked if choice == Settings.GRAPHICS_AUTOMATIC else choice
	return "%s · %s" % [tr_static(PRESET_KEY % String(preset).to_upper()), tr_static(RENDERER_KEYS[renderer])]


static func tr_static(key: String) -> String:
	return TranslationServer.translate(key)


## The button `index` (tests press it).
func button(index: int) -> Button:
	return _buttons[index]


## Every word on it, in order (tests read it).
func words() -> PackedStringArray:
	var out := PackedStringArray()
	for c in _box.find_children("*", "", true, false):
		if c is Label:
			out.append((c as Label).text)
		elif c is RichTextLabel:
			out.append((c as RichTextLabel).get_parsed_text())
		elif c is Button:
			out.append((c as Button).text)
	return out


func kicker(text: String, colour: Color) -> void:
	HudStyle.label(_box, KICKER_SIZE, 800, colour, HORIZONTAL_ALIGNMENT_LEFT, KICKER_SPACING).text = text.to_upper()


func heading(text: String) -> void:
	var l := HudStyle.label(_box, TITLE_SIZE, 800, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT, TITLE_SPACING)
	l.text = text.to_upper()
	# a long title wraps rather than widening the card
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## A line in the muted colour, [b]bold[/b] words in the text colour.
func line(bbcode: String, size: int = BODY_SIZE) -> void:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_theme_font_override("normal_font", GameTheme.font(600))
	r.add_theme_font_override("bold_font", GameTheme.font(800))
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_color_override("default_color", GameTheme.MUTED)
	r.text = bbcode.replace("[b]", "[b][color=#%s]" % GameTheme.TEXT.to_html(false)).replace("[/b]", "[/color][/b]")
	_box.add_child(r)


## Facts in two columns: key, value, key, value...
func facts(pairs: PackedStringArray) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	_box.add_child(grid)
	for i in pairs.size():
		var key := i % 2 == 0
		var l := HudStyle.label(grid, FACT_SIZE, 600, GameTheme.MUTED if key else GameTheme.TEXT,
				HORIZONTAL_ALIGNMENT_LEFT)
		l.text = pairs[i]
		if key:
			l.custom_minimum_size.x = FACT_KEY_WIDTH


func foot(bbcode: String) -> void:
	line(bbcode, FOOT_SIZE)


## The buttons, left to right: the first solid yellow, the rest outlined in yellow.
func actions(words_in_order: PackedStringArray) -> void:
	var gap := Control.new()
	gap.custom_minimum_size.y = ACTIONS_TOP
	_box.add_child(gap)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ACTIONS_GAP)
	_box.add_child(row)
	for i in words_in_order.size():
		var b := Button.new()
		b.text = words_in_order[i].to_upper()
		var solid := i == 0
		var normal := GameTheme.box(GameTheme.ACCENT if solid else Color(0.0, 0.0, 0.0, 0.0), GameTheme.ACCENT)
		var lit := GameTheme.box(GameTheme.ACCENT.lightened(0.15) if solid else GameTheme.CARD_HI, GameTheme.ACCENT)
		GameTheme.dress(b, normal, lit, lit)
		b.add_theme_font_override("font", GameTheme.spaced_font(800, GameTheme.SPACING_TAB, BUTTON_SIZE))
		b.add_theme_font_size_override("font_size", BUTTON_SIZE)
		var ink := GameTheme.ACCENT_INK if solid else GameTheme.TEXT
		for colour: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(colour, ink)
		b.pressed.connect(chosen.emit.bind(i))
		row.add_child(b)
		_buttons.append(b)
	ButtonWidth.group(_buttons)
