class_name HudPingMarker
extends Control
## One ping's marker on the HUD (PN2; concept `step27/ping.png`; the browser game's ui/pingMarkers.ts, PG1): over the
## field a ring in your team's colour for a spot, or a diamond in the other team's for a contact, with "PING · 9 M" or
## "CONTACT · 13 M" under it. Off the screen's side or behind you it is pinned inside the edge instead, as the flag
## marker is: a navy plate with a chevron pointing the way, the ring or diamond and the words. It pops in over
## HudConfig.ping_pop (at once under Reduced motion), stays whole, and fades over the last HudConfig.ping_fade of its
## life. Made once (HudPingMarkers keeps one per teammate) and refilled: its words change only with the distance or
## the kind, and a frame that moves it allocates nothing. Over the field the marker draws its glyph (one triangle
## array: a Mark) and its words itself, one canvas item; the pinned plate's nodes draw only while it is pinned.

## What a glyph draws: the spot's ring, the contact's diamond, or a pinned plate's chevron pointing left or right.
enum Shape { RING, DIAMOND, LEFT, RIGHT }

## The ring's or diamond's box over the field and on a pinned plate (px), and the words' type sizes.
const ICON := 30.0
const EDGE_ICON := 20.0
const WORDS_SIZE := 17
const EDGE_SIZE := 20
## The space between the glyph and its words over the field (px), and the words' dark edge (the vault prompt's).
const WORDS_GAP := 3.0
const OUTLINE := 6
const OUTLINE_COLOUR := Color(0.0, 0.0, 0.0, 0.55)
## The pinned plate: its padding (left, top, right, bottom), the gap between its parts and the rule on top (px).
const EDGE_PAD := Vector4i(14, 6, 15, 7)
const EDGE_GAP := 10
const EDGE_RULE := 2
const CHEVRON := Vector2(10.0, 16.0)
## The glyphs' strokes (px): the ring's band in its colour, the dark ink round it and round the diamond.
const RING_WIDTH := 3.5
const INK_WIDTH := 2.0
const INK := Color(Color("080d18"), 0.85)
const ARC_POINTS := 32
## The antialiasing fringe round a Mark's edges (px), fading to nothing.
const FEATHER := 1.0
## The pop's easing: out, so it pops up and settles (the overtime flag's rise).
const POP_EASE := 0.4

## A spot's words by what it asks (Pings.Ask): a plain ping's, Help, Go, Cover (BQ2).
const ASK_KEYS: PackedStringArray = ["HUD_PING_MARKER", "HUD_HELP_MARKER", "HUD_GO_MARKER", "HUD_COVER_MARKER"]

var _cfg: HudConfig = null
## The field look's glyphs, its words' font, the words and where they start (drawn in _draw).
var _ring: Mark = null
var _diamond: Mark = null
var _font: Font = null
var _text: String = ""
var _text_at := Vector2.ZERO
var _shape: Shape = Shape.RING
var _edge: PanelContainer = null
var _edge_box: StyleBoxFlat = null
var _chevron: Glyph = null
var _edge_icon: Glyph = null
var _edge_words: Label = null
var _kind: Pings.Kind = Pings.Kind.SPOT
var _ask: Pings.Ask = Pings.Ask.NONE
var _colour := Color.TRANSPARENT
var _metres: int = -1
var _pinned: bool = false


## The marker's parts, sized and timed by `cfg`; hidden until a ping shows (HudPingMarkers).
func setup(cfg: HudConfig) -> void:
	_cfg = cfg
	name = "HudPingMarker"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_ring = Mark.ring_for(ICON)
	_diamond = Mark.diamond_for(ICON)
	_font = GameTheme.spaced_font(800, HudStyle.SPACING_AIM, WORDS_SIZE)
	_edge = PanelContainer.new()
	_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edge_box = HudStyle.panel_box(HudStyle.BACKING_CLOCK, EDGE_PAD.x, EDGE_PAD.y)
	_edge_box.content_margin_right = EDGE_PAD.z
	_edge_box.content_margin_bottom = EDGE_PAD.w
	_edge_box.border_width_top = EDGE_RULE
	_edge.add_theme_stylebox_override("panel", _edge_box)
	_edge.visible = false
	add_child(_edge)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", EDGE_GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edge.add_child(row)
	_chevron = Glyph.new(CHEVRON)
	row.add_child(_chevron)
	_edge_icon = Glyph.new(Vector2(EDGE_ICON, EDGE_ICON))
	row.add_child(_edge_icon)
	_edge_words = HudStyle.label(row, EDGE_SIZE, 800, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT,
			HudStyle.SPACING_AIM)


## Shows a ping of `kind` in `colour`, `metres` away, asking `ask` of you (a bot teammate's, BQ2: its words say what):
## the glyph and the words change only when these do.
func set_ping(kind: Pings.Kind, colour: Color, metres: int, ask: Pings.Ask = Pings.Ask.NONE) -> void:
	if kind == _kind and colour == _colour and metres == _metres and ask == _ask:
		return
	_kind = kind
	_colour = colour
	_metres = metres
	_ask = ask
	_shape = Shape.DIAMOND if kind == Pings.Kind.CONTACT else Shape.RING
	var key := "HUD_CONTACT_MARKER" if kind == Pings.Kind.CONTACT else ASK_KEYS[ask]
	_text = (tr(key) % metres).to_upper()
	if _pinned:
		_fill_edge()
	else:
		_lay_out()


## Over the field: the glyph's middle at `at` (the HUD's px), its words under it.
func put_on_field(at: Vector2) -> void:
	_set_pinned(false)
	pivot_offset = Vector2(size.x * 0.5, ICON * 0.5)
	position = at - pivot_offset


## The pinned plate's size (px), its words and glyph filled first (they are only kept while it shows).
func plate_size() -> Vector2:
	_fill_edge()
	return _edge.get_combined_minimum_size()


## Pinned at a side: the plate's top left at `top_left`, its chevron pointing left (`towards_left`) or right.
func put_on_edge(top_left: Vector2, towards_left: bool) -> void:
	_set_pinned(true)
	_chevron.set_look(Shape.LEFT if towards_left else Shape.RIGHT, _colour)
	size = plate_size()
	_edge.size = size
	pivot_offset = size * 0.5
	position = top_left


## How it shows `age` s into a life of `life` s: popped in (scale) unless `pops` is false, and faded (alpha); written
## only when they change (between the pop and the fade, neither does).
func set_age(age: float, life: float, pops: bool) -> void:
	var k := pop_scale(age, _cfg.ping_pop if pops else 0.0, _cfg.ping_pop_from)
	if k != scale.x:
		scale = Vector2(k, k)
	var a := shade(age, life, _cfg.ping_fade)
	if a != modulate.a:
		modulate.a = a


## Whether it is pinned to a side.
func pinned() -> bool:
	return _pinned


## Its words ("PING · 9 M"), or "" while hidden: for tests.
func text() -> String:
	return _text if visible else ""


## Its glyph's shape and colour (RING or DIAMOND), and the chevron's way when pinned: for tests.
func shape() -> Shape:
	return _shape


func colour() -> Color:
	return _colour


func chevron() -> Shape:
	return _chevron.shape


## A marker's scale `age` s after its ping: from `from` to whole over `pop` s, eased out (whole at once for no pop).
static func pop_scale(age: float, pop: float, from: float) -> float:
	if pop <= 0.0 or age >= pop:
		return 1.0
	return lerpf(from, 1.0, ease(clampf(age / pop, 0.0, 1.0), POP_EASE))


## A marker's alpha `age` s into a life of `life` s: whole, then fading to nothing over the last `fade` s.
static func shade(age: float, life: float, fade: float) -> float:
	if fade <= 0.0:
		return 1.0 if age < life else 0.0
	return clampf((life - age) / fade, 0.0, 1.0)


func _set_pinned(on: bool) -> void:
	if on == _pinned:
		return
	_pinned = on
	_edge.visible = on
	if on:
		_fill_edge()
	else:
		_lay_out()
	queue_redraw()


## The field look's layout: the glyph at the top middle, the words under it (as a centred Label had them).
func _lay_out() -> void:
	if _pinned:
		return
	var words := _font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, WORDS_SIZE)
	size = Vector2(maxf(ICON, words.x), ICON + WORDS_GAP + words.y)
	_text_at = Vector2((size.x - words.x) * 0.5, ICON + WORDS_GAP + _font.get_ascent(WORDS_SIZE))
	queue_redraw()


## The pinned plate's look: its glyph, rule, chevron's colour and words (only while it shows).
func _fill_edge() -> void:
	_edge_icon.set_look(_shape, _colour)
	_chevron.set_look(_chevron.shape, _colour)
	if _edge_box.border_color != _colour:
		_edge_box.border_color = _colour
	_edge_words.text = _text


## The field look: the glyph and the words under it with their dark edge. Nothing while pinned (the plate shows).
func _draw() -> void:
	if _pinned or _text.is_empty():
		return
	var mark := _diamond if _shape == Shape.DIAMOND else _ring
	mark.draw(self, Vector2(size.x * 0.5, ICON * 0.5), _colour, INK)
	draw_string_outline(_font, _text_at, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, WORDS_SIZE, OUTLINE, OUTLINE_COLOUR)
	draw_string(_font, _text_at, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, WORDS_SIZE, GameTheme.TEXT)


## A ring or a diamond with its dark ink as one triangle array, so it costs one draw call where two strokes cost two or
## more: rings of `segments` vertices round the middle (`radii` from the inside out, each ink or colour (`inked`) at a
## share of its alpha (`shares`)), each joined to the next unless the two share a radius (where ink meets colour), and
## with `fill` a fan from the middle to the first. Four segments from the top make a diamond. Made once; draw()
## refills its points and colours in place, so it allocates nothing.
class Mark:
	extends RefCounted

	var _base := PackedVector2Array()
	var _inked := PackedByteArray()
	var _shares := PackedFloat32Array()
	var _points := PackedVector2Array()
	var _colours := PackedColorArray()
	var _indices := PackedInt32Array()

	func _init(segments: int, radii: PackedFloat32Array, inked: PackedByteArray, shares: PackedFloat32Array,
			fill: bool, turn: float = 0.0) -> void:
		var stops := radii.size()
		for k in stops:
			for i in segments:
				var a := turn + TAU * i / segments
				_base.append(Vector2(cos(a), sin(a)) * maxf(radii[k], 0.0))
				_inked.append(inked[k])
				_shares.append(shares[k])
		for k in stops - 1:
			if is_equal_approx(radii[k], radii[k + 1]):
				continue
			for i in segments:
				var j := (i + 1) % segments
				var a0 := k * segments + i
				var a1 := k * segments + j
				_indices.append_array([a0, a0 + segments, a1, a1, a0 + segments, a1 + segments])
		if fill:
			var mid := _base.size()
			_base.append(Vector2.ZERO)
			_inked.append(inked[0])
			_shares.append(shares[0])
			for i in segments:
				_indices.append_array([mid, i, (i + 1) % segments])
		_points.resize(_base.size())
		_colours.resize(_base.size())

	## A ring `width` px wide in its colour round `radius`, `ink` px of ink either side.
	static func ring(radius: float, width: float, ink: float, segments: int) -> Mark:
		var inner := radius - width * 0.5
		var outer := radius + width * 0.5
		return Mark.new(segments, PackedFloat32Array([inner - ink - FEATHER, inner - ink, inner, inner, outer, outer,
				outer + ink, outer + ink + FEATHER]), PackedByteArray([1, 1, 1, 0, 0, 1, 1, 1]),
				PackedFloat32Array([0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0]), false)

	## A diamond `corner` px from its middle to each tip, filled in its colour, its edge an ink line `ink` px wide
	## centred on it (as a polyline drew it).
	static func diamond(corner: float, ink: float) -> Mark:
		var across := sqrt(2.0) # a band `w` px across a diamond's edge reaches w * √2 further to its tip
		var inner := corner - ink * 0.5 * across
		var outer := corner + ink * 0.5 * across
		return Mark.new(4, PackedFloat32Array([inner, inner, outer, outer + FEATHER * across]),
				PackedByteArray([0, 1, 1, 1]), PackedFloat32Array([1.0, 1.0, 1.0, 0.0]), true, -PI * 0.5)

	## The field marker's and a plate's ring in a `box` px square (as Glyph drew it).
	static func ring_for(box: float) -> Mark:
		return ring(box * 0.5 - (RING_WIDTH * 0.5 + INK_WIDTH), RING_WIDTH, INK_WIDTH, ARC_POINTS)

	static func diamond_for(box: float) -> Mark:
		return diamond(box * 0.5 - INK_WIDTH * 0.5, INK_WIDTH)

	## Draws it round `at` on `on` (call from its _draw): the colour parts in `colour`, the ink in `ink`.
	func draw(on: CanvasItem, at: Vector2, colour: Color, ink: Color) -> void:
		for i in _base.size():
			_points[i] = at + _base[i]
			var c := ink if _inked[i] == 1 else colour
			c.a *= _shares[i]
			_colours[i] = c
		RenderingServer.canvas_item_add_triangle_array(on.get_canvas_item(), _indices, _points, _colours)


## A ring, a diamond or a chevron in a colour, drawn in its box; redrawn only when its look changes.
class Glyph:
	extends Control

	var shape: Shape = Shape.RING
	var _colour := Color.WHITE
	var _ring: Mark = null
	var _diamond: Mark = null
	var _tri := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])

	func _init(box: Vector2) -> void:
		custom_minimum_size = box
		size = box
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var side := minf(box.x, box.y)
		_ring = Mark.ring_for(side)
		_diamond = Mark.diamond_for(side)

	func set_look(to: Shape, colour: Color) -> void:
		if to == shape and colour == _colour:
			return
		shape = to
		_colour = colour
		queue_redraw()

	func _draw() -> void:
		var box := custom_minimum_size
		var c := box * 0.5
		match shape:
			Shape.RING:
				_ring.draw(self, c, _colour, INK)
			Shape.DIAMOND:
				_diamond.draw(self, c, _colour, INK)
			_:
				var left := shape == Shape.LEFT
				_tri[0] = Vector2(0.0 if left else box.x, box.y * 0.5)
				_tri[1] = Vector2(box.x if left else 0.0, 0.0)
				_tri[2] = Vector2(box.x if left else 0.0, box.y)
				draw_colored_polygon(_tri, _colour)
