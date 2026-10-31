extends GutTest
## DP2 QA: the tiled mesh is a faithful cut of the greybox (winding, area), maps without a bake draw byte for byte as on
## the base, a missing, broken or stale bake draws safely with a warning, switching the row repeatedly leaks nothing and
## leaves the colliders alone, and the Box's roof is sealed (sun patches on its floor come through the ports).

const BROKEN := "qa_broken"
const SHORT := "qa_short"
const MISCOUNT := "qa_miscount"
const SWITCHES := 12
## The meshes the base (origin/main 79969e6) drew, as SHA-256 of vertices, normals and colours (first 16 hex). Woodland
## left it in WL1, its ground drawn at last; WA1 repainted the greybox kinds from the look's palette.
const BASE_HASHES: Dictionary[String, String] = {
	"depot": "cd4626461cff8e0c", # the hall (DR1), the palette's colours (WA1)
	"range": "d8e76694957be155",
}

var play: PlayTuning = PlayTuning.load_default()
var body: BodyConfig = BodyConfig.new()


func after_all() -> void:
	for f: String in [BROKEN, SHORT, MISCOUNT]:
		var path := BakeConfig.path_for(f)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _level(map_id: String) -> MapLevel:
	var m := MapData.load_map(map_id, play.map_style, 1)
	assert_gt(m.blocks.size(), 0, "%s loads" % map_id)
	return _level_of(m)


func _level_of(m: MapData) -> MapLevel:
	var level := MapLevel.new()
	add_child_autofree(level)
	var sun := LightingConfig.for_map(play.lighting, null, m, LightingConfig.DAY) # the sun the map is baked under
	level.build(m, play.map_style, body, play.baked_light, sun)
	return level


func _greybox(level: MapLevel) -> MeshInstance3D:
	return level.get_node("Greybox") as MeshInstance3D


func _mesh_hash(mesh: Mesh) -> String:
	var a := mesh.surface_get_arrays(0)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update((a[Mesh.ARRAY_VERTEX] as PackedVector3Array).to_byte_array())
	ctx.update((a[Mesh.ARRAY_NORMAL] as PackedVector3Array).to_byte_array())
	ctx.update((a[Mesh.ARRAY_COLOR] as PackedColorArray).to_byte_array())
	return ctx.finish().hex_encode().substr(0, 16)


func _shapes(level: MapLevel) -> Array[Shape3D]:
	var out: Array[Shape3D] = []
	for n in level.get_children():
		if n is StaticBody3D:
			for c in n.get_children():
				out.append((c as CollisionShape3D).shape)
	return out


func _fake_map(file: String) -> MapData:
	var m := MapData.load_map("depot", play.map_style, 1)
	m.baked_light_file = file
	return m


func test_maps_without_a_bake_and_every_untiled_mesh_draw_as_the_base_did() -> void:
	for id: String in BASE_HASHES:
		var level := _level(id)
		level.set_baked_light(true) # a switch for the baked two (Woodland's no-op below)
		level.set_baked_light(false)
		assert_eq(_mesh_hash(_greybox(level).mesh), BASE_HASHES[id], "%s off: the base's mesh" % id)
		assert_eq(_greybox(level).cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON, id)
		assert_eq(_greybox(level).get_child_count(), 0, "%s: no shadow caster child when off" % id)
	for id: String in ["woodland"]:
		var level := _level(id)
		var off := _mesh_hash(_greybox(level).mesh)
		level.set_baked_light(true)
		assert_false(level.baked_light_drawn(), "%s names no bake" % id)
		assert_eq(_mesh_hash(_greybox(level).mesh), off, "%s with the row on: the mesh drawn without it" % id)


func test_the_tiles_wind_with_their_normals_and_cover_each_face_exactly() -> void:
	var m := MapData.load_map("depot", play.map_style, 1)
	var t := GreyboxFaces.tile(m, play.baked_light.cell, play.baked_light.ground_y)
	var tiled := 0.0
	var wrong := 0
	for i in range(0, t.indices.size(), 3):
		var a := t.positions[t.indices[i]]
		var b := t.positions[t.indices[i + 1]]
		var c := t.positions[t.indices[i + 2]]
		var cross := (b - a).cross(c - a)
		tiled += cross.length() * 0.5
		if cross.dot(t.normals[t.indices[i]]) >= 0.0: # Godot's front face is clockwise, as the untiled mesh winds
			wrong += 1
	assert_eq(wrong, 0, "triangles wound the wrong way round (they'd be culled)")
	var whole := 0.0
	for b in m.blocks:
		for f in GreyboxFaces.faces_of(b):
			for k in range(1, f.size() - 1):
				whole += (f[k] - f[0]).cross(f[k + 1] - f[0]).length() * 0.5
	assert_almost_eq(tiled, whole, whole * 1e-4, "no gap and no overlap: the tiles' area is the faces'")


func test_a_missing_bake_draws_untiled_with_one_warning_and_no_crash() -> void:
	var level := _level_of(_fake_map("qa_not_there"))
	var before := _mesh_hash(_greybox(level).mesh)
	level.set_baked_light(true)
	assert_false(level.baked_light_drawn())
	assert_eq(_mesh_hash(_greybox(level).mesh), before, "the same mesh")
	assert_push_warning("missing or broken")
	level.set_baked_light(false)
	level.set_baked_light(true) # the file is not looked for again
	assert_false(level.baked_light_drawn())
	assert_push_warning_count(1)


func test_a_garbage_or_truncated_bake_draws_untiled_with_a_warning() -> void:
	var f := FileAccess.open(BakeConfig.path_for(BROKEN), FileAccess.WRITE)
	f.store_string("not a resource")
	f.close()
	var level := _level_of(_fake_map(BROKEN))
	level.set_baked_light(true)
	assert_false(level.baked_light_drawn(), "garbage")
	var short := BakedLight.new()
	short.vertex_count = 100
	short.sky.resize(100)
	short.bounce.resize(10)
	assert_false(short.whole(), "a bake whose arrays are short is not whole")
	assert_eq(ResourceSaver.save(short, BakeConfig.path_for(SHORT)), OK)
	var level2 := _level_of(_fake_map(SHORT))
	level2.set_baked_light(true)
	assert_false(level2.baked_light_drawn(), "truncated arrays")
	assert_eq(_mesh_hash(_greybox(level2).mesh), BASE_HASHES["depot"])
	assert_engine_error_count(2, "the garbage file's load errors are the engine's own")
	assert_push_warning_count(2)


func test_a_stale_bake_of_the_right_size_draws_untiled_with_one_warning() -> void:
	var m := MapData.load_map("depot", play.map_style, 1)
	var level := _level_of(m)
	var real := BakedLight.load_for(m)
	var n := GreyboxFaces.tile(m, play.baked_light.cell, play.baked_light.ground_y).positions.size()
	assert_eq(real.vertex_count, n)
	var good := real.source_hash
	real.source_hash = "stale" # the cached copy the level loads
	level.set_baked_light(true)
	real.source_hash = good
	assert_false(level.baked_light_drawn(), "a stale hash draws untiled, whatever the vertex count")
	assert_eq(_mesh_hash(_greybox(level).mesh), BASE_HASHES["depot"])
	assert_push_warning("rebake with tools/bake_light.gd")
	level.set_baked_light(false)
	level.set_baked_light(true)
	assert_push_warning_count(1, "warned once")


func test_a_bake_of_the_right_hash_but_another_vertex_count_draws_untiled() -> void:
	var real := BakedLight.load_for(_fake_map("depot"))
	var n := real.vertex_count - 1
	var bad := BakedLight.new()
	bad.source_hash = real.source_hash
	bad.vertex_count = n
	bad.sky = real.sky.slice(0, n)
	bad.bounce = real.bounce.slice(0, n * 3)
	assert_true(bad.whole(), "a whole bake, one vertex short of the tiles")
	assert_eq(ResourceSaver.save(bad, BakeConfig.path_for(MISCOUNT)), OK)
	var level := _level_of(_fake_map(MISCOUNT))
	level.set_baked_light(true)
	assert_false(level.baked_light_drawn(), "the count is checked even when the hash matches")
	assert_eq(_mesh_hash(_greybox(level).mesh), BASE_HASHES["depot"])
	assert_push_warning("vertices for")
	assert_push_warning_count(1)


func test_switching_the_row_over_and_over_leaks_nothing_and_leaves_the_colliders() -> void:
	var table := GraphicsTable.shared()
	var rs := GraphicsApply.Server.new()
	var level := _level("depot")
	var shapes := _shapes(level)
	var children := level.get_child_count()
	_cycle(table, rs, level) # two rounds warm what loads once (the engine's and the test's own)
	await wait_physics_frames(2)
	_cycle(table, rs, level)
	await wait_physics_frames(2)
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var resources := int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	var objects := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	for i in SWITCHES:
		_cycle(table, rs, level)
	await wait_physics_frames(3)
	assert_false(level.baked_light_drawn())
	assert_eq(level.get_child_count(), children, "the level's children are the same in number")
	assert_eq(_shapes(level), shapes, "the same collision shapes, untouched")
	assert_eq(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), nodes, "no node left")
	assert_eq(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), orphans, "no orphan")
	assert_eq(int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)), resources, "no resource left")
	assert_eq(int(Performance.get_monitor(Performance.OBJECT_COUNT)), objects, "no object left")


## Medium, Low, Ultra, Low, High, Low through the row's own path, each a switch or a no-op.
func _cycle(table: GraphicsTable, rs: GraphicsApply.Server, level: MapLevel) -> void:
	for p: StringName in [&"medium", &"low", &"ultra", &"low", &"high", &"low"]:
		GraphicsApply.apply_field(table.preset(p), null, null, rs, level)


func test_the_replaced_mesh_is_freed_and_the_new_one_is_where_the_old_was() -> void:
	var level := _level("depot")
	var old := _greybox(level)
	level.set_baked_light(true)
	await wait_physics_frames(2)
	assert_false(is_instance_valid(old), "the old mesh node is freed")
	var named := level.get_children().filter(func(n: Node) -> bool: return n is MeshInstance3D)
	assert_eq(named.size(), 1, "one mesh at a time")
	assert_eq(str(named[0].name), "Greybox", "and it keeps its name")


func test_the_boxs_roof_is_sealed_for_bbs_and_for_the_sun() -> void:
	var level := _level_of(YardMap.load_map(play.map_style, 1)) # the old yard's Box (DR1)
	await wait_physics_frames(2)
	var box: MapAreas.Area = null
	for a in level.map.areas:
		if a.name == "Box":
			box = a
	assert_not_null(box, "the yard names the Box")
	var q := level.query()
	var hit := RayHit.new()
	var leaks := 0
	# BBs falling onto the roof, straight down and along the sun's slant, stop in it and never reach the floor.
	var sun := Basis.from_euler(Vector3(deg_to_rad(-play.lighting.sun_elevation),
			deg_to_rad(play.lighting.sun_heading), 0.0)).z
	var x := box.x0 + 0.02
	while x < box.x1:
		var z := box.z0 + 0.02
		while z < box.z1:
			var on_roof := Vector3(x, 2.6, z)
			for up: Vector3 in [Vector3.UP, sun]:
				if q.ray(on_roof + up * 2.0, on_roof - up * 0.1, hit) and hit.position.y < 2.5:
					leaks += 1
				elif not q.ray(on_roof + up * 2.0, on_roof - up * 0.1, hit):
					leaks += 1
			z += 0.1
		x += 0.1
	assert_eq(leaks, 0, "a ray onto the Box's roof reaches the floor")
	# Every floor spot the sun reaches inside the Box has its sunbeam leave through a wall (port or door), not the roof.
	var through_roof := 0
	var lit := 0
	x = box.x0 + 0.25
	while x < box.x1 - 0.25:
		var z := box.z0 + 0.25
		while z < box.z1 - 0.25:
			var p := Vector3(x, 0.02, z)
			if not q.ray(p, p + sun * 40.0, hit):
				lit += 1
				var t := (2.5 - p.y) / sun.y
				var at := p + sun * t
				if at.x > box.x0 and at.x < box.x1 and at.z > box.z0 and at.z < box.z1:
					through_roof += 1
			z += 0.1
		x += 0.1
	assert_gt(lit, 0, "the sun does reach the Box's floor, through its ports")
	assert_eq(through_roof, 0, "no sunbeam passes the roof's plane inside its footprint")
