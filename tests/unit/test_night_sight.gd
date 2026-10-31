extends GutTest
## Bots by night (WL6; the browser game's map/nightSight.test.ts, nightSightQA.test.ts and ai/woodlandNightMatch.test.ts):
## the NightField built from a map's data (light pools by floor, the canopy grid, roofs), how far bots make someone out
## by it, every level keeping out of the light (the old Easy that stood in it is gone, TL1), and a 5v5 night match on
## Woodland. By day there is no field and sight is as it always was.

const DT := 1.0 / 60.0
## How often the match samples every bot against every enemy (ticks), and the slack for how far either moved since the
## bot last looked (m), as the browser's test.
const SAMPLE_EVERY := 4
const MOVED_SLACK := 0.6

var cfg: BotConfig = BotConfig.load_default()
var tuning: SimTuning = SimTuning.load_default()
## Woodland's level and nav grid, 5v5, built once for the file.
var woodland: MatchRunner = null
var _w: BotWorld = null


func before_all() -> void:
	var t := SimTuning.load_default().duplicate() as SimTuning
	t.rounds = t.rounds.duplicate() as RoundConfig
	t.rounds.team_size = 5
	t.rounds.wins_needed = 2
	t.rounds.half_time_after = 1
	# The first wood (OldWoodland), night alone: these spots, pools and huts are its.
	woodland = MatchRunner.new(self, "woodland", t, null, OldWoodland.load_map(MapStyle.new(), t.rounds.team_size))


func after_all() -> void:
	woodland.free_level()


## The test field, `half` m from its middle each way (floor top 0): a deck 10 x 10 m over (-20, 20) from 2.9 to 3.1 m,
## three trunks round (20, 21), a fire on the ground at (0, -20) lighting 5 m and a lantern over the deck lighting 3 m.
static func _field(half: float = 40.0) -> MapData:
	var blocks: Array[String] = [
		'{"kind": "floor", "center": {"x": 0, "y": -0.25, "z": 0}, "size": {"x": %s, "y": 0.5, "z": %s}}' % [half * 2.0,
				half * 2.0],
		'{"kind": "floor", "center": {"x": -20, "y": 3, "z": 20}, "size": {"x": 10, "y": 0.2, "z": 10}}',
		'{"kind": "tree", "center": {"x": 19, "y": 1, "z": 20}, "size": {"x": 0.4, "y": 2, "z": 0.4}}',
		'{"kind": "tree", "center": {"x": 21, "y": 1, "z": 20}, "size": {"x": 0.4, "y": 2, "z": 0.4}}',
		'{"kind": "tree", "center": {"x": 20, "y": 1, "z": 22}, "size": {"x": 0.4, "y": 2, "z": 0.4}}',
	]
	var lights := '[{"position": {"x": 0, "y": 2, "z": -20}, "radius": 5, "colour": 16751178, "kind": "fire"}, ' \
			+ '{"position": {"x": -20, "y": 5, "z": 20}, "radius": 3, "colour": 16765562, "kind": "lantern"}]'
	return MapData.parse('{"blocks": [%s], "lights": %s, "spawns": [[], []], "deadZones": [[], []]}'
			% [",".join(blocks), lights], MapStyle.new(), 0)


# --- the field ---

func test_no_field_by_day_and_one_by_night() -> void:
	assert_null(NightField.build(_field(), cfg, false), "no field by day")
	var depot := MapData.load_map("depot", MapStyle.new(), 3)
	assert_eq(depot.preset_played(&""), LightingConfig.DAY, "Depot plays by day")
	assert_null(NightField.build(depot, cfg, false), "so its bots see as they always did")
	assert_not_null(NightField.build(_field(), cfg, true), "one by night")
	assert_true(woodland.night, "Woodland plays at night (its only preset)")


func test_sight_ranges_lit_open_under_the_trees_and_indoors() -> void:
	var f := NightField.build(_field(), cfg, true)
	var cases: Array[Array] = [
		[Vector3(0.0, 0.0, -18.0), 40.0, "in the fire's pool"],
		[Vector3(0.0, -0.4, -16.0), 40.0, "a little under its floor"],
		[Vector3(0.0, 3.0, -18.0), 25.0, "over the pool's floor by more than 2 m: not lit"],
		[Vector3(-20.0, 3.1, 20.0), 40.0, "on the deck in the lantern's pool"],
		[Vector3(-20.0, 0.0, 20.0), 15.0, "under the deck, the lantern lighting the deck: indoors in the dark"],
		[Vector3(-17.0, 3.1, 24.0), 25.0, "on the deck outside the lantern: the open"],
		[Vector3(20.2, 0.0, 20.7), 10.0, "under three trunks within 4 m"],
		[Vector3(30.0, 0.0, 30.0), 25.0, "the open"],
		[Vector3(100.0, 0.0, 100.0), 25.0, "off the grid: the open"],
	]
	for c in cases:
		assert_eq(f.sight_range(c[0]), c[1], c[2])


func test_the_canopy_rule_matches_the_ground_s_under_trees_rule() -> void:
	var style := MapStyle.new()
	assert_eq(cfg.night_canopy_trees, style.canopy_trees, "trunks")
	assert_eq(cfg.night_canopy_radius, style.canopy_radius, "radius")
	assert_eq(cfg.night_canopy_cell, style.canopy_cell, "cell")
	assert_eq([cfg.night_lit, cfg.night_open, cfg.night_canopy, cfg.night_indoor], [40.0, 25.0, 10.0, 15.0],
			"NIGHT_SIGHT's ranges")


## Woodland's grid against the browser's own loops (every trunk for each cell; every block for each cell), on a sample
## of cells; its lights lit, inside its hut indoors.
func test_woodland_s_field_is_the_browser_s_and_built_quickly() -> void:
	var map := woodland.map
	var f := NightField.build(map, cfg, true)
	gut.p("Woodland's night field: %d x %d cells, %d under the trees, %d roofs, built in %.1f ms"
			% [f.cols, f.rows, f.canopy.count(1), f.roofs.size(), f.build_usec / 1000.0])
	assert_eq([f.cols, f.rows], [121, 81], "the blocks' footprint in 1 m cells")
	var r2 := cfg.night_canopy_radius * cfg.night_canopy_radius
	var wrong := 0
	var checked := 0
	for c in range(0, f.cols * f.rows, 7):
		checked += 1
		var x := f.min_x + (c % f.cols + 0.5) * f.cell
		var z := f.min_z + (c / f.cols + 0.5) * f.cell
		var n := 0
		var under: Array[float] = []
		for b in map.blocks:
			if b.kind == &"tree":
				var dx := b.center.x - x
				var dz := b.center.z - z
				if dx * dx + dz * dz <= r2:
					n += 1
			elif absf(x - b.center.x) <= b.size.x * 0.5 and absf(z - b.center.z) <= b.size.z * 0.5:
				under.append(b.center.y - b.size.y * 0.5)
		under.sort()
		var filed: Array[float] = []
		for k in range(f.roof_start[c], f.roof_start[c + 1]):
			filed.append(f.roofs[k])
		if (f.canopy[c] == 1) != (n >= cfg.night_canopy_trees) or filed != under:
			wrong += 1
	assert_eq(wrong, 0, "%d cells checked against the browser's loops" % checked)
	assert_between(f.canopy.count(1), 1000, 3000, "the pines close overhead over part of the field")
	assert_lt(f.build_usec, 100000, "built in well under 0.1 s")
	for l in map.lights:
		var feet := Vector3(l.position.x, map.terrain.height_clamped(l.position.x, l.position.z), l.position.z)
		assert_eq(f.sight_range(feet), cfg.night_lit, "lit under the light at %s" % l.position)
	var hut := Vector3(4.0, 0.0, 19.0)
	hut.y = woodland.nav.floor_at(Vector3(hut.x, 0.0, hut.z))
	assert_true(f.under_roof(hut), "inside the hut, under its roof")


# --- what bots see by it ---

## A bot of `level` at `viewer_at` facing `target_at`, its enemy standing there, in an open world; at night on the test
## field when `night`.
func _pair(viewer_at: Vector3, target_at: Vector3, night: bool, level: StringName = &"easy") -> Bot:
	var loadout := ReplicaStats.default_loadout()
	var me := Character.new(0, 0, viewer_at, BotAim.look_yaw(viewer_at, target_at), loadout)
	var foe := Character.new(1, 1, target_at, 0.0, loadout)
	_w = BotWorld.new()
	_w.tuning = tuning
	_w.cfg = cfg
	_w.query = BoxWorld.new()
	_w.planner = RoundPlanner.new(1)
	_w.characters = [me, foe]
	_w.time = 10.0
	_w.night = NightField.build(_field(), cfg, night)
	return Bot.new(me, 1, cfg.skill_for(level), 2)


func _seen(target_at: Vector3, away: float, night: bool) -> bool:
	var b := _pair(target_at + Vector3(away, 0.0, 0.0), target_at, night)
	return BotSenses.visible_part(b.character, _w.characters[1], _w) > 0.0


func test_bots_make_someone_out_by_the_light_they_stand_in() -> void:
	var open := Vector3(10.0, 0.0, -10.0)
	var lit := Vector3(0.0, 0.0, -18.0)
	var trees := Vector3(20.2, 0.0, 20.7)
	var indoors := Vector3(-20.0, 0.0, 20.0)
	assert_true(_seen(open, 24.0, true), "the open, 24 m")
	assert_false(_seen(open, 26.0, true), "the open, 26 m")
	assert_true(_seen(open, 26.0, false), "by day, 26 m")
	assert_true(_seen(lit, 39.0, true), "lit, 39 m")
	assert_false(_seen(lit, 41.0, false), "view_distance still caps it")
	assert_true(_seen(trees, -9.0, true), "under the trees, 9 m")
	assert_false(_seen(trees, -11.0, true), "under the trees, 11 m")
	assert_true(_seen(indoors, 14.0, true), "indoors, 14 m")
	assert_false(_seen(indoors, 16.0, true), "indoors, 16 m")


func test_a_spot_in_the_dark_is_not_seen_empty_beyond_its_range() -> void:
	var spot := Vector3(10.0, 0.0, -10.0)
	var near := _pair(spot + Vector3(20.0, 0.0, 0.0), spot, true)
	assert_true(BotSenses.sees_spot(near.character, spot, 40.0, _w), "20 m in the open")
	var far := _pair(spot + Vector3(30.0, 0.0, 0.0), spot, true)
	assert_false(BotSenses.sees_spot(far.character, spot, 40.0, _w), "30 m in the open")
	far = _pair(spot + Vector3(30.0, 0.0, 0.0), spot, false)
	assert_true(BotSenses.sees_spot(far.character, spot, 40.0, _w), "by day")


func test_the_sight_check_allocates_nothing() -> void:
	var f := NightField.build(woodland.map, cfg, true)
	var points := PackedVector3Array([Vector3(-55.5, 1.0, -12.0), Vector3(4.0, 2.2, 19.0), Vector3(0.0, 1.0, 0.0),
			Vector3(30.0, 2.0, 25.0)])
	var objects := Performance.get_monitor(Performance.OBJECT_COUNT)
	var sum := 0.0
	var started := Time.get_ticks_usec()
	for i in 5000:
		for p in points:
			sum += f.sight_range(p)
	var each := float(Time.get_ticks_usec() - started) / (5000.0 * points.size())
	var made := Performance.get_monitor(Performance.OBJECT_COUNT) - objects
	gut.p("a night sight check: %.2f µs (a bot looks at 5 enemies: %.1f µs a look)" % [each, each * 5.0])
	assert_eq(made, 0.0, "no object made")
	assert_gt(sum, 0.0, "")


# --- keeping out of the light ---

## A bot of `level` in a world on the small test field with its nav grid, at night or by day, standing far from the
## fire and facing away from it.
func _keeper(level: StringName, night: bool) -> Bot:
	var map := _field(30.0)
	var b := _pair(Vector3(25.0, 0.0, 25.0), Vector3(29.0, 0.0, 29.0), night, level)
	_w.night = NightField.build(map, cfg, night)
	_w.nav = _small_nav(map)
	_w.characters[1].status = Character.Status.OUT
	_w.setup_sectors(Vector2(-30.0, -30.0), Vector2(30.0, 30.0))
	return b


var _nav_cache: NavGrid = null


func _small_nav(map: MapData) -> NavGrid:
	if _nav_cache == null:
		_nav_cache = NavGrid.build(map, tuning.nav, tuning.body)
	return _nav_cache


func test_a_lane_point_in_a_pool_moves_to_the_dark_at_every_level_but_not_by_day() -> void:
	var pool := Vector3(0.0, 0.0, -20.0)
	for c: Array in [[&"easy", true, false], [&"normal", true, false], [&"hard", true, false], [&"easy", false, true]]:
		var b := _keeper(c[0], c[1])
		_w.lanes = [PackedVector3Array([pool])]
		b.reset(0, 1, 0.0, cfg)
		assert_true(BotMovement._next_goal(b, _w), "a lane point to go to")
		var lit := NightField.build(_field(30.0), cfg, true).in_light(b.lane_goal)
		assert_eq(lit, c[2], "%s %s: in the light %s" % [c[0], "at night" if c[1] else "by day", c[2]])
		if not lit:
			var off := Vector2(b.lane_goal.x - pool.x, b.lane_goal.z - pool.z).length()
			assert_between(off, 5.0, 6.5, "to the pool's edge, on its floor")
			assert_almost_eq(b.lane_goal.y, 0.0, 0.01, "on its floor")


func test_a_hunt_spot_in_a_pool_moves_to_the_dark_at_every_level() -> void:
	var lit_field := NightField.build(_field(30.0), cfg, true)
	for c: Array in [[&"easy", true, false], [&"hard", true, false], [&"easy", false, true]]:
		var b := _keeper(c[0], c[1])
		_w.planner.bounds_lo = Vector2(-2.0, -22.0)
		_w.planner.bounds_hi = Vector2(2.0, -18.0)
		_w.planner.top_y = 5.0
		assert_true(_w.planner.hunt_point(b, _w), "a spot")
		assert_eq(lit_field.in_light(b.hunt_goal), c[2], "%s %s" % [c[0], "at night" if c[1] else "by day"])


func test_hold_cover_in_a_pool_is_passed_over_when_keeping_dark() -> void:
	for c: Array in [[true, true, false], [false, true, true], [true, false, true]]:
		var b := _keeper(&"easy", c[1])
		var world := BoxWorld.new()
		world.add_box(Vector3(0.0, 0.6, -20.0), Vector3(1.0, 1.2, 1.0))
		_w.query = world
		var crate := BotCover.Block.new()
		crate.center = Vector2(0.0, -20.0)
		crate.half = Vector2(0.5, 0.5)
		_w.low_cover = [crate]
		var spot := BotCover.Spot.new()
		var threat := Vector3(0.0, tuning.body.stand_eye_height, -30.0)
		var found := BotCover.find(Vector3(0.0, 0.0, -18.5), threat, _w, b.rng, spot, 3.0, 0, true,
				PackedVector3Array(), 0, c[0])
		assert_eq(found, c[2], "keep_dark %s, %s: cover behind the crate in the fire's light %s"
				% [c[0], "night" if c[1] else "day", c[2]])


# --- Woodland: a camp fire and a 5v5 night match ---

func test_out_of_a_woodland_camp_fire_s_light_from_its_middle() -> void:
	var w := BotWorld.new()
	w.tuning = woodland.tuning
	w.cfg = cfg
	w.nav = woodland.nav
	w.night = NightField.build(woodland.map, cfg, true)
	# The west camp's fire, the worst case: from its middle the dark is 7 m off.
	var fire := woodland.map.lights[0].position
	fire.y = w.nav.floor_at(Vector3(fire.x, fire.y, fire.z))
	var started := Time.get_ticks_usec()
	var dark := w.out_of_light(fire)
	gut.p("out of the west camp fire's light from its middle: %d µs, %.1f m" % [Time.get_ticks_usec() - started,
			Vector2(dark.x - fire.x, dark.z - fire.z).length()])
	assert_true(w.night.in_light(fire), "the fire lights its middle")
	assert_false(w.night.in_light(dark), "a dark spot by the camp")
	assert_lte(absf(dark.y - fire.y), tuning.body.max_step, "on the same ground")


func test_a_5v5_night_match_on_woodland_keeps_every_sighting_in_range_and_finishes() -> void:
	var view := cfg.view_distance
	var close := cfg.close_awareness
	var look_ticks := ceili(cfg.think_interval / DT) + 1
	var watch := {"sampled": 0, "hidden": 0, "beyond": 0, "seen_lit": 0, "seen_dark": 0, "field": null,
			"changed": false}
	# Each character's night range over the last look_ticks, newest last: a bot sees what it saw when it last looked.
	var ranges: Array[PackedFloat64Array] = []
	for i in woodland.tuning.rounds.team_size * 2:
		ranges.append(PackedFloat64Array())
	woodland.each_tick = func(state: GameState, bots: BotController) -> void:
		var w := bots.world
		if watch.field == null:
			watch.field = w.night
		elif w.night != watch.field:
			watch.changed = true
		var field: NightField = w.night
		for c in state.characters:
			var recent := ranges[c.id]
			recent.append(field.sight_range(c.position))
			if recent.size() > look_ticks:
				recent.remove_at(0)
			ranges[c.id] = recent
		if not state.round_state.is_live() or roundi(state.time / DT) % SAMPLE_EVERY != 0:
			return
		for b in w.bots:
			var me := b.character
			if not Elimination.is_in_play(me):
				continue
			for other in state.characters:
				if other.team == me.team or not Elimination.is_in_play(other):
					continue
				var dist := Vector2(other.position.x - me.position.x, other.position.z - me.position.z).length()
				if dist > view:
					continue
				watch.sampled += 1
				if dist > minf(view, field.sight_range(other.position)) and dist > close:
					watch.hidden += 1
				if b.target_visible and b.target_id == other.id:
					var most := 0.0
					for r in ranges[other.id]:
						most = maxf(most, r)
					if dist > minf(view, most) + MOVED_SLACK and dist > close:
						watch.beyond += 1
					if field.in_light(other.position):
						watch.seen_lit += 1
					else:
						watch.seen_dark += 1
	# Sight by the dark alone: the torches' own light is test_torch.gd's (WL7).
	woodland.lights = MatchRunner.Lights.NONE
	var tally := woodland.play(3, 900.0)
	woodland.lights = MatchRunner.Lights.BY_RULE
	woodland.each_tick = Callable()
	gut.p("Woodland 5v5 at night: %d rounds in %.0f s, %d hits; %d sightings sampled, %d hidden by the dark, %d seen lit, %d seen in the dark"
			% [tally.rounds.size(), tally.ticks * DT, tally.hits, watch.sampled, watch.hidden, watch.seen_lit,
			watch.seen_dark])
	assert_not_null(watch.field, "the bots see by a night field")
	assert_false(watch.changed, "built once as the match loads, never again while it plays")
	assert_gt(watch.sampled, 300, "enough sightings checked")
	assert_eq(watch.beyond, 0, "no bot had a target in view beyond that target's night range")
	assert_gt(watch.hidden, 0, "the dark hides enemies from bots in play")
	assert_gt(watch.seen_lit + watch.seen_dark, 0, "bots still see each other")
	assert_true(tally.finished, "the match is won")
	assert_gte(tally.rounds.size(), 2, "its rounds finish")
	assert_gt(tally.hits, 0, "BBs land")
