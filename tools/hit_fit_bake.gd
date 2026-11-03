extends SceneTree
## Bakes the hit area's joints from the human figure into game/config/hit_fit.tres (HV1, HitFitBaker; dev only, never
## exported). Run it after a figure or its clips change; test_hit_fit.gd fails until it has been.
##   godot --headless --path . -s res://tools/hit_fit_bake.gd

const OUT := "res://game/config/hit_fit.tres"
## Every number in the file is written to this many decimals (1 mm): the file stays small and its diffs readable.
const DECIMALS := 3


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var models := FigureModels.new(FigureConfig.new())
	if not models.load_kinds():
		push_error("hit_fit_bake: the figures didn't load")
		quit(1)
		return
	var holder := Node3D.new()
	root.add_child(holder)
	var fit := HitFitBaker.new().bake(models, HitConfig.new(), MovementConfig.new(), holder)
	if not fit.is_complete():
		push_error("hit_fit_bake: the bake is missing samples")
		quit(1)
		return
	var err := ResourceSaver.save(fit, OUT)
	if err != OK:
		push_error("hit_fit_bake: couldn't write %s (%d)" % [OUT, err])
		quit(1)
		return
	_round_numbers(OUT)
	print("hit_fit_bake: wrote %s" % OUT)
	quit(0)


## Rewrites every decimal number in the text resource at `path` to DECIMALS places.
static func _round_numbers(path: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	var number := RegEx.create_from_string("-?\\d+\\.\\d+(e[-+]?\\d+)?")
	var out := ""
	var at := 0
	for m: RegExMatch in number.search_all(text):
		out += text.substr(at, m.get_start() - at)
		var value := snappedf(m.get_string().to_float(), pow(10.0, -DECIMALS))
		var written := String.num(value, DECIMALS)
		out += "0" if written == "-0" else written
		at = m.get_end()
	out += text.substr(at)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(out)
