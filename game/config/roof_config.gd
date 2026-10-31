class_name RoofConfig
extends Resource
## An indoor field's roof (DR1, MapData.roof_height and roof_lamps), drawn by RoofView: the ceiling's sheeting, the
## steel trusses under it every `truss_step` m across the hall, and the lamp panels. Look only: the light itself is the
## preset's sun, set nearly overhead by the map (its `lighting.overrides`), which the roof never shades. Colours are
## sRGB, the look's (LookConfig.palette), off both team hues (docs/ART.md › Colour).

## The ceiling: its sheeting's paint (in the shared light, so its underside takes the look's shade and the bounce),
## its roughness, and how far past the field's walls it reaches (m), so no gap shows at the eaves.
@export var ceiling_colour: Color = Color8(0x52, 0x4a, 0x72)
@export var roughness: float = 0.9
@export var ceiling_overhang: float = 1.0
## The trusses: across the hall along z, one every `truss_step` m along x, `truss_depth` deep and `truss_width` wide,
## in the look's crimson.
@export var truss_step: float = 8.0
@export var truss_depth: float = 0.5
@export var truss_width: float = 0.25
@export var truss_colour: Color = Color8(0xc2, 0x38, 0x74)
## The lamp panels: hanging `lamp_drop` m under the ceiling, `lamp_size` m (x across, z deep) and 0.08 m thick, glowing
## `lamp_colour` at `lamp_energy` with no real light.
@export var lamp_drop: float = 0.6
@export var lamp_size: Vector2 = Vector2(1.4, 0.5)
@export var lamp_colour: Color = Color(1.0, 0.96, 0.86)
@export var lamp_energy: float = 2.6
