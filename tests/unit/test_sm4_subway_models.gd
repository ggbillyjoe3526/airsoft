extends GutTest
## SM4: Subway's works gear, booths and plant-room models. Each loads and is solid from outside; Subway's blocks name
## every one of them, and each is fitted inside its block's box; the booths look out to their platform's edge and the
## buffer stops down their track.

const MODELS: Array[StringName] = [&"skip_wagon", &"engineering_wagon", &"ballast_wagon", &"platelayer_trolley",
	&"platelayer_trolley_short", &"platelayer_trolley_long", &"buffer_stop", &"cable_drum", &"cable_drum_small",
	&"tunnel_segments", &"signal_cabinet", &"switch_cabinet", &"staff_booth", &"staff_booth_mid", &"staff_booth_small",
	&"works_hoarding", &"works_hoarding_short", &"works_hoarding_deep", &"fan_housing"]
const Faces := preload("res://tests/unit/test_model_faces.gd")

var play: PlayTuning = PlayTuning.load_default()
var tuning: SimTuning = SimTuning.new()


func _boxes(cfg: PropDressConfig) -> Dictionary[StringName, AABB]:
	var boxes: Dictionary[StringName, AABB] = {}
	for model: StringName in MODELS:
		var mesh := cfg.mesh_of(model)
		if mesh != null:
			boxes[model] = mesh.get_aabb()
	return boxes


func test_every_model_loads_and_is_solid_from_outside() -> void:
	var cfg := play.site_look.props
	for model in MODELS:
		assert_true(cfg.models.has(model), "%s is a prop model" % model)
		var mesh := cfg.mesh_of(model)
		assert_not_null(mesh, "%s loads" % model)
		if mesh == null:
			continue
		var share := Faces.back_share(mesh)
		assert_lt(share, Faces.BACK_MOST, "%s: %.1f%% of rays from outside meet a face turned away"
				% [model, share * 100.0])


func test_subway_names_each_model_and_fits_it_inside_its_box() -> void:
	var m := MapData.load_map("subway", play.map_style, tuning.rounds.team_size)
	assert_true(m.ok(), "Subway loads: %s" % [m.problems])
	var named: Dictionary[StringName, int] = {}
	for b in m.blocks:
		if MODELS.has(b.dress):
			named[b.dress] = named.get(b.dress, 0) + 1
	for model in MODELS:
		assert_true(named.has(model), "a Subway block names %s" % model)
	var cfg := play.site_look.props.named_only()
	var boxes := _boxes(cfg)
	for b in m.blocks:
		if not MODELS.has(b.dress) or not boxes.has(b.dress):
			continue
		var one := MapData.new()
		one.blocks.append(b)
		var placed := PropLayout.layout(one, cfg, boxes)
		assert_true(placed.has(b.dress), "%s at %s is laid" % [b.dress, b.center])
		if not placed.has(b.dress):
			continue
		var transforms: Array[Transform3D] = placed[b.dress].transforms
		assert_eq(transforms.size(), 1, "%s: one model fills its box" % b.dress)
		var world := transforms[0] * boxes[b.dress]
		var box := AABB(b.center - b.size * 0.5, b.size)
		assert_true(box.grow(0.01).encloses(world) and world.grow(0.01).encloses(box),
				"%s at %s fills its box exactly: %s in %s" % [b.dress, b.center, world, box])


func test_the_booths_look_out_to_the_edge_and_the_buffer_stops_down_the_track() -> void:
	var m := MapData.load_map("subway", play.map_style, tuning.rounds.team_size)
	var booths := 0
	var stops := 0
	for b in m.blocks:
		if String(b.dress).begins_with("staff_booth"):
			booths += 1
			assert_eq(b.facing, &"+z" if b.center.z > 0.0 else &"-z", "a booth at z %.1f looks out to the edge"
					% b.center.z)
		elif b.dress == &"buffer_stop":
			stops += 1
			assert_eq(b.facing, &"+x", "a buffer stop faces down its track")
	assert_eq(booths, 6, "three booths a platform")
	assert_eq(stops, 2, "a buffer stop a track")
