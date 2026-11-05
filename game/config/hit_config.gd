class_name HitConfig
extends Resource
## Hit rules, hit calling and the hit volume (the browser game's config/hits.ts). One BB hit and you're out: call it
## (hand up, "HIT!"), walk off to the dead zone, wait for the next round. Heights are from the feet, standing.

## Friendly hits count, as at a real site.
@export var friendly_fire: bool = true
## Whether a BB that has bounced off a surface knocks someone out (the match's rule, off by default as at most sites);
## off, a ricochet only ticks them and they play on.
@export var ricochets_count: bool = false
## Seconds a hit player stands still with a hand up calling the hit.
@export var call_time: float = 1.4
## Walk-off pace as a share of the run speed, and the longest walk-off (s) before the character leaves the field.
@export var walk_off_speed: float = 0.8
@export var walk_off_time: float = 20.0
## Close enough to the dead-zone spot to stop (m), and to count a route waypoint reached.
@export var dead_zone_arrive: float = 0.15
@export var waypoint_reach: float = 0.4
## A walk-off crouches where a tunnel (NavGrid.low) lies within this far ahead (m, CT1).
@export var walk_off_crouch_ahead: float = 1.0
## Walking off slower than stuck_speed (m/s) for stuck_time (s) counts as blocked: the character leaves the field.
@export var stuck_speed: float = 0.5
@export var stuck_time: float = 0.5
## Leaving the field: the figure fades out over this long (s), then stands in the dead zone.
@export var vanish_time: float = 0.6
## Crouching lowers everything above the hips this far (m).
@export var crouch_drop: float = 0.62
## The head: a sphere covering head, cap and goggles.
@export var head_height: float = 1.62
@export var head_radius: float = 0.13
## The chest with its plate carrier: a capsule this round, its sphere centres from torso_bottom to torso_top.
@export var body_radius: float = 0.2
@export var torso_bottom: float = 1.2
@export var torso_top: float = 1.4
## The hips: two capsules side by side, hips_half_width either side of the middle.
@export var hips_bottom: float = 0.95
@export var hips_top: float = 1.05
@export var hips_half_width: float = 0.06
@export var hips_radius: float = 0.11
## The hip pivot's height standing (m): the legs swing about it, and the upper body tilts about it in a lean.
@export var pivot_height: float = 0.92
## Leaning (Q / E held, game/sim/lean.gd): the upper body's tilt at a full lean (rad). The eyes and BB origin, the hit
## volume, the camera, the drawn figure and what bots see all use this one geometry.
@export var lean_max_angle: float = 0.6
## The top of the body (the shoulders) standing (m): a lean stops before it, or the eyes, come near a wall.
@export var body_top: float = 1.5
## The legs (M85): each swings about its hip, hip_spread to the side, on the walk cycle, and is squashed towards the
## hips when crouching. Heights below the hip pivot; z is forward-negative.
@export var leg_hip_spread: float = 0.095
@export var leg_hip_lift: float = 0.03
@export var leg_knee: float = 0.44
@export var leg_knee_z: float = -0.015
@export var leg_ankle: float = 0.78
@export var leg_thigh_radius: float = 0.085
@export var leg_shin_radius: float = 0.062
## The boot: its middle boot_drop below the hip, from boot_heel to boot_toe (z), as a capsule of boot_radius.
@export var boot_drop: float = 0.874
@export var boot_heel: float = 0.058
@export var boot_toe: float = -0.148
@export var boot_radius: float = 0.05
## Leg swing at full stride (rad), the least speed that swings them (m/s), and the longest step in a tick (m; more is a
## teleport).
@export var leg_swing: float = 0.55
@export var walking_speed: float = 0.2
## The walk cycle's length (m of ground a cycle of two steps covers, GA1) by speed (m/s): standing at cycle_speeds,
## crouched at crouch_cycle_speeds, in line between them and held past the ends, the two blended by the crouch. Each
## gait clip's speed × its seconds (the figures' sidecars: Walk_F, Run_F, Sprint, CrouchWalk), so a planted foot
## stays put on the ground; the first point is a slow step's.
@export var cycle_speeds: PackedFloat32Array = PackedFloat32Array([0.0, 2.3, 4.2, 6.3])
@export var cycle_metres: PackedFloat32Array = PackedFloat32Array([1.0, 1.763, 2.94, 3.99])
@export var crouch_cycle_speeds: PackedFloat32Array = PackedFloat32Array([0.0, 2.1])
@export var crouch_cycle_metres: PackedFloat32Array = PackedFloat32Array([0.8, 1.26])
## Stepping back or aside the standing cycle is this share of the cycle ahead at the same speed (Run_B and Run_L/R take
## shorter, quicker steps than Run_F: each clip's speed × seconds over Run_F's); between, by the step's share each way.
@export var back_cycle_share: float = 0.6190
@export var side_cycle_share: float = 0.6667
## How much of the hips' turn away from standing still's heading the upper body is turned back over a stepping clip's
## hips (GA1; 1: all, so the replica keeps its heading while the pelvis swings and turns into a step aside; 0: none, the
## upper body rides the hips). Applied alike to the hit volume (HitPose) and the drawn figure (FigureBend).
@export var upper_steady: float = 1.0
@export var max_stride: float = 1.0
## The hit area fitted to the drawn figure (HV1): its joints, baked from the figure's own clips (HitFit,
## tools/hit_fit_bake.gd). A character's volume hangs on them (Hitbox.build_volume); the numbers above shape only the
## practice range's plywood figures, and the volume when no fit is given (null).
@export var fit: HitFit = preload("res://game/config/hit_fit.tres")
## Nothing of a character's hit volume reaches further than volume_reach (m) across from its feet, nor below them or
## higher than volume_top over them by more than that: Hitbox.may_touch's quick test before a volume is built.
@export var volume_reach: float = 1.2
@export var volume_top: float = 2.0
## The fitted volume's shapes on the joints (m; tools/hit_fit_tune.gd measures them against the drawn figure): the head
## sphere fit_head_centre of the way from the Head joint to the drawn head's top; the torso two capsules side by side,
## fit_chest_half_width either side and fit_chest_ahead in front of the spine's line, from fit_chest_low of the way from
## the Hips joint to Spine1 up to fit_chest_high of the way from Chest to Neck; each hip a capsule from the thigh's joint
## fit_pelvis_up along the hips; each leg's thigh and shin between its joints, and the boot from fit_boot_heel of the
## foot's length behind the ankle to the toe, fit_boot_drop under them.
@export var fit_head_centre: float = 0.3625
@export var fit_head_radius: float = 0.1275
@export var fit_chest_low: float = 0.3
@export var fit_chest_high: float = 0.16
@export var fit_chest_half_width: float = 0.057
@export var fit_chest_ahead: float = -0.022
@export var fit_chest_radius: float = 0.15
## And two more on the spine's line for its depth (the plate carrier's pouches, the pack): fit_chest_front ahead of it
## and fit_chest_back behind, of fit_chest_depth_radius.
@export var fit_chest_front: float = 0.072
@export var fit_chest_back: float = 0.0895
@export var fit_chest_depth_radius: float = 0.13
@export var fit_pelvis_up: float = 0.045
@export var fit_hips_radius: float = 0.12
@export var fit_thigh_radius: float = 0.085
@export var fit_shin_radius: float = 0.071
@export var fit_boot_heel: float = 0.16
@export var fit_boot_drop: float = 0.0
@export var fit_boot_radius: float = 0.052
