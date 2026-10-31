class_name MatchGuard
extends RefCounted
## The match guards' plays (MG1, FG2, WL10), shared by the files in tests/guards: whole bot-against-bot matches on one
## field at one level, by day or at night, every match checked for what must never happen on any seed, the totals
## printed. Each file holds its own field-specific checks (Depot's Follow me, the pole mattering); the limits here are
## the browser's, re-measured over these seeds (docs/records/MG1.md and FG2.md): re-measure over all 16 before changing
## one.

## Seeds at Normal, and at the other levels: enough to catch a level that stalls or strands its bots.
const SEEDS := 16
const LEVEL_SEEDS := 8
## Match time a match may take before it counts as stalled (s).
const MAX_MATCH_SECONDS := 30.0 * 60.0
## Rounds that run out the clock, at most this share of all (the browser's STALLED_ROUNDS_MAX).
const STALLED_ROUNDS_MAX := 0.25
## Times a bot is held up on its way in one match (MatchRunner.HELD_UP_SECONDS), at most: twice the most measured.
const HELD_UP_MAX := 10
## Feet never below the lowest floor (or the terrain's lowest point) by more than this, nor above the highest block by
## more (m).
const BELOW_FLOOR := 0.25
const ABOVE_TOP := 2.0
## Longest time off the ground outside a vault (s): a drop off the tallest crate is about 0.7 s.
const LONGEST_AIR := 1.0
## A round never lasts past the clock and its mode's longest overtime (Round.longest_overtime: Attack / Defend's rope,
## Elimination's flag) by more than a tick or two (s).
const ROUND_SLACK := 0.1


## A runner on `map_id` at the team size the game plays there (MatchRunner.sized_for: Woodland 5v5), at `level`, at
## night when `night` is set or the map offers no day, else by day; with `base`'s tuning when given.
static func runner(test: GutTest, map_id: String, level: StringName, night: bool,
		mode: RoundState.Mode = RoundState.Mode.ELIMINATION, base: SimTuning = null) -> MatchRunner:
	var r := MatchRunner.new(test, map_id, MatchRunner.sized_for(map_id, base))
	r.difficulty = level
	r.night = night or r.night
	r.mode = mode
	await test.wait_physics_frames(2)
	test.assert_eq(r.map.problems, [] as Array[String], "%s loads" % map_id)
	test.assert_lt(r.lowest_floor, INF, "%s has a floor to guard" % map_id)
	return r


## The name a runner's field, level and time of day print under ("woodland hard night").
static func label(r: MatchRunner, map_id: String) -> String:
	return "%s %s%s" % [map_id, r.difficulty, " night" if r.night else ""]


## Elimination over seeds 1 to `seeds`: every match won, few rounds run out the clock, every character leaves its
## spawn over a match and every bot each round, nobody held up on its way, falls through the floor, flies, stays in the
## air or leaves the level, and no bot knocks out a teammate.
static func elimination(test: GutTest, map_id: String, level: StringName = &"normal", seeds: int = SEEDS,
		night: bool = false) -> void:
	var r: MatchRunner = await runner(test, map_id, level, night)
	var name := label(r, map_id)
	var longest := longest_round(r.tuning, RoundState.Mode.ELIMINATION)
	var rounds := 0
	var on_time := 0
	var overtimes := 0
	var touches := 0
	var ricochets := 0
	var knocks := 0
	var rings := 0
	for seed_value in range(1, seeds + 1):
		var m := r.play(seed_value, MAX_MATCH_SECONDS)
		var at := "%s seed %d" % [name, seed_value]
		test.assert_true(m.finished, "%s: the match is won" % at)
		rounds += m.rounds.size()
		on_time += m.on_time()
		overtimes += m.overtimes()
		touches += m.flag_touches()
		ricochets += m.friendly_ricochets
		knocks += m.knocks
		rings += m.rings
		for id in m.farthest.size():
			test.assert_gt(m.farthest[id], MatchRunner.LEAVES_SPAWN, "%s: character %d leaves its spawn" % [at, id])
		for round_tally in m.rounds:
			test.assert_lte(round_tally.seconds, longest, "%s: no round runs past the clock and its overtime" % at)
		_heights(test, r, m, at)
		test.assert_eq(m.stayed_home, 0, "%s: every bot leaves its spawn each round" % at)
		test.assert_lte(m.held_up, HELD_UP_MAX, "%s: bots aren't held up on their way" % at)
		test.assert_eq(m.friendly_hits, 0, "%s: no bot knocks out a teammate" % at)
	test.gut.p(("%s: %d rounds over %d seeds, %d on time, %d to the overtime flag (%d touched), %d teammates reached "
			+ "by a bounce, %d knocks and %d rings") % [name, rounds, seeds, on_time, overtimes, touches, ricochets, knocks,
			rings])
	test.assert_gt(rounds, 0)
	test.assert_lt(float(on_time) / maxf(rounds, 1.0), STALLED_ROUNDS_MAX, "%s: rounds settle, not stand-offs" % name)
	r.free_level()


## Attack / Defend over seeds 1 to `seeds` (the map needs a pole), checked as Elimination is, except that only the
## attackers must leave their spawn (defenders hold by their pole), and no round runs past the clock and the longest
## overtime. Returns [rounds, captures, matches with a flag raised, rounds on time] for the file's own checks.
static func attack_defend(test: GutTest, map_id: String, level: StringName = &"normal", seeds: int = SEEDS,
		night: bool = false) -> PackedInt32Array:
	var r: MatchRunner = await runner(test, map_id, level, night, RoundState.Mode.ATTACK_DEFEND)
	test.assert_true(r.map.has_pole, "%s has a pole" % map_id)
	var name := label(r, map_id) + " A/D"
	var longest := longest_round(r.tuning, RoundState.Mode.ATTACK_DEFEND)
	var rounds := 0
	var captures := 0
	var raised := 0
	var on_time := 0
	for seed_value in range(1, seeds + 1):
		var m := r.play(seed_value, MAX_MATCH_SECONDS)
		var at := "%s seed %d" % [name, seed_value]
		test.assert_true(m.finished, "%s: the match is won" % at)
		rounds += m.rounds.size()
		captures += m.captures()
		on_time += m.on_time()
		raised += 1 if m.flag_raised() else 0
		for round_tally in m.rounds:
			test.assert_lte(round_tally.seconds, longest, "%s: no round runs past the clock and its overtime" % at)
		_heights(test, r, m, at)
		test.assert_eq(m.stayed_home, 0, "%s: every attacker leaves its spawn each round" % at)
		test.assert_lte(m.held_up, HELD_UP_MAX, "%s: bots aren't held up on their way" % at)
		test.assert_eq(m.friendly_hits, 0, "%s: no bot knocks out a teammate" % at)
	test.gut.p("%s: %d rounds over %d seeds, %d captures, flag raised in %d matches, %d on time" % [name, rounds,
			seeds, captures, raised, on_time])
	test.assert_gt(rounds, 0)
	test.assert_lt(float(on_time) / maxf(rounds, 1.0), STALLED_ROUNDS_MAX, "%s: rounds settle, not stand-offs" % name)
	r.free_level()
	return PackedInt32Array([rounds, captures, raised, on_time])


## Elimination's overtime flag in play (OV2): Elimination over seeds 1 to `seeds` with `round_time` s rounds, short
## enough that most run out the clock and go to the flag, checked as Elimination is (every match won, no round past its
## clock and the flag's time, nobody falls, flies or leaves the level, no bot knocks out a teammate). Returns [rounds,
## overtimes, taken by a touch, won by a wipe-out, drawn on time] for the file's own checks.
static func overtime_flag(test: GutTest, map_id: String, round_time: float, level: StringName = &"normal",
		seeds: int = SEEDS, night: bool = false) -> PackedInt32Array:
	var base := SimTuning.load_default().duplicate(true) as SimTuning
	base.rounds.round_time = round_time
	var r: MatchRunner = await runner(test, map_id, level, night, RoundState.Mode.ELIMINATION, base)
	test.assert_true(r.map.has_overtime_flag, "%s has an overtime flag" % map_id)
	var name := "%s %ds rounds" % [label(r, map_id), roundi(round_time)]
	var longest := longest_round(r.tuning, RoundState.Mode.ELIMINATION)
	var t := PackedInt32Array([0, 0, 0, 0, 0])
	for seed_value in range(1, seeds + 1):
		var m := r.play(seed_value, MAX_MATCH_SECONDS)
		var at := "%s seed %d" % [name, seed_value]
		test.assert_true(m.finished, "%s: the match is won" % at)
		t[0] += m.rounds.size()
		for round_tally in m.rounds:
			test.assert_lte(round_tally.seconds, longest, "%s: no round runs past the clock and the flag's time" % at)
			if not round_tally.overtime:
				continue
			t[1] += 1
			match round_tally.reason:
				GameEvent.RoundEnd.OVERTIME_FLAG:
					t[2] += 1
				GameEvent.RoundEnd.ELIMINATED:
					t[3] += 1
				GameEvent.RoundEnd.TIME:
					t[4] += 1
		_heights(test, r, m, at)
		test.assert_eq(m.friendly_hits, 0, "%s: no bot knocks out a teammate" % at)
	test.gut.p("%s: %d rounds over %d seeds, %d to the overtime flag: %d touched, %d wiped out, %d drawn on time" % [
			name, t[0], seeds, t[1], t[2], t[3], t[4]])
	r.free_level()
	return t


## The longest a round in `mode` may run (s): its clock, the mode's longest overtime and a tick or two.
static func longest_round(tuning: SimTuning, mode: RoundState.Mode) -> float:
	return tuning.rounds.round_time + Round.longest_overtime(tuning, mode) + ROUND_SLACK


## Nobody falls through the floor, flies, stays in the air or leaves the level.
static func _heights(test: GutTest, r: MatchRunner, m: MatchRunner.MatchTally, at: String) -> void:
	test.assert_gte(m.min_y, r.lowest_floor - BELOW_FLOOR, "%s: nobody falls through the floor" % at)
	test.assert_lte(m.max_y, r.highest_top + ABOVE_TOP, "%s: nobody flies" % at)
	test.assert_lte(m.longest_air, LONGEST_AIR, "%s: nobody stays in the air" % at)
	test.assert_eq(m.rescued, 0, "%s: nobody leaves the level" % at)
