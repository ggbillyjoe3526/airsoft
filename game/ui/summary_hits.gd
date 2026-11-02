class_name SummaryHits
extends PanelContainer
## The match summary's What got you panel (concept `summary.png`): a line for each time you were hit this match (the
## round, the shooter in their team's colour, the side and distance, then whether they held the angle, else how long
## they had you in view, and a bounce), the latest SHOWN of them; then who got you most ("Rook got you twice, both
## times holding the angle.") with that bot's personality note, or the last shooter's note when nobody got you twice.

## One hit on you, kept for the summary.
class Entry:
	extends RefCounted
	var number: int = 0
	var facts: HitFacts = HitFacts.new()
	var shooter: String = ""
	var colour: Color = Color.WHITE
	var note: String = ""


## The most hits listed (the latest); the rest are counted on one line.
const SHOWN := 5
const ROUND_WIDTH := 84.0
const NAME_WIDTH := 92.0
const ROUND_SIZE := 12
const NAME_SIZE := 17
const WORDS_SIZE := 16
const LINE_HEIGHT := 30
const CLOSING_GAP := 12
const SHORT_KEYS: Array[StringName] = [&"WGY_SHORT_FRONT", &"WGY_SHORT_LEFT", &"WGY_SHORT_RIGHT", &"WGY_SHORT_BEHIND"]

var _entries: Array[Entry] = []
var _column: VBoxContainer = null
var _rule: StyleBoxFlat = null
var _closing: RichTextLabel = null


func _init() -> void:
	name = "SummaryHits"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", MatchSummary.panel_box())
	_column = MatchSummary.column(self, 0)
	_rule = MatchSummary.row_rule()


func clear() -> void:
	_entries.clear()


func add(number: int, facts: HitFacts, shooter_name: String, colour: Color, note: String) -> void:
	var e := Entry.new()
	e.number = number
	e.facts.copy_from(facts)
	e.shooter = shooter_name
	e.colour = colour
	e.note = note
	_entries.append(e)


func entries() -> Array[Entry]:
	return _entries


## Lays out the hits kept so far.
func fill() -> void:
	for c in _column.get_children():
		_column.remove_child(c)
		c.queue_free()
	var head := MatchSummary.title(_column, "WGY_TITLE")
	head.custom_minimum_size.y = LINE_HEIGHT
	if _entries.is_empty():
		_closing = _words(_column)
		_closing.text = tr("SUM_NO_HITS")
		return
	var first := maxi(0, _entries.size() - SHOWN)
	if first > 0:
		var earlier := HudStyle.label(_column, WORDS_SIZE - 2, 500, GameTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT)
		earlier.text = tr("SUM_EARLIER_HITS") % first
	for i in range(first, _entries.size()):
		_line(_entries[i])
	var gap := Control.new()
	gap.custom_minimum_size.y = CLOSING_GAP
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(gap)
	_closing = _words(_column)
	_closing.text = closing_bbcode(_entries)


## The closing words as shown (no markup): for tests.
func closing_text() -> String:
	return _closing.get_parsed_text() if _closing != null else ""


## "From your left, 18 m · holding the angle": the side and distance, then the held angle (yellow) or time in view,
## then a bounce.
static func hit_bbcode(facts: HitFacts) -> String:
	var t := TranslationServer.translate(SHORT_KEYS[WhatGotYouCard.from_of(facts)]) % roundi(facts.distance)
	if facts.held:
		t += " · [color=#%s]%s[/color]" % [GameTheme.ACCENT.to_html(false),
				TranslationServer.translate(&"WGY_SHORT_HELD")]
	elif facts.in_view >= 0.0:
		t += " · " + TranslationServer.translate(&"WGY_SHORT_SEEN") % facts.in_view
	if facts.ricochet:
		t += " · " + TranslationServer.translate(&"WGY_SHORT_BOUNCED")
	return t


## Who got you most (the latest of them on a tie), how often and whether they held the angle each time, then their
## note; with nobody twice, the last shooter's note alone.
static func closing_bbcode(entries: Array[Entry]) -> String:
	var top: Entry = null
	var top_count := 0
	for e in entries:
		var count := 0
		for other in entries:
			if other.shooter == e.shooter:
				count += 1
		if count >= top_count:
			top = e
			top_count = count
	var note := WhatGotYouCard.note_bbcode(top.note, top.colour) if top.note != "" else ""
	if top_count < 2:
		return note
	var all_held := true
	for e in entries:
		if e.shooter == top.shooter and not e.facts.held:
			all_held = false
	var who := "[color=#%s]%s[/color]" % [top.colour.to_html(false), top.shooter.replace("[", "[lb]")]
	var t := TranslationServer.translate(&"WGY_GOT_YOU_TWICE") % who if top_count == 2 \
			else TranslationServer.translate(&"WGY_GOT_YOU_TIMES") % [who, top_count]
	if all_held:
		t += TranslationServer.translate(&"WGY_BOTH_HELD" if top_count == 2 else &"WGY_ALL_HELD")
	t += "."
	return t + " " + note if note != "" else t


func _line(e: Entry) -> void:
	var r := PanelContainer.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_stylebox_override("panel", _rule)
	r.custom_minimum_size.y = LINE_HEIGHT
	_column.add_child(r)
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 0)
	r.add_child(line)
	var number := HudStyle.label(line, ROUND_SIZE, 800, GameTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT,
			HudStyle.SPACING_ROUND)
	number.text = (tr("SUM_ROUND") % e.number).to_upper()
	number.custom_minimum_size.x = ROUND_WIDTH
	number.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var who := HudStyle.label(line, NAME_SIZE, 700, e.colour, HORIZONTAL_ALIGNMENT_LEFT)
	who.text = e.shooter
	who.custom_minimum_size.x = NAME_WIDTH
	who.clip_text = true
	who.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var words := _words(line)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	words.autowrap_mode = TextServer.AUTOWRAP_OFF
	words.text = hit_bbcode(e.facts)


func _words(parent: Control) -> RichTextLabel:
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_font_override("normal_font", GameTheme.font(500))
	text.add_theme_font_override("bold_font", GameTheme.font(800))
	for key: String in ["normal_font_size", "bold_font_size"]:
		text.add_theme_font_size_override(key, WORDS_SIZE)
	text.add_theme_color_override("default_color", GameTheme.TEXT)
	parent.add_child(text)
	return text
