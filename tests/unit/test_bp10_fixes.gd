extends GutTest
## The 0.1 Beta 2 pass's fixes (BP10): a round won while you wait to come back is won with you, in your XP and in the
## scoreboard's count; the loadout card menu opens where the card was right-clicked and keeps the keyboard's card when it
## carries another loadout; "You have the bomb" is not told again when a plant is let go of; Subway's announcements are
## the player's own, never over the results, and a new match cuts one still playing.

const LOADOUTS := "user://test_bp10_loadouts.save"
const SETTINGS := "user://test_bp10_settings.save"
const STEP := 0.25

var loadout: Array[ReplicaConfig] = ReplicaStats.default_loadout()


func after_each() -> void:
	await wait_process_frames(2)
	SaveFile.remove(LOADOUTS)
	SaveFile.remove(SETTINGS)


func _events(state: GameState, list: Array) -> void:
	state.events.clear()
	for spec: Array in list:
		var e := state.events.add(spec[0])
		e.actor = spec[1]
		e.target = spec[2]
		e.value = spec[3]
		e.value2 = spec[4] if spec.size() > 4 else 0


## You (id 0, team 0) and an opponent; you were hit, hit nobody, and wait `wait` s to come back (-1: one life).
func _hit_you(wait: float) -> GameState:
	var state := GameState.new(1)
	var me := Character.new(0, 0, Vector3.ZERO, 0.0, loadout)
	var them := Character.new(1, 1, Vector3.ZERO, 0.0, loadout)
	state.characters.append_array([me, them])
	me.status = Character.Status.OUT
	me.respawn_left = wait
	return state


func test_a_round_won_while_you_wait_to_come_back_is_won_with_you() -> void:
	for wait: float in [4.0, -1.0]:
		var state := _hit_you(wait)
		var tally := PlayerTally.new(0)
		var stats := MatchStats.new()
		_events(state, [[GameEvent.Kind.ROUND_START, -1, -1, 1]])
		tally.on_tick(state)
		stats.after_tick(state, 1.0 / 60.0)
		_events(state, [[GameEvent.Kind.ROUND_OVER, -1, -1, 0, GameEvent.RoundEnd.TIME]])
		tally.on_tick(state)
		stats.after_tick(state, 1.0 / 60.0)
		var expected := 1 if wait >= 0.0 else 0
		assert_eq(tally.rounds_won, expected, "Round won with a wait of %s s" % wait)
		assert_eq(stats.rounds_won_with(0), expected, "the scoreboard's count with a wait of %s s" % wait)


func _strip() -> LoadoutStrip:
	SaveFile.remove(LOADOUTS)
	SaveFile.remove(SETTINGS)
	var saved := SavedLoadouts.new(LoadoutRules.standard())
	var page := LoadoutPage.new(saved, Settings.new())
	page.save_path = LOADOUTS
	page.settings_path = SETTINGS
	add_child_autofree(page)
	var strip := page.strip()
	strip.new_card().pressed.emit()
	strip.new_card().pressed.emit()
	saved.use(0)
	return strip


func test_the_card_menu_opens_at_the_card_clicked_when_it_carries_another_loadout() -> void:
	var strip := _strip()
	await wait_process_frames(2)
	var card := strip.card(2)
	var at := Vector2(10.0, 10.0)
	var expected := Vector2i((card.get_screen_position() + at * card.get_global_transform_with_canvas().get_scale())
			.round())
	assert_gt(card.get_screen_position().x, strip.card(0).get_screen_position().x + 1.0, "the third card stands right")
	strip.open_menu(2, at)
	assert_eq(strip.saved.current, 2, "it carries the card clicked")
	assert_eq(strip.menu().position, expected, "the menu stands where the card was clicked, not under the first card")
	strip.menu().hide()


func test_the_keyboard_keeps_the_card_whose_menu_it_opened() -> void:
	var strip := _strip()
	await wait_process_frames(2)
	strip.card(1).grab_focus()
	strip.open_menu(1)
	assert_true(strip.card(1).has_focus(), "the rebuilt card has the keys")
	strip.pick(LoadoutStrip.MenuItem.DUPLICATE)
	assert_true(strip.card(strip.saved.current).has_focus(), "a copy keeps them on the carried card")
	strip.menu().hide()


func test_letting_go_of_a_plant_does_not_tell_you_again_that_you_have_the_bomb() -> void:
	var p := HudPlantPrompt.new(2.5)
	add_child_autofree(p)
	p.show_for(HudPlant.Prompt.NONE, true, 0.0, true)
	assert_true(p._quiet.visible, "picked up: the quiet line")
	p.show_for(HudPlant.Prompt.NONE, false, 1.0, true)
	assert_false(p._quiet.visible, "setting it down: the gauge says so")
	p.show_for(HudPlant.Prompt.NONE, true, 2.0, true)
	assert_false(p._quiet.visible, "let go of the plant 3 s after the pick-up: its time is up, not started again")
	p.show_for(HudPlant.Prompt.NONE, false, 1.0, false)
	p.show_for(HudPlant.Prompt.NONE, true, 0.0, true)
	assert_true(p._quiet.visible, "dropped and picked up again: told again")


func _subway_audio() -> Array:
	var tuning := load("res://game/config/play_tuning.tres") as PlayTuning
	var subway := MapData.load_map("subway", MapStyle.new(), 1)
	var audio := SimAudio.new()
	add_child_autofree(audio)
	audio.setup(tuning.sound, [] as Array[StringName], BodyConfig.new(), null, subway)
	var state := GameState.new(3)
	state.match_number = 1
	var inside := subway.trains[0].cars[0].middle
	state.characters.append(Character.new(0, 0, inside))
	state.characters.append(Character.new(1, 1, inside))
	return [audio, state, tuning.sound.train_announcements]


## Ticks `audio` from `from` s for `seconds` with `listener`'s ears: whether anything started.
func _played(audio: SimAudio, state: GameState, listener: Character, from: float, seconds: float) -> bool:
	for k in int(seconds / STEP):
		state.time = from + k * STEP
		audio.on_tick(state, 0, listener)
		if audio._announcer.playing:
			return true
	return false


func test_subway_announcements_are_the_players_own_and_never_over_the_results() -> void:
	var made := _subway_audio()
	var audio: SimAudio = made[0]
	var state: GameState = made[1]
	var cfg: TrainAnnounceConfig = made[2]
	var span := cfg.once_max + 2.0 * STEP
	assert_false(_played(audio, state, state.characters[1], 0.0, span), "watching a bot in a train: nothing")
	state.round_state.phase = RoundState.Phase.MATCH_OVER
	assert_false(_played(audio, state, state.characters[0], span, span), "under the results: nothing")
	state.round_state.phase = RoundState.Phase.LIVE
	assert_true(_played(audio, state, state.characters[0], 2.0 * span, span), "in play in a train: it plays")
	state.match_number = 2
	state.time += STEP
	audio.on_tick(state, 0, null)
	assert_false(audio._announcer.playing, "a new match cuts it")


func test_the_bots_level_scales_the_defenders_wait_and_nothing_else() -> void:
	var base := MatchOptions.match_tuning(SimTuning.load_default(), MapCatalog.shared().find("depot"), null)
	var field := base.rounds.defender_respawn_delay
	assert_same(MatchOptions.level_tuning(base, &"normal"), base, "Normal plays the field's wait, the tuning shared")
	for level: StringName in [&"easy", &"hard"]:
		var scale: float = base.rounds.defender_respawn_scale[level]
		assert_ne(scale, 1.0, "%s has a scale of its own" % level)
		var played := MatchOptions.level_tuning(base, level)
		assert_almost_eq(played.rounds.defender_respawn_delay, minf(field * scale, base.rounds.defender_respawn_most), 0.001,
				String(level))
		assert_eq(played.rounds.respawn_delay, base.rounds.respawn_delay, "%s: the attackers' wait kept" % level)
		assert_eq(played.rounds.plant_defender_respawn_delay, base.rounds.plant_defender_respawn_delay,
				"%s: Plant The Bomb's kept" % level)
	assert_eq(base.rounds.defender_respawn_delay, field, "the field's tuning is never written")
	assert_same(MatchOptions.level_tuning(base, &"unknown"), base, "a level with no scale waits the field's")


func test_a_levels_wait_stops_at_the_ceiling_unless_the_fields_own_is_longer() -> void:
	var base := MatchOptions.match_tuning(SimTuning.load_default(), MapCatalog.shared().find("depot"), null)
	var most := base.rounds.defender_respawn_most
	assert_gt(base.rounds.defender_respawn_delay * base.rounds.defender_respawn_scale[&"hard"], most, "Depot on Hard")
	assert_eq(MatchOptions.level_tuning(base, &"hard").rounds.defender_respawn_delay, most, "Depot's Hard wait is the ceiling")
	var long := base.duplicate() as SimTuning
	long.rounds = base.rounds.duplicate() as RoundConfig
	long.rounds.defender_respawn_delay = most + 5.0
	assert_eq(MatchOptions.level_tuning(long, &"hard").rounds.defender_respawn_delay, most + 5.0,
			"a field longer than the ceiling keeps its own")
	assert_almost_eq(MatchOptions.level_tuning(long, &"easy").rounds.defender_respawn_delay, (most + 5.0) * 0.75, 0.001,
			"Easy still shortens it")
