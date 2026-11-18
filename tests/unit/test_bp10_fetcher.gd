extends GutTest
## BP10 part 2: a bot picked to fetch the bomb keeps the job for BotConfig.fetcher_hold (BotPlant._pick_fetcher), so
## attackers by a wall (Woodland's Hut row) stop trading it every second.

const START := Vector3(-30.0, 0.0, 0.0)

var w: BotWorld
var rs: RoundState
var cs: Array[Character] = []


func before_each() -> void:
	w = BotWorld.new()
	w.cfg = BotConfig.load_default()
	w.tuning = SimTuning.new()
	w.mode = RoundState.Mode.PLANT_THE_BOMB
	w.attackers = 0
	w.planner = RoundPlanner.new(7)
	w.planner.spawn_centre = [Vector3(-30.0, 0.0, 0.0), Vector3(40.0, 0.0, 0.0)]
	w.planner.attack_dir = [Vector2(1.0, 0.0), Vector2(-1.0, 0.0)]
	w.planner.attack_flag = 0
	rs = RoundState.new()
	rs.mode = RoundState.Mode.PLANT_THE_BOMB
	rs.attackers = 0
	rs.plant.set_sites(PackedVector3Array([Vector3(30.0, 0.0, -12.0), Vector3(30.0, 0.0, 12.0)]),
			PackedFloat32Array(), w.tuning.plant.site_radius)
	rs.plant.start = START
	rs.plant.reset()
	cs = []
	w.bots = []
	var loadout: Array[ReplicaConfig] = []
	for id in 6:
		var team := 0 if id < 3 else 1
		var at := Vector3(-32.0 - id, 0.0, float(id)) if team == 0 else Vector3(38.0, 0.0, float(id) * 4.0 - 16.0)
		var c := Character.new(id, team, at, 0.0, loadout)
		cs.append(c)
		w.bots.append(Bot.new(c, id + 1, w.cfg.skill, 6))
	w.characters = cs
	BotPlant.sync(w, rs)
	# Bot 0 near the bomb, 1 and 2 far.
	cs[0].position = START + Vector3(10.0, 0.0, 0.0)
	cs[1].position = START + Vector3(30.0, 0.0, 0.0)
	cs[2].position = START + Vector3(40.0, 0.0, 0.0)
	w.time = 100.0


func _bot(id: int) -> Bot:
	return w.bot_of(cs[id])


func test_a_fresh_pick_stamps_the_time() -> void:
	BotPlant.plan(w)
	assert_true(_bot(0).fetcher)
	assert_eq(_bot(0).fetcher_since, 100.0)


func test_the_fetcher_is_kept_within_the_hold_though_another_is_far_nearer() -> void:
	BotPlant.plan(w)
	cs[0].position = START + Vector3(40.0, 0.0, 0.0)
	cs[1].position = START + Vector3(1.0, 0.0, 0.0)
	w.time += 1.0
	BotPlant.plan(w)
	assert_true(_bot(0).fetcher)
	assert_false(_bot(1).fetcher)
	assert_eq(_bot(0).fetcher_since, 100.0, "keeping it does not restamp it")


func test_the_job_goes_to_one_nearer_by_the_margin_once_the_hold_is_over() -> void:
	BotPlant.plan(w)
	cs[0].position = START + Vector3(40.0, 0.0, 0.0)
	cs[1].position = START + Vector3(1.0, 0.0, 0.0)
	w.time += w.cfg.fetcher_hold + 0.01
	BotPlant.plan(w)
	assert_true(_bot(1).fetcher)
	assert_false(_bot(0).fetcher)
	assert_eq(_bot(1).fetcher_since, w.time, "the new one's hold starts now")


func test_the_job_stays_after_the_hold_when_nobody_is_nearer_by_the_margin() -> void:
	BotPlant.plan(w)
	cs[1].position = cs[0].position + Vector3(-w.cfg.raiser_switch_margin * 0.5, 0.0, 0.0)
	w.time += w.cfg.fetcher_hold + 1.0
	BotPlant.plan(w)
	assert_true(_bot(0).fetcher)
	assert_false(_bot(1).fetcher)


func test_a_fetcher_out_of_play_is_released_at_once_inside_the_hold() -> void:
	BotPlant.plan(w)
	cs[0].status = Character.Status.OUT
	w.time += 0.1
	BotPlant.plan(w)
	assert_false(_bot(0).fetcher)
	assert_true(_bot(1).fetcher, "the next nearest takes it")


func test_a_fetcher_given_a_squad_order_is_released_at_once_inside_the_hold() -> void:
	BotPlant.plan(w)
	_bot(0).order = SquadOrder.Kind.HOLD
	w.time += 0.1
	BotPlant.plan(w)
	assert_false(_bot(0).fetcher)
	assert_true(_bot(1).fetcher)


func test_reset_clears_the_fetcher_stamp() -> void:
	BotPlant.plan(w)
	_bot(0).reset(0, 0, 0.0, w.cfg)
	assert_false(_bot(0).fetcher)
	assert_eq(_bot(0).fetcher_since, -INF)


func test_a_bot_picked_again_after_a_carry_gets_a_new_hold() -> void:
	BotPlant.plan(w)
	rs.plant.status = PlantState.Status.CARRIED
	rs.plant.carrier = 0
	w.time += 1.0
	BotPlant.plan(w)
	assert_false(_bot(0).fetcher)
	rs.plant.status = PlantState.Status.DOWN
	w.time += 1.0
	BotPlant.plan(w)
	assert_true(_bot(0).fetcher)
	assert_eq(_bot(0).fetcher_since, w.time, "a bomb dropped again is a new job")


func test_the_player_taking_the_bomb_leaves_no_fetcher() -> void:
	BotPlant.plan(w)
	w.bots.erase(_bot(0))
	rs.plant.status = PlantState.Status.CARRIED
	rs.plant.carrier = 0
	w.time += 0.1
	BotPlant.plan(w)
	for b in w.bots:
		assert_false(b.fetcher)


func test_after_the_hold_the_storey_rule_still_wins() -> void:
	# Subway: the bomb a storey up; the kept one is off its storey, one standing on it takes over after the hold.
	var storey := w.cfg.plant_player_level + 6.0
	rs.plant.position = START + Vector3(0.0, storey, 0.0)
	BotPlant.plan(w)
	assert_true(_bot(0).fetcher)
	cs[1].position = START + Vector3(35.0, storey, 0.0)
	w.time += 1.0
	BotPlant.plan(w)
	assert_true(_bot(0).fetcher, "held, though bot 1 is on the bomb's storey")
	w.time += w.cfg.fetcher_hold
	BotPlant.plan(w)
	assert_true(_bot(1).fetcher)
	assert_false(_bot(0).fetcher)
