class_name LookMaterials
## The shared light's ready-made materials (docs/ART.md › Light): a model painted in vertex colours on
## look_vertex.gdshader. The shader is loaded once; each call is a new material (call at build time, never per frame).

const VERTEX_SHADER := preload("res://game/play/look/look_vertex.gdshader")


## A material drawing a model's vertex colours in the shared light, `roughness` and `metallic` over all of it.
static func vertex_colour(roughness: float, metallic: float, tint: Color = Color.WHITE) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = VERTEX_SHADER
	m.set_shader_parameter(&"roughness", roughness)
	m.set_shader_parameter(&"metallic", metallic)
	m.set_shader_parameter(&"tint", tint)
	return m
