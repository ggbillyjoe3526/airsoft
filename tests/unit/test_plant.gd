extends GutTest
## Plant The Bomb's rules (PB1; game/sim/plant.gd and round.gd's plant mode): the bomb on the ground at the attackers'
## start, picked up and dropped, armed in a site, its fuse and beeps, the defuse and its checkpoint, and what ends a
## round. Characters are put in place and their Use held by hand.

const DT := 1.0 / 60.0
const SITE_A := Vector3(20.0, 0.0, -10.0)
const SITE_B := Vector3(20.0, 0.0, 10.0)
const START := Vector3(-18.0, 0.0, 0.5)

var tuning: SimTuning
var rules: RoundConfig
var cfg: PlantConfig
var ends: Array[MapEnd]
var events: SimEvents
var rs: RoundState
var ps: PlantState
var cs: Array[Character]
## Every BOMB cue seen by _run, in order, and every event as (kind, value, value2).
var cues: Array[int] = []
var seen: Array[Vector3i] = []


func before_each() -> void:
	tuning = SimTuning.new()
	rules = tuning.rounds
	rules.round_time = 20.0
	rules.reset_delay = 2.0
	rules.wins_needed = 3
	rules.half_time_after = 2
	cfg = tuning.plant
	cfg.plant_time = 2.0
	cfg.fuse_time = 10.0
	cfg.defuse_time = 4.0
	cfg.defuse_checkpoint = 0.5
	cfg.max_overtime = 3.0
	ends = [_end(-20.0, [0.0, 1.0]), _end(20.0, [2.0, 3.0])]
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
	cues.clear()
	seen.clear()


func _end(x: float, zs: Array[float]) -> MapEnd:
	var e := MapEnd.new()
	for z in zs:
		e.spawns.append(SpawnPoint.new(Vector3(x, 0.0, z), 0.0))
	return e


func _start() -> void:
	events.clear()
	Round.start_match(rs, cs, ends, null, tuning, events)
	for c in cs:
		c.grounded = true


func _run(seconds: float) -> void:
	for i in ceili(seconds / DT - 1e-6):
		events.clear()
		Round.step(rs, cs, ends, null, tuning, events, DT)
		for j in events.count:
			var e := events.items[j]
			seen.append(Vector3i(e.kind, e.value, e.value2))
			if e.kind == GameEvent.Kind.PLANT:
				cues.append(e.value)


func _count(kind: GameEvent.Kind, value: int) -> int:
	var n := 0
	for e in seen:
		if e.x == kind and e.y == value:
			n += 1
	return n


## Attacker `id` takes the bomb from where it lies.
func _pick_up(id: int) -> void:
	cs[id].position = ps.position + Vector3(0.5, 0.0, 0.0)
	cs[id].using = true
	_run(DT)
	cs[id].using = false


## Attacker `id` carries the bomb into site A and arms it there.
func _plant(id: int) -> void:
	_pick_up(id)
	cs[id].position = SITE_A + Vector3(1.0, 0.0, 0.0)
	cs[id].using = true
	_run(cfg.plant_time)
	cs[id].using = false


func _out(id: int) -> void:
	cs[id].status = Character.Status.OUT


# --- the bomb on the ground ---

func test_each_round_starts_with_the_bomb_on_the_ground_at_the_attackers_start() -> void:
	_start()
	assert_eq(rs.attackers, 0, "Alpha attacks first")
	assert_eq(ps.status, PlantState.Status.DOWN)
	assert_eq(ps.position, START)
	assert_eq(ps.carrier, -1)
	assert_false(ps.moved, "it has not left the start")
	assert_eq(cs[0].end, 0, "the attackers start from end 0")
	assert_eq(cs[2].end, 1, "the defenders from end 1, by the sites")


func test_nobody_picks_it_up_without_holding_use() -> void:
	_start()
	cs[0].position = START
	_run(1.0)
	assert_eq(ps.status, PlantState.Status.DOWN, "standing on it is not taking it")


func test_an_attacker_holding_use_in_reach_picks_it_up() -> void:
	_start()
	cs[1].position = START + Vector3(cfg.pickup_reach - 0.05, 0.0, 0.0)
	cs[1].using = true
	_run(DT)
	assert_eq(ps.status, PlantState.Status.CARRIED)
	assert_eq(ps.carrier, 1)
	assert_true(ps.moved)
	assert_eq(cues, [Plant.Cue.PICKED_UP])


func test_out_of_reach_or_on_another_floor_it_stays_down() -> void:
	_start()
	cs[0].using = true
	cs[0].position = START + Vector3(cfg.pickup_reach + 0.1, 0.0, 0.0)
	_run(DT)
	assert_eq(ps.status, PlantState.Status.DOWN, "a step too far")
	cs[0].position = START + Vector3(0.0, cfg.reach_height + 0.1, 0.0)
	_run(DT)
	assert_eq(ps.status, PlantState.Status.DOWN, "from the floor above")


func test_a_defender_cannot_pick_it_up() -> void:
	_start()
	cs[2].position = START
	cs[2].using = true
	_run(0.5)
	assert_eq(ps.status, PlantState.Status.DOWN)


func test_a_carrier_hit_drops_it_where_it_stood_and_a_teammate_takes_it() -> void:
	_start()
	_pick_up(0)
	cs[0].position = Vector3(3.0, 0.0, 4.0)
	_run(DT)
	assert_eq(ps.position, Vector3(3.0, 0.0, 4.0), "it goes where its carrier goes")
	_out(0)
	_run(DT)
	assert_eq(ps.status, PlantState.Status.DOWN)
	assert_eq(ps.position, Vector3(3.0, 0.0, 4.0))
	assert_eq(ps.carrier, -1)
	assert_true(ps.moved, "dropped, not at the start")
	_pick_up(1)
	assert_eq(ps.carrier, 1)
	assert_eq(cues, [Plant.Cue.PICKED_UP, Plant.Cue.DROPPED, Plant.Cue.PICKED_UP])


# --- arming it ---

func test_the_carrier_arms_it_in_a_site_by_holding_use() -> void:
	_start()
	_pick_up(0)
	cs[0].position = SITE_A + Vector3(3.9, 0.0, 0.0)
	cs[0].using = true
	_run(cfg.plant_time * 0.5)
	assert_eq(ps.status, PlantState.Status.CARRIED)
	assert_eq(ps.planter, 0)
	assert_eq(ps.site, 0)
	assert_almost_eq(ps.planting, 0.5, 0.02)
	assert_true(Plant.busy(ps, cs[0]), "both hands on it")
	_run(cfg.plant_time * 0.5)
	assert_eq(ps.status, PlantState.Status.PLANTED)
	assert_eq(ps.site, 0)
	assert_almost_eq(ps.position, Plant.set_down(SITE_A + Vector3(3.9, 0.0, 0.0), cs[0].yaw, cfg), Vector3.ONE * 1e-5,
			"armed where the carrier set it down, in front of them (PB3)")
	assert_almost_eq(ps.fuse_left, cfg.fuse_time, 0.001)
	assert_false(Plant.busy(ps, cs[0]), "hands free again")
	assert_eq(cues, [Plant.Cue.PICKED_UP, Plant.Cue.ARMING, Plant.Cue.PLANTED])


func test_site_b_takes_the_configs_radius_when_the_map_names_none() -> void:
	_start()
	assert_almost_eq(ps.radii[1], cfg.site_radius, 0.0001)
	assert_eq(Plant.site_at(ps, SITE_B + Vector3(cfg.site_radius - 0.1, 0.0, 0.0), cfg), 1)
	assert_eq(Plant.site_at(ps, SITE_B + Vector3(cfg.site_radius + 0.1, 0.0, 0.0), cfg), -1)
	assert_eq(Plant.site_at(ps, SITE_A + Vector3(0.0, cfg.reach_height + 0.1, 0.0), cfg), -1, "the floor above")
	assert_eq(Plant.nearest_site(ps, Vector3(0.0, 0.0, 1.0)), 1)


func test_letting_go_being_outside_or_in_the_air_arms_nothing() -> void:
	_start()
	_pick_up(0)
	cs[0].position = SITE_A
	cs[0].using = true
	_run(cfg.plant_time * 0.6)
	cs[0].using = false
	_run(DT)
	assert_eq(ps.planter, -1)
	assert_eq(ps.planting, 0.0, "letting go starts again")
	assert_eq(cues.back(), Plant.Cue.ARMING_STOPPED)
	cs[0].using = true
	cs[0].position = SITE_A + Vector3(4.2, 0.0, 0.0)
	_run(0.5)
	assert_eq(ps.planting, 0.0, "outside the site")
	cs[0].position = SITE_A
	cs[0].grounded = false
	_run(0.5)
	assert_eq(ps.planting, 0.0, "in the air")
	assert_eq(ps.status, PlantState.Status.CARRIED)


func test_a_carrier_hit_in_the_air_drops_it_on_the_floor_it_last_stood_on() -> void:
	_start()
	_pick_up(0)
	cs[0].position = Vector3(3.0, 0.0, 4.0)
	_run(DT)
	# A jump: off the floor, a metre up and on.
	cs[0].grounded = false
	cs[0].position = Vector3(3.6, 1.0, 4.0)
	_run(DT)
	assert_eq(ps.position, Vector3(3.6, 1.0, 4.0), "carried, it is with its carrier")
	assert_eq(ps.rest, Vector3(3.0, 0.0, 4.0), "its resting place is the floor left behind")
	_out(0)
	_run(DT)
	assert_eq(ps.status, PlantState.Status.DOWN)
	assert_eq(ps.position, Vector3(3.0, 0.0, 4.0), "never left hanging in the air")
	_pick_up(1)
	assert_eq(ps.carrier, 1, "a teammate takes it from there")


func test_a_carrier_hit_before_it_ever_stood_drops_it_where_it_lay() -> void:
	_start()
	cs[0].grounded = false
	cs[0].position = START + Vector3(0.3, 0.9, 0.0)
	cs[0].using = true
	_run(DT)
	cs[0].using = false
	assert_eq(ps.carrier, 0, "taken up mid-jump")
	_out(0)
	_run(DT)
	assert_eq(ps.position, START, "back where it lay")


func test_a_carrier_on_a_lift_drops_it_at_the_rest_the_simulation_keeps() -> void:
	_start()
	_pick_up(0)
	var landing := Vector3(6.0, 0.0, -2.0)
	# The simulation's part (Lifts.bomb_rest) while the carrier rides a car: grounded on its floor, half way up.
	ps.on_lift = true
	ps.rest = landing
	cs[0].position = Vector3(8.0, 2.5, -2.0)
	_run(DT)
	assert_eq(ps.rest, landing, "a car's floor is no resting place")
	_out(0)
	_run(DT)
	assert_eq(ps.position, landing)
	assert_false(ps.on_lift)


func test_a_planter_hit_drops_it_unarmed() -> void:
	_start()
	_pick_up(0)
	cs[0].position = SITE_A
	cs[0].using = true
	_run(cfg.plant_time * 0.9)
	_out(0)
	_run(DT)
	assert_eq(ps.status, PlantState.Status.DOWN)
	assert_eq(ps.planting, 0.0)
	assert_eq(ps.planter, -1)


# --- the fuse ---

func test_the_fuse_run_out_wins_the_round_for_the_attackers() -> void:
	_start()
	_plant(0)
	_run(cfg.fuse_time - 0.5)
	assert_eq(rs.phase, RoundState.Phase.LIVE)
	_run(0.6)
	assert_eq(rs.phase, RoundState.Phase.OVER)
	assert_eq(rs.winner, 0)
	assert_eq(rs.reason, GameEvent.RoundEnd.WENT_OFF)
	assert_eq(ps.status, PlantState.Status.GONE_OFF)
	assert_eq(cues.back(), Plant.Cue.WENT_OFF)


func test_it_beeps_faster_as_the_fuse_runs_out() -> void:
	assert_almost_eq(Plant.beep_gap(cfg.fuse_time, cfg), cfg.beep_slow, 0.0001)
	assert_almost_eq(Plant.beep_gap(0.0, cfg), cfg.beep_fast, 0.0001)
	_start()
	_plant(0)
	cues.clear()
	_run(cfg.fuse_time * 0.5)
	var first := cues.count(Plant.Cue.BEEP)
	cues.clear()
	_run(cfg.fuse_time * 0.5 - 0.1)
	assert_gt(first, 3, "it beeps")
	assert_gt(cues.count(Plant.Cue.BEEP), first, "more in the second half")


func test_the_round_clock_running_out_does_not_end_a_round_with_the_bomb_armed() -> void:
	rules.round_time = 5.0
	_start()
	_plant(0)
	_run(6.0)
	assert_eq(rs.clock, 0.0)
	assert_eq(rs.phase, RoundState.Phase.LIVE, "the fuse is the clock now")


func test_the_attackers_wiped_out_after_the_plant_have_not_lost_yet() -> void:
	_start()
	_plant(0)
	_out(0)
	_out(1)
	_run(1.0)
	assert_eq(rs.phase, RoundState.Phase.LIVE, "the defenders still have to disarm it")
	_run(cfg.fuse_time)
	assert_eq(rs.winner, 0)
	assert_eq(rs.reason, GameEvent.RoundEnd.WENT_OFF)


# --- disarming it ---

func test_a_defender_holding_use_at_the_bomb_disarms_it_and_wins_the_round() -> void:
	_start()
	_plant(0)
	cs[2].position = ps.position + Vector3(cfg.defuse_reach - 0.1, 0.0, 0.0)
	cs[2].using = true
	_run(cfg.defuse_time * 0.5)
	assert_eq(ps.defuser, 2)
	assert_true(Plant.busy(ps, cs[2]))
	assert_almost_eq(ps.defusing, 0.5, 0.02)
	_run(cfg.defuse_time * 0.5 + DT)
	assert_eq(rs.phase, RoundState.Phase.OVER)
	assert_eq(rs.winner, 1)
	assert_eq(rs.reason, GameEvent.RoundEnd.DEFUSED)
	assert_eq(ps.status, PlantState.Status.DEFUSED)
	assert_eq(cues.back(), Plant.Cue.DEFUSED)
	assert_eq(_count(GameEvent.Kind.PLANT, Plant.Cue.DEFUSING), 1)


func test_an_attacker_or_someone_out_of_reach_disarms_nothing() -> void:
	_start()
	_plant(0)
	cs[1].position = ps.position
	cs[1].using = true
	cs[2].position = ps.position + Vector3(cfg.defuse_reach + 0.2, 0.0, 0.0)
	cs[2].using = true
	_run(1.0)
	assert_eq(ps.defuser, -1)
	assert_eq(ps.defusing, 0.0)


func test_letting_go_before_the_checkpoint_starts_again_and_past_it_keeps_the_checkpoint() -> void:
	_start()
	_plant(0)
	cs[2].position = ps.position
	cs[2].using = true
	_run(cfg.defuse_time * 0.4)
	cs[2].using = false
	_run(DT)
	assert_eq(ps.defusing, 0.0, "before the checkpoint: from nothing")
	assert_eq(cues.back(), Plant.Cue.DEFUSING_STOPPED)
	cs[2].using = true
	_run(cfg.defuse_time * 0.7)
	cs[2].using = false
	_run(DT)
	assert_almost_eq(ps.defusing, cfg.defuse_checkpoint, 0.0001, "past it: the checkpoint is kept")
	cs[3].position = ps.position
	cs[3].using = true
	_run(cfg.defuse_time * 0.5 + 2.0 * DT)
	assert_eq(rs.reason, GameEvent.RoundEnd.DEFUSED, "a teammate finishes from the checkpoint")
	assert_eq(rs.winner, 1)


func test_no_checkpoint_when_the_config_has_none() -> void:
	cfg.defuse_checkpoint = 0.0
	_start()
	_plant(0)
	cs[2].position = ps.position
	cs[2].using = true
	_run(cfg.defuse_time * 0.8)
	cs[2].using = false
	_run(DT)
	assert_eq(ps.defusing, 0.0)


func test_a_defuse_not_finished_when_the_fuse_runs_out_is_too_late() -> void:
	_start()
	_plant(0)
	_run(cfg.fuse_time - cfg.defuse_time + 0.5)
	cs[2].position = ps.position
	cs[2].using = true
	_run(cfg.defuse_time)
	assert_eq(rs.winner, 0)
	assert_eq(rs.reason, GameEvent.RoundEnd.WENT_OFF)


func test_a_second_defender_does_not_take_the_defuse_from_the_first() -> void:
	_start()
	_plant(0)
	cs[3].position = ps.position
	cs[3].using = true
	_run(0.5)
	cs[2].position = ps.position
	cs[2].using = true
	_run(0.5)
	assert_eq(ps.defuser, 3, "the one already on it keeps it")
	assert_almost_eq(ps.defusing, 1.0 / cfg.defuse_time, 0.02, "two pairs of hands are no faster")


# --- how a round ends ---

func test_the_defenders_wiped_out_lose_at_once_armed_or_not() -> void:
	_start()
	_out(2)
	_out(3)
	_run(DT)
	assert_eq(rs.winner, 0)
	assert_eq(rs.reason, GameEvent.RoundEnd.ELIMINATED)


func test_the_attackers_wiped_out_before_the_plant_lose_at_once() -> void:
	_start()
	_pick_up(0)
	_out(0)
	_out(1)
	_run(DT)
	assert_eq(rs.winner, 1)
	assert_eq(rs.reason, GameEvent.RoundEnd.ELIMINATED)


func test_both_wiped_out_at_once_is_a_draw_before_the_plant_and_the_attackers_after() -> void:
	_start()
	for id in 4:
		_out(id)
	_run(DT)
	assert_true(rs.drawn(), "nobody armed it: played again")
	before_each()
	_start()
	_plant(0)
	for id in 4:
		_out(id)
	_run(DT)
	assert_eq(rs.winner, 0, "armed with nobody left to disarm it")


func test_time_out_with_the_bomb_not_armed_goes_to_the_defenders() -> void:
	_start()
	_pick_up(0)
	_run(rules.round_time + 0.1)
	assert_eq(rs.winner, 1)
	assert_eq(rs.reason, GameEvent.RoundEnd.TIME)


func test_a_plant_under_way_at_the_buzzer_plays_on_until_it_is_done() -> void:
	_start()
	_pick_up(0)
	_run(rules.round_time - cfg.plant_time * 0.5 - 2.0 * DT)
	cs[0].position = SITE_A
	cs[0].using = true
	_run(cfg.plant_time * 0.5 + 0.2)
	assert_eq(rs.phase, RoundState.Phase.LIVE, "overtime while the carrier arms it")
	assert_eq(rs.clock, 0.0)
	_run(cfg.plant_time * 0.5)
	assert_eq(ps.status, PlantState.Status.PLANTED)
	assert_eq(rs.phase, RoundState.Phase.LIVE)


func test_a_plant_given_up_in_overtime_ends_the_round_and_overtime_has_a_limit() -> void:
	_start()
	_pick_up(0)
	_run(rules.round_time - 0.2)
	cs[0].position = SITE_A
	cs[0].using = true
	_run(0.5)
	cs[0].using = false
	_run(2.0 * DT)
	assert_eq(rs.winner, 1, "let go in overtime")
	assert_eq(rs.reason, GameEvent.RoundEnd.TIME)
	before_each()
	cfg.plant_time = 30.0
	_start()
	_pick_up(0)
	_run(rules.round_time - 0.2)
	cs[0].position = SITE_A
	cs[0].using = true
	_run(cfg.max_overtime + 0.5)
	assert_eq(rs.winner, 1, "overtime runs out")


func test_the_roles_swap_at_half_time_and_the_bomb_is_back_at_the_start_each_round() -> void:
	_start()
	for n in 2:
		_plant(0)
		_run(cfg.fuse_time + 0.1)
		assert_eq(rs.winner, 0)
		_run(rules.reset_delay + 2.0 * DT)
		for c in cs:
			c.grounded = true
	assert_eq(rs.number, 3)
	assert_eq(rs.attackers, 1, "Beta attacks after half time")
	assert_eq(cs[2].end, 0)
	assert_eq(ps.status, PlantState.Status.DOWN)
	assert_eq(ps.position, START)
	assert_false(ps.moved)
	cs[0].position = START
	cs[0].using = true
	_run(DT)
	assert_eq(ps.status, PlantState.Status.DOWN, "Alpha defends now: not theirs to take")


func test_ending_the_round_now_gives_it_to_the_defenders_or_sets_an_armed_bomb_off() -> void:
	_start()
	assert_true(Round.run_clock_out(rs))
	_run(2.0 * DT)
	assert_eq(rs.winner, 1)
	assert_eq(rs.reason, GameEvent.RoundEnd.TIME)
	before_each()
	_start()
	_plant(0)
	assert_true(Round.run_clock_out(rs))
	_run(2.0 * DT)
	assert_eq(rs.winner, 0)
	assert_eq(rs.reason, GameEvent.RoundEnd.WENT_OFF)


func test_a_simulated_round_leans_to_the_attackers_once_the_bomb_is_armed() -> void:
	var wins := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 200:
		before_each()
		_start()
		_plant(0)
		if Round.simulate(rs, cs, tuning, events, rng) == 0:
			wins += 1
	assert_gt(wins, 120, "two against two with the bomb armed: well over half")
	assert_lt(wins, 200, "never certain")


func test_the_longest_overtime_is_a_plant_and_its_fuse() -> void:
	assert_almost_eq(Round.longest_overtime(tuning, RoundState.Mode.PLANT_THE_BOMB), cfg.max_overtime + cfg.fuse_time,
			0.0001)


func test_elimination_and_attack_defend_never_touch_the_bomb() -> void:
	for mode: RoundState.Mode in [RoundState.Mode.ELIMINATION, RoundState.Mode.ATTACK_DEFEND]:
		before_each()
		rs.mode = mode
		_start()
		cs[0].position = START
		cs[0].using = true
		_run(1.0)
		assert_eq(ps.status, PlantState.Status.DOWN, str(mode))
		assert_eq(cues.size(), 0, str(mode))
