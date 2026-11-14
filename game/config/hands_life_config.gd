class_name HandsLifeConfig
extends Resource
## The life in the replica in your hands beyond its pose (HA1, the owner: "go over all first person view animations and
## make them higher quality"): it bobs with your steps, breathes while you stand, leans into a strafe, lags a jump,
## dips as you land and crouch, flicks and rolls on a spring with each shot and each draw, and cants as the sight comes
## up. Metres, radians, seconds, in the camera's space (x right, y up, -z forward). Read by HandsMotion; ReplicaView
## draws it. Reduced motion draws MotionScale's sway share of all but the shot's spring, which takes its kick share.

## Steps: the ground one whole bob covers (two steps, m), the pace it is whole at and the pace it starts from (m/s),
## how fast it comes and goes (1/s), and at most how many times whole it gets (a sprint).
@export var bob_stride: float = 2.7
@export var bob_speed: float = 4.2
@export var bob_from: float = 0.3
@export var bob_rate: float = 8.0
@export var bob_most: float = 1.5
## A whole bob's sway to each side and lift (m), and its roll and tip (rad).
@export var bob_side: float = 0.0034
@export var bob_lift: float = 0.0026
@export var bob_roll: float = 0.010
@export var bob_tip: float = 0.004
## Breathing: a breath's length (s), its lift and slow sideways drift (m) and its tip (rad).
@export var breath_period: float = 3.8
@export var breath_lift: float = 0.0014
@export var breath_drift: float = 0.0009
@export var breath_tip: float = 0.0035
## Moving: at lean_speed (m/s) across, the replica rolls lean_roll (rad) into the strafe and trails lean_trail (m)
## behind it; at that pace ahead it sits lean_back (m) nearer you (back-pedalling, further); a sprint leans it bob_most
## times as far at most. It follows at lean_rate (1/s).
@export var lean_speed: float = 4.2
@export var lean_roll: float = 0.032
@export var lean_trail: float = 0.005
@export var lean_back: float = 0.005
@export var lean_rate: float = 9.0
## Up and down it rides a spring (x: its rate, rad/s; y: its damping, 1 just not bouncing). In the air it trails your
## rise and fall by air_lift (m per m/s), air_most (m) at most. Landing from a fall faster than land_from (m/s) knocks
## it down land_dip (m/s per m/s of fall), land_most (m/s) at most. A whole crouch pushes it crouch_push (m/s) the way
## it trails your body.
@export var lift_spring: Vector2 = Vector2(17.0, 0.5)
@export var air_lift: float = 0.0035
@export var air_most: float = 0.018
@export var land_from: float = 1.5
@export var land_dip: float = 0.085
@export var land_most: float = 0.5
@export var crouch_push: float = 0.16
## Its tip and its roll ride another spring. Each shot flicks the muzzle up shot_flick (rad/s) and rolls it shot_roll
## (rad/s), to one side and then the other; a draw rolls it draw_roll and tips it down draw_tip (rad/s) as it arrives.
@export var turn_spring: Vector2 = Vector2(26.0, 0.45)
@export var shot_flick: float = 0.55
@export var shot_roll: float = 0.30
@export var draw_roll: float = 1.3
@export var draw_tip: float = 0.9
## As the sight comes up or goes down it cants this much (rad) at the middle of the way.
@export var aim_cant: float = 0.07
## With the sight raised, the share of all of this left (the sight stays on the view's middle).
@export var aimed: float = 0.15
