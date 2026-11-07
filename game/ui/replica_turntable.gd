class_name ReplicaTurntable
extends TextureRect
## Customise's replica on a turntable (UI concept B v2, owner 2026-11-02: "the replica stays the same size and place
## whatever parts go on" and "an option to rotate the 3D model"): the replica's model, live, in its paint with its parts
## fitted (ReplicaParts, ReplicaPaint, as ReplicaPictures does), in a viewport of its own drawn to this rect. The view is
## framed on the replica without parts and kept: fitting a part, a paint or switching tabs never moves or rescales it.
## Drag (either mouse button) turns it, the wheel zooms, R puts the view back; `set_view` picks the 3/4, left, right or
## top view. The viewport draws only when something changes (not every frame). Everything it makes is its child.

## A view was picked or the replica was turned (-1: a view of the player's own).
signal view_changed(view: int)

enum View { THREE_QUARTER, LEFT, RIGHT, TOP }

## Each view's turn and tilt (degrees: yaw about the replica's up, pitch towards the camera; pitch -90 looks down on it).
const VIEW_ANGLES: Array[Vector2] = [Vector2(-32.0, -16.0), Vector2(180.0, 0.0), Vector2(0.0, 0.0), Vector2(0.0, -90.0)]
const VIEW_KEYS: Array[String] = ["CUSTOMISE_VIEW_3_4", "CUSTOMISE_VIEW_LEFT", "CUSTOMISE_VIEW_RIGHT",
		"CUSTOMISE_VIEW_TOP"]
## Degrees turned per pixel dragged, and the tilt's limits.
const DRAG := 0.4
const PITCH_MIN := -90.0
const PITCH_MAX := 30.0
## Zoom per wheel step and its limits.
const ZOOM_STEP := 1.1
const ZOOM_MIN := 0.7
const ZOOM_MAX := 1.8
## The camera's horizontal field of view (degrees), and the room round the bare replica: across (its length takes
## 1 / FRAME_WIDE of the view, so a long barrel and a silencer still fit) and up (a scope).
const FOV := 26.0
const FRAME_WIDE := 1.3
const FRAME_HIGH := 1.5
## The most the viewport is drawn over the rect's size (a 4K screen gets sharper pixels, not more).
const MAX_SUPERSAMPLE := 2.0
## The turntable's ring under the replica: its radius against the replica's half length (inside the frame at 3/4), its tube, and its colour.
const RING_REACH := 0.62
const RING_TUBE := 0.02
const RING_COLOUR := Color(1.0, 1.0, 1.0, 0.22)
## How flat the ring is (its tube squashed to a band).
const RING_FLAT := 0.12
const RING_SEGMENTS := 96
## Looking down more steeply than this (pitch, degrees), the ring would run out of the frame: it hides.
const RING_HIDE_PITCH := -40.0

var _port: SubViewport = null
var _camera: Camera3D = null
## The tilt (about the view's across axis), the turn inside it, and the holder that sets the bare replica's centre on
## the turntable's.
var _tilt: Node3D = null
var _spin: Node3D = null
var _holder: Node3D = null
var _ring: MeshInstance3D = null
var _ring_material: StandardMaterial3D = null
var _model: Node3D = null
var _key: StringName = &""
var _paint: StringName = &""
var _realistic: bool = false
var _parts_sig: String = ""
var _fit: ReplicaParts.Fit = null
## The bare replica's half size (m): across, up, deep.
var _half: Vector3 = Vector3.ONE
var _yaw: float = 0.0
var _pitch: float = 0.0
var _zoom: float = 1.0
var _view: int = View.THREE_QUARTER
## The drag buttons held (one bit a button), so letting go of one while the other is down keeps the drag.
var _held: int = 0


func _init() -> void:
	name = "Turntable"
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	_port = SubViewport.new()
	_port.name = "Port"
	_port.own_world_3d = true
	# Turned and framed by hand between the physics ticks: the engine's interpolation stays off (BP6).
	_port.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_port.transparent_bg = true
	_port.msaa_3d = ReplicaPictures.MSAA
	_port.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_port)
	_tilt = Node3D.new()
	_tilt.name = "Tilt"
	_port.add_child(_tilt)
	_spin = Node3D.new()
	_spin.name = "Spin"
	_tilt.add_child(_spin)
	_holder = Node3D.new()
	_holder.name = "Holder"
	_spin.add_child(_holder)
	_ring_material = StandardMaterial3D.new()
	_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_material.albedo_color = RING_COLOUR
	_ring = MeshInstance3D.new()
	_ring.name = "Ring"
	_tilt.add_child(_ring)
	_camera = Camera3D.new()
	_camera.fov = FOV
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	_port.add_child(_camera)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(ReplicaPictures.SUN_ANGLE.x, ReplicaPictures.SUN_ANGLE.y, 0.0)
	sun.light_energy = ReplicaPictures.SUN_ENERGY
	_port.add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ReplicaPictures.AMBIENT
	env.ambient_light_energy = ReplicaPictures.AMBIENT_ENERGY
	var world := WorldEnvironment.new()
	world.environment = env
	_port.add_child(world)
	texture = _port.get_texture()
	_set_angles(VIEW_ANGLES[View.THREE_QUARTER])


## Shows replica `key` (a pool.md Key) in `paint` with `parts` fitted (part slot -> part Key, LoadoutFacts.fitted_keys).
## A new replica is framed on its bare model; new parts or paint keep the frame.
func show_replica(key: StringName, paint: StringName, realistic: bool, parts: Dictionary = {}) -> void:
	var new_model := key != _key or _model == null
	if new_model:
		_load(key)
	var sig := ReplicaPictures.signature(parts)
	var refit := new_model or sig != _parts_sig
	if refit and _model != null:
		if _fit != null:
			ReplicaParts.unfit(_fit)
		_fit = ReplicaParts.fit(_model, key, parts)
		_parts_sig = sig
	var repaint := refit or paint != _paint or realistic != _realistic
	if _model != null and repaint:
		ReplicaPaint.apply(_model, paint, realistic)
	_paint = paint
	_realistic = realistic
	# a refresh that changed nothing here (a slider, a tab) draws nothing
	if repaint:
		_redraw()


## Lets go of the model (the page is closed); the next `show_replica` loads it again.
func let_go() -> void:
	if _model != null:
		_holder.remove_child(_model)
		_model.free()
	_model = null
	_fit = null
	_key = &""
	_parts_sig = ""
	# the render target too, while nothing is shown; `_size_port` gives it back
	_port.size = Vector2i.ONE


## Turns the replica to view `v` (View) and zooms back to 1.
func set_view(v: int) -> void:
	_view = v
	_zoom = 1.0
	_set_angles(VIEW_ANGLES[v])
	_place_camera()
	_redraw()
	view_changed.emit(_view)


## The 3/4 view at zoom 1 (R).
func reset_view() -> void:
	set_view(View.THREE_QUARTER)


## The view picked, or -1 once the replica was turned by hand.
func view() -> int:
	return _view


func yaw() -> float:
	return _yaw


func pitch() -> float:
	return _pitch


func zoom() -> float:
	return _zoom


## The replica's model as shown (null with none), and the camera's distance from the turntable's centre: what fitting
## a part must never change.
func model() -> Node3D:
	return _model


func camera_distance() -> float:
	return _camera.position.length()


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null:
		match button.button_index:
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT:
				var bit := 1 << button.button_index
				_held = (_held | bit) if button.pressed else (_held & ~bit)
				accept_event()
			MOUSE_BUTTON_WHEEL_UP:
				if button.pressed:
					_zoom_by(ZOOM_STEP)
				accept_event()
			MOUSE_BUTTON_WHEEL_DOWN:
				if button.pressed:
					_zoom_by(1.0 / ZOOM_STEP)
				accept_event()
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _held != 0:
		turn_by(motion.relative)
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.physical_keycode != KEY_R or not is_visible_in_tree():
		return
	reset_view()
	get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_size_port()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_held = 0


## Turns by a drag of `pixels` (across turns, up and down tilts).
func turn_by(pixels: Vector2) -> void:
	_set_angles(Vector2(_yaw + pixels.x * DRAG, _pitch - pixels.y * DRAG))
	_view = -1
	_redraw()
	view_changed.emit(_view)


func _zoom_by(factor: float) -> void:
	_zoom = clampf(_zoom * factor, ZOOM_MIN, ZOOM_MAX)
	_place_camera()
	_redraw()


func _set_angles(angles: Vector2) -> void:
	_yaw = wrapf(angles.x, -180.0, 180.0)
	_pitch = clampf(angles.y, PITCH_MIN, PITCH_MAX)
	_spin.rotation_degrees = Vector3(0.0, _yaw, 0.0)
	_tilt.rotation_degrees = Vector3(0.0, 0.0, _pitch)
	_ring.visible = _pitch > RING_HIDE_PITCH


func _load(key: StringName) -> void:
	let_go()
	_key = key
	var path := "%s%s.glb" % [ReplicaPictures.MODEL_DIR, key]
	var scene := load(path) as PackedScene if ResourceLoader.exists(path) else null
	if scene == null:
		return
	_model = scene.instantiate() as Node3D
	_model.name = "Model"
	var figure := _model.find_child(ReplicaParts.FIGURE_NODE, true, false) as Node3D
	if figure != null:
		figure.visible = false
	_holder.add_child(_model)
	var box := ReplicaPictures.bounds(_model)
	_half = Vector3(maxf(box.size.z, ReplicaPictures.MIN_EXTENT), maxf(box.size.y, ReplicaPictures.MIN_EXTENT),
			maxf(box.size.x, ReplicaPictures.MIN_EXTENT)) * 0.5
	_holder.position = -box.get_center()
	_shape_ring()
	_place_camera()
	_size_port()


## The ring under the replica's middle, at its feet.
func _shape_ring() -> void:
	var radius := _half.x * RING_REACH
	var tube := maxf(_half.x * RING_TUBE, ReplicaPictures.MIN_EXTENT)
	var torus := TorusMesh.new()
	torus.inner_radius = radius - tube
	torus.outer_radius = radius + tube
	torus.rings = RING_SEGMENTS
	torus.ring_segments = 4
	torus.material = _ring_material
	_ring.mesh = torus
	_ring.position = Vector3(0.0, -_half.y, 0.0)
	_ring.scale = Vector3(1.0, RING_FLAT, 1.0)


## The camera back along +X far enough that the bare replica, with its room, fits across and up; nearer with the zoom.
func _place_camera() -> void:
	var tan_across := tan(deg_to_rad(FOV) * 0.5)
	var across := maxf(_half.x, _half.z) * FRAME_WIDE / tan_across
	var aspect := size.y / size.x if size.x > 0.0 and size.y > 0.0 else 0.5
	var up := _half.y * FRAME_HIGH / (tan_across * aspect)
	var distance := maxf(across, up) / _zoom
	_camera.position = Vector3(distance, 0.0, 0.0)
	_camera.near = maxf(distance - _half.x * 4.0, ReplicaPictures.MIN_EXTENT * 10.0)
	_camera.far = distance + _half.x * 4.0


func _size_port() -> void:
	if size.x < 1.0 or size.y < 1.0:
		return
	var sharpness := 1.0
	if is_inside_tree():
		sharpness = clampf(get_viewport().get_final_transform().get_scale().x, 1.0, MAX_SUPERSAMPLE)
	_port.size = Vector2i(maxi(1, roundi(size.x * sharpness)), maxi(1, roundi(size.y * sharpness)))
	_place_camera()
	_redraw()


func _redraw() -> void:
	_port.render_target_update_mode = SubViewport.UPDATE_ONCE
