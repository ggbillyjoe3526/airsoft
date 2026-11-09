extends GutTest
## GL1: Woodland's north bridge drew black slivers with a white glow round them (the trunks, grass and spruces near
## it). A reflection probe's faces stopped at its box's sides, so its downward face ended about two metres under the
## eye, in the hillside; that capture left bad values in the probe's blurred levels, and everything shiny it lit drew
## black and set the glow off. Each probe now sees at least LookConfig.probe_reach m from where it captures.


func test_every_maps_reflection_probes_see_past_their_box_into_the_ground_round_them() -> void:
	var play := PlayTuning.load_default()
	var team := SimTuning.load_default().rounds.team_size
	var look := play.look
	for id: String in ["depot", "range", "woodland"]:
		var entry := MapCatalog.shared().find(id)
		var map := MapData.load_map(id, play.map_style, MatchOptions.check_size(entry, team) if entry != null else team)
		assert_true(map.ok(), "%s loads" % id)
		var probes := AreaProbes.build(map, look)
		assert_not_null(probes, "%s has reflection probes" % id)
		add_child_autofree(probes)
		for p: ReflectionProbe in probes.get_children():
			var eye := p.position + p.origin_offset
			var bottom := p.position.y - p.size.y * 0.5
			# Godot's face reaches the farther of max_distance and the box's side (RendererSceneCull's probe render)
			var down := maxf(p.max_distance, eye.y - bottom)
			assert_gte(down, look.probe_reach, "%s %s: the face looking down sees past its box" % [id, p.name])


func test_the_reach_spans_woodlands_whole_rise_and_fall() -> void:
	var play := PlayTuning.load_default()
	var woodland := MapData.load_map("woodland", play.map_style, SimTuning.load_default().rounds.team_size)
	assert_not_null(woodland.terrain, "Woodland's ground rises and falls")
	var lo := INF
	var hi := -INF
	for x in range(-90, 91, 2):
		for z in range(-62, 63, 2):
			var h := woodland.terrain.height_at(float(x), float(z))
			if is_nan(h):
				continue
			lo = minf(lo, h)
			hi = maxf(hi, h)
	assert_gt(hi - lo, 1.0, "the ground does rise and fall")
	assert_gt(play.look.probe_reach, hi - lo + play.look.probe_eye, "a probe sees down to the lowest ground")
