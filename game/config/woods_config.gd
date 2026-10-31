class_name WoodsConfig
extends Resource
## A wood's look in placeholders (WL4; the browser game's config/dressing.ts WOODS, FIREFLIES, puddles and mud, and
## config/gpuDressing.ts GPU_GRASS and GPU_FOREST): the trees' crowns, the wood beyond the fence, grass tufts, puddles
## and mud, leaf drifts, fallen branches and moss, and fireflies and motes at night, as WoodsShapes places them and
## WoodsView draws them. Look only: nothing here collides, hides anyone from the simulation or is read by play. Sizes in
## metres; colours sRGB, each the look's palette's (LookConfig.palette, WA1) and none within 20 degrees of a team's hue
## unless dull (docs/ART.md › Colour). A list indexed
## by step has one value for each Mesh detail step, Low to Ultra (GraphicsQuality.MeshDetail).

@export_group("Crowns")
## Every tree block's crown, on every preset: a cone of `crown_sides` sides from `crown_from` of the trunk's height
## over its foot (never under `crown_clear` m, so it stays over everyone's head) to `crown_over` m over its top,
## `crown_width` of its own height wide (radius), in one of `crown_colours`, each up to `crown_jitter` lighter or darker.
@export var crown_colours: PackedColorArray = PackedColorArray([
	Color("5c9a50"), Color("58904e"), Color("3d7a4a"), Color("79a650"),
])
@export var crown_from: float = 0.38
@export var crown_clear: float = 2.6
@export var crown_over: float = 1.4
@export var crown_width: float = 0.3
@export var crown_sides: int = 8
@export var crown_jitter: float = 0.1
@export var crown_roughness: float = 0.95

@export_group("Forest")
## The wood beyond the fence (MapData.forest_trees): `forest_share` of them on each step (Low none), standing
## `forest_fence` m or more outside the field's ground, out to `forest_reach` m from its middle, `forest_apart` m or
## more from the next, on a skyline hill where they stand on one: cones `forest_height` m tall (a range),
## `forest_width` of that wide (radius), `forest_sides` sides, sunk `forest_sink` m, in one of `forest_colours`,
## faded toward the horizon `forest_fade` as far as the skyline fades (SkylineConfig), casting no shadow.
## `forest_tries` candidate spots a tree at most.
@export var forest_share: PackedFloat32Array = PackedFloat32Array([0.0, 0.45, 0.7, 1.0])
@export var forest_fence: float = 12.0
@export var forest_reach: float = 118.0
@export var forest_apart: float = 2.2
@export var forest_height: Vector2 = Vector2(9.0, 17.0)
@export var forest_width: float = 0.27
@export var forest_sides: int = 6
@export var forest_sink: float = 0.4
@export var forest_tries: int = 30
@export var forest_colours: PackedColorArray = PackedColorArray([
	Color("2b5c48"), Color("2f6e55"), Color("3d7a4a"), Color("2b5c48"),
])
@export var forest_fade: float = 0.2

@export_group("Grass tufts")
## Tufts on the ground's grass squares (Medium and up; MapData.grass_height): `tuft_density` a square metre on each
## step, `tuft_blades` blades `tuft_width` m wide at the foot round a clump `tuft_spread` m across, as tall as the map's
## grass height times `tuft_height` (a range, never over it), leaning out `tuft_lean` of their height, in the grass's
## own colour from `tuft_root` of it at the foot to `tuft_tip` at the tip, each tuft up to `tuft_jitter` lighter or
## darker; none within `tuft_margin` m of a block standing on the ground or of a puddle. Drawn in tiles of `tile` m,
## each out to `tuft_range` m on its step, shrinking away over the last `tuft_fade` of that.
@export var tuft_density: PackedFloat32Array = PackedFloat32Array([0.0, 1.2, 2.0, 3.0])
@export var tuft_range: PackedFloat32Array = PackedFloat32Array([0.0, 30.0, 45.0, 60.0])
@export var tuft_fade: float = 0.3
@export var tuft_blades: int = 5
@export var tuft_width: float = 0.04
@export var tuft_spread: float = 0.08
@export var tuft_height: Vector2 = Vector2(0.55, 1.0)
@export var tuft_lean: float = 0.35
@export var tuft_root: float = 0.8
@export var tuft_tip: float = 1.15
@export var tuft_jitter: float = 0.12
@export var tuft_margin: float = 0.15
## Every other blade turned on by this share of a blade's step, so the clump isn't a regular star.
@export var tuft_stagger: float = 0.37
## How much light the tufts' faces give back as a shine (0 to 1).
@export var tuft_specular: float = 0.2
@export var tile: float = 32.0

@export_group("Puddles")
## Puddles and mud (MapData.puddles; Medium and up): the ground's own squares under each, cut `puddle_cuts` times a
## side and lifted `puddle_lift` m (so they lie on the slope exactly and sit under any BB), coloured by an outline of
## `puddle_points` points pulled in by up to `puddle_wobble` of its radius: water (`water` at `water_alpha`) inside
## `puddle_core` of it, then a wet margin (`wet` at `wet_alpha`) fading out; mud the same in `mud` and `mud_wet`.
## Water glossy (`puddle_roughness`), mud duller (`mud_roughness`), each its own draw; seen through, drawn before every
## other see-through thing so none hides a BB.
@export var puddle_points: int = 24
@export var puddle_wobble: float = 0.35
@export var puddle_core: float = 0.72
@export var puddle_cuts: int = 4
@export var puddle_lift: float = 0.012
@export var puddle_roughness: float = 0.08
@export var mud_roughness: float = 0.5
@export var water: Color = Color("4a6f6c")
@export var water_alpha: float = 0.88
@export var wet: Color = Color("403b34")
@export var wet_alpha: float = 0.45
@export var mud: Color = Color("554e44")
@export var mud_alpha: float = 0.85
@export var mud_wet: Color = Color("403b34")
@export var mud_wet_alpha: float = 0.5

@export_group("Leaf drifts")
## Leaf litter (MapData.leaf_drifts; Medium and up): the ground cut into squares `leaf_cell` m across; a square within
## `leaf_near` m of a foot (a block standing on the ground) gets a drift by the map's share: `leaf_count` leaves (a
## range) scattered `leaf_radius` m round a spot by the foot, each `leaf_size` m long (a range), `leaf_lift` m over the
## ground, in one of `leaf_colours`; none on a puddle.
@export var leaf_cell: float = 2.4
@export var leaf_near: float = 2.2
@export var leaf_count: Vector2i = Vector2i(6, 11)
@export var leaf_radius: float = 0.75
@export var leaf_size: Vector2 = Vector2(0.08, 0.15)
@export var leaf_lift: float = 0.014
## A drift's middle stands this share of `leaf_radius` out from its foot.
@export var leaf_out: float = 0.6
@export var leaf_colours: PackedColorArray = PackedColorArray([
	Color("e4ca46"), Color("8c9a48"), Color("61594f"), Color("b9ae98"), Color("c23874"), Color("b3b891"),
	Color("a0947c"),
])

@export_group("Fallen wood")
## Fallen branches, twigs and short logs (MapData.fallen; Medium and up) against the feet of blocks at least
## `fallen_min_height` m tall: slots `fallen_step` m apart along each side, `fallen_corner` m from its ends, each taken
## by the map's share, the kind by `fallen_weights` (branch, twigs, log), each `fallen_sizes` (along the side, out from
## it, thick) and `fallen_sides` sides round, sunk `fallen_sink` m, in one of `bark` (a log's ends in `grain`); none
## within `fallen_lane` m of a lane or `fallen_spot` m of a spawn, a dead-zone spot or the flag.
@export var fallen_step: float = 1.6
@export var fallen_corner: float = 0.3
@export var fallen_min_height: float = 0.5
@export var fallen_weights: Vector3 = Vector3(3.0, 2.0, 1.0)
@export var fallen_sizes: PackedVector3Array = PackedVector3Array([
	Vector3(1.3, 0.42, 0.12), Vector3(0.7, 0.4, 0.07), Vector3(1.0, 0.34, 0.26),
])
@export var fallen_sides: int = 6
@export var fallen_sink: float = 0.03
@export var fallen_lane: float = 1.2
@export var fallen_spot: float = 2.0
## None within `fallen_puddle` m of a puddle; each piece turned up to `fallen_turn` radians off its side; twigs come
## `twigs` to a slot, each turned up to `twig_turn` radians more and `twig_least` to all of the slot's length.
@export var fallen_puddle: float = 0.1
@export var fallen_turn: float = 0.25
@export var twigs: int = 3
@export var twig_turn: float = 0.6
@export var twig_least: float = 0.6
@export var bark: PackedColorArray = PackedColorArray([
	Color("7b6f62"), Color("61594f"), Color("a0947c"), Color("8c8478"),
])
@export var grain: Color = Color("e4dccd")

@export_group("Moss")
## Moss on the logs (MapData.moss and moss_share; Medium and up): on the chosen logs, a lid over the top and a band
## down the north side (-z) `moss_band` of the log's height deep, `moss_proud` m proud.
@export var moss_band: float = 0.4
@export var moss_proud: float = 0.012

@export_group("Night air")
## Fireflies over the field by night (MapData.fireflies): points `firefly_size` m across hanging `firefly_height` m (a
## range) over the ground within `firefly_reach` m of a log or a puddle of water, each drifting up to `firefly_drift` m
## and pulsing once every `firefly_period` s (a range, never faster), from `firefly_low` to full, self-lit at
## `firefly_glow`. Motes (MapData.motes_tint): `mote_count` specks `mote_size` m across in a box `mote_box` m round the
## eye, drifting `mote_speed` m/s, self-lit at `mote_glow` of the map's tint, fading over `mote_edge` m at the box's
## sides. Both the Wind dust row's share of them (Low none); under Reduced motion they stand still and steady.
@export var firefly_size: float = 0.11
@export var firefly_colour: Color = Color("d6ff7a")
@export var firefly_glow: float = 1.0
@export var firefly_height: Vector2 = Vector2(0.3, 1.9)
@export var firefly_reach: float = 2.5
## The nearest a firefly hangs to its log or puddle's edge (m).
@export var firefly_near: float = 0.3
@export var firefly_drift: float = 0.35
@export var firefly_period: Vector2 = Vector2(2.6, 5.0)
@export var firefly_low: float = 0.12
@export var mote_count: int = 160
@export var mote_size: float = 0.03
## The smallest mote is this share of `mote_size`.
@export var mote_least: float = 0.6
@export var mote_box: Vector3 = Vector3(16.0, 4.0, 16.0)
@export var mote_speed: float = 0.12
## The way the motes drift (scaled by `mote_speed`; each mote 0.5 to 1.5 times as fast).
@export var mote_wind: Vector3 = Vector3(0.6, 0.15, 0.4)
@export var mote_glow: float = 0.35
@export var mote_edge: float = 1.5

@export_group("Bushes")
## The map's bushes (MapData.foliage, WL5; BushView) as placeholder ellipsoids, every one in a single instanced draw on
## every preset: a sphere of `bush_sides` sides and `bush_rings` rings stretched to each bush, in one of `bush_colours`,
## each up to `bush_jitter` lighter or darker, as rough as `bush_roughness`; marked on the minimap in
## MinimapConfig.bush_colour. The art pass gives them leaves (step 32).
@export var bush_colours: PackedColorArray = PackedColorArray([
	Color("79a650"), Color("58904e"), Color("8c9a48"), Color("5c9a50"),
])
@export var bush_jitter: float = 0.1
@export var bush_sides: int = 12
@export var bush_rings: int = 6
@export var bush_roughness: float = 0.95

@export_group("Look")
## The floor's pieces (leaves, wood, moss) and the tufts take light as this rough.
@export var roughness: float = 0.9


## `list`'s value on Mesh detail step `step` (its last for a step past its end, 0 for an empty list).
static func on_step(list: PackedFloat32Array, step: int) -> float:
	if list.is_empty():
		return 0.0
	return list[clampi(step, 0, list.size() - 1)]
