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
## A button's size (m: wide, high, deep): a real lift's push button, as its model is built (SM2).
@export var button_size: Vector3 = Vector3(0.052, 0.052, 0.016)
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
## The modelled car, landing doorway, door leaf and push button (SM2, tools/blender/maps/lift.py), drawn in their own
## (linear) colours. The leaf and button are built in a 1 m cube and scaled to each use. The car and the landing are
## built for one well, door and wall (model_well: along the door's face and out from it; model_door: wide and high;
## model_depth: the shaft wall; model_car_height), its door in the face's middle, the call and panel buttons where
## LiftConfig puts them, beside the door's far jamb: a lift that differs, or whose far jamb lies on the model's left
## (a door facing s or w), keeps the plain boxes. An empty path, or one that can't be read, keeps them too.
@export var car_model: String = "res://assets/models/props/lift_car.glb"
@export var landing_model: String = "res://assets/models/props/lift_landing.glb"
@export var leaf_model: String = "res://assets/models/props/lift_leaf.glb"
@export var button_model: String = "res://assets/models/props/lift_button.glb"
@export var model_well: Vector2 = Vector2(2.3, 1.8)
@export var model_door: Vector2 = Vector2(1.1, 2.1)
@export var model_depth: float = 0.3
@export var model_car_height: float = 2.4
## How near a lift's measurements must come to the model's (m) for it to be drawn.
@export var model_fit: float = 0.02
