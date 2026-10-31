extends GutTest
## DD1: Depot's temporary site dress. Every block of Depot and the range has a finish of its own in the shader's slots,
## no site paint or mark reads as a team, the site mesh is the greybox's faces (baked or not) so cover, collision and the bake
## stay exactly as they were, the details and sandbags stay within their blocks, the stencils name the map's areas on
## a wall, the slab's bay lines lie on open slab and the dock wears its hazard lip, Low drops the fine relief, the day
## gets its clouds and haze, and Woodland stays greybox.

var play: PlayTuning = PlayTuning.load_default()
var tuning: SimTuning = SimTuning.new()
var look: SiteLook = null


func before_each() -> void:
	look = play.site_look


func _map(id: String) -> MapData:
	var m := MapData.load_map(id, play.map_style, 1 if id == "range" else tuning.rounds.team_size)
	assert_true(m.ok(), "%s loads: %s" % [id, m.problems])
	return m


func _level(m: MapData, site: SiteLook) -> MapLevel:
	var level := MapLevel.new()
	add_child_autofree(level)
	level.build(m, play.map_style, tuning.body, play.baked_light, LightingConfig.for_map(play.lighting, null, m,
			LightingConfig.DAY), false, site)
	return level


## The old yard (YardMap; Depot until DR1): its gravel beds, dock, sandbags and stencils, dressed as before.
func _yard() -> MapData:
	return YardMap.load_map(play.map_style, tuning.rounds.team_size)


func _drawn(level: MapLevel) -> MeshInstance3D:
	for n in level.get_children():
		if n is MeshInstance3D:
			return n as MeshInstance3D
	return null


func _box(b: MapData.Block, grow: float) -> AABB:
	return AABB(b.center - b.size * 0.5, b.size).grow(grow)


func test_every_block_of_depot_and_the_range_has_a_finish_of_its_own() -> void:
	var names := look.finish_names()
	assert_lte(names.size(), SiteSurface.SLOTS, "the finishes fit the shader's slots")
	assert_lte(look.container_paint.size(), SiteSurface.PAINTS, "the container paints fit the shader's")
	for n in names:
		assert_true(look.paints.has(n), "%s has a paint" % n)
	for k in SiteSurface.MARKS:
		assert_true(look.marks.has(k), "the %s mark has a colour" % k)
	for id: String in ["depot", "range"]:
		var m := _map(id)
		assert_not_null(m.site, "%s is site-dressed" % id)
		var plain: Array[String] = []
		for b in m.blocks:
			var f := look.finish_of(b)
			if f == &"default" or not names.has(f):
				plain.append("%s at %s" % [b.kind, b.center])
		assert_eq(plain, [] as Array[String], "%s: every block has a finish" % id)


func test_the_gravel_beds_dock_and_slab_are_told_apart() -> void:
	var m := _yard()
	var finishes: Dictionary[StringName, int] = {}
	for b in m.blocks:
		if b.kind == &"floor":
			var f := look.finish_of(b)
			finishes[f] = finishes.get(f, 0) + 1
	assert_eq(finishes, {&"slab": 1, &"dock": 1, &"gravel": 2} as Dictionary[StringName, int])


func test_no_site_paint_reads_as_a_team() -> void:
	var teams := AccessibilityTable.read_file().colours
	var colours: Dictionary[String, Color] = {}
	for n: StringName in look.paints:
		colours["paint %s" % n] = look.paints[n]
	for n: StringName in look.accents:
		colours["accent %s" % n] = look.accents[n]
	for i in look.container_paint.size():
		colours["container %d" % i] = look.container_paint[i]
		colours["frame %d" % i] = look.container_paint[i] * look.frame_shade
	for n: StringName in look.marks:
		colours["mark %s" % n] = look.marks[n]
	colours["stencil"] = look.stencil_paint
	colours["light stencil"] = look.stencil_light
	var team_like: Array[String] = []
	for k in colours:
		if FieldChecks.reads_as_team(colours[k], teams):
			team_like.append(k)
	assert_eq(team_like, [] as Array[String], "no site paint near a team's hue")


func test_a_site_dressing_is_read_and_a_bad_entry_left_out() -> void:
	var warnings: Array[String] = []
	assert_null(SiteDressing.read({}, warnings), "no site: greybox")
	assert_null(SiteDressing.read(null, warnings))
	assert_eq(warnings, [] as Array[String])
	assert_null(SiteDressing.read({"site": 3}, warnings), "not an object: greybox")
	assert_eq(warnings.size(), 1)
	warnings.clear()
	var corner := {"x": 0, "y": 4, "z": 0}
	var d := SiteDressing.read({"site": {
		"stencils": [
			{"area": "Dock", "x": 1, "y": 2, "z": 3, "facing": "+x", "height": 0.5},
			{"area": "Dock", "x": 1, "y": 2, "z": 3, "facing": "up", "height": 0.5},
			{"area": "", "x": 1, "y": 2, "z": 3, "facing": "+z", "height": 0.5},
			{"area": "Dock", "x": 1, "y": 2, "facing": "+z", "height": 0.5},
			{"area": "Dock", "x": 1, "y": 2, "z": 3, "facing": "+z", "height": 0},
		],
		"sails": [
			{"corners": [corner, {"x": 4, "y": 4, "z": 0}, {"x": 2, "y": 5, "z": 3}], "post": 0.5},
			{"corners": [corner, corner], "post": 0.5},
			{"corners": [corner, corner, {"x": 1}], "post": 0.5},
			{"corners": [corner, corner, corner], "post": -1},
		],
		"lines": [
			{"x": 1, "z": 2, "w": 4, "d": 0.1},
			{"x": 1, "z": 2, "w": 4},
			{"x": 1, "z": 2, "w": 0, "d": 0.1},
			"line",
		],
	}}, warnings)
	assert_not_null(d)
	assert_eq(d.stencils.size(), 1, "the good stencil")
	assert_eq(d.stencils[0].area, "Dock")
	assert_almost_eq(d.stencils[0].yaw, PI * 0.5, 1e-6)
	assert_eq(d.stencils[0].at, Vector3(1, 2, 3))
	assert_eq(d.sails.size(), 1, "the good sail")
	assert_almost_eq(d.sails[0].post, 0.5, 1e-6)
	assert_eq(d.lines, [Rect2(-1, 1.95, 4, 0.1)] as Array[Rect2], "the good line, round its centre")
	assert_eq(warnings.size(), 10, "each bad entry warned: %s" % [warnings])


func test_a_map_paints_no_more_bay_lines_than_the_shader_draws() -> void:
	var warnings: Array[String] = []
	var lines: Array[Dictionary] = []
	for i in SiteDressing.LINES + 2:
		lines.append({"x": i, "z": 0, "w": 0.1, "d": 2})
	var d := SiteDressing.read({"site": {"lines": lines}}, warnings)
	assert_eq(d.lines.size(), SiteDressing.LINES)
	assert_eq(warnings.size(), 2, "the extras warned: %s" % [warnings])


func test_the_yard_paints_bay_lines_on_open_slab_and_a_hazard_lip_on_its_dock() -> void:
	var m := _yard()
	assert_gt(m.site.lines.size(), 0, "Depot paints its bay lines")
	var slab: MapData.Block = null
	var dock: MapData.Block = null
	for b in m.blocks:
		match look.finish_of(b):
			&"slab":
				slab = b
			&"dock":
				dock = b
	var buried: Array[String] = []
	for line in m.site.lines:
		var on_slab := Rect2(slab.center.x - slab.size.x * 0.5, slab.center.z - slab.size.z * 0.5, slab.size.x, slab.size.z)
		assert_true(on_slab.encloses(line), "%s lies on the slab" % line)
		var covered := 0.0
		for b in m.blocks:
			if b == slab or b.center.y - b.size.y * 0.5 > look.gravel_to:
				continue
			var foot := Rect2(b.center.x - b.size.x * 0.5, b.center.z - b.size.z * 0.5, b.size.x, b.size.z)
			covered += foot.intersection(line).get_area()
		if covered > line.get_area() * 0.5:
			buried.append(str(line))
	assert_eq(buried, [] as Array[String], "every bay line is mostly in the open")
	var mat := _level(m, look).site_material()
	assert_eq(mat.get_shader_parameter(&"line_count"), m.site.lines.size())
	var first: Vector4 = (mat.get_shader_parameter(&"lines") as PackedVector4Array)[0]
	var line := m.site.lines[0]
	assert_eq(first, Vector4(line.get_center().x, line.get_center().y, line.size.x * 0.5, line.size.y * 0.5))
	assert_true(SiteSurface.flags_of(look, dock) & SiteSurface.FLAG_HAZARD != 0, "the dock is drawn with its hazard lip")
	assert_true(look.accents.has(&"dock"), "in its own accent")
	assert_true(look.hazard_lip.x >= 0.0 and look.hazard_lip.x < look.hazard_lip.y and look.hazard_lip.y < dock.size.y,
			"the lip is a band on the dock's sides, under its top")
	assert_eq(mat.get_shader_parameter(&"hazard_lip"), look.hazard_lip)


func test_the_yard_s_stencils_name_its_areas_on_a_wall_and_read_against_it() -> void:
	var m := _yard()
	var areas: Array[String] = []
	for a in m.areas:
		areas.append(a.name)
	assert_gt(m.site.stencils.size(), 0)
	for s in m.site.stencils:
		assert_true(areas.has(s.area), "%s is one of Depot's areas" % s.area)
		var behind := s.at - Basis(Vector3.UP, s.yaw) * Vector3(0.0, 0.0, 0.01)
		var on := false
		for b in m.blocks:
			on = on or _box(b, 0.0).has_point(behind)
		assert_true(on, "%s's stencil is on a block's face" % s.area)
	var box := m.site.stencils.filter(func(s: SiteDressing.Stencil) -> bool: return s.area == "Box")
	assert_eq(SiteDress.stencil_paint(m, look, box[0]), look.stencil_light, "light on the Box's dark container")
	var hall := m.site.stencils.filter(func(s: SiteDressing.Stencil) -> bool: return s.area == "Hall")
	assert_eq(SiteDress.stencil_paint(m, look, hall[0]), look.stencil_paint, "charcoal on the Hall's pale wall")


func test_the_site_mesh_is_the_greybox_s_faces_with_sandbags_drawn_inside_their_bags() -> void:
	var m := _yard()
	var level := _level(m, look)
	assert_not_null(level.site_material())
	var site := _drawn(level)
	assert_eq(site.name, &"Site")
	assert_eq(site.material_override, level.site_material())
	var grey := MapLevel._greybox_mesh(m, play.map_style)
	var a: PackedVector3Array = site.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var b: PackedVector3Array = grey.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_eq(a.size(), b.size(), "as many vertices as the greybox")
	assert_ne(site.mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_CUSTOM0, 0, "each vertex carries its box")
	var stacks: Array[AABB] = []
	for blk in m.blocks:
		if look.finish_of(blk) == &"sandbags" or SiteSurface.as_props(look, blk): # DR2: a propped box folds or backs
			stacks.append(_box(blk, 1e-4))
	var moved: Array[int] = []
	for i in a.size():
		if a[i].distance_to(b[i]) < 1e-5:
			continue
		var inside := false
		for s in stacks:
			inside = inside or (s.has_point(a[i]) and s.has_point(b[i]))
		if not inside:
			moved.append(i)
	assert_eq(moved, [] as Array[int], "only a sandbag stack's or a propped block's own box is drawn elsewhere, inside it")


func test_the_bake_fits_the_site_mesh_and_lights_it() -> void:
	var m := _map("depot")
	var level := _level(m, look)
	level.set_baked_light(true)
	assert_true(level.baked_light_drawn(), "Depot's bake draws on the site mesh")
	var mi := _drawn(level)
	assert_eq(mi.material_override, level.site_material())
	var tiles := GreyboxFaces.tile(m, play.baked_light.cell, play.baked_light.ground_y)
	assert_eq(mi.mesh.surface_get_array_len(0), tiles.positions.size() + 4, "the tiles and the ground")
	var arrays := mi.mesh.surface_get_arrays(0)
	var custom: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM0]
	assert_eq(custom.size(), (tiles.positions.size() + 4) * 4, "a box for each vertex")
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var grey := 0
	for c in colours:
		if absf(c.r - c.g) > 0.2 or absf(c.g - c.b) > 0.2:
			grey += 1
	assert_eq(grey, 0, "the colour is light alone, no block's paint")
	var caster := mi.get_node("ShadowCaster") as MeshInstance3D
	assert_ne(caster.material_override, level.site_material(), "the shadows are the greybox's")
	level.set_baked_light(false)
	assert_eq(_drawn(level).mesh.surface_get_array_len(0), MapLevel._greybox_mesh(m, play.map_style)
			.surface_get_array_len(0), "off: untiled")


func test_low_draws_the_site_without_its_fine_relief() -> void:
	var level := _level(_map("depot"), look)
	level.set_detail(GraphicsQuality.MeshDetail.LOW)
	assert_true(level.site_material().get_shader_parameter(&"low"))
	level.set_detail(GraphicsQuality.MeshDetail.MEDIUM)
	assert_false(level.site_material().get_shader_parameter(&"low"))


func test_details_stay_within_their_blocks_or_out_of_reach() -> void:
	for id: String in ["depot", "range"]:
		var m := _map(id)
		var level := _level(m, look)
		var dress := SiteDress.build(m, look, level.site_material())
		add_child_autofree(dress)
		var field := AABB()
		for b in m.blocks:
			field = field.merge(_box(b, 0.0)) if field.has_volume() else _box(b, 0.0)
		var allowed: Array[AABB] = []
		for b in m.blocks:
			allowed.append(_box(b, look.proud + 1e-4))
		for s in m.site.sails:
			var sail := AABB(s.corners[0], Vector3.ZERO).expand(s.corners[1]).expand(s.corners[2])
			allowed.append(sail.grow(look.sail_post).expand(sail.position - Vector3(0.0, s.post, 0.0)))
		var stray: Array[Vector3] = []
		for p in dress.details().mesh.get_faces():
			var ok := not field.grow(-0.01).has_point(Vector3(p.x, field.get_center().y, p.z))
			for box in allowed:
				ok = ok or box.has_point(p)
			if not ok:
				stray.append(p)
		assert_eq(stray.size(), 0, "%s: no detail stands out of its block in the field: %s" % [id, stray.slice(0, 4)])
		assert_eq(dress.details().get_class(), "MeshInstance3D")
		assert_eq(dress.find_children("*", "CollisionObject3D", true, false).size(), 0, "%s: no collider" % id)


func test_sandbags_fill_their_stacks() -> void:
	var m := _yard()
	var dress := SiteDress.build(m, look, _level(m, look).site_material())
	add_child_autofree(dress)
	var shades := PackedFloat32Array()
	var bags := SiteDress.bag_layout(m, look, shades)
	assert_eq(dress.bags().multimesh.instance_count, bags.size(), "one MultiMesh of them all")
	assert_eq(shades.size(), bags.size())
	var stacks: Array[AABB] = []
	for b in m.blocks:
		if look.finish_of(b) == &"sandbags":
			stacks.append(_box(b, look.bag_bulge + 0.02))
	assert_eq(stacks.size(), 2)
	assert_gt(bags.size(), 60, "laid bag by bag")
	var stray := 0
	for t in bags:
		var bag := t * AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)
		var ok := false
		for s in stacks:
			ok = ok or s.encloses(bag)
		if not ok:
			stray += 1
	assert_eq(stray, 0, "every bag within its stack and its bulge")
	assert_eq(dress.bags().visibility_range_end, look.bags_until)
	assert_eq(dress.bags().cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "the stack's box casts the shadow")


func test_the_day_gets_clouds_and_haze() -> void:
	var lighting := FieldLighting.build(play.lighting)
	add_child_autofree(lighting)
	SiteDress.dress_sky(lighting, look)
	var sky := lighting.environment.sky.sky_material as ShaderMaterial
	assert_not_null(sky)
	assert_eq(sky.shader, SiteDress.SKY_SHADER)
	assert_true(lighting.environment.fog_enabled)
	assert_eq(lighting.environment.fog_depth_begin, look.haze_from)


func test_woodland_stays_greybox() -> void:
	var m := _map("woodland")
	assert_null(m.site)
	var level := _level(m, look)
	assert_null(level.site_material())
	assert_eq(_drawn(level).name, &"Greybox")
	assert_null(SiteDress.build(m, look, level.site_material()))
