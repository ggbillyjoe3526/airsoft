extends GutTest
## MQ2B QA: the budgets the record states, material naming, and what the bomb views leave shared or behind.

const BOMB_TRIANGLES := 5500
const POWER_TRIANGLES := 6000
const POWER_BYTES := 120 * 1000
const FILES := {
	"res://assets/models/grenades/smoke.glb": BOMB_TRIANGLES,
	"res://assets/models/grenades/flash.glb": BOMB_TRIANGLES,
	"res://assets/models/powerSources/gasBottle.glb": POWER_TRIANGLES,
	"res://assets/models/powerSources/lipoBattery.glb": POWER_TRIANGLES,
	"res://assets/models/powerSources/standardBattery.glb": POWER_TRIANGLES,
	"res://assets/models/powerSources/spring.glb": POWER_TRIANGLES,
}


func before_each() -> void:
	ReplicaPaint.clear()


func after_each() -> void:
	ReplicaPaint.clear()


func _triangles(mesh: Mesh) -> int:
	var total := 0
	for i in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(i)
		var index: Variant = arrays[Mesh.ARRAY_INDEX]
		if index != null and (index as PackedInt32Array).size() > 0:
			total += (index as PackedInt32Array).size() / 3
		else:
			total += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total


func test_every_model_stays_inside_its_triangle_budget() -> void:
	for path: String in FILES:
		var mesh := PropDressConfig.load_mesh(path)
		assert_not_null(mesh, path)
		if mesh != null:
			assert_lte(_triangles(mesh), int(FILES[path]), path)


func test_power_sources_stay_inside_their_byte_budget() -> void:
	for path: String in FILES:
		if path.contains("powerSources"):
			assert_lte(FileAccess.get_file_as_bytes(path).size(), POWER_BYTES, path)


func test_no_model_has_a_duplicated_material_name_or_a_suffixed_one() -> void:
	for path: String in FILES:
		var mesh := PropDressConfig.load_mesh(path)
		var seen: Dictionary[String, bool] = {}
		for i in mesh.get_surface_count():
			var material_name := mesh.surface_get_material(i).resource_name
			assert_false(material_name.is_empty(), "%s surface %d is named" % [path, i])
			assert_false(material_name.match("*.0??"), "%s: %s has a Blender suffix" % [path, material_name])
			assert_false(seen.has(material_name), "%s: %s appears twice" % [path, material_name])
			seen[material_name] = true


func test_a_wrong_or_missing_table_names_nothing() -> void:
	var mesh := ArrayMesh.new()
	assert_eq(ReplicaSurfaces.named(mesh).size(), 0, "no extras")
	mesh.set_meta(ReplicaSurfaces.EXTRAS_META, "junk")
	assert_eq(ReplicaSurfaces.named(mesh).size(), 0, "extras not a dictionary")
	mesh.set_meta(ReplicaSurfaces.EXTRAS_META, {ReplicaSurfaces.NAMED_KEY: {"Cap": "nonsense", "Wire": "card"}})
	var named := ReplicaSurfaces.named(mesh)
	assert_false(named.has(&"Cap"), "an unknown kind is dropped")
	assert_eq(named[&"Wire"], ReplicaSurfaces.index(&"card"))


func test_the_views_pressed_copies_are_not_shared_between_two_views() -> void:
	var tuning := SimTuning.new()
	var first := GrenadeView.new()
	add_child_autofree(first)
	first.setup(2, tuning.grenades, false)
	first.setup_arms(ViewModelConfig.new(), FigureMix.HUMAN)
	var second := GrenadeView.new()
	add_child_autofree(second)
	second.setup(2, tuning.grenades, false)
	second.setup_arms(ViewModelConfig.new(), FigureMix.HUMAN)
	var in_first := {}
	for m: Material in first.materials():
		in_first[m] = true
	for kind: int in [Grenade.Kind.SMOKE, Grenade.Kind.FLASH]:
		for paint: Array in [first._held_paint[kind], first._pin_paint[kind]]:
			for m: Material in paint:
				if m != null and ReplicaPaint.is_surface(m):
					assert_ne((m as ShaderMaterial).get_shader_parameter(&"z_clip_scale"), null)
					assert_false(ReplicaPaint.surface_materials().has(m), "a pressed copy is not the shared surface")
	assert_gt(in_first.size(), 0)


func test_freeing_a_view_leaves_no_orphans() -> void:
	var tuning := SimTuning.new()
	var before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var v := GrenadeView.new()
	add_child(v)
	v.setup(2, tuning.grenades, false)
	v.setup_arms(ViewModelConfig.new(), FigureMix.HUMAN)
	v.free()
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), before)


func test_pictures_freed_leave_no_orphans() -> void:
	var before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var pictures := ReplicaPictures.new()
	add_child(pictures)
	pictures.power_texture(&"spring", Color.RED)
	pictures.power_texture(&"standardBattery", Color.RED)
	pictures.grenade_texture(Grenade.Kind.SMOKE)
	pictures.grenade_texture(Grenade.Kind.FLASH)
	remove_child(pictures)
	pictures.free()
	await wait_physics_frames(2)
	assert_lte(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), before)


func test_building_and_freeing_views_and_pictures_leaves_the_shared_store_unchanged() -> void:
	var tuning := SimTuning.new()
	var before := ReplicaPaint.surface_materials().size()
	for n in 2:
		var v := GrenadeView.new()
		add_child(v)
		v.setup(2, tuning.grenades, false)
		v.setup_arms(ViewModelConfig.new(), FigureMix.HUMAN)
		v.free()
	var pictures := ReplicaPictures.new()
	add_child(pictures)
	pictures.power_texture(&"gasBottle", Color.RED)
	pictures.grenade_texture(Grenade.Kind.SMOKE)
	pictures.grenade_texture(Grenade.Kind.FLASH)
	remove_child(pictures)
	pictures.free()
	assert_eq(ReplicaPaint.surface_materials().size(), before)


func test_paint_keys_pressed_copies_by_material_instance_not_name() -> void:
	var a := StandardMaterial3D.new()
	a.resource_name = "Same"
	a.albedo_color = Color.RED
	var b := StandardMaterial3D.new()
	b.resource_name = "Same"
	b.albedo_color = Color.BLUE
	var mesh := ArrayMesh.new()
	for material: Material in [a, b, a]:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	var pressed: Dictionary[Material, Material] = {}
	var out := GrenadeView._paint(mesh, {}, pressed, 0.5)
	assert_eq(pressed.size(), 2, "two instances of one name stay two copies")
	assert_ne(out[0], out[1])
	assert_same(out[0], out[2], "one model material shares one pressed copy")
	assert_eq((out[0] as BaseMaterial3D).albedo_color, Color.RED)


func test_gas_bottle_decals_sit_on_or_outside_the_can_and_face_outward() -> void:
	var mesh := PropDressConfig.load_mesh("res://assets/models/powerSources/gasBottle.glb")
	var aabb := mesh.get_aabb()
	assert_almost_eq(aabb.size.y, 0.3, 0.001, "the can is 300 mm tall")
	assert_lt(aabb.size.x, 0.1, "bounds are sane")
	var checked := 0
	for i in mesh.get_surface_count():
		var material_name := mesh.surface_get_material(i).resource_name
		if material_name == "Can":
			continue
		var wall := _wall_sign(mesh)
		var arrays := mesh.surface_get_arrays(i)
		var verts := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var index := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		for t in range(0, index.size(), 3):
			var a := verts[index[t]]
			var b := verts[index[t + 1]]
			var c := verts[index[t + 2]]
			var mid := (a + b + c) / 3.0
			if mid.y < 0.06 or mid.y > 0.15:
				continue
			checked += 1
			for v: Vector3 in [a, b, c]:
				assert_gte(Vector2(v.x, v.z).length(), 0.033 - 0.00001, "%s vertex under the can" % material_name)
			var normal := (b - a).cross(c - a)
			var out := Vector3(mid.x, 0.0, mid.z)
			assert_gt(normal.dot(out) * wall, 0.0, "%s face wound inward at %s" % [material_name, mid])
	assert_gt(checked, 20, "decal faces were found")


## +1 when the can's own wall faces have (b - a) x (c - a) pointing away from the axis, -1 when towards it (Godot
## winds front faces clockwise), so the decals are compared with the wall's own winding.
func _wall_sign(mesh: Mesh) -> float:
	var total := 0.0
	for i in mesh.get_surface_count():
		if mesh.surface_get_material(i).resource_name != "Can":
			continue
		var arrays := mesh.surface_get_arrays(i)
		var verts := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var index := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		for t in range(0, index.size(), 3):
			var mid := (verts[index[t]] + verts[index[t + 1]] + verts[index[t + 2]]) / 3.0
			if mid.y > 0.06 and mid.y < 0.15:
				var n := (verts[index[t + 1]] - verts[index[t]]).cross(verts[index[t + 2]] - verts[index[t]])
				total += n.dot(Vector3(mid.x, 0.0, mid.z))
	return 1.0 if total >= 0.0 else -1.0


func _gas() -> Mesh:
	return PropDressConfig.load_mesh("res://assets/models/powerSources/gasBottle.glb")


## Every decal face over the whole label (15 to 200 mm up), not only the middle: outside the wall, wound like it.
func test_gas_bottle_print_faces_outward_over_the_whole_label_height() -> void:
	var mesh := _gas()
	var wall := _wall_sign(mesh)
	var bad := 0
	var checked := 0
	for i in mesh.get_surface_count():
		var material_name := mesh.surface_get_material(i).resource_name
		if material_name == "Can":
			continue
		var arrays := mesh.surface_get_arrays(i)
		var verts := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var index := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		for t in range(0, index.size(), 3):
			var a := verts[index[t]]
			var b := verts[index[t + 1]]
			var c := verts[index[t + 2]]
			var mid := (a + b + c) / 3.0
			if mid.y < 0.015 or mid.y > 0.2:
				continue
			var normal := (b - a).cross(c - a)
			if normal.length() < 1e-10:
				continue
			checked += 1
			var out := Vector3(mid.x, 0.0, mid.z).normalized()
			var radial := normal.normalized().dot(out) * wall
			var under := minf(Vector2(a.x, a.z).length(), minf(Vector2(b.x, b.z).length(), Vector2(c.x, c.z).length()))
			if under < 0.033 - 0.00001:
				bad += 1
			elif radial < -0.5:
				bad += 1
	assert_gt(checked, 500, "print faces were found")
	assert_eq(bad, 0, "faces wound inward or under the wall")


func test_no_print_face_is_a_zero_area_sliver_on_the_label_or_print_layers() -> void:
	var mesh := _gas()
	var slivers := 0
	for i in mesh.get_surface_count():
		if mesh.surface_get_material(i).resource_name != "Print":
			continue
		var arrays := mesh.surface_get_arrays(i)
		var verts := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var index := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		for t in range(0, index.size(), 3):
			var n := (verts[index[t + 1]] - verts[index[t]]).cross(verts[index[t + 2]] - verts[index[t]])
			if n.length() < 1e-10:
				slivers += 1
	assert_eq(slivers, 0, "zero-area print faces")


## Two near-radial print faces over one spot must sit apart (>= 0.03 mm) or they z-fight.
func test_gas_bottle_overlapping_print_layers_are_lifted_apart() -> void:
	var mesh := _gas()
	var cells := {}
	for i in mesh.get_surface_count():
		if mesh.surface_get_material(i).resource_name != "Print":
			continue
		var arrays := mesh.surface_get_arrays(i)
		var verts := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var index := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		for t in range(0, index.size(), 3):
			var a := verts[index[t]]
			var b := verts[index[t + 1]]
			var c := verts[index[t + 2]]
			var mid := (a + b + c) / 3.0
			var key := Vector3i(roundi(atan2(mid.z, mid.x) * 33.0 / 0.0004), roundi(mid.y / 0.0004), i)
			var r := Vector2(mid.x, mid.z).length()
			if not cells.has(key):
				cells[key] = []
			(cells[key] as Array).append(r)
	var close := 0
	for key: Vector3i in cells:
		var radii := cells[key] as Array
		for x in radii.size():
			for y in range(x + 1, radii.size()):
				var d := absf(float(radii[x]) - float(radii[y]))
				if d > 0.000005 and d < 0.00003:
					close += 1
	assert_eq(close, 0, "print faces over one spot closer than 0.03 mm")


func test_smoke_lever_with_its_ribs_stays_inside_the_body_and_hand_box() -> void:
	var mesh := PropDressConfig.load_mesh("res://assets/models/grenades/smoke.glb")
	for i in mesh.get_surface_count():
		if mesh.surface_get_material(i).resource_name != "Lever":
			continue
		var verts := mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX] as PackedVector3Array
		for v in verts:
			assert_lte(v.x, 0.0345, "lever sticks out past the ribs' reach")
			assert_gte(v.x, -0.0276, "lever pokes through the body's far side")
			assert_lte(absf(v.z), 0.0135, "lever wider than its flanges")
			assert_lte(v.y, 0.0725, "lever above the pin head")
