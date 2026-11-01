extends GutTest
## MC1 (match controls, owner's playtest 2026-11-01): the keys moved (bombs on 4 and 5, doors on G, the hop-up dial on
## Page Down and Page Up) and an old save's move to them; the mouse wheel stepping through the replicas and the bombs
## left and the bomb in hand it takes (the replica down, a trigger pull throws it, a slot or a hit puts it back); the
## minimap's zoom (saved, the panel's scale, the heard patches' rim); the round held after a skip until a click; the
## loading screen's Continue; the Day / Night row's room.

const DT := 1.0 / 60.0

var tuning: SimTuning = SimTuning.new()
var loadout: Array[ReplicaConfig] = []


func before_all() -> void:
	loadout = ReplicaStats.default_loadout()


func after_each() -> void:
	InputMap.load_from_project_settings()


# --- the keys ---


func test_the_bombs_sit_on_4_and_5_the_doors_on_g_and_the_dial_on_page_down_and_up() -> void:
	var b := KeyBindings.new()
	assert_eq(b.codes(&"throw_smoke"), PackedInt32Array([KEY_4]))
	assert_eq(b.codes(&"throw_flash"), PackedInt32Array([KEY_5]))
	assert_eq(b.codes(&"use_door"), PackedInt32Array([KEY_G]))
	assert_eq(b.codes(&"hop_up_less"), PackedInt32Array([KEY_PAGEDOWN]))
	assert_eq(b.codes(&"hop_up_more"), PackedInt32Array([KEY_PAGEUP]))
	assert_eq(b.action_of(KEY_U), &"", "U is free")
	assert_eq(b.action_of(KEY_Y), &"", "Y is free")


func test_a_save_from_before_moves_what_sat_on_the_old_defaults_and_keeps_the_players_own_keys() -> void:
	var old := KeyBindings.new()
	var saved := old.to_dict()
	saved.erase(KeyBindings.LAYOUT_KEY)
	for action: StringName in KeyBindings.LAYOUT_1_MOVED:
		saved[String(action)] = KeyBindings.LAYOUT_1_MOVED[action]
	# the player's own key for the flash
	saved["throw_flash"] = [KEY_J]
	var b := KeyBindings.new()
	assert_true(b.load_dict(saved), "the set loads as it came")
	assert_eq(b.codes(&"throw_smoke"), PackedInt32Array([KEY_4]), "on its old default: moved")
	assert_eq(b.codes(&"throw_flash"), PackedInt32Array([KEY_J]), "the player's own key stays")
	assert_eq(b.codes(&"use_door"), PackedInt32Array([KEY_G]))
	assert_eq(b.codes(&"hop_up_less"), PackedInt32Array([KEY_PAGEDOWN]))
	assert_eq(b.codes(&"hop_up_more"), PackedInt32Array([KEY_PAGEUP]))


func test_a_save_of_this_layout_keeps_even_the_old_default_keys() -> void:
	var b := KeyBindings.new()
	assert_eq(b.rebind(&"use_door", KEY_U), KeyBindings.Result.BOUND)
	var saved := b.to_dict()
	assert_eq(saved[KeyBindings.LAYOUT_KEY], KeyBindings.LAYOUT)
	var again := KeyBindings.new()
	assert_true(again.load_dict(saved))
	assert_eq(again.codes(&"use_door"), PackedInt32Array([KEY_U]), "picked on this layout: kept")


func test_a_moved_default_held_by_the_players_own_key_is_left_off() -> void:
	var saved := KeyBindings.new().to_dict()
	saved.erase(KeyBindings.LAYOUT_KEY)
	saved["throw_smoke"] = [KEY_G]
	saved["reload"] = [KEY_4]
	var b := KeyBindings.new()
	b.load_dict(saved)
	assert_eq(b.codes(&"reload"), PackedInt32Array([KEY_4]), "the player's own key wins")
	assert_eq(b.codes(&"throw_smoke"), PackedInt32Array(), "its new default is taken: no key rather than a clash")


# --- the mouse wheel ---


func test_the_wheel_steps_through_the_replicas_then_the_bombs_left_and_round() -> void:
	assert_eq(PlayerInput.wheel_item(0, 1, true, true), 1)
	assert_eq(PlayerInput.wheel_item(1, 1, true, true), PlayerInput.WHEEL_SMOKE)
	assert_eq(PlayerInput.wheel_item(PlayerInput.WHEEL_SMOKE, 1, true, true), PlayerInput.WHEEL_FLASH)
	assert_eq(PlayerInput.wheel_item(PlayerInput.WHEEL_FLASH, 1, true, true), 0, "round again, past no holster")
	assert_eq(PlayerInput.wheel_item(0, -1, true, true), PlayerInput.WHEEL_FLASH, "back from the first")
	assert_eq(PlayerInput.wheel_item(1, 1, false, true), PlayerInput.WHEEL_FLASH, "no smoke left: past it")
	assert_eq(PlayerInput.wheel_item(1, 1, false, false), 0, "no bombs: the replicas only")
	assert_eq(PlayerInput.wheel_item(0, 3, true, true), PlayerInput.WHEEL_FLASH, "three notches in a tick")


func test_a_wheel_notch_past_the_pistol_takes_the_smoke_in_hand() -> void:
	var input := PlayerInput.new()
	add_child_autofree(input)
	input.setup(ControlsConfig.new(), 1.5)
	input.active = true
	var hand := Grenades.Hand.new()
	hand.carry(1, 1)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_WHEEL_DOWN
	down.pressed = true
	input._unhandled_input(down)
	var cmd := PlayerCommand.new()
	input.fill(cmd, 1, hand)
	assert_eq(cmd.ready_grenade, Grenade.Kind.SMOKE)
	assert_eq(cmd.switch_to, -1, "no replica drawn")
	input.fill(cmd, 1, hand)
	assert_eq(cmd.ready_grenade, Grenade.Kind.NONE, "one notch, one take")
	hand.readied = Grenade.Kind.FLASH
	input._unhandled_input(down)
	input.fill(cmd, 1, hand)
	assert_eq(cmd.switch_to, 0, "from the flash in hand on to the first replica")
	assert_eq(cmd.ready_grenade, Grenade.Kind.NONE)
	input.active = false


# --- the bomb in hand ---


## A started match of two (one a side) on a floor: [Simulation, GameState].
func _match() -> Array:
	var w := BoxWorld.new(tuning.body)
	w.add_floor(60.0, 30.0)
	var ends: Array[MapEnd] = []
	for e in 2:
		var end := MapEnd.new()
		end.spawns.append(SpawnPoint.new(Vector3(-10.0 if e == 0 else 10.0, 0.0, 0.0), 0.0))
		end.dead_zone.append(SpawnPoint.new(Vector3(-25.0 if e == 0 else 25.0, 0.0, 10.0), 0.0))
		ends.append(end)
	var sim := Simulation.new(tuning, w, w.mover(), ends, -10.0)
	var s := GameState.new(5, tuning)
	for i in 2:
		s.characters.append(Character.new(i, i, Vector3.ZERO, 0.0, loadout))
	sim.start_match(s)
	return [sim, s]


func _commands(s: GameState) -> Array[PlayerCommand]:
	var out: Array[PlayerCommand] = []
	for c in s.characters:
		var cmd := PlayerCommand.new()
		cmd.reset(c.yaw, c.pitch)
		out.append(cmd)
	return out


## Steps `ticks` ticks, one-shot presses cleared after the first.
func _run(sim: Simulation, s: GameState, cmds: Array[PlayerCommand], ticks: int) -> void:
	for t in ticks:
		sim.step(s, cmds, DT)
		for cmd in cmds:
			cmd.ready_grenade = Grenade.Kind.NONE
			cmd.throw_grenade = Grenade.Kind.NONE
			cmd.switch_to = -1


func _active_bombs(s: GameState) -> int:
	var n := 0
	for g in s.grenades:
		if g.active:
			n += 1
	return n


func test_a_bomb_in_hand_puts_the_replica_down_and_a_trigger_pull_throws_it_then_the_replica_comes_back() -> void:
	var m := _match()
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var you := s.characters[0]
	var cmds := _commands(s)
	_run(sim, s, cmds, 30) # drawn and still
	var smokes := you.grenades.smoke
	cmds[0].ready_grenade = Grenade.Kind.SMOKE
	_run(sim, s, cmds, 1)
	assert_eq(you.grenades.readied, Grenade.Kind.SMOKE)
	assert_true(you.armament.holstered, "the replica goes down")
	_run(sim, s, cmds, 30)
	assert_eq(you.grenades.readied, Grenade.Kind.SMOKE, "it stays in hand")
	assert_eq(_active_bombs(s), 0, "nothing thrown yet")
	cmds[0].fire = true
	_run(sim, s, cmds, 1)
	assert_true(Grenades.throwing(you), "the pull throws it")
	assert_eq(you.grenades.readied, Grenade.Kind.NONE)
	cmds[0].fire = false
	_run(sim, s, cmds, roundi((tuning.grenades.windup + tuning.grenades.recover) / DT) + 2)
	assert_eq(_active_bombs(s), 1, "the smoke is out")
	assert_eq(you.grenades.smoke, smokes - 1)
	assert_false(you.armament.holstered, "the replica comes back up after the throw")
	assert_eq(s.bbs.active_count(), 0, "the pull fired no BB")


func test_a_trigger_held_as_the_bomb_comes_into_hand_does_not_throw_it() -> void:
	var m := _match()
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var you := s.characters[0]
	var cmds := _commands(s)
	_run(sim, s, cmds, 30)
	cmds[0].fire = true
	cmds[0].ready_grenade = Grenade.Kind.FLASH
	_run(sim, s, cmds, 5)
	assert_eq(you.grenades.readied, Grenade.Kind.FLASH)
	assert_false(Grenades.throwing(you), "a held trigger is no pull")
	cmds[0].fire = false
	_run(sim, s, cmds, 1)
	cmds[0].fire = true
	_run(sim, s, cmds, 1)
	assert_true(Grenades.throwing(you), "a fresh pull throws it")


func test_a_slot_puts_the_bomb_back_and_draws_the_replica() -> void:
	var m := _match()
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var you := s.characters[0]
	var cmds := _commands(s)
	_run(sim, s, cmds, 30)
	cmds[0].ready_grenade = Grenade.Kind.SMOKE
	_run(sim, s, cmds, 1)
	cmds[0].switch_to = 1
	_run(sim, s, cmds, 1)
	assert_eq(you.grenades.readied, Grenade.Kind.NONE, "put back")
	assert_false(you.armament.holstered, "the replica is drawn")
	assert_eq(you.armament.active, 1)
	assert_eq(_active_bombs(s), 0)


func test_the_holster_key_puts_the_bomb_back_and_leaves_the_replica_away() -> void:
	var m := _match()
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var you := s.characters[0]
	var cmds := _commands(s)
	_run(sim, s, cmds, 30)
	cmds[0].ready_grenade = Grenade.Kind.SMOKE
	_run(sim, s, cmds, 1)
	cmds[0].holster = true
	_run(sim, s, cmds, 1)
	cmds[0].holster = false
	assert_eq(you.grenades.readied, Grenade.Kind.NONE)
	assert_true(you.armament.holstered)


func test_a_bomb_with_none_of_its_kind_left_is_not_taken() -> void:
	var m := _match()
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var you := s.characters[0]
	var cmds := _commands(s)
	_run(sim, s, cmds, 30)
	you.grenades.flash = 0
	cmds[0].ready_grenade = Grenade.Kind.FLASH
	_run(sim, s, cmds, 1)
	assert_eq(you.grenades.readied, Grenade.Kind.NONE)
	assert_false(you.armament.holstered, "the replica stays up")


func test_a_hit_with_a_bomb_in_hand_drops_it_and_keeps_the_bomb() -> void:
	var m := _match()
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var you := s.characters[0]
	var cmds := _commands(s)
	_run(sim, s, cmds, 30)
	var smokes := you.grenades.smoke
	cmds[0].ready_grenade = Grenade.Kind.SMOKE
	_run(sim, s, cmds, 1)
	Elimination.eliminate(you, s.characters[1].id, s.characters, sim.ends)
	_run(sim, s, cmds, 2)
	assert_eq(you.grenades.readied, Grenade.Kind.NONE, "dropped with the hit")
	assert_eq(you.grenades.smoke, smokes, "the bomb is kept")


# --- the minimap's zoom ---


func test_the_minimap_zoom_saves_loads_snaps_and_falls_back() -> void:
	var p := HudPrefs.new()
	assert_eq(p.minimap_zoom, 1.0, "100 % by default")
	p.minimap_zoom = 1.5
	var q := HudPrefs.new()
	q.from_dict(p.to_dict())
	assert_almost_eq(q.minimap_zoom, 1.5, 1e-6)
	q.from_dict({"minimap_zoom": 1.53})
	assert_almost_eq(q.minimap_zoom, 1.5, 1e-6, "between steps: the nearest")
	q.from_dict({"minimap_zoom": 9.0})
	assert_eq(q.minimap_zoom, 1.0, "out of range: the default")
	q.from_dict({"minimap_zoom": "close"})
	assert_eq(q.minimap_zoom, 1.0)
	q.from_dict({})
	assert_eq(q.minimap_zoom, 1.0, "a file from before it: 100 %")


func test_the_panel_shows_the_field_closer_at_a_higher_zoom() -> void:
	var cfg := MinimapConfig.new()
	var view := HudMinimap.View.new()
	add_child_autofree(view)
	view.size = Vector2.ONE * cfg.size
	view.setup(cfg, [], cfg.layer_scale, Vector2.ZERO, 0)
	view.begin(Vector2.ZERO, -1, 0.0, true, Color.BLUE, Color.ORANGE)
	var plain := view.px_per_m()
	assert_almost_eq(plain, cfg.size / (2.0 * cfg.view_radius), 1e-4)
	view.begin(Vector2.ZERO, -1, 0.0, true, Color.BLUE, Color.ORANGE, 2.0)
	assert_almost_eq(view.px_per_m(), plain * 2.0, 1e-4, "200 %: twice the pixels a metre")
	view.begin(Vector2.ZERO, -1, 0.0, true, Color.BLUE, Color.ORANGE, 0.5)
	assert_almost_eq(view.px_per_m(), plain * 0.5, 1e-4)


func test_a_heard_patch_past_the_zoomed_view_is_beyond_it() -> void:
	var cfg := MinimapConfig.new()
	var heard := MinimapHearing.new(cfg)
	var listener := Character.new(0, 0, Vector3.ZERO, 0.0, loadout)
	var enemy := Character.new(1, 1, Vector3.ZERO, 0.0, loadout)
	var cast: Array[Character] = [listener, enemy]
	heard.patches.clear()
	for c in cast:
		heard.patches.append(MinimapHearing.Patch.new())
	var p := heard.patches[1]
	p.live = true
	p.heard_at = 0.0
	p.centre = Vector3(cfg.view_radius * 0.75, 0.0, 0.0)
	heard._age(listener)
	assert_false(p.beyond_view, "inside the view at 100 %")
	heard.zoom = 2.0
	heard._age(listener)
	assert_true(p.beyond_view, "at 200 % the view reaches half as far")


# --- the round held after a skip ---


func test_a_held_round_waits_past_its_timer_for_the_click() -> void:
	var m := _match()
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var cmds := _commands(s)
	var rs := s.round_state
	rs.hold_next = true
	DevCheats.end_round(s)
	_run(sim, s, cmds, 2)
	assert_eq(rs.phase, RoundState.Phase.OVER)
	var number := rs.number
	_run(sim, s, cmds, roundi(tuning.rounds.reset_delay / DT) + 30)
	assert_eq(rs.phase, RoundState.Phase.OVER, "held past the wait")
	assert_eq(rs.timer, 0.0)
	assert_true(Round.end_wait(rs))
	assert_false(rs.hold_next)
	_run(sim, s, cmds, 1)
	assert_eq(rs.phase, RoundState.Phase.LIVE, "the click starts the next round")
	assert_true(rs.number >= number)
	assert_false(rs.hold_next, "each round starts unheld")


# --- the loading screen ---


func test_continue_comes_up_once_fully_loaded_and_its_press_says_so() -> void:
	var screen := LoadingScreen.new()
	add_child_autofree(screen)
	screen.setup("depot", "Depot", "", "")
	assert_false(screen.continue_button().visible, "not while loading")
	watch_signals(screen)
	screen.show_continue()
	assert_true(screen.continue_button().visible)
	assert_true(screen.continue_button().has_focus(), "Enter or Space presses it")
	assert_almost_eq(screen.progress(), 1.0, 1e-6)
	assert_eq(screen.step_text(), tr("LOAD_READY"))
	screen.continue_button().pressed.emit()
	assert_signal_emitted(screen, "continued")


# --- the Day / Night row ---


func test_the_day_night_row_has_room_over_it() -> void:
	var box := MatchRulesBox.new(MatchPicks.new(), Settings.new(), SimTuning.new())
	add_child_autofree(box)
	var room := box.find_child("TimeOfDayRoom", true, false) as Control
	assert_not_null(room)
	assert_eq(room.custom_minimum_size.y, float(MatchRulesBox.TIME_TOP_GAP))
	assert_eq(room.get_index(), 0, "over the row")


func test_the_range_holds_behind_the_loading_screen_until_continue() -> void:
	var main: Node = add_child_autofree(preload("res://game/main.tscn").instantiate())
	await wait_process_frames(2)
	main.continue_after_loading = true
	main._picks.mode = MatchOptions.MODE_PRACTICE
	main._start_play()
	var play: PlaySession = main._play
	assert_true(play.wait_for_go)
	assert_true(await wait_until(func() -> bool: return play.ready_for_go(), 40.0), "fully loaded")
	assert_not_null(main._loading, "the loading screen stays")
	assert_true(main._loading.continue_button().visible)
	assert_true(play.holding())
	var ticks := play.ticks()
	await wait_physics_frames(5)
	assert_eq(play.ticks(), ticks, "nothing ticks while it waits")
	main._loading.continue_button().pressed.emit()
	assert_null(main._loading, "Continue: the screen goes")
	assert_false(play.holding())
	await wait_physics_frames(5)
	assert_gt(play.ticks(), ticks, "and the match runs")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
