extends GutTest
## DD1 QA: Depot's and the range's site dress changes only what is drawn. The colliders, the nav grid, the bake and the
## block list are the greybox's; every vertex of the site mesh, baked or not, sits in the box and finish its custom
## channels name; the Baked light switch rebuilds the mesh alone and keeps the one material; Low reaches the dress's
## materials; Woodland stays greybox in a match; the night keeps its own sky and haze; a malformed
## site entry is left out with a warning; and a match with the dress frees every node and resource it made.

const CYCLES := 3
const MATCHES := 4
const DRESSED: Array[String] = ["depot", "range"]
const GREYBOX: Array[String] = ["woodland"]

var play: PlayTuning = PlayTuning.load_default()
var tuning: SimTuning = SimTuning.new()
var look: SiteLook = null


func before_each() -> void:
	look = play.site_look


func after_each() -> void:
	get_tree().paused = false


func _map(id: String) -> MapData:
	var m := MapData.load_map(id, play.map_style, 1 if id == "range" else tuning.rounds.team_size)
	assert_true(m.ok(), "%s loads: %s" % [id, m.problems])
	return m


func _level(m: MapData, site: SiteLook, night: bool = false) -> MapLevel:
	var level := MapLevel.new()
	add_child_autofree(level)
	level.build(m, play.map_style, tuning.body, play.baked_light, _sun(m), night, site)
	return level


## The sun `m` is baked under: the day preset as the map sets it (PlaySession passes the same).
func _sun(m: MapData) -> LightingConfig:
	return LightingConfig.for_map(play.lighting, null, m, LightingConfig.DAY)


func _drawn(level: MapLevel) -> MeshInstance3D:
	for n in level.get_children():
		if n is MeshInstance3D:
			return n as MeshInstance3D
	return null


## Each collision body's shapes as text: its surface, then every shape's place, kind and size or points.
func _colliders(level: MapLevel) -> PackedStringArray:
	var out := PackedStringArray()
	for n in level.get_children():
		if not n is StaticBody3D:
			continue
		out.append("%s layer %d" % [n.name, (n as StaticBody3D).collision_layer])
		for c in n.get_children():
			var shape := (c as CollisionShape3D).shape
			var detail := ""
			if shape is BoxShape3D:
				detail = str((shape as BoxShape3D).size)
			elif shape is ConvexPolygonShape3D:
				detail = str((shape as ConvexPolygonShape3D).points)
			elif shape is ConcavePolygonShape3D:
				detail = str((shape as ConcavePolygonShape3D).get_faces().size())
			out.append("%s %s %s" % [(c as CollisionShape3D).position, shape.get_class(), detail])
	return out


## The map's file text with `dressing.site` taken out, as the main branch's file read.
func _text_without_site(id: String) -> String:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MapData.DIR + id + ".json"))
	(d["dressing"] as Dictionary).erase("site")
	return JSON.stringify(d)


func _blocks_of(m: MapData) -> PackedStringArray:
	var out := PackedStringArray()
	for b in m.blocks:
		out.append("%s %s %s %d %d %d" % [b.kind, b.center, b.size, b.rise, b.surface, b.piece])
	return out


func _slot_box(c0: PackedFloat32Array, c1: PackedFloat32Array, v: int) -> Array:
	var k := v * 4
	return [Vector3(c0[k], c0[k + 1], c0[k + 2]), int(c0[k + 3]), Vector3(c1[k], c1[k + 1], c1[k + 2])]


# 1. Hit volumes and navigation


## What a ray along each block's side meets in a level: one string a block (they share a physics space, so one level
## lives at a time).
func _rays(m: MapData, site: SiteLook) -> PackedStringArray:
	var level := MapLevel.new()
	add_child(level)
	level.build(m, play.map_style, tuning.body, play.baked_light, _sun(m), false, site)
	var out := PackedStringArray()
	for blk in m.blocks:
		if blk.rise != MapData.Rise.NONE or blk.size.y < 0.5:
			continue
		var hit := RayHit.new()
		var from := blk.center + Vector3(blk.size.x * 0.5 + 3.0, 0.0, 0.0)
		var found := level.query().ray(from, blk.center, hit)
		out.append("%s %s %s %d" % [found, hit.position, hit.normal, hit.surface])
	out.append_array(_colliders(level))
	remove_child(level)
	level.free()
	return out


func test_the_dress_leaves_the_colliders_and_what_a_ray_meets_the_greyboxs() -> void:
	for id in DRESSED:
		var m := _map(id)
		var grey := _rays(m, null)
		var dressed := _rays(m, look)
		assert_gt(grey.size(), m.blocks.size() / 2, "%s: rays were cast" % id)
		assert_eq(dressed, grey, "%s: the same colliders and the same hits, block for block" % id)
		var level := _level(m, look)
		assert_not_null(level.site_material(), "%s is dressed" % id)


func test_the_site_key_changes_nothing_the_simulation_reads() -> void:
	for id in DRESSED:
		var dressed := _map(id)
		var plain := MapData.parse(_text_without_site(id), play.map_style, 1 if id == "range" else tuning.rounds.team_size)
		assert_true(plain.ok(), "%s without its site key still loads" % id)
		assert_null(plain.site, "%s: no key, no dress" % id)
		assert_not_null(dressed.site, "%s: the key, the dress" % id)
		assert_eq(_blocks_of(dressed), _blocks_of(plain), "%s: the same block list" % id)
		assert_eq(dressed.areas.size(), plain.areas.size())
		assert_eq(dressed.ends.size(), plain.ends.size())
		assert_eq(dressed.skyline.size(), plain.skyline.size())
		var hash_a := BakedLight.hash_of(dressed, play.map_style, _sun(dressed), play.baked_light)
		var hash_b := BakedLight.hash_of(plain, play.map_style, _sun(plain), play.baked_light)
		assert_eq(hash_a, hash_b, "%s: the bake's hash is the same" % id)
		var nav_a := NavGrid.build(dressed, tuning.nav, tuning.body)
		var nav_b := NavGrid.build(plain, tuning.nav, tuning.body)
		assert_eq(nav_a.walkable, nav_b.walkable, "%s: the same walkable cells" % id)
		assert_eq(nav_a.floor_y, nav_b.floor_y, "%s: the same floors" % id)
		assert_eq(nav_a.node_cell, nav_b.node_cell, "%s: the same nodes" % id)
		var bake := BakedLight.load_for(dressed)
		if bake != null:
			assert_eq(bake.source_hash, hash_a, "%s: the shipped bake is still this map's" % id)


# 2. The site mesh and the bake


func test_every_site_vertex_sits_inside_the_box_and_finish_its_channels_name() -> void:
	for id in DRESSED:
		var m := _map(id)
		var level := _level(m, look)
		for baked: bool in [false, true]:
			level.set_baked_light(baked)
			if baked and not level.baked_light_drawn():
				continue # the range names no bake
			var mesh := _drawn(level).mesh as ArrayMesh
			var arrays := mesh.surface_get_arrays(0)
			var pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var c0: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM0]
			var c1: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM1]
			assert_eq(c0.size(), pos.size() * 4, "%s: a box for each vertex" % id)
			assert_eq(c1.size(), pos.size() * 4)
			var slots := PackedInt32Array()
			for b in m.blocks:
				slots.append(SiteSurface.slot_of(look, look.finish_of(b)))
			var loose := 0
			var wrong_finish := 0
			for v in pos.size():
				var s := _slot_box(c0, c1, v)
				var box := AABB(s[0] - s[2], s[2] * 2.0).grow(0.002)
				if not box.has_point(pos[v]):
					loose += 1
				var finish_ok: bool = s[1] == SiteSurface.slot_of(look, &"ground")
				for i in m.blocks.size():
					var b := m.blocks[i]
					if (s[0] as Vector3).is_equal_approx(b.center) and (s[2] as Vector3).is_equal_approx(b.size * 0.5):
						finish_ok = finish_ok or s[1] == slots[i]
				if not finish_ok:
					wrong_finish += 1
			assert_eq(loose, 0, "%s baked=%s: no vertex outside the box it names" % [id, baked])
			assert_eq(wrong_finish, 0, "%s baked=%s: each box carries its block's finish" % [id, baked])


func test_the_baked_site_mesh_keeps_the_tiles_and_draws_sandbags_inside_their_bags() -> void:
	var m := _map("range") # Depot's hall has no sandbags; the range keeps two stacks
	var level := _level(m, look)
	level.set_baked_light(true)
	assert_true(level.baked_light_drawn())
	var tiles := GreyboxFaces.tile(m, play.baked_light.cell, play.baked_light.ground_y)
	var pos: PackedVector3Array = _drawn(level).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var stacks: Array[AABB] = []
	var stack_ids := PackedInt32Array()
	for i in m.blocks.size():
		if look.finish_of(m.blocks[i]) == &"sandbags":
			stacks.append(AABB(m.blocks[i].center - m.blocks[i].size * 0.5, m.blocks[i].size).grow(1e-4))
			stack_ids.append(i)
	assert_eq(stacks.size(), 2)
	for i in m.blocks.size():
		if SiteSurface.as_props(look, m.blocks[i]): # DR2: a box drawn as props folds away or backs them, inside itself
			stacks.append(AABB(m.blocks[i].center - m.blocks[i].size * 0.5, m.blocks[i].size).grow(1e-4))
			stack_ids.append(i)
	var moved := 0
	var outside := 0
	for v in tiles.positions.size():
		if pos[v].distance_to(tiles.positions[v]) < 1e-5:
			continue
		moved += 1
		var k := stack_ids.find(tiles.blocks[v])
		if k < 0 or not (stacks[k].has_point(pos[v]) and stacks[k].has_point(tiles.positions[v])):
			outside += 1
	assert_gt(moved, 0, "the sandbag tiles are drawn smaller")
	assert_eq(outside, 0, "only a stack's (or a propped block's) own tiles move, and inside their block")
	# a tile on the stack's top comes down to bag_core under it, its sides in by bag_core
	for i in stack_ids.slice(0, 2):
		var b := m.blocks[i]
		var top := b.center.y + b.size.y * 0.5
		var lowest_top := INF
		for v in tiles.positions.size():
			if tiles.blocks[v] == i and is_equal_approx(tiles.positions[v].y, top):
				lowest_top = minf(lowest_top, pos[v].y)
		assert_almost_eq(lowest_top, top - look.bag_core, 1e-4, "the stack's own top is drawn bag_core inside")


func test_switching_the_baked_light_rebuilds_the_mesh_alone_and_keeps_the_material() -> void:
	var m := _map("depot")
	var level := _level(m, look)
	var material := level.site_material()
	var others: Array[Node] = []
	for n in level.get_children():
		if n != _drawn(level):
			others.append(n)
	var shapes := _colliders(level)
	var plain := _drawn(level)
	var plain_count: int = plain.mesh.surface_get_array_len(0)
	level.set_baked_light(true)
	var lit := _drawn(level)
	assert_ne(lit, plain, "the mesh node is rebuilt")
	assert_eq(lit.name, &"Site")
	assert_ne(lit.mesh.surface_get_array_len(0), plain_count, "tiled")
	assert_same(level.site_material(), material, "one material through the switch")
	assert_same(lit.material_override, material)
	var kids: Array[Node] = []
	for n in level.get_children():
		if n != lit:
			kids.append(n)
	assert_eq(kids, others, "every other child is the same node")
	assert_eq(_colliders(level), shapes, "the colliders are untouched")
	level.set_baked_light(true)
	assert_same(_drawn(level), lit, "switching on twice rebuilds nothing")
	level.set_baked_light(false)
	assert_eq(_drawn(level).mesh.surface_get_array_len(0), plain_count, "off again: the untiled faces")
	assert_same(_drawn(level).material_override, material)
	# the detail set before a switch survives it
	level.set_detail(GraphicsQuality.MeshDetail.LOW)
	level.set_baked_light(true)
	assert_true(level.site_material().get_shader_parameter(&"low"), "Low stays on through a rebuild")


func test_the_range_without_a_bake_draws_the_site_untiled() -> void:
	var m := _map("range")
	var level := _level(m, look)
	level.set_baked_light(true)
	assert_eq(level.baked_light_drawn(), not m.baked_light_file.is_empty())
	var mi := _drawn(level)
	assert_eq(mi.name, &"Site")
	assert_same(mi.material_override, level.site_material())
	assert_eq(mi.mesh.surface_get_array_len(0), MapLevel._greybox_mesh(m, play.map_style).surface_get_array_len(0) \
			if not level.baked_light_drawn() else mi.mesh.surface_get_array_len(0))


# 3. Low detail


func test_every_mesh_detail_but_low_draws_the_full_site() -> void:
	var level := _level(_map("depot"), look)
	for d: int in GraphicsQuality.MeshDetail.values():
		level.set_detail(d)
		assert_eq(level.site_material().get_shader_parameter(&"low"), d == GraphicsQuality.MeshDetail.LOW,
				"mesh detail %d" % d)


func test_a_match_on_low_reaches_the_dress_and_its_bags_too() -> void:
	var session := PlaySession.new()
	session.map_id = "range" # Depot's hall has no sandbags; the range keeps two stacks
	session.practice = true
	session.autopilot = true
	add_child_autofree(session)
	await wait_physics_frames(2)
	var table := GraphicsTable.shared()
	session._apply_graphics(table.preset(&"low"))
	var mat := session._level.site_material()
	assert_true(mat.get_shader_parameter(&"low"))
	assert_same(session._site.details().material_override, mat, "the details share the level's material")
	assert_not_null(session._site.bags(), "Low keeps the sandbags")
	assert_gt(session._site.bags().multimesh.instance_count, 0)
	session._apply_graphics(table.preset(&"medium"))
	assert_false(mat.get_shader_parameter(&"low"))
	session._apply_graphics(table.preset(&"low"))
	assert_true(mat.get_shader_parameter(&"low"), "and back to Low")


# 4. Woodland


func test_woodland_stays_greybox_in_a_match() -> void:
	for id in GREYBOX:
		var session := PlaySession.new()
		session.map_id = id
		session.autopilot = true
		add_child_autofree(session)
		await wait_physics_frames(2)
		assert_null(session._site, "%s: no site dress" % id)
		assert_null(session._level.site_material(), "%s: no site material" % id)
		assert_eq(_drawn(session._level).name, &"Greybox", "%s: the greybox mesh" % id)
		var greybox := _drawn(session._level).material_override as ShaderMaterial
		assert_eq(greybox.shader, LookMaterials.VERTEX_SHADER, "%s: the greybox in the shared light (WA1)" % id)
		assert_eq(session.find_children("*", "SiteDress", true, false).size(), 0)
		session._apply_graphics(GraphicsTable.shared().preset(&"low")) # nothing to set, nothing breaks
		var sky := session._lighting.environment.sky.sky_material
		assert_false(sky is ShaderMaterial and (sky as ShaderMaterial).shader == SiteDress.SKY_SHADER,
				"%s keeps its own sky" % id)


func test_a_greybox_map_given_a_look_stays_greybox() -> void:
	for id in GREYBOX:
		var level := _level(_map(id), look)
		assert_null(level.site_material(), id)
		assert_eq(_drawn(level).name, &"Greybox", id)
		level.set_detail(GraphicsQuality.MeshDetail.LOW)
		assert_null(level.site_material())
		assert_null(SiteDress.build(_map(id), look, level.site_material()))


# 5. The shader's parameters


func test_every_parameter_the_site_shaders_read_is_set_by_the_game() -> void:
	for id in DRESSED:
		var m := _map(id)
		var mat := SiteSurface.material(look, m)
		# the wet mask is set only on a map with puddles; without one wet_rect's zero width skips it in the shader
		var unread: Array[StringName] = [&"low"]
		if m.puddles.is_empty():
			unread.append_array([&"wet_tex", &"wet_rect"])
		# clean surfaces (AD1: grit 0) weigh the photos at nothing, so they are never loaded or set
		if look.grit <= 0.0:
			unread.append_array([&"slab_col", &"slab_nrm", &"ply_col", &"ply_nrm", &"slab_set", &"ply_set"])
		var unset: Array[String] = []
		for u: Dictionary in mat.shader.get_shader_uniform_list():
			if not unread.has(StringName(u["name"])) and mat.get_shader_parameter(u["name"]) == null:
				unset.append(u["name"])
		assert_eq(unset, [] as Array[String], "%s: a renamed parameter would be set on nothing and read as zero" % id)
	var lighting := FieldLighting.build(play.lighting)
	add_child_autofree(lighting)
	SiteDress.dress_sky(lighting, look)
	var sky := lighting.environment.sky.sky_material as ShaderMaterial
	var missing: Array[String] = []
	for u: Dictionary in sky.shader.get_shader_uniform_list():
		if sky.get_shader_parameter(u["name"]) == null:
			missing.append(u["name"])
	# the sun's size and glow keep the shader's own values
	missing = missing.filter(func(n: String) -> bool: return n != "sun_size" and n != "sun_glow")
	assert_eq(missing, [] as Array[String], "the sky's parameters are all set")


# 6. Night


func _night_on(id: String) -> PlaySession:
	var s := Settings.new()
	s.dev.time_of_day = LightingConfig.NIGHT
	var session := PlaySession.new()
	session.map_id = id
	session.practice = id == "range"
	session.settings = s
	session.autopilot = true
	add_child_autofree(session)
	return session


func test_a_site_dressed_map_at_night_keeps_the_night_sky_and_its_fog() -> void:
	for id in DRESSED:
		await _check_night(id)


func _check_night(id: String) -> void:
	var session := _night_on(id)
	await wait_physics_frames(2)
	assert_true(session.lighting().night)
	var env := session._lighting.environment
	var sky := env.sky.sky_material
	assert_true(sky is ShaderMaterial, "%s: the night's own shader sky" % id)
	assert_eq((sky as ShaderMaterial).shader.code, FieldLighting.NIGHT_SKY, "%s: not the day's clouds" % id)
	assert_ne((sky as ShaderMaterial).shader, SiteDress.SKY_SHADER)
	var fresh := FieldLighting.build(session.lighting())
	add_child_autofree(fresh)
	assert_eq(env.fog_enabled, fresh.environment.fog_enabled, "%s: the night's own fog setting" % id)
	assert_eq(env.fog_depth_begin, fresh.environment.fog_depth_begin)
	assert_eq(env.fog_light_color, fresh.environment.fog_light_color, "%s: no day haze colour" % id)
	assert_eq(env.fog_density, fresh.environment.fog_density)
	assert_not_null(session._site, "%s: the site's surfaces are still dressed" % id)
	assert_not_null(session._level.site_material())


func test_the_same_maps_by_day_get_the_clouds_and_the_haze() -> void:
	for id in DRESSED:
		var s := Settings.new()
		s.dev.time_of_day = LightingConfig.DAY
		var session := PlaySession.new()
		session.map_id = id
		session.practice = id == "range"
		session.settings = s
		session.autopilot = true
		add_child_autofree(session)
		await wait_physics_frames(2)
		assert_false(session.lighting().night)
		var env := session._lighting.environment
		assert_eq((env.sky.sky_material as ShaderMaterial).shader, SiteDress.SKY_SHADER, id)
		assert_true(env.fog_enabled, id)
		assert_eq(env.fog_light_color, look.haze_colour, id)


func test_dressing_the_sky_twice_or_on_a_night_light_does_not_break_the_environment() -> void:
	var cfg := play.night_lighting
	var lighting := FieldLighting.build(cfg)
	add_child_autofree(lighting)
	var before := (lighting.environment.sky.sky_material as ShaderMaterial).shader
	assert_not_null(before)
	SiteDress.dress_sky(lighting, look)
	SiteDress.dress_sky(lighting, look)
	assert_eq((lighting.environment.sky.sky_material as ShaderMaterial).shader, SiteDress.SKY_SHADER)


# 7. Nothing left behind


func _counts() -> PackedInt64Array:
	return PackedInt64Array([
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_COUNT)),
	])


func _dress_cycle(id: String) -> void:
	var m := _map(id)
	var level := MapLevel.new()
	add_child(level)
	level.build(m, play.map_style, tuning.body, play.baked_light, _sun(m), false, look)
	level.set_baked_light(true)
	level.set_baked_light(false)
	var dress := SiteDress.build(m, look, level.site_material())
	add_child(dress)
	var lighting := FieldLighting.build(play.lighting)
	add_child(lighting)
	SiteDress.dress_sky(lighting, look)
	remove_child(dress)
	remove_child(level)
	remove_child(lighting)
	dress.free()
	level.free()
	lighting.free()


func test_building_and_freeing_the_level_and_its_dress_leaves_nothing() -> void:
	for id in DRESSED:
		for i in 2:
			_dress_cycle(id) # warms what loads once: the noise textures, the photo sets, the font, the bake
			await wait_physics_frames(2)
		var before := _counts()
		for i in CYCLES:
			_dress_cycle(id)
		await wait_physics_frames(2)
		assert_eq(_counts(), before, "%s: nodes, orphans, resources and objects the same after %d dresses" % [id, CYCLES])


func _match_cycle(id: String) -> void:
	var session := PlaySession.new()
	session.map_id = id
	session.autopilot = true
	add_child(session)
	await wait_physics_frames(2)
	remove_child(session)
	session.free()


func test_leaving_a_dressed_match_over_and_over_leaves_no_node_or_resource() -> void:
	for i in 2:
		await _match_cycle("depot") # warms what loads once
		await wait_process_frames(2)
	var before := _counts()
	for i in MATCHES:
		await _match_cycle("depot")
	await wait_process_frames(3)
	var after := _counts()
	assert_eq(after[0], before[0], "no node left")
	assert_eq(after[1], before[1], "no orphan")
	# the engine's own lazily made resources wander by a couple either way; a dress's mesh, material or texture
	# left behind would add at least one a match
	assert_lt(after[2] - before[2], MATCHES, "no resource left behind, a match after a match")


# 8. The site key in a map file


func _parse(mutate: Callable) -> MapData:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(YardMap.PATH)) # the old yard keeps a sail
	mutate.call(d["dressing"])
	return MapData.parse(JSON.stringify(d), play.map_style, tuning.rounds.team_size)


func test_a_site_that_is_not_an_object_is_drawn_greybox_with_a_warning() -> void:
	for bad: Variant in [3, "yes", [1], true]:
		var m := _parse(func(d: Dictionary) -> void: d["site"] = bad)
		assert_true(m.ok(), "the map still loads with site %s" % [bad])
		assert_null(m.site, "greybox for %s" % [bad])
		assert_eq(m.warnings.filter(func(w: String) -> bool: return w.contains("dressing.site")).size(), 1)
		assert_push_warning("MapData: dressing.site")


func test_a_bad_stencil_or_sail_is_left_out_of_a_real_map_and_the_good_ones_stay() -> void:
	var m := _parse(func(d: Dictionary) -> void:
		var site: Dictionary = d["site"]
		(site["stencils"] as Array).append({"area": "Hall", "x": 1, "y": 1, "z": 1, "facing": "north", "height": 0.5})
		(site["stencils"] as Array).append("Hall")
		(site["sails"] as Array).append({"corners": [], "post": 0.5}))
	assert_true(m.ok())
	var clean := YardMap.load_map(play.map_style, tuning.rounds.team_size)
	assert_eq(m.site.stencils.size(), clean.site.stencils.size(), "the good stencils stay")
	assert_eq(m.site.sails.size(), clean.site.sails.size(), "the good sail stays")
	var warned := m.warnings.filter(func(w: String) -> bool: return w.contains("dressing.site"))
	assert_eq(warned.size(), 3, "each bad entry warned once: %s" % [warned])
	assert_push_warning_count(3)


func test_a_site_with_stencils_or_sails_that_are_not_lists_warns() -> void:
	var pushed := 0
	for key: String in ["stencils", "sails"]:
		var m := _parse(func(d: Dictionary) -> void: d["site"] = {key: {"area": "Hall"}})
		assert_not_null(m.site, "%s: the rest of the site stands" % key)
		var warned := m.warnings.filter(func(w: String) -> bool: return w.contains("dressing.site"))
		assert_gt(warned.size(), 0, "a %s that is no list is reported, not silently dropped" % key)
		pushed += warned.size()
	assert_push_warning_count(pushed)


func test_a_stencil_with_a_height_that_cannot_be_drawn_is_left_out() -> void:
	var warnings: Array[String] = []
	var d := SiteDressing.read({"site": {"stencils": [
		{"area": "Dock", "x": 1, "y": 2, "z": 3, "facing": "+z", "height": "0.5"},
		{"area": "Dock", "x": 1, "y": 2, "z": 3, "facing": "+z", "height": null},
		{"area": "Dock", "x": "1", "y": 2, "z": 3, "facing": "+z", "height": 0.5},
		{"area": 7, "x": 1, "y": 2, "z": 3, "facing": "+z", "height": 0.5},
		{"area": "Dock", "x": 1, "y": 2, "z": 3, "facing": "+z", "height": -2},
	]}}, warnings)
	assert_eq(d.stencils.size(), 0)
	assert_eq(warnings.size(), 5)


# 9. Hunting


func test_every_stencil_has_clear_air_in_front_and_a_wall_behind_its_lettering() -> void:
	var m := _map("depot")
	var font := GameTheme.font(SiteDress.STENCIL_WEIGHT)
	var dress := SiteDress.build(m, look, _level(m, look).site_material())
	add_child_autofree(dress)
	assert_eq(dress.stencils().size(), m.site.stencils.size())
	var unseen: Array[String] = []
	var floating: Array[String] = []
	for i in m.site.stencils.size():
		var s := m.site.stencils[i]
		var basis := Basis(Vector3.UP, s.yaw)
		var out := basis * Vector3.BACK
		var right := basis * Vector3.RIGHT
		var label := dress.stencils()[i]
		var width := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x * label.pixel_size
		for t: float in [-0.5, 0.0, 0.5]:
			var p := s.at + right * (width * t) # the lettering's left, middle, right
			var front := p + out * 0.05
			var behind := p - out * 0.01
			var wall := false
			for b in m.blocks:
				var box := AABB(b.center - b.size * 0.5, b.size)
				if box.grow(1e-4).has_point(front):
					unseen.append("%s buried at %s" % [s.area, front])
				wall = wall or box.grow(1e-3).has_point(behind)
			if not wall:
				floating.append("%s at %.1f m (%.1f wide)" % [s.area, t * width, width])
	assert_eq(unseen, [] as Array[String], "no stencil is inside a block")
	assert_eq(floating, [] as Array[String], "the lettering's ends and middle all have wall behind them")


func test_the_dress_adds_no_collider_light_or_body_to_a_match() -> void:
	var session := PlaySession.new()
	session.autopilot = true
	add_child_autofree(session)
	await wait_physics_frames(2)
	var dress := session._site
	assert_not_null(dress)
	assert_eq(dress.find_children("*", "CollisionObject3D", true, false).size(), 0)
	assert_eq(dress.find_children("*", "Light3D", true, false).size(), 0)
	assert_eq(dress.find_children("*", "NavigationRegion3D", true, false).size(), 0)
	assert_true(session.state.round_state.is_live())


func test_sandbag_layout_is_the_same_every_time_and_draws_nothing_on_a_map_without_stacks() -> void:
	var m := _map("depot")
	var a := PackedFloat32Array()
	var b := PackedFloat32Array()
	var la := SiteDress.bag_layout(m, look, a)
	var lb := SiteDress.bag_layout(m, look, b)
	assert_eq(la, lb, "seeded")
	assert_eq(a, b)
	var none := PackedFloat32Array()
	assert_eq(SiteDress.bag_layout(_map("woodland"), look, none).size(), 0)
	assert_eq(none.size(), 0)
