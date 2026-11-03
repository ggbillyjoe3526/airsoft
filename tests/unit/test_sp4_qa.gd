extends GutTest
## SP4's QA pass (kit rustle, landings, the whistle, the ambience calls): what the worker's own tests leave open. A
## rustle muffled through a wall, a rustle heard from the ears the view moves to, the calls timed afresh for a rematch
## and not again every tick, every shipped map's ambience loading and sounding, and a busy tick (landing, rustles,
## whistle, a call) making no node or voice.

var cfg: SoundConfig = null
var body: BodyConfig = BodyConfig.new()
var world: BoxWorld = null
var audio: SimAudio = null
var state: GameState = null
var you: Character = null
var other: Character = null


func before_all() -> void:
	cfg = (load("res://game/config/play_tuning.tres") as PlayTuning).sound.duplicate() as SoundConfig


func before_each() -> void:
	for spread: String in ["shot_spread_db", "mechanism_spread_db", "step_spread_db", "vault_spread_db",
			"impact_spread_db", "hit_spread_db", "foley_spread_db"]:
		cfg.set(spread, 0.0)
	world = BoxWorld.new(body)
	state = GameState.new(9)
	you = Character.new(0, 0, Vector3.ZERO)
	other = Character.new(1, 1, Vector3(0.0, 0.0, 7.0))
	state.characters.append(you)
	state.characters.append(other)


func _sound(map: MapData = null) -> void:
	audio = SimAudio.new()
	add_child_autofree(audio)
	audio.setup(cfg, [] as Array[StringName], body, world, map)


## `c` starts leaning out this tick (its lean was upright a tick before).
func _lean_out(c: Character) -> void:
	c.prev_lean = 0.0
	c.lean = 0.5


func _bus_of(cue: StringName) -> StringName:
	for v in audio._field:
		if v.playing and (audio._streams[cue] as Array).has(v.stream):
			return StringName(v.bus)
	return &""


## Others' rustle is muffled by the level between it and your eyes, as every sound another character makes is (SP2).
func test_a_rustle_behind_a_wall_is_muffled_and_in_the_open_it_is_not() -> void:
	_sound()
	audio.on_tick(state, 0, you)
	_lean_out(other)
	state.time += 1.0 / 60.0
	audio.on_tick(state, 0, you)
	assert_eq(_bus_of(&"foley_lean"), SimAudio.BUS_FOOTSTEPS, "in the open")
	world.add_box(Vector3(0.0, 1.5, 3.5), Vector3(6.0, 3.0, 0.4))
	var walled := SimAudio.new()
	add_child_autofree(walled)
	walled.setup(cfg, [] as Array[StringName], body, world, null)
	audio = walled
	other.lean = 0.0
	other.prev_lean = 0.0
	walled.on_tick(state, 0, you)
	_lean_out(other)
	state.time += 1.0
	walled.on_tick(state, 0, you)
	var bus := _bus_of(&"foley_lean")
	assert_ne(bus, &"", "heard")
	assert_ne(bus, SimAudio.BUS_FOOTSTEPS, "through the wall: on a muffled bus")


## The ears are the watched character's: a rustle beside a teammate you watch is heard, though far from your own body.
func test_a_rustle_is_heard_from_the_ears_the_view_moves_to() -> void:
	var mate := Character.new(2, 0, Vector3(0.0, 0.0, 40.0))
	var near_mate := Character.new(3, 1, Vector3(0.0, 0.0, 44.0))
	state.characters.append(mate)
	state.characters.append(near_mate)
	other.position = Vector3(0.0, 0.0, 200.0)
	_sound()
	audio.on_tick(state, 0, you)
	_lean_out(near_mate)
	state.time += 1.0 / 60.0
	audio.on_tick(state, 0, you)
	assert_eq(_bus_of(&"foley_lean"), &"", "4 m from the teammate, 44 m from you: not heard")
	near_mate.lean = 0.0
	near_mate.prev_lean = 0.0
	state.time += 1.0
	audio.on_tick(state, 0, mate)
	_lean_out(near_mate)
	state.time += 1.0 / 60.0
	audio.on_tick(state, 0, mate)
	assert_eq(_bus_of(&"foley_lean"), SimAudio.BUS_FOOTSTEPS, "watching the teammate: heard")


## A rematch times the calls afresh from its own seed; the ticks of one match leave them be.
func test_a_rematch_times_the_calls_afresh_and_the_ticks_of_one_match_do_not() -> void:
	_sound()
	state.match_number = 1
	audio.on_tick(state, 0, you)
	var first := PackedFloat64Array()
	for i in audio._calls.size():
		first.append(audio._calls.next_at(i))
	state.time += 0.5
	audio.on_tick(state, 0, you)
	for i in audio._calls.size():
		assert_eq(audio._calls.next_at(i), first[i], "kind %d: not retimed by a tick of the same match" % i)
	state.match_number = 2
	state.time = 500.0
	audio.on_tick(state, 0, you)
	var fresh := AmbientCalls.new(audio._calls.calls)
	fresh.begin(state.match_seed, 2, 500.0)
	for i in audio._calls.size():
		assert_eq(audio._calls.next_at(i), fresh.next_at(i), "kind %d: the rematch's own seed, from now" % i)
		assert_gt(audio._calls.next_at(i), 500.0)


## Every shipped map's ambience loads: its beds loop on the Ambience bus, every call's cue has its variants, and a
## long stretch of play with a listener sounds each kind of call on the Ambience bus without a script error.
func test_every_shipped_maps_ambience_loads_and_its_calls_sound() -> void:
	for id: String in ["depot", "woodland", "range"]:
		var map := MapData.load_map(id, MapStyle.new(), 1)
		_sound(map)
		var amb := cfg.ambiences.set_for(map.ambience, false)
		assert_eq(audio._beds.size(), amb.beds.size(), "%s: every bed found" % id)
		audio.start_ambience() # the match starts it (UF1: silent under the loading screen)
		for bed in audio._beds:
			assert_true(bed.playing, id)
			assert_eq(bed.bus, SimAudio.BUS_AMBIENCE, id)
		for kind in amb.calls:
			assert_gt((audio._streams[kind.cue] as Array).size(), 0, "%s: %s has its variants" % [id, kind.cue])
		var fired := PackedInt32Array()
		fired.resize(audio._calls.size())
		var due := PackedFloat64Array()
		for i in audio._calls.size():
			due.append(audio._calls.next_at(i))
		for t in range(1, 1200):
			state.time = t * 0.25
			audio.on_tick(state, 0, you)
			for i in audio._calls.size():
				if audio._calls.next_at(i) != due[i]:
					fired[i] += 1
					due[i] = audio._calls.next_at(i)
		for i in fired.size():
			assert_gt(fired[i], 0, "%s: %s sounded in five minutes" % [id, amb.calls[i].cue])
		audio.queue_free()
		await wait_physics_frames(1)


## A busy tick (a hard landing, rustles, the round's whistle, a call falling due) makes no node and no voice. (Objects
## are not counted: the audio server makes a playback for each play(), the old beep's as much as the whistle's.)
func test_a_busy_tick_makes_no_nodes_and_no_voices() -> void:
	_sound()
	state.match_number = 1
	audio.on_tick(state, 0, you)
	var voices := audio.get_child_count()
	# Warm every path once (a first play can make the playback the server keeps).
	for round in 2:
		_busy_tick(round)
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	for round in range(2, 40):
		_busy_tick(round)
	assert_eq(audio.get_child_count(), voices, "no voice made")
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes, "no node made")


func _busy_tick(round: int) -> void:
	state.events.clear()
	state.time += 3.0
	var land := state.events.add(GameEvent.Kind.FOOTSTEP)
	land.actor = other.id
	land.value = GameEvent.Footstep.LAND
	land.position = other.position
	land.direction = Vector3.DOWN * (cfg.hard_land_speed + 1.0)
	state.events.add(GameEvent.Kind.ROUND_START)
	other.prev_crouch_amount = 0.0 if round % 2 == 0 else 1.0
	other.crouch_amount = 1.0 - other.prev_crouch_amount
	you.prev_lean = 0.0
	you.lean = 0.4
	audio.on_tick(state, 0, you)
