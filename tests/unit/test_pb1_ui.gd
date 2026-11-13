extends GutTest
## Plant The Bomb's screens (PB1): the Match page's card, the loading screen's kicker and the summary line; the HUD in a
## plant round (the score bar's fuse clock, the gauge under it, the banners and the round's end stamps, the prompt, the
## marker, the feed's notes); the minimap's sites and bomb, the full-screen map's header, sites and key; the screen
## reader's lines. Driven the way test_flag_play.gd drives Attack / Defend's HUD: the plant state set by hand.

var tuning: SimTuning = null
var state: GameState = null
var you: Character = null
var mate: Character = null
var foe: Character = null
var hud: Hud = null


func before_each() -> void:
	tuning = SimTuning.new()
	state = GameState.new(1, tuning)


## A HUD for a player on `team` in a live plant round: team 0 attacks, sites A at (20, 0, 0) and B at (-30, 0, 0), the
## bomb lying at (2, 0, 0). You stand at the origin, a teammate at (4, 0, 0), a foe at (-4, 0, 0).
func _plant_hud(team: int = 0) -> Hud:
	var kit := ReplicaStats.default_loadout()
	you = Character.new(0, team, Vector3.ZERO, 0.0, kit)
	mate = Character.new(1, team, Vector3(4.0, 0.0, 0.0), 0.0, kit)
	foe = Character.new(2, 1 - team, Vector3(-4.0, 0.0, 0.0), 0.0, kit)
	for c: Character in [you, mate, foe]:
		c.prev_position = c.position
		state.characters.append(c)
	var rs := state.round_state
	rs.mode = RoundState.Mode.PLANT_THE_BOMB
	rs.attackers = 0
	rs.clock = 60.0
	rs.plant.set_sites(PackedVector3Array([Vector3(20.0, 0.0, 0.0), Vector3(-30.0, 0.0, 0.0)]), PackedFloat32Array(),
			tuning.plant.site_radius)
	rs.plant.start = Vector3(2.0, 0.0, 0.0)
	rs.plant.reset()
	hud = Hud.new()
	add_child_autofree(hud)
	hud.size = Vector2(1920.0, 1080.0)
	hud.setup(HudConfig.new(), TeamConfig.new(), ViewConfig.new(), tuning, you)
	return hud


func _update() -> void:
	hud.update(state, 1.0, 0.0)


## Arms the bomb in site `site`, `fuse` s from going off.
func _arm(site: int, fuse: float = 30.0) -> PlantState:
	var ps := state.round_state.plant
	ps.status = PlantState.Status.PLANTED
	ps.site = site
	ps.position = ps.sites[site]
	ps.fuse_left = fuse
	ps.carrier = -1
	return ps


func _event(kind: GameEvent.Kind, value: int = 0, value2: int = 0, actor: int = -1) -> GameEvent:
	state.events.clear()
	var e := state.events.add(kind)
	e.value = value
	e.value2 = value2
	e.actor = actor
	return e


func _camera_at(at: Vector3) -> Camera3D:
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.global_position = at
	return camera


# --- the Match page ---

func test_the_mode_is_listed_third_pickable_on_a_field_with_poles_and_not_on_the_range() -> void:
	assert_eq(MatchOptions.MODES, PackedStringArray(["attack_defend", "elimination", "plant_the_bomb", "practice"]))
	assert_eq(MatchOptions.MODES[2], MatchOptions.MODE_PLANT_THE_BOMB)
	assert_eq(MatchOptions.DEFAULT_MODE, MatchOptions.MODE_ATTACK_DEFEND, "Attack / Defend stays the default")
	assert_true(MatchOptions.BUILT_MODES.has(MatchOptions.MODE_PLANT_THE_BOMB))
	var catalog := MapCatalog.shared()
	var depot := catalog.find("depot")
	var range_map := catalog.find("range")
	assert_true(MatchOptions.mode_pickable("plant_the_bomb", depot, true))
	assert_false(MatchOptions.mode_pickable("plant_the_bomb", depot, false), "its sites default to the poles")
	assert_true(MatchOptions.needs_pole("plant_the_bomb", depot, false))
	assert_false(MatchOptions.needs_pole("plant_the_bomb", depot, true))
	assert_false(MatchOptions.mode_pickable("plant_the_bomb", range_map, true), "a field hosts it, not the range")
	assert_eq(MatchOptions.only_tag_key("plant_the_bomb", range_map), MatchOptions.FIELDS_ONLY_KEY)
	assert_eq(MatchOptions.only_tag_key("plant_the_bomb", depot), "")
	assert_true(MatchOptions.POLE_MODES.has("plant_the_bomb"))


func test_the_loading_screens_kicker_and_the_summary_line_read_right() -> void:
	assert_eq(MatchOptions.kicker("plant_the_bomb", 3, 0), "PLANT THE BOMB · 3 V 3 · YOU'RE ALPHA")
	assert_eq(MatchOptions.kicker("plant_the_bomb", 4, 1), "PLANT THE BOMB · 4 V 4 · YOU'RE BETA")
	assert_eq(MatchOptions.summary_rest("plant_the_bomb", 0, "normal"),
			"Plant The Bomb · Alpha attacks first · Normal bots")
	assert_eq(MatchOptions.summary_rest("attack_defend", 0, "normal"),
			"Attack / Defend · Alpha attacks first · Normal bots", "Attack / Defend as before")
	assert_eq(MatchOptions.summary_rest("elimination", 1, "hard"), "Elimination · Beta · Hard bots", "Elimination too")


func test_the_page_shows_the_card_names_who_attacks_first_and_says_when_a_pole_is_missing() -> void:
	var page := MatchPage.new(MatchPicks.new(), Settings.new())
	add_child_autofree(page)
	var card := page.mode_card("plant_the_bomb")
	assert_false(card.disabled)
	assert_eq(page.mode_blurb("plant_the_bomb"), "Plant the bomb at Site A or B, or defuse it in time.")
	assert_false(page.says_needs_pole("plant_the_bomb"), "Depot has poles")
	card.pressed.emit()
	assert_eq(page.picks.mode, "plant_the_bomb")
	assert_true(card.is_picked())
	assert_eq(page.attack_line(), "Alpha attacks first, sides swap at half time", "the team row, as Attack / Defend")
	assert_eq(page.summary_text(), "Depot · Plant The Bomb · Alpha attacks first · Normal bots")
	page.mode_card("elimination").pressed.emit()
	assert_eq(page.attack_line(), "")
	page._poles["depot"] = false
	page._pick_map("depot")
	assert_true(page.says_needs_pole("plant_the_bomb"), "greyed for want of a pole")
	assert_true(card.disabled)
	page._pick_map("range")
	assert_eq(page.picks.mode, MatchOptions.MODE_PRACTICE, "the range plays Practice")
	assert_true(card.disabled, "and the bomb is not on offer there")


func test_the_modes_win_and_loss_records_are_kept_under_its_id() -> void:
	var records := Records.new()
	var r := Records.Result.new()
	r.mode = MatchOptions.MODE_PLANT_THE_BOMB
	r.won = true
	records.add(r)
	assert_eq(records.win_loss(&"normal", "plant_the_bomb"), PackedInt32Array([1, 0]))
	var back := Records.new()
	assert_eq(back.from_dict(records.to_dict()), [] as Array[String], "the key passes the save's check")
	assert_eq(back.win_loss(&"normal", "plant_the_bomb"), PackedInt32Array([1, 0]))
	assert_eq(back.win_loss(&"normal", "attack_defend"), PackedInt32Array([0, 0]))


# --- the score bar ---

func test_the_score_bar_tags_the_sides_and_shows_the_fuse_in_the_overtime_style() -> void:
	_plant_hud()
	_update()
	var score := hud.score()
	assert_eq(score.tag_text(0), "ATK")
	assert_eq(score.tag_text(1), "DEF")
	assert_eq(score.clock_text(), "1:00", "the round clock before the bomb is armed")
	var ps := _arm(0, 37.4)
	state.round_state.clock = 0.0
	_update()
	assert_eq(score.clock_text(), "0:38", "the fuse's whole seconds left, not the round clock, and no OT")
	assert_true(score.clock_is_fuse(), "in the accent colour")
	ps.fuse_left = 4.0
	_update()
	assert_eq(score.clock_text(), "0:04")
	state.round_state.clock = 20.0
	_update()
	assert_eq(score.clock_text(), "0:04", "once armed the round clock no longer matters")
	ps.status = PlantState.Status.DOWN
	_update()
	assert_eq(score.clock_text(), "0:20", "and the plain clock comes back")
	assert_false(score.clock_is_fuse())


func test_a_plant_under_way_at_the_buzzer_shows_like_the_ropes_overtime() -> void:
	_plant_hud()
	var rs := state.round_state
	rs.clock = 0.0
	rs.overtime = 1.5
	rs.plant.status = PlantState.Status.CARRIED
	rs.plant.carrier = 0
	rs.plant.planter = 0
	_update()
	assert_eq(hud.score().clock_text(), "OT 0:04", "five seconds of overtime less 1.5 played")
	rs.overtime = 5.0
	_update()
	assert_eq(hud.score().clock_text(), "OT 0:00")


func test_the_scoreboards_clock_follows_the_same_rule() -> void:
	_plant_hud()
	var rs := state.round_state
	var cap := tuning.plant.max_overtime
	assert_eq(HudStyle.overtime_clock(rs, cap), -1, "plenty of time")
	rs.clock = 0.0
	rs.overtime = 2.0
	assert_eq(HudStyle.overtime_clock(rs, cap), 3)
	_arm(1, 12.2)
	assert_eq(HudStyle.overtime_clock(rs, cap), 13, "the fuse once armed")
	rs.phase = RoundState.Phase.OVER
	assert_eq(HudStyle.overtime_clock(rs, cap), -1, "none once the round is over")
	rs.phase = RoundState.Phase.LIVE
	rs.mode = RoundState.Mode.ATTACK_DEFEND
	rs.overtime = 4.2
	assert_eq(HudStyle.overtime_clock(rs, 15.0), 11, "Attack / Defend's unchanged")


# --- the gauge ---

func test_the_gauge_is_hidden_unless_something_is_happening() -> void:
	_plant_hud()
	_update()
	assert_false(hud.flag_gauge().visible, "the bomb on the ground")
	state.round_state.plant.status = PlantState.Status.CARRIED
	state.round_state.plant.carrier = 0
	_update()
	assert_false(hud.flag_gauge().visible, "carried, not being armed")


func test_the_gauge_reads_planting_and_fills_with_the_arming_in_the_attackers_colour() -> void:
	_plant_hud()
	var rs := state.round_state
	var ps := rs.plant
	ps.status = PlantState.Status.CARRIED
	ps.carrier = 0
	ps.planter = 0
	ps.site = 0
	ps.planting = 0.5
	_update()
	var gauge := hud.flag_gauge()
	assert_true(gauge.visible)
	assert_eq(gauge.label_text(), "PLANTING")
	assert_eq(gauge.notches_filled(), 6, "half of 12 steps")
	assert_eq(gauge._colour, TeamConfig.new().colours[0])
	assert_true(gauge.bomb_sign(), "the carry case at the end")
	ps.planting = 0.99
	_update()
	assert_eq(gauge.notches_filled(), 11)


func test_the_gauge_reads_defusing_in_the_defenders_colour_and_keeps_the_checkpoint_as_bomb_armed() -> void:
	_plant_hud()
	var ps := _arm(1)
	ps.defuser = 2
	ps.defusing = 0.25
	_update()
	var gauge := hud.flag_gauge()
	assert_true(gauge.visible)
	assert_eq(gauge.label_text(), "DEFUSING")
	assert_eq(gauge.notches_filled(), 3)
	assert_eq(gauge._colour, TeamConfig.new().colours[1])
	ps.defuser = -1
	ps.defusing = tuning.plant.defuse_checkpoint
	_update()
	assert_true(gauge.visible, "armed, nobody on it")
	assert_eq(gauge.label_text(), "BOMB ARMED", "under the score bar for everyone once armed (PB3, the owner's ask)")
	assert_eq(gauge.notches_filled(), 6, "the kept progress")
	ps.defusing = 0.0
	ps.site = 0
	_update()
	assert_eq(gauge.label_text(), "BOMB ARMED", "whichever site")
	assert_eq(gauge.notches_filled(), 0)
	ps.status = PlantState.Status.DEFUSED
	_update()
	assert_false(gauge.visible, "gone with the bomb")


func test_the_gauge_stripes_the_striped_teams_fill_with_patterns_on() -> void:
	_plant_hud()
	hud.set_patterns(true)
	var ps := _arm(0)
	ps.defuser = 2
	ps.defusing = 0.5
	_update()
	assert_true(hud.flag_gauge().striped(), "the defenders are Beta, the striped team")
	state.round_state.attackers = 1
	ps.defuser = -1
	_update()
	assert_false(hud.flag_gauge().striped(), "and Alpha's fill is plain")
	hud.set_patterns(false)
	state.round_state.attackers = 0
	ps.defuser = 2
	_update()
	assert_false(hud.flag_gauge().striped(), "patterns off")


func test_the_gauges_new_words_fit_its_label_column() -> void:
	_plant_hud()
	var ps := _arm(0)
	ps.defuser = 2
	ps.defusing = 0.5
	_update()
	await wait_process_frames(2)
	var label: Label = hud.flag_gauge()._label
	assert_lte(label.get_combined_minimum_size().x, HudStyle.GAUGE_LABEL_WIDTH + 1.0, "DEFUSING in its column")
	ps.defuser = -1
	ps.status = PlantState.Status.CARRIED
	ps.carrier = 0
	ps.planter = 0
	_update()
	await wait_process_frames(2)
	assert_lte(label.get_combined_minimum_size().x, HudStyle.GAUGE_LABEL_WIDTH + 1.0, "PLANTING in its column")
	ps.planter = -1
	ps.carrier = -1
	ps.status = PlantState.Status.PLANTED
	_update()
	await wait_process_frames(2)
	assert_eq(hud.flag_gauge().label_text(), "BOMB ARMED")
	assert_lte(label.get_combined_minimum_size().x, HudStyle.GAUGE_LABEL_WIDTH,
			"BOMB ARMED in its column, no overflow into the gap before the track (PB3)")


# --- banners and the round's end ---

func test_the_round_starts_with_each_sides_job() -> void:
	_plant_hud()
	_event(GameEvent.Kind.ROUND_START, 1)
	hud.on_tick(state)
	assert_eq(hud.banner_text(), "ROUND 1 · ATTACK / PLANT THE BOMB")
	state.characters.clear()
	hud.queue_free()
	_plant_hud(1)
	_event(GameEvent.Kind.ROUND_START, 1)
	hud.on_tick(state)
	assert_eq(hud.banner_text(), "ROUND 1 · DEFEND / HOLD SITES A AND B")
	_event(GameEvent.Kind.ROUND_START, tuning.rounds.half_time_after + 1)
	hud.on_tick(state)
	assert_string_contains(hud.banner_text(), "HALF TIME", "half time keeps its line")


func test_a_planted_bomb_is_a_banner_for_both_teams() -> void:
	_plant_hud()
	_event(GameEvent.Kind.PLANT, Plant.Cue.PLANTED, 1, 0)
	hud.on_tick(state)
	assert_eq(hud.banner_text(), "BOMB PLANTED AT B / KEEP THEM OFF IT UNTIL IT GOES OFF")
	hud.queue_free()
	state.characters.clear()
	_plant_hud(1)
	_event(GameEvent.Kind.PLANT, Plant.Cue.PLANTED, 0, 2)
	hud.on_tick(state)
	assert_eq(hud.banner_text(), "BOMB PLANTED AT A / DEFUSE IT BEFORE IT GOES OFF")


func test_the_rounds_end_stamps_say_how_it_ended() -> void:
	_plant_hud()
	var expect := {
		[0, GameEvent.RoundEnd.WENT_OFF]: "WON / ROUND 1 · BOMB WENT OFF · ALPHA TAKE THE ROUND",
		[1, GameEvent.RoundEnd.DEFUSED]: "LOST / ROUND 1 · BOMB DEFUSED · BETA TAKE THE ROUND",
		[1, GameEvent.RoundEnd.TIME]: "LOST / ROUND 1 · DEFENDED · TIME'S UP · NOTHING PLANTED",
		[1, GameEvent.RoundEnd.ELIMINATED]: "LOST / ROUND 1 · BETA TAKE THE ROUND",
		[0, GameEvent.RoundEnd.ELIMINATED]: "WON / ROUND 1 · ALPHA TAKE THE ROUND",
	}
	for key: Array in expect:
		_event(GameEvent.Kind.ROUND_OVER, key[0], key[1])
		hud.on_tick(state)
		assert_eq(hud.banner_text(), expect[key], str(key))
	assert_eq(HudStyle.flag_round_won(GameEvent.RoundEnd.WENT_OFF), "BOMB WENT OFF")
	assert_eq(HudStyle.flag_round_won(GameEvent.RoundEnd.DEFUSED), "BOMB DEFUSED")
	assert_eq(HudStyle.flag_round_sub(GameEvent.RoundEnd.TIME, "TEAM_BETA"), "TIME'S UP · BETA HELD THE POLE",
			"Attack / Defend's time-out is worded as before")


# --- the prompt ---

func test_the_prompt_offers_each_job_to_the_player_who_can_do_it() -> void:
	_plant_hud()
	var rs := state.round_state
	var key := KeyNames.of_action(&"use_door").to_upper()
	var prompt := hud.plant_prompt()
	_update()
	assert_eq(prompt.text(), "", "the bomb is 2 m away")
	you.position = Vector3(1.0, 0.0, 0.0)
	_update()
	assert_eq(prompt.text(), "HOLD %s · PICK UP THE BOMB" % key)
	assert_false(prompt.visible and prompt.quiet_text() != "", "no quiet line while a prompt shows")
	# carried into the site: the plant
	rs.plant.status = PlantState.Status.CARRIED
	rs.plant.carrier = 0
	you.position = Vector3(2.0, 0.0, 0.0)
	_update()
	assert_eq(prompt.text(), "", "carrying it outside a site")
	assert_eq(prompt.quiet_text(), "YOU HAVE THE BOMB")
	you.position = Vector3(18.0, 0.0, 0.0)
	_update()
	assert_eq(prompt.text(), "HOLD %s · PLANT THE BOMB" % key)
	assert_eq(prompt.quiet_text(), "", "the prompt takes the quiet line's place")
	rs.plant.planter = 0
	_update()
	assert_eq(prompt.text(), "", "already arming it")
	assert_eq(prompt.quiet_text(), "", "setting it down: the PLANTING gauge says it, not the quiet line (PB3)")
	# a teammate carries it: nothing for you
	rs.plant.carrier = 1
	rs.plant.planter = -1
	_update()
	assert_false(prompt.visible)


func test_the_defender_is_offered_the_defuse_beside_the_armed_bomb() -> void:
	_plant_hud(1)
	var rs := state.round_state
	var key := KeyNames.of_action(&"use_door").to_upper()
	var ps := _arm(0)
	you.position = ps.position + Vector3(1.0, 0.0, 0.0)
	_update()
	assert_eq(hud.plant_prompt().text(), "HOLD %s · DEFUSE" % key)
	ps.defuser = 0
	_update()
	assert_eq(hud.plant_prompt().text(), "", "already on it")
	ps.defuser = -1
	you.position = ps.position + Vector3(8.0, 0.0, 0.0)
	_update()
	assert_false(hud.plant_prompt().visible, "out of reach")
	you.position = ps.position
	rs.attackers = 1
	_update()
	assert_false(hud.plant_prompt().visible, "an attacker has nothing to defuse")


func test_the_prompt_is_only_for_the_player_in_play_and_in_a_live_round() -> void:
	_plant_hud()
	you.position = Vector3(1.0, 0.0, 0.0)
	_update()
	assert_true(hud.plant_prompt().visible)
	hud.set_watching("Rook")
	_update()
	assert_false(hud.plant_prompt().visible, "not while watching a bot")
	hud.set_watching("")
	state.round_state.hold = 3.0
	_update()
	assert_false(hud.plant_prompt().visible, "not in the countdown")
	state.round_state.hold = 0.0
	you.status = Character.Status.CALLING
	_update()
	assert_false(hud.plant_prompt().visible, "not once hit")
	you.status = Character.Status.ALIVE
	_update()
	assert_true(hud.plant_prompt().visible)


func test_the_prompt_follows_the_hud_size() -> void:
	_plant_hud()
	you.position = Vector3(1.0, 0.0, 0.0)
	hud.set_hud_size(1.5)
	_update()
	assert_true(hud.plant_prompt().visible)
	assert_almost_eq(hud.scale.x, 1.5, 0.001)


# --- the marker ---

func test_the_marker_points_the_attackers_at_the_bomb_on_the_ground() -> void:
	_plant_hud()
	var rs := state.round_state
	var camera := _camera_at(Vector3(2.0, 1.7, 24.0))
	await wait_process_frames(2) # the camera projects once the window has been through a frame
	hud.place_plant_marker(camera, rs, you, -1)
	assert_eq(hud.flag_marker_text(), "BOMB · 24 m")
	assert_true(hud._flag_marker.bomb_sign(), "the carry case")
	camera.global_position = Vector3(2.0, 1.7, 1.0)
	hud.place_plant_marker(camera, rs, you, -1)
	assert_eq(hud.flag_marker_text(), "", "hidden close by, as the flag's")


func test_the_marker_points_a_defender_at_the_site_nearest_them() -> void:
	_plant_hud(1)
	var rs := state.round_state
	var camera := _camera_at(Vector3(20.0, 1.7, 24.0))
	await wait_process_frames(2) # the camera projects once the window has been through a frame
	hud.place_plant_marker(camera, rs, you, -1)
	assert_eq(hud.flag_marker_text(), "SITE A · 24 m", "A is the nearer to the origin")
	you.position = Vector3(-28.0, 0.0, 0.0)
	camera.global_position = Vector3(-30.0, 1.7, 24.0)
	hud.place_plant_marker(camera, rs, you, -1)
	assert_eq(hud.flag_marker_text(), "SITE B · 24 m")


func test_the_marker_follows_the_carry_and_the_bots_plan() -> void:
	_plant_hud()
	var rs := state.round_state
	var ps := rs.plant
	ps.status = PlantState.Status.CARRIED
	ps.carrier = 0
	var camera := _camera_at(Vector3(20.0, 1.7, 24.0))
	await wait_process_frames(2) # the camera projects once the window has been through a frame
	hud.place_plant_marker(camera, rs, you, 1)
	assert_eq(hud.flag_marker_text(), "SITE A · 24 m", "you carry it: the site nearest you, whatever the plan")
	ps.carrier = 1
	camera.global_position = Vector3(-30.0, 1.7, 24.0)
	hud.place_plant_marker(camera, rs, you, 1)
	assert_eq(hud.flag_marker_text(), "SITE B · 24 m", "a teammate carries it: the site the bots head for")
	camera.global_position = Vector3(20.0, 1.7, 24.0)
	hud.place_plant_marker(camera, rs, you, -1)
	assert_eq(hud.flag_marker_text(), "SITE A · 24 m", "no plan: the nearest")
	hud.place_plant_marker(camera, rs, foe, 1)
	assert_eq(hud.flag_marker_text(), "SITE A · 24 m", "a defender sees the nearest, not the bots' plan")


func test_the_marker_names_the_armed_bomb_for_both_teams() -> void:
	_plant_hud()
	var rs := state.round_state
	_arm(1)
	var camera := _camera_at(Vector3(-30.0, 1.7, 24.0))
	await wait_process_frames(2) # the camera projects once the window has been through a frame
	hud.place_plant_marker(camera, rs, you, 0)
	assert_eq(hud.flag_marker_text(), "BOMB B · 24 m")
	hud.place_plant_marker(camera, rs, foe, -1)
	assert_eq(hud.flag_marker_text(), "BOMB B · 24 m", "the defenders see it too")
	assert_eq(HudPlant.aim_spot(rs, HudPlant.aim(rs, foe, -1), 1), rs.plant.position)


func test_the_marker_is_hidden_when_the_round_is_not_under_way() -> void:
	_plant_hud()
	var rs := state.round_state
	var camera := _camera_at(Vector3(2.0, 1.7, 24.0))
	await wait_process_frames(2) # the camera projects once the window has been through a frame
	rs.phase = RoundState.Phase.OVER
	hud.place_plant_marker(camera, rs, you, -1)
	assert_eq(hud.flag_marker_text(), "")
	rs.phase = RoundState.Phase.LIVE
	rs.hold = 3.0
	hud.place_plant_marker(camera, rs, you, -1)
	assert_eq(hud.flag_marker_text(), "BOMB · 24 m", "shown through the countdown, as the flag's")
	rs.mode = RoundState.Mode.ATTACK_DEFEND
	hud.place_plant_marker(camera, rs, you, -1)
	assert_eq(hud.flag_marker_text(), "", "not outside the mode")


func test_the_flag_marker_keeps_its_own_words_and_sign() -> void:
	_plant_hud()
	var rs := state.round_state
	var camera := _camera_at(Vector3(2.0, 1.7, 24.0))
	await wait_process_frames(2) # the camera projects once the window has been through a frame
	hud.place_plant_marker(camera, rs, you, -1)
	assert_eq(hud.flag_marker_text(), "BOMB · 24 m")
	hud._flag_marker.use_bomb(false)
	hud.place_flag_marker(camera, Vector3(2.0, 0.0, 0.0), true, "B")
	assert_eq(hud.flag_marker_text(), "FLAG B · 24 m")
	hud.place_flag_marker(camera, Vector3(2.0, 0.0, 0.0), true, "")
	assert_eq(hud.flag_marker_text(), "FLAG · 24 m")
	assert_false(hud._flag_marker.bomb_sign())


# --- the feed ---

func test_the_feed_notes_the_pick_up_the_drop_the_plant_and_the_defuse() -> void:
	_plant_hud()
	var feed := hud.hit_lines()
	_event(GameEvent.Kind.PLANT, Plant.Cue.PICKED_UP, 0, 1)
	hud.on_tick(state)
	assert_eq(feed.count(), 1)
	assert_eq(feed.line(0).words, "picked up the bomb")
	assert_true(feed.line(0).note and feed.line(0).call)
	assert_eq(feed.line(0).shooter, 1)
	_event(GameEvent.Kind.PLANT, Plant.Cue.DROPPED, 0, 1)
	hud.on_tick(state)
	assert_eq(feed.line(0).words, "dropped the bomb")
	_event(GameEvent.Kind.PLANT, Plant.Cue.PLANTED, 1, 0)
	hud.on_tick(state)
	assert_eq(feed.line(0).words, "planted the bomb at B")
	_event(GameEvent.Kind.PLANT, Plant.Cue.DEFUSED, 0, 2)
	hud.on_tick(state)
	assert_eq(feed.line(0).words, "defused the bomb")
	assert_eq(feed.count(), 4)
	for cue: Plant.Cue in [Plant.Cue.ARMING, Plant.Cue.ARMING_STOPPED, Plant.Cue.BEEP, Plant.Cue.DEFUSING,
			Plant.Cue.DEFUSING_STOPPED, Plant.Cue.WENT_OFF]:
		_event(GameEvent.Kind.PLANT, cue, 0, 1)
		hud.on_tick(state)
	assert_eq(feed.count(), 4, "the rest are no news")
	_update()
	assert_eq(hud.feed().row_of(0).words(), "Beta: defused the bomb")
	assert_true(hud.feed().row_of(0).is_call())


func test_a_pick_up_and_a_drop_show_to_the_attackers_only() -> void:
	_plant_hud(1)
	_event(GameEvent.Kind.PLANT, Plant.Cue.PICKED_UP, 0, 2)
	hud.on_tick(state)
	_event(GameEvent.Kind.PLANT, Plant.Cue.DROPPED, 0, 2)
	hud.on_tick(state)
	assert_eq(hud.hit_lines().count(), 0, "a defender hears nothing of it")
	_event(GameEvent.Kind.PLANT, Plant.Cue.PLANTED, 0, 2)
	hud.on_tick(state)
	assert_eq(hud.hit_lines().count(), 1, "the plant is everyone's")


func test_a_note_ages_with_the_calls_and_goes_with_the_next_round() -> void:
	_plant_hud()
	_event(GameEvent.Kind.PLANT, Plant.Cue.PLANTED, 0, 1)
	hud.on_tick(state)
	assert_eq(hud.hit_lines().count(), 1)
	_event(GameEvent.Kind.ROUND_START, 2)
	hud.on_tick(state)
	assert_eq(hud.hit_lines().count(), 0, "a new round drops it, as the calls")


# --- the minimap and the full-screen map ---

func _minimap() -> HudMinimap:
	var cfg := MinimapConfig.new()
	var kit := ReplicaStats.default_loadout()
	you = Character.new(0, 0, Vector3(-10.0, 0.0, 1.5), 0.0, kit)
	mate = Character.new(1, 0, Vector3(-3.5, 0.0, -3.5), 0.0, kit)
	foe = Character.new(2, 1, Vector3(3.0, 0.0, -4.0), 0.0, kit)
	for c: Character in [you, mate, foe]:
		c.prev_position = c.position
		state.characters.append(c)
	var rs := state.round_state
	rs.mode = RoundState.Mode.PLANT_THE_BOMB
	rs.attackers = 0
	rs.plant.set_sites(PackedVector3Array([Vector3(8.0, 0.0, 2.0), Vector3(-6.0, 0.0, -9.0)]), PackedFloat32Array(),
			4.5)
	rs.plant.start = Vector3(-8.0, 0.0, 1.0)
	rs.plant.reset()
	var heard := MinimapHearing.new(cfg)
	heard.on_tick(state, you)
	var map := YardMap.load_map(MapStyle.new(), 1)
	var mm := HudMinimap.new()
	add_child_autofree(mm)
	mm.setup(cfg, TeamConfig.new(), map, heard, "Depot", state.characters.size(), Vector2(32.0, 26.0))
	return mm


func _follow(mm: HudMinimap, who: Character) -> void:
	mm.follow(state, who, 0.0, 1.0, HudPrefs.MinimapTurn.ROTATING, false, Vector3.ZERO)


func test_the_minimap_draws_both_sites_and_the_bomb_for_the_attackers_while_it_lies() -> void:
	var mm := _minimap()
	_follow(mm, you)
	var view := mm.view()
	assert_eq(view.site_count(), 2)
	assert_eq(view.site_at(0), Vector2(8.0, 2.0))
	assert_eq(view.site_at(1), Vector2(-6.0, -9.0))
	assert_eq(view.pole_count(), 0, "sites are not flags")
	assert_true(view.bomb_shown())
	assert_eq(view.bomb_at(), Vector2(-8.0, 1.0))
	assert_false(view.bomb_carried())
	_follow(mm, foe)
	assert_eq(view.site_count(), 2, "the defenders see the sites")
	assert_false(view.bomb_shown(), "but not the bomb on the ground")


func test_the_minimap_marks_the_carrier_for_the_attackers_and_the_armed_bomb_for_both() -> void:
	var mm := _minimap()
	var ps := state.round_state.plant
	ps.status = PlantState.Status.CARRIED
	ps.carrier = 1
	ps.position = mate.position
	_follow(mm, you)
	assert_true(mm.view().bomb_shown())
	assert_true(mm.view().bomb_carried(), "a small mark on the teammate's dot")
	assert_eq(mm.view().bomb_at(), Vector2(-3.5, -3.5))
	_follow(mm, foe)
	assert_false(mm.view().bomb_shown(), "the defenders never see the carry")
	_arm(1)
	_follow(mm, foe)
	assert_true(mm.view().bomb_shown())
	assert_false(mm.view().bomb_carried())
	assert_eq(mm.view().bomb_at(), Vector2(-6.0, -9.0))
	_follow(mm, you)
	assert_true(mm.view().bomb_shown(), "and the attackers")


func test_the_minimap_shows_nothing_of_it_out_of_the_mode_or_the_round() -> void:
	var mm := _minimap()
	state.round_state.phase = RoundState.Phase.OVER
	_follow(mm, you)
	assert_eq(mm.view().site_count(), 0)
	assert_false(mm.view().bomb_shown())
	state.round_state.phase = RoundState.Phase.LIVE
	state.round_state.mode = RoundState.Mode.ELIMINATION
	_follow(mm, you)
	assert_eq(mm.view().site_count(), 0)
	assert_false(mm.view().bomb_shown())


func test_the_site_and_bomb_marks_draw_without_error() -> void:
	var mm := _minimap()
	_arm(0)
	_follow(mm, you)
	mm.view().size = Vector2(240.0, 240.0)
	mm.view().queue_redraw()
	await wait_process_frames(2)
	assert_true(mm.view().bomb_shown())
	assert_gt(mm.view()._case.body().size.x, 0.0, "the case was fit for its drawing")


func _field_map(map: MapData) -> HudFieldMap:
	var cfg := MinimapConfig.new()
	var root := Control.new()
	root.size = Vector2(1920.0, 1080.0)
	add_child_autofree(root)
	var heard := MinimapHearing.new(cfg)
	heard.on_tick(state, you)
	var mm := HudMinimap.new()
	root.add_child(mm)
	mm.setup(cfg, TeamConfig.new(), map, heard, map.display_name, state.characters.size(), Vector2(32.0, 26.0))
	var fm := HudFieldMap.new()
	root.add_child(fm)
	fm.setup(cfg, mm, map, map.display_name, state.characters.size(), 8.0, 2.0)
	return fm


func test_the_full_screen_map_names_the_mode_the_job_and_lists_the_marks() -> void:
	var map := MapData.load_map("depot", MapStyle.new(), 2)
	_minimap()
	var fm := _field_map(map)
	var rs := state.round_state
	rs.plant.set_sites(map.bomb_sites, map.bomb_site_radii, 4.5)
	var pointer := MapPointer.new()
	pointer.start()
	fm.update(state, you, 0.0, 1.0, false, Vector3.ZERO, null, pointer, true, false)
	assert_eq(fm._sub.text, "Round 1  ·  Plant The Bomb")
	assert_eq(fm._goal.text, "You attack: plant the bomb at A / B")
	assert_true(fm._overlay._sites_on, "the sites' rings and letters")
	assert_eq(fm._overlay._sites_px.size(), map.bomb_sites.size())
	assert_eq(fm.view().site_count(), 0, "the overlay draws them, not the field's view")
	var key: FieldMapKey = null
	for c in fm.get_children():
		if c is FieldMapKey:
			key = c
	assert_eq(key.row_word(FieldMapKey.ROWS.find(FieldMapKey.Glyph.FLAG)), "Bomb site")
	assert_eq(key.row_word(FieldMapKey.ROWS.size()), "The bomb")
	assert_almost_eq(key.size.y, key.needed_height(), 0.01, "every row fits, the bomb's too")
	fm.update(state, foe, 0.0, 1.0, false, Vector3.ZERO, null, pointer, true, false)
	assert_eq(fm._goal.text, "You defend: keep the bomb off A / B, or defuse it")
	rs.mode = RoundState.Mode.ATTACK_DEFEND
	fm.update(state, you, 0.0, 1.0, false, Vector3.ZERO, null, pointer, true, false)
	assert_eq(fm._sub.text, "Round 1  ·  Attack / Defend")
	assert_false(fm._overlay._sites_on)
	assert_eq(key.row_word(FieldMapKey.ROWS.find(FieldMapKey.Glyph.FLAG)), "Flag", "the key goes back with the mode")
	assert_eq(key.row_word(FieldMapKey.ROWS.size()), "")


func test_every_map_with_a_pole_has_sites_the_map_marks_know() -> void:
	for id: String in ["depot", "woodland"]:
		var map := MapData.load_map(id, MapStyle.new(), 2)
		var marks := FieldMapMarks.of(map, 2.0)
		assert_eq(marks.sites.size(), map.bomb_sites.size(), id)
		assert_gt(marks.sites.size(), 0, id)


# --- the screen reader ---

func _announcer(team: int) -> Announcer:
	_plant_hud(team)
	var a := Announcer.new(TeamConfig.new(), you, tuning.rounds.half_time_after)
	return a


func test_the_screen_reader_says_the_rounds_start_and_end() -> void:
	var a := _announcer(0)
	var rs := state.round_state
	assert_eq(a.round_start_line(rs, 3), "Round 3 · Attack · Plant the bomb")
	assert_eq(a.round_start_line(rs, tuning.rounds.half_time_after + 1), "Round 5 · Attack · Half time · ends swapped")
	var score := " · Alpha 0 – 0 Beta"
	assert_eq(a.round_over_line(rs, 0, GameEvent.RoundEnd.WENT_OFF),
			"Won · Round 1 · Bomb went off · Alpha take the round" + score)
	assert_eq(a.round_over_line(rs, 1, GameEvent.RoundEnd.DEFUSED),
			"Lost · Round 1 · Bomb defused · Beta take the round" + score)
	assert_eq(a.round_over_line(rs, 1, GameEvent.RoundEnd.TIME),
			"Lost · Round 1 · Defended · Time's up · nothing planted" + score)
	assert_eq(a.round_over_line(rs, 1, GameEvent.RoundEnd.ELIMINATED), "Lost · Round 1 · Beta take the round" + score)
	var d := _announcer(1)
	assert_eq(d.round_start_line(state.round_state, 3), "Round 3 · Defend · Hold sites A and B")


func test_the_screen_reader_says_the_bomb_events_that_matter() -> void:
	var a := _announcer(0)
	_event(GameEvent.Kind.PLANT, Plant.Cue.PICKED_UP, 0, 1)
	a.on_tick(state)
	_event(GameEvent.Kind.PLANT, Plant.Cue.PLANTED, 1, 0)
	a.on_tick(state)
	_event(GameEvent.Kind.PLANT, Plant.Cue.BEEP, 100, 1)
	a.on_tick(state)
	a.advance(1.0)
	assert_eq(a.message(), "Alpha picked up the bomb. Bomb planted at B · Keep them off it until it goes off")
	var d := _announcer(1)
	_event(GameEvent.Kind.PLANT, Plant.Cue.PICKED_UP, 0, 1)
	d.on_tick(state)
	d.advance(1.0)
	assert_eq(d.message(), "", "the defenders hear nothing of the pick-up")
	_event(GameEvent.Kind.PLANT, Plant.Cue.PLANTED, 0, 0)
	d.on_tick(state)
	d.advance(1.0)
	assert_eq(d.message(), "Bomb planted at A · Defuse it before it goes off")
