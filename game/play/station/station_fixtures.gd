class_name StationFixtures
extends Node3D
## A station's lamps and extras (SM5, Subway: MapData.station's fixtures): the running tunnels' bulkhead lamps, the
## station's name boards, way-out signs, posters, clocks, CCTV cameras, fire extinguishers, litter bins and the
## platform edges' warnings; and a hall's wall extras (DX1, Depot: MapData.fixtures, its fire points, call points,
## pipework and safety signs; RQ1, the Range: its firing point's shelter, red flag and signs). One MultiMesh a model
## (StationFixturesConfig). A lamp's glass glows (no real light: the ceilings' strip lamps light the station, RoofView),
## a printed face shows its sign sheet. Look only: no collider, nothing the simulation reads; no shadow but from
## StationFixturesConfig.shadow_models. Built once; nothing runs a frame.

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
## The lit models' lights (StationFixturesConfig.lit_models), hidden until set_lamps shows them.
var _lamps: Array[OmniLight3D] = []


## The fixtures of `map`'s station and its own wall extras (MapData.fixtures, DX1: Depot's) drawn under `cfg`, or null
## on a map with none.
static func build(map: MapData, cfg: StationFixturesConfig) -> StationFixtures:
	if map == null or cfg == null:
		return null
	var fixtures: Array[StationDressing.Fixture] = []
	if map.station != null:
		fixtures.append_array(map.station.fixtures)
	fixtures.append_array(map.fixtures)
	if fixtures.is_empty():
		return null
	var placed := placings_of(fixtures, cfg)
	if placed.is_empty():
		return null
	var view := StationFixtures.new()
	view.name = "StationFixtures"
	view._placed = placed
	var prop := LookMaterials.vertex_colour(cfg.roughness, cfg.metallic, Color.WHITE, false, cfg.wear)
	var glow := ShaderMaterial.new()
	glow.shader = CodeShaders.of(GLOW_SHADER)
	glow.set_shader_parameter(&"glow", cfg.lens_colour * cfg.lens_energy)
	view._materials.append_array([prop, glow])
	# each sign sheet's printed material, made the first time a model printing from it is drawn
	var printed: Dictionary[String, Material] = {}
	for model: StringName in placed:
		var src := PropDressConfig.load_mesh(cfg.path_of(model))
		if src == null:
			push_warning("StationFixtures: \"%s\" won't load; its fixtures are left out" % cfg.path_of(model))
			continue
		var sheet_path := cfg.sheet_of(model)
		if not printed.has(sheet_path):
			printed[sheet_path] = _printed(sheet_path, cfg, prop)
			if printed[sheet_path] != prop:
				view._materials.append(printed[sheet_path])
		var mesh := _surfaces(src, prop, glow, printed[sheet_path])
		var chunk: float = cfg.chunks.get(model, 0.0)
		if chunk > 0.0:
			var groups := chunked(placed[model], chunk)
			for i in groups.size():
				view._add(model, mesh, groups[i], i)
		else:
			view._add(model, mesh, placed[model])
		if cfg.shadow_models.has(String(model)):
			for inst in view._views:
				if inst.multimesh.mesh == mesh:
					inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if cfg.lit_models.has(String(model)):
			for t: Transform3D in placed[model]:
				view._add_lamp(t * Vector3(0.0, 0.0, cfg.lamp_out), cfg)
	return view


## The printed material for the sign sheet at `path`, or `prop` (the signs drawn blank) when it won't load.
static func _printed(path: String, cfg: StationFixturesConfig, prop: Material) -> Material:
	var sheet := load(path) as Texture2D if ResourceLoader.exists(path) else null
	if sheet == null:
		push_warning("StationFixtures: the sign sheet \"%s\" won't load; signs drawn blank" % path)
		return prop
	return LookMaterials.printed(sheet, cfg.sign_roughness, cfg.wear)


## Each model's transforms, by its name, in the file's order; a fixture naming a model `cfg` doesn't list is left out
## (warned). Pure.
static func placings(station: StationDressing, cfg: StationFixturesConfig) -> Dictionary[StringName, Array]:
	return placings_of(station.fixtures, cfg)


## `fixtures`' transforms by model, as `placings`. Pure.
static func placings_of(fixtures: Array[StationDressing.Fixture], cfg: StationFixturesConfig) \
		-> Dictionary[StringName, Array]:
	var out: Dictionary[StringName, Array] = {}
	for f: StationDressing.Fixture in fixtures:
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


## `transforms` split by the `size` m square of the world their origins stand in, in order of first use. Pure.
static func chunked(transforms: Array, size: float) -> Array[Array]:
	var cells: Dictionary[Vector2i, int] = {}
	var out: Array[Array] = []
	for t: Transform3D in transforms:
		var cell := Vector2i(floori(t.origin.x / size), floori(t.origin.z / size))
		if not cells.has(cell):
			cells[cell] = out.size()
			out.append([])
		out[cells[cell]].append(t)
	return out


## One MultiMesh of `model` at `transforms`, named for its model (and its chunk, `part`, when it is one of several).
func _add(model: StringName, mesh: ArrayMesh, transforms: Array, part: int = -1) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var inst := MultiMeshInstance3D.new()
	inst.name = String(model).to_pascal_case() + ("" if part < 0 else "Chunk%d" % part)
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
	lamp.visible = false
	add_child(lamp)
	_lamps.append(lamp)


## Turns the lit models' lights on (the station's lamps light: Settings › Graphics › Lamp lights, as the lifts') or off.
func set_lamps(on: bool) -> void:
	for l in _lamps:
		l.visible = on


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
