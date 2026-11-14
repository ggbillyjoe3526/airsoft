extends GutTest
## The second audit pass on the bots (AUD2): a bot leads by the replica it holds, kits kept to a kind of field (the
## Clearer indoors), bushes priced on the nav grid, the string-pulling's routes unchanged, and the bots' lift rides,
## magazine asks and squeezes past Subway's wagons.

const DT := 1.0 / 60.0

var tuning: SimTuning = SimTuning.load_default()


# --- A bot leads by the replica it holds (KNOWN_ISSUES: bots lead by the default loadout's first replica) ---


## A bot holding `replicas` (the first in its hands), alone in a world of `tuning`.
func _holding(replicas: Array[ReplicaConfig]) -> Array:
	var me := Character.new(0, 0, Vector3.ZERO, 0.0, replicas)
	var w := BotWorld.new()
	w.tuning = tuning
	w.cfg = BotConfig.load_default()
	w.characters = [me]
	return [Bot.new(me, 1, w.cfg.skill_for(&"normal"), 1), w]


func test_a_bot_leads_by_the_bbs_of_the_replica_in_its_hands() -> void:
	var aeg := ReplicaStats.load_replica(&"aeg")
	var shotgun := ReplicaStats.load_replica(&"shotgun")
	var with_aeg := _holding([aeg] as Array[ReplicaConfig])
	var with_shotgun := _holding([shotgun, aeg] as Array[ReplicaConfig])
	var by_aeg := BotCombat.flight_time(with_aeg[0], with_aeg[1], 30.0)
	var by_shotgun := BotCombat.flight_time(with_shotgun[0], with_shotgun[1], 30.0)
	var grams := shotgun.bb_weight
	assert_almost_eq(by_shotgun, Ballistics.flight_time_estimate(30.0, Ballistics.muzzle_velocity(shotgun,
			tuning.replica_rules, grams), Ballistics.bb_mass(shotgun, grams), tuning.ballistics), 1e-6,
			"the shotgun's own BBs")
	assert_gt(by_shotgun, by_aeg * 1.05, "slower BBs: a longer lead than the AEG's")
	var b: Bot = with_shotgun[0]
	b.character.armament.active = 1
	assert_almost_eq(BotCombat.flight_time(b, with_shotgun[1], 30.0), by_aeg, 1e-6, "the AEG once it is in hand")


# --- Kits kept to a kind of field (KNOWN_ISSUES: the Clearer on Woodland) ---


func test_indoor_fields_are_the_still_air_ones() -> void:
	var catalog := MapCatalog.shared()
	assert_eq(BotKits.field_kind(catalog.find("depot")), BotKits.INDOOR)
	assert_eq(BotKits.field_kind(catalog.find("subway")), BotKits.INDOOR)
	assert_eq(BotKits.field_kind(catalog.find("woodland")), BotKits.OUTDOOR)
	assert_eq(BotKits.field_kind(catalog.find("stockade")), BotKits.OUTDOOR)
	assert_eq(BotKits.field_kind(null), &"", "a field the catalogue doesn't list: any kit")


func test_the_clearer_is_carried_indoors_only() -> void:
	var k := BotKits.read_file(Pool.read_file())
	assert_eq(k.problems, [] as Array[String])
	var rules := LoadoutRules.standard()
	rules.dev_content = true
	var indoors := 0
	for i in 400:
		var personality: StringName = [&"rusher", &"flanker"][i % 2]
		var outdoor := k.pick(&"hard", rules, Seeds.kit_seed(i, 3), personality, 3.0, BotKits.OUTDOOR)
		assert_ne(outdoor.kit_name, "Clearer", "seed %d: never on Woodland or Stockade" % i)
		var indoor := k.pick(&"hard", rules, Seeds.kit_seed(i, 3), personality, 3.0, BotKits.INDOOR)
		if indoor.kit_name == "Clearer":
			indoors += 1
		var any := k.pick(&"hard", rules, Seeds.kit_seed(i, 3), personality, 3.0)
		assert_eq(any.kit_name, indoor.kit_name, "seed %d: indoors every kit is offered, as with no field" % i)
	assert_gt(indoors, 10, "still carried indoors")
	for plan in k.kits:
		assert_eq(plan.fields, BotKits.INDOOR if plan.kit_name == "Clearer" else &"", plan.kit_name)


func test_a_fields_cell_it_cant_read_is_left_out_with_its_line() -> void:
	var pool := Pool.read_file()
	var header := "| Kit | Primary | Primary parts | Secondary | Secondary parts | Fields | Easy | Normal | Hard |\n" \
			+ "|---|---|---|---|---|---|---|---|---|\n"
	var k := BotKits.parse(header + "| A | AEG Rifle | | | | Indoor | 1 | 1 | 1 |\n"
			+ "| B | AEG Rifle | | | | roof | 1 | 1 | 1 |\n", pool)
	assert_eq(k.kits.size(), 1)
	assert_eq(k.kits[0].fields, BotKits.INDOOR, "any case")
	assert_eq(k.problems.size(), 1)
	assert_string_contains(k.problems[0], "Fields \"roof\"")


# --- Bushes priced on the nav grid (KNOWN_ISSUES: bots walk through a bush where going round is quicker) ---


## A flat 30 m floor with a bush of `radius` (2 m tall) at the middle, when `bushy`.
static func _bush_field(bushy: bool, radius: float) -> MapData:
	var m := MapData.new()
	m.id = "test"
	var floor_block := MapData.Block.new()
	floor_block.kind = &"floor"
	floor_block.center = Vector3(0.0, -0.1, 0.0)
	floor_block.size = Vector3(30.0, 0.2, 30.0)
	m.blocks = [floor_block] as Array[MapData.Block]
	if bushy:
		m.foliage.add(Vector3.ZERO, radius, 2.0)
	return m


## How far `route` (from `start`) runs through `leaves` at a body's bush height.
static func _leaves_walked(leaves: Foliage, start: Vector3, route: PackedVector3Array, probe: float) -> float:
	var total := 0.0
	var from := start
	for p in route:
		total += leaves.depth(from + Vector3.UP * probe, p + Vector3.UP * probe)
		from = p
	return total


static func _length(start: Vector3, route: PackedVector3Array) -> float:
	var total := 0.0
	var from := start
	for p in route:
		total += from.distance_to(p)
		from = p
	return total


func test_the_grids_bush_price_is_the_movements_slow() -> void:
	assert_almost_eq(tuning.nav.bush_cost, tuning.nav.search_greed / tuning.movement.bush_speed_scale, 1e-4,
			"the slow, times the greedy search's greed")
	assert_eq(tuning.nav.bush_probe_height, tuning.movement.bush_probe_height)


func test_nodes_in_a_bush_are_marked_and_priced_as_a_body_is_slowed_there() -> void:
	var m := _bush_field(true, 2.0)
	var g := NavGrid.build(m, tuning.nav, tuning.body)
	var probe := Vector3.UP * tuning.movement.bush_probe_height
	var marked := 0
	for k in g.node_count():
		var inside := m.foliage.holds(g.node_position(k) + probe)
		assert_eq(g.slow[k] == 1, inside, "node %d: marked as Character.in_bush is tested" % k)
		if inside:
			marked += 1
			var w := g.astar.get_point_weight_scale(k)
			assert_almost_eq(w, tuning.nav.bush_cost / tuning.nav.search_greed, 1e-5)
	assert_gt(marked, 100)
	assert_true(NavGrid.build(_bush_field(false, 2.0), tuning.nav, tuning.body).slow.is_empty(), "none without bushes")


func test_a_route_goes_round_a_bush_where_that_is_quicker_and_keeps_round_it() -> void:
	var probe := tuning.movement.bush_probe_height
	var m := _bush_field(true, 2.0)
	var g := NavGrid.build(m, tuning.nav, tuning.body)
	var start := Vector3(-8.0, 0.0, 1.0)
	var goal := Vector3(8.0, 0.0, 1.0)
	var route := PackedVector3Array()
	assert_true(g.find_route(start, goal, route))
	assert_lt(_leaves_walked(m.foliage, start, route, probe), 0.3, "round the bush, a rim at most")
	assert_lt(_length(start, route), 16.0 + 1.0, "and not far out of its way")
	# A bush that fills a gap between two walls is gone through: there is no way round.
	var gap := _bush_field(true, 2.0)
	for side: float in [-1.0, 1.0]:
		var wall := MapData.Block.new()
		wall.kind = &"wall"
		wall.center = Vector3(0.0, 1.0, side * 8.5)
		wall.size = Vector3(0.4, 2.0, 15.0)
		gap.blocks.append(wall)
	var walled := NavGrid.build(gap, tuning.nav, tuning.body)
	start = Vector3(-8.0, 0.0, 0.0)
	goal = Vector3(8.0, 0.0, 0.0)
	assert_true(walled.find_route(start, goal, route))
	assert_gt(_leaves_walked(gap.foliage, start, route, probe), 2.0, "through the only gap")
	# The same field without the bush: the straight line, as before.
	var bare := NavGrid.build(_bush_field(false, 2.0), tuning.nav, tuning.body)
	assert_true(bare.find_route(Vector3(-8.0, 0.0, 1.0), Vector3(8.0, 0.0, 1.0), route))
	assert_eq(route.size(), 1, "one straight leg")


# --- A route planned aboard a lift, and the car stopping on the way (KNOWN_ISSUES: out on the wrong floor's leg) ---


func test_a_rider_whose_car_stops_on_the_way_plans_again_there_and_walks_out_where_its_route_starts() -> void:
	var m := MapData.load_map("subway", MapStyle.new(), 6)
	var level := MapLevel.new()
	add_child(level)
	level.build(m, MapStyle.new(), tuning.body, null, null, false, null, tuning.lifts)
	var nav := NavGrid.build(m, tuning.nav, tuning.body)
	var config := BotConfig.load_default()
	NavLifts.link(nav, level.query(), tuning.lifts, tuning.movement.run_speed, config.lift_wait)
	var q := level.query()
	var spec := q.lifts[0]
	assert_eq(spec.stops.size(), 3, "Subway's west lift: platforms, mezzanine, hall")
	var state := GameState.new(5, tuning)
	state.characters.append(Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout()))
	var bots := BotController.new(state, -1, m, nav, q, tuning, config)
	var w := bots.world
	w.lifts = LiftState.new()
	Lifts.new(tuning, q).reset(w.lifts)
	var b: Bot = w.bots[0]
	var me := b.character
	# Riding up from the platforms, making for the hall: the route is planned from the hall's landing.
	w.lifts.phase[0] = LiftState.Phase.MOVING
	w.lifts.y[0] = (spec.stops[0] + spec.stops[1]) * 0.5
	w.lifts.to[0] = 2
	me.position = spec.car_point(w.lifts.y[0]) + Vector3(0.0, tuning.body.rest_gap, 0.0)
	var goal := spec.landing_point(2, tuning.lifts) + Vector3(-3.0, 0.0, -3.0)
	assert_true(nav.find_route(me.position, goal, b.route, true, w.lifts))
	assert_almost_eq(b.route[0].y, spec.stops[2], tuning.body.max_step, "from the hall's landing")
	b.route_from = me.position
	b.route_leg = 0
	b.route_state = Bot.RouteState.OK
	assert_true(BotRoutes.follow(b, w, DT), "aboard while it rides")
	assert_eq(b.move_dir, Vector3.ZERO, "standing")
	# The car stops at the mezzanine on the way (called meanwhile) and opens there.
	w.lifts.phase[0] = LiftState.Phase.OPEN
	w.lifts.stop[0] = 1
	w.lifts.y[0] = spec.stops[1]
	w.lifts.to[0] = -1
	me.position = spec.car_point(spec.stops[1]) + Vector3(0.0, tuning.body.rest_gap, 0.0)
	assert_true(BotRoutes.follow(b, w, DT))
	assert_eq(b.move_dir, Vector3.ZERO, "it doesn't walk out on the mezzanine on the hall's leg")
	assert_eq(b.route_state, Bot.RouteState.WANTED, "it wants its route again from here")
	assert_true(nav.find_route(me.position, goal, b.route, true, w.lifts))
	assert_almost_eq(b.route[0].y, spec.stops[1], tuning.body.max_step, "now from the mezzanine's landing")
	b.route_from = me.position
	b.route_leg = 0
	b.route_state = Bot.RouteState.OK
	assert_true(BotRoutes.follow(b, w, DT))
	assert_ne(b.move_dir, Vector3.ZERO, "and walks out onto it, as its route says")
	# Open where its route starts, it walks straight out.
	w.lifts.stop[0] = 2
	w.lifts.y[0] = spec.stops[2]
	me.position = spec.car_point(spec.stops[2]) + Vector3(0.0, tuning.body.rest_gap, 0.0)
	assert_true(nav.find_route(me.position, goal, b.route, true, w.lifts))
	b.route_from = me.position
	b.route_leg = 0
	b.route_state = Bot.RouteState.OK
	assert_true(BotRoutes.follow(b, w, DT))
	assert_ne(b.move_dir, Vector3.ZERO, "out at the hall")
	assert_eq(b.route_state, Bot.RouteState.OK)
	level.free()


# --- Magazine asks a bot can't take (KNOWN_ISSUES: an ask to a bot off to the pole stands 15 s unanswered) ---


## Four of team 0 on a 60 by 30 m floor at x = 0, 4, 8 and 12 (0 the asker, on its last magazine) and the share.
func _asks() -> Array:
	var w := BoxWorld.new(tuning.body)
	w.add_floor(60.0, 30.0)
	var s := GameState.new(1, tuning)
	for i in 4:
		s.characters.append(Character.new(i, 0, Vector3(4.0 * i, 0.0, 0.0), 0.0, ReplicaStats.default_loadout()))
	s.characters[0].armament.ammo[0].pouch.fill(0)
	return [s, MagShare.new(tuning, w)]


func test_an_ask_turned_down_goes_to_the_next_nearest_and_never_back() -> void:
	var made := _asks()
	var s: GameState = made[0]
	var share: MagShare = made[1]
	var asker := s.characters[0]
	share.press(asker, s, true)
	assert_eq(asker.mag.asked, 1, "the nearest")
	assert_false(asker.mag.taken, "asked, not taken")
	s.events.clear()
	share.answer(s.characters[1], PlayerCommand.MagAnswer.TURN_DOWN, -1, s, true)
	assert_eq(asker.mag.asked, 2, "passed on to the next nearest at once")
	assert_eq(s.events.first(GameEvent.Kind.MAG_ASK).target, 2)
	share.answer(s.characters[2], PlayerCommand.MagAnswer.TURN_DOWN, -1, s, true)
	assert_eq(asker.mag.asked, 3, "not back to the first that turned it down")
	share.answer(s.characters[3], PlayerCommand.MagAnswer.TAKE, 0, s, true)
	assert_true(asker.mag.taken, "taken: the asker's line may say it is coming")
	share.answer(s.characters[3], PlayerCommand.MagAnswer.TURN_DOWN, 0, s, true)
	assert_eq(asker.mag.asked, 3, "the ask it brings is kept")
	s.events.clear()
	share.answer(s.characters[3], PlayerCommand.MagAnswer.TURN_DOWN, -1, s, true)
	assert_eq(asker.mag.asked, -1, "turned down by everyone: it ends")
	assert_false(asker.mag.taken)
	assert_eq(s.events.first(GameEvent.Kind.MAG_REFUSED).value, MagShare.Refusal.NOBODY, "with nobody to bring it")
	assert_gt(asker.mag.next_ask, s.time, "its gap on, as any ask that ends")
	share.press(asker, s, true)
	assert_eq(asker.mag.asked, -1, "not before the gap")
	asker.mag.next_ask = s.time
	share.press(asker, s, true)
	assert_eq(asker.mag.asked, 1, "a fresh ask may go to anyone again")


func test_an_answer_out_of_play_or_off_the_round_does_nothing() -> void:
	var made := _asks()
	var s: GameState = made[0]
	var share: MagShare = made[1]
	share.press(s.characters[0], s, true)
	share.answer(s.characters[1], PlayerCommand.MagAnswer.TURN_DOWN, -1, s, false)
	assert_eq(s.characters[0].mag.asked, 1, "the round not live")
	share.answer(s.characters[2], PlayerCommand.MagAnswer.TAKE, 0, s, true)
	assert_false(s.characters[0].mag.taken, "only the teammate asked takes it")


func test_the_command_carries_the_answer_and_resets_it() -> void:
	var cmd := PlayerCommand.new()
	cmd.mag_answer = PlayerCommand.MagAnswer.TURN_DOWN
	cmd.mag_answer_to = 4
	var copy := PlayerCommand.new()
	copy.copy_from(cmd)
	assert_eq(copy.mag_answer, PlayerCommand.MagAnswer.TURN_DOWN)
	assert_eq(copy.mag_answer_to, 4)
	cmd.reset()
	assert_eq(cmd.mag_answer, PlayerCommand.MagAnswer.NONE)
	assert_eq(cmd.mag_answer_to, -1)


## A 100 m open field: four of team 0 at `at` (all bots), round 1 live, the bots holding fire. [sim, state, bots].
func _bot_squad(at: Array[Vector3]) -> Array:
	var m := MapData.new()
	m.id = "open field"
	m.kill_y = -10.0
	var floor_block := MapData.Block.new()
	floor_block.kind = &"floor"
	floor_block.center = Vector3(0.0, -0.25, 0.0)
	floor_block.size = Vector3(100.0, 0.5, 100.0)
	m.blocks.append(floor_block)
	for e in 2:
		var end := MapEnd.new()
		end.spawns.append(SpawnPoint.new(Vector3(-30.0, 0.0, 20.0) if e == 0 else Vector3(40.0, 0.0, -40.0), 0.0))
		end.dead_zone.append(SpawnPoint.new(Vector3(-45.0, 0.0, 45.0) if e == 0 else Vector3(45.0, 0.0, -45.0), 0.0))
		m.ends.append(end)
	var w := BoxWorld.new(tuning.body)
	w.add_floor(100.0, 100.0)
	var nav := NavGrid.build(m, tuning.nav, tuning.body)
	var sim := Simulation.new(tuning, w, w.mover(), m.ends, m.kill_y)
	sim.nav = nav
	var state := GameState.new(5, tuning)
	for i in at.size():
		state.characters.append(Character.new(i, 0, at[i], 0.0, ReplicaStats.default_loadout()))
	state.characters.append(Character.new(at.size(), 1, Vector3(40.0, 0.0, -40.0), 0.0, ReplicaStats.default_loadout()))
	var bots := BotController.new(state, -1, m, nav, w, tuning, BotConfig.load_default())
	sim.start_match(state)
	bots.observe(state)
	for b in bots.world.bots:
		if b.character.team == 1:
			bots.world.bots.erase(b)
			break
	for i in at.size():
		state.characters[i].position = at[i]
	state.cheats.bots_hold_fire = true
	return [sim, state, bots]


func _bot_ticks(made: Array, seconds: float) -> void:
	var sim: Simulation = made[0]
	var state: GameState = made[1]
	var bots: BotController = made[2]
	var cmds: Array[PlayerCommand] = []
	for c in state.characters:
		cmds.append(PlayerCommand.new())
	for t in roundi(seconds / DT):
		bots.think(state, cmds, DT)
		sim.step(state, cmds, DT)
		bots.observe(state)


func test_a_bot_bringing_one_passes_a_second_ask_on_to_a_free_teammate_and_says_it_only_once_it_sets_off() -> void:
	var made := _bot_squad([Vector3(-30.0, 0.0, 20.0), Vector3(-26.0, 0.0, 20.0), Vector3(-20.0, 0.0, 20.0),
			Vector3(-8.0, 0.0, 20.0)])
	var state: GameState = made[1]
	var bots: BotController = made[2]
	_bot_ticks(made, 0.5)
	var first := state.characters[0]
	first.armament.ammo[0].pouch.fill(0)
	_bot_ticks(made, 0.2)
	assert_eq(first.mag.asked, 1, "the nearest")
	assert_true(first.mag.taken, "bot 1 took it through its command")
	var giver: Bot = null
	for b in bots.world.bots:
		if b.character.id == 1:
			giver = b
	assert_eq(giver.mag_for, first)
	# Bot 2 runs low while bot 1 brings bot 0's: its ask goes to bot 1 (the nearest), which passes it on to bot 3.
	var second := state.characters[2]
	second.armament.ammo[0].pouch.fill(0)
	var passed := false
	var asked_first := false
	for t in 30:
		_bot_ticks(made, DT)
		asked_first = asked_first or second.mag.asked == 1
		if second.mag.asked == 3:
			passed = true
			break
	assert_true(asked_first, "bot 1 asked first, the nearest")
	assert_true(passed, "passed on to bot 3, free, rather than waiting its turn")
	assert_eq(giver.mag_for, first, "bot 1 still brings bot 0's")
	assert_eq(first.mag.asked, 1)
