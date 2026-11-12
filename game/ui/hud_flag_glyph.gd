class_name HudFlagGlyph
extends Control
## A small flag on its mast, the HUD's sign for Attack / Defend's flag (the approved concept's icon): a pale mast, the
## cloth in `colour` with a pale roundel. `chequered`, the sign for Elimination's overtime flag (concept
## `overtime-flag.png`): a square cloth of off-white and dark checks with a thin off-white edge. `bomb`, Plant The
## Bomb's sign (PB1): a small carry case with a handle and a light (BombShape), in `colour`. Drawn from shapes built
## once for its size, never per frame.

## The icon's drawing box: the concept's 24 x 24 viewbox.
const BOX := 24.0
const MAST := Rect2(4.0, 2.0, 2.6, 21.0)
const CLOTH: PackedVector2Array = [
	Vector2(6.6, 3.2), Vector2(10.0, 2.6), Vector2(13.5, 4.0), Vector2(17.0, 3.4), Vector2(20.5, 2.6),
	Vector2(19.2, 8.0), Vector2(20.5, 13.0), Vector2(17.0, 13.6), Vector2(13.5, 12.4), Vector2(10.0, 13.0),
	Vector2(6.6, 13.8),
]
const ROUNDEL := Vector2(12.2, 8.2)
const ROUNDEL_RADIUS := 2.1
const MAST_COLOUR := GameTheme.TEXT
const ROUNDEL_COLOUR := Color("f3efe2")
## The chequered cloth's box in the viewbox, its checks across and down, its edge (px at 24) and its colours (the
## overtime flag's off-white (238, 234, 224) and dark, as FlagViewConfig draws its cloth).
const CHECK_CLOTH := Rect2(6.6, 2.6, 15.6, 11.7)
const CHECKS := Vector2i(4, 3)
const CHECK_EDGE := 1.0
const CHECK_PALE := Color8(238, 234, 224)
const CHECK_DARK := Color8(38, 40, 44)

var colour: Color = GameTheme.WARN:
	set(value):
		if value != colour:
			colour = value
			queue_redraw()

## Drawn as the overtime flag's chequered cloth instead of the plain one.
var chequered: bool = false:
	set(value):
		if value != chequered:
			chequered = value
			queue_redraw()

## Drawn as Plant The Bomb's carry case instead of a flag.
var bomb: bool = false:
	set(value):
		if value != bomb:
			bomb = value
			queue_redraw()

var _case := BombShape.new()
var _cloth := PackedVector2Array()
var _checks: Array[Rect2] = []
var _check_box := Rect2()
var _check_edge: float = 0.0
var _dark_count: int = 0
var _mast := Rect2()
var _roundel := Vector2.ZERO
var _radius: float = 0.0


func _init(side: float, tint: Color) -> void:
	custom_minimum_size = Vector2(side, side)
	colour = tint
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cloth.resize(CLOTH.size())
	_checks.resize(CHECKS.x * CHECKS.y)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		var k := minf(size.x, size.y) / BOX
		_case.fit(Rect2(Vector2.ZERO, size))
		for i in CLOTH.size():
			_cloth[i] = CLOTH[i] * k
		_mast = Rect2(MAST.position * k, MAST.size * k)
		_roundel = ROUNDEL * k
		_radius = ROUNDEL_RADIUS * k
		_check_box = Rect2(CHECK_CLOTH.position * k, CHECK_CLOTH.size * k)
		_check_edge = CHECK_EDGE * k
		var cell := _check_box.size / Vector2(CHECKS)
		var n := 0
		for j in CHECKS.y:
			for i in CHECKS.x:
				if (i + j) % 2 == 1:
					_checks[n] = Rect2(_check_box.position + cell * Vector2(i, j), cell)
					n += 1
		_dark_count = n


func _draw() -> void:
	if bomb:
		_case.paint(self, colour, GameTheme.BAD, GameTheme.BG)
		return
	draw_rect(_mast, MAST_COLOUR)
	if chequered:
		draw_rect(_check_box, CHECK_PALE)
		for i in _dark_count:
			draw_rect(_checks[i], CHECK_DARK)
		draw_rect(_check_box, CHECK_PALE, false, _check_edge)
		return
	draw_colored_polygon(_cloth, colour)
	draw_circle(_roundel, _radius, ROUNDEL_COLOUR)
