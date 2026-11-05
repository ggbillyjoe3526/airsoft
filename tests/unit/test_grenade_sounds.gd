extends GutTest
## The smoke and flash bombs' sounds are the owner's recordings, cut cleanly (owner, 2026-11-05: "a balloon pop sound
## for the flashbang and for the smoke grenade a ring pull sound and a bouncing can"): the can's knock group plays once
## from a bomb's bounce, the pin starts on its click, and the balloon pop keeps its punch and tail.

const BOUNCE_SECONDS := 0.6
## The can's knock group: within 30 dB of its peak this long (s), about what bounce_hold leaves silent.
const KNOCKS_MOST := 0.5
## A cut that starts on its sound reaches its peak within this long (s): the pin's click and the can's first knock.
const ONSET_MOST := 0.02
const ONSET_SHARE := 0.316
## A clipped burst's loudest 50 ms sit within about 4 dB of its peak; a clean pop's well under it.
const POP_CREST_LEAST_DB := 7.0

var body: BodyConfig = BodyConfig.new()
var cfg: SoundConfig = SoundConfig.new()
var audio: SimAudio = null
var state: GameState = null
var you: Character = null


func before_each() -> void:
	state = GameState.new(1)
	you = Character.new(0, 0, Vector3.ZERO, 0.0, [ReplicaConfig.new()] as Array[ReplicaConfig])
	state.characters.append(you)
	audio = SimAudio.new()
	add_child_autofree(audio)
	audio.setup(cfg, [] as Array[StringName], body, BoxWorld.new(body), null)


func _length(cue: String, n: int) -> float:
	return (load("%s%s_%d.wav" % [SoundConfig.CUE_DIR, cue, n]) as AudioStream).get_length()


## A cue file's 16-bit samples (as tools/cut_recordings.py writes them), read from the source WAV: the imported stream
## is compressed.
func _samples(cue: String, n: int) -> PackedFloat32Array:
	var bytes := FileAccess.get_file_as_bytes("%s%s_%d.wav" % [SoundConfig.CUE_DIR, cue, n])
	var at := 12
	while at + 8 <= bytes.size() and bytes.slice(at, at + 4).get_string_from_ascii() != "data":
		at += 8 + bytes.decode_u32(at + 4)
	var out := PackedFloat32Array()
	out.resize((bytes.size() - at - 8) / 2)
	for i in out.size():
		out[i] = bytes.decode_s16(at + 8 + 2 * i) / 32768.0
	return out


func _bounce_at(slot: int, time: float) -> int:
	for v in audio._field:
		v.stop()
	state.events.clear()
	state.time = time
	var e := state.events.add(GameEvent.Kind.GRENADE_BOUNCE)
	e.actor = 1
	e.target = slot
	e.position = Vector3(0.0, 0.0, -4.0)
	e.reach = cfg.bounce_full_speed
	audio.on_tick(state, you.id, you)
	return _playing(&"grenade_bounce")


func _throw(slot: int) -> void:
	state.events.clear()
	var e := state.events.add(GameEvent.Kind.GRENADE_THROW)
	e.actor = 1
	e.target = slot
	e.position = Vector3(0.0, 1.5, -4.0)
	audio.on_tick(state, you.id, you)


func _playing(cue: StringName) -> int:
	var n := 0
	for v in audio._field:
		if v.playing and (audio._streams.get(cue, []) as Array).has(v.stream):
			n += 1
	return n


func test_a_bombs_can_plays_once_from_its_first_bounce_and_again_once_it_has_rung_out() -> void:
	_throw(0)
	assert_eq(_bounce_at(0, 1.0), 1, "the first bounce starts the can")
	assert_eq(_bounce_at(0, 1.0 + cfg.bounce_hold * 0.5), 0, "the can's own knocks are the next bounces")
	assert_eq(_bounce_at(1, 1.0 + cfg.bounce_hold * 0.5), 1, "another bomb's can is its own")
	assert_eq(_bounce_at(0, 1.0 + cfg.bounce_hold + 0.1), 1, "a bounce after the can has rung out plays it again")


func test_a_new_throw_from_the_same_slot_starts_its_can_afresh() -> void:
	_throw(0)
	assert_eq(_bounce_at(0, 2.0), 1)
	_throw(0)
	assert_eq(_bounce_at(0, 2.0 + cfg.bounce_hold * 0.5), 1, "a new bomb in the slot")


## When (s) `x` first comes within 10 dB of its peak.
func _onset(x: PackedFloat32Array) -> float:
	var peak := 0.0
	for v in x:
		peak = maxf(peak, absf(v))
	for i in x.size():
		if absf(x[i]) >= peak * ONSET_SHARE:
			return i / 44100.0
	return 0.0


func test_the_pin_and_the_can_start_on_their_sound_and_the_hold_is_the_knocks() -> void:
	for n in 3:
		assert_almost_eq(_length("grenade_bounce", n + 1), BOUNCE_SECONDS, 0.01, "grenade_bounce_%d" % (n + 1))
		assert_lt(_onset(_samples("grenade_pin", n + 1)), ONSET_MOST, "grenade_pin_%d starts on its click" % (n + 1))
		assert_lt(_onset(_samples("grenade_bounce", n + 1)), ONSET_MOST, "grenade_bounce_%d on its knock" % (n + 1))
	assert_lt(cfg.bounce_hold, KNOCKS_MOST, "a bomb's next visible bounce is heard")


func test_the_balloon_pop_is_not_clipped_into_a_flat_burst() -> void:
	var window := int(0.05 * 44100.0)
	for n in 3:
		var x := _samples("flash_bang", n + 1)
		var peak := 0.0
		var loudest := 0.0
		var run := 0.0
		for i in x.size():
			peak = maxf(peak, absf(x[i]))
			run += x[i] * x[i]
			if i >= window:
				run -= x[i - window] * x[i - window]
			loudest = maxf(loudest, run)
		var crest := 20.0 * log(peak / sqrt(loudest / window)) / log(10.0)
		assert_gt(crest, POP_CREST_LEAST_DB, "flash_bang_%d: %.1f dB" % [n + 1, crest])
