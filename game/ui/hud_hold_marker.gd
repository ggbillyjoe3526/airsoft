class_name HudHoldMarker
extends Control
## Hold here's marker (the approved concepts `hold-marker.png`, `hold-marker-edge.png`): "HOLD · 18 M" on a dark plate
## with a rule in your team's colour and a tail pointing down, over the middle of the spots your teammates hold, and a
## dashed ring on the floor under it. Seen through cover. Kept inside the screen's edge (a chevron on the side it is
## towards, no tail, no ring) when it is off screen or behind you, and clear of the flag marker's plate.

## Where the marker is: over the spot, or held at the left or right edge, or at the top or bottom.
enum Pin { NONE, LEFT, RIGHT, EDGE }

const GAP := 12
const TAIL := Vector2(20.0, 11.0)
const RULE := 2
const PAD := Vector2i(15, 6)
const PAD_BOTTOM := 7
const TEXT_SIZE := 22
const CHEVRON := Vector2(10.0, 16.0)
## The ring: its segments (every other one drawn, the dashes), the dash's width, and the dark halo's width and share.
const RING_SEGMENTS := 48
const RING_WIDTH := 3.0
const RING_ALPHA := 0.95
const RING_HALO := 7.0
const RING_HALO_ALPHA := 0.35
## The ring needs the spot this many radii ahead of you to draw, so no point of it is behind the camera.
const RING_AHEAD := 1.5

## Where a marker pinned at a side may sit (Hud fills it, the flag marker's stacks): `left` the top left of the left
## stack's next place and `right_top` the top of the right one, `floor_y` how low the left stack may reach, `step` the
## stack's pin step, `flag_side` the side the flag marker is pinned to (-1 left, 1 right, 0 neither), `flag` its
## rectangle and `panel` the minimap's. An empty `panel` and `flag` (the default) mean there are none.
class Slots:
	extends RefCounted

	var left := Vector2.ZERO
	var right_top: float = 0.0
	var floor_y: float = INF
	var step: float = 0.0
	var flag_side: int = 0
	var flag := Rect2()
	var panel := Rect2()


var pin: Pin = Pin.NONE

## The HUD's size (Hud.set_hud_size): the view's screen points are divided by it, as the HUD's root is scaled by it.
var hud_size: float = 1.0
var _cfg: HudConfig = null
var _colour := Color.WHITE
var _plate: PanelContainer = null
var _words: Label = null
var _left: Chevron = null
var _right: Chevron = null
var _ring: Ring = null
var _metres: int = -1
## Go there's (FM1: "GO · 30 M" while your teammates are on their way) rather than Hold here's words.
var _going: bool = false
var _tail := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _ring_ground := PackedVector3Array()


## The marker in `colour` (your team's), sized and kept by `cfg`. Hidden until place() shows it.
func setup(cfg: HudConfig, colour: Color) -> void:
	_cfg = cfg
	_colour = colour
	name = "HudHoldMarker"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_plate = PanelContainer.new()
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := HudStyle.panel_box(HudStyle.BACKING_CLOCK, PAD.x, PAD.y + RULE)
	box.content_margin_bottom = PAD_BOTTOM
	box.border_color = colour
	box.border_width_top = RULE
	_plate.add_theme_stylebox_override("panel", box)
	add_child(_plate)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_child(row)
	_left = Chevron.new(-1.0, colour)
	row.add_child(_left)
	_words = HudStyle.label(row, TEXT_SIZE, 800, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT, HudStyle.SPACING_BANNER)
	_right = Chevron.new(1.0, colour)
	row.add_child(_right)
	_left.visible = false
	_right.visible = false
	# The ring is drawn over the whole screen whatever the marker's own place is.
	_ring = Ring.new(colour)
	_ring.top_level = true
	add_child(_ring)
	_ring.visible = false
	_ring_ground.resize(RING_SEGMENTS + 1)
	for i in RING_SEGMENTS + 1:
		var a := TAU * i / RING_SEGMENTS
		_ring_ground[i] = Vector3(cos(a), 0.0, sin(a)) * cfg.hold_ring_radius


## Go there's words (`on`, FM1: your teammates on their way to a spot pinged) or Hold here's, from the next place().
func set_going(on: bool) -> void:
	if on != _going:
		_going = on
		_metres = -1


## Places the marker over the held spots' middle `spot` as seen by `camera`, inside `area` (the HUD's size); hidden when
## `show` is false. Held at the left or right it takes its place in that side's stack in `slots` (under the flag
## marker's plate when that is pinned there too; past the left stack's floor it goes to the right instead); never over
## the minimap's panel; held at the top or bottom it steps clear of the flag marker, below it, or above when there is
## no room below. `avoid` is the flag marker's rectangle (empty when hidden); without `slots` a marker held at a side is
## simply kept inside the screen.
func place(camera: Camera3D, spot: Vector3, show: bool, area: Vector2, avoid: Rect2, slots: Slots = null) -> void:
	visible = show
	if not show:
		return
	var eye := camera.global_position
	var metres := roundi(Vector2(spot.x - eye.x, spot.z - eye.z).length())
	if metres != _metres:
		_metres = metres
		_words.text = (tr("HUD_GO_MARKER" if _going else "HUD_HOLD_MARKER") % metres).to_upper()
	var top := spot + Vector3.UP * _cfg.hold_marker_height
	var at: Vector2
	var behind := camera.is_position_behind(top)
	if behind:
		var side := camera.global_basis.x.dot(top - eye)
		at = Vector2(area.x * (0.5 + 0.5 * signf(side)), area.y)
	else:
		at = camera.unproject_position(top) / hud_size
	# Where it sits decides its chevron and so its width: judged from the plain plate, the tail's height apart.
	var edge := _cfg.hold_marker_edge
	var plain := _measure(Pin.NONE)
	var was := pin
	if at.x < edge + plain.x * 0.5:
		pin = Pin.LEFT
	elif at.x > area.x - edge - plain.x * 0.5:
		pin = Pin.RIGHT
	elif behind or at.y < edge + plain.y + TAIL.y or at.y > area.y - edge:
		pin = Pin.EDGE
	else:
		pin = Pin.NONE
	var box := _fit(pin)
	if pin == Pin.NONE:
		position = Vector2(at.x - box.x * 0.5, at.y - box.y)
		if slots != null and get_rect().intersects(slots.panel):
			# over the map's panel: held beside it instead, no tail
			pin = Pin.EDGE
			box = _fit(pin)
			position = Vector2(slots.panel.end.x + _cfg.hold_marker_gap, at.y - box.y)
	elif slots != null and (pin == Pin.LEFT or pin == Pin.RIGHT):
		_stack(box, area, slots)
		if slots.flag_side == 0:
			_step_clear(avoid, area) # a flag marker over its pole near this edge is not in the stack
	else:
		at.x = clampf(at.x, edge + box.x * 0.5, area.x - edge - box.x * 0.5)
		at.y = clampf(at.y, edge + box.y, area.y - edge)
		position = Vector2(at.x - box.x * 0.5, at.y - box.y)
		if slots != null and get_rect().intersects(slots.panel):
			position.x = slots.panel.end.x + _cfg.hold_marker_gap
		_step_clear(avoid, area)
	if pin != was:
		queue_redraw()
	_place_ring(camera, spot, pin != Pin.NONE, area)


## The marker's words ("HOLD · 18 M"), or "" while it is hidden: for tests.
func text() -> String:
	return _words.text if visible else ""


## Whether the ring on the floor shows: for tests.
func ring_shown() -> bool:
	return visible and _ring.visible


func _draw() -> void:
	if pin == Pin.NONE:
		draw_colored_polygon(_tail, HudStyle.backing_on(self, HudStyle.BACKING_CLOCK))


## The plate's size with the chevron `held` calls for (none for NONE and EDGE: the tail comes under it instead).
func _measure(held: Pin) -> Vector2:
	var words := _words.get_combined_minimum_size()
	var chevron := CHEVRON.x + GAP if held == Pin.LEFT or held == Pin.RIGHT else 0.0
	return Vector2(words.x + chevron + PAD.x * 2.0, maxf(words.y, CHEVRON.y) + PAD.y + RULE + PAD_BOTTOM)


## Fits the marker to its plate with the chevron `held` calls for, and the tail under it when over the spot; the size it
## comes to.
func _fit(held: Pin) -> Vector2:
	_left.visible = held == Pin.LEFT
	_right.visible = held == Pin.RIGHT
	var plate := _measure(held)
	_plate.size = plate
	size = Vector2(plate.x, plate.y + (TAIL.y if held == Pin.NONE else 0.0))
	var mid := plate.x * 0.5
	_tail[0] = Vector2(mid - TAIL.x * 0.5, plate.y)
	_tail[1] = Vector2(mid + TAIL.x * 0.5, plate.y)
	_tail[2] = Vector2(mid, plate.y + TAIL.y)
	return size


## Held at a side: in that side's stack (see place()), the chevron still pointing the way the spot is.
func _stack(box: Vector2, area: Vector2, slots: Slots) -> void:
	var left := pin == Pin.LEFT
	var y := 0.0
	if left:
		y = slots.left.y
		if slots.flag_side < 0:
			y = maxf(y, slots.flag.position.y + slots.step)
		if y + box.y > slots.floor_y:
			left = false # the left stack would reach the feed
	if not left:
		y = slots.right_top
		if slots.flag_side > 0:
			y = maxf(y, slots.flag.position.y + slots.step)
	# in line with the flag's plates in the same stack
	var inset := slots.left.x
	position = Vector2(inset if left else area.x - inset - box.x, maxf(y, _cfg.hold_marker_edge))


## Held at the edge: moves clear of `avoid` (the flag marker), below it when it fits, else above.
func _step_clear(avoid: Rect2, area: Vector2) -> void:
	if not avoid.has_area() or not get_rect().intersects(avoid.grow(_cfg.hold_marker_gap * 0.5)):
		return
	var y := avoid.end.y + _cfg.hold_marker_gap
	if y + size.y > area.y - _cfg.hold_marker_edge:
		y = avoid.position.y - _cfg.hold_marker_gap - size.y
	position.y = y


## The ring on the floor round `spot`, while the marker is over it and the spot is well ahead of the camera.
func _place_ring(camera: Camera3D, spot: Vector3, held: bool, area: Vector2) -> void:
	var ahead := -camera.global_basis.z.dot(spot - camera.global_position)
	if held or ahead < _cfg.hold_ring_radius * RING_AHEAD:
		_ring.visible = false
		return
	_ring.visible = true
	# The ring is top level, so it takes the HUD's size itself: its points in the HUD's px, its line grown as the
	# other markers' are.
	_ring.scale = Vector2.ONE * hud_size
	_ring.size = area
	_ring.position = Vector2.ZERO
	for i in RING_SEGMENTS + 1:
		_ring.points[i] = camera.unproject_position(spot + _ring_ground[i]) / hud_size
	_ring.queue_redraw()


## The chevron beside the words of a marker held at an edge: pointing `way` (-1 left, 1 right).
class Chevron:
	extends Control

	var _way: float = 1.0
	var _colour := Color.WHITE

	func _init(way: float, colour: Color) -> void:
		_way = way
		_colour = colour
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = CHEVRON
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _draw() -> void:
		var tip := CHEVRON.x if _way > 0.0 else 0.0
		var back := CHEVRON.x - tip
		draw_colored_polygon(PackedVector2Array([Vector2(back, 0.0), Vector2(tip, CHEVRON.y * 0.5),
				Vector2(back, CHEVRON.y)]), _colour)


## The dashed ring: `points` (screen px, closed) drawn as a dark halo and then every other segment in the team colour.
class Ring:
	extends Control

	var points := PackedVector2Array()
	var _colour := Color.WHITE

	func _init(colour: Color) -> void:
		_colour = colour
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		points.resize(RING_SEGMENTS + 1)

	func _draw() -> void:
		draw_polyline(points, Color(GameTheme.BG, RING_HALO_ALPHA), RING_HALO, true)
		var ink := Color(_colour, RING_ALPHA)
		for i in range(0, RING_SEGMENTS, 2):
			draw_line(points[i], points[i + 1], ink, RING_WIDTH, true)
