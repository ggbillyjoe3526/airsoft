class_name LookConfig
extends Resource
## The game's look, shared by every map (docs/ART.md; the owner's art direction "Sunlit Concrete", 2026-11-09):
## Counter-Strike-leaning naturalism, real materials in real light. Three parts, each its own group:
## - **Light.** The shared light (game/play/look/look_light.gdshaderinc): a natural soft falloff (no cel bands), a
##   dark neutral shade, a faint warm rim, a small soft highlight, and every surface's paint pulled back toward its grey
##   (`paint_saturation`). Pushed as global shader uniforms (`push_globals`), so
##   every material that includes the light follows one place; project.godot's [shader_globals] hold the same values.
## - **Picture.** The environment's grade (tonemap, saturation, contrast) and glow, on every preset (FieldLighting).
## - **Graphics.** What the dearer Graphics rows draw when on (data/graphics.md: global illumination, reflections,
##   glow, volumetric fog, softest shadows): their strengths here, their switches in GraphicsApply.
## The palette is the look's colours by name (sRGB), as painted: the light draws each at `paint_saturation` of its
## colour, so the six site colours read as weathered paint. They spread evenly so none dominates, with the neutrals
## under them, and the ink. None is within 20° of a team's hue unless dull (tests/unit/test_look.gd).

## The global shader uniforms the light reads, as project.godot declares them.
const GLOBAL_SHADE := &"look_shade"
const GLOBAL_BAND := &"look_band"
const GLOBAL_BAND_SOFT := &"look_band_soft"
const GLOBAL_MID_BAND := &"look_mid_band"
const GLOBAL_RIM := &"look_rim"
const GLOBAL_RIM_POWER := &"look_rim_power"
const GLOBAL_SPEC := &"look_spec"
const GLOBAL_PAINT_SATURATION := &"look_paint_saturation"
const GLOBAL_WEAR := &"look_wear"
const GLOBAL_GRIME := &"look_grime"
const GLOBAL_DUST := &"look_dust"

@export_group("Light")
## What the sun adds where it doesn't reach: a dark warm grey, so the far side falls to the ambient and bounce light
## as it does in daylight (Sunlit Concrete; it was the old look's violet).
@export var shade: Color = Color8(0x29, 0x28, 0x26)
## Where the sun's light is centred (its angle as a cosine) and how far it spreads either side: wide, so a surface
## darkens smoothly as it turns from the sun, the way real light falls off, with no cel band.
@export var band: float = 0.42
@export var band_soft: float = 0.55
## A second step half way up the lit side (the old look's cel step): this share of the light comes only past it.
@export var mid_band: float = 0.0
## The rim: warm light on an edge seen against the sun, `rim_power` the falloff from the edge (higher is thinner), its
## colour's alpha its strength.
@export var rim: Color = Color(Color8(0xff, 0xf2, 0xd9), 0.03)
@export var rim_power: float = 3.2
## A soft highlight's strength on a smooth surface (none on a rough one).
@export var spec: float = 0.3
## How much of its colour every surface's paint keeps (0 grey, 1 as painted): the palette as weathered material.
@export_range(0.0, 1.0) var paint_saturation: float = 0.6

@export_group("Wear")
## The models' wear (look_vertex.gdshader's `wear`, SL2): grime up a model's foot, streaks down its sides, broad
## stains and dust on its tops, in world space so no two props wear alike. This scales every material's own share (a
## prop's PropDressConfig.wear, a tree's crown none); 0 draws every model clean.
@export_range(0.0, 1.0) var wear: float = 1.0
## The grime's colour (dark earth) and the dust's (pale and dry), mixed over a worn surface's paint.
@export var grime: Color = Color8(0x4a, 0x41, 0x36)
@export var dust: Color = Color8(0xb3, 0xa9, 0x94)

@export_group("Picture")
## AgX's contrast and the grade over it: a natural picture, a little contrasty, the team colours still the loudest.
@export var agx_contrast: float = 1.35
@export var saturation: float = 0.95
@export var contrast: float = 1.12
@export var brightness: float = 1.0
## Glow (Graphics › Glow): only what is brighter than `glow_threshold` (lamps, a lit sky) blooms, softly.
@export var glow_intensity: float = 0.35
@export var glow_strength: float = 1.0
@export var glow_bloom: float = 0.02
@export var glow_threshold: float = 0.95

@export_group("Global illumination")
## Screen-space bounce (Graphics › Global illumination: Screen and up): how far (m) light bounces, and how strong.
@export var ssil_radius: float = 4.0
@export var ssil_intensity: float = 1.1
@export var ssil_sharpness: float = 0.98
## SDFGI (Scene): the whole field's bounce and sky light, occlusion on. Cascades, the smallest cell (m), its strength,
## how much of a bounce feeds the next, and its probes' rays and frames to settle.
@export var sdfgi_cascades: int = 5
@export var sdfgi_min_cell: float = 0.2
@export var sdfgi_energy: float = 1.0
@export var sdfgi_bounce: float = 0.5
@export var sdfgi_rays: RenderingServer.EnvironmentSDFGIRayCount = RenderingServer.ENV_SDFGI_RAY_COUNT_96
@export var sdfgi_converge: RenderingServer.EnvironmentSDFGIFramesToConverge = \
		RenderingServer.ENV_SDFGI_CONVERGE_IN_30_FRAMES
@export var sdfgi_update: RenderingServer.EnvironmentSDFGIFramesToUpdateLight = \
		RenderingServer.ENV_SDFGI_UPDATE_LIGHT_IN_4_FRAMES

@export_group("Reflections")
## Reflection probes (Probes and up): one per named area of a map of at least `probe_area` m², up to `probe_most`,
## box-projected, updated once at the start; `probe_margin` m of blend at their edges.
@export var probe_area: float = 60.0
@export var probe_most: int = 24
@export var probe_margin: float = 1.5
@export var probe_intensity: float = 1.0
## How tall (m) a probe's box is on a field open to the sky (a roofed one reaches its roof), and the height (m) it
## captures from (about eye height).
@export var probe_height: float = 8.0
@export var probe_eye: float = 1.6
## How far (m) each of a probe's six views reaches at least (GL1). Godot ends each view at its box's side, which for
## a probe on Woodland's slopes is a metre or two under the eye and a few metres off to each side, so the views stopped
## in the hillside and trees close round it; on the north bridge that left bad values in the probe's blurred levels,
## which drew every surface near it rough enough to read them black with a white glow. 12 m cleared it; 40 m did too but darkened the
## Clearing (its views took in the dark wood far past its area), so the reach stays short.
@export var probe_reach: float = 12.0
## Screen-space reflections (Screen): steps, fades and depth tolerance.
@export var ssr_steps: int = 96
@export var ssr_fade_in: float = 0.15
@export var ssr_fade_out: float = 2.0
@export var ssr_depth_tolerance: float = 0.2

@export_group("Volumetric fog")
## Graphics › Volumetric fog: a faint haze the sun and the bounce light up, so light has shafts and depth. Density (per
## m), its colour, how forward it scatters, how far it reaches (m), how much bounce light it takes in, and the
## froxel grid (cells across and deep).
@export var fog_density: float = 0.006
@export var fog_albedo: Color = Color8(0xf4, 0xec, 0xda)
@export var fog_anisotropy: float = 0.45
@export var fog_length: float = 80.0
@export var fog_gi_inject: float = 1.0
@export var fog_volume_size: int = 128
@export var fog_volume_depth: int = 128

@export_group("Shadows")
## The sun's apparent size (degrees) on Softest shadows: contact-hardening shadows, sharp at a foot, soft far from it.
@export var sun_size: float = 0.6

@export_group("Palette")
## The look's colours by name (sRGB), for every map's dress: a map's paint (SiteLook, RoofConfig, the props' recipes)
## takes each colour from here, and tests/unit/test_look.gd holds Depot's and Woodland's to it.
@export var palette: Dictionary[StringName, Color] = {
	&"crimson": Color8(0xc2, 0x38, 0x74), &"violet": Color8(0x76, 0x58, 0xaa), &"yellow": Color8(0xe4, 0xca, 0x46),
	&"teal": Color8(0x2a, 0x9c, 0x90), &"green": Color8(0x58, 0x90, 0x4e), &"cream": Color8(0xf4, 0xec, 0xda),
	&"concrete": Color8(0xd2, 0xce, 0xc8), &"floor": Color8(0xb9, 0xb4, 0xae), &"plywood": Color8(0xdc, 0xca, 0xa8),
	&"timber": Color8(0xa0, 0x94, 0x7c), &"crate": Color8(0xc2, 0xb6, 0x98), &"steel": Color8(0x6c, 0x6a, 0x7a),
	&"ink": Color8(0x3a, 0x2f, 0x5a), &"slab": Color8(0x7c, 0x76, 0x70), &"sand": Color8(0xb9, 0xae, 0x98),
	&"plaster": Color8(0xec, 0xe2, 0xcf), &"grey": Color8(0x8c, 0x8a, 0x96), &"pebble": Color8(0xa0, 0x9a, 0x92),
	&"stone": Color8(0x8c, 0x84, 0x78), &"ceiling": Color8(0x52, 0x4a, 0x72), &"umber": Color8(0x61, 0x59, 0x4f),
	&"moss": Color8(0xb3, 0xb8, 0x91),
	# Woodland's (WA1): bark and heartwood, the leaves from a sunlit canopy down to the deep forest, the meadow, leaf
	# litter and earth underfoot, tyre rubber, and the puddles' water and mud.
	&"bark": Color8(0x7b, 0x6f, 0x62), &"heartwood": Color8(0xe4, 0xdc, 0xcd), &"canopy": Color8(0x5c, 0x9a, 0x50),
	&"fern": Color8(0x79, 0xa6, 0x50), &"olive": Color8(0x8c, 0x9a, 0x48), &"pine": Color8(0x3d, 0x7a, 0x4a),
	&"spruce": Color8(0x2f, 0x6e, 0x55), &"forest": Color8(0x2b, 0x5c, 0x48), &"meadow": Color8(0x8a, 0xa8, 0x60),
	&"litter": Color8(0x7c, 0x7a, 0x58), &"earth": Color8(0x8a, 0x80, 0x70), &"rubber": Color8(0x3d, 0x3b, 0x45),
	# Sunlit Concrete (SL1): sloping ground's grass, darker so it stays green once the paint is muted.
	&"grass": Color8(0x5f, 0x8a, 0x3a),
	&"pond": Color8(0x4a, 0x6f, 0x6c), &"mud": Color8(0x55, 0x4e, 0x44), &"mud_wet": Color8(0x40, 0x3b, 0x34),
	# Town colours (ST1): raspberry brick (off Beta's high-contrast orange's hue), and pastel renders (seafoam, lilac,
	# butter, sage).
	&"brick": Color8(0xa3, 0x4a, 0x6a), &"seafoam": Color8(0x7f, 0xb8, 0xad), &"lilac": Color8(0xb9, 0xa8, 0xd6),
	&"butter": Color8(0xe6, 0xd4, 0x78), &"sage": Color8(0xa9, 0xc4, 0x8e),
}
## The six site colours, spread evenly over a map's paint so no one colour dominates.
@export var site_colours: Array[StringName] = [&"crimson", &"violet", &"yellow", &"teal", &"green", &"cream"]


## The palette's colour `name`, or magenta with a warning for a name it doesn't have (a typo shows at once).
func colour(name: StringName) -> Color:
	if palette.has(name):
		return palette[name]
	push_warning("LookConfig: no palette colour %s" % name)
	return Color.MAGENTA


## The shared light's values, as the global shader uniforms (name to value). The colours go linear: a colour global
## reaches a shader as it is set, with no sRGB conversion even with `source_color` (checked on 4.7.2), so project.godot
## holds the same linear values.
func globals() -> Dictionary[StringName, Variant]:
	return {
		GLOBAL_SHADE: shade.srgb_to_linear(), GLOBAL_BAND: band, GLOBAL_BAND_SOFT: band_soft, GLOBAL_MID_BAND: mid_band,
		GLOBAL_RIM: rim.srgb_to_linear(), GLOBAL_RIM_POWER: rim_power, GLOBAL_SPEC: spec,
		GLOBAL_PAINT_SATURATION: paint_saturation, GLOBAL_WEAR: wear, GLOBAL_GRIME: grime.srgb_to_linear(),
		GLOBAL_DUST: dust.srgb_to_linear(),
	}


## Sends the light's values to every material at once. Once a match (they never change in play).
func push_globals() -> void:
	var values := globals()
	for k: StringName in values:
		RenderingServer.global_shader_parameter_set(k, values[k])
