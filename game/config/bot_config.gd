class_name BotConfig
extends Resource
## How the bots play, shared by every difficulty (the browser game's config/botsSenses.ts, botsMovement.ts,
## botsSquad.ts and squad.ts, Elimination and Attack / Defend): what they see and hear and how soon, how they aim and
## fire, lanes, cover, searching, hunting, the pole, squad orders and the magazine hand-off. How well a bot plays is its `skill`.
## bot_tuning.tres is the instance the game loads. Ranges are Vector2(min, max), drawn from each bot's own seeded
## stream.

const DEFAULT_PATH := "res://game/config/bot_tuning.tres"

## Each level's skill (DECISIONS 2026-10-01: difficulty is skill plus a few tactics, never different senses). `skill` is
## Easy's, the baseline every level is tuned from (owner, 2026-10-06; Normal's until the levels moved up, 2026-10-25).
@export var skill: BotSkill = BotSkill.new()
@export var normal_skill: BotSkill = BotSkill.new()
@export var hard_skill: BotSkill = BotSkill.new()
## Squad orders: where bot teammates go when a teammate orders them (SquadOrders).
@export var squad: SquadConfig = SquadConfig.new()
## Callouts: how the bots' calls are read off what they do (Callouts; the words and pace are data/callouts.md).
@export var callouts: CalloutConfig = CalloutConfig.new()

@export_group("Senses")
## Seconds between sight checks per bot (staggered across bots): ten a second (DECISIONS 2026-09-30).
@export var think_interval: float = 0.1
## Field of view (degrees, full angle) and how far a bot makes someone out (m).
@export var fov_deg: float = 120.0
@export var view_distance: float = 40.0
## Anyone this close is noticed whichever way the bot faces (m): footsteps, breathing, kit. Bushes hide no one this
## close.
@export var close_awareness: float = 2.5
## How much bush a bot sees someone through (m of leaves along the line, WL5, FO1): someone at the edge of a bush is
## seen, deeper in or behind one is not. The same as what stops a BB (BallisticsConfig.leaf_stop_depth; a test holds
## them equal): if you can't see through it, a BB can't get through.
@export var foliage_see_through: float = 0.6
## How much smoke a bot sees someone through (m of cloud along the line, by its density; Grenades.smoke_depth, SF1):
## close by in a cloud, or through its thin edge, it still makes someone out. Up close as anywhere: smoke is thick.
@export var smoke_see_through: float = 0.8
## How far gunfire carries (m).
@export var hearing_distance: float = 22.0
## How far an enemy's footsteps carry (m): running, sprinting, a landing, a vault (DECISIONS 2026-10-13). Walking and
## moving crouched are silent.
@export var footstep_hearing_run: float = 11.0
@export var footstep_hearing_sprint: float = 16.0
@export var footstep_hearing_land: float = 12.0
@export var footstep_hearing_vault: float = 18.0
## How far a rattling magazine carries (m), heard even walking (the browser game's footstepHearingRattle).
@export var footstep_hearing_rattle: float = 7.0
## A sound with a wall between carries only this share of its range: bots hear through walls no better than you do.
@export var wall_hearing: float = 0.6
## Walls are looked for along rays from the ear to these heights over the sound's source (m): its knees and head. The
## share blocked is how far the sound is muffled.
@export var hearing_ray_heights: PackedFloat64Array = PackedFloat64Array([0.45, 1.5])
## A heard position is off by up to this share of the distance.
@export var hearing_error: float = 0.3
## Gunfire heard within this long (s) of the last, from about the same place, keeps the same guess of where it is.
@export var hearing_contact_time: float = 2.0
## How long (s) a bot keeps after someone it lost sight or sound of before it forgets them.
@export var memory_time: float = 6.0
## How long (s) a bot keeps a teammate's ping in mind (PN1, Pings): longer than memory_time, so a far ping is still
## worth the walk; real news of an enemy (a sighting, a noise) writes over it sooner.
@export var ping_memory: float = 20.0
## An enemy BB landing this close (m) puts a bot under fire for suppression_time (s): it wants cover.
@export var suppression_radius: float = 1.6
@export var suppression_time: float = 0.4
## Seeing its target with no shot at it for this long (s: glass, BQ1, or more leaves than it shoots through, in the way),
## a bot stops trading looks and goes round to them as to someone it lost sight of.
@export var no_shot_move_after: float = 1.5
## The "What got you" card counts you as moving at a hit from this speed along the floor (m/s): a crouched creep is
## about 1, standing still 0 (the browser game's WHAT_GOT_YOU.movingSpeed).
@export var hit_moving_speed: float = 0.5

@export_group("Aim")
## Seconds someone can be out of sight and still be the same contact (no new reaction delay).
@export var contact_grace: float = 1.2
## A bot stays on its target unless another in sight is at least this much closer (m).
@export var target_switch_margin: float = 3.0
## A fresh contact's first aim is at least this share of its full error off, to one side, tilted at most this far from
## level (degrees): the first BBs whizz past a shoulder rather than land on the legs or the head.
@export var aim_first_error_min: float = 0.6
@export var aim_first_error_tilt_deg: float = 30.0
## How much of the reaction delay the aim already settles over (0..1): at 0 the bot walks its BBs onto the target once
## it opens fire, a fair moment to answer.
@export var aim_settle_while_reacting: float = 0.0
## How fast the aim error drifts (Hz), and how fast it eases to each new drift goal (a multiple of that rate).
@export var aim_wander_rate: float = 0.7
@export var aim_wander_settle: float = 3.0
## Fires only with its view within this of its (erroneous) aim point (degrees).
@export var fire_cone_deg: float = 3.0
## Aims at this share of the target's hit-volume height (the chest), or its head when only that shows.
@export var aim_height_fraction: float = 0.7
@export var head_height_fraction: float = 0.93

@export_group("Firing")
## Swaps a magazine below this share of a full one when nobody is in sight.
@export var tactical_reload_fraction: float = 0.35
## Never fires with a teammate this close to the line of fire (m, beyond their hit volume), widened by this many of the
## replica's spreads per metre flown, nor anywhere a teammate in play could run to at this pace (m/s) by the time the
## BBs pass (BotCombat, WL10; one sprinting faster, also where its pace and route take it).
@export var friendly_margin: float = 0.3
@export var friendly_spread_sigmas: float = 2.0
@export var friendly_mate_speed: float = 4.2
## A miss flies on: a teammate up to this far (m) past the target counts too, and up to friendly_carry from the shooter
## however near the target (a BB fired level from the eye lands 53 m out from the stock AEG, 50 from the cyber, 40 from
## the pistol; more down a slope: Woodland's guards saw a teammate 33 m past a target 23 m off knocked out, WL10),
## unless a wall stops the line first.
@export var friendly_beyond_target: float = 25.0
@export var friendly_carry: float = 60.0
## What the aim line meets is a wall only if it also stands this much higher there (m): BBs sail over low cover.
@export var friendly_wall_clearance: float = 0.6
## That raised check looks from this far (m) before the point, to as far past it.
@export var friendly_wall_probe: float = 0.2
## A teammate up to this far (m) past where the line meets a wall still counts: a grazed corner lets BBs past.
@export var friendly_past_wall: float = 0.8
## Holds fire when its aim line meets a wall within this share of the distance to the target.
@export var aim_wall_fraction: float = 0.5
## Hold fire when the line to the target runs through more than this much bush (m of leaves, FO1): BBs pushed that far
## in come out well off their line or not at all, so the bot waits for a clearer shot.
@export var foliage_fire_through: float = 0.25

@export_group("Lanes and holds")
## Each round a team splits its bots one to a lane, pairs two on one, or stacks them all on one, by these weights.
@export var plan_split_weight: float = 0.4
@export var plan_pair_weight: float = 0.4
@export var plan_stack_weight: float = 0.2
## Bots sharing a lane set off this long apart (s).
@export var lane_follow_delay: Vector2 = Vector2(0.8, 1.6)
## Lane points move up to this far at random (m, onto walkable ground on their floor), in this many tries.
@export var lane_jitter: float = 1.2
@export var lane_jitter_tries: int = 6
## Bots sharing a lane: a lane point with a teammate holding there (or heading there to hold) within lane_hold_spacing
## (m) moves lane_hold_offset (m) to one side, across the way to the enemy, so the two hold side by side.
@export var lane_hold_spacing: float = 1.5
@export var lane_hold_offset: float = 1.0
## A bot more than this far ahead (m, towards the enemy) of its rearmost bot teammate waits at lane points, for at most
## team_wait_max (s) a point.
@export var team_spread: float = 7.0
@export var team_wait_max: float = 4.0
## Holding at a lane point: after this long (s) it crouches, if its crouched eyes still see this far (m) towards the
## enemy, and sweeps its view this far (degrees) either side of the enemy's way over this period (s).
@export var hold_crouch_delay: float = 0.4
@export var hold_look_distance: float = 8.0
@export var hold_sweep_deg: float = 35.0
@export var hold_sweep_period: float = 4.0
## Crouch cover by a lane point: within this radius (m), hiding it from a point this far (m) towards the enemy.
@export var hold_cover_radius: float = 3.0
@export var hold_cover_threat_distance: float = 10.0
## Sprints along a route when nobody was seen or heard for this long (s), heading mostly forward (this much input).
@export var sprint_when_calm_for: float = 3.0
@export var sprint_forward: float = 0.9
## The holster (the browser game's botHolster.ts): a bot puts its replica away after sprinting holster_after seconds
## without a break in its own half, nobody seen or heard for holster_calm_for seconds; it draws again at once on a
## threat, in the enemy's half or for a reload, or holster_draw_after seconds after the sprint stops.
@export var holster_calm_for: float = 5.0
@export var holster_after: float = 1.5
@export var holster_draw_after: float = 0.5

@export_group("Routes")
## Waypoints count as reached within this distance (m).
@export var waypoint_reach: float = 0.45
## Walking slower than this (m/s) for stuck_time (s) along a route means blocked: plan again.
@export var stuck_speed: float = 0.3
@export var stuck_time: float = 1.0
## A route to a goal that moved this far (m) is planned again.
@export var replan_distance: float = 2.5
## A goal with no route isn't asked for again within this long (s).
@export var route_retry_delay: float = 1.0
## A vault link (NavVaults) costs its length plus this (m) in a route: it is taken only where it saves more walking
## round (the browser game's vault price, M102).
@export var vault_price: float = 3.0
## A bot held up on a vault leg (stuck_time) plans its routes without vaults for this long (s).
@export var vault_retry_delay: float = 6.0
## A bot this far off the leg it walks (m) checks the way on for a drop before walking it.
@export var route_off_leg: float = 0.2
## It asks again for a drop off its leg only once it has moved this far (m) from where it last asked: a fresh route
## from the same spot is the same route, and it walks that one (stuck_time still catches a real hold-up).
@export var off_leg_replan_moved: float = 0.5
## A bot crouches when a floor only a crouched body fits over (a tunnel, NavGrid.low) lies within this far ahead (m):
## down before its head would meet the roof at a run.
@export var low_crouch_ahead: float = 1.0
## Steps off a route (sidesteps, the last bit onto a lean spot) look this far ahead for a drop or a wall (m).
@export var edge_lookahead: float = 0.6
## Keeping apart (bodies pass through each other in the physics): a bot steers off anyone in play closer than this (m).
@export var separation_distance: float = 0.8

@export_group("Cover")
## Cover search: random spots within this radius (m) and no nearer than the minimum, how many, and the least time
## between searches (s).
@export var cover_radius: float = 8.0
@export var cover_min_radius: float = 1.0
@export var cover_candidates: int = 28
@export var cover_cooldown: float = 1.5
## Skips spots this share of the way (or this many metres) closer to the threat: no running at it for cover.
@export var cover_toward_threat_fraction: float = 0.7
@export var cover_toward_threat_metres: float = 2.0
## Crouch cover and lean spots score as if this much closer (m): you can stand up or lean out and shoot back.
@export var crouch_cover_bonus: float = 4.0
@export var lean_cover_bonus: float = 1.5
## Behind a low block: this far past its far side (m), or the second try further back.
@export var low_cover_gap: float = 0.45
@export var low_cover_gap_far: float = 0.8
## A block stands on the floor if its bottom is within this of the floor under it (m), or sunk into it by no more than
## low_cover_floor_sink: a piece on sloping ground (Woodland's) is sunk so no gap shows under its low side.
@export var low_cover_floor_gap: float = 0.05
@export var low_cover_floor_sink: float = 0.4
## Lean spots at tall blocks' corners: this far into the corner's shadow (m), stepped back along the sight line in steps
## of this (m) until clear of the block. Further in than the body's radius, less than a full lean moves the eyes.
@export var lean_spot_inset: float = 0.27
@export var lean_spot_step: float = 0.225
## A lean needs this much room past the leaned eyes (m).
@export var lean_room_margin: float = 0.2
## Spots teammates hold or head for are kept this far apart, beyond two body radii (m).
@export var cover_spacing_margin: float = 0.1
## Close enough to settle in (m); a lean spot only right on it.
@export var cover_arrive: float = 0.9
@export var lean_spot_arrive: float = 0.2
## Ducked this long before looking again (s).
@export var cover_time: Vector2 = Vector2(1.2, 2.4)
## Peeking over crouch cover or round a corner: how many looks, how long each lasts with nobody in sight, how long it
## stays up to fight once someone is, and how long it stays down between (s).
@export var peek_count: Vector2 = Vector2(2, 4)
@export var peek_look: Vector2 = Vector2(0.6, 1.1)
@export var peek_fight: Vector2 = Vector2(1.2, 2.4)
@export var peek_down: Vector2 = Vector2(0.8, 1.6)
## Gives up on reaching cover after this long (s).
@export var cover_max_time: float = 5.0
## A fresh contact at range sends it to crouch cover within this radius (m) first.
@export var contact_cover_radius: float = 3.5
## A whole cover episode ends after this long (s).
@export var cover_episode_max: float = 12.0
## Settled in cover this long (s) and still in sight of the enemy: the spot doesn't hide it, so it fights.
@export var cover_settle: float = 0.5

@export_group("Fighting and searching")
## Sidesteps for this long before switching side (s), at this share of full input, keeping the target in sight from eyes
## moved this far (m) that way.
@export var strafe_time: Vector2 = Vector2(0.5, 1.2)
@export var strafe_input: float = 0.6
@export var strafe_sight_offset: float = 0.6
## At the end of a search, crouches and looks round for this long (s), this far (degrees) either side of its arrival.
@export var search_look: Vector2 = Vector2(1.0, 2.0)
@export var search_look_deg: float = 90.0
## Flanking (the skill's flank_chance): a search of a spot this far away (m) first goes to a point this far to one side
## (m), this far short of the spot (m).
@export var flank_min_distance: float = 8.0
@export var flank_offset: float = 4.0
@export var flank_back: float = 2.0

@export_group("Held angles and slicing")
## Held angles (BotSkill.holds_angles): a fan of this many rays over this many degrees across the enemy side at
## standing eye height. An edge is a ray stopped by a wall beside one running at least angle_jump further (m); it aims
## angle_past beyond the wall's end (m) at head height. Walls nearer than angle_min_distance don't count, rays stop at
## angle_max_distance, and corners about angle_best_distance away score best (m). It keeps the best few at least
## angle_separation_deg apart.
@export var angle_fan_deg: float = 140.0
@export var angle_rays: int = 29
@export var angle_jump: float = 2.5
@export var angle_past: float = 0.6
@export var angle_min_distance: float = 2.0
@export var angle_max_distance: float = 30.0
@export var angle_best_distance: float = 10.0
@export var angle_separation_deg: float = 15.0
## Holding, it switches between its angles every this many seconds; it looks for them afresh every angle_refresh
## seconds, or once it has moved angle_move_refresh (m).
@export var angle_switch_time: float = 3.0
@export var angle_refresh: float = 2.0
@export var angle_move_refresh: float = 0.5
## Someone appearing within this many degrees of where a bot aims counts as pre-aimed (BotSkill.pre_aim_reaction_time).
@export var pre_aim_cone_deg: float = 6.0
## Slicing a corner, it leans out past it once within this many metres of it.
@export var slice_lean_distance: float = 6.0

@export_group("Team play")
## A teammate's hit call heard (BotSkill.team_play): for this long (s) it goes to trade, running there, peeking first
## from cover within trade_cover_radius (m) of where it is if there is any.
@export var trade_time: float = 4.0
@export var trade_cover_radius: float = 6.0
## Moving in pairs: at a lane point it waits while a lane partner within bound_distance (m) moves, for at most
## bound_wait_max (s), so one covers while the other goes.
@export var bound_distance: float = 15.0
@export var bound_wait_max: float = 8.0
## Crossfire (Attack / Defend): of two defenders at one lane point, the second holds as far from the lane's next point
## (the choke) as its own point, swung round the choke by crossfire_turn_deg (degrees: the smaller end, the middle, then
## the larger, either way), on the same floor with a clear view of the choke, so the two see it from angles at least
## crossfire_min_deg apart.
@export var crossfire_turn_deg: Vector2 = Vector2(35.0, 65.0)
@export var crossfire_min_deg: float = 30.0
## With this many seconds left or fewer and fewer of its team in play than of the other, it stops holding its lane and
## goes looking for them.
@export var late_push_time: float = 30.0
## Pressing the advantage (BotSkill.presses_advantage, BQ3): this many more eliminations ahead: the other team's
## players out less its own.
@export var press_margin: int = 2

@export_group("Personalities")
## A personality that pushes in (bots.md) closes in on its target as it sidesteps, until this far from it (m).
@export var push_distance: float = 8.0
## An anchor holding short of the middle goes after someone seen or heard within this far of its post (m); further off,
## it watches that way from its post.
@export var anchor_search_radius: float = 12.0
## ...and no further above or below it than this (m): a noise on another floor is watched from the post, not chased down
## the stairs (a post on an upper floor).
@export var anchor_search_rise: float = 2.0
## A kit whose Suits names a bot's personality weighs this many times its weight against the other kits with Suits
## (BotKits.weights), so the level decides how often a bot carries gear and its personality which.
@export var kit_suit_lean: float = 3.0

@export_group("Attack / Defend")
## Defending, a bot holds the first point of its lane (nearest home), or with this chance the second; the first of
## two on a shared lane always holds the second.
@export var defend_forward_chance: float = 0.3
## A defender goes after someone seen or heard within this far of the pole (m, and on the pole's floor:
## anchor_search_rise); further off, it watches that way from its post.
@export var defend_search_radius: float = 12.0
## Once the flag is off the bottom, this many defending bots in play nearest the pole go to pull it down; the rest hold.
@export var retakers: int = 2
## The attacker raising the flag keeps the rope unless another in flag mode is this much nearer the pole (m).
@export var raiser_switch_margin: float = 3.0
## The raiser stands within this of the pole (m, inside the flag's reach), and counts as there within flag_arrive.
@export var flag_stand: float = 0.8
@export var flag_arrive: float = 0.5
## Attackers not raising guard the pole: crouch cover within flag_guard_radius (m) of it, hidden from a point
## flag_guard_threat_distance (m) from it towards the defenders (or where someone was last seen or heard).
@export var flag_guard_radius: float = 6.0
@export var flag_guard_threat_distance: float = 10.0

@export_group("Overtime flag")
## Elimination's overtime flag (OV2; the browser game's botsSquad.ts OVERTIME): each bot sets off for its foot after its
## skill's overtime_reaction (a touch wins); one that watches the flag first (bots.md) guards it from cover as an
## attacker guards the pole, until this many seconds of the overtime are left or fewer, when every bot goes in.
@export var overtime_go_by: float = 10.0
## A bot whose flank roll (the skill's flank_chance, once an overtime) came up, at least overtime_flank_min_distance (m)
## from the flag, goes round by a point overtime_flank_offset (m) to one side of the straight way and
## overtime_flank_back (m) short of the flag first, so it comes at the flag from the side.
@export var overtime_flank_min_distance: float = 15.0
@export var overtime_flank_offset: float = 6.0
@export var overtime_flank_back: float = 6.0

@export_group("Magazine hand-off")
## The bots' side of the hand-off (MH2, BotMagShare; the browser game's config/magShare.ts): a bot bringing one sprints
## while further than mag_hurry_distance (m) from the teammate, and walks on to within mag_walk_up_to (m) while it can't
## toss yet; a bot that asked a player walks up to within mag_walk_up_to of them and waits. The rules (who is asked,
## reach, flight, gaps) are the simulation's (MagShareConfig).
@export var mag_hurry_distance: float = 8.0
@export var mag_walk_up_to: float = 3.0
## A bot presses the hand-off no more often than this (s), so a press the simulation refuses isn't repeated each tick.
@export var mag_press_gap: float = 1.0
## Dev settings › Bots run low on BBs: this long (s) into each round, once the teams have spread out, one bot a team in
## turn is put on its last magazine (DevCheats.run_low), so the giver's walk over shows.
@export var mag_dev_low_after: float = 8.0

@export_group("Hunting")
## Once its lane is swept a bot hunts: the field in square sectors (m), the stalest of this many random spots (each
## drawn in at most this many tries), each metre nearer the middle counting like this many seconds staler.
@export var hunt_sector_size: float = 4.0
@export var hunt_candidates: int = 12
@export var hunt_tries_per_candidate: int = 20
@export var hunt_middle_bias: float = 1.0
## A sector counts as checked once a bot sees a spot in it empty within this range (m).
@export var hunt_clear_range: float = 19.0

@export_group("Smoke and flash bombs")
## When a bot throws its bombs (SF2, BotBombs; the rules are the simulation's GrenadeConfig). It rolls the skill's chance
## at most every bomb_roll_gap s while it may. It turns to the throw at its turn rate and presses once within
## bomb_aim_within_deg, giving up after bomb_aim_time s; it aims bomb_aim_short of the way, for the bounce and roll, and
## throws only along an arc clear of the level, checked in bomb_arc_steps rays.
@export var bomb_roll_gap: float = 1.5
@export var bomb_aim_within_deg: float = 4.0
@export var bomb_aim_time: float = 1.0
@export var bomb_aim_short: float = 0.75
@export var bomb_arc_steps: int = 6
## Smoke: in cover with an enemy BB close within smoke_under_fire_for s, at a threat smoke_min_distance to
## smoke_max_distance m away and no cloud between them yet, it smokes the line to it: smoke_at_share of the way, at most
## smoke_reach m out.
@export var smoke_under_fire_for: float = 2.0
@export var smoke_min_distance: float = 8.0
@export var smoke_max_distance: float = 35.0
@export var smoke_at_share: float = 0.5
@export var smoke_reach: float = 12.0
## Flash: searching toward a spot flash_min_distance to flash_max_distance m away that it can't see (the eyes'
## flash_spot_height m over it), it flashes there, or at the first of its route's next flash_route_points points the bang
## (flash_bang_height m up) would be seen from there; never where a teammate is within flash_mate_clear m of the bang,
## or within flash_mate_sight m with a clear line to it. Then it looks away until flash_wait_after s past the bang, and
## pushes.
@export var flash_min_distance: float = 4.0
@export var flash_max_distance: float = 16.0
@export var flash_spot_height: float = 1.5
@export var flash_mate_clear: float = 8.0
@export var flash_mate_sight: float = 16.0
@export var flash_route_points: int = 3
@export var flash_bang_height: float = 0.3
@export var flash_wait_after: float = 0.3
## Hearing them (BotHearing): an enemy's flash bang out to bang_hearing m, a smoke's pop out to pop_hearing m, heard as
## news of someone where it went off.
@export var bang_hearing: float = 40.0
@export var pop_hearing: float = 20.0

@export_group("Night sight")
## How far a bot makes someone out on a field played at night (m; the browser game's NIGHT_SIGHT, WL6), by the light
## the target stands in: a light pool (as far as by day), the moonlit open, under the trees, or indoors in the dark (a
## floor or roof over it and no pool). view_distance still caps them all. NightField reads these.
@export var night_lit: float = 40.0
@export var night_open: float = 25.0
@export var night_canopy: float = 10.0
@export var night_indoor: float = 15.0
## Ground counts as under the trees when at least `night_canopy_trees` trunks (blocks of kind tree) stand within
## `night_canopy_radius` m of its cell's middle, on a grid of `night_canopy_cell` m cells from the blocks' corner
## (MapStyle's canopy rule for the under-trees ground is the same; a test holds them equal).
@export var night_canopy_trees: int = 3
@export var night_canopy_radius: float = 4.0
@export var night_canopy_cell: float = 1.0
## A pool lights the floor under it, for feet from `night_pool_below` m under that floor to `night_pool_above` m over
## it, not the floors above or below (on terrain the floor is the ground under the feet).
@export var night_pool_below: float = 0.5
@export var night_pool_above: float = 2.0
## Feet with the underside of a block (trees aside) between `night_roof_from` and `night_roof_to` m over them stand
## under a floor or roof: unlit, they are made out from night_indoor.
@export var night_roof_from: float = 1.9
@export var night_roof_to: float = 9.5
## A lit weapon torch (WL7, the browser's NIGHT_SIGHT.torchSeenFromDeg) gives its holder away from night_lit to anyone
## within this angle (degrees, across the ground) of where it points: its lens and spill. Anyone inside a lit beam's
## spill, within its reach, is made out from night_lit too (NightField's torch light).
@export var night_torch_seen_from_deg: float = 60.0
## How bots work their weapon torch at night (BotTorch, the browser's BOT_TORCH): on fighting someone within
## torch_fight_reach (m; or the torch's own reach if shorter) and on the last stretch of a search; off advancing, in
## cover, at the pole, on orders and between rounds. A state is held torch_min_hold s at least: no strobing.
@export var torch_min_hold: float = 1.5
@export var torch_fight_reach: float = 20.0
## Keeping out of the light (every level, the browser game's keepsDark): a lane point or hunt spot in a light pool moves
## to the nearest dark spot on its floor within dark_spot_radius (m), tried in rings dark_spot_step (m) apart,
## dark_spot_directions round each; unmoved if there is none.
@export var dark_spot_radius: float = 8.0
@export var dark_spot_step: float = 1.0
@export var dark_spot_directions: int = 16


## The skill a bot at `level` (MatchOptions.BOT_LEVELS) plays with; Easy's, the baseline, for a level it doesn't know.
func skill_for(level: StringName) -> BotSkill:
	match level:
		&"normal":
			return normal_skill
		&"hard":
			return hard_skill
	return skill


## This tuning as bots play `map`: a map naming its own bot sight (MapData.bot_sight, a hall with longer views, DR1)
## sees that far, on a copy; otherwise this config itself.
func for_map(map: MapData) -> BotConfig:
	if map == null or map.bot_sight <= 0.0 or is_equal_approx(map.bot_sight, view_distance):
		return self
	var out := duplicate() as BotConfig
	out.view_distance = map.bot_sight
	return out


## The game's bot tuning (bot_tuning.tres), or the built-in values with a warning if it can't be loaded.
static func load_default() -> BotConfig:
	var res := load(DEFAULT_PATH) as BotConfig
	if res == null:
		push_warning("BotConfig: %s could not be loaded; using the built-in values" % DEFAULT_PATH)
		return BotConfig.new()
	return res
