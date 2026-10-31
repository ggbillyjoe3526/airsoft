class_name PropDress
extends Node3D
## A site-dressed map's CC0 props (DR2): the drums, barrels, pallets and sofa that stand in the blocks of the kinds
## PropDressConfig dresses, where PropLayout lays them, one MultiMesh a model (the shelving one a chunk,
## PropDressConfig.chunk, so it culls and takes its level of detail by area) in one vertex-coloured material. A
## drum, barrel or sofa casts its own shadow (its box draws nothing, SiteSurface.core_of, and leaves MapLevel's shadow
## caster); shelving casts none, its rack's backing box still does. Scenery only: no collider, no nav cell; the blocks'
## boxes are still what BBs and bodies meet.

var _material: StandardMaterial3D = null
var _views: Dictionary[StringName, Array] = {} # each model's MultiMeshInstance3Ds, a chunk each
var _meshes: Dictionary[StringName, Mesh] = {}
var _placed: Dictionary[StringName, PropLayout.Placed] = {}


## The props of `map` dressed by `cfg`, or null when it dresses none of its blocks. A model that won't load leaves
## its kind's blocks as boxes (with a warning) and its props out.
static func build(map: MapData, cfg: PropDressConfig) -> PropDress:
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
	var placed := PropLayout.layout(map, cfg, boxes)
	if placed.is_empty():
		return null
	var dress := PropDress.new()
	dress.name = "Props"
	dress._material = StandardMaterial3D.new()
	dress._material.vertex_color_use_as_albedo = true
	dress._material.roughness = cfg.roughness
	dress._material.metallic = cfg.metallic
	dress._placed = placed
	dress._meshes = meshes
	for model: StringName in placed:
		var tiled := _tiled(cfg, model)
		dress._add(model, meshes[model], placed[model], not tiled, cfg.chunk if tiled else INF)
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


## The models some block of `map` is dressed with, the pallet too when a cluster stands on one.
static func _models_used(map: MapData, cfg: PropDressConfig) -> Array[StringName]:
	var used: Array[StringName] = []
	for b in map.blocks:
		if not cfg.dresses(b):
			continue
		var model: StringName = cfg.kind_props[b.kind]
		if not used.has(model):
			used.append(model)
		if cfg.kind_lays.get(b.kind, PropDressConfig.Lay.FIT) == PropDressConfig.Lay.CLUSTER \
				and not used.has(cfg.pallet):
			used.append(cfg.pallet)
	return used


## Whether `model` lines boxes (TILE): their backing is still in the shadow caster, so the model casts none.
static func _tiled(cfg: PropDressConfig, model: StringName) -> bool:
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
	for cell: Vector2i in cells:
		var picks := cells[cell]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = picks.size()
		for k in picks.size():
			var shade := p.shades[picks[k]]
			mm.set_instance_transform(k, p.transforms[picks[k]])
			mm.set_instance_color(k, Color(shade, shade, shade))
		var view := MultiMeshInstance3D.new()
		view.name = "%s_%d_%d" % [String(model).capitalize(), cell.x, cell.y]
		view.multimesh = mm
		view.material_override = _material
		if not shadow:
			view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(view)
		views.append(view)
	_views[model] = views
