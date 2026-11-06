extends GutTest
## QA for FA1: the face looks' edge ids, empty tables, the cache and the LODs.

var config: FigureConfig = null
var models: FigureModels = null


func before_each() -> void:
	config = FigureConfig.new()
	models = FigureModels.new(config)
	models.load_kinds()


func _body(kind: int, id: int) -> FigureBody:
	var b := FigureBody.new()
	assert_true(b.setup(models, kind, id, 0, Color.RED, 0.0, config.lod_high))
	add_child_autofree(b)
	return b


func _face_looks(b: FigureBody) -> Array[Material]:
	var out: Array[Material] = []
	for mi in b.meshes:
		for s in mi.mesh.get_surface_count():
			var source := mi.mesh.surface_get_material(s)
			if source != null and source.resource_name.to_lower().begins_with("face"):
				out.append(mi.get_surface_override_material(s))
	return out


func test_an_empty_look_table_or_head_list_gives_look_zero_without_error() -> void:
	config.face_offsets = PackedVector2Array()
	assert_eq(config.face_look(5), 0)
	assert_eq(config.face_look(-9223372036854775808), 0)
	config.face_offsets = PackedVector2Array([Vector2.ZERO, Vector2(0.1, 0.0)])
	config.heads = PackedStringArray()
	assert_between(config.face_look(7), 0, 1)
	assert_between(config.face_look(-7), 0, 1)


func test_every_face_surface_on_every_level_wears_the_figures_look() -> void:
	var b := _body(FigureMix.HUMAN, 1)
	var looks := _face_looks(b)
	assert_gt(looks.size(), 0)
	for m in looks:
		assert_not_null(m, "a face surface without its look")


func test_many_figures_make_one_material_per_look_not_per_figure() -> void:
	for id in 40:
		_body(FigureMix.HUMAN, id)
	var made := models.face_material_count()
	assert_lte(made, config.face_offsets.size() - 1, "look 0 is the source: no copy")
	for id in 40:
		_body(FigureMix.HUMAN, id + 40)
	assert_eq(models.face_material_count(), made, "no new copy for more figures")


func test_prewarm_list_holds_each_look_and_makes_no_extra_copies() -> void:
	var list := models.materials(PackedColorArray([Color.RED, Color.BLUE]), 0.0)
	var made := models.face_material_count()
	assert_eq(made, config.face_offsets.size() - 1)
	models.materials(PackedColorArray([Color.RED, Color.BLUE]), 0.0)
	assert_eq(models.face_material_count(), made)
	var offsets: Dictionary[Vector3, bool] = {}
	for m in list:
		if m.resource_name.to_lower().begins_with(config.face_material_prefix):
			offsets[(m as BaseMaterial3D).uv1_offset] = true
	assert_eq(offsets.size(), config.face_offsets.size(), "every look in the warm-up list")
	config.face_offsets = PackedVector2Array()
	models.materials(PackedColorArray([Color.RED]), 0.0)  # empty table must not crash


func test_the_robot_makes_no_face_looks() -> void:
	var before := models.face_material_count()
	_body(FigureMix.ROBOT, 3)
	assert_eq(models.face_material_count(), before)
