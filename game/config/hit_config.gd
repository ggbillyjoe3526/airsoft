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
## A walk-off crouches where a tunnel (NavGrid.low) lies within this far ahead (m, CR1).
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
## Leg swing at full stride (rad), strides per metre, the least speed that swings them (m/s), and the longest step in a
## tick (m; more is a teleport).
@export var leg_swing: float = 0.55
@export var strides_per_metre: float = 0.75
@export var walking_speed: float = 0.2
@export var max_stride: float = 1.0
