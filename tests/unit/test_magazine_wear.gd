extends GutTest
## Magazine wear (RW2, 2026-11-10): every magazine a worn replica takes is lightly used like the replica. The standard
## magazines are part of their replica's model (RW1); the alternative ones, in the parts files, carry their file's own
## mask (tools/blender/parts/magazines.py, replicaParts/<id>_wear.png) on copies of the painted materials, so the
## file's other parts, and every part's figures' copy, stay plain.

## The parts files with worn magazines, and their magazine parts.
const WORN_PARTS := {"aeg": ["magazine_hiCap", "magazine_lowCap"], "pistol": ["magazine_extended"]}
## Every replica worn in the hands (test_replica_wear.gd WORN): its standard magazine is worn with it.
const WORN_REPLICAS := ["aeg", "pistol", "smg"]
const PARTS := "res://assets/models/replicaParts/%s.glb"
const PARTS_MASK := "res://assets/models/replicaParts/%s_wear.png"
const MODEL := "res://assets/models/replicas/%s.glb"
const MODEL_MASK := "res://assets/models/replicas/%s_wear.png"
## As test_replica_wear.gd's: light use, not a repaint.
const MOST_RUBBED := 0.12
const MOST_SCRATCHED := 0.02

var _nodes: Array[Node] = []


func before_each() -> void:
	ReplicaPaint.clear()


func after_each() -> void:
	for n in _nodes:
		n.free()
	_nodes.clear()
	ReplicaPaint.clear()


func _load(path: String) -> Node3D:
	var n := (load(path) as PackedScene).instantiate() as Node3D
	_nodes.append(n)
	return n


## The painted surfaces (one of the five parts) of `node` and the meshes under it, as [mesh node, surface].
func _painted(node: Node) -> Array:
	var out := []
	var meshes: Array[Node] = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.push_front(node)
	for n: Node in meshes:
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var own := mi.mesh.surface_get_material(i)
			if own != null and ReplicaSchemes.PARTS.has(StringName(own.resource_name)):
				out.append([mi, i])
	return out


func test_alternative_magazines_carry_their_files_mask_on_every_painted_surface() -> void:
	for id: String in WORN_PARTS:
		var mask := load(PARTS_MASK % id) as Texture2D
		assert_not_null(mask, "%s's parts file has its magazines' mask" % id)
		var holder := _load(PARTS % id)
		for part: String in WORN_PARTS[id]:
			var node := holder.get_node_or_null(part)
			assert_not_null(node, "%s has %s" % [id, part])
			var surfaces := _painted(node)
			assert_gt(surfaces.size(), 0, "%s is painted" % part)
			for s: Array in surfaces:
				var mi := s[0] as MeshInstance3D
				assert_eq(ReplicaPaint.wear_mask(mi.mesh, s[1]), mask, "%s surface %d is worn" % [part, s[1]])
				var uv: PackedVector2Array = mi.mesh.surface_get_arrays(s[1])[Mesh.ARRAY_TEX_UV]
				var box := Rect2(uv[0], Vector2.ZERO)
				for p in uv:
					box = box.expand(p)
				assert_true(box.size.x > 0.0 or box.size.y > 0.0, "%s surface %d is unwrapped on UV" % [part, s[1]])


func test_every_other_part_and_every_figures_copy_stays_plain() -> void:
	for id: String in ["aeg", "pistol", "smg", "cyber", "sniper"]:
		var worn: Array = WORN_PARTS.get(id, [])
		var holder := _load(PARTS % id)
		for s: Array in _painted(holder):
			var mi := s[0] as MeshInstance3D
			if worn.has(String(mi.name)) and mi.get_parent() == holder:
				continue
			assert_null(ReplicaPaint.wear_mask(mi.mesh, s[1]), "%s %s stays plain" % [id, mi.name])


func test_standard_magazines_are_worn_with_their_replica() -> void:
	for id: String in WORN_REPLICAS:
		var model := _load(MODEL % id)
		var mags := model.find_children(ReplicaParts.MAGAZINE_NODE, "MeshInstance3D", true, false)
		assert_gt(mags.size(), 0, "%s has its standard magazine" % id)
		for mag: Node in mags:
			for s: Array in _painted(mag):
				var mi := s[0] as MeshInstance3D
				assert_eq(ReplicaPaint.wear_mask(mi.mesh, s[1]), load(MODEL_MASK % id),
						"%s %s surface %d is worn" % [id, mi.name, s[1]])


func test_a_fitted_magazine_wears_the_worn_paint_in_the_hands_and_plain_when_asked() -> void:
	for key: StringName in [&"hiCap", &"lowCap"]:
		var model := _load(MODEL % "aeg")
		var fit := ReplicaParts.fit(model, &"aeg", {ReplicaParts.MAGAZINE_SLOT: key})
		assert_eq(fit.nodes.size(), 1, "the %s is fitted" % key)
		ReplicaPaint.apply(model, &"cobalt", false)
		var surfaces := _painted(fit.nodes[0])
		assert_gt(surfaces.size(), 0, "the %s is painted" % key)
		for s: Array in surfaces:
			var mi := s[0] as MeshInstance3D
			var worn := mi.get_surface_override_material(s[1])
			assert_true(ReplicaPaint.is_worn(worn), "%s surface %d wears the worn paint" % [mi.name, s[1]])
			assert_eq((worn as ShaderMaterial).get_shader_parameter(&"wear_mask"), load(PARTS_MASK % "aeg"),
					"with its file's mask")
		ReplicaPaint.apply(model, &"cobalt", false, false)
		for s: Array in surfaces:
			var mi := s[0] as MeshInstance3D
			assert_false(ReplicaPaint.is_worn(mi.get_surface_override_material(s[1])), "a plain apply is plain")


func test_the_magazines_wear_is_light() -> void:
	for id: String in WORN_PARTS:
		var img := Image.load_from_file(ProjectSettings.globalize_path(PARTS_MASK % id))
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
		assert_gt(rubbed + scratched, 0, "%s: it is worn at all" % id)


func test_a_figures_copy_of_a_magazine_has_no_mask_to_wear() -> void:
	for id: String in WORN_PARTS:
		for part: String in WORN_PARTS[id]:
			var key := StringName(part.trim_prefix("magazine_"))
			var taken := ReplicaParts.take(StringName(id), {ReplicaParts.MAGAZINE_SLOT: key}, true)
			var copy: Node3D = taken.get(ReplicaParts.MAGAZINE_SLOT)
			assert_not_null(copy, "%s has its figures' copy" % part)
			if copy == null:
				continue
			_nodes.append(copy)
			ReplicaPaint.apply(copy, &"cobalt", false)
			var surfaces := _painted(copy)
			assert_gt(surfaces.size(), 0, "%s's copy is painted" % part)
			for s: Array in surfaces:
				var mi := s[0] as MeshInstance3D
				assert_false(ReplicaPaint.is_worn(mi.get_surface_override_material(s[1])), "%s draws plain" % mi.name)


func test_no_parts_file_leaks_a_build_suffix_into_a_material_name() -> void:
	for id: String in ["aeg", "pistol", "cyber", "sniper", "smg"]:
		var holder := _load(PARTS % id)
		var meshes: Array[Node] = holder.find_children("*", "MeshInstance3D", true, false)
		for n: Node in meshes:
			var mi := n as MeshInstance3D
			for i in mi.mesh.get_surface_count():
				var mat := mi.mesh.surface_get_material(i)
				if mat != null:
					assert_false(mat.resource_name.contains(".worn") or mat.resource_name.begins_with("wear_renaming"),
							"%s %s surface %d keeps the painted material's name" % [id, mi.name, i])
