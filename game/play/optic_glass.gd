class_name OpticGlass
extends Node
## Looking through an optic in your hands (the sight concepts the owner approved, 2026-10-19): a disc over the optic's
## glass shows the view through it, drawn by a second camera at your eye that leaves your replica out, so the optic's
## inside never darkens it. A scope's is magnified by its zoom, only inside the glass; a red dot's is clear, with the lit
## dot on it (optic_glass.gdshader). Round the glass the optic's own model shows and the view is the main camera's, with
## nothing dark round it. The second camera draws only while a sight is raised, into a small square picture; the disc
## shows only then, so at the hip the optic looks as its model does. Children: the picture and its camera. The picture
## follows the graphics' render scale and edge smoothing (GraphicsApply's `applied`), and copies the field's environment
## again after a change, so its ambient occlusion matches the view round it.

## The visual layer your replica is drawn on, which the glass's camera leaves out (the last of Godot's 20).
const HANDS_LAYER := 1 << 19
const ALL_LAYERS := (1 << 20) - 1
const MARK_DOT := &"dot"
const SHADER := preload("res://game/play/optic_glass.gdshader")
## How far along the sight line the optic's aim point is taken (m): far enough to read as straight ahead.
const AIM_DISTANCE := 100.0
## The disc sits this far nearer the eye than the glass, so the two never fight over depth (m).
const DISC_LIFT := 0.0005


## One optic's glass, on one replica in the hands.
class Sight:
	extends RefCounted
	var disc: MeshInstance3D = null
	var material: ShaderMaterial = null
	var radius: float = 0.0
	## How much the glass magnifies (a scope's zoom; 0: it shows the view as it is).
	var magnify: float = 0.0
	## The replica's model (its -z is forward) and its optic's sight line in the model's space.
	var model: Node3D = null
	var sight_line: Vector3 = Vector3.ZERO


var _cfg: ViewModelConfig = null
var _view: ViewConfig = null
var _eyes: Camera3D = null
var _port: SubViewport = null
var _camera: Camera3D = null
var _side: int = 0
var _env_ready: bool = false


## Builds the picture and its camera for the eyes `eyes`, sized as `cfg` says.
func setup(cfg: ViewModelConfig, view: ViewConfig, eyes: Camera3D) -> void:
	name = "OpticGlass"
	_cfg = cfg
	_view = view
	_eyes = eyes
	_port = SubViewport.new()
	_port.name = "Glass"
	# Kept in linear light, so the main view's tonemapping applies once, as to everything round it.
	_port.use_hdr_2d = true
	_port.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_port.positional_shadow_atlas_size = 0
	_port.size = Vector2i.ONE
	add_child(_port)
	_camera = Camera3D.new()
	_camera.cull_mask = ALL_LAYERS & ~HANDS_LAYER
	_camera.near = view.near
	_camera.far = view.far
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_port.add_child(_camera)
	_camera.current = true


func _enter_tree() -> void:
	var graphics := GraphicsApply.server()
	if not graphics.applied.is_connected(_follow):
		graphics.applied.connect(_follow)
	if graphics.drawn != null:
		_follow(graphics.drawn)


func _exit_tree() -> void:
	if GraphicsApply.server().applied.is_connected(_follow):
		GraphicsApply.server().applied.disconnect(_follow)


## The graphics drawn changed: the picture's scale and edge smoothing follow, and its environment is copied again at the
## next raise of a sight (once a change, never per frame).
func _follow(values: GraphicsQuality) -> void:
	if _port == null:
		return
	GraphicsApply.apply_picture(values, _port)
	_env_ready = false


## A glass for `optic` (a fitted optic part with Key `key`, on `model`, its sight line at `sight_line` in the model's
## space), magnifying `magnify` times (0: clear); null for an optic the config gives no glass.
func add_window(model: Node3D, optic: Node3D, key: StringName, sight_line: Vector3, magnify: float) -> Sight:
	if not _cfg.optic_glass_z.has(key) or not _cfg.optic_glass_radius.has(key):
		return null
	var w := Sight.new()
	w.model = model
	w.sight_line = sight_line
	w.magnify = magnify
	w.radius = _cfg.optic_glass_radius[key]
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 2.0 * w.radius
	w.material = ShaderMaterial.new()
	w.material.shader = SHADER
	w.material.set_shader_parameter(&"glass", _port.get_texture())
	w.material.set_shader_parameter(&"mark", 0 if _cfg.optic_mark.get(key, MARK_DOT) == MARK_DOT else 1)
	w.material.set_shader_parameter(&"z_clip_scale", _cfg.depth_scale)
	w.disc = MeshInstance3D.new()
	w.disc.name = "Glass"
	w.disc.mesh = quad
	w.disc.material_override = w.material
	w.disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.disc.layers = HANDS_LAYER
	w.disc.visible = false
	# On the sight line, over the glass, facing the eye (+z).
	var line := optic.transform.affine_inverse() * sight_line
	w.disc.position = Vector3(line.x, line.y, float(_cfg.optic_glass_z[key]) + DISC_LIFT)
	optic.add_child(w.disc)
	return w


## Draws the view through `w` with the sight `raise` of the way up (0..1), or stops drawing (`w` null: no glass in
## hand). Every rendered frame, after the replica is posed.
func update(w: Sight, raise: float) -> void:
	if w == null or raise <= 0.0 or not w.model.is_visible_in_tree() or _eyes.is_position_behind(w.disc.global_position):
		if w != null:
			w.disc.visible = false
		# A prewarm's single draw (UPDATE_ONCE) is left to finish.
		if _port.render_target_update_mode == SubViewport.UPDATE_ALWAYS:
			_port.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	if not _env_ready:
		_ready_environment()
	var screen := _eyes.get_viewport().get_visible_rect().size
	_fit_side(screen.y)
	if _port.render_target_update_mode != SubViewport.UPDATE_ALWAYS:
		_port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	w.disc.visible = true
	# The glass's size on screen sets how wide the picture is, and so its field of view: the main view's own scale
	# (clear glass), or the unzoomed view's over the scope's magnification.
	var eye := _eyes.global_position
	var centre := w.disc.global_position
	var centre_px := _eyes.unproject_position(centre)
	var rim_px := _eyes.unproject_position(centre + _eyes.global_basis.x * w.radius)
	var span := minf(2.0 * centre_px.distance_to(rim_px) * _cfg.glass_margin / screen.y, _cfg.glass_share)
	var tan_glass := span * tan(deg_to_rad(_eyes.fov) * 0.5)
	if w.magnify > 0.0:
		tan_glass = span * tan(deg_to_rad(_view.vertical_fov()) * 0.5) / w.magnify
	_camera.fov = rad_to_deg(2.0 * atan(tan_glass))
	_camera.transform = Transform3D(Basis.looking_at(centre - eye, _eyes.global_basis.y), eye)
	var aim := w.model.global_transform * (w.sight_line + Vector3(0.0, 0.0, -AIM_DISTANCE))
	var m := w.material
	m.set_shader_parameter(&"centre_uv", centre_px / screen)
	m.set_shader_parameter(&"span", span)
	m.set_shader_parameter(&"aspect", screen.x / screen.y)
	m.set_shader_parameter(&"screen_h", screen.y)
	m.set_shader_parameter(&"mark_uv", _eyes.unproject_position(aim) / screen)


## The glass's camera while it draws the view through a raised sight, or null (at the hip, no glass in hand): what it
## shows is the cone round its view (FigureView.view_corner, in_cone), for the figures' zoomed detail (BP7).
func drawing_camera() -> Camera3D:
	return _camera if _port != null and _port.render_target_update_mode == SubViewport.UPDATE_ALWAYS else null


## Readies the picture before the match is played, so the first raise of a sight doesn't build it mid-aim: the
## environment copied, the picture sized and drawn once (its disc's shader is warmed with ShaderPrewarm's specks).
func prewarm() -> void:
	_ready_environment()
	_fit_side(_eyes.get_viewport().get_visible_rect().size.y)
	_port.render_target_update_mode = SubViewport.UPDATE_ONCE


func _fit_side(screen_h: float) -> void:
	var side := maxi(1, ceili(screen_h * _cfg.glass_share))
	if side != _side:
		_side = side
		_port.size = Vector2i(side, side)


## The glass's camera sees the field as the main one does, but tonemapped linearly: the main view tonemaps the disc
## with everything else, once.
func _ready_environment() -> void:
	var world := _eyes.get_world_3d()
	if world == null or world.environment == null:
		return
	_env_ready = true
	var env := world.environment.duplicate() as Environment
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	_camera.environment = env
