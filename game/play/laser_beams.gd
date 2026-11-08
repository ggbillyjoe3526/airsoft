class_name LaserBeams
extends Node3D
## Dev › Lasers' beams (LZ1, the owner's Easter egg): each laser shot (a LASER event) is a solid beam in its shooter's
## team colour from the muzzle drawn to where the laser stopped. A single or semi shot flashes once, a burst flashes
## once a shot, three times, and full auto keeps the beam on while the trigger is held (hold_time). Everyone's beams
## are one instanced draw, a ribbon turned to face the eye and never thinner than EffectsConfig.laser_min_angle, so a
## far beam still reads. Look only: what a laser hit is the simulation's (BBStep), and nothing here is read back.
## `on_tick` and `update` allocate nothing.

## The beam's ribbon: one quad from x -1 to 1 across and z 0 to 1 along; the instance's basis z is the beam (its
## length), its origin the muzzle. The vertex stage widens it to face the camera, by `width` m or `min_angle` rad of the
## view, whichever is wider; the fragment stage is brightest down its middle, whitening there by `core_mix`.
const BEAM_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform float width = 0.01;
uniform float min_angle = 0.0022;
uniform float core_mix = 0.35;

varying float across;

void vertex() {
	vec3 start = MODEL_MATRIX[3].xyz;
	vec3 beam = MODEL_MATRIX[2].xyz;
	vec3 at = start + beam * VERTEX.z;
	vec3 to_eye = CAMERA_POSITION_WORLD - at;
	float dist = max(length(to_eye), 1e-4);
	vec3 side = cross(beam, to_eye);
	float side_length = length(side);
	side = side_length > 1e-8 ? side / side_length : vec3(0.0, 1.0, 0.0);
	at += side * VERTEX.x * 0.5 * max(width, dist * min_angle);
	POSITION = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(at, 1.0));
	across = VERTEX.x;
}

void fragment() {
	float core = 1.0 - abs(across);
	float peak = max(COLOR.r, max(COLOR.g, COLOR.b));
	ALBEDO = mix(COLOR.rgb, vec3(peak), core * core * core_mix) * core;
}
"""
## A beam shorter than this (m) isn't drawn.
const MIN_LENGTH := 0.01

var _beams: MultiMeshInstance3D = null
var _cfg: EffectsConfig = null
var _body: BodyConfig = null
## Each team's beam colour (linear, at EffectsConfig.laser_strength).
var _colours: PackedColorArray = PackedColorArray()
## By character id: how long its beam stays on (s of match time), where its last laser stopped, from which slot.
var _left: PackedFloat32Array = PackedFloat32Array()
var _ends: PackedVector3Array = PackedVector3Array()
var _slots: PackedInt32Array = PackedInt32Array()
var _shown: int = 0


## Room for `count` characters' beams (everyone on the field), in `team_colours` (the HUD's, sRGB) at `cfg`'s strength;
## a beam from someone not shown starts under their eyes, at `body`'s heights.
func setup(cfg: EffectsConfig, count: int, team_colours: PackedColorArray, body: BodyConfig) -> void:
	name = "LaserBeams"
	_cfg = cfg
	_body = body
	_colours.clear()
	for c: Color in team_colours:
		var lin := c.srgb_to_linear()
		_colours.append(Color(lin.r * cfg.laser_strength, lin.g * cfg.laser_strength, lin.b * cfg.laser_strength))
	_left.resize(count)
	_left.fill(0.0)
	_ends.resize(count)
	_slots.resize(count)
	_slots.fill(-1)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = beam_mesh(cfg)
	mm.instance_count = maxi(1, count)
	mm.visible_instance_count = 0
	_beams = MultiMeshInstance3D.new()
	_beams.name = "Beams"
	_beams.multimesh = mm
	_beams.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beams)


## How long a laser's beam stays on (s) after a shot from a replica on `mode` firing `fire_rate` shots a second: full
## auto, the gap to the next shot and `cfg.laser_auto_margin` (one beam while the trigger is held); a burst, the share
## `cfg.laser_burst_share` of that gap, at most `cfg.laser_flash_time` (three flashes, apart); a single or semi shot,
## `cfg.laser_flash_time`, no longer than the burst's share either, so fast clicks still flash apart.
static func hold_time(cfg: EffectsConfig, mode: ReplicaConfig.FireMode, fire_rate: float) -> float:
	var gap := 1.0 / fire_rate if fire_rate > 0.0 else INF
	if mode == ReplicaConfig.FireMode.AUTO:
		return gap + cfg.laser_auto_margin if gap < INF else cfg.laser_flash_time
	return minf(cfg.laser_flash_time, gap * cfg.laser_burst_share)


## The tick's LASER events in `state`: each turns its shooter's beam on to where the laser stopped.
func on_tick(state: GameState) -> void:
	var events := state.events
	for i in events.count:
		var e := events.items[i]
		if e.kind != GameEvent.Kind.LASER or e.actor < 0 or e.actor >= _left.size():
			continue
		var c := state.character(e.actor)
		if c == null:
			continue
		var a := c.armament
		var slot := e.slot if e.slot >= 0 and e.slot < a.replicas.size() else a.active
		_left[e.actor] = hold_time(_cfg, a.modes[slot], a.replicas[slot].fire_rate)
		_ends[e.actor] = e.position
		_slots[e.actor] = slot


## Beams on now (for tests and the debug count).
func shown_count() -> int:
	return _shown


## The draw, for tests and the shader prewarm.
func draws() -> MultiMeshInstance3D:
	return _beams


## Draws every beam still on, `dt` s of match time on (each beam's time runs down by it), `fraction` of the way from the
## last tick to this one: `watched`'s from `own_muzzle` (the view's own replica) when it is the one shown in hand
## (`own_shown`), else from under the eyes of `camera`; everyone else's from their figure's muzzle (`figure_of`, by id;
## null where none), or under their eyes.
func update(characters: Array[Character], watched: Character, own_muzzle: Vector3, own_shown: bool, camera: Camera3D,
		fraction: float, dt: float, figure_of: Array[FigureView]) -> void:
	var mm := _beams.multimesh
	var n := 0
	for c in characters:
		var id := c.id
		if id < 0 or id >= _left.size() or _left[id] <= 0.0:
			continue
		_left[id] = maxf(0.0, _left[id] - dt)
		var origin := Vector3.ZERO
		if c == watched:
			origin = own_muzzle if own_shown else camera.global_position + Vector3.DOWN * TorchBeams.EYE_DROP
		else:
			var f: FigureView = figure_of[id] if id < figure_of.size() else null
			if f != null and f.muzzle_shown(_slots[id]):
				origin = f.muzzle_position(_slots[id])
			else:
				var feet := c.prev_position.lerp(c.position, fraction)
				var crouch := lerpf(c.prev_crouch_amount, c.crouch_amount, fraction)
				origin = feet + Vector3(0.0, Character.eye_height(crouch, _body) - TorchBeams.EYE_DROP, 0.0)
		var beam := _ends[id] - origin
		var length := beam.length()
		if length < MIN_LENGTH:
			continue
		mm.set_instance_transform(n, Transform3D(beam_basis(beam / length, length), origin))
		mm.set_instance_color(n, _colours[c.team] if c.team >= 0 and c.team < _colours.size() else Color.WHITE)
		n += 1
	mm.visible_instance_count = n
	_shown = n


## Every beam off at once (a new round).
func clear() -> void:
	_left.fill(0.0)
	_beams.multimesh.visible_instance_count = 0
	_shown = 0


## A basis whose z is `dir` (unit) `length` m long, its x and y one metre square to it (the ribbon's draw box).
static func beam_basis(dir: Vector3, length: float) -> Basis:
	var x := dir.cross(Vector3.UP)
	x = x.normalized() if x.length_squared() > 1e-6 else Vector3.RIGHT
	return Basis(x, dir.cross(x), dir * length)


## The ribbon's quad (see BEAM_SHADER), its look `cfg`'s.
static func beam_mesh(cfg: EffectsConfig) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-1.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0),
			Vector3(-1.0, 0.0, 1.0), Vector3(1.0, 0.0, 1.0)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 1, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var look := ShaderMaterial.new()
	look.shader = CodeShaders.of(BEAM_SHADER)
	look.set_shader_parameter(&"width", cfg.laser_width)
	look.set_shader_parameter(&"min_angle", cfg.laser_min_angle)
	look.set_shader_parameter(&"core_mix", cfg.laser_core_mix)
	mesh.surface_set_material(0, look)
	return mesh
