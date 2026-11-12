class_name ArmsFade
extends RefCounted
## Your arms' materials while a pistol's sight comes up (HA1; arms_fade.gdshader): each arms material's copy that can
## fade out below the sight line, drawn otherwise as the StandardMaterial3D it is copied from. ArmsView wears them only
## while the sight is raised at all, so at the hip the arms draw as they always have.

const SHADER := preload("res://game/play/arms_fade.gdshader")
const HINT := &"hint"
const HINT_FROM := &"hint_from"
const HINT_TO := &"hint_to"


## A fading copy of `base` (its colour, maps, finish and depth press), whole until `fade` says otherwise; what lies
## below the sight line fades between `hint_span`'s two depths under it (m: x whole to, y gone by).
static func of(base: BaseMaterial3D, hint_span: Vector2) -> ShaderMaterial:
	var out := ShaderMaterial.new()
	out.shader = SHADER
	out.resource_name = base.resource_name
	out.set_shader_parameter(&"albedo", base.albedo_color)
	out.set_shader_parameter(&"albedo_map", base.albedo_texture)
	out.set_shader_parameter(&"roughness", base.roughness)
	out.set_shader_parameter(&"roughness_map", base.roughness_texture)
	out.set_shader_parameter(&"metallic", base.metallic)
	out.set_shader_parameter(&"metallic_map", base.metallic_texture)
	out.set_shader_parameter(&"specular", base.metallic_specular)
	out.set_shader_parameter(&"normal_map", base.normal_texture if base.normal_enabled else null)
	out.set_shader_parameter(&"normal_scale", base.normal_scale)
	out.set_shader_parameter(&"uv_scale", base.uv1_scale)
	out.set_shader_parameter(&"uv_offset", base.uv1_offset)
	out.set_shader_parameter(&"z_clip_scale", base.z_clip_scale if base.use_z_clip_scale else 1.0)
	out.set_shader_parameter(HINT_FROM, hint_span.x)
	out.set_shader_parameter(HINT_TO, hint_span.y)
	fade(out, 0.0)
	return out


## Fades `material` (one `of` made): `hint` (0..1) of what lies below the sight line.
static func fade(material: ShaderMaterial, hint: float) -> void:
	material.set_shader_parameter(HINT, hint)
