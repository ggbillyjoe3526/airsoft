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
## Sides of a round part (drums, chimneys, the fuselage, a hill's rings).
@export var sides: int = 12
@export var roughness: float = 0.9

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
## each in one of these greens (far from both teams' hues).
@export var treeline_colours: PackedColorArray = PackedColorArray([
	Color("1c3024"), Color("22382a"), Color("18291f"), Color("2a3a2c"),
])
@export var treeline_spacing: float = 2.4
@export var treeline_jitter: float = 0.35
@export var treeline_low: float = 0.7
@export var treeline_width: float = 0.27
@export var treeline_sides: int = 6
@export var treeline_sink: float = 1.0

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


## The model `kind` is drawn from, or null (not listed, or it won't load: warned once).
func model_of(kind: StringName) -> Mesh:
	if not _tried.has(kind):
		_tried[kind] = true
		var path: String = models.get(kind, "")
		var mesh := PropDressConfig.load_mesh(path)
		if mesh != null:
			_meshes[kind] = mesh
		elif not path.is_empty():
			push_warning("SkylineConfig: %s's model \"%s\" won't load; it keeps its greybox" % [kind, path])
	return _meshes.get(kind, null) as Mesh
