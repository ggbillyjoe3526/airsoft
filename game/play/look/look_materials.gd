class_name LookMaterials
## The shared light's ready-made materials (docs/ART.md › Light): a model painted in vertex colours on
## look_vertex.gdshader, or a see-through one (water, mud) on look_clear.gdshader. The shaders are loaded once; each
## call is a new material (call at build time, never per frame).

const VERTEX_SHADER := preload("res://game/play/look/look_vertex.gdshader")
const CLEAR_SHADER := preload("res://game/play/look/look_clear.gdshader")
const FOLIAGE_SHADER := preload("res://game/play/look/look_foliage.gdshader")
const SURFACE_SHADER := preload("res://game/play/look/look_surface.gdshader")


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


## A material printing `sheet` (sRGB) at a model's UVs over its vertex colours in the shared light (SM5: Subway's
## signs, posters and clock faces), `roughness` over it, worn as `vertex_colour`'s `wear`.
static func printed(sheet: Texture2D, roughness: float, wear: float = 0.0) -> ShaderMaterial:
	var m := vertex_colour(roughness, 0.0, Color.WHITE, false, wear)
	m.set_shader_parameter(&"use_sheet", true)
	m.set_shader_parameter(&"sheet", sheet)
	return m


## A material drawing a tree's, spruce's, fern's or bush's vertex colours (WQ1) times its detail maps in the shared
## light: its leaves from `sheet` (the leaf sheet, cut out), its bark from `bark` and its normal map `relief`, a
## second bark `bark_b` (with `relief_b`) blended in where the model says (look_foliage.gdshader); null maps draw
## plain. `roughness` over all of it, worn as `vertex_colour`'s `wear`; with `by_custom` each instance's custom data
## paints it as a PropDress model (DM1: look_vertex.gdshader's paint_by_custom).
static func foliage(sheet: Texture2D, bark: Texture2D, relief: Texture2D, bark_b: Texture2D, relief_b: Texture2D,
		roughness: float, wear: float = 0.0, by_custom: bool = true) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FOLIAGE_SHADER
	m.set_shader_parameter(&"sheet", sheet)
	m.set_shader_parameter(&"bark", bark)
	m.set_shader_parameter(&"bark_relief", relief)
	m.set_shader_parameter(&"bark_b", bark_b)
	m.set_shader_parameter(&"bark_b_relief", relief_b)
	m.set_shader_parameter(&"use_bark_b", bark_b != null)
	m.set_shader_parameter(&"roughness", roughness)
	m.set_shader_parameter(&"wear", wear)
	m.set_shader_parameter(&"paint_by_custom", by_custom)
	return m


## A material drawing a model's vertex colours with its surfaces' detail and relief (WQ1, look_surface.gdshader:
## Woodland's structures and props; `surfaces` and `relief` texture arrays, a layer each), `roughness` over it, worn as
## `vertex_colour`'s `wear`, each instance painted by its custom data (DM1). Null arrays draw it plain.
static func surfaced(surfaces: Texture2DArray, relief: Texture2DArray, roughness: float, wear: float = 0.0) \
		-> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SURFACE_SHADER
	m.set_shader_parameter(&"roughness", roughness)
	m.set_shader_parameter(&"wear", wear)
	m.set_shader_parameter(&"paint_by_custom", true)
	m.set_shader_parameter(&"surfaces", surfaces)
	m.set_shader_parameter(&"surfaces_relief", relief)
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


## True where a worn model's floor goes on its material, not its instance (look_wear.gdshaderinc): the Compatibility
## renderer, whose instance uniforms run out at 256 drawn instances (BC1). Read once a build, handed to `draw_worn`.
static func floors_by_material() -> bool:
	return RenderingServer.get_current_rendering_method() == GraphicsPick.COMPATIBILITY


## Draws `view` in `material` (look_vertex or door_leaf) with its foot's grime climbing from `foot` m up its model's y
## (SL2): the floor set on `view` where instance uniforms are used; with `by_material` (floors_by_material), on a copy
## of `material` that carries it, one copy a material and foot, kept in `copies` (the caller's, freed with it) for its
## other views. A foot of 0 is the shader's default and draws in `material` itself.
static func draw_worn(view: GeometryInstance3D, material: ShaderMaterial, foot: float, by_material: bool,
		copies: Dictionary) -> void:
	if not by_material:
		view.material_override = material
		view.set_instance_shader_parameter(&"wear_floor", foot)
		return
	if is_zero_approx(foot):
		view.material_override = material
		return
	var mine: Dictionary = copies.get(material, {})
	if not mine.has(foot):
		var copy := material.duplicate() as ShaderMaterial
		copy.set_shader_parameter(&"wear_floor", foot)
		mine[foot] = copy
		copies[material] = mine
	view.material_override = mine[foot]
