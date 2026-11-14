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
			"res://game/play/look/look_vertex.gdshader", "res://game/play/flag_cloth.gdshader"]:
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


func test_depot_s_stencils_take_the_light_of_the_wall_behind_them() -> void:
	var level := _baked_depot()
	var lights := level.baked_lights()
	var dress := SiteDress.build(level.map, play.site_look, level.site_material(), play.skyline)
	add_child_autofree(dress)
	var paints: Array[Color] = []
	for l in dress.stencils():
		paints.append(l.modulate)
	assert_gt(paints.size(), 3, "Depot's zone stencils")
	dress.relight(lights)
	var lit := 0
	for i in paints.size():
		var l := dress.stencils()[i]
		var light := l.modulate.srgb_to_linear().g / paints[i].srgb_to_linear().g
		assert_true(light > 0.6 and light < 1.3, "%s in its wall's light: %.3f" % [l.name, light])
		if not is_equal_approx(light, 1.0):
			lit += 1
	assert_eq(lit, paints.size(), "every stencil takes a baked light, a wall drawn as props (Offices) its props' too")
	var offices := SiteDress.stencil_light(lights, Vector3(16.5, 1.9, -25.834), Vector3.BACK, Vector3(16.5, 0.0, -25.834))
	assert_eq(offices, lights.at(Vector3(16.5, PropDress.LIGHT_LIFT, -25.834)), "the Offices' plywood wall: its foot's")
	var dim := BakedLightNear.new(PackedVector3Array([Vector3(0.0, 1.9, -0.2)]), PackedVector3Array([Vector3.BACK]),
			PackedColorArray([Color(0.4, 0.4, 0.4)]))
	assert_eq(SiteDress.stencil_light(dim, Vector3(0.0, 1.9, 0.0), Vector3.BACK, Vector3.ZERO), Color(0.4, 0.4, 0.4),
			"the wall's own faces first")
	dress.relight(null)
	for i in paints.size():
		assert_eq(dress.stencils()[i].modulate, paints[i], "Baked light off: its own paint")


func test_a_flag_s_cloth_and_ring_take_the_light_at_its_foot() -> void:
	var dim := Color(0.4, 0.35, 0.3)
	var at := PackedVector3Array([Vector3.ZERO])
	var lights := BakedLightNear.new(at, PackedVector3Array([Vector3.UP]), PackedColorArray([dim]))
	var teams := TeamColours.resolve(TeamColours.Set.STANDARD, false, null, play.teams).figures
	var pole := FlagView.new()
	add_child_autofree(pole)
	pole.setup(play.flag, teams, Vector3.ZERO, 3.0)
	var ring := pole.materials()[1] as StandardMaterial3D
	var paint := ring.albedo_color
	pole.relight(lights)
	var cloth := pole.materials()[0] as ShaderMaterial
	assert_eq(cloth.get_shader_parameter(&"light"), Vector3(dim.r, dim.g, dim.b), "the cloth in the floor's light")
	assert_eq(ring.albedo_color, LookMaterials.lit_paint(paint, dim), "the ring too")
	assert_eq(pole.ring_colour(), paint, "its colour as the round has it unchanged")
	var flag := FlagState.new()
	flag.status = FlagState.Status.CONTESTED
	pole.refresh(flag, 0)
	assert_eq(ring.albedo_color, LookMaterials.lit_paint(Color(play.flag.ring_contested, play.flag.ring_alpha), dim),
			"a new colour in the same light")
	pole.relight(null)
	assert_eq(cloth.get_shader_parameter(&"light"), Vector3.ONE)
	assert_eq(ring.albedo_color, Color(play.flag.ring_contested, play.flag.ring_alpha), "off: its own paint")
	var overtime := OvertimeFlagView.new()
	add_child_autofree(overtime)
	overtime.setup(play.flag, teams, Vector3.ZERO, 3.0)
	var ot_ring := overtime.materials()[1] as StandardMaterial3D
	var ot_paint := ot_ring.albedo_color
	overtime.relight(lights)
	assert_eq((overtime.materials()[0] as ShaderMaterial).get_shader_parameter(&"light"), Vector3(dim.r, dim.g, dim.b))
	assert_eq(ot_ring.albedo_color, LookMaterials.lit_paint(ot_paint, dim), "the overtime flag's ring too")
