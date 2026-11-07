extends GutTest
## BP7: MapLevel's build in pieces (`begin`, then `build_some` a slice a loading frame) makes the very level a whole
## `build` makes (every node, collider and mesh alike), a piece a call when the slice is spent, sloping ground's tiles
## and rows over many calls; a level left part built frees whole.

var play: PlayTuning = PlayTuning.load_default()
var tuning: SimTuning = SimTuning.new()


func _level() -> MapLevel:
	var level := MapLevel.new()
	add_child_autofree(level)
	return level


func _begin(level: MapLevel, m: MapData) -> void:
	level.begin(m, play.map_style, tuning.body, play.baked_light, LightingConfig.for_map(play.lighting, null, m,
			LightingConfig.DAY), false, play.site_look)


## Every node under `level` as "path type place what", what being a collider's shape or a mesh's arrays in brief.
static func _picture(level: MapLevel) -> PackedStringArray:
	var out := PackedStringArray()
	var todo: Array[Node] = [level]
	while not todo.is_empty():
		var n: Node = todo.pop_front()
		var line := "%s %s" % [_path(level, n), n.get_class()]
		if n is Node3D:
			line += " %s" % (n as Node3D).transform
		if n is CollisionShape3D:
			line += " " + _shape((n as CollisionShape3D).shape)
		elif n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			line += " " + _mesh((n as MeshInstance3D).mesh)
		out.append(line)
		todo.append_array(n.get_children())
	return out


## `n`'s path under `level`, a node of no name of its own (an engine-made "@" name) by its index.
static func _path(level: Node, n: Node) -> String:
	var parts := PackedStringArray()
	while n != level:
		parts.insert(0, "#%d" % n.get_index() if String(n.name).begins_with("@") else String(n.name))
		n = n.get_parent()
	return "/".join(parts)


static func _shape(s: Shape3D) -> String:
	if s is BoxShape3D:
		return "box %s" % (s as BoxShape3D).size
	if s is ConcavePolygonShape3D:
		var faces := (s as ConcavePolygonShape3D).get_faces()
		return "trimesh %d %s" % [faces.size(), _sum(faces)]
	if s is ConvexPolygonShape3D:
		return "wedge %s" % (s as ConvexPolygonShape3D).points
	return s.get_class()


static func _mesh(mesh: Mesh) -> String:
	var line := "mesh"
	for i in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(i)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		line += " %d %s" % [v.size(), _sum(v)]
	return line


static func _sum(v: PackedVector3Array) -> Vector3:
	var s := Vector3.ZERO
	for p in v:
		s += p
	return s


func test_a_level_built_in_pieces_is_the_level_built_whole() -> void:
	for id: String in ["woodland", "depot", "street"]:
		var m := MapData.load_map(id, play.map_style, tuning.rounds.team_size)
		var whole := _level()
		whole.build(m, play.map_style, tuning.body, play.baked_light, LightingConfig.for_map(play.lighting, null, m,
				LightingConfig.DAY), false, play.site_look)
		var staged := _level()
		_begin(staged, m)
		assert_false(staged.built(), "%s: nothing is built at begin" % id)
		var calls := 1
		# A slice already spent: one piece a call.
		while not staged.build_some(1):
			calls += 1
			assert_lt(calls, 1000, "%s: the build ends" % id)
			if calls >= 1000:
				return
		assert_true(staged.built())
		var a := _picture(staged)
		var b := _picture(whole)
		var first := -1
		for i in mini(a.size(), b.size()):
			if a[i] != b[i]:
				first = i
				break
		assert_eq(a.size(), b.size(), "%s: as many nodes" % id)
		assert_eq(first, -1, "%s: the same nodes, colliders and meshes (first unlike: %s | %s)" % [id,
				a[first] if first >= 0 else "", b[first] if first >= 0 else ""])
		assert_not_null(staged.query(), "%s: the query is made" % id)
		if m.terrain != null:
			assert_gt(calls, 40, "%s: its sloping ground is built over many pieces" % id)
		else:
			assert_gte(calls, 3, "%s: mesh, colliders and the rest are pieces of their own" % id)


func test_a_level_left_part_built_frees_whole() -> void:
	var m := MapData.load_map("woodland", play.map_style, tuning.rounds.team_size)
	var before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var level := MapLevel.new()
	add_child(level)
	_begin(level, m)
	for i in 30:
		level.build_some(1)
	assert_false(level.built(), "part built")
	level.free()
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), before, "no node is left behind")


func test_a_level_left_with_its_bodies_out_of_the_tree_frees_them() -> void:
	# Past COLLIDERS and before REST the static bodies hold their shapes out of the tree (each joins it whole, the
	# bots' replay fix): freeing the level then must free them too (MapLevel's PREDELETE).
	var m := MapData.load_map("woodland", play.map_style, tuning.rounds.team_size)
	var before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var level := MapLevel.new()
	add_child(level)
	_begin(level, m)
	var calls := 0
	while level._piece != MapLevel.Piece.FACES and calls < 400:
		level.build_some(1)
		calls += 1
	assert_eq(level._piece, MapLevel.Piece.FACES, "built past the colliders, into the terrain's faces")
	assert_gt(level._bodies.size(), 0, "its bodies are made")
	assert_null(level._bodies[0].get_parent(), "and still out of the tree")
	level.free()
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), before, "no body is left behind")
