class_name HudStyle
## The HUD's look in the menus' language (the approved concept's `hud` section): the sizes, the dark charcoal backings and
## the few plain helpers the HUD's parts share. Colours are GameTheme's palette and TeamConfig's team colours, never
## copied; the pure helpers (pip fill, clock and banner words) are unit-tested.

## The score bar: its top margin, height, the team block's width, the clock panel's width and the gap to the aim line (px
## at 1080p; the window scales canvas items).
const SCORE_TOP := 22.0
const SCORE_HEIGHT := 73.0
const BLOCK_WIDTH := 64.0
const CLOCK_WIDTH := 170.0
const AIM_GAP := 9.0
## The bar's one rounded glass plate (its corners) and each team block's inset from the plate's top and bottom and its
## corners (UI concept B v2 `hud.png`).
const SCORE_RADIUS := 14.0
const BLOCK_INSET := 7.0
const BLOCK_RADIUS := 8.0
## The ATK / DEF tags' corners.
const TAG_RADIUS := 4.0
## How many points a rounded corner is drawn with.
const CORNER_STEPS := 5
## The slanted pips: size, gap, border, side padding and the lean (tan 14 degrees, the concept's `skewX(-14deg)`).
const PIP_SIZE := Vector2(16.0, 22.0)
const PIP_GAP := 6.0
const PIP_BORDER := 2.0
const SIDE_PAD := 16.0
const PIP_LEAN := 0.2493
## The empty pip's outline, as a share of the text colour.
const PIP_EMPTY_ALPHA := 0.35
## Type sizes the concept sets: team score, clock, the round under it, the aim line, banners, chips and notes.
const SCORE_SIZE := 34
const CLOCK_SIZE := 40
const ROUND_SIZE := 14
const AIM_SIZE := 15
const BANNER_SIZE := 72
const BANNER_SUB_SIZE := 20
const CHIP_SIZE := 13
const NOTE_SIZE := 15
const COUNT_SIZE := 40
## The start countdown's padding (left, top, right, bottom): a square-ish plate round a single digit.
const COUNT_PAD := Vector4(48.0, 6.0, 48.0, 10.0)
const SPARE_SIZE := 16
## A dark box's alpha before the panel opacity (a meta on the box), the panel opacity a part draws at (a meta on the
## part), and the slots restyle() looks in.
const BOX_ALPHA := &"hud_alpha"
const OPACITY := &"hud_opacity"
const BOX_SLOTS: Array[StringName] = [&"panel", &"normal"]
static var _tight: Dictionary[int, Font] = {}
## How dark each backing is (the page colour at this opacity).
const BACKING_SIDE := 0.82
const BACKING_CLOCK := 0.92
const BACKING_BANNER := 0.86
const BACKING_AIM := 0.55
const BACKING_PANEL := 0.82
## A spare magazine's box, as a share of the text colour (the loaded one is full strength).
const MAG_SPARE_ALPHA := 0.85
## Words on a team colour fill: dark on a fill lighter than this (luminance; High contrast's light blue), else light.
## Standard's blue and orange stay under it.
const INK_DARK_ABOVE := 0.7
## The banner: padding (px) and the yellow rule along its top edge.
const BANNER_PAD := Vector4(80.0, 20.0, 80.0, 20.0)
const BANNER_RULE := 4.0
const BANNER_SUB_GAP := 8
## Attack / Defend: the ATK / DEF tags over the team blocks (height, type size), "OT" before the clock (size, gap), the
## flag gauge under the bar (height, type size, the gap between notches) and its warning (type size, padding).
const TAG_HEIGHT := 18.0
const TAG_SIZE := 12
const OT_SIZE := 24
const OT_GAP := 8.0
const GAUGE_HEIGHT := 28.0
const GAUGE_LABEL_SIZE := 12
const GAUGE_LABEL_WIDTH := 72.0
const GAUGE_NOTCH_GAP := 3.0
const GAUGE_PAD := 10.0
const WARNING_SIZE := 30
## The warning's opacity at the low point of its pulse; the marker over the pole's type size.
const WARNING_PULSE_LOW := 0.4
const MARKER_SIZE := 21
const WARNING_GLYPH := 36.0
## Letter spacing in em: the clock's round line, the aim line, banners and their second line.
const SPACING_ROUND := 0.1
const SPACING_AIM := 0.08
const SPACING_BANNER := 0.06
const SPACING_SUB := 0.08
## Gauge patterns (Settings › Accessibility, GaugePattern; concept `gauge-patterns.png`): 45° stripes of STRIPE_WIDTH px
## with STRIPE_GAP px between them across (at 1080p), in the page colour at STRIPE_ALPHA over the fill. STRIPED_TEAM's
## fills are the striped ones (Beta's; Alpha's stay solid, in both colour sets). A number on a striped block gets a
## dark edge of NUMBER_EDGE px in the page colour at NUMBER_EDGE_ALPHA, so it stays readable.
const STRIPE_WIDTH := 3.0
const STRIPE_GAP := 4.0
const STRIPE_ALPHA := 0.58
const STRIPE_INK := Color(GameTheme.BG, STRIPE_ALPHA)
const STRIPED_TEAM := 1
const NUMBER_EDGE := 5
const NUMBER_EDGE_ALPHA := 0.9


## The page colour at `alpha`, scaled by a panel `opacity` (restyle: the HUD opacity fades only the replica panel's and
## the minimap's backgrounds, UR8 and UF1; the rest of the HUD keeps its backings at 1).
static func backing(alpha: float, opacity: float = 1.0) -> Color:
	return Color(GameTheme.BG, alpha * opacity)


## The colour of words on a team colour `fill` (the score blocks, the tables' badges): dark on a light fill, else
## `light`.
static func ink_on(fill: Color, light: Color = GameTheme.TEXT) -> Color:
	return GameTheme.BG if fill.get_luminance() > INK_DARK_ABOVE else light


## Gives the number `l` on a team block its dark edge while the block is `striped`, and takes it off when not.
static func edge_number(l: Label, striped: bool) -> void:
	l.add_theme_constant_override("outline_size", NUMBER_EDGE if striped else 0)
	l.add_theme_color_override("font_outline_color", Color(GameTheme.BG, NUMBER_EDGE_ALPHA))


## The backing a HUD `part` draws itself at `alpha`: at the panel opacity restyle() gave it (100% until then).
static func backing_on(part: CanvasItem, alpha: float) -> Color:
	return backing(alpha, opacity_of(part))


## The panel opacity restyle() gave `part` (1 until then), for a background it draws other than a backing.
static func opacity_of(part: CanvasItem) -> float:
	return part.get_meta(OPACITY, 1.0) as float


## A dark panel at `alpha` with an `edge` and the given margins, at 100% until restyle() brings it to a panel opacity.
static func dark_box(alpha: float, edge: Color, margin_x: int, margin_y: int) -> StyleBoxFlat:
	var box := GameTheme.box(backing(alpha), edge, margin_x, margin_y)
	box.set_meta(BOX_ALPHA, alpha)
	return box


## Brings `root` and every part under it to the panel `opacity`: each dark_box, and each part that draws its own
## backing (backing_on, opacity_of). Only backgrounds fade; icons, numbers and words keep their own alpha. Whoever owns
## the parts calls it again for parts added later.
static func restyle(root: Control, opacity: float) -> void:
	for slot: StringName in BOX_SLOTS:
		var box := root.get_theme_stylebox(slot) as StyleBoxFlat if root.has_theme_stylebox_override(slot) else null
		if box != null and box.has_meta(BOX_ALPHA):
			box.bg_color.a = (box.get_meta(BOX_ALPHA) as float) * opacity
	root.set_meta(OPACITY, opacity)
	root.queue_redraw()
	for child in root.get_children():
		var sub := child as Control
		if sub != null:
			restyle(sub, opacity)


## How many of `count` pips a score of `wins` fills: one per win, never more than there are.
static func pips_filled(wins: int, count: int) -> int:
	return clampi(wins, 0, maxi(0, count))


## A slanted pip with its box's top left at `at`: a parallelogram leaning right, its top edge shifted right and its
## bottom edge left.
static func pip_shape(at: Vector2) -> PackedVector2Array:
	var s := PIP_SIZE.y * 0.5 * PIP_LEAN
	return PackedVector2Array([
		Vector2(at.x + s, at.y), Vector2(at.x + PIP_SIZE.x + s, at.y),
		Vector2(at.x + PIP_SIZE.x - s, at.y + PIP_SIZE.y), Vector2(at.x - s, at.y + PIP_SIZE.y),
	])


## `rect` with corners rounded to `radius`, as a convex outline (clockwise from the top left's end), for a filled shape
## or GaugePattern.set_shape. Built once, never per frame.
static func rounded_rect(rect: Rect2, radius: float) -> PackedVector2Array:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var out := PackedVector2Array()
	var centres: Array[Vector2] = [
		Vector2(rect.end.x - r, rect.position.y + r), Vector2(rect.end.x - r, rect.end.y - r),
		Vector2(rect.position.x + r, rect.end.y - r), Vector2(rect.position.x + r, rect.position.y + r),
	]
	for corner in 4:
		var start := -PI * 0.5 + corner * PI * 0.5
		for i in CORNER_STEPS + 1:
			var a := start + PI * 0.5 * float(i) / float(CORNER_STEPS)
			out.append(centres[corner] + Vector2(cos(a), sin(a)) * r)
	return out


## The width of one team's pip block for `count` pips.
static func side_width(count: int) -> float:
	return SIDE_PAD * 2.0 + count * PIP_SIZE.x + maxi(0, count - 1) * PIP_GAP


## "m:ss" for the clock.
static func clock_text(seconds: int) -> String:
	var s := maxi(0, seconds)
	return "%d:%02d" % [s / 60, s % 60]


## The banners' words, in capitals. A round's start names the round; the second line says the ends swap on the round
## after the half (`half_time_after` decided rounds), else it is empty.
static func round_title(number: int) -> String:
	return (TranslationServer.translate(&"HUD_ROUND") % number).to_upper()


static func round_sub(number: int, half_time_after: int) -> String:
	if half_time_after > 0 and number == half_time_after + 1:
		return TranslationServer.translate(&"HUD_HALF_TIME").to_upper()
	return ""


## Attack / Defend's round start: "ROUND 3 · ATTACK" or "ROUND 3 · DEFEND", and the job under it (or half time).
static func side_round_title(number: int, attacking: bool) -> String:
	var side := TranslationServer.translate(&"HUD_ATTACK" if attacking else &"HUD_DEFEND")
	return (TranslationServer.translate(&"HUD_ROUND_SIDE") % [number, side]).to_upper()


static func side_round_sub(number: int, half_time_after: int, attacking: bool) -> String:
	var half := round_sub(number, half_time_after)
	if not half.is_empty():
		return half
	return caps("HUD_TAKE_FLAG" if attacking else "HUD_HOLD_POLE")


## Plant The Bomb's round start under the same title: "PLANT THE BOMB" for the attackers, "HOLD SITES A AND B" ("HOLD
## SITE A" on a map with one) for the defenders, or half time. `sites` is how many sites the map has.
static func plant_round_sub(number: int, half_time_after: int, attacking: bool, sites: int) -> String:
	var half := round_sub(number, half_time_after)
	if not half.is_empty():
		return half
	if attacking:
		return caps("HUD_PLANT_THE_BOMB")
	if sites < 2:
		return (TranslationServer.translate(&"HUD_HOLD_SITE") % Plant.LETTERS[0]).to_upper()
	return (TranslationServer.translate(&"HUD_HOLD_SITES") % [Plant.LETTERS[0], Plant.LETTERS[1]]).to_upper()


## The banner when the bomb is armed in site `site`: "BOMB PLANTED AT A", and the line under it for the attackers
## (`attacking`) or the defenders.
static func bomb_planted_title(site: int) -> String:
	var letter: String = Plant.LETTERS[clampi(site, 0, Plant.MOST - 1)]
	return (TranslationServer.translate(&"HUD_BOMB_PLANTED_AT") % letter).to_upper()


static func bomb_planted_sub(attacking: bool) -> String:
	return caps("HUD_BOMB_PLANTED_ATTACK" if attacking else "HUD_BOMB_PLANTED_DEFEND")


## A round's end by a flag: Attack / Defend's by the flag or the clock, "FLAG RAISED" / "ALPHA TAKE THE ROUND", or
## "DEFENDED" / "TIME'S UP · BETA HELD THE POLE"; Elimination's overtime flag touched, "FLAG TOUCHED" / "ALPHA TAKE THE
## ROUND". Plant The Bomb's (`bomb`): "BOMB WENT OFF" / "BOMB DEFUSED", or the clock run out with nothing planted,
## "DEFENDED" / "TIME'S UP · NOTHING PLANTED".
static func flag_round_won(reason: GameEvent.RoundEnd) -> String:
	match reason:
		GameEvent.RoundEnd.CAPTURED:
			return caps("HUD_FLAG_RAISED")
		GameEvent.RoundEnd.OVERTIME_FLAG:
			return caps("HUD_FLAG_TOUCHED")
		GameEvent.RoundEnd.WENT_OFF:
			return caps("HUD_BOMB_WENT_OFF")
		GameEvent.RoundEnd.DEFUSED:
			return caps("HUD_BOMB_DEFUSED")
	return caps("HUD_DEFENDED")


static func flag_round_sub(reason: GameEvent.RoundEnd, team_name_key: String, bomb: bool = false) -> String:
	var won := reason == GameEvent.RoundEnd.CAPTURED or reason == GameEvent.RoundEnd.OVERTIME_FLAG \
			or reason == GameEvent.RoundEnd.WENT_OFF or reason == GameEvent.RoundEnd.DEFUSED
	if bomb and reason == GameEvent.RoundEnd.TIME:
		return caps("HUD_BOMB_NO_PLANT")
	var key := &"HUD_ROUND_WON" if won else &"HUD_HELD_POLE"
	return (TranslationServer.translate(key) % TranslationServer.translate(team_name_key)).to_upper()


## Whether a round that ended for `reason` in `mode` ended by a flag (flag_round_won's lines): Attack / Defend's and
## Plant The Bomb's other than by eliminations or a simulated skip (BP8), or Elimination's overtime flag touched.
static func ended_by_flag(mode: RoundState.Mode, reason: GameEvent.RoundEnd) -> bool:
	if reason == GameEvent.RoundEnd.OVERTIME_FLAG:
		return true
	return RoundState.has_sides(mode) and reason != GameEvent.RoundEnd.ELIMINATED \
			and reason != GameEvent.RoundEnd.SIMULATED


## The overtime seconds the clock shows after "OT" while the live round in `rs` is in overtime, or -1 when it isn't:
## Attack / Defend's once time has run out while the attackers work the rope (`max_overtime` less what was played), or
## Elimination's while the overtime flag stands (its time left). Plant The Bomb's is the fuse's whole seconds left once
## the bomb is armed, else the overtime of a plant under way at the buzzer, as the rope's. The score bar and the
## scoreboard's heading both read it.
static func overtime_clock(rs: RoundState, max_overtime: float) -> int:
	if not rs.is_live():
		return -1
	if rs.mode == RoundState.Mode.PLANT_THE_BOMB:
		if rs.plant.planted():
			return maxi(0, ceili(rs.plant.fuse_left))
		return overtime_left(rs.overtime, max_overtime) if rs.clock <= 0.0 and rs.overtime > 0.0 else -1
	if rs.mode == RoundState.Mode.ATTACK_DEFEND:
		return overtime_left(rs.overtime, max_overtime) if rs.clock <= 0.0 and rs.overtime > 0.0 else -1
	return maxi(0, ceili(rs.overtime_flag.left)) if rs.overtime_flag.up else -1


## The overtime left on the clock (whole seconds, never below 0): `max_overtime` less what has been played.
static func overtime_left(overtime: float, max_overtime: float) -> int:
	return maxi(0, ceili(maxf(0.0, max_overtime - overtime)) if is_finite(overtime) else 0)


## The round's stamp from your side: WON, LOST or DRAW (`winner` -1), and the line under it: "ROUND 4 · ALPHA TAKE
## THE ROUND", "ROUND 3 · FLAG RAISED · ALPHA TAKE THE ROUND" ("FLAG TOUCHED" at the overtime flag), or a draw's
## "ROUND 5 · THE ROUND IS PLAYED AGAIN". Plant The Bomb's (`bomb`): "ROUND 2 · BOMB WENT OFF · ALPHA TAKE THE ROUND".
static func round_stamp(winner: int, your_team: int) -> String:
	if winner < 0:
		return caps("HUD_ROUND_DRAW")
	return caps("HUD_WON" if winner == your_team else "HUD_LOST")


static func round_stamp_sub(number: int, winner: int, team_name_key: String, by_flag: bool,
		reason: GameEvent.RoundEnd, bomb: bool = false) -> String:
	var head := round_title(number)
	if winner < 0:
		return "%s · %s" % [head, caps("HUD_ROUND_DRAW_SUB")]
	if by_flag:
		return "%s · %s · %s" % [head, flag_round_won(reason), flag_round_sub(reason, team_name_key, bomb)]
	if reason == GameEvent.RoundEnd.SIMULATED:
		return "%s · %s · %s" % [head, caps("HUD_SIMULATED"), round_won(team_name_key)]
	return "%s · %s" % [head, round_won(team_name_key)]


## "ROUND 4 · 1:30 PLAYED": the round's table title.
static func round_played(number: int, seconds: int) -> String:
	return "%s · %s" % [round_title(number), (TranslationServer.translate(&"HUD_PLAYED") % clock_text(seconds)).to_upper()]


static func round_won(team_name_key: String) -> String:
	return (TranslationServer.translate(&"HUD_ROUND_WON") % TranslationServer.translate(team_name_key)).to_upper()


## "FIRST TO 5": the match's aim, under the clock.
static func first_to(wins: int) -> String:
	return (TranslationServer.translate(&"HUD_FIRST_TO") % wins).to_upper()


static func caps(key: String) -> String:
	return TranslationServer.translate(key).to_upper()


## A flat panel in the page colour at `alpha` with the given margins.
static func panel_box(alpha: float, margin_x: int, margin_y: int) -> StyleBoxFlat:
	return dark_box(alpha, Color(0.0, 0.0, 0.0, 0.0), margin_x, margin_y)


## Inter at `weight` whose line is `font_size` tall, as the concept's line-height 1 sets it: the font's own leading
## taken off evenly above and below (BP6: the replica panel's 40 px count stood in a 48 px line). One per weight and
## size.
static func tight_font(weight: int, font_size: int) -> Font:
	var key := weight * 1000 + font_size
	if _tight.has(key):
		return _tight[key]
	var v := FontVariation.new()
	v.base_font = GameTheme.font(weight)
	var extra := roundi(v.base_font.get_height(font_size)) - font_size
	v.spacing_top = -(extra / 2)
	v.spacing_bottom = -(extra - extra / 2)
	_tight[key] = v
	return v


## A Label under `parent` in Inter at `weight`, with `em_spacing` between letters (0 for none).
static func label(parent: Control, font_size: int, weight: int, colour: Color, align: HorizontalAlignment,
		em_spacing: float = 0.0) -> Label:
	var l := Label.new()
	var font := GameTheme.spaced_font(weight, em_spacing, font_size) if em_spacing > 0.0 else GameTheme.font(weight)
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", colour)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l
