class_name HudFeedRow
extends Control
## One hit-feed line (concept `hud-feed.png`, rounded as UI concept B v2 `hud.png`): who fired, the BB's trail, who was
## hit, and their HIT call, on a rounded navy pill with the shooter's team bar inside its left end. Names in their
## team's colour, "You" in white; a teammate's name carries the teammate chevron; your own lines are framed in teal. A
## teammate's callout (CO2, concept `step27/callouts.png`) is a row of its own kind: the team bar, the speaker's chevron
## and name, a radio glyph and the words. One node: everything is drawn, laid out once each time the line changes.

const HEIGHT := 38.0
const PAD_LEFT := 12.0
const PAD_RIGHT := 8.0
const BAR := 4.0
const GAP := 9.0
const NAME_GAP := 5.0
const NAME_SIZE := 18
const CHEVRON := Vector2(14.0, 11.0)
const TAG_SIZE := 13
const TAG_GLYPH := 15.0
const TAG_PAD := Vector2(6.0, 3.0)
const TAG_GAP := 4.0
const HIT_RED := Color("e23b3b")
## The pill's corners, the team bar's inset from its top and bottom, and the HIT tag's corners.
const RADIUS := 10
const BAR_INSET := 9.0
const TAG_RADIUS := 4
const FRAME_ALPHA := 0.85
const FRAME_WIDTH := 2.0
## Trail dots: three small ones fading in, then the BB with a faint ring.
const DOT := 4.0
const DOT_GAP := 3.0
const BB := 9.0
const BB_RING := 2.0
const BB_RING_ALPHA := 0.25
const DOT_ALPHAS: Array[float] = [0.25, 0.5, 0.75]
## A call's words: their weight and colour; the radio glyph's box (its body under an antenna), the antenna's width and
## height, the speaker grille's lines (how many, their height and the gap between them, inset from the body's sides)
## and its colour.
const WORDS_WEIGHT := 600
const RADIO := Vector2(11.0, 18.0)
const ANTENNA := Vector2(2.0, 5.0)
const GRILLE_LINES := 3
const GRILLE_LINE := 1.5
const GRILLE_GAP := 1.5
const GRILLE_INSET := 2.5
const RADIO_ALPHA := 0.85


## One side of a line, as shown: the name, its colour, and whether it is your teammate (with the chevron) or you (in
## the heavier weight).
class Who:
	var text: String = ""
	var colour: Color = Color.WHITE
	var mate: bool = false
	var you: bool = false

	func set_to(name_text: String, name_colour: Color, is_mate: bool, is_you: bool) -> void:
		text = name_text
		colour = name_colour
		mate = is_mate
		you = is_you


var _name_font: Font = null
var _you_font: Font = null
## The pill, your lines' frame and the HIT tag, made once a row (the pill's colour set at each draw from the panels'
## opacity).
var _plate: StyleBoxFlat = null
var _frame: StyleBoxFlat = null
var _tag_box: StyleBoxFlat = null
var _tag_font: Font = null
var _words_font: Font = null
## A callout row: its words, and where they and the radio glyph sit.
var _call: bool = false
var _words := ""
var _words_x: float = 0.0
var _radio := Rect2()
var _shooter := ""
var _victim := ""
var _shooter_colour := Color.WHITE
var _victim_colour := Color.WHITE
var _shooter_mate: bool = false
var _victim_mate: bool = false
var _shooter_you: bool = false
var _victim_you: bool = false
var _bar := Color.WHITE
var _mate_colour := Color.WHITE
var _framed: bool = false
var _tag_word := ""
# The layout, in px from the left: each name's x, the trail's, the tag's rectangle and the word's x; the text baseline.
var _shooter_x: float = 0.0
var _victim_x: float = 0.0
var _trail_x: float = 0.0
var _tag := Rect2()
var _word_x: float = 0.0
var _baseline: float = 0.0
var _tag_baseline: float = 0.0
var _shooter_chevron := ChevronShape.new()
var _victim_chevron := ChevronShape.new()
var _hand := HandShape.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0.0, HEIGHT)
	_name_font = GameTheme.font(700)
	_you_font = GameTheme.font(800)
	_tag_font = GameTheme.spaced_font(800, HudStyle.SPACING_AIM, TAG_SIZE)
	_words_font = GameTheme.font(WORDS_WEIGHT)
	_tag_word = HudStyle.caps("HUD_HIT_TAG")
	_plate = StyleBoxFlat.new()
	_plate.set_corner_radius_all(RADIUS)
	_plate.anti_aliasing = true
	_frame = StyleBoxFlat.new()
	_frame.draw_center = false
	_frame.set_corner_radius_all(RADIUS)
	_frame.set_border_width_all(roundi(FRAME_WIDTH))
	_frame.border_color = Color(GameTheme.ACCENT, FRAME_ALPHA)
	_frame.anti_aliasing = true
	_tag_box = StyleBoxFlat.new()
	_tag_box.bg_color = HIT_RED
	_tag_box.set_corner_radius_all(TAG_RADIUS)


## Fills the line from `shooter` and `victim` (read now, not kept), the shooter's team colour for the bar, your
## team's for the chevrons, and whether the line is yours (`framed`).
func show_line(shooter: Who, victim: Who, bar: Color, mate_colour: Color, framed: bool) -> void:
	_shooter = shooter.text
	_victim = victim.text
	_shooter_colour = shooter.colour
	_victim_colour = victim.colour
	_shooter_mate = shooter.mate
	_victim_mate = victim.mate
	_shooter_you = shooter.you
	_victim_you = victim.you
	_bar = bar
	_mate_colour = mate_colour
	_framed = framed
	_call = false
	_lay_out()
	queue_redraw()


## Fills the row as `speaker`'s callout (read now, not kept): `words` as said, the bar in `bar` (their team's colour),
## the chevron in `mate_colour`.
func show_call(speaker: Who, words_said: String, bar: Color, mate_colour: Color) -> void:
	_shooter = speaker.text
	_shooter_colour = speaker.colour
	_shooter_mate = speaker.mate
	_shooter_you = speaker.you
	_victim_mate = false
	_words = words_said
	_bar = bar
	_mate_colour = mate_colour
	_framed = false
	_call = true
	_lay_out_call()
	queue_redraw()


## "Owl · Magpie", or a call's "Brick: Two, Crate yard!": the line's words, for tests.
func words() -> String:
	if _call:
		return "%s: %s" % [_shooter, _words]
	return "%s · %s" % [_shooter, _victim]


## Whether the row shows a callout, for tests.
func is_call() -> bool:
	return _call


func is_framed() -> bool:
	return _framed


## Whether the shooter's and the victim's names carry the teammate chevron, for tests.
func has_chevrons() -> Vector2i:
	return Vector2i(1 if _shooter_mate else 0, 1 if _victim_mate else 0)


func _lay_out() -> void:
	var x := BAR + PAD_LEFT
	x = _place_name(x, _shooter_mate, _shooter_chevron)
	_shooter_x = x
	x += _text_width(_shooter, _shooter_you) + GAP
	_trail_x = x
	x += DOT * DOT_ALPHAS.size() + DOT_GAP * DOT_ALPHAS.size() + BB + BB_RING * 2.0 + GAP
	x = _place_name(x, _victim_mate, _victim_chevron)
	_victim_x = x
	x += _text_width(_victim, _victim_you) + GAP
	var word := _tag_font.get_string_size(_tag_word, HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_SIZE).x
	var tag_h := maxf(TAG_GLYPH, _tag_font.get_height(TAG_SIZE)) + TAG_PAD.y * 2.0
	_tag = Rect2(x, (HEIGHT - tag_h) * 0.5, TAG_PAD.x * 2.0 + TAG_GLYPH + TAG_GAP + word, tag_h)
	_hand.fit(Vector2(x + TAG_PAD.x, (HEIGHT - TAG_GLYPH) * 0.5), TAG_GLYPH)
	_word_x = x + TAG_PAD.x + TAG_GLYPH + TAG_GAP
	_tag_baseline = _centred_baseline(_tag_font, TAG_SIZE)
	_baseline = _centred_baseline(_name_font, NAME_SIZE)
	custom_minimum_size.x = _tag.end.x + PAD_RIGHT
	size.x = custom_minimum_size.x


func _lay_out_call() -> void:
	var x := BAR + PAD_LEFT
	x = _place_name(x, _shooter_mate, _shooter_chevron)
	_shooter_x = x
	x += _text_width(_shooter, _shooter_you) + GAP
	_radio = Rect2(x, (HEIGHT - RADIO.y) * 0.5, RADIO.x, RADIO.y)
	x += RADIO.x + GAP
	_words_x = x
	x += _words_font.get_string_size(_words, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE).x
	_baseline = _centred_baseline(_name_font, NAME_SIZE)
	custom_minimum_size.x = x + PAD_LEFT # the words as far from the end as the name from the bar
	size.x = custom_minimum_size.x


func _place_name(x: float, mate: bool, chevron: ChevronShape) -> float:
	if not mate:
		return x
	chevron.fit(Rect2(Vector2(x, (HEIGHT - CHEVRON.y) * 0.5), CHEVRON))
	return x + CHEVRON.x + NAME_GAP


func _text_width(text: String, you: bool) -> float:
	var f := _you_font if you else _name_font
	return f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE).x


static func _centred_baseline(f: Font, font_size: int) -> float:
	return (HEIGHT + f.get_ascent(font_size) - f.get_descent(font_size)) * 0.5


func _draw() -> void:
	var w := size.x
	_plate.bg_color = HudStyle.backing_on(self, HudStyle.BACKING_CLOCK)
	draw_style_box(_plate, Rect2(0.0, 0.0, w, HEIGHT))
	draw_rect(Rect2(BAR, BAR_INSET, BAR, HEIGHT - BAR_INSET * 2.0), _bar)
	if _shooter_mate:
		_shooter_chevron.paint(self, _mate_colour, false)
	draw_string(_you_font if _shooter_you else _name_font, Vector2(_shooter_x, _baseline), _shooter,
			HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE, _shooter_colour)
	if _call:
		_draw_radio()
		draw_string(_words_font, Vector2(_words_x, _baseline), _words, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE,
				GameTheme.TEXT)
		return
	var y := HEIGHT * 0.5
	var x := _trail_x + DOT * 0.5
	for a: float in DOT_ALPHAS:
		draw_circle(Vector2(x, y), DOT * 0.5, Color(1.0, 1.0, 1.0, a))
		x += DOT + DOT_GAP
	var bb := Vector2(x - DOT * 0.5 + BB * 0.5 + BB_RING, y)
	draw_circle(bb, BB * 0.5 + BB_RING, Color(1.0, 1.0, 1.0, BB_RING_ALPHA))
	draw_circle(bb, BB * 0.5, Color.WHITE)
	if _victim_mate:
		_victim_chevron.paint(self, _mate_colour, false)
	draw_string(_you_font if _victim_you else _name_font, Vector2(_victim_x, _baseline), _victim,
			HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE, _victim_colour)
	draw_style_box(_tag_box, _tag)
	_hand.paint(self, Color.WHITE)
	draw_string(_tag_font, Vector2(_word_x, _tag_baseline), _tag_word, HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_SIZE,
			Color.WHITE)
	if _framed:
		draw_style_box(_frame, Rect2(0.0, 0.0, w, HEIGHT))


## The radio glyph: a handset's body under its antenna, the speaker grille cut across it.
func _draw_radio() -> void:
	var r := _radio
	var colour := Color(GameTheme.TEXT, RADIO_ALPHA)
	draw_rect(Rect2(r.position.x + GRILLE_INSET * 0.5, r.position.y, ANTENNA.x, ANTENNA.y), colour)
	var body := Rect2(r.position.x, r.position.y + ANTENNA.y, r.size.x, r.size.y - ANTENNA.y)
	draw_rect(body, colour)
	var cut := HudStyle.backing(1.0, 1.0)
	var y := body.position.y + GRILLE_INSET
	for i in GRILLE_LINES:
		draw_rect(Rect2(body.position.x + GRILLE_INSET, y, body.size.x - GRILLE_INSET * 2.0, GRILLE_LINE), cut)
		y += GRILLE_LINE + GRILLE_GAP
