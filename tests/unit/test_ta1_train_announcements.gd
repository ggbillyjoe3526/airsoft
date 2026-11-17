extends GutTest
## TA1, Subway's easter egg: the owner's two train announcements (game/play/train_announcements.gd, SimAudio). Each
## match plays the gap 2 or 3 times, randomly apart, to someone near a train or inside one, and King's Cross once, to
## someone standing inside a train; never one over the other; the same seeds give the same announcements; the
## recordings are his, as they are.

## The clock's step in these runs (s): the schedule's gaps are tens of seconds.
const STEP := 0.25

var tuning: PlayTuning = null
var cfg: TrainAnnounceConfig = TrainAnnounceConfig.new()
var subway: MapData = null


func before_all() -> void:
	tuning = load("res://game/config/play_tuning.tres") as PlayTuning
	cfg = tuning.sound.train_announcements
	subway = MapData.load_map("subway", MapStyle.new(), 1)


## Inside the first of Subway's trains: its first car's floor.
func _in_train() -> Vector3:
	return subway.trains[0].cars[0].middle


## On the platform beside the first train, `off` m out from its side.
func _beside(off: float) -> Vector3:
	var t := subway.trains[0]
	var car := t.cars[0].middle
	var side := t.box.end.z if car.z - t.box.position.z > t.box.end.z - car.z else t.box.position.z
	return Vector3(car.x, car.y, side + signf(side - car.z) * off)


## Every announcement `a` plays over `seconds` with the feet at `feet`: [time, cue] each.
func _run(a: TrainAnnouncements, seconds: float, feet: Vector3) -> Array:
	var heard := []
	for t in int(seconds / STEP):
		var now := t * STEP
		var cue := a.due(now, feet)
		if cue != &"":
			heard.append([now, cue])
	return heard


func _count(heard: Array, cue: StringName) -> int:
	var n := 0
	for h: Array in heard:
		n += 1 if h[1] == cue else 0
	return n


func test_subway_has_trains_and_the_recordings_are_there_as_he_made_them() -> void:
	assert_false(subway.trains.is_empty(), "Subway's trains")
	var gap := load("%s%s_1.wav" % [SoundConfig.CUE_DIR, cfg.gap_cue]) as AudioStream
	var cross := load("%s%s_1.wav" % [SoundConfig.CUE_DIR, cfg.once_cue]) as AudioStream
	assert_not_null(gap, "gap")
	assert_not_null(cross, "King's Cross")
	# His takes with only the silence round them cut (tools/announce_sound.py).
	assert_almost_eq(gap.get_length(), 2.2, 0.1)
	assert_almost_eq(cross.get_length(), 15.2, 0.1)


func test_inside_a_train_a_match_plays_the_gap_two_or_three_times_randomly_apart_and_kings_cross_once() -> void:
	var counts := {}
	for seed_value in 24:
		var a := TrainAnnouncements.new(cfg, subway.trains)
		a.begin(seed_value, 1, 0.0)
		var heard := _run(a, 1200.0, _in_train())
		assert_eq(_count(heard, cfg.once_cue), 1, "King's Cross once")
		var gaps := _count(heard, cfg.gap_cue)
		assert_between(gaps, cfg.gap_plays_min, cfg.gap_plays_max, "the gap 2 or 3 times")
		counts[gaps] = true
		var last := -1.0
		for h: Array in heard:
			if h[1] != cfg.gap_cue:
				continue
			var at: float = h[0]
			var lo := cfg.first_min if last < 0.0 else last + cfg.apart_min
			var hi := cfg.first_max if last < 0.0 else last + cfg.apart_max
			assert_true(at >= lo - 1e-6 and at <= hi + STEP, "gap at %f after %f" % [at, last])
			last = at
		var once: Array = heard.filter(func(h: Array) -> bool: return h[1] == cfg.once_cue)
		assert_true(once[0][0] >= cfg.once_min - 1e-6 and once[0][0] <= cfg.once_max + STEP, "King's Cross due")
	assert_eq(counts.size(), 2, "both 2 and 3 plays happen")


func test_near_a_train_only_the_gap_plays_and_further_off_nothing() -> void:
	var near := _beside(cfg.near * 0.5)
	var far := _beside(cfg.near + 1.0)
	var a := TrainAnnouncements.new(cfg, subway.trains)
	assert_true(a.near_train(near), "near")
	assert_false(a.in_train(near), "but not in it")
	assert_false(a.near_train(far), "too far")
	a.begin(9, 1, 0.0)
	var heard := _run(a, 1200.0, near)
	assert_between(_count(heard, cfg.gap_cue), cfg.gap_plays_min, cfg.gap_plays_max, "the gap near a train")
	assert_eq(_count(heard, cfg.once_cue), 0, "King's Cross only inside")
	a.begin(9, 1, 0.0)
	assert_eq(_run(a, 1200.0, far).size(), 0, "nothing further off")


func test_inside_means_in_the_car_not_under_it_or_on_its_roof_and_a_due_one_waits_for_you() -> void:
	var t := subway.trains[0]
	var a := TrainAnnouncements.new(cfg, subway.trains)
	var under := Vector3(t.cars[0].middle.x, t.box.position.y + 0.05, t.cars[0].middle.z)
	var roof := Vector3(t.cars[0].middle.x, t.box.end.y + 0.5, t.cars[0].middle.z)
	assert_true(a.in_train(_in_train()), "on the car's floor")
	assert_false(a.in_train(under), "in the track bed under it")
	assert_false(a.in_train(roof), "on its roof")
	a.begin(5, 1, 0.0)
	assert_eq(_run(a, 600.0, _beside(cfg.near + 1.0)).size(), 0, "never far off")
	# Step in at 600 s: both are overdue; King's Cross first, the gap only once it has finished (busy).
	assert_eq(a.due(600.0, _in_train()), cfg.once_cue, "King's Cross as you step in")
	assert_eq(a.due(600.1, _in_train(), true), &"", "nothing over it")
	assert_eq(a.due(616.0, _in_train()), cfg.gap_cue, "then the gap")
	assert_eq(a.at, _in_train(), "from all round you inside")


func test_the_same_seeds_give_the_same_announcements_and_a_rematch_others() -> void:
	var inside := _in_train()
	var a := TrainAnnouncements.new(cfg, subway.trains)
	var b := TrainAnnouncements.new(cfg, subway.trains)
	a.begin(42, 1, 0.0)
	b.begin(42, 1, 0.0)
	var first := _run(a, 900.0, inside)
	assert_eq(_run(b, 900.0, inside), first)
	b.begin(42, 2, 0.0)
	assert_ne(_run(b, 900.0, inside), first, "a rematch")
	a.begin(42, 1, 0.0)
	assert_eq(_run(a, 900.0, inside), first, "begun afresh")


func test_sim_audio_plays_them_from_the_train_only_on_a_map_with_trains() -> void:
	var audio := SimAudio.new()
	add_child_autofree(audio)
	audio.setup(tuning.sound, [] as Array[StringName], BodyConfig.new(), null, subway)
	assert_not_null(audio._announcer, "Subway has the announcer")
	var state := GameState.new(3)
	var you := Character.new(0, 0, _beside(cfg.near + 1.0))
	state.characters.append(you)
	var t := 0.0
	while t < cfg.first_max + 1.0:
		state.time = t
		audio.on_tick(state, 0, you)
		t += STEP
	assert_false(audio._announcer.playing, "nothing far off")
	you.position = _beside(1.0)
	audio.on_tick(state, 0, you)
	assert_true(audio._announcer.playing, "the gap beside the train")
	assert_eq(audio._announcer.stream, audio._streams[cfg.gap_cue][0])
	assert_almost_eq(audio._announcer.global_position.distance_to(you.position), 1.0 + cfg.wall, 1e-3, "from the train's side")
	var plain := SimAudio.new()
	add_child_autofree(plain)
	plain.setup(tuning.sound, [] as Array[StringName], BodyConfig.new(), null, null)
	assert_null(plain._announcer, "no trains, no announcer")
