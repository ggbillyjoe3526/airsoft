extends GutTest
## MT3: Kingsmere's station dress in CC0 photo sets. The map file names its rooms' styles, strips and tracks; every
## finish names a set baked into both texture arrays; each face takes the finish of the room it faces (the hall's
## terrazzo, tiles and plaster, the platforms' concrete, the tunnels' lining, the escalators' tread, the trains' paint)
## or its cover kind's; the level draws one mesh in one material, its colliders exactly the greybox's and no prop models
## in its boxes; the strips lie on the platforms and the rails on the track bed, low enough to walk over; Low drops
## the relief; no tint reads as a team; a malformed dress is warned about; the other maps have none.

var play: PlayTuning = PlayTuning.load_default()
var tuning: SimTuning = SimTuning.new()
var look: StationLook = null


func before_each() -> void:
	look = play.station_look


func _map(id: String) -> MapData:
	var m := MapData.load_map(id, play.map_style, 1 if id == "range" else tuning.rounds.team_size)
	assert_true(m.ok(), "%s loads: %s" % [id, m.problems])
	return m


func _level(m: MapData, station: StationLook) -> MapLevel:
	var level := MapLevel.new()
	add_child_autofree(level)
	level.build(m, play.map_style, tuning.body, play.baked_light, LightingConfig.for_map(play.lighting, null, m,
			LightingConfig.DAY), false, play.site_look, station)
	return level


## The face of a block lying in the plane through `p` facing `n` and holding `p`, as [block, face]; [] for none.
func _face_at(m: MapData, p: Vector3, n: Vector3) -> Array:
	for b in m.blocks:
		for f in GreyboxFaces.faces_of(b):
			var fn := GreyboxFaces.face_normal(f)
			if fn.dot(n) < 0.99 or absf((p - f[0]).dot(fn)) > 0.02:
				continue
			var box := AABB(f[0], Vector3.ZERO)
			for q in f:
				box = box.expand(q)
			if box.grow(0.01).has_point(p):
				return [b, f]
	return []


func _finish_at(m: MapData, p: Vector3, n: Vector3) -> StringName:
	var hit := _face_at(m, p, n)
	assert_false(hit.is_empty(), "a face at %s facing %s" % [p, n])
	if hit.is_empty():
		return &""
	return StationSurface.finish_of_face(m, look, hit[0], hit[1])


func test_kingsmere_names_its_station_and_the_other_maps_none() -> void:
	var m := _map("kingsmere")
	assert_not_null(m.station, "Kingsmere is station-dressed")
	assert_gt(m.station.zones.size(), 60, "its rooms' air")
	assert_eq(m.station.strips.size(), 4, "two strips on each platform's edge")
	assert_eq(m.station.tracks.size(), 4, "both lines, either side of the trains")
	assert_eq(m.warnings.filter(func(w: String) -> bool: return w.contains("station")), [], "no warnings")
	for id: String in ["depot", "woodland", "range"]:
		assert_null(_map(id).station, "%s has no station dress" % id)


func test_every_finish_names_a_set_in_both_texture_arrays() -> void:
	for f: StringName in look.finish_sets:
		assert_true(look.sets.has(look.finish_sets[f]), "%s's set %s is baked" % [f, look.finish_sets[f]])
	for d: Dictionary in [look.style_floors, look.style_ceilings, look.kind_finishes]:
		for k: StringName in d:
			assert_true(look.finish_sets.has(d[k]), "%s's finish %s has a set" % [k, d[k]])
	for s: StringName in look.style_walls:
		assert_true(look.style_floors.has(s) and look.style_ceilings.has(s), "%s has a floor and a ceiling" % s)
	var mat := StationSurface.material(look)
	assert_not_null(mat, "the arrays load")
	for p: StringName in [&"colour_tex", &"surface_tex"]:
		var tex := mat.get_shader_parameter(p) as TextureLayered
		assert_eq(tex.get_layers(), look.sets.size(), "%s holds every set" % p)
		assert_eq(Vector2i(tex.get_width(), tex.get_height()), Vector2i(512, 512), "%s's layers are 512 px" % p)


func test_every_style_the_map_names_is_one_the_look_knows() -> void:
	for z in _map("kingsmere").station.zones:
		assert_true(look.style_walls.has(z.style), "style %s is known" % z.style)


func test_each_face_takes_its_room_s_finish() -> void:
	var m := _map("kingsmere")
	assert_eq(_finish_at(m, Vector3(-45.0, 18.9, 5.0), Vector3.UP), &"terrazzo", "the ticket hall's floor")
	assert_eq(_finish_at(m, Vector3(-62.0, 20.0, 0.0), Vector3.RIGHT), &"wall_tile", "the ticket hall's west wall")
	assert_eq(_finish_at(m, Vector3(-50.0, 24.9, 0.0), Vector3.DOWN), &"plaster", "the ticket hall's ceiling")
	assert_eq(_finish_at(m, Vector3(0.0, 0.9, -7.0), Vector3.UP), &"platform", "the north platform")
	assert_eq(_finish_at(m, Vector3(-30.0, 0.0, 11.5), Vector3.UP), &"ballast", "the south track bed")
	assert_eq(_finish_at(m, Vector3(70.0, 1.5, 12.6), Vector3.FORWARD), &"lining", "the south running tunnel's wall")
	assert_eq(_finish_at(m, Vector3(40.0, 2.0, 9.0), Vector3.FORWARD), &"car", "the south train's side, outside")
	assert_eq(_finish_at(m, Vector3(40.0, 0.9, 10.75), Vector3.UP), &"rubber", "the south train's floor")
	assert_eq(_finish_at(m, Vector3(10.0, 8.9, 3.0), Vector3.UP), &"platform", "the plant room's floor")


func test_the_escalators_are_tread_and_the_cover_its_kind_s() -> void:
	var m := _map("kingsmere")
	var treads := 0
	for b in m.blocks:
		if b.kind == &"ramp" and b.center.x > -37.0 and b.center.x < -19.0 and absf(b.center.z) > 0.5:
			for f in GreyboxFaces.faces_of(b):
				if GreyboxFaces.face_normal(f).y > 0.5:
					assert_eq(StationSurface.finish_of_face(m, look, b, f), &"tread", "the upper escalators' steps")
					treads += 1
		if look.kind_finishes.has(b.kind) and m.station.owner_of(b) == &"":
			var f0 := GreyboxFaces.faces_of(b)[0]
			assert_eq(StationSurface.finish_of_face(m, look, b, f0), look.kind_finishes[b.kind], "a %s" % b.kind)
	assert_gt(treads, 10, "the upper escalators' ramp")


func test_almost_every_floor_faces_the_room_it_carries() -> void:
	var m := _map("kingsmere")
	var facing := 0
	var floors := 0
	for b in m.blocks:
		if b.kind != &"floor" and b.kind != &"ramp":
			continue
		for f in GreyboxFaces.faces_of(b):
			if GreyboxFaces.face_normal(f).y < 0.5:
				continue
			floors += 1
			if StationSurface.zone_faced(m.station, look, f) != null:
				facing += 1
	# the few that don't: the lid over the shell and floors under the spiral's flights and the escalators' balustrade
	assert_gt(float(facing) / float(floors), 0.9, "%d of %d floors face a room" % [facing, floors])


func test_the_level_draws_one_station_mesh_with_the_greybox_s_colliders() -> void:
	var m := _map("kingsmere")
	var dressed := _level(m, look)
	var plain := _level(_map("kingsmere"), null)
	var mesh := dressed.get_node("Station") as MeshInstance3D
	assert_not_null(mesh, "the station's mesh")
	assert_eq(mesh.material_override, dressed.station_material(), "in the station's material")
	assert_eq(mesh.mesh.get_surface_count(), 1, "one draw")
	assert_null(dressed.get_node_or_null("Greybox"), "no greybox under it")
	assert_null(plain.station_material(), "no look: greybox")
	assert_eq(_shapes(dressed), _shapes(plain), "the very same colliders")


func _shapes(level: MapLevel) -> Array[String]:
	var out: Array[String] = []
	for body in level.find_children("*", "StaticBody3D", true, false):
		for c in body.get_children():
			if c is CollisionShape3D:
				var s := c as CollisionShape3D
				out.append("%s %s %s" % [body.name, s.position, (s.shape as BoxShape3D).size if s.shape is BoxShape3D
						else s.shape.get_class()])
	out.sort()
	return out


func test_strips_lie_on_the_platforms_and_the_rails_low_on_the_track_bed() -> void:
	var m := _map("kingsmere")
	for s in m.station.strips:
		var mid := Vector3(s.area.get_center().x, s.y + look.strip_lift, s.area.get_center().y)
		assert_eq(m.station.style_at(mid + Vector3.UP * 0.05), &"platform", "a %s strip on a platform" % s.finish)
		assert_almost_eq(m.floor_under(mid.x, mid.z, s.y + 0.5), s.y, 0.01, "on its floor")
	for t in m.station.tracks:
		assert_almost_eq(t.y, 0.0, 0.001, "on the track bed")
		var mid := (t.from + t.to) * 0.5
		var style := m.station.style_at(Vector3(mid.x, t.y + 0.05, mid.y))
		assert_true(style == &"track" or style == &"tunnel", "a track in a track or a tunnel (%s)" % style)
	var top := look.sleeper_size.y + look.rail_size.y
	assert_lt(top, tuning.body.max_step, "a rail stands lower than a step")


func test_low_drops_the_relief() -> void:
	var level := _level(_map("kingsmere"), look)
	level.set_detail(GraphicsQuality.MeshDetail.LOW)
	assert_true(level.station_material().get_shader_parameter(&"low"), "Low: no relief")
	level.set_detail(GraphicsQuality.MeshDetail.HIGH)
	assert_false(level.station_material().get_shader_parameter(&"low"), "High: relief")


func test_no_tint_reads_as_a_team() -> void:
	for f: StringName in look.finish_tints:
		assert_lt(look.finish_tints[f].s, 0.2, "%s's tint is near grey" % f)


func test_a_malformed_station_dress_is_warned_about_and_left_out() -> void:
	var warnings: Array[String] = []
	assert_null(StationDressing.read({}, warnings), "none named: none")
	assert_null(StationDressing.read({"station": 3}, warnings), "not an object: greybox")
	var d := StationDressing.read({"station": {
		"zones": [{"style": "hall", "box": [0, 1, 0, 1, 0, 1]}, {"style": "hall", "box": [1, 0, 0, 1, 0, 1]}, {"box": []}],
		"strips": [{"finish": "tactile", "x0": 0, "x1": 2, "z0": 0, "z1": 1, "y": 0.9}, {"x0": 0}],
		"tracks": [{"x0": 0, "x1": 10, "z0": 0, "z1": 1, "y": 0}, {"x0": 5, "x1": 1, "z0": 0, "z1": 1, "y": 0}],
	}}, warnings)
	assert_eq([d.zones.size(), d.strips.size(), d.tracks.size()], [1, 1, 1], "the good ones kept")
	assert_eq(warnings.size(), 5, "each bad one warned about, and the bad dress")
	assert_eq(d.style_at(Vector3(0.5, 0.5, 0.5)), &"hall", "a point in a zone")
	assert_eq(d.style_at(Vector3(5.0, 0.5, 0.5)), &"", "a point in none")


func test_zone_lookup_holds_at_column_and_box_edges() -> void:
	var w: Array[String] = []
	var d := StationDressing.read({"station": {"zones": [
		{"style": "hall", "box": [-9.0, 17.0, 0, 3, 0, 3]},
		{"style": "plant", "box": [20.0, 24.0, 0, 3, 0, 3]},
	]}}, w)
	for x: float in [-9.0, -8.0, -0.001, 0.0, 7.999, 8.0, 16.0, 17.0]:
		assert_eq(d.style_at(Vector3(x, 1.0, 1.0)), &"hall", "x=%s lies in the hall across the column edges" % x)
	assert_eq(d.style_at(Vector3(17.5, 1.0, 1.0)), &"", "just past the hall: none")
	assert_eq(d.style_at(Vector3(-9.5, 1.0, 1.0)), &"", "just before it: none")
	assert_eq(d.style_at(Vector3(24.0, 1.0, 1.0)), &"plant", "a far zone")
	assert_eq(d.style_at(Vector3(1e6, 1.0, 1.0)), &"", "far away: none")
	assert_eq(w, [], "no warnings")


func test_a_station_with_no_zones_leaves_every_face_outside() -> void:
	var w: Array[String] = []
	var d := StationDressing.read({"station": {}}, w)
	assert_not_null(d, "an empty station is still a dress")
	assert_eq(d.zones.size(), 0)
	assert_null(d.zone_at(Vector3.ZERO), "no zone")
	assert_eq(d.owner_of(MapData.Block.new()), &"", "no owner")


func test_a_face_in_no_room_takes_the_outside_set_and_every_finish_has_a_layer() -> void:
	var b := MapData.Block.new()
	b.kind = &"wall"
	assert_eq(look.finish_of(b, Vector3.UP, &"", &""), look.outside, "no room: outside")
	assert_eq(look.finish_of(b, Vector3.UP, &"nonsense", &""), look.outside, "an unknown style: outside")
	assert_eq(look.layer_of(&"never_heard_of"), look.layer_of(look.outside), "an unknown finish: the outside's layer")
	var m := _map("kingsmere")
	var blocks_outside := 0
	for blk in m.blocks:
		if look.kind_finishes.has(blk.kind) and m.station.owner_of(blk) == &"":
			continue
		for f in GreyboxFaces.faces_of(blk):
			var layer := look.layer_of(StationSurface.finish_of_face(m, look, blk, f))
			assert_between(layer, 0, look.sets.size() - 1, "a valid layer")
		if m.station.zone_at(blk.center) == null and blk.kind == &"floor":
			blocks_outside += 1
	gut.p("floor blocks whose centre lies in no zone: %d" % blocks_outside)


func test_a_look_whose_arrays_are_missing_draws_the_greybox() -> void:
	var bad: StationLook = look.duplicate()
	bad.colour_array = "res://assets/textures/station/does_not_exist.res"
	var level := MapLevel.new()
	add_child_autofree(level)
	level.build(_map("kingsmere"), play.map_style, tuning.body, play.baked_light, LightingConfig.for_map(play.lighting,
			null, _map("kingsmere"), LightingConfig.DAY), false, play.site_look, bad)
	assert_null(level.station_material(), "no material")
	assert_null(level.get_node_or_null("Station"), "no station mesh")
	assert_not_null(level.get_node_or_null("Greybox"), "the greybox instead")
	assert_push_error("texture arrays")


func test_set_detail_before_a_build_and_on_a_greybox_map_is_harmless() -> void:
	var level := MapLevel.new()
	add_child_autofree(level)
	level.set_detail(GraphicsQuality.MeshDetail.LOW)
	assert_null(level.station_material(), "nothing before a build")
	var plain := _level(_map("depot"), look)
	plain.set_detail(GraphicsQuality.MeshDetail.LOW)
	assert_null(plain.station_material(), "a map without a dress ignores the station look")
	assert_null(plain.get_node_or_null("Station"), "and draws no station")


func test_freeing_a_station_level_leaves_no_orphans() -> void:
	var before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var level := MapLevel.new()
	add_child(level)
	level.build(_map("kingsmere"), play.map_style, tuning.body, play.baked_light, LightingConfig.for_map(play.lighting,
			null, _map("kingsmere"), LightingConfig.DAY), false, play.site_look, look)
	remove_child(level)
	level.free()
	await wait_physics_frames(2)
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), before, "no node left behind")
