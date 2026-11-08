extends GutTest
## BP8 HUD, the critic's second look: the round banner stays up through the whole countdown and GO (so the plate under it
## never jumps into its place), the weapon rail keeps its place whatever notes show under it, the bomb icons stand on a
## lighter plate, and the sim's end_countdown says GO.

var loadout: Array[ReplicaConfig] = []
var you: Character = null


func before_all() -> void:
	loadout = ReplicaStats.default_loadout()


func _hud() -> Hud:
	you = Character.new(0, 0, Vector3.ZERO, 0.0, loadout)
	you.grenades.carry(1, 1)
	var hud := Hud.new()
	add_child_autofree(hud)
	hud.size = Vector2(1920.0, 1080.0)
	hud.setup(HudConfig.new(), TeamConfig.new(), ViewConfig.new(), SimTuning.new(), you)
	var paints: Array[StringName] = [&"cobalt", &"cobalt"]
	hud.setup_weapon_rail(you.armament.replicas, paints, false)
	return hud


func test_the_banner_stays_up_through_the_countdown_and_go_and_goes_with_the_plate() -> void:
	var hud := _hud()
	var tuning := SimTuning.new()
	var state := GameState.new(1, tuning)
	state.characters.append(you)
	state.round_state.hold = 3.0
	state.round_state.mode = RoundState.Mode.ELIMINATION
	state.events.add(GameEvent.Kind.ROUND_START).value = 1
	state.events.add(GameEvent.Kind.ROUND_COUNT).value = 3
	hud.on_tick(state)
	assert_true(hud._banner.visible)
	assert_true(hud._count.visible)
	var cfg := HudConfig.new()
	var seconds := 0.0
	while seconds < 3.0:
		hud.update(state, 1.0, 0.1)
		seconds += 0.1
		assert_true(hud._banner.visible, "still up at %.1f s, past the banner's own %.1f s" % [seconds, cfg.banner_time])
		assert_true(hud._count.visible)
	state.events.clear()
	state.events.add(GameEvent.Kind.ROUND_GO)
	hud.on_tick(state)
	assert_eq(hud._count.big_text(), tr("HUD_ROUND_GO"))
	hud.update(state, 1.0, cfg.go_time * 0.5)
	assert_true(hud._banner.visible, "up through GO")
	hud.update(state, 1.0, cfg.go_time)
	assert_false(hud._count.visible, "GO is gone")
	hud.update(state, 1.0, 0.1)
	assert_false(hud._banner.visible, "and the banner with it")


func test_the_rail_keeps_its_place_whatever_notes_show_under_it_or_over_it() -> void:
	var hud := _hud()
	hud._replica.refresh(you.armament, you.grenades)
	await wait_process_frames(2)
	var rail := hud._rail
	var frame := hud._replica.find_child("Frame", false, false) as Control
	var rest := rail.global_position.y
	assert_lte(rail.get_global_rect().end.y, frame.global_position.y + 0.5, "the rail sits above the ammo panel")
	hud._replica.show_hop("HOP-UP 60")
	hud._replica._status.text = "RELOADING"
	hud._replica._status.visible = true
	await wait_process_frames(2)
	assert_almost_eq(rail.global_position.y, rest, 0.5, "the notes rise above it: the rail does not move")
	var notes_bottom := hud._replica._status.get_global_rect().end.y
	assert_lte(notes_bottom, rail.global_position.y + 0.5, "and sit clear of it")
	hud._replica.hide_hop()
	hud._replica._status.visible = false
	await wait_process_frames(2)
	assert_almost_eq(rail.global_position.y, rest, 0.5, "and back")


func test_a_bomb_icon_stands_on_a_lighter_plate_and_is_big_enough_to_read() -> void:
	var r := WeaponRail.new()
	add_child_autofree(r)
	var paints: Array[StringName] = [&"cobalt", &"cobalt"]
	r.setup(loadout, paints)
	var plate := r._glyph_plates[Grenade.Kind.FLASH - Grenade.Kind.SMOKE][0] as PanelContainer
	var box := plate.get_theme_stylebox("panel") as StyleBoxFlat
	assert_gt(box.bg_color.get_luminance(), 0.6, "a light plate under a dark model")
	assert_gte(box.bg_color.a, 0.75, "mostly opaque, so a dimmed row's plate still stands out from the dark glass")
	assert_gte(r._glyphs[1][0].custom_minimum_size.y, 44.0, "the icon is the row's height")


func test_end_countdown_says_go_once_and_makes_the_round_live() -> void:
	var rs := RoundState.new()
	rs.phase = RoundState.Phase.LIVE
	rs.hold = 2.0
	var events := SimEvents.new()
	Round.end_countdown(rs, events)
	assert_true(rs.is_live())
	assert_eq(events.count_of(GameEvent.Kind.ROUND_GO), 1)


func test_the_countdown_plate_is_not_drawn_under_the_pause_menu() -> void:
	var hud := _hud()
	hud._count.count(2)
	hud.set_paused(true)
	assert_eq(hud._count.modulate.a, 0.0, "the pause panel is see-through: the plate would show through it")
	hud.set_paused(false)
	assert_eq(hud._count.modulate.a, 1.0)
	assert_true(hud._count.visible, "and it is still counting")


func test_the_tab_board_hangs_under_the_score_column_even_with_the_flag_gauge_up() -> void:
	var hud := _hud()
	hud._gauge.visible = true
	await wait_process_frames(3)
	var column_foot := hud._top.position.y + hud._top.size.y
	assert_gte(hud._board.offset_top, column_foot, "the board starts under the FIRST TO line, not over it")


func test_the_pole_marker_is_not_drawn_through_the_tab_board() -> void:
	var hud := _hud()
	var camera := Camera3D.new()
	add_child_autofree(camera)
	hud._board.visible = true
	hud.place_flag_marker(camera, Vector3(0.0, 1.0, -20.0), true)
	assert_false(hud._flag_marker.visible, "the board is see-through: the marker would show through it")
	hud._board.visible = false
	hud.place_flag_marker(camera, Vector3(0.0, 1.0, -20.0), true)
	assert_true(hud._flag_marker.visible)


func test_the_pole_marker_never_sits_on_the_banner_or_the_countdown_plate() -> void:
	var hud := _hud()
	hud._banner.show_text("ROUND 1 · DEFEND", "HOLD THE POLE")
	hud._count.count(2)
	await wait_process_frames(3)
	var camera := Camera3D.new()
	add_child_autofree(camera)
	var pole := Vector3(0.0, 0.0, -20.0)
	hud._flag_marker.place(camera, pole, true, hud.size, Vector2.ZERO, 0.0, 1080.0)
	# slide the stack down to where the marker over the pole is
	var shift := hud._flag_marker.occupied().position.y - hud._stack_rects()[0].position.y
	hud._middle.offset_top += shift
	hud._middle.offset_bottom += shift
	await wait_process_frames(3)
	assert_true(Hud.overlaps_any(hud._flag_marker.occupied(), hud._stack_rects()), "the control: left alone it would sit on them")
	hud.place_flag_marker(camera, pole, true)
	assert_false(hud._flag_marker.visible, "so it is held back")
	assert_true(Hud.overlaps_any(Rect2(Vector2(10.0, 10.0), Vector2(5.0, 5.0)), [Rect2(0.0, 0.0, 20.0, 20.0)] as Array[Rect2]))
	assert_false(Hud.overlaps_any(Rect2(30.0, 30.0, 5.0, 5.0), [Rect2(0.0, 0.0, 20.0, 20.0)] as Array[Rect2]))
	hud._banner.visible = false
	hud._count.end()
	hud.place_flag_marker(camera, pole, true)
	assert_true(hud._flag_marker.visible, "it is back once they are gone")
