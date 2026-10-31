extends GutTest
## The magazine hand-off on H, the order wheel and the screen (MH3; concepts `step27/wheel-need-a-mag.png` and
## `step27/mag-hand-off.png`): Need a Mag's key and the wheel's fifth item (each pressing mag_hand_off once, dead on the
## range and while you are out), Toss a Mag in reach, a refusal in the wheel's middle or on the line, the line's words
## (who needs one and how far, underlined in reach; whose is coming; what you caught; why not, for 2.5 s), hidden under
## the open wheel and with Settings › HUD › Mag hand-off off, the glyph by the chevron, the screen reader's messages, the
## sounds, the magazine in the air (its pool, arc and spin), the setting saved, and the match marking you as the player
## (your ask gap is the player's 4 s). Headless, on a BoxWorld floor with the default loadout.

const DT := 1.0 / 60.0
const SAVE := "user://mh3-test.save"
const NAMES := ["", "Rook", "Brick", "Fox"]
const YOU := 0
const ROOK := 1
const BRICK := 2
## The order wheel's pointer on its last item, Need a Mag, upper left (288 degrees clockwise from the top).
const UPPER_LEFT := Vector2(-80.0, -26.0)

var tuning := SimTuning.new()
var loadout: Array[ReplicaConfig] = []
var controls := ControlsConfig.new()
var world: BoxWorld = null
var sim: Simulation = null
var state: GameState = null
var cmds: Array[PlayerCommand] = []
var hud: Hud = null
var wheel: OrderWheelPointer = null
var outcome := SquadOrders.Outcome.new()
var input: PlayerInput = null
var cmd := PlayerCommand.new()


func before_all() -> void:
	loadout = ReplicaStats.default_loadout()


func before_each() -> void:
	controls = ControlsConfig.new()
	wheel = OrderWheelPointer.new(controls.wheel_reach, controls.wheel_dead_zone, controls.wheel_orders.size())
	outcome = SquadOrders.Outcome.new()
	input = null


func after_each() -> void:
	for action: StringName in [&"mag_hand_off", &"order_wheel", &"fire"]:
		Input.action_release(action)
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)


# --- helpers ---

## You (0), Rook (1) 4 m off, Brick (2) 8 m off on your team, Fox (3) far off on the other; round 1 live; a HUD with
## the wheel, the line and the markers.
func _match() -> void:
	var w := BoxWorld.new(tuning.body)
	w.add_floor(60.0, 30.0)
	world = w
	var ends: Array[MapEnd] = []
	for e in 2:
		var end := MapEnd.new()
		for i in 3:
			end.spawns.append(SpawnPoint.new(Vector3(-10.0 if e == 0 else 10.0, 0.0, i * 2.0), 0.0))
			end.dead_zone.append(SpawnPoint.new(Vector3(-25.0 if e == 0 else 25.0, 0.0, 10.0), 0.0))
		ends.append(end)
	sim = Simulation.new(tuning, w, w.mover(), ends, -10.0)
	state = GameState.new(5, tuning)
	for i in 4:
		state.characters.append(Character.new(i, 0 if i < 3 else 1, Vector3.ZERO, 0.0, loadout))
	sim.start_match(state)
	var spots: Array[Vector3] = [Vector3.ZERO, Vector3(4.0, 0.0, 0.0), Vector3(0.0, 0.0, 8.0),
			Vector3(25.0, 0.0, -10.0)]
	for c in state.characters:
		c.position = spots[c.id] + Vector3(0.0, c.position.y, 0.0)
		c.prev_position = c.position
	cmds.clear()
	for c in state.characters:
		var k := PlayerCommand.new()
		k.reset(c.yaw, c.pitch)
		cmds.append(k)
	var frame := Control.new()
	frame.size = get_viewport().get_visible_rect().size
	add_child_autofree(frame)
	hud = Hud.new()
	frame.add_child(hud)
	hud.setup(HudConfig.new(), TeamConfig.new(), ViewConfig.new(), tuning, state.characters[YOU])
	hud.setup_orders(controls)
	hud.setup_mag_line(sim.mag_share, state.characters.size())
	hud.setup_field(w, tuning.body, PackedStringArray(NAMES), state.characters, null)


## One tick with `pressing` pressing the hand-off; the HUD reads it (`from_wheel`: your press was picked on the wheel)
## and draws a frame with the wheel as it is.
func _tick(pressing: Array = [], from_wheel: bool = false) -> void:
	for k in cmds:
		k.mag_hand_off = false
	for id: int in pressing:
		cmds[id].mag_hand_off = true
	sim.step(state, cmds, DT)
	hud.on_tick(state, from_wheel)
	hud.update_orders(wheel, SquadOrder.Kind.NONE, outcome, DT)


func _ticks(n: int) -> void:
	for i in n:
		_tick()


static func _last_mag(c: Character) -> void:
	c.armament.ammo[0].pouch.fill(0)


func _line() -> HudMagLine:
	return hud.mag_line()


func _make_input() -> PlayerInput:
	input = PlayerInput.new()
	input.setup(controls, 1.5)
	add_child_autofree(input)
	input.active = true
	return input


func _event(action: StringName, pressed: bool) -> void:
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)
	var e := InputEventAction.new()
	e.action = action
	e.pressed = pressed
	input._unhandled_input(e)


func _move(at: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.screen_relative = at / (controls.wheel_gain * controls.sensitivity)
	input._unhandled_input(e)


# --- criterion 1: H and the wheel ---

func test_need_a_mag_is_on_h_rebindable_and_named_squad_need_a_mag() -> void:
	assert_has(KeyBindings.ACTIONS, &"mag_hand_off", "on the Controls list, so rebindable")
	assert_eq(KeyBindings.DEFAULTS[&"mag_hand_off"], [KEY_H])
	var keys := InputMap.action_get_events(&"mag_hand_off")
	assert_eq(keys.size(), 1)
	assert_eq((keys[0] as InputEventKey).physical_keycode, KEY_H, "project.godot's input map agrees")
	assert_eq(tr(KeyBindingList.label_key(&"mag_hand_off")), "SQUAD: NEED A MAG")


func test_h_presses_the_hand_off_once() -> void:
	_make_input()
	_event(&"mag_hand_off", true)
	input.fill(cmd)
	assert_true(cmd.mag_hand_off)
	assert_eq(cmd.squad_order, SquadOrder.Kind.NONE, "no squad order")
	assert_false(input.mag_from_wheel)
	input.fill(cmd)
	assert_false(cmd.mag_hand_off, "once a press")
	_event(&"mag_hand_off", false)


func test_h_is_dead_on_the_range_and_while_you_are_out() -> void:
	_make_input()
	input.allow_orders(false, false)
	_event(&"mag_hand_off", true)
	input.fill(cmd)
	assert_false(cmd.mag_hand_off, "the range")
	_event(&"mag_hand_off", false)
	input.allow_orders(true, false)
	_event(&"mag_hand_off", true)
	input.fill(cmd)
	assert_false(cmd.mag_hand_off, "out")
	_event(&"mag_hand_off", false)
	input.allow_orders(true, true)
	_event(&"mag_hand_off", true)
	input.allow_orders(true, false)
	input.fill(cmd)
	assert_false(cmd.mag_hand_off, "a press made just before going out is dropped")


func test_the_wheels_fifth_item_upper_left_does_what_h_does() -> void:
	assert_eq(controls.wheel_orders.size(), 6, "Go There (FM1) made it six")
	assert_eq(controls.wheel_orders[5], SquadOrder.Kind.MAG)
	assert_eq(controls.wheel_keys[5], &"mag_hand_off")
	assert_eq(OrderWheelPointer.slice(UPPER_LEFT, 6, controls.wheel_dead_zone), 5, "upper left")
	for pick: ControlsConfig.WheelPick in [ControlsConfig.WheelPick.HOVER, ControlsConfig.WheelPick.CLICK]:
		controls.wheel_pick = pick
		_make_input()
		_event(&"order_wheel", true)
		_move(UPPER_LEFT)
		if pick == ControlsConfig.WheelPick.CLICK:
			_event(&"fire", true)
			_event(&"fire", false)
		_event(&"order_wheel", false)
		input.fill(cmd)
		assert_true(cmd.mag_hand_off, "picked: the hand-off pressed")
		assert_eq(cmd.squad_order, SquadOrder.Kind.NONE, "never a squad order")
		assert_true(input.mag_from_wheel)


func test_h_with_the_wheel_held_open_answers_in_the_wheels_middle() -> void:
	_make_input()
	_event(&"order_wheel", true)
	_event(&"mag_hand_off", true)
	_event(&"mag_hand_off", false)
	input.fill(cmd)
	assert_true(cmd.mag_hand_off, "H pressed with the wheel open")
	assert_true(input.mag_from_wheel, "the answer shows in the wheel's middle, as an order key's notice does")
	_event(&"order_wheel", false)


func test_a_bot_playing_you_keeps_its_own_press() -> void:
	_make_input()
	cmd.reset(0.0, 0.0)
	cmd.mag_hand_off = true
	input.fill_order(cmd)
	assert_true(cmd.mag_hand_off, "the pilot's press stands")
	assert_false(input.mag_sent, "but it isn't yours (the smoke test counts only yours)")
	_event(&"mag_hand_off", true)
	cmd.mag_hand_off = false
	input.fill_order(cmd)
	assert_true(cmd.mag_hand_off, "yours adds to it")
	assert_true(input.mag_sent)
	_event(&"mag_hand_off", false)


func test_the_wheel_draws_need_a_mag_upper_left_with_h_and_toss_a_mag_in_reach() -> void:
	_match()
	wheel.start()
	wheel.at = UPPER_LEFT
	hud.update_orders(wheel, SquadOrder.Kind.NONE, outcome, DT)
	var w := hud.order_wheel()
	assert_eq(w.slice_name(5), "NEED A MAG")
	assert_eq(w.slice_key(5), "H")
	assert_eq(w.lit_slice(), 5)
	assert_true(w._label_at[5].x < 0.0 and w._label_at[5].y < 0.0, "upper left")
	_last_mag(state.characters[ROOK])
	_tick([ROOK])
	assert_true(_line().toss_ready(), "Rook asked you and is 4 m off")
	assert_eq(w.slice_name(5), "TOSS A MAG")
	state.characters[ROOK].position.x = 12.0
	_tick()
	assert_eq(w.slice_name(5), "NEED A MAG", "out of reach: asking again")


# --- criterion 2: a refusal, and the radio click ---

func test_a_refusal_from_the_wheel_shows_in_its_middle_and_from_h_on_the_line() -> void:
	_match()
	_tick([YOU])
	assert_eq(_line().text, "You still have a full spare mag", "from H: on the line")
	assert_eq(hud.order_wheel().notice_text(), "")
	_ticks(160)
	wheel.start()
	wheel.at = UPPER_LEFT
	hud.update_orders(wheel, SquadOrder.Kind.NONE, outcome, DT)
	wheel.close()
	hud.update_orders(wheel, SquadOrder.Kind.NONE, outcome, DT)
	_tick([YOU], true)
	assert_eq(hud.order_wheel().notice_text(), "You still have a full spare mag", "in the wheel's middle")
	assert_false(_line().visible, "not on the line as well")


func test_an_ask_taken_plays_the_radio_click_and_the_toss_and_catch_sound() -> void:
	_match()
	var audio := SimAudio.new()
	add_child_autofree(audio)
	audio.setup(SoundConfig.new(), [] as Array[StringName], tuning.body, world, null)
	var heard := func(cue: StringName) -> int:
		var n := 0
		for v in audio._own:
			if v.stream != null and (audio._streams[cue] as Array).has(v.stream):
				n += 1
		return n
	_tick([YOU])
	audio.on_tick(state, YOU, state.characters[YOU])
	assert_eq(heard.call(&"radio_ack"), 0, "a refusal plays nothing")
	_ticks(300)
	_last_mag(state.characters[YOU])
	_tick([YOU])
	audio.on_tick(state, YOU, state.characters[YOU])
	assert_eq(heard.call(&"radio_ack"), 1, "your ask taken: the radio's double click")
	_tick([ROOK])
	audio.on_tick(state, YOU, state.characters[YOU])
	assert_not_null(state.events.first(GameEvent.Kind.MAG_TOSS), "Rook tossed it")
	for i in 60:
		_tick()
		audio.on_tick(state, YOU, state.characters[YOU])
		if state.events.first(GameEvent.Kind.MAG_CATCH) != null:
			break
	assert_eq(heard.call(&"magCatch"), 1, "your catch in your ear")


# --- criterion 3: the line and the glyph ---

func test_the_line_says_who_needs_a_mag_and_how_far_underlined_once_in_reach() -> void:
	_match()
	state.characters[ROOK].position.x = 12.0
	_last_mag(state.characters[ROOK])
	_tick([ROOK])
	assert_eq(_line().text, "Rook needs a mag · 12 m")
	assert_true(_line().visible)
	assert_false(_line().underlined(), "12 m: out of reach")
	state.characters[ROOK].position.x = 4.0
	_tick()
	assert_eq(_line().text, "Rook needs a mag · 4 m")
	assert_true(_line().underlined(), "in reach: underlined in your team's colour")
	assert_eq((_line().get_theme_stylebox(&"normal") as StyleBoxFlat).border_color, TeamConfig.new().colours[0])


func test_the_line_never_names_a_key() -> void:
	_match()
	_last_mag(state.characters[ROOK])
	_tick([ROOK])
	assert_false(_line().text.contains("H"), "the line says what is happening, never which key")
	_tick([YOU])
	assert_eq(_line().text, "Mag to Rook")


func test_whose_is_coming_and_what_you_caught() -> void:
	_match()
	_last_mag(state.characters[YOU])
	_tick([YOU])
	assert_eq(_line().text, "Rook is bringing you a mag", "your ask stands with Rook, the nearest")
	_tick([ROOK])
	assert_eq(_line().text, "Rook is bringing you a mag", "in the air")
	var caught: GameEvent = null
	for i in 60:
		_tick()
		caught = state.events.first(GameEvent.Kind.MAG_CATCH)
		if caught != null:
			break
	assert_not_null(caught)
	assert_eq(_line().text, "+1 mag from Rook · %d BBs" % caught.value)


func test_a_caught_notice_leaves_the_bbs_out_with_the_ammo_counter_off() -> void:
	_match()
	var p := HudPrefs.new()
	p.ammo_counter = false
	hud.apply_prefs(p)
	_last_mag(state.characters[YOU])
	_tick([YOU])
	_tick([ROOK])
	for i in 60:
		_tick()
		if state.events.first(GameEvent.Kind.MAG_CATCH) != null:
			break
	assert_eq(_line().text, "+1 mag from Rook")


func test_a_notice_shows_2_5_s() -> void:
	_match()
	_tick([YOU])
	assert_true(_line().visible)
	_ticks(roundi(HudConfig.new().mag_notice_time / DT) - 2)
	assert_eq(_line().text, "You still have a full spare mag", "still up")
	_ticks(3)
	assert_eq(_line().text, "")
	assert_false(_line().visible)


func test_each_refusal_has_its_words() -> void:
	var words := {
		MagShare.Refusal.NOBODY: "Nobody near has a mag to spare",
		MagShare.Refusal.NOT_LOW: "You still have a full spare mag",
		MagShare.Refusal.NO_SPARE: "No mag of yours fits Rook's replica",
		MagShare.Refusal.WAIT: "Ask again in a moment",
		MagShare.Refusal.ALREADY: "Rook is already bringing you one",
		MagShare.Refusal.TOO_FAR: "Get closer to Rook to toss a mag",
		MagShare.Refusal.NOT_NOW: "Mags wait for the next round",
	}
	for why: MagShare.Refusal in words:
		assert_eq(HudMagLine.refusal_text(why, "Rook"), words[why])
	assert_eq(HudMagLine.refusal_text(MagShare.Refusal.WAIT, "Rook", true), "Toss again in a moment",
			"a toss waiting on the pool")
	assert_eq(HudMagLine.refusal_text(MagShare.Refusal.WAIT, "Rook", true, true), "Your mag is still in the air")


func test_a_toss_while_yours_is_in_the_air_says_so() -> void:
	_match()
	_last_mag(state.characters[ROOK])
	_tick([ROOK])
	_tick([YOU])
	assert_eq(_line().text, "Mag to Rook")
	var brick := state.characters[BRICK]
	brick.position = Vector3(0.0, 0.0, 3.0)
	brick.prev_position = brick.position
	_last_mag(brick)
	_tick([BRICK])
	assert_eq(brick.mag.asked, YOU, "Brick asks you while your mag to Rook flies")
	_tick([YOU])
	var refused := state.events.first(GameEvent.Kind.MAG_REFUSED)
	assert_not_null(refused)
	if refused != null:
		assert_eq(refused.value, MagShare.Refusal.WAIT)
	assert_eq(_line().text, "Your mag is still in the air")


func test_hidden_while_the_wheel_is_open_and_with_the_setting_off() -> void:
	_match()
	_last_mag(state.characters[ROOK])
	_tick([ROOK])
	assert_true(_line().visible)
	wheel.start()
	hud.update_orders(wheel, SquadOrder.Kind.NONE, outcome, DT)
	assert_false(_line().visible, "the wheel open")
	wheel.close()
	hud.update_orders(wheel, SquadOrder.Kind.NONE, outcome, DT)
	assert_true(_line().visible, "back when it closes")
	var p := HudPrefs.new()
	p.mag_hand_off = false
	hud.apply_prefs(p)
	_tick()
	assert_false(_line().visible, "Settings › HUD › Mag hand-off off")


func test_a_glyph_by_the_chevron_of_a_teammate_asking_you_or_bringing_you_one() -> void:
	_match()
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.look_at_from_position(Vector3(-6.0, 1.6, 4.0), Vector3(2.0, 1.0, 4.0))
	await wait_process_frames(1)
	var you := state.characters[YOU]
	hud.place_team_markers(camera, state.characters, you, 1.0)
	assert_true(hud.team_markers().is_shown(ROOK))
	assert_false(hud.team_markers().has_mag(ROOK), "nobody asking")
	_last_mag(state.characters[ROOK])
	_tick([ROOK])
	hud.place_team_markers(camera, state.characters, you, 1.0)
	assert_true(hud.team_markers().has_mag(ROOK), "Rook asks you")
	assert_false(hud.team_markers().has_mag(BRICK))
	var p := HudPrefs.new()
	p.mag_hand_off = false
	hud.apply_prefs(p)
	hud.place_team_markers(camera, state.characters, you, 1.0)
	assert_false(hud.team_markers().has_mag(ROOK), "the setting off hides the glyphs")
	p.mag_hand_off = true
	hud.apply_prefs(p)
	_tick([YOU])
	_ticks(40)
	hud.place_team_markers(camera, state.characters, you, 1.0)
	assert_false(hud.team_markers().has_mag(ROOK), "tossed and caught: Rook's ask is over")
	_last_mag(you)
	_tick([YOU])
	hud.place_team_markers(camera, state.characters, you, 1.0)
	assert_true(hud.team_markers().has_mag(BRICK), "Brick (Rook keeps the one it caught) is bringing you one")


func test_a_standing_line_allocates_no_object() -> void:
	_match()
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.look_at_from_position(Vector3(-6.0, 1.6, 4.0), Vector3(2.0, 1.0, 4.0))
	await wait_process_frames(1)
	_last_mag(state.characters[ROOK])
	_tick([ROOK])
	_ticks(2)
	var before := Performance.get_monitor(Performance.OBJECT_COUNT)
	for i in 120:
		_tick()
		hud.place_team_markers(camera, state.characters, state.characters[YOU], 1.0)
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), before)


# --- criterion 5: the setting, and the screen reader ---

func test_screen_reader_messages_read_the_lines_notices() -> void:
	_match()
	hud.set_read_out(true)
	_tick([YOU])
	hud.update(state, 1.0, 0.35)
	assert_eq(hud.announce().text, "You still have a full spare mag")
	assert_eq(hud.announce().accessibility_live, AccessibilityServer.LIVE_POLITE)


func test_the_setting_is_on_by_default_and_saved() -> void:
	assert_true(HudPrefs.new().mag_hand_off)
	var old := HudPrefs.new()
	old.from_dict({"callouts": true})
	assert_true(old.mag_hand_off, "a file from before it loads on")
	var s := Settings.new(PlayTuning.new())
	var screen := SettingsScreen.new()
	screen.settings = s
	screen.save_path = SAVE
	add_child_autofree(screen)
	screen.open()
	var page: SettingsHudPage = screen._hud_page
	assert_true(page._mag.button_pressed)
	page._mag.toggled.emit(false)
	assert_false(s.hud.mag_hand_off)
	screen.close()
	var back := Settings.new(PlayTuning.new())
	back.load_file(SAVE)
	assert_false(back.hud.mag_hand_off)


# --- criterion 4: the magazine in the air ---

func test_the_toss_arcs_a_tenth_a_metre_up_to_0_6_m_and_spins_2_5_turns_a_second() -> void:
	var mid := MagTossView.flight_at(Vector3.ZERO, Vector3(4.0, 0.0, 0.0), 0.5, 0.5)
	assert_almost_eq(mid.origin, Vector3(2.0, 0.4, 0.0), Vector3.ONE * 0.001, "0.1 m a metre at the middle")
	var far := MagTossView.flight_at(Vector3.ZERO, Vector3(10.0, 0.0, 0.0), 0.5, 0.8)
	assert_almost_eq(far.origin.y, 0.6, 0.001, "never over 0.6 m")
	assert_almost_eq(MagTossView.flight_at(Vector3.ZERO, Vector3(4.0, 0.0, 0.0), 1.0, 0.5).origin,
			Vector3(4.0, 0.0, 0.0), Vector3.ONE * 0.001, "lands at the chest")
	var a_turn := MagTossView.flight_at(Vector3.ZERO, Vector3(4.0, 0.0, 0.0), 0.8, 0.5)
	assert_almost_eq(a_turn.basis.y, Vector3.UP, Vector3.ONE * 0.001, "0.4 s in: one whole turn")
	var half := MagTossView.flight_at(Vector3.ZERO, Vector3(4.0, 0.0, 0.0), 0.4, 0.5)
	assert_almost_eq(half.basis.y, Vector3.DOWN, Vector3.ONE * 0.001, "0.2 s in: half a turn")


func test_the_toss_is_the_throwers_magazine_in_a_pool_of_six_made_once() -> void:
	_match()
	var models := FigureModels.new(FigureConfig.new())
	var view := MagTossView.new()
	add_child_autofree(view)
	view.setup(state.mag_tosses.size(), state.characters, models, sim.mag_share)
	assert_eq(view.get_child_count(), 6, "a pool of six")
	var rifle_mag := models.magazine_mesh(loadout[0].id)
	assert_not_null(rifle_mag, "the rifle's model has its magazine")
	_last_mag(state.characters[ROOK])
	_tick([ROOK])
	_tick([YOU])
	view.update(state, 0.5, DT)
	assert_true(view.shown(0), "in the air")
	assert_eq(view.mesh_of(0), rifle_mag, "your rifle's own magazine")
	var children := view.get_child_count()
	for i in 60:
		_tick()
		view.update(state, 0.5, DT)
	assert_false(view.shown(0), "landed: hidden")
	assert_eq(view.get_child_count(), children, "nothing made per toss")


# --- the match marks you as the player ---

func test_a_match_marks_you_as_the_player_so_your_ask_gap_is_4_s() -> void:
	var play := PlaySession.new()
	play.bots_active = false
	add_child_autofree(play)
	await wait_physics_frames(2)
	var you := play.player
	assert_true(you.mag.player, "set by the match")
	assert_not_null(play.hud().mag_line(), "the line is built for a match")
	assert_not_null(play._mag_tosses)
	var share := play._sim.mag_share
	var s := play.state
	_last_mag(you)
	you.mag.next_ask = -INF
	share.press(you, s, true)
	assert_true(you.mag.asked >= 0, "asked a teammate")
	s.time += tuning.mag_share.ask_time + 1.0
	share.step(s, true, 0.0)
	assert_eq(you.mag.asked, -1, "the ask lapsed")
	assert_almost_eq(you.mag.next_ask - s.time, tuning.mag_share.player_ask_gap, 0.001, "the player's gap, not 20 s")
