class_name RetroFilter
extends CanvasLayer
## The Dev settings' Retro filter (RF1, owner 2026-11-10: "less like Doom, more like PS1"): the 3D view drawn as a
## 1990s console drew it. The view in square low-resolution pixels, `lines` of them top to bottom (240 by default,
## that console's height), each in 15-bit colour (`levels` shades of red, green and blue, 32 by default) with that
## console's own 4x4 dither on the pixel grid; the field's geometry snapped to those pixels so its corners wobble as
## you move, and its surfaces' patterns laid on screen-straight, not in perspective, so they swim (the look's shaders,
## look/retro_vertex.gdshaderinc, through the `retro_snap` global and the main camera's view projection, set every
## frame while it is on); and a short depth haze (FieldLighting.retro_haze).
## Drawn over the 3D view and under the HUD. Changes only what you see. Built only while it is on.

## Lines of retro pixels top to bottom, and shades a channel: the defaults, and the Dev tab's sliders' ends and step.
const LINES := 240
const LINES_MIN := 120
const LINES_MAX := 480
const LINES_STEP := 24
const LEVELS := 32
const LEVELS_MIN := 4
const LEVELS_MAX := 32
## How far the field's surface patterns follow the screen rather than the perspective (0 none, 1 all, as the console),
## and at most how far (m) a point's pattern swims from where it belongs (the console's games cut big faces small, so
## their swim stayed local; unbounded, a field's floor, one face, smears into long streaks).
const AFFINE := 1.0
const AFFINE_REACH := 0.2
## The haze: from and to (m from the eye), at most this much of the view, the map's own haze colour (else its sky's
## horizon) times `HAZE_LIGHT`.
const HAZE_FROM := 12.0
const HAZE_TO := 70.0
const HAZE_MOST := 0.85
const HAZE_LIGHT := 0.55
const SHADER := preload("res://game/play/retro_filter.gdshader")
## The global the look's shaders read (project.godot [shader_globals]): x, y the retro screen in pixels (0: off),
## z the AFFINE share, w AFFINE_REACH.
const SNAP_GLOBAL := &"retro_snap"
## The main camera's view projection and its inverse (mat4 globals), which the corners are snapped through.
const VIEW_PROJECTION_GLOBAL := &"retro_view_projection"
const VIEW_PROJECTION_INVERSE_GLOBAL := &"retro_view_projection_inverse"

var _mat: ShaderMaterial = null
var _lines: int = LINES
var _levels: int = LEVELS
var _lighting: FieldLighting = null
## What it last set the `retro_snap` global to (reading a global back can stall the renderer).
var _snap: Vector4 = Vector4.ZERO


## The field's light, whose haze the filter sets while it is on (none: no haze). Call before it enters the tree.
func setup(lighting: FieldLighting) -> void:
	_lighting = lighting


## The lines and shades a channel, each held to its sliders' ends; before or after it is in the tree.
func set_look(lines: int, levels: int) -> void:
	_lines = clampi(lines, LINES_MIN, LINES_MAX)
	_levels = clampi(levels, LEVELS_MIN, LEVELS_MAX)
	if _mat != null:
		_mat.set_shader_parameter(&"levels", float(_levels))
		_resize()


## What it set the look's `retro_snap` global to: the retro screen in pixels, the AFFINE share and reach.
func snap() -> Vector4:
	return _snap


## Screen pixels a retro pixel on a view `height` pixels tall drawn in `lines` lines (whole, so every pixel is square
## and the same size).
static func pixel_size(height: float, lines: int) -> int:
	return maxi(1, roundi(height / float(maxi(lines, 1))))


func _ready() -> void:
	name = "RetroFilter"
	# Under the HUD's layer (the default 1), over the 3D view.
	layer = 0
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	rect.material = _mat
	add_child(rect)
	get_viewport().size_changed.connect(_resize)
	set_look(_lines, _levels)
	if _lighting != null:
		_lighting.retro_haze(true, HAZE_FROM, HAZE_TO, HAZE_MOST, HAZE_LIGHT)


## The main camera as it draws this frame (after the session's _process placed it: the filter is its child).
func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var view_projection := camera.get_camera_projection() * Projection(camera.get_camera_transform().affine_inverse())
	RenderingServer.global_shader_parameter_set(VIEW_PROJECTION_GLOBAL, view_projection)
	RenderingServer.global_shader_parameter_set(VIEW_PROJECTION_INVERSE_GLOBAL, view_projection.inverse())


func _exit_tree() -> void:
	_snap = Vector4.ZERO
	RenderingServer.global_shader_parameter_set(SNAP_GLOBAL, _snap)
	if get_viewport().size_changed.is_connected(_resize):
		get_viewport().size_changed.disconnect(_resize)
	if _lighting != null and is_instance_valid(_lighting):
		_lighting.retro_haze(false)


## The block size for the view's height, and the retro screen the geometry snaps to.
func _resize() -> void:
	var view := get_viewport().get_visible_rect().size
	var size := pixel_size(view.y, _lines)
	_mat.set_shader_parameter(&"pixel_size", float(size))
	_snap = Vector4(view.x / float(size), view.y / float(size), AFFINE, AFFINE_REACH)
	RenderingServer.global_shader_parameter_set(SNAP_GLOBAL, _snap)
