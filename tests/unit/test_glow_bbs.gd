extends GutTest
## WL8: Glowing BBs. Customise's choice per replica (At Night by default, Always, Off), saved with the loadout, an old
## save reading At Night and every bot loading At Night; a glowing BB drawn green with a green streak, never under its
## least size on screen, a white one as before; and none of it reaching the simulation: a seeded match plays the same
## with every choice.

const MATCH_SEED := 11
const MATCH_SECONDS := 60.0
const SAVE_PATH := "user://test_glow_bbs.save"
## A BB this far from the eye, flying across the view at this speed (m, m/s).
const RANGE := 20.0
const SPEED := 90.0

var rules: LoadoutRules = null


func before_all() -> void:
	rules = LoadoutRules.standard()


func after_all() -> void:
	for p: String in [SAVE_PATH, SAVE_PATH + ".bak"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func test_each_replica_loads_glowing_bbs_at_night_until_another_choice() -> void:
	var l := rules.default_loadout("A")
	var primary := l.replica_id(Loadout.Slot.PRIMARY)
	var secondary := l.replica_id(Loadout.Slot.SECONDARY)
	assert_eq(l.glow_of(primary), Loadout.Glow.NIGHT, "At Night is the default")
	assert_true(l.set_glow(primary, Loadout.Glow.ALWAYS))
	assert_false(l.set_glow(primary, Loadout.Glow.ALWAYS), "no change, no edit")
	assert_eq(l.glow_of(primary), Loadout.Glow.ALWAYS)
	assert_eq(l.glow_of(secondary), Loadout.Glow.NIGHT, "per replica")
	var c := l.copy("B")
	l.set_glow(primary, Loadout.Glow.OFF)
	assert_eq(c.glow_of(primary), Loadout.Glow.ALWAYS, "a copy keeps its own")


func test_bbs_glow_by_the_choice_and_the_field() -> void:
	assert_true(Loadout.glows(Loadout.Glow.NIGHT, true))
	assert_false(Loadout.glows(Loadout.Glow.NIGHT, false))
	assert_true(Loadout.glows(Loadout.Glow.ALWAYS, true))
	assert_true(Loadout.glows(Loadout.Glow.ALWAYS, false))
	assert_false(Loadout.glows(Loadout.Glow.OFF, true))
	assert_false(Loadout.glows(Loadout.Glow.OFF, false))
	var choices: Array[Loadout.Glow] = [Loadout.Glow.OFF, Loadout.Glow.ALWAYS]
	assert_eq(BBView.glow_bits(choices, false), 2, "the secondary's bit")
	choices = [Loadout.Glow.NIGHT, Loadout.Glow.NIGHT]
	assert_eq(BBView.glow_bits(choices, true), 3)
	assert_eq(BBView.glow_bits(choices, false), 0)


func test_the_choice_is_saved_through_save_file() -> void:
	var saved := SavedLoadouts.new(rules)
	var l := saved.carried()
	var primary := l.replica_id(Loadout.Slot.PRIMARY)
	var secondary := l.replica_id(Loadout.Slot.SECONDARY)
	l.set_glow(primary, Loadout.Glow.ALWAYS)
	l.set_glow(secondary, Loadout.Glow.OFF)
	assert_true(saved.save(SAVE_PATH))
	var again := SavedLoadouts.new(rules)
	again.load_file(SAVE_PATH)
	assert_eq(again.load_message, "")
	assert_eq(again.carried().glow_of(primary), Loadout.Glow.ALWAYS)
	assert_eq(again.carried().glow_of(secondary), Loadout.Glow.OFF)
	var read := SaveFile.read(SAVE_PATH, SavedLoadouts.KIND)
	assert_eq(int(read.version), SavedLoadouts.VERSION, "the same version: the key is new, nothing old changes")


func test_an_old_save_reads_at_night() -> void:
	var saved := SavedLoadouts.new(rules)
	var l := saved.carried()
	l.set_glow(l.replica_id(Loadout.Slot.PRIMARY), Loadout.Glow.OFF)
	var data := saved.to_dict()
	for entry: Dictionary in data["slots"]:
		entry.erase("glow")
	var old := SavedLoadouts.new(rules)
	assert_eq(old.from_dict(data), [] as Array[String], "an old save reads without a word")
	for slot: Loadout.Slot in [Loadout.Slot.PRIMARY, Loadout.Slot.SECONDARY]:
		assert_eq(old.carried().glow_of(old.carried().replica_id(slot)), Loadout.Glow.NIGHT)


func test_a_choice_that_won_t_read_is_at_night_and_said() -> void:
	var saved := SavedLoadouts.new(rules)
	var primary := saved.carried().replica_id(Loadout.Slot.PRIMARY)
	var data := saved.to_dict()
	(data["slots"][0] as Dictionary)["glow"] = {primary: "sparkly", "no-such-replica": "always"}
	var problems := saved.from_dict(data)
	assert_eq(problems.size(), 2, str(problems))
	assert_eq(saved.carried().glow_of(primary), Loadout.Glow.NIGHT)
	(data["slots"][0] as Dictionary)["glow"] = "always"
	assert_eq(saved.from_dict(data).size(), 1)


func test_a_choice_saved_for_a_part_or_power_is_dropped_and_said() -> void:
	var saved := SavedLoadouts.new(rules)
	var part := rules.pool.parts[0]
	assert_ne(part.kind, Pool.Kind.REPLICA)
	var data := saved.to_dict()
	(data["slots"][0] as Dictionary)["glow"] = {part.id: "always"}
	var problems := saved.from_dict(data)
	assert_eq(problems.size(), 1, str(problems))
	assert_false(saved.carried().glow.has(part.id), "only a replica has Glowing BBs")


func test_the_kit_carries_each_slot_s_choice_and_bots_load_at_night() -> void:
	var l := rules.default_loadout("A")
	l.set_glow(l.replica_id(Loadout.Slot.SECONDARY), Loadout.Glow.ALWAYS)
	var kit := rules.carried(l)
	assert_eq(kit.glow_bbs, [Loadout.Glow.NIGHT, Loadout.Glow.ALWAYS] as Array[Loadout.Glow])
	assert_eq(BotKits.GLOW_BBS, Loadout.Glow.NIGHT)
	var kits := BotKits.shared()
	assert_gt(kits.kits.size(), 0)
	var bot := BotKits.kit_of(kits.kits[0], rules)
	assert_eq(bot.glow_bbs.size(), bot.replicas.size())
	for g in bot.glow_bbs:
		assert_eq(g, Loadout.Glow.NIGHT)


func test_the_glow_is_green_and_off_every_team_s_hue() -> void:
	var cfg := PlayTuning.load_default().effects
	assert_eq(cfg.glow_colour.to_rgba32(), Color8(157, 255, 122).to_rgba32())
	assert_eq(cfg.glow_streak_colour.to_rgba32(), Color8(92, 255, 74).to_rgba32())
	assert_almost_eq(cfg.glow_min_angle, 0.0045, 1e-6)
	assert_almost_eq(cfg.glow_streak_time, 0.05, 1e-6)
	var play := PlayTuning.load_default()
	var teams: Array[Color] = AccessibilityTable.read_file().colours
	teams.append_array(play.teams.colours)
	for c: Color in [cfg.glow_colour, cfg.glow_streak_colour]:
		assert_gt(FieldChecks.hue_gap(c, teams), FieldStandard.HUE_MARGIN_DEG, "#%s" % c.to_html(false))


func test_a_glowing_bb_is_green_with_its_streak_and_a_white_one_draws_as_before() -> void:
	var cfg := EffectsConfig.new()
	var view := _view(cfg)
	var pool := BBPool.new(4)
	_fire(pool, 1, 0, 1.0)
	_fire(pool, 2, 0, 1.0)
	_fire(pool, 1, 0, 0.02)
	view.update(pool, 0, Vector3.ZERO, 0.0, PlaySession.TICK, Vector3.ZERO)
	var draws := view.draws()
	assert_eq(draws.size(), 4, "white BBs, glowing balls and streaks, and the white BBs' trails (FB4): no halo")
	assert_eq(view.get_child_count(), 3)
	assert_eq(draws[0].multimesh.visible_instance_count, 1, "one white BB")
	var white := draws[0].material_override as ShaderMaterial
	assert_eq(white.get_shader_parameter(&"colour"), cfg.bb_colour, "white as before, rimmed (FB4)")
	assert_eq(draws[3].multimesh.visible_instance_count, 1, "its trail; none for the glowing ones")
	assert_eq(draws[1].multimesh.visible_instance_count, 2, "two glowing BBs")
	assert_eq(draws[2].multimesh.visible_instance_count, 2, "a streak each")
	assert_true(draws[1].visible and draws[2].visible)
	var green := draws[1].material_override as StandardMaterial3D
	assert_eq(green.albedo_color, cfg.glow_colour)
	assert_eq(green.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED, "lit itself")
	var trail := draws[2].multimesh.mesh.surface_get_material(0) as StandardMaterial3D
	assert_eq(Color(trail.albedo_color, 1.0), cfg.glow_streak_colour)
	assert_eq(trail.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA)
	view.free()


func test_a_glowing_bb_is_never_under_its_least_size_on_screen() -> void:
	var cfg := EffectsConfig.new()
	var at := Vector3(0.0, 0.0, -RANGE)
	var far := BBView.ball(cfg, at, Vector3.ZERO)
	assert_eq(far.origin, at)
	assert_almost_eq(far.basis.get_scale().x / RANGE, 2.0 * cfg.glow_min_angle, 1e-6,
			"0.0045 rad across its radius at 20 m")
	var near := BBView.ball(cfg, Vector3(0.0, 0.0, -0.5), Vector3.ZERO)
	assert_almost_eq(near.basis.get_scale().x, cfg.bb_size, 1e-6, "point-blank, a BB's size")
	for metres: float in [1.0, 5.0, 12.0, 40.0, 80.0]:
		var t := BBView.ball(cfg, Vector3(0.0, 0.0, -metres), Vector3.ZERO)
		assert_gte(t.basis.get_scale().x * 0.5 / metres, cfg.glow_min_angle - 1e-7, "%s m" % metres)


func test_the_streak_is_0_05_s_of_its_flight_facing_the_eye() -> void:
	var cfg := EffectsConfig.new()
	var at := Vector3(0.0, 0.0, -RANGE)
	var v := Vector3.RIGHT * SPEED
	var streak := BBView.streak_of(cfg, at, v, 1.0, Vector3.ZERO)
	assert_almost_eq(streak.basis.y.length(), SPEED * cfg.glow_streak_time, 1e-3, "0.05 s of its flight")
	assert_almost_eq(streak.origin.distance_to(at), SPEED * cfg.glow_streak_time * 0.5, 1e-3, "behind it")
	assert_lt(streak.origin.x, at.x, "back along its flight")
	assert_almost_eq(streak.basis.x.length(), cfg.glow_streak_angle * streak.origin.length(), 1e-5)
	assert_almost_eq(streak.basis.x.normalized().dot(streak.origin.normalized()), 0.0, 1e-5, "facing the eye")
	assert_almost_eq(streak.basis.z.dot(streak.basis.y), 0.0, 1e-4)
	var short := BBView.streak_of(cfg, at, v, 0.02, Vector3.ZERO)
	assert_almost_eq(short.basis.y.length(), SPEED * 0.02, 1e-3, "never longer than its flight so far")
	var end_on := BBView.streak_of(cfg, at, Vector3.FORWARD * SPEED, 1.0, Vector3.ZERO)
	assert_eq(end_on.basis.x, Vector3.ZERO, "seen end-on: not drawn")
	var standing := BBView.streak_of(cfg, at, Vector3.ZERO, 1.0, Vector3.ZERO)
	assert_eq(standing.basis.x, Vector3.ZERO, "no flight: not drawn")


func test_drawing_makes_nothing_and_hides_the_glow_with_none_in_flight() -> void:
	var cfg := EffectsConfig.new()
	var view := _view(cfg)
	var pool := BBPool.new(64)
	for i in 60:
		_fire(pool, i % 3, i % 2, 0.01 * i)
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var objects := Performance.get_monitor(Performance.OBJECT_COUNT)
	for frame in 30:
		view.update(pool, 0, Vector3(0.1, -0.1, -0.3), frame / 30.0, PlaySession.TICK, Vector3.ZERO)
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes, "no node made while drawing")
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), objects, "no object made while drawing")
	var bits := PackedByteArray([0, 0, 0])
	view.set_glowing(bits)
	assert_false(view._any, "none glows: white BBs skip the glow test")
	view.update(pool, 0, Vector3.ZERO, 0.0, PlaySession.TICK, Vector3.ZERO)
	var draws := view.draws()
	assert_eq(draws[0].multimesh.visible_instance_count, 60, "all white with none glowing")
	assert_false(draws[1].visible or draws[2].visible, "the glow's draws hidden")
	view.free()


func test_customise_offers_the_choice_beside_bb_weight_per_replica() -> void:
	SaveFile.remove(SAVE_PATH)
	var saved := SavedLoadouts.new(rules)
	var page := LoadoutPage.new(saved, Settings.new())
	page.save_path = SAVE_PATH
	page.settings_path = "user://test_glow_bbs_settings.save"
	add_child_autofree(page)
	page.show_customise(0)
	var view := page.customise()
	view.show_tab(CustomiseView.Tab.BBS)
	var choice := view.glow_choice()
	assert_eq(choice.get_parent().get_parent(), view.weight_slider().get_parent(), "in the BB weight's column")
	assert_eq(choice.selected(), Loadout.Glow.NIGHT, "At Night picked")
	assert_eq(choice.button(0).text, "AT NIGHT")
	assert_eq(view.glow_blurb(), tr("CUSTOMISE_GLOW_NIGHT_BLURB"))
	assert_eq(choice.button(1).tooltip_text, view.glow_blurb(), "its words are the choice's tooltip (UI1)")
	choice.button(Loadout.Glow.ALWAYS).pressed.emit()
	var primary := saved.carried().replica_id(Loadout.Slot.PRIMARY)
	assert_eq(saved.carried().glow_of(primary), Loadout.Glow.ALWAYS)
	assert_true(saved.dirty)
	assert_eq(view.glow_blurb(), tr("CUSTOMISE_GLOW_ALWAYS_BLURB"))
	page.show_gear()
	page.show_customise(1)
	assert_eq(view.glow_choice().selected(), Loadout.Glow.NIGHT, "the secondary keeps its own")
	page.close()
	var back := SavedLoadouts.new(rules)
	back.load_file(SAVE_PATH)
	assert_eq(back.carried().glow_of(primary), Loadout.Glow.ALWAYS, "saved on leaving")
	await wait_process_frames(2)
	SaveFile.remove(SAVE_PATH)
	SaveFile.remove("user://test_glow_bbs_settings.save")


func test_a_seeded_match_plays_the_same_with_every_choice() -> void:
	var depot := MatchRunner.new(self, "depot")
	var tallies: Array[MatchRunner.MatchTally] = []
	var drawn: Array[int] = []
	for choice: Loadout.Glow in [Loadout.Glow.OFF, Loadout.Glow.ALWAYS, Loadout.Glow.NIGHT]:
		var view := BBView.new()
		add_child(view)
		var count := [0]
		var choices: Array[Loadout.Glow] = [choice, choice]
		# Every character loads `choice`, drawn every tick as on a night field (At Night glows too), from the first
		# character's place.
		depot.each_tick = func(state: GameState, _bots: BotController) -> void:
			if view.multimesh == null:
				view.setup(EffectsConfig.new(), state.bbs.bbs.size())
				var bits := PackedByteArray()
				bits.resize(state.characters.size())
				bits.fill(BBView.glow_bits(choices, true))
				view.set_glowing(bits)
			view.update(state.bbs, -1, Vector3.ZERO, 1.0, PlaySession.TICK, state.characters[0].position)
			count[0] += view.draws()[1].multimesh.visible_instance_count
		tallies.append(depot.play(MATCH_SEED, MATCH_SECONDS))
		depot.each_tick = Callable()
		drawn.append(count[0])
		view.free()
	depot.free_level()
	assert_eq(drawn[0], 0, "Off: every BB white")
	assert_gt(drawn[1], 0, "Always: BBs glowed")
	assert_gt(drawn[2], 0, "At Night on a night field: BBs glowed")
	var off := tallies[0]
	gut.p("%d ticks, %d hits, %d glowing BB frames" % [off.ticks, off.hits, drawn[1]])
	assert_gt(off.hits, 0, "shots were fired and landed")
	for t in tallies:
		assert_eq([t.ticks, t.hits, t.rounds.size()], [off.ticks, off.hits, off.rounds.size()],
				"the same match, tick for tick")
		assert_eq(t.hits_by, off.hits_by, "the same hits")
		assert_eq(t.farthest, off.farthest, "everyone as far from their spawn")


func test_a_match_glows_your_bbs_by_your_kit_and_the_bots_by_the_field() -> void:
	var l := rules.default_loadout("A")
	l.set_glow(l.replica_id(Loadout.Slot.PRIMARY), Loadout.Glow.ALWAYS)
	var session := PlaySession.new()
	session.settings = Settings.new()
	session.kit = rules.carried(l)
	session.bots_active = false
	add_child_autofree(session)
	var frames := 0
	while frames < 400 and session.ticks() < 1:
		await wait_physics_frames(1)
		frames += 1
	assert_false(session.lighting().night, "Depot by day")
	var bits := session._bbs._glowing
	assert_eq(bits.size(), session.state.characters.size())
	assert_eq(bits[PlaySession.PLAYER_ID], 1, "your primary's BBs glow by day; your secondary's, At Night, don't")
	for c in session.state.characters:
		if c.id != PlaySession.PLAYER_ID:
			assert_eq(bits[c.id], 0, "a bot's BBs are white by day")


func _view(cfg: EffectsConfig) -> BBView:
	var view := BBView.new()
	view.setup(cfg, 64)
	# characters 0 and 1 glow on both slots, character 2 on neither
	view.set_glowing(PackedByteArray([3, 3, 0]))
	return view


## A BB of `owner` from `slot`, `age` s into its flight, RANGE m ahead of the eye and flying across the view (+x).
func _fire(pool: BBPool, owner: int, slot: int, age: float) -> void:
	var bb := pool.spawn(owner, Vector3(0.0, 0.0, -RANGE), Vector3.RIGHT, SPEED, 0.0, 0.0002, 0.0, slot)
	bb.age = age
