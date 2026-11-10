class_name ReplicaPaint
extends RefCounted
## Paints a replica's model in a ReplicaSchemes paint (presentation only, nothing in the simulation reads it): the
## five materials the replica models name Body, Furniture, Detail, Accent and Metal are overridden on each mesh
## surface that carries one, the rest (rubber, the BB, the orange tip) keep the model's own. The materials are built
## once per paint and shared by every replica wearing it; a paint with no colours (the Cyber Pistol's) leaves the
## model's own, except under Realistic colours, which turns its glowing lines plain grey (ReplicaSchemes.OWN_REALISTIC).
## The glb files are never edited.

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

## The materials per paint (PARTS' order), keyed "<paint>" or "<paint>/realistic".
static var _sets: Dictionary[String, Array] = {}
## The own colours' realistic materials, by the model's material name; built once.
static var _own_realistic: Dictionary[StringName, StandardMaterial3D] = {}


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


## Puts `paint` on every surface of `model` and below it whose material is one of the five parts.
static func apply(model: Node, paint: StringName, realistic: bool) -> void:
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
		for i in mesh_node.mesh.get_surface_count():
			var own := mesh_node.mesh.surface_get_material(i)
			if own == null:
				continue
			var material_name := StringName(own.resource_name)
			if own_colours:
				# Its own colours, or their realistic grey (and back again, a menu picture being repainted).
				if ReplicaSchemes.OWN_REALISTIC.has(material_name):
					mesh_node.set_surface_override_material(i, _realistic_own(material_name) if realistic else null)
				continue
			var part := ReplicaSchemes.PARTS.find(material_name)
			if part >= 0 and part < painted.size():
				mesh_node.set_surface_override_material(i, painted[part])


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
