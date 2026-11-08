class_name HudFlagGauge
extends Control
## Attack / Defend's flag gauge under the score bar (concept `hud-attack.png`): "FLAG", one notch per ratchet step of the
## rope filled up to the flag's height in the attacking team's colour, a white line where the flag is, and a flag at
## the top end. While a raised flag is held (FlagConfig.hold_time, BP8) "FLAG" reads "HOLD 4", the whole seconds left.
## With gauge patterns on (set_patterned), a striped team's fill (HudStyle.STRIPED_TEAM, Beta's) is striped
## too: each notch's GaugePattern is built again only when the gauge's size changes. Redraws only when the filled
## notches, the line, the colour or the stripes change.

## The track's and the line's heights, and the end flag's mast and pennant, as shares of the gauge's height (the
## pennant's length in px).
const TRACK_TOP := 0.3
const TRACK_HEIGHT := 0.4
const LINE_TOP := 0.15
const LINE_HEIGHT := 0.7
const LINE_WIDTH := 3.0
const MAST_TOP := 0.22
const MAST_HEIGHT := 0.56
const MAST_WIDTH := 2.0
const PENNANT_LENGTH := 11.0
const PENNANT_HEIGHT := 0.24

var _notches: int = 12
var _progress: float = -1.0
var _colour: Color = Color.WHITE
var _label: Label = null
## The hold's whole seconds left shown in the label; -1: none ("FLAG").
var _hold_left: int = -1
var _pennant := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _mast := Rect2()
var _patterned: bool = false
## Whether the team raising the flag is the striped one, and each notch's stripes.
var _striped: bool = false
var _notch_stripes: Array[GaugePattern] = []


## `notches` steps across `width` px (the score bar's).
func setup(notches: int, width: float) -> void:
	name = "HudFlagGauge"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notches = maxi(1, notches)
	for i in _notches:
		_notch_stripes.append(GaugePattern.new())
	custom_minimum_size = Vector2(width, HudStyle.GAUGE_HEIGHT)
	_label = HudStyle.label(self, HudStyle.GAUGE_LABEL_SIZE, 800, GameTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT,
			HudStyle.SPACING_ROUND)
	_label.text = HudStyle.caps("HUD_FLAG")
	_label.position = Vector2(HudStyle.GAUGE_PAD, 0.0)
	_label.size = Vector2(HudStyle.GAUGE_LABEL_WIDTH, HudStyle.GAUGE_HEIGHT)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


## The flag `progress` (0..1) up the pole, raised by the team in `colour`; `striped` when that team's fill is the
## striped one (drawn so only with gauge patterns on).
func set_flag(progress: float, colour: Color, striped: bool = false) -> void:
	var p := clampf(progress, 0.0, 1.0)
	# The line moves in pixel steps, so a redraw only when it would move.
	if absf(p - _progress) * _track_width() < 0.5 and colour == _colour and striped == _striped:
		return
	_progress = p
	_colour = colour
	_striped = striped
	queue_redraw()


## The raised flag's hold: `left` whole seconds to go ("HOLD 4"), or -1 for none ("FLAG"). Words change only when
## `left` does.
func set_hold(left: int) -> void:
	if left == _hold_left:
		return
	_hold_left = left
	_label.text = HudStyle.caps("HUD_FLAG") if left < 0 else (tr("HUD_FLAG_HOLD") % left).to_upper()


## The label's words, for tests.
func label_text() -> String:
	return _label.text


## Gauge patterns on or off.
func set_patterned(on: bool) -> void:
	if on != _patterned:
		_patterned = on
		queue_redraw()


## Whether the fill is drawn striped now.
func striped() -> bool:
	return _patterned and _striped


## Notch `i`'s rect on the track.
func notch_rect(i: int) -> Rect2:
	var gap := HudStyle.GAUGE_NOTCH_GAP
	var w := (_track_width() - gap * (_notches - 1)) / _notches
	var x0 := HudStyle.GAUGE_PAD + HudStyle.GAUGE_LABEL_WIDTH
	return Rect2(x0 + i * (w + gap), size.y * TRACK_TOP, w, size.y * TRACK_HEIGHT)


## Notch `i`'s stripes, for tests.
func notch_stripes(i: int) -> GaugePattern:
	return _notch_stripes[i]


## Notches filled now, for tests.
func notches_filled() -> int:
	return floori(_progress * _notches + 1e-4)


func _track_width() -> float:
	return size.x - HudStyle.GAUGE_LABEL_WIDTH - HudStyle.GAUGE_PAD * 2.0 - HudStyle.GAUGE_HEIGHT


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		# The flag at the top end, built once for the size: a short mast and a pennant.
		var h := size.y
		var fx := HudStyle.GAUGE_PAD + HudStyle.GAUGE_LABEL_WIDTH + _track_width() + HudStyle.GAUGE_PAD
		_mast = Rect2(fx, h * MAST_TOP, MAST_WIDTH, h * MAST_HEIGHT)
		_pennant[0] = Vector2(fx + MAST_WIDTH, h * MAST_TOP)
		_pennant[1] = Vector2(fx + MAST_WIDTH + PENNANT_LENGTH, h * (MAST_TOP + PENNANT_HEIGHT * 0.5))
		_pennant[2] = Vector2(fx + MAST_WIDTH, h * (MAST_TOP + PENNANT_HEIGHT))


func _draw() -> void:
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), HudStyle.backing_on(self, HudStyle.BACKING_SIDE))
	var filled := notches_filled()
	var empty := Color(GameTheme.TEXT, HudStyle.PIP_EMPTY_ALPHA * 0.5)
	var stripes := striped()
	for i in _notches:
		var notch := notch_rect(i)
		draw_rect(notch, _colour if i < filled else empty)
		if stripes and i < filled:
			_notch_stripes[i].set_rect(notch)
			_notch_stripes[i].draw(self)
	# Where the flag is: a white line through the track.
	var at := HudStyle.GAUGE_PAD + HudStyle.GAUGE_LABEL_WIDTH + _track_width() * maxf(_progress, 0.0)
	draw_rect(Rect2(at - LINE_WIDTH * 0.5, h * LINE_TOP, LINE_WIDTH, h * LINE_HEIGHT), GameTheme.TEXT)
	draw_rect(_mast, GameTheme.TEXT)
	draw_colored_polygon(_pennant, GameTheme.TEXT)
