extends GutTest
## MQ2: what the fitted parts are made of (owner, 2026-11-12: "go over all the attachment and accessory models and
## improve their quality and make them look more realistic and detailed"). A part names a kind for each of its
## materials in its mesh's table (ReplicaSurfaces.named), the hands draw its paint on that surface and its own named
## materials (rubber, a brass crown) on theirs, and the figures' copies stay plain. The vertical grip is a little
## longer (owner, 2026-11-12).

const PARTS := "res://assets/models/replicaParts/%s.glb"
const FILES: Array[String] = ["aeg", "pistol", "cyber", "sniper", "smg"]
const FIGURE_SUFFIX := "_Figure"
## What the owner's parts are made of: file, part, material, kind.
const MADE_OF := [
	["aeg", "optic_redDot", "Detail", &"aluminium"],
	["aeg", "optic_scope2x", "Detail", &"aluminium"],
	["aeg", "optic_scopeVar", "Detail", &"aluminium"],
	["aeg", "muzzle_silencer", "Detail", &"aluminium"],
	["aeg", "light_weaponTorch", "Detail", &"aluminium"],
	["aeg", "laser_redLaser", "Detail", &"polymer"],
	["aeg", "grip_vertical", "Furniture", &"polymer"],
	["aeg", "grip_angled", "Furniture", &"polymer"],
	["aeg", "grip_vertical", "Metal", &"steel"],
	["aeg", "optic_redDot", "Rubber", &"rubber"],
	["aeg", "magazine_hiCap", "Detail", &"steel"],
	["aeg", "magazine_lowCap", "Detail", &"polymer"],
	["aeg", "barrel_long", "Brass", &"polished"],
	["aeg", "barrel_tightBore", "Steel", &"polished"],
	["pistol", "muzzle_silencer", "Detail", &"aluminium"],
	["pistol", "magazine_extended", "Metal", &"steel"],
	["cyber", "light_weaponTorch", "Detail", &"aluminium"],
	["sniper", "optic_scope2x", "Detail", &"aluminium"],
	["smg", "optic_redDot", "Detail", &"aluminium"],
]
## The vertical grip's height under the rail (m): 53 mm before the owner asked for it a little longer, about 64 now,
## and no longer than a hand's hold needs.
const GRIP_WAS := 0.053
const GRIP_LONGER_BY := 0.008
const GRIP_AT_MOST := 0.072

## A magazine part's BBs are true balls: each at least this many triangles (24 sides in 12 bands is 528; the old
## six-band ones were 160), and every corner on a 6 mm ball's skin (m).
const BB_TRIS_AT_LEAST := 500
const BB_RADIUS := 0.003
const BB_SKIN := 0.00002
## Corners closer than this (m) are one corner (a seam in the unwrap splits them in the file).
const BB_SNAP := 0.000002
## File, part, BBs showing.
const BBS := [["aeg", "magazine_hiCap", 3], ["aeg", "magazine_lowCap", 3], ["pistol", "magazine_extended", 2]]

var _nodes: Array[Node] = []


func before_each() -> void:
	ReplicaPaint.clear()


func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()
	ReplicaPaint.clear()


func _file(id: String) -> Node:
	var model := (load(PARTS % id) as PackedScene).instantiate()
	_nodes.append(model)
	return model


func _part(model: Node, part: String) -> MeshInstance3D:
	return model.find_child(part, true, false) as MeshInstance3D


func _surface(mi: MeshInstance3D, material: String) -> int:
	for i in mi.mesh.get_surface_count():
		var own := mi.mesh.surface_get_material(i)
		if own != null and own.resource_name == material:
			return i
	return -1


func test_every_hands_part_names_a_known_kind_for_each_paint_it_wears() -> void:
	for id in FILES:
		var model := _file(id)
		var seen := 0
		for node in model.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			var named := ReplicaSurfaces.named(mi.mesh)
			if String(mi.name).ends_with(FIGURE_SUFFIX) or String(mi.name).contains(FIGURE_SUFFIX + "_"):
				assert_true(named.is_empty(), "%s %s: a figure's copy names no kinds" % [id, mi.name])
				continue
			seen += 1
			for i in mi.mesh.get_surface_count():
				var material_name := StringName(mi.mesh.surface_get_material(i).resource_name)
				if ReplicaSchemes.PARTS.has(material_name):
					assert_true(named.has(material_name), "%s %s: %s names its kind" % [id, mi.name, material_name])
			for material_name in named:
				assert_between(named[material_name], 0, ReplicaSurfaces.KINDS.size() - 1,
						"%s %s: %s is a known kind" % [id, mi.name, material_name])
				assert_gte(_surface(mi, material_name), 0, "%s %s: names only materials it has" % [id, mi.name])
		assert_gt(seen, 0, "%s: the scan read its parts" % id)


func test_the_parts_are_made_of_what_the_real_ones_are() -> void:
	var files: Dictionary[String, Node] = {}
	for row: Array in MADE_OF:
		var id: String = row[0]
		if not files.has(id):
			files[id] = _file(id)
		var mi := _part(files[id], row[1])
		assert_not_null(mi, "%s has %s" % [id, row[1]])
		if mi == null:
			continue
		var named := ReplicaSurfaces.named(mi.mesh)
		assert_eq(named.get(StringName(row[2]), -1), ReplicaSurfaces.index(row[3]),
				"%s %s: %s is %s" % [id, row[1], row[2], row[3]])


func test_in_the_hands_a_part_wears_its_paint_on_its_kind_and_its_rubber_on_rubber() -> void:
	var dot := _part(_file("aeg"), "optic_redDot")
	ReplicaPaint.apply(dot, &"cobalt", false)
	var body := dot.get_surface_override_material(_surface(dot, "Detail")) as ShaderMaterial
	assert_true(ReplicaPaint.is_surface(body), "the housing is drawn on its surface")
	assert_eq(int(body.get_shader_parameter(&"default_kind")), ReplicaSurfaces.index(&"aluminium"))
	assert_eq(ReplicaPaint.plain_of(body), ReplicaPaint.materials(&"cobalt", false)[ReplicaSchemes.PARTS.find(&"Detail")],
			"in the paint's colour")
	var rubber_at := _surface(dot, "Rubber")
	var rubber := dot.get_surface_override_material(rubber_at) as ShaderMaterial
	assert_true(ReplicaPaint.is_surface(rubber), "its rubber is drawn on its surface too")
	assert_eq(int(rubber.get_shader_parameter(&"default_kind")), ReplicaSurfaces.index(&"rubber"))
	var own := dot.mesh.surface_get_material(rubber_at) as StandardMaterial3D
	assert_eq(ReplicaPaint.plain_of(rubber), own, "in its own colour, whatever the paint")
	assert_eq(rubber.get_shader_parameter(&"albedo"), own.albedo_color)
	assert_null(dot.get_surface_override_material(_surface(dot, "LensDot")), "the glass is left as the file has it")


func test_a_lit_or_mirrored_part_of_its_own_stays_as_the_file_has_it() -> void:
	var torch := _part(_file("aeg"), "light_weaponTorch")
	ReplicaPaint.apply(torch, &"tan", false)
	assert_null(torch.get_surface_override_material(_surface(torch, "TorchLens")), "the reflector")
	assert_null(torch.get_surface_override_material(_surface(torch, "Led")), "the lit LED")
	var laser := _part(_file("aeg"), "laser_redLaser")
	ReplicaPaint.apply(laser, &"tan", false)
	assert_null(laser.get_surface_override_material(_surface(laser, "LaserLens")), "the glowing lens")


func test_a_figures_copy_and_a_plain_apply_stay_flat() -> void:
	var model := _file("aeg")
	var dot := _part(model, "optic_redDot")
	ReplicaPaint.apply(dot, &"cobalt", false, false)
	assert_true(dot.get_surface_override_material(_surface(dot, "Detail")) is StandardMaterial3D, "the flat paint")
	assert_null(dot.get_surface_override_material(_surface(dot, "Rubber")), "its own rubber untouched")
	# Surfaced, then plain again: the own material's surface is taken off.
	ReplicaPaint.apply(dot, &"cobalt", false)
	assert_true(ReplicaPaint.is_surface(dot.get_surface_override_material(_surface(dot, "Rubber"))))
	ReplicaPaint.apply(dot, &"cobalt", false, false)
	assert_null(dot.get_surface_override_material(_surface(dot, "Rubber")), "plain again")
	var copy := _part(model, "optic_redDot" + FIGURE_SUFFIX)
	assert_not_null(copy)
	ReplicaPaint.apply(copy, &"cobalt", false)
	for i in copy.mesh.get_surface_count():
		var worn := copy.get_surface_override_material(i)
		if ReplicaPaint.is_surface(worn):
			var material_name := StringName(copy.mesh.surface_get_material(i).resource_name)
			assert_eq(int((worn as ShaderMaterial).get_shader_parameter(&"default_kind")),
					ReplicaSurfaces.part_index(material_name), "a copy names no kinds: the part's usual one")


func test_the_cybers_torch_in_its_own_colours_is_aluminium_with_its_reflector_kept() -> void:
	var torch := _part(_file("cyber"), "light_weaponTorch")
	ReplicaPaint.apply(torch, ReplicaSchemes.OWN, false)
	var body := torch.get_surface_override_material(_surface(torch, "Detail")) as ShaderMaterial
	assert_true(ReplicaPaint.is_surface(body))
	assert_eq(int(body.get_shader_parameter(&"default_kind")), ReplicaSurfaces.index(&"aluminium"))
	assert_null(torch.get_surface_override_material(_surface(torch, "TorchLens")), "the reflector stays a mirror")
	assert_null(torch.get_surface_override_material(_surface(torch, "Led")), "the LED stays lit")


func test_a_brass_crown_is_polished_metal_in_its_own_colour() -> void:
	var barrel := _part(_file("aeg"), "barrel_long")
	ReplicaPaint.apply(barrel, &"cobalt", false)
	var at := _surface(barrel, "Brass")
	var crown := barrel.get_surface_override_material(at) as ShaderMaterial
	assert_true(ReplicaPaint.is_surface(crown))
	assert_eq(int(crown.get_shader_parameter(&"default_kind")), ReplicaSurfaces.index(&"polished"))
	assert_eq(crown.get_shader_parameter(&"albedo"), (barrel.mesh.surface_get_material(at) as StandardMaterial3D).albedo_color)
	var look: Dictionary = ReplicaSurfaces.LOOKS[&"polished"]
	assert_gt(float(look["gain"]), 1.0, "its own colour lifted, as bare metal's is, so it reads bright under a dull sky")
	assert_gt(float(look["metallic"]), 0.9, "all metal")
	assert_eq(look["stretch"], 1.0, "not brushed")
	assert_eq(look["relief"], 0.0, "no grain: its highlight is one clean band")
	assert_eq(look["cloud"], 0.0, "and no clouding")


func test_a_table_that_is_missing_or_wrong_names_nothing() -> void:
	var mesh := ArrayMesh.new()
	assert_true(ReplicaSurfaces.named(null).is_empty())
	assert_true(ReplicaSurfaces.named(mesh).is_empty(), "no extras")
	mesh.set_meta(ReplicaSurfaces.EXTRAS_META, "not a table")
	assert_true(ReplicaSurfaces.named(mesh).is_empty(), "extras of another shape")
	mesh.set_meta(ReplicaSurfaces.EXTRAS_META, {ReplicaSurfaces.NAMED_KEY: 3})
	assert_true(ReplicaSurfaces.named(mesh).is_empty(), "a table of another shape")
	mesh.set_meta(ReplicaSurfaces.EXTRAS_META, {ReplicaSurfaces.NAMED_KEY: {"Detail": "steel", "Metal": "unobtainium"}})
	var named := ReplicaSurfaces.named(mesh)
	assert_eq(named.size(), 1, "a kind this build doesn't know is left out")
	assert_eq(named[&"Detail"], ReplicaSurfaces.index(&"steel"))


func test_the_vertical_grip_is_a_little_longer() -> void:
	for id: String in ["aeg", "sniper"]:
		var grip := _part(_file(id), "grip_vertical")
		var box := grip.mesh.get_aabb()
		# The part hangs under its mount: its origin on the rail's face, the body below it.
		assert_gt(-box.position.y, GRIP_WAS + GRIP_LONGER_BY, "%s: longer than the stubby one" % id)
		assert_lt(-box.position.y, GRIP_AT_MOST, "%s: only a little" % id)


func test_a_magazine_parts_bbs_are_round() -> void:
	for row: Array in BBS:
		var mi := _part(_file(row[0]), row[1])
		assert_not_null(mi, "%s has %s" % [row[0], row[1]])
		if mi == null:
			continue
		var at := _surface(mi, "BB")
		assert_gte(at, 0, "%s has its BBs" % row[1])
		var arrays := mi.mesh.surface_get_arrays(at)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		@warning_ignore("integer_division")
		assert_gte(index.size() / 3, BB_TRIS_AT_LEAST * int(row[2]), "%s: each BB is finely turned" % row[1])
		# Each ball is one piece of the surface: its corners joined by its triangles, its centre their mean.
		var place: Dictionary[Vector3i, int] = {}
		var root: Array[int] = []
		var unique: Array[Vector3] = []
		var of: Array[int] = []
		for p in points:
			var key := Vector3i((p / BB_SNAP).round())
			if not place.has(key):
				place[key] = unique.size()
				root.append(unique.size())
				unique.append(p)
			of.append(place[key])
		for t in range(0, index.size(), 3):
			for k in 2:
				var a := _root(root, of[index[t + k]])
				var b := _root(root, of[index[t + k + 1]])
				if a != b:
					root[a] = b
		var sums: Dictionary[int, Vector3] = {}
		var counts: Dictionary[int, int] = {}
		for i in unique.size():
			var r := _root(root, i)
			sums[r] = sums.get(r, Vector3.ZERO) + unique[i]
			counts[r] = counts.get(r, 0) + 1
		assert_eq(sums.size(), int(row[2]), "%s: its BBs are whole and apart" % row[1])
		var off := 0.0
		for i in unique.size():
			var r := _root(root, i)
			off = maxf(off, absf((sums[r] / float(counts[r])).distance_to(unique[i]) - BB_RADIUS))
		assert_lt(off, BB_SKIN, "%s: every corner of a BB is on a 6 mm ball" % row[1])


func _root(root: Array[int], i: int) -> int:
	while root[i] != i:
		root[i] = root[root[i]]
		i = root[i]
	return i
