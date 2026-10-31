class_name HudFlagMarker
extends Control
## Attack / Defend's marker over the pole (the approved concept): the flag sign, "FLAG" ("FLAG A" or "FLAG B" on a map
## with two poles, AB1) and the distance ("· 24 m") on a dark plate with a yellow top rule, and a tail pointing down at
## the pole. Seen through cover; kept inside the screen's edges; hidden within HudConfig.flag_marker_hide_within. With
## the pole off the screen's side or behind you it is pinned to that side instead (concept `minimap-attack.png`): a
## chevron pointing there, "FLAG · 7 M", on the left under the minimap and its caption so it never sits behind them.

const GAP := 8
const TAIL := Vector2(18.0, 11.0)
const RULE := 3
const PAD := Vector2i(14, 6)
## The pinned plate: its padding, the gap after its chevron, the plate's backing, the rule on top and the chevron's size.
const EDGE_PAD := Vector4i(15, 6, 15, 7)
const EDGE_GAP := 12
const EDGE_RULE := 2
const CHEVRON := Vector2(10.0, 16.0)
## The pinned plate's type size (the concept's 22).
const EDGE_SIZE := 22

## The HUD's size (Hud.set_hud_size): the view's screen points are divided by it, as the HUD's root is scaled by it.
var hud_size: float = 1.0
var _cfg: HudConfig = null
## The anchor's height over the foot (m): the pole's, or the overtime flag's.
var _height: float = 0.0
var _glyph: HudFlagGlyph = null
var _plate: PanelContainer = null
var _distance: Label = null
var _metres: int = -1
var _tail := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _edge: PanelContainer = null
var _edge_chevron: Chevron = null
var _edge_distance: Label = null
var _pinned: bool = false
var _side: int = 0 # where a pinned plate sits: -1 left, 1 right (0 while it is over the pole or hidden)
## Both plates' titles ("FLAG", or "FLAG A" on a map with two poles), and the letter they carry.
var _title: Label = null
var _edge_title: Label = null
var _letter: String = ""


## The chevron on a pinned plate: a yellow triangle pointing left or right.
class Chevron:
	extends Control

	var left: bool = true
	var _shape := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])

	func _init() -> void:
		custom_minimum_size = CHEVRON
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func point(towards_left: bool) -> void:
		if towards_left != left:
			left = towards_left
			queue_redraw()

	func _draw() -> void:
		var w := CHEVRON.x
		var h := CHEVRON.y
		_shape[0] = Vector2(0.0 if left else w, h * 0.5)
		_shape[1] = Vector2(w if left else 0.0, 0.0)
		_shape[2] = Vector2(w if left else 0.0, h)
		draw_colored_polygon(_shape, GameTheme.YELLOW)


func setup(cfg: HudConfig) -> void:
	_cfg = cfg
	_height = cfg.flag_marker_height
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_plate = PanelContainer.new()
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := HudStyle.panel_box(HudStyle.BACKING_CLOCK, PAD.x, PAD.y)
	box.border_color = GameTheme.YELLOW
	box.border_width_top = RULE
	_plate.add_theme_stylebox_override("panel", box)
	add_child(_plate)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_child(row)
	_glyph = HudFlagGlyph.new(HudStyle.MARKER_SIZE, GameTheme.YELLOW)
	_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_glyph)
	_title = HudStyle.label(row, HudStyle.MARKER_SIZE, 800, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT,
			HudStyle.SPACING_AIM)
	_title.text = HudStyle.caps("HUD_FLAG")
	_distance = HudStyle.label(row, HudStyle.MARKER_SIZE, 700, GameTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT,
			HudStyle.SPACING_AIM)
	_plate.resized.connect(_fit)
	_build_edge()


## The marker over Elimination's overtime flag: the chequered glyph, anchored HudConfig.overtime_marker_height over its
## foot.
func use_overtime() -> void:
	_glyph.chequered = true
	_height = _cfg.overtime_marker_height


## Whether the plate carries the overtime flag's chequered glyph, for tests.
func chequered() -> bool:
	return _glyph.chequered


## Places the marker over the pole at `pole` as seen by `camera`, inside `area` (the HUD's size); hidden when `show` is
## false or you stand within reach of it. With the pole off the screen's side or behind you the marker pins to that side,
## its top at `pin.y` and its edge `pin.x` from the screen's; on the right its top is `right_top` instead (below the
## hit feed when that is up there), since the left side's stack has nothing to do with what is on the right. A plate for
## the left whose bottom would pass `left_floor` (the bottom-left feed's top) goes to the right edge instead, its arrow
## still pointing left.
func place(camera: Camera3D, pole: Vector3, show: bool, area: Vector2, pin: Vector2, right_top: float,
		left_floor: float) -> void:
	var eye := camera.global_position
	var metres := roundi(Vector2(pole.x - eye.x, pole.z - eye.z).length())
	visible = show and metres >= _cfg.flag_marker_hide_within
	_side = 0
	if not visible:
		return
	if metres != _metres:
		_metres = metres
		_distance.text = tr("HUD_FLAG_DISTANCE") % metres
		_edge_distance.text = _distance.text.to_upper()
	var top := pole + Vector3.UP * _height
	var behind := camera.is_position_behind(top)
	var at := Vector2.ZERO if behind else camera.unproject_position(top) / hud_size
	var to_left := camera.global_basis.x.dot(top - eye) < 0.0 if behind else at.x < 0.0
	_set_pinned(behind or at.x < 0.0 or at.x > area.x)
	if _pinned:
		_edge_chevron.point(to_left)
		var plate := _edge.get_combined_minimum_size()
		var on_left := to_left and pin.y + plate.y <= left_floor
		var x := pin.x if on_left else area.x - pin.x - plate.x
		position = Vector2.ZERO
		_edge.position = Vector2(x, pin.y if on_left else right_top)
		_side = -1 if on_left else 1
		return
	var half := size.x * 0.5
	var edge := _cfg.flag_marker_edge
	at.x = clampf(at.x, edge + half, area.x - edge - half)
	at.y = clampf(at.y, edge + size.y, area.y - edge)
	position = Vector2(at.x - half, at.y - size.y)


## Names the pole `letter` on both plates ("FLAG A", AB1), or with "" just "FLAG"; the text changes only when the
## letter does.
func set_letter(letter: String) -> void:
	if letter == _letter:
		return
	_letter = letter
	_title.text = HudStyle.caps("HUD_FLAG") if letter.is_empty() else (tr("HUD_FLAG_NAMED") % letter).to_upper()
	_edge_title.text = _title.text


## Where a plate pinned to a side sits: -1 on the left, 1 on the right, 0 when it is not pinned (or hidden).
func pinned_side() -> int:
	return _side


## What the marker covers on the screen: the pinned plate, or the plate with its tail; empty while hidden.
func occupied() -> Rect2:
	if not visible:
		return Rect2()
	return Rect2(_edge.position, _edge.get_combined_minimum_size()) if _pinned else get_rect()


## The marker's words ("FLAG · 24 m"), or "" while it is hidden: for tests.
func text() -> String:
	if not visible:
		return ""
	return "%s %s" % [_title.text, _distance.text]


## The pinned plate: a chevron, "FLAG" and the distance, on a navy strip with a yellow rule on top.
func _build_edge() -> void:
	_edge = PanelContainer.new()
	_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := HudStyle.panel_box(HudStyle.BACKING_CLOCK, EDGE_PAD.x, EDGE_PAD.y)
	box.content_margin_right = EDGE_PAD.z
	box.content_margin_bottom = EDGE_PAD.w
	box.border_color = GameTheme.YELLOW
	box.border_width_top = EDGE_RULE
	_edge.add_theme_stylebox_override("panel", box)
	_edge.visible = false
	add_child(_edge)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", EDGE_GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edge.add_child(row)
	_edge_chevron = Chevron.new()
	row.add_child(_edge_chevron)
	_edge_title = HudStyle.label(row, EDGE_SIZE, 800, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT,
			HudStyle.SPACING_AIM)
	_edge_title.text = HudStyle.caps("HUD_FLAG")
	_edge_distance = HudStyle.label(row, EDGE_SIZE, 700, GameTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT,
			HudStyle.SPACING_AIM)


## Shows the pinned plate (`pinned`) or the plate with its tail.
func _set_pinned(pinned: bool) -> void:
	if pinned == _pinned:
		return
	_pinned = pinned
	_plate.visible = not pinned
	_edge.visible = pinned
	queue_redraw()


func _fit() -> void:
	var plate := _plate.size
	size = Vector2(plate.x, plate.y + TAIL.y)
	var mid := plate.x * 0.5
	_tail[0] = Vector2(mid - TAIL.x * 0.5, plate.y)
	_tail[1] = Vector2(mid + TAIL.x * 0.5, plate.y)
	_tail[2] = Vector2(mid, plate.y + TAIL.y)
	queue_redraw()


func _draw() -> void:
	if _pinned:
		return
	draw_colored_polygon(_tail, HudStyle.backing_on(self, HudStyle.BACKING_CLOCK))
