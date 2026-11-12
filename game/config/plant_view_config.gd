class_name PlantViewConfig
extends Resource
## Plant The Bomb's prop and sites as drawn (PB1). Read by PlantView. The prop is a stand-in built from these sizes
## until its model is made (owner, 2026-11-12: a model after his reference); scenery only, no collider.

## The case: its size lying flat (m: long, tall, deep), hi-vis so it reads on any floor, and its roughness.
@export var case_size: Vector3 = Vector3(0.36, 0.13, 0.26)
@export var case_colour: Color = Color("e0701c")
@export var case_roughness: float = 0.6
## Its bumpers, handle and panel: how far a bumper stands proud of the case and how wide it is (m), the handle's size
## (m) over the long side, the panel's size (m) on the lid and its display's.
@export var trim_colour: Color = Color("1d2026")
@export var bumper_proud: float = 0.008
@export var bumper_width: float = 0.05
@export var handle_size: Vector3 = Vector3(0.14, 0.03, 0.02)
@export var panel_size: Vector3 = Vector3(0.2, 0.006, 0.14)
@export var panel_colour: Color = Color("8a9099")
@export var display_size: Vector3 = Vector3(0.1, 0.004, 0.035)
@export var display_colour: Color = Color("10261a")
## The lamp on the lid: its radius (m) and where it sits on the panel (m from the case's middle, along and across).
@export var lamp_radius: float = 0.016
@export var lamp_at: Vector2 = Vector2(0.06, -0.035)
## The lamp unlit, waiting on the ground or being keyed (amber), armed (red, a flash on each beep), made safe (green).
@export var lamp_off: Color = Color("2a2a2a")
@export var lamp_waiting: Color = Color("ffb020")
@export var lamp_armed: Color = Color("ff3020")
@export var lamp_safe: Color = Color("3ddc61")
## Waiting on the ground it winks every lamp_wait_period s for lamp_wait_on of it; being keyed, every lamp_key_period;
## armed, it flashes for lamp_flash s on each beep.
@export var lamp_wait_period: float = 1.4
@export var lamp_wait_on: float = 0.25
@export var lamp_key_period: float = 0.25
@export var lamp_flash: float = 0.07
## Carried by somebody else, it hangs at the carrier's left hip: this far up, left and forward of the feet (m), tipped
## on its long edge.
@export var carry_at: Vector3 = Vector3(0.26, 0.78, 0.02)
## A site's ring on the floor at its radius: width (m); off-white while nothing happens there, the attackers' colour
## while the bomb is keyed in or armed in it, the defenders' while it is being made safe.
@export var ring_width: float = 0.1
@export var ring_alpha: float = 0.55
@export var ring_idle: Color = Color("f3efe2")
@export var ring_edge: Color = Color("0c1424", 0.55)
@export var ring_edge_width: float = 0.04
## A site's letter, turned to face you, this far over its floor (m; lower under a low ceiling, MapData.pole_height),
## this tall a glyph (font px at letter_pixel m a px), off-white on a dark outline.
@export var letter_rise: float = 2.6
@export var letter_size: int = 96
@export var letter_pixel: float = 0.007
@export var letter_outline: int = 18
@export var letter_colour: Color = Color("f3efe2")
@export var letter_outline_colour: Color = Color("2b303a")
## Going off, a field's prop: this many dust puffs thrown up round it, this far out (m) and up to this high (m).
@export var pop_puffs: int = 10
@export var pop_radius: float = 0.7
@export var pop_height: float = 1.2
