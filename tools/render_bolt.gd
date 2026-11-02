extends SceneTree
## Renders the Sniper Rifle's cocking sound (SN1) to assets/audio/cues/boltCycle_<n>.wav, 16-bit mono 44.1 kHz like the
## other cues, each variant from its own seeded noise and a slightly moved pitch. A spring rifle is cocked by hand after
## every shot: the charging handle drawn back over the spring (a plastic scrape, the spring's rising zing under it, the
## sear's click as it catches), then let go to snap home (a hollow plastic clack). Timed to the model's Fire clip
## (tools/blender/replicas/sniper.py: back from 0.29 s to 0.50 s, home at 0.71 s). A toy's plastic, not a rifle's steel.
## No display needed:
##   godot --headless --path . -s res://tools/render_bolt.gd
## then `godot --headless --path . --import` and commit the files with their .import files. An argument after `--`
## names another output folder.

const RATE := 44100
const OUT_DIR := "res://assets/audio/cues/"
const STEM := "boltCycle"
const WHISTLE := preload("res://tools/render_whistle.gd")
const GRENADES := preload("res://tools/render_grenades.gd")
## Variants, the seed the noise starts from (variant n adds n), and each variant's pitch step up from the last.
const VARIANTS := 3
const SEED := 7713
const PITCH_STEP := 0.04
const LENGTH := 0.85

## The draw back: from DRAW_AT s for DRAW s, ratchet pulses at a rate gliding from SCRAPE_FROM to SCRAPE_TO Hz (each
## period off by up to SCRAPE_JITTER of itself) ringing SCRAPE_BODY Hz (pole radius SCRAPE_Q) at SCRAPE_LEVEL; under it
## the spring's zing gliding from ZING_FROM to ZING_TO Hz at ZING_LEVEL.
const DRAW_AT := 0.29
const DRAW := 0.21
const SCRAPE_FROM := 380.0
const SCRAPE_TO := 620.0
const SCRAPE_JITTER := 0.25
const SCRAPE_BODY := 2300.0
const SCRAPE_Q := 0.97
const SCRAPE_LEVEL := 0.35
const ZING_FROM := 310.0
const ZING_TO := 640.0
const ZING_LEVEL := 0.12
## The sear's click as the handle reaches the back: a bright partial ringing CLICK_RING s with a tick of noise over the
## first CLICK_TICK s.
const CLICK_HZ := 1900.0
const CLICK_RING := 0.01
const CLICK_TICK := 0.003
const CLICK_LEVEL := 0.8
## Home at CLACK_AT s: a hollow plastic knock (modes in Hz, dying over CLACK_DECAY s) and a crack of noise.
const CLACK_AT := 0.71
const CLACK_MODES := Vector3(640.0, 1310.0, 2150.0)
const CLACK_DECAY := 0.035
const CLACK_CRACK := 0.005
## How far into the edges of the draw its scrape and zing swell in and out (s).
const EDGE := 0.03


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := OUT_DIR if args.is_empty() else args[0].trim_suffix("/") + "/"
	var failed := false
	for v in VARIANTS:
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + v
		var path := "%s%s_%d.wav" % [out, STEM, v + 1]
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			push_error("render_bolt: %s could not be written (%s)" % [path, error_string(FileAccess.get_open_error())])
			failed = true
			continue
		file.store_buffer(WHISTLE.wav(GRENADES.normalised(cycle(rng, 1.0 + PITCH_STEP * v))))
		file.close()
		print("[render_bolt] %s" % path)
	quit(1 if failed else 0)


## One cocking: the draw back over the spring, the sear's click, the snap home.
static func cycle(rng: RandomNumberGenerator, pitch: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(roundi(LENGTH * RATE))
	_draw(out, rng, pitch)
	_click(out, DRAW_AT + DRAW, rng, pitch)
	_clack(out, CLACK_AT, rng, pitch)
	return out


## Adds the draw back: ratchet pulses ringing a resonance, and the spring's zing under them.
static func _draw(out: PackedFloat32Array, rng: RandomNumberGenerator, pitch: float) -> void:
	var start := roundi(DRAW_AT * RATE)
	var n := mini(out.size() - start, roundi(DRAW * RATE))
	var w := TAU * SCRAPE_BODY * pitch / RATE
	var a1 := 2.0 * SCRAPE_Q * cos(w)
	var a2 := -SCRAPE_Q * SCRAPE_Q
	var y1 := 0.0
	var y2 := 0.0
	var next_pulse := 0.0
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var along := t / DRAW
		var x := 0.0
		if t >= next_pulse:
			var rate := lerpf(SCRAPE_FROM, SCRAPE_TO, along) * pitch
			next_pulse = t + (1.0 + rng.randf_range(-SCRAPE_JITTER, SCRAPE_JITTER)) / rate
			x = rng.randf_range(0.6, 1.0)
		var y := x + a1 * y1 + a2 * y2
		y2 = y1
		y1 = y
		phase += TAU * lerpf(ZING_FROM, ZING_TO, along) * pitch / RATE
		var edge := minf(1.0, t / EDGE) * clampf((DRAW - t) / EDGE, 0.0, 1.0)
		out[start + i] += (y * sin(w) * SCRAPE_LEVEL + sin(phase) * ZING_LEVEL) * edge


## Adds the sear's click at `at` s.
static func _click(out: PackedFloat32Array, at: float, rng: RandomNumberGenerator, pitch: float) -> void:
	var start := roundi(at * RATE)
	var n := mini(out.size() - start, roundi(CLICK_RING * 8.0 * RATE))
	for i in n:
		var t := float(i) / RATE
		var ring := sin(TAU * CLICK_HZ * pitch * t) * exp(-t / CLICK_RING)
		var tick := rng.randf_range(-1.0, 1.0) * maxf(0.0, 1.0 - t / CLICK_TICK)
		out[start + i] += (ring + tick) * CLICK_LEVEL


## Adds the handle's snap home at `at` s: hollow plastic modes and a crack.
static func _clack(out: PackedFloat32Array, at: float, rng: RandomNumberGenerator, pitch: float) -> void:
	var start := roundi(at * RATE)
	var n := out.size() - start
	for i in n:
		var t := float(i) / RATE
		var body := (sin(TAU * CLACK_MODES.x * pitch * t) + 0.6 * sin(TAU * CLACK_MODES.y * pitch * t)
				+ 0.35 * sin(TAU * CLACK_MODES.z * pitch * t)) * exp(-t / CLACK_DECAY)
		var crack := rng.randf_range(-1.0, 1.0) * maxf(0.0, 1.0 - t / CLACK_CRACK)
		out[start + i] += body + crack
