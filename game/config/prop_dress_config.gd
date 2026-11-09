class_name PropDressConfig
extends Resource
## A field's props (DR2, WR3, RK1): which blocks are drawn as models instead of their box (Depot's by kind, Woodland's
## by the prop each block names, MapData.Block.dress), and how the models are laid in the box. Each prop fills its
## block's box (never past it), so cover and the nav grid stay the box's and collision the box's (a round prop's,
## its stepped boxes that hug it: MapStyle.round_steps, RoundSteps); the box's own faces are not
## drawn (SiteSurface.core_of). Most models are Kenney's (CC0), recoloured off the teams' hues by
## tools/props/build_props.py into assets/models/props/; Depot's and the Range's racking, drums, pallet, barrel, sofa,
## desk, lockers and kit rack are built in Blender by tools/blender/maps/ (RK1), the same one vertex-coloured mesh
## each (docs/ASSETS.md).

## How a kind's props are laid: ROW stands round props upright side by side along the box's long side, as many as fit
## at its short side's width; CLUSTER stands them on a pallet in a grid of cells about `cluster_cell` m across; FIT
## stretches one model to the whole box, its front to the field's middle; TILE lines the box's faces with rows of the
## model as tall as the box, each facing out (`tile_depths`), over a dark backing; GRID fills the box with the model
## in cells about `grid_cells` m across (x along the box's long side, y up, z across it), stacked, each stretched to
## its cell, the model's z across the box (WR3); BAY lines a wall's box with the model in cells on a grid of the
## world (`bay_pitch` m apart from `bay_anchor`), each stretched to its cell and its front (+z) to the field's middle,
## a feature bay (`bay_features`) in some cells with nothing standing in front of them (Dev 3: Depot's hall walls,
## their columns under the roof's trusses); TREE stands one tree in the box (Dev 3, WT1: Woodland's pines, oaks and
## birches): the model's origin on the ground under the box's middle, its trunk's foot (`tree_feet` m round its
## origin) stretched to the box's half-width and the tree's top to the box's top, turned a random quarter; its crown
## (`tree_crowns`, a model of its own) scaled evenly by the tree's height over it, so it keeps its shape however the
## box is proportioned, spreading past the box over head height, look only, as the cone crowns WoodsView drew before.
enum Lay { ROW, CLUSTER, FIT, TILE, GRID, BAY, TREE }

## Each prop's model (a .glb of one vertex-coloured mesh).
@export var models: Dictionary[StringName, String] = {
	# Depot's and the Range's, built in Blender (RK1): plastic barrels, two steel drums stacked, the pallet under them,
	# the Lounge's sofa, a bay of pallet racking, the Offices' desks and lockers, the Range's kit rack.
	&"barrel": "res://assets/models/props/plastic_barrel.glb",
	&"drum": "res://assets/models/props/steel_drum.glb",
	&"pallet": "res://assets/models/props/pallet.glb",
	&"sofa": "res://assets/models/props/sofa.glb",
	&"shelf": "res://assets/models/props/pallet_racking.glb",
	&"shelf_b": "res://assets/models/props/pallet_racking_b.glb",
	&"shelf_c": "res://assets/models/props/pallet_racking_c.glb",
	&"desk": "res://assets/models/props/office_desk.glb",
	&"locker": "res://assets/models/props/steel_locker.glb",
	&"kit_rack": "res://assets/models/props/kit_rack.glb",
	&"trunk": "res://assets/models/props/trunk.glb",
	&"log": "res://assets/models/props/log.glb",
	&"logstack": "res://assets/models/props/logstack.glb",
	&"pine": "res://assets/models/props/pine.glb",
	&"tyre": "res://assets/models/props/tyre.glb",
	&"crate": "res://assets/models/props/crate.glb",
	&"truck": "res://assets/models/props/truck.glb",
	# The Street's (ST2).
	&"car_crimson": "res://assets/models/props/car_crimson.glb",
	&"car_teal": "res://assets/models/props/car_teal.glb",
	&"car_cream": "res://assets/models/props/car_cream.glb",
	&"car_lilac": "res://assets/models/props/car_lilac.glb",
	&"car_yellow": "res://assets/models/props/car_yellow.glb",
	&"car_green": "res://assets/models/props/car_green.glb",
	&"car_grey": "res://assets/models/props/car_grey.glb",
	&"van_cream": "res://assets/models/props/van_cream.glb",
	&"van_plaster": "res://assets/models/props/van_plaster.glb",
	&"van_teal": "res://assets/models/props/van_teal.glb",
	&"van_grey": "res://assets/models/props/van_grey.glb",
	&"lorry_crimson": "res://assets/models/props/lorry_crimson.glb",
	&"lorry_teal": "res://assets/models/props/lorry_teal.glb",
	&"lorry_cream": "res://assets/models/props/lorry_cream.glb",
	&"bin_green": "res://assets/models/props/bin_green.glb",
	&"bin_steel": "res://assets/models/props/bin_steel.glb",
	&"bin_teal": "res://assets/models/props/bin_teal.glb",
	&"skip": "res://assets/models/props/skip.glb",
	&"lamp": "res://assets/models/props/lamp.glb",
	&"settee": "res://assets/models/props/settee.glb",
	&"table": "res://assets/models/props/table.glb",
	&"units": "res://assets/models/props/units.glb",
	&"fridge": "res://assets/models/props/fridge.glb",
	# Depot's hall shell (Dev 3, tools/blender/maps/): the walls' bays, its pillars and its camouflage nets.
	&"hall_wall": "res://assets/models/props/hall_wall.glb",
	&"hall_shutter": "res://assets/models/props/hall_shutter.glb",
	&"hall_exit": "res://assets/models/props/hall_exit.glb",
	&"pillar": "res://assets/models/props/pillar.glb",
	&"camo_net": "res://assets/models/props/camo_net.glb",
	# Woodland's trees (Dev 3, WT1, tools/blender/maps/): the pine's three ages, the oak and the birch, each block of
	# kind tree naming one, its trunk and its crown apart (tree_crowns); and the thickets' spruce.
	&"pine_young": "res://assets/models/props/pine_young.glb",
	&"pine_grown": "res://assets/models/props/pine_grown.glb",
	&"pine_old": "res://assets/models/props/pine_old.glb",
	&"oak": "res://assets/models/props/oak.glb",
	&"birch": "res://assets/models/props/birch.glb",
	&"pine_young_crown": "res://assets/models/props/pine_young_crown.glb",
	&"pine_grown_crown": "res://assets/models/props/pine_grown_crown.glb",
	&"pine_old_crown": "res://assets/models/props/pine_old_crown.glb",
	&"oak_crown": "res://assets/models/props/oak_crown.glb",
	&"birch_crown": "res://assets/models/props/birch_crown.glb",
	&"spruce": "res://assets/models/props/spruce.glb",
}
## Each dressed block kind's prop, and how it is laid. A kind not listed keeps its box.
@export var kind_props: Dictionary[StringName, StringName] = {
	&"barrel": &"barrel", &"drum": &"drum", &"sofa": &"sofa", &"rack": &"shelf",
	&"wall": &"hall_wall", &"pillar": &"pillar", &"net": &"camo_net",
}
@export var kind_lays: Dictionary[StringName, Lay] = {
	&"barrel": Lay.ROW, &"drum": Lay.CLUSTER, &"sofa": Lay.FIT, &"rack": Lay.TILE,
	&"wall": Lay.BAY, &"pillar": Lay.FIT, &"net": Lay.GRID,
}
## Other models a lining model (TILE) takes turns with, place by place along a rack, never the same twice in a row,
## so a long rack wall never reads as one bay repeated (the owner, 2026-11-09: the racking loaded three ways; five drew
## three times the hall's draws on Low). Each is in `models`, the same size as the model it stands in for. Their chunks
## are `many_chunk` across, so the bays together take about the draws one model did in `chunk` ones.
@export var variants: Dictionary[StringName, PackedStringArray] = {
	&"shelf": PackedStringArray(["shelf_b", "shelf_c"]),
}
## How a prop a block names (MapData.Block.dress, WR3) is laid in it; one not listed is fitted to the box (FIT, long
## side along the box's).
@export var model_lays: Dictionary[StringName, Lay] = {
	&"logstack": Lay.GRID, &"crate": Lay.GRID, &"tyre": Lay.GRID, &"pine": Lay.GRID, &"spruce": Lay.GRID,
	&"pine_young": Lay.TREE, &"pine_grown": Lay.TREE, &"pine_old": Lay.TREE, &"oak": Lay.TREE, &"birch": Lay.TREE,
	&"bin_green": Lay.GRID, &"bin_steel": Lay.GRID, &"bin_teal": Lay.GRID, &"units": Lay.GRID,
}
## GRID's cells (m): x along the box's long side, y up (0: one layer the box's height), z across. Cordwood a metre and
## a half long a stack, crates about a metre, tyres in stacks, a spruce every metre and a half; The Street's bins side
## by side, about 0.7 m each, and its kitchen units about 0.6 m a cupboard.
@export var grid_cells: Dictionary[StringName, Vector3] = {
	&"logstack": Vector3(1.6, 0.9, 1.4), &"crate": Vector3(0.9, 0.9, 1.0), &"tyre": Vector3(0.9, 0.45, 0.9),
	&"pine": Vector3(1.5, 0.0, 1.5), &"spruce": Vector3(1.5, 0.0, 1.5),
	&"bin_green": Vector3(0.7, 0.0, 0.7), &"bin_steel": Vector3(0.7, 0.0, 0.7), &"bin_teal": Vector3(0.7, 0.0, 0.7),
	&"units": Vector3(0.6, 0.0, 0.6),
	# a camouflage net's scaffold sections, a pole every 2 m
	&"camo_net": Vector3(2.0, 0.0, 0.3),
}
## GRID models laid all one way round, never turned at random: a net wall's sections match only edge to edge as
## modelled (DH1).
@export var grid_unturned: PackedStringArray = PackedStringArray(["camo_net"])
## A named prop whose box is still drawn behind it, cut down to a share (y) of its height and inset (x, m, at most a
## fifth of the box's width) on each side with no other such box against it, rather than not at all: a thicket's dark
## core between its spruces, unbroken across touching thickets, so nothing is seen through a thicket that stops BBs
## and sight below the tops of its trees.
@export var model_cores: Dictionary[StringName, Vector2] = {&"pine": Vector2(0.7, 0.6), &"spruce": Vector2(0.7, 0.6)}
## TREE's models: each one's trunk's widest reach (m) round its origin at the ground and under it (an oak's buttress
## roots), which the box's half-width is; as each build script prints it (tools/blender/maps/pine.py, oak.py,
## birch.py). A tree model not listed keeps its box.
@export var tree_feet: Dictionary[StringName, float] = {
	&"pine_young": 0.2, &"pine_grown": 0.33, &"pine_old": 0.42, &"oak": 0.85, &"birch": 0.17,
}
## Each TREE model's crown (its limbs and leaves, written apart by the build script): laid over the trunk scaled evenly
## by the tree's height (PropLayout.crown_fit). A tree without one is all trunk.
@export var tree_crowns: Dictionary[StringName, StringName] = {
	&"pine_young": &"pine_young_crown", &"pine_grown": &"pine_grown_crown", &"pine_old": &"pine_old_crown",
	&"oak": &"oak_crown", &"birch": &"birch_crown",
}
## A dressed kind's block lower than this (m) keeps its box: a rack's shelf boards stay boards, its racking is
## shelving; only a hall's 8 m walls are its bays (the Range's and The Street's lower walls keep their boxes).
@export var kind_min_height: Dictionary[StringName, float] = {&"rack": 2.0, &"wall": 6.0}
## BAY's cells (m) by model: their edges at `bay_anchor` plus whole `bay_pitch`es along the world's x (anchor x) or z
## (anchor y), a wall's end cell shorter than half a pitch joined to the next. Depot's hall: the roof's trusses stand
## every RoofConfig.truss_step m along x from 0, so a long wall's columns stand under them; the end walls' bays run
## from their corners.
@export var bay_pitch: Dictionary[StringName, float] = {&"hall_wall": 8.0}
@export var bay_anchor: Dictionary[StringName, Vector2] = {&"hall_wall": Vector2(0.0, 4.0)}
## A bay model's feature bays, taken in turn, at most `bay_feature_most` a wall, never side by side, each in a whole
## cell with no block standing within `bay_clear` m of its face below `bay_clear_height` m (a door behind a stack of
## crates would make no sense).
@export var bay_features: Dictionary[StringName, PackedStringArray] = {
	&"hall_wall": PackedStringArray(["hall_shutter", "hall_exit"]),
}
@export var bay_feature_most: int = 2
@export var bay_clear: float = 2.0
@export var bay_clear_height: float = 3.0
## A cluster's cell (m, about) and the pallet's height under it (m; `pallet` is its model). A drum block's 1.8 m
## pallet holds three by three stacks of two steel drums (RK1).
@export var cluster_cell: float = 0.6
## The share of its cell a cluster's prop is wide: a drum stack 0.53 m in its 0.6 m cell, a real drum's proportions at
## the block's height (RK1; RoundSteps steps them the same).
@export var cluster_fill: float = 0.887
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
## A model laid this many times or more is chunked too (Woodland's trunks, spruces and cordwood, WR3), in squares
## `many_chunk` m across, so a field's worth of it culls by area; fewer are one MultiMesh. Twice the shelving's chunk
## (BP7): Woodland's props drew 167 of a High frame's 445 draws in 20 m chunks, 93 in 40 m ones.
@export var chunk_from: int = 64
@export var many_chunk: float = 40.0
## Models chunked as `many_chunk` however few are laid: spread round a field's edge (Depot's hall walls, DH1) or
## heavy and spread over it (Woodland's oaks and birches, WT1), one MultiMesh would draw them all wherever you look.
@export var spread_models: PackedStringArray = PackedStringArray(["hall_wall", "camo_net", "oak", "oak_crown", "birch",
		"birch_crown"])
## The props' material: roughness, and metalness.
@export var roughness: float = 0.7
@export var metallic: float = 0.0
## Models drawn rougher or smoother than `roughness` (each roughness its own material): Woodland's trees' foliage is
## matt, so its soft crown normals never shine like plastic (WT1).
@export var model_roughness: Dictionary[StringName, float] = {
	&"pine_young": 0.95, &"pine_grown": 0.95, &"pine_old": 0.95, &"oak": 0.95, &"birch": 0.95, &"spruce": 0.95,
	&"pine_young_crown": 0.95, &"pine_grown_crown": 0.95, &"pine_old_crown": 0.95, &"oak_crown": 0.95,
	&"birch_crown": 0.95,
}

## Each model path's mesh as loaded (null when it won't load), so a kind is dressed only by a model that loads.
var _meshes: Dictionary[String, Mesh] = {}


## Whether block `b` is drawn as props: the prop it names, or else its kind's, has a model that loads (a tree's with
## its foot's reach), the kind's is tall enough, and the block is no ramp (else it keeps its box).
func dresses(b: MapData.Block) -> bool:
	if b.rise != MapData.Rise.NONE:
		return false
	if b.dress != &"":
		# a tree model is laid only with its foot's reach (tree_feet)
		var tree_ok: bool = model_lays.get(b.dress, Lay.FIT) != Lay.TREE or tree_feet.has(b.dress)
		return tree_ok and mesh_of(b.dress) != null
	var model: StringName = kind_props.get(b.kind, &"")
	return model != &"" and b.size.y >= kind_min_height.get(b.kind, 0.0) and mesh_of(model) != null


## Whether `model` is part of a tree (Lay.TREE's trunk, or its crown): stood by its origin on the ground, its crown
## spreading past its box over head height.
func is_tree_part(model: StringName) -> bool:
	return model_lays.get(model, Lay.FIT) == Lay.TREE or tree_crowns.values().has(model)


## `model` and the variants it takes turns with (`variants`), those with a model.
func variants_of(model: StringName) -> Array[StringName]:
	var out: Array[StringName] = [model]
	for v: String in variants.get(model, PackedStringArray()):
		if models.has(StringName(v)):
			out.append(StringName(v))
	return out


## The prop block `b` is drawn as: the one it names (MapData.Block.dress), else its kind's; empty for none.
func model_of(b: MapData.Block) -> StringName:
	return b.dress if b.dress != &"" else kind_props.get(b.kind, &"")


## How block `b`'s props are laid: its named prop's lay (FIT unless model_lays says), else its kind's.
func lay_of(b: MapData.Block) -> Lay:
	if b.dress != &"":
		return model_lays.get(b.dress, Lay.FIT)
	return kind_lays.get(b.kind, Lay.FIT)


## Where block `b`'s box is still drawn behind its props (model_cores): (side inset m, share of its height), or zero
## when it isn't drawn at all.
func core_of(b: MapData.Block) -> Vector2:
	return model_cores.get(b.dress, Vector2.ZERO) if b.dress != &"" and dresses(b) else Vector2.ZERO


## Prop `model`'s mesh, or null when its model is missing or holds none (loaded once a path).
func mesh_of(model: StringName) -> Mesh:
	var path: String = models.get(model, "")
	if not _meshes.has(path):
		_meshes[path] = load_mesh(path)
		if _meshes[path] == null:
			push_warning("PropDressConfig: %s's model \"%s\" won't load; its blocks stay boxes" % [model, path])
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
	return lay_of(b) == Lay.TILE and dresses(b)


## The depth (m) of TILE's rows on block `b`'s faces: x for the rows along x (on its two faces across z), y for the
## rows along z; 0 where a face is too short for a row.
func tile_depths(b: MapData.Block) -> Vector2:
	var along_x := minf(tile_skin, b.size.z * 0.5) if b.size.x >= tile_min_face else 0.0
	var along_z := minf(tile_skin, b.size.x * 0.5) if b.size.z - 2.0 * along_x >= tile_min_face else 0.0
	return Vector2(along_x, along_z)
