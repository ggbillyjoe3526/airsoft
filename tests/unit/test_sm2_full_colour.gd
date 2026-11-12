extends GutTest
## SM2: models listed in PropDressConfig.full_colour keep their painted parts' whole colour (keep_by_alpha); the rest
## do not, and a material is shared per (roughness, wear, full colour).

var play: PlayTuning = PlayTuning.load_default()
var tuning: SimTuning = SimTuning.new()
var look: SiteLook = null


func before_each() -> void:
	look = play.site_look


func _dress() -> PropDress:
	var m := MapData.load_map("subway", play.map_style, tuning.rounds.team_size)
	assert_true(m.ok(), "subway loads")
	var dress := PropDress.build(m, look.props)
	add_child_autofree(dress)
	return dress


func test_full_colour_models_keep_by_alpha_and_others_do_not() -> void:
	var dress := _dress()
	var full_seen := 0
	var other_seen := 0
	for model: StringName in dress.placed():
		var listed := look.props.full_colour.has(model)
		for view in dress.views_of(model):
			var keeps: bool = (view.material_override as ShaderMaterial).get_shader_parameter(&"keep_by_alpha")
			assert_eq(keeps, listed, "%s keep_by_alpha" % model)
			if listed:
				full_seen += 1
			else:
				other_seen += 1
	assert_gt(full_seen, 0, "some full-colour view is drawn")
	assert_gt(other_seen, 0, "and some other")


func test_materials_are_shared_per_key_and_full_ones_are_separate() -> void:
	var dress := _dress()
	var mats := dress.materials()
	var seen: Dictionary = {}
	for mat in mats:
		assert_false(seen.has(mat), "each material listed once")
		seen[mat] = true
	var full := 0
	for mat in mats:
		if (mat as ShaderMaterial).get_shader_parameter(&"keep_by_alpha"):
			full += 1
	assert_gt(full, 0, "a full-colour material exists")
	assert_lt(full, mats.size(), "and a normal one")
	# the four full-colour models share their roughness and wear? at most one material per distinct (rough, wear)
	assert_lte(full, look.props.full_colour.size())


func test_the_default_full_colour_list_is_the_escalators_and_stairs() -> void:
	var want: Array[StringName] = [&"escalator_upper", &"escalator_lower", &"spiral_stair", &"platform_stair"]
	for m in want:
		assert_true(look.props.full_colour.has(m), String(m))
