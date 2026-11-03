extends SceneTree
## Tunes the fitted hit volume's shapes (HitConfig fit_*, HV1) against the drawn human (HitAreaProbe, M85's measure; dev
## only, never exported): a coordinate search over each number, keeping a step that lowers the score, halving the steps
## each round. The score is the mean missed plus thin air over the human's heads and poses, with every point over M85's
## bar (4 % missed, 3 % thin air, less MARGIN) counted SURCHARGE times more. Prints the numbers to copy into HitConfig;
## run after a re-bake.
##   godot --headless --path . -s res://tools/hit_fit_tune.gd [-- fit_chest_front fit_chest_back ...]

## Each number and its first round's step (m, or a share for the lerps), halved each round. Arguments after `--`
## name the numbers to tune (default: all).
const STEPS: Dictionary[String, float] = {"fit_head_centre": 0.1, "fit_head_radius": 0.01, "fit_chest_low": 0.1,
		"fit_chest_high": 0.1, "fit_chest_half_width": 0.01, "fit_chest_ahead": 0.01, "fit_chest_radius": 0.01,
		"fit_chest_front": 0.02, "fit_chest_back": 0.02, "fit_chest_depth_radius": 0.02, "fit_pelvis_up": 0.02,
		"fit_hips_radius": 0.01, "fit_thigh_radius": 0.01, "fit_shin_radius": 0.01, "fit_boot_heel": 0.1,
		"fit_boot_drop": 0.01, "fit_boot_radius": 0.01}
const ROUNDS := 4
const BAR_MISSED := 4.0
const BAR_THIN := 3.0
const MARGIN := 0.75
const SURCHARGE := 4.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var models := FigureModels.new(FigureConfig.new())
	models.load_kinds()
	var holder := Node3D.new()
	root.add_child(holder)
	var hits := HitConfig.new()
	var probe := HitAreaProbe.new(models, hits, MovementConfig.new(), holder)
	var heads: Array[StringName] = probe.heads(FigureMix.HUMAN)
	var best := _score(probe, heads)
	print("start %.3f" % best)
	var names := PackedStringArray(OS.get_cmdline_user_args())
	if names.is_empty():
		names = PackedStringArray(STEPS.keys())
	var steps: Dictionary[String, float] = STEPS.duplicate()
	for round_index in ROUNDS:
		for n in names:
			for sign_of: float in [1.0, -1.0]:
				var was: float = hits.get(n)
				hits.set(n, was + sign_of * steps[n])
				var s := _score(probe, heads)
				if s < best:
					best = s
					print("  %s %.4f -> %.3f" % [n, hits.get(n), best])
					break
				hits.set(n, was)
		for n in names:
			steps[n] *= 0.5
		print("round %d %.3f" % [round_index, best])
	for n in names:
		print("@export var %s: float = %.3f" % [n, hits.get(n)])
	probe.free_bodies()
	quit(0)


static func _score(probe: HitAreaProbe, heads: Array[StringName]) -> float:
	var total := 0.0
	for head in heads:
		for pose in HitAreaProbe.POSES:
			var r := probe.measure(FigureMix.HUMAN, head, pose)
			total += r.missed + r.thin_air
			total += SURCHARGE * (maxf(0.0, r.missed - (BAR_MISSED - MARGIN))
					+ maxf(0.0, r.thin_air - (BAR_THIN - MARGIN)))
	return total / float(HitAreaProbe.POSES.size() * heads.size())
