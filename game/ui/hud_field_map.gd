class_name HudFieldMap
extends Control
## The full-screen map (FM1): while its key is held, the minimap's field whole, north up, in a square as big as the
## screen allows over a dimmed screen, "DEPOT · ROUND 2" over it. It shows what the minimap shows and nothing more
## (DECISIONS › Minimap: hearing only): you as the white arrow, your teammates, the pole or the overtime flag, Hold
## here's or Go there's spot, your team's pings and the other team only where your side heard them; with the named
## areas' words over their places on the storey you stand on. While you can ping, its pointer (MapPointer) shows: a
## click is a Go there to that point of the field, a ping's press a ping there. Any map's field fits, whatever its
## size: the drawing is the minimap's own (HudMinimap.textures, made once a match), so a frame only places it and
## allocates nothing; the words are laid out once per storey and size.

var _cfg: MinimapConfig = null
var _minimap: HudMinimap = null
var _view: HudMinimap.View = null
var _overlay: Overlay = null
var _title: Label = null
var _round_label: Label = null
var _map_name: String = ""
var _round: int = -1
var _layer: int = -1
var _ping_life: float = 0.0
var _ping_fade: float = 0.0


## One named area's words over the map: the name, where (the world's x, z: the middle of its biggest box) and the feet
## heights it holds.
class AreaWords:
	extends RefCounted
	var name: String = ""
	var at: Vector2 = Vector2.ZERO
	var floor_from: float = -INF
	var floor_to: float = INF
	var box: float = 0.0


## Builds the map over `minimap`'s drawing of `map` (call once, after the minimap's setup, behind the loading screen),
## `map_name` in its title, its pings fading over the last `ping_fade` s of their `ping_life` as on the minimap. Hidden
## until update shows it. `capacity` is the most characters a match has.
func setup(cfg: MinimapConfig, minimap: HudMinimap, map: MapData, map_name: String, capacity: int, ping_life: float,
		ping_fade: float) -> void:
	_cfg = cfg
	_ping_life = ping_life
	_ping_fade = ping_fade
	_minimap = minimap
	_map_name = map_name
	name = "HudFieldMap"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	# While it is up it hides itself under the pause menu, which stops the HUD's own updates (as the order wheel does).
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	var field := minimap.field()
	_view = HudMinimap.View.new()
	_view.setup(cfg, minimap.textures(), field.scale, field.origin, capacity)
	add_child(_view)
	_overlay = Overlay.new()
	_overlay.setup(cfg, areas_of(map.areas))
	add_child(_overlay)
	_title = HudStyle.label(self, cfg.map_title_size, 800, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER,
			HudStyle.SPACING_BANNER)
	_title.uppercase = true
	_title.text = map_name
	resized.connect(_lay_out)
	_lay_out()


## The words for `areas`: one for each name on each band of floors, over the biggest of its boxes.
static func areas_of(areas: Array[MapAreas.Area]) -> Array[AreaWords]:
	var out: Array[AreaWords] = []
	for a in areas:
		var box := (a.x1 - a.x0) * (a.z1 - a.z0)
		var words := a.name.to_upper()
		var same: AreaWords = null
		for w in out:
			if w.name == words and w.floor_from == a.floor_from and w.floor_to == a.floor_to:
				same = w
				break
		if same == null:
			same = AreaWords.new()
			same.name = words
			same.floor_from = a.floor_from
			same.floor_to = a.floor_to
			out.append(same)
		elif box <= same.box:
			continue
		same.box = box
		same.at = Vector2((a.x0 + a.x1) * 0.5, (a.z0 + a.z1) * 0.5)
	return out


## Each frame: shown while `open` (the map's key held; never over the scoreboard or the match's summary, `covered`),
## for `watched` looking `yaw`, `fraction` of the way through the tick, as the minimap is (Hold here or Go there at
## `hold` while `holding`, the pings of their team in `book`, null for none). It frames `pointer` (where a click lands
## on the field) and draws it while `pointing`. Allocates nothing.
func update(state: GameState, watched: Character, yaw: float, fraction: float, holding: bool, hold: Vector3,
		book: Pings, pointer: MapPointer, pointing: bool, covered: bool) -> void:
	var field := _minimap.field()
	var feet := watched.prev_position.lerp(watched.position, fraction)
	var storey := field.storey_of(feet.y)
	var shown_floor := field.floors[storey] if storey < field.floors.size() else 0.0
	# Framed shut too, so the pointer opens on you and a click on the first frame lands where it is drawn.
	pointer.frame(_view.centre(), _view.px_per_m(), _view.size.x * 0.5, shown_floor,
			_view.panel_of(Vector2(feet.x, feet.z)))
	var on := pointer.open and not covered
	if on != visible:
		visible = on
		set_process(on)
	if not on:
		return
	var layer := storey if storey < _view.layers() else -1
	var teams := _minimap.teams()
	_view.begin_whole(Vector2(feet.x, feet.z), layer, yaw, teams.colours[watched.team], teams.colours[1 - watched.team],
			_cfg.map_fit)
	_minimap.fill(_view, state, watched, fraction, storey, holding, hold)
	if book != null:
		_minimap.add_pings(book, watched.team, state.time, _ping_life, _ping_fade, _view)
	var rs := state.round_state
	if rs.number != _round:
		_round = rs.number
		var round_words := tr("MODE_PRACTICE") if rs.practice else tr("HUD_ROUND") % _round
		_title.text = "%s  ·  %s" % [_map_name, round_words]
	if layer != _layer:
		_layer = layer
		_overlay.storey_floor = shown_floor
		_overlay.laid_out = false
	_overlay.place(_view, pointer.at, pointing, teams.colours[watched.team])


func _process(_delta: float) -> void:
	if get_tree().paused:
		visible = false
		set_process(false)


## The square: as big as the screen allows inside map_margin, the title in its top.
func _lay_out() -> void:
	var room := size - Vector2.ONE * _cfg.map_margin * 2.0
	var side := maxf(minf(room.x, room.y), 0.0)
	_view.position = (size - Vector2(side, side)) * 0.5
	_view.size = Vector2(side, side)
	_view.fit_whole(_cfg.map_fit)
	_overlay.position = _view.position
	_overlay.size = _view.size
	_overlay.laid_out = false
	_title.position = _view.position
	_title.size = Vector2(side, _cfg.map_title_room)
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	queue_redraw()


## The dimmed screen and the square's ring.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), _cfg.map_backdrop)
	var r := Rect2(_view.position, _view.size).grow(_cfg.ring)
	draw_rect(r, GameTheme.LINE, false, _cfg.ring * 2.0)


## For tests: the view, the overlay's words drawn on the storey shown, and the title.
func view() -> HudMinimap.View:
	return _view


func area_words() -> PackedStringArray:
	return _overlay.shown_names()


func title_text() -> String:
	return _title.text


## Over the view: the named areas' words on the storey shown, and the pointer while you can ping.
class Overlay:
	extends Control

	## The pointer's ring's points, and its dark ink: this much wider than the ring, and round the dot (px).
	const POINTER_ARC_POINTS := 32
	const POINTER_INK := 3.0
	const DOT_INK := 1.2

	var storey_floor: float = 0.0
	## The words' places hold until the square or the storey changes (the whole field never moves on it).
	var laid_out: bool = false
	var _cfg: MinimapConfig = null
	var _words: Array[AreaWords] = []
	var _font: Font = null
	var _sizes := PackedVector2Array()
	var _at := PackedVector2Array()
	var _pointer := Vector2.ZERO
	var _pointing: bool = false
	var _colour := Color.WHITE

	func setup(cfg: MinimapConfig, words: Array[AreaWords]) -> void:
		_cfg = cfg
		_words = words
		name = "Overlay"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_font = GameTheme.spaced_font(800, HudStyle.SPACING_AIM, cfg.map_area_size)
		_sizes.resize(words.size())
		_at.resize(words.size())
		for i in words.size():
			_sizes[i] = _font.get_string_size(words[i].name, HORIZONTAL_ALIGNMENT_LEFT, -1, cfg.map_area_size)

	## This frame: the words' places from `view` (begun; only when not laid_out), and the pointer at `pointer` (px from
	## the middle) in `colour` while `pointing`. Redrawn only when something moved.
	func place(view: HudMinimap.View, pointer: Vector2, pointing: bool, colour: Color) -> void:
		var mid := size * 0.5
		var moved := not laid_out
		if not laid_out:
			laid_out = true
			var ascent := _font.get_ascent(_cfg.map_area_size)
			for i in _words.size():
				var p := mid + view.panel_of(_words[i].at)
				_at[i] = Vector2(p.x - _sizes[i].x * 0.5, p.y - _sizes[i].y * 0.5 + ascent)
		var at := mid + pointer
		if moved or at != _pointer or pointing != _pointing or colour != _colour:
			_pointer = at
			_pointing = pointing
			_colour = colour
			queue_redraw()

	func _shows(i: int) -> bool:
		var w := _words[i]
		var feet := storey_floor + _cfg.storey_pick
		return feet >= w.floor_from and feet < w.floor_to

	func shown_names() -> PackedStringArray:
		var out := PackedStringArray()
		for i in _words.size():
			if _shows(i):
				out.append(_words[i].name)
		return out

	func _draw() -> void:
		var s := _cfg.map_area_size
		for i in _words.size():
			if not _shows(i):
				continue
			draw_string_outline(_font, _at[i], _words[i].name, HORIZONTAL_ALIGNMENT_LEFT, -1, s, _cfg.map_area_outline,
					_cfg.ink)
			draw_string(_font, _at[i], _words[i].name, HORIZONTAL_ALIGNMENT_LEFT, -1, s, GameTheme.MUTED)
		if not _pointing:
			return
		var r := _cfg.map_pointer_radius
		draw_arc(_pointer, r, 0.0, TAU, POINTER_ARC_POINTS, _cfg.ink, _cfg.map_pointer_width + POINTER_INK, true)
		draw_arc(_pointer, r, 0.0, TAU, POINTER_ARC_POINTS, _colour, _cfg.map_pointer_width, true)
		draw_circle(_pointer, _cfg.map_pointer_dot + DOT_INK, _cfg.ink)
		draw_circle(_pointer, _cfg.map_pointer_dot, Color.WHITE)
