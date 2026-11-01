extends GutTest
## BP2 QA: the code shaders are shared yet each material keeps its own uniforms; the HUD draws its crosshair again
## whenever something it shows changes (and not otherwise); a BB impact's occlusion ray with no direction known keeps
## the old gap, one with a direction casts from its own side of a wall of any thickness.

const HudSizeTest := preload("res://tests/unit/test_hud_size.gd")

var body: BodyConfig = BodyConfig.new()
var you: Character = null
var state: GameState = null


func before_each() -> void:
	you = Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	you.prev_position = you.position
	state = GameState.new(1)
	state.characters.append(you)


# --- shared shaders -----------------------------------------------------------------------------------------------------


func test_two_night_skies_share_a_shader_but_keep_their_own_colours() -> void:
	var a := LightingConfig.new()
	var b := LightingConfig.new()
	a.sky_top = Color(1.0, 0.0, 0.0)
	b.sky_top = Color(0.0, 0.0, 1.0)
	var first := FieldLighting.night_sky_material(a)
	var second := FieldLighting.night_sky_material(b)
	assert_same(first.shader, second.shader)
	assert_eq(first.get_shader_parameter(&"top"), a.sky_top)
	assert_eq(second.get_shader_parameter(&"top"), b.sky_top, "set per material, not on the shared shader")


func test_a_shared_shader_survives_the_first_material_being_freed() -> void:
	var first := FieldLighting.night_sky_material(LightingConfig.new())
	var shader := first.shader
	first = null
	var second := FieldLighting.night_sky_material(LightingConfig.new())
	assert_same(second.shader, shader)
	assert_true(is_instance_valid(second.shader))
	assert_true(second.shader.code.length() > 0)


func test_every_cached_shader_compiles_to_a_uniform_list() -> void:
	for code: String in [FieldLighting.NIGHT_SKY, LightPools.POOL_SHADER, KickedDust.SHADER, WindDust.SHADER,
			TorchBeams.CONE_SHADER, WoodsView.TUFT_SHADER, WoodsView.AIR_SHADER]:
		var s := CodeShaders.of(code)
		assert_eq(s.code, code)
		assert_gt(s.get_shader_uniform_list().size(), 0, "a shader with uniforms: %s" % code.substr(0, 40))


func test_two_kicked_dusts_have_their_own_materials_on_the_one_shader() -> void:
	var cfg := EffectsConfig.new()
	var one := KickedDust.new()
	var two := KickedDust.new()
	add_child_autofree(one)
	add_child_autofree(two)
	one.setup(cfg, Color.RED, 1.0)
	two.setup(cfg, Color.BLUE, 1.0)
	var m1 := one.drawn_material() as ShaderMaterial
	var m2 := two.drawn_material() as ShaderMaterial
	assert_not_null(m1)
	assert_not_null(m2)
	assert_ne(m1, m2)
	assert_same(m1.shader, m2.shader)


# --- occlusion with and without a direction -----------------------------------------------------------------------------


func test_an_impact_with_no_direction_keeps_the_old_gap_and_one_with_a_direction_sees_a_thin_wall() -> void:
	var cfg := SoundConfig.new()
	var world := BoxWorld.new(body)
	world.add_box(Vector3(0.0, 1.5, 10.0), Vector3(6.0, 3.0, 0.1))
	var occ := SoundOcclusion.new(cfg, world)
	occ.begin_tick(state.characters, you, you.eye(body))
	var far_side := Vector3(0.0, you.eye(body).y, 10.05)
	assert_eq(occ.impact_share(far_side), 0.0, "no way in known: stops 0.2 m short, never meets 0.1 m of wall")
	assert_eq(occ.impact_share(far_side, Vector3(0.0, 0.0, -60.0)), 1.0, "arriving from the other side: muffled")
	var near_side := Vector3(0.0, you.eye(body).y, 9.95)
	assert_eq(occ.impact_share(near_side, Vector3(0.0, 0.0, 60.0)), 0.0, "the near face, struck from this side: open")


func test_a_thick_wall_is_still_blocked_by_either_ray() -> void:
	var cfg := SoundConfig.new()
	var world := BoxWorld.new(body)
	world.add_box(Vector3(0.0, 1.5, 10.0), Vector3(6.0, 3.0, 1.0))
	var occ := SoundOcclusion.new(cfg, world)
	occ.begin_tick(state.characters, you, you.eye(body))
	var at := Vector3(0.0, you.eye(body).y, 10.5)
	assert_eq(occ.impact_share(at), 1.0)
	assert_eq(occ.impact_share(at, Vector3(0.0, 0.0, -60.0)), 1.0)


func test_a_grazing_impact_on_the_floor_in_view_is_open() -> void:
	var cfg := SoundConfig.new()
	var world := BoxWorld.new(body)
	var occ := SoundOcclusion.new(cfg, world)
	occ.begin_tick(state.characters, you, you.eye(body))
	var at := Vector3(0.0, 0.0, 8.0)
	for angle: float in [1.0, 5.0, 30.0, 90.0]:
		var v := Vector3(0.0, -sin(deg_to_rad(angle)), cos(deg_to_rad(angle))) * 60.0
		assert_eq(occ.impact_share(at, v), 0.0, "floor at %s degrees, nothing between" % angle)


func test_an_impact_at_the_listener_with_a_direction_does_not_error() -> void:
	var cfg := SoundConfig.new()
	var occ := SoundOcclusion.new(cfg, BoxWorld.new(body))
	occ.begin_tick(state.characters, you, you.eye(body))
	assert_eq(occ.impact_share(you.eye(body), Vector3(0.0, 0.0, 60.0)), 0.0)
	assert_eq(occ.impact_share(you.eye(body), Vector3(0.0, 0.0, 1e-20)), 0.0)


# --- the HUD's redraw only when something changed -----------------------------------------------------------------------


func _hud(window: Vector2 = Vector2(1920.0, 1080.0)) -> Hud:
	var frame := Control.new()
	frame.size = HudSizeTest.canvas_of(window)
	add_child_autofree(frame)
	var hud := Hud.new()
	frame.add_child(hud)
	hud.setup(HudConfig.new(), TeamConfig.new(), ViewConfig.new(), SimTuning.new(), you)
	hud.apply_prefs(HudPrefs.new())
	hud._stats = MatchStats.new()
	hud._names = PackedStringArray(["You"])
	return hud


var draws: int = 0
var drawn_hud: Hud = null


func _count_draws() -> void:
	draws += 1


## Whether `hud` drew since the last call (its `draw` signal), after a frame lets a queued redraw happen.
func _drew(hud: Hud) -> bool:
	if drawn_hud != hud:
		drawn_hud = hud
		hud.draw.connect(_count_draws)
		draws = 0
	await wait_process_frames(2)
	var any := draws > 0
	draws = 0
	return any


## Updates twice and lets the frame draw, so the next update starts from a drawn HUD.
func _settled(hud: Hud, zoom: float = 1.0) -> void:
	hud.update(state, zoom, 0.0)
	await _drew(hud)
	hud.update(state, zoom, 0.0)
	await _drew(hud)


func test_an_unchanged_hud_does_not_queue_a_redraw() -> void:
	var hud := _hud()
	await _settled(hud)
	assert_false(await _drew(hud), "drawn and nothing changed")
	hud.update(state, 1.0, 0.0)
	assert_false(await _drew(hud), "an update with the same inputs")


func test_a_changed_spread_queues_a_redraw() -> void:
	var hud := _hud()
	var prefs := HudPrefs.new()
	prefs.gap = 0.0
	prefs.dynamic = true
	hud.apply_prefs(prefs)
	await _settled(hud)
	you.spread_scale = 8.0
	hud.update(state, 1.0, 0.0)
	assert_true(await _drew(hud), "the spread widened the gap")


func test_a_zoom_change_that_moves_the_gap_queues_a_redraw() -> void:
	var hud := _hud()
	var prefs := HudPrefs.new()
	prefs.gap = 0.0
	hud.apply_prefs(prefs)
	you.spread_scale = 4.0
	await _settled(hud, 1.0)
	hud.update(state, 3.0, 0.0)
	assert_true(await _drew(hud), "zoomed in: the same spread is wider on screen")


func test_the_hit_marker_redraws_while_it_fades_and_once_more_as_it_ends() -> void:
	var hud := _hud()
	await _settled(hud)
	hud._marker_left = 0.2
	hud.update(state, 1.0, 0.05)
	assert_true(await _drew(hud), "the marker is up")
	await _drew(hud)
	hud.update(state, 1.0, 0.05)
	assert_true(await _drew(hud), "and fading")
	await _drew(hud)
	hud.update(state, 1.0, 1.0)
	assert_true(await _drew(hud), "it ended: drawn without it")
	await _drew(hud)
	hud.update(state, 1.0, 0.016)
	assert_false(await _drew(hud), "and then still")


func test_a_hit_marker_switched_off_never_redraws_for_it() -> void:
	var hud := _hud()
	var prefs := HudPrefs.new()
	prefs.marker = false
	hud.apply_prefs(prefs)
	await _settled(hud)
	hud._marker_left = 0.2
	hud.update(state, 1.0, 0.05)
	assert_false(await _drew(hud))


func test_losing_the_crosshair_queues_a_redraw() -> void:
	var hud := _hud()
	await _settled(hud)
	you.status = Character.Status.CALLING
	hud.update(state, 1.0, 0.0)
	assert_true(await _drew(hud), "hit: the crosshair goes")
	await _drew(hud)
	you.status = Character.Status.ALIVE
	hud.update(state, 1.0, 0.0)
	assert_true(await _drew(hud), "and comes back")


func test_new_crosshair_prefs_queue_a_redraw_even_with_the_same_gap_and_size() -> void:
	var hud := _hud()
	await _settled(hud)
	var prefs := HudPrefs.new()
	prefs.colour = (prefs.colour + 1) % HudPrefs.COLOURS.size()
	prefs.shape = HudPrefs.Shape.CIRCLE
	hud.apply_prefs(prefs)
	await _drew(hud)
	assert_false(await _drew(hud))
	hud.apply_prefs(prefs)
	hud.update(state, 1.0, 0.0)
	assert_true(await _drew(hud), "after apply_prefs the next update draws")


func test_prefs_changed_in_place_and_applied_again_redraw() -> void:
	var hud := _hud()
	var prefs := HudPrefs.new()
	hud.apply_prefs(prefs)
	await _settled(hud)
	prefs.outline = not prefs.outline
	prefs.opacity = 0.3
	hud.apply_prefs(prefs)
	await _drew(hud)
	hud.update(state, 1.0, 0.0)
	assert_true(await _drew(hud))


func test_a_resized_hud_queues_a_redraw() -> void:
	var hud := _hud()
	await _settled(hud)
	(hud.get_parent() as Control).size = Vector2(1280.0, 720.0)
	hud.size = Vector2(1280.0, 720.0)
	hud.update(state, 1.0, 0.0)
	assert_true(await _drew(hud), "the centre moved")


func test_a_hud_size_change_queues_a_redraw() -> void:
	var hud := _hud()
	await _settled(hud)
	hud.set_hud_size(1.5)
	assert_true(await _drew(hud))


func test_a_hud_shown_again_after_being_hidden_draws_its_crosshair() -> void:
	var hud := _hud()
	await _settled(hud)
	hud.visible = false
	await _drew(hud)
	hud.update(state, 1.0, 0.0)
	hud.visible = true
	await _drew(hud)
	assert_false(await _drew(hud), "drawn once shown, nothing left over")
