class_name MenuParts
## Small builders the menu pages share (the concept's `h2`, text, padded boxes and the picture's glow), so each page builds
## its labels one way: Inter at a weight, a size and a colour from GameTheme.

const HEADING_GAP := 16
## A section the picked mode doesn't use: how much of it shows, and its tag's size and gap after the heading (px).
const UNUSED_ALPHA := 0.4
const UNUSED_TAG_SIZE := 12
const UNUSED_TAG_GAP := 14
## The glow behind a replica's picture (the concept's radial gradient from #27406b to the card colour).
const GLOW := Color("27406b")
const GLOW_CENTRE := Vector2(0.5, 0.6)
const GLOW_REACH := 0.7
const GLOW_SIZE := 64
## A menu page (UI concept B): its room inside the space right of the side rail (left, top, right, bottom), its title's
## size and letter spacing, the gap to the line beside it and that line's size, the gap under the title row, and its
## glass panels' gap and padding. Every page draws these through page_title and glass, so they line up page to page.
const PAGE_MARGIN := Vector4(52.0, 34.0, 48.0, 44.0)
const PAGE_TITLE_SIZE := 54
const PAGE_TITLE_SPACING := 0.02
const PAGE_TITLE_GAP := 22
const PAGE_LINE_SIZE := 18
const PAGE_TITLE_AFTER := 20
const PANEL_GAP := 26
const PANEL_PAD := Vector2i(22, 22)
## A key cap's corner radius and least width (px).
const KEY_CORNER := 4
const KEY_MIN_WIDTH := 26.0


## A label in Inter at `weight`.
static func text(words: String, size: int, weight: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = words
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", GameTheme.font(weight))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	return label


## A label in capitals spaced `em` (the concept's letter-spacing).
static func spaced(words: String, size: int, weight: int, colour: Color, em: float) -> Label:
	var label := text(words, size, weight, colour)
	label.add_theme_font_override("font", GameTheme.spaced_font(weight, em, size))
	return label


## A key's cap: its words in a small outlined box with rounded corners (the concepts' `.key`); the box's only child is
## the label. Its mouse is ignored.
static func key_chip(words: String, size: int, colour: Color, pad: Vector2i) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.custom_minimum_size = Vector2(KEY_MIN_WIDTH, 0.0)
	var face := GameTheme.box(Color(0.0, 0.0, 0.0, 0.0), colour, pad.x, pad.y)
	face.set_corner_radius_all(KEY_CORNER)
	chip.add_theme_stylebox_override("panel", face)
	var label := text(words, size, 800, colour)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.add_child(label)
	return chip


## The section heading: muted Barlow Condensed capitals, spaced (concept B's `.cap`).
static func heading(words: String) -> Label:
	return head_text(words, GameTheme.HEADING_SIZE, 600, GameTheme.MUTED, GameTheme.SPACING_HEADING_CAPS)


## A label in Barlow Condensed capitals spaced `em`: a page title, a card's name (words only, never a number).
static func head_text(words: String, size: int, weight: int, colour: Color, em: float) -> Label:
	var label := text(words.to_upper(), size, weight, colour)
	label.add_theme_font_override("font", GameTheme.heading_font(weight, em, size))
	return label


## A section heading with its NOT USED tag after it (child 1, hidden until `set_unused`): the concept's `h2 .later`.
static func heading_row(words: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", UNUSED_TAG_GAP)
	row.add_child(heading(words))
	var tag := MenuTag.grey("MENU_NOT_USED", UNUSED_TAG_SIZE)
	tag.name = "NotUsed"
	tag.visible = false
	row.add_child(tag)
	return row


## Marks a section the picked mode doesn't use (the Match page's Practice): its `tag` shows, `parts` (its body, not its
## heading) fade to UNUSED_ALPHA and no button or slider in them takes a click, a drag or the focus; or the reverse.
static func set_unused(parts: Array[Control], tag: Control, on: bool) -> void:
	tag.visible = on
	for part in parts:
		part.modulate.a = UNUSED_ALPHA if on else 1.0
		_lock(part, on)


static func _lock(node: Node, on: bool) -> void:
	if node is BaseButton or node is Slider:
		var c := node as Control
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE if on else Control.MOUSE_FILTER_STOP
		c.focus_mode = Control.FOCUS_NONE if on else Control.FOCUS_ALL
	for child in node.get_children():
		_lock(child, on)


## A margin container with the margins left, top, right, bottom.
static func padded(left: float, top: float, right: float, bottom: float) -> MarginContainer:
	var pad := MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_theme_constant_override("margin_left", int(left))
	pad.add_theme_constant_override("margin_top", int(top))
	pad.add_theme_constant_override("margin_right", int(right))
	pad.add_theme_constant_override("margin_bottom", int(bottom))
	return pad


## A vertical box holding `head` over what follows.
static func section(head: Control) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", HEADING_GAP)
	box.add_child(head)
	return box


## The radial glow a replica's picture sits in, fading into `edge`.
static func glow(edge: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, GLOW)
	gradient.set_color(1, edge)
	gradient.set_offset(1, GLOW_REACH)
	var t := GradientTexture2D.new()
	t.gradient = gradient
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = GLOW_CENTRE
	t.fill_to = Vector2(1.0, GLOW_CENTRE.y)
	t.width = GLOW_SIZE
	t.height = GLOW_SIZE
	return t


## A picture frame: `texture` kept in shape, centred, and never past the box it is in (so never over a card's lines).
## With `box` the picture is at most that size (px at 1080p) and centred in the room it is given; else it fills it.
static func picture(box: Vector2 = Vector2.ZERO) -> TextureRect:
	var r := TextureRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if box != Vector2.ZERO:
		r.custom_minimum_size = box
		r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r


## A page's title row: `title` in condensed capitals and `line` beside it, sitting on the title's baseline.
static func page_title(title: String, line: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "TitleRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", PAGE_TITLE_GAP)
	var words := head_text(title, PAGE_TITLE_SIZE, 700, GameTheme.TEXT, PAGE_TITLE_SPACING)
	words.name = "Title"
	row.add_child(words)
	var drop := padded(0.0, 0.0, 0.0, roundf(PAGE_TITLE_SIZE * 0.16))
	drop.size_flags_vertical = Control.SIZE_SHRINK_END
	line.size_flags_vertical = Control.SIZE_SHRINK_END
	drop.add_child(line)
	row.add_child(drop)
	return row


## A page title's muted line.
static func page_line(words: String) -> Label:
	var line := text(words, PAGE_LINE_SIZE, 500, GameTheme.MUTED)
	line.add_theme_constant_override("line_spacing", 0)
	return line


## `content` on a glass panel, padded.
static func glass(content: Control, pad: Vector2i = PANEL_PAD) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", GameTheme.panel_box(pad.x, pad.y))
	panel.add_child(content)
	return panel
