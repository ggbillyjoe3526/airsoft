extends GutTest
## The hit feed and teammate markers (HF1; concept `hud-feed.png`): lines newest first, at most six, each up six
## seconds of simulation time and fading over its last; names in team colours, "You" for you, your own lines framed,
## teammates' names with the chevron; top right or bottom left; and the markers over teammates only, hollow behind
## cover, grey with a hand once out, gone in the dead zone.

var session: PlaySession = null


func after_each() -> void:
	get_tree().paused = false


func _characters() -> Array[Character]:
	var out: Array[Character] = []
	for i in 6:
		out.append(Character.new(i, 0 if i < 3 else 1))
	return out


func _feed_view(feed: HitFeed) -> HudFeed:
	var view := HudFeed.new()
	view.setup(feed.max_lines, 6.0, PlayTuning.new().teams)
	add_child_autofree(view)
	view.set_names(PackedStringArray(["", "Owl", "Brick", "Rook", "Magpie", "Dash"]))
	return view


# --- the lines ---

func test_lines_come_newest_first_and_the_oldest_goes_when_full() -> void:
	var feed := HitFeed.new()
	feed.setup(3, 6.0, 1.0)
	for i in 4:
		feed.add(i, i + 1, float(i))
	assert_eq(feed.count(), 3)
	assert_eq(feed.line(0).shooter, 3, "newest first")
	assert_eq(feed.line(2).shooter, 1, "the first line was dropped")


func test_a_line_lasts_six_seconds_and_fades_over_the_last() -> void:
	var feed := HitFeed.new()
	feed.setup(6, 6.0, 1.0)
	feed.add(0, 3, 10.0)
	assert_eq(feed.alpha(0, 14.9), 1.0)
	assert_almost_eq(feed.alpha(0, 15.5), 0.5, 0.001)
	feed.prune(15.9)
	assert_eq(feed.count(), 1)
	feed.prune(16.0)
	assert_eq(feed.count(), 0, "gone after six seconds")


func test_the_version_moves_only_when_the_lines_change() -> void:
	var feed := HitFeed.new()
	feed.setup(6, 6.0, 1.0)
	var v := feed.version
	feed.prune(1.0)
	feed.clear()
	assert_eq(feed.version, v, "nothing to drop")
	feed.add(0, 3, 0.0)
	assert_gt(feed.version, v)


# --- on screen ---

func test_a_line_names_both_sides_and_yours_are_framed() -> void:
	var feed := HitFeed.new()
	feed.setup(6, 6.0, 1.0)
	var view := _feed_view(feed)
	var people := _characters()
	feed.add(4, 1, 0.0)
	feed.add(0, 3, 1.0)
	view.refresh(feed, 1.0, people, people[0])
	assert_eq(view.shown(), 2)
	assert_eq(view.row_of(0).words(), "You · Rook")
	assert_true(view.row_of(0).is_framed())
	assert_eq(view.row_of(1).words(), "Magpie · Owl")
	assert_false(view.row_of(1).is_framed())
	assert_eq(view.row_of(1).has_chevrons(), Vector2i(0, 1), "your teammate Owl carries the chevron")
	assert_eq(view.row_of(0).has_chevrons(), Vector2i(0, 0), "never on You")


func test_the_feed_fades_its_old_lines() -> void:
	var feed := HitFeed.new()
	feed.setup(6, 6.0, 1.0)
	var view := _feed_view(feed)
	var people := _characters()
	feed.add(0, 3, 0.0)
	view.refresh(feed, 5.5, people, people[0])
	assert_almost_eq(view.row_of(0).modulate.a, 0.5, 0.001)


func test_bottom_left_puts_the_newest_line_at_the_bottom() -> void:
	var feed := HitFeed.new()
	feed.setup(6, 6.0, 1.0)
	var view := _feed_view(feed)
	view.set_corner(HudFeed.Place.BOTTOM_LEFT)
	var people := _characters()
	feed.add(4, 1, 0.0)
	feed.add(0, 3, 1.0)
	view.refresh(feed, 1.0, people, people[0])
	assert_eq(view.row_of(0).words(), "You · Rook")
	assert_eq(view.row_of(0).get_index(), view.get_child_count() - 1, "the newest is the last row")


# --- in a match ---

func _session() -> PlaySession:
	var s := PlaySession.new()
	s.bots_active = false
	add_child_autofree(s)
	return s


func test_a_called_hit_puts_a_line_in_the_feed_and_a_new_match_clears_it() -> void:
	session = _session()
	await wait_physics_frames(2)
	var state := session.state
	var hud := session.hud()
	state.events.clear()
	var hit := state.events.add(GameEvent.Kind.CHARACTER_HIT)
	hit.actor = 4
	hit.target = 1
	hud.on_tick(state)
	hud.update(state, 1.0, 0.0)
	assert_eq(hud.feed().shown(), 1)
	assert_string_ends_with(hud.feed().row_of(0).words(), " · " + session._bots.name_of(1))
	state.events.clear()
	var start := state.events.add(GameEvent.Kind.ROUND_START)
	start.value = 1
	hud.on_tick(state)
	hud.update(state, 1.0, 0.0)
	assert_eq(hud.feed().shown(), 0, "a new match starts a clean feed")
	state.events.clear()


func test_a_pause_holds_the_lines_on_screen() -> void:
	session = _session()
	await wait_physics_frames(2)
	var state := session.state
	var hud := session.hud()
	state.events.clear()
	var hit := state.events.add(GameEvent.Kind.CHARACTER_HIT)
	hit.actor = 4
	hit.target = 1
	hit.position = Vector3.ZERO
	hud.on_tick(state)
	state.events.clear()
	var stood := state.time
	get_tree().paused = true
	await wait_process_frames(3)
	hud.update(state, 1.0, 10.0)
	assert_eq(state.time, stood, "the simulation stands still while paused")
	assert_eq(hud.feed().shown(), 1, "ten real seconds later the line is still up")
	assert_eq(hud.feed().row_of(0).modulate.a, 1.0)
	get_tree().paused = false


func test_there_is_one_marker_for_each_teammate_only() -> void:
	session = _session()
	await wait_physics_frames(2)
	assert_eq(session.hud().team_markers().count(), session._tuning.rounds.team_size - 1)


func test_teammates_get_a_marker_and_enemies_never_do() -> void:
	session = _session()
	await wait_physics_frames(2)
	await wait_process_frames(2)
	var state := session.state
	var markers := session.hud().team_markers()
	var camera := Camera3D.new()
	add_child_autofree(camera)
	var mate := state.characters[1]
	var enemy := state.characters[state.characters.size() - 1]
	for c: Character in [mate, enemy]:
		c.position = Vector3(20.0, 0.0, -8.0)
		c.prev_position = c.position
	camera.global_position = Vector3(20.0, 1.6, 0.0)
	camera.look_at(Vector3(20.0, 1.6, -8.0))
	var hud := session.hud()
	hud.place_team_markers(camera, state.characters, session.player, 1.0)
	assert_true(markers.is_shown(mate.id))
	assert_false(markers.is_shown(enemy.id), "never over an enemy")
	assert_false(markers.is_shown(session.player.id), "never over you")
	assert_false(markers.is_out(mate.id))
	mate.status = Character.Status.WALKING_OFF
	hud.place_team_markers(camera, state.characters, session.player, 1.0)
	assert_true(markers.is_out(mate.id), "grey with a raised hand while walking off")
	mate.status = Character.Status.OUT
	hud.place_team_markers(camera, state.characters, session.player, 1.0)
	assert_false(markers.is_shown(mate.id), "gone in the dead zone")
	mate.status = Character.Status.ALIVE
	hud.place_team_markers(camera, state.characters, mate, 1.0)
	assert_false(markers.is_shown(mate.id), "none over the teammate whose eyes you watch through")


func test_a_teammate_crouched_behind_low_cover_gets_a_hollow_marker() -> void:
	session = _session()
	await wait_physics_frames(2)
	var state := session.state
	var mate := state.characters[1]
	var camera := Camera3D.new()
	add_child_autofree(camera)
	var hud := session.hud()
	var markers := hud.team_markers()
	# A crate in Depot's Chrono hall (1.1 m high, z 4.5 to 5.5 at x -5.3 to -2.7), seen from a few metres off at a low
	# aim, past one crate of its two (sight meets them as drawn, DG1: the seam between them at x -4 is open).
	var behind := Vector3(-4.6, 0.0, 6.2)
	camera.global_position = Vector3(-4.6, 1.3, 0.0)
	camera.look_at(behind + Vector3.UP)
	mate.position = behind
	mate.prev_position = behind
	mate.crouch_amount = 1.0
	_place_all(hud, camera, state)
	assert_true(markers.is_shown(mate.id), "seen through cover too")
	assert_true(markers.is_hollow(mate.id), "crouched behind the crate: hidden, though the marker clears them")
	mate.crouch_amount = 0.0
	_place_all(hud, camera, state)
	assert_false(markers.is_hollow(mate.id), "standing, the head shows over them")


func _place_all(hud: Hud, camera: Camera3D, state: GameState) -> void:
	for i in PlayTuning.new().hud.team_marker_check:
		hud.place_team_markers(camera, state.characters, session.player, 1.0)
