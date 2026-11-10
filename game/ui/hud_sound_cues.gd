class_name HudSoundCues
extends Control
## The sound cue ring round the crosshair (AC4, concept `hud-sound-cues.png`; the browser game's ui/soundCues.ts): each
## SoundCues marker up sits on a ring AccessibilityConfig.cue_ring_radius px (at 1080p) from the screen's middle, at its
## sound's bearing from the eyes the view is through relative to where they look, so the ring turns as you turn: two
## dots for a step, an arrowhead pointing outwards for a shot, a HIT tag for a hit call, in Settings › Accessibility's
## colour and size (the size scales the markers, never the ring), each as strong as SoundCues.opacity. The faint ring
## itself shows while a marker does, as strong as the strongest. Redrawn only while something shows (and once more as
## the last goes); a frame allocates nothing. Painter draws the same markers for the settings' sample and key.

var _cues: SoundCues = null
var _radius: float = 0.0
var _paint: Painter = Painter.new()
var _ear: Vector3 = Vector3.ZERO
var _yaw: float = 0.0
## Whether the last draw showed anything (so the frame after the last marker goes clears it).
var _drawn: bool = false


## Draws `cues` on the ring `cfg` sets. Call once, as the HUD is built.
func setup(cues: SoundCues, cfg: AccessibilityConfig) -> void:
	_cues = cues
	_radius = cfg.cue_ring_radius
	name = "SoundCues"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## The markers' size (1 = as built) and colour.
func set_style(marker_scale: float, colour: Color) -> void:
	_paint.set_style(marker_scale, colour)
	queue_redraw()


## The eyes the view is through: at `ear`, looking `yaw` (Character's yaw). Redraws while a marker is up.
func follow(ear: Vector3, yaw: float) -> void:
	_ear = ear
	_yaw = yaw
	if visible and _cues != null and (_drawn or _cues.live_count() > 0):
		queue_redraw()


## The ring's middle and radius (px), for tests.
func ring_centre() -> Vector2:
	return size * 0.5


func ring_radius() -> float:
	return _radius


## Where `c` sits on the ring now (px).
func marker_point(c: SoundCues.Cue) -> Vector2:
	var b := SoundCues.bearing(_ear, c.at, _yaw)
	return ring_centre() + Vector2(sin(b), -cos(b)) * _radius


func painter() -> Painter:
	return _paint


func _draw() -> void:
	_drawn = false
	if _cues == null:
		return
	var strongest := 0.0
	for c in _cues.cues:
		strongest = maxf(strongest, _cues.opacity(c))
	if strongest <= 0.0:
		return
	_drawn = true
	_paint.ring(self, ring_centre(), _radius, strongest)
	for c in _cues.cues:
		var shade := _cues.opacity(c)
		if shade > 0.0:
			_paint.marker(self, c.kind, marker_point(c), SoundCues.bearing(_ear, c.at, _yaw), shade)


## Draws the cue markers and the ring as the concept does (its cueRing): the marker shapes at size 1 in px at 1080p,
## each with a dark edge outside its fill. Shapes are built once; a draw allocates nothing.
class Painter:
	extends RefCounted

	## The edges' ink and the ring's two strokes (a dark one under a light one) and their widths (px).
	const INK := Color(0.075, 0.075, 0.067, 0.85)
	const RING_SHADE := Color(0.075, 0.075, 0.067, 0.4)
	const RING_LINE := Color(1.0, 1.0, 1.0, 0.45)
	const RING_SHADE_WIDTH := 3.5
	const RING_LINE_WIDTH := 1.5
	const RING_POINTS := 96
	## A step: two dots either side of the ring's line, turned with the bearing; their radius and edge.
	const DOTS: Array[Vector2] = [Vector2(-4.5, -9.0), Vector2(4.5, 8.0)]
	const DOT_RADIUS := 6.0
	const DOT_EDGE := 1.2
	## A shot: an arrowhead pointing outwards, turned with the bearing, and its edge.
	const ARROW: Array[Vector2] = [Vector2(0.0, -15.0), Vector2(13.0, 12.0), Vector2(0.0, 5.5), Vector2(-13.0, 12.0)]
	const ARROW_EDGE := 1.3
	## A hit call: an upright tag with HIT on it (Inter 800, the concept's letter spacing) and its edge.
	const TAG := Rect2(-26.0, -13.0, 52.0, 26.0)
	const TAG_CORNER := 3.0
	const TAG_EDGE := 1.2
	const TAG_TEXT_SIZE := 16
	const TAG_BASELINE := 6.5
	const TAG_SPACING := 0.0875

	var marker_scale: float = 1.0
	var colour: Color = Color.RED

	var _word: String = ""
	var _word_ink: Color = GameTheme.TEXT
	var _font: Font = null
	var _font_size: int = TAG_TEXT_SIZE
	var _arrow := PackedVector2Array()
	var _arrow_edge := PackedVector2Array()
	var _tag := PackedVector2Array()
	var _tag_edge := PackedVector2Array()

	func _init() -> void:
		_word = HudStyle.caps("HUD_HIT_TAG")
		_arrow = PackedVector2Array(ARROW)
		_arrow_edge = _outline(_arrow, ARROW_EDGE * 0.5)
		var inner := TAG.grow(-TAG_CORNER)
		var box := PackedVector2Array([inner.position, Vector2(inner.end.x, inner.position.y), inner.end,
				Vector2(inner.position.x, inner.end.y)])
		_tag = Geometry2D.offset_polygon(box, TAG_CORNER, Geometry2D.JOIN_ROUND)[0]
		_tag_edge = _outline(box, TAG_CORNER + TAG_EDGE * 0.5)
		set_style(marker_scale, colour)

	## The markers' size (1 = as built) and colour.
	func set_style(new_scale: float, new_colour: Color) -> void:
		marker_scale = new_scale
		colour = new_colour
		_word_ink = HudStyle.ink_on(new_colour)
		_font_size = maxi(1, roundi(TAG_TEXT_SIZE * new_scale))
		_font = GameTheme.spaced_font(800, TAG_SPACING, _font_size)

	## The ring round `centre`, `radius` px out, at `strength` (0..1).
	func ring(ci: CanvasItem, centre: Vector2, radius: float, strength: float) -> void:
		ci.draw_arc(centre, radius, 0.0, TAU, RING_POINTS, Color(RING_SHADE, RING_SHADE.a * strength),
				RING_SHADE_WIDTH, true)
		ci.draw_arc(centre, radius, 0.0, TAU, RING_POINTS, Color(RING_LINE, RING_LINE.a * strength), RING_LINE_WIDTH,
				true)

	## A marker of `kind` at `at`, turned to `bearing` (radians clockwise from up; the HIT tag stays upright), at
	## `strength` (0..1).
	func marker(ci: CanvasItem, kind: SoundCues.Kind, at: Vector2, bearing: float, strength: float) -> void:
		var fill := Color(colour, colour.a * strength)
		var ink := Color(INK, INK.a * strength)
		var k := Vector2(marker_scale, marker_scale)
		match kind:
			SoundCues.Kind.STEP:
				ci.draw_set_transform(at, bearing, k)
				for p in DOTS:
					ci.draw_circle(p, DOT_RADIUS + DOT_EDGE * 0.5, ink, false, DOT_EDGE, true)
					ci.draw_circle(p, DOT_RADIUS, fill, true, -1.0, true)
			SoundCues.Kind.SHOT:
				ci.draw_set_transform(at, bearing, k)
				ci.draw_colored_polygon(_arrow, fill)
				ci.draw_polyline(_arrow_edge, ink, ARROW_EDGE, true)
			SoundCues.Kind.HIT:
				ci.draw_set_transform(at, 0.0, k)
				ci.draw_colored_polygon(_tag, fill)
				ci.draw_polyline(_tag_edge, ink, TAG_EDGE, true)
				# The word at its own size, not scaled up from 16 px.
				ci.draw_set_transform(at, 0.0, Vector2.ONE)
				ci.draw_string(_font, Vector2(TAG.position.x, TAG_BASELINE) * marker_scale, _word,
						HORIZONTAL_ALIGNMENT_CENTER, TAG.size.x * marker_scale, _font_size,
						Color(_word_ink, _word_ink.a * strength))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	## `shape` grown by `by` px with rounded corners, closed (its first point again at the end) for draw_polyline.
	static func _outline(shape: PackedVector2Array, by: float) -> PackedVector2Array:
		var out: PackedVector2Array = Geometry2D.offset_polygon(shape, by, Geometry2D.JOIN_ROUND)[0]
		out.append(out[0])
		return out
