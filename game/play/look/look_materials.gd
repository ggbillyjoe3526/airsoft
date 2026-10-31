class_name LookMaterials
## The shared light's ready-made materials (docs/ART.md › Light): a model painted in vertex colours on
## look_vertex.gdshader, or a see-through one (water, mud) on look_clear.gdshader. The shaders are loaded once; each
## call is a new material (call at build time, never per frame).

const VERTEX_SHADER := preload("res://game/play/look/look_vertex.gdshader")
const CLEAR_SHADER := preload("res://game/play/look/look_clear.gdshader")


## A material drawing a model's vertex colours in the shared light, `roughness` and `metallic` over all of it. With
## `srgb`, the colours are sRGB (a mesh built in code with SurfaceTool or a MultiMesh's instance colours), not linear
## (a glTF's).
static func vertex_colour(roughness: float, metallic: float, tint: Color = Color.WHITE,
		srgb: bool = false) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = VERTEX_SHADER
	m.set_shader_parameter(&"roughness", roughness)
	m.set_shader_parameter(&"metallic", metallic)
	m.set_shader_parameter(&"tint", tint)
	m.set_shader_parameter(&"srgb_colours", srgb)
	return m


## A see-through material in the shared light: sRGB vertex colours, their alpha its opacity, `roughness` over all of
## it (Woodland's puddles and mud), drawn before the rest of the see-through things.
static func clear_colour(roughness: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = CLEAR_SHADER
	m.set_shader_parameter(&"roughness", roughness)
	m.render_priority = Material.RENDER_PRIORITY_MIN
	return m
