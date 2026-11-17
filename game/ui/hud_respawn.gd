class_name HudRespawn
extends PanelContainer
## The respawn panel (RS1), bottom centre while you are out with a respawn coming: "RESPAWN IN 7" over a chip for each
## place you may come back at, the start area first and then your end's forward spawns (the defenders' too where
## RoundConfig.defender_forward_spawns lets them), each with the key that picks it (the first two replica slots' and
## Holster's: 1, 2 and 3 by default; the mouse wheel steps through them, PlayerInput.spawn_pick). The pick is lit; a
## forward spawn an enemy stands near is greyed out, as a pick of it comes back at the start area (Respawns.resolve,
## owner 2026-11-17: grey it out), and nothing else changes, so an enemy walking up while you wait never moves or
## resizes anything. Built once for the most places an end has; a frame changes text and looks only when what they show
## changes.

const TITLE_SIZE := 18
const NAME_SIZE := 15
const KEY_SIZE := 13
const PAD := Vector2i(14, 10)
const KEY_PAD := Vector2i(8, 3)
const CHIP_PAD := Vector2i(10, 6)
const GAP := 8
const CHIP_GAP := 8
const KEY_GAP := 8
## A shut spawn's chip, greyed out: seen through, nothing else about it changes.
const SHUT_ALPHA := 0.45
## The keys that pick each place, in order (the mouse wheel steps through them too).
const KEYS: Array[StringName] = [&"slot_1", &"slot_2", &"holster"]

var _title: Label = null
var _chips: Array[PanelContainer] = []
var _keys: Array[Label] = []
var _names: Array[Label] = []
var _lit: StyleBoxFlat = null
var _plain: StyleBoxFlat = null
## What the panel shows now, so a frame that changes nothing touches nothing: the whole seconds, the places (their
## count and end), the pick and which places are shut (a bit each).
var _shown_seconds: int = -1
var _shown_count: int = -1
var _shown_end: int = -1
var _shown_pick: int = -1
var _shown_shut: int = -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var box := HudStyle.panel_box(HudStyle.BACKING_CLOCK, PAD.x, PAD.y)
	box.border_color = GameTheme.accent
	box.border_width_left = roundi(HudStyle.BANNER_RULE)
	add_theme_stylebox_override("panel", box)
	_lit = GameTheme.box(GameTheme.CARD_HI, GameTheme.accent, CHIP_PAD.x, CHIP_PAD.y)
	_plain = GameTheme.box(GameTheme.CARD_HI, GameTheme.LINE, CHIP_PAD.x, CHIP_PAD.y)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", GAP)
	add_child(column)
	_title = HudStyle.label(column, TITLE_SIZE, 800, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, HudStyle.SPACING_AIM)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", CHIP_GAP)
	column.add_child(row)
	for i in KEYS.size():
		var chip := PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_theme_stylebox_override("panel", _plain)
		row.add_child(chip)
		var line := HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_theme_constant_override("separation", KEY_GAP)
		chip.add_child(line)
		var key := HudStyle.label(line, KEY_SIZE, 800, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		key.add_theme_stylebox_override("normal", GameTheme.box(GameTheme.CARD_HI, GameTheme.LINE, KEY_PAD.x, KEY_PAD.y))
		key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var name_label := HudStyle.label(line, NAME_SIZE, 700, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
		name_label.uppercase = true
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_chips.append(chip)
		_keys.append(key)
		_names.append(name_label)
	visible = false


## Shows the panel for `c` (you) in `rs`'s round, out with a respawn coming, or hides it: the seconds left, the places
## its end offers it (MapEnd.forward, only where it may use them), its pick (Character.spawn_pick, as the simulation
## last took it) and the forward spawns `characters` shut within `rounds`' block radius.
func show_for(c: Character, rs: RoundState, ends: Array[MapEnd], characters: Array[Character],
		rounds: RoundConfig) -> void:
	var waiting := rs.is_live() and Respawns.waiting(c)
	if waiting != visible:
		visible = waiting
		if waiting:
			_shown_count = -1
			_refresh_keys()
	if not waiting:
		return
	var seconds := maxi(1, ceili(c.respawn_left))
	if seconds != _shown_seconds:
		_shown_seconds = seconds
		_title.text = tr("HUD_RESPAWN_IN") % seconds
	var end: MapEnd = ends[c.end] if c.end >= 0 and c.end < ends.size() else null
	var forward := end.forward.size() if end != null and Respawns.forward_allowed(rs, c.team, rounds) else 0
	var count := mini(KEYS.size(), 1 + forward)
	if count != _shown_count or c.end != _shown_end:
		_shown_count = count
		_shown_end = c.end
		_shown_pick = -1
		_shown_shut = -1
		for i in KEYS.size():
			_chips[i].visible = i < count
			if i < count:
				_names[i].text = tr("HUD_RESPAWN_START") if i == 0 else end.forward[i - 1].name
	var shut := 0
	for i in range(1, count):
		if Respawns.shut(end.forward[i - 1], c.team, characters, rounds.forward_block_radius):
			shut |= 1 << i
	var pick := clampi(c.spawn_pick, 0, count - 1)
	if pick != _shown_pick or shut != _shown_shut:
		_shown_pick = pick
		_shown_shut = shut
		for i in count:
			var closed := (shut >> i) & 1 == 1
			_chips[i].add_theme_stylebox_override("panel", _lit if i == pick else _plain)
			_chips[i].modulate.a = SHUT_ALPHA if closed else 1.0


## The panel's title now ("" while hidden), and the places it offers, for tests.
func title_text() -> String:
	return _title.text if visible else ""


func place_names() -> PackedStringArray:
	var out := PackedStringArray()
	for i in KEYS.size():
		if _chips[i].visible:
			out.append(_names[i].text)
	return out


## The place lit as picked (-1 while hidden).
func lit_place() -> int:
	return _shown_pick if visible else -1


## Each chip's least size now, and which places read shut (a bit each), for tests.
func chip_sizes() -> PackedVector2Array:
	var out := PackedVector2Array()
	for chip in _chips:
		out.append(chip.get_combined_minimum_size())
	return out


func shut_places() -> int:
	return _shown_shut


## Each key chip says the key bound now (a rebind in the pause menu shows the next time the panel opens).
func _refresh_keys() -> void:
	for i in KEYS.size():
		_keys[i].text = KeyNames.of_action(KEYS[i]).to_upper()
