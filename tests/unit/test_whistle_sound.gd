extends GutTest
## The referee's whistle (SP3, recorded in AU2): the owner's recorded blasts on disk (format, length, peak, a pea
## whistle's pitch, cut by tools/cut_recordings.py) and SoundConfig's level and blast pattern (the browser game's
## whistle.ts and AUDIO).

const SHORT := "whistle_short"
const LONG := "whistle_long"
const RATE := 44100
const HEADER := 44
## Where a pea whistle sounds (Hz, its zero crossings' rate): the owner's first whistle was about 2.2 to 3.1 kHz, his
## second (AU6) about 2.6 to 2.8 kHz, but 4.05 kHz on its two harder 1 s blasts; referees' whistles run to about
## 4.5 kHz.
const PITCH := Vector2(1500.0, 4500.0)
## The recordings' peaks sit at tools/cut_recordings.py's cap (-1 dB) or a little under.
const PEAK := Vector2(0.8, 0.9)

var cfg: SoundConfig


func before_all() -> void:
	cfg = PlayTuning.load_default().sound


func test_each_blast_is_a_16_bit_mono_wav_of_its_length_peaking_near_full_scale_at_a_whistles_pitch() -> void:
	for stem: String in [SHORT, LONG]:
		var seconds := cfg.whistle_short if stem == SHORT else cfg.whistle_long
		for v in cfg.whistle_variants:
			var path := "%s%s_%d.wav" % [SoundConfig.CUE_DIR, stem, v + 1]
			var bytes := FileAccess.get_file_as_bytes(path)
			assert_gt(bytes.size(), HEADER, path)
			if bytes.size() <= HEADER:
				continue
			assert_eq(bytes.slice(0, 4).get_string_from_ascii(), "RIFF", path)
			assert_eq(bytes.decode_u16(20), 1, "%s is PCM" % path)
			assert_eq(bytes.decode_u16(22), 1, "%s is mono" % path)
			assert_eq(bytes.decode_u32(24), RATE, "%s is 44.1 kHz" % path)
			assert_eq(bytes.decode_u16(34), 16, "%s is 16-bit" % path)
			var frames := bytes.decode_u32(40) >> 1
			assert_almost_eq(float(frames) / RATE, seconds, 1.0 / RATE, "%s lasts its blast" % path)
			var peak := 0
			var rises := 0
			var before := bytes.decode_s16(HEADER)
			for i in range(1, frames):
				var s := bytes.decode_s16(HEADER + i * 2)
				peak = maxi(peak, absi(s))
				if before <= 0 and s > 0:
					rises += 1
				before = s
			assert_between(peak / 32767.0, PEAK.x, PEAK.y, "%s peaks near full scale" % path)
			var hz := rises / seconds
			assert_between(hz, PITCH.x, PITCH.y, "%s sounds as a pea whistle (%.0f Hz)" % [path, hz])


func test_the_blasts_are_each_their_own_take() -> void:
	var seen: Array[PackedByteArray] = []
	for stem: String in [SHORT, LONG]:
		for v in cfg.whistle_variants:
			var path := "%s%s_%d.wav" % [SoundConfig.CUE_DIR, stem, v + 1]
			var bytes := FileAccess.get_file_as_bytes(path)
			assert_false(seen.has(bytes), "%s differs from the other variants" % path)
			seen.append(bytes)
	assert_false(ResourceLoader.exists("%s%s_%d.wav" % [SoundConfig.CUE_DIR, SHORT, cfg.whistle_variants + 1]))


func test_the_whistle_numbers() -> void:
	# The browser's 0.25 lifted 5 dB: a real whistle's loudest 50 ms sit that far under the old full-scale sine's.
	assert_almost_eq(cfg.whistle_gain, 0.45, 1e-6, "level")
	assert_almost_eq(cfg.whistle_short, 0.3, 1e-6)
	assert_almost_eq(cfg.whistle_long, 0.8, 1e-6, "the browser's long blast")
	assert_eq(cfg.whistle_variants, 3)


func test_a_round_starts_on_two_short_blasts_the_second_1_6_lengths_on() -> void:
	assert_eq(cfg.round_start_blasts, 2)
	assert_almost_eq(cfg.round_start_blast(0), 0.0, 1e-6)
	assert_almost_eq(cfg.round_start_blast(1), 0.3 * 1.6, 1e-6)


func test_the_match_ends_on_three_more_long_blasts_after_the_rounds_each_1_3_lengths_on() -> void:
	assert_eq(cfg.match_over_blasts, 3)
	for i in 3:
		assert_almost_eq(cfg.match_over_blast(i), 0.8 * 1.3 * (i + 1), 1e-6, "blast %d" % i)
	assert_gt(cfg.match_over_blast(0), cfg.whistle_long, "the round's long blast ends before the next starts")
