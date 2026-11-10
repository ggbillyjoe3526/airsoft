extends GutTest
## Baked light (DP2): tools/bake_light.gd's per-vertex sky and sun bounce on the tiled mesh (GreyboxFaces.tile), each map's
## bake matching the blocks it was baked from, MapLevel drawing it as vertex colour in one draw call and switching it
## (Settings › Graphics › Baked light) by rebuilding the mesh alone, and a map with no bake drawn as before.

const BakeTool := preload("res://tools/bake_light.gd")
const DIR := "user://test_baked_light"
## Depot's untiled greybox (Low): the faces before DP2.
const DEPOT_UNTILED_VERTICES := 7926
## Open floor in Depot's Chrono hall, clear of the hut and of any lid.
const OPEN_FLOOR := Vector3(8.0, 0.0, 0.0)
## A small yard: a 30 m slab, a wall 4 m tall across it and a 1 m cube; two ends of one spawn each.
const YARD := """{"name": "Yard", "blocks": [
	{"kind": "floor", "center": {"x": 0, "y": -0.25, "z": 0}, "size": {"x": 30, "y": 0.5, "z": 30}},
	{"kind": "wall", "center": {"x": 0, "y": 2, "z": 0}, "size": {"x": 0.4, "y": 4, "z": 8}},
	{"kind": "crate", "center": {"x": -8, "y": 0.5, "z": -8}, "size": {"x": 1, "y": 1, "z": 1}}],
	"spawns": [[{"position": {"x": -10, "y": 0, "z": 10}}], [{"position": {"x": 10, "y": 0, "z": 10}}]],
	"deadZones": [[{"position": {"x": -12, "y": 0, "z": 12}}], [{"position": {"x": 12, "y": 0, "z": 12}}]],
	"bakedLight": {"file": "yard"}}"""

var play: PlayTuning = PlayTuning.load_default()
var body: BodyConfig = BodyConfig.new()


func _yard() -> MapData:
	var m := MapData.parse(YARD, play.map_style, 1)
	m.id = "yard"
	assert_true(m.ok(), "the yard loads: %s" % [m.problems])
	return m


## A quick bake's settings: whole-metre tiles.
func _coarse() -> BakeConfig:
	var cfg := BakeConfig.new()
	cfg.cell = 1.0
	return cfg


## The index of the tiles' vertex at `at` facing `normal`, or -1.
func _vertex(t: GreyboxFaces.Tiles, at: Vector3, normal: Vector3) -> int:
	for v in t.positions.size():
		if t.positions[v].is_equal_approx(at) and t.normals[v].is_equal_approx(normal):
			return v
	return -1


func _mesh_hash(mesh: Mesh) -> String:
	var a := mesh.surface_get_arrays(0)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update((a[Mesh.ARRAY_VERTEX] as PackedVector3Array).to_byte_array())
	ctx.update((a[Mesh.ARRAY_NORMAL] as PackedVector3Array).to_byte_array())
	ctx.update((a[Mesh.ARRAY_COLOR] as PackedColorArray).to_byte_array())
	return ctx.finish().hex_encode()


func _level(map_id: String) -> MapLevel:
	var m := MapData.load_map(map_id, play.map_style, 1)
	assert_true(m.ok(), "%s loads: %s" % [map_id, m.problems])
	var level := MapLevel.new()
	add_child_autofree(level)
	level.build(m, play.map_style, body, play.baked_light, _sun(m))
	return level


## The sun `m` is baked under: the day preset as the map sets it (PlaySession passes the same).
func _sun(m: MapData) -> LightingConfig:
	return LightingConfig.for_map(play.lighting, null, m, LightingConfig.DAY)


func _greybox(level: MapLevel) -> MeshInstance3D:
	return level.get_node("Greybox") as MeshInstance3D


func test_every_bake_matches_the_blocks_it_was_baked_from() -> void:
	var baked := 0
	for file in DirAccess.get_files_at(MapData.DIR):
		if file.get_extension() != "json":
			continue
		var m := MapData.load_map(file.get_basename(), play.map_style, 1)
		if m.baked_light_file.is_empty():
			continue
		baked += 1
		var bake := BakedLight.load_for(m)
		assert_not_null(bake, "%s's bake %s is there" % [m.id, m.baked_light_file])
		if bake == null:
			continue
		var sun := LightingConfig.for_map(play.lighting, null, m, LightingConfig.DAY)
		assert_eq(bake.source_hash, BakedLight.hash_of(m, play.map_style, sun, play.baked_light),
				"%s's blocks changed since its bake: rebake with tools/bake_light.gd" % m.id)
		assert_eq(bake.vertex_count, GreyboxFaces.tile(m, play.baked_light.cell, play.baked_light.ground_y).positions.size(),
				"%s's bake covers its tiles: rebake with tools/bake_light.gd" % m.id)
	assert_gte(baked, 1, "Depot names a bake")


func test_a_moved_block_or_a_new_setting_changes_the_hash() -> void:
	var m := _yard()
	var before := BakedLight.hash_of(m, play.map_style, play.lighting, play.baked_light)
	m.blocks[2].center.x += 0.1
	assert_ne(BakedLight.hash_of(m, play.map_style, play.lighting, play.baked_light), before, "a moved crate")
	m.blocks[2].center.x -= 0.1
	assert_eq(BakedLight.hash_of(m, play.map_style, play.lighting, play.baked_light), before)
	var cfg := BakeConfig.new()
	cfg.rays += 1
	assert_ne(BakedLight.hash_of(m, play.map_style, play.lighting, cfg), before, "a bake setting")
	cfg = BakeConfig.new()
	cfg.bounce_gain *= 2.0
	assert_eq(BakedLight.hash_of(m, play.map_style, play.lighting, cfg), before, "the look needs no rebake")


func test_two_runs_write_the_same_bytes() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var path := DIR.path_join("yard.res")
	var m := _yard()
	var cfg := _coarse()
	assert_eq(BakeTool.save(BakeTool.bake_map(m, play.map_style, play.lighting, cfg), path), OK)
	var first := FileAccess.get_file_as_bytes(path)
	assert_eq(BakeTool.save(BakeTool.bake_map(m, play.map_style, play.lighting, cfg), path), OK)
	assert_gt(first.size(), 0)
	assert_eq(FileAccess.get_file_as_bytes(path), first)
	var back := load(path) as BakedLight
	assert_true(back != null and back.whole(), "it loads back whole")
	DirAccess.remove_absolute(path)


func test_open_ground_sees_the_sky_and_a_sunlit_wall_warms_the_ground_beside_it() -> void:
	var m := _yard()
	var cfg := _coarse()
	var bake: BakedLight = BakeTool.bake_map(m, play.map_style, play.lighting, cfg)
	var t := GreyboxFaces.tile(m, cfg.cell, cfg.ground_y)
	assert_eq(bake.vertex_count, t.positions.size())
	assert_true(bake.whole())
	# The sun's side of the wall (its light travels away from the sun).
	var sun := Basis.from_euler(Vector3(deg_to_rad(-play.lighting.sun_elevation),
			deg_to_rad(play.lighting.sun_heading), 0.0)).z
	var lit := signf(sun.x)
	var open := _vertex(t, Vector3(-14.0 * lit, 0.0, 14.0), Vector3.UP)
	var beside := _vertex(t, Vector3(1.0 * lit, 0.0, 0.0), Vector3.UP)
	var under := _vertex(t, Vector3(-8.0, 0.0, -8.0), Vector3.UP)
	assert_true(open >= 0 and beside >= 0 and under >= 0, "the vertices are on the slab's top")
	assert_eq(bake.sky[open], 255, "open ground sees all the sky")
	assert_eq(bake.bounce[open * 3], 0, "and nothing to bounce off")
	assert_lt(bake.sky[beside], 255, "the wall hides some sky from the ground beside it")
	assert_gt(bake.sky[beside], 0)
	assert_gt(bake.bounce[beside * 3], 0, "the sunlit wall bounces light onto it")
	assert_gt(bake.bounce[beside * 3], bake.bounce[beside * 3 + 2], "warm: more red than blue")
	# Under the crate no one sees: it takes an open neighbour's light (BP7), so the slab round the crate is not drawn
	# darkening toward a vertex hidden in it.
	var round_it: Array[int] = []
	for step: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		round_it.append(bake.sky[_vertex(t, Vector3(-8.0, 0.0, -8.0) + step, Vector3.UP)])
	assert_has(round_it, bake.sky[under], "under the crate takes the light of an open vertex beside it")
	assert_gt(bake.sky[under], 0, "not the dark inside the crate")
	var foot := _vertex(t, Vector3(0.2, 0.0, 0.0), Vector3.RIGHT)
	assert_true(foot >= 0, "the wall's foot")
	assert_lt(bake.sky[foot], bake.sky[_vertex(t, Vector3(0.2, 4.0, 0.0), Vector3.RIGHT)],
			"the wall's foot keeps its shade where it meets the slab")
	var shade := _vertex(t, Vector3(-1.0 * lit, 0.0, 0.0), Vector3.UP)
	assert_eq(bake.bounce[shade * 3], 0, "the wall's shaded side sends no sun back")


func test_depot_draws_its_bake_as_vertex_colour_in_one_draw_call() -> void:
	var level := _level("depot")
	var untiled := _greybox(level).mesh
	assert_eq(untiled.surface_get_array_len(0), DEPOT_UNTILED_VERTICES, "off (as on Low): the untiled faces")
	var bodies := level.get_children().filter(func(n: Node) -> bool: return n is StaticBody3D)
	level.set_baked_light(true)
	assert_true(level.baked_light_drawn())
	var mi := _greybox(level)
	assert_eq(mi.mesh.get_surface_count(), 1, "one surface, one material: one draw call")
	var tiles := GreyboxFaces.tile(level.map, play.baked_light.cell, play.baked_light.ground_y)
	assert_eq(mi.mesh.surface_get_array_len(0), tiles.positions.size() + 4, "the tiles and the ground")
	assert_ne(mi.mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_COLOR, 0)
	assert_eq(mi.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "the tiles cast no shadow")
	var caster := mi.get_node("ShadowCaster") as MeshInstance3D
	assert_eq(caster.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY, "the untiled faces do")
	assert_eq(caster.mesh.surface_get_array_len(0), DEPOT_UNTILED_VERTICES)
	# The west tunnel's floor under its lid is drawn darker than the open floor of the Chrono hall.
	var colours: PackedColorArray = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var inside := _vertex(tiles, Vector3(-29.5, 0.0, 5.0), Vector3.UP)
	var outside := _vertex(tiles, OPEN_FLOOR, Vector3.UP)
	assert_true(inside >= 0 and outside >= 0, "the floor's vertices")
	assert_lt(colours[inside].get_luminance(), colours[outside].get_luminance() * 0.9, "the tunnel is in the shade")
	var after := level.get_children().filter(func(n: Node) -> bool: return n is StaticBody3D)
	assert_eq(after, bodies, "the colliders are the same bodies: the mesh alone was rebuilt")
	level.set_baked_light(false)
	assert_false(level.baked_light_drawn())
	assert_eq(_greybox(level).mesh.surface_get_array_len(0), DEPOT_UNTILED_VERTICES, "off again: untiled")


func test_depot_under_its_shining_lamps_draws_no_sun_bounce_and_switches_back() -> void:
	var level := _level("depot")
	level.set_baked_light(true)
	var sunny: PackedColorArray = _greybox(level).mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var mesh := _greybox(level).mesh
	level.set_baked_light(true, true)
	assert_true(level.baked_light_drawn())
	assert_ne(_greybox(level).mesh, mesh, "rebuilt without the sun's bounce")
	var lamplit: PackedColorArray = _greybox(level).mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	assert_eq(lamplit.size(), sunny.size())
	var warmer := 0
	var brighter := 0
	for i in sunny.size():
		if lamplit[i].get_luminance() > sunny[i].get_luminance() + 1e-4:
			brighter += 1
		if sunny[i].get_luminance() > lamplit[i].get_luminance() + 1e-3:
			warmer += 1
	assert_eq(brighter, 0, "nothing lighter without the sun's bounce")
	assert_gt(warmer, sunny.size() / 10, "the sun's bounce is gone under the lit roof (PT1)")
	mesh = _greybox(level).mesh
	level.set_baked_light(true, true)
	assert_eq(_greybox(level).mesh, mesh, "the same again: not rebuilt")
	level.set_baked_light(true, false)
	assert_eq(_greybox(level).mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR], sunny, "the lamps off: the sun's bounce back")


func test_a_field_with_no_roof_lamps_keeps_the_suns_bounce_whatever_the_lamp_setting() -> void:
	var level := _level("range")
	level.set_baked_light(true)
	var mesh := _greybox(level).mesh
	level.set_baked_light(true, true)
	assert_eq(_greybox(level).mesh, mesh, "nothing to shine: not rebuilt")


func test_depot_at_night_keeps_its_bake_with_no_warning_drawn_by_its_sky_share_alone() -> void:
	var day := _level("depot")
	var m := MapData.load_map("depot", play.map_style, 1)
	var night := MapLevel.new()
	add_child_autofree(night)
	# as PlaySession builds it under the night preset: the day's sun for the hash, the night flag for the drawing
	night.build(m, play.map_style, body, play.baked_light, _sun(m), true)
	night.set_baked_light(true)
	assert_true(night.baked_light_drawn(), "the bake fits: no stale hash, no warning")
	var night_hash := BakedLight.hash_of(m, play.map_style, _sun(m), play.baked_light)
	assert_eq(BakedLight.load_for(m).source_hash, night_hash, "hashed with the day sun it was baked under")
	assert_ne(BakedLight.hash_of(m, play.map_style, play.night_lighting, play.baked_light), night_hash,
			"the moon's sun would mark it stale: never passed")
	day.set_baked_light(true)
	var lit: PackedColorArray = _greybox(day).mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var dark: PackedColorArray = _greybox(night).mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	assert_eq(dark.size(), lit.size())
	var warmer := 0
	var brighter := 0
	for i in lit.size():
		if dark[i].get_luminance() > lit[i].get_luminance() + 1e-4:
			brighter += 1
		if lit[i].get_luminance() > dark[i].get_luminance() + 1e-3:
			warmer += 1
	assert_eq(brighter, 0, "no vertex brighter at night")
	assert_gt(warmer, lit.size() / 10, "the sun's bounce is gone at night")
	# what is left is the sky share alone: an open floor vertex as the sky's share says
	var tiles := GreyboxFaces.tile(m, play.baked_light.cell, play.baked_light.ground_y)
	var open := _vertex(tiles, OPEN_FLOOR, Vector3.UP)
	var bake := BakedLight.load_for(m)
	var own := play.map_style.block_colour(m.blocks[tiles.blocks[open]]).srgb_to_linear()
	var share := 1.0 - play.baked_light.sky_share + play.baked_light.sky_share / BakedLight.FULL * bake.sky[open]
	assert_almost_eq(dark[open].srgb_to_linear().g, own.g * share, 0.003, "sky share alone")


func test_a_map_with_no_bake_draws_as_before_with_it_on() -> void:
	var level := _level("woodland")
	assert_eq(level.map.baked_light_file, "")
	var off := _greybox(level)
	var vertices: int = off.mesh.surface_get_array_len(0)
	var off_hash := _mesh_hash(off.mesh)
	level.set_baked_light(true)
	assert_false(level.baked_light_drawn())
	var mi := _greybox(level)
	assert_eq(mi.mesh.surface_get_array_len(0), vertices)
	assert_eq(_mesh_hash(mi.mesh), off_hash, "the greybox drawn as with it off, byte for byte")
	assert_eq(mi.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)


func test_a_bake_that_doesnt_fit_its_tiles_is_left_out() -> void:
	var level := _level("depot")
	var cfg := play.baked_light.duplicate() as BakeConfig
	cfg.cell = 0.25
	var other := MapLevel.new()
	add_child_autofree(other)
	other.build(level.map, play.map_style, body, cfg)
	other.set_baked_light(true)
	assert_false(other.baked_light_drawn(), "a bake of other tiles is not drawn")
	assert_eq(_greybox(other).mesh.surface_get_array_len(0), DEPOT_UNTILED_VERTICES)
	assert_push_warning("baked from other blocks or settings")


func test_the_graphics_row_is_off_on_low_and_on_from_medium() -> void:
	var table := GraphicsTable.shared()
	assert_false(table.preset(&"low").baked_light)
	for p: StringName in [&"medium", &"high", &"ultra"]:
		assert_true(table.preset(p).baked_light, String(p))
	var level := _level("depot")
	var rs := GraphicsApply.Server.new()
	GraphicsApply.apply_field(table.preset(&"medium"), null, null, rs, level)
	assert_true(level.baked_light_drawn(), "Medium draws it")
	var drawn := _greybox(level)
	GraphicsApply.apply_field(table.preset(&"high"), null, null, rs, level)
	assert_eq(_greybox(level), drawn, "no change, no new mesh")
	GraphicsApply.apply_field(table.preset(&"low"), null, null, rs, level)
	assert_false(level.baked_light_drawn(), "Low doesn't")


func test_a_map_names_its_bake_or_none() -> void:
	assert_eq(MapData.load_map("depot", play.map_style, 1).baked_light_file, "depot")
	var bad := MapData.parse(YARD.replace("{\"file\": \"yard\"}", "{\"file\": 3}"), play.map_style, 1)
	assert_eq(bad.baked_light_file, "")
	assert_eq(bad.warnings.size(), 1, "a warning, and the map still loads")
	assert_true(bad.ok())
	assert_push_warning("bakedLight")


func test_the_tile_count_is_known_before_any_tile_is_made() -> void:
	for id: String in ["depot", "range"]:
		var m := MapData.load_map(id, play.map_style, 1)
		for cell: float in [0.5, 0.25, 1.0]:
			assert_eq(GreyboxFaces.tile_count(m, cell, 0.06), GreyboxFaces.tile(m, cell, 0.06).positions.size(),
					"%s at %.2f m" % [id, cell])


func test_a_tiny_tile_size_is_turned_away_before_tiling() -> void:
	var m := MapData.load_map("depot", play.map_style, 1)
	var cfg := play.baked_light.duplicate() as BakeConfig
	cfg.cell = 0.001
	var level := MapLevel.new()
	add_child_autofree(level)
	level.build(m, play.map_style, body, cfg, _sun(m))
	var started := Time.get_ticks_msec()
	level.set_baked_light(true)
	assert_lt(Time.get_ticks_msec() - started, 200, "no millions of vertices made")
	assert_false(level.baked_light_drawn())
	assert_push_warning("rebake with tools/bake_light.gd")


func test_doors_and_props_follow_the_light_when_only_the_lamps_toggle() -> void:
	var session := PlaySession.new()
	session.map_id = "depot"
	session.practice = true
	session.autopilot = true
	add_child_autofree(session)
	await wait_physics_frames(2)
	var base := GraphicsTable.shared().preset(&"high").copy()
	base.baked_light = true
	base.lamp_lights = GraphicsQuality.LampLights.OFF
	session._apply_graphics(base)
	var lit := base.copy()
	lit.lamp_lights = GraphicsQuality.LampLights.NEAR
	session._apply_graphics(lit)
	assert_true(session._level.baked_light_drawn())
	assert_not_null(session._doors, "Depot has doors")
	var held: PackedColorArray = session._doors._lights_down.duplicate()
	session._relight()
	assert_eq(session._doors._lights_down, held, "the doors hold the light now drawn, not the one before the lamps lit")
