class_name WoodsView
extends Node3D
## A wood's look in placeholders (WL4; MapData's dressing, WoodsShapes' geometry, WoodsConfig's tuning): every tree's
## crown, instanced on every preset; and from Medium (the Mesh detail row) the wood beyond the fence (a share of it a
## step), grass tufts in tiles that cull and shrink away with distance, the puddles and mud (glossy, see-through, drawn
## before every other see-through thing so none hides a BB), and the leaf drifts, fallen wood and moss as one mesh. By
## night, fireflies and motes as one instanced draw, the Wind dust row's share of them, standing still and steady under
## Reduced motion. Look only: no collider, no nav cell, nothing the simulation reads; crowns sit over head height.

## A tuft: the grass's own colour (its instance colour, sRGB, taken to linear where the renderer works in linear, as
## a vertex colour marked sRGB is) from root to tip, lit as the ground under it is (the mesh's normals point straight
## up), shrinking to nothing over the last `fade` of `reach` m from the eye. Each blade is two faces, one each way,
## rather than one face drawn from both sides: the simpler renderer lights a back face black whatever its normal.
const TUFT_SHADER := """
shader_type spatial;

uniform float reach = 30.0;
uniform float fade = 0.3;
uniform float root = 0.7;
uniform float tip = 1.25;
uniform float rough = 0.9;
uniform float shine = 0.2;
varying float up;

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float keep = 1.0 - smoothstep(reach * (1.0 - fade), reach, distance(origin, CAMERA_POSITION_WORLD));
	VERTEX *= keep;
	up = UV.y;
}

void fragment() {
	vec3 own = COLOR.rgb;
	if (!OUTPUT_IS_SRGB) {
		own = mix(pow((own + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), own * (1.0 / 12.92), lessThan(own, vec3(0.04045)));
	}
	ALBEDO = own * mix(root, tip, up);
	ROUGHNESS = rough;
	SPECULAR = shine;
}
"""
## Fireflies and motes: points facing the eye, self-lit and added to what is behind them, through the haze. A firefly
## drifts round where it hangs and pulses; a mote drifts through a box round the eye (`eye`, `box`), wrapping at its
## sides and fading there. `motion` 0 holds both still and steady (Reduced motion).
const AIR_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled, skip_vertex_transform;

uniform vec3 eye = vec3(0.0);
uniform vec3 box = vec3(16.0, 4.0, 16.0);
uniform float edge = 1.5;
uniform float motion = 1.0;
uniform vec4 firefly : source_color = vec4(1.0);
uniform vec4 mote : source_color = vec4(1.0);
uniform float drift = 0.35;
uniform float low = 0.12;
uniform float speed = 0.12;
uniform vec3 wind = vec3(0.6, 0.15, 0.4);
varying vec3 tint;
varying float shine;

void vertex() {
	vec3 at = MODEL_MATRIX[3].xyz;
	float t = TIME * motion;
	float phase = INSTANCE_CUSTOM.y * 6.2831853;
	if (INSTANCE_CUSTOM.x < 0.5) {
		at += drift * vec3(sin(t * 0.37 + phase), 0.5 * sin(t * 0.53 + phase * 1.7), cos(t * 0.29 + phase * 0.6));
		float pulse = 0.5 + 0.5 * sin(t * 6.2831853 / max(INSTANCE_CUSTOM.z, 0.1) + phase);
		shine = motion > 0.0 ? mix(low, 1.0, pulse) : 1.0;
		tint = firefly.rgb;
	} else {
		vec3 corner = eye - box * 0.5;
		at = corner + mod(at + wind * speed * t * (0.5 + INSTANCE_CUSTOM.y) - corner, box);
		vec3 inside = min(at - corner, corner + box - at);
		shine = clamp(min(inside.x, min(inside.y, inside.z)) / edge, 0.0, 1.0);
		tint = mote.rgb;
	}
	vec3 centre = (VIEW_MATRIX * vec4(at, 1.0)).xyz;
	VERTEX = centre + vec3(VERTEX.xy * INSTANCE_CUSTOM.w, 0.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	float round_edge = 1.0 - smoothstep(0.15, 0.5, length(UV - vec2(0.5)));
	ALBEDO = tint;
	ALPHA = round_edge * shine;
}
"""

## A tuft tile is drawn while its middle is within its step's reach and this share of its side (its middle to its
## far corner is 0.71 of the side).
const TILE_REACH := 0.75
## How far under and over 0 the night air's box reaches (m): past any field's ground and eye.
const AIR_DEPTH := 100.0

var _cfg: WoodsConfig = null
var _crowns: MultiMeshInstance3D = null
var _forest: MultiMeshInstance3D = null
var _tufts: Array[MultiMeshInstance3D] = []
var _tuft_look: ShaderMaterial = null
var _puddles: MeshInstance3D = null
var _floor: MeshInstance3D = null
var _air: MultiMeshInstance3D = null
var _air_look: ShaderMaterial = null


## `map`'s wood drawn with `cfg`, under `lighting` (the playing preset: its horizon fades the forest, its night flag
## brings the fireflies and motes), the grass in `style`'s colour, the forest faded as `sky` fades the skyline; null
## on a map with no trees and none of a wood's dressing. Every part starts as Low draws it (`set_quality`).
static func build(map: MapData, cfg: WoodsConfig, sky: SkylineConfig, lighting: LightingConfig,
		style: MapStyle) -> WoodsView:
	var view := WoodsView.new()
	view.name = "Woods"
	view._cfg = cfg
	view._make_crowns(WoodsShapes.crowns(map, cfg))
	view._make_forest(WoodsShapes.forest(map, cfg, sky, lighting.sky_horizon))
	view._make_tufts(WoodsShapes.tufts(map, cfg, style))
	view._make_puddles(WoodsShapes.puddles(map, cfg))
	view._make_floor(WoodsShapes.floor_mesh(map, cfg))
	if lighting.night:
		view._make_air(WoodsShapes.night_air(map, cfg), map)
	if view.get_child_count() == 0:
		view.free()
		return null
	view.set_quality(GraphicsQuality.MeshDetail.LOW, 0.0)
	return view


## Draws each part as Mesh detail step `detail` (GraphicsQuality.MeshDetail) asks, and `dust_share` (the Wind dust
## row, 0 to 1) of the fireflies and motes.
func set_quality(detail: int, dust_share: float) -> void:
	var dressed := detail >= GraphicsQuality.MeshDetail.MEDIUM
	if _forest != null:
		_show_share(_forest, WoodsConfig.on_step(_cfg.forest_share, detail))
	if not _tufts.is_empty():
		var most := WoodsConfig.on_step(_cfg.tuft_density, _cfg.tuft_density.size() - 1)
		var share := WoodsConfig.on_step(_cfg.tuft_density, detail) / most if most > 0.0 else 0.0
		var reach := WoodsConfig.on_step(_cfg.tuft_range, detail)
		_tuft_look.set_shader_parameter(&"reach", reach)
		for tile in _tufts:
			_show_share(tile, share if reach > 0.0 else 0.0)
			tile.visibility_range_end = reach + _cfg.tile * TILE_REACH
	if _puddles != null:
		_puddles.visible = dressed
	if _floor != null:
		_floor.visible = dressed
	if _air != null:
		_show_share(_air, clampf(dust_share, 0.0, 1.0))


## Reduced motion holds the fireflies and motes still and steady.
func set_motion(motion: MotionScale) -> void:
	if _air_look != null:
		_air_look.set_shader_parameter(&"motion", 1.0 if motion.dust > 0.0 else 0.0)


## Follows the eye at `eye` with the motes' box (nothing to do without them).
func update(eye: Vector3) -> void:
	if _air != null and _air.visible:
		_air_look.set_shader_parameter(&"eye", eye)


## The materials it draws, for ShaderPrewarm.
func materials() -> Array[Material]:
	var out: Array[Material] = []
	for g: GeometryInstance3D in [_crowns, _forest, _floor, _air]:
		if g != null:
			out.append(g.material_override)
	if _puddles != null:
		for i in _puddles.mesh.get_surface_count():
			out.append(_puddles.mesh.surface_get_material(i))
	if _tuft_look != null:
		out.append(_tuft_look)
	return out


## The crowns, or null on a map with no trees.
func crowns() -> MultiMeshInstance3D:
	return _crowns


## The wood beyond the fence, or null without one.
func forest() -> MultiMeshInstance3D:
	return _forest


## The grass tufts' tiles (empty without grass).
func tufts() -> Array[MultiMeshInstance3D]:
	return _tufts


## The puddles and mud, or null without them.
func puddles() -> MeshInstance3D:
	return _puddles


## The leaf drifts, fallen wood and moss, or null without them.
func floor_pieces() -> MeshInstance3D:
	return _floor


## The fireflies and motes, or null by day or without them.
func air() -> MultiMeshInstance3D:
	return _air


func _make_crowns(placed: WoodsShapes.Placed) -> void:
	if placed.size() == 0:
		return
	_crowns = _instanced("Crowns", placed.multimesh(), _flat_material(_cfg.crown_roughness))


func _make_forest(placed: WoodsShapes.Placed) -> void:
	if placed == null or placed.size() == 0:
		return
	_forest = _instanced("Forest", placed.multimesh(), _flat_material(_cfg.crown_roughness))
	_forest.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _make_tufts(tiles: Array[WoodsShapes.Placed]) -> void:
	var holder: Node3D = null
	for i in tiles.size():
		if tiles[i].size() == 0:
			continue
		if holder == null:
			holder = Node3D.new()
			holder.name = "Tufts"
			add_child(holder)
			_tuft_look = ShaderMaterial.new()
			_tuft_look.shader = Shader.new()
			_tuft_look.shader.code = TUFT_SHADER
			_tuft_look.set_shader_parameter(&"fade", _cfg.tuft_fade)
			_tuft_look.set_shader_parameter(&"root", _cfg.tuft_root)
			_tuft_look.set_shader_parameter(&"tip", _cfg.tuft_tip)
			_tuft_look.set_shader_parameter(&"rough", _cfg.roughness)
			_tuft_look.set_shader_parameter(&"shine", _cfg.tuft_specular)
		var mi := MultiMeshInstance3D.new()
		mi.name = "Tile%d" % i
		mi.multimesh = tiles[i].multimesh()
		mi.material_override = _tuft_look
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(mi)
		_tufts.append(mi)


func _make_puddles(mesh: ArrayMesh) -> void:
	if mesh == null:
		return
	for i in mesh.get_surface_count():
		var rough := _cfg.mud_roughness if mesh.surface_get_name(i) == WoodsShapes.MUD else _cfg.puddle_roughness
		mesh.surface_set_material(i, LookMaterials.clear_colour(rough))
	_puddles = MeshInstance3D.new()
	_puddles.name = "Puddles"
	_puddles.mesh = mesh
	_puddles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_puddles)


func _make_floor(mesh: ArrayMesh) -> void:
	if mesh == null:
		return
	_floor = MeshInstance3D.new()
	_floor.name = "Floor"
	_floor.mesh = mesh
	_floor.material_override = _flat_material(_cfg.roughness)
	_floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_floor)


func _make_air(placed: WoodsShapes.Placed, map: MapData) -> void:
	if placed == null:
		return
	_air_look = ShaderMaterial.new()
	_air_look.shader = Shader.new()
	_air_look.shader.code = AIR_SHADER
	_air_look.set_shader_parameter(&"box", _cfg.mote_box)
	_air_look.set_shader_parameter(&"edge", _cfg.mote_edge)
	_air_look.set_shader_parameter(&"firefly", _cfg.firefly_colour * _cfg.firefly_glow)
	_air_look.set_shader_parameter(&"mote", map.motes_tint * _cfg.mote_glow)
	_air_look.set_shader_parameter(&"drift", _cfg.firefly_drift)
	_air_look.set_shader_parameter(&"low", _cfg.firefly_low)
	_air_look.set_shader_parameter(&"speed", _cfg.mote_speed)
	_air_look.set_shader_parameter(&"wind", _cfg.mote_wind)
	_air = _instanced("NightAir", placed.multimesh(), _air_look)
	_air.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# the shader moves every point: the field and the motes' box round any eye on it
	var field := WoodsShapes.field_rect(map)
	var lo := Vector3(field.position.x, -AIR_DEPTH, field.position.y) - _cfg.mote_box
	_air.custom_aabb = AABB(lo, Vector3(field.size.x, AIR_DEPTH * 2.0, field.size.y) + _cfg.mote_box * 2.0)


func _instanced(id: String, mm: MultiMesh, look: Material) -> MultiMeshInstance3D:
	var mi := MultiMeshInstance3D.new()
	mi.name = id
	mi.multimesh = mm
	mi.material_override = look
	add_child(mi)
	return mi


## A vertex-coloured (sRGB) material in the shared light (docs/ART.md › A map in the look).
func _flat_material(rough: float) -> ShaderMaterial:
	return LookMaterials.vertex_colour(rough, 0.0, Color.WHITE, true)


## Draws `share` of `mi`'s instances (a seeded order's first ones), hiding it at none.
static func _show_share(mi: MultiMeshInstance3D, share: float) -> void:
	var n := roundi(mi.multimesh.instance_count * clampf(share, 0.0, 1.0))
	mi.visible = n > 0
	mi.multimesh.visible_instance_count = n
