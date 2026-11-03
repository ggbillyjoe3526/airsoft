extends SceneTree
## The browser game's synthesised draft of the referee's pea whistle and the ping's pip, kept for reference since the
## game plays tools/cut_recordings.py's whistle (AU3) and the owner's recorded pip (AU2), and the plain WAV writer the
## other renderers share. Renders the whistle (the browser game's whistle.ts, which played it live) from SoundConfig's
## whistle numbers in play_tuning.tres as whistle_short_<n>.wav and whistle_long_<n>.wav to the folder named after `--`:
## 16-bit mono 44.1 kHz like the other cues, whistle_variants of each, the warble's phase moved round its cycle from one
## to the next; and the ping's pip (PN2; the browser game's whistle.beep at AUDIO.pingPip, on the same output) to
## ping_pip_1.wav.
## No display needed:
##   godot --headless --path . -s res://tools/render_whistle.gd -- <folder>

const RATE := 44100
## The blasts rendered, each the stem of its files.
const SHORT := "whistle_short"
const LONG := "whistle_long"
const PIP := "ping_pip"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		# The game plays tools/cut_recordings.py's cues (AU2, AU3): render this draft elsewhere.
		push_error("render_whistle: the game plays tools/cut_recordings.py's cues; name an output folder after --")
		quit(1)
		return
	var out := args[0].trim_suffix("/") + "/"
	var cfg := PlayTuning.load_default().sound
	var failed := false
	for stem: String in [SHORT, LONG]:
		for v in cfg.whistle_variants:
			var path := "%s%s_%d.wav" % [out, stem, v + 1]
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file == null:
				push_error("render_whistle: %s could not be written (%s)" % [path, error_string(FileAccess.get_open_error())])
				failed = true
				continue
			file.store_buffer(wav(samples(cfg, length_of(cfg, stem), v)))
			file.close()
			print("[render_whistle] %s" % path)
	var pip_path := "%s%s_1.wav" % [out, PIP]
	var pip_file := FileAccess.open(pip_path, FileAccess.WRITE)
	if pip_file == null:
		push_error("render_whistle: %s could not be written (%s)" % [pip_path, error_string(FileAccess.get_open_error())])
		failed = true
	else:
		pip_file.store_buffer(wav(pip(cfg)))
		pip_file.close()
		print("[render_whistle] %s" % pip_path)
	quit(1 if failed else 0)


## How long the blast `stem` (SHORT or LONG) lasts (s).
static func length_of(cfg: SoundConfig, stem: String) -> float:
	return cfg.whistle_short if stem == SHORT else cfg.whistle_long


## One blast `seconds` long, variant `variant` (0-based): a sine at whistle_hz whose pitch warbles round it by
## whistle_warble_depth at whistle_warble_hz, the warble starting variant / whistle_variants of its cycle on, faded in
## over whistle_attack and out over the last whistle_release, at full scale as the browser's oscillator was (the level
## is whistle_gain, set as it plays).
static func samples(cfg: SoundConfig, seconds: float, variant: int) -> PackedFloat32Array:
	var count := roundi(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var warble_phase := TAU * variant / maxf(cfg.whistle_variants, 1.0)
	var phase := 0.0
	for i in count:
		var t := float(i) / RATE
		var gain := 1.0
		if t < cfg.whistle_attack:
			gain = t / cfg.whistle_attack
		elif t > seconds - cfg.whistle_release:
			gain = (seconds - t) / cfg.whistle_release
		out[i] = sin(phase) * gain
		var hz := cfg.whistle_hz * (1.0 + cfg.whistle_warble_depth * sin(TAU * cfg.whistle_warble_hz * t + warble_phase))
		phase = fmod(phase + TAU * hz / RATE, TAU)
	return out


## The ping's pip: a plain sine at ping_pip_hz (no warble: an electronic tone, not a whistle), ping_pip_length long,
## faded in over whistle_attack and out over the last whistle_release as the browser's beep was, at full scale (the
## level is ping_pip_gain, set as it plays).
static func pip(cfg: SoundConfig) -> PackedFloat32Array:
	var seconds := cfg.ping_pip_length
	var count := roundi(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	for i in count:
		var t := float(i) / RATE
		var gain := 1.0
		if t < cfg.whistle_attack:
			gain = t / cfg.whistle_attack
		elif t > seconds - cfg.whistle_release:
			gain = (seconds - t) / cfg.whistle_release
		out[i] = sin(TAU * cfg.ping_pip_hz * t) * gain
	return out


## `mono` as a 16-bit mono WAV file at RATE (the plain 44-byte header the other cues have).
static func wav(mono: PackedFloat32Array) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(mono.size() * 2)
	for i in mono.size():
		data.encode_s16(i * 2, clampi(roundi(mono[i] * 32767.0), -32767, 32767))
	var head := PackedByteArray()
	head.resize(44)
	head.encode_u32(0, 0x46464952) # "RIFF"
	head.encode_u32(4, 36 + data.size())
	head.encode_u32(8, 0x45564157) # "WAVE"
	head.encode_u32(12, 0x20746d66) # "fmt "
	head.encode_u32(16, 16)
	head.encode_u16(20, 1) # PCM
	head.encode_u16(22, 1) # mono
	head.encode_u32(24, RATE)
	head.encode_u32(28, RATE * 2)
	head.encode_u16(32, 2)
	head.encode_u16(34, 16)
	head.encode_u32(36, 0x61746164) # "data"
	head.encode_u32(40, data.size())
	return head + data
