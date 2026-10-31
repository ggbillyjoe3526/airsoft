class_name PropDress
extends Node3D
## A site-dressed map's CC0 props (DR2): the drums, barrels, pallets and sofa that stand in the blocks of the kinds
## PropDressConfig dresses, where PropLayout lays them, one MultiMesh a model in one vertex-coloured material. A
## drum, barrel or sofa casts its own shadow (its box draws nothing, SiteSurface.core_of, and leaves MapLevel's shadow
## caster); shelving casts none, its rack's backing box still does. Scenery only: no collider, no nav cell; the blocks'
## boxes are still what BBs and bodies meet.

var _material: StandardMaterial3D = null
var _views: Dictionary[StringName, MultiMeshInstance3D] = {}
var _placed: Dictionary[StringName, PropLayout.Placed] = {}


## The props of `map` dressed by `cfg`, or null when it dresses none of its blocks. A model that won't load leaves
## its kind's blocks as boxes (with a warning) and its props out.
static func build(map: MapData, cfg: PropDressConfig) -> PropDress:
	if map == null or cfg == null:
		return null
	var meshes: Dictionary[StringName, Mesh] = {}
	var boxes: Dictionary[StringName, AABB] = {}
	for model: StringName in _models_used(map, cfg):
		var mesh := load_mesh(cfg.models.get(model, ""))
		if mesh == null:
			push_warning("PropDress: %s's model %s won't load; its blocks stay boxes" % [model,
					cfg.models.get(model, "(none)")])
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
	for model: StringName in placed:
		dress._add(model, meshes[model], placed[model], not _tiled(cfg, model))
	return dress


## The first mesh of the model at `path` (a .glb scene), or null.
static func load_mesh(path: String) -> Mesh:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var root := scene.instantiate()
	var found := root.find_children("*", "MeshInstance3D", true, false)
	var mesh: Mesh = (found[0] as MeshInstance3D).mesh if not found.is_empty() else null
	root.free()
	return mesh


## Each model's view, by model name.
func views() -> Dictionary[StringName, MultiMeshInstance3D]:
	return _views


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


func _add(model: StringName, mesh: Mesh, p: PropLayout.Placed, shadow: bool) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = p.transforms.size()
	for i in p.transforms.size():
		mm.set_instance_transform(i, p.transforms[i])
		mm.set_instance_color(i, Color(p.shades[i], p.shades[i], p.shades[i]))
	var view := MultiMeshInstance3D.new()
	view.name = String(model).capitalize()
	view.multimesh = mm
	view.material_override = _material
	if not shadow:
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(view)
	_views[model] = view
