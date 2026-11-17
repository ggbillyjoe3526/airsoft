extends GutTest
## SW2: the owner's 0.1 Beta 2 playtest of Subway (2026-11-17). The running tunnels go on round a bend out of sight
## behind a steel grille, met at their old end walls; the north platform runs level to its end (no ramp); the spiral
## stair's slit and the space under its flights are walled; the ticket hall has more benches; no poster stands in
## front of a lift's doors.

var play: PlayTuning = PlayTuning.load_default()
var map: MapData = null


func before_all() -> void:
	map = MapData.load_map("subway", play.map_style, SimTuning.new().rounds.team_size)


func _block_box(b: MapData.Block) -> AABB:
	return AABB(b.center - b.size * 0.5, b.size)


func _bent() -> Array[StationDressing.TunnelVault]:
	var out: Array[StationDressing.TunnelVault] = []
	for v in map.station.vaults:
		if v.bend != null:
			out.append(v)
	return out


func test_both_running_tunnels_bend_away_from_each_other() -> void:
	assert_true(map.ok(), "Subway loads: %s" % [map.problems])
	var bent := _bent()
	assert_eq(bent.size(), 2, "the two running tunnels, no other vault")
	var turns: Array[float] = []
	for v in bent:
		assert_almost_eq(v.area.end.x, 82.0, 1e-3, "it bends on from the old end wall")
		assert_almost_eq(v.bend.radius, 40.0, 1e-3)
		assert_almost_eq(v.bend.angle, deg_to_rad(60.0), 1e-4)
		assert_almost_eq(v.bend.floor_y, 0.0, 1e-3, "on the track bed")
		var track := v.area.get_center().y + v.bend.track
		assert_almost_eq(absf(track), 10.75, 1e-3, "its track carries on round it")
		turns.append(v.bend.turn * signf(v.area.get_center().y))
	assert_eq(turns, [1.0, 1.0] as Array[float], "each turns outwards, away from the other")


func test_each_bend_is_shut_by_its_old_end_wall_and_a_grille() -> void:
	for v in _bent():
		var shut := v.shut_end()
		var walls := 0
		for b in map.blocks:
			if shut.encloses(_block_box(b)) and b.kind == &"wall":
				walls += 1
				assert_true(map.station.in_vault(_block_box(b)), "the end wall is met, not drawn: the bend shows")
		assert_gt(walls, 0, "a wall still stops bodies and BBs at %.0f" % v.area.end.x)
		var grilles := 0
		for f in map.station.fixtures:
			if f.model == &"tunnel_grille" and absf(f.position.x - v.area.end.x) < 1e-3 \
					and absf(f.position.z - v.area.get_center().y) < 1e-3:
				grilles += 1
				assert_almost_eq(f.yaw, deg_to_rad(-90.0), 1e-3, "facing back along the tunnel")
				assert_almost_eq(f.position.y, v.bend.floor_y, 1e-3, "on the track bed")
		assert_eq(grilles, 1, "one grille at its end")


func test_the_grille_fills_the_arch_and_stays_inside_it() -> void:
	var mesh := PropDressConfig.load_mesh(play.station_fixtures.path_of(&"tunnel_grille"))
	assert_not_null(mesh, "the grille's model loads")
	if mesh == null:
		return
	var box := mesh.get_aabb()
	var v := _bent()[0]
	var half := v.area.size.y * 0.5
	assert_almost_eq(box.size.x, half * 2.0 - 0.02, 0.005, "wall to wall across, 10 mm in")
	assert_almost_eq(box.end.y, v.y + v.rise - v.bend.floor_y - 0.01, 0.005, "up to the crown, 10 mm under")
	assert_almost_eq(box.position.z, 0.0, 1e-3, "its back on the end wall")


func test_each_bend_has_lamps_on_its_outer_wall() -> void:
	for v in _bent():
		var c := v.area.get_center()
		# the bend's middle: the curve's centre, radius m across from the tunnel's middle at its start
		var centre := Vector2(v.area.end.x, c.y + v.bend.turn * v.bend.radius)
		var lamps := 0
		for f in map.station.fixtures:
			if f.model != &"tunnel_lamp" or f.position.x <= v.area.end.x:
				continue
			var p := Vector2(f.position.x, f.position.z)
			if absf(p.distance_to(centre) - (v.bend.radius + v.area.size.y * 0.5)) < 0.01:
				lamps += 1
		assert_eq(lamps, 2, "two lamps light the curve away")


func test_the_surface_draws_each_bend_past_its_end() -> void:
	var mesh := StationSurface.mesh(map, play.map_style, play.station_look, play.site_look.props.named_only())
	var past := 0
	for s in mesh.get_surface_count():
		var verts: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		for p in verts:
			if p.x > 82.5:
				past += 1
	assert_gt(past, 500, "walls, arch, floor and rails swept round each bend")


func test_the_north_platform_is_level_to_its_end() -> void:
	for x: float in [-50.0, 0.0, 40.0, 45.0, 49.5]:
		assert_almost_eq(map.floor_under(x, -7.0, 3.0), 0.9, 1e-3, "the platform's floor at x %.1f" % x)
	for b in map.blocks:
		if b.rise != MapData.Rise.NONE and b.center.z < -5.5 and b.center.z > -9.0 and b.center.x > 40.0:
			fail_test("a ramp still on the north platform's end at %s" % b.center)


func test_the_ticket_hall_has_more_benches() -> void:
	var benches := 0
	for b in map.blocks:
		if b.dress == &"station_bench_long" and b.center.y > 8.0:
			benches += 1
	assert_gte(benches, 4, "the hall's new benches (owner, 2026-11-17)")


func test_no_wall_model_stands_in_front_of_a_lift_door() -> void:
	var boxes: Dictionary[StringName, AABB] = {}
	for f in map.station.fixtures:
		if not boxes.has(f.model):
			boxes[f.model] = PropDressConfig.load_mesh(play.station_fixtures.path_of(f.model)).get_aabb()
	var bad: Array[String] = []
	for lift in map.lifts:
		for k in lift.stops.size():
			# the doorway through the wall, a hand wider either side and out past its face
			var size := lift.door_size() + (Vector3(0.6, 0.0, 0.2) if lift.along_x() else Vector3(0.2, 0.0, 0.6))
			var door := AABB(lift.door_center(k) - size * 0.5, size)
			for f in map.station.fixtures:
				var t := Transform3D(Basis(Vector3.UP, f.yaw).scaled(Vector3.ONE * f.scale), f.position)
				if door.intersects(t * boxes[f.model]):
					bad.append("%s at %s" % [f.model, f.position])
	assert_eq(bad, [] as Array[String], "the lifts' doors are clear")


func test_no_one_gets_under_the_spiral_stair_s_flights() -> void:
	# The owner, 2026-11-17: "at the bottom level there is an open space under the stairs, block this off". From the
	# platform by the stair's foot, the floor under its flights is out of reach on foot; the stair itself is not.
	var nav := NavGrid.build(map, SimTuning.new().nav, SimTuning.new().body)
	var route := PackedVector3Array()
	var platform := Vector3(-28.7, 0.9, 7.0)
	for under: Vector3 in [Vector3(-29.0, 0.9, 3.0), Vector3(-31.5, 0.9, 1.5)]:
		assert_almost_eq(map.floor_under(under.x, under.z, 1.2), 0.9, 1e-3, "the well's floor under the flights")
		assert_false(nav.find_route(platform, under, route), "no way in under the flights to %s" % under)
	assert_true(nav.find_route(platform, Vector3(-32.5, 1.9, 4.5), route), "up the stair's first flight")


func test_the_cars_stand_clear_of_the_tunnel_lining() -> void:
	# The owner, 2026-11-17: "tunnel wall is glitching around the train": the cars' sides stood flush with the lining
	# drawn at their box's edge, and the two fought. Every car model now stands at least 2.5 cm inside it.
	var look := play.station_look.trains
	assert_gt(map.trains.size(), 0)
	for path in look.paths():
		var mesh := look.mesh(path)
		if mesh == null:
			continue
		for t in map.trains:
			assert_lte(maxf(mesh.get_aabb().end.z, -mesh.get_aabb().position.z), t.box.size.z * 0.5 - 0.025,
					"%s inside the lining" % path)


func test_the_mouths_and_the_platform_ends_are_backed_where_the_wall_stops() -> void:
	# SW2, the critic's thin dark line round the south mouth: a tunnel's end and a mouth's face stand vault_proud in
	# front of the shell, whose wall over the edge is the vault's and undrawn; a strip in the wall's own plane backs it.
	var look := play.station_look
	assert_gt(look.vault_backing, 0.0)
	var mesh := StationSurface.mesh(map, play.map_style, look, play.site_look.props.named_only())
	var mouth := 0
	var end := 0
	for s in mesh.get_surface_count():
		var verts: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		for p in verts:
			if absf(p.x - 50.0) > 1e-4:
				continue
			if p.z >= 9.0 - 1e-4 and p.z <= 9.0 + look.vault_backing + 1e-4 and p.y >= 2.7 - 1e-4 and p.y <= 4.1 + 1e-4:
				mouth += 1
			if p.z > 5.5 - 1e-4 and p.z < 12.5 + 1e-4 and absf(p.y - (4.1 + look.vault_backing)) < 1e-4:
				end += 1
	assert_gt(mouth, 0, "the south mouth's side backed in the wall's plane")
	assert_gt(end, 0, "the south platform's end backed over its springing")


func test_the_cab_fronts_and_outer_ends_have_no_holes_in_their_faces() -> void:
	# SW2, the critic's slivers up the cab's mask: the face beside the glass was cut away where the car's outline steps
	# in at the roof (clip() took each edge's whole line), and the rim's round showed through. Looking straight at a
	# front, no ray may pass the face (a hit near the car's inside at x 0) where the face goes on further out. The open
	# cab's doorway (1.2 m, train.py CAB_DOOR_HW) is open on purpose.
	var look := play.station_look.trains
	for key: StringName in [&"cab", &"cab_open", &"outer"]:
		var doorway := 0.61 if key == &"cab_open" else 0.0
		var faces := look.mesh(look.ends[key]).get_faces()
		var holes := 0
		for row in 23:
			var y := 0.2 + row * 0.1
			var tris := PackedVector3Array()
			for i in range(0, faces.size(), 3):
				var a := faces[i]
				var b := faces[i + 1]
				var c := faces[i + 2]
				if minf(a.y, minf(b.y, c.y)) <= y and maxf(a.y, maxf(b.y, c.y)) >= y and maxf(a.x, maxf(b.x, c.x)) > 0.02:
					tris.append_array([a, b, c])
			for side: float in [-1.0, 1.0]:
				var face_further_out := false
				for k in range(172, -1, -1):
					var hit_x := _front_hit(tris, y, side * k * 0.01)
					if hit_x > 0.1:
						face_further_out = true
					elif hit_x < 0.03 and face_further_out and k * 0.01 > doorway:
						holes += 1
						gut.p("%s: a hole at y %.2f z %.2f" % [key, y, side * k * 0.01])
		assert_eq(holes, 0, "%s's face is whole" % key)


func _front_hit(tris: PackedVector3Array, y: float, z: float) -> float:
	# the x of the first face met looking at the front (from +x) at (y, z); -INF where the ray meets nothing
	var best := -INF
	for i in range(0, tris.size(), 3):
		var hit: Variant = Geometry3D.ray_intersects_triangle(Vector3(1.0, y, z), Vector3.LEFT, tris[i], tris[i + 1],
				tris[i + 2])
		if hit != null and (hit as Vector3).x > best:
			best = (hit as Vector3).x
	return best
