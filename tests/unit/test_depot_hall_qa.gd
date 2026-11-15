extends GutTest
## QA for DR1 (Depot as the indoor hall): every start, dead-zone spot and flag stands on the nav grid, every lane point is
## within a metre of it, both ends reach all of them; no block pokes through the roof; no spot lets a BB out through the ceiling;
## the windows and container ports can be seen through standing and are not vaulted.

const SIDE := 6

var tuning: SimTuning = SimTuning.new()
var style: MapStyle = MapStyle.new()
var map: MapData = null
var nav: NavGrid = null
var level: MapLevel = null


func before_all() -> void:
	map = MapData.load_map("depot", style, SIDE)
	nav = NavGrid.build(map, tuning.nav, tuning.body)
	level = MapLevel.new()
	add_child(level)
	level.build(map, style, tuning.body)


func after_all() -> void:
	level.free()
	level = null


func test_every_start_dead_zone_lane_point_and_flag_is_on_the_nav_grid() -> void:
	var bad := PackedStringArray()
	for e in 2:
		for s in map.ends[e].spawns:
			if not nav.is_walkable_at(s.position):
				bad.append("spawn %s" % s.position)
		for d in map.ends[e].dead_zone:
			if not nav.is_walkable_at(d.position):
				bad.append("dead zone %s" % d.position)
	for lane in map.lanes:
		for p in lane:
			# A lane point a body's width off a block is snapped by the router; none may be further than a metre.
			if nav.nearest_walkable(p, 1.0) < 0:
				bad.append("lane %s" % p)
	for p: Vector3 in [map.pole, map.overtime_flag]:
		if not nav.is_walkable_at(p):
			bad.append("flag %s" % p)
	assert_eq(bad.size(), 0, "off the grid: %s" % [bad])


func test_both_ends_reach_every_lane_point_flag_and_the_other_ends_rooms() -> void:
	var route := PackedVector3Array()
	var lost := PackedStringArray()
	for e in 2:
		var from := map.ends[e].spawns[0].position
		var goals: Array[Vector3] = [map.pole, map.overtime_flag, map.ends[1 - e].spawns[0].position,
				map.ends[1 - e].dead_zone[0].position, map.ends[e].dead_zone[0].position]
		for lane in map.lanes:
			goals.append_array(lane)
		for g in goals:
			for vaults: bool in [false, true]:
				route.clear()
				if not nav.find_route(from, g, route, vaults):
					lost.append("end %d to %s (vaults %s)" % [e, g, vaults])
	assert_eq(lost.size(), 0, "unreachable: %s" % [lost.slice(0, 6)])


func test_no_block_pokes_through_the_roof_and_every_spawn_is_under_it() -> void:
	for b in map.blocks:
		assert_lte(b.center.y + b.size.y * 0.5, map.roof_height + 1e-3, "block %s at %s" % [b.kind, b.center])
	var q := level.query()
	var hit := RayHit.new()
	var out := PackedStringArray()
	for x in range(-55, 56, 3):
		for z in range(-36, 37, 3):
			var p := Vector3(x, 1.5, z)
			if nav.is_walkable_at(Vector3(x, 0, z)) and not q.ray(p, p + Vector3.UP * 30.0, hit):
				out.append(str(p))
	assert_eq(out.size(), 0, "a BB fired straight up leaves the hall from %s" % [out.slice(0, 5)])


func test_windows_and_container_ports_are_seen_through_standing_and_not_vaulted() -> void:
	var q := level.query()
	var hit := RayHit.new()
	var out := VaultState.new()
	var tried := 0
	var vaulted := PackedStringArray()
	for low in map.blocks:
		var low_lo := low.center - low.size * 0.5
		if low_lo.y > 0.01 or low.rise != MapData.Rise.NONE:
			continue
		for high in map.blocks:
			var high_lo := high.center - high.size * 0.5
			var low_top := low_lo.y + low.size.y
			if high == low or high_lo.y <= low_top + 0.01 or high.kind != low.kind:
				continue
			if not (is_equal_approx(high.center.x, low.center.x) and is_equal_approx(high.center.z, low.center.z)
					and is_equal_approx(high.size.x, low.size.x) and is_equal_approx(high.size.z, low.size.z)):
				continue
			tried += 1
			var thin_x := low.size.x < low.size.z
			var through := Vector3.RIGHT if thin_x else Vector3.BACK
			var half_thick := (low.size.x if thin_x else low.size.z) * 0.5
			for side: float in [1.0, -1.0]:
				var feet := Vector3(low.center.x, 0.0, low.center.z) + through * side * (half_thick + tuning.body.radius + 0.05)
				feet.y = tuning.body.rest_gap
				var way := -through * side
				if Vault.plan(feet, Vector2(way.x, way.z), tuning.vault.max_speed, tuning.vault, tuning.body, q, out):
					vaulted.append("%s from %s" % [low.kind, feet])
	assert_gt(tried, 0, "the hall has ports")
	assert_eq(vaulted.size(), 0, "ports vaulted: %s" % [vaulted.slice(0, 5)])


## DR1 QA, second pass: the spawn rooms' chicanes (0821da4, 46230ea) and the hall's finishes.

func test_every_spawn_walks_out_through_its_chicane_to_the_floor_without_a_vault() -> void:
	var lost := PackedStringArray()
	var long_way := PackedStringArray()
	var route := PackedVector3Array()
	# Out of Staging by each stairs mouth and its mouth into Upper mid (DC1: the room 10 m east, where the Mid exit
	# was); out of the Loading bay by the A stairs, the ramp and the Garage.
	var outside: Array = [
		[Vector3(-39.0, 0, -17.0), Vector3(-38.5, 0, 10.0), Vector3(-30.0, 0, -2.0)],
		[Vector3(49.0, 0, -12.0), Vector3(49.0, 0, 15.0), Vector3(40.0, 0, 4.0)],
	]
	for e in 2:
		for s in map.ends[e].spawns:
			for g: Vector3 in outside[e]:
				route.clear()
				if not nav.find_route(s.position, g, route, false):
					lost.append("end %d spawn %s to %s" % [e, s.position, g])
					continue
				var length := 0.0
				var at := s.position
				for p in route:
					length += Vector2(p.x - at.x, p.z - at.z).length()
					at = p
				# A chicane costs a few metres, not a lap of the hall.
				if length > Vector2(g.x - s.position.x, g.z - s.position.z).length() * 1.8 + 8.0:
					long_way.append("end %d spawn %s to %s: %.1f m" % [e, s.position, g, length])
			for d in map.ends[e].dead_zone:
				route.clear()
				if not nav.find_route(s.position, d.position, route, false):
					lost.append("end %d spawn %s to its dead zone %s" % [e, s.position, d.position])
	assert_eq(lost.size(), 0, "no way out: %s" % [lost.slice(0, 5)])
	assert_eq(long_way.size(), 0, "a long way round: %s" % [long_way.slice(0, 5)])


func test_the_middle_of_every_chicane_gap_is_open_to_the_nav_grid() -> void:
	var shut := PackedStringArray()
	# The middle of each outer screen's gap (the stairs' two, the A stairs' and the ramp's), of each inner screen's gap
	# and of each corridor between screens (the chicanes as widened on attempt 3).
	# The west's 10 m east of the concept's since DC1's compact hall.
	for p: Vector3 in [Vector3(-41.0, 0, -13.0), Vector3(-41.0, 0, 5.0), Vector3(51.75, 0, -4.5),
			Vector3(51.75, 0, 13.5), Vector3(-37.7, 0, -9.0), Vector3(-37.7, 0, 1.0), Vector3(47.7, 0, -0.5),
			Vector3(47.7, 0, 9.5), Vector3(-39.5, 0, -11.0), Vector3(-39.5, 0, 3.0), Vector3(49.5, 0, -2.5),
			Vector3(49.5, 0, 11.5)]:
		if not nav.is_walkable_at(p):
			shut.append(str(p))
	assert_eq(shut.size(), 0, "a chicane gap shut to the nav grid: %s" % [shut])


func test_every_block_kind_of_the_hall_has_its_own_site_finish() -> void:
	var look := PlayTuning.new().site_look
	var plain := PackedStringArray()
	for b in map.blocks:
		var finish := look.finish_of(b)
		if finish == &"default" or not look.canvases.has(finish) or not look.paints.has(finish):
			plain.append("%s -> %s" % [b.kind, finish])
	assert_eq(plain.size(), 0, "drawn in the grey default: %s" % [plain.slice(0, 5)])
	assert_lte(look.finish_names().size(), SiteSurface.SLOTS, "the shader has a slot for each finish")
	var material := SiteSurface.material(look, map)
	for param: StringName in [&"modes", &"paints", &"accents", &"bands", &"pbr"]:
		var values: Variant = material.get_shader_parameter(param)
		assert_eq(values.size(), look.finish_names().size(), "%s" % param)


## DR1 QA, third pass: the overtime flankers' side point (bot_movement.gd _overtime_flank_point) from every side of the flag.

func test_the_overtime_flank_point_from_every_side_is_on_the_flags_floor_and_reachable_without_crossing_a_wall() -> void:
	var cfg := BotConfig.load_default()
	var spot := map.overtime_flag
	var world := BotWorld.new()
	world.cfg = cfg
	world.tuning = tuning
	world.nav = nav
	world.query = level.query()
	var body := Character.new(0, 1, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	var b := Bot.new(body, 1, cfg.skill_for(&"normal"), 1)
	var wrong_floor := PackedStringArray()
	var cut_off := PackedStringArray()
	var no_wall := PackedStringArray()
	var found := 0
	var none := 0
	var route := PackedVector3Array()
	var worst := 0.0
	var both_covered := 0
	for deg in 360:
		var a := deg_to_rad(float(deg))
		var u := Vector2(cos(a), sin(a))
		body.position = Vector3(spot.x - u.x * 25.0, spot.y, spot.z - u.y * 25.0)
		# Where both nominal side points are covered, the old code gave no flank at all.
		var covered := 0
		for side: float in [-1.0, 1.0]:
			var sx: float = spot.x - u.x * cfg.overtime_flank_back - u.y * cfg.overtime_flank_offset * side
			var sz: float = spot.z - u.y * cfg.overtime_flank_back + u.x * cfg.overtime_flank_offset * side
			if not BotMovement._on_same_floor(world, spot, sx, sz):
				covered += 1
		both_covered += 1 if covered == 2 else 0
		for seed_value in 2:
			b.rng = Seeds.stream(seed_value + 7 * deg)
			b.flanking = false
			BotMovement._overtime_flank_point(b, world, spot)
			if not b.flanking:
				none += 1
				continue
			found += 1
			var g := b.flank_goal
			if not nav.is_walkable_at(g) or absf(g.y - spot.y) > tuning.body.max_step:
				wrong_floor.append("%d deg: %s" % [deg, g])
			route.clear()
			if not nav.find_route(g, spot, route, false):
				cut_off.append("%d deg: %s" % [deg, g])
			if not nav.clear_line(g, spot):
				no_wall.append("%d deg: %s" % [deg, g])
			var len := 0.0
			var at := g
			for q in route:
				len += Vector2(q.x - at.x, q.z - at.z).length()
				at = q
			worst = maxf(worst, len)
			if len > 20.0:
				gut.p("long %d deg goal %s route %.1f" % [deg, g, len])
	# DC1 moved the hut to the open middle, where no approach has both side points covered any more: that case is
	# held by test_a_flank_point_is_found_where_both_side_points_are_covered.
	gut.p("approaches with both side points covered: %d" % both_covered)
	gut.p("worst route %.1f" % worst)
	gut.p("flank points found %d, none %d, no straight walk to flag %d" % [found, none, no_wall.size()])
	assert_gt(found, 0)
	assert_eq(none, 0, "a flank point from every side")
	assert_eq(wrong_floor.size(), 0, "off the flag's floor: %s" % [wrong_floor.slice(0, 5)])
	assert_eq(cut_off.size(), 0, "no way on foot to the flag: %s" % [cut_off.slice(0, 5)])


func test_a_flank_point_is_found_where_both_side_points_are_covered() -> void:
	# A flag in Staging's north chicane corridor, come at from the Yard to the north: both nominal side points, 6 m back
	# and 6 m either side, stand in the racking (one past the hall's west wall), which the old code gave up on. The
	# flank point snaps to the nearest walkable floor on the flag's floor instead.
	var cfg := BotConfig.load_default()
	var spot := Vector3(-39.5, 0.0, -11.0)
	var world := BotWorld.new()
	world.cfg = cfg
	world.tuning = tuning
	world.nav = nav
	world.query = level.query()
	var body := Character.new(0, 1, Vector3(spot.x, 0.0, spot.z - 20.0), 0.0, ReplicaStats.default_loadout())
	var b := Bot.new(body, 1, cfg.skill_for(&"normal"), 1)
	var u := Vector2(0.0, 1.0)
	var covered := 0
	for side: float in [-1.0, 1.0]:
		var sx: float = spot.x - u.x * cfg.overtime_flank_back - u.y * cfg.overtime_flank_offset * side
		var sz: float = spot.z - u.y * cfg.overtime_flank_back + u.x * cfg.overtime_flank_offset * side
		if not BotMovement._on_same_floor(world, spot, sx, sz):
			covered += 1
	assert_eq(covered, 2, "both side points are covered here")
	for seed_value in 4:
		b.rng = Seeds.stream(seed_value)
		b.flanking = false
		BotMovement._overtime_flank_point(b, world, spot)
		assert_true(b.flanking, "a flank point all the same (seed %d)" % seed_value)
		assert_true(nav.is_walkable_at(b.flank_goal), "on walkable floor: %s" % b.flank_goal)
		assert_lt(absf(b.flank_goal.y - spot.y), tuning.body.max_step, "on the flag's floor")
