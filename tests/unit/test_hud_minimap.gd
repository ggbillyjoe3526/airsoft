extends GutTest
## The minimap on the HUD (MM4): the panel, caption and area label follow the character the view is through; Rotating
## turns the field so the view is up and Fixed keeps north up and turns the arrow; teammates are dots (grey once hit, an
## arrow on another storey), the other team shows only as patches, a patch is whole on the panel or a mark on the rim
## and never both; the pole and your Hold here show when they should; the flag marker pinned past the panel's side sits
## under it; none on the range; a frame allocates nothing.

var cfg: MinimapConfig = null
var teams: TeamConfig = null
var state: GameState = null
var heard: MinimapHearing = null
var you: Character = null
var mate: Character = null
var hurt: Character = null
var enemy: Character = null
var map: MapData = null
var mm: HudMinimap = null


func before_all() -> void:
	map = YardMap.load_map(MapStyle.new(), 1)


func before_each() -> void:
	cfg = MinimapConfig.new()
	teams = TeamConfig.new()
	state = GameState.new(5)
	state.match_number = 1
	var kit: Array[ReplicaConfig] = [ReplicaConfig.new()]
	you = Character.new(0, 0, Vector3(-10.0, 0.0, 1.5), 0.0, kit)
	mate = Character.new(1, 0, Vector3(-3.5, 0.0, -3.5), 0.0, kit)
	hurt = Character.new(2, 0, Vector3(-13.5, 0.0, 5.5), 0.0, kit)
	enemy = Character.new(3, 1, Vector3(3.0, 0.0, -4.0), 0.0, kit)
	var everyone: Array[Character] = [you, mate, hurt, enemy]
	for c in everyone:
		state.characters.append(c)
		c.prev_position = c.position
	hurt.status = Character.Status.CALLING
	heard = MinimapHearing.new(cfg)
	heard.on_tick(state, you)


func _panel(on: MapData = null, name_of_map: String = "Depot") -> HudMinimap:
	mm = HudMinimap.new()
	add_child_autofree(mm)
	mm.setup(cfg, teams, on if on != null else map, heard, name_of_map, state.characters.size(), Vector2(32.0, 26.0))
	return mm


func _follow(watched: Character = null, yaw: float = 0.0, turn: HudPrefs.MinimapTurn = HudPrefs.MinimapTurn.ROTATING,
		holding: bool = false, hold: Vector3 = Vector3.ZERO) -> void:
	mm.follow(state, watched if watched != null else you, yaw, 1.0, turn, holding, hold)


## A live patch for `who` at `at` (flat), `radius` m, as the hearing would leave it.
func _patch(who: Character, at: Vector3, radius: float = 3.0, shot: bool = false) -> void:
	var p := heard.patch_of(who.id)
	p.live = true
	p.centre = at
	p.radius = radius
	p.heard_at = heard.time
	p.sound = MinimapHearing.Sound.SHOT if shot else MinimapHearing.Sound.STEP


# --- the panel ---

func test_the_panel_names_the_map_and_round_and_where_the_character_stands() -> void:
	_panel()
	state.round_state.number = 2
	_follow()
	assert_eq(mm.caption_text(), "Depot · Round 2")
	assert_eq(mm.area_text(), MapAreas.area_at(map.areas, you.position))
	assert_ne(mm.area_text(), "", "the spot is in a named area")
	assert_eq(mm.view().size, Vector2(cfg.size - cfg.ring * 2.0, cfg.size - cfg.ring * 2.0), "the field fills the ring")
	assert_eq(mm.custom_minimum_size, Vector2.ZERO)
	assert_eq(mm.offset_bottom - mm.offset_top, cfg.size + cfg.caption_room, "the panel and its caption's room")


func test_the_area_label_is_rebuilt_only_when_the_area_changes() -> void:
	_panel()
	_follow()
	var first := mm.area_text()
	mm._area.text = "marker" # a rebuild would overwrite this
	_follow()
	assert_eq(mm._area.text, "marker", "the same area leaves the label alone")
	you.position = Vector3(8.0, 0.0, 1.5)
	you.prev_position = you.position
	_follow()
	assert_ne(mm.area_text(), "marker", "another area rebuilds it")
	assert_ne(mm.area_text(), first)
	you.position = Vector3(500.0, 0.0, 500.0)
	you.prev_position = you.position
	_follow()
	assert_eq(mm.area_text(), "", "none where no area is named")


func test_it_follows_the_one_the_view_is_through_and_their_team() -> void:
	_panel()
	_follow(mate)
	assert_eq(mm.area_text(), MapAreas.area_at(map.areas, mate.position))
	var view := mm.view()
	assert_eq(view._centre, Vector2(mate.position.x, mate.position.z))
	assert_eq(view._dot_count, 2, "you and the hurt teammate: the others on their team")
	assert_eq(view._team, teams.colours[0])
	_follow(enemy)
	assert_eq(view._team, teams.colours[1], "through an enemy's eyes the team is theirs")
	assert_eq(view._dot_count, 0, "nobody else on their side")


func test_rotating_turns_the_field_and_fixed_turns_the_arrow() -> void:
	_panel()
	var view := mm.view()
	var yaw := -PI / 2.0 # looking east: -z is north, so yaw 0 looks north and a right turn is negative
	_follow(you, yaw, HudPrefs.MinimapTurn.ROTATING)
	assert_almost_eq(view._rot, yaw, 0.0001)
	assert_eq(view._arrow_rot, 0.0, "the arrow always points up")
	var east := view._to_panel(Vector2(you.position.x + 10.0, you.position.z))
	assert_almost_eq(east.x, 0.0, 0.001, "what is east is straight up")
	assert_almost_eq(east.y, -10.0 * view._ppm, 0.001)
	_follow(you, yaw, HudPrefs.MinimapTurn.FIXED)
	assert_eq(view._rot, 0.0, "north stays up")
	assert_almost_eq(view._arrow_rot, PI / 2.0, 0.0001, "the arrow turns to face east")
	var again := view._to_panel(Vector2(you.position.x + 10.0, you.position.z))
	assert_almost_eq(again.x, 10.0 * view._ppm, 0.001, "east is to the right")
	assert_almost_eq(again.y, 0.0, 0.001)


func test_the_panel_scale_is_the_view_radius_across_the_square() -> void:
	_panel()
	_follow()
	var view := mm.view()
	assert_almost_eq(view._ppm * cfg.view_radius, view.size.x * 0.5, 0.001)


# --- who is drawn ---

func test_teammates_are_dots_grey_once_hit_and_enemies_are_never_dots() -> void:
	_panel()
	_follow()
	var view := mm.view()
	assert_eq(view._dot_count, 2, "both teammates and nobody else")
	assert_eq(view._dot_colours[0], teams.colours[0])
	assert_eq(view._dot_colours[1], cfg.out_colour, "the one hit is grey")
	assert_eq(view._dot_arrows[0], 0)
	assert_eq(view._dots[0], Vector2(mate.position.x, mate.position.z))


func test_a_teammate_on_another_storey_is_an_arrow_up_or_down() -> void:
	var tower := TowerBlock.load_map(MapStyle.new(), 1)
	assert_true(tower.ok(), "the map loads")
	_panel(tower, "Tower Block")
	you.position = Vector3(8.5, 6.0, 7.3)
	you.prev_position = you.position
	mate.position = Vector3(11.0, 0.0, -2.0)
	mate.prev_position = mate.position
	hurt.position = Vector3(0.5, 6.0, 7.3)
	hurt.prev_position = hurt.position
	hurt.status = Character.Status.ALIVE
	_follow()
	var view := mm.view()
	assert_eq(view.layers(), 3, "one picture a storey")
	assert_eq(view._layer, 2, "your storey's drawing")
	assert_eq(view._dot_arrows[0], -1, "below you")
	assert_eq(view._dot_arrows[1], 0, "level with you")
	you.position = Vector3(8.5, 0.0, 7.3)
	you.prev_position = you.position
	_follow()
	assert_eq(view._layer, 0)
	assert_eq(view._dot_arrows[1], 1, "above you now")
	assert_eq(mm.area_text(), MapAreas.area_at(tower.areas, you.position))
	_patch(enemy, Vector3(3.0, 6.0, -4.0))
	_follow()
	assert_eq(view._patch_count, 0, "a patch heard on another storey is not on this drawing")
	you.position = Vector3(8.5, 6.0, 7.3)
	you.prev_position = you.position
	_follow()
	assert_eq(view._patch_count, 1, "up there it is")


func test_patches_are_anonymous_and_only_those_on_your_storey_and_live() -> void:
	_panel()
	_patch(enemy, Vector3(3.0, 0.0, -4.0), 4.0, true)
	_follow()
	var view := mm.view()
	assert_eq(view._patch_count, 1)
	assert_eq(view._patches[0], Vector2(3.0, -4.0))
	assert_eq(view._patch_shots[0], 1, "a shot")
	assert_eq(view._enemy, teams.colours[1], "the team's colour, never a player's")
	heard.patch_of(enemy.id).live = false
	_follow()
	assert_eq(view._patch_count, 0, "a patch that is over is gone")


func test_a_patch_is_whole_on_the_panel_or_a_mark_on_the_rim_never_both() -> void:
	_panel()
	var view := mm.view()
	_follow()
	var reach := view._half
	for metres: float in [2.0, 12.0, 19.5, 20.5, 30.0]:
		for turn: float in [0.0, 1.0, 2.5, -2.0]:
			_follow(you, turn)
			var p := view._to_panel(Vector2(you.position.x + metres, you.position.z))
			var whole := not view._off(p)
			assert_eq(whole, absf(p.x) <= reach and absf(p.y) <= reach, "%s m at %s" % [metres, turn])
			var pinned := view._pin(p, 4.0)
			assert_true(absf(pinned.x) <= reach and absf(pinned.y) <= reach, "a rim mark stays on the panel")
	# the middle of the panel, a corner a little inside and the same corner a little outside
	assert_false(view._off(Vector2.ZERO))
	assert_false(view._off(Vector2(reach, reach)), "the corner itself is on the panel")
	assert_true(view._off(Vector2(reach + 0.5, 0.0)))


func test_the_pole_shows_while_the_round_is_live_in_attack_defend_only() -> void:
	_panel()
	var rs := state.round_state
	rs.pole = Vector3(11.5, 0.0, 1.0)
	_follow()
	assert_eq(mm.view().pole_count(), 0, "not in Elimination")
	rs.mode = RoundState.Mode.ATTACK_DEFEND
	rs.attackers = 0
	rs.phase = RoundState.Phase.LIVE
	_follow()
	assert_eq(mm.view().pole_count(), 1, "live")
	assert_eq(mm.view().pole_at(0), Vector2(11.5, 1.0))
	rs.phase = RoundState.Phase.OVER
	_follow()
	assert_eq(mm.view().pole_count(), 0, "not once the round is over")


func test_your_hold_is_a_diamond_while_it_is_in_force() -> void:
	_panel()
	_follow(you, 0.0, HudPrefs.MinimapTurn.ROTATING, true, Vector3(6.0, 0.0, -5.0))
	assert_true(mm.view()._hold_on)
	assert_eq(mm.view()._hold, Vector2(6.0, -5.0))
	_follow()
	assert_false(mm.view()._hold_on, "none once the order ends, or for a hold where each stood")


func test_a_field_with_no_layers_still_gets_a_panel() -> void:
	var woodland := MapData.load_map("woodland", MapStyle.new(), 1)
	woodland.terrain = null # its roof ramps alone: nothing to draw
	_panel(woodland, "Woodland")
	_follow()
	var view := mm.view()
	assert_eq(view.layers(), 0, "a field of ramps alone draws nothing")
	assert_eq(view._layer, -1)
	assert_eq(view._dot_count, 2, "teammates still show")
	_patch(enemy, Vector3(3.0, 0.0, -4.0))
	_follow()
	assert_eq(view._patch_count, 1, "and patches")


# --- frames ---

func test_a_frame_allocates_nothing() -> void:
	_panel()
	_patch(enemy, Vector3(3.0, 0.0, -4.0), 3.0, true)
	for i in 3:
		_follow(you, float(i))
		await wait_process_frames(1)
	var before := Performance.get_monitor(Performance.OBJECT_COUNT)
	for i in 12:
		_follow(you, float(i) * 0.1, HudPrefs.MinimapTurn.ROTATING if i % 2 == 0 else HudPrefs.MinimapTurn.FIXED, true,
				Vector3(6.0, 0.0, -5.0))
		await wait_process_frames(1)
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), before)


func test_the_pictures_go_with_the_panel() -> void:
	_panel()
	var textures: Array[Texture2D] = mm.view()._textures
	assert_eq(textures.size(), 1)
	assert_true(textures[0].get_width() > 0)
	var guard: WeakRef = weakref(textures[0])
	textures = []
	mm.free()
	await wait_process_frames(1)
	assert_null(guard.get_ref(), "freed with the panel")


# --- in the match ---

func _session(mode: String = MatchOptions.MODE_ELIMINATION, practice: bool = false, map_id: String = "") -> PlaySession:
	var s := PlaySession.new()
	s.mode = mode
	s.practice = practice
	if map_id != "":
		s.map_id = map_id
	s.bots_active = false
	add_child_autofree(s)
	return s


func test_the_hud_has_no_panel_on_the_range() -> void:
	var s := _session(MatchOptions.MODE_ELIMINATION, true, "range")
	await wait_physics_frames(2)
	assert_null(s.hud().minimap(), "none on the range")


func test_practice_on_a_field_has_its_panel_captioned_practice() -> void:
	var s := _session(MatchOptions.MODE_PRACTICE, true, "depot")
	await wait_physics_frames(2)
	assert_not_null(s.hud().minimap(), "a field's minimap in practice (WL9)")
	assert_string_contains(s.hud().minimap().caption_text(), "Practice", "no rounds to count")


func test_what_got_you_and_the_pinned_flag_marker_sit_under_the_panel_and_the_summary_hides_it() -> void:
	var s := _session(MatchOptions.MODE_ATTACK_DEFEND)
	await wait_physics_frames(2)
	var hud := s.hud()
	var panel := hud.minimap()
	assert_not_null(panel, "in a match")
	assert_eq(panel.area_text(), MapAreas.area_at(s._map.areas, s.player.position))
	var below := panel.under_top()
	assert_eq(below, cfg.under_gap + HudConfig.new().minimap_margin.y + cfg.size + cfg.caption_room)
	# the flag marker with the pole behind you: pinned to the side, the first one under the caption
	var pole := s.state.round_state.pole
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.global_position = pole + Vector3(6.0, 1.7, -24.0) # the pole is behind you, to the left
	hud.place_flag_marker(camera, pole, true)
	var marker: HudFlagMarker = hud._flag_marker
	assert_true(marker._edge.visible, "pinned to the side")
	assert_false(marker._plate.visible)
	assert_eq(marker._edge.position.y, below)
	assert_eq(marker._edge.position.x, cfg.pin_x)
	assert_eq(hud.pin_point(), Vector2(cfg.pin_x, below))
	# What got you under the caption, and the marker under it
	hud.show_what_got_you(HitFacts.new(), "Dash", Color.ORANGE, "")
	assert_eq(hud.what_got_you().offset_top, below, "under the caption, as the concept")
	hud.place_flag_marker(camera, pole, true)
	var card := hud.what_got_you()
	await wait_process_frames(2)
	hud.place_flag_marker(camera, pole, true)
	assert_almost_eq(marker._edge.position.y, card.position.y + card.size.y + cfg.under_gap, 0.5, "as laid out")
	camera.global_position = pole + Vector3(0.0, 1.7, 24.0)
	camera.look_at(pole)
	hud.place_flag_marker(camera, pole, true)
	assert_true(marker._plate.visible, "in view it sits over the pole as before")
	assert_false(marker._edge.visible)
	hud.update(s.state, 1.0, 0.0)
	assert_true(panel.visible)
	hud.summary().open(s.state, s.match_stats(), s.player, false, "")
	hud.update(s.state, 1.0, 0.0)
	assert_false(panel.visible, "hidden under the match summary")
