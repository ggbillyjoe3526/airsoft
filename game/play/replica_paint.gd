class_name ReplicaPaint
extends RefCounted
## Paints a replica's model in a ReplicaSchemes paint (presentation only, nothing in the simulation reads it): the five
## materials the replica models name Body, Furniture, Detail, Accent and Metal are overridden on each mesh surface that
## carries one, the rest (rubber, the BB, the orange tip) keep the model's own. The materials are built once per paint
## and shared by every replica wearing it; a paint with no colours (the Cyber Pistol's) leaves the model's own, except
## under Realistic colours, which turns its glowing lines plain grey (ReplicaSchemes.OWN_REALISTIC). The glb files are
## never edited. In the hands and on the menus' pictures a painted part is drawn on its surface (MQ1:
## replica_surface.gdshader, what ReplicaSurfaces says its faces are made of: steel and aluminium reflect under the
## paint, polymer is matte and grained, wood shows its figure), and a model that carries a wear mask (RW1: the hands'
## meshes of the AEG Rifle, the GBB Pistol and the Compact SMG, its `<model>_wear.png` as their materials' ao_texture;
## tools/blender/replicas/wear.py) wears it lightly used too (faint scratches, rubbed edges, grime in the recesses).
## The caller asks for it plain for the figures' copies, which are seen from far off and merged by their plain paints
## (HeldMerge): those keep the flat paints.

## How a painted part is drawn: matte polymer with a soft sheen, the metal parts a little shiny (Sunlit Concrete, SL4).
const ROUGHNESS := 0.64
const METAL_PART := &"Metal"
const METAL_ROUGHNESS := 0.48
const METALLIC := 0.4
## The look's paint saturation (LookConfig.paint_saturation, kept in project.godot's shader globals): a paint is drawn
## at this share of its colour, as the maps' paint is (SL4).
const PAINT_SATURATION_SETTING := "shader_globals/look_paint_saturation"
## A linear colour's brightness (Rec. 709), as look_paint() weighs it.
const LUMA := Vector3(0.2126, 0.7152, 0.0722)
## The most paints kept; the cache is cleared past it (there are twelve paints, each plain or realistic).
const MAX_SETS := 32
## The paint on its surface (MQ1; worn where the model carries a mask, RW1), and the most such materials kept (a
## paint's part on one model's mask); cleared past it.
const SURFACE_SHADER := preload("res://game/play/replica_surface.gdshader")
const MAX_SURFACED := 160
## The meta a surfaced paint keeps its plain one in (plain_of).
const PLAIN_META := &"plain"

## The materials per paint (PARTS' order), keyed "<paint>" or "<paint>/realistic".
static var _sets: Dictionary[String, Array] = {}
## The own colours' realistic materials, by the model's material name; built once.
static var _own_realistic: Dictionary[StringName, StandardMaterial3D] = {}
## The surfaced materials (MQ1, RW1), keyed by the plain one, the mask (0: none) and the default kind:
## "<plain's id>/<mask's id>/<kind>".
static var _surfaced: Dictionary[String, ShaderMaterial] = {}


## The paint a bot on `team` carries on `replica`: its team's for the replica's class, or its own colours.
static func bot_paint(team: int, replica: ReplicaConfig) -> StringName:
	if ReplicaSchemes.OWN_COLOURS.has(replica.id):
		return ReplicaSchemes.OWN
	return ReplicaSchemes.bot_paint(team, replica.site_class)


## The paint `replica` wears when the kit names none for its slot.
static func default_paint(replica: ReplicaConfig) -> StringName:
	if ReplicaSchemes.OWN_COLOURS.has(replica.id):
		return ReplicaSchemes.OWN
	return ReplicaSchemes.default_paint(replica.site_class)


## The five shared materials of `paint` (PARTS' order); empty for a paint with no colours.
static func materials(paint: StringName, realistic: bool) -> Array[StandardMaterial3D]:
	var key := String(paint) + ("/realistic" if realistic else "")
	if not _sets.has(key):
		var colours := ReplicaSchemes.colours(paint, realistic)
		if colours.is_empty():
			return []
		if _sets.size() >= MAX_SETS:
			_sets.clear()
			_surfaced.clear()
		var built: Array = []
		for i in colours.size():
			var m := StandardMaterial3D.new()
			m.resource_name = "%s_%s" % [key, ReplicaSchemes.PARTS[i]]
			m.albedo_color = drawn(colours[i])
			var is_metal := ReplicaSchemes.PARTS[i] == METAL_PART
			m.roughness = METAL_ROUGHNESS if is_metal else ROUGHNESS
			m.metallic = METALLIC if is_metal else 0.0
			built.append(m)
		_sets[key] = built
	var out: Array[StandardMaterial3D] = []
	out.assign(_sets[key])
	return out


## Puts `paint` on every surface of `model` and below it whose material is one of the five parts: on its surface (MQ1),
## worn where the model carries a wear mask (RW1), unless `surfaced` is false (a figure's copy: the plain paint). A
## fitted part names a kind for each of its materials (MQ2, ReplicaSurfaces.named), and those of its own that it names
## (rubber pads, a brass crown) go on their surfaces too, in their own colours.
static func apply(model: Node, paint: StringName, realistic: bool, surfaced: bool = true) -> void:
	var painted := materials(paint, realistic)
	var own_colours := paint == ReplicaSchemes.OWN
	if painted.is_empty() and not own_colours:
		return
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	if model is MeshInstance3D:
		meshes.append(model)
	for node: Node in meshes:
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		# A part's own table of kinds (MQ2), material name to kind; empty for a replica, whose faces say theirs.
		var named: Dictionary[StringName, int] = {}
		if surfaced:
			named = ReplicaSurfaces.named(mesh_node.mesh)
		for i in mesh_node.mesh.get_surface_count():
			var own := mesh_node.mesh.surface_get_material(i)
			if own == null:
				continue
			var material_name := StringName(own.resource_name)
			var kind: int = named.get(material_name, ReplicaSurfaces.part_index(material_name))
			if own_colours:
				# Its own colours, or their realistic grey (and back again, a menu picture being repainted), on their
				# surfaces in the hands (MQ1).
				var grey: StandardMaterial3D = null
				if realistic and ReplicaSchemes.OWN_REALISTIC.has(material_name):
					grey = _realistic_own(material_name)
				var shown: StandardMaterial3D = grey if grey != null else own as StandardMaterial3D
				# A part that names its kinds (the Cyber's torch) is surfaced only where it names one: its reflector
				# and its lit parts stay as the file has them.
				var stands_in := named.is_empty() or named.has(material_name)
				if surfaced and shown != null and stands_in and plain_colour(shown):
					mesh_node.set_surface_override_material(i, _surface_of(shown, null, kind))
				elif ReplicaSchemes.OWN_REALISTIC.has(material_name) \
						or is_surface(mesh_node.get_surface_override_material(i)):
					# plain again: the realistic grey, or the model's own (a surface an earlier apply left is taken off)
					mesh_node.set_surface_override_material(i, grey)
				continue
			var part := ReplicaSchemes.PARTS.find(material_name)
			if part >= 0 and part < painted.size():
				var mask := wear_mask(mesh_node.mesh, i) if surfaced else null
				mesh_node.set_surface_override_material(i,
						_surface_of(painted[part], mask, kind) if surfaced else painted[part])
			elif named.has(material_name) and own is StandardMaterial3D and plain_colour(own as StandardMaterial3D):
				# A part's own material that names its kind (MQ2: rubber pads, a brass crown): its own colour on that
				# surface.
				mesh_node.set_surface_override_material(i,
						_surface_of(own as StandardMaterial3D, wear_mask(mesh_node.mesh, i), kind))
			elif is_surface(mesh_node.get_surface_override_material(i)):
				# plain again: a surface an earlier apply left on one of the part's own materials is taken off
				mesh_node.set_surface_override_material(i, null)


## Whether `material` is one plain colour (opaque, no texture): the kind the surface shader can stand in for.
static func plain_colour(material: BaseMaterial3D) -> bool:
	return material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and material.albedo_texture == null \
			and material.normal_texture == null


## The wear mask surface `i` of `mesh` carries (RW1): its own material's ao_texture (the glTF occlusion texture, read
## on the surface's UV); null for a clean one.
static func wear_mask(mesh: Mesh, i: int) -> Texture2D:
	if mesh == null:
		return null
	var own := mesh.surface_get_material(i) as BaseMaterial3D
	return own.ao_texture if own != null else null


## `plain` (one of materials()'s, or a model's own material) on its surface (MQ1), worn by `mask` where there is one
## (RW1), its faces with no kind of their own drawn as `default_kind`: built once and shared by every surface alike.
static func _surface_of(plain: StandardMaterial3D, mask: Texture2D, default_kind: int) -> ShaderMaterial:
	var key := "%d/%d/%d" % [plain.get_instance_id(), mask.get_instance_id() if mask != null else 0, default_kind]
	if not _surfaced.has(key):
		if _surfaced.size() >= MAX_SURFACED:
			_surfaced.clear()
		_surfaced[key] = _built(plain, mask, default_kind)
	return _surfaced[key]


## A new surface in `plain`'s colour and glow (MQ1), worn by `mask` where there is one (RW1), its faces with no kind of
## their own drawn as `default_kind`.
static func _built(plain: StandardMaterial3D, mask: Texture2D, default_kind: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.resource_name = plain.resource_name + ("/worn" if mask != null else "/surface")
	m.shader = SURFACE_SHADER
	ReplicaSurfaces.dress(m)
	m.set_shader_parameter(&"albedo", plain.albedo_color)
	m.set_shader_parameter(&"default_kind", default_kind)
	m.set_shader_parameter(&"emission", plain.emission if plain.emission_enabled else Color.BLACK)
	m.set_shader_parameter(&"emission_energy", plain.emission_energy_multiplier if plain.emission_enabled else 0.0)
	m.set_shader_parameter(&"wear", 1.0 if mask != null else 0.0)
	if mask != null:
		m.set_shader_parameter(&"wear_mask", mask)
	m.set_meta(PLAIN_META, plain)
	return m


## `own` (an accessory's own plain-coloured material: a bomb in the hand, a power source's picture, MQ2B) on a new
## surface of kind `kind` in its own colour, the caller's to keep and to change (never one of surface_materials(): a
## picture's or a view's own paint would otherwise stay in the shared store after it); `own` itself where the surface
## can't stand in for it (glass, a texture).
static func own_surface(own: Material, kind: int) -> Material:
	var plain := own as StandardMaterial3D
	if plain == null or not plain_colour(plain):
		return own
	return _built(plain, null, kind)


## The plain paint `material` was surfaced from (MQ1), or `material` itself where it is a plain one.
static func plain_of(material: Material) -> Material:
	var surfaced := is_surface(material) and material.has_meta(PLAIN_META)
	return material.get_meta(PLAIN_META) as Material if surfaced else material


## Whether `material` is a paint on its surface (MQ1), or a copy of one.
static func is_surface(material: Material) -> bool:
	return material is ShaderMaterial and (material as ShaderMaterial).shader == SURFACE_SHADER


## Whether `material` is a worn paint (RW1: a surfaced one whose model carries a wear mask), or a copy of one.
static func is_worn(material: Material) -> bool:
	if not is_surface(material):
		return false
	var wear: Variant = (material as ShaderMaterial).get_shader_parameter(&"wear")
	return wear is float and wear > 0.0


## The surfaced materials built so far (MQ1, RW1), for ShaderPrewarm.
static func surface_materials() -> Array[Material]:
	var out: Array[Material] = []
	out.assign(_surfaced.values())
	return out


## The plain material, with no glow, that the own colours' `material_name` turns into under Realistic colours.
static func _realistic_own(material_name: StringName) -> StandardMaterial3D:
	if not _own_realistic.has(material_name):
		var m := StandardMaterial3D.new()
		m.resource_name = "own/realistic_%s" % material_name
		m.albedo_color = drawn(Color.hex((ReplicaSchemes.OWN_REALISTIC[material_name] << 8) | 0xff))
		m.roughness = ROUGHNESS
		_own_realistic[material_name] = m
	return _own_realistic[material_name]


## `colour` (sRGB) as a replica draws it: pulled toward its own grey to the look's paint saturation, in linear light
## like look_paint() (look_light.gdshaderinc), so a bold scheme sits in the muted world and keeps its two tones.
static func drawn(colour: Color) -> Color:
	var linear := colour.srgb_to_linear()
	var grey := Vector3(linear.r, linear.g, linear.b).dot(LUMA)
	var paint := Color(grey, grey, grey, linear.a).lerp(linear, paint_saturation())
	return paint.linear_to_srgb()


## The look's paint saturation (1 when the setting is missing: the paint as it is).
static func paint_saturation() -> float:
	var entry: Variant = ProjectSettings.get_setting(PAINT_SATURATION_SETTING, null)
	if entry is Dictionary:
		return float((entry as Dictionary).get("value", 1.0))
	if entry is float:
		return entry
	return 1.0


## Lets go of the shared materials (a match ends); replicas still wearing them keep theirs until freed.
static func clear() -> void:
	_sets.clear()
	_own_realistic.clear()
	_surfaced.clear()
