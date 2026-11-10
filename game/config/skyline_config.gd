class_name SkylineConfig
extends Resource
## The skyline round a field (DP3; the browser game's config/dressing.ts `skyline`, `silo`, `hill` and `smoke`): how
## SkylineShapes builds each kind of SkylinePiece in greybox, how SkylineView fades it toward the sky's horizon and
## smokes its chimneys, and where SkylineSight stands to see it. Scenery out of reach; colours are site colours and
## greys only, never near a team's hue (docs/ART.md › Colour and readability).

@export_group("Look")
## A vertex is faded toward the sky's horizon colour from `fade_from` m from the field's middle, reaching `fade_most`
## of the way `fade_span` m further out (by eye on the concept's eye-level picture).
@export var fade_from: float = 25.0
@export var fade_span: float = 140.0
@export var fade_most: float = 0.7
## A treeline's share of that fade (FT1): it stands just past the fence, so a player near it sees it close up; faded as
## far as a horizon piece, then lit by the sun, it read white. As the far wood behind it is (WoodsConfig.forest_fade).
@export var treeline_fade: float = 0.2
## Sides of a round part (drums, chimneys, the fuselage, a hill's rings).
@export var sides: int = 12
@export var roughness: float = 0.9
## How much of the sky its faces mirror at a glancing angle (look_vertex.gdshader's `specular`; FT1): none, so a
## dark treeline seen up its sides from the field's edge stays green rather than mirroring the bright sky white.
@export var specular: float = 0.0

@export_group("Models")
## The kinds drawn from a model (Dev 3 map models, tools/blender/maps/skyline.py) in place of their greybox, each
## stretched to fill its piece (SkylineModels): the model's path. A kind not listed, or one whose model won't load,
## keeps its greybox. Sight (SkylineSight, `hides_of`) reads the greybox either way, so a model changes no row.
@export var models: Dictionary[StringName, String] = {
	&"shed": "res://assets/models/skyline/shed.glb",
	&"crane": "res://assets/models/skyline/crane.glb",
	&"mast": "res://assets/models/skyline/mast.glb",
	&"fuselage": "res://assets/models/skyline/fuselage.glb",
	&"silo": "res://assets/models/skyline/silo.glb",
	&"watchTower": "res://assets/models/skyline/watch_tower.glb",
	&"waterTower": "res://assets/models/skyline/water_tower.glb",
}
## The kinds whose model keeps its own depth, scaled as its length and height are (never past its piece's), so a
## crane's piece, deeper than the crane, doesn't fatten its pillar.
@export var keep_depth: Array[StringName] = [&"crane"]
## More models of a kind at other proportions (a shed's sizes): each piece stands whichever of its kind's models needs
## the least uneven stretch to fill its box (SkylineModels), so doors and windows keep their size. One that won't load
## is left out with a warning.
@export var variants: Dictionary[StringName, PackedStringArray] = {
	&"shed": PackedStringArray(["res://assets/models/skyline/shed_long.glb", "res://assets/models/skyline/shed_deep.glb"]),
}

@export_group("Sight")
## A floor whose top stands this high (m) or higher is a raised floor: its corners, `floor_inset` m in, and its middle
## are stand points.
@export var raised_from: float = 0.3
@export var floor_inset: float = 0.4

@export_group("Shed")
## The walls, the gabled roof (its ridge `roof_rise` of the short side over the eaves, `roof_overhang` m past them), a
## band `band_height` m tall `band_below` m under the eaves and doors `door_width` x `door_height` m every
## `door_every` m on the side facing the field.
@export var shed_colour: Color = Color("52634a")
@export var shed_roof: Color = Color("4a4f57")
@export var shed_band: Color = Color("3f7a6a")
@export var shed_doors: Color = Color("cdb338")
@export var roof_rise: float = 0.15
@export var roof_overhang: float = 0.3
@export var band_height: float = 0.8
@export var band_below: float = 1.2
@export var door_width: float = 5.0
@export var door_height: float = 6.0
@export var door_every: float = 11.0
## How far a band or a door stands proud of its wall (m).
@export var proud: float = 0.08

@export_group("Water tower")
## Four legs `tower_leg` m square under a tank `tank` of the height tall, under a cone roof `tank_roof` of its width.
@export var tank_colour: Color = Color("e8e6e0")
@export var tank_legs: Color = Color("8e949a")
@export var tank_roof_colour: Color = Color("3f7a72")
@export var tank: float = 0.42
@export var tank_roof: float = 0.25
@export var tower_leg: float = 0.4

@export_group("Crane")
## A mast `crane_mast` m square, a jib `crane_jib` m thick along the long side reaching `crane_reach` of it toward the
## field, a counterweight `crane_weight` m on the back end and a hook line `crane_line` m long near the jib's tip.
@export var crane_colour: Color = Color("cdb338")
@export var crane_weight_colour: Color = Color("6f7378")
@export var crane_mast: float = 1.4
@export var crane_jib: float = 0.9
@export var crane_reach: float = 0.7
@export var crane_weight: Vector3 = Vector3(2.5, 2.0, 2.0)
@export var crane_line: float = 6.0

@export_group("Containers")
## A stack of `container_tier` m tiers, each in one of these site colours (no red: it sits too near Beta's hue).
@export var container_colours: PackedColorArray = PackedColorArray([
	Color("6b7a3e"), Color("cdb338"), Color("4f8a57"), Color("7a8288"), Color("3f7a72"),
])
@export var container_tier: float = 2.6

@export_group("Chimney")
## A drum narrowing to `chimney_top` of its width, with `chimney_bands` bands `chimney_band` m tall, the first
## `chimney_band_below` m under the top, `chimney_band_gap` m apart.
@export var chimney_colour: Color = Color("e8e4dc")
@export var chimney_band_colour: Color = Color("6f7378")
@export var chimney_top: float = 0.62
@export var chimney_bands: int = 2
@export var chimney_band: float = 1.2
@export var chimney_band_below: float = 2.0
@export var chimney_band_gap: float = 3.0

@export_group("Silo")
## Drums the short side wide, `silo_gap` m apart, cone roofs `silo_roof` radii tall, a band `silo_band` m tall at
## `silo_band_at` m, a walkway `silo_walkway` m wide over their tops.
@export var silo_colour: Color = Color("d8d6cf")
@export var silo_roof_colour: Color = Color("9aa0a6")
@export var silo_band_colour: Color = Color("6f7378")
@export var silo_walkway_colour: Color = Color("6d737a")
@export var silo_gap: float = 0.8
@export var silo_roof: float = 0.6
@export var silo_band: float = 1.2
@export var silo_band_at: float = 3.0
@export var silo_walkway: float = 1.2

@export_group("Power line")
## Pylons narrowing from `pylon_base` to `pylon_top` m, a cross arm `pylon_arm` m long, and `wires` wires `wire` m
## thick sagging `sag` m in `wire_pieces` pieces a span.
@export var pylon_colour: Color = Color("9aa0a6")
@export var wire_colour: Color = Color("3a3c40")
@export var pylon_base: float = 1.4
@export var pylon_top: float = 0.35
@export var pylon_arm: float = 6.0
@export var wire: float = 0.1
@export var wires: int = 3
@export var sag: float = 2.5
@export var wire_pieces: int = 6

@export_group("Hill")
## A mound in `hill_rings` rings over its footprint.
@export var hill_colour: Color = Color("26362b")
@export var hill_rings: int = 4

@export_group("Treeline")
## A band of dark conifers along a line (WL4; the browser game's DRESSING.treeline): cones `treeline_spacing` m apart
## in rows across its depth, jittered by `treeline_jitter` of the spacing, `treeline_low` to 1 of its height tall,
## `treeline_width` of their height wide (radius) with `treeline_sides` sides, sunk `treeline_sink` m into the ground,
## each in one of these greens (far from both teams' hues), drawn as they are (`treeline_keep`): spruce greens, the
## hue of the field's spruces in the sun (FT1: the old near-black greens, pulled toward grey, read olive-grey).
@export var treeline_colours: PackedColorArray = PackedColorArray([
	Color("2e7a50"), Color("347f4a"), Color("3f8a4c"), Color("2e7a50"),
])
@export var treeline_spacing: float = 2.4
@export var treeline_jitter: float = 0.35
@export var treeline_low: float = 0.7
@export var treeline_width: float = 0.27
@export var treeline_sides: int = 6
@export var treeline_sink: float = 1.0
## How much of its own colour a treeline keeps against the look's pull toward grey (LookConfig.paint_saturation; FT1):
## all of it. Pulled to the look's share, its greens lit by the warm sun read olive-grey from the fence. Every other
## piece takes the look's pull.
@export_range(0.0, 1.0) var treeline_keep: float = 1.0
## The band drawn from a model (Dev 3, WT1, tools/blender/maps/far_tree.py) in place of the cones: a section of two
## rows of stepped spruces `treeline_section` m long (x) and deep (y), its top the tallest spire, laid end to end along
## each run of the line (whole sections, each stretched to an even share), every other one mirrored, each in one of
## `treeline_colours`. Empty, or a model that won't load, keeps the cones.
@export var treeline_model: String = "res://assets/models/skyline/treeline.glb"
@export var treeline_section: Vector2 = Vector2(20.0, 5.0)
## So the band never reads as one section repeated (WS1, the owner: the far trees stood too neatly): each section is a
## seeded one of the model and these variants (their own trees, heights and gaps; a variant that won't load is left
## out), as tall as a seeded `treeline_rise` share of the piece's height (x to y), and standing a seeded up to
## `treeline_shift` m off its line either way, across it.
@export var treeline_variants: PackedStringArray = PackedStringArray([
	"res://assets/models/skyline/treeline_b.glb", "res://assets/models/skyline/treeline_c.glb",
	"res://assets/models/skyline/treeline_d.glb",
])
@export var treeline_rise: Vector2 = Vector2(0.82, 1.0)
@export var treeline_shift: float = 0.9

@export_group("Watch tower")
## A concrete column `watch_column` of the width wide up to a deck `watch_deck` m thick, a parapet `watch_parapet` m
## tall, corner posts and a roof `watch_roof` m thick over a cabin `watch_cabin` m tall.
@export var watch_colour: Color = Color("b8b2a6")
@export var watch_roof_colour: Color = Color("545c45")
@export var watch_column: float = 0.7
@export var watch_deck: float = 0.4
@export var watch_parapet: float = 1.1
@export var watch_cabin: float = 2.6
@export var watch_roof: float = 0.4
@export var watch_post: float = 0.25

@export_group("Fuselage")
## An airliner's body lying along its long side on `fuselage_cradle` m blocks, the short side its width; the tail fin
## reaches the piece's height. A window stripe, a nose `fuselage_nose` radii long, a tail cone `fuselage_tail` radii
## long, wing stubs `fuselage_wing` m out from the body.
@export var fuselage_colour: Color = Color("d6d6d0")
@export var fuselage_trim: Color = Color("6f7378")
@export var fuselage_cradle: float = 1.0
@export var fuselage_nose: float = 1.2
@export var fuselage_tail: float = 2.2
@export var fuselage_wing: float = 3.5
@export var fuselage_fin: float = 3.0

@export_group("Mast")
## A floodlight mast: a pole `mast_pole` m square, a head bar the piece's width facing the field with `mast_lamps`
## lamps, which glow `mast_lamp_glow` at `mast_lamp_energy` at night (self-lit through the haze, no real light;
## yellow-white as the lanterns, off Beta's hue).
@export var mast_colour: Color = Color("8a9096")
@export var mast_head_colour: Color = Color("3a3e46")
@export var mast_lamp_colour: Color = Color("d6d6d0")
@export var mast_lamp_glow: Color = Color8(255, 238, 200)
@export var mast_lamp_energy: float = 3.0
@export var mast_pole: float = 0.35
@export var mast_head: float = 0.9
@export var mast_lamps: int = 4

@export_group("Smoke")
## Each smoking chimney's puffs: `smoke_puffs` on a loop `smoke_life` s long, rising `smoke_rise` m, spreading
## `smoke_spread` degrees, growing from `smoke_size_from` to `smoke_size_to` m and fading out; the wind bends them
## (`smoke_wind_share` of the match's wind, at least `smoke_breeze` m/s along x), followed every `smoke_refresh` s.
## `smoke_night` darkens them under a night light. Drawn from Medium; frozen under Reduced motion.
@export var smoke_puffs: int = 14
@export var smoke_life: float = 9.0
@export var smoke_rise: float = 16.0
@export var smoke_spread: float = 8.0
@export var smoke_size_from: float = 2.2
@export var smoke_size_to: float = 6.0
@export var smoke_opacity: float = 0.55
@export var smoke_fade_in: float = 0.08
@export var smoke_colour: Color = Color("ece9e3")
@export var smoke_night: float = 0.35
@export var smoke_wind_share: float = 0.6
@export var smoke_breeze: float = 0.5
@export var smoke_refresh: float = 0.5

var _meshes: Dictionary[StringName, Mesh] = {}
var _tried: Dictionary[StringName, bool] = {}
var _all: Dictionary[StringName, Array] = {}


## The model `kind` is drawn from, or null (not listed, or it won't load: warned once).
func model_of(kind: StringName) -> Mesh:
	if not _tried.has(kind):
		_tried[kind] = true
		var path: String = models.get(kind, "")
		var mesh := _load(kind, path)
		if mesh != null:
			_meshes[kind] = mesh
	return _meshes.get(kind, null) as Mesh


## Every model `kind` may be drawn from: its own (model_of) first, then its `variants` that load; none without its own.
func models_of(kind: StringName) -> Array[Mesh]:
	if not _all.has(kind):
		var out: Array[Mesh] = []
		var own := model_of(kind)
		if own != null:
			out.append(own)
			for path: String in variants.get(kind, PackedStringArray()):
				var mesh := _load(kind, path)
				if mesh != null:
					out.append(mesh)
		_all[kind] = out
	var list: Array[Mesh] = []
	list.assign(_all[kind])
	return list


## The treeline band's section (treeline_model), or null (none, or it won't load: warned once).
func treeline_mesh() -> Mesh:
	if not _tried.has(&"treeline"):
		_tried[&"treeline"] = true
		var mesh := _load(&"treeline", treeline_model)
		if mesh != null:
			_meshes[&"treeline"] = mesh
	return _meshes.get(&"treeline", null) as Mesh


## The band's sections: treeline_mesh first, then each of treeline_variants that loads (empty without the model).
func treeline_meshes() -> Array[Mesh]:
	var out: Array[Mesh] = []
	var main := treeline_mesh()
	if main == null:
		return out
	out.append(main)
	for i in treeline_variants.size():
		var kind := StringName("treeline_%d" % i)
		if not _tried.has(kind):
			_tried[kind] = true
			var mesh := _load(kind, treeline_variants[i])
			if mesh != null:
				_meshes[kind] = mesh
		if _meshes.has(kind):
			out.append(_meshes[kind])
	return out


## The mesh at `path` if it loads as a skyline model (one indexed surface with vertex colours), else null, warned.
func _load(kind: StringName, path: String) -> Mesh:
	if path.is_empty():
		return null
	var mesh := PropDressConfig.load_mesh(path)
	if mesh != null and mesh.get_surface_count() > 0:
		var arrays := mesh.surface_get_arrays(0)
		if arrays[Mesh.ARRAY_COLOR] != null and arrays[Mesh.ARRAY_INDEX] != null:
			var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			if colours.size() == verts.size():
				return mesh
	push_warning("SkylineConfig: %s's model \"%s\" won't load; it is left out" % [kind, path])
	return null
