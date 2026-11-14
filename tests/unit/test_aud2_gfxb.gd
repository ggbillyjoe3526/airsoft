extends GutTest
## The Dev 3 audit's second pass on what is drawn (AUD2, graphics B): the site's, doors' and models' colours handed to
## the Compatibility renderer in the space it takes them (sRGB), so it draws them as Forward+ does; the contact shadow
## faded by its own shader, which both renderers draw; and Depot's stencils and the flags' cloth and ring in the baked
## light near them.

var play: PlayTuning = PlayTuning.load_default()
var _depot: MapLevel = null


func after_all() -> void:
	if _depot != null:
		_depot.free()


func _baked_depot() -> MapLevel:
	if _depot == null:
		var m := MapData.load_map("depot", play.map_style, 5)
		_depot = MapLevel.new()
		add_child(_depot)
		var sun := LightingConfig.for_map(play.lighting, null, m, LightingConfig.DAY)
		_depot.build(m, play.map_style, SimTuning.load_default().body, play.baked_light, sun, false, play.site_look)
	_depot.set_baked_light(true)
	return _depot


## look_colour.gdshaderinc's pair, as the shader computes them.
func _to_linear(c: float) -> float:
	return c * (c * (c * 0.305306011 + 0.682171111) + 0.012522878)


func _to_srgb(c: float) -> float:
	return maxf(1.055 * pow(maxf(c, 0.0), 0.416666667) - 0.055, 0.0)


func test_a_linear_colour_handed_to_compatibility_comes_back_as_it_went() -> void:
	# Compatibility's scene shader takes ALBEDO as sRGB and puts it through its srgb_to_linear (the same polynomial).
	for i in range(1, 21):
		var lin := float(i) / 20.0
		assert_almost_eq(_to_linear(_to_srgb(lin)), lin, 0.006, "linear %.2f" % lin)
	# The site's paints are linear: read as sRGB they drew darker and more saturated (the row's 216,185,136).
	assert_lt(_to_linear(0.5), 0.25, "a linear 0.5 taken as sRGB draws at a fifth")


func test_the_site_doors_and_models_hand_their_linear_colours_over_through_look_albedo() -> void:
	var inc := FileAccess.get_file_as_string("res://game/play/look/look_colour.gdshaderinc")
	assert_string_contains(inc, "#define LOOK_ALBEDO(c) (OUTPUT_IS_SRGB ? look_linear_to_srgb(c) : (c))")
	assert_string_contains(inc, "#define LOOK_LINEAR(c) (OUTPUT_IS_SRGB ? look_srgb_to_linear(c) : (c))")
	var light := FileAccess.get_file_as_string("res://game/play/look/look_light.gdshaderinc")
	assert_string_contains(light, '#include "res://game/play/look/look_colour.gdshaderinc"')
	for path: String in ["res://game/play/site/site_surface.gdshader", "res://game/play/door_leaf.gdshader",
			"res://game/play/look/look_vertex.gdshader"]:
		var code := FileAccess.get_file_as_string(path)
		var albedo := 0
		for line: String in code.split("\n"):
			if line.strip_edges().begins_with("ALBEDO = "):
				albedo += 1
				assert_string_contains(line, "LOOK_ALBEDO(", "%s: %s" % [path.get_file(), line.strip_edges()])
		assert_eq(albedo, 1, "%s: one ALBEDO" % path.get_file())
	# The source_color colours (sRGB on Compatibility) are taken linear before the linear light multiplies them.
	assert_string_contains(FileAccess.get_file_as_string("res://game/play/door_leaf.gdshader"), "LOOK_LINEAR(tint.rgb)")
	var site := FileAccess.get_file_as_string("res://game/play/site/site_surface.gdshader")
	assert_string_contains(site, "LOOK_LINEAR(texture(slab_col, uv).rgb)")
	assert_string_contains(site, "LOOK_LINEAR(texture(ply_col, uv).rgb)")


func test_the_contact_shadow_fades_by_its_shader_not_the_instance_s_transparency() -> void:
	var cfg := EffectsConfig.new()
	var disc := FigureView.contact_mesh(cfg)
	var mat := disc.material as ShaderMaterial
	assert_not_null(mat, "a shader of its own")
	assert_eq(mat.shader, FigureView.CONTACT_SHADER)
	assert_not_null(mat.get_shader_parameter(&"disc"), "its soft disc")
	var c := Character.new(3, 0, Vector3(1.0, 0.5, 2.0), 0.0, ReplicaStats.default_loadout())
	c.grounded = true
	var f := FigureView.new()
	add_child_autofree(f)
	f.setup(c, Color.RED, HitConfig.new(), null)
	f.add_contact_shadow(disc, cfg)
	f.set_contact_shadow(true)
	f.update(c, 1.0)
	var node := f.contact_shadow()
	assert_eq(f.contact_fade(), 1.0, "whole on the floor")
	c.grounded = false
	c.prev_position = c.position + Vector3.UP * cfg.contact_fade_height * 0.25
	c.position = c.prev_position
	f.update(c, 1.0)
	assert_almost_eq(f.contact_fade(), 0.75, 1e-3, "fading with the height")
	assert_almost_eq(float(node.get_instance_shader_parameter(&"fade")), 0.75, 1e-3, "drawn so, on either renderer")
	assert_eq(node.transparency, 0.0, "not by the transparency Compatibility ignores")

