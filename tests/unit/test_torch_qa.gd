extends GutTest
## WL7 QA: the weapon torch at the seams the worker's own tests leave: the dead can't switch it, a saved torch tagged
## dev with Dev content off (public since 2026-10-29, so tagged by DevContent), the kit a match really builds by day and
## by night (player, bots, dev flag), the watched player's torch when spectating, the preset changing mid-match, and
## the torch's draws and light freed with the session.

const DT := 1.0 / 60.0
const AEG := "000002"
const TORCH := "000020"

var tuning: SimTuning = SimTuning.load_default()
var stats: ReplicaStats = ReplicaStats.read_file()


func _light() -> Torch.Light:
	return Torch.Light.of(&"weaponTorch", stats.parts.part(&"light", &"weaponTorch"))


func _rules(dev: bool) -> LoadoutRules:
	var r := LoadoutRules.standard()
	r.dev_content = dev
	return r


func _kit_with_torch() -> Kit:
	var rules := _rules(true)
	var l := rules.default_loadout("Night")
	rules.set_part(l, AEG, &"light", TORCH)
	return rules.carried(l)


func _settings(dev: bool) -> Settings:
	var s := Settings.new()
	s.dev.dev_content = dev
	return s


func _session(map_id: String, s: Settings, kit: Kit = null) -> PlaySession:
	var session := PlaySession.new()
	session.map_id = map_id
	# Woodland by night (its second preset since WR1); a map with one preset plays that.
	session.lighting_pick = LightingConfig.NIGHT
	session.settings = s
	session.kit = kit
	session.bots_active = false
	add_child_autofree(session)
	return session


func _lights_of(session: PlaySession, node_class: String) -> int:
	return session.find_children("*", node_class, true, false).size()


# --- the sim ---

func test_the_event_for_the_torch_was_appended_and_no_older_id_moved() -> void:
	assert_eq(GameEvent.Kind.OVERTIME, GameEvent.Kind.TORCH + 1, "appended: only the overtime flag's (OV1) after it")
	assert_eq(GameEvent.Kind.TORCH, GameEvent.Kind.BB_LEAVES + 1, "straight after the leaves")
	assert_eq(GameEvent.Kind.BB_LEAVES, GameEvent.Kind.PROP_RING + 1, "nothing before it shifted")


func test_a_player_who_is_out_cannot_switch_it_back_on() -> void:
	var w := BoxWorld.new(tuning.body)
	w.add_floor(200.0, 200.0)
	var ends: Array[MapEnd] = []
	for e in 2:
		var end := MapEnd.new()
		end.spawns.append(SpawnPoint.new(Vector3(-60.0 if e == 0 else 60.0, 0.0, 0.0), 0.0))
		end.dead_zone.append(SpawnPoint.new(Vector3(-70.0 if e == 0 else 70.0, 0.0, 40.0), 0.0))
		ends.append(end)
	var sim := Simulation.new(tuning, w, w.mover(), ends, -10.0)
	var state := GameState.new(3, tuning)
	var cmds: Array[PlayerCommand] = []
	for i in 2:
		var c := Character.new(i, i, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
		c.armament.lights = [_light(), null]
		state.characters.append(c)
		cmds.append(PlayerCommand.new())
	sim.start_match(state)
	for i in 5:
		sim.step(state, cmds, DT)
	var me := state.characters[0]
	Elimination.eliminate(me, 1, state.characters, ends)
	var clicks := 0
	for i in 600:
		if Elimination.is_in_play(me):
			break  # the round ended and a new one began: in play again, as it should be
		for k in cmds.size():
			cmds[k].reset(state.characters[k].yaw, state.characters[k].pitch)
		cmds[0].toggle_torch = true
		sim.step(state, cmds, DT)
		clicks += state.events.count_of(GameEvent.Kind.TORCH)
		assert_false(me.torch_on, "tick %d: hit, walking off or parked: no torch" % i)
		if me.torch_on:
			return
	assert_eq(clicks, 0, "no click for the dead")


# --- saves and dev content ---

func test_a_saved_dev_torch_with_dev_content_off_is_not_carried_and_marks_nothing() -> void:
	var was := DevContent.use_item(TORCH)
	var on := _rules(true)
	var l := on.default_loadout("Night")
	on.set_part(l, AEG, &"light", TORCH)
	var off := _rules(false)
	var kit := off.carried(l)
	for slot in kit.lights.size():
		assert_null(kit.lights[slot], "slot %d: a dev torch is not fitted without Dev content" % slot)
	assert_false(kit.light_dev)
	assert_false(kit.dev_under(true), "a normal player's night match stays on the record")
	assert_false(kit.parts[0].has(&"light"))
	DevContent.restore_item(was)


func test_a_torch_saved_for_a_replica_it_no_longer_fits_is_cleaned_not_fatal() -> void:
	var rules := _rules(true)
	var l := rules.default_loadout("Odd")
	rules.set_part(l, AEG, &"light", TORCH)
	rules.tune_of(l, AEG).parts[&"light"] = "000007"
	var problems := rules.clean(l)
	assert_eq(problems.size(), 1, "a red dot is no light: listed and dropped")
	assert_false(rules.tune_of(l, AEG).parts.has(&"light"))


# --- the match a session builds ---

func test_by_day_a_torch_in_the_kit_is_not_fitted_and_the_match_is_not_dev() -> void:
	var session := _session("depot", _settings(true), _kit_with_torch())
	assert_false(session.lighting().night, "Depot is a day map")
	assert_null(session.player.armament.light_in_hand())
	assert_true(session.player.armament.lights.is_empty())
	for c in session.state.characters:
		assert_true(c.armament.lights.is_empty(), "nobody carries a light by day (%d)" % c.id)
	assert_false(session.state.dev_content, "the torch alone doesn't make a day match dev")
	assert_null(session.find_child("TorchBeams", true, false), "nothing drawn by day")


func test_at_night_your_torch_and_every_bots_are_fitted_and_the_match_stays_on_the_record() -> void:
	var session := _session("woodland", _settings(true), _kit_with_torch())
	assert_true(session.lighting().night)
	assert_not_null(session.player.armament.lights[0], "your rifle's torch")
	assert_null(session.player.armament.lights[1], "the pistol has none fitted")
	assert_false(session.state.dev_content, "Woodland and the torch are public")
	var bots := 0
	for c in session.state.characters:
		if c == session.player:
			continue
		bots += 1
		assert_gt(c.armament.lights.size(), 0, "bot %d" % c.id)
		for l in c.armament.lights:
			assert_not_null(l, "bot %d carries one on each replica" % c.id)
	assert_gt(bots, 0)
	assert_not_null(session.find_child("TorchBeams", true, false))


func test_a_dev_torch_marks_a_night_match_dev_and_without_dev_content_nobody_has_one() -> void:
	var was := DevContent.use_item(TORCH)
	var on := _session("woodland", _settings(true), _kit_with_torch())
	var off := _session("woodland", _settings(false))
	DevContent.restore_item(was)
	assert_true(on.state.dev_content, "a dev torch at night: off the record")
	for c in off.state.characters:
		assert_true(c.armament.lights.is_empty() or c.armament.lights.all(func(l: Torch.Light) -> bool: return l == null),
				"%d" % c.id)


func test_a_night_match_without_dev_content_gives_every_bot_the_torch() -> void:
	var session := _session("woodland", _settings(false))
	assert_false(session.state.dev_content)
	for c in session.state.characters:
		if c != session.player:
			assert_true(c.armament.lights.any(func(l: Torch.Light) -> bool: return l != null), "bot %d" % c.id)


# --- drawing it ---

func test_spectating_shows_the_watched_bots_torch_not_yours() -> void:
	var session := _session("woodland", _settings(true), _kit_with_torch())
	session._apply_graphics(GraphicsTable.shared().preset(&"high"))
	var spot := session._eyes.torch()
	assert_not_null(spot)
	var bot: Character = null
	for c in session.state.characters:
		if c != session.player:
			bot = c
			break
	session.player.torch_on = true
	await wait_process_frames(2)
	assert_true(spot.visible, "your own torch, watched through your own eyes")
	session.player.torch_on = false
	Elimination.eliminate(session.player, bot.id, session.state.characters, session._sim.ends)
	session._spectate_any = true
	session._watch_id = bot.id
	bot.torch_on = true
	await wait_process_frames(2)
	assert_eq(session.spectated(), bot)
	assert_true(spot.visible, "through the bot's eyes its torch is the spot")
	bot.torch_on = false
	await wait_process_frames(2)
	assert_false(spot.visible, "and out when it goes out")


func test_changing_presets_mid_match_leaves_one_spot_or_none_and_no_beam_stacks() -> void:
	var session := _session("woodland", _settings(true), _kit_with_torch())
	var beams := session.find_child("TorchBeams", true, false) as TorchBeams
	assert_eq(session.find_children("*", "TorchBeams", true, false).size(), 1)
	for preset: StringName in [&"low", &"high", &"medium", &"ultra", &"low", &"high", &"low"]:
		session._apply_graphics(GraphicsTable.shared().preset(preset))
		await get_tree().process_frame
		var want := 0 if preset == &"low" else 1
		assert_eq(_lights_of(session, "SpotLight3D"), want, "the view's spot after %s" % preset)
		var spot := session._eyes.torch()
		if spot != null:
			assert_eq(spot.shadow_enabled, preset in [&"high", &"ultra"], String(preset))
	assert_eq(session.find_children("*", "TorchBeams", true, false).size(), 1)
	assert_eq(session.find_child("TorchBeams", true, false), beams, "the one made at the start")


func test_a_rematch_frees_the_torch_draws_and_their_light() -> void:
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var orphans := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	for round_n in 2:
		var session := _session("woodland", _settings(true), _kit_with_torch())
		session._apply_graphics(GraphicsTable.shared().preset(&"high"))
		session.player.torch_on = true
		await wait_process_frames(2)
		session.free()
		await get_tree().process_frame
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes, "no node left over")
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), orphans, "no orphan")
