class_name OrderWheelPointer
extends RefCounted
## The order wheel's own pointer (CW1; M23 and the browser game's input/orderWheel.ts before it): while the wheel is
## open the mouse moves this instead of the view. It starts in the middle, on Spotted, each time the wheel opens, and
## moves over the wheel's drawing itself (OrderWheelLayout, px of the HUD's 1920 x 1080 layout from the middle, y
## down), kept on the wheel's buttons, so a big flick still lands on one. It knows when it opened, so a tap of the key
## (ControlsConfig.wheel_tap) is told from a hold. Plain state and math; PlayerInput feeds it, the HUD draws it.
## Allocates nothing.

## On nothing, and on Spotted (the circle in the middle).
const NONE := OrderWheelLayout.NONE
const SPOT := OrderWheelLayout.SPOT

var open: bool = false
var at: Vector2 = Vector2.ZERO
## When it last opened (ms, Time.get_ticks_msec).
var opened_ms: int = 0
var layout: OrderWheelLayout = null


## A pointer over `layout`'s wheel (none: every point is on nothing).
func _init(wheel_layout: OrderWheelLayout = null) -> void:
	layout = wheel_layout


## Opens in the middle, on Spotted, at `now_ms` (ms, Time.get_ticks_msec).
func start(now_ms: int = 0) -> void:
	open = true
	at = Vector2.ZERO
	opened_ms = now_ms


## Moves the pointer by `delta` px, kept on the wheel.
func move(delta: Vector2) -> void:
	at = layout.keep(at + delta) if layout != null else at + delta


## What the pointer is on: a button (an index into the wheel's orders), SPOT, or NONE (closed, or between the columns).
func pick() -> int:
	if not open or layout == null:
		return NONE
	return layout.pick(at)


## Whether the wheel, open since opened_ms, is held past a tap at `now_ms` (`tap`: s): then it is drawn, and letting
## go is no tap. Where the pointer went meanwhile doesn't count (BP9): a mouse following someone leaves the circle in
## less than a tap.
func held(now_ms: int, tap: float) -> bool:
	return open and now_ms - opened_ms >= roundi(tap * 1000.0)


## Closed, back in the middle.
func close() -> void:
	open = false
	at = Vector2.ZERO
