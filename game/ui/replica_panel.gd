class_name ReplicaPanel
extends VBoxContainer
## The replica panel, bottom right (UI concept B v2 `hud.png`): a rounded glass panel, set to its right edge but for the
## magazine boxes. At its top the smoke and flash bombs (SF1) as icons (GrenadeGlyph) with how many are left, dimmed at
## none, the one in hand (MC1) larger on a light chip; then the loaded count and the spare BBs, a box per magazine
## (MagGauges) at the panel's left edge, and the replica's name with the fire modes it offers as S / B / A chips, the
## one in use lit. Above the panel two small notes: the hop-up readout while you turn the dial, and the status
## (reloading, out of BBs, last magazine, holstered, a bomb in hand; nothing while a bomb is thrown). With the HUD tab's
## ammo counter off there are no counts and each box shows only whether its magazine holds BBs. Text is rebuilt only
## when what it shows changes.

## The panel's width (px at 1080p), its padding (left, top, right, bottom) and the space between its rows.
const WIDTH := 196.0
const PAD := Vector4(14.0, 10.0, 14.0, 12.0)
const ROW_GAP := 10
const CHIP_GAP := 5
const CHIP_PAD_X := 6
const CHIP_PAD_Y := 3
## A bomb icon's opacity once none of that bomb are left.
const DIM_ICON := 0.35
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
## The bombs' row: each kind's words (Grenade.Kind order, NONE unused), the icons' size and the one in hand's, the
## count's size, and the chip under the one in hand (its padding).
const BOMB_KEYS: Array[String] = ["", "HUD_SMOKE", "HUD_FLASH"]
const BOMB_ICON := 28.0
const BOMB_ICON_HELD := 40.0
const BOMB_COUNT_SIZE := 17
const BOMB_GAP := 4
const BOMB_CHIP_PAD := Vector2i(6, 2)
const NAME_SIZE := 12

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
var _name: Label = null
## What the panel shows now, so text is rebuilt only on a change.
var _shown_slot: int = -1
var _shown_mode: int = -1
var _shown_holstered: bool = false
var _shown_mag: int = -1
var _shown_spare: int = -1
var _shown_status: int = -1
## The bombs' counts, icons and chips (Grenade.Kind order, NONE null), the counts they show (-1: not yet) and the bomb
## shown in hand; the chip's two boxes.
var _bombs: Array[Label] = []
var _bomb_icons: Array[GrenadeGlyph] = []
var _bomb_chips: Array[PanelContainer] = []
var _chip_held: StyleBoxFlat = null
var _chip_clear: StyleBoxFlat = null
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
	_status = _note(GameTheme.WARN)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	panel.custom_minimum_size = Vector2(WIDTH, 0.0)
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
	_build_bombs(rows)
	var counts := HBoxContainer.new()
	_counts = counts
	counts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	counts.alignment = BoxContainer.ALIGNMENT_END
	counts.add_theme_constant_override("separation", ROW_GAP)
	rows.add_child(counts)
	_mag = HudStyle.label(counts, HudStyle.COUNT_SIZE, 800, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	_spare = HudStyle.label(counts, HudStyle.SPARE_SIZE, 700, GameTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	_spare.size_flags_vertical = Control.SIZE_SHRINK_END
	_gauges = MagGauges.new()
	_gauges.setup(cfg)
	# at the panel's left edge, under the name's start (owner, 2026-11-03)
	_gauges.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	rows.add_child(_gauges)
	var foot := HBoxContainer.new()
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_theme_constant_override("separation", CHIP_GAP)
	rows.add_child(foot)
	_name = HudStyle.label(foot, NAME_SIZE, 700, GameTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, HudStyle.SPACING_AIM)
	_name.name = "ReplicaName"
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_name.clip_text = true
	_lit = GameTheme.box(GameTheme.TEXT, GameTheme.TEXT, CHIP_PAD_X, CHIP_PAD_Y)
	_unlit = GameTheme.box(Color(0.0, 0.0, 0.0, 0.0), GameTheme.LINE, CHIP_PAD_X, CHIP_PAD_Y)
	for key in CHIP_KEYS:
		var chip := HudStyle.label(foot, HudStyle.CHIP_SIZE, 800, GameTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		chip.text = tr(key)
		chip.add_theme_stylebox_override("normal", _unlit)
		_chips.append(chip)


## The bombs' row, right-aligned: per kind an icon and its count on a chip, clear until that bomb is in hand.
func _build_bombs(rows: VBoxContainer) -> void:
	var bombs := HBoxContainer.new()
	bombs.name = "Bombs"
	bombs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bombs.alignment = BoxContainer.ALIGNMENT_END
	bombs.add_theme_constant_override("separation", BOMB_GAP)
	# as tall as a bomb in hand on its chip, so readying one never moves the panel's top
	bombs.custom_minimum_size.y = BOMB_ICON_HELD + BOMB_CHIP_PAD.y * 2
	rows.add_child(bombs)
	_chip_held = GameTheme.box(GameTheme.CARD_HI, GameTheme.LINE, BOMB_CHIP_PAD.x, BOMB_CHIP_PAD.y)
	_chip_clear = GameTheme.box(Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), BOMB_CHIP_PAD.x, BOMB_CHIP_PAD.y)
	for kind in BOMB_KEYS.size():
		if BOMB_KEYS[kind].is_empty():
			_bombs.append(null)
			_bomb_icons.append(null)
			_bomb_chips.append(null)
			continue
		var chip := PanelContainer.new()
		chip.name = BOMB_KEYS[kind]
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.size_flags_vertical = Control.SIZE_SHRINK_END
		chip.add_theme_stylebox_override("panel", _chip_clear)
		bombs.add_child(chip)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", BOMB_GAP)
		chip.add_child(row)
		var icon := GrenadeGlyph.new(kind, BOMB_ICON)
		row.add_child(icon)
		var count := HudStyle.label(row, BOMB_COUNT_SIZE, 800, GameTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT)
		count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_bombs.append(count)
		_bomb_icons.append(icon)
		_bomb_chips.append(chip)


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
		_name.text = r.display_name.to_upper()
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
		_mag.add_theme_color_override("font_color", GameTheme.WARN if low else GameTheme.TEXT)
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


## The bombs left in `hand`, each rebuilt only when its count or the bomb in hand changes: dimmed at none, the one in
## hand larger on its chip.
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
		label.text = str(left)
		var held := kind == hand.readied
		label.add_theme_color_override("font_color", GameTheme.TEXT if left > 0 else GameTheme.DIM)
		var side := BOMB_ICON_HELD if held else BOMB_ICON
		_bomb_icons[kind].custom_minimum_size = Vector2(side, side)
		_bomb_icons[kind].modulate.a = 1.0 if left > 0 else DIM_ICON
		_bomb_chips[kind].add_theme_stylebox_override("panel", _chip_held if held else _chip_clear)


## The bombs' words now (Grenade.Kind order, NONE and a bomb not yet shown empty): "SMOKE 1", for tests.
func bomb_texts() -> PackedStringArray:
	var out := PackedStringArray()
	for kind in _bombs.size():
		var shown := _shown_bombs[kind]
		out.append((tr(BOMB_KEYS[kind]) % shown).to_upper() if _bombs[kind] != null and shown >= 0 else "")
	return out


## The icon `kind` shows (null for none), for tests.
func bomb_icon(kind: Grenade.Kind) -> GrenadeGlyph:
	return _bomb_icons[kind]


## A small note above the panel on its own dark backing, right-aligned, hidden until it has words.
func _note(colour: Color) -> Label:
	var l := HudStyle.label(self, HudStyle.NOTE_SIZE, 700, colour, HORIZONTAL_ALIGNMENT_RIGHT, HudStyle.SPACING_AIM)
	l.size_flags_horizontal = Control.SIZE_SHRINK_END
	l.add_theme_stylebox_override("normal", HudStyle.panel_box(HudStyle.BACKING_PANEL, NOTE_PAD.x, NOTE_PAD.y))
	l.visible = false
	return l
