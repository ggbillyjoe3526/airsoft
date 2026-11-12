extends GutTest
## Replica surfaces (MQ1, 2026-11-12): every face of a replica's model in the hands says what it is made of in its
## vertex colour's alpha (tools/blender/replicas/surface.py), and ReplicaPaint draws the paint on that surface
## (game/play/replica_surface.gdshader, ReplicaSurfaces): a steel slide on a polymer frame, aluminium receivers, a
## steel barrel. The figures' copies carry no kinds and keep the plain paints.

const REPLICAS := ["aeg", "pistol", "smg", "sniper", "cyber"]
const MODEL := "res://assets/models/replicas/%s.glb"
const SURFACE_PY := "res://tools/blender/replicas/surface.py"
## What each replica's painted materials are mostly made of, by the hands' mesh and material that show it best.
const MADE_OF := [
	["pistol", "Slide", "Body", &"steel"],
	["pistol", "Body", "Furniture", &"polymer"],
	["pistol", "Barrel", "Metal", &"steel"],
	["aeg", "Body", "Body", &"aluminium"],
	["aeg", "Body", "Metal", &"steel"],
	["aeg", "Magazine", "Detail", &"aluminium"],
	["smg", "Body", "Body", &"steel"],
	["smg", "Body", "Furniture", &"polymer"],
	["sniper", "Body", "Furniture", &"polymer"],
	["sniper", "Body", "Metal", &"steel"],
	["cyber", "Body", "CyberSlab", &"coated"],
	["cyber", "Body", "CyberFrame", &"polymer"],
]
## The AEG Rifle's Body material is two things: forged aluminium receivers and a polymer pistol grip.
const MIXED := ["aeg", "Body", "Body", [&"aluminium", &"polymer"]]

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


func _mesh(model: Node, mesh_name: String) -> MeshInstance3D:
	return model.find_child(mesh_name, true, false) as MeshInstance3D


func _surface(mi: MeshInstance3D, material: String) -> int:
	for i in mi.mesh.get_surface_count():
		var own := mi.mesh.surface_get_material(i)
		if own != null and own.resource_name == material:
			return i
	return -1


## How many vertices of surface `i` of `mi` say each kind (by index; ReplicaSurfaces.SLOTS for "none").
func _kinds(mi: MeshInstance3D, i: int) -> Dictionary:
	var out := {}
	var colours: Variant = mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_COLOR]
	if colours == null:
		return out
	for c: Color in colours as PackedColorArray:
		var k := roundi(c.a * ReplicaSurfaces.SLOTS)
		out[k] = int(out.get(k, 0)) + 1
	return out


func _most(kinds: Dictionary) -> int:
	var best := -1
	for k: int in kinds:
		if best < 0 or int(kinds[k]) > int(kinds[best]):
			best = k
	return best


func test_the_kinds_are_the_build_scripts_in_the_same_order() -> void:
	var text := FileAccess.get_file_as_string(SURFACE_PY)
	var at := text.find("KINDS = (")
	assert_gt(at, 0, "surface.py names its kinds")
	var names := text.substr(at + 9, text.find(")", at) - at - 9).replace("\"", "").replace(" ", "").split(",")
	var mine: Array[String] = []
	for k in ReplicaSurfaces.KINDS:
		mine.append(String(k))
	assert_eq(Array(names), mine, "the model files hold the index: the two lists never differ")
	assert_true(text.contains("SLOTS = %d" % ReplicaSurfaces.SLOTS), "and the same step")
	assert_lte(ReplicaSurfaces.KINDS.size(), ReplicaSurfaces.SLOTS, "every kind has a row in the shader's tables")


func test_every_kind_has_a_look() -> void:
	for kind in ReplicaSurfaces.KINDS:
		assert_true(ReplicaSurfaces.LOOKS.has(kind), "%s has a look" % kind)
		var look: Dictionary = ReplicaSurfaces.LOOKS[kind]
		for field: String in ["metallic", "roughness", "sheen", "bares", "tile", "stretch", "relief", "figure",
				"cloud", "dark", "light", "gain"]:
			assert_true(look.has(field), "%s says its %s" % [kind, field])
		assert_gt(float(look["tile"]), 0.0, "%s: a grain that repeats" % kind)
		assert_gte(float(look["stretch"]), 1.0, "%s: stretched along the bore or not at all" % kind)
	assert_gt(float(ReplicaSurfaces.LOOKS[&"steel"]["metallic"]), 0.5, "steel is metal")
	assert_gt(float(ReplicaSurfaces.LOOKS[&"aluminium"]["metallic"]), 0.5, "aluminium is metal")
	assert_eq(float(ReplicaSurfaces.LOOKS[&"polymer"]["metallic"]), 0.0, "polymer is not")
	assert_eq(float(ReplicaSurfaces.LOOKS[&"wood"]["metallic"]), 0.0, "nor wood")
	assert_gt(float(ReplicaSurfaces.LOOKS[&"wood"]["figure"]), 0.0, "wood shows its figure")


func test_an_unknown_kind_and_part_fall_back() -> void:
	assert_eq(ReplicaSurfaces.index(&"cheese"), ReplicaSurfaces.index(ReplicaSurfaces.DEFAULT_KIND))
	assert_eq(ReplicaSurfaces.part_index(&"Metal"), ReplicaSurfaces.index(&"steel"), "a metal part is steel")
	assert_eq(ReplicaSurfaces.part_index(&"Body"), ReplicaSurfaces.index(&"polymer"), "the rest polymer")


func test_every_hands_mesh_says_its_kinds_and_the_figures_copies_none() -> void:
	for id: String in REPLICAS:
		var model := _model(id)
		for node: Node in model.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			if mi.mesh == null:
				continue
			var figure := String(mi.name).begins_with("Figure")
			for i in mi.mesh.get_surface_count():
				var colours: Variant = mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_COLOR]
				if figure:
					assert_null(colours, "%s %s surface %d: a figure's copy carries no kinds" % [id, mi.name, i])
					continue
				assert_not_null(colours, "%s %s surface %d carries kinds" % [id, mi.name, i])
				if colours == null:
					continue
				var own := mi.mesh.surface_get_material(i)
				var painted := own != null and (ReplicaSchemes.PARTS.has(StringName(own.resource_name))
						or own.resource_name.begins_with("Cyber"))
				var bad := 0
				for c: Color in colours as PackedColorArray:
					var k := roundi(c.a * ReplicaSurfaces.SLOTS)
					# White, so the file's own material draws as it did; a known kind on a painted face, none on the rest.
					if c.r < 0.99 or c.g < 0.99 or c.b < 0.99:
						bad += 1
					elif painted and k >= ReplicaSurfaces.KINDS.size():
						bad += 1
					elif not painted and k != ReplicaSurfaces.SLOTS:
						bad += 1
				assert_eq(bad, 0, "%s %s surface %d (%s): every corner white with a kind it may have" % [id, mi.name,
						i, own.resource_name if own != null else "none"])


func test_each_replica_is_made_of_what_the_owner_asked() -> void:
	for row: Array in MADE_OF:
		var mi := _mesh(_model(row[0]), row[1])
		assert_not_null(mi, "%s has a %s" % [row[0], row[1]])
		if mi == null:
			continue
		var i := _surface(mi, row[2])
		assert_gte(i, 0, "%s %s draws %s" % [row[0], row[1], row[2]])
		if i < 0:
			continue
		assert_eq(_most(_kinds(mi, i)), ReplicaSurfaces.index(row[3]), "%s %s %s is mostly %s" % [row[0], row[1],
				row[2], row[3]])


func test_one_material_can_be_two_things() -> void:
	var mi := _mesh(_model(MIXED[0]), MIXED[1])
	var kinds := _kinds(mi, _surface(mi, MIXED[2]))
	for kind: StringName in MIXED[3]:
		assert_gt(int(kinds.get(ReplicaSurfaces.index(kind), 0)), 0, "the AEG Rifle's body has %s faces" % kind)


func test_the_hands_paint_is_drawn_on_its_surface() -> void:
	for id: String in REPLICAS:
		var model := _model(id)
		var paint := ReplicaSchemes.OWN if ReplicaSchemes.OWN_COLOURS.has(StringName(id)) else &"cobalt"
		ReplicaPaint.apply(model, paint, false)
		var surfaced := 0
		for node: Node in model.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			if mi.mesh == null:
				continue
			for i in mi.mesh.get_surface_count():
				var own := mi.mesh.surface_get_material(i)
				var named := StringName(own.resource_name) if own != null else &""
				if not ReplicaSchemes.PARTS.has(named) and not String(named).begins_with("Cyber"):
					continue
				var drawn := mi.get_surface_override_material(i)
				assert_true(ReplicaPaint.is_surface(drawn), "%s %s %s is drawn on its surface" % [id, mi.name, named])
				if not ReplicaPaint.is_surface(drawn):
					continue
				surfaced += 1
				var shader := drawn as ShaderMaterial
				assert_eq(shader.get_shader_parameter(&"grain"), ReplicaSurfaces.GRAIN, "with the shared grain")
				assert_eq((shader.get_shader_parameter(&"kind_finish") as Array).size(), ReplicaSurfaces.SLOTS)
				assert_eq(int(shader.get_shader_parameter(&"default_kind")), ReplicaSurfaces.part_index(named))
		assert_gt(surfaced, 0, "%s has painted surfaces" % id)


func test_a_plain_apply_keeps_the_flat_paints() -> void:
	# The figures' copies (worn = false) are merged by their plain paints (HeldMerge): no shader there.
	var model := _model("aeg")
	ReplicaPaint.apply(model, &"cobalt", false, false)
	var plain := ReplicaPaint.materials(&"cobalt", false)
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var drawn := mi.get_surface_override_material(i)
			if drawn != null:
				assert_true(plain.has(drawn), "%s surface %d wears a plain paint" % [mi.name, i])


func test_a_surfaced_paint_remembers_its_plain_one_and_its_colour() -> void:
	var model := _model("sniper")
	ReplicaPaint.apply(model, &"tan", false)
	var plain := ReplicaPaint.materials(&"tan", false)
	var mi := _mesh(model, "Body")
	var i := _surface(mi, "Furniture")
	var drawn := mi.get_surface_override_material(i) as ShaderMaterial
	var part := ReplicaSchemes.PARTS.find(&"Furniture")
	assert_eq(ReplicaPaint.plain_of(drawn), plain[part], "its plain paint")
	assert_eq(drawn.get_shader_parameter(&"albedo"), plain[part].albedo_color, "in its colour")
	assert_false(ReplicaPaint.is_worn(drawn), "the Sniper Rifle carries no wear mask: clean")
	assert_eq(float(drawn.get_shader_parameter(&"wear")), 0.0)


func test_the_cyber_pistols_lines_still_glow_on_their_surface_and_not_under_realistic_colours() -> void:
	var model := _model("cyber")
	ReplicaPaint.apply(model, ReplicaSchemes.OWN, false)
	var mi := _mesh(model, "Body")
	var i := _surface(mi, "CyberLine")
	var own := mi.mesh.surface_get_material(i) as StandardMaterial3D
	var drawn := mi.get_surface_override_material(i) as ShaderMaterial
	assert_true(ReplicaPaint.is_surface(drawn))
	assert_true(own.emission_enabled, "the file's line glows")
	assert_eq(drawn.get_shader_parameter(&"emission"), own.emission, "and so does its surface")
	assert_gt(float(drawn.get_shader_parameter(&"emission_energy")), 0.0)
	ReplicaPaint.apply(model, ReplicaSchemes.OWN, true)
	var grey := mi.get_surface_override_material(i) as ShaderMaterial
	assert_true(ReplicaPaint.is_surface(grey), "Realistic colours: still on its surface")
	assert_eq(float(grey.get_shader_parameter(&"emission_energy")), 0.0, "but plain, with no glow")
	ReplicaPaint.apply(model, ReplicaSchemes.OWN, false)
	assert_eq(mi.get_surface_override_material(i), drawn, "and back again, the same shared material")


func test_the_grain_tiles_and_is_small() -> void:
	var grain := ReplicaSurfaces.GRAIN
	assert_eq(grain.get_width(), grain.get_height(), "square")
	assert_lte(grain.get_width(), 512, "one small texture for every replica")
	var img := grain.get_image()
	if img.is_compressed():
		img.decompress()
	# Flat on average: a slope map centred on 0.5 never tilts a whole face.
	var sum := Vector2.ZERO
	for y in range(0, img.get_height(), 8):
		for x in range(0, img.get_width(), 8):
			var c := img.get_pixel(x, y)
			sum += Vector2(c.r, c.g)
	var n := float((img.get_height() / 8) * (img.get_width() / 8))
	assert_almost_eq(sum.x / n, 0.5, 0.02, "the grain's slope averages flat across")
	assert_almost_eq(sum.y / n, 0.5, 0.02, "and up")


func test_the_menus_pictures_have_a_studio_to_reflect() -> void:
	var env := Environment.new()
	StudioSky.light(env)
	assert_eq(env.reflected_light_source, Environment.REFLECTION_SOURCE_SKY)
	assert_eq(env.sky, StudioSky.sky(), "one shared studio")
	assert_ne(env.background_mode, Environment.BG_SKY, "never drawn behind the replica")


func test_a_plain_apply_takes_the_own_colours_surfaces_off_again() -> void:
	var model := _model("cyber")
	ReplicaPaint.apply(model, ReplicaSchemes.OWN, false)
	ReplicaPaint.apply(model, ReplicaSchemes.OWN, false, false)
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			assert_null(mi.get_surface_override_material(i), "%s surface %d wears the model's own again" % [mi.name, i])
