class_name FieldMapKey
extends Control
## The full-screen map's key (FM2), down its right side: each mark the map draws beside what it means, in the map's own
## shapes and colours (your team's and the other's set by set_teams). Drawn once; redrawn only when the colours change.

enum Glyph { YOU, MATE, OUT, STEPS, SHOT, PING, ORDER, FLAG, START, DEAD, DOOR, LOW, WALL, GREEN }

## The rows, in order, and their words.
const ROWS: Array[Glyph] = [Glyph.YOU, Glyph.MATE, Glyph.OUT, Glyph.STEPS, Glyph.SHOT, Glyph.PING, Glyph.ORDER,
		Glyph.FLAG, Glyph.START, Glyph.DEAD, Glyph.DOOR, Glyph.LOW, Glyph.WALL, Glyph.GREEN]
const WORDS: Array[String] = ["MAP_KEY_YOU", "MAP_KEY_MATE", "MAP_KEY_OUT", "MAP_KEY_STEPS", "MAP_KEY_SHOT",
		"MAP_KEY_PING", "MAP_KEY_ORDER", "MAP_KEY_FLAG", "MAP_KEY_START", "MAP_KEY_DEAD", "MAP_KEY_DOOR",
		"MAP_KEY_LOW", "MAP_KEY_WALL", "MAP_KEY_GREEN"]
## Sizes (px at 1080p): the heading's and a row's type, a row's height, the glyph's column and its half size, the
## inner padding, the rings' widths, the ink under a glyph.
const HEADING_SIZE := 13
const WORD_SIZE := 14
const ROW := 30.0
const GLYPH_COLUMN := 34.0
const GLYPH := 8.0
const PAD := 18.0
const RING := 2.2
const INK := 1.8
const ARC_POINTS := 24
## A heard shot's disc and a start's box fill, as alphas of the other team's and your team's colour; a dashed ring's
## dashes.
const SHOT_FILL := 0.75
const START_FILL := 0.25
const DASHES := 6
## The flag's badge: its radius (px), where it sits from the ring's middle (px) and its letter.
const FLAG_BADGE := 7.0
const FLAG_BADGE_AT := Vector2(-6.0, -6.0)
const FLAG_LETTER := "A"
## The arrow (you), the diamond (an order), as the map's own.
const YOU_SHAPE: Array[Vector2] = [Vector2(0.0, -9.5), Vector2(7.0, 7.5), Vector2(0.0, 3.6), Vector2(-7.0, 7.5)]
const DIAMOND_SHAPE: Array[Vector2] = [Vector2(0.0, -8.0), Vector2(8.0, 0.0), Vector2(0.0, 8.0), Vector2(-8.0, 0.0)]

var _cfg: MinimapConfig = null
var _team := Color.WHITE
var _enemy := Color.WHITE
var _font: Font = null
var _heading_font: Font = null
var _badge_font: Font = null
var _heading: String = ""
var _words := PackedStringArray()
var _you := PackedVector2Array()
var _diamond := PackedVector2Array()


func setup(cfg: MinimapConfig) -> void:
	_cfg = cfg
	name = "Key"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = GameTheme.font(600)
	_heading_font = GameTheme.spaced_font(800, HudStyle.SPACING_SUB, HEADING_SIZE)
	_badge_font = GameTheme.font(800)
	_heading = HudStyle.caps("MAP_KEY")
	for w in WORDS:
		_words.append(tr(w))
	for p in YOU_SHAPE:
		_you.append(p)
	for p in DIAMOND_SHAPE:
		_diamond.append(p)


## Your team's colour and the other's.
func set_teams(team: Color, enemy: Color) -> void:
	if team == _team and enemy == _enemy:
		return
	_team = team
	_enemy = enemy
	queue_redraw()


## The height its rows take (px), heading and padding included.
func needed_height() -> float:
	return PAD * 2.0 + ROW * (ROWS.size() + 1)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), HudStyle.backing_on(self, HudStyle.BACKING_PANEL))
	var y := PAD + _heading_font.get_ascent(HEADING_SIZE)
	draw_string(_heading_font, Vector2(PAD, y), _heading, HORIZONTAL_ALIGNMENT_LEFT, -1, HEADING_SIZE, GameTheme.MUTED)
	var top := PAD + ROW
	for i in ROWS.size():
		var mid := Vector2(PAD + GLYPH_COLUMN * 0.5, top + ROW * (i + 0.5))
		_draw_glyph(ROWS[i], mid)
		var base := Vector2(PAD + GLYPH_COLUMN + PAD * 0.5, mid.y + _font.get_ascent(WORD_SIZE) * 0.5 - 1.0)
		draw_string(_font, base, _words[i], HORIZONTAL_ALIGNMENT_LEFT, size.x - base.x - PAD, WORD_SIZE,
				GameTheme.TEXT)


func _draw_glyph(g: Glyph, at: Vector2) -> void:
	var box := Rect2(at - Vector2(GLYPH, GLYPH * 0.7), Vector2(GLYPH * 2.0, GLYPH * 1.4))
	match g:
		Glyph.YOU:
			draw_set_transform(at, 0.0, Vector2.ONE)
			draw_colored_polygon(_you, _cfg.you_colour)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		Glyph.MATE, Glyph.OUT:
			draw_circle(at, _cfg.dot_radius + INK, _cfg.ink)
			draw_circle(at, _cfg.dot_radius, _team if g == Glyph.MATE else _cfg.out_colour)
		Glyph.STEPS:
			draw_circle(at, GLYPH, Color(_enemy, _cfg.patch_fill))
			var dash := TAU / (DASHES * 2.0)
			for d in DASHES:
				draw_arc(at, GLYPH, dash * 2.0 * d, dash * (2.0 * d + 1.0), 4, _enemy, RING, true)
		Glyph.SHOT:
			draw_circle(at, GLYPH, Color(_enemy, SHOT_FILL))
		Glyph.PING:
			draw_arc(at, _cfg.ping_ring_radius, 0.0, TAU, ARC_POINTS, _cfg.ink, _cfg.ping_ring_width + INK, true)
			draw_arc(at, _cfg.ping_ring_radius, 0.0, TAU, ARC_POINTS, _team, _cfg.ping_ring_width, true)
		Glyph.ORDER:
			draw_set_transform(at, 0.0, Vector2.ONE)
			draw_colored_polygon(_diamond, Color(_team, _cfg.hold_fill))
			draw_polyline(_diamond, _team, RING, true)
			draw_line(_diamond[_diamond.size() - 1], _diamond[0], _team, RING, true)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		Glyph.FLAG:
			# The map's ring round the pole, its lettered badge over the ring's top left.
			draw_arc(at, GLYPH, 0.0, TAU, ARC_POINTS, _cfg.ink, _cfg.map_flag_ring_width + INK, true)
			draw_arc(at, GLYPH, 0.0, TAU, ARC_POINTS, GameTheme.YELLOW, _cfg.map_flag_ring_width, true)
			var badge := at + FLAG_BADGE_AT
			draw_circle(badge, FLAG_BADGE + INK, _cfg.ink)
			draw_circle(badge, FLAG_BADGE, GameTheme.YELLOW)
			var fs := roundi(FLAG_BADGE * _cfg.map_badge_type)
			var s := _badge_font.get_string_size(FLAG_LETTER, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			draw_string(_badge_font, Vector2(badge.x - s.x * 0.5, badge.y - s.y * 0.5 + _badge_font.get_ascent(fs)),
					FLAG_LETTER, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, GameTheme.YELLOW_INK)
		Glyph.START:
			draw_rect(box, Color(_team, START_FILL))
			draw_rect(box, _team, false, _cfg.map_zone_ring)
		Glyph.DEAD:
			draw_line(box.position + Vector2(box.size.x * 0.5, 0.0), box.position + Vector2(0.0, box.size.y),
					_cfg.map_dead_colour, RING * 0.6)
			draw_line(box.end - Vector2(0.0, box.size.y), box.end - Vector2(box.size.x * 0.5, 0.0),
					_cfg.map_dead_colour, RING * 0.6)
			draw_rect(box, _cfg.map_dead_colour, false, _cfg.map_zone_ring)
		Glyph.DOOR:
			draw_line(at - Vector2(GLYPH, 0.0), at + Vector2(GLYPH, 0.0), _cfg.ink, _cfg.map_door_width + INK * 2.0)
			draw_line(at - Vector2(GLYPH, 0.0), at + Vector2(GLYPH, 0.0), _cfg.map_door_colour, _cfg.map_door_width)
		Glyph.LOW:
			draw_rect(box, _cfg.low_colour)
		Glyph.WALL:
			draw_rect(box, _cfg.tall_colour)
		Glyph.GREEN:
			draw_rect(box, _cfg.green_tall_colour)
