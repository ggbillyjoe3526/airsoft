extends GutTest
## Bots climb (CL1, owner 2026-11-10: out of Subway's track pits, whose steps went): the nav grid links the foot of a
## ledge a body can climb to its top, one way up, with a drop link back down, and nothing on a ledge too high or a
## top too shallow; bots climb out of a pit and drop into it on their way. On Subway every track pit is joined to
## its platform by climbs and drops only, and the other maps have no climb at all.

const DT := 1.0 / 60.0
const KILL_Y := -10.0
## A link rising or falling more than this is a climb or a drop (a vault lands at most VaultConfig max_climb higher,
## on a slope a cell or so more; a climb rises at least min_height).
const STEP := 0.5

var tuning: SimTuning = SimTuning.load_default()
var config: BotConfig = BotConfig.load_default()


## A 40 by 26 m field: the west half a pit, the east half a platform `height` over it (its edge along x = 0), a shelter
## at each end, the ends at x -17 (in the pit) and 17 (on the platform). As map data and as the matching BoxWorld.
func _field(height: float) -> Array:
	var map := MapData.new()
	map.id = "climb field"
	map.kill_y = KILL_Y
	var w := BoxWorld.new(tuning.body)
	w.add_floor(40.0, 26.0)
	map.blocks.append(_block(&"floor", Vector3(0.0, -0.25, 0.0), Vector3(40.0, 0.5, 26.0)))
	var top := Vector3(10.0, height * 0.5, 0.0)
	map.blocks.append(_block(&"floor", top, Vector3(20.0, height, 26.0)))
	w.add_box(top, Vector3(20.0, height, 26.0))
	for b: Array in [[Vector3(-14.0, 1.5, -6.0), Vector3(0.4, 3.0, 6.0)],
			[Vector3(14.0, height + 1.5, -6.0), Vector3(0.4, 3.0, 6.0)]]:
		map.blocks.append(_block(&"wall", b[0], b[1]))
		w.add_box(b[0], b[1])
	for e in 2:
		var x := -17.0 if e == 0 else 17.0
		var y := 0.0 if e == 0 else height
		var end := MapEnd.new()
		for z: float in [-8.0, -6.0, -4.0]:
			end.spawns.append(SpawnPoint.new(Vector3(x, y, z), -PI * 0.5 if e == 0 else PI * 0.5))
		for z: float in [9.0, 10.0, 11.0]:
			end.dead_zone.append(SpawnPoint.new(Vector3(-18.0 if e == 0 else 18.0, y, z), 0.0))
		map.ends.append(end)
	map.lanes.append(PackedVector3Array([Vector3(-17.0, 0.0, -9.0), Vector3(-6.0, 0.0, -6.0),
			Vector3(6.0, height, -6.0), Vector3(17.0, height, -9.0)]))
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


## The links' count up (a climb), down (a drop) and level (a vault).
static func _links(nav: NavGrid) -> Vector3i:
	var n := Vector3i.ZERO
	for k in nav.node_count():
		for l in range(nav.vault_start[k], nav.vault_start[k + 1]):
			var dy := nav.node_position(nav.vault_to[l]).y - nav.node_position(k).y
			if dy > STEP:
				n.x += 1
			elif dy < -STEP:
				n.y += 1
			else:
				n.z += 1
	return n


static func _legs(nav: NavGrid, from: Vector3, route: PackedVector3Array) -> int:
	var n := 0
	var a := from
	for b in route:
		n += 1 if nav.is_vault_leg(a, b) else 0
		a = b
	return n


func test_links_a_ledge_a_body_can_climb_up_with_a_drop_back_down_and_nothing_taller() -> void:
	for pair: Array in [[0.9, true], [0.6, true], [1.1, false], [0.45, false]]:
		var f := _field(pair[0])
		var nav := _linked(f[0], f[1])
		var n := _links(nav)
		assert_eq(n.x > 0, pair[1], "%.2f m: climbs" % pair[0])
		assert_eq(n.y, n.x, "%.2f m: a drop for every climb" % pair[0])
		assert_eq(n.z, 0, "%.2f m: nothing to vault" % pair[0])


func test_a_route_climbs_out_of_the_pit_and_drops_into_it_and_never_on_foot() -> void:
	var f := _field(0.9)
	var nav := _linked(f[0], f[1])
	var pit := Vector3(-6.0, 0.0, -6.0)
	var top := Vector3(6.0, 0.9, -6.0)
	var route := PackedVector3Array()
	assert_false(nav.find_route(pit, top, route), "no way up on foot")
	assert_false(nav.find_route(top, pit, route), "nor down")
	assert_true(nav.find_route(pit, top, route, true))
	assert_eq(_legs(nav, pit, route), 1, "one climb")
	assert_lt(route[route.size() - 1].distance_to(top), 0.5)
	assert_true(nav.find_route(top, pit, route, true))
	assert_eq(_legs(nav, top, route), 1, "one drop")
	assert_lt(route[route.size() - 1].distance_to(pit), 0.5)


func test_links_are_the_same_spread_over_calls() -> void:
	var f := _field(0.9)
	var whole := _linked(f[0], f[1])
	var spread := NavGrid.build(f[0], tuning.nav, tuning.body)
	var finder := NavVaults.Finder.new()
	while not NavVaults.find(finder, spread, f[1], tuning.vault, tuning.body, 0):
		pass
	NavVaults.finish(finder, spread, config.vault_price)
	assert_eq(spread.vault_start, whole.vault_start)
	assert_eq(spread.vault_to, whole.vault_to)


func test_bots_climb_out_of_the_pit_and_drop_into_it_on_their_way() -> void:
	var f := _field(0.9)
	var map: MapData = f[0]
	var w: BoxWorld = f[1]
	var nav := NavGrid.build(map, tuning.nav, tuning.body)
	var sim := Simulation.new(tuning, w, w.mover(), map.ends, KILL_Y)
	sim.nav = nav
	var state := GameState.new(21, tuning)
	var loadout := ReplicaStats.default_loadout()
	var commands: Array[PlayerCommand] = []
	for i in tuning.rounds.team_size * 2:
		state.characters.append(Character.new(i, 0 if i < tuning.rounds.team_size else 1, Vector3.ZERO, 0.0, loadout))
		commands.append(PlayerCommand.new())
	var bots := BotController.new(state, -1, map, nav, w, tuning, config)
	sim.start_match(state)
	bots.observe(state)
	var climbs := 0
	var drops := 0
	var rounds := 0
	var fell := 0
	var was_high: Array[bool] = []
	for c in state.characters:
		was_high.append(c.position.y > 0.45)
	for t in roundi(tuning.rounds.round_time / DT) * 2:
		bots.think(state, commands, DT)
		sim.step(state, commands, DT)
		bots.observe(state)
		for e in state.events.count:
			var ev := state.events.items[e]
			if ev.kind == GameEvent.Kind.VAULT and state.characters[ev.actor].vault.climb:
				climbs += 1
		rounds += state.events.count_of(GameEvent.Kind.ROUND_OVER)
		for i in state.characters.size():
			var c := state.characters[i]
			if c.position.y < KILL_Y + 1.0:
				fell += 1
			if not c.grounded:
				continue
			var high := c.position.y > 0.45
			if was_high[i] and not high and c.position.x < -0.3:
				drops += 1
			was_high[i] = high
		if rounds >= 2:
			break
	gut.p("climb field: %d climbs, %d drops, %d rounds" % [climbs, drops, rounds])
	assert_gt(climbs, 0, "bots climbed out of the pit")
	assert_gt(drops, 0, "bots dropped into it")
	assert_eq(fell, 0)


func test_subway_pits_join_their_platforms_by_climbs_and_drops_and_no_other_map_climbs() -> void:
	for id: String in ["depot", "range", "woodland", "subway"]:
		var map := MapData.load_map(id, MapStyle.new(), tuning.rounds.team_size)
		var level := MapLevel.new()
		add_child(level)
		level.build(map, MapStyle.new(), tuning.body)
		var nav := _linked(map, level.query())
		var n := _links(nav)
		if id != "subway":
			assert_eq(n.x, 0, "%s: no ledge to climb" % id)
			assert_eq(n.y, 0, "%s: so no drop" % id)
			level.free()
			continue
		assert_gt(n.x, 100, "subway: climbs all along the pits")
		assert_eq(n.y, n.x)
		var route := PackedVector3Array()
		# The south track's trench, the north track's west pit and its east stretch, each to and from its platform.
		for pair: Array in [[Vector3(-10.0, 0.0, 11.0), Vector3(-10.0, 0.9, 7.0)],
				[Vector3(-48.0, 0.0, -11.0), Vector3(-48.0, 0.9, -7.0)],
				[Vector3(26.0, 0.0, -11.0), Vector3(26.0, 0.9, -7.0)]]:
			assert_true(nav.find_route(pair[0], pair[1], route, true), "%s up" % pair[0])
			assert_eq(_legs(nav, pair[0], route), 1, "%s: one climb" % pair[0])
			assert_true(nav.find_route(pair[1], pair[0], route, true), "%s down" % pair[0])
		# The trench and the north track's west pit have no way out on foot now their steps are gone.
		assert_false(nav.find_route(Vector3(-10.0, 0.0, 11.0), Vector3(-10.0, 0.9, 7.0), route))
		assert_false(nav.find_route(Vector3(-48.0, 0.0, -11.0), Vector3(-48.0, 0.9, -7.0), route))
		level.free()
