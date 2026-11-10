extends GutTest
## FI7 QA: what the capsules used to cover and the rigged figure now carries alone. A figure whose kind could not load
## draws no body yet still signs, fades, flinches and takes every call; an old save holding Rigged figures loads clean
## from a real file; Attack/Defend and a rematch with a model that went missing; no export ships the dev tools.

const SAVE := "user://fi7_qa_settings.json"

var s: Settings = null


func before_each() -> void:
	s = Settings.new(PlayTuning.new())


func after_each() -> void:
	get_tree().paused = false
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)


## Models none of whose kinds can be read (the models folder is missing).
func _no_models() -> FigureModels:
	var c := FigureConfig.new()
	c.models_dir = "res://nowhere/"
	var m := FigureModels.new(c)
	m.load_kinds()
	return m


func _bare_view(c: Character) -> FigureView:
	var v := FigureView.new()
	add_child_autofree(v)
	v.setup(c, Color.RED, HitConfig.new(), null, false, [], 0.3, FigureConfig.new())
	return v


func test_a_bodyless_figure_signs_flinches_fades_and_takes_every_call() -> void:
	var c := Character.new(4, 1, Vector3(3.0, 0.0, 1.0), 0.5, ReplicaStats.default_loadout())
	var v := _bare_view(c)
	assert_null(v.body(), "no body was ever given")
	v.update(c, 0.5, 0.016)
	v.animate(c, 0.5, 0.016, Vector3.ZERO)
	assert_false(v._sign.visible, "no sign while alive")
	v.on_shot()
	v.hit(Vector3(1.0, 0.0, 0.0), 0.5)
	for i in 30:
		v.update(c, 1.0, 0.016)
		v.animate(c, 1.0, 0.016, Vector3(0.0, 1.7, 5.0))
	v.reset_flinch()
	c.status = Character.Status.CALLING
	v.update(c, 1.0, 0.016)
	v.animate(c, 1.0, 0.016, Vector3.ZERO)
	assert_true(v._sign.visible, "HIT! shows with no body drawn")
	c.status = Character.Status.WALKING_OFF
	v.update(c, 1.0, 0.016)
	assert_true(v._sign.visible, "and on the walk-off")
	c.status = Character.Status.LEAVING
	c.status_time = 100.0
	v.update(c, 1.0, 0.016)
	v.animate(c, 1.0, 0.016, Vector3.ZERO)
	assert_false(v.visible, "gone once the fade is done")
	for replica in v._replicas:
		if replica != null:
			assert_false(replica.visible, "a replica is never drawn floating without a body")


func test_a_body_swapped_for_a_missing_kind_keeps_the_replicas_hidden_and_parented() -> void:
	var good := FigureModels.new(FigureConfig.new())
	good.load_kinds()
	var c := Character.new(4, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	var v := _bare_view(c)
	await wait_process_frames(1)
	var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	v.set_body(good, FigureMix.HUMAN, Vector2(12.0, 28.0))
	v.update(c, 1.0, 0.016)
	v.animate(c, 1.0, 0.016, Vector3.ZERO)
	v.set_body(null, FigureMix.HUMAN, Vector2(12.0, 28.0))
	await wait_process_frames(2)
	assert_null(v.body())
	for replica in v._replicas:
		if replica != null:
			assert_eq(replica.get_parent(), v, "the replica is back on the view, not freed with the body")
			assert_false(replica.visible)
	v.set_body(good, FigureMix.ROBOT, Vector2(12.0, 28.0))
	assert_not_null(v.body(), "and a body can come back")
	assert_eq(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), orphans, "no orphan left over")


func test_a_session_whose_models_went_missing_still_plays_calls_and_rematches() -> void:
	var p := PlaySession.new()
	p.settings = s
	p.map_id = "depot"
	p.autopilot = true
	p.match_seed = 9
	add_child_autofree(p)
	await wait_physics_frames(2)
	var none := _no_models()
	for f: FigureView in p._figures:
		f.set_body(none, p.figure_kinds[f.character_id], p._figure_lines)
		assert_null(f.body())
	await wait_physics_frames(10)
	var target := p._figures[0]
	var c: Character = p.state.characters[target.character_id]
	target.hit(Vector3.FORWARD, c.yaw)
	c.status = Character.Status.CALLING
	await wait_physics_frames(2)
	assert_true(target._sign.visible, "the sign works with no body")
	# A rematch with the mix flipped: figures whose kind changes are handed models that cannot supply a body.
	p._figure_models = none
	s.dev.robots = not s.dev.robots
	s.mark_changed()
	p._rematch_left = 0.0
	await wait_physics_frames(6)
	for f: FigureView in p._figures:
		assert_null(f.body(), "still no body, no crash")
	assert_eq(p.find_children("*", "FigureBody", true, false).size(), 0)


func test_attack_defend_draws_every_bot_as_a_figure_and_keeps_them_over_a_rematch() -> void:
	var p := PlaySession.new()
	p.settings = s
	p.map_id = "depot"
	p.mode = MatchOptions.MODE_ATTACK_DEFEND
	p.autopilot = true
	p.match_seed = 3
	add_child_autofree(p)
	await wait_physics_frames(30)
	assert_not_null(p._figure_models)
	for f: FigureView in p._figures:
		assert_not_null(f.body(), "%s: a body in Attack/Defend" % f.name)
	p._rematch_left = 0.0
	await wait_physics_frames(6)
	for f: FigureView in p._figures:
		assert_not_null(f.body(), "%s: and after the rematch" % f.name)
		assert_eq(f.find_children("*", "FigureBody", true, false).size(), 1)


func test_an_old_save_file_holding_rigged_figures_loads_clean_from_disk() -> void:
	var old := DevSettings.new().to_dict()
	old["rigged_figures"] = true
	var bundle := Settings.new(PlayTuning.new()).to_dict()
	bundle["dev_enabled"] = true
	bundle["dev"] = old
	assert_true(SaveFile.write(SAVE, Settings.KIND, Settings.VERSION, bundle), "the old file is written")
	var loaded := Settings.new(PlayTuning.new())
	loaded.load_file(SAVE)
	assert_eq(loaded.load_message, "", "no complaint")
	var fresh := DevSettings.new().to_dict()
	assert_eq(loaded.dev.to_dict(), fresh, "no stray setting turned on by the old key")
	assert_false((loaded.to_dict()["dev"] as Dictionary).has("rigged_figures"), "and dropped when saved again")
	assert_true(loaded.save(SAVE))
	var again := Settings.new(PlayTuning.new())
	again.load_file(SAVE)
	assert_eq(again.dev.to_dict(), fresh)


func test_a_dev_block_with_a_wrong_type_for_the_old_key_still_loads() -> void:
	var dev := DevSettings.new()
	dev.from_dict({"rigged_figures": "yes", "retro_pixels": true})
	assert_true(dev.retro_filter)
	dev.from_dict({"rigged_figures": [1, 2], "ghost": true})
	assert_true(dev.ghost)
	assert_false(dev.retro_filter, "the rest read as saved, a missing key false")


func test_every_export_preset_leaves_the_dev_tools_and_tests_out() -> void:
	var cfg := ConfigFile.new()
	assert_eq(cfg.load("res://export_presets.cfg"), OK)
	var presets := 0
	for section in cfg.get_sections():
		if section.ends_with(".options"):
			continue
		presets += 1
		var filter := String(cfg.get_value(section, "exclude_filter", ""))
		assert_true("tools/*" in filter, "%s leaves tools/ (figure_bench.gd) out" % section)
		assert_true("tests/*" in filter, "%s leaves tests/ (the hit area probe) out" % section)
	assert_gt(presets, 0)
