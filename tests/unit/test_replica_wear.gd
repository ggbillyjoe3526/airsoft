extends GutTest
## Replica wear (RW1, 2026-11-10): the AEG Rifle's and the GBB Pistol's hands' models carry a baked wear mask
## (tools/blender/replicas/wear.py) as their painted materials' ao_texture, and ReplicaPaint draws those surfaces in the
## worn paint (game/play/replica_wear.gdshader); the figures' copies, the Cyber Pistol and the Sniper Rifle stay plain.

const WORN := ["aeg", "pistol"]
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
