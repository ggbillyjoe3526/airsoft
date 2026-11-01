class_name SquadConfig
extends Resource
## Squad orders for bot teammates (the browser game's config/squad.ts SQUAD_ORDERS, M22): where Follow me, Hold here and
## Regroup put them, and how followers keep up. Part of BotConfig (bot_tuning.tres).

## Follow me: each teammate keeps a spot this far behind the giver (m), either side of their heading.
@export var follow_distance: float = 3.2
## How far either side of straight behind the giver the follow spots are (degrees).
@export var follow_spread_deg: float = 40.0
## Each further pair of followers keeps this much further back (m).
@export var follow_row_gap: float = 1.6
## Where a follow spot isn't walkable (a wall, a drop), it is tried straight behind the giver, then this much closer
## (m).
@export var follow_fallback_step: float = 1.5
## A follow spot must also be in a straight walkable line from the giver (not behind a wall). That line starts at the
## nearest walkable ground within this (m) when the giver stands inside the margin bots keep from walls and edges.
@export var follow_line_snap: float = 0.8
## Close enough to the follow spot to stop there while the giver stands still (m).
@export var follow_arrive: float = 1.2
## Settled at the spot, followers stay put until it is this much further off (m), so they don't shuffle.
@export var follow_settle: float = 0.8
## Making for the spot with the giver still, followers run while further than this from it (m), and walk the last
## stretch (the browser's three times follow_settle).
@export var follow_run_from: float = 2.4
## More than this behind their spot along the giver's way (m), followers go a pace faster than the giver until back on
## it; more than this ahead of it, a pace slower until back on it.
@export var catch_up_gap: float = 1.5
## With the giver on the move, followers head the giver's way plus this much (1/s) of the gap to their spot.
@export var follow_pull: float = 1.5
## Further than this from the giver (m), followers sprint to catch up (otherwise they keep the giver's pace: walk, run
## or sprint), until rush_ease inside it.
@export var catch_up: float = 8.0
@export var rush_ease: float = 3.0
## Hurrying followers sprint while at least this much of their move is forward (bots' own gate is stricter).
@export var sprint_forward: float = 0.6
## The giver's heading is the way they move, once they move at least this fast (m/s); standing still keeps it.
@export var heading_speed: float = 1.0
## Followers' idea of the giver's heading turns at most this fast (rad/s), so their spots swing round rather than jump.
@export var heading_turn_rate: float = 1.5
## A giver crouched more than this (0 to 1) moves at a walk for the followers' pace.
@export var crouched_pace: float = 0.5
## Where followers look once at their spot, turned from the giver's heading (degrees): the first straight behind, the
## next to either side, so they cover the giver's back.
@export var follow_watch_deg: PackedFloat32Array = PackedFloat32Array([180.0, 90.0, -90.0])
## Hold here: the spot the giver looks at, up to this far (m); nothing that close: each holds where it stands.
@export var hold_range: float = 40.0
## Held spots stop this far short of the wall the giver looks at (m).
@export var hold_wall_gap: float = 0.6
## Teammates holding a spot stand this far apart, across the giver's line of sight (m).
@export var hold_spacing: float = 1.4
## Close enough to the held spot to stop (m).
@export var hold_arrive: float = 0.7
## Hold here again, looking at least this far from the held spot (m), moves it; nearer cancels the order.
@export var hold_move: float = 3.0
## Go there (FM1) once all are there holds as a Hold here, but only while something happens (BQ1): this long (s) with
## no holder seeing an enemy, fighting, in cover or with one seen or heard within go_there_contact_radius (m) of
## where it stands, and they go back to the team plan. A Hold here given as one never lapses.
@export var go_there_quiet: float = 30.0
@export var go_there_contact_radius: float = 30.0
## Regroup: teammates sprint back to the giver and follow once this close (m).
@export var regroup_arrive: float = 4.0
