extends GutTest
## The callouts' guards (CO1; the browser game's depotMatch.callouts.test.ts, CL1): whole bot matches with the shipped
## data/callouts.md. On every field (Depot in both modes, Woodland at night) a seeded match plays the same with the
## callouts as without: the same shots, hits, rounds and flag; a replay says the same calls. On every map every call
## keeps the pace (one a team a tick, the team's and the bot's gaps, which Flash out alone may cut into: BC1), comes
## from a bot in play during a live round and fits a feed line, and the calls come at a steady rate; the rates print
## beside the browser's for the record. Run by tools/match_guards.sh, a CI job of its own.

const SLACK := 1e-6
## Calls a team a minute of live play: enough to hear the team, never a stream (the team's gap alone allows 40).
const RATE_MIN := 3.0
const RATE_MAX := 20.0
## The browser's match: seed 1 for 180 s on each map; seed 2 for 120 s to compare with and without.
const PACE_SEED := 1
const PACE_SECONDS := 180.0
const SAME_SEED := 2
const SAME_SECONDS := 120.0
## QA's additions (the other fields, a replay) play this long.
const OTHER_SECONDS := 90.0
## The events every map's runs call somewhere between them (the browser's list).
const CALLED: Array[int] = [
	CalloutsFile.Event.CONTACT, CalloutsFile.Event.DOWN, CalloutsFile.Event.LAST_ONE, CalloutsFile.Event.HEARD,
	CalloutsFile.Event.CHECKING, CalloutsFile.Event.FLANKING, CalloutsFile.Event.HOLDING, CalloutsFile.Event.RAISING,
	CalloutsFile.Event.FLAG,
]


## Every call said over a match, checked as it is said (MatchRunner.each_tick).
class Heard:
	extends RefCounted
	var calls: int = 0
	var live_seconds: float = 0.0
	var events: Dictionary[int, int] = {}
	var problems: PackedStringArray = PackedStringArray()
	var _read: int = 0
	var _team_said: PackedFloat64Array = PackedFloat64Array([-INF, -INF])
	var _bot_said: Dictionary[int, float] = {}

	func on_tick(state: GameState, bots: BotController) -> void:
		var pace := CalloutsFile.shared().pace
		var ring := bots.callouts.said
		var t := state.time
		if state.round_state.is_live():
			live_seconds += MatchRunner.DT
		if ring.total - _read > ring.capacity():
			problems.append("%.2f s: more calls in a tick than the log keeps" % t)
		var teams := PackedInt32Array()
		for n in range(maxi(_read, ring.oldest()), ring.total):
			var c := ring.entry(n)
			var speaker := state.character(c.speaker_id)
			var at := "%.2f s, %d \"%s\"" % [t, c.speaker_id, c.line]
			calls += 1
			events[c.event] = events.get(c.event, 0) + 1
			if c.time != t:
				problems.append("%s: said at %.2f s, logged after" % [at, c.time])
			if not state.round_state.is_live():
				problems.append("%s: said outside a live round" % at)
			if speaker == null or speaker.team != c.team or not Elimination.is_in_play(speaker):
				problems.append("%s: the speaker is not in play on that team" % at)
			if bots.world.bot_of(speaker) == null:
				problems.append("%s: the speaker is not a bot" % at)
			if teams.has(c.team):
				problems.append("%s: a second call for the team this tick" % at)
			teams.append(c.team)
			# Flash out goes at once, past both gaps: the bang is only a moment off (callouts.md, BC1).
			var urgent := c.event == CalloutsFile.Event.FLASH_OUT
			if not urgent and t - _team_said[c.team] < pace.team_gap - SLACK:
				problems.append("%s: the team spoke %.2f s ago" % [at, t - _team_said[c.team]])
			if not urgent and t - _bot_said.get(c.speaker_id, -INF) < pace.bot_gap - SLACK:
				problems.append("%s: the bot spoke within its gap" % at)
			if c.line == "" or c.line.length() > CalloutsFile.LINE_MAX or c.line.contains("{") or c.line.contains("}"):
				problems.append("%s: not a filled line that fits" % at)
			_team_said[c.team] = t
			_bot_said[c.speaker_id] = t
		_read = ring.total
		if state.events.count_of(GameEvent.Kind.ROUND_START) > 0:
			_team_said.fill(-INF)

	## Calls a team a minute of live play.
	func rate() -> float:
		return calls / 2.0 / maxf(live_seconds / 60.0, 1e-6)


func test_depot_plays_the_same_with_the_callouts_as_without() -> void:
	for mode: RoundState.Mode in [RoundState.Mode.ELIMINATION, RoundState.Mode.ATTACK_DEFEND]:
		var r: MatchRunner = await MatchGuard.runner(self, "depot", &"normal", false, mode)
		r.talk = false
		var quiet := r.play(SAME_SEED, SAME_SECONDS)
		r.talk = true
		var heard := Heard.new()
		r.each_tick = heard.on_tick
		var talking := r.play(SAME_SEED, SAME_SECONDS)
		r.free_level()
		var at := "depot %s" % ("attack/defend" if mode == RoundState.Mode.ATTACK_DEFEND else "elimination")
		assert_gt(heard.calls, 5, "%s: the bots talk" % at)
		assert_eq(heard.problems, PackedStringArray(), at)
		assert_eq([talking.shots, talking.hits, talking.ticks], [quiet.shots, quiet.hits, quiet.ticks], at)
		assert_eq(talking.hits_by, quiet.hits_by, at)
		assert_eq(talking.farthest, quiet.farthest, at)
		assert_eq(_rounds(talking), _rounds(quiet), at)
		gut.p("%s, seed %d, %d s: %d shots, %d hits, %d rounds, the same with %d calls" % [at, SAME_SEED,
				SAME_SECONDS, quiet.shots, quiet.hits, quiet.rounds.size(), heard.calls])


func test_woodland_plays_the_same_with_the_callouts_as_without() -> void:
	# QA (CO1): the same check on the other field, Woodland at night.
	for run: Array in [["woodland", RoundState.Mode.ELIMINATION]]:
		var r: MatchRunner = await MatchGuard.runner(self, run[0], &"normal", false, run[1])
		r.talk = false
		var quiet := r.play(SAME_SEED, OTHER_SECONDS)
		r.talk = true
		var heard := Heard.new()
		r.each_tick = heard.on_tick
		var talking := r.play(SAME_SEED, OTHER_SECONDS)
		var at := MatchGuard.label(r, run[0])
		r.free_level()
		assert_gt(heard.calls, 3, "%s: the bots talk" % at)
		assert_eq(heard.problems, PackedStringArray(), at)
		assert_eq([talking.shots, talking.hits, talking.ticks], [quiet.shots, quiet.hits, quiet.ticks], at)
		assert_gt(quiet.shots, 0, "%s: shots were fired" % at)
		assert_eq(talking.hits_by, quiet.hits_by, at)
		assert_eq(talking.farthest, quiet.farthest, at)
		assert_eq(_rounds(talking), _rounds(quiet), at)
		gut.p("%s, seed %d, %d s: %d shots, %d hits, %d rounds, the same with %d calls" % [at, SAME_SEED,
				OTHER_SECONDS, quiet.shots, quiet.hits, quiet.rounds.size(), heard.calls])


func test_the_same_seed_says_the_same_calls_in_the_same_order() -> void:
	# QA (CO1): a replay repeats the calls (speaker, event, line, time), and another seed says something else.
	var r: MatchRunner = await MatchGuard.runner(self, "depot", &"normal", false)
	var runs: Array[Array] = [[], [], []]
	var seeds: Array[int] = [SAME_SEED, SAME_SEED, SAME_SEED + 1]
	for k in 3:
		var out: Array = runs[k]
		var seen: Array[int] = [0]
		r.each_tick = func(_state: GameState, bots: BotController) -> void:
			var ring := bots.callouts.said
			for n in range(seen[0], ring.total):
				var c := ring.entry(n)
				out.append("%.3f %d %d %s" % [c.time, c.speaker_id, c.event, c.line])
			seen[0] = ring.total
		r.play(seeds[k], OTHER_SECONDS)
	var first := runs[0]
	var again := runs[1]
	var other := runs[2]
	r.free_level()
	assert_gt(first.size(), 5, "the bots talk")
	assert_eq(first, again, "the same seed, the same calls")
	assert_ne(first, other, "another seed, other play")


func test_every_map_keeps_the_pace_from_bots_in_play_at_a_steady_rate() -> void:
	# The browser's runs and its calls a team a minute (seed 1, 180 s).
	var runs: Array[Array] = [
		["depot", RoundState.Mode.ELIMINATION, 8.2],
		["depot", RoundState.Mode.ATTACK_DEFEND, 11.4],
		["woodland", RoundState.Mode.ELIMINATION, 6.8],
	]
	var called: Dictionary[int, int] = {}
	for run in runs:
		var r: MatchRunner = await MatchGuard.runner(self, run[0], &"normal", false, run[1])
		var heard := Heard.new()
		r.each_tick = heard.on_tick
		r.play(PACE_SEED, PACE_SECONDS)
		var at := "%s %s" % [MatchGuard.label(r, run[0]),
				"attack/defend" if run[1] == RoundState.Mode.ATTACK_DEFEND else "elimination"]
		r.free_level()
		assert_eq(heard.problems, PackedStringArray(), at)
		assert_gt(heard.live_seconds, 60.0, "%s: over a minute of live play" % at)
		assert_between(heard.rate(), RATE_MIN, RATE_MAX, "%s: calls a team a minute" % at)
		for e in heard.events:
			called[e] = called.get(e, 0) + heard.events[e]
		gut.p("%s: %d calls in %.0f s live, %.1f a team a minute (browser %.1f); %s" % [at, heard.calls,
				heard.live_seconds, heard.rate(), run[2], _events(heard.events)])
	for e in CALLED:
		assert_true(called.has(e), "%s is called somewhere" % CalloutsFile.EVENT_NAMES[e])


## A match's rounds as compared: winner, reason, length, the top of the flag, how far each went.
static func _rounds(t: MatchRunner.MatchTally) -> Array:
	var out := []
	for r in t.rounds:
		out.append([r.winner, r.reason, r.seconds, r.top_flag, r.first_hit_time, r.farthest])
	return out


## The events called and how often, most first.
static func _events(events: Dictionary[int, int]) -> String:
	var keys := events.keys()
	keys.sort_custom(func(a: int, b: int) -> bool: return events[a] > events[b])
	var out := PackedStringArray()
	for e: int in keys:
		out.append("%s %d" % [CalloutsFile.EVENT_NAMES[e], events[e]])
	return ", ".join(out)
