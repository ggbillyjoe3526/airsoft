extends GutTest
## SM3: Subway's ticket hall and concourse models. A block names the way its model's front faces (`facing`: +x, -x,
## +z or -z), a bad one warned and the lay's own rule kept; FIT turns a facing model's front that way, its x across
## it; every hall model is in the config, loads, is laid somewhere on Subway and stands inside the box that names it;
## the platform benches sit with their backs to the wall and their seats to the track.

const HALL_MODELS: Array[StringName] = [
	&"ticket_gate", &"ticket_machine", &"kiosk", &"kiosk_long", &"ticket_office",
	&"booking_counter", &"help_point", &"station_bench", &"station_bench_long", &"crowd_barrier",
]

var play: PlayTuning = PlayTuning.load_default()
var tuning: SimTuning = SimTuning.new()


func _subway() -> MapData:
	var m := MapData.load_map("subway", play.map_style, tuning.rounds.team_size)
	assert_true(m.ok(), "Subway loads: %s" % [m.problems])
	return m


func _box(b: MapData.Block) -> AABB:
	return AABB(b.center - b.size * 0.5, b.size)


## `t` applied to `box`'s eight corners, as the box round them.
func _moved(t: Transform3D, box: AABB) -> AABB:
	var out := AABB(t * box.position, Vector3.ZERO)
	for i in 8:
		out = out.expand(t * box.get_endpoint(i))
	return out


func test_a_block_s_facing_is_read_and_a_bad_one_warned() -> void:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MapData.DIR + "depot.json"))
	var blocks: Array = d["blocks"]
	(blocks[0] as Dictionary)["facing"] = "+x"
	(blocks[1] as Dictionary)["facing"] = "up"
	var m := MapData.parse(JSON.stringify(d), play.map_style, 6)
	assert_true(m.ok(), "a bad facing never stops the map loading: %s" % [m.problems])
	assert_eq(m.blocks[0].facing, &"+x", "read")
	assert_eq(m.blocks[1].facing, &"", "a bad one dropped")
	assert_eq(m.blocks[2].facing, &"", "none named: empty")
	assert_eq(m.warnings.filter(func(w: String) -> bool: return w.contains("facing up")).size(), 1, "and warned")


func test_facing_turns_the_model_s_front_that_way_its_x_across_it() -> void:
	var b := MapData.Block.new()
	b.size = Vector3(0.6, 0.8, 2.0)
	for f: StringName in [&"+x", &"-x", &"+z", &"-z"]:
		var want := Vector3(1.0 if f == &"+x" else -1.0 if f == &"-x" else 0.0, 0.0,
				1.0 if f == &"+z" else -1.0 if f == &"-z" else 0.0)
		var front := Basis(Vector3.UP, PropLayout.facing_yaw(f)) * Vector3.BACK
		assert_almost_eq(front, want, Vector3.ONE * 1e-5, "front to %s" % f)
	b.facing = &"+x"
	assert_eq(PropLayout.facing_size(b), Vector3(2.0, 0.8, 0.6), "facing x: the model's x along the box's z")
	b.facing = &"-z"
	assert_eq(PropLayout.facing_size(b), b.size, "facing z: as the box")
	# fitted in the box either way, whatever the box's long side
	var model := AABB(Vector3(-1.0, 0.0, -0.3), Vector3(2.0, 0.8, 0.6))
	b.center = Vector3(5.0, 0.4, 3.0)
	b.facing = &"+x"
	var t := PropLayout.fit(model, Vector3(5.0, 0.0, 3.0), PropLayout.facing_size(b), PropLayout.facing_yaw(b.facing))
	var laid := _moved(t, model)
	assert_almost_eq(laid.position, _box(b).position, Vector3.ONE * 1e-4, "fills the box")
	assert_almost_eq(laid.size, b.size, Vector3.ONE * 1e-4, "exactly")


func test_every_hall_model_loads_and_is_laid_inside_its_box() -> void:
	var m := _subway()
	var props := play.site_look.props.named_only()
	var named: Dictionary[StringName, Array] = {}
	for b in m.blocks:
		if HALL_MODELS.has(b.dress):
			if not named.has(b.dress):
				named[b.dress] = []
			named[b.dress].append(_box(b).grow(0.01))
	var dress := PropDress.build(m, props)
	assert_not_null(dress, "Subway is dressed")
	if dress == null:
		return
	add_child_autofree(dress)
	for model in HALL_MODELS:
		assert_not_null(props.mesh_of(model), "%s loads" % model)
		assert_true(named.has(model), "a block names %s" % model)
		if props.mesh_of(model) == null or not named.has(model):
			continue
		var aabb := props.mesh_of(model).get_aabb()
		var placed: Array[Transform3D] = dress.placed()[model].transforms
		assert_eq(placed.size(), named[model].size(), "one %s a block" % model)
		for t in placed:
			var laid := _moved(t, aabb)
			var inside := named[model].any(func(box: AABB) -> bool: return box.encloses(laid))
			assert_true(inside, "%s at %s stands inside its box" % [model, laid])


func test_the_platform_benches_back_on_the_wall_and_seat_the_track() -> void:
	var m := _subway()
	var benches := 0
	for b in m.blocks:
		if b.dress != &"station_bench" or b.facing == &"":
			continue
		benches += 1
		# the platforms lie either side of z = 0, their walls inside and their tracks outside: seats face away from 0
		var out := signf(b.center.z)
		assert_eq(b.facing, &"+z" if out > 0.0 else &"-z", "the bench at %s faces its track" % b.center)
	assert_eq(benches, 6, "three a platform")


func _lone(kind: StringName, dress: StringName, size: Vector3, facing: StringName) -> PropLayout.Placed:
	var cfg := play.site_look.props
	var floor_b := MapData.Block.new()
	floor_b.kind = &"floor"
	floor_b.center = Vector3(0.0, -0.25, 0.0)
	floor_b.size = Vector3(60.0, 0.5, 60.0)
	var b := MapData.Block.new()
	b.kind = kind
	b.dress = dress
	b.center = Vector3(4.0, size.y * 0.5, -6.0)
	b.size = size
	b.facing = facing
	var m := MapData.new()
	m.id = "sm3 qa"
	m.blocks.append(floor_b)
	m.blocks.append(b)
	var boxes: Dictionary[StringName, AABB] = {}
	for model: StringName in cfg.models:
		var mesh := cfg.mesh_of(model)
		if mesh != null:
			boxes[model] = mesh.get_aabb()
	var out := PropLayout.layout(m, cfg, boxes)
	return out.get(dress) as PropLayout.Placed


func test_a_facing_on_a_non_fit_lay_is_ignored() -> void:
	var cfg := play.site_look.props
	var checked := 0
	for model: StringName in [&"crate", &"container"]:
		if cfg.lay_of(_dressed(model)) == PropDressConfig.Lay.FIT or cfg.mesh_of(model) == null:
			continue
		var plain := _lone(&"crate", model, Vector3(2.4, 1.2, 1.2), &"")
		var turned := _lone(&"crate", model, Vector3(2.4, 1.2, 1.2), &"-x")
		assert_not_null(plain, "%s laid" % model)
		if plain == null or turned == null:
			continue
		assert_eq(turned.transforms, plain.transforms, "%s: facing changes nothing off FIT" % model)
		checked += 1
	assert_gt(checked, 0, "a non-FIT model was exercised")


func _dressed(model: StringName) -> MapData.Block:
	var b := MapData.Block.new()
	b.dress = model
	return b


func test_a_facing_on_a_square_box_keeps_the_model_inside_it() -> void:
	var aabb := play.site_look.props.mesh_of(&"station_bench").get_aabb()
	for f: StringName in [&"+x", &"-x", &"+z", &"-z"]:
		var size := Vector3(1.0, 0.8, 1.0)
		var p := _lone(&"crate", &"station_bench", size, f)
		assert_not_null(p, "laid facing %s" % f)
		if p == null:
			continue
		var laid := _moved(p.transforms[0], aabb)
		var box := AABB(Vector3(4.0, 0.0, -6.0) - Vector3(size.x * 0.5, 0.0, size.z * 0.5), size).grow(0.01)
		assert_true(box.encloses(laid), "square box, facing %s: %s" % [f, laid])
		var front := p.transforms[0].basis * Vector3.BACK
		front.y = 0.0
		assert_almost_eq(front.normalized(), Basis(Vector3.UP, PropLayout.facing_yaw(f)) * Vector3.BACK,
				Vector3.ONE * 1e-4, "front %s" % f)


func test_an_empty_facing_still_turns_a_fit_model_to_the_field_middle() -> void:
	# regression: the long side stays the box's long side, as before facing existed
	var p := _lone(&"crate", &"station_bench", Vector3(3.0, 0.8, 0.6), &"")
	assert_not_null(p)
	if p == null:
		return
	var laid := _moved(p.transforms[0], play.site_look.props.mesh_of(&"station_bench").get_aabb())
	assert_almost_eq(laid.size.x, 3.0, 1e-3, "long side along x")
	assert_almost_eq(laid.size.z, 0.6, 1e-3, "short side across")


func test_depot_and_woodland_name_no_facing() -> void:
	for id: String in ["depot", "woodland"]:
		var m := MapData.load_map(id, play.map_style, 6)
		if not m.ok():
			continue
		for b in m.blocks:
			assert_eq(b.facing, &"", "%s block %s: no facing" % [id, b.kind])


## The gate lanes between Subway's ticket gates: [lane middle (on the floor), its width] each.
func _lanes(m: MapData) -> Array:
	var gates: Array[MapData.Block] = []
	for b in m.blocks:
		if b.dress == &"ticket_gate":
			gates.append(b)
	var out: Array = []
	for a in gates:
		for b in gates:
			var gap := b.center.z - a.center.z - (a.size.z + b.size.z) * 0.5
			var space := AABB(Vector3(a.center.x - 0.6, a.center.y - 0.4, a.center.z + a.size.z * 0.5 + 0.05),
					Vector3(1.2, 0.8, maxf(gap - 0.1, 0.0)))
			var open := m.blocks.all(func(o: MapData.Block) -> bool:
				return o == a or o == b or not AABB(o.center - o.size * 0.5, o.size).intersects(space))
			if gap > 0.0 and gap < 1.5 and is_equal_approx(a.center.x, b.center.x) and open:
				out.append([Vector3(a.center.x, a.center.y - a.size.y * 0.5, a.center.z + a.size.z * 0.5 + gap * 0.5),
						gap])
	return out


func test_the_gate_lanes_are_one_person_wide_and_every_one_walkable() -> void:
	var m := _subway()
	var lanes := _lanes(m)
	assert_eq(lanes.size(), 12, "six lanes either side of the hall's column")
	var nav := NavGrid.build(m, tuning.nav, tuning.body)
	for lane: Array in lanes:
		var mid: Vector3 = lane[0]
		var w: float = lane[1]
		assert_lt(w, 2.0 * tuning.body.radius * 1.6, "the lane at z %.2f is one body wide (%.2f m)" % [mid.z, w])
		assert_gt(w, 2.0 * (tuning.body.radius + tuning.nav.clearance_margin), "and a body fits it")
		var walkable := false
		var z := mid.z - w * 0.5
		while z < mid.z + w * 0.5 and not walkable:
			walkable = nav.is_walkable_at(Vector3(mid.x, mid.y, z))
			z += 0.05
		assert_true(walkable, "bots can walk the lane at z %.2f" % mid.z)


func test_each_lane_has_a_paddle_each_side_shut_across_it() -> void:
	var m := _subway()
	var g := GatePaddles.build(m, play.gate_paddles)
	assert_not_null(g, "Subway's gates get paddles")
	if g == null:
		return
	add_child_autofree(g)
	assert_eq(g.count(), 24, "two a lane")
	var tip_x := PropDressConfig.load_mesh(play.gate_paddles.paddle_path).get_aabb().end.x
	for i in g.count():
		assert_eq(g.open_of(i), 0.0, "shut at the start")
		var tip := g.paddle_at(i) * Vector3(tip_x, 0.0, 0.0)
		var lane := g.lane_of(i)
		assert_almost_eq(Vector2(tip.x, tip.z).distance_to(Vector2(lane.x, lane.z)),
				play.gate_paddles.middle_gap * 0.5, 0.01, "paddle %d reaches the lane's middle" % i)
	assert_null(GatePaddles.build(MapData.load_map("depot", play.map_style, 6), play.gate_paddles), "Depot has none")


func test_a_lane_s_paddles_swing_open_as_someone_walks_up_and_shut_behind() -> void:
	var m := _subway()
	var g := GatePaddles.build(m, play.gate_paddles)
	add_child_autofree(g)
	var c := Character.new()
	c.position = g.lane_of(0) + Vector3(-1.0, 0.0, 0.0)
	var people: Array[Character] = [c]
	var swing := play.gate_paddles.swing_time
	g.refresh(people, swing * 0.5)
	var mine: Array[int] = []
	for i in g.count():
		if g.lane_of(i).is_equal_approx(g.lane_of(0)):
			mine.append(i)
	assert_eq(mine.size(), 2, "the lane's two paddles")
	assert_almost_eq(g.open_of(mine[0]), 0.5, 0.001, "half open half way through the swing")
	g.refresh(people, swing)
	for i in g.count():
		assert_eq(g.open_of(i), 1.0 if mine.has(i) else 0.0, "paddle %d: only the lane walked up to opens" % i)
	for i in mine:
		var along := g.paddle_at(i).basis * Vector3.RIGHT
		assert_almost_eq(along.normalized(), Vector3.RIGHT, Vector3.ONE * 1e-4, "folded back the way in")
	c.position = g.lane_of(0) + Vector3(-5.0, 0.0, 0.0)
	g.refresh(people, swing)
	for i in mine:
		assert_eq(g.open_of(i), 0.0, "shut once nobody is near")
	c.position = g.lane_of(0) + Vector3(0.0, -9.0, 0.0)
	g.refresh(people, swing)
	assert_eq(g.open_of(mine[0]), 0.0, "someone a floor away doesn't open it")
