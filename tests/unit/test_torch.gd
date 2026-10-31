extends GutTest
## The weapon torch (WL7; the browser game's sim/torch.test.ts, torchRounds.test.ts, ai/botTorch.test.ts and
## map/torchLight.test.ts): the Light slot and its saving, the torch fitted only at night, switched through the command
## with an event (T), out when holstered, on a replica without one, when hit and at each round start; every bot carrying
## one at night and working it by what it does with a minimum hold; what a lit beam shows the bots and gives away; a
## day kit with a torch playing exactly as one without; and how torches are drawn (your own a real spot on Medium up,
## shadows on High and Ultra, a haze on Low; everyone else's three instanced draws).

const DT := 1.0 / 60.0
const KILL_Y := -10.0
const LOADOUTS := "user://test_wl7_loadouts.save"
const SETTINGS := "user://test_wl7_settings.save"
const AEG := "000002"
const PISTOL := "000001"
const CYBER := "000019"
const TORCH := "000020"

var tuning: SimTuning = SimTuning.load_default()
var cfg: BotConfig = BotConfig.load_default()
var stats: ReplicaStats = ReplicaStats.read_file()


func after_each() -> void:
	SaveFile.remove(LOADOUTS)
	SaveFile.remove(SETTINGS)


func _rules(dev: bool) -> LoadoutRules:
	var r := LoadoutRules.standard()
	r.dev_content = dev
	return r


func _light() -> Torch.Light:
	return Torch.Light.of(&"weaponTorch", stats.parts.part(&"light", &"weaponTorch"))


# --- the Light slot ---

func test_the_lights_table_is_a_part_slot_with_its_stats() -> void:
	var pool := Pool.shared()
	var torch := pool.item(TORCH)
	assert_not_null(torch, "the Weapon Torch is a part now, no longer waiting")
	assert_eq(torch.slot, Pool.LIGHT_SLOT)
	assert_false(torch.is_dev(), "public with Woodland (owner, 2026-10-29)")
	assert_true(pool.waiting.is_empty())
	var row := stats.parts.part(&"light", &"weaponTorch")
	assert_eq([row.reach, row.beam, row.spill], [40.0, 14.0, 28.0], "stats.md › Lights")
	assert_true(stats.parts.problems.is_empty(), "stats.md reads: %s" % [stats.parts.problems])


func test_offered_on_the_replicas_it_fits_and_a_dev_one_only_with_dev_content() -> void:
	var was := DevContent.use_item(TORCH)
	assert_true(_rules(false).parts_for(AEG, &"light").is_empty(), "a dev torch: not offered with Dev content off")
	assert_eq(_rules(true).parts_for(AEG, &"light").size(), 1, "and offered with it on")
	DevContent.restore_item(was)
	var rules := _rules(false)
	assert_eq(rules.parts_for(AEG, &"light").size(), 1, "the rifle takes it")
	assert_eq(rules.parts_for(PISTOL, &"light").size(), 1, "the pistol's rail takes it")
	assert_eq(rules.parts_for(CYBER, &"light").size(), 1, "the Cyber Pistol takes it too (RM8 made its torch)")


func test_saved_with_the_loadout_and_a_save_from_before_loads() -> void:
	var saved := SavedLoadouts.new(_rules(true))
	assert_true(saved.rules.set_part(saved.carried(), AEG, &"light", TORCH))
	saved.mark_changed()
	assert_true(saved.save(LOADOUTS))
	var back := SavedLoadouts.new(_rules(true))
	back.load_file(LOADOUTS)
	assert_eq(back.rules.tune_of(back.carried(), AEG).parts[&"light"], TORCH, "saved with the loadout")
	var older := ReplicaTune.from_dict({"bb_weight": 0.28, "parts": {"optic": "000007"}}, ReplicaTune.new())
	assert_false(older.parts.has(&"light"), "a setup saved before the Light slot loads, no light")
	assert_eq(older.parts[&"optic"], "000007")


func test_fitted_only_at_night_a_day_kit_carries_no_light() -> void:
	var rules := _rules(true)
	var l := rules.default_loadout("Night")
	rules.set_part(l, AEG, &"light", TORCH)
	var kit := rules.carried(l)
	assert_false(kit.dev)
	assert_false(kit.light_dev, "the torch is public")
	assert_false(kit.dev_under(true), "a night match with it stays on the record")
	assert_eq(kit.parts[0][&"light"], &"weaponTorch", "the models' part keys still list it")
	assert_false(kit.parts_under(false)[0].has(&"light"), "by day the hands show no torch")
	assert_true(kit.parts[0].has(&"light"), "a copy: the kit's own keys keep it")
	assert_eq(kit.parts_under(true)[0][&"light"], &"weaponTorch", "at night they do")
	assert_true(kit.lights_for(false).is_empty(), "by day: not fitted")
	var night := kit.lights_for(true)
	assert_eq(night.size(), 2)
	assert_eq(night[0].reach, 40.0)
	assert_null(night[1], "the pistol has none fitted")
	var a := Armament.create(kit.replicas, kit.bb_weights)
	a.lights = kit.lights_for(false)
	assert_null(a.light_in_hand())


func test_every_bot_carries_the_offered_torch_at_night_never_in_a_kit() -> void:
	var was := DevContent.use_item(TORCH)
	assert_null(BotKits.night_light(_rules(false)), "a dev torch only with Dev content on")
	DevContent.restore_item(was)
	var rules := _rules(false)
	var light := BotKits.night_light(rules)
	assert_eq(light.id, TORCH)
	var lights := BotKits.lights_for(ReplicaStats.default_loadout(), rules, light)
	assert_eq(lights.size(), 2)
	assert_not_null(lights[0], "on the rifle")
	assert_not_null(lights[1], "on the pistol")
	var cyber: Array[ReplicaConfig] = [rules.config(rules.pool.item(CYBER))]
	assert_not_null(BotKits.lights_for(cyber, rules, light)[0], "on the Cyber Pistol")
	var unknown := ReplicaConfig.new()
	unknown.id = "noSuchReplica"
	var none: Array[ReplicaConfig] = [unknown]
	assert_null(BotKits.lights_for(none, rules, light)[0], "none on a replica the pool doesn't know")


# --- switching it ---

class Field:
	extends RefCounted
	var sim: Simulation
	var state: GameState
	var cmds: Array[PlayerCommand] = []
	var torch_events: int = 0
	var last_on: int = -1


func _field(lights: Array[Torch.Light]) -> Field:
	var f := Field.new()
	var w := BoxWorld.new(tuning.body)
	w.add_floor(200.0, 200.0)
	var ends: Array[MapEnd] = []
	for e in 2:
		var end := MapEnd.new()
		end.spawns.append(SpawnPoint.new(Vector3(-60.0 if e == 0 else 60.0, 0.0, 0.0), 0.0))
		end.dead_zone.append(SpawnPoint.new(Vector3(-70.0 if e == 0 else 70.0, 0.0, 40.0), 0.0))
		ends.append(end)
	f.sim = Simulation.new(tuning, w, w.mover(), ends, KILL_Y)
	f.state = GameState.new(3, tuning)
	for i in 2:
		var c := Character.new(i, i, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
		c.armament.lights = lights.duplicate()
		f.state.characters.append(c)
		f.cmds.append(PlayerCommand.new())
	f.sim.start_match(f.state)
	_run(f, 10)
	return f


func _tick(f: Field, fill: Callable = Callable()) -> void:
	for i in f.cmds.size():
		f.cmds[i].reset(f.state.characters[i].yaw, f.state.characters[i].pitch)
	if fill.is_valid():
		fill.call(f.cmds[0])
	f.sim.step(f.state, f.cmds, DT)
	var e := f.state.events.first(GameEvent.Kind.TORCH)
	if e != null:
		f.torch_events += f.state.events.count_of(GameEvent.Kind.TORCH)
		f.last_on = e.value
		assert_eq(e.actor, 0)


func _run(f: Field, n: int, fill: Callable = Callable()) -> void:
	for i in n:
		_tick(f, fill)


func _toggle(f: Field) -> void:
	_tick(f, func(cmd: PlayerCommand) -> void: cmd.toggle_torch = true)


func test_the_command_switches_it_with_an_event_both_ways() -> void:
	var f := _field([_light(), null])
	var me := f.state.characters[0]
	assert_false(me.torch_on, "off to start")
	_toggle(f)
	assert_true(Torch.lit(me))
	assert_eq([f.torch_events, f.last_on], [1, 1])
	_run(f, 30)
	assert_almost_eq(me.torch_time, 30 * DT, 1e-6, "the time since its switch")
	_toggle(f)
	assert_false(me.torch_on)
	assert_eq([f.torch_events, f.last_on], [2, 0])


func test_nothing_switches_without_a_light_in_hand() -> void:
	var f := _field([])
	_toggle(f)
	assert_false(f.state.characters[0].torch_on)
	assert_eq(f.torch_events, 0, "no click")


func test_it_goes_out_when_holstered_and_stays_out_drawn_again() -> void:
	var f := _field([_light(), _light()])
	var me := f.state.characters[0]
	_toggle(f)
	_tick(f, func(cmd: PlayerCommand) -> void: cmd.holster = true)
	assert_false(me.torch_on, "out with the replica away")
	assert_eq([f.torch_events, f.last_on], [2, 0], "the thumb's click as it goes")
	_tick(f, func(cmd: PlayerCommand) -> void: cmd.switch_to = 0)
	_run(f, 60)
	assert_false(Torch.lit(me), "drawn again, it needs a press")


func test_switching_to_a_replica_without_one_puts_it_out() -> void:
	var f := _field([_light(), null])
	var me := f.state.characters[0]
	_toggle(f)
	_tick(f, func(cmd: PlayerCommand) -> void: cmd.switch_to = 1)
	assert_false(me.torch_on)
	_toggle(f)
	assert_false(me.torch_on, "the pistol has none to switch")


func test_out_when_hit_and_off_at_each_round_start() -> void:
	var f := _field([_light(), null])
	var me := f.state.characters[0]
	_toggle(f)
	Elimination.eliminate(me, 1, f.state.characters, f.sim.ends)
	_tick(f)
	assert_false(me.torch_on, "the hand goes up, the torch goes out")
	assert_false(Torch.lit(me))
	var them := f.state.characters[1]
	them.torch_on = true
	them.respawn()
	assert_false(them.torch_on, "a new round starts with it off")
	assert_eq(them.torch_time, 0.0)


# --- what the bots see by it ---

func _world(characters: Array[Character], query: WorldQuery) -> BotWorld:
	var w := BotWorld.new()
	w.tuning = tuning
	w.cfg = cfg
	w.query = query
	w.planner = RoundPlanner.new(1)
	w.characters = characters
	w.time = 10.0
	w.night = NightField.build(MapData.parse('{"blocks": [{"kind": "floor", "center": {"x": 0, "y": -0.25, "z": 0}, '
			+ '"size": {"x": 200, "y": 0.5, "z": 200}}], "spawns": [[], []], "deadZones": [[], []]}', MapStyle.new(),
			0), cfg, true)
	return w


func _person(id: int, team: int, at: Vector3, facing_to: Vector3, torch_on: bool) -> Character:
	var c := Character.new(id, team, at, BotAim.look_yaw(at, facing_to), ReplicaStats.default_loadout())
	c.armament.lights = [_light(), null]
	c.torch_on = torch_on
	return c


func test_a_beam_lights_whoever_is_in_its_spill_within_its_reach() -> void:
	var holder := _person(0, 0, Vector3.ZERO, Vector3(0.0, 0.0, -10.0), true)
	var inside := _person(1, 1, Vector3(0.0, 0.0, -35.0), Vector3.ZERO, false)
	var edge := _person(2, 1, Vector3(-10.0, 0.0, -20.0), Vector3.ZERO, false)
	var beyond := _person(3, 1, Vector3(0.0, 0.0, -45.0), Vector3.ZERO, false)
	var walled := _person(4, 1, Vector3(5.0, 0.0, -30.0), Vector3.ZERO, false)
	var box := BoxWorld.new(tuning.body)
	box.add_box(Vector3(5.0, 1.0, -25.0), Vector3(2.0, 2.0, 0.5))
	var w := _world([holder, inside, edge, beyond, walled], box)
	BotTorch.refresh(w)
	var lit := w.night.torch_lit
	assert_eq(lit[1], 1, "35 m down the beam")
	assert_eq(lit[2], 0, "26.6° off its middle: outside the 28° spill")
	assert_eq(lit[3], 0, "45 m: beyond its 40 m reach")
	assert_eq(lit[4], 0, "a wall between")
	assert_eq(lit[0], 0, "never its own holder")
	holder.torch_on = false
	w.time += cfg.think_interval
	BotTorch.refresh(w)
	assert_eq(w.night.torch_lit[1], 0, "worked out again each look: off, nobody lit")


func test_bots_make_out_whoever_a_beam_lights_and_a_lit_torch_pointed_their_way() -> void:
	var box := BoxWorld.new(tuning.body)
	var viewer := _person(0, 0, Vector3.ZERO, Vector3(0.0, 0.0, -35.0), false)
	var foe := _person(1, 1, Vector3(0.0, 0.0, -35.0), Vector3(20.0, 0.0, -35.0), false)
	var w := _world([viewer, foe], box)
	BotTorch.refresh(w)
	assert_eq(BotSenses.visible_part(viewer, foe, w), 0.0, "35 m in the moonlit open: not made out")
	viewer.torch_on = true
	w.time += cfg.think_interval
	BotTorch.refresh(w)
	assert_gt(BotSenses.visible_part(viewer, foe, w), 0.0, "in the viewer's beam: made out from 40 m")
	viewer.torch_on = false
	foe.torch_on = true
	foe.yaw = BotAim.look_yaw(foe.position, foe.position + Vector3(-sin(deg_to_rad(50.0)), 0.0,
			cos(deg_to_rad(50.0))) * 10.0)
	w.time += cfg.think_interval
	BotTorch.refresh(w)
	assert_gt(BotSenses.visible_part(viewer, foe, w), 0.0, "its torch pointed 50° off the viewer gives it away")
	foe.yaw = BotAim.look_yaw(foe.position, foe.position + Vector3(-sin(deg_to_rad(70.0)), 0.0,
			cos(deg_to_rad(70.0))) * 10.0)
	assert_eq(BotSenses.visible_part(viewer, foe, w), 0.0, "70° off: not")
	assert_eq(w.night.torch_range(viewer, foe), 0.0)


func test_the_torch_light_allocates_nothing_once_sized() -> void:
	var people: Array[Character] = []
	for i in 12:
		people.append(_person(i, i % 2, Vector3(i * 3.0, 0.0, -i * 2.0), Vector3(0.0, 0.0, -40.0), true))
	var w := _world(people, BoxWorld.new(tuning.body))
	BotTorch.refresh(w)
	var objects := Performance.get_monitor(Performance.OBJECT_COUNT)
	var started := Time.get_ticks_usec()
	for k in 200:
		w.time += cfg.think_interval
		BotTorch.refresh(w)
		for v in people:
			w.night.range_between(v, people[0])
	var each := float(Time.get_ticks_usec() - started) / 200.0
	var made := Performance.get_monitor(Performance.OBJECT_COUNT) - objects
	gut.p("the torch light for 12 lit torches: %.0f µs a look" % each)
	assert_eq(made, 0.0, "no object made")


# --- how bots work it ---

func _bot(level: StringName, w: BotWorld) -> Bot:
	var b := Bot.new(w.characters[0], 1, cfg.skill_for(level), 2)
	w.bots = [b]
	return b


func test_bots_switch_it_by_what_they_do() -> void:
	var me := _person(0, 0, Vector3.ZERO, Vector3(0.0, 0.0, -10.0), false)
	var foe := _person(1, 1, Vector3(0.0, 0.0, -15.0), Vector3.ZERO, false)
	var w := _world([me, foe], BoxWorld.new(tuning.body))
	var b := _bot(&"easy", w)
	w.live = true
	b.mode = Bot.Mode.FIGHT
	b.target_id = 1
	assert_true(BotTorch.wants_torch(b, w, 20.0), "fighting someone 15 m off")
	foe.position = Vector3(0.0, 0.0, -25.0)
	assert_false(BotTorch.wants_torch(b, w, 20.0), "not someone 25 m off: a beam only gives it away")
	b.mode = Bot.Mode.SEARCH
	b.last_known = Vector3(0.0, 0.0, -5.0)
	assert_true(BotTorch.wants_torch(b, w, 20.0), "the last stretch of a search")
	b.last_known = Vector3(0.0, 0.0, -50.0)
	assert_false(BotTorch.wants_torch(b, w, 20.0), "on its way to one")
	for mode: Bot.Mode in [Bot.Mode.ADVANCE, Bot.Mode.COVER, Bot.Mode.FLAG, Bot.Mode.ORDER]:
		b.mode = mode
		assert_false(BotTorch.wants_torch(b, w, 20.0), "off: %s" % Bot.Mode.keys()[mode])
	# Every level alike since TL1: the old Easy, that kept it on while advancing, is gone.
	for level: StringName in [&"easy", &"normal", &"hard"]:
		var other := _bot(level, w)
		other.mode = Bot.Mode.ADVANCE
		assert_false(BotTorch.wants_torch(other, w, 20.0), "%s: off while advancing" % level)
	b.mode = Bot.Mode.FIGHT
	foe.position = Vector3(0.0, 0.0, -15.0)
	w.live = false
	assert_false(BotTorch.wants_torch(b, w, 20.0), "off between rounds")


func test_a_bot_holds_each_state_its_minimum_no_strobing_and_never_by_day() -> void:
	var me := _person(0, 0, Vector3.ZERO, Vector3(0.0, 0.0, -10.0), false)
	var foe := _person(1, 1, Vector3(0.0, 0.0, -15.0), Vector3.ZERO, false)
	var w := _world([me, foe], BoxWorld.new(tuning.body))
	w.live = true
	var b := _bot(&"easy", w)
	b.mode = Bot.Mode.FIGHT
	b.target_id = 1
	var cmd := PlayerCommand.new()
	me.torch_time = cfg.torch_min_hold - 0.1
	BotTorch.step(b, w, cmd)
	assert_false(cmd.toggle_torch, "its last switch was too recent")
	me.torch_time = cfg.torch_min_hold
	BotTorch.step(b, w, cmd)
	assert_true(cmd.toggle_torch, "held long enough: on")
	me.torch_on = true
	me.torch_time = 0.0
	b.mode = Bot.Mode.COVER
	BotTorch.step(b, w, cmd)
	assert_false(cmd.toggle_torch, "into cover a moment later: it waits out the hold")
	w.night = null
	me.torch_time = 10.0
	BotTorch.step(b, w, cmd)
	assert_false(cmd.toggle_torch, "by day (no night field) it never presses")


func test_a_day_kit_with_a_torch_plays_exactly_as_one_without() -> void:
	var depot := MatchRunner.new(self, "depot")
	assert_false(depot.night, "Depot plays by day")
	depot.lights = MatchRunner.Lights.NONE
	var bare := depot.play(11, 150.0)
	depot.lights = MatchRunner.Lights.ALWAYS
	var lit := depot.play(11, 150.0)
	depot.free_level()
	assert_eq([lit.ticks, lit.hits, lit.rounds.size()], [bare.ticks, bare.hits, bare.rounds.size()],
			"the same match, tick for tick")
	assert_eq(lit.hits_by, bare.hits_by)


func test_a_5v5_night_match_on_woodland_works_the_torches_without_strobing() -> void:
	var t := SimTuning.load_default().duplicate() as SimTuning
	t.rounds = t.rounds.duplicate() as RoundConfig
	t.rounds.team_size = 5
	t.rounds.wins_needed = 2
	t.rounds.half_time_after = 1
	var woodland := MatchRunner.new(self, "woodland", t)
	woodland.night = true # Woodland by night (its second preset since WR1)
	var watch := {"on": 0, "off": 0, "fast": 0, "lit_at_start": 0, "sampled": 0, "beyond": 0, "by_torch": 0,
			"most_lit": 0}
	var last_switch: Dictionary[int, float] = {}
	woodland.each_tick = func(state: GameState, bots: BotController) -> void:
		for i in state.events.count:
			var e := state.events.items[i]
			if e.kind == GameEvent.Kind.ROUND_START:
				for c in state.characters:
					watch.lit_at_start += 1 if c.torch_on else 0
			if e.kind != GameEvent.Kind.TORCH:
				continue
			watch.on += e.value
			watch.off += 1 - e.value
			var c := state.character(e.actor)
			if last_switch.has(e.actor) and state.time - last_switch[e.actor] < cfg.torch_min_hold - 1e-6 \
					and Elimination.is_in_play(c) and not c.armament.holstered:
				watch.fast += 1
			last_switch[e.actor] = state.time
		var lit := 0
		for c in state.characters:
			lit += 1 if Torch.lit(c) else 0
		watch.most_lit = maxi(watch.most_lit, lit)
		var field := bots.world.night
		for b in bots.world.bots:
			if not b.target_visible or not Elimination.is_in_play(b.character):
				continue
			var other := state.character(b.target_id)
			var dist := Vector2(other.position.x - b.character.position.x,
					other.position.z - b.character.position.z).length()
			watch.sampled += 1
			if dist > field.sight_range(other.position) + 0.6 and dist > cfg.close_awareness:
				watch.by_torch += 1
			# A torch seen up to a look ago: no further than the lit range plus what either moved meanwhile.
			if dist > minf(cfg.view_distance, field.lit) + 1.5 and dist > cfg.close_awareness:
				watch.beyond += 1
	var tally := woodland.play(5, 420.0)
	woodland.each_tick = Callable()
	woodland.free_level()
	gut.p("Woodland 5v5 at night with torches: %d rounds in %.0f s, %d hits; torches on %d, off %d times, at most %d lit at once; %d of %d sightings by torchlight"
			% [tally.rounds.size(), tally.ticks * DT, tally.hits, watch.on, watch.off, watch.most_lit, watch.by_torch,
			watch.sampled])
	assert_gt(watch.on, 0, "the bots switch their torches on")
	assert_eq(watch.fast, 0, "no switch inside the minimum hold: no strobing")
	assert_eq(watch.lit_at_start, 0, "every torch off as a round starts")
	assert_eq(watch.beyond, 0, "no target seen beyond the lit range")
	assert_gt(tally.hits, 0, "BBs land")


# --- input ---

func test_t_is_the_weapon_torch_key_and_rebindable() -> void:
	var keys := KeyBindings.new()
	assert_has(KeyBindings.ACTIONS, &"torch")
	assert_eq(Array(keys.codes(&"torch")), [KEY_T])
	assert_eq(TranslationServer.translate(KeyBindingList.label_key(&"torch")), "WEAPON TORCH")
	assert_eq(keys.rebind(&"torch", KEY_J), KeyBindings.Result.BOUND, "a free key (G throws smoke since SF1)")
	var older := KeyBindings.new()
	older.load_dict({"reload": [KEY_R]})
	assert_eq(Array(older.codes(&"torch")), [KEY_T], "a settings file from before it keeps the default")
	var taken := KeyBindings.new()
	taken.load_dict({"reload": [KEY_T]})
	assert_true(taken.codes(&"torch").is_empty(), "left keyless where the player's own keys hold T")


func test_the_key_fills_the_command_once() -> void:
	var input := PlayerInput.new()
	input.setup(ControlsConfig.new(), 1.5)
	add_child_autofree(input)
	input.active = true
	var e := InputEventAction.new()
	e.action = &"torch"
	e.pressed = true
	input._unhandled_input(e)
	var cmd := PlayerCommand.new()
	input.fill(cmd)
	assert_true(cmd.toggle_torch, "a press")
	input.fill(cmd)
	assert_false(cmd.toggle_torch, "once")


# --- how it is drawn ---

func test_your_torch_is_a_real_spot_from_medium_with_shadows_from_high_and_a_haze_on_low() -> void:
	var night := PlayTuning.load_default().night_lighting
	var table := GraphicsTable.shared()
	var modes: Array[TorchBeams.Mode] = []
	var pools: Array[int] = []
	for preset: StringName in [&"low", &"medium", &"high", &"ultra"]:
		var q := table.preset(preset)
		assert_eq(GraphicsApply.torch_mode(q, night, false), TorchBeams.Mode.HAZE, "none fitted: %s" % preset)
		modes.append(GraphicsApply.torch_mode(q, night, true))
		pools.append(GraphicsApply.pool_lights(q, night, true))
	assert_eq(modes, [TorchBeams.Mode.HAZE, TorchBeams.Mode.SPOT, TorchBeams.Mode.SHADOWED,
			TorchBeams.Mode.SHADOWED] as Array[TorchBeams.Mode])
	assert_eq(pools, [0, 1, 3, 3] as Array[int], "the torch is one of the preset's real lights")
	assert_eq(GraphicsApply.pool_lights(table.preset(&"high"), night, false), 4, "none fitted: the pools have all")
	var no_sun := table.preset(&"ultra")
	no_sun.sun_shadows = false
	assert_eq(GraphicsApply.torch_mode(no_sun, night, true), TorchBeams.Mode.SPOT, "Sun shadows off: no torch shadow")
	assert_eq(GraphicsApply.pool_lights(no_sun, night, true), 3, "still one real light for it")


func test_the_pools_give_your_torch_a_real_light_only_when_you_carry_one_and_for_the_whole_match() -> void:
	var medium := GraphicsTable.shared().preset(&"medium")
	var real := PlayTuning.load_default().night_lighting.real_lights_for(medium.mesh_detail)
	var settings := Settings.new()
	settings.dev.dev_content = true
	var bare := PlaySession.new()
	bare.map_id = "woodland"
	bare.lighting_pick = LightingConfig.NIGHT
	bare.settings = settings
	bare.bots_active = false
	add_child_autofree(bare)
	bare._apply_graphics(medium)
	assert_eq(bare.light_pools().real_lights().size(), real, "no light in your kit: the pools keep all")
	assert_null(bare._eyes.torch(), "and no spot is made")
	var rules := _rules(true)
	var l := rules.default_loadout("Night")
	rules.set_part(l, AEG, &"light", TORCH)
	var fitted := PlaySession.new()
	fitted.map_id = "woodland"
	fitted.lighting_pick = LightingConfig.NIGHT
	fitted.settings = settings
	fitted.kit = rules.carried(l)
	fitted.bots_active = false
	add_child_autofree(fitted)
	fitted._apply_graphics(medium)
	var pools := fitted.light_pools()
	assert_eq(pools.real_lights().size(), real - 1, "your torch takes one")
	for on: bool in [true, false, true]:
		fitted.player.torch_on = on
		await wait_process_frames(2)
		pools.update(Vector3(-50.0, 2.0, -10.0), 0.05)
		assert_eq(pools.real_lights().size(), real - 1, "lit or not: the pools never flicker")


func test_the_view_s_spot_follows_the_torch_and_its_mode() -> void:
	var eyes := FirstPersonView.new()
	add_child_autofree(eyes)
	eyes.setup(ViewConfig.new(), tuning.body, tuning.hits)
	var input := PlayerInput.new()
	add_child_autofree(input)
	var c := _person(0, 0, Vector3.ZERO, Vector3(0.0, 0.0, -10.0), false)
	eyes.set_torch(TorchBeams.Mode.SHADOWED)
	var spot := eyes.torch()
	assert_not_null(spot)
	assert_true(spot.shadow_enabled, "shadows on High and Ultra")
	eyes.update(c, input, 1.0, DT, c.aim_raise)
	assert_false(spot.visible, "off")
	c.torch_on = true
	eyes.update(c, input, 1.0, DT, c.aim_raise)
	assert_true(spot.visible, "lit")
	assert_eq(spot.spot_range, 40.0)
	assert_almost_eq(spot.spot_angle, 14.0, 1e-4, "its spill's half angle")
	eyes.set_torch(TorchBeams.Mode.SPOT)
	assert_eq(eyes.torch(), spot, "kept")
	assert_false(spot.shadow_enabled, "no shadows on Medium")
	eyes.set_torch(TorchBeams.Mode.HAZE)
	assert_null(eyes.torch(), "Low: none")
	await wait_process_frames(1)
	assert_false(is_instance_valid(spot), "freed")


func test_everyone_else_s_torches_are_three_instanced_draws() -> void:
	var box := BoxWorld.new(tuning.body)
	box.add_floor(200.0, 200.0)
	var people: Array[Character] = []
	for i in 6:
		var c := _person(i, i % 2, Vector3(i * 2.0, 0.0, 0.0), Vector3(i * 2.0, 0.0, -10.0), i > 0)
		c.pitch = -0.1 # a little down: the beam lands on the floor about 13 m off
		people.append(c)
	var beams := TorchBeams.new()
	add_child_autofree(beams)
	beams.setup(people.size(), box, tuning.body)
	var cam := Camera3D.new()
	add_child_autofree(cam)
	cam.position = Vector3(0.0, 1.6, 0.0)
	var figures: Array[FigureView] = []
	figures.resize(people.size())
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	beams.update(people, people[0], 1.0, figures, cam)
	assert_eq(beams.draws().size(), 3)
	assert_eq(beams.lit_count(), 5, "every lit torch but the view's own")
	var cones := beams.draws()[0].multimesh
	assert_eq(cones.visible_instance_count, 5)
	assert_eq(beams.draws()[1].multimesh.visible_instance_count, 5, "a glare on each lens")
	assert_eq(beams.draws()[2].multimesh.visible_instance_count, 5, "a spot where each beam lands")
	people[0].torch_on = true
	beams.set_own_haze(true)
	beams.update(people, people[0], 1.0, figures, cam)
	assert_eq(beams.lit_count(), 6, "on Low your own is drawn too, as a haze")
	assert_eq(beams.draws()[1].multimesh.visible_instance_count, 5, "with no glare of its own")
	for c in people:
		c.torch_on = false
	beams.update(people, people[0], 1.0, figures, cam)
	assert_eq(beams.lit_count(), 0)
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes, "no node made while drawing")


func test_the_torch_light_is_off_every_team_s_hue() -> void:
	var teams := AccessibilityTable.read_file().colours
	assert_gte(FieldChecks.hue_gap(TorchBeams.COLOUR, teams), FieldStandard.HUE_MARGIN_DEG,
			"#%s" % TorchBeams.COLOUR.to_html(false))


func test_the_click_is_a_cue() -> void:
	assert_true(ResourceLoader.exists("%storchClick_1.wav" % SoundConfig.CUE_DIR), "rendered from the browser's recipe")


# --- Customise's Light slot ---

var _saved: SavedLoadouts = null


func _customise(dev: bool) -> CustomiseView:
	_saved = SavedLoadouts.new(_rules(dev))
	var settings := Settings.new()
	settings.dev.dev_content = dev
	var page := LoadoutPage.new(_saved, settings)
	page.save_path = LOADOUTS
	page.settings_path = SETTINGS
	add_child_autofree(page)
	page.show_customise(0)
	return page.customise()


func test_customise_offers_the_light_slot_and_a_dev_one_stays_later_without_dev_content() -> void:
	var was := DevContent.use_item(TORCH)
	var off := _customise(false)
	DevContent.restore_item(was)
	assert_true(off.part_later(CustomiseView.Tab.LIGHT), "a dev torch: LIGHT stays LATER")
	assert_false(off.part_card(CustomiseView.Tab.LIGHT).visible)
	assert_eq(off.later_count(), 2, "the laser greyed and the light LATER")
	var view := _customise(false)
	assert_false(view.part_later(CustomiseView.Tab.LIGHT))
	assert_true(view.part_available(CustomiseView.Tab.LIGHT), "the rifle takes it")
	view.show_tab(CustomiseView.Tab.LIGHT)
	var page := view.part_page(CustomiseView.Tab.LIGHT)
	assert_eq(page.card_count(), 2, "none, and the Weapon Torch")
	page.card(1).pressed.emit()
	assert_eq(_saved.rules.tune_of(_saved.carried(), AEG).parts[&"light"], TORCH, "fitted to the loadout")
	assert_eq(view.part_sub_text(CustomiseView.Tab.LIGHT), "Weapon Torch")
