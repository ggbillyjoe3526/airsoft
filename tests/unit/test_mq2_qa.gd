extends GutTest
## MQ2 QA: ReplicaPaint.apply over every part of every parts file in every scheme, repeated applies, and the
## replicas' own meshes.

const FILES: Array[String] = ["aeg", "pistol", "cyber", "sniper", "smg"]
const PARTS := "res://assets/models/replicaParts/%s.glb"
const REPLICAS := "res://assets/models/replicas/%s.glb"
## Materials that must stay as the file has them whatever the paint (glass, fibre, lit parts, BBs).
const NEVER_SURFACED: Array[String] = ["Lens", "LensDot", "TorchLens", "LaserLens", "Led", "Fibre", "Glass", "BB"]

var _nodes: Array[Node] = []


func before_each() -> void:
	ReplicaPaint.clear()


func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()
	ReplicaPaint.clear()


func _file(path: String) -> Node:
	var model := (load(path) as PackedScene).instantiate()
	_nodes.append(model)
	return model


func _meshes(model: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for n in model.find_children("*", "MeshInstance3D", true, false):
		out.append(n as MeshInstance3D)
	return out


func _paints() -> Array[StringName]:
	var out: Array[StringName] = [ReplicaSchemes.OWN, &"cobalt", &"ghost", &"tan", &"black"]
	for k: StringName in ReplicaSchemes.SCHEMES:
		out.append(k)
	return out


func _worn_ids(model: Node) -> Dictionary:
	var out := {}
	for mi in _meshes(model):
		for i in mi.mesh.get_surface_count():
			out["%s/%d" % [mi.name, i]] = mi.get_surface_override_material(i)
	return out


func test_no_scheme_surfaces_glass_lens_led_or_fibre_and_none_leaves_an_invalid_override() -> void:
	for id in FILES:
		var model := _file(PARTS % id)
		for paint in _paints():
			for realistic: bool in [false, true]:
				for surfaced: bool in [true, false]:
					ReplicaPaint.apply(model, paint, realistic, surfaced)
					for mi in _meshes(model):
						for i in mi.mesh.get_surface_count():
							var own := mi.mesh.surface_get_material(i)
							var worn := mi.get_surface_override_material(i)
							var tag := "%s %s/%d %s real=%s surf=%s" % [id, mi.name, i, paint, realistic, surfaced]
							if worn != null:
								assert_true(is_instance_valid(worn), tag)
							if own != null and NEVER_SURFACED.has(own.resource_name) and not String(mi.name).contains("_Figure"):
								assert_false(ReplicaPaint.is_surface(worn), "never surfaced: " + tag)
							if not surfaced:
								assert_false(ReplicaPaint.is_surface(worn), "plain apply leaves no surface: " + tag)


func test_repeated_applies_do_not_stack_or_grow_the_cache() -> void:
	var model := _file(PARTS % "aeg")
	var first := {}
	for round_no in 3:
		for paint in _paints():
			ReplicaPaint.apply(model, paint, false)
			ReplicaPaint.apply(model, paint, true, false)
		ReplicaPaint.apply(model, &"cobalt", false)
		var now := _worn_ids(model)
		if round_no == 0:
			first = now
		else:
			assert_eq(now, first, "the same shared materials every round")
	assert_lte(ReplicaPaint.surface_materials().size(), ReplicaPaint.MAX_SURFACED, "the cache is bounded")
	ReplicaPaint.clear()
	assert_eq(ReplicaPaint.surface_materials().size(), 0, "clear() empties it")


func test_surfaced_then_plain_returns_every_override_to_what_a_fresh_plain_apply_gives() -> void:
	for id in FILES:
		var fresh := _file(PARTS % id)
		var again := _file(PARTS % id)
		ReplicaPaint.apply(fresh, &"signal", false, false)
		ReplicaPaint.apply(again, &"signal", false)
		ReplicaPaint.apply(again, &"signal", false, false)
		for mi in _meshes(fresh):
			var other := again.find_child(mi.name, true, false) as MeshInstance3D
			for i in mi.mesh.get_surface_count():
				assert_eq(other.get_surface_override_material(i), mi.get_surface_override_material(i),
						"%s %s/%d" % [id, mi.name, i])


func test_the_replicas_own_meshes_name_no_kinds_and_are_painted_as_before() -> void:
	for id in FILES:
		var model := _file(REPLICAS % id)
		for mi in _meshes(model):
			assert_true(ReplicaSurfaces.named(mi.mesh).is_empty(), "%s %s: a replica names none" % [id, mi.name])
		ReplicaPaint.apply(model, &"cobalt", false)
		for mi in _meshes(model):
			for i in mi.mesh.get_surface_count():
				var own := mi.mesh.surface_get_material(i)
				var worn := mi.get_surface_override_material(i)
				if own != null and not ReplicaSchemes.PARTS.has(StringName(own.resource_name)):
					assert_null(worn, "%s %s: a material that isn't a paint part is untouched" % [id, mi.name])
				elif worn != null and ReplicaPaint.is_surface(worn):
					var kind := int((worn as ShaderMaterial).get_shader_parameter(&"default_kind"))
					assert_eq(kind, ReplicaSurfaces.part_index(StringName(own.resource_name)), "usual kind")


func test_a_mesh_with_a_table_naming_a_part_material_paints_it_on_that_kind_and_no_other_table_changes_others() -> void:
	var model := _file(PARTS % "aeg")
	ReplicaPaint.apply(model, &"cobalt", false)
	for mi in _meshes(model):
		var named := ReplicaSurfaces.named(mi.mesh)
		for i in mi.mesh.get_surface_count():
			var material_name: StringName = StringName(mi.mesh.surface_get_material(i).resource_name)
			var worn := mi.get_surface_override_material(i)
			if named.has(material_name) and ReplicaPaint.is_surface(worn):
				assert_eq(int((worn as ShaderMaterial).get_shader_parameter(&"default_kind")), named[material_name],
						"%s/%s" % [mi.name, material_name])


func test_no_part_is_over_the_triangle_budget_and_carries_only_the_surfaces_table() -> void:
	for id in FILES:
		for mi in _meshes(_file(PARTS % id)):
			var tris := 0
			for i in mi.mesh.get_surface_count():
				var arrays := mi.mesh.surface_get_arrays(i)
				var idx: Variant = arrays[Mesh.ARRAY_INDEX]
				tris += (idx as PackedInt32Array).size() / 3 if idx != null else 0
			var is_copy := String(mi.name).contains("_Figure")
			assert_lte(tris, 600 if is_copy else 9999, "%s %s triangles" % [id, mi.name])
			if mi.mesh.has_meta(ReplicaSurfaces.EXTRAS_META):
				var extras: Variant = mi.mesh.get_meta(ReplicaSurfaces.EXTRAS_META)
				assert_true(extras is Dictionary and (extras as Dictionary).keys() == [ReplicaSurfaces.NAMED_KEY],
						"%s %s: extras hold only the surfaces table" % [id, mi.name])
				assert_false(is_copy, "%s %s: a figure copy has no table" % [id, mi.name])


func test_a_silencers_dark_rubber_cap_details_keep_their_own_colour_in_every_paint() -> void:
	for id: String in ["aeg", "pistol", "smg"]:
		var model := _file(PARTS % id)
		for paint in _paints():
			ReplicaPaint.apply(model, paint, false)
			for mi in _meshes(model):
				if not String(mi.name).begins_with("muzzle_silencer") or String(mi.name).contains("_Figure"):
					continue
				for i in mi.mesh.get_surface_count():
					var own := mi.mesh.surface_get_material(i)
					if own.resource_name == "Rubber":
						assert_eq(ReplicaPaint.plain_of(mi.get_surface_override_material(i)), own,
								"%s %s: rubber not painted over (%s)" % [id, mi.name, paint])


func _surface_extent(mesh: Mesh, material_name: String) -> AABB:
	var box := AABB()
	var first := true
	for i in mesh.get_surface_count():
		if mesh.surface_get_material(i).resource_name != material_name:
			continue
		for v in (mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			box = AABB(v, Vector3.ZERO) if first else box.expand(v)
			first = false
	return box


func _tris_of(mesh: Mesh, material_name: String) -> int:
	var tris := 0
	for i in mesh.get_surface_count():
		if mesh.surface_get_material(i).resource_name == material_name:
			tris += (mesh.surface_get_arrays(i)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return tris


func test_no_parts_file_carries_a_duplicate_suffixed_material_and_every_file_is_within_its_cap() -> void:
	var paths: Array[String] = ["res://assets/models/replicaParts/inside/aeg.glb"]
	for id in FILES:
		paths.append(PARTS % id)
	for path in paths:
		assert_lt(FileAccess.get_file_as_bytes(path).size(), 4 * 1024 * 1024, "%s within the 4 MiB cap" % path)
		for mi in _meshes(_file(path)):
			for i in mi.mesh.get_surface_count():
				var material_name := mi.mesh.surface_get_material(i).resource_name
				assert_false(material_name.contains("."), "%s %s: material '%s' is a duplicate" % [path, mi.name, material_name])


func test_each_magazine_part_keeps_every_material_slot_and_its_balls() -> void:
	var expected := {
		"aeg/magazine_hiCap": ["Detail", "Rubber", "BB", "Metal"],
		"aeg/magazine_lowCap": ["Detail", "Rubber", "BB"],
		"pistol/magazine_extended": ["Detail", "Metal", "BB", "Accent", "Furniture", "Rubber"],
	}
	for key: String in expected:
		var parts := key.split("/")
		var found := false
		for mi in _meshes(_file(PARTS % parts[0])):
			if mi.name != StringName(parts[1]):
				continue
			found = true
			for material_name: String in expected[key]:
				assert_gt(_tris_of(mi.mesh, material_name), 0, "%s keeps its %s slot" % [key, material_name])
			assert_gt(_tris_of(mi.mesh, "BB"), 1000, "%s keeps all of its BBs" % key)
		assert_true(found, "%s exists" % key)


func test_the_long_barrels_open_backed_crown_is_buried_in_the_barrel_and_sealed_by_the_inner_barrel() -> void:
	var outside: MeshInstance3D
	var inside: MeshInstance3D
	for mi in _meshes(_file(PARTS % "aeg")):
		if mi.name == &"barrel_long":
			outside = mi
	for mi in _meshes(_file("res://assets/models/replicaParts/inside/aeg.glb")):
		if mi.name == &"barrel_long_Inside":
			inside = mi
	assert_not_null(outside)
	assert_not_null(inside)
	var crown := _surface_extent(outside.mesh, "Brass")
	var body := _surface_extent(outside.mesh, "Metal")
	var inner := _surface_extent(inside.mesh, "Brass")
	assert_eq(outside.position, inside.position, "the inside sits on the barrel")
	# The crown's back edge (its highest z) lies inside the body's length and within its radius, so no back face shows.
	assert_gt(crown.end.z, body.position.z, "crown's back edge is behind the body's front")
	assert_lt(crown.end.z, body.end.z, "crown's back edge is inside the body")
	assert_lt(maxf(crown.end.x, crown.end.y), minf(body.end.x, body.end.y), "crown narrower than the body")
	# The inner barrel starts where the crown ends, so the Loadout picture has no gap behind it.
	assert_lte(inner.position.z, crown.end.z + 0.0002, "inner barrel meets the crown's back edge")
	assert_gte(inner.end.x, crown.end.x - 0.0002, "inner barrel is as wide as the crown")
