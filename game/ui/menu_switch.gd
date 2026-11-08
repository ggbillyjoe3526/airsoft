class_name MenuSwitch
extends CheckButton
## A Settings On/Off switch: a pill with a knob, yellow with the knob at the right when on, the line colour with the knob
## at the left when off (UI1). It has no words, and its size is fixed (WIDTH by GameTheme.CONTROL_HEIGHT) whatever its
## state, hovered or pressed: every state's box is empty and the pill is drawn here, so clicking it moves nothing beside it
## (owner, 2026-10-29: "on/off toggles ... still affect other UI elements"; the old switch was words in a box, and the box
## Godot drew while it was on under the pointer had other margins, so the row shrank by 8 px as it was clicked).

## The control's width, the pill's size and the knob's inset (px at 1080p).
const WIDTH := 48.0
const PILL := Vector2(44.0, 22.0)
const KNOB_INSET := 3.0
## The focus ring's gap round the pill (px).
const RING_GAP := 3.0
## A greyed switch's opacity, and how much the pointer lightens it.
const DIM_ALPHA := 0.45
const HOVER_LIGHTEN := 0.12
## The off switch's outline (px at 1080p).
const OFF_OUTLINE := 2.0

## An empty icon, so CheckButton keeps no room of its own for one; the focus ring's box. Made once.
static var _none: ImageTexture = null
static var _ring: StyleBoxFlat = null


## A switch, off to begin with. `on_words` and `off_words` are its state in words (`words()`), shown nowhere.
func _init(on_words: String = "", off_words: String = "") -> void:
	text = ""
	set_meta(&"words", PackedStringArray([off_words, on_words]))
	custom_minimum_size = Vector2(WIDTH, GameTheme.CONTROL_HEIGHT)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	focus_mode = Control.FOCUS_ALL
	var none := StyleBoxEmpty.new()
	for state: String in GameTheme.BUTTON_STATES:
		add_theme_stylebox_override(state, none)
	add_theme_stylebox_override("focus", none)
	add_theme_constant_override("align_to_largest_stylebox", 1)
	if _none == null:
		_none = ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8))
		_ring = StyleBoxFlat.new()
		_ring.draw_center = false
		_ring.set_border_width_all(GameTheme.FOCUS_BORDER)
		_ring.border_color = GameTheme.ACCENT
		_ring.set_corner_radius_all(int((PILL.y + RING_GAP * 2.0) * 0.5))
	for icon: String in ["checked", "unchecked", "checked_disabled", "unchecked_disabled", "checked_mirrored",
			"unchecked_mirrored", "checked_disabled_mirrored", "unchecked_disabled_mirrored"]:
		add_theme_icon_override(icon, _none)
	toggled.connect(func(_on: bool) -> void: queue_redraw())
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


## Sets the switch without sending `toggled`.
func put(on: bool) -> void:
	set_pressed_no_signal(on)
	queue_redraw()


## Its state in words ("On" or "Off", as given).
func words() -> String:
	var both: PackedStringArray = get_meta(&"words")
	return both[1] if button_pressed else both[0]


## The pill, knob and outline colours for a state: on is the accent with an ink knob; off is a plain grey outline with a
## small grey knob and no fill, so a switched-off pill is quiet and its two ends never read as two spheres (BP8).
static func colours(on: bool, hovered: bool, dimmed: bool) -> PackedColorArray:
	var fill := Color(0.0, 0.0, 0.0, 0.0)
	var knob := GameTheme.DIM
	var outline := GameTheme.DIM
	if on:
		fill = GameTheme.ACCENT
		knob = GameTheme.ACCENT_INK
		outline = fill
	if hovered and not dimmed:
		fill = fill.lightened(HOVER_LIGHTEN)
		outline = outline.lightened(HOVER_LIGHTEN) if on else GameTheme.MUTED
		knob = knob if on else GameTheme.MUTED
	if dimmed:
		fill.a *= DIM_ALPHA
		knob.a *= DIM_ALPHA
		outline.a *= DIM_ALPHA
	return PackedColorArray([fill, knob, outline])


func _draw() -> void:
	var on := button_pressed
	var pill := Rect2((size - PILL) * 0.5, PILL)
	var radius := PILL.y * 0.5
	var col := colours(on, is_hovered(), disabled)
	var mid := pill.get_center().y
	if on:
		draw_rect(Rect2(pill.position.x + radius, pill.position.y, pill.size.x - radius * 2.0, pill.size.y), col[0])
		draw_circle(Vector2(pill.position.x + radius, mid), radius, col[0])
		draw_circle(Vector2(pill.end.x - radius, mid), radius, col[0])
	else:
		var inset := OFF_OUTLINE * 0.5
		var r := radius - inset
		var left := Vector2(pill.position.x + radius, mid)
		var right := Vector2(pill.end.x - radius, mid)
		draw_line(Vector2(left.x, pill.position.y + inset), Vector2(right.x, pill.position.y + inset), col[2], OFF_OUTLINE)
		draw_line(Vector2(left.x, pill.end.y - inset), Vector2(right.x, pill.end.y - inset), col[2], OFF_OUTLINE)
		draw_arc(left, r, PI * 0.5, PI * 1.5, 16, col[2], OFF_OUTLINE)
		draw_arc(right, r, -PI * 0.5, PI * 0.5, 16, col[2], OFF_OUTLINE)
	var knob_x := pill.end.x - radius if on else pill.position.x + radius
	var knob_r := radius - KNOB_INSET if on else radius - KNOB_INSET - OFF_OUTLINE
	draw_circle(Vector2(knob_x, mid), knob_r, col[1])
	if has_focus():
		draw_style_box(_ring, pill.grow(RING_GAP))
