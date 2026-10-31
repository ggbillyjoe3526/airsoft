class_name HudOrderWheel
extends Control
## The order wheel (the approved concepts `wheel-open.png`, `wheel-notice.png`) round the crosshair while the wheel's key
## is held: a ring of slices clockwise from the top, one for each of ControlsConfig.wheel_orders, each with its name and
## its key, the one the pointer is on lit yellow, the order in force banded in your team's colour and tagged ACTIVE, the
## pointer a white dot. A notice (nobody to order, back on the team plan) shows in the middle, dimming the rest, for
## HudConfig.order_notice_time; there is no order text anywhere else. Built on its first opening and drawn only while
## open: closed, it does nothing and a frame costs a comparison. The pointer's move is OrderWheelPointer's (px of mouse
## from the middle); this maps it onto the drawing (pointer_at). Need a Mag (MH3) reads Toss a Mag while a toss is in
## reach (set_mag_toss), and a refusal of the hand-off picked on the wheel shows in the middle as an order's notice does
## (tell).

## Each slice's edge, in segments of its arc, and the strokes (px) of an ordinary and of the lit slice's.
const ARC_STEPS := 28
const STROKE := 2.0
const LIT_STROKE := 3.0
const LIT_EDGE := Color("ffe28a")
const SLICE_ALPHA := 0.86
## The hub in the middle: the gap between it and the ring (px), its fill's alpha open and with a notice up, the notice's
## yellow rule (px), the band on the order in force (px, along the ring's outer edge).
const HUB_GAP := 8.0
const HUB_ALPHA := 0.22
const NOTICE_ALPHA := 0.96
const NOTICE_RULE := 3.0
const BAND := 9.0
## What lies behind the wheel: a dark that fades out to the radius `SCRIM_RADII` ends at, its darkest share and the
## texture (px) it is baked into.
const SCRIM := Color("080d18")
const SCRIM_RADII := Vector3(360.0, 470.0, 540.0)
const SCRIM_ALPHAS := Vector2(0.3, 0.1)
const SCRIM_BAKE := 128
## The words: a slice's name, its key's chip and the ACTIVE tag (type sizes, letter spacing in em, padding in px), the
## room a slice's words are given, how far the words dim under a notice, and the notice's type size and side padding.
const NAME_SIZE := 24
const NAME_SPACING := 0.05
const KEY_SIZE := 17
const KEY_PAD := Vector2(10.0, 3.0)
## Room (px) a key chip keeps for its border, added to its padding.
const KEY_EDGE := 3.0
const KEY_MIN := 34.0
const KEY_RADIUS := 4
const TAG_SIZE := 12
const TAG_SPACING := 0.1
const TAG_PAD := Vector4(9.0, 2.0, 9.0, 3.0)
const TAG_RADIUS := 3
const TAG_LOWER := 6.0
const SLICE_BOX := Vector2(190.0, 96.0)
const WORDS_GAP := 8.0
const NO_KEY_HEIGHT := 28.0
const DIM := 0.55
const NOTICE_SIZE := 23
const NOTICE_PAD := 22.0
## The pointer: its dot, the dark ring round it and the pale halo round that (px).
const POINTER_DOT := 7.0
const POINTER_RING := 10.0
const POINTER_HALO := 12.0
const POINTER_HALO_ALPHA := 0.6

var _cfg: HudConfig = null
var _controls: ControlsConfig = null
var _colour := Color.WHITE
var _built: bool = false
var _slices: Array[PackedVector2Array] = []
var _outlines: Array[PackedVector2Array] = []
var _bands: Array[PackedVector2Array] = []
var _label_at := PackedVector2Array()
var _names := PackedStringArray()
var _keys := PackedStringArray()
var _hub: float = 0.0
var _scrim: GradientTexture2D = null
var _name_font: Font = null
var _key_font: Font = null
var _tag_font: Font = null
var _tag_text: String = ""
var _chip := StyleBoxFlat.new()
var _tag := StyleBoxFlat.new()
var _pointer: Pointer = null
var _notice: Label = null
var _lit: int = -2
var _force: int = -2
var _showing_notice: bool = false
var _notice_left: float = 0.0
var _serial: int = 0
## The wheel was open last frame, and pointed at a slice then; how long (s) a pick that shut it still waits for its
## answer; and the wheel is up with only a notice (an order picked on it, which shut it as it was picked).
var _was_open: bool = false
var _on_slice: bool = false
var _wait_left: float = 0.0
var _notice_only: bool = false
## The slice of Need a Mag (-1: the wheel has none), its two names as drawn (asking, tossing), whether it reads the
## second, and a notice told (tell) and not shown yet.
var _mag_slice: int = -1
var _mag_names := PackedStringArray(["", ""])
var _mag_toss: bool = false
var _told: String = ""


## A wheel for `controls`' orders in `colour` (your team's), sized by `cfg`. Builds nothing until it first opens.
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
## plan), `outcome` (the last order given, for its notice) and `you` (your character's id), `delta` seconds on.
func update(wheel: OrderWheelPointer, in_force: SquadOrder.Kind, outcome: SquadOrders.Outcome, you: int,
		delta: float) -> void:
	var told := outcome.serial != _serial and outcome.giver == you and outcome.notice != SquadOrders.Notice.NONE
	_serial = outcome.serial
	var words := ""
	if told:
		words = tr(notice_key(outcome.notice))
	if not _told.is_empty():
		words = _told
		_told = ""
		told = true
	if not wheel.open:
		_closed(told, words, delta)
		return
	_was_open = true
	_on_slice = wheel.pick() != OrderWheelPointer.NONE
	if not visible or _notice_only:
		_open()
	if told:
		_show_notice(words)
	elif _showing_notice:
		_notice_left -= delta
		if _notice_left <= 0.0:
			_clear_notice()
	var lit := OrderWheelPointer.NONE if _showing_notice else wheel.pick()
	var force := -1 if _showing_notice else _index_of(in_force)
	if lit != _lit or force != _force:
		_lit = lit
		_force = force
		queue_redraw()
	_pointer.visible = not _showing_notice
	_pointer.position = pointer_at(wheel.at, _controls.wheel_dead_zone, _controls.wheel_reach, _hub,
			_cfg.wheel_pointer_reach) - Vector2.ONE * POINTER_HALO


## A notice of the hand-off's (a refusal of Need a Mag picked on the wheel; HudMagLine.refusal_text) for the middle,
## shown on the next update as an order's notice is.
func tell(words: String) -> void:
	_told = words


## Need a Mag reads Toss a Mag (`on`) or Need a Mag; redrawn only when it changes while open.
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


## A frame with the wheel shut. Just shut on a slice, it waits order_notice_wait for the notice of the order it was
## shut by: one that comes shows alone in the hub for order_notice_time, then goes; none, or shut on nothing, and it goes
## at once.
func _closed(told: bool, words: String, delta: float) -> void:
	if _was_open:
		var on_slice := _on_slice
		dismiss()
		_wait_left = _cfg.order_notice_wait if on_slice else 0.0
	elif _wait_left > 0.0:
		_wait_left -= delta
	if told and _wait_left > 0.0:
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


## Where the pointer is drawn (px from the middle) for the mouse's `at` (px from the middle): in step with the hub while
## inside the dead zone `dead`, then out to `far` as it goes from there to `reach`, in the same direction.
static func pointer_at(at: Vector2, dead: float, reach: float, hub: float, far: float) -> Vector2:
	var d := at.length()
	if d <= 0.0:
		return Vector2.ZERO
	var r := d / maxf(dead, 0.001) * hub if d < dead else hub + (d - dead) / maxf(reach - dead, 0.001) * (far - hub)
	return at / d * minf(r, far)


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
	return ""


## The slice lit now (an index into the wheel's orders, -1 none), for tests.
func lit_slice() -> int:
	return _lit if visible else -1


## The slice banded as the order in force (-1 none), for tests.
func banded_slice() -> int:
	return _force if visible else -1


## The slice's name as drawn and its key's ("" for none), for tests.
func slice_name(i: int) -> String:
	return _names[i] if _built and i < _names.size() else ""


func slice_key(i: int) -> String:
	return _keys[i] if _built and i < _keys.size() else ""


## The notice's words while one shows, else "", for tests.
func notice_text() -> String:
	return _notice.text if _showing_notice else ""


## Whether the wheel's parts have been built, for tests.
func built() -> bool:
	return _built


## The wheel itself (the dark behind it and its slices) is drawn: not while only a notice shows in its hub, so the
## crosshair stays clear while you have control again.
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
	var back := HudStyle.backing_on(self, SLICE_ALPHA)
	for i in _slices.size():
		var lit := i == _lit
		draw_colored_polygon(_slices[i], GameTheme.YELLOW if lit else back)
		draw_polyline(_outlines[i], LIT_EDGE if lit else GameTheme.LINE, LIT_STROKE if lit else STROKE, true)
	if _force >= 0:
		draw_colored_polygon(_bands[_force], _colour)
	_draw_hub()
	for i in _slices.size():
		_draw_words(i)


## The hub and its ring, ruled while it tells a notice; see-through when the wheel is shut and it only tells you.
func _draw_hub() -> void:
	var alpha := NOTICE_ALPHA if _showing_notice and not _notice_only else HUB_ALPHA
	draw_circle(Vector2.ZERO, _hub, HudStyle.backing_on(self, alpha))
	draw_arc(Vector2.ZERO, _hub, 0.0, TAU, 64, GameTheme.LINE, STROKE, true)
	if _showing_notice:
		draw_arc(Vector2.ZERO, _hub - NOTICE_RULE * 0.5, 0.0, TAU, 64, GameTheme.YELLOW, NOTICE_RULE, true)


## Slice `i`'s name and key, and the ACTIVE tag when it is the order in force.
func _draw_words(i: int) -> void:
	var lit := i == _lit
	var fade := DIM if _showing_notice else 1.0
	var ink := Color(GameTheme.YELLOW_INK if lit else GameTheme.TEXT, fade)
	var key_ink := Color(GameTheme.YELLOW_INK if lit else GameTheme.MUTED, fade)
	var has_key := not _keys[i].is_empty()
	var key_h := _key_font.get_height(KEY_SIZE) + KEY_PAD.y * 2.0 + KEY_EDGE
	var column := float(NAME_SIZE) + WORDS_GAP + (key_h if has_key else NO_KEY_HEIGHT)
	var box := _label_at[i] - SLICE_BOX * 0.5
	var top := box.y + (SLICE_BOX.y - column) * 0.5
	var mid := _label_at[i].x
	var base := top + (NAME_SIZE - _name_font.get_height(NAME_SIZE)) * 0.5 + _name_font.get_ascent(NAME_SIZE)
	draw_string(_name_font, Vector2(box.x, base), _names[i], HORIZONTAL_ALIGNMENT_CENTER, SLICE_BOX.x, NAME_SIZE, ink)
	if has_key:
		var text_w := _key_font.get_string_size(_keys[i], HORIZONTAL_ALIGNMENT_LEFT, -1, KEY_SIZE).x
		var w := maxf(KEY_MIN, text_w + KEY_PAD.x * 2.0 + KEY_EDGE)
		var chip := Rect2(mid - w * 0.5, top + NAME_SIZE + WORDS_GAP, w, key_h)
		_chip.bg_color = Color(GameTheme.YELLOW_INK, 0.1 * fade) if lit else Color(0.0, 0.0, 0.0, 0.0)
		_chip.border_color = key_ink
		draw_style_box(_chip, chip)
		var key_base := chip.position.y + (key_h - _key_font.get_height(KEY_SIZE)) * 0.5 + _key_font.get_ascent(KEY_SIZE)
		draw_string(_key_font, Vector2(chip.position.x, key_base), _keys[i], HORIZONTAL_ALIGNMENT_CENTER, w, KEY_SIZE,
				key_ink)
	if i == _force and not _showing_notice:
		var tag_w := _tag_font.get_string_size(_tag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_SIZE).x + TAG_PAD.x \
				+ TAG_PAD.z
		var tag_h := _tag_font.get_height(TAG_SIZE) + TAG_PAD.y + TAG_PAD.w
		var tag := Rect2(mid - tag_w * 0.5, box.y + SLICE_BOX.y + TAG_LOWER - tag_h, tag_w, tag_h)
		draw_style_box(_tag, tag)
		var tag_base := tag.position.y + TAG_PAD.y + _tag_font.get_ascent(TAG_SIZE)
		draw_string(_tag_font, Vector2(tag.position.x, tag_base), _tag_text, HORIZONTAL_ALIGNMENT_CENTER, tag_w,
				TAG_SIZE, Color.WHITE)


## Opens: builds the parts the first time, and reads the names and the keys as they are now (a key may have been
## rebound since).
func _open() -> void:
	if not _built:
		_build()
	for i in _names.size():
		_names[i] = tr(_controls.wheel_labels[i]).to_upper() if i < _controls.wheel_labels.size() else ""
	if _mag_slice >= 0:
		_mag_names[0] = _names[_mag_slice]
		_mag_names[1] = tr(_controls.wheel_mag_toss).to_upper()
		_names[_mag_slice] = _mag_names[1 if _mag_toss else 0]
	for i in _names.size():
		var action := _controls.wheel_keys[i] if i < _controls.wheel_keys.size() else &""
		var key := KeyNames.of_action(action) if action != &"" else ""
		_keys[i] = "" if key == KeyNames.NO_KEY else key
	_tag_text = tr("HUD_ORDER_ACTIVE").to_upper()
	_lit = -2
	_force = -2
	_clear_notice()
	_notice_only = false
	visible = true
	set_process(true)
	queue_redraw()


func _build() -> void:
	_built = true
	var n := _controls.wheel_orders.size()
	_mag_slice = _controls.wheel_orders.find(SquadOrder.Kind.MAG)
	_hub = _cfg.wheel_inner - HUB_GAP
	_names.resize(n)
	_keys.resize(n)
	_label_at.resize(n)
	for i in n:
		var a := TAU * i / maxi(n, 1)
		_label_at[i] = _at(_cfg.wheel_label_radius, a)
		_slices.append(_sector(i, n, _cfg.wheel_inner, _cfg.wheel_outer, false))
		_outlines.append(_sector(i, n, _cfg.wheel_inner, _cfg.wheel_outer, true))
		_bands.append(_sector(i, n, _cfg.wheel_outer - BAND, _cfg.wheel_outer, false))
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
	_key_font = GameTheme.font(800)
	_tag_font = GameTheme.spaced_font(800, TAG_SPACING, TAG_SIZE)
	_chip.set_border_width_all(roundi(STROKE))
	_chip.set_corner_radius_all(KEY_RADIUS)
	_tag.bg_color = _colour
	_tag.set_corner_radius_all(TAG_RADIUS)
	_notice = HudStyle.label(self, NOTICE_SIZE, 800, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.position = Vector2(-_hub + NOTICE_PAD, -_hub)
	_notice.size = Vector2(_hub * 2.0 - NOTICE_PAD * 2.0, _hub * 2.0)
	_notice.visible = false
	_pointer = Pointer.new()
	add_child(_pointer)


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


## Which of the wheel's orders is `kind` (-1 for none, or one the wheel doesn't have).
func _index_of(kind: SquadOrder.Kind) -> int:
	if kind == SquadOrder.Kind.NONE:
		return -1
	return _controls.wheel_orders.find(kind)


## The point `r` px from the middle at `angle` (0 up, clockwise).
static func _at(r: float, angle: float) -> Vector2:
	return Vector2(sin(angle), -cos(angle)) * r


## Slice `i` of `n` between radii `r0` and `r1` with the gap between slices kept: its corners and edges, closed with its
## first point again for an outline (`line`).
func _sector(i: int, n: int, r0: float, r1: float, line: bool) -> PackedVector2Array:
	var centre := TAU * i / n
	var half := TAU / n * 0.5
	var out := PackedVector2Array()
	var outer_from := centre - half + _cfg.wheel_gap / r1
	var outer_to := centre + half - _cfg.wheel_gap / r1
	var inner_from := centre - half + _cfg.wheel_gap / r0
	var inner_to := centre + half - _cfg.wheel_gap / r0
	for s in ARC_STEPS + 1:
		out.append(_at(r1, lerpf(outer_from, outer_to, float(s) / ARC_STEPS)))
	for s in ARC_STEPS + 1:
		out.append(_at(r0, lerpf(inner_to, inner_from, float(s) / ARC_STEPS)))
	if line:
		out.append(out[0])
	return out


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
