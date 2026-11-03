extends SceneTree
## The hinged doors' synthesised draft (DO1), kept for reference since the game plays the owner's recordings (AU2,
## tools/cut_recordings.py): rendered to the folder named after `--`, 16-bit mono 44.1 kHz like the cues, each variant
## from its own seeded noise and a slightly moved pitch:
## - door_open_<n>: the latch's click, then the hinge's creak as the plywood leaf swings away;
## - door_shut_<n>: a shorter creak, then the leaf's hollow wooden slam and the latch clicking home.
## A plywood door in a hall, not a vault's: light and a little rattly, loud enough that the other team hears it.
## No display needed:
##   godot --headless --path . -s res://tools/render_doors.gd -- <folder>

const RATE := 44100
const WHISTLE := preload("res://tools/render_whistle.gd")
const GRENADES := preload("res://tools/render_grenades.gd")
## Variants of each cue, and the seed each cue's noise starts from (variant n adds n).
const VARIANTS := 3
const SEED := 5531
## Each variant's pitch moves this share up from the last.
const PITCH_STEP := 0.05

## The latch: a bright partial (Hz) ringing out over LATCH_RING s, with a tick of noise over the first LATCH_TICK s.
const LATCH_HZ := 2650.0
const LATCH_RING := 0.012
const LATCH_TICK := 0.004
const LATCH_LEVEL := 0.7
## The creak: a hinge's stick-slip, pulses at a rate gliding from CREAK_FROM to CREAK_TO Hz (each period off by up to
## CREAK_JITTER of itself) ringing the leaf's CREAK_BODY Hz resonance (pole radius CREAK_Q), swelling in over
## CREAK_ATTACK s and out over the last CREAK_FADE s of its length, at CREAK_LEVEL (a pulse's ring peaking near it).
const CREAK_FROM := 170.0
const CREAK_TO := 310.0
const CREAK_JITTER := 0.18
const CREAK_BODY := 1150.0
const CREAK_Q := 0.985
const CREAK_ATTACK := 0.05
const CREAK_FADE := 0.12
const CREAK_LEVEL := 0.5
## Opening: the latch, then the creak from OPEN_CREAK_AT s for OPEN_CREAK s.
const OPEN_CREAK_AT := 0.03
const OPEN_CREAK := 0.34
const OPEN_LENGTH := 0.45
## Shutting: a creak of SHUT_CREAK s, then at SLAM_AT s the slam (the leaf's wooden modes, Hz, dying over SLAM_DECAY s,
## with a crack of noise over the first SLAM_CRACK s), and the latch SHUT_LATCH s after it.
const SHUT_CREAK := 0.2
const SLAM_AT := 0.2
const SLAM_MODES := Vector3(118.0, 236.0, 405.0)
const SLAM_DECAY := 0.07
const SLAM_CRACK := 0.008
const SHUT_LATCH := 0.025
const SHUT_LENGTH := 0.5


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		# The game plays the owner's recordings (AU2, tools/cut_recordings.py): render this draft elsewhere.
		push_error("render_doors: the game plays recordings now; name an output folder after --")
		quit(1)
		return
	var out := args[0].trim_suffix("/") + "/"
	var failed := false
	for v in VARIANTS:
		var pitch := 1.0 + PITCH_STEP * v
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + v
		failed = not _write(out, "door_open", v, opening(rng, pitch)) or failed
		failed = not _write(out, "door_shut", v, shutting(rng, pitch)) or failed
	quit(1 if failed else 0)


func _write(out: String, stem: String, variant: int, mono: PackedFloat32Array) -> bool:
	var path := "%s%s_%d.wav" % [out, stem, variant + 1]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("render_doors: %s could not be written (%s)" % [path, error_string(FileAccess.get_open_error())])
		return false
	file.store_buffer(WHISTLE.wav(GRENADES.normalised(mono)))
	file.close()
	print("[render_doors] %s" % path)
	return true


## A door opening: the latch, then the creak.
static func opening(rng: RandomNumberGenerator, pitch: float) -> PackedFloat32Array:
	var out := _blank(OPEN_LENGTH)
	_latch(out, 0.0, rng, pitch)
	_creak(out, OPEN_CREAK_AT, OPEN_CREAK, rng, pitch)
	return out


## A door shutting: a short creak, the slam, the latch.
static func shutting(rng: RandomNumberGenerator, pitch: float) -> PackedFloat32Array:
	var out := _blank(SHUT_LENGTH)
	_creak(out, 0.0, SHUT_CREAK, rng, pitch * 1.1)
	_slam(out, SLAM_AT, rng, pitch)
	_latch(out, SLAM_AT + SHUT_LATCH, rng, pitch)
	return out


## Adds the latch's click at `at` s.
static func _latch(out: PackedFloat32Array, at: float, rng: RandomNumberGenerator, pitch: float) -> void:
	var start := roundi(at * RATE)
	var n := mini(out.size() - start, roundi(LATCH_RING * 8.0 * RATE))
	for i in n:
		var t := float(i) / RATE
		var ring := sin(TAU * LATCH_HZ * pitch * t) * exp(-t / LATCH_RING)
		var tick := rng.randf_range(-1.0, 1.0) * maxf(0.0, 1.0 - t / LATCH_TICK)
		out[start + i] += (ring + tick) * LATCH_LEVEL


## Adds a creak of `seconds` from `at` s: stick-slip pulses ringing a resonance.
static func _creak(out: PackedFloat32Array, at: float, seconds: float, rng: RandomNumberGenerator,
		pitch: float) -> void:
	var start := roundi(at * RATE)
	var n := mini(out.size() - start, roundi(seconds * RATE))
	var w := TAU * CREAK_BODY * pitch / RATE
	var a1 := 2.0 * CREAK_Q * cos(w)
	var a2 := -CREAK_Q * CREAK_Q
	var y1 := 0.0
	var y2 := 0.0
	var next_pulse := 0.0
	for i in n:
		var t := float(i) / RATE
		var x := 0.0
		if t >= next_pulse:
			var rate := lerpf(CREAK_FROM, CREAK_TO, t / seconds) * pitch
			next_pulse = t + (1.0 + rng.randf_range(-CREAK_JITTER, CREAK_JITTER)) / rate
			x = rng.randf_range(0.6, 1.0)
		var y := x + a1 * y1 + a2 * y2
		y2 = y1
		y1 = y
		var level := CREAK_LEVEL * minf(1.0, t / CREAK_ATTACK) * clampf((seconds - t) / CREAK_FADE, 0.0, 1.0)
		out[start + i] += y * sin(w) * level


## Adds the leaf's slam at `at` s: its wooden modes and a crack.
static func _slam(out: PackedFloat32Array, at: float, rng: RandomNumberGenerator, pitch: float) -> void:
	var start := roundi(at * RATE)
	var n := out.size() - start
	for i in n:
		var t := float(i) / RATE
		var body := (sin(TAU * SLAM_MODES.x * pitch * t) + 0.7 * sin(TAU * SLAM_MODES.y * pitch * t)
				+ 0.4 * sin(TAU * SLAM_MODES.z * pitch * t)) * exp(-t / SLAM_DECAY)
		var crack := rng.randf_range(-1.0, 1.0) * maxf(0.0, 1.0 - t / SLAM_CRACK)
		out[start + i] += body + crack


static func _blank(seconds: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(roundi(seconds * RATE))
	return out
