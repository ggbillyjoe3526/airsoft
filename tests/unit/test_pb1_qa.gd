extends GutTest
## QA's probes of Plant The Bomb (PB1): boundaries the rules tests step around, and what a round end or a new round
## leaves behind in the plan the bots keep.

const DT := 1.0 / 60.0
const SITE_A := Vector3(20.0, 0.0, -10.0)
const SITE_B := Vector3(20.0, 0.0, 10.0)
const START := Vector3(-18.0, 0.0, 0.5)

var tuning: SimTuning
var cfg: PlantConfig
var ends: Array[MapEnd]
var events: SimEvents
var rs: RoundState
var ps: PlantState
var cs: Array[Character]


func before_each() -> void:
	tuning = SimTuning.new()
	tuning.rounds.round_time = 20.0
	tuning.rounds.reset_delay = 2.0
	tuning.rounds.half_time_after = 1
	tuning.rounds.start_countdown = 0.0
	cfg = tuning.plant
	cfg.plant_time = 2.0
	cfg.fuse_time = 10.0
	cfg.defuse_time = 4.0
	cfg.defuse_checkpoint = 0.5
	cfg.max_overtime = 3.0
	ends = [_end(-20.0), _end(20.0)]
	events = SimEvents.new()
	rs = RoundState.new()
	rs.mode = RoundState.Mode.PLANT_THE_BOMB
	ps = rs.plant
	ps.set_sites(PackedVector3Array([SITE_A, SITE_B]), PackedFloat32Array([4.0, 0.0]), cfg.site_radius)
	ps.start = START
	cs = []
	var loadout: Array[ReplicaConfig] = []
	for id in 4:
		cs.append(Character.new(id, 0 if id < 2 else 1, Vector3.ZERO, 0.0, loadout))


func _end(x: float) -> MapEnd:
	var e := MapEnd.new()
	for z: float in [0.0, 1.0]:
		e.spawns.append(SpawnPoint.new(Vector3(x, 0.0, z), 0.0))
	return e


func _start() -> void:
	Round.start_match(rs, cs, ends, null, tuning, events)
	for c in cs:
		c.grounded = true


func _run(seconds: float) -> void:
	for i in ceili(seconds / DT - 1e-6):
		events.clear()
		Round.step(rs, cs, ends, null, tuning, events, DT)


func _arm(id: int) -> void:
	cs[id].position = START
	cs[id].using = true
	_run(DT)
	cs[id].position = SITE_A + Vector3(1.0, 0.0, 0.0)
	_run(cfg.plant_time + 2.0 * DT)
	cs[id].using = false
	_run(DT)


func test_a_defuse_let_go_at_exactly_the_checkpoint_keeps_it() -> void:
	_start()
	_arm(0)
	assert_true(ps.planted())
	cs[2].position = ps.position
	cs[2].using = true
	# Whole ticks of the defuse that make exactly half of defuse_time.
	_run(cfg.defuse_time * 0.5)
	cs[2].using = false
	_run(DT)
	assert_almost_eq(ps.defusing, cfg.defuse_checkpoint, 0.0001, "half the work done is the checkpoint")


func test_the_defuse_finishing_in_the_tick_the_fuse_ends_wins_it_for_the_defenders() -> void:
	_start()
	_arm(0)
	cs[2].position = ps.position
	cs[2].using = true
	# Leave just enough fuse for the defuse to need its last tick as the fuse ends.
	ps.fuse_left = cfg.defuse_time
	_run(cfg.defuse_time + 3.0 * DT)
	assert_true(rs.winner == 1 or rs.winner == 0)
	assert_eq(rs.reason, GameEvent.RoundEnd.DEFUSED if rs.winner == 1 else GameEvent.RoundEnd.WENT_OFF)
	assert_eq(rs.score[0] + rs.score[1], 1, "decided once, one point")


func test_two_attackers_holding_use_in_the_same_tick_leave_one_carrier() -> void:
	_start()
	cs[0].position = START
	cs[1].position = START
	cs[0].using = true
	cs[1].using = true
	_run(5.0 * DT)
	assert_eq(ps.status, PlantState.Status.CARRIED)
	assert_true(ps.carrier == 0 or ps.carrier == 1)


func test_an_attacker_in_reach_of_the_armed_bomb_cannot_disarm_it() -> void:
	_start()
	_arm(0)
	cs[1].position = ps.position
	cs[1].using = true
	_run(cfg.defuse_time + 1.0)
	assert_eq(ps.defusing, 0.0)
	assert_ne(rs.reason, GameEvent.RoundEnd.DEFUSED)


func test_a_new_round_forgets_an_armed_bomb_and_its_defuse() -> void:
	_start()
	_arm(0)
	cs[2].position = ps.position
	cs[2].using = true
	_run(1.0)
	rs.plant.fuse_left = 0.0
	_run(3.0 * DT)
	assert_eq(rs.phase, RoundState.Phase.OVER)
	_run(tuning.rounds.reset_delay + 1.0)
	assert_eq(rs.number, 2)
	assert_eq(ps.status, PlantState.Status.DOWN)
	assert_eq(ps.defuser, -1)
	assert_eq(ps.defusing, 0.0)
	assert_eq(ps.planter, -1)
	assert_eq(ps.position, START)
	assert_eq(rs.attackers, 1, "sides swapped at half time")


func test_the_round_ending_mid_plant_leaves_nothing_armed_in_the_next() -> void:
	_start()
	cs[0].position = START
	cs[0].using = true
	_run(DT)
	cs[0].position = SITE_A
	_run(1.0)
	assert_gt(ps.planting, 0.0)
	cs[2].status = Character.Status.OUT
	cs[3].status = Character.Status.OUT
	_run(DT)
	assert_eq(rs.winner, 0)
	_run(tuning.rounds.reset_delay + 1.0)
	assert_eq(ps.planting, 0.0)
	assert_eq(ps.planter, -1)
	assert_eq(ps.carrier, -1)
	assert_false(cs[0].using, "respawn lets go of Use")


func test_a_map_with_one_site_still_plays_a_round() -> void:
	ps.set_sites(PackedVector3Array([SITE_A]), PackedFloat32Array(), cfg.site_radius)
	_start()
	assert_eq(Plant.nearest_site(ps, SITE_B), 0)
	_arm(0)
	assert_true(ps.planted())
	assert_eq(ps.site, 0)


func test_a_negative_or_zero_site_radius_falls_back() -> void:
	ps.set_sites(PackedVector3Array([SITE_A, SITE_B]), PackedFloat32Array([-3.0, 0.0]), 4.5)
	assert_eq(ps.radii[0], 4.5)
	assert_eq(ps.radii[1], 4.5)


func test_a_map_with_no_sites_never_arms_and_does_not_crash() -> void:
	ps.set_sites(PackedVector3Array(), PackedFloat32Array(), cfg.site_radius)
	_start()
	cs[0].position = START
	cs[0].using = true
	_run(1.0)
	cs[0].position = SITE_A
	_run(cfg.plant_time + 1.0)
	assert_ne(ps.status, PlantState.Status.PLANTED)
	assert_eq(Plant.nearest_site(ps, SITE_A), -1)


func test_letting_go_of_a_plant_at_the_buzzer_hands_the_round_to_the_defenders() -> void:
	cfg.plant_time = 5.0
	_start()
	cs[0].position = START
	cs[0].using = true
	_run(DT)
	_run(tuning.rounds.round_time - 1.0)
	cs[0].position = SITE_A
	_run(2.0)
	assert_eq(rs.phase, RoundState.Phase.LIVE, "arming at the buzzer plays on")
	assert_gt(rs.overtime, 0.0)
	cs[0].using = false
	_run(DT)
	assert_eq(rs.phase, RoundState.Phase.OVER, "let go at the buzzer: the defenders win")
	assert_eq(rs.winner, 1)


func test_elimination_ignores_use_and_plant_state() -> void:
	rs.mode = RoundState.Mode.ELIMINATION
	_start()
	cs[0].position = START
	cs[0].using = true
	_run(2.0)
	assert_eq(ps.status, PlantState.Status.DOWN)
	assert_eq(rs.attackers, -1)
