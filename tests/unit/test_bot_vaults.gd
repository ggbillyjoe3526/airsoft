extends GutTest
## Bots vault (the browser game's ai/vaultBots.test.ts and map/vaultSpots.test.ts, M102): the nav grid links a low wall
## a body can vault and nothing taller or shorter (game/nav/nav_vaults.gd), a bot's route goes over it where that saves
## the walk round and a walk-off's never does, a vault is a leg of its own, and bots press Jump there as the player
## would. On Depot the hall wall is the one way over, each way, and no route on foot gets longer for it.

const DT := 1.0 / 60.0
const KILL_Y := -10.0

var tuning: SimTuning = SimTuning.load_default()
var config: BotConfig = BotConfig.load_default()


## A 40 by 26 m field split by a long wall of `height` from the south edge to 2.5 m short of the north one (the way
## round is up there), a shelter at each end, the ends at x -17 and 17. As map data and as the matching BoxWorld.
func _field(height: float) -> Array:
	var map := MapData.new()
	map.id = "vault field"
	map.kill_y = KILL_Y
	var w := BoxWorld.new(tuning.body)
	w.add_floor(40.0, 26.0)
	map.blocks.append(_block(&"floor", Vector3(0.0, -0.25, 0.0), Vector3(40.0, 0.5, 26.0)))
	for b: Array in [[Vector3(0.0, height * 0.5, -1.25), Vector3(0.4, height, 23.5)],
			[Vector3(-14.0, 1.5, -6.0), Vector3(0.4, 3.0, 6.0)], [Vector3(14.0, 1.5, -6.0), Vector3(0.4, 3.0, 6.0)]]:
		map.blocks.append(_block(&"wall", b[0], b[1]))
		w.add_box(b[0], b[1])
	for e in 2:
		var x := -17.0 if e == 0 else 17.0
		var end := MapEnd.new()
		for z: float in [-8.0, -6.0, -4.0]:
			end.spawns.append(SpawnPoint.new(Vector3(x, 0.0, z), -PI * 0.5 if e == 0 else PI * 0.5))
		for z: float in [9.0, 10.0, 11.0]:
			end.dead_zone.append(SpawnPoint.new(Vector3(-18.0 if e == 0 else 18.0, 0.0, z), 0.0))
		map.ends.append(end)
	map.lanes.append(PackedVector3Array([Vector3(-17.0, 0.0, -9.0), Vector3(-6.0, 0.0, -6.0), Vector3(6.0, 0.0, -6.0),
			Vector3(17.0, 0.0, -9.0)]))
	return [map, w]


static func _block(kind: StringName, center: Vector3, size: Vector3) -> MapData.Block:
	var b := MapData.Block.new()
	b.kind = kind
	b.center = center
	b.size = size
	return b


func _linked(map: MapData, query: WorldQuery) -> NavGrid:
	var nav := NavGrid.build(map, tuning.nav, tuning.body)
	NavVaults.link(nav, query, tuning.vault, tuning.body, config.vault_price)
	return nav


static func _length(from: Vector3, route: PackedVector3Array) -> float:
	var s := 0.0
	var a := from
	for b in route:
		s += Vector2(b.x - a.x, b.z - a.z).length()
		a = b
	return s


static func _vaults(nav: NavGrid, from: Vector3, route: PackedVector3Array) -> int:
	var n := 0
	var a := from
	for b in route:
		n += 1 if nav.is_vault_leg(a, b) else 0
		a = b
	return n


func test_links_a_low_wall_a_body_can_vault_and_nothing_taller_or_shorter() -> void:
	for pair: Array in [[0.85, true], [0.6, true], [1.2, false], [0.4, false]]:
		var f := _field(pair[0])
		var nav := _linked(f[0], f[1])
		assert_eq(nav.vault_to.size() > 0, pair[1], "%.2f m" % pair[0])
		assert_eq(NavVaults.link(nav, f[1], tuning.vault, tuning.body, config.vault_price), nav.vault_to.size(),
				"linked once per grid")


## The loading screen spreads the search over frames (PlaySession._prepare_bots): stopped at every clock look, it finds
## the very links one whole search does, with the same search points and routes.
func test_a_search_spread_over_calls_finds_the_same_links() -> void:
	var f := _field(0.85)
	var whole := _linked(f[0], f[1])
	var spread := NavGrid.build(f[0], tuning.nav, tuning.body)
	var finder := NavVaults.Finder.new()
	var calls := 1
	while not NavVaults.find(finder, spread, f[1], tuning.vault, tuning.body, 0):
		calls += 1
	assert_gt(calls, 2, "stopped along the way")
	assert_eq(NavVaults.finish(finder, spread, config.vault_price), whole.vault_to.size())
	assert_gt(whole.vault_to.size(), 0)
	assert_eq(spread.vault_start, whole.vault_start)
	assert_eq(spread.vault_to, whole.vault_to)
	assert_eq(spread.vault_region, whole.vault_region)
	assert_eq(spread.astar.get_point_count(), whole.astar.get_point_count())
	var a := PackedVector3Array()
	var b := PackedVector3Array()
	assert_true(whole.find_route(Vector3(6.0, 0.0, -6.0), Vector3(-6.0, 0.0, -6.0), a, true))
	assert_true(spread.find_route(Vector3(6.0, 0.0, -6.0), Vector3(-6.0, 0.0, -6.0), b, true))
	assert_eq(b, a)


func test_a_bots_route_goes_over_where_that_saves_the_walk_and_a_walk_off_never_does() -> void:
	var f := _field(0.85)
	var nav := _linked(f[0], f[1])
	var from := Vector3(6.0, 0.0, -6.0)
	var to := Vector3(-6.0, 0.0, -6.0)
	var on_foot := PackedVector3Array()
	var over := PackedVector3Array()
	assert_true(nav.find_route(from, to, on_foot))
	assert_true(nav.find_route(from, to, over, true))
	# Round the north end on foot (about 40 m), straight over with a vault (12 m).
	assert_gt(_length(from, on_foot), 30.0)
	assert_eq(_vaults(nav, from, on_foot), 0, "a walk-off goes on foot")
	assert_lt(_length(from, over), 15.0)
	assert_eq(_vaults(nav, from, over), 1)
	# The vault is a leg of its own: from a waypoint before the wall to one past it, square across it.
	var a := from
	for b in over:
		if nav.is_vault_leg(a, b):
			assert_gt(a.x, 0.2)
			assert_lt(b.x, -0.2)
			assert_almost_eq(a.z, b.z, 1e-4, "straight across")
		a = b
	# Near the wall's end, going round is shorter than a vault's price: no vault.
	var north := Vector3(1.5, 0.0, 9.8)
	var round := PackedVector3Array()
	assert_true(nav.find_route(north, Vector3(-1.5, 0.0, 9.8), round, true))
	assert_eq(_vaults(nav, north, round), 0)
	var went_round := false
	for p in round:
		assert_true(p.z > 10.5 or absf(p.x) > 0.5, "never on the wall: %s" % p)
		went_round = went_round or p.z > 10.5
	assert_true(went_round)


func test_a_low_wall_across_the_whole_field_parts_it_on_foot_and_vault_links_join_it() -> void:
	var f := _field(0.85)
	var map: MapData = f[0]
	var w: BoxWorld = f[1]
	# Close the gap at the wall's north end with more of the same wall.
	map.blocks.append(_block(&"wall", Vector3(0.0, 0.425, 11.75), Vector3(0.4, 0.85, 2.5)))
	w.add_box(Vector3(0.0, 0.425, 11.75), Vector3(0.4, 0.85, 2.5))
	var nav := _linked(map, w)
	var east := nav.node_at(Vector3(6.0, 0.0, -6.0))
	var west := nav.node_at(Vector3(-6.0, 0.0, -6.0))
	assert_false(nav.linked(east, west), "two regions on foot")
	assert_true(nav.linked(east, west, true), "one with the vault links")
	var route := PackedVector3Array()
	assert_false(nav.find_route(Vector3(6.0, 0.0, -6.0), Vector3(-6.0, 0.0, -6.0), route), "no walk-off across")
	assert_true(nav.find_route(Vector3(6.0, 0.0, -6.0), Vector3(-6.0, 0.0, -6.0), route, true), "a bot vaults it")
	assert_eq(_vaults(nav, Vector3(6.0, 0.0, -6.0), route), 1)


func test_a_route_starting_at_the_wall_begins_on_the_takeoff() -> void:
	var f := _field(0.85)
	var nav := _linked(f[0], f[1])
	var from := Vector3(0.75, 0.0, -6.13)
	var route := PackedVector3Array()
	assert_true(nav.find_route(from, Vector3(-6.0, 0.0, -6.0), route, true))
	assert_eq(_vaults(nav, from, route), 1)
	assert_true(nav.is_vault_leg(route[0], route[1]), "to the takeoff, then over")


func test_bots_go_over_a_low_wall_on_their_way_and_never_over_crouch_cover() -> void:
	var low := _play(0.85)
	gut.p("vault field: %d vaults, %d rounds" % [low[0], low[1]])
	assert_gt(low[0], 0, "bots vaulted the low wall")
	assert_eq(low[2], 0, "nobody left standing on the wall or fell off")
	var cover := _play(1.2)
	assert_eq(cover[0], 0, "crouch cover is never vaulted")


## Two rounds of bots on the field: [vaults, rounds, ticks anyone stood on or under the wall's line].
func _play(height: float) -> Array:
	var f := _field(height)
	var map: MapData = f[0]
	var w: BoxWorld = f[1]
	var nav := NavGrid.build(map, tuning.nav, tuning.body)
	var sim := Simulation.new(tuning, w, w.mover(), map.ends, KILL_Y)
	sim.nav = nav
	var state := GameState.new(14, tuning)
	var loadout := ReplicaStats.default_loadout()
	var commands: Array[PlayerCommand] = []
	for i in tuning.rounds.team_size * 2:
		state.characters.append(Character.new(i, 0 if i < tuning.rounds.team_size else 1, Vector3.ZERO, 0.0, loadout))
		commands.append(PlayerCommand.new())
	var bots := BotController.new(state, -1, map, nav, w, tuning, config)
	sim.start_match(state)
	bots.observe(state)
	var vaults := 0
	var rounds := 0
	var bad := 0
	for t in roundi(tuning.rounds.round_time / DT) * 2:
		bots.think(state, commands, DT)
		sim.step(state, commands, DT)
		bots.observe(state)
		vaults += state.events.count_of(GameEvent.Kind.VAULT)
		rounds += state.events.count_of(GameEvent.Kind.ROUND_OVER)
		for c in state.characters:
			var on_wall := absf(c.position.x) < 0.2 and c.position.z < 10.5 and not c.vault.active
			if c.position.y < KILL_Y + 1.0 or (on_wall and c.grounded):
				bad += 1
		if rounds >= 2:
			break
	return [vaults, rounds, bad]


func test_depots_hall_wall_is_the_one_way_over_each_way() -> void:
	var map := YardMap.load_map(MapStyle.new(), tuning.rounds.team_size)
	var level := MapLevel.new()
	add_child(level)
	level.build(map, MapStyle.new(), tuning.body)
	var nav := _linked(map, level.query())
	var north := 0
	var south := 0
	for k in nav.node_count():
		for l in range(nav.vault_start[k], nav.vault_start[k + 1]):
			var a := nav.node_position(k)
			var b := nav.node_position(nav.vault_to[l])
			# The hall's south wall, at z 7.2 to 7.4, between x -0.8 and 9.
			assert_true(a.x > -0.8 and a.x < 9.0 and minf(a.z, b.z) < 7.2 and maxf(a.z, b.z) > 7.4,
					"%s -> %s" % [a, b])
			north += 1 if b.z > a.z else 0
			south += 1 if b.z < a.z else 0
	assert_gt(north, 0)
	assert_gt(south, 0)
	# Over it into the hall is much shorter than round by its door.
	var from := Vector3(1.2, 0.0, 5.5)
	var to := Vector3(1.2, 0.0, 9.5)
	var on_foot := PackedVector3Array()
	var over := PackedVector3Array()
	assert_true(nav.find_route(from, to, on_foot))
	assert_true(nav.find_route(from, to, over, true))
	assert_eq(_vaults(nav, from, over), 1)
	assert_gt(_length(from, on_foot) - _length(from, over), config.vault_price * 2.0)
	# No route gets longer on the ground for the links: spawn to spawn, spawn to dead zone, and a sweep. A route takes
	# a link where the search's cells (a staircase on a slant) price the walk round more than its price over; walked
	# straight, that walk is at least half the price longer.
	var pairs: Array[PackedVector3Array] = []
	for e in 2:
		for s in map.ends[e].spawns:
			for t in map.ends[1 - e].spawns:
				pairs.append(PackedVector3Array([s.position, t.position]))
			for t in map.ends[1 - e].dead_zone:
				pairs.append(PackedVector3Array([s.position, t.position]))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 300:
		pairs.append(PackedVector3Array([Vector3(rng.randf_range(-24.0, 24.0), 0.0, rng.randf_range(-15.0, 15.0)),
				Vector3(rng.randf_range(-24.0, 24.0), 0.0, rng.randf_range(-15.0, 15.0))]))
	var vaulted := 0
	for p in pairs:
		if not nav.is_walkable_at(p[0]) or not nav.is_walkable_at(p[1]):
			continue
		if not nav.find_route(p[0], p[1], on_foot) or not nav.find_route(p[0], p[1], over, true):
			continue
		var walk := _length(p[0], on_foot)
		var v := _vaults(nav, p[0], over)
		if v == 0:
			assert_almost_eq(_length(p[0], over), walk, 1e-4, "%s -> %s: unchanged" % [p[0], p[1]])
			continue
		vaulted += 1
		assert_lt(_length(p[0], over) + v * config.vault_price * 0.5, walk, "%s -> %s" % [p[0], p[1]])
	assert_gt(vaulted, 0)
	level.free()


func test_every_map_links_and_no_route_over_links_is_longer_than_on_foot_or_lands_off_grid() -> void:
	for id: String in ["depot", "range", "woodland"]:
		var map := MapData.load_map(id, MapStyle.new(), tuning.rounds.team_size)
		var level := MapLevel.new()
		add_child(level)
		level.build(map, MapStyle.new(), tuning.body)
		var nav := _linked(map, level.query())
		var again := _linked(map, level.query())
		assert_eq(nav.vault_to, again.vault_to, "%s: links are deterministic" % id)
		for l in nav.vault_to.size():
			assert_eq(nav.walkable[nav.vault_to[l]], 1, "%s: a link lands on a walkable node" % id)
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		var on_foot := PackedVector3Array()
		var over := PackedVector3Array()
		var bad := 0
		var vaulted := 0
		for i in 120:
			var p := Vector3(rng.randf_range(-20.0, 20.0), 0.0, rng.randf_range(-12.0, 12.0))
			var q := Vector3(rng.randf_range(-20.0, 20.0), 0.0, rng.randf_range(-12.0, 12.0))
			if not nav.is_walkable_at(p) or not nav.is_walkable_at(q):
				continue
			var a := nav.find_route(p, q, on_foot)
			var b := nav.find_route(p, q, over, true)
			assert_eq(a, b, "%s: a route exists either way" % id)
			if not a or not b:
				continue
			vaulted += _vaults(nav, p, over)
			if _length(p, over) > _length(p, on_foot) + 0.5:
				bad += 1
		gut.p("%s: %d links, %d vault legs in the sweep" % [id, nav.vault_to.size(), vaulted])
		assert_eq(bad, 0, "%s: routes over links never longer" % id)
		level.free()


func test_a_bot_held_up_on_a_vault_leg_routes_round_for_a_while_and_a_new_round_forgives_it() -> void:
	var f := _field(0.85)
	var map: MapData = f[0]
	var w: BoxWorld = f[1]
	var nav := NavGrid.build(map, tuning.nav, tuning.body)
	var state := GameState.new(14, tuning)
	var loadout := ReplicaStats.default_loadout()
	for i in 2:
		state.characters.append(Character.new(i, i, Vector3.ZERO, 0.0, loadout))
	var bots := BotController.new(state, -1, map, nav, w, tuning, config)
	var bot: Bot = bots.world.bots[0]
	var from := Vector3(6.0, 0.0, -6.0)
	var route := PackedVector3Array()
	assert_true(nav.find_route(from, Vector3(-6.0, 0.0, -6.0), route, true))
	var a := from
	var takeoff := Vector3.ZERO
	for b in route:
		if nav.is_vault_leg(a, b):
			takeoff = a
		a = b
	assert_ne(takeoff, Vector3.ZERO)
	bot.character.position = takeoff
	bot.character.velocity = Vector3.ZERO
	bot.route = route
	bot.route_from = takeoff
	bot.route_leg = route.find(route[route.find(takeoff) + 1]) if route.has(takeoff) else 0
	bot.route_state = Bot.RouteState.OK
	bots.world.time = 10.0
	for i in 90:
		BotRoutes.follow(bot, bots.world, DT)
	assert_eq(bot.route_state, Bot.RouteState.WANTED, "held up: asks for a new route")
	assert_almost_eq(bot.vaults_off_until, 10.0 + config.vault_retry_delay, 1e-6)
	bot.reset(0, 3, 0.0, config)
	assert_eq(bot.vaults_off_until, -INF, "a new round forgives it")


## PP1: each link's search point is priced at its own take-off node's weight (a wade's x8, WS1), never at the first
## node's: with the field's first node made dear, the wall's links keep their own nodes' weights.
func test_each_vault_link_is_priced_at_its_take_off_node_s_weight() -> void:
	var f := _field(0.85)
	var nav := NavGrid.build(f[0], tuning.nav, tuning.body)
	var first := -1
	for k in nav.node_count():
		if nav.walkable[k] == 1:
			first = k
			break
	assert_gt(first, -1)
	nav.astar.set_point_weight_scale(first, nav.astar.get_point_weight_scale(first) * 8.0)
	NavVaults.link(nav, f[1], tuning.vault, tuning.body, config.vault_price)
	assert_gt(nav.vault_to.size(), 0)
	var wrong := 0
	for k in nav.node_count():
		for l in range(nav.vault_start[k], nav.vault_start[k + 1]):
			var half := maxf(nav.node_position(k).distance_to(nav.node_position(nav.vault_to[l])), nav.cell) * 0.5
			var want := nav.astar.get_point_weight_scale(k) * (half + config.vault_price) / half
			if absf(nav.astar.get_point_weight_scale(nav.vault_base + l) - want) > 1e-4 * want:
				wrong += 1
	assert_eq(wrong, 0, "every link at its take-off node's weight")
