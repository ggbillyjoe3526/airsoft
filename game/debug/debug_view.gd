class_name DebugView
extends Node
## The in-world debug draw of a match, from the simulation's state: F4 shows every BB's recent flight as a fading trail
## (the hop-up lift, then the drop; a ribbon a few pixels wide, DebugRibbons) and F5 the hit volumes of the characters
## in play (`Hitbox.build_volume`, the volume the BB tests use). The keys are the `debug_bb_paths` and `debug_hit_areas`
## actions; KeyBindings.UNBINDABLE keeps them from being rebound. Off, it costs a check per tick and per input event:
## the trail buffers and the line meshes are made when a draw is switched on and freed when it is switched off, and
## nothing processes. Read only: it never writes state.

const ACTION_BB_PATHS := &"debug_bb_paths"
const ACTION_HIT_AREAS := &"debug_hit_areas"

## The character whose eyes you see through: not drawn, as the camera sits inside its head (-1: draw everyone).
var viewer_id: int = -1
## Hit shapes drawn on the last frame, and the BB trail points drawn.
var shapes_drawn: int = 0
var points_drawn: int = 0

var _state: GameState = null
var _hits: HitConfig = null
var _cfg: DebugViewConfig = null
var _bb_paths := false
var _hit_areas := false
var _trails: BBTrails = null
var _volume: Hitbox.Volume = null
var _path_lines: DebugRibbons = null
var _hit_lines: DebugLines = null


func setup(state: GameState, hits: HitConfig, cfg: DebugViewConfig) -> void:
	name = "DebugView"
	_state = state
	_hits = hits
	_cfg = cfg


func _ready() -> void:
	set_process(false)


func bb_paths_on() -> bool:
	return _bb_paths


func hit_areas_on() -> bool:
	return _hit_areas


func set_bb_paths(on: bool) -> void:
	if on == _bb_paths:
		return
	_bb_paths = on
	if on:
		_trails = BBTrails.new(_state.bbs.bbs.size(), ceili(_cfg.trail_seconds * _cfg.trail_rate))
		_path_lines = DebugRibbons.new()
		add_child(_path_lines)
	else:
		_trails = null
		_path_lines.free()
		_path_lines = null
		points_drawn = 0
	set_process(_bb_paths or _hit_areas)


func set_hit_areas(on: bool) -> void:
	if on == _hit_areas:
		return
	_hit_areas = on
	if on:
		_volume = Hitbox.Volume.new()
		_hit_lines = _add_lines(true)
	else:
		_volume = null
		_drop(_hit_lines)
		_hit_lines = null
		shapes_drawn = 0
	set_process(_bb_paths or _hit_areas)


## Once a simulation tick: records where the BBs are, while the BB paths are on.
func on_tick() -> void:
	if _bb_paths:
		_trails.record(_state.bbs)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_pressed():
		return
	if event.is_action_pressed(ACTION_BB_PATHS):
		set_bb_paths(not _bb_paths)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(ACTION_HIT_AREAS):
		set_hit_areas(not _hit_areas)
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _bb_paths:
		_draw_paths()
	if _hit_areas:
		_draw_hit_areas()


func _draw_paths() -> void:
	_path_lines.begin(get_viewport().get_camera_3d(), _cfg.trail_width_px)
	var points := 0
	for slot in _trails.slots():
		var n := _trails.count(slot)
		if n < 2:
			continue
		_path_lines.strip(_trails, slot, _cfg.trail_old_colour, _cfg.trail_new_colour)
		points += n
	_path_lines.end()
	points_drawn = points


func _draw_hit_areas() -> void:
	_hit_lines.begin()
	var shapes := 0
	for c in _state.characters:
		if c.id == viewer_id or not Elimination.is_in_play(c):
			continue
		Hitbox.build_volume(c, _hits, _volume)
		var colour := _cfg.hit_colours[c.team % _cfg.hit_colours.size()]
		shapes += HitShapes.draw_volume(_hit_lines, _volume, colour, _cfg)
	_hit_lines.end()
	shapes_drawn = shapes


func _add_lines(see_through: bool = false) -> DebugLines:
	var lines := DebugLines.new(see_through)
	add_child(lines)
	return lines


## Frees a line mesh at once (nothing of ours is mid-call in it).
func _drop(lines: DebugLines) -> void:
	lines.free()
