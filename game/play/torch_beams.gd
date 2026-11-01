class_name TorchBeams
extends Node3D
## The weapon torches as drawn at night (WL7; the browser game's render/light/torchBeams.ts): everyone else's lit torch
## is a cone of haze along its beam, a glare on its lens that flares as it points at the eye, and a lit spot where the
## middle of its beam falls on the level, all three instanced for the match (three draw calls, however many torches
## are lit). A lit torch gives its holder away. The torch of the one the view is through is a real spot from the rail
## (FirstPersonView) on Medium and up; on Low (`own_haze`) it is drawn here instead, its cone and spot from the rail.
## Look only: the torch's state is the simulation's (Torch), and nothing here is read back. `update` each rendered frame
## allocates nothing.

## How a view's own torch is drawn (GraphicsApply.torch_mode): a haze drawn here, or a real spot (one of the preset's
## real lights), casting shadows or not.
enum Mode { HAZE, SPOT, SHADOWED }

## The torch's light: a neutral white, at least 20° of hue from every team colour (the night's light rule; a test holds
## it).
const COLOUR := Color8(250, 250, 236)
## The cone drawn: this share of the torch's reach long, as wide as its spill, at this strength at the lens fading to
## nothing at its end (by CONE_FADE: higher is quicker), from CONE_NEAR m off the eye up (so a cone over the eye never
## fills the view).
const CONE_SHARE := 0.5
const CONE_STRENGTH := 0.6
const CONE_SEGMENTS := 24
const CONE_NEAR := 1.5
const CONE_FADE := 1.5
## Your own haze on Low, at this share of an other's cone (it fills the view), its tip OWN_AHEAD m out along the beam
## from the rail: seen from its tip a cone is all rim (a hard ring); from behind it fills softly from the middle.
const OWN_HAZE := 0.5
const OWN_AHEAD := 2.0
## The lens's glare: a billboard GLARE_SIZE m across at GLARE_STRENGTH seen straight down the beam, down to GLARE_SIDE
## of both seen from the side or behind, sharpening towards the beam's middle by GLARE_POWER.
const GLARE_SIZE := 1.4
const GLARE_STRENGTH := 1.6
const GLARE_SIDE := 0.45
const GLARE_POWER := 6.0
## The lit spot where the beam's middle lands: as wide as the spill there, SPOT_STRENGTH bright up close fading to
## nothing at the torch's reach, SPOT_LIFT m off the surface.
const SPOT_STRENGTH := 0.5
const SPOT_LIFT := 0.04
## Where a figure's torch sits: MUZZLE_BACK m back along its beam from the muzzle of the replica in its hand; with no
## replica shown, EYE_DROP m under its eyes.
const MUZZLE_BACK := 0.3
const EYE_DROP := 0.3
## Your own torch on the rail, in the view's space (m: right, up, forward is -z), and its real spot's strength and
## falloff along and across the beam (FirstPersonView; reach and spill are the light's own, stats.md).
const RAIL := Vector3(0.14, -0.13, -0.45)
const SPOT_ENERGY := 14.0
const SPOT_ATTENUATION := 0.8
const SPOT_ANGLE_ATTENUATION := 1.6
## The cone's haze: brightest where it faces the eye, faint at its silhouette, nothing within CONE_NEAR of the eye.
const CONE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform float near_fade = 1.5;

uniform float fade_power = 1.5;

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float near = clamp(length(VERTEX) / near_fade - 1.0, 0.0, 1.0);
	float along = pow(1.0 - clamp(UV.x, 0.0, 1.0), fade_power);
	ALBEDO = COLOR.rgb * along * facing * facing * near;
}
"""

var _cones: MultiMeshInstance3D = null
var _glares: MultiMeshInstance3D = null
var _spots: MultiMeshInstance3D = null
var _query: WorldQuery = null
var _body: BodyConfig = null
var _hit: RayHit = RayHit.new()
var _own_haze: bool = false
var _lit: int = 0


## Room for `count` torches (everyone on the field), spots found on `query`'s level (null: none drawn), the eyes'
## height from `body`.
func setup(count: int, query: WorldQuery, body: BodyConfig) -> void:
	name = "TorchBeams"
	_query = query
	_body = body
	_cones = _instanced("Cones", cone_mesh(CONE_SEGMENTS), count)
	_glares = _instanced("Glares", _glare_mesh(), count)
	_spots = _instanced("Spots", _spot_mesh(), count)
	for draw: MultiMeshInstance3D in [_cones, _glares, _spots]:
		add_child(draw)


## Your own torch drawn here (Low: no real light for it), or by FirstPersonView's real spot.
func set_own_haze(on: bool) -> void:
	_own_haze = on


## Torches drawn on the last update (cones; a glare and a spot go with each but your own).
func lit_count() -> int:
	return _lit


## The three materials, for the shader prewarm.
func materials() -> Array[Material]:
	return [_cones.multimesh.mesh.surface_get_material(0), _glares.multimesh.mesh.surface_get_material(0),
			_spots.multimesh.mesh.surface_get_material(0)]


## The three draws (cones, glares, spots), for tests and the debug count.
func draws() -> Array[MultiMeshInstance3D]:
	return [_cones, _glares, _spots]


## Draws every lit torch for this frame, `fraction` of the way from the last tick to this one: everyone's but
## `watched`'s from their figure (`figure_of`, by id; null where none), and `watched`'s from `camera`'s rail while its
## haze is drawn here.
func update(characters: Array[Character], watched: Character, fraction: float, figure_of: Array[FigureView],
		camera: Camera3D) -> void:
	var eye := camera.global_position
	var cones := _cones.multimesh
	var glares := _glares.multimesh
	var spots := _spots.multimesh
	var n := 0
	var spot_n := 0
	var glare_n := 0
	for c in characters:
		if not Torch.lit(c):
			continue
		var light := Torch.in_hand(c)
		var origin := Vector3.ZERO
		var dir := Vector3.ZERO
		var own := c == watched
		if own:
			if not _own_haze:
				continue
			origin = camera.global_transform * (RAIL + Vector3(0.0, 0.0, -OWN_AHEAD))
			dir = -camera.global_basis.z
		else:
			var yaw := lerp_angle(c.prev_yaw, c.yaw, fraction)
			var pitch := lerpf(c.prev_pitch, c.pitch, fraction)
			var cp := cos(pitch)
			dir = Vector3(-sin(yaw) * cp, sin(pitch), -cos(yaw) * cp)
			var f: FigureView = figure_of[c.id] if c.id < figure_of.size() else null
			var slot := c.armament.active
			if f != null and f.muzzle_shown(slot):
				origin = f.muzzle_position(slot) - dir * MUZZLE_BACK
			else:
				var feet := c.prev_position.lerp(c.position, fraction)
				var crouch := lerpf(c.prev_crouch_amount, c.crouch_amount, fraction)
				origin = feet + Vector3(0.0, Character.eye_height(crouch, _body) - EYE_DROP, 0.0)
		var length := light.reach * CONE_SHARE
		var wide := length * tan(deg_to_rad(light.spill_deg * 0.5))
		var strength := CONE_STRENGTH * (OWN_HAZE if own else 1.0)
		cones.set_instance_transform(n, Transform3D(_aim_basis(dir) * Basis.from_scale(Vector3(wide, wide, length)),
				origin))
		cones.set_instance_color(n, Color(COLOUR.r * strength, COLOUR.g * strength, COLOUR.b * strength))
		n += 1
		if not own:
			var to_eye := eye - origin
			var d := to_eye.length()
			var facing := dir.dot(to_eye / d) if d > 1e-4 else 1.0
			var flare := GLARE_SIDE + (1.0 - GLARE_SIDE) * pow(maxf(facing, 0.0), GLARE_POWER)
			glares.set_instance_transform(glare_n, Transform3D(Basis.from_scale(Vector3.ONE * GLARE_SIZE * flare),
					origin))
			var g := GLARE_STRENGTH * flare
			glares.set_instance_color(glare_n, Color(COLOUR.r * g, COLOUR.g * g, COLOUR.b * g))
			glare_n += 1
		if _query != null and _query.ray(origin, origin + dir * light.reach, _hit):
			var dist := light.reach * _hit.fraction
			var size := 2.0 * dist * tan(deg_to_rad(light.spill_deg * 0.5))
			var s := SPOT_STRENGTH * clampf(1.0 - _hit.fraction, 0.0, 1.0)
			var face := Basis.looking_at(-_hit.normal, Vector3.FORWARD if absf(_hit.normal.y) > 0.9 else Vector3.UP)
			spots.set_instance_transform(spot_n, Transform3D(face * Basis.from_scale(Vector3(size, size, 1.0)),
					_hit.position + _hit.normal * SPOT_LIFT))
			spots.set_instance_color(spot_n, Color(COLOUR.r * s, COLOUR.g * s, COLOUR.b * s))
			spot_n += 1
	cones.visible_instance_count = n
	glares.visible_instance_count = glare_n
	spots.visible_instance_count = spot_n
	_lit = n


## A unit cone: its tip at the origin, its rim one metre down -z with a radius of one, UV.x how far along (0 at the tip,
## 1 at the rim, where the shader fades it to nothing), its normals outward.
static func cone_mesh(segments: int) -> ArrayMesh:
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	var segs := maxi(3, segments)
	for s in segs + 1:
		var a := TAU * s / segs
		var out := Vector3(cos(a), sin(a), 0.0)
		var normal := (out + Vector3(0.0, 0.0, 1.0)).normalized()
		pos.append(Vector3.ZERO)
		nrm.append(normal)
		uv.append(Vector2(0.0, float(s) / segs))
		pos.append(Vector3(out.x, out.y, -1.0))
		nrm.append(normal)
		uv.append(Vector2(1.0, float(s) / segs))
	for s in segs:
		var k := s * 2
		idx.append_array([k, k + 3, k + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	arrays[Mesh.ARRAY_NORMAL] = nrm
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var look := ShaderMaterial.new()
	look.shader = CodeShaders.of(CONE_SHADER)
	look.set_shader_parameter(&"near_fade", CONE_NEAR)
	look.set_shader_parameter(&"fade_power", CONE_FADE)
	mesh.surface_set_material(0, look)
	return mesh


## A basis whose -z runs along `dir` (unit).
static func _aim_basis(dir: Vector3) -> Basis:
	return Basis.looking_at(dir, Vector3.FORWARD if absf(dir.y) > 0.99 else Vector3.UP)


static func _instanced(node_name: String, mesh: Mesh, count: int) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = maxi(1, count)
	mm.visible_instance_count = 0
	var inst := MultiMeshInstance3D.new()
	inst.name = node_name
	inst.multimesh = mm
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return inst


## The glare's billboard: a soft round flare, added to what is behind it.
static func _glare_mesh() -> QuadMesh:
	var quad := QuadMesh.new()
	var look := _soft_look(PackedFloat32Array([0.0, 0.12, 1.0]),
			PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.3), Color(1, 1, 1, 0)]))
	look.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	look.billboard_keep_scale = true
	quad.material = look
	return quad


## The spot's quad, lying on the surface it lands on (+z its normal): bright in the middle, soft to its edge.
static func _spot_mesh() -> QuadMesh:
	var quad := QuadMesh.new()
	var look := _soft_look(PackedFloat32Array([0.0, 0.35, 1.0]),
			PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)]))
	quad.material = look
	return quad


static func _soft_look(offsets: PackedFloat32Array, colours: PackedColorArray) -> StandardMaterial3D:
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	look.vertex_color_use_as_albedo = true
	look.disable_fog = true
	var soft := GradientTexture2D.new()
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(0.5, 0.0)
	var g := Gradient.new()
	g.offsets = offsets
	g.colors = colours
	soft.gradient = g
	look.albedo_texture = soft
	return look
