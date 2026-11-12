extends GutTest
## MQ2B: what the bombs and the power sources are made of (owner, 2026-11-12: "go over all the attachment and accessory
## models and improve their quality and make them look more realistic and detailed"). Each file names a kind for its
## materials in its mesh's table (ReplicaSurfaces.named); the bomb in your hand and the menus' pictures draw them on
## those surfaces in their own colours, and a bomb thrown or lying stays plain. A card tube is a kind of its own.

const GRENADES := "res://assets/models/grenades/%s.glb"
const POWER := "res://assets/models/powerSources/%s.glb"
## What each is made of: file, material, kind.
const MADE_OF := [
	[GRENADES, "smoke", "Shell", &"coated"],
	[GRENADES, "smoke", "Kind", &"coated"],
	[GRENADES, "smoke", "Cap", &"polymer"],
	[GRENADES, "smoke", "Lever", &"steel"],
	[GRENADES, "smoke", "Wire", &"steel"],
	[GRENADES, "flash", "Olive", &"card"],
	[GRENADES, "flash", "Kind", &"card"],
	[GRENADES, "flash", "Print", &"card"],
	[GRENADES, "flash", "Seal", &"card"],
	[POWER, "gasBottle", "Can", &"coated"],
	[POWER, "gasBottle", "Label", &"coated"],
	[POWER, "lipoBattery", "Case", &"coated"],
	[POWER, "lipoBattery", "Lead", &"polymer"],
	[POWER, "lipoBattery", "Plug", &"polymer"],
	[POWER, "standardBattery", "Wrap", &"coated"],
	[POWER, "standardBattery", "Print", &"card"],
	[POWER, "standardBattery", "Caution", &"card"],
	[POWER, "spring", "Label", &"coated"],
]
## The dark holes and sockets, and the bombs' bright wire (a mirror on a wire so thin sparkles), no file names: they
## stay as the file has them.
const LEFT_PLAIN := [
	[GRENADES, "flash", "Hole"], [GRENADES, "flash", "Steel"], [GRENADES, "smoke", "Steel"], [POWER, "lipoBattery", "Socket"], [POWER, "lipoBattery", "Slot"],
	[POWER, "standardBattery", "Socket"],
]
## The kinds before MQ2B, whose order the model files hold.
const KINDS_BEFORE: Array[StringName] = [
	&"polymer", &"steel", &"aluminium", &"wood", &"rubber", &"bare", &"coated", &"polished",
]
const BOMBS: Array[int] = [Grenade.Kind.SMOKE, Grenade.Kind.FLASH]
const LABEL := Color("6bc47c")

var tuning: SimTuning = SimTuning.new()


func before_each() -> void:
	ReplicaPaint.clear()


func after_each() -> void:
	ReplicaPaint.clear()


func _mesh(path: String) -> Mesh:
	return PropDressConfig.load_mesh(path)


func _surface(mesh: Mesh, material: String) -> int:
	for i in mesh.get_surface_count():
		var own := mesh.surface_get_material(i)
		if own != null and own.resource_name == material:
			return i
	return -1


func _view() -> GrenadeView:
	var v := GrenadeView.new()
	add_child_autofree(v)
	v.setup(2, tuning.grenades, false)
	v.setup_arms(ViewModelConfig.new(), FigureMix.HUMAN)
	return v


func test_card_is_a_new_kind_after_the_others() -> void:
	assert_eq(ReplicaSurfaces.KINDS.slice(0, KINDS_BEFORE.size()), KINDS_BEFORE, "the order the files hold is kept")
	assert_eq(ReplicaSurfaces.index(&"card"), KINDS_BEFORE.size())
	var look: Dictionary = ReplicaSurfaces.LOOKS[&"card"]
	assert_eq(look["metallic"], 0.0, "no metal in it")
	assert_gt(float(look["roughness"]), 0.85, "dead matte")
	assert_eq(look["gain"], 1.0, "in its own colour")
	assert_lt(float(look["specular"]), float(ReplicaSurfaces.LOOKS[&"polymer"]["specular"]), "duller than a moulding")


func test_each_file_is_made_of_what_the_real_one_is() -> void:
	for row: Array in MADE_OF:
		var mesh := _mesh((row[0] as String) % row[1])
		assert_not_null(mesh, row[1])
		if mesh == null:
			continue
		assert_gte(_surface(mesh, row[2]), 0, "%s has %s" % [row[1], row[2]])
		assert_eq(ReplicaSurfaces.named(mesh).get(StringName(row[2]), -1), ReplicaSurfaces.index(row[3]),
				"%s: %s is %s" % [row[1], row[2], row[3]])
	for row: Array in LEFT_PLAIN:
		var mesh := _mesh((row[0] as String) % row[1])
		assert_gte(_surface(mesh, row[2]), 0, "%s has %s" % [row[1], row[2]])
		assert_false(ReplicaSurfaces.named(mesh).has(StringName(row[2])), "%s: %s names no kind" % [row[1], row[2]])


func test_every_file_names_only_materials_it_has_and_kinds_the_game_knows() -> void:
	for path: String in [GRENADES % "smoke", GRENADES % "flash", POWER % "gasBottle", POWER % "lipoBattery",
			POWER % "standardBattery", POWER % "spring"]:
		var mesh := _mesh(path)
		var named := ReplicaSurfaces.named(mesh)
		assert_gt(named.size(), 0, "%s names its kinds" % path)
		var extras: Dictionary = mesh.get_meta(ReplicaSurfaces.EXTRAS_META)
		assert_eq(extras.keys(), [ReplicaSurfaces.NAMED_KEY], "%s: no other custom property" % path)
		assert_eq((extras[ReplicaSurfaces.NAMED_KEY] as Dictionary).size(), named.size(), "%s: every kind is known" % path)
		for material_name: StringName in named:
			assert_gte(_surface(mesh, material_name), 0, "%s: %s is one of its materials" % [path, material_name])


func test_the_bomb_in_your_hand_is_drawn_on_its_surfaces_in_its_own_colours() -> void:
	var v := _view()
	var depth := ViewModelConfig.new().depth_scale
	for kind: int in BOMBS:
		var named := ReplicaSurfaces.named(v.mesh_of(kind))
		assert_gt(named.size(), 0, "kind %d: the mesh the view made keeps its table" % kind)
		var surfaced := 0
		for part: Array in [[v.held_mesh_of(kind), v._held_paint[kind]], [v.pin_mesh_of(kind), v._pin_paint[kind]]]:
			var mesh := part[0] as Mesh
			var paint := part[1] as Array
			assert_eq(paint.size(), mesh.get_surface_count())
			for i in mesh.get_surface_count():
				var own := mesh.surface_get_material(i) as StandardMaterial3D
				var worn := paint[i] as Material
				var material_name := StringName(own.resource_name)
				if not named.has(material_name):
					assert_true(worn is BaseMaterial3D, "kind %d: %s stays as the file has it" % [kind, material_name])
					continue
				surfaced += 1
				assert_true(ReplicaPaint.is_surface(worn), "kind %d: %s on its surface" % [kind, material_name])
				var shader := worn as ShaderMaterial
				assert_eq(int(shader.get_shader_parameter(&"default_kind")), named[material_name])
				assert_eq(shader.get_shader_parameter(&"albedo"), own.albedo_color, "in its own colour")
				assert_eq(shader.get_shader_parameter(&"z_clip_scale"), depth, "its depth pressed as the arms' is")
				assert_eq(ReplicaPaint.plain_of(worn), own)
		assert_gt(surfaced, 3, "kind %d" % kind)
		# The band and stripe are still the bomb's own colour.
		var at := _surface(v.mesh_of(kind), GrenadeView.KIND_MATERIAL)
		assert_gte(at, 0, "kind %d: the painted material keeps its name" % kind)
		assert_eq((v.mesh_of(kind).surface_get_material(at) as StandardMaterial3D).albedo_color,
				GrenadeView.BODY_COLOURS[kind])


func test_a_bomb_thrown_or_lying_stays_plain() -> void:
	var v := _view()
	for kind: int in BOMBS:
		for mesh: Mesh in [v.mesh_of(kind), v.thrown_mesh_of(kind)]:
			for i in mesh.get_surface_count():
				assert_true(mesh.surface_get_material(i) is StandardMaterial3D, "kind %d surface %d" % [kind, i])
	# The pressed copies are the view's own: the shared surfaces keep the depth they had.
	for m: Material in ReplicaPaint.surface_materials():
		assert_eq((m as ShaderMaterial).get_shader_parameter(&"z_clip_scale"), null, m.resource_name)


func test_the_view_hands_its_surfaced_materials_to_the_prewarm_once_each() -> void:
	var v := _view()
	var shared := v.materials()
	var surfaced := 0
	for m: Material in shared:
		assert_eq(shared.count(m), 1)
		if ReplicaPaint.is_surface(m):
			surfaced += 1
	assert_gt(surfaced, 6, "the bombs' surfaces are warmed with the rest")


func test_a_menu_picture_draws_a_power_source_on_its_surfaces() -> void:
	var pictures := ReplicaPictures.new()
	add_child_autofree(pictures)
	assert_not_null(pictures.power_texture(&"gasBottle", LABEL))
	assert_not_null(pictures.power_texture(&"lipoBattery", LABEL))
	var seen := 0
	for shot: ReplicaPictures.Shot in pictures._power_shots.values():
		for node in shot.model.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			var named := ReplicaSurfaces.named(mi.mesh)
			for i in mi.mesh.get_surface_count():
				var own := mi.mesh.surface_get_material(i) as StandardMaterial3D
				var worn := mi.get_surface_override_material(i)
				var material_name := StringName(own.resource_name)
				if not named.has(material_name):
					assert_false(ReplicaPaint.is_surface(worn), "%s stays plain" % material_name)
					continue
				seen += 1
				assert_true(ReplicaPaint.is_surface(worn), "%s on its surface" % material_name)
				assert_eq(int((worn as ShaderMaterial).get_shader_parameter(&"default_kind")), named[material_name])
				var want := LABEL if material_name == &"Label" else own.albedo_color
				assert_eq((worn as ShaderMaterial).get_shader_parameter(&"albedo"), want,
						"%s: the label in the power source's colour, the rest in their own" % material_name)
	assert_gt(seen, 8)


func test_a_bomb_picture_is_drawn_on_its_surfaces_with_its_colour() -> void:
	var pictures := ReplicaPictures.new()
	add_child_autofree(pictures)
	for kind: int in BOMBS:
		assert_not_null(pictures.grenade_texture(kind))
		var shot := pictures._grenade_shots[kind] as ReplicaPictures.Shot
		var mi := shot.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var at := _surface(mi.mesh, GrenadeView.KIND_MATERIAL)
		var worn := mi.get_surface_override_material(at) as ShaderMaterial
		assert_true(ReplicaPaint.is_surface(worn), "kind %d" % kind)
		assert_eq(worn.get_shader_parameter(&"albedo"), GrenadeView.BODY_COLOURS[kind])


func test_own_surface_leaves_what_it_cannot_stand_in_for() -> void:
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	assert_eq(ReplicaPaint.own_surface(glass, ReplicaSurfaces.index(&"card")), glass, "glass")
	assert_null(ReplicaPaint.own_surface(null, 0))
	var plain := StandardMaterial3D.new()
	plain.albedo_color = Color(0.2, 0.3, 0.1)
	var card := ReplicaPaint.own_surface(plain, ReplicaSurfaces.index(&"card")) as ShaderMaterial
	assert_true(ReplicaPaint.is_surface(card))
	assert_ne(ReplicaPaint.own_surface(plain, ReplicaSurfaces.index(&"card")), card, "the caller's own each time")
	assert_false(ReplicaPaint.surface_materials().has(card), "never kept in the shared store")
	assert_eq(card.get_shader_parameter(&"albedo"), plain.albedo_color)
