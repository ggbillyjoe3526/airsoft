extends GutTest
## GR2 QA: bug hunt over Applying the quality and Settings > Graphics (game/save/graphics_apply.gd and
## game/ui/settings_graphics_page.gd). Headless: properties and counts, never pixels.

const ROOT := "user://test-gr2-qa"
const FORWARD := "forward_plus"
const COMPATIBILITY := "gl_compatibility"

var s: Settings = null
var screen: SettingsScreen = null
var _saved: Dictionary[StringName, Variant] = {}
var _knobs: Array[StringName] = [&"scaling_3d_scale", &"scaling_3d_mode", &"msaa_3d", &"screen_space_aa", &"use_taa",
		&"anisotropic_filtering_level", &"mesh_lod_threshold"]
var _drawn_before: GraphicsQuality = null


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ROOT)
	for k in _knobs:
		_saved[k] = get_tree().root.get(k)
	_drawn_before = GraphicsApply.server().drawn
	s = Settings.new(PlayTuning.new())
	screen = SettingsScreen.new()
	screen.settings = s
	screen.save_path = ROOT.path_join("settings.save")
	add_child_autofree(screen)
	screen.open()


func after_each() -> void:
	for k in _knobs:
		get_tree().root.set(k, _saved[k])
	GraphicsApply.server().drawn = _drawn_before
	get_tree().paused = false


func after_all() -> void:
	for f: String in DirAccess.get_files_at(ROOT):
		DirAccess.remove_absolute(ROOT.path_join(f))
	DirAccess.remove_absolute(ROOT)


func _page() -> SettingsGraphicsPage:
	return screen._graphics_page


func _probe(preset: StringName, method: String = FORWARD) -> GraphicsPick.Probe:
	var p := GraphicsPick.Probe.new()
	p.preset = preset
	p.rendering_method = method
	p.driver = "vulkan"
	return p


func _preset(page: SettingsGraphicsPage, name: StringName) -> void:
	page.preset_choice().button(GraphicsTable.PRESETS.find(name)).pressed.emit()


func _choice(page: SettingsGraphicsPage, id: StringName, name: String) -> Button:
	var line := page.line(id)
	return line.choice.button(line.levels.find(GraphicsQuality.CHOICES[id].find(name)))


# --- Sliders ---

func test_closing_the_tab_mid_drag_keeps_the_value() -> void:
	var page := _page()
	_preset(page, &"high")
	var slider := page.line(GraphicsQuality.RENDER_SCALE).slider
	slider.drag_started.emit()
	slider.value = 60.0
	screen.close() # Esc while the slider is held: the slider's drag_ended never comes (checked with real mouse events)
	assert_eq(s.graphics_in_force(page.probe.preset).render_scale, 60, "the value let go of on close is kept")


func test_a_closed_mid_drag_does_not_leave_the_slider_deaf() -> void:
	var page := _page()
	_preset(page, &"high")
	var slider := page.line(GraphicsQuality.RENDER_SCALE).slider
	slider.drag_started.emit()
	slider.value = 60.0
	screen.close()
	screen.open()
	slider.value = 80.0 # an arrow key's step
	assert_eq(s.graphics_in_force(page.probe.preset).render_scale, 80, "a keyboard step still applies")


# --- The Custom marking ---

func test_custom_stays_in_step_through_change_preset_and_change_back() -> void:
	var page := _page()
	_preset(page, &"high")
	_choice(page, GraphicsQuality.AMBIENT_OCCLUSION, "off").pressed.emit()
	assert_true(page.line(GraphicsQuality.AMBIENT_OCCLUSION).marked())
	_preset(page, &"low")
	assert_eq(s.graphics_choice, &"low")
	for id in GraphicsQuality.ROWS:
		assert_false(page.line(id).marked(), "%s unmarked after a preset" % id)
	# Low's ambient occlusion is already off: changing to the same level is no change.
	_choice(page, GraphicsQuality.AMBIENT_OCCLUSION, "off").pressed.emit()
	assert_eq(s.graphics_choice, &"low", "no change, no Custom")
	_choice(page, GraphicsQuality.AMBIENT_OCCLUSION, "half").pressed.emit()
	assert_eq(s.graphics_base, &"low")
	assert_true(page.line(GraphicsQuality.AMBIENT_OCCLUSION).marked())
	_choice(page, GraphicsQuality.AMBIENT_OCCLUSION, "off").pressed.emit()
	assert_false(page.line(GraphicsQuality.AMBIENT_OCCLUSION).marked(), "changed back: no mark")
	assert_true(s.graphics_custom.is_empty(), "no rows of its own")
	assert_true(GraphicsApply.server().drawn.equals(GraphicsTable.shared().preset(&"low")), "drawn as Low again")


func test_custom_then_another_custom_row_counts_each_change() -> void:
	var page := _page()
	_preset(page, &"medium")
	_choice(page, GraphicsQuality.MESH_DETAIL, "ultra").pressed.emit()
	_choice(page, GraphicsQuality.TEXTURE_FILTERING, "2x").pressed.emit()
	assert_eq(s.graphics_base, &"medium", "the base stays the preset you were on")
	assert_string_contains(page.blurb(), "Medium with 2 changes")
	_preset(page, GraphicsQuality.CUSTOM)
	assert_eq(s.graphics_custom.size(), 2, "Custom picked again keeps its rows")


# --- Reset ---

func test_reset_saves_only_the_choice_and_a_later_custom_starts_from_the_pick() -> void:
	var page := _page()
	_preset(page, &"ultra")
	_choice(page, GraphicsQuality.MESH_DETAIL, "low").pressed.emit()
	page.reset_button().pressed.emit()
	var now := s.to_dict()
	assert_false(now.has("graphics_choice"), "automatic is never written")
	assert_eq(now["graphics_custom"], {} as Dictionary[String, Variant], "no rows of its own")
	assert_eq(s.graphics_in_force(page.probe.preset).level(GraphicsQuality.MESH_DETAIL),
			GraphicsTable.shared().preset(page.probe.preset).mesh_detail, "the pick's own rows")
	_choice(page, GraphicsQuality.TEXTURE_FILTERING, "2x").pressed.emit()
	assert_eq(s.graphics_base, page.probe.preset, "Custom starts from the pick, not the old base")


func test_reset_in_a_forced_run_is_a_noop_the_tab_shows() -> void:
	s.graphics_forced = &"low"
	screen.open()
	var page := _page()
	_choice(page, GraphicsQuality.MESH_DETAIL, "ultra").pressed.emit()
	assert_eq(page.line(GraphicsQuality.MESH_DETAIL).choice.selected(), page.line(GraphicsQuality.MESH_DETAIL).levels.find(
			GraphicsTable.shared().preset(&"low").mesh_detail), "a row the forced run can't change snaps back")


# --- Compatibility ---

func test_compatibility_draws_low_with_bilinear_and_greys_taa_and_ssao() -> void:
	var values := GraphicsApply.values_for(_settings_low(), _probe(&"low", COMPATIBILITY))
	assert_eq(values.upscaler, GraphicsQuality.Upscaler.BILINEAR)
	var page := SettingsGraphicsPage.new()
	page.probe = _probe(&"low", COMPATIBILITY)
	page.build(screen)
	page.refresh()
	add_child_autofree(page)
	assert_true(page.line(GraphicsQuality.TEMPORAL_SMOOTHING).check.disabled)
	assert_true(page.line(GraphicsQuality.AMBIENT_OCCLUSION).shut)
	for b in page.line(GraphicsQuality.AMBIENT_OCCLUSION).choice.get_children():
		if (b as Button).text != "OFF":
			assert_true((b as Button).disabled, "%s shut" % (b as Button).text)


func test_a_saved_high_on_the_simpler_renderer_draws_without_ssao_or_taa() -> void:
	var st := Settings.new(PlayTuning.new())
	st.choose_graphics(&"ultra", &"low")
	st.change_graphics_row(GraphicsQuality.TEMPORAL_SMOOTHING, "on", &"low")
	var values := GraphicsApply.values_for(st, _probe(&"low", COMPATIBILITY))
	assert_false(values.temporal_smoothing)
	assert_eq(values.ambient_occlusion, GraphicsQuality.AmbientOcclusion.OFF)
	assert_ne(values.edge_smoothing, GraphicsQuality.EdgeSmoothing.SMAA)
	assert_eq(st.graphics_in_force(&"low").temporal_smoothing, true, "the saved choice is kept for a better renderer")


func _settings_low() -> Settings:
	var st := Settings.new(PlayTuning.new())
	st.choose_graphics(&"low", &"low")
	return st


# --- Mid-match and a match after the change ---

func test_a_match_started_after_a_change_gets_the_optic_glass_picture_too() -> void:
	var table := GraphicsTable.shared()
	var low := table.preset(&"low")
	low.edge_smoothing = GraphicsQuality.EdgeSmoothing.FXAA
	GraphicsApply.server().drawn = low
	var eyes := Camera3D.new()
	add_child_autofree(eyes)
	var glass := OpticGlass.new()
	glass.setup(ViewModelConfig.new(), ViewConfig.new(), eyes)
	add_child_autofree(glass)
	var port := glass.get_child(0) as SubViewport
	assert_almost_eq(port.scaling_3d_scale, 0.8, 0.001, "the glass built after Low starts at Low's scale")
	assert_eq(port.screen_space_aa, Viewport.SCREEN_SPACE_AA_FXAA)


func test_the_glass_at_msaa_and_a_low_render_scale_keeps_a_drawable_picture() -> void:
	var table := GraphicsTable.shared()
	var eyes := Camera3D.new()
	add_child_autofree(eyes)
	var glass := OpticGlass.new()
	glass.setup(ViewModelConfig.new(), ViewConfig.new(), eyes)
	add_child_autofree(glass)
	var port := glass.get_child(0) as SubViewport
	var q := table.preset(&"ultra")
	q.render_scale = 50
	q.edge_smoothing = GraphicsQuality.EdgeSmoothing.MSAA_4X
	GraphicsApply.server().applied.emit(q)
	assert_eq(port.msaa_3d, Viewport.MSAA_4X)
	assert_almost_eq(port.scaling_3d_scale, 0.5, 0.001)
	glass.prewarm()
	await wait_process_frames(3)
	assert_gt(port.size.x, 0)
	assert_eq(port.scaling_3d_mode, Viewport.SCALING_3D_MODE_BILINEAR, "the glass stays bilinear")


func test_pause_menu_graphics_reach_the_dust_the_sun_and_ssao_of_the_live_match() -> void:
	var st := Settings.new(PlayTuning.new())
	var play := PlaySession.new()
	play.settings = st
	play.match_seed = 91
	add_child_autofree(play)
	await wait_physics_frames(3)
	get_tree().paused = true
	st.choose_graphics(&"low", &"high")
	SettingsApply.apply_graphics(st)
	assert_false(play._lighting.sun.shadow_enabled)
	assert_false(play._lighting.environment.ssao_enabled)
	assert_false(play._dust.emitting)
	st.choose_graphics(&"ultra", &"high")
	SettingsApply.apply_graphics(st)
	assert_true(play._lighting.sun.shadow_enabled)
	assert_true(play._lighting.environment.ssao_enabled)
	assert_true(play._dust.emitting)
	assert_almost_eq(play._lighting.sun.directional_shadow_max_distance, 100.0, 0.001)
	get_tree().paused = false


# --- Leaks in the menus ---

func test_switching_presets_in_the_tab_many_times_leaves_no_nodes_or_resources() -> void:
	var page := _page()
	_preset(page, &"high")
	await wait_process_frames(2)
	var orphans := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var resources := Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	for i in 40:
		for p in GraphicsTable.PRESETS:
			_preset(page, p)
		_choice(page, GraphicsQuality.MESH_DETAIL, "ultra").pressed.emit()
		page.reset_button().pressed.emit()
	_preset(page, &"high")
	await wait_process_frames(2)
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), orphans, "orphans")
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes, "nodes")
	# No growth: the count can fall while an earlier test's resources are freed (CI, 2026-10-23).
	assert_lte(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT), resources, "resources")


# --- Text ---

func test_every_label_choice_preset_and_line_of_the_tab_is_translated() -> void:
	var table := GraphicsTable.shared()
	var missing: Array[String] = []
	for id in GraphicsQuality.ROWS:
		var r := table.row(id)
		_need(r.label, missing)
		if GraphicsQuality.is_range(id):
			continue
		for c: String in r.choices:
			_need("GRAPHICS_CHOICE_%s" % c.to_upper(), missing)
	for p in GraphicsTable.PRESETS:
		_need("GRAPHICS_PRESET_%s" % String(p).to_upper(), missing)
		_need("GRAPHICS_BLURB_%s" % String(p).to_upper(), missing)
	_need("GRAPHICS_PRESET_CUSTOM", missing)
	assert_eq(missing, [] as Array[String])


func _need(key: String, missing: Array[String]) -> void:
	if tr(key) == key:
		missing.append(key)


func test_the_lead_line_formats_in_every_state_without_a_stray_placeholder() -> void:
	var page := _page()
	_preset(page, &"high")
	var lines: Array[String] = [page.blurb()]
	_choice(page, GraphicsQuality.MESH_DETAIL, "ultra").pressed.emit()
	lines.append(page.blurb())
	_choice(page, GraphicsQuality.TEXTURE_FILTERING, "2x").pressed.emit()
	lines.append(page.blurb())
	_choice(page, GraphicsQuality.MESH_DETAIL, "high").pressed.emit()
	_choice(page, GraphicsQuality.TEXTURE_FILTERING, "16x").pressed.emit()
	lines.append(page.blurb())
	page.reset_button().pressed.emit()
	lines.append(page.blurb())
	lines.append(page.reset_button().text)
	lines.append_array(page.system_lines())
	for l in lines:
		assert_false(l.contains("%"), "no stray placeholder in: %s" % l)
		assert_false(l.contains("GRAPHICS_"), "no raw key in: %s" % l)
