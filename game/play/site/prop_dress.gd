class_name PropDress
extends Node3D
## A map's CC0 props (DR2, WR3): the drums, barrels, pallets and sofa that stand in the blocks of the kinds
## PropDressConfig dresses, and Woodland's trunks, logs, cordwood, spruces, tyres, crates and truck in the blocks that
## name them, where PropLayout lays them, one MultiMesh a model (a model laid often, or tiled, one a chunk,
## PropDressConfig.many_chunk or chunk, so it culls and takes its level of detail by area) in one vertex-coloured material. A
## drum, barrel or sofa casts its own shadow (its box draws nothing, SiteSurface.core_of, and leaves MapLevel's shadow
## caster); shelving casts none, its rack's backing box still does. Depot's crate walls, plywood walls and containers
## are map models of the game's own (DM1, tools/blender/maps). Each prop is drawn in its own shade times its paint (a
## container's unit colour, DM1) times, while a bake is drawn, the baked light near it (`relight`, BP7). Scenery only: no collider, no nav cell; the blocks' boxes
## are what BBs and bodies meet, a round prop's (a trunk, a drum, a barrel) as its stepped boxes (RoundSteps).

## A prop takes the baked light near this far (m) over its foot, from faces facing any way (BakedLightNear.at).
const LIGHT_LIFT := 0.5

var _material: ShaderMaterial = null
var _views: Dictionary[StringName, Array] = {} # each model's MultiMeshInstance3Ds, a chunk each
var _meshes: Dictionary[StringName, Mesh] = {}
var _placed: Dictionary[StringName, PropLayout.Placed] = {}
## Each view's instances, as indices into its model's Placed (in `_views`' order), and each prop's light while a bake
## is drawn (empty with none).
var _picks: Dictionary[StringName, Array] = {}
var _lights: Dictionary[StringName, PackedColorArray] = {}


## The props of `map` dressed by `cfg`, or null when it dresses none of its blocks. A model that won't load leaves
## its kind's blocks as boxes (with a warning) and its props out.
static func build(map: MapData, cfg: PropDressConfig, paint: Callable = Callable()) -> PropDress:
	if map == null or cfg == null:
		return null
	var meshes: Dictionary[StringName, Mesh] = {}
	var boxes: Dictionary[StringName, AABB] = {}
	for model: StringName in _models_used(map, cfg):
		var mesh := cfg.mesh_of(model) # warns once when it won't load
		if mesh == null:
			continue
		meshes[model] = mesh
		boxes[model] = mesh.get_aabb()
	var placed := PropLayout.layout(map, cfg, boxes, paint)
	if placed.is_empty():
		return null
	var dress := PropDress.new()
	dress.name = "Props"
	dress._material = LookMaterials.vertex_colour(cfg.roughness, cfg.metallic)
	dress._material.set_shader_parameter(&"paint_by_custom", true)
	dress._placed = placed
	dress._meshes = meshes
	for model: StringName in placed:
		var tiled := _tiled(cfg, model)
		var many := placed[model].transforms.size() >= cfg.chunk_from
		var chunk := cfg.chunk if tiled else cfg.many_chunk if many else INF
		dress._add(model, meshes[model], placed[model], not tiled, chunk)
	return dress


## Model `model`'s views, a chunk each (none when the model isn't drawn).
func views_of(model: StringName) -> Array[MultiMeshInstance3D]:
	var out: Array[MultiMeshInstance3D] = []
	out.assign(_views.get(model, []))
	return out


## Every view.
func all_views() -> Array[MultiMeshInstance3D]:
	var out: Array[MultiMeshInstance3D] = []
	for model: StringName in _views:
		out.append_array(views_of(model))
	return out


## How many of `model` are drawn.
func count(model: StringName) -> int:
	var n := 0
	for view in views_of(model):
		n += view.multimesh.instance_count
	return n


## Model `model`'s mesh, or null when it isn't drawn.
func mesh_of(model: StringName) -> Mesh:
	return _meshes.get(model, null)


## Each model's instances as laid (PropLayout), by model name: what the views draw.
func placed() -> Dictionary[StringName, PropLayout.Placed]:
	return _placed


## The materials drawn, to warm their shaders before play.
func materials() -> Array[Material]:
	return [_material]


## Draws each prop in its shade and paint times the baked light near it (BakedLightNear.at, LIGHT_LIFT m over its foot), or in
## its shade alone with `lights` null (no bake drawn). Once a switch; nothing to do on a map with no bake.
func relight(lights: BakedLightNear) -> void:
	if lights == null and _lights.is_empty():
		return
	_lights.clear()
	for model: StringName in _views:
		var p := _placed[model]
		var each := PackedColorArray()
		each.resize(p.transforms.size())
		for i in each.size():
			each[i] = lights.at(p.transforms[i].origin + Vector3(0.0, LIGHT_LIFT, 0.0)) if lights != null \
					else Color.WHITE
		if lights != null:
			_lights[model] = each
		var views: Array = _views[model]
		var picks: Array = _picks[model]
		for c in views.size():
			var mm := (views[c] as MultiMeshInstance3D).multimesh
			var pick: PackedInt32Array = picks[c]
			for k in pick.size():
				var shade := p.shades[pick[k]]
				var l := each[pick[k]]
				mm.set_instance_color(k, Color(shade * l.r, shade * l.g, shade * l.b))


## Prop `i` of `model`'s light (PropLayout.Placed order; a linear multiplier of its shade, white with no bake drawn).
func light_of(model: StringName, i: int) -> Color:
	var each: PackedColorArray = _lights.get(model, PackedColorArray())
	return each[i] if i < each.size() else Color.WHITE


## The models some block of `map` is dressed with, the pallet too when a cluster stands on one.
static func _models_used(map: MapData, cfg: PropDressConfig) -> Array[StringName]:
	var used: Array[StringName] = []
	for b in map.blocks:
		if not cfg.dresses(b):
			continue
		var model := cfg.model_of(b)
		if not used.has(model):
			used.append(model)
		if cfg.lay_of(b) == PropDressConfig.Lay.CLUSTER \
				and not used.has(cfg.pallet):
			used.append(cfg.pallet)
	return used


## Whether `model` lines boxes (TILE): their backing is still in the shadow caster, so the model casts none.
static func _tiled(cfg: PropDressConfig, model: StringName) -> bool:
	if cfg.model_lays.get(model, PropDressConfig.Lay.FIT) == PropDressConfig.Lay.TILE:
		return true
	for kind: StringName in cfg.kind_props:
		if cfg.kind_props[kind] == model and cfg.kind_lays.get(kind, PropDressConfig.Lay.FIT) == PropDressConfig.Lay.TILE:
			return true
	return false


func _add(model: StringName, mesh: Mesh, p: PropLayout.Placed, shadow: bool, chunk: float) -> void:
	var cells: Dictionary[Vector2i, PackedInt32Array] = {}
	for i in p.transforms.size():
		var at := p.transforms[i].origin
		var cell := Vector2i(floori(at.x / chunk), floori(at.z / chunk)) if is_finite(chunk) else Vector2i.ZERO
		if not cells.has(cell):
			cells[cell] = PackedInt32Array()
		cells[cell].append(i)
	var views: Array[MultiMeshInstance3D] = []
	var picked: Array[PackedInt32Array] = []
	for cell: Vector2i in cells:
		var picks := cells[cell]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = mesh
		mm.instance_count = picks.size()
		for k in picks.size():
			var shade := p.shades[picks[k]]
			mm.set_instance_transform(k, p.transforms[picks[k]])
			mm.set_instance_color(k, Color(shade, shade, shade))
			mm.set_instance_custom_data(k, p.paints[picks[k]])
		var view := MultiMeshInstance3D.new()
		view.name = "%s_%d_%d" % [String(model).capitalize(), cell.x, cell.y]
		view.multimesh = mm
		view.material_override = _material
		if not shadow:
			view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(view)
		views.append(view)
		picked.append(picks)
	_views[model] = views
	_picks[model] = picked
