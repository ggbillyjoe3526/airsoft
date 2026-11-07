extends GutTest
## MM4 QA: the minimap's wiring in a match (whose yaw it turns by, Woodland, teardown), a saved settings file from before
## it, a capped field scale, and the HUD's layout at the 1920x1080 the 1280x720 window scales to: the What got you card
## and the pinned flag marker against the Tab scoreboard and a full hit feed.

const HUD_SIZE := Vector2(1920.0, 1080.0)


func _session(mode: String = MatchOptions.MODE_ATTACK_DEFEND, map_id: String = "") -> PlaySession:
	var s := PlaySession.new()
	s.mode = mode
	s.bots_active = false
	if map_id != "":
		s.map_id = map_id
	add_child_autofree(s)
	return s


## The card up with a bot's note (its tallest case), laid out.
func _card(s: PlaySession, note: String = "holds one spot short of the middle, aiming over cover.") -> WhatGotYouCard:
	var facts := HitFacts.new()
	facts.from_shooter = Vector2(0.95, 0.3)
	facts.held_known = true
	facts.held = true
	facts.in_view = 0.4
	s.hud().size = HUD_SIZE
	s.hud().show_what_got_you(facts, "Rook", Color.ORANGE, note)
	return s.hud().what_got_you()


# --- layout at 1920x1080 (what a 1280x720 window scales to) ---

func test_the_card_and_a_pinned_flag_marker_clear_the_tab_scoreboard_and_a_full_feed() -> void:
	var s := _session()
	await wait_physics_frames(2)
	var hud := s.hud()
	hud.size = HUD_SIZE
	# a full feed in the top right and the pole behind you, to the right: the marker pins on that side
	var hits := hud.hit_lines()
	for i in HudConfig.new().feed_lines:
		hits.add(3, 4, s.state.time)
	hud.feed().refresh(hits, s.state.time, s.state.characters, s.player)
	var pole := s.state.round_state.pole
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.global_position = pole + Vector3(-6.0, 1.7, -24.0)
	hud.place_flag_marker(camera, pole, true)
	await wait_process_frames(3)
	hud.place_flag_marker(camera, pole, true)
	var plate: Control = hud._flag_marker._edge
	assert_true(plate.visible, "pinned")
	assert_gt(plate.global_position.x, HUD_SIZE.x * 0.5, "on the right")
	var in_feed := plate.get_global_rect().intersection(hud.feed().get_global_rect())
	assert_eq(in_feed.get_area(), 0.0, "plate %s in the feed %s" % [plate.get_global_rect(), hud.feed().get_global_rect()])
	# What got you with the Tab scoreboard up
	var card := _card(s)
	await wait_process_frames(3)
	s.set_process(false) # the session would let go of the key again each frame
	hud.show_board(true)
	hud.board().visible = true # as the Tab key holds it
	hud.update(s.state, 1.0, 0.0)
	# the card gives way to the board (it hides while Tab is held) and comes back when Tab is let go
	assert_false(card.is_visible_in_tree(), "hidden under the board")
	var on_board := card.get_global_rect().intersection(hud.board().get_global_rect()) if card.visible else Rect2()
	assert_eq(on_board.get_area(), 0.0, "card %s over the board %s" % [card.get_global_rect(),
			hud.board().get_global_rect()])
	hud.show_board(false)
	hud.update(s.state, 1.0, 0.0)
	assert_true(card.visible, "back when Tab is released")


# --- wiring ---

func test_the_panel_turns_with_your_mouse_look_and_with_the_teammate_you_watch_once_out() -> void:
	var s := _session(MatchOptions.MODE_ELIMINATION)
	await wait_physics_frames(2)
	var view := s.hud().minimap().view()
	s.set_physics_process(false) # no tick turns you in between: only the mouse look can
	s._input.view_yaw = 1.1
	await wait_process_frames(2)
	assert_almost_eq(view._rot, 1.1, 0.0001, "in play: the mouse look, not the last tick's yaw")
	var mate: Character = null
	for c in s.state.characters:
		if c.team == s.player.team and c != s.player and mate == null:
			mate = c
	mate.yaw = -0.7
	mate.prev_yaw = -0.7
	s.player.status = Character.Status.OUT
	await wait_process_frames(2)
	assert_eq(s.spectated(), mate)
	assert_almost_eq(view._rot, -0.7, 0.0001, "out: the teammate's yaw")
	assert_eq(view._centre, view.on_field(Vector2(mate.position.x, mate.position.z)), "and centred on them, kept on the field (BP6)")


func test_the_minimap_goes_with_the_session() -> void:
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var orphans := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var s := PlaySession.new()
	s.mode = MatchOptions.MODE_ATTACK_DEFEND
	s.bots_active = false
	add_child(s)
	await wait_physics_frames(3)
	var panel_texture: Texture2D = s.hud().minimap().view()._textures[0]
	var guard: WeakRef = weakref(panel_texture)
	panel_texture = null
	assert_gt(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes)
	s.free()
	await wait_process_frames(3)
	assert_null(guard.get_ref(), "the picture is freed")
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes, "every node it made is gone")
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), orphans)


# --- a field with its scale capped ---

func test_a_capped_scale_still_maps_the_world_to_the_picture() -> void:
	var cfg := MinimapConfig.new()
	cfg.max_layer_side = 120 # Depot is wider than 12 m
	var map := MapData.load_map("depot", MapStyle.new(), 1)
	var teams := TeamConfig.new()
	var state := GameState.new(5)
	state.match_number = 1
	var kit: Array[ReplicaConfig] = [ReplicaConfig.new()]
	var you := Character.new(0, 0, Vector3(1.0, 0.0, 1.0), 0.0, kit)
	state.characters.append(you)
	var heard := MinimapHearing.new(cfg)
	heard.on_tick(state, you)
	var mm := HudMinimap.new()
	add_child_autofree(mm)
	mm.setup(cfg, teams, map, heard, "Depot", 1, Vector2.ZERO)
	var field := mm.field()
	assert_lt(field.scale, cfg.layer_scale, "the cap lowered it")
	assert_eq(mm.view()._scale, field.scale, "the panel places the picture at the scale it was drawn at")
	var texture: Texture2D = mm.view()._textures[0]
	assert_lte(maxi(texture.get_width(), texture.get_height()), cfg.max_layer_side)
	mm.follow(state, you, 0.0, 1.0, HudPrefs.MinimapTurn.FIXED, false, Vector3.ZERO)
	# a world point lands where the picture puts its pixel: the picture's corner, then the pixel at the panel's scale
	var view := mm.view()
	var world := Vector2(field.origin.x + 7.0, field.origin.y + 3.0)
	var by_picture := (field.origin - Vector2(you.position.x, you.position.z)) * view._ppm \
			+ field.pixel_of(world.x, world.y) * (view._ppm / view._scale)
	var by_world := view._to_panel(world)
	assert_almost_eq(by_picture.x, by_world.x, 0.01)
	assert_almost_eq(by_picture.y, by_world.y, 0.01)


# --- an older settings file ---

func test_a_settings_file_from_before_the_minimap_loads_rotating_and_a_float_from_json_picks_fixed() -> void:
	var s := Settings.new(PlayTuning.new())
	s.hud.minimap_turn = HudPrefs.MinimapTurn.FIXED
	s.from_dict({"hud": {"shape": int(HudPrefs.Shape.DOT)}})
	assert_eq(s.hud.shape, HudPrefs.Shape.DOT)
	assert_eq(s.hud.minimap_turn, HudPrefs.MinimapTurn.ROTATING, "the default, not the stale pick")
	s.from_dict({"hud": {"minimap_turn": 1.0}})
	assert_eq(s.hud.minimap_turn, HudPrefs.MinimapTurn.FIXED, "JSON hands numbers back as floats")
	s.from_dict({"hud": {"minimap_turn": "fixed"}})
	assert_eq(s.hud.minimap_turn, HudPrefs.MinimapTurn.ROTATING, "a word is not a turn")


# --- after the fixes ---

## The flag marker pinned to the right with `lines` hits in the feed at `corner`; the plate's rect against the feed's.
func _right_plate_over_feed(s: PlaySession, lines: int, corner: HudPrefs.FeedCorner) -> float:
	var hud := s.hud()
	hud.size = HUD_SIZE
	var prefs := HudPrefs.new()
	prefs.feed_corner = corner
	prefs.feed_lines = HudPrefs.FeedLines.KEEP
	hud.apply_prefs(prefs)
	hud.hit_lines().clear()
	for i in lines:
		hud.hit_lines().add(3, 4, s.state.time)
	hud.feed().refresh(hud.hit_lines(), s.state.time, s.state.characters, s.player)
	var pole := s.state.round_state.pole
	var camera: Camera3D = get_tree().root.find_child("QaCam", true, false)
	camera.global_position = pole + Vector3(-6.0, 1.7, -24.0)
	hud.place_flag_marker(camera, pole, true)
	return 0.0


func test_a_right_pinned_flag_plate_clears_the_feed_whatever_its_length_and_corner() -> void:
	var s := _session()
	await wait_physics_frames(2)
	var camera := Camera3D.new()
	camera.name = "QaCam"
	add_child_autofree(camera)
	var hud := s.hud()
	for corner: int in [HudPrefs.FeedCorner.TOP_RIGHT, HudPrefs.FeedCorner.BOTTOM_LEFT]:
		for lines: int in [0, 6, 10]:
			_right_plate_over_feed(s, lines, corner as HudPrefs.FeedCorner)
			await wait_process_frames(3)
			hud.place_flag_marker(camera, s.state.round_state.pole, true)
			var plate: Control = hud._flag_marker._edge
			assert_true(plate.visible, "pinned, %d lines, corner %d" % [lines, corner])
			var hit := plate.get_global_rect().intersection(hud.feed().get_global_rect())
			assert_eq(hit.get_area(), 0.0, "%d lines, corner %d: plate %s feed %s" % [lines, corner,
					plate.get_global_rect(), hud.feed().get_global_rect()])
			assert_true(plate.get_global_rect().end.y <= HUD_SIZE.y and plate.global_position.x + plate.size.x <= HUD_SIZE.x,
					"on the screen")


func test_the_marker_is_under_a_card_the_frame_it_comes_up() -> void:
	var s := _session()
	await wait_physics_frames(2)
	var hud := s.hud()
	hud.size = HUD_SIZE
	var pole := s.state.round_state.pole
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.global_position = pole + Vector3(6.0, 1.7, -24.0) # behind you, to the left
	var card := _card(s)
	hud.place_flag_marker(camera, pole, true)
	var plate: Control = hud._flag_marker._edge
	assert_true(hud._flag_marker.visible and plate.visible, "shown the frame the card comes up")
	assert_gte(plate.position.y, card.position.y + card.size.y, "under the card from the first frame")


func test_the_flag_marker_sits_under_the_minimap_in_the_hud() -> void:
	var s := _session()
	await wait_physics_frames(2)
	var hud := s.hud()
	assert_lt(hud._flag_marker.get_index(), hud.minimap().get_index(), "the map draws over it")
	assert_gt(hud._flag_marker.get_index(), hud.team_markers().get_index(), "and it over the names")
	assert_lt(hud._flag_marker.get_index(), hud.feed().get_index(), "other panels as before")
	assert_lt(hud._flag_marker.get_index(), hud.board().get_index())


## The feed in the bottom left at its fullest (Keep, 10 lines) with the card up on its tallest note, the pole off each
## side: the card, the plate and the feed keep apart and stay on the screen.
func test_a_full_bottom_left_feed_keeps_clear_of_the_card_and_the_flag_plate() -> void:
	var s := _session()
	await wait_physics_frames(2)
	var hud := s.hud()
	hud.size = HUD_SIZE
	var prefs := HudPrefs.new()
	prefs.feed_corner = HudPrefs.FeedCorner.BOTTOM_LEFT
	prefs.feed_lines = HudPrefs.FeedLines.KEEP
	hud.apply_prefs(prefs)
	hud.hit_lines().clear()
	for i in HudPrefs.KEPT_LINES:
		hud.hit_lines().add(3, 4, s.state.time, true)
	var note := "holds one spot short of the middle, aiming over cover, until late in the round, and then falls back " \
			+ "to the stairs to watch the long lane for anyone who dares to cross it."
	var card := _card(s, note)
	var pole := s.state.round_state.pole
	var camera := Camera3D.new()
	add_child_autofree(camera)
	await wait_process_frames(3)
	var screen := Rect2(Vector2.ZERO, HUD_SIZE)
	var feed := hud.feed()
	for side: float in [-6.0, 6.0]:
		camera.global_position = pole + Vector3(side, 1.7, -24.0)
		for i in 3:
			hud.update(s.state, 1.0, 0.0)
			hud.place_flag_marker(camera, pole, true)
			await wait_process_frames(1)
		hud.update(s.state, 1.0, 0.0)
		hud.place_flag_marker(camera, pole, true)
		var plate: Control = hud._flag_marker._edge
		assert_true(plate.visible, "pinned")
		var feed_rect := feed.get_global_rect()
		var rows := Rect2(feed_rect.position.x, HUD_SIZE.y - hud._cfg.feed_margin.y - feed.lines_height(), feed_rect.size.x,
				feed.lines_height())
		assert_gt(feed.shown(), 0, "some of the feed shows")
		assert_eq(card.get_global_rect().intersection(rows).get_area(), 0.0, "card %s feed %s" % [card.get_global_rect(), rows])
		assert_eq(plate.get_global_rect().intersection(rows).get_area(), 0.0, "plate %s feed %s" % [plate.get_global_rect(), rows])
		assert_eq(plate.get_global_rect().intersection(card.get_global_rect()).get_area(), 0.0, "plate over the card")
		assert_true(screen.encloses(plate.get_global_rect()) and screen.encloses(card.get_global_rect())
				and screen.encloses(rows), "all on the screen")
	# the card goes and every line comes back
	hud.hide_what_got_you()
	hud.update(s.state, 1.0, 0.0)
	assert_eq(feed.shown(), HudPrefs.KEPT_LINES, "all the lines are back")


## The flag and hold markers both pinned to one side, the minimap up, a full bottom-left Keep feed, with and without the
## card: they sit apart, clear of the panel, the card and the feed, and on the screen; the left stack with room stays left.
func test_the_flag_and_hold_markers_pinned_together_keep_apart_from_the_panel_the_card_and_the_feed() -> void:
	var s := _session()
	await wait_physics_frames(2)
	var hud := s.hud()
	hud.size = HUD_SIZE
	hud.setup_orders(ControlsConfig.new())
	var prefs := HudPrefs.new()
	prefs.feed_corner = HudPrefs.FeedCorner.BOTTOM_LEFT
	prefs.feed_lines = HudPrefs.FeedLines.KEEP
	hud.apply_prefs(prefs)
	hud.hit_lines().clear()
	for i in HudPrefs.KEPT_LINES:
		hud.hit_lines().add(3, 4, s.state.time, true)
	var pole := s.state.round_state.pole
	var camera := Camera3D.new()
	add_child_autofree(camera)
	var note := "holds one spot short of the middle, aiming over cover, until late in the round, and then falls back " \
			+ "to the stairs to watch the long lane for anyone who dares to cross it."
	var screen := Rect2(Vector2.ZERO, HUD_SIZE)
	for with_card: bool in [false, true]:
		if with_card:
			_card(s, note)
		for side: float in [1.0, -1.0]:
			camera.global_position = pole + Vector3(6.0 * side, 1.7, -24.0)
			var spot := camera.global_position + Vector3(-8.0 * side, 0.0, 30.0)
			for i in 4:
				hud.update(s.state, 1.0, 0.0)
				hud.place_flag_marker(camera, pole, true)
				hud.place_hold_marker(camera, spot, true)
				await wait_process_frames(1)
			hud.update(s.state, 1.0, 0.0)
			hud.place_flag_marker(camera, pole, true)
			hud.place_hold_marker(camera, spot, true)
			var tag := "card %s, side %s" % [with_card, side]
			var flag: Rect2 = hud._flag_marker.occupied()
			var hold := hud.hold_marker().get_rect()
			var feed := hud.feed()
			var rows := Rect2(32.0, HUD_SIZE.y - hud._cfg.feed_margin.y - feed.lines_height(), 255.0, feed.lines_height())
			var others: Array[Rect2] = [hud.minimap().panel_rect(), rows]
			if with_card:
				others.append(hud.what_got_you().get_rect())
			assert_true(flag.has_area() and hud.hold_marker().visible, "both up, " + tag)
			assert_eq(flag.intersection(hold).get_area(), 0.0, "flag %s over hold %s, %s" % [flag, hold, tag])
			for other: Rect2 in others:
				assert_eq(flag.intersection(other).get_area(), 0.0, "flag %s over %s, %s" % [flag, other, tag])
				assert_eq(hold.intersection(other).get_area(), 0.0, "hold %s over %s, %s" % [hold, other, tag])
			assert_true(screen.encloses(flag) and screen.encloses(hold), "on the screen, " + tag)
			if not with_card and side > 0.0:
				assert_lt(flag.end.x, HUD_SIZE.x * 0.5, "the left stack has room, so it stays left")
				assert_lt(hold.end.x, HUD_SIZE.x * 0.5)
				assert_gte(hold.position.y, flag.position.y + hud.minimap().step_down() - 0.5, "a step under the flag plate")
			if with_card:
				assert_gt(hold.position.x, HUD_SIZE.x * 0.5, "past the feed's top the stack moves right, " + tag)


# --- the hold marker pinned to a side against the flag marker (attempt 3) ---

## A session at the layout size with the minimap up and a camera at `at`, for the markers' placement.
func _markers_ready(at: Vector3) -> Dictionary:
	var s := _session()
	await wait_physics_frames(2)
	var hud := s.hud()
	hud.size = HUD_SIZE
	hud.setup_orders(ControlsConfig.new())
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.global_position = at
	return {"s": s, "hud": hud, "camera": camera}


## The flag marker over its pole (not pinned) near a side edge, Hold here's marker held at that side: the two plates do
## not cover each other, whatever height the pole stands at on the screen.
func test_a_hold_marker_pinned_to_a_side_keeps_clear_of_a_flag_marker_over_its_pole_near_that_edge() -> void:
	var r := await _markers_ready(Vector3(0.0, 1.7, 0.0))
	var hud: Hud = r["hud"]
	var camera: Camera3D = r["camera"]
	for side: float in [-1.0, 1.0]:
		var tried := 0
		for px in range(4, 28):
			for i in 21:
				camera.rotation = Vector3(-0.5 + 0.05 * i, 0.0, 0.0)
				var pole := Vector3(side * px, 0.0, -20.0)
				var spot := Vector3(side * 60.0, 0.0, -20.0)
				hud.place_flag_marker(camera, pole, true)
				hud.place_hold_marker(camera, spot, true)
				var flag: Rect2 = hud._flag_marker.occupied()
				var held := HudHoldMarker.Pin.LEFT if side < 0.0 else HudHoldMarker.Pin.RIGHT
				if not flag.has_area() or hud._flag_marker.pinned_side() != 0 or hud.hold_marker().pin != held:
					continue
				var hold := hud.hold_marker().get_rect()
				if flag.position.x > 200.0 and flag.end.x < HUD_SIZE.x - 200.0:
					continue
				tried += 1
				assert_eq(flag.intersection(hold).get_area(), 0.0,
						"side %s: flag %s over hold %s (pole %d, pitch %d)" % [side, flag, hold, px, i])
		assert_gt(tried, 0, "side %s: the sweep put the flag over its pole at the edge with the hold marker pinned there" % side)


## Turning the view through a full circle with both markers up: neither plate changes side more often than the
## geometry makes it (a swap is a few turns' worth, not a flicker), and the two never overlap.
func test_turning_all_the_way_round_swaps_the_markers_sides_only_when_the_view_crosses_them() -> void:
	var r := await _markers_ready(Vector3(0.0, 1.7, 0.0))
	var hud: Hud = r["hud"]
	var camera: Camera3D = r["camera"]
	var pole := Vector3(0.0, 0.0, -30.0)
	var spot := Vector3(20.0, 0.0, 10.0)
	var flips := {"flag": 0, "hold": 0}
	var last := {"flag": 0, "hold": 0}
	for i in 721:
		camera.rotation = Vector3(0.0, deg_to_rad(i * 0.5), 0.0)
		hud.place_flag_marker(camera, pole, true)
		hud.place_hold_marker(camera, spot, true)
		var flag: Rect2 = hud._flag_marker.occupied()
		var hold := hud.hold_marker().get_rect()
		assert_eq(flag.intersection(hold).get_area(), 0.0, "overlap at %d: %s %s" % [i, flag, hold])
		var f := signi(roundi(flag.get_center().x - HUD_SIZE.x * 0.5))
		var h := signi(roundi(hold.get_center().x - HUD_SIZE.x * 0.5))
		if i > 0 and f != last["flag"] and absf(flag.get_center().x - HUD_SIZE.x * 0.5) > 200.0:
			flips["flag"] += 1
		if i > 0 and h != last["hold"] and absf(hold.get_center().x - HUD_SIZE.x * 0.5) > 200.0:
			flips["hold"] += 1
		last["flag"] = f
		last["hold"] = h
	# Each marker passes from one side to the other while the view turns past it at most twice a turn (in front, behind).
	assert_lte(flips["flag"] as int, 8, "flag swaps %s" % flips)
	assert_lte(flips["hold"] as int, 8, "hold swaps %s" % flips)


## A card just added is not yet laid out: Hold here's marker, pinned left, holds its place with the flag marker rather
## than jumping with the card's first (meaningless) height.
func test_a_card_just_added_does_not_move_the_pinned_hold_marker_for_a_frame() -> void:
	var r := await _markers_ready(Vector3(0.0, 1.7, 0.0))
	var s: PlaySession = r["s"]
	var hud: Hud = r["hud"]
	var camera: Camera3D = r["camera"]
	var spot := Vector3(-40.0, 0.0, -20.0)
	hud.place_hold_marker(camera, spot, true)
	var before := hud.hold_marker().position
	var note := "holds one spot short of the middle, aiming over cover, until late in the round."
	_card(s, note)
	hud.place_hold_marker(camera, spot, true)
	var first := hud.hold_marker().position
	await wait_process_frames(3)
	hud.place_hold_marker(camera, spot, true)
	var settled := hud.hold_marker().position
	assert_almost_eq(first.y, settled.y, 1.0, "first frame %s, laid out %s, before the card %s" % [first, settled, before])


## Placing the hold marker, pinned at each side and over the spot, with the flag marker up, makes no objects a frame.
func test_placing_the_hold_marker_with_the_stacks_allocates_no_objects() -> void:
	var r := await _markers_ready(Vector3(0.0, 1.7, 0.0))
	var hud: Hud = r["hud"]
	var camera: Camera3D = r["camera"]
	var pole := Vector3(0.0, 0.0, -30.0)
	var spots: Array[Vector3] = [Vector3(-60.0, 0.0, -20.0), Vector3(60.0, 0.0, -20.0), Vector3(0.0, 0.0, -20.0)]
	for spot in spots:
		hud.place_flag_marker(camera, pole, true)
		hud.place_hold_marker(camera, spot, true)
	var before := Performance.get_monitor(Performance.OBJECT_COUNT)
	for i in 60:
		for spot in spots:
			hud.place_flag_marker(camera, pole, true)
			hud.place_hold_marker(camera, spot, true)
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), before, "no objects made over 180 placements")


## The card's height on its first frame is the height it settles at, for a short, a long and an unbreakable note.
func test_the_card_is_its_real_height_on_the_first_frame_whatever_the_note() -> void:
	var r := await _markers_ready(Vector3(0.0, 1.7, 0.0))
	var s: PlaySession = r["s"]
	var hud: Hud = r["hud"]
	var notes: Array[String] = ["", "holds the stairs.",
			"holds one spot short of the middle, aiming over cover, until late in the round, and then falls back to the stairs "
			+ "to watch the long lane for anyone who dares to cross it, and never once peeks the same corner twice. ".repeat(3),
			"Verylongunbrokenwordwithoutanyspacesatalltotestthewrapofthenoteinthecardwhichmustnotwidenthecardbeyonditswidth",
			"待ち伏せして長いレーンを見張り、誰かが横切るのを待っている。ラウンドの終わりまで同じ場所に留まる。".repeat(3)]
	for note in notes:
		var card := _card(s, note)
		var first := card.get_combined_minimum_size()
		var width := card.get_combined_minimum_size().x
		await wait_process_frames(3)
		assert_almost_eq(card.size.y, first.y, 1.0, "height on frame one for %s" % note.left(20))
		assert_almost_eq(card.size.x, WhatGotYouCard.WIDTH, 1.0, "card width for %s (min %s)" % [note.left(20), width])


## The hold marker pinned to a side and stepped clear of a flag marker over its pole stays off the minimap, the card and
## the screen's edge.
func test_a_side_pinned_hold_marker_stepped_clear_of_an_unpinned_flag_keeps_off_the_panel_and_the_card() -> void:
	var r := await _markers_ready(Vector3(0.0, 1.7, 0.0))
	var s: PlaySession = r["s"]
	var hud: Hud = r["hud"]
	var camera: Camera3D = r["camera"]
	var screen := Rect2(Vector2.ZERO, HUD_SIZE)
	for with_card: bool in [false, true]:
		if with_card:
			_card(s)
			await wait_process_frames(3)
		for side: float in [-1.0, 1.0]:
			var tried := 0
			for px in range(4, 28):
				for i in 21:
					camera.rotation = Vector3(-0.5 + 0.05 * i, 0.0, 0.0)
					hud.update(s.state, 1.0, 0.0)
					hud.place_flag_marker(camera, Vector3(side * px, 0.0, -20.0), true)
					hud.place_hold_marker(camera, Vector3(side * 60.0, 0.0, -20.0), true)
					var flag: Rect2 = hud._flag_marker.occupied()
					if not flag.has_area() or hud._flag_marker.pinned_side() != 0:
						continue
					var hold := hud.hold_marker().get_rect()
					if hud.hold_marker().pin == HudHoldMarker.Pin.NONE:
						continue
					tried += 1
					var tag := "card %s side %s pole %d pitch %d hold %s flag %s" % [with_card, side, px, i, hold, flag]
					assert_true(screen.encloses(hold), "on screen, " + tag)
					assert_eq(hold.intersection(hud.minimap().panel_rect()).get_area(), 0.0, "off the panel, " + tag)
					if with_card:
						assert_eq(hold.intersection(hud.what_got_you().get_rect()).get_area(), 0.0, "off the card, " + tag)
