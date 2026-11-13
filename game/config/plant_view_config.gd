class_name PlantViewConfig
extends Resource
## Plant The Bomb's prop and sites as drawn (PB1). Read by PlantView. The prop is the bomb model built from the owner's
## photos (PB2: assets/models/bomb/, tools/blender/bomb/bomb.py); scenery only, no collider.

## The bomb's bounds lying on the ground (m: across, tall, long), its lamp lit by the floor's light at its height. A
## model that won't load draws a box this size, hi-vis yellow, at this roughness.
@export var case_size: Vector3 = Vector3(0.113, 0.12, 0.27)
@export var case_colour: Color = Color("d9b81e")
@export var case_roughness: float = 0.6
## The wire cutters while someone makes it safe: at the model's `Cut` mark, coming in from this way (the bomb's own
## axes; normalised), each half opening this far (rad) and back, this many snips a second.
@export var cutters_from: Vector3 = Vector3(0.55, 0.75, -0.35)
@export var cutters_open: float = 0.2
@export var cutters_snips: float = 1.5
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
## Carried by somebody else, it rides at the carrier's left hip: this far up, left and forward of the feet (m), on its
## side with its keypad out.
@export var carry_at: Vector3 = Vector3(0.19, 0.9, 0.04)
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
