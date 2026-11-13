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


# ---- Attempt 2: the dropped bomb's resting place ----


func test_a_carrier_hit_in_the_air_drops_the_bomb_on_the_floor_it_last_stood_on() -> void:
	_start()
	cs[0].position = START
	cs[0].using = true
	_run(DT)
	cs[0].using = false
	var floor_at := START + Vector3(3.0, 0.0, 0.0)
	cs[0].position = floor_at
	_run(DT)
	cs[0].grounded = false
	cs[0].position = floor_at + Vector3(0.5, 1.2, 0.0)
	_run(DT)
	Elimination.eliminate(cs[0], 1, cs, ends)
	_run(DT)
	assert_eq(ps.status, PlantState.Status.DOWN)
	assert_eq(ps.position, floor_at, "on the floor, not hanging where they were in the air")


func test_a_carrier_never_grounded_since_pickup_drops_it_where_it_lay() -> void:
	_start()
	cs[0].position = START
	cs[0].using = true
	_run(DT)
	assert_eq(ps.status, PlantState.Status.CARRIED)
	cs[0].grounded = false
	cs[0].position = START + Vector3(0.0, 2.0, 0.0)
	Elimination.eliminate(cs[0], 1, cs, ends)
	_run(DT)
	assert_eq(ps.position, START, "the pickup spot is the floor it lay on")


func test_a_bomb_dropped_and_picked_up_again_rests_where_the_new_carrier_stood() -> void:
	_start()
	cs[0].position = START
	cs[0].using = true
	_run(DT)
	cs[0].position = START + Vector3(4.0, 0.0, 0.0)
	_run(DT)
	Elimination.eliminate(cs[0], 1, cs, ends)
	_run(DT)
	var lay := ps.position
	assert_eq(lay, START + Vector3(4.0, 0.0, 0.0))
	cs[1].position = lay
	cs[1].using = true
	_run(DT)
	assert_eq(ps.carrier, 1)
	cs[1].grounded = false
	cs[1].position = lay + Vector3(0.0, 1.5, 0.0)
	Elimination.eliminate(cs[1], 1, cs, ends)
	_run(DT)
	assert_eq(ps.position, lay, "the second carrier's rest is the spot it took the bomb from")


func test_a_new_round_puts_the_resting_place_back_at_the_start() -> void:
	_start()
	cs[0].position = START
	cs[0].using = true
	_run(DT)
	cs[0].position = START + Vector3(9.0, 0.0, 0.0)
	_run(DT)
	assert_ne(ps.rest, START)
	ps.reset()
	assert_eq(ps.rest, START)
	assert_false(ps.on_lift)


func test_carrier_of_is_null_unless_the_bomb_is_carried() -> void:
	_start()
	assert_null(Plant.carrier_of(ps, cs))
	cs[0].position = START
	cs[0].using = true
	_run(DT)
	assert_same(Plant.carrier_of(ps, cs), cs[0])
	ps.carrier = 99
	assert_null(Plant.carrier_of(ps, cs), "a carrier id nobody has: null, not a crash")


# ---- Attempt 2: the bots' site guards, the player's storey and what smoke hides ----


var w: BotWorld
var brs: RoundState
var bcs: Array[Character]


func _bot_world(player: int = -1, defenders: int = 3, two_sites: bool = true) -> void:
	w = BotWorld.new()
	w.cfg = BotConfig.load_default()
	w.tuning = SimTuning.new()
	w.mode = RoundState.Mode.PLANT_THE_BOMB
	w.attackers = 0
	w.planner = RoundPlanner.new(7)
	w.planner.spawn_centre = [Vector3(-30.0, 0.0, 0.0), Vector3(40.0, 0.0, 0.0)]
	w.planner.attack_dir = [Vector2(1.0, 0.0), Vector2(-1.0, 0.0)]
	w.planner.attack_flag = 0
	brs = RoundState.new()
	brs.mode = RoundState.Mode.PLANT_THE_BOMB
	brs.attackers = 0
	var sites := PackedVector3Array([SITE_A, SITE_B]) if two_sites else PackedVector3Array([SITE_A])
	brs.plant.set_sites(sites, PackedFloat32Array(), w.tuning.plant.site_radius)
	brs.plant.start = START
	brs.plant.reset()
	bcs = []
	w.bots = []
	var loadout: Array[ReplicaConfig] = []
	for id in 3 + defenders:
		var team := 0 if id < 3 else 1
		var c := Character.new(id, team, Vector3(38.0, 0.0, float(id)), 0.0, loadout)
		c.end = 1 if team == 1 else 0
		bcs.append(c)
		if id != player:
			w.bots.append(Bot.new(c, id + 1, w.cfg.skill, 6))
	w.characters = bcs
	BotPlant.sync(w, brs)


func _deal_all_to_a() -> void:
	w.lanes = [PackedVector3Array([START, SITE_A + Vector3(4.0, 0.0, 2.0)]),
			PackedVector3Array([START, SITE_A + Vector3(6.0, 0.0, 9.0)])]
	for b in w.bots:
		if b.character.team != w.attackers:
			b.reset(b.character.id % 2, 1, 0.0, w.cfg)


func _guards() -> int:
	var n := 0
	for b in w.bots:
		if b.site_guard >= 0:
			n += 1
	return n


func test_one_defender_alone_is_not_pulled_off_its_lane() -> void:
	_bot_world(-1, 1)
	_deal_all_to_a()
	BotPlant.plan(w)
	assert_eq(_guards(), 0, "half of one, rounded down: none, and nothing crashes")


func test_two_defenders_leave_one_guarding_the_open_site() -> void:
	_bot_world(-1, 2)
	_deal_all_to_a()
	BotPlant.plan(w)
	assert_eq(_guards(), 1)


func test_five_defenders_guard_with_two() -> void:
	_bot_world(-1, 5)
	_deal_all_to_a()
	BotPlant.plan(w)
	assert_eq(_guards(), 2, "half of five, rounded down")


func test_the_player_among_the_defenders_is_never_dealt_a_guard_post() -> void:
	_bot_world(4, 3)
	_deal_all_to_a()
	BotPlant.plan(w)
	assert_null(w.bot_of(bcs[4]))
	assert_eq(_guards(), 1, "half of the two bots")


func test_a_map_with_one_site_deals_no_guards() -> void:
	_bot_world(-1, 3, false)
	_deal_all_to_a()
	BotPlant.plan(w)
	assert_eq(_guards(), 0)


func test_the_roles_swapping_at_half_time_deals_the_new_defenders() -> void:
	_bot_world()
	_deal_all_to_a()
	BotPlant.plan(w)
	assert_eq(_guards(), 1)
	w.attackers = 1
	brs.attackers = 1
	var ev := SimEvents.new()
	ev.add(GameEvent.Kind.ROUND_START)
	BotPlant.observe(w, ev, 0.0)
	w.lanes = [PackedVector3Array([START, SITE_A + Vector3(4.0, 0.0, 2.0)])]
	for b in w.bots:
		b.reset(0, 1, 0.0, w.cfg)
		b.character.end = 0 if b.character.team == 0 else 1
	BotPlant.plan(w)
	for b in w.bots:
		if b.character.team == 1:
			assert_eq(b.site_guard, -1, "the old defenders are attackers now")
	assert_eq(_guards(), 1, "the other team's bots hold the open site")


func test_a_guard_is_dealt_once_a_round_and_kept_over_later_plans() -> void:
	_bot_world()
	_deal_all_to_a()
	BotPlant.plan(w)
	var who := -1
	for b in w.bots:
		if b.site_guard >= 0:
			who = b.character.id
	assert_ne(who, -1)
	for i in 5:
		BotPlant.plan(w)
	assert_eq(w.bot_of(bcs[who]).site_guard, 1)
	assert_eq(_guards(), 1)


func test_given_away_costs_nothing_and_changes_nothing_without_a_bomb() -> void:
	_bot_world()
	w.plant = null
	assert_false(BotPlant.given_away(bcs[3], 1.0, w))


func _smoke(at: Vector3) -> void:
	var box := BoxWorld.new(w.tuning.body)
	box.add_floor(120.0, 80.0)
	w.query = box
	var g := Grenade.new()
	g.launch(Grenade.Kind.SMOKE, 0, at, Vector3.ZERO)
	g.resting = true
	g.popped = true
	g.smoking = w.tuning.grenades.smoke_grow + 1.0
	w.grenades = [g]


func test_the_edge_of_the_giving_away_range_is_inclusive() -> void:
	_bot_world()
	brs.plant.status = PlantState.Status.CARRIED
	brs.plant.carrier = 1
	brs.plant.planter = 1
	assert_true(BotPlant.given_away(bcs[1], w.cfg.plant_gives_away, w))
	assert_false(BotPlant.given_away(bcs[1], w.cfg.plant_gives_away + 0.01, w))
	assert_false(BotPlant.given_away(bcs[2], 1.0, w), "hands off: never")


func test_a_bomb_laid_down_gives_nobody_away_once_the_planter_lets_go() -> void:
	_bot_world()
	var site := brs.plant.sites[0]
	brs.plant.status = PlantState.Status.CARRIED
	brs.plant.carrier = 1
	brs.plant.position = site
	bcs[1].position = site
	_smoke(site)
	bcs[3].position = site + Vector3(2.0, 0.0, 0.0)
	bcs[3].yaw = BotAim.look_yaw(bcs[3].position, bcs[1].position)
	brs.plant.planter = 1
	assert_gt(BotSenses.visible_part(bcs[3], bcs[1], w), 0.0)
	brs.plant.planter = -1
	assert_eq(BotSenses.visible_part(bcs[3], bcs[1], w), 0.0, "hands off: hidden by the smoke again")


func test_a_floor_between_still_hides_the_one_on_the_bomb_through_smoke() -> void:
	_bot_world()
	var site := brs.plant.sites[0]
	brs.plant.status = PlantState.Status.CARRIED
	brs.plant.carrier = 1
	brs.plant.planter = 1
	brs.plant.position = site
	bcs[1].position = site
	_smoke(site)
	(w.query as BoxWorld).add_box(site + Vector3(0.0, 3.0, 0.0), Vector3(20.0, 0.3, 20.0))
	bcs[3].position = site + Vector3(2.0, 6.0, 0.0)
	bcs[3].yaw = BotAim.look_yaw(bcs[3].position, bcs[1].position)
	assert_eq(BotSenses.visible_part(bcs[3], bcs[1], w), 0.0, "on another storey behind a slab: unseen")


func test_the_player_arming_it_is_given_away_to_a_bot_through_smoke() -> void:
	_bot_world(0)
	var site := brs.plant.sites[0]
	brs.plant.status = PlantState.Status.CARRIED
	brs.plant.carrier = 0
	brs.plant.planter = 0
	brs.plant.position = site
	bcs[0].position = site
	_smoke(site)
	bcs[3].position = site + Vector3(3.0, 0.0, 0.0)
	bcs[3].yaw = BotAim.look_yaw(bcs[3].position, bcs[0].position)
	assert_gt(BotSenses.visible_part(bcs[3], bcs[0], w), 0.0)


func test_a_player_on_another_storey_has_no_claim_on_the_bomb() -> void:
	_bot_world(0)
	brs.plant.position = Vector3(20.0, 0.0, 0.0)
	w.plant_down_at = 0.0
	w.time = 0.0
	bcs[0].position = Vector3(20.0, w.cfg.plant_player_level, 1.0)
	assert_false(BotPlant.may_take(w), "exactly at the level limit: still on its storey")
	bcs[0].position = Vector3(20.0, w.cfg.plant_player_level + 0.1, 1.0)
	assert_true(BotPlant.may_take(w), "one storey up: the bots may take it")
	bcs[0].position = Vector3(20.0, -w.cfg.plant_player_level - 0.1, 1.0)
	assert_true(BotPlant.may_take(w), "one storey down too")


func test_a_defuse_is_open_to_the_bots_when_the_player_is_on_another_storey() -> void:
	_bot_world(3)
	brs.plant.status = PlantState.Status.PLANTED
	brs.plant.site = 0
	brs.plant.position = SITE_A
	brs.plant.fuse_left = w.tuning.plant.fuse_time
	bcs[3].position = SITE_A + Vector3(1.0, 0.0, 0.0)
	assert_false(BotPlant.may_defuse(w), "the player stands by it with the fuse long")
	bcs[3].position = SITE_A + Vector3(1.0, w.cfg.plant_player_level + 0.5, 0.0)
	assert_true(BotPlant.may_defuse(w))


# --- Attempt 3: the fetcher chosen by storey ---


func _fetcher_id() -> int:
	for b in w.bots:
		if b.fetcher:
			return b.character.id
	return -1


func _bomb_down_at(at: Vector3) -> void:
	brs.plant.position = at
	brs.plant.status = PlantState.Status.DOWN


func test_a_fetcher_exactly_at_the_storey_limit_is_kept_over_a_nearer_one_below_it() -> void:
	_bot_world()
	_bomb_down_at(Vector3(0.0, 9.0, 0.0))
	bcs[0].position = Vector3(30.0, 9.0 - w.cfg.plant_player_level, 0.0)
	bcs[1].position = Vector3(40.0, 9.0 - w.cfg.plant_player_level - 0.01, 1.0)
	bcs[2].position = Vector3(41.0, 9.0 - w.cfg.plant_player_level - 0.01, 1.0)
	BotPlant.plan(w)
	assert_eq(_fetcher_id(), 0, "the only one within the limit")
	bcs[1].position = Vector3(3.0, 9.0 - w.cfg.plant_player_level - 0.01, 0.0)
	BotPlant.plan(w)
	assert_eq(_fetcher_id(), 0, "a hair under the limit is not on the storey")


func test_a_fetcher_given_a_squad_order_hands_the_bomb_to_the_nearest_on_its_storey() -> void:
	_bot_world()
	_bomb_down_at(Vector3(0.0, 9.0, 0.0))
	bcs[0].position = Vector3(5.0, 9.0, 0.0)
	bcs[1].position = Vector3(20.0, 9.0, 0.0)
	bcs[2].position = Vector3(4.0, 0.0, 0.0)
	BotPlant.plan(w)
	assert_eq(_fetcher_id(), 0)
	w.bots[0].order = SquadOrder.Kind.HOLD if SquadOrder.Kind.has("HOLD") else SquadOrder.Kind.values()[1]
	BotPlant.plan(w)
	assert_eq(_fetcher_id(), 1, "the keeper under orders is no keeper; the one off the storey stays out")
	assert_false(w.bots[0].fetcher)


func test_a_keeper_that_is_out_leaves_the_job_to_the_nearest_with_nobody_on_the_storey() -> void:
	_bot_world()
	_bomb_down_at(Vector3(0.0, 9.0, 0.0))
	bcs[0].position = Vector3(10.0, 0.0, 0.0)
	bcs[1].position = Vector3(20.0, 0.0, 0.0)
	bcs[2].position = Vector3(2.0, 0.0, 30.0)
	BotPlant.plan(w)
	assert_eq(_fetcher_id(), 0)
	bcs[0].status = Character.Status.OUT
	BotPlant.plan(w)
	assert_eq(_fetcher_id(), 1, "nobody on the storey and no keeper: the nearest level")


func test_the_job_after_a_pick_up_and_drop_goes_to_the_one_on_the_storey_not_the_old_keeper() -> void:
	_bot_world()
	_bomb_down_at(Vector3(0.0, 9.0, 0.0))
	bcs[0].position = Vector3(5.0, 0.0, 0.0)
	bcs[1].position = Vector3(30.0, 9.0, 0.0)
	bcs[2].position = Vector3(40.0, 0.0, 0.0)
	BotPlant.plan(w)
	assert_eq(_fetcher_id(), 1)
	brs.plant.status = PlantState.Status.CARRIED
	BotPlant.plan(w)
	assert_eq(_fetcher_id(), -1, "while it is carried nobody fetches")
	_bomb_down_at(Vector3(0.0, 0.9, 0.0))
	BotPlant.plan(w)
	assert_eq(_fetcher_id(), 0, "dropped a storey lower: the nearest of those on that storey")


func test_a_fetcher_half_a_flight_below_a_bomb_on_the_stairs_has_not_come_to_it() -> void:
	_bot_world()
	_bomb_down_at(Vector3(0.0, 1.8, 0.0))
	bcs[0].position = Vector3(0.3, 0.0, 0.0)
	bcs[1].position = Vector3(30.0, 0.0, 0.0)
	bcs[2].position = Vector3(31.0, 0.0, 0.0)
	w.time = 100.0
	BotPlant.plan(w)
	assert_eq(_fetcher_id(), 0)
	var cmd := PlayerCommand.new()
	BotMovement._flag(w.bots[0], w, cmd, DT)
	var cmd2 := PlayerCommand.new()
	BotPlant.act(w.bots[0], w, cmd2)
	assert_false(Plant.in_reach(brs.plant, bcs[0], w.tuning.plant.pickup_reach, w.tuning.plant), "out of a hand's reach")
	assert_false(cmd2.interact)
	assert_false(cmd.crouch, "so it has not come to it: it keeps on up the stairs (QA attempt 3: it crouched there for good)")
