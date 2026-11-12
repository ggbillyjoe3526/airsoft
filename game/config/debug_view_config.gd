class_name DebugViewConfig
extends Resource
## The in-world debug draw (F4 BB paths, F5 hit areas; DebugView): how long a BB's trail is and what colours and
## roundness the lines have. Dev tooling, not a rule: nothing here touches the simulation.

## A BB's trail keeps its last this many seconds of flight (a level shot lands within about 1.5 s, so the default shows
## a whole one; a lobbed BB lives up to BallisticsConfig.max_lifetime and trails its last part).
@export var trail_seconds: float = 2.5
## Ticks per second the trail is recorded at (the simulation's rate).
@export var trail_rate: int = 60
## A BB's trail runs from the first colour (the oldest point, faded out) to the second (the BB).
@export var trail_old_colour: Color = Color(1.0, 0.1, 0.55, 0.15)
@export var trail_new_colour: Color = Color(1.0, 0.1, 0.55, 1.0)
## A trail's width on screen (pixels), at any distance.
@export var trail_width_px: float = 3.0
## A hit volume's lines, by team (Alpha, Beta); a character out of play isn't drawn.
@export var hit_colours: PackedColorArray = PackedColorArray([Color(0.3, 0.7, 1.0, 0.9), Color(1.0, 0.45, 0.2, 0.9)])
## Segments round a wireframe capsule's rings and in each quarter arc of its ends.
@export var ring_segments: int = 8
@export var arc_segments: int = 4
