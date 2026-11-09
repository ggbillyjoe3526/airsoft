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
