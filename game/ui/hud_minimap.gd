class_name HudMinimap
extends Control
## The minimap on the HUD (concepts `minimap-play.png`, `minimap-attack.png`, `minimap-out.png`, `minimap-storeys.png`;
## the browser game's M23, M34c and M83): a square panel top left with the field round the character the view is through,
## the area they stand in at its top left and "Depot · Round 2" under it. It shows you as a white arrow, your teammates as
## dots in the team's colour (grey once hit, an arrow up or down on another storey, pinned to the edge when off the
## panel), Attack / Defend's pole while the round is live, Elimination's overtime flag (a chequered flag) while it
## stands in a live round, your Hold here's spot as a diamond, your team's pings (PN2: a spot's ring in the team's colour,
## a contact's diamond in the other team's, on the rim when off the panel; `add_pings`), and the other team only as
## the patches where your side last heard them (MinimapHearing). Rotating turns the field so the way you look is up;
## Fixed keeps north (the map's -z) up and turns the arrow. The field is drawn once a match (MinimapField, one picture per
## storey) and the panel only places it, so a frame allocates nothing. `View` draws everything over the picture; the
## settings' thumbnails use it too, and so does the full-screen map (HudFieldMap, FM1), whole and north up, through
## `fill` and `add_pings` with its own View.

## The panel's and the caption's navy, before the panels' opacity.
const BACKING := 1.0
const CAPTION_SIZE := 15
const CAPTION_PAD := 10
const CAPTION_SPACING := 0.02
## The space either side of the caption's muted dot (px).
const CAPTION_DOT_GAP := 5
const AREA_SIZE := 12
const AREA_SPACING := 0.12
const AREA_PAD := Vector4i(7, 3, 8, 3)
const AREA_CORNER := 2

var _cfg: MinimapConfig = null
var _teams: TeamConfig = null
var _map: MapData = null
var _field: MinimapField = null
var _textures: Array[Texture2D] = []
var _heard: MinimapHearing = null
var _view: View = null
var _area: Label = null
var _area_name: String = ""
var _round_label: Label = null
var _round: int = -1
var _corner: Vector2 = Vector2.ZERO


## Builds the panel for `map` (its field drawn now, once: call this behind the loading screen, never per frame) with
## `heard`'s patches and `map_name` in its caption, its top left `corner` px from the screen's. `capacity` is the most
## characters a match has.
func setup(cfg: MinimapConfig, teams: TeamConfig, map: MapData, heard: MinimapHearing, map_name: String,
		capacity: int, corner: Vector2) -> void:
	_cfg = cfg
	_corner = corner
	_teams = teams
	_map = map
	_heard = heard
	name = "HudMinimap"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0
	offset_left = corner.x
	offset_top = corner.y
	offset_right = corner.x + cfg.size
	offset_bottom = corner.y + cfg.size + cfg.caption_room
	_field = MinimapField.build(map, cfg)
	_textures = textures_of(_field)
	_view = View.new()
	var inner := cfg.size - cfg.ring * 2.0
	_view.position = Vector2(cfg.ring, cfg.ring)
	_view.size = Vector2(inner, inner)
	_view.setup(cfg, _textures, _field.scale, _field.origin, capacity)
	add_child(_view)
	_area = HudStyle.label(self, AREA_SIZE, 800, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT, AREA_SPACING)
	_area.uppercase = true
	var box := HudStyle.panel_box(cfg.label_backing, AREA_PAD.x, AREA_PAD.y)
	box.content_margin_right = AREA_PAD.z
	box.content_margin_bottom = AREA_PAD.w
	box.corner_radius_bottom_right = AREA_CORNER
	_area.add_theme_stylebox_override("normal", box)
	_area.position = Vector2(cfg.ring, cfg.ring)
	_area.visible = false
	_build_caption(map_name)


## One texture for each of `field`'s layers, with mipmaps (a drawing at 10 px/m is shown at about 5, and less in a small
## window), made once; they go with whoever holds them.
static func textures_of(field: MinimapField) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	for img in field.layers:
		img.generate_mipmaps()
		textures.append(ImageTexture.create_from_image(img))
	return textures


## The picture of the field (for tests, and the full-screen map's storeys).
func field() -> MinimapField:
	return _field


## The teams' colours it draws in.
func teams() -> TeamConfig:
	return _teams


## The field's layers as textures, one per storey (the full-screen map draws the same ones).
func textures() -> Array[Texture2D]:
	return _textures


func view() -> View:
	return _view


## The area label's words ("" while it shows none), and the caption's round line: for tests.
func area_text() -> String:
	return _area.text if _area.visible else ""


func caption_text() -> String:
	var parts := _round_label.get_parent().get_children()
	var words := PackedStringArray()
	for p in parts:
		words.append((p as Label).text)
	return " ".join(words)


## The top (px from the screen's top) of what sits under the panel and its caption: the moved What got you card, and
## the markers pinned past the panel's side.
func under_top() -> float:
	return _corner.y + _cfg.size + _cfg.caption_room + _cfg.under_gap


## How far apart (px) markers stacked down the panel's side sit.
func step_down() -> float:
	return _cfg.pin_step_down


## What the panel and its caption cover on the screen (nothing while it is hidden).
func panel_rect() -> Rect2:
	if not visible:
		return Rect2()
	return Rect2(_corner, Vector2(_cfg.size, _cfg.size + _cfg.caption_room))


## Where the first marker pinned to the screen's left edge sits (the top left of its plate): under the panel and its
## caption, or under a card that hangs there (`card_bottom`, its lower edge; 0 for none).
func pin(card_bottom: float) -> Vector2:
	var top := under_top()
	if card_bottom > 0.0:
		top = maxf(top, card_bottom + _cfg.under_gap)
	return Vector2(_cfg.pin_x, top)


## Places the panel on the character `watched` (the view is through them), looking `yaw`, as they stand `fraction` of
## the way from their last tick to this one: the field, the area they stand in, the round, the teammates, the patches
## and the markers. `hold` is where your Hold here stands when `holding`. Allocates nothing.
func follow(state: GameState, watched: Character, yaw: float, fraction: float, turn: HudPrefs.MinimapTurn,
		holding: bool, hold: Vector3) -> void:
	var feet := watched.prev_position.lerp(watched.position, fraction)
	var storey := _field.storey_of(feet.y)
	var rotating := turn == HudPrefs.MinimapTurn.ROTATING
	var team := _teams.colours[watched.team]
	_view.begin(Vector2(feet.x, feet.z), storey if storey < _view.layers() else -1, yaw, rotating, team,
			_teams.colours[1 - watched.team])
	var area := MapAreas.area_at(_map.areas, feet)
	if area != _area_name:
		_area_name = area
		_area.text = area
		_area.visible = area != ""
		_area.reset_size()
	var rs := state.round_state
	if rs.number != _round:
		_round = rs.number
		# Practice on a field has no rounds: its caption says Practice.
		_round_label.text = tr("MODE_PRACTICE") if rs.practice else tr("HUD_ROUND") % _round
	fill(_view, state, watched, fraction, storey, holding, hold)


## Puts on `view` (begun for this frame) what the minimap shows over the field for `watched`, on `storey`, `fraction` of
## the way through the tick: the teammates, the patches your side heard, the pole or the overtime flag while the round
## is live, and Hold here's spot `hold` when `holding`. Never the other team itself. Allocates nothing.
func fill(view: View, state: GameState, watched: Character, fraction: float, storey: int, holding: bool,
		hold: Vector3) -> void:
	var rs := state.round_state
	var team := _teams.colours[watched.team]
	for c in state.characters:
		if c.team != watched.team or c == watched:
			continue
		var at := c.prev_position.lerp(c.position, fraction)
		var out := not Elimination.is_in_play(c)
		var arrow := 0
		var level := _field.storey_of(at.y)
		if level != storey:
			arrow = 1 if level > storey else -1
		view.add_dot(Vector2(at.x, at.z), _cfg.out_colour if out else team, arrow)
	for p in _heard.patches:
		if p.live and _field.storey_of(p.centre.y) == storey:
			view.add_patch(Vector2(p.centre.x, p.centre.z), p.radius, p.sound == MinimapHearing.Sound.SHOT,
					_heard.shade(p))
	if rs.mode == RoundState.Mode.ATTACK_DEFEND and rs.attackers >= 0 and rs.is_live():
		view.set_pole(Vector2(rs.pole.x, rs.pole.z))
	elif rs.overtime_flag.up and rs.is_live():
		view.set_pole(Vector2(rs.overtime_flag.foot.x, rs.overtime_flag.foot.z), true)
	if holding:
		view.set_hold(Vector2(hold.x, hold.z))
	view.queue_redraw()


## Adds the pings of `team` up in `book` at `now` (s of match time) to this frame's panel (after follow), or to `to`
## (the full-screen map's view, after its fill): each fading over the last `fade` s of its `life`, as its marker on the
## field does. Allocates nothing.
func add_pings(book: Pings, team: int, now: float, life: float, fade: float, to: View = null) -> void:
	var view := to if to != null else _view
	for i in book.size():
		var p := book.of(i)
		if p.team == team and book.is_up(p, now):
			view.add_ping(Vector2(p.spot.x, p.spot.z), p.kind == Pings.Kind.CONTACT,
					HudPingMarker.shade(now - p.at, life, fade))


## The panel's ring.
func _draw() -> void:
	var s := _cfg.size
	var r := _cfg.ring
	draw_rect(Rect2(0.0, 0.0, s, r), GameTheme.LINE)
	draw_rect(Rect2(0.0, s - r, s, r), GameTheme.LINE)
	draw_rect(Rect2(0.0, r, r, s - r * 2.0), GameTheme.LINE)
	draw_rect(Rect2(s - r, r, r, s - r * 2.0), GameTheme.LINE)


## The caption under the panel: the map, a muted dot and the round, on a navy strip.
func _build_caption(map_name: String) -> void:
	var strip := PanelContainer.new()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_theme_stylebox_override("panel", HudStyle.panel_box(BACKING, CAPTION_PAD, 0))
	strip.position = Vector2(0.0, _cfg.size + _cfg.caption_gap)
	strip.custom_minimum_size = Vector2(_cfg.size, _cfg.caption_room - _cfg.caption_gap)
	add_child(strip)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", CAPTION_DOT_GAP)
	strip.add_child(row)
	var map_label := HudStyle.label(row, CAPTION_SIZE, 700, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT, CAPTION_SPACING)
	map_label.text = map_name
	var dot := HudStyle.label(row, CAPTION_SIZE, 700, GameTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, CAPTION_SPACING)
	dot.text = "·"
	_round_label = HudStyle.label(row, CAPTION_SIZE, 700, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT, CAPTION_SPACING)


## The square the field and everything over it is drawn in (clipped to it), from what the owner hands it each frame
## (begin, then add_dot, add_patch, set_pole and set_hold): world positions as (x, z), and the layer to show. Preallocated:
## drawing allocates nothing.
class View:
	extends Control

	## An arrow's and a dot's shapes (px), as the concept's SVG: you, a teammate on another storey (up; down is its
	## mirror), the hold's diamond, the pole's flag.
	var _you_shape := PackedVector2Array([Vector2(0.0, -9.5), Vector2(7.0, 7.5), Vector2(0.0, 3.6), Vector2(-7.0, 7.5),
			Vector2(0.0, -9.5)])
	var _arrow_up := PackedVector2Array([Vector2(0.0, -8.0), Vector2(7.0, 0.0), Vector2(2.6, 0.0), Vector2(2.6, 7.0),
			Vector2(-2.6, 7.0), Vector2(-2.6, 0.0), Vector2(-7.0, 0.0), Vector2(0.0, -8.0)])
	var _arrow_down := PackedVector2Array([Vector2(0.0, 8.0), Vector2(7.0, 0.0), Vector2(2.6, 0.0), Vector2(2.6, -7.0),
			Vector2(-2.6, -7.0), Vector2(-2.6, 0.0), Vector2(-7.0, 0.0), Vector2(0.0, 8.0)])
	var _diamond := PackedVector2Array([Vector2(0.0, -9.0), Vector2(9.0, 0.0), Vector2(0.0, 9.0), Vector2(-9.0, 0.0),
			Vector2(0.0, -9.0)])
	var _flag := PackedVector2Array([Vector2(0.0, -15.0), Vector2(11.0, -11.0), Vector2(0.0, -7.0)])
	var _flag_line := PackedVector2Array([Vector2(0.0, -15.0), Vector2(11.0, -11.0), Vector2(0.0, -7.0),
			Vector2(0.0, -15.0)])
	const POLE_TOP := Vector2(0.0, -15.0)
	## The overtime flag's chequered cloth (px from its foot, as the pole's flag), its checks across and down.
	const CHEQUER := Rect2(0.0, -15.0, 12.0, 8.0)
	const CHEQUER_CHECKS := Vector2i(3, 2)
	const POLE_COLOUR := Color("e6ebf2")
	const YOU_COLOUR := Color("ffffff")
	## Stroke widths (px) the concept gives: the outlines under the arrows, the pole, the hold and a dot's ring.
	const OUTLINE := 1.8
	const POLE_INK := 5.0
	const POLE_WIDTH := 2.0
	const FLAG_INK := 3.0
	const POLE_BASE := 3.2
	const POLE_BASE_INK := 1.4
	const HOLD_INK := 5.2
	const HOLD_WIDTH := 2.4
	const RING_INK := 2.0
	const ARC_POINTS := 40
	const DISC := 64
	const DISC_EDGE := 0.985
	## Where the shot disc's fill passes from its centre alpha to its edge alpha (0..1 of the radius).
	const DISC_MID := 0.55
	## The rim mark's centre sits this far (px) further in than half its size, so its outline stays on the panel.
	const RIM_PAD := 1.0
	## Points of an arc: a dash of the ring, the rim mark's outline, a teammate dot's outline, the pole's foot.
	const DASH_ARC_POINTS := 4
	const RIM_ARC_POINTS := 16
	const DOT_ARC_POINTS := 20
	const POLE_ARC_POINTS := 16
	const RIM_OUTLINE := 1.0

	var _cfg: MinimapConfig = null
	var _textures: Array[Texture2D] = []
	var _disc: GradientTexture2D = null
	var _scale: float = 10.0
	var _origin: Vector2 = Vector2.ZERO
	var _layer: int = -1
	var _centre: Vector2 = Vector2.ZERO
	var _rot: float = 0.0
	var _arrow_rot: float = 0.0
	var _ppm: float = 1.0
	var _half: float = 0.0
	var _team: Color = Color.WHITE
	var _enemy: Color = Color.WHITE
	var _dots := PackedVector2Array()
	var _dot_colours := PackedColorArray()
	var _dot_arrows := PackedInt32Array()
	var _dot_count: int = 0
	var _patches := PackedVector2Array()
	var _patch_radii := PackedFloat32Array()
	var _patch_alphas := PackedFloat32Array()
	var _patch_shots := PackedByteArray()
	var _patch_count: int = 0
	var _pole_on: bool = false
	var _pole: Vector2 = Vector2.ZERO
	var _chequered: bool = false
	var _dark_checks: Array[Rect2] = []
	var _hold_on: bool = false
	var _hold: Vector2 = Vector2.ZERO
	var _pings := PackedVector2Array()
	var _ping_contacts := PackedByteArray()
	var _ping_alphas := PackedFloat32Array()
	var _ping_count: int = 0
	## A ping's ring and diamond with their ink, each one triangle array (one draw call; HudPingMarker.Mark).
	var _ping_ring: HudPingMarker.Mark = null
	var _ping_diamond: HudPingMarker.Mark = null
	var _you_on: bool = true
	## Where the white arrow is (the world's x, z): the middle on the minimap, wherever you are on the whole field.
	var _you_at: Vector2 = Vector2.ZERO

	## `textures` are the layers (one per storey) of a drawing at `field_scale` px/m whose top left is the world's
	## `field_origin` (x, z); up to `capacity` dots and patches.
	func setup(cfg: MinimapConfig, textures: Array[Texture2D], field_scale: float, field_origin: Vector2,
			capacity: int) -> void:
		_cfg = cfg
		_textures = textures
		_scale = field_scale
		_origin = field_origin
		name = "View"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_dots.resize(capacity)
		_dot_colours.resize(capacity)
		_dot_arrows.resize(capacity)
		_patches.resize(capacity)
		_patch_radii.resize(capacity)
		_patch_alphas.resize(capacity)
		var cell := CHEQUER.size / Vector2(CHEQUER_CHECKS)
		for j in CHEQUER_CHECKS.y:
			for i in CHEQUER_CHECKS.x:
				if (i + j) % 2 == 1:
					_dark_checks.append(Rect2(CHEQUER.position + cell * Vector2(i, j), cell))
		_patch_shots.resize(capacity)
		_pings.resize(capacity)
		_ping_contacts.resize(capacity)
		_ping_alphas.resize(capacity)
		_ping_ring = HudPingMarker.Mark.ring(cfg.ping_ring_radius, cfg.ping_ring_width, RING_INK, RIM_ARC_POINTS)
		_ping_diamond = HudPingMarker.Mark.diamond(cfg.ping_diamond, OUTLINE)
		var gradient := Gradient.new()
		# Opaque to the disc's edge, then clear: the texture is a square round a circle.
		gradient.offsets = PackedFloat32Array([0.0, DISC_MID, DISC_EDGE, 1.0])
		gradient.colors = PackedColorArray([Color(1.0, 1.0, 1.0, cfg.shot_alpha.x), Color(1.0, 1.0, 1.0, cfg.shot_alpha.y),
				Color(1.0, 1.0, 1.0, cfg.shot_alpha.z), Color(1.0, 1.0, 1.0, 0.0)])
		_disc = GradientTexture2D.new()
		_disc.gradient = gradient
		_disc.fill = GradientTexture2D.FILL_RADIAL
		_disc.fill_from = Vector2(0.5, 0.5)
		_disc.fill_to = Vector2(1.0, 0.5)
		_disc.width = DISC
		_disc.height = DISC

	## How many layers there are (0 on a map with no field drawing: the panel then shows only what is over it).
	func layers() -> int:
		return _textures.size()

	## Starts a frame: the world point at the middle (x, z), the layer shown (-1 for none), the way the character looks
	## `yaw` (the game's: positive turns left), whether the field turns with it, and the colours of their team and of
	## the other.
	func begin(centre: Vector2, layer: int, yaw: float, rotating: bool, team: Color, enemy: Color) -> void:
		_centre = centre
		_layer = layer
		_rot = yaw if rotating else 0.0
		_arrow_rot = 0.0 if rotating else -yaw
		_team = team
		_enemy = enemy
		_ppm = size.x / (2.0 * _cfg.view_radius)
		_you_at = centre
		_clear()

	## Starts a frame of the whole field (the full-screen map, FM1): the field's drawing fitted in the square, `fill`
	## of its side, north up, the white arrow at the world's `you` turned by `yaw`; otherwise as begin.
	func begin_whole(you: Vector2, layer: int, yaw: float, team: Color, enemy: Color, fit: float) -> void:
		_layer = layer
		_rot = 0.0
		_arrow_rot = -yaw
		_team = team
		_enemy = enemy
		fit_whole(fit)
		_you_at = you
		_clear()

	## The whole field's frame without drawing (the full-screen map frames its pointer from it while shut): the field
	## centred, `fit` of the square's side.
	func fit_whole(fit: float) -> void:
		var world := field_size()
		_centre = _origin + world * 0.5
		_ppm = size.x * fit / maxf(maxf(world.x, world.y), 1.0)

	## The field's drawing's size (m; zero with no drawing).
	func field_size() -> Vector2:
		if _textures.is_empty() or _scale <= 0.0:
			return Vector2.ZERO
		return _textures[0].get_size() / _scale

	## The world (x, z) at the square's middle and its px per metre, as this frame's begin left them.
	func centre() -> Vector2:
		return _centre

	func px_per_m() -> float:
		return _ppm

	## The square's point (px from its middle) for the world's `at` (x, z).
	func panel_of(at: Vector2) -> Vector2:
		return _to_panel(at)

	func _clear() -> void:
		_half = size.x * 0.5
		_dot_count = 0
		_patch_count = 0
		_pole_on = false
		_hold_on = false
		_ping_count = 0

	## A teammate: `colour` at the world's `at`, with `arrow` 1 up, -1 down for another storey, 0 a dot.
	func add_dot(at: Vector2, colour: Color, arrow: int) -> void:
		if _dot_count >= _dots.size():
			return
		_dots[_dot_count] = at
		_dot_colours[_dot_count] = colour
		_dot_arrows[_dot_count] = arrow
		_dot_count += 1

	## A heard patch: its middle, radius (m), whether a shot (else footsteps) and how strongly it shows (0..1).
	func add_patch(at: Vector2, radius: float, shot: bool, alpha: float) -> void:
		if _patch_count >= _patches.size():
			return
		_patches[_patch_count] = at
		_patch_radii[_patch_count] = radius
		_patch_alphas[_patch_count] = alpha
		_patch_shots[_patch_count] = 1 if shot else 0
		_patch_count += 1

	## Attack / Defend's pole at the world's `at`, or with `chequered` Elimination's overtime flag.
	func set_pole(at: Vector2, chequered: bool = false) -> void:
		_pole_on = true
		_pole = at
		_chequered = chequered

	func set_hold(at: Vector2) -> void:
		_hold_on = true
		_hold = at

	## A ping at the world's `at`: a contact's diamond (`contact`) or a spot's ring, at `alpha` (its fade).
	func add_ping(at: Vector2, contact: bool, alpha: float) -> void:
		if _ping_count >= _pings.size():
			return
		_pings[_ping_count] = at
		_ping_contacts[_ping_count] = 1 if contact else 0
		_ping_alphas[_ping_count] = alpha
		_ping_count += 1

	## How many pings this frame shows, and whether ping `i` is a contact: for tests.
	func ping_count() -> int:
		return _ping_count

	func ping_is_contact(i: int) -> bool:
		return i < _ping_count and _ping_contacts[i] == 1

	## Whether the white arrow shows (the thumbnails' sample has it; so does every real panel).
	func set_you(on: bool) -> void:
		_you_on = on

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), HudStyle.backing_on(self, BACKING))
		var mid := size * 0.5
		if _layer >= 0 and _layer < _textures.size():
			var at := mid + ((_origin - _centre) * _ppm).rotated(_rot)
			draw_set_transform(at, _rot, Vector2.ONE * (_ppm / _scale))
			draw_texture(_textures[_layer], Vector2.ZERO)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for i in _patch_count:
			if _patch_shots[i] == 0:
				_draw_step(i, mid)
		for i in _patch_count:
			if _patch_shots[i] != 0:
				_draw_shot(i, mid)
		for i in _patch_count:
			var p := _to_panel(_patches[i])
			if _off(p):
				_draw_rim(mid + _pin(p, _cfg.rim_patch * 0.5 + RIM_PAD), _patch_alphas[i])
		if _hold_on:
			_draw_hold(mid + _pin(_to_panel(_hold), _cfg.mark_pad))
		for i in _ping_count:
			_draw_ping(mid + _pin(_to_panel(_pings[i]), _cfg.mark_pad), _ping_contacts[i] == 1, _ping_alphas[i])
		if _pole_on:
			_draw_pole(mid + _pin(_to_panel(_pole), _cfg.mark_pad))
		for i in _dot_count:
			_draw_dot(mid + _pin(_to_panel(_dots[i]), _cfg.dot_pad), _dot_colours[i], _dot_arrows[i])
		if _you_on:
			draw_set_transform(mid + _pin(_to_panel(_you_at), _cfg.dot_pad), _arrow_rot, Vector2.ONE)
			draw_colored_polygon(_you_shape, YOU_COLOUR)
			draw_polyline(_you_shape, _cfg.ink, OUTLINE, true)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	## The panel's point (px from the middle) for the world's `at`.
	func _to_panel(at: Vector2) -> Vector2:
		return (at - _centre).rotated(_rot) * _ppm

	## `p` held inside the panel `pad` px from its edge, towards where it is.
	func _pin(p: Vector2, pad: float) -> Vector2:
		var limit := _half - pad
		var m := maxf(absf(p.x), absf(p.y))
		return p if m <= limit else p * (limit / m)

	## Whether the panel's point `p` lies off the panel: a patch there is only a mark on the rim, one on it is drawn whole.
	func _off(p: Vector2) -> bool:
		return absf(p.x) > _half or absf(p.y) > _half

	## Footsteps: a faint disc inside a dashed ring on a dark outline.
	func _draw_step(i: int, mid: Vector2) -> void:
		var p := _to_panel(_patches[i])
		if _off(p):
			return
		var r := _patch_radii[i] * _ppm
		var a := _patch_alphas[i]
		var c := mid + p
		draw_circle(c, r, Color(_enemy, _cfg.patch_fill * a))
		draw_arc(c, r, 0.0, TAU, ARC_POINTS, Color(_cfg.ink, _cfg.ink.a * a), _cfg.ring_width + RING_INK, true)
		var period := _cfg.dash + _cfg.dash_gap
		var n := maxi(3, roundi(TAU * r / period))
		var span := TAU / n * _cfg.dash / period
		for k in n:
			var from := TAU * k / n
			draw_arc(c, r, from, from + span, DASH_ARC_POINTS, Color(_enemy, a), _cfg.ring_width, true)

	## A shot: a disc fading to its edge, ringed.
	func _draw_shot(i: int, mid: Vector2) -> void:
		var p := _to_panel(_patches[i])
		if _off(p):
			return
		var r := _patch_radii[i] * _ppm
		var c := mid + p
		var tint := Color(_enemy, _patch_alphas[i])
		draw_texture_rect(_disc, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, tint)
		draw_arc(c, r, 0.0, TAU, ARC_POINTS, tint, _cfg.shot_ring_width, true)

	## Something heard beyond the edge: a small dot on the rim.
	func _draw_rim(at: Vector2, alpha: float) -> void:
		var r := _cfg.rim_patch * 0.5
		draw_circle(at, r, Color(_enemy, alpha))
		draw_arc(at, r, 0.0, TAU, RIM_ARC_POINTS, Color(_cfg.ink, _cfg.ink.a * alpha), RIM_OUTLINE, true)

	## A teammate: a dot (grey once hit), or an arrow where they are on another storey.
	func _draw_dot(at: Vector2, colour: Color, arrow: int) -> void:
		if arrow == 0:
			draw_circle(at, _cfg.dot_radius, colour)
			draw_arc(at, _cfg.dot_radius, 0.0, TAU, DOT_ARC_POINTS, _cfg.ink, _cfg.dot_outline, true)
			return
		draw_set_transform(at, 0.0, Vector2.ONE)
		var shape := _arrow_up if arrow > 0 else _arrow_down
		draw_colored_polygon(shape, colour)
		draw_polyline(shape, _cfg.ink, _cfg.dot_outline, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	## Your Hold here: a diamond in your team's colour.
	func _draw_hold(at: Vector2) -> void:
		draw_set_transform(at, 0.0, Vector2.ONE)
		draw_polyline(_diamond, _cfg.ink, HOLD_INK, true)
		draw_colored_polygon(_diamond, Color(_team, _cfg.hold_fill))
		draw_polyline(_diamond, _team, HOLD_WIDTH, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	## A ping: a contact's diamond in the other team's colour, or a spot's ring in the team's, each on a dark outline.
	## One draw call each.
	func _draw_ping(at: Vector2, contact: bool, alpha: float) -> void:
		var ink := Color(_cfg.ink, _cfg.ink.a * alpha)
		if contact:
			_ping_diamond.draw(self, at, Color(_enemy, alpha), ink)
		else:
			_ping_ring.draw(self, at, Color(_team, alpha), ink)

	## The pole: a yellow flag on a white staff, its foot a dot; the overtime flag's cloth chequered off-white and dark,
	## its foot off-white.
	func _draw_pole(at: Vector2) -> void:
		draw_set_transform(at, 0.0, Vector2.ONE)
		draw_line(Vector2.ZERO, POLE_TOP, _cfg.ink, POLE_INK, true)
		if _chequered:
			draw_rect(CHEQUER, _cfg.ink, false, FLAG_INK)
		else:
			draw_colored_polygon(_flag, _cfg.ink)
			draw_polyline(_flag_line, _cfg.ink, FLAG_INK, true)
		draw_line(Vector2.ZERO, POLE_TOP, POLE_COLOUR, POLE_WIDTH, true)
		var foot := GameTheme.YELLOW
		if _chequered:
			foot = HudFlagGlyph.CHECK_PALE
			draw_rect(CHEQUER, foot)
			for r in _dark_checks:
				draw_rect(r, HudFlagGlyph.CHECK_DARK)
		else:
			draw_colored_polygon(_flag, foot)
		draw_circle(Vector2.ZERO, POLE_BASE, foot)
		draw_arc(Vector2.ZERO, POLE_BASE, 0.0, TAU, POLE_ARC_POINTS, _cfg.ink, POLE_BASE_INK, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
