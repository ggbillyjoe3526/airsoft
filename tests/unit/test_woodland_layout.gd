extends GutTest
## Woodland as the owner's concept 3 (WR1, 2026-10-31, built by tools/woodland/build_map.py): a 176 x 120 m wood on
## sloping ground with a dry stream down the middle, three lanes, the Ridge, the Clearing and the road. The file reads
## clean with six a side, by day or by night; its ground, crossings and pieces stand where the concept put them; no
## spawn is seen from outside its camp; both ends reach the overtime flag together and their own site first; a body
## walks every lane end to end; bots take cover at its pieces; and bots play a whole match on it.

const DT := 1.0 / 60.0
const SIDE := 6
## The field's half sizes (m).
const HALF_X := 88.0
const HALF_Z := 60.0
## The camps' plan boxes (x0, z0, size): spawns inside, seen from nowhere outside.
const CAMPS: Array[Rect2] = [Rect2(-88.0, -14.0, 16.0, 34.0), Rect2(72.0, -16.0, 16.0, 30.0)]
## The crossings of the dry stream (world x, z): the North bridge's deck, the road over the culvert, the Ford.
const NORTH_BRIDGE := Vector2(-1.0, -41.5)
const CULVERT_ROAD := Vector2(8.0, 48.3)
const FORD := Vector2(9.5, 0.5)
## Where the stream is measured across (world x the search starts at, z): between the Ford and the culvert, off the
## slides, and the least its banks stand over its bed there (m).
const BED_SPAN := Vector2(0.0, 30.0)
const STREAM_DEPTH := 1.5
## Walkable ground cut off from both camps, this many nav nodes or more (1 m²), is a pit nobody walks out of; the
## Crawl box's mound top (its plan box) is out of everyone's reach instead, its sides too steep to climb.
const PIT_NODES := 25
const MOUND_TOP := Rect2(-26.0, -19.0, 10.0, 6.0)
## The most a lane's walk may take, as a share of a run along its route, before the body counts as stuck.
const WALK_SLACK := 1.6
## A route's waypoint counts as reached within this (m).
const REACHED := 0.4
## The most match time (s) a whole bot match may take.
const MATCH_SECONDS := 1800.0

var tuning: SimTuning = SimTuning.load_default()
var style: MapStyle = PlayTuning.load_default().map_style
var map: MapData = null
var nav: NavGrid = null
var level: MapLevel = null
var hit: RayHit = RayHit.new()


func before_all() -> void:
	map = MapData.load_map("woodland", style, SIDE)
	level = MapLevel.new()
	add_child(level)
	level.build(map, style, tuning.body)
	nav = NavGrid.build(map, tuning.nav, tuning.body)


func after_all() -> void:
	level.free()
	level = null
	nav = null


func test_it_reads_clean_with_six_a_side_by_day_or_night() -> void:
	assert_true(map.ok(), "Woodland loads: %s" % [map.problems])
	assert_eq(map.warnings, [] as Array[String], "nothing in the file is left out")
	assert_eq(map.display_name, "Woodland")
	for e in 2:
		assert_eq(map.ends[e].spawns.size(), SIDE, "end %d spawns six" % e)
		assert_eq(map.ends[e].dead_zone.size(), SIDE, "end %d walks six off" % e)
	var entry := MapCatalog.shared().find("woodland")
	assert_not_null(entry)
	if entry != null:
		assert_eq([entry.team_min, entry.team_standard, entry.team_max], [5, 5, 6], "5 v 5 or 6 v 6")
	assert_eq(map.lanes.size(), 3, "three lanes")
	assert_true(map.has_pole and map.has_overtime_flag)
	assert_eq(map.lighting_presets, [LightingConfig.DAY, LightingConfig.NIGHT] as Array[StringName],
			"day by default, night by the Time of day setting")
	assert_false(map.night, "day first")
	assert_eq(map.lights.size(), 11, "the concept's eleven lights for the night")
	assert_eq(map.bot_sight, 60.0, "bots see 60 m (owner, 2026-10-31)")


func test_it_is_176_by_120_m_of_half_metre_ground_with_the_stream_cut_down_the_middle() -> void:
	var t := map.terrain
	assert_not_null(t)
	assert_eq([t.min_x, t.min_z, t.max_x(), t.max_z(), t.cell], [-HALF_X, -HALF_Z, HALF_X, HALF_Z, 0.5])
	# Across the stream between the Ford and the culvert, away from its slides: the bed's lowest point, and either
	# bank 6 m off it standing well over it.
	var bed := INF
	var bed_x := 0.0
	for i in 33:
		var x := BED_SPAN.x + i * 0.5
		if t.height_at(x, BED_SPAN.y) < bed:
			bed = t.height_at(x, BED_SPAN.y)
			bed_x = x
	for side: float in [-1.0, 1.0]:
		var bank := t.height_at(bed_x + side * 6.0, BED_SPAN.y)
		assert_gt(bank - bed, STREAM_DEPTH, "the %s bank stands %.2f m over the bed" % [
				"east" if side > 0.0 else "west", bank - bed])


func test_both_stream_crossings_are_level_with_the_ground_at_their_ends() -> void:
	for at: Vector2 in [NORTH_BRIDGE, CULVERT_ROAD]:
		var deck := _deck_at(at)
		assert_not_null(deck, "a deck at %s" % at)
		if deck == null:
			continue
		var top := deck.center.y + deck.size.y * 0.5
		for side: float in [-1.0, 1.0]:
			var end := Vector2(deck.center.x + side * (deck.size.x * 0.5 + 0.4), at.y)
			var ground := map.terrain.height_at(end.x, end.y)
			assert_almost_eq(ground, top, 0.15, "the ground off the %s end of the deck at %s" % [
					"east" if side > 0.0 else "west", at])


func test_every_piece_stands_on_the_ground_and_none_is_on_the_road() -> void:
	var floating := PackedStringArray()
	for b in map.blocks:
		if b.kind == &"floor" or b.kind == &"ramp" or b.kind == &"plywood" and b.size.y < 0.5:
			continue # decks, the stair, roofs and lintels stand on posts and walls
		var bottom := b.center.y - b.size.y * 0.5
		var lowest := INF
		for corner: Vector2 in [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(-0.5, 0.5), Vector2(0.5, 0.5)]:
			var x := b.center.x + corner.x * b.size.x
			var z := b.center.z + corner.y * b.size.z
			lowest = minf(lowest, map.terrain.height_at(clampf(x, -HALF_X, HALF_X), clampf(z, -HALF_Z, HALF_Z)))
		if bottom > lowest + 0.05 and b.kind != &"log" and b.kind != &"plywood" and not _on_a_deck(b):
			floating.append("%s at %s" % [b.kind, b.center])
	assert_eq(floating.size(), 0, "blocks over the ground: %s" % [floating.slice(0, 5)])


func test_bots_take_cover_at_its_pieces_sunk_into_the_slope() -> void:
	var cfg := BotConfig.load_default()
	var low := BotCover.low_blocks(map, nav, cfg, tuning)
	var tall := BotCover.tall_blocks(map, nav, cfg, tuning)
	gut.p("cover: %d low, %d tall" % [low.size(), tall.size()])
	assert_gt(low.size(), 40, "logs, stacks and crates hide a crouched bot")
	assert_gt(tall.size(), 400, "trunks, huts and thickets hide a standing one")
	# On a flat floor: a crate on it and one sunk 0.3 m count; one sunk 0.5 m or floating 0.1 m over it does not.
	var crates := [_box("floor", Vector3(0.0, -0.5, 0.0), Vector3(30.0, 1.0, 12.0))]
	for c: Vector3 in [Vector3(-10.0, 0.0, 1.3), Vector3(-4.0, -0.3, 1.6), Vector3(2.0, -0.5, 1.8),
			Vector3(8.0, 0.1, 1.2)]:
		crates.append(_box("crate", Vector3(c.x, c.y + c.z * 0.5, 0.0), Vector3(1.2, c.z, 1.2)))
	var field := MapData.parse(JSON.stringify({"blocks": crates}), style, 1)
	var found := BotCover.low_blocks(field, NavGrid.build(field, tuning.nav, tuning.body), cfg, tuning)
	var xs: Array[float] = []
	for k in found:
		xs.append(k.center.x)
	assert_eq(xs, [-10.0, -4.0] as Array[float], "the crates standing on or sunk into the floor")


func test_no_walkable_ground_is_a_pit_cut_off_from_the_camps() -> void:
	var home := nav.node_at(map.ends[0].spawns[0].position)
	assert_true(nav.linked(home, nav.node_at(map.ends[1].spawns[0].position)), "the camps join")
	var cut_off: Dictionary[int, Vector3] = {}
	var counts: Dictionary[int, int] = {}
	for k in nav.floor_y.size():
		if nav.walkable[k] != 1 or nav.linked(home, k):
			continue
		var r: int = nav.region[k]
		counts[r] = counts.get(r, 0) + 1
		cut_off[r] = nav.node_position(k)
	var pits := PackedStringArray()
	for r in counts:
		var at := cut_off[r]
		if counts[r] >= PIT_NODES and not MOUND_TOP.has_point(Vector2(at.x, at.z)):
			pits.append("%d nodes at %s" % [counts[r], at])
	assert_eq(pits.size(), 0, "ground nobody walks out of: %s" % [pits])


func test_no_spawn_is_seen_from_outside_its_camp() -> void:
	var q := level.query()
	var eye := tuning.body.stand_eye_height
	var seen := PackedStringArray()
	for e in 2:
		for s in map.ends[e].spawns:
			var from := s.position + Vector3.UP * eye
			for i in range(-87, 88, 2):
				for j in range(-59, 60, 2):
					var p := Vector3(i + 0.5, 0.0, j + 0.5)
					if CAMPS[0].has_point(Vector2(p.x, p.z)) or CAMPS[1].has_point(Vector2(p.x, p.z)):
						continue
					if not nav.is_walkable_at(Vector3(p.x, 50.0, p.z)):
						continue
					p.y = nav.floor_at(Vector3(p.x, 50.0, p.z))
					if not q.ray(from, p + Vector3.UP * eye, hit):
						seen.append("%s from %s" % [s.position, p])
	assert_eq(seen.size(), 0, "spawns seen: %s" % [seen.slice(0, 5)])


func test_both_ends_reach_the_overtime_flag_together_and_their_own_site_first() -> void:
	var run := tuning.movement.run_speed
	var west := _fastest(0, map.overtime_flag) / run
	var east := _fastest(1, map.overtime_flag) / run
	gut.p("overtime flag: west %.1f s, east %.1f s" % [west, east])
	assert_lt(absf(west - east), 2.0, "the Clearing is even (%.1f and %.1f s)" % [west, east])
	var attack := _fastest(0, map.pole) / run
	var defend := _fastest(1, map.pole) / run
	gut.p("A flag: attackers %.1f s, defenders %.1f s" % [attack, defend])
	assert_between(attack, 30.0, 45.0, "attackers take a while to reach A")
	assert_lt(defend, 15.0, "defenders are home at A first")


func test_every_crossing_is_reached_from_both_ends() -> void:
	var run := tuning.movement.run_speed
	for at: Vector2 in [NORTH_BRIDGE, CULVERT_ROAD, FORD]:
		var goal := Vector3(at.x, nav.floor_at(Vector3(at.x, 50.0, at.y)), at.y)
		var west := _fastest(0, goal) / run
		var east := _fastest(1, goal) / run
		gut.p("%s: west %.1f s, east %.1f s" % [at, west, east])
		assert_lt(maxf(west, east), 32.0, "%s is near both ends" % at)


func test_a_body_walks_every_lane_end_to_end_on_the_bots_routes() -> void:
	var mover := level.mover(tuning.body)
	var route := PackedVector3Array()
	var cmd := PlayerCommand.new()
	for l in map.lanes.size():
		var lane := map.lanes[l]
		var c := Character.new(0, 0, lane[0] + Vector3(0.0, tuning.body.rest_gap, 0.0), 0.0,
				ReplicaStats.default_loadout())
		var walked := 0.0
		var ticks := 0
		var ok := true
		for k in range(1, lane.size()):
			if not nav.find_route(c.position, lane[k], route, true):
				ok = false
				assert_true(false, "lane %d: no route from %s to point %d" % [l + 1, c.position, k + 1])
				break
			var length := 0.0
			var here := c.position
			for p in route:
				length += Vector2(p.x - here.x, p.z - here.z).length()
				here = p
			walked += length
			var budget := ceili(length / tuning.movement.run_speed / DT * WALK_SLACK) + 30
			var next := 0
			var spent := 0
			while next < route.size() and spent < budget:
				var to := route[next] - c.position
				if Vector2(to.x, to.z).length() < REACHED:
					next += 1
					continue
				cmd.forward = 1.0
				cmd.yaw = atan2(-to.x, -to.z)
				Movement.step(c, cmd, tuning.movement, tuning.accuracy, DT, mover)
				spent += 1
			ticks += spent
			if next < route.size():
				ok = false
				assert_true(false, "lane %d: stuck at %s on the way to point %d" % [l + 1, c.position, k + 1])
				break
		gut.p("lane %d: %.1f m walked in %.1f s" % [l + 1, walked, ticks * DT])
		if ok:
			var end := lane[lane.size() - 1]
			assert_lt(Vector2(c.position.x - end.x, c.position.z - end.z).length(), 1.0, "lane %d's end reached" % (l + 1))


func test_bots_play_a_whole_match_at_today_s_team_size() -> void:
	var runner := MatchRunner.new(self, "woodland")
	var t := runner.play(7, MATCH_SECONDS)
	runner.free_level()
	gut.p("%d rounds in %.0f s of play, %d hits, held up %d, stayed home %d" % [t.rounds.size(), t.ticks * DT, t.hits,
			t.held_up, t.stayed_home])
	assert_true(t.finished, "the match is won")
	assert_gt(t.hits, 0, "BBs land")
	assert_eq(t.held_up, 0, "no bot held up")


## A block's entry in a map file.
static func _box(kind: String, center: Vector3, size: Vector3) -> Dictionary:
	return {"kind": kind, "center": {"x": center.x, "y": center.y, "z": center.z},
			"size": {"x": size.x, "y": size.y, "z": size.z}}


## Whether `b` stands on a deck (the culvert's kerbs on the road over it).
func _on_a_deck(b: MapData.Block) -> bool:
	var deck := _deck_at(Vector2(b.center.x, b.center.z))
	return deck != null and absf(deck.center.y + deck.size.y * 0.5 - (b.center.y - b.size.y * 0.5)) < 0.05


## The deck (a floor block) over (x, z), or null.
func _deck_at(at: Vector2) -> MapData.Block:
	for b in map.blocks:
		if b.kind == &"floor" and absf(at.x - b.center.x) < b.size.x * 0.5 and absf(at.y - b.center.z) < b.size.z * 0.5:
			return b
	return null


## The shortest walk (m) from any of end `e`'s spawns to `goal`.
func _fastest(e: int, goal: Vector3) -> float:
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


## The three crouch tunnels (CT1): each one's ends (x, z) in the order a test walks it, north to south, and the stretch
## under its roof (z): the Crawl box's plywood, the Badger run's logs, the road deck over the Culvert's bed.
const TUNNELS: Array[Array] = [
	["Crawl box", Vector2(-14.0, -20.5), Vector2(-14.0, -9.5), Vector2(-18.0, -12.0)],
	["Badger run", Vector2(31.0, 13.0), Vector2(31.0, 25.0), Vector2(15.5, 22.5)],
	["Culvert", Vector2(8.0, 45.3), Vector2(8.0, 51.3), Vector2(45.3, 51.3)],
]
## How far (m) past each end a walk through starts and finishes.
const TUNNEL_APPROACH := 1.5
## How far (m) inside each end of its roof a tunnel's floor must be low: its first metre runs up the slope to the
## mouth, roofed higher.
const ROOF_INSET := 1.0


## Whether cell (x, z) has a walkable floor only a crouched body fits over.
func _low_floor_at(x: float, z: float) -> bool:
	var c := nav.cell_index(x, z)
	for k in range(nav.cell_start[c], nav.cell_start[c + 1]):
		if nav.walkable[k] == 1 and nav.low[k] == 1:
			return true
	return false


func test_each_tunnel_is_low_floor_under_its_roof_on_the_grid() -> void:
	for t: Array in TUNNELS:
		var a: Vector2 = t[1]
		var roof: Vector2 = t[3]
		var gaps := 0
		var z := roof.x + ROOF_INSET
		while z <= roof.y - ROOF_INSET:
			if not _low_floor_at(a.x, z):
				gaps += 1
			z += tuning.nav.cell
		assert_eq(gaps, 0, "%s: a crouched body's floor all along under its roof" % t[0])


## Walks a body from TUNNEL_APPROACH before end a to as far past end b, crouched or standing; where it ends.
func _walk_through(a: Vector2, b: Vector2, crouched: bool) -> Character:
	var way := (b - a).normalized()
	var start := a - way * TUNNEL_APPROACH
	var c := Character.new(0, 0, Vector3(start.x, map.terrain.height_at(start.x, start.y) + 0.3, start.y), 0.0,
			ReplicaStats.default_loadout())
	var cmd := PlayerCommand.new()
	cmd.yaw = atan2(-way.x, -way.y)
	cmd.forward = 1.0
	cmd.crouch = crouched
	var mover := level.mover(tuning.body)
	var ticks := ceili((a.distance_to(b) + 2.0 * TUNNEL_APPROACH) / tuning.movement.crouch_speed / DT * 1.5)
	for i in ticks:
		Movement.step(c, cmd, tuning.movement, tuning.accuracy, DT, mover)
	return c


func test_a_crouched_body_walks_through_each_tunnel_and_a_standing_one_can_t() -> void:
	for t: Array in TUNNELS:
		var a: Vector2 = t[1]
		var b: Vector2 = t[2]
		var way := (b - a).normalized()
		var c := _walk_through(a, b, true)
		var past := Vector2(c.position.x - b.x, c.position.z - b.y).dot(way)
		assert_gt(past, 0.5, "%s: crouched, out past the far end (at %s)" % [t[0], c.position])
		var roof: Vector2 = t[3]
		var s := _walk_through(a, b, false)
		assert_lt(s.position.z, roof.x + ROOF_INSET, "%s: standing, stopped at the mouth (at %s)" % [t[0], s.position])
