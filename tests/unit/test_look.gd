extends GutTest
## The game's look (AD1, docs/ART.md): LookConfig's palette off the team hues and its light's values the same as
## project.godot's global shader uniforms, the shared light's materials, the Graphics rows that scale it (bounce light,
## reflections, glow, volumetric fog, contact-hardening shadows) switched in place by preset with Low drawing none of
## them, the map's reflection probes, Depot's clean surfaces and its roof wound to face out. Headless: properties and
## counts, never pixels.

var table: GraphicsTable = null
var look: LookConfig = null


func before_each() -> void:
	table = GraphicsTable.shared()
	look = PlayTuning.load_default().look


func test_no_palette_colour_reads_as_a_team() -> void:
	var teams := AccessibilityTable.read_file().colours
	teams.append_array(PlayTuning.load_default().teams.colours)
	var team_like: Array[String] = []
	for n: StringName in look.palette:
		if FieldChecks.reads_as_team(look.palette[n], teams):
			team_like.append(String(n))
	# the light's own tints too: the shade and the rim light every surface, so they never tint toward a team
	for n: String in ["shade", "rim"]:
		if FieldChecks.reads_as_team(look.get(n) as Color, teams):
			team_like.append(n)
	assert_eq(team_like, [] as Array[String], "no palette colour or light tint near a team's hue")


func test_the_six_site_colours_are_in_the_palette() -> void:
	assert_eq(look.site_colours.size(), 6, "crimson, violet, yellow, teal, green and cream")
	for n in look.site_colours:
		assert_true(look.palette.has(n), "%s is a palette colour" % n)


func test_the_lights_values_are_the_projects_global_uniforms() -> void:
	var values := look.globals()
	for k: StringName in values:
		var setting := "shader_globals/%s" % k
		assert_true(ProjectSettings.has_setting(setting), "project.godot declares %s" % k)
		var declared: Variant = (ProjectSettings.get_setting(setting) as Dictionary).get("value")
		if values[k] is Color:
			var want := values[k] as Color
			var got := declared as Color
			for c in 4:
				assert_almost_eq(got[c], want[c], 0.00001, "%s channel %d" % [k, c])
		else:
			assert_almost_eq(declared as float, values[k] as float, 0.0001, String(k))


## SiteLook colours that aren't paint: a container's base (each unit takes container_paint), a frame's white tint, and
## the marks drawn only with grit (none on a clean surface).
const NOT_PAINT: Array[StringName] = [&"container", &"frame", &"tuft", &"chip", &"rust_foot", &"dirt_foot"]
## The props' recipe parts recoloured into the look (tools/props/build_props.py), by palette name.
const PROP_PARTS := {
	"barrel": {"warm": &"crimson"}, "drum": {"warm": &"teal", "cool": &"ink"}, "sofa": {"carpet": &"violet"},
	"shelf": {"shelf-boxes": &"steel", "carton": &"crate", "box": &"cream"},
}


func test_depots_paint_is_the_palettes() -> void:
	var play := PlayTuning.load_default()
	var site := play.site_look
	var off: Array[String] = []
	for group: String in ["paints", "accents", "marks"]:
		var colours := site.get(group) as Dictionary
		for n: StringName in colours:
			if not NOT_PAINT.has(n):
				_in_palette("%s %s" % [group, n], colours[n] as Color, off)
	for i in site.container_paint.size():
		_in_palette("container paint %d" % i, site.container_paint[i], off)
	_in_palette("roof ceiling", play.roof.ceiling_colour, off)
	_in_palette("roof trusses", play.roof.truss_colour, off)
	assert_eq(off, [] as Array[String], "every colour Depot paints is a palette colour")


func test_the_props_recipes_are_the_palettes() -> void:
	var text := FileAccess.get_file_as_string("res://tools/props/build_props.py")
	assert_false(text.is_empty(), "reads the recipes")
	for model: String in PROP_PARTS:
		var start := text.find('\n    "%s": {' % model)
		assert_gt(start, -1, "a %s recipe" % model)
		var recipe := text.substr(start, text.find("\n    \"", start + 1) - start)
		for part: String in PROP_PARTS[model]:
			var re := RegEx.create_from_string('"%s": \\(([\\d.]+), ([\\d.]+), ([\\d.]+)\\)' % part)
			var m := re.search(recipe)
			assert_not_null(m, "%s's %s colour" % [model, part])
			if m == null:
				continue
			var got := Color(m.get_string(1).to_float(), m.get_string(2).to_float(), m.get_string(3).to_float())
			var want := look.colour(PROP_PARTS[model][part] as StringName)
			for c in 3:
				assert_almost_eq(got[c], want[c], 0.002, "%s's %s is %s" % [model, part, PROP_PARTS[model][part]])


func test_a_palette_name_it_lacks_warns_and_shows_magenta() -> void:
	assert_eq(look.colour(&"crimson"), look.palette[&"crimson"])
	assert_eq(look.colour(&"no such colour"), Color.MAGENTA)


func test_the_shared_materials_draw_in_the_shared_light() -> void:
	var m := LookMaterials.vertex_colour(0.4, 0.2)
	assert_eq(m.shader, LookMaterials.VERTEX_SHADER)
	assert_true(m.shader.code.contains("look_light.gdshaderinc"), "the vertex-colour shader includes the light")
	assert_true(SiteSurface.SHADER.code.contains("look_light.gdshaderinc"), "the site surface includes the light")
	assert_almost_eq(m.get_shader_parameter(&"roughness") as float, 0.4, 0.0001)
	assert_almost_eq(m.get_shader_parameter(&"metallic") as float, 0.2, 0.0001)


func test_the_presets_scale_the_effects_and_low_draws_none() -> void:
	var low := table.preset(&"low")
	assert_eq(low.global_illumination, GraphicsQuality.GlobalIllumination.OFF)
	assert_eq(low.reflections, GraphicsQuality.Reflections.OFF)
	assert_false(low.glow)
	assert_false(low.volumetric_fog)
	assert_false(low.sun_shadows, "Low has no sun shadows (the 60 FPS floor)")
	var medium := table.preset(&"medium")
	assert_eq(medium.global_illumination, GraphicsQuality.GlobalIllumination.OFF)
	assert_eq(medium.reflections, GraphicsQuality.Reflections.PROBES)
	assert_true(medium.glow)
	var high := table.preset(&"high")
	assert_eq(high.global_illumination, GraphicsQuality.GlobalIllumination.SCREEN)
	assert_eq(high.reflections, GraphicsQuality.Reflections.PROBES)
	assert_false(high.volumetric_fog)
	var ultra := table.preset(&"ultra")
	assert_eq(ultra.global_illumination, GraphicsQuality.GlobalIllumination.SCENE)
	assert_eq(ultra.reflections, GraphicsQuality.Reflections.SCREEN)
	assert_true(ultra.glow)
	assert_true(ultra.volumetric_fog)


func test_the_simpler_renderer_draws_no_bounce_light_haze_or_screen_reflections() -> void:
	var drawn := GraphicsApply.drawable(table.preset(&"ultra"), "gl_compatibility", table)
	assert_eq(drawn.global_illumination, GraphicsQuality.GlobalIllumination.OFF)
	assert_false(drawn.volumetric_fog)
	assert_eq(drawn.reflections, GraphicsQuality.Reflections.PROBES, "probes it draws")
	assert_true(drawn.glow, "glow it draws")


func test_each_preset_switches_the_effects_in_place() -> void:
	var lighting := FieldLighting.build(LightingConfig.new(), look)
	lighting.add_probes(_depot())
	add_child_autofree(lighting)
	var env := lighting.environment
	var rs := GraphicsApply.Server.new()
	GraphicsApply.apply_field(table.preset(&"ultra"), lighting, null, rs)
	assert_true(env.ssil_enabled and env.sdfgi_enabled and env.ssr_enabled and env.glow_enabled)
	assert_true(env.volumetric_fog_enabled)
	assert_true(lighting.get_node("ReflectionProbes").visible, "probes shown")
	assert_almost_eq(lighting.sun.light_angular_distance, look.sun_size, 0.0001, "contact-hardening on Softest")
	assert_eq(rs.gi_quality, GraphicsQuality.GlobalIllumination.SCENE)
	assert_eq(rs.fog_grid, Vector2i(look.fog_volume_size, look.fog_volume_depth))
	GraphicsApply.apply_field(table.preset(&"high"), lighting, null, rs)
	assert_true(env.ssil_enabled)
	assert_false(env.sdfgi_enabled or env.ssr_enabled or env.volumetric_fog_enabled)
	assert_true(env.glow_enabled)
	assert_almost_eq(lighting.sun.light_angular_distance, 0.0, 0.0001, "a point sun below Softest")
	GraphicsApply.apply_field(table.preset(&"low"), lighting, null, rs)
	assert_false(env.ssil_enabled or env.sdfgi_enabled or env.ssr_enabled or env.glow_enabled)
	assert_false(env.volumetric_fog_enabled)
	assert_false(lighting.get_node("ReflectionProbes").visible, "probes hidden")


func test_the_grade_is_drawn_on_every_preset() -> void:
	var lighting := FieldLighting.build(LightingConfig.new(), look)
	add_child_autofree(lighting)
	GraphicsApply.apply_field(table.preset(&"low"), lighting, null, GraphicsApply.Server.new())
	var env := lighting.environment
	assert_true(env.adjustment_enabled)
	assert_almost_eq(env.adjustment_saturation, look.saturation, 0.0001)
	assert_almost_eq(env.tonemap_agx_contrast, look.agx_contrast, 0.0001)


func test_depots_probes_cover_the_field_and_its_large_areas_as_interiors() -> void:
	var depot := _depot()
	var probes := AreaProbes.build(depot, look)
	add_child_autofree(probes)
	var large := AreaProbes.boxes(depot, look).size()
	assert_gt(large, 3, "Depot has large named areas")
	assert_eq(probes.get_child_count(), mini(look.probe_most, large + 1), "the field and its large areas")
	var whole := probes.get_child(0) as ReflectionProbe
	var foot := depot.footprint()
	assert_gte(whole.size.x, foot.size.x, "the first covers the field")
	for p: ReflectionProbe in probes.get_children():
		assert_true(p.interior, "under Depot's roof: %s" % p.name)
		assert_eq(p.update_mode, ReflectionProbe.UPDATE_ONCE, "captured once: %s" % p.name)
		assert_almost_eq(p.size.y, depot.roof_height, 0.001, "reaches the roof: %s" % p.name)


func test_depot_is_drawn_clean_without_its_photos() -> void:
	var play := PlayTuning.load_default()
	assert_eq(play.site_look.grit, 0.0, "the look's clean surfaces")
	var m := SiteSurface.material(play.site_look, _depot())
	assert_null(m.get_shader_parameter(&"slab_col"), "no photo grain, so no photo loaded")
	assert_almost_eq(m.get_shader_parameter(&"grit") as float, 0.0, 0.0001)
	assert_gt(m.get_shader_parameter(&"gradient") as float, 0.0, "the soft vertical gradient")


func test_the_roofs_faces_are_wound_to_face_out() -> void:
	var roof := RoofView.build(_depot(), PlayTuning.load_default().roof)
	add_child_autofree(roof)
	var mesh := (roof.get_node("Ceiling") as MeshInstance3D).mesh
	var arrays := mesh.surface_get_arrays(0)
	var v := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var n := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
	var reference := _winding_sign(BoxMesh.new())
	var wrong := 0
	for i in range(0, v.size(), 3):
		if signf((v[i + 1] - v[i]).cross(v[i + 2] - v[i]).dot(n[i])) != reference:
			wrong += 1
	assert_eq(wrong, 0, "every triangle wound as Godot's own box is")


## The sign of a triangle's winding against its normal in a mesh Godot builds itself (its front faces).
func _winding_sign(box: BoxMesh) -> float:
	var arrays := box.get_mesh_arrays()
	var v := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var n := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
	var idx := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	var a := v[idx[0]]
	return signf((v[idx[1]] - a).cross(v[idx[2]] - a).dot(n[idx[0]]))


## Adds `what` to `off` unless `colour` is one of the palette's.
func _in_palette(what: String, colour: Color, off: Array[String]) -> void:
	for n: StringName in look.palette:
		if (look.palette[n] as Color).is_equal_approx(colour):
			return
	off.append("%s #%s" % [what, colour.to_html(false)])


func _depot() -> MapData:
	var play := PlayTuning.load_default()
	return MapData.load_map("depot", play.map_style, SimTuning.load_default().rounds.team_size)
