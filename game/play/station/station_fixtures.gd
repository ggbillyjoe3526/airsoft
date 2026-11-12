class_name StationFixtures
extends Node3D
## A station's lamps and extras (SM5, Subway: MapData.station's fixtures): the running tunnels' bulkhead lamps, the
## station's name boards, way-out signs, posters, clocks, CCTV cameras, fire extinguishers, litter bins and the
## platform edges' warnings, one MultiMesh a model (StationFixturesConfig). A lamp's glass glows (no real light: the
## ceilings' strip lamps light the station, RoofView), a printed face shows the sign sheet. Look only: no collider,
## no shadow, nothing the simulation reads. Built once; nothing runs a frame.

const PROP_SURFACE := &"Prop"
const LENS_SURFACE := &"Lens"
const SIGN_SURFACE := &"Sign"
const GLOW_SHADER := """shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled;
uniform vec4 glow : source_color = vec4(1.0);
void fragment() {
	ALBEDO = glow.rgb;
}
"""

var _views: Array[MultiMeshInstance3D] = []
var _materials: Array[Material] = []
var _placed: Dictionary[StringName, Array] = {}
## The lit models' lights (StationFixturesConfig.lit_models).
var _lamps: Array[OmniLight3D] = []


## The fixtures of `map`'s station drawn under `cfg`, or null on a map with none.
static func build(map: MapData, cfg: StationFixturesConfig) -> StationFixtures:
	if map == null or cfg == null or map.station == null or map.station.fixtures.is_empty():
		return null
	var placed := placings(map.station, cfg)
	if placed.is_empty():
		return null
	var view := StationFixtures.new()
	view.name = "StationFixtures"
	view._placed = placed
	var prop := LookMaterials.vertex_colour(cfg.roughness, cfg.metallic, Color.WHITE, false, cfg.wear)
	var glow := ShaderMaterial.new()
	glow.shader = CodeShaders.of(GLOW_SHADER)
	glow.set_shader_parameter(&"glow", cfg.lens_colour * cfg.lens_energy)
	var sheet := load(cfg.sign_sheet) as Texture2D if ResourceLoader.exists(cfg.sign_sheet) else null
	var printed: Material = LookMaterials.printed(sheet, cfg.sign_roughness, cfg.wear) if sheet != null else prop
	if sheet == null:
		push_warning("StationFixtures: the sign sheet \"%s\" won't load; signs drawn blank" % cfg.sign_sheet)
	view._materials.append_array([prop, glow, printed])
	for model: StringName in placed:
		var src := PropDressConfig.load_mesh(cfg.path_of(model))
		if src == null:
			push_warning("StationFixtures: \"%s\" won't load; its fixtures are left out" % cfg.path_of(model))
			continue
		view._add(model, _surfaces(src, prop, glow, printed), placed[model])
		if cfg.lit_models.has(String(model)):
			for t: Transform3D in placed[model]:
				view._add_lamp(t * Vector3(0.0, 0.0, cfg.lamp_out), cfg)
	return view


## Each model's transforms, by its name, in the file's order; a fixture naming a model `cfg` doesn't list is left out
## (warned). Pure.
static func placings(station: StationDressing, cfg: StationFixturesConfig) -> Dictionary[StringName, Array]:
	var out: Dictionary[StringName, Array] = {}
	for f: StationDressing.Fixture in station.fixtures:
		if not cfg.models.has(String(f.model)):
			push_warning("StationFixtures: no model \"%s\"; left out" % f.model)
			continue
		if not out.has(f.model):
			out[f.model] = []
		out[f.model].append(Transform3D(Basis(Vector3.UP, f.yaw).scaled(Vector3.ONE * f.scale), f.position))
	return out


## `src`'s surfaces drawn by each surface's material name: the shared light's for its own, `glow` for a lamp's glass,
## `printed` for a printed face.
static func _surfaces(src: Mesh, prop: Material, glow: Material, printed: Material) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for s in src.get_surface_count():
		var m := src.surface_get_material(s)
		var surface_name := StringName(m.resource_name) if m != null else PROP_SURFACE
		var look: Material = prop
		if surface_name == LENS_SURFACE:
			look = glow
		elif surface_name == SIGN_SURFACE:
			look = printed
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, src.surface_get_arrays(s))
		mesh.surface_set_material(mesh.get_surface_count() - 1, look)
	return mesh


func _add(model: StringName, mesh: ArrayMesh, transforms: Array) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var inst := MultiMeshInstance3D.new()
	inst.name = String(model).to_pascal_case()
	inst.multimesh = mm
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(inst)
	_views.append(inst)


func _add_lamp(at: Vector3, cfg: StationFixturesConfig) -> void:
	var lamp := OmniLight3D.new()
	lamp.name = "Lamp%d" % _lamps.size()
	lamp.position = at
	lamp.omni_range = cfg.lamp_range
	lamp.light_energy = cfg.lamp_energy
	lamp.light_color = cfg.lens_colour
	lamp.shadow_enabled = false
	lamp.light_bake_mode = Light3D.BAKE_STATIC
	add_child(lamp)
	_lamps.append(lamp)


func lamps() -> Array[OmniLight3D]:
	return _lamps


## Each model's instances, by name: what the views draw.
func placed() -> Dictionary[StringName, Array]:
	return _placed


func views() -> Array[MultiMeshInstance3D]:
	return _views


## The materials drawn, to warm their shaders before play.
func materials() -> Array[Material]:
	return _materials
