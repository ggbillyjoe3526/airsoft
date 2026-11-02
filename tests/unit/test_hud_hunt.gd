extends GutTest
## QA's hunt on the HUD restyle (HD1): banners through Hud.on_tick, the replica panel across replicas and states, the
## magazine boxes, odd pip counts, and no leftover nodes after a session.

const Fixtures := preload("res://tests/unit/replica_fixtures.gd")

var session: PlaySession = null
var hud: Hud = null


func before_each() -> void:
	session = PlaySession.new()
	add_child_autofree(session)
	await wait_physics_frames(2)
	hud = session._hud


func after_each() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _tick_with(kind: GameEvent.Kind, value: int, target: int = -1) -> void:
	var st := session.state
	st.events.clear()
	var e := st.events.add(kind)
	e.value = value
	e.target = target
	hud.on_tick(st)
	st.events.clear()


func _big_colour() -> Color:
	return hud._banner._big.get_theme_color("font_color")


func test_round_start_banner_names_the_round_with_no_second_line() -> void:
	_tick_with(GameEvent.Kind.ROUND_START, 2)
	assert_true(hud._banner.visible)
	assert_eq(hud._banner.big_text(), "ROUND 2")
	assert_eq(hud._banner.sub_text(), "")


func test_the_round_after_the_half_says_half_time() -> void:
	var half := session._tuning.rounds.half_time_after
	_tick_with(GameEvent.Kind.ROUND_START, half + 1)
	assert_eq(hud._banner.sub_text(), "HALF TIME · ENDS SWAPPED")
	_tick_with(GameEvent.Kind.ROUND_START, half)
	assert_eq(hud._banner.sub_text(), "", "the round before the half has none")


func test_a_won_round_is_in_the_winners_colour() -> void:
	_tick_with(GameEvent.Kind.ROUND_OVER, 1)
	assert_eq(hud._banner.big_text(), "LOST", "from your side (RR1)")
	assert_eq(_big_colour(), hud._teams.colours[1])
	_tick_with(GameEvent.Kind.ROUND_OVER, 0)
	assert_eq(_big_colour(), hud._teams.colours[0])


func test_a_draw_banner_has_two_lines_in_the_text_colour() -> void:
	_tick_with(GameEvent.Kind.ROUND_OVER, -1)
	assert_eq(hud._banner.big_text(), "DRAW")
	assert_string_ends_with(hud._banner.sub_text(), " · THE ROUND IS PLAYED AGAIN")
	assert_eq(_big_colour(), GameTheme.TEXT, "no stale team colour from the banner before")


func test_a_ricochet_tick_shows_one_line_but_never_over_a_round_banner() -> void:
	hud._banner.visible = false
	_tick_with(GameEvent.Kind.RICOCHET_TICK, 0, session.player.id)
	assert_eq(hud._banner.big_text(), "")
	assert_true(hud._banner.sub_text().begins_with("RICOCHET"))
	_tick_with(GameEvent.Kind.ROUND_START, 3)
	_tick_with(GameEvent.Kind.RICOCHET_TICK, 0, session.player.id)
	assert_eq(hud._banner.big_text(), "ROUND 3")


func test_the_match_stamp_reads_won_or_lost_with_the_score_your_team_first() -> void:
	_tick_with(GameEvent.Kind.MATCH_OVER, 0)
	assert_eq(hud._banner.big_text(), "WON")
	assert_string_starts_with(hud._banner.sub_text(), "THE MATCH · ALPHA ")
	_tick_with(GameEvent.Kind.MATCH_OVER, 1)
	assert_eq(hud._banner.big_text(), "LOST")


func test_the_banner_hides_after_its_time() -> void:
	_tick_with(GameEvent.Kind.ROUND_START, 1)
	hud.update(session.state, 1.0, 100.0)
	assert_false(hud._banner.visible)


func test_odd_and_huge_win_targets_lay_out_that_many_pips() -> void:
	for n: int in [1, 3, 7, 12]:
		var s := HudScore.new()
		add_child_autofree(s)
		s.setup(TeamConfig.new(), n)
		s.set_score(n, n - 1)
		assert_eq(s.pip_count(), n)
		assert_eq(s.pips_filled(0), n)
		assert_eq(s.pips_filled(1), n - 1)
	var zero := HudScore.new()
	add_child_autofree(zero)
	zero.setup(TeamConfig.new(), 0)
	assert_eq(zero.pip_count(), 1, "a zero target still draws a block")


func test_the_clock_past_ten_minutes_and_an_hour() -> void:
	assert_eq(HudStyle.clock_text(0), "0:00")
	assert_eq(HudStyle.clock_text(754), "12:34")
	assert_eq(HudStyle.clock_text(3600), "60:00")


func test_a_negative_clock_never_shows_a_minus() -> void:
	var s := HudScore.new()
	add_child_autofree(s)
	s.setup(TeamConfig.new(), 5)
	s.set_clock(-9)
	assert_eq(s._clock_label.text, "0:00")


func _panel_for(loadout: Array[ReplicaConfig]) -> Array:
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, loadout)
	var p := ReplicaPanel.new()
	add_child_autofree(p)
	p.setup(HudConfig.new())
	p.refresh(c.armament)
	return [p, c.armament]


func _visible_chips(p: ReplicaPanel) -> int:
	var n := 0
	for chip in p._chips:
		if chip.visible:
			n += 1
	return n


func test_the_start_reads_full_magazine_over_all_the_spares() -> void:
	var r := _panel_for(ReplicaStats.default_loadout())
	var p: ReplicaPanel = r[0]
	var a: Armament = r[1]
	assert_eq(p._mag.text, str(a.replica().mag_size))
	assert_eq(p._spare.text, "/ %d" % ((a.replica().mags - 1) * a.replica().mag_size))
	assert_false(p._status.visible)


func test_chips_follow_the_replica_in_hand_and_the_selector() -> void:
	var r := _panel_for(ReplicaStats.default_loadout())
	var p: ReplicaPanel = r[0]
	var a: Armament = r[1]
	var modes := a.replica().fire_modes.size()
	assert_eq(_visible_chips(p), modes)
	a.active = 1
	p.refresh(a)
	assert_eq(_visible_chips(p), a.replica().fire_modes.size(), "switching replicas re-reads the modes")


func test_a_semi_only_replica_shows_a_single_chip() -> void:
	var pistol: ReplicaConfig = Fixtures.pistol()
	var loadout: Array[ReplicaConfig] = [pistol]
	var r := _panel_for(loadout)
	assert_eq(_visible_chips(r[0]), pistol.fire_modes.size())


func test_holstered_lights_no_chip_and_says_so() -> void:
	var r := _panel_for(ReplicaStats.default_loadout())
	var p: ReplicaPanel = r[0]
	var a: Armament = r[1]
	a.holstered = true
	p.refresh(a)
	assert_eq(p._status.text, "HOLSTERED")
	assert_true(p._status.visible)
	for chip in p._chips:
		assert_eq(chip.get_theme_color("font_color"), GameTheme.MUTED, "nothing lit while holstered")
	a.holstered = false
	p.refresh(a)
	assert_false(p._status.visible)


func test_reloading_out_of_bbs_and_last_magazine_statuses() -> void:
	var r := _panel_for(ReplicaStats.default_loadout())
	var p: ReplicaPanel = r[0]
	var a: Armament = r[1]
	a.ammo[a.active].pouch.fill(0)
	p.refresh(a)
	assert_eq(p._status.text, "LAST MAGAZINE")
	a.ammo[a.active].mag = 0
	p.refresh(a)
	assert_eq(p._status.text, "OUT OF BBS")
	a.reload_left = 1.0
	p.refresh(a)
	assert_eq(p._status.text, "RELOADING", "a reload outranks the empty note")


func test_the_count_turns_yellow_at_a_low_magazine_and_back_on_a_swap() -> void:
	var r := _panel_for(ReplicaStats.default_loadout())
	var p: ReplicaPanel = r[0]
	var a: Armament = r[1]
	assert_eq(p._mag.get_theme_color("font_color"), GameTheme.TEXT)
	a.ammo[a.active].mag = 1
	p.refresh(a)
	assert_eq(p._mag.get_theme_color("font_color"), GameTheme.WARN)
	a.ammo[a.active].mag = a.replica().mag_size
	p.refresh(a)
	assert_eq(p._mag.get_theme_color("font_color"), GameTheme.TEXT)


func test_an_empty_replica_loadout_does_not_crash_the_hud_update() -> void:
	var empty: Array[ReplicaConfig] = []
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, empty)
	var g := MagGauges.new()
	add_child_autofree(g)
	g.setup(HudConfig.new())
	g.refresh(c.armament)
	assert_eq(g._count, 0)


func test_the_loaded_box_is_yellow_when_low_and_an_empty_spare_has_no_fill() -> void:
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	var a := c.armament
	a.ammo[a.active].mag = 2
	a.ammo[a.active].pouch = PackedInt32Array([0, a.replica().mag_size, 0])
	var shares := PackedFloat32Array()
	var n := MagGauges.fill_shares(a, shares)
	assert_eq(n, 4)
	assert_lte(shares[0], HudConfig.new().low_mag_share, "loaded is low, so drawn in the warning colour")
	assert_almost_eq(shares[1], 1.0, 0.0001, "the fullest spare sits beside the loaded one")
	assert_eq(shares[3], 0.0)


func test_a_session_leaves_no_hud_nodes_behind() -> void:
	var before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var s := PlaySession.new()
	add_child(s)
	await wait_physics_frames(3)
	s.queue_free()
	await wait_physics_frames(3)
	assert_lte(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), before + 1.0)
