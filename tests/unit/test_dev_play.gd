extends GutTest
## The Dev settings in a match on Depot (game/play/play_session.gd): game speed slows the fixed tick, bots hold fire,
## Spectate any bot follows a bot while you stand still, the bot intention labels and Retro filter are built only while
## on and freed once off, End the round now from the pause menu, the record mark, and a dev map counted as dev content.

var session: PlaySession = null
var s: Settings = null


func before_each() -> void:
	s = Settings.new(PlayTuning.new())


func after_each() -> void:
	get_tree().paused = false


func _play(map_id: String = "depot", autopilot: bool = true) -> void:
	session = PlaySession.new()
	session.settings = s
	session.map_id = map_id
	session.autopilot = autopilot
	add_child_autofree(session)
	await wait_physics_frames(2)


func test_nothing_on_plays_on_the_record() -> void:
	await _play()
	assert_false(session.state.off_record)
	assert_false(session.state.dev_content)
	assert_eq(session.find_children("*", "BotIntentView", true, false).size(), 0)
	assert_eq(session.find_children("*", "RetroFilter", true, false).size(), 0)


func test_game_speed_runs_fewer_fixed_ticks() -> void:
	s.dev.game_speed = 0.5
	await _play()
	assert_true(session.state.off_record)
	var before := session.ticks()
	var t0 := session.state.time
	await wait_physics_frames(40)
	var ran := session.ticks() - before
	assert_between(ran, 19, 21, "half the physics ticks")
	assert_almost_eq(session.state.time - t0, ran / 60.0, 1e-6, "each still a 60 Hz tick")


func test_bots_hold_fire_and_nobody_shoots() -> void:
	s.dev.bots_hold_fire = true
	await _play("depot", false)
	await wait_physics_frames(600)
	assert_eq(session.all_shots, 0)
	s.dev.bots_hold_fire = false
	s.mark_changed()
	assert_false(session.state.cheats.bots_hold_fire, "follows the settings while playing")


func test_changes_while_playing_reach_the_match_and_off_turns_them_off() -> void:
	await _play()
	s.dev.ghost = true
	s.dev.bottomless = true
	s.mark_changed()
	assert_true(session.player.ghost)
	assert_true(session.player.armament.bottomless)
	s.dev.ghost = false
	s.dev.bottomless = false
	s.mark_changed()
	assert_false(session.player.ghost)
	assert_false(session.player.armament.bottomless)
	assert_true(session.state.off_record, "the match stays off the record")


func test_spectate_any_bot_follows_a_bot_while_you_stand_still() -> void:
	s.dev.spectate_bots = true
	await _play("depot", false)
	var you := session.player
	var start := you.position
	var watched := session.spectated()
	assert_ne(watched, you)
	assert_true(Elimination.is_in_play(watched))
	await wait_process_frames(1)
	assert_false(session._hands.visible, "your replica is not in a bot's view")
	Input.action_press(&"move_forward")
	await wait_physics_frames(30)
	Input.action_release(&"move_forward")
	assert_lt(you.position.distance_to(start), 0.05, "you stand still")
	var first := session.spectated().id
	Input.action_press(&"fire")
	await wait_physics_frames(2)
	Input.action_release(&"fire")
	await wait_physics_frames(2)
	assert_ne(session.spectated().id, first, "a pull moves on to the next bot")
	assert_eq(session.shots, 0, "and fires nothing")


func test_bot_intentions_are_built_while_on_and_freed_once_off() -> void:
	s.dev.bot_intent = true
	await _play()
	var views := session.find_children("*", "BotIntentView", true, false)
	assert_eq(views.size(), 1)
	await wait_process_frames(2)
	var labels := views[0].find_children("*", "Label3D", true, false)
	assert_eq(labels.size(), session.state.characters.size() - 1, "one over every bot, none over you")
	assert_ne((labels[0] as Label3D).text, "", "says what it is doing")
	assert_false((labels[0] as Label3D).no_depth_test, "hidden by walls (BP6)")
	# BP6: under the see-through wheel and field map and a raised sight's glass they would show through
	var you := session.player
	assert_false(session.intents_covered(you), "nothing over them at the hip")
	you.aim_raise = 1.0
	assert_true(session.intents_covered(you), "a raised sight")
	you.aim_raise = 0.0
	session._input.field_map().open = true
	assert_true(session.intents_covered(you), "the field map")
	session._input.field_map().open = false
	s.dev.bot_intent = false
	s.mark_changed()
	await wait_process_frames(1)
	assert_eq(session.find_children("*", "BotIntentView", true, false).size(), 0)


func test_retro_filter_is_built_while_on_and_freed_once_off() -> void:
	s.dev.retro_filter = true
	await _play()
	var retro: Array[Node] = session.find_children("*", "RetroFilter", true, false)
	assert_eq(retro.size(), 1)
	assert_false(session.state.off_record, "a look only")
	var filter := retro[0] as RetroFilter
	assert_gt(filter.snap().x, 0.0, "RF1: the field's corners snap while it is on")
	assert_eq(filter.snap().z, RetroFilter.AFFINE)
	var env := session._lighting.environment
	assert_true(env.fog_enabled, "RF1: its haze on")
	assert_eq(env.fog_depth_end, RetroFilter.HAZE_TO)
	# BP6: the Dev tab's sliders reach the shader while it is up
	s.dev.retro_lines = 120
	s.dev.retro_levels = 3
	s.mark_changed()
	await wait_process_frames(1)
	var mat := (filter.get_child(0) as ColorRect).material as ShaderMaterial
	var height := session.get_viewport().get_visible_rect().size.y
	assert_eq(float(mat.get_shader_parameter(&"pixel_size")), float(RetroFilter.pixel_size(height, 120)))
	assert_eq(float(mat.get_shader_parameter(&"levels")), float(RetroFilter.LEVELS_MIN), "held to its end")
	s.dev.retro_filter = false
	s.mark_changed()
	# Out of the tree at once, its look off before it is freed.
	assert_eq(session.find_children("*", "RetroFilter", true, false).size(), 0)
	assert_eq(filter.snap(), Vector4.ZERO, "the corners true again once off")
	assert_true(env.fog_enabled, "Depot by day: the site sky's haze back (SiteDress.dress_sky)")
	assert_eq(env.fog_depth_begin, session._play.site_look.haze_from)
	assert_almost_eq(env.fog_density, session._play.site_look.haze_density, 0.0001)
	await wait_process_frames(1)
	assert_false(is_instance_valid(filter), "freed")


func test_end_the_round_from_the_pause_menu() -> void:
	await _play()
	var pause: PauseMenu = session.find_children("*", "PauseMenu", true, false)[0]
	assert_true(pause.end_round.is_valid())
	assert_true(pause.end_round.call())
	await wait_physics_frames(2)
	assert_false(session.state.round_state.is_live(), "the round is over")
	assert_eq(session.state.round_state.reason, GameEvent.RoundEnd.TIME)
	assert_true(session.state.off_record)
	pause.open_settings()
	assert_false(pause._screen._end_round.disabled, "the Dev tab's button reaches the match")


func test_a_dev_map_counts_as_dev_content() -> void:
	var was := DevContent.use_map("depot")
	await _play("depot")
	DevContent.restore_map(was)
	assert_true(session.state.dev_content)
	assert_true(session.state.off_record)
	await wait_physics_frames(30)
	assert_gt(session.ticks(), 20, "and plays")


func test_leaving_lets_go_of_the_settings() -> void:
	await _play()
	assert_true(s.changed.is_connected(session._apply_dev))
	var apply := session._apply_dev
	session.free()
	assert_false(s.changed.is_connected(apply))
