extends GutTest
## UG3 QA: eye adaptation's edges: old saves, Custom rows, the Compatibility renderer, a freed field, the scope's glass.

var table: GraphicsTable = null
var play: PlayTuning = PlayTuning.load_default()


func before_each() -> void:
	table = GraphicsTable.shared()


func test_a_custom_save_without_the_row_keeps_the_base_preset_s_choice() -> void:
	var high := GraphicsQuality.resolve(GraphicsQuality.CUSTOM, &"high", {"glow": "off"}, table)
	assert_true(high.eye_adaptation, "an older save (no row) takes the base's column")
	var medium := GraphicsQuality.resolve(GraphicsQuality.CUSTOM, &"medium", {}, table)
	assert_false(medium.eye_adaptation)


func test_a_custom_override_round_trips_and_a_bad_value_is_dropped() -> void:
	var q := GraphicsQuality.resolve(GraphicsQuality.CUSTOM, &"low", {"eye_adaptation": "on"}, table)
	assert_true(q.eye_adaptation)
	var saved := GraphicsQuality.overrides(q, &"low", table)
	assert_eq(saved.get("eye_adaptation"), "on")
	for bad: Variant in ["maybe", 7, null, true]:
		var r := GraphicsQuality.resolve(GraphicsQuality.CUSTOM, &"high", {"eye_adaptation": bad}, table)
		assert_true(r.eye_adaptation, "a value the table doesn't offer is dropped: %s" % str(bad))


func test_compatibility_draws_the_row_off_and_mobile_keeps_it() -> void:
	var ultra := table.preset(&"ultra")
	var compat := GraphicsApply.drawable(ultra, GraphicsPick.COMPATIBILITY, table)
	assert_false(compat.eye_adaptation)
	assert_false(table.can_draw(GraphicsQuality.EYE_ADAPTATION, 1, GraphicsPick.COMPATIBILITY))
	assert_true(GraphicsApply.drawable(ultra, "forward_plus", table).eye_adaptation)
	assert_true(GraphicsApply.drawable(ultra, "mobile", table).eye_adaptation)


func test_switching_the_renderer_clears_the_eyes_and_back_restores_them() -> void:
	var lighting := FieldLighting.build(play.lighting, play.look)
	add_child_autofree(lighting)
	var ultra := table.preset(&"ultra")
	var rs := GraphicsApply.Server.new()
	GraphicsApply.apply_field(GraphicsApply.drawable(ultra, GraphicsPick.COMPATIBILITY, table), lighting, null, rs)
	assert_false(lighting.eye_adaptation())
	GraphicsApply.apply_field(GraphicsApply.drawable(ultra, "forward_plus", table), lighting, null, rs)
	assert_true(lighting.eye_adaptation())


func test_a_freed_field_leaves_no_orphans() -> void:
	var before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	for i in 5:
		var lighting := FieldLighting.build(play.lighting, play.look)
		add_child(lighting)
		lighting.set_eye_adaptation(true)
		lighting.set_eye_adaptation(false)
		lighting.set_eye_adaptation(true)
		remove_child(lighting)
		lighting.free()
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), before)


func test_the_eyes_are_the_one_resource_the_world_holds_when_off_and_on_again() -> void:
	var lighting := FieldLighting.build(play.lighting, play.look)
	add_child_autofree(lighting)
	lighting.set_eye_adaptation(true)
	var first := (lighting.get_node("Environment") as WorldEnvironment).camera_attributes
	lighting.set_eye_adaptation(false)
	lighting.set_eye_adaptation(true)
	assert_same((lighting.get_node("Environment") as WorldEnvironment).camera_attributes, first)


func test_a_map_without_an_override_uses_the_day_preset_s_eyes() -> void:
	var m := MapData.load_map("woodland", play.map_style, 6)
	var cfg := LightingConfig.for_map(play.lighting, play.night_lighting, m, play.lighting.id)
	assert_eq(cfg.eye_lift, play.lighting.eye_lift)
	var eyes := FieldLighting.eye_attributes(cfg, play.look)
	assert_gt(eyes.auto_exposure_max_sensitivity, 0.0)
	assert_true(eyes.auto_exposure_min_sensitivity <= eyes.auto_exposure_max_sensitivity)


func test_zero_or_huge_eye_settings_stay_finite_and_ordered() -> void:
	for lift: float in [0.0, 1.0, 1e6]:
		for drop: float in [0.0, 1.0, 50.0]:
			var cfg := LightingConfig.new()
			cfg.eye_lift = lift
			cfg.eye_drop = drop
			var e := FieldLighting.eye_attributes(cfg, LookConfig.new())
			assert_true(is_finite(e.auto_exposure_min_sensitivity) and is_finite(e.auto_exposure_max_sensitivity))
			assert_true(e.auto_exposure_min_sensitivity <= e.auto_exposure_max_sensitivity)


func test_the_row_has_a_label_and_a_note_in_the_text() -> void:
	assert_ne(tr("GRAPHICS_EYE_ADAPTATION"), "GRAPHICS_EYE_ADAPTATION")
	assert_ne(tr("GRAPHICS_EYE_ADAPTATION_NOTE"), "GRAPHICS_EYE_ADAPTATION_NOTE")
