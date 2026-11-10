class_name LookMaterials
## The shared light's ready-made materials (docs/ART.md › Light): a model painted in vertex colours on
## look_vertex.gdshader, or a see-through one (water, mud) on look_clear.gdshader. The shaders are loaded once; each
## call is a new material (call at build time, never per frame).

const VERTEX_SHADER := preload("res://game/play/look/look_vertex.gdshader")
const CLEAR_SHADER := preload("res://game/play/look/look_clear.gdshader")


## A material drawing a model's vertex colours in the shared light, `roughness` and `metallic` over all of it. With
## `srgb`, the colours are sRGB (a mesh built in code with SurfaceTool or a MultiMesh's instance colours), not linear
## (a glTF's). `wear` is how worn it is drawn (SL2: grime, streaks, stains, dust; 0 clean), times LookConfig.wear.
## Without `wobble`, Dev › Retro filter leaves its corners true (RF1: the level's blocks and ground).
static func vertex_colour(roughness: float, metallic: float, tint: Color = Color.WHITE,
		srgb: bool = false, wear: float = 0.0, wobble: bool = true) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = VERTEX_SHADER
	m.set_shader_parameter(&"roughness", roughness)
	m.set_shader_parameter(&"metallic", metallic)
	m.set_shader_parameter(&"tint", tint)
	m.set_shader_parameter(&"srgb_colours", srgb)
	m.set_shader_parameter(&"wear", wear)
	m.set_shader_parameter(&"retro_wobble", wobble)
	return m


## A material painting a whole mesh without vertex colours `colour` (sRGB) in the shared light, `roughness` and
## `metallic` over it: a door's leaves, a flag pole (BP7). A mesh without colours reads as white, so the tint is its
## paint.
static func paint(colour: Color, roughness: float, metallic: float = 0.0) -> ShaderMaterial:
	return vertex_colour(roughness, metallic, colour)


## Sets each of `paints` (made by `paint`) to its colour in `colours` (sRGB) lit by `light`, a linear multiplier of a
## paint (BakedLightNear's, BP7), so it draws at that share of its paint; white draws it as painted.
static func light_paints(paints: Array[ShaderMaterial], colours: PackedColorArray, light: Color) -> void:
	for i in paints.size():
		paints[i].set_shader_parameter(&"tint", lit_paint(colours[i], light))


## Paint `colour` (sRGB) lit by `light` (a linear multiplier), in sRGB again.
static func lit_paint(colour: Color, light: Color) -> Color:
	var lin := colour.srgb_to_linear()
	return Color(lin.r * light.r, lin.g * light.g, lin.b * light.b, lin.a).linear_to_srgb()


## A see-through material in the shared light: sRGB vertex colours, their alpha its opacity, `roughness` over all of
## it (Woodland's puddles and mud), drawn before the rest of the see-through things.
static func clear_colour(roughness: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = CLEAR_SHADER
	m.set_shader_parameter(&"roughness", roughness)
	m.render_priority = Material.RENDER_PRIORITY_MIN
	return m
