class_name MatchRunner
extends RefCounted
## Whole matches of bots against bots (Elimination, or Attack / Defend on a map with a pole), headless and as fast as
## the machine allows: the map's level built once (its Jolt colliders, so it must be in the tree), then each match
## stepped tick by tick with no rendering and no waiting for frames. Each match comes back as a MatchTally of what the
## guards (tests/guards/) and the balance report (BR1) read. Test-only (tests/ never ships).

const DT := 1.0 / 60.0
const TICKS_PER_SECOND := 60
## Held up: a bot that has been walking its lane, hunting or making for the pole (Bot.Mode ADVANCE, SEARCH or FLAG) at
## every sample of the last HELD_UP_SECONDS (once a second) and is back within HELD_UP_DISTANCE (m) of where it was
## then, counts one episode until it moves on, if either it kept one errand (mode) throughout (going round in a loop)
## or every sample stayed within HELD_UP_REACH of that place (frozen, jittering or pacing in a doorway, whatever its
## mode flips between). A fight or a hold on purpose in between is not held up, nor a change of errand on a long walk
## (a search given up for its lane, walking back the way it came).
const HELD_UP_SECONDS := 10
const HELD_UP_DISTANCE := 0.5
## How far (m) from where it was HELD_UP_SECONDS ago a bot that changed errand may stray at any sample and still be held
## up: well under the 10 m a given-up search walks back (DP1, Depot seed 7 at Pro, now Hard), well over a bot pacing a
## doorway.
const HELD_UP_REACH := 2.0
## A character that ends a round in play without ever getting this far from its spawn (m) stayed home that round.
const LEAVES_SPAWN := 8.0
## Follow me (follow_leader): a follower is judged once it has carried out the order FOLLOW_REJOIN seconds in a row
## (back from a fight or cover, it gets that long to rejoin); near within the follow distance, catch_up_gap and
## FOLLOW_NEAR_SLACK (m) of the leader; standing still slower than STILL_SPEED (m/s) while the leader moves.
const FOLLOW_REJOIN := 3.0
const FOLLOW_NEAR_SLACK := 2.0
const STILL_SPEED := 0.5
## Beyond catch_up a follower is chasing, not left behind, while over the last CHASE_TICKS it covered ground at
## CHASE_PACE or more of its sprint speed (straight-line, so a corner's slow-down and a route bending round cover still
## count) and the gap to the leader grew by no more than CHASE_SLACK (m): one back from cover can't gain on a leader
## sprinting at its own top speed, and bots never outrun the player's sprint (lead ruling, DP4). A follower stuck,
## standing, lost (the gap grows) or slower than it could be is left behind.
const CHASE_TICKS := 30
const CHASE_PACE := 0.8
const CHASE_SLACK := 0.25


## One round, as it ended.
class RoundTally:
	extends RefCounted
	## The winning team, or -1 for a draw; why it ended (GameEvent.RoundEnd); how long it lasted (s).
	var winner: int = -1
	var reason: int = 0
	var seconds: float = 0.0
	## Which end of the map each team started from this round (ends swap at half time): Alpha's end.
	var alpha_end: int = 0
	## The round's first knock-out: when (s into the round), and how far the shooter stood from the target (m); -1
	## if nobody was hit.
	var first_hit_time: float = -1.0
	var first_hit_range: float = -1.0
	## Each character's farthest distance from this round's spawn (m, level).
	var farthest: PackedFloat32Array = PackedFloat32Array()
	## Attack / Defend: the team attacking (-1 in Elimination), and how far the flag got up (0 to 1).
	var attackers: int = -1
	var top_flag: float = 0.0
	## Elimination: the overtime flag went up this round (OV1).
	var overtime: bool = false


## One match: its rounds and everything that must never happen, counted.
class MatchTally:
	extends RefCounted
	var map_id: String = ""
	var seed_value: int = 0
	## The kit each bot picked, by character id ("" for one carrying its replicas as they come).
	var kits: PackedStringArray = PackedStringArray()
	## Each bot's personality (bots.md, &"" for none) and its knock-outs of an opponent, by character id.
	var personalities: Array[StringName] = []
	var hits_by: PackedInt32Array = PackedInt32Array()
	var rounds: Array[RoundTally] = []
	## A team won the match before the tick limit.
	var finished: bool = false
	var ticks: int = 0
	## Each character's farthest distance from its round's spawn (m, level), over the whole match.
	var farthest: PackedFloat32Array = PackedFloat32Array()
	## Rounds a character ended still in play but never more than LEAVES_SPAWN from its spawn (one per character and
	## round).
	var stayed_home: int = 0
	## Bots held up on their way (episodes; see HELD_UP_SECONDS).
	var held_up: int = 0
	## Route searches (NavGrid.searches, the bots' and the walk-offs') over the match and the most in one tick; the
	## longest a bot in play waited for a route it wanted (s, from when the planner first saw it wanted, or its retry
	## time if later: Bot.route_asked_at) and the longest a hit character waited for its walk-off route (s).
	var searches: int = 0
	var most_searches_a_tick: int = 0
	var longest_route_wait: float = 0.0
	var longest_walk_off_wait: float = 0.0
	## Lowest and highest feet over the match (m), and the longest a character spent off the ground outside a vault
	## (s): one figure each for the whole match, all the guards need (BR1 reads rounds and hits, not these).
	var min_y: float = INF
	var max_y: float = -INF
	var longest_air: float = 0.0
	## Knock-outs in all; those by a teammate's BB (direct), and by the shooter's own bounced BB. A teammate reached
	## by a bounced BB while ricochets don't count (a RICOCHET_TICK) is counted apart.
	var hits: int = 0
	## BBs fired (SHOT events): the callouts' guard plays a match with and without them and compares.
	var shots: int = 0
	var friendly_hits: int = 0
	var self_hits: int = 0
	var friendly_ricochets: int = 0
	## Runs into noisy props and BBs ringing off steel (NP1): measured for the record, never asserted.
	var knocks: int = 0
	var rings: int = 0
	## Ticks a character in or out of play spent within a metre above the kill height (falling out of the level; the
	## simulation puts it back below it).
	var rescued: int = 0
	## With a follow_leader: follower ticks judged, those near the leader and those standing still while it moved, the
	## farthest a judged follower was from it (m) while not chasing it (CHASE_PACE), and the ticks spent chasing.
	var follow_counted: int = 0
	var follow_near: int = 0
	var follow_standing: int = 0
	var follow_worst: float = 0.0
	var follow_chasing: int = 0

	## Rounds that ran out the clock.
	func on_time() -> int:
		return _ended(GameEvent.RoundEnd.TIME)

	## Attack / Defend: rounds won by raising the flag.
	func captures() -> int:
		return _ended(GameEvent.RoundEnd.CAPTURED)

	## Elimination: rounds that went to the overtime flag, and those won by touching it.
	func overtimes() -> int:
		var n := 0
		for r in rounds:
			if r.overtime:
				n += 1
		return n

	func flag_touches() -> int:
		return _ended(GameEvent.RoundEnd.OVERTIME_FLAG)

	## Attack / Defend: the flag got all the way up in some round.
	func flag_raised() -> bool:
		for r in rounds:
			if r.top_flag >= 1.0:
				return true
		return false

	func _ended(reason: GameEvent.RoundEnd) -> int:
		var n := 0
		for r in rounds:
			if r.reason == reason:
				n += 1
		return n


var tuning: SimTuning = null
## Every bot, on both teams, picks a kit from data/bot-kits.md at its team's difficulty (the same weights for both at
## one level, so the map's ends stay comparable); off, they all carry their replicas as they come.
var kitted: bool = true
## Both teams' level (MatchOptions.BOT_LEVELS), or team 0's when `beta_difficulty` is set: a ladder match, one level
## against another.
var difficulty: StringName = &"normal"
var beta_difficulty: StringName = &""
## Every bot gets a name and personality from data/bots.md as in a match (their kits lean by it); off, none has one.
var personalities: bool = true
## A bot (character id on team 0) that gives its teammates Follow me through its command at each round start, as the
## player would, while the match tallies how well they keep up (MatchTally.follow_*); -1, nobody: no order is given.
var follow_leader: int = -1
## The match's mode: Attack / Defend needs a map with a pole (MapData.has_pole); team 0 attacks first, as in the browser
## game's guards.
var mode: RoundState.Mode = RoundState.Mode.ELIMINATION
## Called after every tick's step with the state and the bots (a test's own watch, such as what each bot sees through
## bushes, WL5); none by default.
var each_tick: Callable = Callable()
## Every bot's command marked a manual reload after it thinks (RL2): the simulation never reloads on a dry click, so
## only the bots' own reload loads their replicas. Off by default (the bots' commands as they fill them).
var manual_reload: bool = false
## Played at night (WL6): the bots see by the map's NightField, built once each match. On by default for a map that
## offers no day (Woodland); on a map that offers both a test sets it for the night.
var night: bool = false
## Who carries a weapon torch (WL7): by rule every bot at night and none by day (BY_RULE, the game's), nobody, or every
## bot even by day (ALWAYS: a day match with torches fitted must play exactly as one without).
enum Lights { BY_RULE, NONE, ALWAYS }
var lights: Lights = Lights.BY_RULE
## The bots call to their team (Callouts, CO1); off, they say nothing and must play exactly the same.
var talk: bool = true
## Elimination's overtime flag goes up on a map with a spot, as in the game (OV1); off, a clock run out level is a draw
## at once, as before it: a match that never reaches overtime plays the same either way.
var overtime_flag: bool = true
var _kits: BotKits = null
var _kit_rules: LoadoutRules = null
var config: BotConfig = null
var map: MapData = null
var level: MapLevel = null
var nav: NavGrid = null
## The lowest floor's top (or the terrain's lowest point, WL10) and the highest block's or terrain's top on the map (m),
## for the height guards.
var lowest_floor: float = INF
var highest_top: float = -INF


## Builds `map_id`'s level under `parent` (it stays there until `free_level`), or `given`'s when there is one (a map
## already read, such as a copy with a part of its file taken out). Check `map.problems` before trusting the height
## bounds: a map refused for having no floor leaves `lowest_floor` at INF.
func _init(parent: Node, map_id: String, sim_tuning: SimTuning = null, bot_config: BotConfig = null,
		given: MapData = null) -> void:
	tuning = sim_tuning if sim_tuning != null else SimTuning.load_default()
	config = bot_config if bot_config != null else BotConfig.load_default()
	var style := MapStyle.new()
	map = given if given != null else MapData.load_map(map_id, style, tuning.rounds.team_size)
	level = MapLevel.new()
	parent.add_child(level)
	level.build(map, style, tuning.body)
	nav = NavGrid.build(map, tuning.nav, tuning.body)
	night = map.ok() and not map.lighting_presets.has(LightingConfig.DAY)
	for b in map.blocks:
		var top := b.center.y + b.size.y * 0.5
		highest_top = maxf(highest_top, top)
		if b.kind == &"floor" or b.rise != MapData.Rise.NONE:
			lowest_floor = minf(lowest_floor, top if b.rise == MapData.Rise.NONE else b.center.y - b.size.y * 0.5)
	if map.terrain != null:
		var heights := map.terrain.height_range()
		lowest_floor = minf(lowest_floor, heights.x)
		highest_top = maxf(highest_top, heights.y)


## The round tuning a match on `map_id` plays in the guards and the balance report: `base` (the loaded tuning by
## default) where the map offers its team size, else a copy at the map's standard size (data/maps.md, as
## MapCatalog.Entry.team_size_for picks for the game): Depot at 3, Woodland at 5.
static func sized_for(map_id: String, base: SimTuning = null) -> SimTuning:
	var t := base if base != null else SimTuning.load_default()
	var entry := MapCatalog.shared().find(map_id)
	if entry == null or entry.allows(t.rounds.team_size):
		return t
	var sized := t.duplicate() as SimTuning
	sized.rounds = t.rounds.duplicate() as RoundConfig
	sized.rounds.team_size = entry.team_size_for(t.rounds.team_size)
	return sized


## Team `team`'s level.
func team_level(team: int) -> StringName:
	return beta_difficulty if team == 1 and beta_difficulty != &"" else difficulty


func free_level() -> void:
	if level != null:
		level.free()
		level = null


## Plays one whole match on `seed_value`, every character a bot, for at most `max_seconds` of match time.
func play(seed_value: int, max_seconds: float) -> MatchTally:
	var sim := Simulation.new(tuning, level.query(), level.mover(tuning.body), map.ends, map.kill_y)
	sim.nav = nav
	var state := GameState.new(seed_value, tuning)
	var loadout := ReplicaStats.default_loadout()
	var commands: Array[PlayerCommand] = []
	var size := tuning.rounds.team_size
	var kit_names := PackedStringArray()
	if kitted and _kits == null:
		_kits = BotKits.shared()
		_kit_rules = LoadoutRules.standard()
	var levels: Dictionary[int, StringName] = {0: difficulty, 1: team_level(1)}
	var ids := PackedInt32Array()
	var teams := PackedInt32Array()
	for i in size * 2:
		ids.append(i)
		teams.append(0 if i < size else 1)
	var identities: Dictionary[int, BotRoster.Identity] = {}
	if personalities:
		identities = BotRoster.draw(seed_value, ids, teams, BotsFile.shared())
	var t := MatchTally.new()
	for i in size * 2:
		var who: BotRoster.Identity = identities.get(i)
		var personality: StringName = who.personality if who != null else &""
		t.personalities.append(personality)
		var kit_level := levels[0 if i < size else 1]
		var plan := _kits.pick(kit_level, _kit_rules, Seeds.kit_seed(seed_value, i), personality,
				config.kit_suit_lean) if kitted else null
		kit_names.append(plan.kit_name if plan != null else "")
		if plan == null:
			state.characters.append(Character.new(i, 0 if i < size else 1, Vector3.ZERO, 0.0, loadout))
		else:
			var kit := BotKits.kit_of(plan, _kit_rules)
			state.characters.append(Character.new(i, 0 if i < size else 1, Vector3.ZERO, 0.0, kit.replicas,
					kit.bb_weights))
		commands.append(PlayerCommand.new())
	if lights == Lights.ALWAYS or (lights == Lights.BY_RULE and night):
		# Every bot carries the torch at night, as a match there does.
		var light_rules := LoadoutRules.standard()
		var light := BotKits.night_light(light_rules)
		for c in state.characters:
			c.armament.lights = BotKits.lights_for(c.armament.replicas, light_rules, light)
	var bots := BotController.new(state, -1, map, nav, level.query(), tuning, config, levels, identities, talk)
	bots.world.night = NightField.build(map, config, night)
	t.kits = kit_names
	t.hits_by.resize(state.characters.size())
	t.map_id = map.id
	t.seed_value = seed_value
	t.farthest.resize(state.characters.size())
	if mode == RoundState.Mode.ATTACK_DEFEND:
		state.round_state.mode = mode
		state.round_state.poles = map.poles
		state.round_state.first_attackers = 0
	else:
		state.round_state.has_overtime_spot = map.has_overtime_flag and overtime_flag
		state.round_state.overtime_spot = map.overtime_flag
	sim.start_match(state)
	bots.observe(state)
	var round_now := _new_round(state)
	var round_start := state.time
	var limit := roundi(max_seconds / DT)
	var n := state.characters.size()
	# Each character's position and errand once a second for the last HELD_UP_SECONDS (INF where it wasn't on its way),
	# and whether it is held up now.
	var trail: Array[PackedVector3Array] = []
	var errands: Array[PackedInt32Array] = []
	var held := PackedByteArray()
	held.resize(n)
	for i in n:
		var ring := PackedVector3Array()
		ring.resize(HELD_UP_SECONDS)
		ring.fill(Vector3.INF)
		trail.append(ring)
		var kinds := PackedInt32Array()
		kinds.resize(HELD_UP_SECONDS)
		errands.append(kinds)
	var order_due := follow_leader >= 0
	# Per character, seconds in a row spent carrying out Follow me (a fight or cover resets it).
	var following := PackedFloat32Array()
	following.resize(n)
	# Per character, where it was and its gap to the leader over the last CHASE_TICKS (a ring; the gap -1: not known).
	var chase_at: Array[PackedVector3Array] = []
	var chase_gap: Array[PackedFloat32Array] = []
	for i in n:
		var at := PackedVector3Array()
		at.resize(CHASE_TICKS)
		chase_at.append(at)
		var gap := PackedFloat32Array()
		gap.resize(CHASE_TICKS)
		gap.fill(-1.0)
		chase_gap.append(gap)
	# Per character, ticks in a row its walk-off route has been waiting.
	var walk_off_wait := PackedInt32Array()
	walk_off_wait.resize(n)
	while t.ticks < limit and not t.finished:
		var searched := nav.searches
		bots.think(state, commands, DT)
		if manual_reload:
			for cmd in commands:
				cmd.manual_reload = true
		if order_due:
			commands[follow_leader].squad_order = SquadOrder.Kind.FOLLOW
			order_due = false
		sim.step(state, commands, DT)
		bots.observe(state)
		if each_tick.is_valid():
			each_tick.call(state, bots)
		t.ticks += 1
		_watch_routes(state, bots, t, nav.searches - searched, walk_off_wait)
		_watch(state, t, round_now)
		if follow_leader >= 0:
			_watch_follow(state, bots, t, following, chase_at, chase_gap)
		if t.ticks % TICKS_PER_SECOND == 0:
			_watch_held_up(state, bots, t, trail, errands, held, (t.ticks / TICKS_PER_SECOND) % HELD_UP_SECONDS)
		for i in state.events.count:
			var e := state.events.items[i]
			match e.kind:
				GameEvent.Kind.SHOT:
					t.shots += 1
				GameEvent.Kind.CHARACTER_HIT:
					count_hit(state, e, t)
					var shooter := state.character(e.actor)
					var target := state.character(e.target)
					if shooter != null and target != null and round_now.first_hit_time < 0.0:
						round_now.first_hit_time = state.time - round_start
						round_now.first_hit_range = shooter.position.distance_to(target.position)
				GameEvent.Kind.RICOCHET_TICK:
					count_ricochet(state, e, t)
				GameEvent.Kind.PROP_KNOCK:
					t.knocks += 1
				GameEvent.Kind.PROP_RING:
					t.rings += 1
				GameEvent.Kind.OVERTIME:
					round_now.overtime = true
				GameEvent.Kind.ROUND_OVER:
					# In Attack / Defend only the attackers must leave: defenders hold by their pole.
					for c in state.characters:
						if Elimination.is_in_play(c) and round_now.farthest[c.id] <= LEAVES_SPAWN \
								and (round_now.attackers < 0 or c.team == round_now.attackers):
							t.stayed_home += 1
					round_now.winner = e.value
					round_now.reason = int(e.value2)
					round_now.seconds = state.time - round_start
					t.rounds.append(round_now)
				GameEvent.Kind.ROUND_START:
					round_now = _new_round(state)
					order_due = follow_leader >= 0
					round_start = state.time
					for ring in trail:
						ring.fill(Vector3.INF)
				GameEvent.Kind.MATCH_OVER:
					t.finished = true
	return t


## The tick's route searches (`searched`) and who is waiting for a route, into `t`.
static func _watch_routes(state: GameState, bots: BotController, t: MatchTally, searched: int,
		walk_off_wait: PackedInt32Array) -> void:
	t.searches += searched
	t.most_searches_a_tick = maxi(t.most_searches_a_tick, searched)
	for b in bots.world.bots:
		if b.route_state == Bot.RouteState.WANTED and Elimination.is_in_play(b.character) \
				and not is_inf(b.route_asked_at):
			t.longest_route_wait = maxf(t.longest_route_wait, state.time - maxf(b.route_asked_at, b.route_retry_at))
	for c in state.characters:
		walk_off_wait[c.id] = walk_off_wait[c.id] + 1 if c.walk_off_route_pending else 0
		t.longest_walk_off_wait = maxf(t.longest_walk_off_wait, walk_off_wait[c.id] * DT)


## One knock-out (a CHARACTER_HIT) counted: by a teammate's BB, or by the shooter's own bounced BB.
static func count_hit(state: GameState, e: GameEvent, t: MatchTally) -> void:
	t.hits += 1
	var shooter := state.character(e.actor)
	var target := state.character(e.target)
	if shooter == null or target == null:
		return
	if e.actor == e.target:
		t.self_hits += 1
	elif shooter.team == target.team:
		t.friendly_hits += 1
	elif e.actor < t.hits_by.size():
		t.hits_by[e.actor] += 1


## A bounced BB that reached someone while ricochets don't count (a RICOCHET_TICK): counted if it was a teammate's.
static func count_ricochet(state: GameState, e: GameEvent, t: MatchTally) -> void:
	var from := state.character(e.actor)
	var reached := state.character(e.target)
	if from != null and reached != null and e.actor != e.target and from.team == reached.team:
		t.friendly_ricochets += 1


func _new_round(state: GameState) -> RoundTally:
	var r := RoundTally.new()
	r.farthest.resize(state.characters.size())
	r.attackers = state.round_state.attackers
	for c in state.characters:
		if c.team == 0:
			r.alpha_end = c.end
			break
	return r


## Once a second: a bot held up (held_up_sample) starts a held-up episode, which lasts until it moves on.
func _watch_held_up(state: GameState, bots: BotController, t: MatchTally, trail: Array[PackedVector3Array],
		errands: Array[PackedInt32Array], held: PackedByteArray, slot: int) -> void:
	for c in state.characters:
		var b := _bot_of(bots, c.id)
		var bot_mode := bots.mode_of(c.id)
		var walking := (bot_mode == Bot.Mode.ADVANCE or bot_mode == Bot.Mode.SEARCH or bot_mode == Bot.Mode.FLAG) \
				and not (b != null and holding_on_purpose(b, bots.world.time))
		var on_way := Elimination.is_in_play(c) and state.round_state.is_live() and walking
		var now := 1 if held_up_sample(trail[c.id], errands[c.id], slot, c.position, bot_mode, on_way) else 0
		if now == 1 and held[c.id] == 0:
			t.held_up += 1
		held[c.id] = now


## Records this second's sample in `ring` (one a second for HELD_UP_SECONDS; INF for a second it wasn't on its way) and
## its errand in `errands`, both at `slot`, and whether it is held up now: on its way at every sample, back within
## HELD_UP_DISTANCE of the place HELD_UP_SECONDS ago, and on this one errand throughout or never farther than
## HELD_UP_REACH from that place.
static func held_up_sample(ring: PackedVector3Array, errands: PackedInt32Array, slot: int, position: Vector3,
		errand: int, on_way: bool) -> bool:
	var then := ring[slot]
	ring[slot] = position if on_way else Vector3.INF
	errands[slot] = errand
	if not on_way or then == Vector3.INF:
		return false
	var one_errand := true
	for i in ring.size():
		if ring[i] == Vector3.INF:
			return false
		one_errand = one_errand and errands[i] == errand
	if position.distance_to(then) >= HELD_UP_DISTANCE:
		return false
	if one_errand:
		return true
	for p: Vector3 in ring:
		if p.distance_to(then) > HELD_UP_REACH:
			return false
	return true


## The tick's heights, air time and distances from spawn, for everyone still in play. Distances only while the round
## is live: between rounds the ends may swap, so a spawn moves before its character does.
func _watch(state: GameState, t: MatchTally, r: RoundTally) -> void:
	var live := state.round_state.is_live()
	r.top_flag = maxf(r.top_flag, state.round_state.flag.progress)
	for c in state.characters:
		if c.position.y < map.kill_y + 1.0:
			t.rescued += 1
		if not Elimination.is_in_play(c):
			continue
		t.min_y = minf(t.min_y, c.position.y)
		t.max_y = maxf(t.max_y, c.position.y)
		if not c.vault.active:
			t.longest_air = maxf(t.longest_air, 0.0 if c.grounded else c.air_time)
		if not live:
			continue
		var away := Vector2(c.position.x - c.spawn_position.x, c.position.z - c.spawn_position.z).length()
		t.farthest[c.id] = maxf(t.farthest[c.id], away)
		r.farthest[c.id] = maxf(r.farthest[c.id], away)


## Follow me's tally for the tick (see FOLLOW_REJOIN), while the round is live and the leader in play.
func _watch_follow(state: GameState, bots: BotController, t: MatchTally, following: PackedFloat32Array,
		chase_at: Array[PackedVector3Array], chase_gap: Array[PackedFloat32Array]) -> void:
	var leader := state.character(follow_leader)
	if not state.round_state.is_live() or leader == null or not Elimination.is_in_play(leader):
		return
	var squad := config.squad
	var leader_moving := Vector2(leader.velocity.x, leader.velocity.z).length() > squad.heading_speed
	for b in bots.world.bots:
		var c := b.character
		if c.team != leader.team or c == leader:
			continue
		var carried := b.order == SquadOrder.Kind.FOLLOW and b.mode == Bot.Mode.ORDER
		following[c.id] = following[c.id] + DT if carried else 0.0
		# The ring's oldest entry, CHASE_TICKS ago, is the one this tick overwrites.
		var slot := t.ticks % CHASE_TICKS
		var then_at := chase_at[c.id][slot]
		var then_gap := chase_gap[c.id][slot]
		chase_at[c.id][slot] = c.position
		chase_gap[c.id][slot] = Vector2(c.position.x - leader.position.x, c.position.z - leader.position.z).length()
		if following[c.id] < FOLLOW_REJOIN:
			continue
		judge_follower(t, c, leader, leader_moving, squad, tuning.movement.sprint_speed, then_at, then_gap)


## One judged tick of follower `c` behind `leader` (moving or not) into `t`: near, standing, chasing or how far behind.
## `then_at` and `then_gap` are where `c` was and its gap to the leader CHASE_TICKS ago (the gap -1: not known).
static func judge_follower(t: MatchTally, c: Character, leader: Character, leader_moving: bool, squad: SquadConfig,
		sprint_speed: float, then_at: Vector3, then_gap: float) -> void:
	var d := Vector2(c.position.x - leader.position.x, c.position.z - leader.position.z).length()
	t.follow_counted += 1
	if d < squad.follow_distance + squad.catch_up_gap + FOLLOW_NEAR_SLACK:
		t.follow_near += 1
	if leader_moving and Vector2(c.velocity.x, c.velocity.z).length() < STILL_SPEED:
		t.follow_standing += 1
	if chasing(c, leader, squad.catch_up, sprint_speed, then_at, then_gap):
		t.follow_chasing += 1
	else:
		t.follow_worst = maxf(t.follow_worst, d)


## Whether follower `c` is chasing `leader` rather than left behind: further than `catch_up` (m) from it, and since
## CHASE_TICKS ago (when it stood at `then_at`, `then_gap` m from the leader; -1: not known) it covered ground at
## CHASE_PACE of `sprint_speed` (m/s) or more and the gap grew by CHASE_SLACK at most, only while the leader moves at
## CHASE_PACE of it or faster (otherwise the gap must shrink). Flat distances.
static func chasing(c: Character, leader: Character, catch_up: float, sprint_speed: float, then_at: Vector3,
		then_gap: float) -> bool:
	var d := Vector2(leader.position.x - c.position.x, leader.position.z - c.position.z).length()
	if d <= catch_up or then_gap < 0.0:
		return false
	var covered := Vector2(c.position.x - then_at.x, c.position.z - then_at.z).length()
	if covered < CHASE_PACE * sprint_speed * CHASE_TICKS * DT:
		return false
	var leader_fast := Vector2(leader.velocity.x, leader.velocity.z).length() >= CHASE_PACE * sprint_speed
	return d <= then_gap + CHASE_SLACK if leader_fast else d < then_gap


## Standing still on purpose, not held up: an anchor settled at its post (bots.md › Holds until), a bot watching where
## someone ducked out of sight (Watch where you ducked), or one pausing at a lane point or waiting there for its team
## (holding this tick, on its lane), or at its spot by the pole (Attack / Defend: its route there done).
static func holding_on_purpose(b: Bot, time: float) -> bool:
	return b.at_post or time < b.watch_until or (b.mode == Bot.Mode.ADVANCE and b.holding) \
			or (b.mode == Bot.Mode.FLAG and b.route_state == Bot.RouteState.NONE)


static func _bot_of(bots: BotController, id: int) -> Bot:
	for b in bots.world.bots:
		if b.character.id == id:
			return b
	return null
