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
