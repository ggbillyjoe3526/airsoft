class_name WhatGotYouCard
extends PanelContainer
## "What got you" (concept `out.png`; the browser game's whatGotYou): once your hit is called, on the left, a card from
## HitFacts: a dial with you in the middle facing up and the line the shot came along, the shooter's name in their team's
## colour with which side and how far, then whether they held the angle, how long you were in their view and whether you
## were moving (each only when known), and last the bot's personality note. The HUD makes it on the hit and frees it when
## the next round starts.

## Which way the shot came from, seen from where you faced.
enum From { FRONT, LEFT, RIGHT, BEHIND }

const WIDTH := 500.0
const PAD := Vector2i(24, 18)
const RULE := 3
const TITLE_SIZE := 13
const NAME_SIZE := 34
const FROM_SIZE := 18
const ROW_SIZE := 17
const ROW_HEIGHT := 39
const NOTE_SIZE := 16
const DIAL := 110.0
const HEAD_GAP := 22
const SECTION_GAP := 14
const BACKING := 0.92
## Within this many degrees of straight ahead (or behind) the shot reads as from the front (or behind).
const AHEAD_DEGREES := 45.0
const FROM_KEYS: Array[StringName] = [&"WGY_FROM_FRONT", &"WGY_FROM_LEFT", &"WGY_FROM_RIGHT", &"WGY_FROM_BEHIND"]


## The dial: a ring, you in the middle as an arrow facing up, and the shot's line from the edge in the shooter's colour.
class Dial:
	extends Control

	const RING := 1.5
	const INNER_SHARE := 0.55
	const ARROW := Vector2(10.0, 14.0)
	const DOT := 6.0
	const LINE := 3.0
	const DASHES := 24

	var point := Vector2.UP
	var colour := Color.WHITE

	func _init(at: Vector2, shooter_colour: Color) -> void:
		point = at
		colour = shooter_colour
		custom_minimum_size = Vector2(DIAL, DIAL)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var centre := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - RING
		draw_circle(centre, r, HudStyle.backing_on(self, BACKING))
		draw_arc(centre, r, 0.0, TAU, 64, GameTheme.LINE, RING, true)
		var inner := r * INNER_SHARE
		for i in DASHES:
			if i % 2 == 0:
				var a := TAU * i / DASHES
				draw_arc(centre, inner, a, a + TAU / DASHES, 4, GameTheme.DIM, 1.0, true)
		var edge := centre + point * r
		draw_line(centre, edge, colour, LINE, true)
		draw_circle(edge, DOT, colour)
		var tip := centre + Vector2(0.0, -ARROW.y * 0.5)
		draw_colored_polygon(PackedVector2Array([tip, centre + Vector2(ARROW.x * 0.5, ARROW.y * 0.5),
				centre + Vector2(0.0, ARROW.y * 0.2), centre + Vector2(-ARROW.x * 0.5, ARROW.y * 0.5)]), GameTheme.TEXT)


## The card for `facts`, the shooter called `shooter_name` (their team's `colour`), and the bot's `note` ("" for none).
func _init(facts: HitFacts, shooter_name: String, colour: Color, note: String) -> void:
	name = "WhatGotYou"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.x = WIDTH
	var box := HudStyle.panel_box(BACKING, PAD.x, PAD.y)
	box.border_color = colour
	box.border_width_top = RULE
	add_theme_stylebox_override("panel", box)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", SECTION_GAP)
	add_child(column)
	var title := HudStyle.label(column, TITLE_SIZE, 800, GameTheme.ACCENT, HORIZONTAL_ALIGNMENT_LEFT,
			HudStyle.SPACING_ROUND)
	title.text = HudStyle.caps("WGY_TITLE")
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", HEAD_GAP)
	column.add_child(head)
	head.add_child(Dial.new(dial_point(facts), colour))
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(words)
	var who := HudStyle.label(words, NAME_SIZE, 800, colour, HORIZONTAL_ALIGNMENT_LEFT)
	who.text = shooter_name
	var from := HudStyle.label(words, FROM_SIZE, 600, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	from.text = from_words(facts)
	# One rule above each row, shared by them all.
	var rule := GameTheme.box(Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), 0, 0)
	rule.border_width_top = 1
	rule.border_color = GameTheme.LINE
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 0)
	column.add_child(rows)
	if facts.ricochet:
		_row(rows, rule, tr("WGY_BOUNCED"), tr("WGY_YES"), GameTheme.ACCENT)
	if facts.held_known:
		_row(rows, rule, tr("WGY_HELD") % shooter_name, tr("WGY_YES" if facts.held else "WGY_NO"),
				GameTheme.ACCENT if facts.held else GameTheme.TEXT)
	if facts.in_view >= 0.0:
		_row(rows, rule, tr("WGY_IN_VIEW") % shooter_name, tr("WGY_SECONDS") % facts.in_view, GameTheme.TEXT)
	_row(rows, rule, tr("WGY_YOU_WERE"), tr("WGY_MOVING" if facts.moving else "WGY_STILL"), GameTheme.TEXT)
	if note != "":
		var text := RichTextLabel.new()
		text.bbcode_enabled = true
		text.fit_content = true
		# Wrapping at the card's own width from the first frame, so its height is right before it has been laid out.
		text.custom_minimum_size.x = WIDTH - PAD.x * 2
		text.scroll_active = false
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.add_theme_font_override("normal_font", GameTheme.font(500))
		text.add_theme_font_override("bold_font", GameTheme.font(800))
		for key: String in ["normal_font_size", "bold_font_size"]:
			text.add_theme_font_size_override(key, NOTE_SIZE)
		text.add_theme_color_override("default_color", GameTheme.TEXT)
		text.text = note_bbcode(note, colour)
		column.add_child(text)


## Which side the shot came from: the shooter as seen from where the victim faced at the hit.
static func from_of(facts: HitFacts) -> From:
	var p := dial_point(facts)
	var ahead := cos(deg_to_rad(AHEAD_DEGREES))
	if -p.y >= ahead:
		return From.FRONT
	if p.y >= ahead:
		return From.BEHIND
	return From.RIGHT if p.x > 0.0 else From.LEFT


## "From your left, 18 m away".
static func from_words(facts: HitFacts) -> String:
	return TranslationServer.translate(FROM_KEYS[from_of(facts)]) % roundi(facts.distance)


## Where the shooter stood on the dial (unit length; up is the way the victim faced, right their right).
static func dial_point(facts: HitFacts) -> Vector2:
	var to_shooter := -facts.from_shooter
	if to_shooter == Vector2.ZERO:
		return Vector2.UP
	# Yaw 0 looks down -Z and turning left is positive: forward (-sin, -cos), right (cos, -sin) along (x, z).
	var forward := to_shooter.dot(Vector2(-sin(facts.victim_yaw), -cos(facts.victim_yaw)))
	var right := to_shooter.dot(Vector2(cos(facts.victim_yaw), -sin(facts.victim_yaw)))
	return Vector2(right, -forward).normalized()


## The note with its lead ("Rook anchors:") in bold in the shooter's colour; the rest as it is.
static func note_bbcode(note: String, colour: Color) -> String:
	var safe := note.replace("[", "[lb]")
	var cut := safe.find(":")
	if cut < 0:
		return safe
	return "[b][color=#%s]%s[/color][/b]%s" % [colour.to_html(false), safe.substr(0, cut + 1), safe.substr(cut + 1)]


func _row(parent: Control, rule: StyleBox, words: String, value: String, value_colour: Color) -> void:
	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_stylebox_override("panel", rule)
	row.custom_minimum_size.y = ROW_HEIGHT
	parent.add_child(row)
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)
	var left := HudStyle.label(line, ROW_SIZE, 500, GameTheme.MUTED.lightened(0.25), HORIZONTAL_ALIGNMENT_LEFT)
	left.text = words
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var right := HudStyle.label(line, ROW_SIZE, 700, value_colour, HORIZONTAL_ALIGNMENT_RIGHT)
	right.text = value
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
