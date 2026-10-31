class_name PropDressConfig
extends Resource
## A site's CC0 props (DR2): which block kinds are drawn as models instead of their box, and how the models are laid
## in the box. Each prop fills its block's box (never past it), so cover, collision and the nav grid stay the box's;
## the box's own faces are not drawn (SiteSurface.core_of). The models are Kenney's (CC0), recoloured off the teams'
## hues by tools/props/build_props.py into assets/models/props/ (docs/ASSETS.md).

## How a kind's props are laid: ROW stands round props upright side by side along the box's long side, as many as fit
## at its short side's width; CLUSTER stands them on a pallet in a grid of cells about `cluster_cell` m across; FIT
## stretches one model to the whole box, its front to the field's middle; TILE lines the box's faces with rows of the
## model as tall as the box, each facing out (`tile_depths`), over a dark backing.
enum Lay { ROW, CLUSTER, FIT, TILE }

## Each prop's model (a .glb of one vertex-coloured mesh).
@export var models: Dictionary[StringName, String] = {
	&"barrel": "res://assets/models/props/barrel.glb",
	&"drum": "res://assets/models/props/drum.glb",
	&"pallet": "res://assets/models/props/pallet.glb",
	&"sofa": "res://assets/models/props/sofa.glb",
	&"shelf": "res://assets/models/props/shelf.glb",
}
## Each dressed block kind's prop, and how it is laid. A kind not listed keeps its box.
@export var kind_props: Dictionary[StringName, StringName] = {
	&"barrel": &"barrel", &"drum": &"drum", &"sofa": &"sofa", &"rack": &"shelf",
}
@export var kind_lays: Dictionary[StringName, Lay] = {
	&"barrel": Lay.ROW, &"drum": Lay.CLUSTER, &"sofa": Lay.FIT, &"rack": Lay.TILE,
}
## A dressed kind's block lower than this (m) keeps its box: a rack's shelf boards stay boards, its racking is
## shelving.
@export var kind_min_height: Dictionary[StringName, float] = {&"rack": 2.0}
## A cluster's cell (m, about) and the pallet's height under it (m; `pallet` is its model).
@export var cluster_cell: float = 0.9
@export var pallet_height: float = 0.15
@export var pallet: StringName = &"pallet"
## TILE lines a box's faces with rows of props, each row `tile_skin` m deep at most (half the box's depth across it
## at most), on every face at least `tile_min_face` m long (a row along x runs the whole face; one along z stops
## short of the x rows at its ends). The box itself is drawn half a row inside each lined face, and `backing_top`
## under its top, in a dark backing (SiteLook's `backing` finish): the props' fronts stand proud of it and nothing is
## seen through them that the box would stop.
@export var tile_skin: float = 0.9
@export var tile_min_face: float = 1.5
@export var backing_top: float = 0.05
## A round prop's turn about its axis is a random quarter (seeded by the map's dressing seed), and its shade varies
## this much either way, so a row never reads as one model repeated.
@export var shade_jitter: float = 0.06
## Tiled props (the shelving, most of the props' triangles) are drawn in square chunks this many m across, one
## MultiMesh a chunk, so the camera culls the chunks off screen and each takes its own mesh level of detail (the Mesh
## detail step's mesh_lod_threshold, GraphicsApply; the simpler meshes are generated on import). The other models are
## one MultiMesh each, few draw calls for few triangles.
@export var chunk: float = 20.0
## The props' material: roughness, and metalness.
@export var roughness: float = 0.7
@export var metallic: float = 0.0

## Each model path's mesh as loaded (null when it won't load), so a kind is dressed only by a model that loads.
var _meshes: Dictionary[String, Mesh] = {}


## Whether block `b` is drawn as props: its kind has a prop whose model loads and it is tall enough (else it keeps
## its box).
func dresses(b: MapData.Block) -> bool:
	var model: StringName = kind_props.get(b.kind, &"")
	return model != &"" and b.size.y >= kind_min_height.get(b.kind, 0.0) and mesh_of(model) != null


## Prop `model`'s mesh, or null when its model is missing or holds none (loaded once a path).
func mesh_of(model: StringName) -> Mesh:
	var path: String = models.get(model, "")
	if not _meshes.has(path):
		_meshes[path] = load_mesh(path)
		if _meshes[path] == null:
			push_warning("PropDressConfig: %s's model %s won't load; its blocks stay boxes" % [model, path])
	return _meshes[path]


## The first mesh of the model at `path` (a .glb scene), or null.
static func load_mesh(path: String) -> Mesh:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var root := scene.instantiate()
	if root == null:
		return null
	var found := root.find_children("*", "MeshInstance3D", true, false)
	var mesh: Mesh = (found[0] as MeshInstance3D).mesh if not found.is_empty() else null
	root.free()
	return mesh


## Whether block `b` is drawn as props laid by TILE, with its backing behind them.
func backs(b: MapData.Block) -> bool:
	return kind_lays.get(b.kind, Lay.FIT) == Lay.TILE and dresses(b)


## The depth (m) of TILE's rows on block `b`'s faces: x for the rows along x (on its two faces across z), y for the
## rows along z; 0 where a face is too short for a row.
func tile_depths(b: MapData.Block) -> Vector2:
	var along_x := minf(tile_skin, b.size.z * 0.5) if b.size.x >= tile_min_face else 0.0
	var along_z := minf(tile_skin, b.size.x * 0.5) if b.size.z - 2.0 * along_x >= tile_min_face else 0.0
	return Vector2(along_x, along_z)
