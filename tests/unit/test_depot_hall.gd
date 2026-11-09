extends GutTest
## Depot as the indoor hall (DR1, the owner's concept 3 of 2026-10-31, built by tools/depot/build_map.py): the file
## reads clean, eight a side at each end (TS1), the roof (its lamps drawn, its ceiling stopping a BB), the bots' longer
## sight, the overhead sun, no spawn seen from the floor, and the run times the concept was balanced on.

const SIDE := 8

var tuning: SimTuning = SimTuning.new()
var style: MapStyle = MapStyle.new()
var play: PlayTuning = PlayTuning.new()
var map: MapData = null


func before_all() -> void:
	map = MapData.load_map("depot", style, SIDE)


func test_it_reads_clean_with_eight_a_side() -> void:
	assert_true(map.ok(), "Depot loads: %s" % [map.problems])
	assert_eq(map.warnings, [] as Array[String], "nothing in the file is left out")
	assert_eq(map.display_name, "Depot")
	for e in 2:
		assert_eq(map.ends[e].spawns.size(), SIDE, "end %d spawns eight" % e)
		assert_eq(map.ends[e].dead_zone.size(), SIDE, "end %d walks eight off" % e)
	var entry := MapCatalog.shared().find("depot")
	assert_not_null(entry)
	if entry != null:
		assert_eq([entry.team_min, entry.team_standard, entry.team_max], [5, 6, 8],
				"5 v 5 to 8 v 8, 6 v 6 its standard (TS1)")
	assert_eq(map.lanes.size(), 3, "three lanes")
	assert_true(map.has_pole and map.has_overtime_flag)


func test_the_roof_hangs_its_lamps_and_casts_no_shadow() -> void:
	assert_eq(map.roof_height, 8.0)
	assert_gt(map.roof_lamps.size(), 50)
	var roof := RoofView.build(map, play.roof)
	add_child_autofree(roof)
	assert_eq(roof.lamp_count(), map.roof_lamps.size())
	assert_eq(roof.materials().size(), 4, "the ceiling, the bays, the lamps' glow and their bodies")
	for child in roof.get_children():
		assert_eq((child as GeometryInstance3D).cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
				"%s lets the overhead sun through" % child.name)


func test_a_field_open_to_the_sky_has_no_roof() -> void:
	var yard := YardMap.load_map(style, 3)
	assert_eq(yard.roof_height, 0.0)
	assert_null(RoofView.build(yard, play.roof))


func test_a_bb_shot_up_meets_the_ceiling_as_steel() -> void:
	var level := MapLevel.new()
	add_child_autofree(level)
	level.build(map, style, tuning.body)
	var hit := RayHit.new()
	# Up from the middle of the Chrono hall, clear of the hut.
	assert_true(level.query().ray(Vector3(8.0, 1.5, 0.0), Vector3(8.0, 20.0, 0.0), hit))
	assert_almost_eq(hit.position.y, 8.0, 1e-3)
	assert_eq(hit.surface, RayHit.Surface.METAL)


func test_its_bots_see_fifty_five_metres_on_a_copy() -> void:
	var base := BotConfig.new()
	var hall := base.for_map(map)
	assert_eq(hall.view_distance, 55.0)
	assert_eq(base.view_distance, 40.0, "the tuning itself is untouched")
	assert_same(base.for_map(YardMap.load_map(style, 3)), base, "a map naming none plays the tuning as it is")


func test_its_lamps_light_from_nearly_overhead() -> void:
	var lit := LightingConfig.for_map(play.lighting, null, map, LightingConfig.DAY)
	assert_eq(lit.sun_elevation, 76.0)
	assert_eq(lit.sun_heading, 25.0)
	assert_ne(play.lighting.sun_elevation, 76.0, "the day preset is untouched")


func test_no_spawn_is_seen_from_the_floor() -> void:
	var level := MapLevel.new()
	add_child_autofree(level)
	level.build(map, style, tuning.body)
	var nav := NavGrid.build(map, tuning.nav, tuning.body)
	var q := level.query()
	var hit := RayHit.new()
	var eye := tuning.body.stand_eye_height
	var seen := PackedStringArray()
	for e in 2:
		var room := "Staging" if e == 0 else "Loading bay"
		for s in map.ends[e].spawns:
			var from := s.position + Vector3.UP * eye
			for i in range(-53, 54, 1):
				for j in range(-35, 36, 1):
					var p := Vector3(i + 0.5, 0.0, j + 0.5)
					# Everywhere on the floor but the spawn's own room: both sites, the stairs and the ramp too.
					if MapAreas.area_at(map.areas, p) == room or not nav.is_walkable_at(p):
						continue
					if not q.ray(from, p + Vector3.UP * eye, hit):
						seen.append("%s from %s" % [s.position, p])
	assert_eq(seen.size(), 0, "spawns seen: %s" % [seen.slice(0, 5)])


func test_all_the_floor_outside_the_named_areas_is_racking_or_plywood_rooms() -> void:
	# Dead space is solid to 3 m (the concept): every spot of the hall in no area stands in a tall block, so no zone edit
	# opens a crack in the racking (DR1 critic, attempt 3: a 0.5 m strip by the north chicane). Every 0.5 m.
	var tall: Array[MapData.Block] = []
	for blk in map.blocks:
		if blk.center.y + blk.size.y * 0.5 >= 2.0:
			tall.append(blk)
	var open := PackedStringArray()
	for i in 216:
		for j in 144:
			var p := Vector3(-54.0 + 0.25 + i * 0.5, 0.0, -36.0 + 0.25 + j * 0.5)
			if MapAreas.area_at(map.areas, p) != "":
				continue
			var inside := false
			for blk in tall:
				if absf(p.x - blk.center.x) < blk.size.x * 0.5 and absf(p.z - blk.center.z) < blk.size.z * 0.5:
					inside = true
					break
			if not inside:
				open.append(str(p))
	assert_eq(open.size(), 0, "open dead space at %s" % [open.slice(0, 5)])


func test_no_lane_starts_or_ends_inside_a_spawn_room() -> void:
	# A defender or an anchor holds its lane's points nearest its own end (RoundPlanner): those stand at the chicanes'
	# outer mouths, never in the spawn room, whose screens see nothing (DR1 critic, attempt 2).
	for lane in map.lanes:
		for k: int in [0, 1, lane.size() - 2, lane.size() - 1]:
			var area := MapAreas.area_at(map.areas, lane[k])
			assert_false(area == "Staging" or area == "Loading bay", "lane point %s is in %s" % [lane[k], area])


func test_both_teams_reach_the_middle_together_and_each_owns_a_side_lane() -> void:
	var nav := NavGrid.build(map, tuning.nav, tuning.body)
	var run := tuning.movement.run_speed
	var hall := _fastest(nav, 0, map.overtime_flag) - _fastest(nav, 1, map.overtime_flag)
	assert_lt(absf(hall) / run, 1.5, "the Chrono hall is even (%.1f s apart)" % (hall / run))
	var lounge := (_fastest(nav, 0, Vector3(-3, 0, -24)) - _fastest(nav, 1, Vector3(-3, 0, -24))) / run
	var box_yard := (_fastest(nav, 0, Vector3(1, 0, 18)) - _fastest(nav, 1, Vector3(1, 0, 18))) / run
	assert_between(lounge, -4.0, -1.0, "end 0 reaches the Lounge first (%.1f s)" % lounge)
	assert_between(box_yard, 1.0, 4.0, "end 1 reaches the Box yard first (%.1f s)" % box_yard)
	assert_lt(absf(lounge + box_yard), 1.5, "each end's lead is about the same")


## The shortest walk (m) from any of end `e`'s spawns to `goal`.
func _fastest(nav: NavGrid, e: int, goal: Vector3) -> float:
	var best := INF
	var route := PackedVector3Array()
	for s in map.ends[e].spawns:
		route.clear()
		if not nav.find_route(s.position, goal, route):
			continue
		var length := 0.0
		var at := s.position
		for p in route:
			length += Vector2(p.x - at.x, p.z - at.z).length()
			at = p
		best = minf(best, length)
	assert_true(is_finite(best), "end %d reaches %s" % [e, goal])
	return best
