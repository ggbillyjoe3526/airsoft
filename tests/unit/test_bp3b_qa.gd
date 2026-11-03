extends GutTest
## QA hunts for BP3B: the HUD's crosshair really is sized on the eye's own zoom through a scope (the wiring in
## PlaySession, which the unit test on FirstPersonView alone does not pin), and the QUIT GAME? prompt's other
## key-readers.

var s: Settings = null


func before_each() -> void:
	s = Settings.new(PlayTuning.new())
	s.dev.dev_content = true


func after_each() -> void:
	get_tree().paused = false


func _scope_session() -> PlaySession:
	var rules := LoadoutRules.new(Pool.read_file(), ReplicaStats.read_file(), ReplicaRulesConfig.new())
	rules.dev_content = true
	var l := rules.default_loadout("L")
	assert_true(rules.equip(l, Loadout.Slot.PRIMARY, "000021"), "the Sniper Rifle with its 2x Scope")
	var session := PlaySession.new()
	session.settings = s
	session.settings_path = "user://test_bp3b_qa_settings.save"
	session.kit = rules.carried(l)
	session.bots_active = false
	add_child_autofree(session)
	return session


func test_through_a_scope_the_huds_crosshair_gap_follows_the_views_zoom() -> void:
	var session := _scope_session()
	await wait_physics_frames(3)
	var c := session.player
	assert_true(c.armament.replica().zoom_in_glass, "the rifle's zoom is in its glass")
	c.aim_raise = 0.4
	for i in 30:
		await wait_process_frames(1)
		c.aim_raise = 0.4
	var eyes: FirstPersonView = session._eyes
	var hud: Hud = session._hud
	assert_gt(session._input.zoom, eyes.view_zoom, "the turn is on the glass's zoom, the view's is less")
	var shown := hud._gap
	hud.update(session.state, eyes.view_zoom, 0.0)
	assert_almost_eq(shown, hud._gap, 1e-4, "the crosshair was drawn on the view's zoom")
	hud.update(session.state, session._input.zoom, 0.0)
	assert_ne(snappedf(shown, 0.01), snappedf(hud._gap, 0.01), "which is not the turn's")
