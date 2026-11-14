extends GutTest
## QA's tests for the Dev 3 audit's second pass (AUD1, attempt 3): the edges of the owner-approved changes the first
## hunt did not reach (a simulated round followed by a played one, the Hi-Cap's rattle on a slot that is not the first,
## the SMG bots' full auto outdoors and with no full auto to select, the bot kits' Fields column with a value it cannot
## read) and a staged load left at each of its stages.

const DT := 1.0 / 60.0
## The nav grid is built on a worker thread, in seconds not frames: a load is waited for by the clock.
const LOAD_WAIT_MSEC := 90000

var tuning: SimTuning = SimTuning.new()
var loadout: Array[ReplicaConfig] = ReplicaStats.default_loadout()


# --- A simulated round (2d669ea): a played round after it, and a loss ---


func _tick_events(state: GameState, list: Array) -> void:
	state.events.clear()
	for spec: Array in list:
		var e := state.events.add(spec[0])
		e.actor = spec[1]
		e.target = spec[2]
		e.value = spec[3]
		e.value2 = spec[4] if spec.size() > 4 else 0


func _two() -> Array:
	var state := GameState.new(1)
	var me := Character.new(0, 0, Vector3.ZERO, 0.0, loadout)
	var them := Character.new(1, 1, Vector3.ZERO, 0.0, loadout)
	state.characters.append_array([me, them])
	return [state, PlayerTally.new(0)]


func test_a_simulated_round_before_a_played_one_takes_back_only_its_own_hits_and_shots() -> void:
	var made := _two()
	var state: GameState = made[0]
	var tally: PlayerTally = made[1]
	# Round 1 is skipped after a hit and two shots; round 2 is played out and won with a hit and a shot.
	_tick_events(state, [[GameEvent.Kind.ROUND_START, -1, -1, 1], [GameEvent.Kind.SHOT, 0, -1, 0],
			[GameEvent.Kind.SHOT, 0, -1, 0], [GameEvent.Kind.CHARACTER_HIT, 0, 1, 0]])
	tally.on_tick(state)
	_tick_events(state, [[GameEvent.Kind.ROUND_OVER, -1, -1, 1, GameEvent.RoundEnd.SIMULATED]])
	tally.on_tick(state)
	assert_eq([tally.hits, tally.bbs_fired, tally.rounds_won], [0, 0, 0], "a simulated round gives nothing")
	_tick_events(state, [[GameEvent.Kind.ROUND_START, -1, -1, 2], [GameEvent.Kind.SHOT, 0, -1, 0],
			[GameEvent.Kind.CHARACTER_HIT, 0, 1, 0]])
	tally.on_tick(state)
	_tick_events(state, [[GameEvent.Kind.ROUND_OVER, -1, -1, 0, GameEvent.RoundEnd.ELIMINATED]])
	tally.on_tick(state)
	assert_eq([tally.hits, tally.bbs_fired, tally.rounds_won], [1, 1, 1], "only the round played out counts")


func test_a_simulated_loss_ends_the_match_as_a_loss_with_nothing_else_taken() -> void:
	var made := _two()
	var state: GameState = made[0]
	var tally: PlayerTally = made[1]
	_tick_events(state, [[GameEvent.Kind.ROUND_START, -1, -1, 1]])
	tally.on_tick(state)
	_tick_events(state, [[GameEvent.Kind.ROUND_OVER, -1, -1, 1, GameEvent.RoundEnd.SIMULATED],
			[GameEvent.Kind.MATCH_OVER, -1, -1, 1]])
	tally.on_tick(state)
	assert_true(tally.is_over())
	var progress := Progress.new(LevelTable.read_file(Pool.read_file()))
	var records := Records.new()
	var s := tally.settle(progress, records, false, 0, 1, "elimination", &"normal", &"normal")
	assert_not_null(s)
	assert_eq(records.win_loss(&"normal", "elimination"), PackedInt32Array([0, 1]), "the loss is kept")
	assert_eq(records.streak, 0)
	assert_lt(records.best_accuracy, 0.0, "no BB was played: no accuracy record is set")


# --- The Hi-Cap's rattle (6da5b3c) on a slot that is not the first ---


func _strides_for(replicas: Array[ReplicaConfig], sprinting: bool, crouched: bool) -> Array[GameEvent]:
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, replicas)
	c.grounded = true
	c.sprinting = sprinting
	c.crouch_amount = 1.0 if crouched else 0.0
	var events := SimEvents.new()
	var out: Array[GameEvent] = []
	for i in 400:
		events.clear()
		c.prev_position = c.position
		c.position.z -= 0.05
		Footsteps.step(c, tuning.footsteps, events, BoxWorld.new(tuning.body), tuning.noise)
		for k in events.count:
			var copy := GameEvent.new()
			copy.reset(events.items[k].kind)
			copy.value = events.items[k].value
			copy.slot = events.items[k].slot
			out.append(copy)
	return out


func test_a_rattle_on_the_second_replica_names_its_slot_and_a_crouch_stays_the_rattle_alone() -> void:
	var rifle := loadout[0].duplicate() as ReplicaConfig
	var pistol := loadout[1].duplicate() as ReplicaConfig
	rifle.rattles = false
	pistol.rattles = true
	var both: Array[ReplicaConfig] = [rifle, pistol]
	var run := _strides_for(both, false, false)
	assert_gt(run.size(), 0)
	assert_eq(run[0].slot, 1, "the slot whose magazine rattles, not the first")
	var crouch := _strides_for(both, false, true)
	assert_gt(crouch.size(), 0)
	assert_eq(crouch[0].value, GameEvent.Footstep.RATTLE, "a crouched stride is the rattle alone, as before")
	assert_eq(crouch[0].slot, -1, "and names no slot, so a bot hears no more than the rattle's reach")
	var bots := BotConfig.new()
	var reach := BotHearing.footstep_reach(crouch[0], bots)
	assert_almost_eq(reach, bots.footstep_hearing_rattle, 1e-4, "the rattle's 7 m once, not twice")


# --- SMG bots (c10455c, 89ad7b6): outdoors unchanged, and no full auto to go to ---


func _selector_after(key: StringName, dist: float, start: ReplicaConfig.FireMode, modes: Array[ReplicaConfig.FireMode],
		ticks: int) -> Array:
	var config := BotConfig.load_default()
	var r := ReplicaStats.load_replica(key).duplicate() as ReplicaConfig
	r.fire_modes = modes
	r.default_fire_mode = modes[modes.size() - 1]
	var me := Character.new(0, 0, Vector3.ZERO, 0.0, [r] as Array[ReplicaConfig])
	var foe := Character.new(1, 1, Vector3(0.0, 0.0, -dist), 0.0, ReplicaStats.default_loadout())
	var w := BotWorld.new()
	w.tuning = tuning
	w.cfg = config
	var box := BoxWorld.new()
	box.add_box(Vector3(0.0, 1.5, -dist - 1.0), Vector3(10.0, 3.0, 0.4))
	w.query = box
	w.characters = [me, foe]
	var g := NavGrid.new()
	g.cell = 1.0
	g.cols = 100
	g.rows = 100
	g.min_x = -50.0
	g.min_z = -50.0
	g.open.resize(100 * 100)
	w.nav = g
	w.start_mode = start
	me.armament.reset_fire_modes(w.start_mode)
	var b := Bot.new(me, 1, config.skill_for(&"normal"), 2)
	b.target_visible = true
	var eye := Vector3(0.0, 1.6, 0.0)
	BotFireMode.on_burst(b, w, foe, eye, Vector3(0.0, 0.0, -1.0))
	var events := SimEvents.new()
	var cycled := 0
	for i in ticks:
		var cmd := PlayerCommand.new()
		BotFireMode.select(b, w, foe, cmd)
		if cmd.cycle_fire_mode:
			cycled += 1
		Armament.step(me, cmd, eye, 1.0, false, BBPool.new(1), Seeds.stream(1), events, tuning, DT)
	return [me.armament.fire_mode(), cycled]


func test_an_smg_bot_outdoors_never_touches_its_selector_at_any_range() -> void:
	var smg: Array[ReplicaConfig.FireMode] = [ReplicaConfig.FireMode.SEMI, ReplicaConfig.FireMode.AUTO]
	for dist: float in [2.0, 6.0, 11.0]:
		var got := _selector_after(&"smg", dist, ReplicaConfig.FireMode.AUTO, smg, 6)
		assert_eq(got[1], 0, "%.0f m on a field with no start mode: no press" % dist)
		assert_eq(got[0], ReplicaConfig.FireMode.AUTO)


func test_an_smg_bot_with_no_full_auto_to_select_presses_nothing_indoors() -> void:
	var semi_only: Array[ReplicaConfig.FireMode] = [ReplicaConfig.FireMode.SEMI]
	var got := _selector_after(&"smg", 5.0, ReplicaConfig.FireMode.SEMI, semi_only, 6)
	assert_eq(got[1], 0, "full auto is wanted but the replica has none: the selector is not pressed round and round")
	assert_eq(got[0], ReplicaConfig.FireMode.SEMI)


func test_an_smg_bot_with_a_burst_setting_between_reaches_full_auto_and_stops_there() -> void:
	var three: Array[ReplicaConfig.FireMode] = [ReplicaConfig.FireMode.SEMI, ReplicaConfig.FireMode.BURST,
			ReplicaConfig.FireMode.AUTO]
	var got := _selector_after(&"smg", 5.0, ReplicaConfig.FireMode.SEMI, three, 12)
	assert_eq(got[0], ReplicaConfig.FireMode.AUTO, "semi to burst to auto, a press a tick")
	assert_lte(got[1], 3, "and no more presses than it takes")


# --- Bot kits' Fields column (ca3f750) ---

const KIT_HEADER := """## Kits

| Kit | Primary | Primary parts | Secondary | Secondary parts | Suits | Fields | Easy | Normal | Hard |
|---|---|---|---|---|---|---|---|---|---|
"""


func test_a_kits_fields_cell_it_cant_read_leaves_that_kit_out_with_its_line_and_the_others_stay() -> void:
	var pool := Pool.read_file()
	var text := KIT_HEADER + "| Mixed | 000002 | | | | | Indors | 1 | 1 | 1 |\n" \
			+ "| Upper | 000002 | | | | | INDOOR | 1 | 1 | 1 |\n" \
			+ "| Any | 000002 | | | | | | 1 | 1 | 1 |\n"
	var kits := BotKits.parse(text, pool, BotKits.personalities())
	assert_eq(kits.problems.size(), 1, "one problem: %s" % [kits.problems])
	assert_string_contains(kits.problems[0], "Indors")
	assert_eq(kits.kits.size(), 2, "the unreadable row is left out, the rest read")
	assert_eq(kits.kits[0].fields, BotKits.INDOOR, "case does not matter")
	assert_eq(kits.kits[1].fields, &"", "an empty cell is every field")


func test_a_kit_table_without_a_fields_column_is_carried_on_every_field() -> void:
	var pool := Pool.read_file()
	var text := "## Kits\n\n| Kit | Primary | Primary parts | Secondary | Secondary parts | Suits | Easy | Normal | Hard |\n|---|---|---|---|---|---|---|---|---|\n| A | 000002 | | | | | 1 | 1 | 1 |\n"
	var kits := BotKits.parse(text, pool, BotKits.personalities())
	assert_eq(kits.problems, [] as Array[String])
	for kind: StringName in [&"", BotKits.INDOOR, BotKits.OUTDOOR]:
		assert_true(kits.kits[0].fits_field(kind), "field %s" % kind)


func test_the_clearer_is_never_picked_on_an_outdoor_field_by_any_seed() -> void:
	var pool := Pool.read_file()
	var kits := BotKits.read_file(pool)
	var rules := LoadoutRules.new(pool, ReplicaStats.read_file(), ReplicaRulesConfig.new())
	rules.dev_content = true
	for seed_value in 300:
		for level: StringName in [&"easy", &"normal", &"hard"]:
			var plan := kits.pick(level, rules, seed_value, &"rusher", 1.0, BotKits.OUTDOOR)
			if plan != null:
				assert_ne(plan.kit_name, "Clearer", "seed %d at %s" % [seed_value, level])


# --- Staged loading (4ff2160, 79a45c6): left at each stage, and twice in a row ---


func _staged(map_id: String) -> PlaySession:
	var session := PlaySession.new()
	session.settings = Settings.new(PlayTuning.new())
	session.map_id = map_id
	session.match_seed = 7
	session.autopilot = true
	session.staged = true
	add_child(session)
	return session


func _reached(session: PlaySession, stage: int) -> bool:
	match stage:
		0:
			return session._step == PlaySession.LEVEL_STEP
		1:
			return session._step == PlaySession.VIEWS_STEP and session._views_piece == PlaySession.VIEWS_FIGURES
		2:
			return session._step == PlaySession.VIEWS_STEP and session._views_piece == PlaySession.VIEWS_BODIES
		3:
			return session._step == PlaySession.VIEWS_STEP and session._views_piece == PlaySession.VIEWS_REST
	return session._bots != null


func test_a_load_left_at_any_stage_leaves_no_node_task_or_kept_parts_file_behind() -> void:
	# A first load and leave, so what the game keeps for good (caches) is not counted as left behind.
	var warm := _staged("depot")
	await wait_process_frames(3)
	warm.free()
	await wait_process_frames(2)
	var leaks: Array[String] = []
	for stage in 5:
		var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		var orphans := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
		var session := _staged("depot")
		var frames := 0
		var until := Time.get_ticks_msec() + LOAD_WAIT_MSEC
		while Time.get_ticks_msec() < until and not _reached(session, stage):
			await wait_process_frames(1)
			frames += 1
		assert_true(_reached(session, stage), "stage %d reached (frames %d step %d piece %d)" % [stage, frames, session._step, session._views_piece])
		session.leave_loading()
		session.free()
		await wait_process_frames(2)
		if Performance.get_monitor(Performance.OBJECT_NODE_COUNT) != nodes:
			leaks.append("stage %d nodes %d -> %d" % [stage, nodes, Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
		if Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT) != orphans:
			leaks.append("stage %d orphans %d -> %d" % [stage, orphans,
					Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)])
		assert_false(ReplicaParts._keeping, "stage %d: no parts file is held after leaving" % stage)
		assert_true(ReplicaParts._kept.is_empty(), "stage %d: none kept" % stage)
	assert_eq(leaks, [] as Array[String], "nothing left behind at any stage")


func test_a_load_left_at_the_woods_pieces_leaves_nothing_behind() -> void:
	var warm := _staged("woodland")
	await wait_process_frames(3)
	warm.free()
	await wait_process_frames(2)
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var orphans := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var session := _staged("woodland")
	var frames := 0
	var until := Time.get_ticks_msec() + LOAD_WAIT_MSEC
	# After the wood's first piece and before it joins the tree, the case 79a45c6 fixed, then a second load on top.
	while Time.get_ticks_msec() < until and (session._woods == null or session._woods.is_inside_tree()):
		await wait_process_frames(1)
		frames += 1
	session.free()
	await wait_process_frames(2)
	var again := _staged("woodland")
	await wait_process_frames(30)
	again.free()
	await wait_process_frames(2)
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes, "no node left")
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), orphans, "no orphan left")
