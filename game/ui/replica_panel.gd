class_name ReplicaPanel
extends VBoxContainer
## The replica panel, bottom right (UI concept B v2 `hud.png`): a compact rounded glass panel with the loaded count and
## the spare BBs, then a box per magazine (MagGauges) at the left with the fire modes the replica offers as S / B / A
## chips beside them (under them with many magazines), the one in use lit. The replica's name and the bombs are not
## here (BP8): the weapon rail just above the panel (WeaponRail) shows what you carry and what is in hand. Above the
## panel two small notes: the hop-up readout while you turn the dial, and the status (reloading, out of BBs, last
## magazine, holstered, a bomb in hand; nothing while a bomb is thrown). With the HUD tab's ammo counter off there are
## no counts and each box shows only whether its magazine holds BBs. Text is rebuilt only when what it shows changes.

## The panel's width (px at 1080p), its padding (left, top, right, bottom) and the space between its rows.
const WIDTH := 176.0
const PAD := Vector4(12.0, 8.0, 12.0, 9.0)
const ROW_GAP := 6
const CHIP_GAP := 5
const CHIP_PAD_X := 6
const CHIP_PAD_Y := 3
const NOTE_PAD := Vector2i(10, 4)
const NOTE_GAP := 6
const HOP_SIZE := 17
## The room the three fire chips need beside the boxes (px): with more magazines than leave it, the chips take a row
## of their own under them, so the panel never widens.
const CHIPS_ROOM := 84.0
## The fire modes' chip letters (ReplicaConfig.FireMode order) and the status lines' keys (none, reloading, out of BBs,
## last magazine, holstered, then a smoke and a flash bomb in hand: STATUS_IN_HAND plus its Grenade.Kind).
const CHIP_KEYS: Array[String] = ["HUD_CHIP_SEMI", "HUD_CHIP_BURST", "HUD_CHIP_AUTO"]
const STATUS_KEYS: Array[String] = ["", "HUD_RELOADING", "HUD_OUT_OF_BBS", "HUD_LAST_MAG", "HUD_HOLSTERED",
		"HUD_SMOKE_IN_HAND", "HUD_FLASH_IN_HAND"]
const STATUS_HOLSTERED := 4
const STATUS_IN_HAND := 4

var _cfg: HudConfig = null
var _hop: Label = null
var _status: Label = null
var _mag: Label = null
var _spare: Label = null
var _counts: HBoxContainer = null
var _chips: Array[Label] = []
var _lit: StyleBoxFlat = null
var _unlit: StyleBoxFlat = null
var _gauges: MagGauges = null
var _foot: HBoxContainer = null
var _chip_row: HBoxContainer = null
## What the panel shows now, so text is rebuilt only on a change.
var _shown_slot: int = -1
var _shown_mode: int = -1
var _shown_holstered: bool = false
var _shown_mag: int = -1
var _shown_spare: int = -1
var _shown_status: int = -1

func setup(cfg: HudConfig) -> void:
	_cfg = cfg
	name = "ReplicaPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override("separation", NOTE_GAP)
	_hop = _note(GameTheme.TEXT)
	_hop.add_theme_font_override("font", GameTheme.font(600))
	_hop.add_theme_font_size_override("font_size", HOP_SIZE)
	_status = _note(GameTheme.WARN)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	panel.custom_minimum_size = Vector2(WIDTH, 0.0)
	panel.name = "Frame"
	var frame := HudStyle.panel_box(HudStyle.BACKING_PANEL, 0, 0)
	frame.set_corner_radius_all(GameTheme.PANEL_RADIUS)
	frame.content_margin_left = PAD.x
	frame.content_margin_top = PAD.y
	frame.content_margin_right = PAD.z
	frame.content_margin_bottom = PAD.w
	panel.add_theme_stylebox_override("panel", frame)
	add_child(panel)
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", ROW_GAP)
	panel.add_child(rows)
	var counts := HBoxContainer.new()
	_counts = counts
	counts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	counts.alignment = BoxContainer.ALIGNMENT_END
	counts.add_theme_constant_override("separation", ROW_GAP)
	rows.add_child(counts)
	_mag = HudStyle.label(counts, HudStyle.COUNT_SIZE, 800, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	# the concept's line height 1: the count's line as tall as its size
	_mag.add_theme_font_override("font", HudStyle.tight_font(800, HudStyle.COUNT_SIZE))
	_spare = HudStyle.label(counts, HudStyle.SPARE_SIZE, 700, GameTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	_spare.size_flags_vertical = Control.SIZE_SHRINK_END
	var foot := HBoxContainer.new()
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_theme_constant_override("separation", CHIP_GAP)
	rows.add_child(foot)
	_foot = foot
	_chip_row = HBoxContainer.new()
	_chip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip_row.alignment = BoxContainer.ALIGNMENT_END
	_chip_row.add_theme_constant_override("separation", CHIP_GAP)
	_chip_row.visible = false
	rows.add_child(_chip_row)
	_gauges = MagGauges.new()
	_gauges.setup(cfg)
	# at the panel's left edge (owner, 2026-11-03), the fire modes at its right
	_gauges.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_gauges.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(_gauges)
	var gap := Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(gap)
	_lit = GameTheme.box(GameTheme.TEXT, GameTheme.TEXT, CHIP_PAD_X, CHIP_PAD_Y)
	_unlit = GameTheme.box(Color(0.0, 0.0, 0.0, 0.0), GameTheme.LINE, CHIP_PAD_X, CHIP_PAD_Y)
	for key in CHIP_KEYS:
		var chip := HudStyle.label(foot, HudStyle.CHIP_SIZE, 800, GameTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		chip.text = tr(key)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.add_theme_stylebox_override("normal", _unlit)
		_chips.append(chip)


## The ammo counter on (the counts, and each box filled to its BBs) or off (no counts; a box shows only whether its
## magazine holds BBs).
func set_counted(on: bool) -> void:
	_counts.visible = on
	_gauges.set_counted(on)


func counted() -> bool:
	return _counts.visible


## Gauge patterns on or off: a low loaded magazine striped as well as yellow.
func set_patterned(on: bool) -> void:
	_gauges.set_patterned(on)


func gauges() -> MagGauges:
	return _gauges


## Shows the hop-up readout `text`.
func show_hop(text: String) -> void:
	_hop.text = text
	_hop.visible = true


func hide_hop() -> void:
	_hop.visible = false


## Follows `a` and `hand`: the count, the spare, the chips, the boxes and the status; rebuilt only on
## a change. Down for a throw, or away while the hands are on Plant The Bomb's bomb (`on_bomb`, PB3: the rail shows the
## bomb as the thing in hand), the replica isn't said to be holstered.
func refresh(a: Armament, hand: Grenades.Hand = null, on_bomb: bool = false) -> void:
	var r := a.replica()
	var mag := a.mag()
	var spare := a.spare_bbs()
	var mode := a.fire_mode() as int
	var throwing := hand != null and hand.throwing != Grenade.Kind.NONE
	var in_hand := hand.readied if hand != null else Grenade.Kind.NONE
	var away := a.holstered and not throwing and in_hand == Grenade.Kind.NONE
	if a.active != _shown_slot or mode != _shown_mode or away != _shown_holstered:
		_shown_slot = a.active
		_shown_mode = mode
		_shown_holstered = away
		for i in _chips.size():
			var lit := i == mode and not a.holstered
			_chips[i].visible = r.fire_modes.has(i)
			_chips[i].add_theme_stylebox_override("normal", _lit if lit else _unlit)
			_chips[i].add_theme_color_override("font_color", GameTheme.BG if lit else GameTheme.MUTED)
		_seat_chips(_gauges.row_width(r.mags) + CHIPS_ROOM > WIDTH - PAD.x - PAD.z)
		_shown_mag = -1
	if mag != _shown_mag:
		_shown_mag = mag
		_mag.text = str(mag)
		var low := mag <= floori(r.mag_size * _cfg.low_mag_share)
		_mag.add_theme_color_override("font_color", GameTheme.WARN if low else GameTheme.TEXT)
	if spare != _shown_spare:
		_shown_spare = spare
		_spare.text = tr("HUD_SPARE") % spare
	_gauges.refresh(a)
	# STATUS_KEYS' order.
	var status := 0
	if throwing or on_bomb:
		status = 0
	elif in_hand != Grenade.Kind.NONE:
		status = STATUS_IN_HAND + in_hand
	elif a.holstered:
		status = STATUS_HOLSTERED
	elif a.reloading():
		status = 1
	elif mag == 0 and spare == 0:
		status = 2
	elif spare == 0:
		status = 3
	if status != _shown_status:
		_shown_status = status
		_status.text = HudStyle.caps(STATUS_KEYS[status]) if status > 0 else ""
		_status.visible = status > 0


## The chips beside the boxes, or (`below`, many magazines) in a row of their own under them.
func _seat_chips(below: bool) -> void:
	var home: Control = _chip_row if below else _foot
	for chip in _chips:
		if chip.get_parent() != home:
			chip.reparent(home, false)
	_chip_row.visible = below


## A small note above the panel on its own dark backing, right-aligned, hidden until it has words.
func _note(colour: Color) -> Label:
	var l := HudStyle.label(self, HudStyle.NOTE_SIZE, 700, colour, HORIZONTAL_ALIGNMENT_RIGHT, HudStyle.SPACING_AIM)
	l.size_flags_horizontal = Control.SIZE_SHRINK_END
	l.add_theme_stylebox_override("normal", HudStyle.panel_box(HudStyle.BACKING_PANEL, NOTE_PAD.x, NOTE_PAD.y))
	l.visible = false
	return l
