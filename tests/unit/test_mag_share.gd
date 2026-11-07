extends GutTest
## The magazine hand-off's rules (MH1; the browser game's sim/magShare.test.ts and sim/magShareSim.test.ts, MG1, with
## the ask of ai/magShare.ts and src/magHandoff.ts): who may toss to whom, which spare goes, the flight, what lands, who
## is asked and when, each refusal, and that no BB is ever made: the thrower's and the catcher's BBs add up to what they
## were, but a lost toss's. Headless, on a BoxWorld floor; the default loadout (an AEG rifle and a GBB pistol).

const DT := 1.0 / 60.0

var tuning: SimTuning = SimTuning.new()
var cfg: MagShareConfig = tuning.mag_share
var loadout: Array[ReplicaConfig] = []
var rifle: ReplicaConfig = null
var pistol: ReplicaConfig = null


func before_all() -> void:
	loadout = ReplicaStats.default_loadout()
	rifle = loadout[0]
	pistol = loadout[1]


## A floor 60 m by 30 m, and a wall across x = 2 if `walled`.
func _world(walled: bool = false) -> BoxWorld:
	var w := BoxWorld.new(tuning.body)
	w.add_floor(60.0, 30.0)
	if walled:
		w.add_box(Vector3(2.0, 1.5, 0.0), Vector3(0.2, 3.0, 4.0))
	return w


## A state with characters standing at `spots` (team 0 unless `teams` says), no match started.
func _state(spots: Array[Vector3], teams: Array[int] = []) -> GameState:
	var s := GameState.new(1, tuning)
	for i in spots.size():
		s.characters.append(Character.new(i, teams[i] if i < teams.size() else 0, spots[i], 0.0, loadout))
	return s


## Empties `c`'s spares for `slot`: on its last magazine.
static func _last_mag(c: Character, slot: int = 0) -> void:
	c.armament.ammo[slot].pouch.fill(0)


## Every BB the characters of `team` carry for `slot`: loaded and spare.
static func _held(s: GameState, slot: int = 0, team: int = 0) -> int:
	var n := 0
	for c in s.characters:
		if c.team == team:
			n += c.armament.ammo[slot].mag + c.armament.ammo[slot].spare_bbs()
	return n


static func _active(s: GameState) -> int:
	var n := 0
	for t in s.mag_tosses:
		if t.active:
			n += 1
	return n


func _refusal(s: GameState) -> int:
	var e := s.events.first(GameEvent.Kind.MAG_REFUSED)
	return e.value if e != null else -1


# --- Low on BBs, room and the spare a toss takes (sim/magShare.test.ts) ---


func test_low_is_less_than_one_full_spare_of_the_replica_in_hand() -> void:
	var a := Armament.create(loadout)
	assert_false(MagShare.low_on(a, cfg.low_mags))
	a.ammo[0].pouch.fill(0)
	a.ammo[0].pouch[0] = rifle.mag_size
	assert_false(MagShare.low_on(a, cfg.low_mags))
	a.ammo[0].pouch[0] = rifle.mag_size - 1
	assert_true(MagShare.low_on(a, cfg.low_mags))
	a.active = 1
	assert_false(MagShare.low_on(a, cfg.low_mags), "the pistol in hand has its spares")


func test_room_is_the_emptiest_spares_and_none_with_every_spare_full() -> void:
	var a := Armament.create(loadout)
	assert_eq(MagShare.pouch_room(a, 0), 0)
	a.ammo[0].pouch[1] = 20
	assert_eq(MagShare.pouch_room(a, 0), rifle.mag_size - 20)


func test_a_spare_fits_by_class_never_the_other() -> void:
	var giver := Armament.create(loadout)
	var out := MagShare.SparePick.new()
	assert_true(MagShare.choose_spare(giver, rifle, rifle.mag_size, out))
	assert_eq(out.slot, 0)
	assert_true(MagShare.choose_spare(giver, pistol, pistol.mag_size, out))
	assert_eq(out.slot, 1)
	giver.ammo[0].pouch.fill(0)
	assert_false(MagShare.choose_spare(giver, rifle, rifle.mag_size, out))


func test_a_spare_not_in_hand_goes_first_then_the_fullest_and_only_what_there_is_room_for() -> void:
	var two: Array[ReplicaConfig] = [rifle, rifle]
	var giver := Armament.create(two)
	giver.ammo[0].pouch[0] = 10
	giver.ammo[1].pouch[2] = 30
	var out := MagShare.SparePick.new()
	assert_true(MagShare.choose_spare(giver, rifle, 40, out))
	# Slot 1 is not in hand: its fullest spare goes, though slot 0 has fuller ones.
	assert_eq([out.slot, out.index, out.bbs], [1, 0, 40])
	giver.ammo[1].pouch.fill(0)
	assert_true(MagShare.choose_spare(giver, rifle, 40, out))
	assert_eq([out.slot, out.bbs], [0, 40])
	assert_ne(out.index, 0)


func test_only_the_replica_in_hand_counts_against_the_full_spare_kept() -> void:
	var giver := Armament.create(loadout)
	var out := MagShare.SparePick.new()
	MagShare.choose_spare(giver, rifle, rifle.mag_size, out)
	assert_false(MagShare.leaves_low(giver, out, cfg.keep_mags))
	giver.ammo[0].pouch.fill(0)
	giver.ammo[0].pouch[0] = rifle.mag_size
	MagShare.choose_spare(giver, rifle, rifle.mag_size, out)
	assert_true(MagShare.leaves_low(giver, out, cfg.keep_mags))
	MagShare.choose_spare(giver, pistol, pistol.mag_size, out)
	assert_false(MagShare.leaves_low(giver, out, cfg.keep_mags))


func test_landing_fills_the_emptiest_spares_first_each_up_to_a_full_magazine() -> void:
	var a := Armament.create(loadout)
	var pouch := a.ammo[0].pouch
	pouch.fill(0)
	pouch[0] = 50
	assert_eq(MagShare.fill_spares(a, 0, 70), 70)
	assert_eq(Array(a.ammo[0].pouch), [50, rifle.mag_size, 70 - rifle.mag_size])
	assert_eq(MagShare.fill_spares(a, 0, 500), rifle.mag_size * pouch.size() - 120)


# --- Who can toss to whom ---


func test_a_toss_needs_a_teammate_in_play_in_reach_in_sight_with_room() -> void:
	var s := _state([Vector3.ZERO, Vector3(3.0, 0.0, 0.0), Vector3(3.0, 0.0, 1.0)], [0, 0, 1])
	var ms := MagShare.new(tuning, _world())
	var out := MagShare.SparePick.new()
	var a := s.characters[0]
	var b := s.characters[1]
	var enemy := s.characters[2]
	assert_false(ms.can_toss_to(a, b, out), "b's spares are full")
	_last_mag(b)
	assert_true(ms.can_toss_to(a, b, out))
	assert_false(MagShare.new(tuning, _world(true)).can_toss_to(a, b, out), "a wall between")
	assert_false(ms.can_toss_to(a, a, out))
	_last_mag(enemy)
	assert_false(ms.can_toss_to(a, enemy, out))


func test_a_toss_reaches_toss_range_eye_to_chest_and_no_further() -> void:
	var s := _state([Vector3.ZERO, Vector3(cfg.toss_range - 0.2, 0.0, 0.0)])
	var ms := MagShare.new(tuning, _world())
	var out := MagShare.SparePick.new()
	_last_mag(s.characters[1])
	assert_true(ms.can_toss_to(s.characters[0], s.characters[1], out))
	s.characters[1].position.x = cfg.toss_range + 0.2
	assert_false(ms.can_toss_to(s.characters[0], s.characters[1], out))


func test_neither_from_nor_to_someone_out_of_play() -> void:
	var s := _state([Vector3.ZERO, Vector3(3.0, 0.0, 0.0)])
	var ms := MagShare.new(tuning, _world())
	var out := MagShare.SparePick.new()
	_last_mag(s.characters[1])
	s.characters[1].status = Character.Status.CALLING
	assert_false(ms.can_toss_to(s.characters[0], s.characters[1], out))
	s.characters[1].status = Character.Status.ALIVE
	s.characters[0].status = Character.Status.CALLING
	assert_false(ms.can_toss_to(s.characters[0], s.characters[1], out))


# --- A toss and its landing ---


## a (0) and b (1) `d` m apart, b on its last magazine and asking a; a presses.
func _toss_pair(d: float, slots: int = MagShareConfig.new().max_tosses) -> Array:
	var s := _state([Vector3.ZERO, Vector3(d, 0.0, 0.0)])
	s.mag_tosses = MagShare.make_tosses(slots)
	var ms := MagShare.new(tuning, _world())
	_last_mag(s.characters[1])
	s.characters[1].mag.asked = 0
	return [s, ms]


func test_a_toss_moves_the_bbs_and_never_makes_them() -> void:
	var p := _toss_pair(4.0)
	var s: GameState = p[0]
	var ms: MagShare = p[1]
	var b := s.characters[1]
	var before := _held(s)
	ms.press(s.characters[0], s, true)
	var e := s.events.first(GameEvent.Kind.MAG_TOSS)
	assert_not_null(e)
	assert_eq([e.actor, e.target, e.value, e.slot, e.value2], [0, 1, rifle.mag_size, 0, 0])
	var t: MagShare.Toss = s.mag_tosses[0]
	assert_almost_eq(t.flight, cfg.flight_base + cfg.flight_per_metre * ms.toss_distance(s.characters[0], b), 1e-6)
	assert_almost_eq(t.flight, cfg.flight_base + cfg.flight_per_metre * 4.0, 0.05)
	# In the air: out of the thrower's spares, not yet in the catcher's.
	assert_eq(_held(s), before - rifle.mag_size)
	assert_eq(b.mag.coming, 1)
	var ticks := 0
	while t.active and ticks < 600:
		s.events.clear()
		ms.step(s, true, DT)
		ticks += 1
	assert_eq(ticks, ceili(t.flight / DT))
	var caught := s.events.first(GameEvent.Kind.MAG_CATCH)
	assert_not_null(caught)
	assert_eq([caught.actor, caught.target, caught.value, caught.slot], [0, 1, rifle.mag_size, 0])
	assert_eq(_held(s), before)
	assert_false(ms.low(b))
	assert_eq(b.mag.asked, -1, "the ask ends as the magazine lands")
	assert_eq(b.mag.coming, 0)


func test_one_in_the_air_a_thrower_at_a_time_and_as_many_as_there_are_slots() -> void:
	var s := _state([Vector3.ZERO, Vector3(2.0, 0.0, 0.0), Vector3(0.0, 0.0, 2.0), Vector3(0.0, 0.0, -2.0)])
	s.mag_tosses = MagShare.make_tosses(1)
	var ms := MagShare.new(tuning, _world())
	_last_mag(s.characters[1])
	_last_mag(s.characters[2])
	s.characters[1].mag.asked = 0
	s.characters[2].mag.asked = 0
	ms.press(s.characters[0], s, true)
	ms.press(s.characters[0], s, true) # its own still in the air
	assert_eq(_refusal(s), MagShare.Refusal.WAIT)
	s.characters[2].mag.asked = 3
	s.events.clear()
	ms.press(s.characters[3], s, true) # no slot left
	assert_eq(_refusal(s), MagShare.Refusal.WAIT)
	assert_eq(_active(s), 1)


func test_the_pool_is_made_once_with_the_state() -> void:
	var s := GameState.new(1, tuning)
	assert_eq(s.mag_tosses.size(), cfg.max_tosses)
	assert_eq(cfg.max_tosses, 6)


func test_a_toss_is_lost_with_the_catcher_out_of_play_or_the_round_decided() -> void:
	for how: String in ["hit", "whistle"]:
		var p := _toss_pair(3.0)
		var s: GameState = p[0]
		var ms: MagShare = p[1]
		var before := _held(s)
		ms.press(s.characters[0], s, true)
		if how == "hit":
			s.characters[1].status = Character.Status.CALLING
		var lost: GameEvent = null
		for i in 120:
			s.events.clear()
			ms.step(s, how == "hit", DT)
			if lost == null and s.events.first(GameEvent.Kind.MAG_LOST) != null:
				lost = s.events.first(GameEvent.Kind.MAG_LOST)
				assert_eq([lost.actor, lost.target, lost.value], [0, 1, rifle.mag_size], how)
		assert_not_null(lost, how)
		assert_eq(_active(s), 0, how)
		assert_eq(_held(s), before - rifle.mag_size, how)


func test_a_toss_whose_catcher_steps_behind_a_wall_is_lost_where_it_meets_it() -> void:
	# BP7: before, the magazine flew on through the wall to the catcher's chest.
	var s := _state([Vector3.ZERO, Vector3(3.0, 0.0, 0.0)])
	s.mag_tosses = MagShare.make_tosses(2)
	var w := _world()
	# A wall at z 1.5 from x 0 to 6: not between them now, between them once the catcher steps round behind it.
	w.add_box(Vector3(3.0, 1.5, 1.5), Vector3(6.0, 3.0, 0.2))
	var ms := MagShare.new(tuning, w)
	var b := s.characters[1]
	_last_mag(b)
	b.mag.asked = 0
	var before := _held(s)
	ms.press(s.characters[0], s, true)
	assert_not_null(s.events.first(GameEvent.Kind.MAG_TOSS))
	b.position = Vector3(3.0, 0.0, 3.0)
	var lost: GameEvent = null
	for i in 120:
		s.events.clear()
		ms.step(s, true, DT)
		assert_null(s.events.first(GameEvent.Kind.MAG_CATCH), "never caught through the wall")
		if lost == null:
			lost = s.events.first(GameEvent.Kind.MAG_LOST)
	assert_not_null(lost, "it was lost")
	if lost != null:
		assert_almost_eq(lost.position.z, 1.4, 0.05, "at the wall's near face")
		assert_eq(lost.value, rifle.mag_size, "its BBs with it")
	assert_eq(_held(s), before - rifle.mag_size)
	assert_eq(b.mag.coming, 0)
	assert_eq(b.mag.asked, -1, "the ask ends with it")


## Character 0 presses to toss character 1 (asking it) and the step flies it out: whether it was caught, never lost.
func _caught(s: GameState, ms: MagShare) -> bool:
	s.mag_tosses = MagShare.make_tosses(2)
	var b := s.characters[1]
	_last_mag(b)
	b.mag.asked = 0
	s.events.clear()
	ms.press(s.characters[0], s, true)
	if s.events.first(GameEvent.Kind.MAG_TOSS) == null:
		return false
	var caught := false
	for i in 120:
		s.events.clear()
		ms.step(s, true, DT)
		if s.events.first(GameEvent.Kind.MAG_LOST) != null:
			return false
		caught = caught or s.events.first(GameEvent.Kind.MAG_CATCH) != null
	return caught


func test_a_toss_allowed_with_nobody_moving_is_caught_under_a_lintel_or_over_low_cover() -> void:
	# BP7 critic: the check took the straight eye-to-chest line while the flight rays its arc from the hand, so a
	# standing pair under a low lintel, or a crouched thrower against crouch cover, had the toss allowed and then lost.
	# Now both check the same pieces of the arc: allowed means caught, else refused.
	for under: float in [1.6, 1.9, 2.1]:
		var s := _state([Vector3.ZERO, Vector3(5.5, 0.0, 0.0)])
		var w := _world()
		# A lintel across the middle, its underside at `under`.
		w.add_box(Vector3(2.75, under + 0.5, 0.0), Vector3(0.3, 1.0, 4.0))
		var ms := MagShare.new(tuning, w)
		_last_mag(s.characters[1])
		var allowed := ms.can_toss_to(s.characters[0], s.characters[1], MagShare.SparePick.new())
		assert_eq(_caught(s, ms), allowed, "under a lintel at %.1f m: caught exactly when allowed" % under)
		if is_equal_approx(under, 1.6):
			assert_false(allowed, "the arc meets a 1.6 m lintel: refused, never lost")
		if is_equal_approx(under, 2.1):
			assert_true(allowed, "a 2.1 m lintel is over the arc")
	for top: float in [0.8, 1.0]:
		var s := _state([Vector3.ZERO, Vector3(4.0, 0.0, 0.0)])
		s.characters[0].crouch_amount = 1.0
		var w := _world()
		# Crouch cover `top` tall, its face touching the crouched thrower's body.
		w.add_box(Vector3(tuning.body.radius + 0.16, top * 0.5, 0.0), Vector3(0.3, top, 4.0))
		var ms := MagShare.new(tuning, w)
		_last_mag(s.characters[1])
		var allowed := ms.can_toss_to(s.characters[0], s.characters[1], MagShare.SparePick.new())
		assert_eq(_caught(s, ms), allowed, "over %.1f m cover from a crouch: caught exactly when allowed" % top)
		if is_equal_approx(top, 1.0):
			assert_false(allowed, "the hand is below 1.0 m cover: refused, never lost in its own cover")
		else:
			assert_true(allowed, "over 0.8 m cover")


func test_a_toss_with_nothing_in_the_way_follows_the_arc_presentation_draws() -> void:
	var c := MagShareConfig.new()
	var mid := MagShare.flight_point(Vector3.ZERO, Vector3(4.0, 0.0, 0.0), 0.5, c)
	assert_almost_eq(mid, Vector3(2.0, 0.4, 0.0), Vector3.ONE * 1e-4, "arc_per_metre at the middle")
	assert_almost_eq(MagShare.flight_point(Vector3.ZERO, Vector3(10.0, 0.0, 0.0), 0.5, c).y, c.arc_max, 1e-4)
	assert_eq(MagTossView.flight_at(Vector3.ZERO, Vector3(4.0, 0.0, 0.0), 0.3, 0.5, c).origin,
			MagShare.flight_point(Vector3.ZERO, Vector3(4.0, 0.0, 0.0), 0.3, c), "the view draws the same arc")


# --- Asking ---


func test_an_ask_goes_to_the_nearest_teammate_within_reach_with_one_to_spare() -> void:
	# You (0), a teammate 10 m off on its last spare but one (1), one 20 m off (2), an enemy 2 m off (3), one 31 m off (4).
	var s := _state([Vector3.ZERO, Vector3(10.0, 0.0, 0.0), Vector3(-20.0, 0.0, 0.0), Vector3(2.0, 0.0, 0.0),
			Vector3(0.0, 0.0, 0.0)], [0, 0, 0, 1, 0])
	var ms := MagShare.new(tuning, _world())
	var me := s.characters[0]
	_last_mag(me)
	s.characters[4].position = Vector3(cfg.ask_range + 1.0, 0.0, 0.0)
	# 1 would be left with less than a full spare of the replica it fights with.
	s.characters[1].armament.ammo[0].pouch.fill(0)
	s.characters[1].armament.ammo[0].pouch[0] = rifle.mag_size
	ms.press(me, s, true)
	var e := s.events.first(GameEvent.Kind.MAG_ASK)
	assert_not_null(e)
	assert_eq([e.actor, e.target, e.slot], [0, 2, 0])
	assert_eq(me.mag.asked, 2)
	# Nobody else within reach: refused as nobody.
	s.characters[2].status = Character.Status.CALLING
	me.mag.asked = -1
	s.events.clear()
	ms.press(me, s, true)
	assert_eq(_refusal(s), MagShare.Refusal.NOBODY)


func test_an_ask_for_the_pistol_needs_a_pistol_magazine() -> void:
	var s := _state([Vector3.ZERO, Vector3(5.0, 0.0, 0.0)])
	var ms := MagShare.new(tuning, _world())
	var me := s.characters[0]
	me.armament.active = 1
	_last_mag(me, 1)
	s.characters[1].armament.ammo[1].pouch.fill(0)
	ms.press(me, s, true)
	assert_eq(_refusal(s), MagShare.Refusal.NOBODY, "the rifle's spares don't fit a pistol")


func test_refusals_not_low_already_and_not_now() -> void:
	var s := _state([Vector3.ZERO, Vector3(5.0, 0.0, 0.0)])
	var ms := MagShare.new(tuning, _world())
	var me := s.characters[0]
	ms.press(me, s, true)
	assert_eq(_refusal(s), MagShare.Refusal.NOT_LOW)
	_last_mag(me)
	s.events.clear()
	ms.press(me, s, true)
	assert_eq(me.mag.asked, 1)
	s.events.clear()
	ms.press(me, s, true)
	assert_eq(_refusal(s), MagShare.Refusal.ALREADY)
	s.events.clear()
	ms.press(me, s, false)
	assert_eq(_refusal(s), MagShare.Refusal.NOT_NOW, "between rounds")
	me.status = Character.Status.WALKING_OFF
	s.events.clear()
	ms.press(me, s, true)
	assert_eq(_refusal(s), MagShare.Refusal.NOT_NOW, "out")


func test_an_asker_out_of_reach_is_too_far_and_one_no_spare_fits() -> void:
	var s := _state([Vector3.ZERO, Vector3(cfg.toss_range + 3.0, 0.0, 0.0)])
	var ms := MagShare.new(tuning, _world())
	var me := s.characters[0]
	var asker := s.characters[1]
	_last_mag(asker)
	asker.mag.asked = 0
	ms.press(me, s, true)
	assert_eq(_refusal(s), MagShare.Refusal.TOO_FAR)
	assert_eq(s.events.first(GameEvent.Kind.MAG_REFUSED).target, 1)
	me.armament.ammo[0].pouch.fill(0)
	me.armament.ammo[0].pouch[0] = rifle.mag_size # not low
	asker.armament.active = 1
	_last_mag(asker, 1)
	me.armament.ammo[1].pouch.fill(0)
	s.events.clear()
	ms.press(me, s, true)
	assert_eq(_refusal(s), MagShare.Refusal.NO_SPARE)


func test_an_ask_stands_its_time_then_lapses_and_the_gap_is_the_players_or_a_bots() -> void:
	for player: bool in [true, false]:
		var s := _state([Vector3.ZERO, Vector3(10.0, 0.0, 0.0)])
		var ms := MagShare.new(tuning, _world())
		var me := s.characters[0]
		me.mag.player = player
		_last_mag(me)
		ms.press(me, s, true)
		assert_eq(me.mag.asked, 1)
		var ticks := 0
		while me.mag.asked >= 0 and ticks < 3600:
			s.events.clear()
			ms.step(s, true, DT)
			s.time += DT
			ticks += 1
		assert_almost_eq(ticks * DT, cfg.ask_time, 2.0 * DT, "an ask stands ask_time")
		var gap := cfg.player_ask_gap if player else cfg.bot_ask_gap
		assert_almost_eq(me.mag.next_ask - s.time, gap, 2.0 * DT)
		s.events.clear()
		ms.press(me, s, true)
		assert_eq(_refusal(s), MagShare.Refusal.WAIT)
		s.time = me.mag.next_ask
		s.events.clear()
		ms.press(me, s, true)
		assert_eq(me.mag.asked, 1, "asks again after its gap")


func test_an_ask_ends_when_its_giver_is_out_or_can_spare_none() -> void:
	var s := _state([Vector3.ZERO, Vector3(10.0, 0.0, 0.0)])
	var ms := MagShare.new(tuning, _world())
	var me := s.characters[0]
	_last_mag(me)
	ms.press(me, s, true)
	ms.step(s, true, DT)
	assert_eq(me.mag.asked, 1)
	s.characters[1].status = Character.Status.CALLING
	ms.step(s, true, DT)
	assert_eq(me.mag.asked, -1)


func test_an_ask_to_a_teammate_that_asks_for_its_own_ends_at_once_and_may_go_elsewhere() -> void:
	# BP7: before, it stood its 15 s unanswered (a giver asking never gives).
	var s := _state([Vector3.ZERO, Vector3(5.0, 0.0, 0.0), Vector3(12.0, 0.0, 0.0)])
	var ms := MagShare.new(tuning, _world())
	var me := s.characters[0]
	_last_mag(me)
	ms.press(me, s, true)
	assert_eq(me.mag.asked, 1, "the nearest")
	# The giver runs low and asks the third.
	_last_mag(s.characters[1])
	s.characters[1].mag.asked = 2
	s.time = 1.0
	ms.step(s, true, DT)
	assert_eq(me.mag.asked, -1, "over at once")
	assert_eq(me.mag.next_ask, 1.0, "with no wait")
	s.events.clear()
	ms.press(me, s, true)
	assert_eq(me.mag.asked, 2, "asked of the next teammate")


func test_the_toss_goes_to_the_nearest_asker_in_reach() -> void:
	var s := _state([Vector3.ZERO, Vector3(5.0, 0.0, 0.0), Vector3(3.0, 0.0, 0.0), Vector3(1.5, 0.0, 0.0)])
	var ms := MagShare.new(tuning, _world())
	for i: int in [1, 2]:
		_last_mag(s.characters[i])
		s.characters[i].mag.asked = 0
	ms.press(s.characters[0], s, true)
	assert_eq(s.events.first(GameEvent.Kind.MAG_TOSS).target, 2)


# --- Through Simulation.step (sim/magShareSim.test.ts) ---


## Three on team 0 (0, 1, 2) 4 m apart and an opponent far off (3), round 1 live.
func _match(seed_value: int = 9) -> Array:
	var w := _world()
	var ends: Array[MapEnd] = []
	for e in 2:
		var end := MapEnd.new()
		for i in 3:
			end.spawns.append(SpawnPoint.new(Vector3(-10.0 if e == 0 else 10.0, 0.0, i * 2.0), 0.0))
			end.dead_zone.append(SpawnPoint.new(Vector3(-25.0 if e == 0 else 25.0, 0.0, 10.0), 0.0))
		ends.append(end)
	var sim := Simulation.new(tuning, w, w.mover(), ends, -10.0)
	var s := GameState.new(seed_value, tuning)
	for i in 4:
		s.characters.append(Character.new(i, 0 if i < 3 else 1, Vector3.ZERO, 0.0, loadout))
	sim.start_match(s)
	var spots: Array[Vector3] = [Vector3(0.0, 0.0, 0.0), Vector3(4.0, 0.0, 0.0), Vector3(0.0, 0.0, 4.0),
			Vector3(25.0, 0.0, -10.0)]
	for c in s.characters:
		c.position = spots[c.id] + Vector3(0.0, c.position.y, 0.0)
	var cmds: Array[PlayerCommand] = []
	for c in s.characters:
		var cmd := PlayerCommand.new()
		cmd.reset(c.yaw, c.pitch)
		cmds.append(cmd)
	return [sim, s, cmds]


## One tick: `pressing` press the hand-off this tick only; returns the tick's hand-off events as [kind, actor, target,
## value] in order.
func _tick(m: Array, pressing: Array = []) -> Array:
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var cmds: Array[PlayerCommand] = m[2]
	for c in cmds:
		c.mag_hand_off = false
	for id: int in pressing:
		cmds[id].mag_hand_off = true
	sim.step(s, cmds, DT)
	var out := []
	for i in s.events.count:
		var e := s.events.items[i]
		if e.kind >= GameEvent.Kind.MAG_ASK and e.kind <= GameEvent.Kind.MAG_REFUSED:
			out.append([e.kind, e.actor, e.target, e.value])
	return out


func test_through_the_step_an_ask_then_a_toss_moves_the_bbs_and_none_are_made() -> void:
	var m := _match()
	var s: GameState = m[1]
	var catcher := s.characters[1]
	_last_mag(catcher)
	var before := _held(s)
	var seen := _tick(m, [1])
	assert_eq(seen, [[GameEvent.Kind.MAG_ASK, 1, 0, 0]], "the nearest teammate with one to spare")
	seen = _tick(m, [0])
	assert_eq(seen, [[GameEvent.Kind.MAG_TOSS, 0, 1, rifle.mag_size]])
	assert_eq(_held(s), before - rifle.mag_size, "in the air")
	assert_eq(s.characters[0].armament.ammo[0].spare_bbs(), 2 * rifle.mag_size)
	assert_eq(catcher.armament.ammo[0].spare_bbs(), 0)
	var landed := []
	for i in 120:
		landed = _tick(m)
		if not landed.is_empty():
			break
	assert_eq(landed, [[GameEvent.Kind.MAG_CATCH, 0, 1, rifle.mag_size]])
	assert_eq(catcher.armament.ammo[0].spare_bbs(), rifle.mag_size)
	assert_eq(_held(s), before)
	assert_eq(_active(s), 0)
	assert_eq(catcher.mag.asked, -1)


func test_through_the_step_nothing_moves_in_a_round_that_is_not_live() -> void:
	var m := _match()
	var s: GameState = m[1]
	_last_mag(s.characters[1])
	s.characters[1].mag.asked = 0
	s.round_state.phase = RoundState.Phase.MATCH_OVER
	var before := _held(s)
	assert_eq(_tick(m, [0]), [[GameEvent.Kind.MAG_REFUSED, 0, -1, MagShare.Refusal.NOT_NOW]])
	assert_eq(_held(s), before)
	assert_eq(_active(s), 0)


func test_through_the_step_a_press_while_out_is_not_now() -> void:
	var m := _match()
	var s: GameState = m[1]
	s.characters[2].status = Character.Status.OUT
	assert_eq(_tick(m, [2]), [[GameEvent.Kind.MAG_REFUSED, 2, -1, MagShare.Refusal.NOT_NOW]])


func test_through_the_step_the_magazine_in_the_air_is_lost_when_the_round_is_decided() -> void:
	var m := _match()
	var s: GameState = m[1]
	_last_mag(s.characters[1])
	s.characters[1].mag.asked = 0
	var before := _held(s)
	assert_eq(_tick(m, [0])[0][0], GameEvent.Kind.MAG_TOSS)
	s.round_state.phase = RoundState.Phase.MATCH_OVER
	assert_eq(_tick(m), [[GameEvent.Kind.MAG_LOST, 0, 1, rifle.mag_size]])
	assert_eq(_held(s), before - rifle.mag_size)
	assert_eq(s.characters[1].armament.ammo[0].spare_bbs(), 0)


func test_through_the_step_a_pistol_magazine_goes_into_the_pistol_spares() -> void:
	var m := _match()
	var s: GameState = m[1]
	var catcher := s.characters[1]
	catcher.armament.active = 1
	_last_mag(catcher, 1)
	catcher.mag.asked = 0
	var rifle_before := _held(s, 0)
	var seen := _tick(m, [0])
	assert_eq(seen, [[GameEvent.Kind.MAG_TOSS, 0, 1, pistol.mag_size]])
	assert_eq(s.events.first(GameEvent.Kind.MAG_TOSS).value2, 1, "from the thrower's pistol")
	for i in 120:
		seen = _tick(m)
		if not seen.is_empty():
			break
	assert_eq(seen, [[GameEvent.Kind.MAG_CATCH, 0, 1, pistol.mag_size]])
	assert_eq(catcher.armament.ammo[1].spare_bbs(), pistol.mag_size)
	assert_eq(_held(s, 0), rifle_before, "no rifle BB moved")


func test_through_the_step_no_toss_to_an_asker_out_of_reach_or_an_enemy() -> void:
	var m := _match()
	var s: GameState = m[1]
	var mate := s.characters[1]
	var enemy := s.characters[3]
	_last_mag(mate)
	mate.mag.asked = 0
	mate.position.x = cfg.toss_range + 3.0
	_last_mag(enemy)
	enemy.mag.asked = 0
	enemy.position = Vector3(-3.0, enemy.position.y, 0.0)
	assert_eq(_tick(m, [0]), [[GameEvent.Kind.MAG_REFUSED, 0, 1, MagShare.Refusal.TOO_FAR]])
	assert_eq(_active(s), 0)


## A run of `seed_value` with an ask and a toss: everything the hand-off touched, as text.
func _run(seed_value: int) -> String:
	var m := _match(seed_value)
	var s: GameState = m[1]
	_last_mag(s.characters[1])
	var seen := []
	for i in 240:
		var pressing := [1] if i == 3 else ([0] if i == 5 else [])
		seen.append_array(_tick(m, pressing))
	var pouches := []
	for c in s.characters:
		pouches.append([c.position, Array(c.armament.ammo[0].pouch), c.mag.asked, c.mag.next_ask])
	return str([s.tick, s.time, seen, pouches, s.rng.state])


func test_two_runs_of_one_seed_with_a_hand_off_end_alike() -> void:
	var a := _run(33)
	assert_string_contains(a, "[%d, 0, 1, %d]" % [GameEvent.Kind.MAG_CATCH, rifle.mag_size])
	assert_eq(_run(33), a)


func test_no_bb_is_made_or_lost_over_many_hand_offs_but_a_lost_tosss() -> void:
	var m := _match(5)
	var s: GameState = m[1]
	var lost := 0
	var dropped := 0
	var tosses := 0
	var before := _held(s)
	for c in s.characters:
		c.mag.player = true
	for i in 3600:
		# Every second a teammate runs dry, the giver's spares are full again and everyone presses; every third toss its
		# catcher is hit with it in the air, and back in play once it is lost.
		if i % 60 == 0:
			var dry := s.characters[1 + (i / 60) % 2]
			dropped += dry.armament.ammo[0].spare_bbs()
			_last_mag(dry)
			# The giver's spares topped up again by the test (BBs it adds, not the rules).
			var giver := s.characters[0].armament.ammo[0]
			dropped -= rifle.mag_size * giver.pouch.size() - giver.spare_bbs()
			giver.pouch.fill(rifle.mag_size)
		for row: Array in _tick(m, [0, 1, 2]):
			if row[0] == GameEvent.Kind.MAG_LOST:
				lost += row[3]
				for c in s.characters:
					c.status = Character.Status.ALIVE
			elif row[0] == GameEvent.Kind.MAG_TOSS:
				tosses += 1
				if tosses % 3 == 0:
					s.characters[row[2]].status = Character.Status.CALLING
		if _held(s) + _in_air(s) + lost != before - dropped:
			fail_test("BBs made or lost at tick %d" % i)
			return
	assert_gt(tosses, 5, "magazines changed hands")
	assert_gt(lost, 0, "a toss was lost")
	pass_test("every BB accounted for")


static func _in_air(s: GameState) -> int:
	var n := 0
	for t in s.mag_tosses:
		if t.active:
			n += t.bbs
	return n


func test_a_tick_with_magazines_in_the_air_allocates_nothing() -> void:
	var m := _match(7)
	var s: GameState = m[1]
	var cycle := func() -> void:
		for c in s.characters:
			c.mag.clear()
			c.armament.refill()
		_last_mag(s.characters[1])
		_last_mag(s.characters[2])
		_tick(m, [1, 2])
		_tick(m, [0])
		_tick(m, [0])
		for i in 3:
			_tick(m, [0, 1, 2])
	var sim: Simulation = m[0]
	var cmds: Array[PlayerCommand] = m[2]
	var pressing := func() -> void:
		for c in cmds:
			c.mag_hand_off = true
		for i in 10:
			sim.step(s, cmds, DT)
		for i in 60:
			_tick(m)
	# Warm: a whole hand-off and its landing, then the same again measured with the magazines in the air.
	cycle.call()
	pressing.call()
	cycle.call()
	assert_gt(_active(s), 0, "magazines in the air")
	for c in cmds:
		c.mag_hand_off = true
	var before := Performance.get_monitor(Performance.OBJECT_COUNT)
	for i in 10:
		sim.step(s, cmds, DT)
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), before)
	assert_gt(_active(s), 0, "still in the air")
