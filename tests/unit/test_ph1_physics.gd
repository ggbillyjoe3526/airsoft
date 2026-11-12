extends GutTest
## PH1, the physics audit's fixes: a field's own weather (still air indoors, its air's temperature for every BB and for a
## gas replica's energy), the site limit read at the BB weight loaded, BBs up to 0.40 g, a lobbed BB that lands instead
## of vanishing, and a moving body met where it was when the BB got there (BBStep._first_body).

const DT := 1.0 / 60.0
const KILL_Y := -10.0
const MASS := 0.25e-3
const AEG := "000002"
const PISTOL := "000001"
const CYBER := "000019"
## The built-in volume's chest is a capsule this far round its axis (HitConfig.body_radius), and this is chest height.
const CHEST := 1.3
## A sprinter's step in one tick (m): 6.6 m/s.
const STRIDE := 0.11

var tuning: SimTuning = null
var events: SimEvents = null
var no_wall: WorldQuery = WorldQuery.new()
var ends: Array[MapEnd] = []


func before_each() -> void:
	tuning = SimTuning.new()
	tuning.hits.fit = null
	events = SimEvents.new()


func rules() -> LoadoutRules:
	return LoadoutRules.new(Pool.read_file(), ReplicaStats.read_file(), tuning.replica_rules)


## A level BB along -Z from `x` across, chest high, fast enough to reach a body 0.2 m ahead early in its first tick.
func shot(pool: BBPool, x: float) -> BB:
	return pool.spawn(1, Vector3(x, CHEST, 0.0), Vector3.FORWARD, 90.0, 0.0, MASS, tuning.ballistics.spin_per_hop)


## The shooter (id 1) and a body (id 2, the other team) standing `ahead` m down the line, that stepped `step` this tick.
func roster(ahead: float, step: Vector3) -> Array[Character]:
	var body := Character.new(2, 1, Vector3(0.0, 0.0, -ahead) - step, 0.0)
	body.prev_position = body.position
	body.position += step
	return [Character.new(1, 0, Vector3(0.0, 0.0, 5.0), 0.0), body]


func fly(pool: BBPool, characters: Array[Character]) -> void:
	BBStep.step(pool, characters, no_wall, tuning, KILL_Y, false, ends, events, DT)


func hit_target() -> int:
	for i in events.count:
		if events.items[i].kind == GameEvent.Kind.CHARACTER_HIT:
			return events.items[i].target
	return -1


# --- Weather ---


func test_no_breeze_reaches_an_indoor_field_and_part_of_it_a_sheltered_one() -> void:
	for seed_value in range(1, 20):
		var open := Wind.new()
		open.draw(seed_value, tuning.wind)
		var indoors := Wind.new()
		indoors.draw(seed_value, tuning.wind, 0.0)
		var sheltered := Wind.new()
		sheltered.draw(seed_value, tuning.wind, 0.5)
		assert_eq(indoors.at(12.3), Vector3.ZERO, "still air")
		assert_almost_eq(sheltered.speed, open.speed * 0.5, 1e-9)
		assert_eq(sheltered.yaw, open.yaw, "the same breeze, weaker")
		assert_true(sheltered.at(12.3).is_equal_approx(open.at(12.3) * 0.5))


func test_a_match_draws_its_breeze_by_the_fields_share() -> void:
	var sim := Simulation.new(tuning, no_wall, CharacterMover.new(), ends, KILL_Y)
	var state := GameState.new(11, tuning)
	assert_eq(state.wind_share, 1.0)
	assert_eq(state.air_temperature, tuning.ballistics.air_temperature)
	assert_same(state.air, AirModel.of(tuning.ballistics))
	sim.set_weather(state, 0.0, 14.0)
	sim.start_match(state)
	assert_eq(state.wind.speed, 0.0)
	assert_eq(state.wind.at(3.0), Vector3.ZERO)
	assert_eq(state.air_temperature, 14.0)
	sim.set_weather(state, 1.0, 20.0)
	sim.start_match(state)
	assert_between(state.wind.speed, tuning.wind.min_speed, tuning.wind.max_speed)
	assert_same(state.air, AirModel.of(tuning.ballistics), "the rated air is the one model")


func test_cold_air_is_thicker_and_slows_a_bb_sooner() -> void:
	var cfg := tuning.ballistics
	var rated := AirModel.of(cfg)
	assert_same(AirModel.at(cfg, cfg.air_temperature), rated)
	var cold := AirModel.at(cfg, 0.0)
	assert_ne(cold, rated)
	var denser := AirModel.air_density(0.0, cfg.air_pressure) / AirModel.air_density(20.0, cfg.air_pressure)
	assert_almost_eq(denser, 293.15 / 273.15, 1e-6, "the ideal gas law")
	assert_almost_eq(cold.lift_factor / rated.lift_factor, denser, 1e-6)
	assert_gt(cold.drag_factor(80.0), rated.drag_factor(80.0))
	var pool := BBPool.new(2)
	var warm_bb := pool.spawn(0, Vector3.ZERO, Vector3.FORWARD, 88.0, 0.0, MASS, cfg.spin_per_hop)
	var cold_bb := pool.spawn(0, Vector3.ZERO, Vector3.FORWARD, 88.0, 0.0, MASS, cfg.spin_per_hop)
	for i in 30:
		Ballistics.step_flight(warm_bb, rated, DT)
		Ballistics.step_flight(cold_bb, cold, DT)
	assert_lt(cold_bb.velocity.length(), warm_bb.velocity.length())
	# A few per cent, not a different game: the air's part is small beside a gas replica's.
	assert_gt(cold_bb.velocity.length(), warm_bb.velocity.length() * 0.95)


func test_the_bb_step_flies_bbs_in_the_fields_air() -> void:
	var cfg := tuning.ballistics
	var cold := AirModel.at(cfg, -10.0)
	var pool := BBPool.new(2)
	var a := pool.spawn(0, Vector3(0, 50, 0), Vector3.FORWARD, 88.0, 0.0, MASS, cfg.spin_per_hop)
	var nobody: Array[Character] = []
	var none: Array[RangeTarget] = []
	BBStep.step(pool, nobody, no_wall, tuning, KILL_Y, false, ends, events, DT, Vector3.ZERO, null, none, cold)
	var in_cold := a.velocity.length()
	a = pool.spawn(0, Vector3(0, 50, 0), Vector3.FORWARD, 88.0, 0.0, MASS, cfg.spin_per_hop)
	pool.bbs[0].active = pool.bbs[0] == a
	BBStep.step(pool, nobody, no_wall, tuning, KILL_Y, false, ends, events, DT)
	assert_lt(in_cold, a.velocity.length())
	assert_lt(Ballistics.flight_time_estimate(40.0, 88.0, MASS, cfg),
			Ballistics.flight_time_estimate(40.0, 88.0, MASS, cfg, cold), "a bot's lead knows the air too")


func test_gas_shoots_softer_in_the_cold_and_harder_in_the_heat() -> void:
	var w := tuning.weather
	assert_eq(w.gas_energy_scale(20.0, 20.0), 1.0)
	assert_almost_eq(w.gas_energy_scale(10.0, 20.0), 0.88, 1e-9)
	assert_almost_eq(w.gas_energy_scale(30.0, 20.0), 1.12, 1e-9)
	assert_eq(w.gas_energy_scale(-200.0, 20.0), w.gas_energy_min)
	assert_eq(w.gas_energy_scale(200.0, 20.0), w.gas_energy_max)
	assert_eq(w.temperature_at(16.0, false), 16.0)
	assert_eq(w.temperature_at(16.0, true), 16.0 - w.night_drop)
	# The players' rule of thumb: about 1 fps a °F on a 290 fps pistol.
	var fps_per_f := 290.0 * (sqrt(w.gas_energy_scale(20.0 + 5.0 / 9.0, 20.0)) - 1.0)
	assert_between(fps_per_f, 0.7, 1.3)


func test_only_a_kits_gas_replicas_follow_the_temperature_and_never_past_the_limit() -> void:
	var r := rules()
	var l := r.default_loadout("x")
	var kit := r.carried(l)
	assert_eq(kit.replicas[0].power, &"electric")
	assert_eq(kit.replicas[1].power, &"gas")
	var rifle := kit.replicas[0].muzzle_energy
	var pistol := kit.replicas[1].muzzle_energy
	assert_almost_eq(kit.energies[1], pistol, 1e-9)
	kit.set_temperature(tuning.weather, 8.0, 20.0)
	assert_eq(kit.replicas[0].muzzle_energy, rifle, "a battery doesn't mind the cold")
	assert_almost_eq(kit.replicas[1].muzzle_energy, pistol * (1.0 - 12.0 * 0.012), 1e-9)
	kit.set_temperature(tuning.weather, 8.0, 20.0)
	assert_almost_eq(kit.replicas[1].muzzle_energy, pistol * (1.0 - 12.0 * 0.012), 1e-9, "from the energy as built")
	kit.set_temperature(tuning.weather, 20.0, 20.0)
	assert_almost_eq(kit.replicas[1].muzzle_energy, pistol, 1e-9)
	kit.set_temperature(tuning.weather, 40.0, 20.0)
	assert_lte(kit.replicas[1].muzzle_energy, kit.limits[1] + 1e-9)
	kit.limits[1] = pistol
	kit.set_temperature(tuning.weather, 40.0, 20.0)
	assert_almost_eq(kit.replicas[1].muzzle_energy, pistol, 1e-9, "the site's chrono holds on a hot day")
	# The shared built-in replicas were never touched: a kit's are its own copies.
	assert_almost_eq(ReplicaStats.default_loadout()[1].muzzle_energy, pistol, 1e-9)


# --- The site limit and BB weights ---


func test_the_site_limit_is_read_with_the_bbs_loaded() -> void:
	var r := rules()
	var l := r.default_loadout("x")
	assert_true(r.equip(l, Loadout.Slot.SECONDARY, CYBER))
	var limit := r.stats.energy_limit(&"pistol")
	# As it comes (0.25 g) the Cyber Pistol leaves at its limit, the owner's ruling.
	var kit := r.carried(l)
	assert_almost_eq(Ballistics.muzzle_energy(kit.replicas[1], tuning.replica_rules, kit.bb_weights[1]), limit, 1e-9)
	assert_false(kit.capped[1])
	# Heavier BBs take more of the push; the chrono still reads no more than the limit.
	for grams: float in [0.3, 0.36, 0.4]:
		r.set_bb_weight(l, CYBER, grams)
		kit = r.carried(l)
		var out := Ballistics.muzzle_energy(kit.replicas[1], tuning.replica_rules, kit.bb_weights[1])
		assert_almost_eq(out, limit, 1e-9, "%s g leaves at the limit, not past it" % grams)
		assert_true(kit.capped[1])
	# A replica well under its limit keeps the whole of a heavy BB's bonus.
	r.set_bb_weight(l, AEG, 0.3)
	kit = r.carried(l)
	var base := ReplicaStats.default_loadout()[0]
	assert_almost_eq(Ballistics.muzzle_energy(kit.replicas[0], tuning.replica_rules, 0.3),
			base.muzzle_energy * pow(0.3 / base.bb_weight, tuning.replica_rules.bb_energy_exponent), 1e-9)


func test_bbs_load_up_to_0_40_g_and_a_hop_up_lifts_only_so_much() -> void:
	var r := rules()
	var l := r.default_loadout("x")
	assert_eq(tuning.replica_rules.bb_weight_max, 0.4)
	assert_eq(r.set_bb_weight(l, AEG, 5.0), 0.4)
	assert_almost_eq(r.set_bb_weight(l, AEG, 0.36), 0.36, 1e-6)
	# The pistol's hop-up can't hold a 0.40 g BB up: its best reach with one is well short of its best with a 0.25 g.
	var pistol := ReplicaStats.default_loadout()[1]
	assert_lt(_best_reach(pistol, 0.4), _best_reach(pistol, 0.25) - 5.0)


func _best_reach(replica: ReplicaConfig, grams: float) -> float:
	var best := 0.0
	for notch in 21:
		best = maxf(best, Ballistics.hop_up_reach(replica, notch * 0.05, tuning, DT, 0.15, 80.0, grams).on_target_to)
	return best


func test_a_lobbed_bb_lands_instead_of_vanishing() -> void:
	# The longest shot there is: the Sniper Rifle at its site limit with 0.40 g BBs (2.3 J, 107 m/s), lobbed. It is still
	# in the air long after 2.5 s.
	var cfg := tuning.ballistics
	var pool := BBPool.new(1)
	var up := deg_to_rad(24.0)
	var bb := pool.spawn(0, Vector3(0.0, 1.6, 0.0), Vector3(0.0, sin(up), -cos(up)), 107.0, 0.24, 0.4e-3,
			cfg.spin_per_hop)
	var nobody: Array[Character] = []
	var ticks := 0
	while bb.active and ticks < 1000:
		BBStep.step(pool, nobody, no_wall, tuning, 0.0, false, ends, events, DT)
		ticks += 1
	assert_false(bb.active)
	assert_lt(bb.position.y, 0.0, "it came down to the ground (kill_y), not out of time")
	assert_gt(bb.age, 2.5)
	assert_lt(bb.age, cfg.max_lifetime)
	assert_gt(-bb.position.z, 110.0)


# --- A moving body ---


func test_a_bb_meets_a_sprinter_where_it_was_when_the_bb_got_there() -> void:
	# The body stands 0.4 m ahead at the tick's end, having stepped 11 cm along +x during it. The BB reaches it in the
	# first quarter of the tick, when it had barely left where it started.
	var body_radius := tuning.hits.body_radius
	var behind := -(body_radius + 0.04) # inside the chest as it was then, outside it as it stands now
	var pool := BBPool.new(2)
	var bb := shot(pool, behind)
	var chars := roster(0.4, Vector3(STRIDE, 0.0, 0.0))
	assert_gt(absf(behind - chars[1].position.x), body_radius, "beside the body as it stands at the tick's end")
	fly(pool, chars)
	assert_eq(hit_target(), 2, "the BB struck the body where it was")
	assert_false(bb.active)
	assert_almost_eq(bb.position.x, behind, 1e-6, "stopped on its own line")
	assert_between(-bb.position.z, 0.0, 0.4)


func test_a_bb_passes_ahead_of_a_sprinter_that_was_not_there_yet() -> void:
	var body_radius := tuning.hits.body_radius
	var ahead := body_radius - 0.04 # inside the chest as it stands now, clear of it as it was then
	var pool := BBPool.new(2)
	var bb := shot(pool, ahead)
	var chars := roster(0.4, Vector3(STRIDE, 0.0, 0.0))
	assert_lt(absf(ahead - chars[1].position.x), body_radius, "inside the body as it stands at the tick's end")
	fly(pool, chars)
	assert_eq(hit_target(), -1, "it wasn't there yet when the BB went by")
	assert_true(bb.active)


func test_a_standing_body_and_a_moved_one_are_met_as_they_stand() -> void:
	var body_radius := tuning.hits.body_radius
	# Standing: exactly as before PH1.
	var pool := BBPool.new(2)
	shot(pool, body_radius - 0.01)
	fly(pool, roster(0.4, Vector3.ZERO))
	assert_eq(hit_target(), 2)
	events.clear()
	pool = BBPool.new(2)
	shot(pool, body_radius + 0.01)
	fly(pool, roster(0.4, Vector3.ZERO))
	assert_eq(hit_target(), -1)
	# Moved a stride or more in a tick (a respawn, the dead zone): no step to follow, the body is where it stands.
	events.clear()
	pool = BBPool.new(2)
	shot(pool, 0.0)
	fly(pool, roster(0.4, Vector3(tuning.hits.max_stride + 1.0, 0.0, 0.0)))
	assert_eq(hit_target(), 2)


func test_nearer_of_two_moving_bodies_is_the_one_hit() -> void:
	var pool := BBPool.new(2)
	shot(pool, 0.0)
	var chars := roster(0.9, Vector3(STRIDE, 0.0, 0.0))
	var near := Character.new(3, 1, Vector3(STRIDE, 0.0, -0.5), 0.0)
	near.prev_position = near.position
	near.position -= Vector3(STRIDE, 0.0, 0.0)
	chars.append(near)
	fly(pool, chars)
	assert_eq(hit_target(), 3)


# --- The maps' weather ---


func test_the_maps_table_says_each_fields_wind_and_air() -> void:
	var text := """## Maps
| Id | Name | Kind | Tag | Min | Standard | Max | Wind (×) | Air (°C) | Blurb |
|---|---|---|---|---|---|---|---|---|---|
| hall | Hall | field | public | 1 | 3 | 3 | 0 | 14 | Indoors. |
| moor | Moor | field | public | 1 | 3 | 3 | 1.5 | -4 | Open. |
| plain | Plain | field | public | 1 | 3 | 3 |  |  | As built in. |
| odd | Odd | field | public | 1 | 3 | 3 | gale | 99 | Unreadable. |
"""
	var m := MapCatalog.parse(text)
	assert_eq(m.find("hall").wind, 0.0)
	assert_eq(m.find("hall").air_or(20.0), 14.0)
	assert_eq(m.find("moor").wind, 1.5)
	assert_eq(m.find("moor").air_or(20.0), -4.0)
	assert_eq(m.find("plain").wind, 1.0)
	assert_eq(m.find("plain").air_or(20.0), 20.0)
	assert_eq(m.find("odd").wind, 1.0)
	assert_eq(m.find("odd").air_or(20.0), 20.0)
	assert_eq(m.problems.size(), 2, str(m.problems))
	# A table from before the columns reads as ever.
	var old := MapCatalog.parse("""## Maps
| Id | Name | Kind | Tag | Min | Standard | Max | Blurb |
|---|---|---|---|---|---|---|---|
| hall | Hall | field | public | 1 | 3 | 3 | Indoors. |
""")
	assert_eq(old.find("hall").wind, 1.0)
	assert_eq(old.find("hall").air_or(20.0), 20.0)
	assert_eq(old.problems, [] as Array[String])


func test_the_shipped_fields_indoors_have_still_air() -> void:
	var m := MapCatalog.read_file()
	assert_eq(m.problems, [] as Array[String])
	assert_eq(m.find("depot").wind, 0.0)
	assert_eq(m.find("subway").wind, 0.0)
	assert_gt(m.find("woodland").wind, 0.0)
	assert_gt(m.find("range").wind, 0.0)
	# Depot and the Range play in the air replicas are rated in: what the Loadout says is what they shoot.
	assert_eq(m.find("depot").air_or(20.0), tuning.ballistics.air_temperature)
	assert_eq(m.find("range").air_or(20.0), tuning.ballistics.air_temperature)
	assert_lt(m.find("woodland").air_or(20.0), 20.0)


func test_the_pause_menu_and_the_field_cards_say_the_weather() -> void:
	assert_eq(PauseMenu.weather_line(16.2, 1.24), "Air 16 °C · breeze 1.2 m/s")
	assert_eq(PauseMenu.weather_line(20.0, 0.0), "Air 20 °C · still air")
	var m := MapCatalog.read_file()
	assert_eq(MatchPage.field_tip(m.find("depot"), tuning),
			"An indoor airsoft hall: three lanes, two dark tunnels.\nStill air, 20 °C.")
	assert_string_ends_with(MatchPage.field_tip(m.find("woodland"), tuning), "\nOpen to the breeze, 16 °C by day.")
