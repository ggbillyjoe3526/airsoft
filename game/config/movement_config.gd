class_name MovementConfig
extends Resource
## Character movement (the browser game's config/movement.ts). Metres, seconds, radians. Read by game/sim/movement.gd.

## Normal pace, walking (walk key held: slow and quiet), sprinting, and moving fully crouched (m/s).
@export var run_speed: float = 4.2
@export var walk_speed: float = 2.3
@export var sprint_speed: float = 6.3
## The normal pace with the replica holstered: faster than the armed run without holding sprint, never past the sprint
## (the browser game's M92 and the owner's Dev 6 note 27). Walking and crouching are not faster for it.
@export var holster_run_speed: float = 5.4
## A sprint with the replica holstered is this much faster than the armed sprint (the owner's 0.1 Dev 1 playtest, note
## 12; the browser game had none: its holster never added to the sprint). Players and bots alike.
@export var holster_sprint_scale: float = 1.1
@export var crouch_speed: float = 2.1
## Pushing through a bush (BP8, owner: slower, and louder, Footsteps): every pace is this share of itself while the body
## is in one, players and bots alike; a body is in a bush when a point this high (m) over its feet is among its leaves
## (Foliage.holds), so brushing a bush's rim or stepping by a low one doesn't count.
@export var bush_speed_scale: float = 0.75
@export var bush_probe_height: float = 0.5
## A Follow me follower further than SquadConfig.catch_up_boost_from behind its leader sprints this much faster than
## the sprint (PlayerCommand.catch_up), so it can close on a leader sprinting at its own top speed (the owner's card
## B6, 2026-11-07); nearer, it matches the leader's pace.
@export var catch_up_sprint_scale: float = 1.2
## Horizontal acceleration on the ground pushing a direction, deceleration letting go, and in the air (m/s²).
@export var ground_accel: float = 45.0
@export var ground_decel: float = 38.0
@export var air_accel: float = 6.0
## Gravity on characters (m/s²; stronger than the BBs' for a snappy, grounded jump) and terminal fall speed (m/s).
@export var gravity: float = 20.0
@export var max_fall_speed: float = 30.0
## Take-off speed (m/s), the least time between jumps (no bunny-hopping) and how long a jump press is kept (s, audit
## SIM-05: pressed just before landing or while standing up, it still jumps).
@export var jump_speed: float = 5.4
@export var jump_cooldown: float = 0.55
@export var jump_buffer: float = 0.1
## Sprint counts only with at least this much forward input.
@export var sprint_min_forward: float = 0.5
## Seconds between standing and fully crouched; at or past crouched_threshold no sprinting or jumping.
@export var crouch_transition_time: float = 0.15
@export var crouched_threshold: float = 0.5
## Rising, an upward move cut below this share of the intended one has hit a ceiling.
@export var ceiling_block_fraction: float = 0.5
## A standing character stays glued to ground this far below its feet (m); a larger drop is a fall (BN1).
@export var ground_settle_distance: float = 0.07
## Movement input below this size is no input.
@export var input_deadzone: float = 0.01
## Ramp pace restoration (audit SIM-17): 0 is off; a climb steeper than ramp_max_rise is a step, not a ramp.
@export var ramp_pace: float = 0.0
@export var ramp_max_rise: float = 0.6
## Furthest the view pitches up or down (rad): just short of straight up.
@export var max_pitch: float = 1.5507963
## Holding walk while aiming down sights creeps at this share of the aiming pace (M84, owner's note 8).
@export var aim_walk_scale: float = 0.6
## Seconds to raise a sight to the eye, and to lower it.
@export var aim_raise_time: float = 0.15
## Seconds from upright to a full lean (Q / E held), and back.
@export var lean_time: float = 0.18
## A leaning head and shoulders stay at least this far from walls (m), so nobody sees or shoots through one.
@export var lean_wall_clearance: float = 0.2
## From this share of a full lean (0..1) you move at walking pace, quietly; less slows you part of the way.
@export var lean_quiet_from: float = 0.5
