class_name Bot
extends RefCounted
## One bot's mind as plain data (the browser game's ai/bot.ts): what it has seen and heard, its aim, its route, its lane,
## its cover and its part at the pole. The bot's body is an ordinary Character it drives through a PlayerCommand like the
## player's (docs/ARCHITECTURE.md › Contracts 2); BotBrain decides that command each tick from this.

## What it is doing: walking its lane (then hunting), fighting someone in sight, in cover, going to where someone was
## seen or heard, in Attack / Defend at the pole (raising, pulling down or guarding it: BotFlag), carrying out a squad
## order from a teammate (SquadOrders), or the magazine hand-off: bringing a teammate one, or waiting for one
## (BotMagShare).
enum Mode { ADVANCE, FIGHT, COVER, SEARCH, FLAG, ORDER, MAG }
## In cover: down behind it, or up (over crouch cover, or leaning out round a corner) looking.
enum CoverPhase { DOWN, PEEK }
## Its route: none, asked for (the controller plans one a tick), walking one, or none to be had.
enum RouteState { NONE, WANTED, OK, FAILED }


## What a bot remembers of one enemy it has seen, kept for the match (one per enemy).
class Contact:
	extends RefCounted
	## Last seen (s), first seen in this contact, when its aim began settling, and when it may open fire.
	var seen_at: float = -INF
	var first_seen_at: float = -INF
	## It was holding an angle (still at a post, its view already there) when it first saw them: "What got you".
	var held: bool = false
	var acquired_at: float = 0.0
	var react_at: float = 0.0


var character: Character = null
var rng: RandomNumberGenerator = null
var skill: BotSkill = null
var mode: Mode = Mode.ADVANCE

## The view it turns (at the skill's turn rate) and its aim error: a wander, and a fresh contact's first aim off to one
## side (BotAim).
var aim_yaw: float = 0.0
var aim_pitch: float = 0.0
var err_yaw: float = 0.0
var err_pitch: float = 0.0
var goal_err_yaw: float = 0.0
var goal_err_pitch: float = 0.0
var wander_left: float = 0.0
var first_yaw: float = 0.0
var first_pitch: float = 0.0

## Each enemy's contact by character id (null until first seen), the current one, and who it fights.
var contacts: Array[Contact] = []
var contact: Contact = null
var target_id: int = -1
var target_visible: bool = false
## The part of the target it sees (a share of its height: chest, or head).
var target_part: float = 0.0
## Seconds to its next sight check.
var think_left: float = 0.0
## Last time anything gave an enemy away (seen, heard, shot at).
var last_threat_at: float = -INF
## Seconds sprinting without a break, and since the sprint last stopped (BotHolster).
var sprint_run: float = 0.0
var sprint_gap: float = 0.0
## Where it last saw or heard someone, and whether that is in mind; when it last heard something.
var last_known: Vector3 = Vector3.ZERO
var has_last_known: bool = false
var heard_at: float = -INF
## Someone heard while it fought someone else: kept for when that fight is over.
var heard_other: Vector3 = Vector3.ZERO
var heard_other_at: float = -INF
## Last near miss from an enemy BB.
var suppressed_at: float = -INF
## A teammate's ping it took (PN1, Pings.take): when (-INF: none this round) and its floor spot. It is the bot's
## last-known spot until real news writes another, kept in mind BotConfig.ping_memory (ping_in_mind).
var ping_at: float = -INF
var ping_spot: Vector3 = Vector3.ZERO

## Its route: waypoints, the one it walks to, where the leg began, the goal and the route's state.
var route: PackedVector3Array = PackedVector3Array()
var route_leg: int = 0
var route_from: Vector3 = Vector3.ZERO
var route_goal: Vector3 = Vector3.ZERO
var route_state: RouteState = RouteState.NONE
var route_retry_at: float = -INF
## When the planner first saw the route wanted now (match time, BotRoutes.plan), -INF while none is: a bot's wait in
## the queue runs from it (or from route_retry_at, if later).
var route_asked_at: float = -INF
## Seconds it has walked slower than BotConfig.stuck_speed.
var stuck_for: float = 0.0
## Walking the first half of a route's vault leg this tick (BotRoutes.follow): straight at it, Jump once it's there.
var vault_leg: bool = false
## No vault in its routes before this time (s): it got held up on a vault leg (BotConfig.vault_retry_delay).
var vaults_off_until: float = -INF
## The way it walks this tick (a unit vector on the ground; zero to coast).
var move_dir: Vector3 = Vector3.ZERO

## Its lane (index in the map's lanes, -1 none), the way it walks it (1 first to last, -1 back), the point last reached
## (-1 none yet), how many points it walks before hunting, and the point it walks to now.
var lane: int = -1
var lane_dir: int = 1
var lane_index: int = -1
var lane_points: int = 0
var lane_goal: Vector3 = Vector3.ZERO
## Its lane swept: it hunts the stalest spot its team hasn't checked.
var hunting: bool = false
var hunt_goal: Vector3 = Vector3.ZERO
var hunt_picked_at: float = -INF
## Pausing at a lane point: time left, time spent there, waiting for the team, holding (this tick), and crouching to.
var hold_left: float = 0.0
var team_wait: float = 0.0
var wait_for_team: bool = false
var holding: bool = false
var hold_crouch: bool = false
## Stepping into crouch cover by a lane point first, and that spot.
var hold_cover: bool = false
var hold_spot: BotCover.Spot = BotCover.Spot.new()

## In cover: the spot, ducked or peeking, seconds left down, to give up getting there, settled there, since the episode
## began, looks left and the one under way; fighting from it now, and for how long more.
var cover: BotCover.Spot = BotCover.Spot.new()
var cover_phase: CoverPhase = CoverPhase.DOWN
var cover_left: float = 0.0
var cover_give_up: float = 0.0
var cover_held: float = 0.0
var cover_since: float = -INF
var peeks_left: int = 0
var peek_left: float = 0.0
var from_cover: bool = false
var peek_fight_left: float = 0.0
## Seconds until the next cover search may run.
var cover_cooldown: float = 0.0

## The trigger: seconds left in the burst, and in the pause after it; sidestepping, and which way.
var burst_left: float = 0.0
var pause_left: float = 0.0
var strafe_left: float = 0.0
var strafe_dir: int = 1

## Searching: the look round at the end (left, all, from which way), and going round by a flank point first.
var search_look_left: float = 0.0
var search_look_time: float = 0.0
var search_look_yaw: float = 0.0
var flanking: bool = false
var flank_goal: Vector3 = Vector3.ZERO
## Glances taken (hunting by eye), for the even spread over its view.
var glances: int = 0
## Held angles (BotAngles; skill.holds_angles or slices_corners): the best found, how many, and when and where they
## were last looked for.
var held_angles: Array[BotAngles.HeldAngle] = []
var held_angle_count: int = 0
var held_angles_at: float = -INF
var held_angles_from: Vector3 = Vector3.ZERO
## Near the enemy with skill.slices_corners: walking and slicing each corner ahead (BotBrain).
var careful: bool = false
## Lost sight of someone in a fight: watching where they were until this time before going after them (s).
var watch_until: float = -INF
## Team play: when it heard a teammate's hit call (to trade), and whether it has tried for cover to trade from.
var trade_at: float = -INF
var trade_tried: bool = false
## Who it is this match (BotRoster): its name ("" without one) and the personality it plays (BotsFile), laid over its
## skill once (BotPersonality.personal_skill); the neutral style for a bot without one.
var bot_name: String = ""
var personality: StringName = &""
var style: BotsFile.Style = BotsFile.neutral()
## Settled at its post (an anchor's last lane point) since last tick: whether to crouch there is chosen on arrival.
var at_post: bool = false
## Pushing in: whether a step forward keeps the target in sight, looked at once a sidestep or for a new target.
var push_in_sight: bool = false
var push_look_for: int = -1
## Attack / Defend (BotFlag): its lane swept (an attacker goes for the pole), picked to pull the flag down (a defender)
## or to raise it (an attacker; the others guard), and in flag mode the spot it makes for and whether it guards there.
var lane_done: bool = false
var retake: bool = false
## The pole it was picked to pull down (BotFlag.pick_retakers; -1 none), on a map with two its own (AB1).
var retake_pole: int = -1
var raiser: bool = false
var flag_goal: Vector3 = Vector3.ZERO
var flag_guard: bool = false
## The pole (BotWorld.flag_index) its flag spot was picked by: when the pole in play changes it picks again (AB1).
var flag_pole: int = -1
## Elimination's overtime flag (OV2): when it sets off for the flag (s of match time: the flag going up plus its skill's
## overtime_reaction; INF until it is up), and whether this overtime it goes round the side (its flank_chance, drawn as
## the flag goes up and used once).
var overtime_at: float = INF
var overtime_flank: bool = false
## A squad order from a teammate in play (SquadOrders; NONE: it plays the team plan): which, from whom, its place among
## the teammates given it (which spot is its own), the spot it makes for and the way it looks once there.
var order: SquadOrder.Kind = SquadOrder.Kind.NONE
var order_giver: Character = null
var order_slot: int = 0
var order_goal: Vector3 = Vector3.ZERO
var order_yaw: float = 0.0
## Follow me: its idea of the giver's heading (eased, so the spots swing round), whether it hurries (sprints: catching
## up or regrouping), whether it is settled at its spot, and whether it is catching up on it or dropping back to it.
var order_heading: float = 0.0
var order_rush: bool = false
var order_settled: bool = false
var order_catching_up: bool = false
var order_dropping_back: bool = false
## The magazine hand-off (MH2, BotMagShare): the teammate it brings one to (null: none) and since when (s), whether it
## sprints there, and the time it may press the hand-off again. Its own ask is its character's (Character.mag).
var mag_for: Character = null
var mag_for_at: float = -INF
var mag_rush: bool = false
var mag_press_at: float = -INF

## Its smoke and flash bombs (SF2, BotBombs), from their own stream (Seeds.bomb_seed): the throw it is turning to
## (NONE: none) and its view, until when it turns before giving up, when it may next roll for one, and after a flash,
## until when it looks away (that way) before it pushes.
var bomb_rng: RandomNumberGenerator = null
var bomb_kind: Grenade.Kind = Grenade.Kind.NONE
var bomb_yaw: float = 0.0
var bomb_pitch: float = 0.0
var bomb_aim_until: float = -INF
var bomb_roll_at: float = -INF
var bomb_away_until: float = -INF
var bomb_away_yaw: float = 0.0


func _init(body: Character, seed_value: int, bot_skill: BotSkill, roster_size: int) -> void:
	character = body
	rng = Seeds.stream(seed_value)
	bomb_rng = Seeds.stream(Seeds.bomb_seed(seed_value))
	skill = bot_skill
	for i in roster_size:
		contacts.append(Contact.new())
	for i in BotAngles.KEPT:
		held_angles.append(BotAngles.HeldAngle.new())
	aim_yaw = body.yaw


## A fresh round: everything it knew and any squad order forgotten, on `lane_id` (walked from its end) for `points`
## points, setting off after `start_hold` seconds.
func reset(lane_id: int, points: int, start_hold: float, cfg: BotConfig) -> void:
	aim_yaw = character.yaw
	aim_pitch = 0.0
	err_yaw = 0.0
	err_pitch = 0.0
	goal_err_yaw = 0.0
	goal_err_pitch = 0.0
	wander_left = 0.0
	first_yaw = 0.0
	first_pitch = 0.0
	mode = Mode.ADVANCE
	# Sight checks are staggered across bots.
	think_left = rng.randf() * cfg.think_interval
	forget_target()
	for c in contacts:
		if c != null:
			c.seen_at = -INF
	has_last_known = false
	heard_at = -INF
	heard_other_at = -INF
	last_threat_at = -INF
	sprint_run = 0.0
	sprint_gap = 0.0
	suppressed_at = -INF
	ping_at = -INF
	bomb_kind = Grenade.Kind.NONE
	bomb_aim_until = -INF
	bomb_roll_at = -INF
	bomb_away_until = -INF
	route.clear()
	route_leg = 0
	route_state = RouteState.NONE
	route_retry_at = -INF
	route_asked_at = -INF
	stuck_for = 0.0
	vault_leg = false
	vaults_off_until = -INF
	move_dir = Vector3.ZERO
	lane = lane_id
	# From end 0 the lane's points go first to last, from end 1 last to first.
	lane_dir = 1 if character.end == 0 else -1
	lane_index = -1
	lane_points = points
	hunting = false
	hunt_picked_at = -INF
	hold_left = start_hold
	team_wait = 0.0
	wait_for_team = false
	holding = false
	hold_crouch = false
	hold_cover = false
	cover_phase = CoverPhase.DOWN
	cover_left = 0.0
	cover_since = -INF
	from_cover = false
	cover_cooldown = 0.0
	burst_left = 0.0
	pause_left = 0.0
	strafe_left = 0.0
	search_look_left = 0.0
	flanking = false
	held_angle_count = 0
	held_angles_at = -INF
	careful = false
	watch_until = -INF
	trade_at = -INF
	trade_tried = false
	at_post = false
	push_look_for = -1
	lane_done = false
	retake = false
	retake_pole = -1
	flag_pole = -1
	raiser = false
	flag_guard = false
	overtime_at = INF
	overtime_flank = false
	order = SquadOrder.Kind.NONE
	order_giver = null
	order_rush = false
	mag_for = null
	mag_for_at = -INF
	mag_rush = false
	mag_press_at = -INF


func forget_target() -> void:
	target_id = -1
	target_visible = false
	contact = null


## When it last saw the target it has in mind (-INF: none).
func last_seen_at() -> float:
	return contact.seen_at if contact != null else -INF


## Something seen or heard is still in mind (BotConfig.memory_time), or a teammate's ping it took (ping_in_mind).
func threat_in_mind(time: float, cfg: BotConfig) -> bool:
	return has_last_known and (time - maxf(last_seen_at(), heard_at) < cfg.memory_time or ping_in_mind(time, cfg))


## A teammate's ping is what it has in mind (PN1): taken within BotConfig.ping_memory and still its last-known spot
## (real news since, a sighting, a noise or a teammate's, writes another; a search that got there and looked forgets it).
func ping_in_mind(time: float, cfg: BotConfig) -> bool:
	return time - ping_at < cfg.ping_memory and on_ping_spot()


## Whether its last-known spot is still the one a teammate's ping gave it, however long ago.
func on_ping_spot() -> bool:
	return has_last_known and ping_at > -INF and last_known == ping_spot


## Takes up the enemy heard during a fight now that the fight is over, if that is recent. True if there was one.
func recall_heard_other(time: float, cfg: BotConfig) -> bool:
	if time - heard_other_at >= cfg.memory_time:
		return false
	last_known = heard_other
	has_last_known = true
	heard_at = heard_other_at
	heard_other_at = -INF
	return true


## A draw from `span` (Vector2(min, max)) on its own stream.
func pick(span: Vector2) -> float:
	return rng.randf_range(span.x, span.y)
