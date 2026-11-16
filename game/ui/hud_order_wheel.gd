class_name HudOrderWheel
extends Control
## The order wheel (CW1, owner 2026-11-15, after Battlefield's commo rose) round the crosshair while the wheel's key is
## held: Spotted in a circle in the middle and two columns of equal buttons beside it (OrderWheelLayout, from
## ControlsConfig), each with its name alone, the one the pointer is on lit, the order in force banded in your team's
## colour on its outer edge, the pointer a white dot. A button kept free is drawn empty and faint, and never lit. Drawn only once
## the key is held past a tap (OrderWheelPointer.held), wherever the pointer went meanwhile (BP9), so a tap that spots
## never flashes it up. A notice (nobody to order, back on the team plan) shows in the circle, dimming the rest, for
## HudConfig.order_notice_time; there is no order text anywhere else. The notice of an order that ended by itself
## (SquadOrders.Outcome.news: its last carrier hit, you walked away from it, all quiet) shows in the circle alone
## with the wheel shut (BP9). Built on its first showing and drawn only while
## up: shut, it does nothing and a frame costs a comparison. Need a Mag (MH3) reads Toss a Mag while a toss is in reach
## (set_mag_toss), and a refusal of the hand-off picked on the wheel shows in the circle as an order's notice does
## (tell).

## Nothing worked out yet (the lit button and the banded one, before the first frame open).
const UNSET := -3
## The buttons' strokes (px) plain and lit, how much paler than the accent the lit edge is, the fill's alpha, the corner
## radius, and a free button's fill alpha.
const STROKE := 2.0
const LIT_STROKE := 3.0
const LIT_EDGE_LIGHTEN := 0.6
const BUTTON_ALPHA := 0.86
const RADIUS := 4
const FREE_ALPHA := 0.35
## The band on the order in force (px, along the button's outer edge).
const BAND := 7.0
## The circle: its fill's alpha open and with a notice up, and the notice's accent rule (px).
const HUB_ALPHA := 0.6
const NOTICE_ALPHA := 0.96
const NOTICE_RULE := 3.0
const CIRCLE_STEPS := 64
## What lies behind the wheel: a dark that fades out to the radius `SCRIM_RADII` ends at, its darkest share and the
## texture (px) it is baked into.
const SCRIM := GameTheme.BG
const SCRIM_RADII := Vector3(300.0, 400.0, 470.0)
const SCRIM_ALPHAS := Vector2(0.32, 0.12)
const SCRIM_BAKE := 128
## The words: a button's name (type size, letter spacing in em) and the room it keeps from the button's ends (px),
## Spotted's name in the circle, how far the words dim under a notice, and the notice's type size and side padding.
const NAME_SIZE := 22
const NAME_SPACING := 0.05
const NAME_PAD := 14.0
const SPOT_SIZE := 18
const DIM := 0.55
const NOTICE_SIZE := 16
const NOTICE_PAD := 14.0
## The pointer: its dot, the dark ring round it and the pale halo round that (px).
const POINTER_DOT := 6.0
const POINTER_RING := 9.0
const POINTER_HALO := 11.0
const POINTER_HALO_ALPHA := 0.6

var _cfg: HudConfig = null
var _controls: ControlsConfig = null
var _layout: OrderWheelLayout = null
var _colour := Color.WHITE
var _built: bool = false
var _names := PackedStringArray()
var _spot_name: String = ""
var _scrim: GradientTexture2D = null
var _name_font: Font = null
var _button := StyleBoxFlat.new()
var _pointer: Pointer = null
var _notice: Label = null
var _lit: int = UNSET
var _force: int = UNSET
var _showing_notice: bool = false
var _notice_left: float = 0.0
var _serial: int = 0
## The wheel was up last frame, and on a button then; how long (s) a pick that shut it still waits for its answer; and
## the wheel is up with only a notice (an order picked on it, which shut it as it was picked).
var _was_open: bool = false
var _on_slice: bool = false
var _wait_left: float = 0.0
var _notice_only: bool = false
## The button of Need a Mag (-1: the wheel has none), its two names as drawn (asking, tossing), whether it reads the
## second, and a notice told (tell) and not shown yet.
var _mag_slice: int = -1
var _mag_names := PackedStringArray(["", ""])
var _mag_toss: bool = false
var _told: String = ""


## A wheel for `controls`' orders in `colour` (your team's), timed by `cfg`. Builds nothing until it first shows.
func setup(cfg: HudConfig, controls: ControlsConfig, colour: Color) -> void:
	_cfg = cfg
	_controls = controls
	_colour = colour
	name = "HudOrderWheel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	# While it is up it hides itself under the pause menu, which stops the HUD's own updates.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


## Each frame: `wheel` (the pointer PlayerInput moves), `in_force` (the order your teammates carry out, NONE for the team
## plan), `outcome` (the last order given, for its notice) and `you` (your character's id), `delta` seconds on;
## `now_ms` (Time.get_ticks_msec, by default now) tells a tap from a hold.
func update(wheel: OrderWheelPointer, in_force: SquadOrder.Kind, outcome: SquadOrders.Outcome, you: int,
		delta: float, now_ms: int = -1) -> void:
	var told := outcome.serial != _serial and outcome.giver == you and outcome.notice != SquadOrders.Notice.NONE
	var news := told and outcome.news
	_serial = outcome.serial
	var words := ""
	if told:
		words = tr(notice_key(outcome.notice))
	if not _told.is_empty():
		words = _told
		_told = ""
		told = true
	# A notice for you while it is open (an order key pressed with it held) shows it at once, tap or not.
	var shown := wheel.held(Time.get_ticks_msec() if now_ms < 0 else now_ms, _controls.wheel_tap) or (told and wheel.open)
	if not shown and not (_was_open and wheel.open):
		_closed(told, words, delta, news)
		return
	_was_open = true
	var pick := wheel.pick()
	_on_slice = pick >= 0
	if not visible or _notice_only:
		_open()
	if told:
		_show_notice(words)
	elif _showing_notice:
		_notice_left -= delta
		if _notice_left <= 0.0:
			_clear_notice()
	var lit := OrderWheelPointer.NONE if _showing_notice or not _pickable(pick) else pick
	var force := -1 if _showing_notice else _index_of(in_force)
	if lit != _lit or force != _force:
		_lit = lit
		_force = force
		queue_redraw()
	# In Spotted's circle the lit circle is the pointer: the dot would sit on its name.
	_pointer.visible = not _showing_notice and pick != OrderWheelPointer.SPOT
	_pointer.position = wheel.at - Vector2.ONE * POINTER_HALO


## A notice of the hand-off's (a refusal of Need a Mag picked on the wheel; HudMagLine.refusal_text) for the circle,
## shown on the next update as an order's notice is.
func tell(words: String) -> void:
	_told = words


## Need a Mag reads Toss a Mag (`on`) or Need a Mag; redrawn only when it changes while up.
func set_mag_toss(on: bool) -> void:
	if on == _mag_toss:
		return
	_mag_toss = on
	if _built and _mag_slice >= 0:
		_names[_mag_slice] = _mag_names[1 if on else 0]
		if visible:
			queue_redraw()


## Puts the wheel away at once (the pause menu opening): nothing stays up, no notice is owed.
func dismiss() -> void:
	_was_open = false
	_on_slice = false
	_wait_left = 0.0
	_notice_only = false
	_clear_notice()
	visible = false
	set_process(false)


func _process(_delta: float) -> void:
	if get_tree().paused:
		dismiss()


## A frame with the wheel shut (or held no longer than a tap). Just shut on a button, it waits order_notice_wait for
## the notice of the order it was shut by: one that comes shows alone in the circle for order_notice_time, then goes;
## none, or shut on nothing, and it goes at once. `news` (an order that ended by itself, SquadOrders.Outcome.news)
## shows the same way whenever it comes: you asked nothing, so nothing else would tell you (BP9). A key's own answer
## with the wheel shut still shows nothing (SO4).
func _closed(told: bool, words: String, delta: float, news: bool) -> void:
	if _was_open:
		var on_slice := _on_slice
		dismiss()
		_wait_left = _cfg.order_notice_wait if on_slice else 0.0
	elif _wait_left > 0.0:
		_wait_left -= delta
	if told and (news or _wait_left > 0.0):
		_wait_left = 0.0
		_open()
		_notice_only = true
		_lit = OrderWheelPointer.NONE
		_force = -1
		_show_notice(words)
		_pointer.visible = false
	elif _notice_only:
		_notice_left -= delta
		if _notice_left <= 0.0:
			dismiss()


## The notice's words for `notice` (a translation key), or "" for none.
static func notice_key(notice: SquadOrders.Notice) -> String:
	match notice:
		SquadOrders.Notice.CANCELLED:
			return "HUD_ORDER_CANCELLED"
		SquadOrders.Notice.ON_PLAN:
			return "HUD_ORDER_ON_PLAN"
		SquadOrders.Notice.NOBODY:
			return "HUD_ORDER_NOBODY"
		SquadOrders.Notice.NOT_NOW:
			return "HUD_ORDER_NOT_NOW"
		SquadOrders.Notice.NOWHERE:
			return "HUD_ORDER_NOWHERE"
		SquadOrders.Notice.QUIET:
			return "HUD_ORDER_QUIET"
	return ""


## The lit button's and circle's edge: the accent, paler (UA2: it follows the interface colour).
static func lit_edge() -> Color:
	return GameTheme.accent.lightened(LIT_EDGE_LIGHTEN)


## The button lit now (an index into the wheel's orders; OrderWheelPointer.SPOT for Spotted; -1 none), for tests.
func lit_slice() -> int:
	return _lit if visible and _lit != UNSET else -1


## The button banded as the order in force (-1 none), for tests.
func banded_slice() -> int:
	return _force if visible and _force != UNSET else -1


## The button's name as drawn ("" for a free one), for tests.
func slice_name(i: int) -> String:
	return _names[i] if _built and i >= 0 and i < _names.size() else ""


## Spotted's name as drawn in the circle, for tests.
func spot_name() -> String:
	return _spot_name


## Whether button `i`'s name fits inside it at full size (NAME_PAD clear of each end), for tests.
func name_fits(i: int) -> bool:
	if not _built or i < 0 or i >= _names.size():
		return false
	var wide := _name_font.get_string_size(_names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE).x
	return wide <= _layout.box(i).size.x - NAME_PAD * 2.0


## The notice's words while one shows, else "", for tests.
func notice_text() -> String:
	return _notice.text if _showing_notice else ""


## Whether the wheel's parts have been built, for tests.
func built() -> bool:
	return _built


## Whether the buttons are drawn (the wheel up, not only a notice), for tests.
func draws_wheel() -> bool:
	return _built and visible and not _notice_only


func _draw() -> void:
	if not _built:
		return
	if not draws_wheel():
		_draw_hub()
		return
	var far := SCRIM_RADII.z
	draw_texture_rect(_scrim, Rect2(-far, -far, far * 2.0, far * 2.0), false)
	var back := HudStyle.backing_on(self, BUTTON_ALPHA)
	for i in _names.size():
		_draw_button(i, back)
	_draw_hub()


## Button `i`: its box, lit or plain (or only a faint outline when free), the band of the order in force, its name.
func _draw_button(i: int, back: Color) -> void:
	var box := _layout.box(i)
	var fade := DIM if _showing_notice else 1.0
	if _names[i].is_empty():
		_button.bg_color = HudStyle.backing_on(self, FREE_ALPHA)
		_button.border_color = GameTheme.LINE
		_button.set_border_width_all(roundi(STROKE))
		draw_style_box(_button, box)
		return
	var lit := i == _lit
	_button.bg_color = GameTheme.accent if lit else back
	_button.border_color = lit_edge() if lit else GameTheme.LINE
	_button.set_border_width_all(roundi(LIT_STROKE if lit else STROKE))
	draw_style_box(_button, box)
	if i == _force:
		var outer := box.end.x - BAND if box.position.x > 0.0 else box.position.x
		draw_rect(Rect2(outer, box.position.y, BAND, box.size.y), _colour)
	var ink := Color(GameTheme.accent_ink if lit else GameTheme.TEXT, fade)
	var size := NAME_SIZE
	var room := box.size.x - NAME_PAD * 2.0
	var wide := _name_font.get_string_size(_names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE).x
	if wide > room:
		size = floori(NAME_SIZE * room / wide)
	var base := box.position.y + (box.size.y - _name_font.get_height(size)) * 0.5 + _name_font.get_ascent(size)
	draw_string(_name_font, Vector2(box.position.x + NAME_PAD, base), _names[i], HORIZONTAL_ALIGNMENT_CENTER, room,
			size, ink)


## Spotted's circle, lit while the pointer is in it; ruled while it tells a notice (and its name hidden); see-through
## when the wheel is shut and it only tells you.
func _draw_hub() -> void:
	var r := _layout.centre
	var lit := _lit == OrderWheelPointer.SPOT and not _showing_notice
	var alpha := NOTICE_ALPHA if _showing_notice and not _notice_only else HUB_ALPHA
	draw_circle(Vector2.ZERO, r, GameTheme.accent if lit else HudStyle.backing_on(self, alpha))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, CIRCLE_STEPS, lit_edge() if lit else GameTheme.LINE,
			LIT_STROKE if lit else STROKE, true)
	if _showing_notice:
		draw_arc(Vector2.ZERO, r - NOTICE_RULE * 0.5, 0.0, TAU, CIRCLE_STEPS, GameTheme.accent, NOTICE_RULE, true)
		return
	if not draws_wheel():
		return
	var ink := GameTheme.accent_ink if lit else GameTheme.TEXT
	var base := (_name_font.get_ascent(SPOT_SIZE) - _name_font.get_descent(SPOT_SIZE)) * 0.5
	draw_string(_name_font, Vector2(-r, base), _spot_name, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, SPOT_SIZE, ink)


## Opens: builds the parts the first time, and reads the names as they are now.
func _open() -> void:
	if not _built:
		_build()
	for i in _names.size():
		var key := _controls.wheel_labels[i] if i < _controls.wheel_labels.size() else ""
		_names[i] = tr(key).to_upper() if not key.is_empty() else ""
	_spot_name = tr(_controls.wheel_spot_label).to_upper()
	if _mag_slice >= 0:
		_mag_names[0] = _names[_mag_slice]
		_mag_names[1] = tr(_controls.wheel_mag_toss).to_upper()
		_names[_mag_slice] = _mag_names[1 if _mag_toss else 0]
	_lit = UNSET
	_force = UNSET
	_clear_notice()
	_notice_only = false
	visible = true
	set_process(true)
	queue_redraw()


func _build() -> void:
	_built = true
	_layout = OrderWheelLayout.new(_controls)
	_names.resize(mini(_controls.wheel_orders.size(), _layout.count))
	_mag_slice = _controls.wheel_orders.find(SquadOrder.Kind.MAG)
	if _mag_slice >= _names.size():
		_mag_slice = -1
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, SCRIM_RADII.x / SCRIM_RADII.z, SCRIM_RADII.y / SCRIM_RADII.z, 1.0])
	gradient.colors = PackedColorArray([Color(SCRIM, SCRIM_ALPHAS.x), Color(SCRIM, SCRIM_ALPHAS.x),
			Color(SCRIM, SCRIM_ALPHAS.y), Color(SCRIM, 0.0)])
	_scrim = GradientTexture2D.new()
	_scrim.gradient = gradient
	_scrim.fill = GradientTexture2D.FILL_RADIAL
	_scrim.fill_from = Vector2(0.5, 0.5)
	_scrim.fill_to = Vector2(1.0, 0.5)
	_scrim.width = SCRIM_BAKE
	_scrim.height = SCRIM_BAKE
	_name_font = GameTheme.spaced_font(800, NAME_SPACING, NAME_SIZE)
	_button.set_corner_radius_all(RADIUS)
	_button.anti_aliasing = true
	var r := _layout.centre
	_notice = HudStyle.label(self, NOTICE_SIZE, 800, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.position = Vector2(-r + NOTICE_PAD, -r)
	_notice.size = Vector2(r * 2.0 - NOTICE_PAD * 2.0, r * 2.0)
	_notice.visible = false
	_pointer = Pointer.new()
	add_child(_pointer)


## Whether `pick` is something to light: Spotted, or a button with an order on it.
func _pickable(pick: int) -> bool:
	if pick == OrderWheelPointer.SPOT:
		return true
	return pick >= 0 and pick < _names.size() and not _names[pick].is_empty()


func _show_notice(words: String) -> void:
	if words.is_empty():
		return
	_notice.text = words
	_notice.visible = true
	_showing_notice = true
	_notice_left = _cfg.order_notice_time
	queue_redraw()


func _clear_notice() -> void:
	_notice_left = 0.0
	if _showing_notice:
		_showing_notice = false
		_notice.visible = false
		queue_redraw()


## Which of the wheel's buttons is `kind` (-1 for none, or one the wheel doesn't have).
func _index_of(kind: SquadOrder.Kind) -> int:
	if kind == SquadOrder.Kind.NONE:
		return -1
	var i := _controls.wheel_orders.find(kind)
	return i if i < _names.size() else -1


## The pointer: a white dot in a dark ring in a pale halo.
class Pointer:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2.ONE * POINTER_HALO * 2.0

	func _draw() -> void:
		var mid := size * 0.5
		draw_arc(mid, POINTER_RING + 1.0, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, POINTER_HALO_ALPHA), 2.0, true)
		draw_circle(mid, POINTER_RING, GameTheme.BG)
		draw_circle(mid, POINTER_DOT, Color.WHITE)
