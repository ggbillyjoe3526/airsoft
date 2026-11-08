extends GutTest
## The referee's whistle played (game/play/whistle_queue.gd and SimAudio's whistle; SP4): two short blasts start a
## round, one long ends it, three more long end the match, at SoundConfig's pattern, on the Interface bus at
## whistle_gain; a new round's whistle cuts the last short; the queue is fixed and a tick allocates nothing.

var cfg: SoundConfig = SoundConfig.new()


## Every blast `queue` hands out over `seconds` from `from`, ticked at 60 Hz: [time, blast] each.
func _drain(queue: WhistleQueue, from: float, seconds: float) -> Array:
	var heard := []
	for t in int(seconds * 60.0) + 1:
		var now := from + t / 60.0
		var blast := queue.pop_due(now)
		while blast != WhistleQueue.Blast.NONE:
			heard.append([now, blast])
			blast = queue.pop_due(now)
	return heard


func test_a_round_starts_on_two_short_blasts_at_the_pattern() -> void:
	var queue := WhistleQueue.new(cfg)
	queue.round_start(10.0)
	var heard := _drain(queue, 10.0, 2.0)
	assert_eq(heard.size(), cfg.round_start_blasts)
	for i in heard.size():
		assert_eq(heard[i][1], WhistleQueue.Blast.SHORT)
		assert_almost_eq(heard[i][0] - 10.0, cfg.round_start_blast(i), 1.0 / 60.0 + 1e-6)


func test_the_match_ends_on_the_rounds_long_blast_and_three_more() -> void:
	var queue := WhistleQueue.new(cfg)
	queue.round_over(4.0)
	queue.match_over(4.0)
	var heard := _drain(queue, 4.0, 6.0)
	assert_eq(heard.size(), 1 + cfg.match_over_blasts)
	assert_eq(heard[0][0], 4.0)
	for i in cfg.match_over_blasts:
		assert_eq(heard[i + 1][1], WhistleQueue.Blast.LONG)
		assert_almost_eq(heard[i + 1][0] - 4.0, cfg.match_over_blast(i), 1.0 / 60.0 + 1e-6)


func test_a_new_round_cuts_what_is_left_and_a_full_queue_drops_rather_than_grows() -> void:
	var queue := WhistleQueue.new(cfg)
	queue.round_over(0.0)
	queue.match_over(0.0)
	assert_eq(queue.pop_due(0.0), WhistleQueue.Blast.LONG)
	queue.round_start(0.5)
	assert_eq(queue.waiting(), cfg.round_start_blasts, "the match's blasts cut")
	for i in 20:
		queue.round_over(1.0)
	# Room for the longest pattern (the overtime's blasts with a round's and the match's end) and the range's Time.
	assert_eq(queue.waiting(), maxi(cfg.round_start_blasts, cfg.overtime_blasts + 1 + cfg.match_over_blasts) + 1)


func test_sim_audio_blows_the_round_start_and_cuts_the_last_blast() -> void:
	var audio := SimAudio.new()
	add_child_autofree(audio)
	audio.setup(cfg, [] as Array[StringName], BodyConfig.new(), null, null)
	var state := GameState.new(1)
	state.events.add(GameEvent.Kind.ROUND_OVER)
	state.events.add(GameEvent.Kind.MATCH_OVER)
	audio.on_tick(state, 0, null)
	assert_true((audio._streams[&"whistle_long"] as Array).has(audio._whistle.stream), "the round's end")
	assert_true(audio._whistle.playing)
	assert_eq(audio._whistle.bus, SimAudio.BUS_INTERFACE)
	assert_almost_eq(audio._whistle.volume_db, linear_to_db(cfg.whistle_gain), 1e-4)
	assert_null(audio._own[0].stream, "no beep")
	state.events.clear()
	state.time += 0.2
	state.events.add(GameEvent.Kind.ROUND_START)
	audio.on_tick(state, 0, null)
	assert_false((audio._streams[&"whistle_short"] as Array).has(audio._whistle.stream), "the round's start is silent (BP8)")
	state.events.clear()
	state.events.add(GameEvent.Kind.ROUND_GO)
	audio.on_tick(state, 0, null)
	assert_true((audio._streams[&"whistle_short"] as Array).has(audio._whistle.stream), "the whistle blows at GO")
	assert_eq(audio._blasts.waiting(), cfg.round_start_blasts - 1, "the match's blasts gone")
	state.events.clear()
	var voices := audio.get_child_count()
	for i in 30:
		state.time += 1.0 / 60.0
		audio.on_tick(state, 0, null)
	assert_eq(audio._blasts.waiting(), 0, "the second short blown")
	assert_eq(audio.get_child_count(), voices, "no voice made per blast")


func test_the_queue_allocates_nothing() -> void:
	var queue := WhistleQueue.new(cfg)
	var before := Performance.get_monitor(Performance.OBJECT_COUNT)
	for i in 100:
		queue.round_start(i)
		queue.round_over(i + 0.5)
		queue.match_over(i + 0.5)
		while queue.pop_due(i + 10.0) != WhistleQueue.Blast.NONE:
			pass
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), before)
