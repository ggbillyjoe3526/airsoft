extends GutTest
## UL3 (owner's 0.1 Beta 2 playtest, 2026-11-20: "subway map is too dark ... it improves the closer i get"): under an
## underground roof Global illumination Scene (Ultra) gathers no bounce light (SDFGI), whose rays found no sky there
## and left the escalator shafts and ceilings near black, and the area probes keep no ambient of their own, so the
## field's fill lights the shade as on High; above ground Ultra keeps both (game/play/field_lighting.gd,
## game/save/graphics_apply.gd).

var table: GraphicsTable = GraphicsTable.shared()
var subway: MapData = null


func before_all() -> void:
	subway = MapData.load_map("subway", MapStyle.new(), 6)


func _lit(underground: bool, probes: bool = false) -> FieldLighting:
	var lighting := FieldLighting.build(LightingConfig.new())
	add_child_autofree(lighting)
	if probes:
		lighting.add_probes(subway)
	lighting.set_underground(underground)
	return lighting


func _interior_ambient(lighting: FieldLighting) -> Array[ReflectionProbe.AmbientMode]:
	var modes: Array[ReflectionProbe.AmbientMode] = []
	for node in lighting.find_children("*", "ReflectionProbe", true, false):
		var probe := node as ReflectionProbe
		if probe.interior:
			modes.append(probe.ambient_mode)
	return modes


func test_ultra_underground_gathers_no_bounce_light_and_its_probes_keep_no_ambient() -> void:
	var ultra := table.preset(&"ultra")
	assert_eq(ultra.global_illumination, GraphicsQuality.GlobalIllumination.SCENE, "Ultra is the Scene preset")
	var under := _lit(true, true)
	GraphicsApply.apply_field(ultra, under, null, GraphicsApply.Server.new())
	assert_false(under.environment.sdfgi_enabled, "no SDFGI underground")
	assert_true(under.environment.ssil_enabled, "the screen's bounce light stays")
	var modes := _interior_ambient(under)
	assert_gt(modes.size(), 0, "Subway's areas have interior probes")
	for mode in modes:
		assert_eq(mode, ReflectionProbe.AMBIENT_DISABLED, "the field's fill, not the probe's darker picture")
	assert_gt(under.environment.ambient_light_energy, 0.0, "the fill is there")
	assert_false(GraphicsApply.scene_bounce(ultra, under))


func test_ultra_above_ground_keeps_its_bounce_light_and_the_probes_ambient() -> void:
	var ultra := table.preset(&"ultra")
	var open := _lit(false, true)
	GraphicsApply.apply_field(ultra, open, null, GraphicsApply.Server.new())
	assert_true(open.environment.sdfgi_enabled, "SDFGI above ground")
	for mode in _interior_ambient(open):
		assert_eq(mode, ReflectionProbe.AMBIENT_ENVIRONMENT, "BP9's interiors under the bounce light")
	assert_true(GraphicsApply.scene_bounce(ultra, open))
	assert_true(GraphicsApply.scene_bounce(ultra), "no field: the preset's")


func test_going_underground_after_the_preset_turns_the_bounce_off_and_back() -> void:
	var ultra := table.preset(&"ultra")
	var lighting := _lit(false, true)
	GraphicsApply.apply_field(ultra, lighting, null, GraphicsApply.Server.new())
	assert_true(lighting.environment.sdfgi_enabled)
	lighting.set_underground(true)
	assert_false(lighting.environment.sdfgi_enabled, "set as the field is built, in either order")
	for mode in _interior_ambient(lighting):
		assert_eq(mode, ReflectionProbe.AMBIENT_DISABLED)
	lighting.set_underground(false)
	assert_true(lighting.environment.sdfgi_enabled, "put back")


func test_no_refresh_of_a_bounce_light_that_isnt_there() -> void:
	var under := _lit(true)
	GraphicsApply.apply_field(table.preset(&"ultra"), under, null, GraphicsApply.Server.new())
	under.refresh_scene_light()
	assert_false(under.refreshing_scene_light(), "nothing to gather afresh underground")
	assert_false(under.environment.sdfgi_enabled)
