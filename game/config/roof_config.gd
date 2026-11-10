class_name RoofConfig
extends Resource
## An indoor field's roof (DR1, MapData.roof_height and roof_lamps), drawn by RoofView: the ceiling's sheeting, the
## steel trusses under it every `truss_step` m across the hall, and the lamp panels. Look only: the light itself is the
## preset's sun, set nearly overhead by the map (its `lighting.overrides`), standing in for the lamps on Low and Medium;
## on High and Ultra the lamps as real lights light the hall alone (Lamp light), the sun out. Colours are
## sRGB, the look's (LookConfig.palette), off both team hues (docs/ART.md › Colour).

## The ceiling: its sheeting's paint (in the shared light, so its underside takes the look's shade and the bounce),
## its roughness, and how far past the field's walls it reaches (m), so no gap shows at the eaves.
@export var ceiling_colour: Color = Color8(0xd2, 0xce, 0xc8)
@export var roughness: float = 0.9
@export var ceiling_overhang: float = 1.0
## The trusses: across the hall along z, one every `truss_step` m along x (Depot's hall walls' columns stand under
## them, PropDressConfig.bay_anchor), drawn as the roof's bay model (Dev 3: truss, purlins, sheet and services,
## tools/blender/maps/roof_truss.py), each bay `truss_step` m along x and about `bay_span` m across, `bay_chunk` truss
## lines a MultiMesh so far ones cull and take a simpler mesh; without the model, plain beams `truss_depth` deep and
## `truss_width` wide, in the look's galvanised grey (Sunlit Concrete, SL3; the ceiling its pale concrete grey).
@export_file("*.glb") var bay_model: String = "res://assets/models/props/roof_truss.glb"
@export var bay_span: float = 18.0
@export var bay_chunk: int = 2
@export var truss_step: float = 8.0
@export var truss_depth: float = 0.5
@export var truss_width: float = 0.25
@export var truss_colour: Color = Color8(0x8c, 0x8a, 0x96)
## The lamps: the high-bay model (Dev 3, its top at the ceiling, hanging on its cable; its `lamp_lens` material's
## faces glow `lamp_colour` at `lamp_energy` with no real light, the rest painted in its vertex colours); without the
## model, panels hanging `lamp_drop` m under the ceiling, `lamp_size` m (x across, z deep) and 0.08 m thick, glowing.
@export_file("*.glb") var lamp_model: String = "res://assets/models/props/roof_lamp.glb"
@export var lamp_lens: StringName = &"Lens"
## How far (m) a lamp hangs at least from a truss line with the bay model, so it never hangs inside the truss (a
## lamp's half width, the truss's half width and a hand between).
@export var lamp_clear: float = 0.4
@export var lamp_drop: float = 0.6
## A plain roof's lamps (MT1, MapData.roof_plain: a station's strip lights): panels this far under their ceiling.
@export var plain_lamp_drop: float = 0.08
@export var lamp_size: Vector2 = Vector2(1.4, 0.5)
@export var lamp_colour: Color = Color(1.0, 0.96, 0.86)
@export var lamp_energy: float = 2.6
## Worn lamps (DW1, a map's `roof.lamps[].state`: Depot's): a dim one lights at `lamp_dim_share` of a working one's
## strength in the older, warmer `lamp_dim_colour`, its lens at `lamp_dim_glow` of a working one's (a lens glows so
## brightly that half still reads full white); a dead one neither glows nor lights (`lamp_dead_glow`). A flickering one
## mostly shines in full, but each `lamp_flicker_every` s (its own phase), all but `lamp_flicker_quiet` of the time, it
## stutters for `lamp_flicker_shortest` to 1 of `lamp_flicker_burst` s, each `lamp_flicker_step` s step off (at
## `lamp_flicker_low`) at `lamp_flicker_off` odds.
@export var lamp_dim_share: float = 0.45
@export var lamp_dim_glow: float = 0.12
@export var lamp_dim_colour: Color = Color(1.0, 0.78, 0.5)
@export var lamp_dead_glow: float = 0.0
@export var lamp_flicker_low: float = 0.05
@export var lamp_flicker_step: float = 0.09
@export var lamp_flicker_every: float = 3.5
@export var lamp_flicker_burst: float = 1.0
@export var lamp_flicker_quiet: float = 0.3
@export var lamp_flicker_shortest: float = 0.4
@export var lamp_flicker_off: float = 0.6

@export_group("Lamp light")
## The lamps as real lights (Settings › Graphics › Lamp light, RoofLamps): each a spot `lamp_light_drop` m under the
## lamp's lowest point, shining straight down, `lamp_cone` degrees from its axis to the cone's edge (dimming from its
## axis to the edge by the engine's curve `lamp_cone_falloff`: below 1 soft, so neighbouring pools blend), reaching
## `lamp_range` m at `lamp_light_energy` with the engine's distance falloff `lamp_falloff` (1: inverse distance), in
## `lamp_colour`. On the haze (Volumetric fog) it shines `lamp_fog` of itself.
@export var lamp_light_drop: float = 0.05
@export var lamp_cone: float = 70.0
@export var lamp_cone_falloff: float = 0.15
@export var lamp_range: float = 24.0
@export var lamp_light_energy: float = 6.0
@export var lamp_falloff: float = 0.6
@export var lamp_fog: float = 0.3
## A plain roof's lamps (MT1, a station's low ceilings, one level over another): each reaching only
## `plain_lamp_reach` m past the storey under it (MapData.storeys), so no light falls through a floor onto the level
## under that, at `plain_lamp_energy`.
@export var plain_lamp_reach: float = 2.5
@export var plain_lamp_energy: float = 2.4
## While the lamps shine the hall is lit by them alone (owner, 2026-11-10: no sun gets indoors): the preset's
## overhead light, which stands in for them on Low and Medium, keeps `lamp_sun_share` of itself (none), and the sky's
## ambient light under the roof `lamp_ambient_share`, so their shadows stay deep.
@export var lamp_sun_share: float = 0.0
@export var lamp_ambient_share: float = 0.6
## How far (m) from the eye the lamps cast shadows: Near within `lamp_near`, Far all of them (at least `lamp_far`);
## every lamp is lit across the whole roof (RoofLamps.reach), fading out over its last `lamp_fade` m.
@export var lamp_near: float = 28.0
@export var lamp_far: float = 70.0
@export var lamp_fade: float = 10.0
## The lamps' shadows: blur on the softer filters, and the lens's width (`lamp_lens_size`, m) on Softest, so a shadow is
## sharp at its foot and soft away from it, as the sun's.
@export var lamp_shadow_blur: float = 1.0
@export var lamp_lens_size: float = 0.35
