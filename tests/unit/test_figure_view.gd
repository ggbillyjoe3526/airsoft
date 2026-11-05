extends GutTest
## FI1, FI7: every other player drawn as its rigged figure (game/play/figure_view.gd, play_session.gd), with no switch:
## the models loaded as the session is built (before its first frame), one body a figure; no leak over a rematch or a
## session freed with frees pending; nothing loaded on the range; a kind that couldn't load draws no body; the levels'
## lines follow the graphics; the sign, the fade and the replica on a body; an old save's Rigged figures key still
## loads.

var s: Settings = null


func after_each() -> void:
	get_tree().paused = false


func before_each() -> void:
	s = Settings.new(PlayTuning.new())


func _play(practice: bool = false) -> PlaySession:
	var p := PlaySession.new()
	p.settings = s
	p.map_id = "depot"
	p.autopilot = true
	p.practice = practice
	p.match_seed = 5
	add_child_autofree(p)
	await wait_physics_frames(2)
	return p


static func _bodies_of(f: FigureView) -> int:
	return f.find_children("*", "FigureBody", true, false).size()


static func _first(p: PlaySession) -> FigureView:
	return p.find_children("Figure_*", "FigureView", true, false)[0] as FigureView


func _view() -> FigureView:
	var view := FigureView.new()
	add_child_autofree(view)
	view.setup(Character.new(3, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout()), Color.RED, HitConfig.new(),
			null)
	return view


func test_every_figure_has_its_body_as_the_session_is_built() -> void:
	var p := PlaySession.new()
	p.settings = s
	p.map_id = "depot"
	add_child_autofree(p)
	# Built in _ready (not staged): the models are in before the first frame is drawn.
	assert_not_null(p._figure_models, "loaded with the views")
	assert_not_null(p._thrown, "the thrown magazines' pool with them")
	var figures := p.find_children("Figure_*", "FigureView", true, false)
	assert_eq(figures.size(), p.state.characters.size() - 1, "everyone but you")
	for f: FigureView in figures:
		assert_eq(_bodies_of(f), 1, "%s: one body" % f.name)
		assert_eq(f.body().name, "Body")
		for mi: MeshInstance3D in f.find_children("*", "MeshInstance3D", true, false):
			assert_false(mi.mesh is CapsuleMesh or mi.mesh is SphereMesh, "%s: no capsule left" % mi.name)


func test_the_settings_no_longer_carry_rigged_figures_and_an_old_save_still_loads() -> void:
	var dev := DevSettings.new()
	assert_false("rigged_figures" in dev, "the switch is gone")
	assert_false(dev.to_dict().has("rigged_figures"), "and never saved")
	var old := dev.to_dict()
	old["rigged_figures"] = true
	old["retro_pixels"] = true
	dev.from_dict(old)
	assert_true(dev.retro_pixels, "the rest of an old save reads as saved")
	assert_false(SettingsScreen.DEV_SWITCHES.has(&"rigged_figures"), "no Dev row")
	assert_eq(tr("DEV_RIGGED_FIGURES"), "DEV_RIGGED_FIGURES", "its words gone")


func test_a_rematch_keeps_one_body_a_figure() -> void:
	var p := await _play()
	p._rematch_left = 0.0
	await wait_physics_frames(3)
	for f: FigureView in p.find_children("Figure_*", "FigureView", true, false):
		assert_eq(_bodies_of(f), 1)


func test_freeing_a_session_with_frees_pending_leaves_no_orphan() -> void:
	await wait_process_frames(2)
	var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var p := PlaySession.new()
	p.settings = s
	p.map_id = "depot"
	p.autopilot = true
	add_child(p)
	await wait_physics_frames(2)
	_first(p).set_body(p._figure_models, FigureMix.ROBOT, p._figure_lines)
	p.free()
	await wait_process_frames(3)
	assert_eq(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), orphans)
	assert_false(GraphicsApply.server().applied.has_connections(), "applied disconnected")


func test_the_range_loads_no_models() -> void:
	var p := await _play(true)
	assert_eq(p.find_children("Figure_*", "FigureView", true, false).size(), 0, "no figures on the range")
	assert_null(p._figure_models, "nothing loaded for nobody")
	assert_null(p._thrown, "no pool either")
	assert_eq(p.figure_kinds.size(), p.state.characters.size(), "you still have a kind")


func test_a_kind_that_could_not_load_draws_no_body() -> void:
	var c := FigureConfig.new()
	c.kinds = PackedStringArray(["human", "robot_nope"])
	var m := FigureModels.new(c)
	assert_false(m.load_kinds())
	var v := _view()
	v.set_body(m, FigureMix.ROBOT, c.lod_high)
	assert_null(v.body())
	v.set_body(m, FigureMix.HUMAN, c.lod_high)
	assert_not_null(v.body(), "the human still loads")
	v.set_body(m, 7, c.lod_high)
	assert_null(v.body(), "an unknown kind: none")
	assert_eq(_bodies_of(v), 0, "the old one out of the tree at once")
	v.set_body(m, -1, c.lod_high)
	assert_null(v.body())
	assert_eq(v.find_children("*", "MeshInstance3D", true, false).filter(
			func(n: Node) -> bool: return (n as MeshInstance3D).visible).size(), 0, "nothing drawn but the sign")


func _detail(detail: GraphicsQuality.MeshDetail) -> void:
	var q := GraphicsQuality.new()
	q.mesh_detail = detail
	GraphicsApply.server().applied.emit(q)


func test_the_lines_follow_the_graphics_while_playing() -> void:
	var p := await _play()
	var f := _first(p)
	_detail(GraphicsQuality.MeshDetail.HIGH)
	assert_eq(f.body().meshes[0].visibility_range_end, 12.0)
	_detail(GraphicsQuality.MeshDetail.MEDIUM)
	assert_eq(f.body().meshes[0].visibility_range_end, 6.0)
	# A rematch's new kind: a new body on the lines in force.
	f.set_body(p._figure_models, FigureMix.ROBOT if p.figure_kinds[f.character_id] == FigureMix.HUMAN else
			FigureMix.HUMAN, p._figure_lines)
	assert_eq(f.body().meshes[0].visibility_range_end, 6.0, "a new body on the lines in force")


func test_the_sign_and_the_fade_on_a_body() -> void:
	var p := await _play()
	var f := _first(p)
	var c := p.state.characters[f.character_id]
	for st: Character.Status in [Character.Status.CALLING, Character.Status.WALKING_OFF]:
		c.status = st
		f.update(c, 1.0)
		assert_true(f._sign.visible, "sign")
		assert_true(f.visible)
		assert_eq(f.body().meshes[0].transparency, 0.0)
	c.status = Character.Status.LEAVING
	c.status_time = 0.0
	f.update(c, 1.0)
	assert_false(f._sign.visible)
	c.status_time = 1000.0
	f.update(c, 1.0)
	assert_false(f.visible)
	assert_eq(f.body().meshes[0].transparency, 1.0)
	c.status_time = HitConfig.new().vanish_time * 0.5
	f.update(c, 1.0)
	f.set_body(p._figure_models, p.figure_kinds[f.character_id], p._figure_lines)
	var vanish := HitConfig.new().vanish_time
	assert_almost_eq(f.body().meshes[0].transparency, clampf(c.status_time / vanish, 0.0, 1.0), 0.01,
			"a new body mid-fade")


func test_the_replica_out_shows_on_a_body() -> void:
	var p := await _play()
	var f := _first(p)
	var c := p.state.characters[f.character_id]
	c.status = Character.Status.ALIVE
	f.update(c, 1.0)
	f.animate(c, 1.0, 0.0, f.global_position)
	var hands := f.body().hands
	assert_true(hands.replica(hands.in_hand) != null and hands.replica(hands.in_hand).visible, "the replica out")
	var worn := 0
	for slot: int in [hands.on_back, hands.in_holster]:
		if hands.replica(slot) != null:
			worn += 1
	var shown := 0
	for r in f._replicas:
		if r != null and r.visible:
			shown += 1
	assert_eq(shown, 1 + worn, "the replica out and the ones worn on the body (HS1), no more")
