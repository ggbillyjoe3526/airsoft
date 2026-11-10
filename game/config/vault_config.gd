class_name VaultConfig
extends Resource
## Vaulting (the browser game's config/vault.ts, M102): Jump pressed at a low obstacle takes you over it in one short,
## committed move (game/sim/vault.gd). Heights are from the floor you take off from (owner, 2026-10-12: obstacles 0.6 to
## 0.95 m; crouch cover stays peek-only). The same press at a ledge of those heights whose top runs on, a platform's edge
## seen from the track, climbs up onto it instead (owner, 2026-11-10, CL1). Metres, seconds, radians. Read through
## SimTuning.vault.

## The obstacle's top over the floor you take off from: the lowest and the highest you vault.
@export var min_height: float = 0.6
@export var max_height: float = 0.95
## The top at most this far over the floor you land on, so 1.2 m crouch cover is never vaulted, not even from a raised
## side, and nothing takes you down off a balcony's edge.
@export var max_landing_height: float = 0.95
## The floor you land on at most this far over the one you take off from (the far side of a slope).
@export var max_climb: float = 0.3
## The deepest obstacle vaulted, along the way you go (a wall, a barrier, a crate; deeper is a platform, climbed).
@export var max_depth: float = 1.0
## A climb (CL1): the top runs on, flat and open, at least this far past the edge along the way you go (a platform, a
## dock; never a crate or a bench, so the ledges climbed are floors, not props).
@export var climb_depth: float = 1.5
## The climb's rise onto the top (hands on the edge, a knee up) takes at least this long.
@export var climb_rise_time: float = 0.34
## Speed onto the top after the rise: the speed you came in at, held between these (m/s).
@export var climb_min_speed: float = 3.0
@export var climb_max_speed: float = 4.0
## How far the body tucks on the way up (0..1, as `tuck`).
@export var climb_tuck: float = 0.5
## How far in front of the body's surface a Jump press finds an obstacle: reach plus reach_per_speed × speed (m/s).
@export var reach: float = 0.55
@export var reach_per_speed: float = 0.12
## The height over the floor the obstacle's face is looked for at (over any kerb you walk onto).
@export var face_probe: float = 0.4
## The top is flat: every sample of it within this of the first.
@export var top_tolerance: float = 0.1
## Spacing of the samples along the top that find its far side.
@export var depth_step: float = 0.1
## Room kept between the far side and the body where it lands.
@export var landing_room: float = 0.12
## The feet pass this far over the top.
@export var clearance: float = 0.08
## The largest angle between the vault's way and the view (70°): nobody vaults sideways or backwards, blind.
@export var max_view_angle: float = 1.2217305
## The rise onto the top takes at least this long.
@export var rise_time: float = 0.16
## Speed across the top: the speed you came in at, held between these (m/s).
@export var min_speed: float = 3.5
@export var max_speed: float = 5.0
## How high the body arcs over the top, on top of the clearance.
@export var arc: float = 0.04
## Speed downwards handed to the fall past the far side: the push off the top (m/s).
@export var drop_speed: float = 2.5
## How far the body tucks over the top, as a crouch (0..1): the eyes, the hit volume and the figure follow it.
@export var tuck: float = 0.6
## The replica stays carried (no firing) through the vault and this long after it.
@export var fire_lockout: float = 0.3
## A body held back this far from its path (by something the plan didn't see) gives up the vault and falls where it is.
@export var blocked_at: float = 0.12
## The gap the planned path keeps from the obstacle's faces: the controller's skin and a hair more.
@export var skin: float = 0.03
## The clearance rays look for anything this far over the feet's path, and this far under the head.
@export var low_ray: float = 0.15
@export var head_ray: float = 0.05
## The side rays run this far inside the body's radius, so a wall it brushes along doesn't count.
@export var side_inset: float = 0.04
## The scan line runs this far over the highest top vaulted, so a top of exactly max_height is under it.
@export var scan_above: float = 0.02
