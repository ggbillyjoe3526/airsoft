extends GutTest
## The match guards' held-up measure (tests/support/match_runner.gd): a bot on its way that stays put or goes round in
## a loop on one errand counts; one that gets somewhere, fights in between, changes errand or holds on purpose does not.

const SECONDS := MatchRunner.HELD_UP_SECONDS

var config: BotConfig = BotConfig.load_default()


func _ring() -> PackedVector3Array:
	errands = PackedInt32Array()
	errands.resize(SECONDS)
	var ring := PackedVector3Array()
	ring.resize(SECONDS)
	ring.fill(Vector3.INF)
	return ring


## Each sample's errand ring, beside `_ring()`'s positions.
var errands: PackedInt32Array = PackedInt32Array()


## Feeds one sample a second from `places` (looping over them) for `seconds`, on errand `errand` (ADVANCE unless it
## says otherwise); true if held up at the last.
func _feed(ring: PackedVector3Array, places: Array[Vector3], seconds: int, on_way: Callable = func(_s: int) -> bool:
		return true, errand: Callable = func(_s: int) -> int: return Bot.Mode.ADVANCE) -> bool:
	var held := false
	for s in seconds:
		held = MatchRunner.held_up_sample(ring, errands, s % SECONDS, places[s % places.size()], errand.call(s),
				on_way.call(s))
	return held


func _bot() -> Bot:
	var me := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	return Bot.new(me, 1, config.skill_for(&"easy"), 2)


func test_a_bot_frozen_on_its_way_counts_once_the_window_is_full() -> void:
	var ring := _ring()
	assert_false(_feed(ring, [Vector3.ZERO] as Array[Vector3], SECONDS), "not before a whole window")
	assert_true(_feed(ring, [Vector3.ZERO] as Array[Vector3], 1), "a whole window on the spot")


func test_a_bot_going_round_in_a_loop_counts() -> void:
	var ring := _ring()
	# Up the stairs and back every ten seconds: far apart in between, back at the same place.
	var places: Array[Vector3] = []
	for s in SECONDS:
		places.append(Vector3(0.0, 0.0, 8.0 * sin(PI * s / SECONDS)))
	assert_true(_feed(ring, places, SECONDS * 2 + 1), "back where it was ten seconds ago")


## The loop above, hunting the whole time: one errand throughout, so it still counts.
func test_a_bot_looping_on_one_search_counts() -> void:
	var ring := _ring()
	var places: Array[Vector3] = []
	for s in SECONDS:
		places.append(Vector3(10.0 * sin(PI * s / SECONDS), 0.0, 0.0))
	assert_true(_feed(ring, places, SECONDS * 2 + 1, func(_s: int) -> bool: return true,
			func(_s: int) -> int: return Bot.Mode.SEARCH), "searching out and back to the same spot, again and again")


## Frozen in a doorway while its mode flips between its lane and a search every few seconds, jittering a few
## centimetres: never far from where it was, so held up whatever the errand.
func test_a_frozen_bot_whose_errand_flips_counts() -> void:
	var ring := _ring()
	var jitter: Array[Vector3] = [Vector3.ZERO, Vector3(0.05, 0.0, 0.0), Vector3(0.0, 0.0, 0.05)]
	var flips := func(s: int) -> int: return Bot.Mode.ADVANCE if (s / 3) % 2 == 0 else Bot.Mode.SEARCH
	assert_true(_feed(ring, jitter, SECONDS * 2 + 1, func(_s: int) -> bool: return true, flips),
			"stuck on the spot, flipping between lane and search")


## Pacing ±0.5 m across a doorway every second while its mode flips: 5 to 10 m of path over the window, but never more
## than a metre from where it was, so held up whatever the errand.
func test_a_bot_dithering_in_a_doorway_whose_errand_flips_counts() -> void:
	var ring := _ring()
	var pacing: Array[Vector3] = [Vector3(-0.5, 0.0, 0.0), Vector3(0.5, 0.0, 0.0)]
	var flips := func(s: int) -> int: return Bot.Mode.ADVANCE if (s / 3) % 2 == 0 else Bot.Mode.SEARCH
	assert_true(_feed(ring, pacing, SECONDS * 2 + 1, func(_s: int) -> bool: return true, flips),
			"pacing the doorway, flipping between lane and search")


## A search given up for its lane, walking back the way it came (DP1, Depot seed 7 at Pro, now Hard): out 10 m
## searching, back advancing, at the same place ten seconds apart. Not held up; a whole window on the lane errand on the spot is.
func test_a_search_given_up_for_the_lane_walking_back_does_not_count() -> void:
	var ring := _ring()
	var places: Array[Vector3] = []
	for s in SECONDS:
		places.append(Vector3(10.0 * sin(PI * s / SECONDS), 0.0, 0.0))
	var search_then_lane := func(s: int) -> int: return Bot.Mode.SEARCH if s < SECONDS + SECONDS / 2 else Bot.Mode.ADVANCE
	assert_false(_feed(ring, places, SECONDS * 2 + 1, func(_s: int) -> bool: return true, search_then_lane),
			"back where it was, but on another errand since")
	var spot: Array[Vector3] = [Vector3.ZERO]
	assert_true(_feed(ring, spot, SECONDS * 2 + 1, func(_s: int) -> bool: return true,
			func(_s: int) -> int: return Bot.Mode.ADVANCE), "a whole window on its lane on the spot")


## A hunter whose spot a teammate checked first, turning for another spot the way it came (WR1, Woodland seed 7): out
## and back on two hunts in one mode. Not held up; one hunt throughout, or on the spot, still is.
func test_a_hunt_for_another_spot_walking_back_does_not_count() -> void:
	var b := _bot()
	b.hunting = true
	b.hunt_goal = Vector3(-12.0, 0.0, -30.0)
	var first := MatchRunner.errand_of(b, Bot.Mode.ADVANCE)
	b.hunt_goal = Vector3(23.0, 0.0, -13.0)
	var second := MatchRunner.errand_of(b, Bot.Mode.ADVANCE)
	assert_ne(first, second, "two spots, two errands")
	b.hunting = false
	assert_eq(MatchRunner.errand_of(b, Bot.Mode.ADVANCE), int(Bot.Mode.ADVANCE), "its lane: the mode")
	var ring := _ring()
	var places: Array[Vector3] = []
	for s in SECONDS:
		places.append(Vector3(28.0 * sin(PI * s / SECONDS), 0.0, 0.0))
	var two_hunts := func(s: int) -> int: return first if s < SECONDS + SECONDS / 2 else second
	assert_false(_feed(ring, places, SECONDS * 2 + 1, func(_s: int) -> bool: return true, two_hunts),
			"back where it was, but hunting another spot since")
	assert_true(_feed(ring, places, SECONDS * 2 + 1, func(_s: int) -> bool: return true,
			func(_s: int) -> int: return second), "round in a loop on one hunt")


func test_a_bot_that_gets_somewhere_does_not_count() -> void:
	var ring := _ring()
	var places: Array[Vector3] = []
	for s in SECONDS * 3:
		places.append(Vector3(float(s), 0.0, 0.0))
	assert_false(_feed(ring, places, SECONDS * 3))


func test_a_fight_in_the_window_does_not_count_and_after_a_whole_window_on_the_spot_it_does() -> void:
	var ring := _ring()
	var fight_at := SECONDS + 3
	var places: Array[Vector3] = [Vector3.ZERO]
	assert_false(_feed(ring, places, SECONDS * 2, func(s: int) -> bool: return s != fight_at), "fought 7 s ago")
	assert_true(_feed(ring, places, SECONDS * 3 + 1, func(s: int) -> bool: return s != fight_at), "a window since")


func test_holding_on_purpose_is_an_anchor_at_its_post_a_watch_or_a_pause_on_its_lane() -> void:
	var b := _bot()
	b.mode = Bot.Mode.SEARCH
	assert_false(MatchRunner.holding_on_purpose(b, 10.0), "hunting")
	b.at_post = true
	assert_true(MatchRunner.holding_on_purpose(b, 10.0), "an anchor at its post")
	b.at_post = false
	b.watch_until = 12.0
	assert_true(MatchRunner.holding_on_purpose(b, 10.0), "watching where someone ducked")
	assert_false(MatchRunner.holding_on_purpose(b, 13.0), "the watch over")
	b.mode = Bot.Mode.ADVANCE
	b.holding = true
	assert_true(MatchRunner.holding_on_purpose(b, 13.0), "pausing or waiting for its team at a lane point")


func test_a_pause_cut_short_by_a_fight_does_not_excuse_a_stuck_search() -> void:
	var b := _bot()
	b.wait_for_team = true
	b.holding = true
	b.mode = Bot.Mode.SEARCH
	assert_false(MatchRunner.holding_on_purpose(b, 10.0), "hunting now, whatever its pause left behind")
