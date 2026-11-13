extends GutTest
## Plant The Bomb in a real match (PB1, PlaySession): the mode reads the map's sites and puts the bomb down in front
## of the attackers, the bomb and its sites are drawn and the pole is not, holding Use takes the bomb up and puts the
## replica away while the hands are on it, and every field hosts the mode.

var session: PlaySession = null


func after_each() -> void:
	Input.action_release(PlayerInput.USE_DOOR)
	get_tree().paused = false


func _session(mode: String, team: int = 0, map_id: String = "depot") -> PlaySession:
	var s := PlaySession.new()
	s.mode = mode
	s.map_id = map_id
	s.player_team = team
	s.bots_active = false
	add_child_autofree(s)
	return s


func test_the_mode_reads_the_maps_sites_and_your_team_attacks_first() -> void:
	session = _session(MatchOptions.MODE_PLANT_THE_BOMB, 1)
	await wait_physics_frames(2)
	var rs := session.state.round_state
	var map := MapData.load_map("depot", PlayTuning.load_default().map_style, 1)
	assert_eq(rs.mode, RoundState.Mode.PLANT_THE_BOMB)
	assert_eq(rs.attackers, 1, "the team you picked attacks first")
	assert_eq(rs.plant.sites, map.bomb_sites)
	assert_eq(rs.plant.sites.size(), Plant.MOST)
	assert_eq(rs.plant.status, PlantState.Status.DOWN)
	assert_eq(rs.plant.position, map.bomb_start_ahead(SimTuning.load_default().plant.start_ahead),
			"on the ground in front of the attackers' start")
	assert_lt(rs.plant.position.distance_to(session.player.position), 12.0, "by you, an attacker")
	assert_null(session.flag_view(), "no pole in this mode")


func test_the_bomb_and_both_sites_are_drawn() -> void:
	session = _session(MatchOptions.MODE_PLANT_THE_BOMB)
	await wait_physics_frames(2)
	await wait_process_frames(2)
	var view := session.plant_view()
	var ps := session.state.round_state.plant
	assert_not_null(view)
	assert_true(view.prop().visible)
	assert_almost_eq(view.prop().global_position.x, ps.position.x, 0.01)
	assert_almost_eq(view.prop().global_position.z, ps.position.z, 0.01)
	for i in ps.sites.size():
		assert_eq(view.letter(i).text, Plant.LETTERS[i])


func test_other_modes_draw_no_bomb() -> void:
	session = _session(MatchOptions.MODE_ATTACK_DEFEND)
	await wait_physics_frames(2)
	assert_null(session.plant_view())
	assert_not_null(session.flag_view())


func test_holding_use_takes_the_bomb_up() -> void:
	session = _session(MatchOptions.MODE_PLANT_THE_BOMB)
	await wait_physics_frames(2)
	var ps := session.state.round_state.plant
	RoundHold.release(session.state)
	session.player.position = ps.position + Vector3(0.6, 0.0, 0.0)
	Input.action_press(PlayerInput.USE_DOOR)
	await wait_physics_frames(6)
	Input.action_release(PlayerInput.USE_DOOR)
	assert_eq(ps.status, PlantState.Status.CARRIED)
	assert_eq(ps.carrier, session.player.id)
	await wait_process_frames(2)
	assert_false(session.plant_view().prop().visible, "in your own hands it is out of the first-person view")


func test_every_field_hosts_the_mode() -> void:
	var style := PlayTuning.load_default().map_style
	for e in MapCatalog.read_file().entries:
		if e.kind != &"field":
			continue
		var map := MapData.load_map(e.id, style, 1)
		assert_true(map.has_bomb_sites, "%s has bomb sites" % e.id)
		assert_true(MatchOptions.mode_pickable(MatchOptions.MODE_PLANT_THE_BOMB, e, map.has_pole or map.has_bomb_sites),
				"%s offers the mode" % e.id)
