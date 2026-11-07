class_name BotIntentView
extends Node3D
## The Dev settings' Bot intentions: a small label over each bot in play with its name and what it is doing (advancing,
## fighting, in cover, searching, at the flag, under a squad order, bringing a magazine or waiting for one), read from
## the bots' controller each frame (BotController.intent_of). Built only while it is on; a label's text is set only when
## its bot's intent changes. Labels are hidden by walls like the world (BP6), and ones that would overlap on screen
## step up a line each, the nearest bot's staying put.

## Over the eyes (m), as the browser game's DEV_BOT_INTENT; the label's font size, and its size per pixel at a metre
## (it keeps one size on screen at any distance, about 25 px tall).
const ABOVE_EYES := 0.55
const FONT_SIZE := 32
const PIXEL := 0.001
## Lines a label may step up to clear the nearer ones, and its line in label pixels (the font's height with a gap).
const MAX_STEPS := 4
const LINE := FONT_SIZE * 1.15
## Screen pixels two labels may share before they count as overlapping (the line holds a gap of its own).
const SLACK := 3.0
## A sight raised this far hides the labels, as it does the crosshair (PlaySession.intents_covered).
const SIGHT_UP := 0.5
const MODE_KEYS: Array[StringName] = [&"DEV_INTENT_ADVANCE", &"DEV_INTENT_FIGHT", &"DEV_INTENT_COVER",
		&"DEV_INTENT_SEARCH", &"DEV_INTENT_FLAG", &"DEV_INTENT_ORDER", &"DEV_INTENT_MAG", &"DEV_INTENT_MAG_WAIT"]

var _bots: BotController = null
var _body: BodyConfig = null
var _labels: Array[Label3D] = []
var _ids: PackedInt32Array = PackedInt32Array()
var _shown: PackedInt32Array = PackedInt32Array()
## Each label's text width in label pixels, measured when its text changes.
var _widths: PackedFloat32Array = PackedFloat32Array()
## Reused each frame: the labels on screen, nearest first, and the screen boxes of those already placed.
var _order: Array[int] = []
var _depth: PackedFloat32Array = PackedFloat32Array()
var _placed: Array[Rect2] = []
var _nearer: Callable = _is_nearer


func setup(state: GameState, bots: BotController, body: BodyConfig, player_id: int) -> void:
	name = "BotIntentView"
	_bots = bots
	_body = body
	for c in state.characters:
		if c.id == player_id or bots.mode_of(c.id) < 0:
			continue
		var l := Label3D.new()
		l.font_size = FONT_SIZE
		l.pixel_size = PIXEL
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.fixed_size = true
		l.no_depth_test = false
		l.outline_size = FONT_SIZE / 6
		add_child(l)
		_labels.append(l)
		_ids.append(c.id)
		_shown.append(-1)
		_widths.append(0.0)
	_depth.resize(_labels.size())


func update(state: GameState, fraction: float) -> void:
	for i in _labels.size():
		var c := state.character(_ids[i])
		var l := _labels[i]
		l.visible = c != null and Elimination.is_in_play(c)
		if not l.visible:
			continue
		var mode := _bots.intent_of(c.id)
		if mode != _shown[i] and mode >= 0 and mode < MODE_KEYS.size():
			_shown[i] = mode
			var bot_name := _bots.name_of(c.id)
			l.text = tr(MODE_KEYS[mode]) if bot_name == "" else tr("DEV_INTENT_NAMED") % [bot_name, tr(MODE_KEYS[mode])]
			var font := l.font if l.font != null else ThemeDB.fallback_font
			_widths[i] = font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		var feet := c.prev_position.lerp(c.position, fraction)
		var eye := Character.eye_height(lerpf(c.prev_crouch_amount, c.crouch_amount, fraction), _body)
		l.position = feet + Vector3(0.0, eye + ABOVE_EYES, 0.0)
	_space(get_viewport().get_camera_3d() if is_inside_tree() else null)


## Steps up the labels that would overlap a nearer one on screen, a line at a time (MAX_STEPS at most).
func _space(camera: Camera3D) -> void:
	_order.clear()
	for i in _labels.size():
		_labels[i].offset.y = 0.0
		if camera == null or not _labels[i].visible or camera.is_position_behind(_labels[i].position):
			continue
		_depth[i] = camera.global_position.distance_squared_to(_labels[i].position)
		_order.append(i)
	if _order.size() < 2:
		return
	_order.sort_custom(_nearer)
	# fixed_size: a label pixel is this many screen pixels at any distance
	var px_per_label := camera.get_viewport().get_visible_rect().size.y * PIXEL / (2.0 * tan(deg_to_rad(camera.fov) * 0.5))
	var line := LINE * px_per_label
	_placed.clear()
	for i in _order:
		var at := camera.unproject_position(_labels[i].position)
		var w := _widths[i] * px_per_label
		var box := Rect2(at.x - w * 0.5, at.y - line * 0.5, w, line)
		var steps := 0
		while steps < MAX_STEPS and _overlaps(box):
			steps += 1
			box.position.y -= line
		_labels[i].offset.y = steps * LINE
		_placed.append(box)


func _is_nearer(a: int, b: int) -> bool:
	return _depth[a] < _depth[b]


func _overlaps(box: Rect2) -> bool:
	for other in _placed:
		if other.grow(-SLACK).intersects(box):
			return true
	return false
