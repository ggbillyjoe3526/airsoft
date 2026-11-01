class_name ReplicaPanel
extends VBoxContainer
## The replica panel, bottom right (the concept's `.rep`): a framed dark panel with a yellow rule on its left holding the
## loaded count and the spare BBs, the fire modes the replica offers as S / B / A chips with the one in use lit, and a
## box per magazine (MagGauges). Above it two small notes: the hop-up readout while you turn the dial, and the status
## (reloading, out of BBs, last magazine, holstered, a bomb in hand; nothing while a bomb is thrown). Under the boxes,
## the smoke and flash bombs left (SF1), dimmed at none, the one in hand (MC1) yellow. With the HUD tab's ammo counter off there are no counts and each box shows
## only whether its magazine holds BBs. Text is rebuilt only when what it shows changes.

## The framed panel's width (px at 1080p, the browser's UI2 compact panel), its yellow rule, its padding (left, top,
## right, bottom: the left one is past the rule) and the space between its rows.
const WIDTH := 176.0
const RULE := 4
const PAD := Vector4(18.0, 12.0, 14.0, 12.0)
const ROW_GAP := 10
const CHIP_GAP := 5
const CHIP_PAD_Y := 3
const NOTE_PAD := Vector2i(10, 4)
const NOTE_GAP := 6
const HOP_SIZE := 17
## The fire modes' chip letters (ReplicaConfig.FireMode order) and the status lines' keys (none, reloading, out of BBs,
## last magazine, holstered, then a smoke and a flash bomb in hand: STATUS_IN_HAND plus its Grenade.Kind).
const CHIP_KEYS: Array[String] = ["HUD_CHIP_SEMI", "HUD_CHIP_BURST", "HUD_CHIP_AUTO"]
const STATUS_KEYS: Array[String] = ["", "HUD_RELOADING", "HUD_OUT_OF_BBS", "HUD_LAST_MAG", "HUD_HOLSTERED",
		"HUD_SMOKE_IN_HAND", "HUD_FLASH_IN_HAND"]
const STATUS_HOLSTERED := 4
const STATUS_IN_HAND := 4
## The bombs' row: each kind's words (Grenade.Kind order, NONE unused).
const BOMB_KEYS: Array[String] = ["", "HUD_SMOKE", "HUD_FLASH"]

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
## What the panel shows now, so text is rebuilt only on a change.
var _shown_slot: int = -1
var _shown_mode: int = -1
var _shown_holstered: bool = false
var _shown_mag: int = -1
var _shown_spare: int = -1
var _shown_status: int = -1
## The bombs' labels (Grenade.Kind order, NONE null), the counts they show (-1: not yet) and the bomb shown in hand.
var _bombs: Array[Label] = []
var _shown_bombs: PackedInt32Array = PackedInt32Array([-1, -1, -1])
var _shown_in_hand: Grenade.Kind = Grenade.Kind.NONE


func setup(cfg: HudConfig) -> void:
	_cfg = cfg
	name = "ReplicaPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override("separation", NOTE_GAP)
	_hop = _note(GameTheme.TEXT)
	_hop.add_theme_font_override("font", GameTheme.font(600))
	_hop.add_theme_font_size_override("font_size", HOP_SIZE)
	_status = _note(GameTheme.YELLOW)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	panel.custom_minimum_size = Vector2(WIDTH, 0.0)
	var frame := HudStyle.panel_box(HudStyle.BACKING_PANEL, 0, 0)
	frame.border_width_left = RULE
	frame.border_color = GameTheme.YELLOW
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
	counts.add_theme_constant_override("separation", ROW_GAP)
	rows.add_child(counts)
	_mag = HudStyle.label(counts, HudStyle.COUNT_SIZE, 800, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	_spare = HudStyle.label(counts, HudStyle.SPARE_SIZE, 700, GameTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	_spare.size_flags_vertical = Control.SIZE_SHRINK_END
	var chips := HBoxContainer.new()
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chips.add_theme_constant_override("separation", CHIP_GAP)
	rows.add_child(chips)
	_lit = GameTheme.box(GameTheme.TEXT, GameTheme.TEXT, 0, CHIP_PAD_Y)
	_unlit = GameTheme.box(Color(0.0, 0.0, 0.0, 0.0), GameTheme.LINE, 0, CHIP_PAD_Y)
	for key in CHIP_KEYS:
		var chip := HudStyle.label(chips, HudStyle.CHIP_SIZE, 800, GameTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		chip.text = tr(key)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.add_theme_stylebox_override("normal", _unlit)
		_chips.append(chip)
	_gauges = MagGauges.new()
	_gauges.setup(cfg)
	rows.add_child(_gauges)
	var bombs := HBoxContainer.new()
	bombs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bombs.add_theme_constant_override("separation", ROW_GAP)
	rows.add_child(bombs)
	for key in BOMB_KEYS:
		if key.is_empty():
			_bombs.append(null)
			continue
		var bomb := HudStyle.label(bombs, HudStyle.CHIP_SIZE, 800, GameTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT)
		bomb.name = key
		_bombs.append(bomb)


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


## Follows `a` and `hand`: the count, the spare, the chips, the boxes, the status and the bombs left; rebuilt only on
## a change. Down for a throw, the replica isn't said to be holstered.
func refresh(a: Armament, hand: Grenades.Hand = null) -> void:
	var r := a.replica()
	var mag := a.mag()
	var spare := a.spare_bbs()
	var mode := a.fire_mode() as int
	var throwing := hand != null and hand.throwing != Grenade.Kind.NONE
	var in_hand := hand.readied if hand != null else Grenade.Kind.NONE
	var away := a.holstered and not throwing and in_hand == Grenade.Kind.NONE
	if hand != null:
		_refresh_bombs(hand)
	if a.active != _shown_slot or mode != _shown_mode or away != _shown_holstered:
		_shown_slot = a.active
		_shown_mode = mode
		_shown_holstered = away
		for i in _chips.size():
			var lit := i == mode and not a.holstered
			_chips[i].visible = r.fire_modes.has(i)
			_chips[i].add_theme_stylebox_override("normal", _lit if lit else _unlit)
			_chips[i].add_theme_color_override("font_color", GameTheme.BG if lit else GameTheme.MUTED)
		_shown_mag = -1
	if mag != _shown_mag:
		_shown_mag = mag
		_mag.text = str(mag)
		var low := mag <= floori(r.mag_size * _cfg.low_mag_share)
		_mag.add_theme_color_override("font_color", GameTheme.YELLOW if low else GameTheme.TEXT)
	if spare != _shown_spare:
		_shown_spare = spare
		_spare.text = tr("HUD_SPARE") % spare
	_gauges.refresh(a)
	# STATUS_KEYS' order.
	var status := 0
	if throwing:
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


## The bombs left in `hand`, each label rebuilt only when its count or the bomb in hand changes: dimmed at none, yellow
## in hand.
func _refresh_bombs(hand: Grenades.Hand) -> void:
	var held_changed := hand.readied != _shown_in_hand
	_shown_in_hand = hand.readied
	for kind in _bombs.size():
		var label := _bombs[kind]
		if label == null:
			continue
		var left := hand.left(kind as Grenade.Kind)
		if left == _shown_bombs[kind] and not held_changed:
			continue
		_shown_bombs[kind] = left
		label.text = (tr(BOMB_KEYS[kind]) % left).to_upper()
		var colour := GameTheme.TEXT if left > 0 else GameTheme.DIM
		if kind == hand.readied:
			colour = GameTheme.YELLOW
		label.add_theme_color_override("font_color", colour)


## The bombs' labels' text now (Grenade.Kind order, NONE empty), for tests.
func bomb_texts() -> PackedStringArray:
	var out := PackedStringArray()
	for label in _bombs:
		out.append(label.text if label != null else "")
	return out


## A small note above the panel on its own dark backing, right-aligned, hidden until it has words.
func _note(colour: Color) -> Label:
	var l := HudStyle.label(self, HudStyle.NOTE_SIZE, 700, colour, HORIZONTAL_ALIGNMENT_RIGHT, HudStyle.SPACING_AIM)
	l.size_flags_horizontal = Control.SIZE_SHRINK_END
	l.add_theme_stylebox_override("normal", HudStyle.panel_box(HudStyle.BACKING_PANEL, NOTE_PAD.x, NOTE_PAD.y))
	l.visible = false
	return l
