class_name LiftViewConfig
extends Resource
## How the lifts are drawn (MT2, LiftView): the steel's finish, the car's walls and ceiling strip, the doors' leaves,
## the buttons, the panel's stop names and the car's lamp. Its colours are MapStyle's (lift_car, lift_door,
## lift_button, lift_lit, lift_strip). Part of PlayTuning.

## The steel's roughness and metalness, the car's and the doors' alike: painted, not mirror steel, as underground
## there's no sky for it to mirror (any metalness shows the sky's blue on the car's roof, or black on the doors).
@export var roughness: float = 0.55
@export var metallic: float = 0.0
## The car's walls' thickness (m), inside its well, and its ceiling strip's size (m: across, deep, along).
@export var wall_thickness: float = 0.04
@export var strip_size: Vector3 = Vector3(0.9, 0.03, 0.25)
## Each door leaf's thickness and the gap left at its edges (m), so the two read as two.
@export var leaf_thickness: float = 0.04
@export var leaf_gap: float = 0.01
## A button's size (m: wide, high, deep).
@export var button_size: Vector3 = Vector3(0.09, 0.09, 0.03)
## The panel's stop names: beside their buttons by label_beside, off the wall by label_off (m), in this size.
@export var label_beside: float = 0.08
@export var label_off: float = 0.01
@export var label_pixel_size: float = 0.0012
@export var label_font_size: int = 32
@export var label_colour: Color = Color(0.12, 0.12, 0.12)
## The car's lamp under its ceiling strip: this far under it (m), its reach (m), brightness and colour.
@export var lamp_drop: float = 0.1
@export var lamp_range: float = 3.0
@export var lamp_energy: float = 1.2
@export var lamp_colour: Color = Color(1.0, 0.96, 0.88)
## Each car's reflection probe (with Reflections on): an interior one over the car, so its steel mirrors the car and
## its ambient is this warm grey (linear) at this energy, not the sky's blue (the shafts lie outside every area's
## probe).
@export var probe_ambient: Color = Color(0.42, 0.4, 0.37)
@export var probe_ambient_energy: float = 1.0
