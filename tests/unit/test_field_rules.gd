extends GutTest
## The field rules (FC1; the browser game's content/mapChecks.test.ts): FieldChecks run on every field row of
## data/maps.md, each field failing exactly its FieldStandard.KNOWN_FAILING checks (a refused file only if NOT_YET names
## it), the lists themselves well formed, and each rule failing on its own fault in a copy of Depot's data.

var catalog: MapCatalog
var style: MapStyle
var teams: Array[Color] = []
var tuning: SimTuning
## Each field's map, nav grid (none for a refused file) and results, by id.
var maps: Dictionary[String, MapData] = {}
var navs: Dictionary[String, NavGrid] = {}
var results: Dictionary[String, Array] = {}
## The old yard's nav grid (DR1): the rules broken one at a time on its layout.
var yard_nav: NavGrid = null


func before_all() -> void:
	catalog = MapCatalog.read_file()
	style = PlayTuning.load_default().map_style
	teams = AccessibilityTable.read_file().colours
	tuning = SimTuning.load_default()
	for e in catalog.entries:
		if e.kind != &"field":
			continue
		var m := MapData.load_map(e.id, style, 1)
		maps[e.id] = m
		var nav: NavGrid = NavGrid.build(m, tuning.nav, tuning.body) if m.ok() else null
		navs[e.id] = nav
		results[e.id] = FieldChecks.run(e, m, nav, style, teams, FieldStandard.allowed_clashes(e.id))
	yard_nav = NavGrid.build(_depot(), tuning.nav, tuning.body)


func after_all() -> void:
	maps.clear()
	navs.clear()
	results.clear()


## A fresh copy of the old yard's data (YardMap, Depot until DR1), to break.
func _depot() -> MapData:
	return YardMap.load_map(style, 1)


## The one result for `id` in `list`.
static func _only(list: Array[FieldChecks.Result], id: String) -> FieldChecks.Result:
	for r in list:
		if r.id == id:
			return r
	return null


func test_there_are_fields_to_check_and_depot_is_one() -> void:
	assert_gt(results.size(), 1, "fields read from data/maps.md")
	assert_true(results.has("depot"), "Depot is a field row")


func test_every_field_fails_exactly_its_known_failing_checks() -> void:
	for id in results:
		var list: Array[FieldChecks.Result] = []
		list.assign(results[id])
		for r in list:
			if r.status != FieldChecks.Status.PASS:
				gut.p("%s %s" % [id, r])
		if not maps[id].ok():
			assert_true(FieldStandard.NOT_YET.has(id), "%s is refused and not on NOT_YET: %s" % [id, list[0].text])
			continue
		assert_false(FieldStandard.NOT_YET.has(id), "%s loads now: take it off NOT_YET" % id)
		var failing := FieldChecks.failing(list)
		var known := FieldStandard.known_failing(id, FieldStandard.RULES)
		for check in failing:
			assert_true(known.has(check), "%s newly fails %s: %s" % [id, check, _only(list, check).text])
		for check in known:
			assert_true(failing.has(check), "%s passes %s now: take it off KNOWN_FAILING" % [id, check])


func test_the_lists_name_fields_and_checks_with_reasons_and_steps() -> void:
	for id in FieldStandard.KNOWN_FAILING:
		assert_true(results.has(id), "KNOWN_FAILING names %s, not a field row" % id)
		for item: Dictionary in FieldStandard.KNOWN_FAILING[id]:
			assert_true(FieldStandard.CHECKS.has(item.get("check", "")), "%s: %s is not a check" % [id, item])
			assert_false(str(item.get("reason", "")).is_empty(), "%s: a reason" % id)
			assert_false(str(item.get("step", "")).is_empty(), "%s: the step that clears it" % id)
	for id in FieldStandard.NOT_YET:
		assert_true(results.has(id), "NOT_YET names %s, not a field row" % id)
		assert_false(str(FieldStandard.NOT_YET[id].get("step", "")).is_empty(), "%s: the step that makes it load" % id)
	for id in FieldStandard.EXCEPTIONS:
		assert_true(results.has(id), "EXCEPTIONS names %s, not a field row" % id)
		var e: Dictionary = FieldStandard.EXCEPTIONS[id]
		if e.has("clashes"):
			assert_false(str(e.get("clash_reason", "")).is_empty(), "%s: the clashes' reason" % id)
		if e.has("sightline"):
			assert_false(str(e.get("sightline_reason", "")).is_empty(), "%s: the sightline's reason" % id)


func test_depot_passes_every_rule_its_faults_break() -> void:
	var list: Array[FieldChecks.Result] = []
	list.assign(results["depot"])
	for id in FieldStandard.RULES:
		var r := _only(list, id)
		assert_not_null(r, id)
		if r != null:
			assert_eq(r.status, FieldChecks.Status.PASS, str(r))


func test_a_field_with_no_blurb_or_a_refused_file_fails_registered() -> void:
	var e := MapCatalog.Entry.new()
	e.id = "depot"
	e.display_name = "Depot"
	var r := FieldChecks.registered(e, _depot())
	assert_eq(r.status, FieldChecks.Status.FAIL)
	assert_string_contains(r.text, "a blurb")
	e.blurb = "A yard."
	var refused := MapData.parse("{}", style, 1)
	r = FieldChecks.registered(e, refused)
	assert_eq(r.status, FieldChecks.Status.FAIL)
	assert_string_contains(r.text, "is refused: no blocks")
	assert_eq(FieldChecks.run(e, refused, null, style, teams, PackedStringArray()).size(), 1, "nothing else runs")


func test_an_end_short_of_the_largest_team_fails_room() -> void:
	var m := _depot()
	m.ends[1].dead_zone.resize(2)
	var r := FieldChecks.room(m)
	assert_eq(r.status, FieldChecks.Status.FAIL)
	assert_string_contains(r.text, "end 1 has 2 dead-zone spots")


func test_a_spawn_lifted_half_a_metre_fails_on_floor() -> void:
	var m := _depot()
	var p := m.ends[0].spawns[0].position
	m.ends[0].spawns[0].position = p + Vector3(0, 0.5, 0)
	var r := FieldChecks.on_floor(m, yard_nav)
	assert_eq(r.status, FieldChecks.Status.FAIL)
	assert_string_contains(r.text, "end 0 spawn 1 at %s is 0.5 m off the floor" % FieldChecks.at(p + Vector3(0, 0.5, 0)))


func test_each_field_reads_its_overtime_flag_and_one_lifted_fails_on_floor() -> void:
	for id in maps:
		assert_true(maps[id].has_overtime_flag, "%s has a spot for the overtime flag" % id)
	var m := _depot()
	assert_eq(m.overtime_flag, Vector3(2.0, 0.0, 1.6), "the yard's spot, as in its file")
	assert_false(MapData.load_map("range", style, 1).has_overtime_flag, "the range has none")
	m.overtime_flag += Vector3(0, 0.5, 0)
	var r := FieldChecks.on_floor(m, yard_nav)
	assert_eq(r.status, FieldChecks.Status.FAIL)
	assert_string_contains(r.text, "the overtime flag at %s is 0.5 m off the floor" % FieldChecks.at(m.overtime_flag))


func test_each_field_hosts_plant_the_bomb_and_a_site_lifted_fails_on_floor() -> void:
	for id in maps:
		var f := maps[id]
		assert_eq(f.bomb_sites.size(), Plant.MOST, "%s names both bomb sites" % id)
		assert_eq(f.bomb_site_radii.size(), f.bomb_sites.size(), "%s: a radius a site" % id)
		var start := f.bomb_start_ahead(tuning.plant.start_ahead)
		var home := f.ends[1].spawns[0].position
		for i in f.bomb_sites.size():
			var site := f.bomb_sites[i]
			assert_lt(site.distance_to(home), site.distance_to(start),
					"%s: site %s is on the defenders' side" % [id, Plant.LETTERS[i]])
		if f.bomb_sites.size() == Plant.MOST:
			var apart := f.bomb_sites[0].distance_to(f.bomb_sites[1])
			var widest := maxf(f.bomb_site_radii[0], f.bomb_site_radii[1])
			assert_gt(apart, 2.0 * maxf(widest, tuning.plant.site_radius), "%s: the sites do not overlap" % id)
		assert_eq(_only(results[id], FieldStandard.ON_FLOOR).status, FieldChecks.Status.PASS,
				"%s: sites and the bomb's start on walkable floor" % id)
	var m := MapData.load_map("depot", style, 1)
	m.bomb_sites[1] += Vector3(0, 0.5, 0)
	var r := FieldChecks.on_floor(m, navs["depot"])
	assert_eq(r.status, FieldChecks.Status.FAIL)
	assert_string_contains(r.text, "bomb site B at %s is 0.5 m off the floor" % FieldChecks.at(m.bomb_sites[1]))


func test_a_ramp_of_one_in_one_and_a_half_fails_ramps() -> void:
	var m := _depot()
	var ramp: MapData.Block = null
	for b in m.blocks:
		if b.rise != MapData.Rise.NONE:
			ramp = b
			break
	assert_not_null(ramp, "Depot has a ramp")
	if ramp == null:
		return
	var along_x := ramp.rise == MapData.Rise.POS_X or ramp.rise == MapData.Rise.NEG_X
	ramp.size.y = (ramp.size.x if along_x else ramp.size.z) / 1.5
	var r := FieldChecks.ramps(m)
	assert_eq(r.status, FieldChecks.Status.FAIL)
	assert_string_contains(r.text, "rises 1:1.5")


func test_kill_y_at_zero_fails_kill_y() -> void:
	var m := _depot()
	m.kill_y = 0.0
	var r := FieldChecks.kill_y(m)
	assert_eq(r.status, FieldChecks.Status.FAIL)
	assert_string_contains(r.text, "(0 m)")


func test_a_crate_moved_a_tenth_into_another_fails_blocks_and_a_stale_exception_warns() -> void:
	var m := _depot()
	var crates: Array[MapData.Block] = []
	for b in m.blocks:
		if b.kind == &"crate":
			crates.append(b)
	assert_gt(crates.size(), 1, "Depot has two crates")
	if crates.size() < 2:
		return
	var a := crates[0]
	var b := crates[1]
	a.center = b.center + Vector3((a.size.x + b.size.x) * 0.5 - 0.1, (a.size.y - b.size.y) * 0.5, 0)
	var found := FieldChecks.blocks(m, PackedStringArray())
	assert_eq(found.size(), 1)
	assert_eq(found[0].status, FieldChecks.Status.FAIL)
	var pair := "%s and %s" % [FieldChecks.where(a), FieldChecks.where(b)] # crates[0] comes first in the blocks
	assert_string_contains(found[0].text, pair)
	var allowed := FieldChecks.blocks(m, PackedStringArray([pair]))
	assert_eq(allowed[0].status, FieldChecks.Status.PASS, "a listed pair passes")
	var stale := FieldChecks.blocks(_depot(), PackedStringArray([pair]))
	assert_eq(stale.size(), 2)
	assert_eq(stale[0].status, FieldChecks.Status.PASS)
	assert_eq(stale[1].status, FieldChecks.Status.WARN, "a listed pair no longer there warns")
	assert_string_contains(stale[1].text, pair)


func test_seams_up_to_the_slack_are_not_clashes() -> void:
	var m := _depot()
	var crates: Array[MapData.Block] = []
	for b in m.blocks:
		if b.kind == &"crate":
			crates.append(b)
	assert_gt(crates.size(), 1, "Depot has two crates")
	if crates.size() < 2:
		return
	var a := crates[0]
	var b := crates[1]
	a.center = b.center + Vector3((a.size.x + b.size.x) * 0.5 - FieldStandard.SEAM_SLACK * 0.8, 0, 0)
	assert_eq(FieldChecks.blocks(m, PackedStringArray())[0].status, FieldChecks.Status.PASS)


func test_a_kind_coloured_team_orange_fails_team_colour() -> void:
	var orange := MapStyle.new()
	orange.colours = style.colours.duplicate()
	orange.container_colours = style.container_colours.duplicate()
	orange.colours[&"crate"] = AccessibilityTable.BUILT_IN_COLOURS[1]
	var r := FieldChecks.team_colour(_depot(), orange, teams)
	assert_eq(r.status, FieldChecks.Status.FAIL)
	assert_string_contains(r.text, "the crate #fa8c29")
	assert_eq(FieldChecks.team_colour(_depot(), style, teams).status, FieldChecks.Status.PASS)


func test_every_container_colour_is_checked() -> void:
	var slate := MapStyle.new()
	slate.colours = style.colours.duplicate()
	slate.container_colours = style.container_colours.duplicate()
	slate.container_colours[3] = AccessibilityTable.BUILT_IN_COLOURS[0]
	var r := FieldChecks.team_colour(_depot(), slate, teams)
	assert_eq(r.status, FieldChecks.Status.FAIL)
	assert_string_contains(r.text, "the container 4 #3b87f5")


func test_the_colour_rule_is_hsl_on_linear_rgb_as_the_browser_measured() -> void:
	for near: String in ["3d6ea8", "f07c2a", "8c5b3e", "3b87f5", "b8460c"]:
		assert_true(FieldChecks.reads_as_team(Color(near), teams), near)
	for far: String in ["7a7a7a", "4f8a3c", "d9d3c8"]:
		assert_false(FieldChecks.reads_as_team(Color(far), teams), far)
	# A dark brown near orange's hue: saturated as HSV reads it, under the rule as HSL does.
	var brown := Color(0.25, 0.22, 0.19)
	assert_gt(brown.srgb_to_linear().s, FieldStandard.MIN_SATURATION, "HSV calls it saturated")
	assert_lt(FieldChecks.hue_gap(brown, teams), FieldStandard.HUE_MARGIN_DEG, "near a team's hue")
	assert_false(FieldChecks.reads_as_team(brown, teams), "HSL saturation %.3f" % FieldChecks.hue_saturation(brown).y)


func test_a_walkable_spot_in_no_area_fails_areas() -> void:
	var m := _depot()
	var nav := yard_nav
	var spot := Vector3.INF
	for k in nav.node_count():
		if nav.walkable[k] == 1:
			spot = nav.node_position(k)
			break
	var kept: Array[MapAreas.Area] = []
	for a in m.areas:
		if MapAreas.area_at([a] as Array[MapAreas.Area], spot).is_empty():
			kept.append(a)
	m.areas = kept
	var r := FieldChecks.areas(m, nav)
	assert_eq(r.status, FieldChecks.Status.FAIL)
	assert_string_contains(r.text, FieldChecks.at(spot))


func test_a_name_holding_no_walkable_spot_fails_areas() -> void:
	var m := _depot()
	var nowhere := MapAreas.Area.new()
	nowhere.name = "Nowhere"
	nowhere.x0 = 500.0
	nowhere.x1 = 510.0
	nowhere.z0 = 500.0
	nowhere.z1 = 510.0
	m.areas.append(nowhere)
	var r := FieldChecks.areas(m, yard_nav)
	assert_eq(r.status, FieldChecks.Status.FAIL)
	assert_string_contains(r.text, "Nowhere")


func test_one_lane_fails_and_two_warn() -> void:
	var m := _depot()
	m.lanes.resize(2)
	assert_eq(FieldChecks.lanes(m).status, FieldChecks.Status.WARN)
	m.lanes.resize(1)
	var r := FieldChecks.lanes(m)
	assert_eq(r.status, FieldChecks.Status.FAIL)
	assert_string_contains(r.text, "1 lane:")
