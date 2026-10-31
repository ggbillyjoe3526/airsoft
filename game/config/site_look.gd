class_name SiteLook
extends Resource
## How a site-dressed map is drawn (DD1, Depot's temporary dress until the owner's models: docs/ART.md › The field kit):
## each block kind's finish (one of the site surface shader's canvases, its paint and accent, its roughness and
## metalness), the container paint and how a long container splits into units, the slab and plywood photo sets, and
## the day sky's clouds and haze. Every stand-in fills its block's box exactly, so cover, collision and the nav grid
## are the greybox's (SiteSurface, SiteDress, MapLevel's site mesh). Team colours stay off: no paint within 20° of a
## team's hue unless dull (tested as the greybox's are), safety paint yellow, blue a greyed navy.

## The shader's canvases (game/play/site/site_surface.gdshader's MODE_ constants, in this order).
enum Canvas {
	CONCRETE, BLOCK, CORRUGATED, PLYWOOD, OSB, GRAVEL, TREAD, GABION, FILM, PAINT, GROUND, FABRIC, RACK, IBC, PRECAST,
	TIMBER,
}

## Each finish: its canvas, base paint and accent (sRGB), the accent band's height over the block's foot (m, from and
## to; an empty band when from >= to), and its roughness and metalness.
@export var canvases: Dictionary[StringName, Canvas] = {
	&"slab": Canvas.CONCRETE, &"dock": Canvas.CONCRETE, &"gravel": Canvas.GRAVEL, &"ground": Canvas.GROUND,
	&"wall_outer": Canvas.BLOCK, &"wall_inner": Canvas.BLOCK, &"container": Canvas.CORRUGATED,
	&"container_box": Canvas.CORRUGATED, &"hoarding": Canvas.CORRUGATED, &"plywood": Canvas.PLYWOOD,
	&"crate": Canvas.OSB, &"precast": Canvas.PRECAST, &"wrapped": Canvas.FILM, &"rack": Canvas.RACK,
	&"gabion": Canvas.GABION, &"toilet": Canvas.PAINT, &"ibc": Canvas.IBC, &"generator": Canvas.PAINT,
	&"sandbags": Canvas.FABRIC, &"skip": Canvas.PAINT, &"ramp": Canvas.TREAD, &"timber": Canvas.TIMBER,
	&"frame": Canvas.PAINT, &"steel": Canvas.PAINT, &"hazard": Canvas.PAINT, &"net": Canvas.FABRIC,
	&"flag": Canvas.FABRIC, &"coping": Canvas.PRECAST, &"sail": Canvas.FABRIC, &"default": Canvas.PAINT,
	&"drum": Canvas.PAINT, &"barrel": Canvas.PAINT, &"pillar": Canvas.PAINT, &"netting": Canvas.FABRIC,
	&"sofa": Canvas.FABRIC, &"backing": Canvas.PAINT,
}
@export var paints: Dictionary[StringName, Color] = {
	&"slab": Color8(0x7c, 0x76, 0x70), &"dock": Color8(0xd2, 0xce, 0xc8), &"gravel": Color8(0xb9, 0xb4, 0xae),
	&"ground": Color8(0xb9, 0xae, 0x98), &"wall_outer": Color8(0xec, 0xe2, 0xcf), &"wall_inner": Color8(0xf4, 0xec, 0xda),
	&"container": Color(0.5, 0.5, 0.5), &"container_box": Color8(0x76, 0x58, 0xaa), &"hoarding": Color8(0x2a, 0x9c, 0x90),
	&"plywood": Color8(0xdc, 0xca, 0xa8), &"crate": Color8(0xc2, 0xb6, 0x98), &"precast": Color8(0xd2, 0xce, 0xc8),
	&"wrapped": Color8(0xf4, 0xec, 0xda), &"rack": Color8(0x6c, 0x6a, 0x7a), &"gabion": Color8(0xb9, 0xb4, 0xae),
	&"toilet": Color8(0x58, 0x90, 0x4e), &"ibc": Color8(0xf4, 0xec, 0xda), &"generator": Color8(0xe4, 0xca, 0x46),
	&"sandbags": Color8(0xa0, 0x94, 0x7c), &"skip": Color8(0xe4, 0xca, 0x46), &"ramp": Color8(0x8c, 0x8a, 0x96),
	&"timber": Color8(0xa0, 0x94, 0x7c), &"frame": Color(1.0, 1.0, 1.0), &"steel": Color8(0x6c, 0x6a, 0x7a),
	&"hazard": Color8(0xe4, 0xca, 0x46), &"net": Color8(0x58, 0x90, 0x4e), &"flag": Color8(0xe4, 0xca, 0x46),
	&"coping": Color8(0xd2, 0xce, 0xc8), &"sail": Color8(0xf4, 0xec, 0xda), &"default": Color8(0xb9, 0xb4, 0xae),
	# Depot's hall (DR1) in the look's six site colours (LookConfig.palette), each off both team hues: teal drums,
	# crimson barrels, yellow pillars, green netting, a violet sofa; the shelving's backing in the look's ink.
	&"drum": Color8(0x2a, 0x9c, 0x90), &"barrel": Color8(0xc2, 0x38, 0x74), &"pillar": Color8(0xe4, 0xca, 0x46),
	&"netting": Color8(0x58, 0x90, 0x4e), &"sofa": Color8(0x76, 0x58, 0xaa), &"backing": Color8(0x3a, 0x2f, 0x5a),
}
@export var accents: Dictionary[StringName, Color] = {
	&"dock": Color8(0xe4, 0xca, 0x46), &"gravel": Color8(0xa0, 0x9a, 0x92), &"wall_outer": Color8(0x76, 0x58, 0xaa),
	&"wall_inner": Color8(0x2a, 0x9c, 0x90), &"hoarding": Color8(0xe4, 0xca, 0x46), &"precast": Color8(0xe4, 0xca, 0x46),
	&"rack": Color8(0xe4, 0xca, 0x46), &"gabion": Color8(0x8c, 0x84, 0x78), &"toilet": Color8(0xf4, 0xec, 0xda),
	&"ibc": Color8(0x8c, 0x8a, 0x96), &"generator": Color8(0x3a, 0x2f, 0x5a), &"hazard": Color8(0x3a, 0x2f, 0x5a),
}
@export var bands: Dictionary[StringName, Vector2] = {
	&"wall_outer": Vector2(-1.0, 1.2), &"wall_inner": Vector2(-1.0, 0.9), &"precast": Vector2(0.86, 1.03),
	&"generator": Vector2(0.35, 0.7), &"hoarding": Vector2(-1.0, 0.3),
}
## The colours the canvases draw their marks in (sRGB): grass in the slab's joints, paint chips, rust at a container's
## foot, the site's chevron, hazard stripes' black, gabion wire, cartons under film and the pallet's slats and gaps,
## the goods on a rack, an IBC's pallet, the ground's grass, the dirt at a painted prop's foot and the slab's bay
## lines. SiteSurface.MARKS gives the shader's order.
@export var marks: Dictionary[StringName, Color] = {
	&"tuft": Color(0.63, 0.68, 0.48), &"chip": Color(0.77, 0.75, 0.74), &"rust_foot": Color(0.7, 0.67, 0.61),
	&"chevron": Color8(0xf4, 0xec, 0xda), &"stripe": Color8(0x3a, 0x2f, 0x5a), &"wire": Color8(0xd2, 0xce, 0xc8),
	&"carton": Color8(0xc2, 0xb6, 0x98), &"slat_gap": Color8(0x61, 0x59, 0x4f), &"slat": Color8(0xdc, 0xca, 0xa8),
	&"goods_olive": Color8(0x58, 0x90, 0x4e), &"goods_tan": Color8(0xdc, 0xca, 0xa8), &"pallet": Color8(0x8c, 0x8a, 0x96),
	&"grass": Color8(0xb3, 0xb8, 0x91), &"dirt_foot": Color(0.68, 0.65, 0.6),
	&"bay_line": Color8(0xe4, 0xca, 0x46),
}
## Roughness and metalness; a finish not listed is 0.8 and 0.
@export var finishes_pbr: Dictionary[StringName, Vector2] = {
	&"slab": Vector2(0.62, 0.0), &"dock": Vector2(0.7, 0.0), &"gravel": Vector2(0.9, 0.0),
	&"ground": Vector2(0.95, 0.0), &"wall_outer": Vector2(0.85, 0.0), &"wall_inner": Vector2(0.85, 0.0),
	&"container": Vector2(0.45, 0.1), &"container_box": Vector2(0.45, 0.1), &"hoarding": Vector2(0.5, 0.1),
	&"plywood": Vector2(0.85, 0.0), &"crate": Vector2(0.85, 0.0), &"precast": Vector2(0.85, 0.0),
	&"wrapped": Vector2(0.3, 0.0), &"rack": Vector2(0.5, 0.2), &"gabion": Vector2(0.9, 0.0),
	&"toilet": Vector2(0.55, 0.0), &"ibc": Vector2(0.4, 0.0), &"generator": Vector2(0.5, 0.1),
	&"sandbags": Vector2(0.97, 0.0), &"skip": Vector2(0.5, 0.1), &"ramp": Vector2(0.45, 0.4),
	&"timber": Vector2(0.85, 0.0), &"frame": Vector2(0.5, 0.2), &"steel": Vector2(0.4, 0.4),
	&"hazard": Vector2(0.6, 0.0), &"net": Vector2(1.0, 0.0), &"flag": Vector2(1.0, 0.0),
	&"coping": Vector2(0.8, 0.0), &"sail": Vector2(1.0, 0.0), &"drum": Vector2(0.6, 0.0), &"barrel": Vector2(0.4, 0.2),
	&"pillar": Vector2(0.45, 0.1), &"netting": Vector2(1.0, 0.0), &"sofa": Vector2(0.95, 0.0),
}
## The finish of each block kind; a kind not listed is `default`. Floors, walls, containers and barriers pick among
## theirs by shape (`finish_of`).
@export var kind_finishes: Dictionary[StringName, StringName] = {
	&"floor": &"slab", &"wall": &"wall_inner", &"container": &"container", &"plywood": &"plywood", &"crate": &"crate",
	&"barrier": &"hoarding", &"wrapped": &"wrapped", &"rack": &"rack", &"gabion": &"gabion", &"toilet": &"toilet",
	&"ibc": &"ibc", &"generator": &"generator", &"sandbags": &"sandbags", &"skip": &"skip", &"ramp": &"ramp",
	&"drum": &"drum", &"barrel": &"barrel", &"pillar": &"pillar", &"net": &"netting", &"sofa": &"sofa",
}
## A floor this thin (m) or thinner is a gravel bed, one standing on the ground (its centre above 0) the dock; a wall
## this tall (m) or more is the perimeter's; a barrier this low or lower and this long or longer is a precast
## block; a container this thin (m) or thinner is a wall of the Box (one container cut with ports, its own colour, no
## mark).
@export var gravel_to: float = 0.1
@export var outer_wall_from: float = 3.9
@export var low_barrier_to: float = 1.3
@export var low_barrier_length: float = 2.0
@export var box_wall_to: float = 1.0

## Container paint (the look's six site colours, docs/ART.md › Colour: crimson, violet, yellow, teal, green and cream,
## each kept off the teams' hues), each unit of a long or stacked container
## its own: a container longer than `container_split` m splits into units about `container_unit` long, one taller than
## a unit into tiers `container_tier` tall.
@export var container_paint: Array[Color] = [
	Color8(0xc2, 0x38, 0x74), Color8(0x76, 0x58, 0xaa), Color8(0xe4, 0xca, 0x46), Color8(0x2a, 0x9c, 0x90),
	Color8(0x58, 0x90, 0x4e), Color8(0xf4, 0xec, 0xda),
]
@export var container_unit: float = 6.1
@export var container_split: float = 7.0
@export var container_tier: float = 2.6
## The frame (corner posts, rails, lock bars) is the unit's paint this much darker.
@export var frame_shade: float = 0.75

## The slab's joints every this many metres; the slab and plywood photo sets (colour, OpenGL normal), each laid once
## every `*_scale` m and mixed in at `*_mix` with its relief at `*_depth`.
@export var joint: float = 4.0
## The dock's hazard-striped lip (its accent and the stripes' black) on its sides, from and to this far (m) below its
## top.
@export var hazard_lip: Vector2 = Vector2(0.04, 0.22)
@export_file("*.jpg", "*.png") var slab_colour: String = "res://assets/textures/site/concrete_floor_02_diff_1k.jpg"
@export_file("*.jpg", "*.png") var slab_normal: String = "res://assets/textures/site/concrete_floor_02_nor_gl_1k.jpg"
@export var slab_scale: float = 3.0
@export var slab_mix: float = 0.9
@export var slab_depth: float = 0.7
## The set's mean brightness (linear luma), so it darkens and lightens round the finish's paint.
@export var slab_luma: float = 0.173
@export_file("*.jpg", "*.png") var ply_colour: String = "res://assets/textures/site/plywood_diff_1k.jpg"
@export_file("*.jpg", "*.png") var ply_normal: String = "res://assets/textures/site/plywood_nor_gl_1k.jpg"
@export var ply_scale: float = 1.22
@export var ply_mix: float = 0.7
@export var ply_depth: float = 0.8
@export var ply_luma: float = 0.142
## The lighter bevel on every box edge within this many metres of it (the "CS edge highlight"), this much lighter.
@export var edge_width: float = 0.04
@export var edge_light: float = 0.3
## The look's clean surfaces (docs/ART.md › Surfaces): how much wear and grain the canvases show (0 clean painted, 1
## the old worn site: stains, chips, rust, grime and photo grain), and the soft vertical gradient on every side,
## `gradient` darker at its foot, full paint `gradient_height` m up.
@export_range(0.0, 1.0) var grit: float = 0.0
@export var gradient: float = 0.22
@export var gradient_height: float = 2.6
## Puddles (the map's own) are drawn into a mask this many pixels a metre.
@export var wet_pixels: float = 4.0

## The day sky's clouds: sky colours (sRGB), the clouds' lit and shaded colours, how much of the sky they cover (0 to 1),
## their edge's softness and their size (bigger is smaller clouds).
@export var sky_top: Color = Color(0.2, 0.42, 0.78)
@export var sky_horizon: Color = Color(0.72, 0.82, 0.92)
@export var sky_below: Color = Color(0.55, 0.52, 0.46)
@export var cloud_lit: Color = Color(1.0, 0.98, 0.95)
@export var cloud_shade: Color = Color(0.62, 0.68, 0.78)
@export var cloud_cover: float = 0.52
@export var cloud_softness: float = 0.22
@export var cloud_scale: float = 0.55
## The day's haze, so the skyline sits back: from and to (m), its density and colour (sRGB).
@export var haze_from: float = 45.0
@export var haze_to: float = 260.0
@export var haze_density: float = 0.55
@export var haze_colour: Color = Color(0.74, 0.82, 0.9)

## Sandbags: a bag's length and depth (m) as laid, a course's height, how far (m) a bag bulges out of its stack's box,
## how far (m) inside its sides and top the stack's own box is drawn under the bags, and the distance (m) past which
## only that box is drawn (the bags are one MultiMesh, so all of them at once).
@export var bag_size: Vector2 = Vector2(0.6, 0.36)
@export var bag_course: float = 0.145
@export var bag_bulge: float = 0.03
@export var bag_core: float = 0.08
@export var bags_until: float = 60.0
## The CC0 props drawn in place of some kinds' boxes (DR2).
@export var props: PropDressConfig = PropDressConfig.new()
## How far (m) the details (frames, battens, caps) stand proud of their box, and their sizes: a container's corner
## posts, rails and door lock bars, a crate's battens, a plywood sheet's cap and the perimeter wall's coping.
@export var proud: float = 0.015
@export var post: float = 0.16
@export var rail: float = 0.14
@export var lock_bar: float = 0.04
@export var batten: float = 0.08
@export var cap: float = 0.06
@export var coping: float = 0.08
## A sail's posts' thickness (m); the watch tower's camouflage net: how far (m) it overhangs the roof each side and its
## skirt's drop; its flag's size and pole's height (m).
@export var sail_post: float = 0.08
@export var net_overhang: float = 1.1
@export var net_skirt: float = 0.7
@export var flag_size: Vector2 = Vector2(1.2, 0.7)
@export var flag_pole: float = 2.4
## Stencils: their paint (sRGB, with alpha), the light paint on a wall darker than `stencil_light_below` (its paint's
## luminance), and how far (m) they stand off the wall.
@export var stencil_paint: Color = Color(0.227, 0.184, 0.353, 0.92)
@export var stencil_light: Color = Color(0.96, 0.93, 0.85, 0.92)
@export var stencil_light_below: float = 0.45
@export var stencil_off: float = 0.006


## The finishes in the shader's order (index = the finish's slot in its uniform arrays).
func finish_names() -> Array[StringName]:
	var out: Array[StringName] = []
	for k: StringName in canvases:
		out.append(k)
	return out


## The finish block `b` is drawn in: a box filled by tiled props shows only its dark backing behind them (DR2).
func finish_of(b: MapData.Block) -> StringName:
	if props != null and props.backs(b):
		return &"backing"
	match b.kind:
		&"floor":
			if b.size.y <= gravel_to:
				return &"gravel"
			return &"slab" if b.center.y < 0.0 else &"dock"
		&"wall":
			return &"wall_outer" if b.size.y >= outer_wall_from else &"wall_inner"
		&"container":
			return &"container_box" if is_box_wall(b) else &"container"
		&"barrier":
			return &"precast" if is_low_barrier(b) else &"hoarding"
	return kind_finishes.get(b.kind, &"default")


func is_box_wall(b: MapData.Block) -> bool:
	return b.kind == &"container" and minf(b.size.x, b.size.z) <= box_wall_to


func is_low_barrier(b: MapData.Block) -> bool:
	return b.size.y <= low_barrier_to and maxf(b.size.x, b.size.z) >= low_barrier_length


## How container `b` splits: units along its length and tiers up its height (1 each when it doesn't).
func container_split_of(b: MapData.Block) -> Vector2i:
	var length := maxf(b.size.x, b.size.z)
	var units := maxi(1, roundi(length / container_unit)) if length > container_split else 1
	var tiers := maxi(1, roundi(b.size.y / container_tier))
	return Vector2i(units, tiers)


## The paint of unit `unit`, tier `tier` of the `piece`-th container; site_surface.gdshader's container_paint() picks
## the same.
func container_colour(piece: int, unit: int, tier: int) -> Color:
	return container_paint[(piece * 5 + unit * 3 + tier * 2) % container_paint.size()]
