extends GutTest
## The match guards (MG1; the browser game's depotMatch*.test.ts and depotMatchSupport.ts): whole bot-against-bot
## Elimination matches over 16 seeds on Depot at Normal, and 8 at Easy and Hard (Woodland's in test_woodland_guards.gd),
## checking only what must never happen on any seed. Every match is won, few rounds run out the clock, every bot leaves
## its spawn each round and isn't held up on its way, nobody falls through the floor, flies or leaves the level, and no
## bot knocks out a teammate; on Depot, bot teammates told to follow a leader keep up with it (Follow me). Who wins is
## the balance report's (BR1), never asserted here. Thresholds are the browser's, re-measured over these seeds
## (docs/records/MG1.md); re-measure over all 16 before changing one. Run by tools/match_guards.sh, in four CI jobs (one
## a test).

## Follow me on Depot (the browser's depotMatch.test.ts, M22): seeds 1 to FOLLOW_SEEDS of FOLLOW_SECONDS each, a leader
## bot giving it at each round start. Each seed judges more than FOLLOW_TICKS ticks, with more than FOLLOW_NEAR of them
## near the leader (MatchRunner.FOLLOW_NEAR_SLACK) and the farthest under catch_up, a follower sprinting for the leader
## beyond it counting as chasing, not left behind (MatchRunner.CHASE_PACE; lead ruling, DP4); standing still
## while the leader moves, under FOLLOW_STANDING of the ticks over all four (one seed's share swings with a single long
## wait).
const FOLLOW_SEEDS := 4
const FOLLOW_SECONDS := 90.0
const FOLLOW_TICKS := 1000
const FOLLOW_NEAR := 0.95
const FOLLOW_STANDING := 0.03


func test_depot_matches_play_out_on_every_seed() -> void:
	await MatchGuard.elimination(self, "depot")


func test_depot_matches_play_out_at_easy_and_hard() -> void:
	for level: StringName in [&"easy", &"hard"]:
		await MatchGuard.elimination(self, "depot", level, MatchGuard.LEVEL_SEEDS)


func test_bot_teammates_follow_a_leader_round_depot_without_being_left_behind() -> void:
	var runner := MatchRunner.new(self, "depot")
	runner.follow_leader = 0
	await wait_physics_frames(2)
	var catch_up := runner.config.squad.catch_up
	var counted := 0
	var standing := 0
	for seed_value in range(1, FOLLOW_SEEDS + 1):
		var m := runner.play(seed_value, FOLLOW_SECONDS)
		var at := "depot follow seed %d" % seed_value
		var near := float(m.follow_near) / maxf(m.follow_counted, 1.0)
		gut.p("%s: %d ticks judged, %.1f %% near, worst %.2f m, standing %.1f %%, chasing %d ticks" % [at,
				m.follow_counted, near * 100.0, m.follow_worst, 100.0 * m.follow_standing / maxf(m.follow_counted, 1.0),
				m.follow_chasing])
		assert_gt(m.follow_counted, FOLLOW_TICKS, "%s: enough ticks judged" % at)
		assert_gt(near, FOLLOW_NEAR, "%s: followers keep near the leader" % at)
		assert_lt(m.follow_worst, catch_up, "%s: never left behind" % at)
		counted += m.follow_counted
		standing += m.follow_standing
	var still := float(standing) / maxf(counted, 1.0)
	gut.p("depot follow: standing still %.2f %% of %d ticks" % [still * 100.0, counted])
	assert_lt(still, FOLLOW_STANDING, "followers rarely stand while the leader moves")
	runner.free_level()


## Dev settings › Bots run low on BBs (MH2): over each guard seed's first MAG_SECONDS of play on Depot and Woodland (at
## the size and time each is played), every bot put low that stays in play with its round live gets a magazine within
## MAG_WITHIN s. A bot hit, or its round over, before then is left out (and counted), as is one with no teammate in play
## within the ask's reach with one to spare, as it is put low or once its givers are hit: nobody it could ask. One whose
## giver fought or took cover meanwhile is counted apart and printed (fights and cover come first, criterion 1).
const MAG_SECONDS := 60.0
const MAG_WITHIN := 10.0
## Bots put low whose giver's fight or cover held it past MAG_WITHIN, at most, a field: twice the most measured
## (docs/records/MH2.md).
const MAG_HELD_MAX := 2


## Who Bots run low on BBs put low each round and what came of it, read after every tick (MatchRunner.each_tick).
class MagWatch:
	extends RefCounted
	var after: float = 0.0
	var round_start: float = 0.0
	## Each team's bot put low this round has been seen (bit per team).
	var picked: int = 0
	## Per pending bot: character id, when it was put low, and the giver's distance at its ask (-1: none yet).
	var ids: PackedInt32Array = PackedInt32Array()
	var low_at: PackedFloat64Array = PackedFloat64Array()
	var walk: PackedFloat64Array = PackedFloat64Array()
	## Per pending bot: whether the teammate it asked has fought or taken cover since (fights come first).
	var fought: PackedByteArray = PackedByteArray()
	## What came of it: the wait (s) and the giver's distance at the ask (m) of each served; those late, and those late
	## whose giver fought or took cover meanwhile (held: fights come first); those left out (hit, the round over); those
	## with nobody to ask, as put low or once their givers were hit.
	var waits: PackedFloat64Array = PackedFloat64Array()
	var walks: PackedFloat64Array = PackedFloat64Array()
	var late: PackedStringArray = PackedStringArray()
	var held: PackedStringArray = PackedStringArray()
	var left_out: int = 0
	var nobody: int = 0
	var seed_value: int = 0

	func _init(low_after: float) -> void:
		after = low_after

	func start(seed_number: int) -> void:
		seed_value = seed_number
		round_start = 0.0
		picked = 0
		ids.clear()
		low_at.clear()
		walk.clear()
		fought.clear()

	func tick(state: GameState, bots: BotController) -> void:
		state.cheats.bots_run_low = true
		var events := state.events
		if events.count_of(GameEvent.Kind.ROUND_START) > 0:
			left_out += ids.size()
			start(seed_value)
			round_start = state.time
		# BotController puts them low in a think mag_dev_low_after into the round (DevCheats.run_low), and a bot put low
		# may ask in the same tick: seen here once low, before the tick's events are read.
		var since := state.time - round_start
		if picked != 3 and state.round_state.is_live() and since >= after - MatchRunner.DT and since < after + 1.0:
			for team in 2:
				var c := DevCheats.low_pick(state, team, -1)
				if picked & (1 << team) or c == null or not MagShare.low_on(c.armament, 1):
					continue
				picked |= 1 << team
				if not Elimination.is_in_play(c):
					continue
				if not _anyone_near(c, state, bots.world):
					nobody += 1
				else:
					ids.append(c.id)
					low_at.append(state.time - MatchRunner.DT)
					walk.append(-1.0)
					fought.append(0)
		for n in events.count:
			var e := events.items[n]
			var k := ids.find(e.target if e.kind == GameEvent.Kind.MAG_CATCH else e.actor)
			if e.kind == GameEvent.Kind.MAG_ASK and k >= 0:
				var giver := state.character(e.target)
				walk[k] = state.character(e.actor).position.distance_to(giver.position) if giver != null else -1.0
			elif e.kind == GameEvent.Kind.MAG_CATCH and k >= 0 and e.value > 0:
				waits.append(state.time - low_at[k])
				walks.append(walk[k])
				_forget(k)
		for k in range(ids.size() - 1, -1, -1):
			var c := state.character(ids[k])
			var giver := state.character(c.mag.asked) if c.mag.asked >= 0 else null
			var b := BotMagShare.bot_of(giver, bots.world) if giver != null else null
			if b != null and (b.mode == Bot.Mode.FIGHT or b.mode == Bot.Mode.COVER):
				fought[k] = 1
			if not Elimination.is_in_play(c) or not state.round_state.is_live():
				left_out += 1
				_forget(k)
			elif state.time - low_at[k] > MAG_WITHIN:
				var what := "seed %d character %d at %.1f s" % [seed_value, ids[k], low_at[k]]
				if not _anyone_near(c, state, bots.world):
					nobody += 1 # its givers were hit meanwhile
				elif fought[k] == 1:
					held.append(what)
				else:
					late.append(what)
				_forget(k)

	## A teammate of `c` in play within the ask's reach with a magazine to spare for it.
	static func _anyone_near(c: Character, state: GameState, w: BotWorld) -> bool:
		for o in state.characters:
			if o != c and o.team == c.team and Elimination.is_in_play(o) and w.mag_share.has_mag_for(o, c) \
					and o.position.distance_to(c.position) <= w.mag_share.cfg.ask_range:
				return true
		return false

	func _forget(k: int) -> void:
		ids.remove_at(k)
		low_at.remove_at(k)
		walk.remove_at(k)
		fought.remove_at(k)


func test_a_bot_put_low_gets_a_magazine_within_10_s_on_depot_and_woodland() -> void:
	for map_id: String in ["depot", "woodland"]:
		var r: MatchRunner = await MatchGuard.runner(self, map_id, &"normal", false)
		var watch := MagWatch.new(r.config.mag_dev_low_after)
		r.each_tick = watch.tick
		for seed_value in range(1, MatchGuard.SEEDS + 1):
			watch.start(seed_value)
			r.play(seed_value, MAG_SECONDS)
		var waits := Array(watch.waits)
		waits.sort()
		gut.p(("%s bots run low: %d served, waits %s s, givers' walks %s m; %d late %s; %d held by the giver's fight %s; "
				+ "%d left out (hit or round over), %d with nobody to ask") % [map_id, waits.size(),
				str(waits.map(func(x: float) -> String: return "%.1f" % x)),
				str(Array(watch.walks).map(func(x: float) -> String: return "%.0f" % x)), watch.late.size(),
				str(watch.late), watch.held.size(), str(watch.held), watch.left_out, watch.nobody])
		assert_gt(waits.size(), 0, "%s: some bot put low is served" % map_id)
		assert_eq(watch.late.size(), 0, "%s: every bot put low gets one within %.0f s" % [map_id, MAG_WITHIN])
		assert_lte(watch.held.size(), MAG_HELD_MAX, "%s: a giver's fight seldom holds one up" % map_id)
		r.free_level()
