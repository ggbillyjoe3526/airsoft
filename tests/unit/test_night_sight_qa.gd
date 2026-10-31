extends GutTest
## QA for WL6 (bots by night): the range boundaries exactly, which preset plays at night, and that moving a point out of
## a light pool never leaves its floor or region, on Woodland and on the test field TowerBlock (floors in storeys) at night.

const DT := 1.0 / 60.0

var cfg: BotConfig = BotConfig.load_default()
var tuning: SimTuning = SimTuning.load_default()


func _open_pair(away: float, night: bool) -> Array:
	var loadout := ReplicaStats.default_loadout()
	var target_at := Vector3(10.0, 0.0, -10.0)
	var viewer_at := target_at + Vector3(away, 0.0, 0.0)
	var me := Character.new(0, 0, viewer_at, BotAim.look_yaw(viewer_at, target_at), loadout)
	var foe := Character.new(1, 1, target_at, 0.0, loadout)
	var w := BotWorld.new()
	w.tuning = tuning
	w.cfg = cfg
	w.query = BoxWorld.new()
	w.planner = RoundPlanner.new(1)
	w.characters = [me, foe]
	w.time = 10.0
	var blocks := '{"kind": "floor", "center": {"x": 0, "y": -0.25, "z": 0}, "size": {"x": 200, "y": 0.5, "z": 200}}'
	w.night = NightField.build(MapData.parse('{"blocks": [%s], "lights": [], "spawns": [[], []], "deadZones": [[], []]}'
			% blocks, MapStyle.new(), 0), cfg, night)
	return [me, foe, w]


func test_someone_exactly_at_the_open_range_is_seen_and_a_hair_beyond_is_not() -> void:
	for c: Array in [[cfg.night_open, true], [cfg.night_open + 0.01, false]]:
		var p := _open_pair(c[0], true)
		var seen := BotSenses.visible_part(p[0], p[1], p[2]) > 0.0
		assert_eq(seen, c[1], "%.2f m away in the moonlit open" % c[0])


func test_a_bot_loses_a_target_that_steps_from_the_light_into_the_dark() -> void:
	# The browser's rule too: sight is judged afresh each look from the target's own spot, no memory of having seen.
	var p := _open_pair(30.0, true)
	var w: BotWorld = p[2]
	var foe: Character = p[1]
	assert_eq(BotSenses.visible_part(p[0], foe, w), 0.0, "30 m away in the open: not made out")
	w.night.light_at.append(foe.position)
	w.night.light_radius_sq.append(9.0)
	w.night.light_floor.append(0.0)
	assert_gt(BotSenses.visible_part(p[0], foe, w), 0.0, "30 m away in a pool: made out")


func test_the_preset_played_decides_the_night() -> void:
	var play := PlayTuning.load_default()
	var woodland := MapData.load_map("woodland", play.map_style, 3)
	var tower := TowerBlock.load_map(play.map_style, 3)
	var depot := MapData.load_map("depot", play.map_style, 3)
	assert_false(PlaySession.lighting_for(woodland, play, &"", &"").night, "Woodland: day first (WR1)")
	assert_true(PlaySession.lighting_for(woodland, play, LightingConfig.NIGHT, &"").night, "and picked for night")
	assert_true(PlaySession.lighting_for(tower, play, &"", &"").night, "a map offering both: night by default")
	assert_false(PlaySession.lighting_for(tower, play, LightingConfig.DAY, &"").night, "and picked for day")
	assert_false(PlaySession.lighting_for(depot, play, &"", &"").night, "Depot")
	assert_true(PlaySession.lighting_for(depot, play, &"", LightingConfig.NIGHT).night, "Depot, Dev: Time of day Night")
	assert_false(PlaySession.lighting_for(woodland, play, LightingConfig.NIGHT, LightingConfig.DAY).night,
			"Woodland, Dev: Time of day Day (a forced preset wins over the map's own)")


## Every lit walkable spot of `map`'s light pools (`map_id` names it in the messages), moved out of the light: still on
## its floor, walkable, dark, a step from where it was and in the same region on foot.
func _sweep(map: MapData, map_id: String) -> void:
	var nav := NavGrid.build(map, tuning.nav, tuning.body)
	var w := BotWorld.new()
	w.tuning = tuning
	w.cfg = cfg
	w.nav = nav
	w.night = NightField.build(map, cfg, true)
	var lit := 0
	var moved := 0
	var stuck := 0
	var bad_floor := 0
	var bad_region := 0
	var still_lit := 0
	var far := 0
	var worst := 0.0
	var first_bad := ""
	for l in map.lights:
		var r := l.radius + 0.5
		var x := l.position.x - r
		while x <= l.position.x + r:
			var z := l.position.z - r
			while z <= l.position.z + r:
				z += 0.5
				var probe := Vector3(x, l.position.y, z)
				var k := nav.node_at(probe)
				if k < 0 or nav.walkable[k] != 1:
					continue
				var g := nav.node_position(k)
				if not w.night.in_light(g):
					continue
				lit += 1
				var out := w.out_of_light(g)
				if out == g:
					stuck += 1
					continue
				moved += 1
				var j := nav.node_at(out)
				var why := ""
				if j < 0 or nav.walkable[j] != 1 or absf(nav.floor_y[j] - out.y) > 0.01 \
						or absf(out.y - g.y) > tuning.body.max_step:
					bad_floor += 1
					why = "floor"
				elif not nav.linked(k, j, true):
					bad_region += 1
					why = "region"
				if w.night.in_light(out):
					still_lit += 1
					why = "lit"
				var d := Vector2(out.x - g.x, out.z - g.z).length()
				worst = maxf(worst, d)
				if d > cfg.dark_spot_radius + 0.01:
					far += 1
				if why != "" and first_bad == "":
					first_bad = "%s from %s to %s" % [why, g, out]
			x += 0.5
	gut.p("%s at night: %d lit spots swept, %d moved (worst %.1f m), %d unmoved (no dark spot within %.0f m)"
			% [map_id, lit, moved, worst, stuck, cfg.dark_spot_radius])
	assert_gt(lit, 0, "%s has lit walkable ground" % map_id)
	assert_eq(bad_floor, 0, "%s: a moved point stays on its floor, walkable (%s)" % [map_id, first_bad])
	assert_eq(bad_region, 0, "%s: a moved point stays in its region (%s)" % [map_id, first_bad])
	assert_eq(still_lit, 0, "%s: a moved point is dark (%s)" % [map_id, first_bad])
	assert_eq(far, 0, "%s: never moved past dark_spot_radius" % map_id)


func test_out_of_light_stays_on_the_floor_and_region_on_woodland() -> void:
	_sweep(MapData.load_map("woodland", PlayTuning.load_default().map_style, 3), "woodland")


func test_out_of_light_stays_on_the_floor_and_region_on_a_field_in_storeys() -> void:
	_sweep(TowerBlock.load_map(PlayTuning.load_default().map_style, 3), "Tower Block")
