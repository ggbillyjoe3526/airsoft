class_name GatePaddlesConfig
extends Resource
## How a station's ticket gates' paddle doors are drawn and swung (SM3, GatePaddles): the owner's gates have a paddle
## each side of a lane, shut across it and swinging open as someone walks up. Look only: a lane's box is open, so
## nothing here stops a body or a BB. Part of PlayTuning.

## The gate model whose blocks stand the paddles (PropDressConfig.models' name) and the paddle's own model: its post's
## axis at its origin, its blade along +x (tools/blender/maps/ticket_gate.py).
@export var gate_model: StringName = &"ticket_gate"
@export var paddle_path: String = "res://assets/models/props/gate_paddle.glb"
## Two gates stand a lane apart when the gap between them is at most this (m) and they overlap along it.
@export var max_lane: float = 1.5
## A paddle's arm swings from this far (m) off its gate's side (less than 0: inside the slot housing, hidden), and a
## lane's two shut paddles leave this gap between them.
@export var post_off: float = -0.03
@export var middle_gap: float = 0.03
## A lane's paddles open while anyone (a player or a bot, hit or not) stands within `reach` m of the lane's middle
## across the floor and `reach_height` m of its floor up or down, and shut again once nobody does.
@export var reach: float = 1.6
@export var reach_height: float = 1.5
## Seconds a paddle takes to swing all the way open or shut, a quarter turn towards the gate's facing (the way in).
@export var swing_time: float = 0.35
## The paddles' finish: their moulded plastic a little glossier than the props' (PropDressConfig.roughness), so the
## lamps catch their shape; and their wear.
@export var roughness: float = 0.45
@export var wear: float = 1.0
