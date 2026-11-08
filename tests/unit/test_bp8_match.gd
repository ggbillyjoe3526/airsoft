extends GutTest
## BP8 match fixes (William's 0.1 Dev 2 playtest notes): two grenade slots, each any bomb (2); the flag's raise and hold
## times (16); Attack / Defend the default mode (20); still camera after the round (22); SIMULATE a skipped round (24);
## bushes slow you and rustle louder (25).

const LOADOUTS := "user://test_bp8_match_loadouts.save"
const SETTINGS := "user://test_bp8_match_settings.save"

var tuning: SimTuning = SimTuning.load_default()


func before_each() -> void:
	SaveFile.remove(LOADOUTS)
	SaveFile.remove(SETTINGS)


func after_each() -> void:
	await wait_process_frames(2)
	SaveFile.remove(LOADOUTS)
	SaveFile.remove(SETTINGS)


func _kinds(picks: Array[Grenade.Kind]) -> Array:
	return Array(picks)


# --- 2: grenade slots ---


func test_a_loadout_has_two_grenade_slots_each_a_smoke_or_a_flash_the_same_twice_allowed() -> void:
	var rules := LoadoutRules.standard()
	var l := rules.default_loadout("Test")
	assert_eq(rules.bombs.slots, 2)
	assert_eq(_kinds(rules.bombs_of(l)), [Grenade.Kind.SMOKE, Grenade.Kind.FLASH], "the default pick: one of each")
	assert_true(rules.set_bomb(l, 1, Grenade.Kind.SMOKE))
	assert_eq(_kinds(rules.bombs_of(l)), [Grenade.Kind.SMOKE, Grenade.Kind.SMOKE], "two smokes")
	assert_false(rules.set_bomb(l, 1, Grenade.Kind.SMOKE), "already so")
	assert_true(rules.set_bomb(l, 0, Grenade.Kind.FLASH))
	assert_true(rules.set_bomb(l, 1, Grenade.Kind.FLASH))
	assert_eq(_kinds(rules.carried(l).bombs), [Grenade.Kind.FLASH, Grenade.Kind.FLASH], "the kit carries two flashes")
	assert_false(rules.set_bomb(l, 2, Grenade.Kind.SMOKE), "no third slot")
	assert_false(rules.set_bomb(l, 0, Grenade.Kind.NONE), "a slot holds a bomb")


func test_the_pick_is_saved_and_an_old_save_carries_one_of_each() -> void:
	var saved := SavedLoadouts.new(LoadoutRules.standard())
	saved.rules.set_bomb(saved.carried(), 0, Grenade.Kind.FLASH)
	assert_true(saved.save(LOADOUTS))
	var back := SavedLoadouts.new(LoadoutRules.standard())
	back.load_file(LOADOUTS)
	assert_eq(_kinds(back.rules.bombs_of(back.carried())), [Grenade.Kind.FLASH, Grenade.Kind.FLASH])
	assert_eq(_kinds(back.carried().copy("x").bombs), [Grenade.Kind.FLASH, Grenade.Kind.FLASH], "a copy keeps them")
	var old := SavedLoadouts.new(LoadoutRules.standard())
	var problems := old.from_dict({"slots": [{"name": "Old", "equipped": ["000002", "000001"]}]})
	assert_eq(problems, [] as Array[String], "a save from before grenade slots reads cleanly")
	assert_eq(_kinds(old.rules.bombs_of(old.carried())), [Grenade.Kind.SMOKE, Grenade.Kind.FLASH])
	problems = old.from_dict({"slots": [{"name": "Bad", "equipped": ["000002", "000001"], "bombs": ["smoke", "frag"]}]})
	assert_eq(problems.size(), 1, "a bomb this build doesn't know is listed")
	assert_eq(_kinds(old.rules.bombs_of(old.carried())), [Grenade.Kind.SMOKE, Grenade.Kind.FLASH], "the default pick")


func test_the_hand_carries_its_picks_and_a_match_start_hands_them_out() -> void:
	var hand := Grenades.Hand.new()
	hand.carry_picked(tuning.grenades)
	assert_eq([hand.smoke, hand.flash], [1, 1], "no pick: one of each")
	hand.picks = [Grenade.Kind.SMOKE, Grenade.Kind.SMOKE] as Array[Grenade.Kind]
	hand.carry_picked(tuning.grenades)
	assert_eq([hand.smoke, hand.flash], [2, 0])
	hand.smoke = 0
	hand.refill()
	assert_eq(hand.smoke, 2, "a respawn refills the pick")
	hand.picks = [Grenade.Kind.FLASH, Grenade.Kind.FLASH, Grenade.Kind.FLASH] as Array[Grenade.Kind]
	hand.carry_picked(tuning.grenades)
	assert_eq([hand.smoke, hand.flash], [1, 1], "more than two slots won't do: the default pick")
	var w := BoxWorld.new(tuning.body)
	w.add_floor(40.0, 40.0)
	var ends: Array[MapEnd] = []
	for e in 2:
		var end := MapEnd.new()
		end.spawns.append(SpawnPoint.new(Vector3(-10.0 if e == 0 else 10.0, 0.0, 0.0), 0.0))
		end.dead_zone.append(SpawnPoint.new(Vector3(-15.0 if e == 0 else 15.0, 0.0, 0.0), 0.0))
		ends.append(end)
	var sim := Simulation.new(tuning, w, w.mover(), ends, -10.0)
	var s := GameState.new(3, tuning)
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	c.grenades.picks = [Grenade.Kind.FLASH, Grenade.Kind.FLASH] as Array[Grenade.Kind]
	s.characters.append(c)
	s.characters.append(Character.new(1, 1, Vector3.ZERO, 0.0, ReplicaStats.default_loadout()))
	sim.start_match(s)
	assert_eq([c.grenades.smoke, c.grenades.flash], [0, 2])
	assert_eq([s.characters[1].grenades.smoke, s.characters[1].grenades.flash], [1, 1])


func test_bot_kits_list_their_grenades() -> void:
	var kits := BotKits.shared()
	assert_eq(kits.problems, [] as Array[String])
	var rules := LoadoutRules.standard()
	var seen := {}
	for plan in kits.kits:
		assert_eq(plan.bombs.size(), 2, "%s lists two bombs" % plan.kit_name)
		seen[_kinds(BotKits.kit_of(plan, rules).bombs)] = true
	assert_true(seen.has([Grenade.Kind.FLASH, Grenade.Kind.FLASH]), "some kits carry two flashes")
	assert_true(seen.has([Grenade.Kind.SMOKE, Grenade.Kind.SMOKE]), "some two smokes")
	var pool := Pool.shared()
	var head := "| Kit | Primary | Primary parts | Secondary | Secondary parts | Grenades | Easy | Normal | Hard |\n"
	head += "|---|---|---|---|---|---|---|---|---|\n"
	var bad := BotKits.parse(head + "| X | AEG Rifle | | | | Smoke, Frag | 1 | 1 | 1 |\n", pool)
	assert_eq(bad.kits.size(), 0)
	assert_string_contains(bad.problems[0], "Frag")


func test_the_loadout_page_picks_each_slot() -> void:
	var saved := SavedLoadouts.new(LoadoutRules.standard())
	var page := LoadoutPage.new(saved, Settings.new())
	page.save_path = LOADOUTS
	page.settings_path = SETTINGS
	add_child_autofree(page)
	var gear := page.gear()
	assert_eq(gear.grenade_pick(0).selected(), 0, "slot 1: smoke")
	assert_eq(gear.grenade_pick(1).selected(), 1, "slot 2: flash")
	gear.grenade_pick(0).button(1).pressed.emit()
	assert_eq(_kinds(saved.rules.bombs_of(saved.carried())), [Grenade.Kind.FLASH, Grenade.Kind.FLASH])
	var slot1 := gear.find_child("GrenadeSlot1", true, false)
	var bomb := slot1.find_child("Bomb", true, false) as Label
	assert_eq(bomb.text, "FLASH", "the tile shows its bomb")
	assert_eq((slot1.find_children("*", "GrenadeGlyph", true, false)[0] as GrenadeGlyph).kind, Grenade.Kind.FLASH)


# --- 16: the flag's raise and hold ---


func _flag_step(flag: FlagState, cs: Array[Character], cfg: FlagConfig, seconds: float) -> bool:
	var events := SimEvents.new()
	var won := false
	for i in ceili(seconds * 60.0 - 1e-6):
		events.clear()
		won = Flag.step(flag, cs, 0, cfg, events, 1.0 / 60.0)
		if won:
			return true
	return won


func test_the_raise_takes_longer_and_a_raised_flag_must_be_held() -> void:
	var cfg := SimTuning.load_default().flag
	assert_eq(cfg.raise_time, 7.0, "longer than the 5 s it was, tuned on the balance report")
	assert_eq(cfg.hold_time, 3.0, "a hold where there was none")
	var flag := FlagState.new()
	flag.reset(Vector3.ZERO)
	var none: Array[ReplicaConfig] = []
	var attacker := Character.new(0, 0, Vector3(0.5, 0.0, 0.0), 0.0, none)
	var defender := Character.new(1, 1, Vector3(50.0, 0.0, 0.0), 0.0, none)
	var cs: Array[Character] = [attacker, defender]
	assert_false(_flag_step(flag, cs, cfg, cfg.raise_time - 0.1), "not up yet")
	assert_false(_flag_step(flag, cs, cfg, 0.2), "raised, not yet held")
	assert_eq(flag.progress, 1.0)
	attacker.position = Vector3(50.0, 0.0, 5.0)
	assert_false(_flag_step(flag, cs, cfg, cfg.hold_time - 1.0), "held by nobody: it stays up and counts")
	assert_gt(flag.held, cfg.hold_time - 1.2)
	defender.position = Vector3(0.5, 0.0, 0.0)
	attacker.position = Vector3(-0.5, 0.0, 0.0)
	_flag_step(flag, cs, cfg, 2.0)
	assert_eq(flag.status, FlagState.Status.CONTESTED)
	assert_gt(flag.held, cfg.hold_time - 1.2, "both on the rope pause the hold")
	assert_lt(flag.held, cfg.hold_time)
	attacker.position = Vector3(50.0, 0.0, 5.0)
	_flag_step(flag, cs, cfg, 0.1)
	assert_lt(flag.progress, 1.0, "a defender alone pulls it off the top")
	assert_eq(flag.held, 0.0, "and the hold starts again")
	defender.position = Vector3(50.0, 0.0, 0.0)
	attacker.position = Vector3(0.5, 0.0, 0.0)
	assert_false(_flag_step(flag, cs, cfg, 0.5))
	assert_true(_flag_step(flag, cs, cfg, cfg.hold_time + 0.1), "held the whole hold: the attackers win")
	assert_true(Flag.rope_worked([flag] as Array[FlagState]), "a raised flag held plays on past the buzzer")


func test_the_gauge_counts_the_hold_down() -> void:
	var gauge := HudFlagGauge.new()
	gauge.setup(12, 300.0)
	add_child_autofree(gauge)
	assert_eq(gauge.label_text(), "FLAG")
	gauge.set_hold(4)
	assert_eq(gauge.label_text(), "HOLD 4")
	gauge.set_hold(-1)
	assert_eq(gauge.label_text(), "FLAG")


# --- 22: a still view once the round is over ---


func test_the_view_holds_still_once_the_round_is_over_unless_it_is_yours_in_play() -> void:
	var none: Array[ReplicaConfig] = []
	var you := Character.new(0, 0, Vector3.ZERO, 0.0, none)
	var bot := Character.new(1, 0, Vector3.ZERO, 0.0, none)
	var rs := RoundState.new()
	assert_false(FirstPersonView.holds_still(rs, bot, you), "live: the view follows whoever you watch")
	rs.phase = RoundState.Phase.OVER
	assert_true(FirstPersonView.holds_still(rs, bot, you), "over: the bot you watch glances about, the view doesn't")
	assert_false(FirstPersonView.holds_still(rs, you, you), "your own view, in play, is still yours to turn")
	you.status = Character.Status.WALKING_OFF
	assert_true(FirstPersonView.holds_still(rs, you, you), "your walk-off doesn't turn the view")
	rs.phase = RoundState.Phase.MATCH_OVER
	assert_true(FirstPersonView.holds_still(rs, bot, you))


# --- 20: Attack / Defend by default ---


func test_attack_defend_is_the_default_mode() -> void:
	assert_eq(MatchPicks.new().mode, MatchOptions.MODE_ATTACK_DEFEND)
	assert_eq(MatchOptions.DEFAULT_MODE, MatchOptions.MODE_ATTACK_DEFEND)


# --- 24: SIMULATE a skipped round ---


func _simulated(alpha: int, beta: int, seed_value: int, flag: float = 0.0) -> Array:
	var none: Array[ReplicaConfig] = []
	var cs: Array[Character] = []
	for i in alpha + beta:
		cs.append(Character.new(i, 0 if i < alpha else 1, Vector3.ZERO, 0.0, none))
	var rs := RoundState.new()
	if flag > 0.0:
		rs.mode = RoundState.Mode.ATTACK_DEFEND
		rs.attackers = 0
		rs.pole = Vector3.ZERO
		rs.flags[0].progress = flag
	var events := SimEvents.new()
	var won := Round.simulate(rs, cs, tuning, events, Seeds.stream(seed_value))
	return [won, rs, events]


func test_simulate_decides_the_round_at_once_by_a_seeded_roll_weighted_by_who_is_left() -> void:
	var first: Array = _simulated(3, 2, 7)
	var rs: RoundState = first[1]
	var events: SimEvents = first[2]
	assert_ne(first[0], -1)
	assert_false(rs.is_live(), "decided")
	assert_eq(rs.reason, GameEvent.RoundEnd.SIMULATED)
	assert_eq(rs.score[first[0]], 1)
	assert_eq(events.count, 1)
	assert_eq(events.items[0].kind, GameEvent.Kind.ROUND_OVER)
	assert_eq(_simulated(3, 2, 7)[0], first[0], "the same seed, the same result")
	var alpha_wins := 0
	var flag_wins := 0
	for i in 400:
		alpha_wins += 1 if _simulated(4, 2, i)[0] == 0 else 0
		flag_wins += 1 if _simulated(2, 2, i, 0.9)[0] == 0 else 0
	# 4 v 2 squared: 16 to 4, Alpha wins about 80 %; level with the flag 90 % up, 2.8 to 1, about 74 %
	assert_between(alpha_wins, 280, 360, "a man up counts for more than his share")
	assert_between(flag_wins, 255, 335, "a flag going up favours the attackers")
	assert_eq(_simulated(3, 0, 1)[0], 0, "nobody left never wins it")
	var over: Array = _simulated(3, 2, 7)
	assert_eq(Round.simulate(over[1], [] as Array[Character], tuning, SimEvents.new(), Seeds.stream(1)), -1,
			"a round already over isn't simulated again")
	assert_ne(Seeds.simulate_seed(5, 1, 2), Seeds.simulate_seed(5, 1, 3), "each round its own roll")


func test_simulate_skipped_rounds_is_a_gameplay_setting_off_by_default() -> void:
	var s := Settings.new()
	assert_false(s.simulate_skips)
	s.simulate_skips = true
	var back := Settings.new()
	back.from_dict(s.to_dict())
	assert_true(back.simulate_skips)
	var screen := SettingsScreen.new()
	screen.settings = Settings.new()
	screen.save_path = SETTINGS
	add_child_autofree(screen)
	screen.open()
	assert_eq(screen._simulate_skips.selected(), 0, "Off")
	screen._simulate_skips.button(1).pressed.emit()
	assert_true(screen.settings.simulate_skips)
	assert_eq(screen._simulate_skips.accessibility_name, tr("SETTINGS_SIMULATE_SKIPS"))


func test_simulate_on_a_skip_ends_the_round_at_once_and_only_with_the_setting_on() -> void:
	var session := PlaySession.new()
	session.bots_active = false
	session.difficulty = &"easy"
	session.settings = Settings.new()
	add_child_autofree(session)
	await wait_physics_frames(2)
	session.player.status = Character.Status.OUT
	session.start_skip()
	assert_true(session.skipping())
	assert_false(session.simulate_offered(), "off by default: the skip only fast-forwards")
	session.simulate_skip()
	assert_true(session.skipping(), "nothing simulated with the setting off")
	session._stop_skip()
	session.state.round_state.hold_next = false
	session.settings.simulate_skips = true
	session.start_skip()
	assert_true(session.simulate_offered(), "SIMULATE beside the skip")
	session._skip_simulate.button().pressed.emit()
	var rs := session.state.round_state
	assert_false(session.skipping(), "the skip is over")
	assert_false(rs.is_live(), "decided at once")
	assert_eq(rs.reason, GameEvent.RoundEnd.SIMULATED)
	assert_true(rs.hold_next, "the round's table waits for a click, as after any skip")
	assert_false(session._skip_simulate.visible)
	assert_true(session.hud().visible)


func test_simulate_is_a_button_only_a_second_click_keeps_skipping() -> void:
	var session := PlaySession.new()
	session.bots_active = false
	session.difficulty = &"easy"
	session.settings = Settings.new()
	session.settings.simulate_skips = true
	add_child_autofree(session)
	await wait_physics_frames(2)
	session._input.active = true
	session.player.status = Character.Status.OUT
	session.start_skip()
	assert_true(session.simulate_offered())
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	session._unhandled_input(click)
	var fire := InputEventAction.new()
	fire.action = &"fire"
	fire.pressed = true
	session._unhandled_input(fire)
	assert_true(session.skipping(), "a double click to skip doesn't simulate: the skip plays on")
	assert_true(session.state.round_state.is_live())
	session._skip_simulate.button().pressed.emit()
	assert_false(session.skipping(), "the button does")
	# (The pointer shown for the button and captured again after can't be seen headless: the mouse mode stays put.)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# --- 25: bushes slow you and rustle louder ---


func _bush_match(w: BoxWorld) -> Array:
	var ends: Array[MapEnd] = []
	for e in 2:
		var end := MapEnd.new()
		end.spawns.append(SpawnPoint.new(Vector3(-15.0 if e == 0 else 15.0, 0.0, 0.0), 0.0))
		end.dead_zone.append(SpawnPoint.new(Vector3(-18.0 if e == 0 else 18.0, 0.0, 0.0), 0.0))
		ends.append(end)
	var sim := Simulation.new(tuning, w, w.mover(), ends, -10.0)
	var s := GameState.new(3, tuning)
	s.characters.append(Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout()))
	s.characters.append(Character.new(1, 1, Vector3.ZERO, 0.0, ReplicaStats.default_loadout()))
	sim.start_match(s)
	return [sim, s]


## Runs character 0 north (-z) from `from` for `seconds`; its pace over the last half second (m/s).
func _run_north(sim: Simulation, s: GameState, from: Vector3, seconds: float, steps: Array[GameEvent]) -> float:
	var c := s.characters[0]
	c.position = from
	c.prev_position = from
	c.yaw = 0.0
	var cmds: Array[PlayerCommand] = [PlayerCommand.new(), PlayerCommand.new()]
	cmds[0].forward = 1.0
	var ticks := roundi(seconds * 60.0)
	var half_at := Vector3.ZERO
	for i in ticks:
		if i == ticks - 30:
			half_at = c.position
		sim.step(s, cmds, 1.0 / 60.0)
		for j in s.events.count:
			var e := s.events.items[j]
			if e.kind == GameEvent.Kind.FOOTSTEP and e.actor == 0:
				var copy := GameEvent.new()
				copy.value2 = e.value2
				copy.carry = e.carry
				steps.append(copy)
	return Vector2(c.position.x - half_at.x, c.position.z - half_at.z).length() / 0.5


func test_a_bush_slows_whoever_pushes_through_it_and_its_steps_rustle_further() -> void:
	var move := tuning.movement
	assert_eq(move.bush_speed_scale, 0.75)
	assert_eq(tuning.noise.bush_carry, 1.75)
	var w := BoxWorld.new(tuning.body)
	w.add_box(Vector3(0.0, -0.25, 0.0), Vector3(60.0, 0.5, 60.0), RayHit.Surface.EARTH)
	w.add_bush(Vector3(0.0, 0.0, -10.0), 6.0, 1.6)
	var m := _bush_match(w)
	var sim: Simulation = m[0]
	var s: GameState = m[1]
	var open: Array[GameEvent] = []
	var pace := _run_north(sim, s, Vector3(20.0, 0.0, 10.0), 2.0, open)
	assert_almost_eq(pace, move.run_speed, 0.1, "a run in the open")
	assert_false(s.characters[0].in_bush)
	var leafy: Array[GameEvent] = []
	var slowed := _run_north(sim, s, Vector3(0.0, 0.0, -6.0), 2.0, leafy)
	assert_true(s.characters[0].in_bush, "deep in the bush")
	assert_almost_eq(slowed, move.run_speed * move.bush_speed_scale, 0.1, "a quarter slower through the leaves")
	assert_gt(open.size(), 0)
	assert_gt(leafy.size(), 0)
	assert_eq(open[-1].value2, RayHit.Surface.EARTH)
	assert_eq(open[-1].carry, 1.0)
	assert_eq(leafy[-1].value2, RayHit.Surface.LEAVES, "a step in a bush sounds as leaves")
	assert_eq(leafy[-1].carry, tuning.noise.bush_carry, "and carries further: bots hear it the further too")
	var bots := BotConfig.load_default()
	assert_gt(bots.footstep_hearing_run * leafy[-1].carry, bots.footstep_hearing_run * 1.5)


func test_foliage_holds_a_point_among_its_leaves() -> void:
	var f := Foliage.new()
	f.add(Vector3(0.0, 0.0, 0.0), 2.0, 1.6)
	f.add(Vector3(30.0, 0.0, 0.0), 1.0, 1.0)
	assert_true(f.holds(Vector3(0.0, 0.5, 0.0)))
	assert_true(f.holds(Vector3(1.5, 0.8, 0.0)))
	assert_false(f.holds(Vector3(2.2, 0.8, 0.0)), "past its radius")
	assert_false(f.holds(Vector3(0.0, 1.7, 0.0)), "over its top")
	assert_true(f.holds(Vector3(30.0, 0.5, 0.0)))
	assert_false(Foliage.new().holds(Vector3.ZERO))


# --- 7: louder bombs, and the flash's echo ---


## A cue file's samples, read from its source WAV (as tools/cut_recordings.py writes them).
func _cue_samples(cue: String, n: int) -> PackedFloat32Array:
	var bytes := FileAccess.get_file_as_bytes("%s%s_%d.wav" % [SoundConfig.CUE_DIR, cue, n])
	var at := 12
	while at + 8 <= bytes.size() and bytes.slice(at, at + 4).get_string_from_ascii() != "data":
		at += 8 + bytes.decode_u32(at + 4)
	var out := PackedFloat32Array()
	out.resize((bytes.size() - at - 8) / 2)
	for i in out.size():
		out[i] = bytes.decode_s16(at + 8 + 2 * i) / 32768.0
	return out


## The loudest 50 ms's level (dB, RMS) of `x` from `from` s to `to` s.
func _loudest_db(x: PackedFloat32Array, from: float, to: float) -> float:
	var window := int(0.05 * 44100.0)
	var best := 0.0
	var i := int(from * 44100.0)
	while i + window <= mini(x.size(), int(to * 44100.0)):
		var sum := 0.0
		for j in window:
			sum += x[i + j] * x[i + j]
		best = maxf(best, sum / window)
		i += window / 2
	return 10.0 * log(maxf(best, 1e-12)) / log(10.0)


func test_both_bombs_go_off_louder_and_the_flash_rings_out() -> void:
	var cfg := SoundConfig.new()
	assert_almost_eq(linear_to_db(cfg.smoke_pop_gain) - linear_to_db(0.8), 6.0, 0.1, "the smoke 6 dB louder")
	assert_almost_eq(linear_to_db(cfg.bang_gain) - linear_to_db(1.4), 4.0, 0.2, "the bang 4 dB louder")
	assert_true(SimAudio.OWN_CAP_CUES.has(&"smoke_pop"), "a smoke's raise is heard up close too")
	for n in 3:
		var x := _cue_samples("flash_bang", n + 1)
		assert_gt(x.size() / 44100.0, 2.0, "flash_bang_%d rings for 2 s" % (n + 1))
		var pop := _loudest_db(x, 0.0, 0.1)
		var echo := _loudest_db(x, 0.6, 0.8) - pop
		assert_between(echo, -32.0, -12.0, "flash_bang_%d still echoing 0.6 s on: %.1f dB" % [n + 1, echo])
		assert_lt(_loudest_db(x, 1.0, 1.2) - pop, echo, "and dying away")
		assert_lt(absf(x[x.size() - 1]), 0.001, "faded out, never cut off")
