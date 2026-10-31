class_name MapStyle
extends Resource
## How a map's blocks are drawn and what they are made of, by block kind (the browser game's config/materials.ts for the
## surfaces; the colours follow docs/ART.md: warm concrete and cream for the field, site colours on containers and
## plant, plywood for crates and port walls, dull timber for Woodland's trees, logs and fence, never a team colour).
## Read by MapData (surfaces) and MapLevel (the greybox). A block's own `surface` in the map data wins over its kind's,
## and a surface with a colour of its own (gravel) is drawn in it. Sloping ground (TerrainGrid) is drawn in its
## surfaces' `terrain_colours`.

## What a BB or a footstep meets on each kind (RayHit.Surface). Moulded plastic ticks hollow, nearest to wood;
## sand-filled bags and gabions soak BBs up like wood. Kinds not listed are concrete.
@export var surfaces: Dictionary[StringName, int] = {
	&"floor": RayHit.Surface.CONCRETE,
	&"ramp": RayHit.Surface.CONCRETE,
	&"wall": RayHit.Surface.CONCRETE,
	&"barrier": RayHit.Surface.CONCRETE,
	&"crate": RayHit.Surface.WOOD,
	&"container": RayHit.Surface.METAL,
	&"toilet": RayHit.Surface.WOOD,
	&"rack": RayHit.Surface.WOOD,
	&"gabion": RayHit.Surface.WOOD,
	&"wrapped": RayHit.Surface.WOOD,
	&"ibc": RayHit.Surface.METAL,
	&"sandbags": RayHit.Surface.WOOD,
	&"generator": RayHit.Surface.METAL,
	&"skip": RayHit.Surface.METAL,
	&"plywood": RayHit.Surface.WOOD,
	&"tree": RayHit.Surface.WOOD,
	&"log": RayHit.Surface.WOOD,
	&"fence": RayHit.Surface.WOOD,
	# Depot's warehouse (DR1): fibre drums and the sofa soak BBs up like wood, steel barrels and pillars ring, and the
	# netting's fine mesh stops a BB dead, nearest to wood.
	&"drum": RayHit.Surface.WOOD,
	&"barrel": RayHit.Surface.METAL,
	&"pillar": RayHit.Surface.METAL,
	&"net": RayHit.Surface.WOOD,
	&"sofa": RayHit.Surface.WOOD,
	# Woodland's concept 3 (WR1): rubber tyres soak BBs up like wood, the pickup rings, a spruce thicket is leaves.
	&"tyre": RayHit.Surface.WOOD,
	&"truck": RayHit.Surface.METAL,
	&"thicket": RayHit.Surface.LEAVES,
}
## Each kind's greybox colour (sRGB). Kinds not listed take `default_colour`.
@export var colours: Dictionary[StringName, Color] = {
	&"floor": Color8(0xb9, 0xb4, 0xae),
	&"ramp": Color8(0xb9, 0xb4, 0xae),
	&"wall": Color8(0xd2, 0xce, 0xc8),
	&"barrier": Color(0.74, 0.72, 0.67),
	&"crate": Color8(0xc2, 0xb6, 0x98),
	&"toilet": Color(0.32, 0.55, 0.40),
	&"rack": Color(0.54, 0.49, 0.36),
	&"gabion": Color(0.56, 0.55, 0.51),
	&"wrapped": Color(0.86, 0.86, 0.83),
	&"ibc": Color(0.89, 0.89, 0.85),
	&"sandbags": Color(0.71, 0.64, 0.47),
	&"generator": Color(0.81, 0.70, 0.20),
	&"skip": Color(0.81, 0.70, 0.20),
	&"plywood": Color8(0xdc, 0xca, 0xa8),
	# Woodland's timber, from the look's palette (LookConfig, WA1) and dull (HSL saturation under 0.3 on linear RGB) so
	# none reads as a team: bark, weathered logs and fence boards in timber.
	&"tree": Color8(0x7b, 0x6f, 0x62),
	&"log": Color8(0xa0, 0x94, 0x7c),
	&"fence": Color8(0xa0, 0x94, 0x7c),
	# Depot's warehouse (DR1), off both team hues: tan fibre drums, olive-grey steel barrels, raspberry steel pillars,
	# teal netting, a plum sofa.
	&"drum": Color(0.72, 0.64, 0.36),
	&"barrel": Color(0.30, 0.33, 0.28),
	&"pillar": Color(0.62, 0.16, 0.40),
	&"net": Color(0.20, 0.55, 0.53),
	&"sofa": Color(0.42, 0.31, 0.48),
	# Its hinged doors (DO1): bottle-green painted leaves, so a door reads apart from the plywood round it.
	&"door": Color(0.22, 0.40, 0.27),
	# Woodland's concept 3 (WR1), off both team hues, from the palette: rubber tyres, a violet pickup, a thicket's core
	# in its spruces' pine green.
	&"tyre": Color8(0x3d, 0x3b, 0x45),
	&"truck": Color8(0x76, 0x58, 0xaa),
	&"thicket": Color8(0x3d, 0x7a, 0x4a),
}
## Surfaces drawn in their own colour whatever their block's kind (RayHit.Surface to sRGB): a gravel bed on the slab.
@export var surface_colours: Dictionary[int, Color] = {
	RayHit.Surface.GRAVEL: Color8(0xa0, 0x9a, 0x92),
}
## Containers take the site colours in turn (bottle green, mustard, slate, teal), so a row of them never reads as one;
## every block of one container (MapData.Block.piece) takes the same.
@export var container_colours: Array[Color] = [
	Color(0.22, 0.40, 0.29), Color(0.79, 0.68, 0.19), Color(0.37, 0.43, 0.49), Color(0.18, 0.48, 0.48),
]
@export var default_colour: Color = Color(0.7, 0.7, 0.7)
## The ground beyond the field's walls, out to `ground_extent` metres each way from the middle, just below the floor.
@export var ground_colour: Color = Color8(0x8a, 0xa8, 0x60)
@export var ground_extent: float = 120.0
@export var ground_drop: float = 0.02
## Sloping ground's colour on each of its surfaces (RayHit.Surface to sRGB, the palette's meadow, litter, earth, pebble
## and timber), each far enough from a team's hue or dull enough to read as no team; a surface not listed is drawn in
## `ground_colour`.
@export var terrain_colours: Dictionary[int, Color] = {
	RayHit.Surface.GRASS: Color8(0x8a, 0xa8, 0x60),
	RayHit.Surface.LEAVES: Color8(0x8a, 0x8a, 0x6a),
	RayHit.Surface.EARTH: Color8(0x8a, 0x80, 0x70),
	RayHit.Surface.GRAVEL: Color8(0xa0, 0x9a, 0x92),
	RayHit.Surface.WOOD: Color8(0xa0, 0x94, 0x7c),
}
## Sloping ground's surfaces come in squares this size (m; half the browser game's 1 m, so a 2 m path keeps its
## width), a whole number to a terrain cell's side. Its under-trees surface goes where at least `canopy_trees` trunks
## stand within `canopy_radius` m of the middle of the `canopy_cell` square holding a square's middle (the browser's
## NIGHT_SIGHT canopy rule).
@export var ground_cell: float = 0.5
@export var canopy_trees: int = 3
@export var canopy_radius: float = 4.0
@export var canopy_cell: float = 1.0
## The most fireflies and wood trees beyond the fence a map's `dressing` may ask for (WL4): more are cut to this
## with a warning, as each costs load time and a drawn copy.
@export var most_fireflies: int = 1000
@export var most_forest_trees: int = 6000
## Greybox roughness, drawn clean in the shared light (no floor grid since WA1).
@export var roughness: float = 0.85


## What blocks of `kind` are made of.
func surface_of(kind: StringName) -> RayHit.Surface:
	return surfaces.get(kind, RayHit.Surface.CONCRETE) as RayHit.Surface


## The colour of the `index`-th piece of `kind` on its map.
func colour_of(kind: StringName, index: int) -> Color:
	if kind == &"container" and not container_colours.is_empty():
		return container_colours[index % container_colours.size()]
	return colours.get(kind, default_colour)


## The colour sloping ground of `surface` (RayHit.Surface) is drawn in.
func terrain_colour(surface: int) -> Color:
	return terrain_colours.get(surface, ground_colour)


## The colour block `b` is drawn in: its surface's own, else its piece's of its kind.
func block_colour(b: MapData.Block) -> Color:
	return surface_colours.get(b.surface, colour_of(b.kind, b.piece))
