class_name HudFieldMap
extends Control
## The full-screen map (FM1, FM2): while its key is held, the minimap's field whole, north up, as big as the screen
## allows over a dimmed screen, under a header ("DEPOT", "ROUND 2 · ATTACK / DEFEND" and what your side must do) and
## beside a key to its marks. It shows what the minimap shows and nothing more of the other team (DECISIONS › Minimap:
## hearing only): you as the white arrow, your teammates, Hold here's or Go there's spot, your team's pings and the
## other team only where your side heard them. Over that (FieldMapOverlay) what never moves: the flags' letters or the
## overtime flag's spot, each end's start and dead zone, the doors, the named areas' words on the storey you stand on,
## a compass and a scale bar. While you can ping, its pointer (MapPointer) shows: a click is a Go there to that point of
## the field, a ping's press a ping there. Any map's field fits, whatever its size and shape: the drawing is the
## minimap's own (HudMinimap.textures, made once a match), so a frame only places it and allocates nothing; the marks
## are laid out once per size, storey and round.

## What the header says your side must do.
enum Goal { PRACTICE, ELIMINATION, OVERTIME, ATTACK, DEFEND }

var _cfg: MinimapConfig = null
var _minimap: HudMinimap = null
var _view: HudMinimap.View = null
var _overlay: FieldMapOverlay = null
var _key: FieldMapKey = null
var _title: Label = null
var _sub: Label = null
var _goal: Label = null
var _map_name: String = ""
var _round: int = -1
var _goal_state: Goal = Goal.PRACTICE
var _layer: int = -1
var _ping_life: float = 0.0
var _ping_fade: float = 0.0
var _flag_count: int = 0
var _end_colours := PackedColorArray([Color.WHITE, Color.WHITE])
var _end_words := PackedStringArray(["", ""])
## The field's box on this control (px), ringed in _draw.
var _field_box := Rect2()


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
	_flag_count = map.poles.size()
	name = "HudFieldMap"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	# While it is up it hides itself under the pause menu, which stops the HUD's own updates (as the order wheel does).
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	var field := minimap.field()
	_view = HudMinimap.View.new()
	_view.setup(cfg, minimap.textures(), field.scale, field.origin, capacity, minimap.ground(), field.ground_rect)
	add_child(_view)
	_overlay = FieldMapOverlay.new()
	_overlay.setup(cfg, FieldMapMarks.of(map, cfg.map_start_pad))
	add_child(_overlay)
	_key = FieldMapKey.new()
	_key.setup(cfg)
	add_child(_key)
	_title = HudStyle.label(self, cfg.map_title_size, 800, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT,
			HudStyle.SPACING_BANNER)
	_title.uppercase = true
	_title.text = map_name
	_sub = HudStyle.label(self, cfg.map_subtitle_size, 700, GameTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT,
			HudStyle.SPACING_SUB)
	_sub.uppercase = true
	_goal = HudStyle.label(self, cfg.map_goal_size, 700, GameTheme.TEXT, HORIZONTAL_ALIGNMENT_RIGHT,
			HudStyle.SPACING_SUB)
	resized.connect(_lay_out)
	_lay_out()


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
	pointer.frame_rect(_view.centre(), _view.px_per_m(), _view.size * 0.5, shown_floor,
			_view.panel_of(Vector2(feet.x, feet.z)))
	var on := pointer.open and not covered
	if on != visible:
		visible = on
		set_process(on)
	if not on:
		return
	var layer := storey if storey < _view.layers() else -1
	var teams := _minimap.teams()
	var team := teams.colours[watched.team]
	var enemy := teams.colours[1 - watched.team]
	_view.begin_whole(Vector2(feet.x, feet.z), layer, yaw, team, enemy, _cfg.map_fit)
	_minimap.fill(_view, state, watched, fraction, storey, holding, hold)
	if book != null:
		_minimap.add_pings(book, watched.team, state.time, _ping_life, _ping_fade, _view)
	var rs := state.round_state
	var goal := _goal_of(rs, watched.team)
	if rs.number != _round or goal != _goal_state:
		_round = rs.number
		_goal_state = goal
		_show_round(state, goal, team)
	_key.set_teams(team, enemy)
	if layer != _layer:
		_layer = layer
		_overlay.storey_floor = shown_floor
		_overlay.laid_out = false
	var flags := rs.mode == RoundState.Mode.ATTACK_DEFEND and not rs.practice
	var overtime := rs.mode == RoundState.Mode.ELIMINATION and not rs.practice
	_overlay.set_round(flags, overtime, rs.overtime_flag.up, _end_colours, _end_words)
	_overlay.place(_view, pointer.at, pointing, team)


static func _goal_of(rs: RoundState, team: int) -> Goal:
	if rs.practice:
		return Goal.PRACTICE
	if rs.mode == RoundState.Mode.ATTACK_DEFEND and rs.attackers >= 0:
		return Goal.ATTACK if rs.attackers == team else Goal.DEFEND
	return Goal.OVERTIME if rs.overtime_flag.up else Goal.ELIMINATION


## A new round, or its goal changed: the header's words, and each end's colour and start's word (teams swap ends at half
## time).
func _show_round(state: GameState, goal: Goal, team: Color) -> void:
	var rs := state.round_state
	var mode := tr("MODE_ATTACK_DEFEND") if rs.mode == RoundState.Mode.ATTACK_DEFEND else tr("MODE_ELIMINATION")
	_sub.text = tr("MODE_PRACTICE") if rs.practice else "%s  ·  %s" % [tr("HUD_ROUND") % _round, mode]
	var letters := " / ".join(Flag.LETTERS.slice(0, maxi(_flag_count, 1)))
	match goal:
		Goal.ATTACK:
			_goal.text = (tr("MAP_GOAL_ATTACK") % letters) if _flag_count > 1 else tr("MAP_GOAL_ATTACK_ONE")
		Goal.DEFEND:
			_goal.text = (tr("MAP_GOAL_DEFEND") % letters) if _flag_count > 1 else tr("MAP_GOAL_DEFEND_ONE")
		Goal.OVERTIME:
			_goal.text = tr("MAP_GOAL_OVERTIME")
		Goal.ELIMINATION:
			_goal.text = tr("MAP_GOAL_ELIMINATION")
		_:
			_goal.text = ""
	_goal.add_theme_color_override("font_color", GameTheme.TEXT if goal == Goal.PRACTICE else team)
	var teams := _minimap.teams()
	var colours := PackedColorArray([Color.WHITE, Color.WHITE])
	var words := PackedStringArray(["", ""])
	for c in state.characters:
		if c.end >= 0 and c.end < colours.size():
			colours[c.end] = teams.colours[c.team]
			words[c.end] = (tr("MAP_START") % tr(teams.names[c.team])).to_upper()
	_end_colours = colours
	_end_words = words


func _process(_delta: float) -> void:
	if get_tree().paused:
		visible = false
		set_process(false)


## The header across the top, the key down the right, and the field in the room left, as big as it allows.
func _lay_out() -> void:
	var m := _cfg.map_margin
	var content := Rect2(Vector2(m, m), (size - Vector2(m, m) * 2.0).max(Vector2.ZERO))
	var header := _cfg.map_header
	var key_w := minf(_cfg.map_key_width, content.size.x * _cfg.map_key_share)
	var room := Rect2(content.position + Vector2(0.0, header), (content.size - Vector2(key_w + _cfg.map_key_gap,
			header)).max(Vector2.ZERO))
	_view.position = room.position
	_view.size = room.size
	_view.fit_whole(_cfg.map_fit)
	var world := _view.field_size() * _view.px_per_m()
	_field_box = Rect2(room.position + (room.size - world) * 0.5, world)
	_overlay.position = _view.position
	_overlay.size = _view.size
	_overlay.laid_out = false
	_key.size = Vector2(key_w, minf(_key.needed_height(), room.size.y))
	_key.position = Vector2(content.end.x - key_w, room.position.y)
	var title_h := _cfg.map_title_size * _cfg.map_title_line
	_title.position = content.position
	_title.size = Vector2(content.size.x * 0.5, title_h)
	_sub.position = content.position + Vector2(0.0, title_h)
	_sub.size = Vector2(content.size.x * 0.5, header - title_h)
	_goal.position = content.position + Vector2(content.size.x * 0.5, 0.0)
	_goal.size = Vector2(content.size.x * 0.5, header - _cfg.map_key_gap * 0.5)
	_goal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	queue_redraw()


## The dimmed screen and the field's ring.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), _cfg.map_backdrop)
	if _field_box.has_area():
		draw_rect(_field_box.grow(_cfg.ring), GameTheme.LINE, false, _cfg.ring * 2.0)


## For tests: the view, the words drawn on the storey shown, the title, the round's line and the goal.
func view() -> HudMinimap.View:
	return _view


func overlay() -> FieldMapOverlay:
	return _overlay


func area_words() -> PackedStringArray:
	return _overlay.shown_names()


func title_text() -> String:
	return _title.text


func sub_text() -> String:
	return _sub.text


func goal_text() -> String:
	return _goal.text
