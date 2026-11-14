extends GutTest
## DP5: a gas replica's breath (GasPuffs), dust kicked up by feet (KickedDust), the wind's specks lit by the sun
## (WindDust) and the figures' contact shadows (FigureView): pooled, never on the wrong replica or footfall, never tall
## enough to hide anyone, off where the graphics say, and never in a team's hue.

const TICK := 1.0 / 60.0
const EYE := Vector3(0.0, 1.6, 3.0)

var cfg: EffectsConfig = null


func before_each() -> void:
	cfg = EffectsConfig.new()


func _gas() -> GasPuffs:
	var g := GasPuffs.new()
	add_child_autofree(g)
	g.setup(cfg)
	return g


func _kicked(tint: Color = Color.WHITE, size: float = 1.0) -> KickedDust:
	var k := KickedDust.new()
	add_child_autofree(k)
	k.setup(cfg, tint, size)
	return k


## Each puff in the air's centre and radius, by pool slot, seen from EYE.
static func _drawn(p: DriftPuffs) -> Array[Vector4]:
	var out: Array[Vector4] = []
	for i in p.multimesh.instance_count:
		var d := p.drawn(i, EYE)
		if d.w > 0.0:
			out.append(d)
	return out


# --- gas puffs ---

func test_only_a_gas_replica_breathes() -> void:
	var g := _gas()
	assert_true(g.breathes(load("res://game/config/replicas/pistol.tres") as ReplicaConfig), "the GBB pistol")
	assert_false(g.breathes(load("res://game/config/replicas/aeg.tres") as ReplicaConfig), "an AEG")
	assert_false(g.breathes(load("res://game/config/replicas/cyber.tres") as ReplicaConfig), "the battery pistol")
	var spring := ReplicaConfig.new()
	spring.power = &"spring"
	assert_false(g.breathes(spring), "a spring replica")


func test_a_shot_puffs_at_the_muzzle_forward_and_at_the_port_to_the_right() -> void:
	var g := _gas()
	var muzzle := Vector3(0.0, 1.5, -0.5)
	var eye := Vector3(0.0, 1.6, 0.0)
	g.shot(muzzle, eye, Vector3.FORWARD, eye)
	assert_eq(g.live(), 2, "the muzzle's and the port's")
	g.update(0.1, eye)
	var puffs := _drawn(g)
	assert_eq(puffs.size(), 2)
	assert_lt(puffs[0].z, muzzle.z, "pushed forward from the muzzle")
	assert_gt(puffs[1].x, 0.0, "the port's goes right")
	assert_lt(puffs[1].w, puffs[0].w, "and is the smaller")
	assert_true(g.visible)
	g.update(cfg.gas_life, eye)
	assert_eq(g.live(), 0, "gone after its life")
	assert_false(g.visible, "no draw call while none is in the air")


func test_the_pool_is_fixed_and_the_oldest_puff_is_reused() -> void:
	var g := _gas()
	for i in 20:
		g.shot(Vector3(i, 1.5, 0.0), Vector3(i, 1.6, 0.5), Vector3.FORWARD, EYE)
	assert_eq(g.multimesh.instance_count, cfg.gas_pool, "never grown: no allocation a shot")
	assert_eq(g.live(), cfg.gas_pool, "the pool full, the oldest reused")


func test_a_far_puff_keeps_its_least_size_on_screen() -> void:
	var g := _gas()
	g.shot(Vector3(0.0, 1.5, -30.0), Vector3(0.0, 1.6, -29.5), Vector3.FORWARD, EYE)
	g.update(TICK, EYE)
	var far := _drawn(g)[0]
	var distance := EYE.distance_to(Vector3(far.x, far.y, far.z))
	assert_almost_eq(far.w, cfg.gas_min_angle * distance, 1e-4, "a hint at 33 m, not nothing")
	g.clear()
	g.shot(Vector3(0.0, 1.5, -cfg.gas_range - 4.0), Vector3(0.0, 1.6, -cfg.gas_range - 3.5), Vector3.FORWARD, EYE)
	assert_eq(g.live(), 0, "none beyond its range: a far puff would cover its shooter")


# --- kicked dust ---

func test_only_a_sprint_or_a_landing_in_range_kicks_dust_and_a_landing_more() -> void:
	var k := _kicked()
	k.footfall(GameEvent.Footstep.RUN, Vector3.ZERO, EYE)
	k.footfall(GameEvent.Footstep.RATTLE, Vector3.ZERO, EYE)
	assert_eq(k.live(), 0, "a run or a rattle kicks none")
	k.footfall(GameEvent.Footstep.SPRINT, Vector3.ZERO, EYE)
	k.footfall(GameEvent.Footstep.LAND, Vector3(2.0, 0.0, 0.0), EYE)
	assert_eq(k.live(), 2)
	k.footfall(GameEvent.Footstep.SPRINT, Vector3(0.0, 0.0, -cfg.kick_range - 4.0), EYE)
	assert_eq(k.live(), 2, "none beyond its range of the eye")
	k.update(cfg.kick_grow_time, EYE)
	var puffs := _drawn(k)
	assert_almost_eq(puffs[1].w / puffs[0].w, cfg.kick_land, 1e-3, "a landing's is bigger")


func test_its_top_stays_under_the_cap_all_its_life_so_it_never_hides_anyone() -> void:
	var k := _kicked(Color.WHITE, 2.0)
	var feet := Vector3(0.0, 3.0, 0.0)
	k.footfall(GameEvent.Footstep.LAND, feet, EYE)
	var highest := -INF
	for i in ceili(cfg.kick_life / TICK):
		k.update(TICK, EYE)
		for p in _drawn(k):
			highest = maxf(highest, p.y + p.w)
	assert_lte(highest - feet.y, 0.3 + 1e-5, "at twice the size, landing, on a raised floor")
	assert_gt(highest - feet.y, 0.0)


func test_it_takes_the_maps_tint_and_switches_off_with_the_wind_dust() -> void:
	var depot := MapData.load_map("depot", PlayTuning.load_default().map_style, 1)
	var k := _kicked(depot.kicked_dust_tint, depot.kicked_dust_scale)
	k.footfall(GameEvent.Footstep.SPRINT, Vector3.ZERO, EYE)
	k.update(TICK, EYE)
	var c := k.drawn_colour(0)
	assert_eq(c.to_html(false), "b9b7b0", "Depot's dressing.kickedDust")
	assert_lt(c.a, cfg.kick_opacity + 1e-4, "faint")
	var look := k.multimesh.mesh.surface_get_material(0) as ShaderMaterial
	assert_not_null(look, "its own material, not PuffView's unshaded one")
	assert_false(look.shader.code.contains("unshaded"), "lit by the floor's light")
	assert_true(look.shader.code.contains("void light()"), "takes each light whichever way it faces")
	assert_eq(look.get_shader_parameter(&"lit"), cfg.kick_lit)
	var table := GraphicsTable.shared()
	GraphicsApply.apply_field(table.preset(&"low"), null, null, GraphicsApply.Server.new(), null, k)
	assert_false(k.is_on(), "Low's wind dust is 0 %")
	assert_eq(k.live(), 0, "none left in the air")
	k.footfall(GameEvent.Footstep.LAND, Vector3.ZERO, EYE)
	assert_eq(k.live(), 0)
	GraphicsApply.apply_field(table.preset(&"medium"), null, null, GraphicsApply.Server.new(), null, k)
	assert_true(k.is_on(), "Medium's is 50 %")


# --- wind dust, contact shadows, colours ---

func test_the_specks_are_lit_by_the_light_and_fade_near_the_eye() -> void:
	var dust := WindDust.new()
	add_child_autofree(dust)
	dust.setup(cfg)
	var mat := dust.drawn_material() as ShaderMaterial
	assert_not_null(mat, "a lit shader, no longer unshaded")
	var code := mat.shader.code
	assert_string_contains(code, "void light()")
	assert_string_contains(code, "ambient_light_disabled", "nothing in shade")
	assert_false(code.contains("unshaded"))
	assert_eq(mat.get_shader_parameter(&"fade_near"), cfg.dust_fade_near)
	assert_eq(mat.get_shader_parameter(&"fade_far"), cfg.dust_fade_far)
	dust.set_share(1.0)
	dust.set_motion(MotionScale.of(true, _half_dust()))
	assert_eq(dust.amount, roundi(cfg.dust_count * 0.5), "Reduced motion keeps its share")


static func _half_dust() -> AccessibilityTable:
	var t := AccessibilityTable.read_file()
	t.motion[&"dust"] = 0.5
	return t


func test_contact_shadows_only_where_the_sun_casts_none() -> void:
	var table := GraphicsTable.shared()
	assert_true(GraphicsApply.contact_shadows(table.preset(&"low")))
	for p: StringName in [&"medium", &"high", &"ultra"]:
		assert_false(GraphicsApply.contact_shadows(table.preset(p)), p)


func test_the_contact_shadow_lies_under_the_feet_and_stays_on_the_floor_off_it() -> void:
	var c := Character.new(3, 0, Vector3(1.0, 0.5, 2.0), 0.0, ReplicaStats.default_loadout())
	c.grounded = true
	var f := FigureView.new()
	add_child_autofree(f)
	f.setup(c, Color.RED, HitConfig.new(), null)
	f.add_contact_shadow(FigureView.contact_mesh(cfg), cfg)
	var disc := f.contact_shadow()
	assert_false(disc.visible, "hidden until the graphics ask")
	f.set_contact_shadow(true)
	f.update(c, 1.0)
	assert_almost_eq(disc.global_position, Vector3(1.0, 0.5 + cfg.contact_lift, 2.0), Vector3.ONE * 1e-4)
	assert_almost_eq(disc.global_basis.get_scale().x, cfg.contact_radius, 1e-4)
	assert_eq(f.contact_fade(), 1.0)
	c.grounded = false
	c.prev_position = c.position + Vector3.UP * cfg.contact_fade_height * 0.5
	c.position = c.prev_position
	f.update(c, 1.0)
	assert_almost_eq(disc.global_position.y, 0.5 + cfg.contact_lift, 1e-4, "on the floor while the feet are off it")
	assert_almost_eq(1.0 - f.contact_fade(), 0.5, 1e-3, "fading with the height")


func test_the_figures_muzzle_is_read_from_the_model() -> void:
	var model := (load(FigureView.MODEL_DIR + "pistol.glb") as PackedScene).instantiate()
	var at := FigureView._in_model(model.find_child(ReplicaParts.MUZZLE_NODE, true, false) as Node3D, model)
	assert_almost_eq(at, Vector3(0.0, 0.0119, -0.1006), Vector3.ONE * 1e-3,
			"the pistol's muzzle point (BL2; GS2: the bore 48 % down the face)")
	model.free()


func test_no_effect_colour_reads_as_a_team() -> void:
	var teams := AccessibilityTable.read_file().colours
	var style := PlayTuning.load_default().map_style
	var colours: Dictionary[String, Color] = {"gas": cfg.gas_colour, "wind dust": cfg.dust_colour}
	for id: String in ["depot", "range", "woodland"]:
		colours[id + " kicked dust"] = MapData.load_map(id, style, 1).kicked_dust_tint
	for what: String in colours:
		assert_false(FieldChecks.reads_as_team(colours[what], teams), what)


func test_a_match_draws_them_from_its_events_and_its_graphics() -> void:
	var p := PlaySession.new()
	p.settings = Settings.new(PlayTuning.new())
	p.map_id = "depot"
	p.autopilot = true
	add_child_autofree(p)
	await wait_process_frames(2)
	var table := GraphicsTable.shared()
	p._apply_graphics(table.preset(&"low"))
	for f in p._figures:
		assert_true(f.contact_shadow().visible, "%s: a contact shadow on Low" % f.name)
	assert_false(p._kicked.is_on(), "no kicked dust on Low")
	p._apply_graphics(table.preset(&"high"))
	assert_false(p._figures[0].contact_shadow().visible, "the sun's own shadows on High")
	assert_true(p._kicked.is_on())
	var shot := GameEvent.new()
	shot.kind = GameEvent.Kind.SHOT
	shot.actor = PlaySession.PLAYER_ID
	shot.direction = Vector3.FORWARD
	var replicas := p.player.armament.replicas
	assert_true(replicas.any(func(r: ReplicaConfig) -> bool: return r.power == &"gas"), "a gas pistol in the kit")
	for slot in replicas.size():
		shot.slot = slot
		p._breathe(shot, p.player)
		assert_eq(p._gas.live(), 2 if replicas[slot].power == &"gas" else 0, "%s, in hand" % replicas[slot].id)
		p._gas.clear()
	var bot := p.state.characters[1]
	var gas_slot := -1
	for slot in bot.armament.replicas.size():
		if bot.armament.replicas[slot].power == &"gas":
			gas_slot = slot
	shot.actor = bot.id
	shot.slot = gas_slot
	p._breathe(shot, bot)
	assert_eq(p._gas.live(), 2, "through a bot's eyes its pistol breathes from the view")
	p._gas.clear()
	p._kicked.footfall(GameEvent.Footstep.SPRINT, p.player.position, p._eyes.global_position)
	assert_eq(p._kicked.live(), 1, "a sprint by you")
