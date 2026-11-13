extends GutTest
## The field layout (FC2; the browser game's content/mapChecks.test.ts, its layout half): FieldMeasure measures every
## field row of data/maps.md once, on its MapLevel's JoltQuery (the BBs' own ray) and its NavGrid, and FieldChecks.layout
## judges the figures, each field failing exactly its FieldStandard.KNOWN_FAILING layout checks and every field's overtime
## flag passing (OV1); then each check fails on its own fault in a copy of Depot's data, measured on a BoxWorld of its
## blocks.

var catalog: MapCatalog
var style: MapStyle
var tuning: SimTuning
## Each loaded field's measure and layout results, by id; the fields the game refuses, by id.
var measures: Dictionary[String, FieldMeasure] = {}
var results: Dictionary[String, Array] = {}
var refused: PackedStringArray = PackedStringArray()
## The old yard's own nav grid (DR1), for the faults that move a spawn or the flag but no block.
var depot_nav: NavGrid = null
## How long each field took to measure (s).
var took: Dictionary[String, float] = {}


func before_all() -> void:
	catalog = MapCatalog.read_file()
	style = PlayTuning.load_default().map_style
	tuning = SimTuning.load_default()
	for e in catalog.entries:
		if e.kind != &"field":
			continue
		var m := MapData.load_map(e.id, style, 1)
		if not m.ok():
			refused.append(e.id)
			continue
		var start := Time.get_ticks_usec()
		var nav := NavGrid.build(m, tuning.nav, tuning.body)
		var level := MapLevel.new()
		add_child(level)
		level.build(m, style, tuning.body)
		NavVaults.link(nav, level.query(), tuning.vault, tuning.body, BotConfig.load_default().vault_price)
		var measure := FieldMeasure.new(m, nav, level.query(), tuning.body)
		results[e.id] = FieldChecks.layout(measure, FieldStandard.sightline_limit(e.id),
				FieldStandard.sightline_reason(e.id))
		var summary := measure.summary()
		# Every figure is measured now: the level goes, and nothing can cast through it again.
		measure.world = null
		level.free()
		took[e.id] = (Time.get_ticks_usec() - start) / 1e6
		measures[e.id] = measure
		gut.p("%s (%s s): %s" % [e.id, FieldChecks.num(took[e.id]), summary])
	depot_nav = NavGrid.build(_depot(), tuning.nav, tuning.body)


func after_all() -> void:
	measures.clear()
	results.clear()
	depot_nav = null


## A fresh copy of the old yard's data (YardMap, Depot until DR1), to break.
func _depot() -> MapData:
	return YardMap.load_map(style, 1)


## The yard's ground floor alone: an open yard, every spawn in sight of every other.
func _open_yard() -> MapData:
	var m := _depot()
	var floors: Array[MapData.Block] = []
	for b in m.blocks:
		if b.kind == &"floor" and b.center.y < 0.0:
			floors.append(b)
	m.blocks = floors
	return m


## `m` measured on a BoxWorld of its blocks (ramps left out: no fault needs one), on `nav` or its own new nav grid.
func _measure(m: MapData, nav: NavGrid = null) -> FieldMeasure:
	var world := BoxWorld.new(tuning.body)
	for b in m.blocks:
		if b.rise == MapData.Rise.NONE:
			world.add_box(b.center, b.size, b.surface)
	var grid := nav if nav != null else NavGrid.build(m, tuning.nav, tuning.body)
	return FieldMeasure.new(m, grid, world, tuning.body)


## A wall block centred at `c`, `s` in size.
static func _wall(c: Vector3, s: Vector3) -> MapData.Block:
	var b := MapData.Block.new()
	b.kind = &"wall"
	b.center = c
	b.size = s
	return b


## The one result for `id` in `list`.
static func _only(list: Array[FieldChecks.Result], id: String) -> FieldChecks.Result:
	for r in list:
		if r.id == id:
			return r
	return null


func test_every_loaded_field_is_measured_and_refused_ones_are_not_yet() -> void:
	assert_true(results.has("depot"), "Depot is measured")
	assert_gt(results.size(), 1, "fields measured")
	for id in refused:
		assert_true(FieldStandard.NOT_YET.has(id), "%s is refused and not on NOT_YET" % id)
	var total := 0.0
	for id in took:
		total += took[id]
	gut.p("measuring %d fields took %s s" % [took.size(), FieldChecks.num(total)])


func test_every_field_fails_exactly_its_known_failing_layout_checks() -> void:
	for id in results:
		var list: Array[FieldChecks.Result] = []
		list.assign(results[id])
		for r in list:
			if r.status != FieldChecks.Status.PASS:
				gut.p("%s %s" % [id, r])
		var failing := FieldChecks.failing(list)
		var known := FieldStandard.known_failing(id, FieldStandard.LAYOUT)
		for check in failing:
			assert_true(known.has(check), "%s newly fails %s: %s" % [id, check, _only(list, check).text])
		for check in known:
			assert_true(failing.has(check), "%s passes %s now: take it off KNOWN_FAILING" % [id, check])
		assert_eq(failing, known, "%s fails exactly its known layout checks" % id)


func test_every_layout_check_runs_on_a_field_with_a_flag() -> void:
	var list: Array[FieldChecks.Result] = []
	list.assign(results["depot"])
	for id in FieldStandard.LAYOUT:
		assert_not_null(_only(list, id), id)


func test_no_level_is_left_in_the_tree() -> void:
	for child in get_children():
		assert_false(child is MapLevel, "a field's level is freed once measured")


func test_a_lane_run_backwards_fails_lane_walk() -> void:
	var m := _depot()
	var lane := m.lanes[0].duplicate()
	lane.reverse()
	m.lanes[0] = lane
	var r := FieldChecks.lane_walk(_measure(m, depot_nav))
	assert_eq(r.status, FieldChecks.Status.FAIL)
	assert_string_contains(r.text, "lane 1 does not run from end 0 towards end 1")


func test_a_lane_point_on_a_2_m_wall_fails_lane_walk() -> void:
	var m := _depot()
	m.blocks.append(_wall(Vector3(0, 1, 14), Vector3(1, 2, 1)))
	var lane := m.lanes[0].duplicate()
	lane.insert(2, Vector3(0, 2, 14))
	m.lanes[0] = lane
	var r := FieldChecks.lane_walk(_measure(m))
	assert_eq(r.status, FieldChecks.Status.FAIL)
	assert_string_contains(r.text, "lane 1 can't be walked from point 2 to 3")


func test_a_spawn_boxed_in_by_four_walls_fails_routes() -> void:
	var m := _depot()
	var s := m.ends[1].spawns[0].position
	m.blocks.append(_wall(s + Vector3(1, 1.5, 0), Vector3(0.3, 3, 2.3)))
	m.blocks.append(_wall(s + Vector3(-1, 1.5, 0), Vector3(0.3, 3, 2.3)))
	m.blocks.append(_wall(s + Vector3(0, 1.5, 1), Vector3(1.7, 3, 0.3)))
	m.blocks.append(_wall(s + Vector3(0, 1.5, -1), Vector3(1.7, 3, 0.3)))
	var r := FieldChecks.routes(_measure(m))
	assert_eq(r.status, FieldChecks.Status.FAIL)
	assert_string_contains(r.text, "end 1 spawn 1 can't reach the middle")


func test_depot_ground_floor_alone_fails_spawn_sight_and_sightline_but_an_80_m_exception_passes() -> void:
	var measure := _measure(_open_yard())
	var seen := FieldChecks.spawn_sight(measure)
	assert_eq(seen.status, FieldChecks.Status.FAIL)
	assert_string_contains(seen.text, "standing")
	var r := FieldChecks.sightline(measure, FieldStandard.LONGEST_SIGHTLINE, "")
	assert_eq(r.status, FieldChecks.Status.FAIL, r.text)
	assert_string_contains(r.text, "Depot's standard is 34 m")
	var allowed := FieldChecks.sightline(measure, 80.0, "test")
	assert_eq(allowed.status, FieldChecks.Status.PASS, allowed.text)
	assert_string_contains(allowed.text, "allowed up to 80 m: test")


func test_end_1_spawns_24_m_nearer_the_middle_fails_middle() -> void:
	var m := _depot()
	for s in m.ends[1].spawns:
		s.position.x -= 24.0
	var r := FieldChecks.middle(_measure(m, depot_nav))
	assert_eq(r.status, FieldChecks.Status.FAIL, r.text)
	assert_string_contains(r.text, "One end gets there first")


func test_the_flag_in_the_middle_fails_flag() -> void:
	var m := _depot()
	m.pole = Vector3(0, 0, 0.5)
	var r := FieldChecks.flag(_measure(m, depot_nav))
	assert_eq(r.status, FieldChecks.Status.FAIL, r.text)
	assert_string_contains(r.text, "need a head start")


func test_a_flag_in_sight_of_the_attackers_fails_flag() -> void:
	var m := _open_yard()
	var s := m.ends[1].spawns[0].position
	m.pole = Vector3(s.x - 4.0, 0, s.z)
	var r := FieldChecks.flag(_measure(m))
	assert_eq(r.status, FieldChecks.Status.FAIL, r.text)
	assert_string_contains(r.text, "can be seen from the attackers' spawn")


func test_every_fields_overtime_flag_passes() -> void:
	for id in results:
		var list: Array[FieldChecks.Result] = []
		list.assign(results[id])
		var r := _only(list, FieldStandard.OVERTIME_FLAG)
		assert_not_null(r, id)
		if r != null:
			gut.p("%s %s" % [id, r])
			assert_eq(r.status, FieldChecks.Status.PASS, "%s: %s" % [id, r.text])


func test_an_overtime_flag_by_one_end_fails_and_none_warns() -> void:
	var m := _depot()
	var s := m.ends[1].spawns[0].position
	m.overtime_flag = Vector3(s.x - 4.0, s.y, s.z)
	var r := FieldChecks.overtime_flag(_measure(m, depot_nav))
	assert_eq(r.status, FieldChecks.Status.FAIL, r.text)
	assert_string_contains(r.text, "One end gets there first")
	m.has_overtime_flag = false
	r = FieldChecks.overtime_flag(_measure(m, depot_nav))
	assert_eq(r.status, FieldChecks.Status.WARN, r.text)
	assert_string_contains(r.text, "a draw at once")


func test_an_overtime_flag_past_15_percent_fails_not_warns() -> void:
	var m := _depot()
	# Walk the spot towards end 1's spawns, half a metre at a time on floor that passes, until the ends' walks to it are
	# more than 15 % apart: in the middle check's warning band, the overtime flag's check fails.
	var c1 := Vector3.ZERO
	for s in m.ends[1].spawns:
		c1 += s.position / m.ends[1].spawns.size()
	var step := Vector3(c1.x - m.overtime_flag.x, 0.0, c1.z - m.overtime_flag.z).normalized() * 0.5
	var spread := 0.0
	var r: FieldChecks.Result = null
	for i in 60:
		m.overtime_flag += step
		var k := depot_nav.node_at(m.overtime_flag + Vector3.UP)
		if k < 0:
			continue
		m.overtime_flag.y = depot_nav.floor_y[k]
		if not FieldChecks.off_floor(m, depot_nav, "spot", m.overtime_flag).is_empty():
			continue
		var measure := _measure(m, depot_nav)
		var ow := measure.overtime_walks()
		var a := FieldMeasure.mean(ow[0])
		var b := FieldMeasure.mean(ow[1])
		spread = maxf(a, b) / minf(a, b) - 1.0
		if spread > FieldStandard.WALK_SPREAD:
			r = FieldChecks.overtime_flag(measure)
			break
	assert_between(spread, FieldStandard.WALK_SPREAD, FieldStandard.WALK_SPREAD_WARN, "in the middle's warning band")
	assert_not_null(r, "a spot past 15 % found")
	if r != null:
		assert_eq(r.status, FieldChecks.Status.FAIL, r.text)
		assert_string_contains(r.text, "more than 15 %")


func test_an_overtime_flag_off_the_floor_or_in_a_bush_fails() -> void:
	var m := _depot()
	m.overtime_flag += Vector3(0, 0.5, 0)
	var r := FieldChecks.overtime_flag(_measure(m, depot_nav))
	assert_eq(r.status, FieldChecks.Status.FAIL, r.text)
	assert_string_contains(r.text, "off the floor")
	m = _depot()
	m.foliage.add(m.overtime_flag, 1.5, 2.0)
	r = FieldChecks.overtime_flag(_measure(m, depot_nav))
	assert_eq(r.status, FieldChecks.Status.FAIL, r.text)
	assert_string_contains(r.text, "stands in a bush")
