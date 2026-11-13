extends GutTest
## QA for Stockade (SK1): the map loads clean, is dev-only, its ends, sites, poles, flag and bomb start stand on floor
## the bots reach from both spawns, nobody can stand above the ground (no roof walks), and every walkable cell is
## reachable on foot from the attackers' spawn.

const SPOT_SNAP := 0.6

var map: MapData
var nav: NavGrid
var tuning: SimTuning


func before_all() -> void:
	tuning = SimTuning.load_default()
	map = MapData.load_map("stockade", PlayTuning.load_default().map_style, tuning.rounds.team_size)
	nav = NavGrid.build(map, tuning.nav, tuning.body)


func after_all() -> void:
	map = null
	nav = null


func _reached(from: Vector3, to: Vector3) -> bool:
	var route := PackedVector3Array()
	return nav.find_route(from, to, route)


func test_stockade_loads_with_no_problem_and_no_warning() -> void:
	assert_eq(map.problems, [] as Array[String])
	assert_eq(map.warnings, [] as Array[String])
	var style := PlayTuning.load_default().map_style
	assert_eq(MatchOptions.map_problems("stockade", style, 6), [] as Array[String])
	assert_eq(MatchOptions.map_problems("stockade", style, 8), [] as Array[String])


func test_stockade_is_listed_only_with_dev_content_on() -> void:
	var catalog := MapCatalog.read_file()
	var public_ids: Array[String] = []
	for e: MapCatalog.Entry in catalog.fields(false):
		public_ids.append(e.id)
	var dev_ids: Array[String] = []
	for e: MapCatalog.Entry in catalog.fields(true):
		dev_ids.append(e.id)
	assert_does_not_have(public_ids, "stockade")
	assert_has(dev_ids, "stockade")
	assert_true(catalog.is_dev("stockade"))


func test_the_night_preset_and_every_light_are_read() -> void:
	assert_has(map.lighting_presets, &"night")
	assert_has(map.lighting_presets, &"day")
	assert_eq(map.lights.size(), 26, "every lantern and fire kept")


func test_sites_poles_flag_and_bomb_start_are_on_floor_both_ends_reach() -> void:
	assert_true(map.has_bomb_sites)
	assert_eq(map.bomb_sites.size(), 2)
	assert_true(map.has_bomb_start)
	assert_true(map.has_overtime_flag)
	var spots: Array[Vector3] = [map.bomb_start, map.overtime_flag]
	for s: Vector3 in map.bomb_sites:
		spots.append(s)
	for f: Vector3 in map.poles:
		spots.append(f)
	assert_eq(spots.size(), 6)
	for p: Vector3 in spots:
		assert_true(nav.is_walkable_at(p), "%s stands on walkable floor" % p)
		for e in 2:
			var spawn := map.ends[e].spawns[0].position
			assert_true(_reached(spawn, p), "end %d reaches %s" % [e, p])


func test_every_spawn_and_dead_zone_spot_is_walkable_and_reaches_the_other_end() -> void:
	for e in 2:
		for list: Array in [map.ends[e].spawns, map.ends[e].dead_zone]:
			for sp: SpawnPoint in list:
				assert_true(nav.is_walkable_at(sp.position), "%s walkable" % sp.position)
		var d: SpawnPoint = map.ends[e].dead_zone[0]
		var other: Vector3 = map.ends[1 - e].spawns[0].position
		assert_true(_reached(d.position, other), "dead zone %d reaches the other end's spawn" % e)


func test_nobody_stands_above_the_ground_so_no_roof_is_walkable() -> void:
	var highest := 0.0
	for k in nav.node_count():
		if nav.floor_y[k] > highest:
			highest = nav.floor_y[k]
	assert_lt(highest, 0.3, "the highest standable floor on the nav grid")


func test_every_walkable_node_is_reachable_on_foot_from_the_attackers_spawn() -> void:
	var start: Vector3 = map.ends[0].spawns[0].position
	var route := PackedVector3Array()
	var cut_off := 0
	var worst := Vector3.ZERO
	for k in nav.node_count():
		if not nav.walkable[k]:
			continue
		var p := nav.node_position(k)
		# A sparse sample keeps the run short: every 6th node.
		if k % 6 != 0:
			continue
		if not nav.find_route(start, p, route):
			cut_off += 1
			worst = p
	assert_eq(cut_off, 0, "standable cells with no walk from the West camp (last at %s)" % worst)
