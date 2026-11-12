extends GutTest
## Replica wear (RW1, 2026-11-10): the AEG Rifle's and the GBB Pistol's hands' models carry a baked wear mask
## (tools/blender/replicas/wear.py) as their painted materials' ao_texture, and ReplicaPaint draws those surfaces in the
## worn paint (game/play/replica_surface.gdshader with its `wear` on, MQ1); the figures' copies stay plain and the
## Cyber Pistol and the Sniper Rifle clean.

const WORN := ["aeg", "pistol", "smg"]
const CLEAN := ["cyber", "sniper"]
const MODEL := "res://assets/models/replicas/%s.glb"
const MASK := "res://assets/models/replicas/%s_wear.png"
## The masks are light use, not a repaint: how much of a mask may be rubbed edge or scratch, at most.
const MOST_RUBBED := 0.12
const MOST_SCRATCHED := 0.02

var _models: Array[Node] = []


func before_each() -> void:
	ReplicaPaint.clear()


func after_each() -> void:
	for m in _models:
		m.free()
	_models.clear()
	ReplicaPaint.clear()


func _model(id: String) -> Node:
	var m := (load(MODEL % id) as PackedScene).instantiate()
	_models.append(m)
	return m


## Every painted surface (one of the five parts) of `model`, as [mesh node, surface].
func _painted(model: Node, figures: bool) -> Array:
	var out := []
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or String(mi.name).begins_with("Figure") != figures:
			continue
		for i in mi.mesh.get_surface_count():
			var own := mi.mesh.surface_get_material(i)
			if own != null and ReplicaSchemes.PARTS.has(StringName(own.resource_name)):
				out.append([mi, i])
	return out


func test_worn_models_carry_their_mask_on_every_painted_surface() -> void:
	for id: String in WORN:
		var mask := load(MASK % id) as Texture2D
		assert_not_null(mask, "%s has its wear mask" % id)
		var surfaces := _painted(_model(id), false)
		assert_gt(surfaces.size(), 0, "%s has painted surfaces" % id)
		for s: Array in surfaces:
			assert_eq(ReplicaPaint.wear_mask((s[0] as MeshInstance3D).mesh, s[1]), mask,
					"%s %s surface %d carries the mask" % [id, (s[0] as MeshInstance3D).name, s[1]])


func test_clean_models_carry_no_mask() -> void:
	for id: String in CLEAN:
		var model := _model(id)
		for node: Node in model.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			for i in mi.mesh.get_surface_count():
				assert_null(ReplicaPaint.wear_mask(mi.mesh, i), "%s %s stays clean" % [id, mi.name])


func test_import_lays_the_mask_on_the_surface_uv() -> void:
	# The glb has the mask on TEXCOORD_1; Godot's import makes it these surfaces' UV, as their occlusion texture reads
	# it (the worn paint samples UV). If an engine update ever stops doing that, every UV here would be one point.
	for id: String in WORN:
		for s: Array in _painted(_model(id), false):
			var uv: PackedVector2Array = (s[0] as MeshInstance3D).mesh.surface_get_arrays(s[1])[Mesh.ARRAY_TEX_UV]
			var box := Rect2(uv[0], Vector2.ZERO)
			for p in uv:
				box = box.expand(p)
			assert_true(box.size.x > 0.0 or box.size.y > 0.0 or uv.size() < 3,
					"%s %s surface %d is unwrapped on UV" % [id, (s[0] as MeshInstance3D).name, s[1]])


func test_hands_wear_one_shared_worn_paint_per_part() -> void:
	var a := _model("aeg")
	var b := _model("aeg")
	ReplicaPaint.apply(a, &"cobalt", false)
	ReplicaPaint.apply(b, &"cobalt", false)
	var plain := ReplicaPaint.materials(&"cobalt", false)
	for s: Array in _painted(a, false):
		var mi := s[0] as MeshInstance3D
		var worn := mi.get_surface_override_material(s[1]) as ShaderMaterial
		assert_true(ReplicaPaint.is_worn(worn), "%s surface %d wears the worn paint" % [mi.name, s[1]])
		var part := ReplicaSchemes.PARTS.find(StringName(mi.mesh.surface_get_material(s[1]).resource_name))
		assert_eq(worn.get_shader_parameter(&"albedo"), plain[part].albedo_color, "its paint's colour")
		assert_eq(worn.get_shader_parameter(&"wear_mask"), load(MASK % "aeg"), "its model's mask")
	var first := _painted(a, false)[0] as Array
	var twin := _painted(b, false)[0] as Array
	assert_same((first[0] as MeshInstance3D).get_surface_override_material(first[1]),
			(twin[0] as MeshInstance3D).get_surface_override_material(twin[1]), "two replicas in one paint share it")


func test_a_plain_apply_and_the_figures_copies_wear_the_plain_paint() -> void:
	var model := _model("pistol")
	ReplicaPaint.apply(model, &"ghost", true, false)
	var plain := ReplicaPaint.materials(&"ghost", true)
	for s: Array in _painted(model, false) + _painted(model, true):
		var mi := s[0] as MeshInstance3D
		var part := ReplicaSchemes.PARTS.find(StringName(mi.mesh.surface_get_material(s[1]).resource_name))
		assert_same(mi.get_surface_override_material(s[1]), plain[part], "%s is plain" % mi.name)
	assert_eq(ReplicaPaint.worn_materials().size(), 0, "nothing worn was built")


func test_the_figures_corner_of_the_mask_is_clean() -> void:
	# The figures' copies keep their UVs at the origin (glTF (0, 1)): if drawn worn, they read the mask's bottom-left.
	for id: String in WORN:
		var img := Image.load_from_file(ProjectSettings.globalize_path(MASK % id))
		var corner := img.get_pixel(0, img.get_height() - 1)
		assert_eq(Color(corner.r, corner.g, corner.b), Color(1, 0, 0), "%s's mask is clean at the origin" % id)


func test_the_wear_is_light() -> void:
	for id: String in WORN:
		var img := Image.load_from_file(ProjectSettings.globalize_path(MASK % id))
		img.resize(256, 256, Image.INTERPOLATE_BILINEAR)
		var rubbed := 0
		var scratched := 0
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				rubbed += 1 if c.g > 0.25 else 0
				scratched += 1 if c.b > 0.25 else 0
		var n := float(img.get_width() * img.get_height())
		assert_lt(rubbed / n, MOST_RUBBED, "%s: little of it is rubbed" % id)
		assert_lt(scratched / n, MOST_SCRATCHED, "%s: few scratches" % id)
		assert_gt(rubbed, 0, "%s: some edges are rubbed" % id)


func test_the_worn_paint_follows_the_hands_depth_press() -> void:
	ReplicaPaint.apply(_model("aeg"), &"cobalt", false)
	var worn := ReplicaPaint.worn_materials()
	assert_gt(worn.size(), 0, "worn paints were built")
	var shader := (worn[0] as ShaderMaterial).shader
	var names: Array[StringName] = []
	for u: Dictionary in shader.get_shader_uniform_list():
		names.append(StringName(u["name"]))
	assert_has(names, &"z_clip_scale", "ReplicaView can press its depth")
	assert_true(ReplicaPaint.is_worn((worn[0] as ShaderMaterial).duplicate() as Material), "a copy is still worn")


func _first_override(model: Node) -> Material:
	var s := _painted(model, false)[0] as Array
	return (s[0] as MeshInstance3D).get_surface_override_material(s[1])


func test_repainting_a_model_swaps_the_worn_paint_and_back_to_plain_with_worn_false() -> void:
	var model := _model("aeg")
	ReplicaPaint.apply(model, &"cobalt", false)
	var cobalt := _first_override(model)
	ReplicaPaint.apply(model, &"ghost", true)
	var ghost := _first_override(model)
	assert_true(ReplicaPaint.is_worn(ghost), "the repaint is worn too")
	assert_ne(ghost, cobalt, "a new paint is a new worn material")
	assert_ne(ReplicaPaint.plain_of(ghost), ReplicaPaint.plain_of(cobalt), "over its own plain paint")
	ReplicaPaint.apply(model, &"cobalt", false)
	assert_same(_first_override(model), cobalt, "back to the first paint reuses its worn material")
	ReplicaPaint.apply(model, &"cobalt", false, false)
	assert_false(ReplicaPaint.is_worn(_first_override(model)), "worn=false repaints it plain")


func test_repeated_applies_build_no_duplicate_worn_materials() -> void:
	var model := _model("pistol")
	ReplicaPaint.apply(model, &"cobalt", false)
	var built := ReplicaPaint.worn_materials().size()
	for i in 5:
		ReplicaPaint.apply(model, &"cobalt", false)
		ReplicaPaint.apply(_model("pistol"), &"cobalt", false)
	assert_eq(ReplicaPaint.worn_materials().size(), built, "no new worn material per apply")


func test_the_own_paint_leaves_every_model_unworn() -> void:
	for id: String in WORN + CLEAN:
		var model := _model(id)
		ReplicaPaint.apply(model, ReplicaSchemes.OWN, true)
		ReplicaPaint.apply(model, ReplicaSchemes.OWN, false)
		for node: Node in model.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			for i in mi.mesh.get_surface_count():
				assert_false(ReplicaPaint.is_worn(mi.get_active_material(i)), "%s %s own paint is not worn" % [id, mi.name])
	# their own colours go on their surfaces (MQ1), none of them worn
	for built: Material in ReplicaPaint.worn_materials():
		assert_false(ReplicaPaint.is_worn(built), "nothing worn was built")


func test_clean_models_stay_plain_under_any_paint() -> void:
	for id: String in CLEAN:
		var model := _model(id)
		ReplicaPaint.apply(model, &"cobalt", false)
		for node: Node in model.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			for i in mi.mesh.get_surface_count():
				assert_false(ReplicaPaint.is_worn(mi.get_active_material(i)), "%s %s plain" % [id, mi.name])


func test_clearing_the_cache_keeps_a_live_replicas_worn_paint() -> void:
	var model := _model("aeg")
	ReplicaPaint.apply(model, &"cobalt", false)
	var held := _first_override(model)
	var albedo: Color = (held as ShaderMaterial).get_shader_parameter(&"albedo")
	ReplicaPaint.clear()
	assert_eq(ReplicaPaint.worn_materials().size(), 0, "the cache let go")
	assert_true(is_instance_valid(held), "the live material survives")
	assert_eq((held as ShaderMaterial).get_shader_parameter(&"albedo"), albedo, "unchanged")
	assert_not_null((held as ShaderMaterial).get_shader_parameter(&"wear_mask"), "mask kept")
	assert_not_null(ReplicaPaint.plain_of(held), "its plain paint is kept by the meta")
	var again := _model("aeg")
	ReplicaPaint.apply(again, &"cobalt", false)
	assert_true(ReplicaPaint.is_worn(_first_override(again)), "a new apply after clear is worn")


func test_the_worn_cache_stays_bounded() -> void:
	var model := _model("aeg")
	for p: StringName in ReplicaSchemes.SCHEMES.keys():
		for r: bool in [false, true]:
			ReplicaPaint.apply(model, p, r)
	assert_lte(ReplicaPaint.worn_materials().size(), ReplicaPaint.MAX_WORN)


func test_the_pressed_copy_keeps_the_worn_colour_and_mask() -> void:
	var cfg := ViewModelConfig.new()
	cfg.depth_scale = 0.5
	var view := ReplicaView.new()
	view._cfg = cfg
	add_child_autofree(view)
	var model := _model("aeg")
	ReplicaPaint.apply(model, &"cobalt", false)
	var src := _first_override(model) as ShaderMaterial
	var copy := view._pressed_copy(src) as ShaderMaterial
	assert_ne(copy, src, "a copy")
	assert_true(ReplicaPaint.is_worn(copy))
	assert_eq(copy.get_shader_parameter(&"z_clip_scale"), 0.5)
	assert_eq(copy.get_shader_parameter(&"albedo"), src.get_shader_parameter(&"albedo"))
	assert_eq(copy.get_shader_parameter(&"wear_mask"), src.get_shader_parameter(&"wear_mask"))
	assert_ne(src.get_shader_parameter(&"z_clip_scale"), 0.5, "the shared one is not pressed")
	assert_same(view._pressed_copy(src), copy, "one copy per material")
