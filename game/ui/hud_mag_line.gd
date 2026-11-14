class_name HudMagLine
extends Label
## The magazine hand-off's line under the crosshair (MH3; concept `step27/mag-hand-off.png`; the browser game's
## src/magHandoff.ts and ui/magPrompt.ts): one plate saying what the hand-off is doing, read from the simulation's state
## and events once a tick, never a key or a control. In order:
##
## 1. A notice, for HudConfig.mag_notice_time: your toss ("Mag to Rook"), your catch ("+1 mag from Brick · 60 BBs", the
##    BBs left out with the ammo counter off), a magazine lost, or why your press did nothing (MagShare.Refusal). A
##    refusal of a press picked on the order wheel shows in the wheel's middle instead (wheel_notice).
## 2. The nearest teammate asking you, with nothing in the air to them yet, and how far across the ground ("Rook needs
##    a mag · 12 m"), underlined in your team's colour once a press would toss it (MagShare.can_toss_to).
## 3. The teammate your ask stands with, or whose magazine is in the air to you ("Brick is bringing you a mag").
##
## Also, for the HUD: whether a toss is ready (the wheel's item reads Toss a Mag), and the teammates to mark with a
## magazine glyph by their chevron (`marks`, by character id: one asking you, or bringing you one). Each notice goes to
## the screen reader's messages (Announcer) as it is made. Hidden while the order wheel is open, and with Settings ›
## HUD › Mag hand-off off (`enabled`). A string is made only when what the plate says changes; a tick otherwise
## allocates nothing.

## What the plate says (besides a notice): nothing, a teammate needing one, or one coming to you.
enum Says { NOTHING, NEEDS, BRINGING }

## Settings › HUD › Mag hand-off: off, neither the plate nor the glyphs show (the rules and the notices to the screen
## reader go on).
var enabled: bool = true
## The ammo counter shows (Settings › HUD): a caught magazine's notice names its BBs only then.
var counted: bool = true
## By character id, 1 for a teammate to mark with the magazine glyph (made once with setup; refilled each tick).
var marks := PackedByteArray()
## A refusal of a press picked on the wheel since the last look, for the wheel's middle ("" for none; take_wheel_notice).
var wheel_notice: String = ""

var _cfg: HudConfig = null
var _share: MagShare = null
var _you: Character = null
var _announcer: Announcer = null
var _names := PackedStringArray()
var _plain: StyleBoxFlat = null
var _ruled: StyleBoxFlat = null
## The notice up and until when (s of match time).
var _notice: String = ""
var _notice_until: float = -INF
## What the plate says now, about whom, how far (m), and whether a press would toss it.
var _says: Says = Says.NOTHING
var _about: int = -1
var _metres: int = 0
var _in_reach: bool = false
## The words last made for (_says, _about, _metres), and what they were made for.
var _line: String = ""
var _line_for := Vector3i(-1, -1, -1)
## Hidden for now (the order wheel open, or the middle wanted clear).
var _hidden: bool = false


## The plate for `you`, checking a toss with `share` (the simulation's own rules), its notices also handed to
## `announcer` (null: none), sized by `cfg` and underlined in `colour` (your team's). `characters` sizes `marks`.
func setup(cfg: HudConfig, share: MagShare, you: Character, characters: int, colour: Color,
		announcer: Announcer) -> void:
	name = "HudMagLine"
	_cfg = cfg
	_share = share
	_you = you
	_announcer = announcer
	marks.resize(characters)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	add_theme_font_override("font", GameTheme.font(700))
	add_theme_font_size_override("font_size", GameTheme.SMALL_SIZE)
	add_theme_color_override("font_color", GameTheme.TEXT)
	var pad := cfg.mag_line_pad
	_plain = HudStyle.panel_box(HudStyle.BACKING_PANEL, roundi(pad.x), roundi(pad.y))
	_ruled = HudStyle.panel_box(HudStyle.BACKING_PANEL, roundi(pad.x), roundi(pad.y))
	_ruled.border_color = colour
	_ruled.border_width_bottom = roundi(cfg.mag_line_rule)
	add_theme_stylebox_override(&"normal", _plain)
	visible = false


## The names by character id, as the feed shows them.
func set_names(names: PackedStringArray) -> void:
	_names = names


## The tick's events and state: your tosses, catches, losses and refusals become notices (`from_wheel`: your last press
## was picked on the order wheel, so its refusal goes to the wheel), then what the plate says and the marks are worked
## out afresh.
func on_tick(state: GameState, from_wheel: bool) -> void:
	var me := _you.id
	var events := state.events
	for i in events.count:
		var e := events.items[i]
		match e.kind:
			GameEvent.Kind.ROUND_START:
				_notice_until = -INF
			GameEvent.Kind.MAG_TOSS when e.actor == me:
				_say(tr("HUD_MAG_TOSSED") % _name(e.target), state.time)
			GameEvent.Kind.MAG_CATCH when e.target == me:
				var words := tr("HUD_MAG_CAUGHT") % [_name(e.actor), e.value] if counted \
						else tr("HUD_MAG_CAUGHT_UNCOUNTED") % _name(e.actor)
				_say(words, state.time)
			GameEvent.Kind.MAG_LOST when e.target == me or e.actor == me:
				_say(tr("HUD_MAG_LOST"), state.time)
			GameEvent.Kind.MAG_REFUSED when e.actor == me:
				var tossing := e.value == MagShare.Refusal.WAIT and e.target >= 0
				var why := refusal_text(e.value as MagShare.Refusal, _name(e.target), tossing, tossing and _flying(state))
				if from_wheel:
					wheel_notice = why
					if _announcer != null:
						_announcer.add(why, false)
				else:
					_say(why, state.time)
	_standing(state)
	_show(state.time)


## Each frame: hidden while the order wheel is open (`wheel_open`) or the HUD wants the middle clear (`clear`).
func update(wheel_open: bool, clear: bool) -> void:
	_hidden = wheel_open or clear
	visible = enabled and not _hidden and not text.is_empty()


## The words for refusal `why` about the teammate named `who` ("" for none); a WAIT refused a toss if `toss`, with a
## magazine of yours still in the air if `in_air` (else every slot of the pool is).
static func refusal_text(why: MagShare.Refusal, who: String, toss: bool = false, in_air: bool = false) -> String:
	match why:
		MagShare.Refusal.NOBODY:
			return TranslationServer.translate("HUD_MAG_NOBODY")
		MagShare.Refusal.NOT_LOW:
			return TranslationServer.translate("HUD_MAG_NOT_LOW")
		MagShare.Refusal.NO_SPARE:
			return TranslationServer.translate("HUD_MAG_NO_SPARE") % who
		MagShare.Refusal.WAIT:
			if in_air:
				return TranslationServer.translate("HUD_MAG_WAIT_IN_AIR")
			return TranslationServer.translate("HUD_MAG_WAIT_TOSS" if toss else "HUD_MAG_WAIT")
		MagShare.Refusal.ALREADY:
			return TranslationServer.translate("HUD_MAG_ALREADY") % who
		MagShare.Refusal.TOO_FAR:
			return TranslationServer.translate("HUD_MAG_TOO_FAR") % who
	return TranslationServer.translate("HUD_MAG_NOT_NOW")


## The wheel's notice since the last look, once ("" for none).
func take_wheel_notice() -> String:
	var n := wheel_notice
	wheel_notice = ""
	return n


## A press would toss a magazine now (the wheel's item reads Toss a Mag).
func toss_ready() -> bool:
	return _says == Says.NEEDS and _in_reach


## Whether the plate is underlined (a toss in reach and no notice over it), for tests.
func underlined() -> bool:
	return get_theme_stylebox(&"normal") == _ruled


## A notice: shown for mag_notice_time and handed to the screen reader.
func _say(words: String, now: float) -> void:
	_notice = words
	_notice_until = now + _cfg.mag_notice_time
	if _announcer != null:
		_announcer.add(words, false)


## Who is asking you and who is bringing you one, in a live round with you in play; the marks.
func _standing(state: GameState) -> void:
	marks.fill(0)
	_says = Says.NOTHING
	_about = -1
	_in_reach = false
	var me := _you
	if not state.round_state.is_live() or state.round_state.practice or not Elimination.is_in_play(me):
		return
	var asking := false
	for o in state.characters:
		if o == me or o.team != me.team or o.mag.asked != me.id or o.mag.coming > 0 or not Elimination.is_in_play(o):
			continue
		_mark(o.id)
		asking = true
	var bringer := me.mag.coming_from if me.mag.coming > 0 else me.mag.asked
	_mark(bringer)
	# The press's own pick (MagShare.nearest_asker): the nearest asker in reach, else the nearest one.
	var best: Character = null
	if asking:
		best = _share.nearest_asker(me, state.characters, true)
		_in_reach = best != null
		if best == null:
			best = _share.nearest_asker(me, state.characters, false)
	if best != null:
		_says = Says.NEEDS
		_about = best.id
		_metres = roundi(Vector2(best.position.x - me.position.x, best.position.z - me.position.z).length())
	elif bringer >= 0:
		_says = Says.BRINGING
		_about = bringer
		_metres = 0


func _mark(id: int) -> void:
	if id >= 0 and id < marks.size():
		marks[id] = 1


## The plate's words and rule at `now`: a notice over all, else what it says.
func _show(now: float) -> void:
	var words := ""
	var ruled := false
	if now < _notice_until:
		words = _notice
	elif _says != Says.NOTHING:
		var key := Vector3i(_says, _about, _metres)
		if key != _line_for:
			_line_for = key
			_line = tr("HUD_MAG_NEEDS") % [_name(_about), _metres] if _says == Says.NEEDS \
					else tr("HUD_MAG_BRINGING") % _name(_about)
		words = _line
		ruled = _in_reach
	if words != text:
		text = words
	var box := _ruled if ruled else _plain
	if get_theme_stylebox(&"normal") != box:
		add_theme_stylebox_override(&"normal", box)
	visible = enabled and not _hidden and not words.is_empty()


## A magazine you tossed is still in the air.
func _flying(state: GameState) -> bool:
	for t in state.mag_tosses:
		if t.active and t.from_id == _you.id:
			return true
	return false


func _name(id: int) -> String:
	return _names[id] if id >= 0 and id < _names.size() else ""
