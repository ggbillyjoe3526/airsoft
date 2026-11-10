extends GutTest
## UG3: Graphics › Eye adaptation (data/graphics.md): off on Low and Medium, on on High and Ultra; while on, the field's
## world meters what its camera sees and lifts a dark view towards the preset's middle, at most `eye_lift` times, the
## tuned exposure held in any brighter view; the night keeps its dark; a scope's glass never adapts on its own. Headless: properties, never pixels.

var table: GraphicsTable = null
var play: PlayTuning = PlayTuning.load_default()


func before_each() -> void:
	table = GraphicsTable.shared()


func _lighting(cfg: LightingConfig = null) -> FieldLighting:
	var lighting := FieldLighting.build(cfg if cfg != null else play.lighting, play.look)
	add_child_autofree(lighting)
	return lighting


func _world(lighting: FieldLighting) -> WorldEnvironment:
	return lighting.get_node("Environment") as WorldEnvironment


func test_the_presets_adapt_from_high_up() -> void:
	assert_false(table.preset(&"low").eye_adaptation)
	assert_false(table.preset(&"medium").eye_adaptation)
	assert_true(table.preset(&"high").eye_adaptation)
	assert_true(table.preset(&"ultra").eye_adaptation)
	assert_true(GraphicsQuality.ROWS.has(GraphicsQuality.EYE_ADAPTATION))


func test_the_eyes_lift_the_dark_and_hold_the_tuned_exposure_above_the_middle() -> void:
	var cfg := LightingConfig.new()
	cfg.eye_middle = 0.5
	cfg.eye_lift = 4.0
	cfg.eye_drop = 1.0
	var look := LookConfig.new()
	var eyes := FieldLighting.eye_attributes(cfg, look)
	assert_true(eyes.auto_exposure_enabled)
	assert_almost_eq(eyes.auto_exposure_scale, 0.5, 1e-5, "metered at the middle, the preset's exposure")
	assert_almost_eq(eyes.auto_exposure_min_sensitivity, 0.5 / 4.0 * FieldLighting.ISO_PER_BRIGHTNESS, 1e-3,
			"a darker view lifted at most four times")
	assert_almost_eq(eyes.auto_exposure_max_sensitivity, 0.5 * FieldLighting.ISO_PER_BRIGHTNESS, 1e-3,
			"never darker than tuned")
	assert_almost_eq(eyes.auto_exposure_speed, look.eye_speed, 1e-5)
	assert_lt(look.eye_speed, 1.0, "a frame a second long never overshoots")


func test_a_lift_or_drop_under_one_still_holds_the_exposure() -> void:
	var cfg := LightingConfig.new()
	cfg.eye_lift = 0.5
	cfg.eye_drop = 0.0
	var eyes := FieldLighting.eye_attributes(cfg, LookConfig.new())
	assert_almost_eq(eyes.auto_exposure_min_sensitivity, eyes.auto_exposure_max_sensitivity, 1e-3)


func test_the_row_turns_the_eyes_on_and_off() -> void:
	var lighting := _lighting()
	assert_null(_world(lighting).camera_attributes, "built off, so a preset without it costs nothing")
	GraphicsApply.apply_field(table.preset(&"ultra"), lighting, null, GraphicsApply.Server.new())
	var eyes := _world(lighting).camera_attributes as CameraAttributesPractical
	assert_not_null(eyes)
	assert_true(eyes.auto_exposure_enabled)
	assert_true(lighting.eye_adaptation())
	lighting.set_eye_adaptation(true)
	assert_same(_world(lighting).camera_attributes, eyes, "a repeat keeps the same eyes")
	GraphicsApply.apply_field(table.preset(&"medium"), lighting, null, GraphicsApply.Server.new())
	assert_null(_world(lighting).camera_attributes)
	assert_false(lighting.eye_adaptation())


func test_the_night_keeps_its_dark() -> void:
	var woodland := MapData.load_map("woodland", play.map_style, 6)
	var night := LightingConfig.for_map(play.lighting, play.night_lighting, woodland, play.night_lighting.id)
	assert_almost_eq(night.eye_lift, 1.0, 1e-5, "by night the eyes never lift the tuned dark")
	var eyes := FieldLighting.eye_attributes(night, play.look)
	assert_almost_eq(eyes.auto_exposure_min_sensitivity, eyes.auto_exposure_max_sensitivity, 1e-3,
			"held at the night's own exposure")
	assert_gt(play.lighting.eye_lift, 1.0, "by day it lifts")


func test_the_scope_glass_never_adapts_on_its_own() -> void:
	var eyes := Camera3D.new()
	add_child_autofree(eyes)
	var glass := OpticGlass.new()
	glass.setup(ViewModelConfig.new(), ViewConfig.new(), eyes)
	add_child_autofree(glass)
	var own := glass._camera.attributes as CameraAttributesPractical
	assert_not_null(own, "its own attributes, so the field's adapting ones never reach it")
	assert_false(own.auto_exposure_enabled, "the main view tonemaps its picture, adapting once")
