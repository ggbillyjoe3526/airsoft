extends GutTest
## BP6, the known-issues pass's graphics: the figures' detail lines scaled by the eye's zoom (a scope raised), and the
## shadow twin hidden while no light casts shadows.

var config: FigureConfig = FigureConfig.new()
var view: ViewConfig = ViewConfig.new()
var models: FigureModels = null


func before_all() -> void:
	models = FigureModels.new(config)
	models.load_kinds()


func _scope(zoom: float, to: float) -> ReplicaConfig:
	var r := ReplicaConfig.new()
	r.aim_zoom = zoom
	r.aim_zoom_to = to
	r.zoom_in_glass = true
	return r


func test_the_lines_scale_with_the_zoom_and_never_shrink() -> void:
	var high := GraphicsQuality.MeshDetail.HIGH
	assert_eq(config.zoomed_lines(high, 1.0), config.lod_high)
	assert_eq(config.zoomed_lines(high, 6.0), config.lod_high * 6.0, "a figure 6x farther looks as big")
	assert_eq(config.zoomed_lines(GraphicsQuality.MeshDetail.LOW, 4.0), config.lod_low * 4.0)
	assert_eq(config.zoomed_lines(high, 0.5), config.lod_high, "no zoom below 1")


func test_the_sight_zoom_is_the_glass_turned_or_the_view_raised() -> void:
	assert_almost_eq(FirstPersonView.sight_zoom(null, view, 0.0), view.aim_zoom, 1e-6, "iron sights")
	var dot := ReplicaConfig.new()
	dot.aim_zoom = 1.5
	assert_almost_eq(FirstPersonView.sight_zoom(dot, view, 1.5), 1.5, 1e-6, "an optic that zooms the view")
	assert_almost_eq(FirstPersonView.sight_zoom(_scope(2.0, 6.0), view, 6.0), 6.0, 1e-6, "the Variable Scope at 6x")
	assert_almost_eq(FirstPersonView.sight_zoom(_scope(2.0, 6.0), view, 2.0), 2.0, 1e-6, "turned to 2x")
	assert_almost_eq(FirstPersonView.sight_zoom(_scope(4.0, 0.0), view, 0.0), 4.0, 1e-6, "a fixed scope, no glass zoom")


func test_a_figure_40_m_off_through_6x_draws_its_nearest_level_and_its_radio() -> void:
	var b := FigureBody.new()
	assert_true(b.setup(models, FigureMix.HUMAN, 0, 0, Color.RED, 0.0,
			config.zoomed_lines(GraphicsQuality.MeshDetail.HIGH, 6.0)))
	add_child_autofree(b)
	var radio := b.skeleton.get_node(^"Kit_Radio_LOD1") as MeshInstance3D
	assert_gt(radio.visibility_range_end, 40.0, "the radio still drawn at 40 m")
	for i in b.meshes.size():
		if b.levels[i] == 0:
			assert_gt(b.meshes[i].visibility_range_end, 40.0, "%s drawn at 40 m, as at 6.7 m unzoomed" % b.meshes[i].name)


func test_the_shadow_twin_hides_while_nothing_casts_shadows_and_a_new_body_keeps_it() -> void:
	var c := Character.new(1, 1, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	var v := FigureView.new()
	add_child_autofree(v)
	v.setup(c, Color.BLUE, HitConfig.new(), GameTheme.font(800), false, [], 0.0, config)
	v.set_body(models, FigureMix.HUMAN, config.lod_high)
	var twin := v.body().meshes[-1]
	assert_eq(v.body().levels[-1], -1, "the twin is last")
	assert_true(twin.visible)
	v.set_shadow_cast(false)
	assert_false(twin.visible, "hidden on Low")
	v.set_body(models, FigureMix.ROBOT, config.lod_high)
	assert_false(v.body().meshes[-1].visible, "a new body (a rematch's kind) keeps it hidden")
	v.set_shadow_cast(true)
	assert_true(v.body().meshes[-1].visible)
	for i in v.body().meshes.size() - 1:
		assert_true(v.body().meshes[i].visible, "the levels are untouched")
	await get_tree().process_frame


func test_only_the_sun_casts_shadows() -> void:
	var q := GraphicsQuality.new()
	q.sun_shadows = false
	assert_false(GraphicsApply.any_shadows(q))
	assert_ne(GraphicsApply.torch_mode(q, LightingConfig.new(), true), TorchBeams.Mode.SHADOWED, "nor the torch then")
	q.sun_shadows = true
	assert_true(GraphicsApply.any_shadows(q))
