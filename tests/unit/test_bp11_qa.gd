extends GutTest
## BP11 QA: what the second pass's fixes must not break: a defuse's win keeps its defuser's cue, a standing Follow me is
## taken up again only from a giver in play on the bot's own team and never at a slot a teammate holds. Second pass: the
## edges of a field's own Attack / Defend wait against Hard bots.

const DT := 1.0 / 60.0
const SITE_A := Vector3(20.0, 0.0, -10.0)
const NONE: Array[ReplicaConfig] = []


func _plant_world() -> Array:
	var tuning := SimTuning.new()
	tuning.rounds.round_time = 20.0
	tuning.plant.plant_time = 2.0
	tuning.plant.fuse_time = 10.0
	tuning.plant.defuse_time = 4.0
	var ends: Array[MapEnd] = []
	for x: float in [-20.0, 20.0]:
		var e := MapEnd.new()
		e.spawns.append(SpawnPoint.new(Vector3(x, 0.0, 0.0), 0.0))
		e.spawns.append(SpawnPoint.new(Vector3(x, 0.0, 1.0), 0.0))
		ends.append(e)
	var rs := RoundState.new()
	rs.mode = RoundState.Mode.PLANT_THE_BOMB
	rs.plant.set_sites(PackedVector3Array([SITE_A]), PackedFloat32Array([4.0]), tuning.plant.site_radius)
	rs.plant.start = Vector3(-18.0, 0.0, 0.5)
	var cs: Array[Character] = []
	for id in 4:
		cs.append(Character.new(id, 0 if id < 2 else 1, Vector3.ZERO, 0.0, NONE))
	var events := SimEvents.new()
	Round.start_match(rs, cs, ends, null, tuning, events)
	for c in cs:
		c.grounded = true
	return [rs, cs, ends, tuning, events]


func _step(m: Array, seconds: float, kinds: Array[Vector3i]) -> void:
	for i in ceili(seconds / DT - 1e-6):
		var ev: SimEvents = m[4]
		ev.clear()
		Round.step(m[0], m[1], m[2], null, m[3], ev, DT)
		for j in ev.count:
			var e := ev.items[j]
			kinds.append(Vector3i(e.kind, e.actor, e.value))


func test_a_defuse_win_still_names_its_defuser_in_the_event_after_the_plant_halts() -> void:
	var m := _plant_world()
	var rs: RoundState = m[0]
	var cs: Array[Character] = m[1]
	var seen: Array[Vector3i] = []
	cs[0].position = rs.plant.position + Vector3(0.5, 0.0, 0.0)
	cs[0].using = true
	_step(m, DT, seen)
	cs[0].using = false
	cs[0].position = SITE_A + Vector3(1.0, 0.0, 0.0)
	cs[0].using = true
	_step(m, 2.5, seen)
	assert_true(rs.plant.planted(), "armed")
	cs[0].using = false
	cs[2].position = rs.plant.position + Vector3(0.5, 0.0, 0.0)
	cs[2].using = true
	seen.clear()
	_step(m, 4.5, seen)
	assert_eq(rs.reason, GameEvent.RoundEnd.DEFUSED)
	assert_eq(rs.plant.defuser, -1, "halted")
	assert_eq(rs.plant.status, PlantState.Status.DEFUSED, "still defused: the lamp and the ring read it")
	var named := false
	for k in seen:
		if k.x == GameEvent.Kind.PLANT and k.y == 2:
			named = true
	assert_true(named, "the DEFUSED cue named the defender who did it")


func test_ending_the_round_during_a_defuse_goes_off_and_leaves_nobody_on_the_bomb() -> void:
	var m := _plant_world()
	var rs: RoundState = m[0]
	var cs: Array[Character] = m[1]
	var seen: Array[Vector3i] = []
	cs[0].position = rs.plant.position + Vector3(0.5, 0.0, 0.0)
	cs[0].using = true
	_step(m, DT, seen)
	cs[0].using = false
	cs[0].position = SITE_A + Vector3(1.0, 0.0, 0.0)
	cs[0].using = true
	_step(m, 2.5, seen)
	cs[0].using = false
	cs[2].position = rs.plant.position + Vector3(0.5, 0.0, 0.0)
	cs[2].using = true
	_step(m, 1.0, seen)
	assert_eq(rs.plant.defuser, 2)
	assert_true(Round.run_clock_out(rs))
	_step(m, 3.0 * DT, seen)
	assert_eq(rs.phase, RoundState.Phase.OVER)
	assert_eq(rs.plant.defuser, -1)
	assert_false(Plant.busy(rs.plant, cs[2]), "free to move through the pause")


func _book(giver_team: int) -> Array:
	var w := BotWorld.new()
	w.cfg = BotConfig.load_default()
	w.tuning = SimTuning.new()
	var you := Character.new(0, giver_team, Vector3.ZERO, 0.0, NONE)
	w.characters = [you]
	for id: int in [1, 2, 3]:
		var c := Character.new(id, 0, Vector3(2.0 * id, 0.0, 0.0), 0.0, NONE)
		w.characters.append(c)
		w.bots.append(Bot.new(c, id + 3, w.cfg.skill, 3))
	return [w, SquadOrderBook.new(w), you]


func test_a_bot_back_from_a_hit_does_not_follow_a_giver_who_is_out() -> void:
	var t := _book(0)
	var w: BotWorld = t[0]
	var book: SquadOrderBook = t[1]
	var you: Character = t[2]
	book.give_order(you, SquadOrder.Kind.FOLLOW)
	you.status = Character.Status.OUT
	var b := w.bots[0]
	b.character.status = Character.Status.ALIVE
	b.order = SquadOrder.Kind.NONE
	book.rejoin(b)
	assert_eq(b.order, SquadOrder.Kind.NONE, "nobody to follow")


func test_a_bot_does_not_take_up_an_order_given_by_the_other_team() -> void:
	var t := _book(1)
	var w: BotWorld = t[0]
	var book: SquadOrderBook = t[1]
	var you: Character = t[2]
	book.give_order(you, SquadOrder.Kind.FOLLOW)
	var b := w.bots[0]
	b.order = SquadOrder.Kind.NONE
	b.order_giver = null
	book.rejoin(b)
	assert_eq(b.order, SquadOrder.Kind.NONE, "the enemy's Follow me is not ours")


func test_two_bots_back_at_once_take_different_slots_behind_the_giver() -> void:
	var t := _book(0)
	var w: BotWorld = t[0]
	var book: SquadOrderBook = t[1]
	var you: Character = t[2]
	book.give_order(you, SquadOrder.Kind.FOLLOW)
	for b in w.bots:
		b.order = SquadOrder.Kind.NONE
		b.order_giver = null
		b.order_slot = -1
	book.rejoin(w.bots[0])
	book.rejoin(w.bots[1])
	book.rejoin(w.bots[2])
	var slots: Dictionary = {}
	for b in w.bots:
		assert_eq(b.order, SquadOrder.Kind.FOLLOW)
		slots[b.order_slot] = true
	assert_eq(slots.size(), 3, "no two at one slot")


# --- second pass: a field's own Hard wait ---

func _field(own: float, hard: float) -> MapCatalog.Entry:
	var e := MapCatalog.Entry.new()
	e.id = "edge"
	e.kind = &"field"
	e.defender_respawn = own
	e.defender_respawn_hard = hard
	return e


func _hard_delay(own: float, hard: float, level: StringName = &"hard") -> float:
	var base := SimTuning.load_default()
	var t := MatchOptions.match_tuning(base, _field(own, hard), null)
	return MatchOptions.level_tuning(t, level).rounds.defender_respawn_delay


func test_a_hard_wait_shorter_than_the_fields_own_is_played_as_set() -> void:
	assert_eq(_hard_delay(15.0, 5.0), 5.0, "not the field's 15 times 1.9")
	assert_eq(_hard_delay(15.0, 5.0, &"normal"), 15.0, "Normal keeps the field's own")


func test_a_hard_wait_is_not_held_to_the_scaled_ceiling() -> void:
	var most := SimTuning.load_default().rounds.defender_respawn_most
	assert_eq(_hard_delay(7.0, 30.0), 30.0, "the field's own Hard wait passes the %s s ceiling up to the column's 30" % most)


func test_the_hard_wait_does_not_reach_plant_the_bomb_defenders() -> void:
	var base := SimTuning.load_default()
	var t := MatchOptions.level_tuning(MatchOptions.match_tuning(base, _field(7.0, 15.2), null), &"hard")
	var rs := RoundState.new()
	rs.mode = RoundState.Mode.PLANT_THE_BOMB
	rs.attackers = 0
	assert_eq(Respawns.delay(rs, t.rounds, 1), base.rounds.plant_defender_respawn_delay)
	rs.mode = RoundState.Mode.ATTACK_DEFEND
	assert_eq(Respawns.delay(rs, t.rounds, 1), 15.2, "Attack / Defend defenders wait it")
	assert_eq(Respawns.delay(rs, t.rounds, 0), base.rounds.respawn_delay, "attackers keep theirs")


func test_a_null_map_and_an_unknown_level_leave_the_tuning_alone() -> void:
	var base := SimTuning.load_default()
	assert_eq(MatchOptions.match_tuning(base, null, null).rounds.defender_respawn_hard, 0.0)
	assert_same(MatchOptions.level_tuning(base, &"nonsense"), base)
