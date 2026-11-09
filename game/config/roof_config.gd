class_name RoofConfig
extends Resource
## An indoor field's roof (DR1, MapData.roof_height and roof_lamps), drawn by RoofView: the ceiling's sheeting, the
## steel trusses under it every `truss_step` m across the hall, and the lamp panels. Look only: the light itself is the
## preset's sun, set nearly overhead by the map (its `lighting.overrides`), which the roof shades only on Lamp light Far
## (but at its rooflights), and the lamps as real lights on High and Ultra (Lamp light). Colours are
## sRGB, the look's (LookConfig.palette), off both team hues (docs/ART.md › Colour).

## The ceiling: its sheeting's paint (in the shared light, so its underside takes the look's shade and the bounce),
## its roughness, and how far past the field's walls it reaches (m), so no gap shows at the eaves.
@export var ceiling_colour: Color = Color8(0x52, 0x4a, 0x72)
@export var roughness: float = 0.9
@export var ceiling_overhang: float = 1.0
## The trusses: across the hall along z, one every `truss_step` m along x (Depot's hall walls' columns stand under
## them, PropDressConfig.bay_anchor), drawn as the roof's bay model (Dev 3: truss, purlins, sheet and services,
## tools/blender/maps/roof_truss.py), each bay `truss_step` m along x and about `bay_span` m across, `bay_chunk` truss
## lines a MultiMesh so far ones cull and take a simpler mesh; without the model, plain beams `truss_depth` deep and
## `truss_width` wide, in the look's crimson.
@export_file("*.glb") var bay_model: String = "res://assets/models/props/roof_truss.glb"
@export var bay_span: float = 18.0
@export var bay_chunk: int = 2
@export var truss_step: float = 8.0
@export var truss_depth: float = 0.5
@export var truss_width: float = 0.25
@export var truss_colour: Color = Color8(0xc2, 0x38, 0x74)
## The lamps: the high-bay model (Dev 3, its top at the ceiling, hanging on its cable; its `lamp_lens` material's
## faces glow `lamp_colour` at `lamp_energy` with no real light, the rest painted in its vertex colours); without the
## model, panels hanging `lamp_drop` m under the ceiling, `lamp_size` m (x across, z deep) and 0.08 m thick, glowing.
@export_file("*.glb") var lamp_model: String = "res://assets/models/props/roof_lamp.glb"
@export var lamp_lens: StringName = &"Lens"
## How far (m) a lamp hangs at least from a truss line with the bay model, so it never hangs inside the truss (a
## lamp's half width, the truss's half width and a hand between).
@export var lamp_clear: float = 0.4
@export var lamp_drop: float = 0.6
@export var lamp_size: Vector2 = Vector2(1.4, 0.5)
@export var lamp_colour: Color = Color(1.0, 0.96, 0.86)
@export var lamp_energy: float = 2.6

@export_group("Lamp light")
## The lamps as real lights (Settings › Graphics › Lamp light, RoofLamps): each a spot `lamp_light_drop` m under the
## lamp's lowest point, shining straight down, `lamp_cone` degrees from its axis to the cone's edge (dimming from its
## axis to the edge by the engine's curve `lamp_cone_falloff`: below 1 soft, so neighbouring pools blend), reaching
## `lamp_range` m at `lamp_light_energy` with the engine's distance falloff `lamp_falloff` (1: inverse distance), in
## `lamp_colour`. On the haze (Volumetric fog) it shines `lamp_fog` of itself.
@export var lamp_light_drop: float = 0.05
@export var lamp_cone: float = 36.0
@export var lamp_cone_falloff: float = 0.6
@export var lamp_range: float = 17.0
@export var lamp_light_energy: float = 26.0
@export var lamp_falloff: float = 1.0
@export var lamp_fog: float = 0.6
## While the lamps shine the preset's overhead sun, which stands in for them on Low and Medium, is turned down to this
## share of itself, so the hall keeps about its brightness and reads as lit by its lamps.
@export var lamp_sun_share: float = 0.55
## How far (m) from the eye the lamps are lit (Near, Far), each fading out over its last `lamp_fade` m; past that a
## lamp is not lit at all, as an unshadowed one would shine through the rooms' roofs. Far keeps Depot's 65 m hall
## sight line lit.
@export var lamp_near: float = 28.0
@export var lamp_far: float = 70.0
@export var lamp_fade: float = 10.0
## The lamps' shadows: blur on the softer filters, and the lens's width (`lamp_lens_size`, m) on Softest, so a shadow is
## sharp at its foot and soft away from it, as the sun's.
@export var lamp_shadow_blur: float = 1.0
@export var lamp_lens_size: float = 0.35
## On Far (Ultra) the roof also shades the sun but at its rooflights (RoofView's sun shade, with the bay model): strips
## `rooflight_half` m either side of each bay's edge, halfway between the trusses (tools/blender/maps/roof_truss.py's
## ROOFLIGHT), so the sun falls through them in shafts on the haze and patches on the floor. Shaded, the sun keeps
## `shade_sun_share` of itself and each lamp shines `lamp_shaded_energy`, so the hall keeps about its brightness, and
## the haze under the roof thickens by `shade_haze` (a FogVolume's density) so the sun's shafts show.
@export var rooflight_half: float = 0.8
@export var shade_haze: float = 0.012
@export var shade_sun_share: float = 1.0
@export var lamp_shaded_energy: float = 34.0
