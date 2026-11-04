extends GutTest
## The map's ambience played (game/play/ambient_calls.gd and SimAudio's beds and calls; SP4): each kind of call on its
## own seeded gaps at its distance round the listener and at its height, the same seeds giving the same calls; the
## calls positional on the Ambience bus at the pool's lowest priority; the map's day beds on the Ambience bus.

var cfg: SoundConfig = SoundConfig.new()
var yard: AmbienceSet = null


func before_all() -> void:
	cfg = (load("res://game/config/play_tuning.tres") as PlayTuning).sound
	yard = cfg.ambiences.set_for(&"yard", false)


## Every call `calls` makes over `seconds` round `listener`, ticked at 60 Hz: [time, kind, where] each.
func _schedule(calls: AmbientCalls, seconds: float, listener: Vector3) -> Array:
	var heard := []
	for t in int(seconds * 60.0):
		var now := t / 60.0
		for i in calls.size():
			if calls.due(i, now, listener):
				heard.append([now, i, calls.at])
	return heard


func test_the_same_seeds_give_the_same_calls_and_another_match_others() -> void:
	var a := AmbientCalls.new(yard.calls)
	var b := AmbientCalls.new(yard.calls)
	a.begin(42, 1, 0.0)
	b.begin(42, 1, 0.0)
	var first := _schedule(a, 300.0, Vector3.ZERO)
	assert_gt(first.size(), 10)
	assert_eq(_schedule(b, 300.0, Vector3.ZERO), first)
	b.begin(42, 2, 0.0)
	assert_ne(_schedule(b, 300.0, Vector3.ZERO), first, "a rematch")
	b.begin(43, 1, 0.0)
	assert_ne(_schedule(b, 300.0, Vector3.ZERO), first, "another seed")
	a.begin(42, 1, 0.0)
	assert_eq(_schedule(a, 300.0, Vector3.ZERO), first, "begun afresh")


func test_each_kind_keeps_its_own_gaps_distances_and_height_round_the_listener() -> void:
	var calls := AmbientCalls.new(yard.calls)
	calls.begin(7, 1, 0.0)
	var listener := Vector3(12.0, 3.0, -40.0)
	var last := PackedFloat64Array([0.0, 0.0, 0.0])
	var bearings: Array[PackedFloat64Array] = [PackedFloat64Array(), PackedFloat64Array(), PackedFloat64Array()]
	var tick := 1.0 / 60.0
	for heard: Array in _schedule(calls, 1200.0, listener):
		var i: int = heard[1]
		var kind := yard.calls[i]
		var at: Vector3 = heard[2]
		var gap: float = heard[0] - last[i]
		assert_true(gap >= kind.gap_min - 1e-6 and gap <= kind.gap_max + tick, "%s gap %f" % [kind.cue, gap])
		last[i] = heard[0]
		var flat := Vector2(at.x - listener.x, at.z - listener.z)
		assert_true(flat.length() >= kind.distance_min - 1e-3 and flat.length() <= kind.distance_max + 1e-3,
				"%s at %f m" % [kind.cue, flat.length()])
		assert_almost_eq(at.y, kind.height, 1e-5, "at its height")
		bearings[i].append(flat.angle())
	for i in yard.calls.size():
		assert_gt(bearings[i].size(), 3, "every kind is heard")
		var spread: float = Array(bearings[i]).max() - Array(bearings[i]).min()
		assert_gt(spread, PI, "at bearings all round")


func test_a_kind_keeps_its_timing_whatever_the_others_do() -> void:
	var all := AmbientCalls.new(yard.calls)
	var birds_only: Array[AmbienceCall] = [yard.calls[0]]
	var alone := AmbientCalls.new(birds_only)
	all.begin(5, 1, 0.0)
	alone.begin(5, 1, 0.0)
	var with_others := []
	for heard: Array in _schedule(all, 200.0, Vector3.ZERO):
		if heard[1] == 0:
			with_others.append(heard)
	assert_eq(_schedule(alone, 200.0, Vector3.ZERO), with_others)


func test_the_calls_play_round_the_listener_on_ambience_at_the_lowest_priority() -> void:
	var audio := _audio(null)
	var state := GameState.new(9)
	var you := Character.new(0, 0, Vector3(5.0, 0.0, 5.0))
	state.characters.append(you)
	audio.on_tick(state, 0, you)
	var first := audio._calls.next_at(0)
	assert_eq(_calls_playing(audio), 0, "nothing before the first gap")
	state.time = first
	audio.on_tick(state, 0, you)
	var v := _call_voice(audio)
	assert_not_null(v, "the first bird")
	if v == null:
		return
	assert_eq(v.bus, SimAudio.BUS_AMBIENCE)
	var ear := you.eye(BodyConfig.new())
	assert_gte(v.max_distance, ear.distance_to(v.global_position), "never cut off by its reach")
	var flat := Vector2(v.global_position.x - ear.x, v.global_position.z - ear.z).length()
	assert_between(flat, yard.calls[0].distance_min - 1e-3, yard.calls[0].distance_max + 1e-3)
	assert_eq(audio._priority[SimAudio.Kind.CALL], VoicePool.Priority.CALL)


func test_no_listener_hears_no_calls() -> void:
	var audio := _audio(null)
	var state := GameState.new(9)
	audio.on_tick(state, 0, null)
	state.time = 1000.0
	audio.on_tick(state, 0, null)
	assert_eq(_calls_playing(audio), 0)


func test_the_maps_day_beds_loop_on_ambience_and_no_map_plays_the_yard() -> void:
	var none := _audio(null)
	assert_eq(none._beds.size(), 1)
	assert_eq(none._beds[0].bus, SimAudio.BUS_AMBIENCE)
	assert_eq(none._beds[0].stream.resource_path, "res://assets/audio/loops/yard.wav")
	assert_true(none._beds[0].playing)
	var woods := MapData.new()
	woods.ambience = &"woods"
	var wood := _audio(woods)
	var loops: Array[String] = []
	for v in wood._beds:
		loops.append(v.stream.resource_path.get_file())
	assert_eq(loops, ["woods_day.wav"], "the woods by day: the owner's woods (AU6)")
	var calls: Array[StringName] = []
	for kind in wood._calls.calls:
		calls.append(kind.cue)
	assert_eq(calls, [&"ambience_bird", &"ambience_creak"])


func _audio(map: MapData) -> SimAudio:
	var audio := SimAudio.new()
	add_child_autofree(audio)
	audio.setup(cfg, [] as Array[StringName], BodyConfig.new(), null, map)
	audio.start_ambience() # the match starts it (UF1: silent under the loading screen)
	return audio


func _call_voice(audio: SimAudio) -> AudioStreamPlayer3D:
	for v in audio._field:
		if v.playing and (audio._streams[&"ambience_bird"] as Array).has(v.stream):
			return v
	return null


func _calls_playing(audio: SimAudio) -> int:
	var n := 0
	for v in audio._field:
		n += int(v.playing and v.bus == SimAudio.BUS_AMBIENCE)
	return n
