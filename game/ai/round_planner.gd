class_name RoundPlanner
## Each round's plan per team (the browser game's ai/roundPlanner.ts and teamPlan.ts): where each team starts and which
## way its enemy is, the team plan (split over the lanes, a pair on one, or all stacked on one) and the lane each bot
## walks, bots on a shared lane setting off a moment apart; in Attack / Defend the attackers walk theirs to the middle
## (then make for the pole) and the defenders only to their first or second point, where they hold. Between plans it
## answers where a bot stands (ahead of its team?) and picks hunt spots from the team's memory. Its own seeded stream,
## apart from each bot's.

enum Plan { SPLIT, PAIR, STACK }

## Per team: this round's plan, the middle of its spawns, the way its enemy is (yaw), and the unit way there (x, z).
var plans: Array[Plan] = [Plan.SPLIT, Plan.SPLIT]
var spawn_centre: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var enemy_yaw: PackedFloat64Array = PackedFloat64Array([0.0, 0.0])
var attack_dir: Array[Vector2] = [Vector2.RIGHT, Vector2.LEFT]
## Attack / Defend on a map with two poles (AB1): the one the attacking bots go for this round once their lanes are
## swept (BotFlag.in_play), drawn each round; 0 with one pole.
var attack_flag: int = 0
## The field's walkable extent (x, z) and the height over every floor, for drawing hunt spots.
var bounds_lo: Vector2 = Vector2.ZERO
var bounds_hi: Vector2 = Vector2.ZERO
var top_y: float = 0.0

var _rng: RandomNumberGenerator = null
## Scratch for dealing lanes (reused each round).
var _order: PackedInt32Array = PackedInt32Array()
var _members: Array[Bot] = []
var _dealt: PackedInt32Array = PackedInt32Array()


func _init(match_seed: int) -> void:
	_rng = Seeds.stream(Seeds.plan_seed(match_seed))


## A fresh round for every bot: per team a plan, the lanes dealt in a random order, bots sharing a lane setting off
## lane_follow_delay apart; on a map with two poles, the one the attackers go for. Call after the round's respawn
## (spawns and ends are this round's).
func plan(w: BotWorld) -> void:
	_measure_ends(w.characters)
	var cfg := w.cfg
	var lane_count := w.lanes.size()
	var flag := w.mode == RoundState.Mode.ATTACK_DEFEND and w.attackers >= 0
	attack_flag = _rng.randi_range(0, w.flags.size() - 1) if flag and w.flags.size() > 1 else 0
	for team in 2:
		_members.clear()
		for b in w.bots:
			if b.character.team == team:
				_members.append(b)
		var defending := flag and team != w.attackers
		var attacking := flag and team == w.attackers
		var p := _pick_plan(cfg)
		# Three bots holding one lane point would stand in a heap.
		if defending and p == Plan.STACK:
			p = Plan.PAIR
		# With fewer than three bots (the player makes up the team) a pair would be a stack: split instead.
		if p == Plan.PAIR and _members.size() < 3:
			p = Plan.SPLIT
		plans[team] = p
		_shuffle_lanes(lane_count)
		_dealt.resize(_members.size())
		for i in _members.size():
			var lane := -1
			if lane_count > 0:
				var slot := 0 if p == Plan.STACK else ((0 if i < 2 else i - 1) if p == Plan.PAIR else i)
				lane = _order[slot % lane_count]
			_dealt[i] = lane
		# Not on defence: defenders hold the points they were dealt.
		if not defending:
			_take_own_lanes(w.lanes)
		for i in _members.size():
			var b := _members[i]
			var lane := _dealt[i]
			var ahead := 0
			for k in i:
				if _dealt[k] == lane:
					ahead += 1
			var hold := 0.0
			for k in ahead:
				hold += b.pick(cfg.lane_follow_delay)
			var points := w.lanes[lane].size() if lane >= 0 else 0
			if points > 0 and defending:
				# The first on a lane, or anyone sharing one with team play, holds its second point (a defender alone on
				# its lane only sometimes, defend_forward_chance); the others hold the first.
				var shared := _dealt.count(lane) > 1
				var forward := ahead == 0 and (shared or _rng.randf() < cfg.defend_forward_chance)
				points = mini(points, 2 if forward or (shared and b.skill.team_play) else 1)
			elif points > 0 and attacking:
				points = _points_to_middle(w.lanes[lane], team, b.character.end)
			elif points > 0 and b.style.holds and w.mode == RoundState.Mode.ELIMINATION:
				# An anchor (bots.md › Holds until) walks its lane only to the last point short of the middle, and holds
				# there (BotPersonality.anchor_holding).
				points = maxi(1, _points_to_middle(w.lanes[lane], team, b.character.end) - 1)
			b.reset(lane, points, hold, cfg)


## True if `b` is more than team_spread ahead (towards the enemy) of its rearmost bot teammate in play.
func ahead_of_team(b: Bot, w: BotWorld) -> bool:
	var me := b.character
	var rear := INF
	for o in w.bots:
		var c := o.character
		# An anchor holds short of the middle, a defender at its post, a bot under a squad order goes its own way: nobody
		# waits for them.
		if c == me or c.team != me.team or not Elimination.is_in_play(c) or BotFlag.holds_post(o, w) \
				or o.order != SquadOrder.Kind.NONE:
			continue
		rear = minf(rear, _progress(c))
	return _progress(me) - rear > w.cfg.team_spread


## True if `b` is past halfway from its team's spawns to the enemy's.
func in_enemy_half(b: Bot) -> bool:
	var me := b.character
	var home := spawn_centre[me.team]
	var enemy := spawn_centre[1 - me.team]
	return _progress(me) > Vector2(enemy.x - home.x, enemy.z - home.z).length() * 0.5


## A walkable spot worth checking for `b`'s team into b.hunt_goal: of a few random walkable spots, the one in the sector
## the team checked longest ago (a check older than the skill's hunt_memory counts as never), nearer the middle of the
## field first: there the other team, sweeping its own lane the other way, comes back through. A spot the bot sees empty
## from where it stands is checked there and then, and picked only if every spot drawn was one. A spot is on the highest
## walkable floor over it a route from the bot reaches (inside a hut, not on its roof); one with none is drawn again. At
## night a bot that keeps dark moves its pick out of the light. False if none turned up.
func hunt_point(b: Bot, w: BotWorld) -> bool:
	var cfg := w.cfg
	var team := b.character.team
	var mid := (spawn_centre[0] + spawn_centre[1]) * 0.5
	var stale := w.time - b.skill.hunt_memory
	var best := INF
	var in_view := INF
	var found := 0
	var tries := 0
	var home := w.nav.nearest_walkable(b.character.position, w.nav.snap)
	while found < cfg.hunt_candidates and tries < cfg.hunt_candidates * cfg.hunt_tries_per_candidate:
		tries += 1
		var spot := Vector3(b.rng.randf_range(bounds_lo.x, bounds_hi.x), top_y, b.rng.randf_range(bounds_lo.y, bounds_hi.y))
		var k := _reached_floor(w.nav, home, w.nav.node_at(spot))
		if k < 0:
			continue
		found += 1
		spot.y = w.nav.floor_y[k]
		var score := maxf(w.visited_at(team, spot), stale) + Vector2(spot.x - mid.x, spot.z - mid.z).length() \
				* cfg.hunt_middle_bias
		if cfg.hunt_clear_range > 0.0 and BotSenses.sees_spot(b.character, spot, cfg.hunt_clear_range, w):
			w.mark_visited(team, spot)
			if best == INF and score < in_view:
				in_view = score
				b.hunt_goal = spot
			continue
		if score < best:
			best = score
			b.hunt_goal = spot
	if best == INF and in_view == INF:
		return false
	# At night it hunts out of the light pools (BotWorld.out_of_light).
	b.hunt_goal = w.out_of_light(b.hunt_goal)
	return true


## The highest walkable floor of `top`'s cell at or under `top` a route from node `home` reaches (on foot or vaulting;
## any walkable one when `home` is -1), or -1.
static func _reached_floor(nav: NavGrid, home: int, top: int) -> int:
	if top < 0:
		return -1
	var c := nav.node_cell[top]
	for k in range(top, nav.cell_start[c] - 1, -1):
		if nav.walkable[k] == 1 and (home < 0 or nav.linked(home, k, true)):
			return k
	return -1


func _pick_plan(cfg: BotConfig) -> Plan:
	var total := cfg.plan_split_weight + cfg.plan_pair_weight + cfg.plan_stack_weight
	var r := _rng.randf() * total
	if r < cfg.plan_split_weight:
		return Plan.SPLIT
	if r < cfg.plan_split_weight + cfg.plan_pair_weight:
		return Plan.PAIR
	return Plan.STACK


## A bot that keeps a lane of its own (bots.md › Own lane) and was dealt one a teammate shares in _dealt takes the free
## lane furthest from the lanes the others walk, if there is one.
func _take_own_lanes(lanes: Array[PackedVector3Array]) -> void:
	for i in _members.size():
		var lane := _dealt[i]
		if not _members[i].style.own_lane or lane < 0 or _dealt.count(lane) < 2:
			continue
		var best := -1
		var best_gap := -1.0
		for free in lanes.size():
			if _dealt.has(free) or lanes[free].is_empty():
				continue
			var mid := _lane_middle(lanes[free])
			var gap := INF
			for j in _members.size():
				if j != i and _dealt[j] >= 0 and not lanes[_dealt[j]].is_empty():
					gap = minf(gap, mid.distance_to(_lane_middle(lanes[_dealt[j]])))
			if gap > best_gap:
				best_gap = gap
				best = free
		if best >= 0:
			_dealt[i] = best


## The middle of a lane's points (x, z).
static func _lane_middle(points: PackedVector3Array) -> Vector2:
	var sum := Vector2.ZERO
	for q in points:
		sum += Vector2(q.x, q.z)
	return sum / points.size()


## How many of `points` a bot of `team` walking from `end` passes to reach the first one past the middle of the field
## (all of them if none is).
func _points_to_middle(points: PackedVector3Array, team: int, end: int) -> int:
	var home := spawn_centre[team]
	var enemy := spawn_centre[1 - team]
	var half := Vector2(enemy.x - home.x, enemy.z - home.z).length() * 0.5
	var dir := attack_dir[team]
	var n := points.size()
	for k in n:
		# From end 0 the points go first to last, from end 1 last to first (Bot.reset).
		var q := points[k if end == 0 else n - 1 - k]
		if Vector2(q.x - home.x, q.z - home.z).dot(dir) >= half:
			return k + 1
	return n


## _order = 0..count-1 shuffled (Fisher-Yates on the planner's stream).
func _shuffle_lanes(count: int) -> void:
	_order.resize(count)
	for i in count:
		_order[i] = i
	for i in range(count - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var t := _order[i]
		_order[i] = _order[j]
		_order[j] = t


## Where each team starts this round (its spawns' middle), and which way its enemy is.
func _measure_ends(chars: Array[Character]) -> void:
	for team in 2:
		var centre := Vector3.ZERO
		var n := 0
		for c in chars:
			if c.team == team:
				centre += c.spawn_position
				n += 1
		spawn_centre[team] = centre / maxi(1, n)
	var blue := spawn_centre[0]
	var orange := spawn_centre[1]
	enemy_yaw[0] = BotAim.look_yaw(blue, orange)
	enemy_yaw[1] = BotAim.look_yaw(orange, blue)
	var way := Vector2(orange.x - blue.x, orange.z - blue.z)
	var u := way / maxf(1e-6, way.length())
	attack_dir[0] = u
	attack_dir[1] = -u


## How far `c` is from its team's spawns towards the enemy's (m).
func _progress(c: Character) -> float:
	var home := spawn_centre[c.team]
	return Vector2(c.position.x - home.x, c.position.z - home.z).dot(attack_dir[c.team])
