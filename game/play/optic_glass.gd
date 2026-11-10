class_name OpticGlass
extends Node
## Looking through an optic in your hands (the sight concepts the owner approved, 2026-10-19): a disc over the optic's
## glass shows the view through it, drawn by a second camera at your eye that leaves your replica out, so the optic's
## inside never darkens it. A scope's is magnified by its zoom, only inside the glass; a red dot's is clear, with the lit
## dot on it (optic_glass.gdshader). Round the glass the optic's own model shows and the view is the main camera's, with
## nothing dark round it. The second camera draws only while a sight is raised, into a small square picture, or while a
## scope is held at the hip (BP8, the owner): then its disc is clear glass you see through, the second camera drawing
## what lies straight ahead of the optic, looking down its own axis (SG1, the owner: not the patch of the view behind
## the glass, which at the hip looks off at a slant), at the main view's own scale, lightly tinted with a reflection
## and no reticle (its own material, optic_glass_hip.gdshader), drawn without the dearer effects (no ambient occlusion,
## bounce light, reflections, glow or volumetric fog); below `hip_glass_camera_from`'s Mesh detail (Low) the hip glass
## is a still tint and no camera draws. Neither shader copies the screen. A red dot's glass at the hip is its model's
## own, clear.
## Children: the picture and its camera. The picture
## follows the graphics' render scale and edge smoothing (GraphicsApply's `applied`), and copies the field's environment
## again after a change, so its ambient occlusion matches the view round it.

## The visual layer your replica is drawn on, which the glass's camera leaves out (the last of Godot's 20).
const HANDS_LAYER := 1 << 19
const ALL_LAYERS := (1 << 20) - 1
const MARK_DOT := &"dot"
const SHADER := preload("res://game/play/optic_glass.gdshader")
const HIP_SHADER := preload("res://game/play/optic_glass_hip.gdshader")
## How far along the sight line the optic's aim point is taken (m): far enough to read as straight ahead.
const AIM_DISTANCE := 100.0
## The points round a disc's rim measured for its reach on screen at the hip.
const RIM_POINTS := 8
## The disc sits this far nearer the eye than the glass, so the two never fight over depth (m).
const DISC_LIFT := 0.0005
## Past this share of straight up or down the optic points too near the eye's up to keep the hip glass's picture
## upright by it, and the optic's own up is taken.
const UPRIGHT_LIMIT := 0.999


## One optic's glass, on one replica in the hands.
class Sight:
	extends RefCounted
	var disc: MeshInstance3D = null
	var material: ShaderMaterial = null
	## A scope's glass at the hip (null: an optic that doesn't magnify), on the disc only then.
	var hip_material: ShaderMaterial = null
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
## Whether the glass's camera draws a scope's hip glass (not a raised sight's view).
var _at_hip: bool = false
## Whether a scope's hip glass shows the field behind it (the graphics' Mesh detail at hip_glass_camera_from or up).
var _hip_camera: bool = true
## The field's environment for a raised sight's view, and the cheaper one for the hip glass.
var _env_aimed: Environment = null
var _env_hip: Environment = null


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
	# Nor the reflection probes: seen by this camera too, they broke the field's reflections up (AreaProbes.LAYER).
	_camera.cull_mask = ALL_LAYERS & ~HANDS_LAYER & ~AreaProbes.LAYER
	_camera.near = view.near
	_camera.far = view.far
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	# Placed by hand every rendered frame (off the eye at the hip), never eased between ticks by the engine.
	_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
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


## The graphics drawn changed: the picture's scale, edge smoothing and shadow atlas follow, and its environment is
## copied again at the next raise of a sight (once a change, never per frame).
func _follow(values: GraphicsQuality) -> void:
	if _port == null:
		return
	GraphicsApply.apply_picture(values, _port)
	var atlas := GraphicsApply.glass_atlas(values)
	if _port.positional_shadow_atlas_size != atlas:
		_port.positional_shadow_atlas_size = atlas
	_hip_camera = values.mesh_detail >= _cfg.hip_glass_camera_from
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
	if magnify > 0.0:
		w.hip_material = ShaderMaterial.new()
		w.hip_material.shader = HIP_SHADER
		w.hip_material.set_shader_parameter(&"glass", _port.get_texture())
		w.hip_material.set_shader_parameter(&"z_clip_scale", _cfg.depth_scale)
		w.hip_material.set_shader_parameter(&"hip_tint", _cfg.hip_glass_tint)
		w.hip_material.set_shader_parameter(&"hip_shine", _cfg.hip_glass_shine)
		w.hip_material.set_shader_parameter(&"still_colour", _cfg.hip_glass_still)
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
## hand). At the hip (`raise` 0) a scope's glass shows as clear glass (`hip_glass`). Every rendered frame, after the
## replica is posed.
func update(w: Sight, raise: float) -> void:
	var hip := hip_glass(w, raise)
	if w == null or (raise <= 0.0 and not hip) or not w.model.is_visible_in_tree() \
			or _eyes.is_position_behind(w.disc.global_position):
		if w != null:
			w.disc.visible = false
		_stop_drawing()
		return
	var m := w.hip_material if hip else w.material
	_wear(w, m)
	if hip:
		m.set_shader_parameter(&"see_through", _hip_camera)
		if not _hip_camera:
			_stop_drawing()
			w.disc.visible = true
			return
	_at_hip = hip
	if not _env_ready:
		_ready_environment()
	var env := _env_hip if hip else _env_aimed
	if _camera.environment != env:
		_camera.environment = env
	var screen := _eyes.get_viewport().get_visible_rect().size
	_fit_side(screen.y)
	if _port.render_target_update_mode != SubViewport.UPDATE_ALWAYS:
		_port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	w.disc.visible = true
	# The glass's size on screen sets how wide the picture is, and so its field of view: the main view's own scale
	# (clear glass, and a scope at the hip), or the unzoomed view's over the scope's magnification.
	var eye := _eyes.global_position
	var centre := w.disc.global_position
	var centre_px := _eyes.unproject_position(centre)
	var rim_px := _eyes.unproject_position(centre + _eyes.global_basis.x * w.radius)
	var reach := centre_px.distance_to(rim_px)
	if hip:
		reach = _rim_reach(w, centre_px)
	var span := minf(2.0 * reach * _cfg.glass_margin / screen.y, _cfg.glass_share)
	if _camera.projection != Camera3D.PROJECTION_PERSPECTIVE:
		_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	# The glass sees as far, and as near, as the eye.
	if _camera.near != _eyes.near or _camera.far != _eyes.far:
		_camera.near = _eyes.near
		_camera.far = _eyes.far
	if hip:
		_face_optic(w, span, screen.x / screen.y)
	else:
		var tan_glass := span * tan(deg_to_rad(_eyes.fov) * 0.5)
		if w.magnify > 0.0:
			tan_glass = span * tan(deg_to_rad(_view.vertical_fov()) * 0.5) / w.magnify
		_camera.fov = rad_to_deg(2.0 * atan(tan_glass))
		_camera.transform = Transform3D(Basis.looking_at(centre - eye, _eyes.global_basis.y), eye)
	m.set_shader_parameter(&"span", span)
	m.set_shader_parameter(&"aspect", screen.x / screen.y)
	m.set_shader_parameter(&"centre_uv", centre_px / screen)
	if not hip:
		m.set_shader_parameter(&"screen_h", screen.y)
		_place_mark(w, screen)


## How far from `centre_px` the rim of `w`'s disc reaches on screen (px), at its farthest of RIM_POINTS round it: a
## disc seen at a slant, off the view's centre, stretches out of round.
func _rim_reach(w: Sight, centre_px: Vector2) -> float:
	var b := w.disc.global_basis
	var centre := w.disc.global_position
	var reach := 0.0
	for i in RIM_POINTS:
		var t := TAU * i / RIM_POINTS
		var rim := centre + (b.x * cos(t) + b.y * sin(t)) * w.radius
		reach = maxf(reach, _eyes.unproject_position(rim).distance_to(centre_px))
	return reach


## The glass's camera on `w`'s optic's own axis, where it passes nearest the eye (at most hip_glass_eye_reach from it),
## looking straight down it, upright as the eye sees, at the main view's own scale for a picture `span` screen heights
## across (the screen's width over its height `aspect`): the glass shows what lies directly in front of the optic.
func _face_optic(w: Sight, span: float, aspect: float) -> void:
	var eye := _eyes.global_position
	var ahead := -w.model.global_basis.z.normalized()
	var on_axis := w.disc.global_position
	var nearest := on_axis + ahead * (eye - on_axis).dot(ahead)
	var from := eye + (nearest - eye).limit_length(_cfg.hip_glass_eye_reach)
	var up := _eyes.global_basis.y
	if absf(ahead.dot(up)) > UPRIGHT_LIMIT:
		up = w.model.global_basis.y.normalized()
	var half_h := tan(deg_to_rad(_eyes.fov) * 0.5)
	if _eyes.keep_aspect == Camera3D.KEEP_WIDTH:
		half_h /= aspect
	_camera.fov = rad_to_deg(2.0 * atan(span * half_h))
	_camera.transform = Transform3D(Basis.looking_at(ahead, up), from)


## Whether `w`'s glass shows as plain glass now, its sight raised `raise` (0..1): a scope's (one that magnifies) at the
## hip. A red dot's model glass is clear of itself, so it draws none.
static func hip_glass(w: Sight, raise: float) -> bool:
	return w != null and raise <= 0.0 and w.magnify > 0.0


## `w`'s disc drawn with `m` (its sight's material or its hip glass's), set only when it changes.
static func _wear(w: Sight, m: ShaderMaterial) -> void:
	if w.disc.material_override != m:
		w.disc.material_override = m


## Where on the `screen` (px) `w`'s raised sight points, for its dot or reticle.
func _place_mark(w: Sight, screen: Vector2) -> void:
	var aim := w.model.global_transform * (w.sight_line + Vector3(0.0, 0.0, -AIM_DISTANCE))
	w.material.set_shader_parameter(&"mark_uv", _eyes.unproject_position(aim) / screen)


## The glass's camera stops drawing (a prewarm's single draw, UPDATE_ONCE, is left to finish).
func _stop_drawing() -> void:
	_at_hip = false
	if _port.render_target_update_mode == SubViewport.UPDATE_ALWAYS:
		_port.render_target_update_mode = SubViewport.UPDATE_DISABLED


## The glass's camera while it draws the view through a raised sight, or null (a scope's glass at the hip, no glass in
## hand): what it shows is the cone round its view (FigureView.view_corner, in_cone), for the figures' zoomed detail
## (BP7). At the hip it draws at the main view's own scale, so it adds no detail.
func drawing_camera() -> Camera3D:
	if _port == null or _at_hip or _port.render_target_update_mode != SubViewport.UPDATE_ALWAYS:
		return null
	return _camera


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
	_env_aimed = world.environment.duplicate() as Environment
	_env_aimed.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_env_aimed.tonemap_exposure = 1.0
	# The hip glass, a small lightly tinted picture, leaves out the screen-space and volume passes; the depth fog (no
	# pass of its own) stays, so distance hazes as round the glass.
	_env_hip = _env_aimed.duplicate() as Environment
	_env_hip.ssao_enabled = false
	_env_hip.ssil_enabled = false
	_env_hip.sdfgi_enabled = false
	_env_hip.ssr_enabled = false
	_env_hip.glow_enabled = false
	_env_hip.volumetric_fog_enabled = false
	_camera.environment = _env_hip if _at_hip else _env_aimed
