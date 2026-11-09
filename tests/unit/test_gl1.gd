extends GutTest
## GL1: Woodland's north bridge drew black slivers with a white glow round them (the trunks, grass and spruces near
## it). Godot ends each of a reflection probe's views at its box's side; probe Area15's ended 2.24 m below the eye and
## 9.5 to 10.5 m to the sides, close in the hill and trees, and its blurred levels came out bad, so every surface
## rough enough to read them drew black and set the glow off (reaching only down did not clear it). Each of a probe's
## views now reaches at least LookConfig.probe_reach m.


func test_every_maps_reflection_probes_see_at_least_the_reach_every_way() -> void:
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
			var to_floor := eye.y - (p.position.y - p.size.y * 0.5)
			# Godot ends each view at the farther of max_distance and the box's side (RendererSceneCull's probe render)
			assert_gte(p.max_distance, look.probe_reach, "%s %s: every view reaches the reach" % [id, p.name])
			assert_gte(maxf(p.max_distance, to_floor), look.probe_reach,
					"%s %s: the view down too, past the hill under the eye" % [id, p.name])


func test_the_reach_reaches_past_woodlands_slopes_but_stays_near() -> void:
	# The view down on the north bridge's probe ended 2.24 m under the eye; 12 m cleared the glow, 40 m darkened the
	# Clearing (GL1's pictures).
	var play := PlayTuning.load_default()
	var woodland := MapData.load_map("woodland", play.map_style, SimTuning.load_default().rounds.team_size)
	var probes := AreaProbes.build(woodland, play.look)
	add_child_autofree(probes)
	var deepest := 0.0
	for p: ReflectionProbe in probes.get_children():
		deepest = maxf(deepest, p.origin_offset.y + p.size.y * 0.5)
	assert_gt(play.look.probe_reach, deepest, "the reach is past every box's floor, so the view down is never the short one")
	assert_lte(play.look.probe_reach, 20.0, "the views stay near their area")
