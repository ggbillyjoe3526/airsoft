class_name OrderWheelLayout
extends RefCounted
## The order wheel's shape (CW1, owner 2026-11-15): Spotted's circle in the middle and two columns of equal buttons
## beside it, the right column's first (top to bottom), then the left's, from ControlsConfig's wheel_* numbers. One
## shape for both sides of it: OrderWheelPointer picks with it, HudOrderWheel draws with it, so the button under the
## pointer's dot is the one given. Positions are px of the HUD's 1920 x 1080 layout from the middle, y down. Made once
## a wheel; asking it allocates nothing.

## On nothing, and on Spotted (the circle in the middle).
const NONE := -1
const SPOT := -2

## The buttons a column, how many in all, and the circle's radius.
var rows: int = 0
var count: int = 0
var centre: float = 0.0
## Each button's box, by index (right column top to bottom, then the left).
var _boxes: Array[Rect2] = []
var _pitch: float = 0.0
var _strip: float = 0.0
var _half: Vector2 = Vector2.ZERO


## The shape `controls` sets out.
func _init(controls: ControlsConfig) -> void:
	rows = maxi(controls.wheel_rows, 1)
	count = rows * 2
	centre = controls.wheel_centre
	_pitch = controls.wheel_row_pitch
	_strip = controls.wheel_strip
	var button := controls.wheel_button
	var top := -(_pitch * (rows - 1) + button.y) * 0.5
	var mid := (rows - 1) * 0.5
	var widest := 0.0
	for side in 2:
		for row in rows:
			# The rows nearest the middle line sit furthest out: the columns bow round the circle.
			var out := controls.wheel_column_gap + controls.wheel_column_bow * (1.0 - absf(row - mid) / maxf(mid, 1.0))
			widest = maxf(widest, out + button.x)
			var x := out if side == 0 else -out - button.x
			_boxes.append(Rect2(Vector2(x, top + row * _pitch), button))
	_half = Vector2(widest, -top)


## Button `i`'s box (an empty one for an index it doesn't have).
func box(i: int) -> Rect2:
	return _boxes[i] if i >= 0 and i < _boxes.size() else Rect2()


## Half the wheel's width and height round the middle: the pointer stays inside it.
func half_extent() -> Vector2:
	return _half


## What the point `p` is on: SPOT inside the circle; NONE straight above or below it, between the columns; otherwise
## the button of its row (by height, the end rows reaching on past the column's ends) on its side.
func pick(p: Vector2) -> int:
	if p.length() <= centre:
		return SPOT
	if absf(p.x) < _strip or count == 0:
		return NONE
	var row := clampi(floori((p.y + rows * _pitch * 0.5) / _pitch), 0, rows - 1)
	return row if p.x > 0.0 else rows + row


## `p` kept inside the wheel's box.
func keep(p: Vector2) -> Vector2:
	return p.clamp(-_half, _half)
