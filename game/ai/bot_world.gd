class_name BotWorld
extends RefCounted
## What every bot thinks with (the browser game's ai/bot.ts BotWorld): the tuning, the level's rays and nav grid, the
## map's lanes and cover, everyone on the field, the round's plan and each team's hunt memory. The controller owns it
## and refreshes the time each tick; bots read it and write only their own Bot and the hunt memory.

var tuning: SimTuning = null
var cfg: BotConfig = null
var nav: NavGrid = null
var query: WorldQuery = null
var characters: Array[Character] = []
var bots: Array[Bot] = []
## The map's lanes (walkable points from end 0 to end 1) and its cover blocks (BotCover).
var lanes: Array[PackedVector3Array] = []
var low_cover: Array[BotCover.Block] = []
var tall_cover: Array[BotCover.Block] = []
var planner: RoundPlanner = null
## Seconds of match time, and whether the round is live (bots hold fire otherwise).
var time: float = 0.0
var live: bool = true
## Seconds left in the live round (team play's late push).
var round_clock: float = INF
## The match's mode, and in Attack / Defend the team attacking this round (-1 in Elimination), every pole's flag
## (RoundState's, read each tick) and the one in play (BotFlag.in_play: the one going for, or to pull down).
var mode: RoundState.Mode = RoundState.Mode.ELIMINATION
var attackers: int = -1
var flags: Array[FlagState] = [FlagState.new()]
var flag: FlagState = flags[0]
var flag_index: int = 0
## Elimination's overtime flag (OV2; RoundState's, read each tick): up, its foot and the time it has left.
var overtime_flag: OvertimeFlag = OvertimeFlag.new()
## The dark on a field played at night (WL6): light pools, canopy and roofs, built once as the match loads (null by
## day, and sight is as it always was).
var night: NightField = null
## The magazine hand-off's rules (MH2): who has one to spare, who can be tossed one now (MagShare's, made with the bots
## for their own checks; the simulation keeps its own).
var mag_share: MagShare = null
## The smoke and flash bombs thrown (SF1; GameState.grenades, the same pool): their clouds hide whoever is behind them.
var grenades: Array[Grenade] = []
## The level's doors as the round has left them (GameState.doors, DO1).
var doors: DoorState = null

## The field split into square sectors (BotConfig.hunt_sector_size) from (min_x, min_z): when each team last checked
## each one (-INF never).
var _sector_min: Vector2 = Vector2.ZERO
var _sector_cols: int = 1
var _sector_rows: int = 1
var _visited: Array[PackedFloat64Array] = []


## Sets up the hunt memory over the field from `lo` to `hi` (x, z), every sector unchecked.
func setup_sectors(lo: Vector2, hi: Vector2) -> void:
	var size := cfg.hunt_sector_size
	_sector_min = lo
	_sector_cols = maxi(1, ceili((hi.x - lo.x) / size))
	_sector_rows = maxi(1, ceili((hi.y - lo.y) / size))
	_visited.clear()
	for team in 2:
		var v := PackedFloat64Array()
		v.resize(_sector_cols * _sector_rows)
		v.fill(-INF)
		_visited.append(v)


## Every sector unchecked again (a new round).
func clear_sectors() -> void:
	for v in _visited:
		v.fill(-INF)


func sector_of(p: Vector3) -> int:
	var size := cfg.hunt_sector_size
	var i := clampi(floori((p.x - _sector_min.x) / size), 0, _sector_cols - 1)
	var j := clampi(floori((p.z - _sector_min.y) / size), 0, _sector_rows - 1)
	return j * _sector_cols + i


## Team `team` checked the sector of `p` now.
func mark_visited(team: int, p: Vector3) -> void:
	_visited[team][sector_of(p)] = time


## When team `team` last checked the sector of `p`.
func visited_at(team: int, p: Vector3) -> float:
	return _visited[team][sector_of(p)]


## Team play, in Elimination: true if `b` plays as a team, the round is live with late_push_time or less left, and
## fewer of its team are in play than of the other.
func pushing_late(b: Bot) -> bool:
	if mode != RoundState.Mode.ELIMINATION or not b.skill.team_play or not live or round_clock > cfg.late_push_time:
		return false
	var balance := 0
	for c in characters:
		if Elimination.is_in_play(c):
			balance += 1 if c.team == b.character.team else -1
	return balance < 0


## Team play: true while `b` goes to trade a teammate's hit call it heard.
func trading(b: Bot) -> bool:
	return time - b.trade_at < cfg.trade_time


## Keeping out of the light (every level): `g` (a floor point) moved to the nearest dark spot on its own floor,
## within dark_spot_radius in rings dark_spot_step apart, dark_spot_directions round each; `g` itself by day, outside the
## light, or with no dark spot near. The nearest is at the pool's edge, so a bot that stops a little short of it may
## stand just inside the light (the browser game's M40: a margin past the edge made defenders too strong).
func out_of_light(g: Vector3) -> Vector3:
	if night == null or not night.in_light(g):
		return g
	var step := cfg.dark_spot_step
	var turns := maxi(1, cfg.dark_spot_directions)
	var ring := 1
	while step > 0.0 and ring * step <= cfg.dark_spot_radius + 1e-6:
		var r := ring * step
		for k in turns:
			var angle := TAU * k / turns
			var at := Vector3(g.x + cos(angle) * r, g.y, g.z + sin(angle) * r)
			if not nav.is_walkable_at(at):
				continue
			at.y = nav.floor_at(at)
			if absf(at.y - g.y) > tuning.body.max_step or night.in_light(at):
				continue
			return at
		ring += 1
	return g


## The bot playing `c`, or null for the player (or anyone no bot plays).
func bot_of(c: Character) -> Bot:
	for b in bots:
		if b.character == c:
			return b
	return null


## The enemy side's direction (yaw) for `team` this round.
func enemy_yaw(team: int) -> float:
	return planner.enemy_yaw[team]
