extends GutTest
## Ping markers, the minimap and the pip (PN2; concept `step27/ping.png`): a spot's ring in your team's colour 0.3 m
## over its floor spot with "PING · 9 M", a contact's diamond in the other team's over the enemy's head where they were
## seen, never following them; the pop over 0.35 s (none under Reduced motion), 7 s whole and the last second's fade;
## pinned inside the screen's edge under the minimap when off screen; hidden while you spectate, with the scoreboard up,
## in the pause menu and with Settings › HUD › Ping markers off; HUD size and opacity; the minimap's ring and diamond;
## the pip for your own ping only; the setting (On, saved, an old file loads On); markers made once, a frame with none
## allocating nothing.

const YOU := 0
const BRICK := 1
const ROOK := 2
const DASH := 3
const SAVE := "user://test_ping_markers_settings.save"

var _teams := TeamConfig.new()
var _cfg := HudConfig.new()
var _sim := SimTuning.new()
var _state: GameState = null
var _book: Pings = null
var _hud: Hud = null
var _camera: Camera3D = null


func before_each() -> void:
	_state = GameState.new()
	for i in 4:
		# You and Brick in Alpha, Rook and Dash in Beta.
		_state.characters.append(Character.new(i, 0 if i < 2 else 1))
	_book = Pings.new(_state.characters, _sim.pings)
	var frame := Control.new()
	frame.size = get_viewport().get_visible_rect().size
	add_child_autofree(frame)
	_hud = Hud.new()
	frame.add_child(_hud)
	_hud.setup(_cfg, _teams, ViewConfig.new(), _sim, _state.characters[YOU])
	_hud.setup_field(BoxWorld.new(), BodyConfig.new(), PackedStringArray(["", "Brick", "Rook", "Dash"]),
			_state.characters, null)
	_camera = Camera3D.new()
	add_child_autofree(_camera)
	_camera.global_position = Vector3(0.0, 1.6, 0.0)


func after_all() -> void:
	for path: String in [SAVE, SAVE + ".bak", SAVE + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


## Character `who`'s ping placed at `at` (s): a spot on the floor at `spot`, or a contact over an enemy standing there.
func _ping(who: int, spot: Vector3, contact: bool = false, at: float = 0.0, marked: bool = false) -> Pings.Ping:
	var p := _book.of(who)
	p.owner = who
	p.team = _state.characters[who].team
	p.kind = Pings.Kind.CONTACT if contact else Pings.Kind.SPOT
	p.spot = spot
	p.point = spot + Vector3.UP * 1.26 if contact else spot
	p.enemy_id = ROOK if contact else -1
	p.at = at
	p.marked = marked
	_book.placed += 1
	return p


func _place(now: float, show: bool = true) -> void:
	_hud.update(_state, 1.0, 0.0)
	_hud.place_pings(_camera, _book, now, show)


func _marker(who: int = YOU) -> HudPingMarker:
	return _hud.ping_markers().marker_of(who)


# --- over the field ---

func test_a_spot_is_a_ring_in_your_colour_over_the_floor_with_its_distance() -> void:
	_ping(YOU, Vector3(0.0, 0.0, -9.0))
	_place(1.0)
	var m := _marker()
	assert_true(m.visible)
	assert_eq(m.text(), "PING · 9 M")
	assert_eq(m.shape(), HudPingMarker.Shape.RING)
	assert_eq(m.colour(), _teams.colours[0], "your team's colour")
	assert_false(m.pinned())
	var anchor := Vector3(0.0, _cfg.ping_spot_height, -9.0)
	var at := _camera.unproject_position(anchor)
	assert_almost_eq(m.position + m.pivot_offset, at, Vector2(0.5, 0.5), "the ring's middle 0.3 m over the spot")
	assert_almost_eq(m.pivot_offset.y, HudPingMarker.ICON * 0.5, 0.01, "its words under it")


func test_a_contact_is_a_diamond_in_their_colour_over_the_head_and_never_follows() -> void:
	var p := _ping(BRICK, Vector3(2.0, 0.0, -13.0), true)
	_place(1.0)
	var m := _marker(BRICK)
	assert_eq(m.text(), "CONTACT · 13 M")
	assert_eq(m.shape(), HudPingMarker.Shape.DIAMOND)
	assert_eq(m.colour(), _teams.colours[1], "the other team's colour")
	var anchor := p.point + Vector3.UP * _cfg.ping_contact_lift
	assert_gt(anchor.y, BodyConfig.new().height, "over their head")
	var before := m.position
	_state.characters[ROOK].position = Vector3(8.0, 0.0, -20.0)
	_place(1.5)
	assert_eq(m.position, before, "it stays where they were seen")


func test_it_pops_in_stays_whole_seven_seconds_and_fades_over_the_last() -> void:
	_ping(YOU, Vector3(0.0, 0.0, -9.0), false, 10.0)
	_place(10.0)
	var m := _marker()
	assert_almost_eq(m.scale.x, _cfg.ping_pop_from, 0.001, "pops in from small")
	_place(10.0 + _cfg.ping_pop * 0.5)
	assert_between(m.scale.x, _cfg.ping_pop_from + 0.01, 0.999, "on its way")
	_place(10.0 + _cfg.ping_pop)
	assert_eq(m.scale.x, 1.0, "whole after 0.35 s")
	_place(17.0)
	assert_eq(m.modulate.a, 1.0, "whole for 7 s")
	_place(17.5)
	assert_almost_eq(m.modulate.a, 0.5, 0.001, "fading over the last second")
	_place(18.0)
	assert_false(m.visible, "gone after 8 s")


func test_reduced_motion_shows_it_whole_at_once() -> void:
	_hud.set_motion(MotionScale.of(true))
	_ping(YOU, Vector3(0.0, 0.0, -9.0), false, 10.0)
	_place(10.0)
	assert_eq(_marker().scale.x, 1.0)
	_hud.set_motion(MotionScale.of(false))
	_place(10.0)
	assert_lt(_marker().scale.x, 1.0)


# --- off screen ---

func test_off_screen_it_is_pinned_inside_the_edge_under_what_is_there() -> void:
	_ping(YOU, Vector3(-60.0, 0.0, -10.0))
	_place(1.0)
	var m := _marker()
	assert_true(m.pinned())
	assert_eq(m.chevron(), HudPingMarker.Shape.LEFT)
	var pin := _hud.pin_point()
	assert_almost_eq(m.position, pin, Vector2(0.5, 0.5), "where the flag marker pins")
	_ping(BRICK, Vector3(-40.0, 0.0, 5.0))
	_place(1.0)
	var under := _marker(BRICK)
	assert_true(under.pinned())
	assert_gte(under.position.y, m.get_rect().end.y, "the next one under it")
	_ping(YOU, Vector3(60.0, 0.0, -10.0))
	_place(1.0)
	assert_eq(m.chevron(), HudPingMarker.Shape.RIGHT)
	assert_almost_eq(m.get_rect().end.x, _hud.size.x - pin.x, 0.5, "on the right side")
	_ping(YOU, Vector3(0.5, 0.0, 30.0))
	_place(1.0)
	assert_true(m.pinned(), "behind you")
	var r := m.get_rect()
	assert_true(Rect2(Vector2.ZERO, _hud.size).encloses(r), "inside the screen")


## Two rects `gap` apart or more, or side by side.
func _clear_of(a: Rect2, b: Rect2, gap: float) -> bool:
	return a.position.x >= b.end.x + gap - 0.01 or b.position.x >= a.end.x + gap - 0.01 \
			or a.position.y >= b.end.y + gap - 0.01 or b.position.y >= a.end.y + gap - 0.01


func test_over_the_field_two_pings_close_on_screen_step_clear_of_each_other() -> void:
	# BP7 row 43: they no longer overlap, and they part up and down, each by half, about where they were.
	_ping(YOU, Vector3(0.0, 0.0, -20.0))
	_ping(BRICK, Vector3(0.3, 0.0, -20.5))
	_place(1.0)
	var a := _marker()
	var b := _marker(BRICK)
	assert_false(a.pinned() or b.pinned())
	assert_ne(_hud.ping_markers().nudge_of(0), 0.0, "they met and moved")
	assert_true(_clear_of(a.get_rect(), b.get_rect(), _cfg.ping_clear_gap), "%s %s" % [a.get_rect(), b.get_rect()])
	var mid := (_camera.unproject_position(Vector3(0.0, _cfg.ping_spot_height, -20.0))
			+ _camera.unproject_position(Vector3(0.3, _cfg.ping_spot_height, -20.5))) * 0.5
	var spread := (a.get_rect().get_center() + b.get_rect().get_center()) * 0.5
	assert_almost_eq(spread.y + a.pivot_offset.y - a.size.y * 0.5, mid.y, 2.0, "they part about where they are")
	_book.of(BRICK).spot = Vector3(8.0, 0.0, -20.0)
	for i in 60:
		_place(1.1 + i * 0.016)
	assert_almost_eq(_hud.ping_markers().nudge_of(0), 0.0, 0.1, "far apart again: back where they belong")


func test_a_ping_moving_into_another_eases_clear() -> void:
	_ping(YOU, Vector3(0.0, 0.0, -20.0))
	_ping(BRICK, Vector3(6.0, 0.0, -20.0))
	_place(1.0)
	var markers := _hud.ping_markers()
	assert_eq(markers.nudge_of(0), 0.0, "apart: not nudged")
	_book.of(BRICK).spot = Vector3(0.2, 0.0, -20.0)
	_place(1.016)
	var first := absf(markers.nudge_of(0))
	assert_gt(first, 0.0, "on its way")
	for i in 60:
		_place(1.032 + i * 0.016)
	var settled := absf(markers.nudge_of(0))
	assert_gt(settled, first, "it eases, not jumps")
	assert_true(_clear_of(_marker().get_rect(), _marker(BRICK).get_rect(), _cfg.ping_clear_gap - 0.5), "and gets clear")


func test_over_the_field_a_ping_steps_clear_of_the_hold_plate() -> void:
	var spot := Vector3(0.0, 0.0, -20.0)
	_hud.setup_orders(ControlsConfig.new())
	_hud.place_hold_marker(_camera, spot, true)
	var hold := _hud.hold_marker()
	assert_eq(hold.pin, HudHoldMarker.Pin.NONE, "Hold here's plate over the field")
	_ping(YOU, spot + Vector3(0.0, 1.0, 0.0))
	_place(1.0)
	assert_false(_marker().pinned())
	assert_ne(_hud.ping_markers().nudge_of(0), 0.0, "it met the plate and moved")
	assert_true(_clear_of(_marker().get_rect(), hold.get_rect(), _cfg.ping_clear_gap),
			"%s %s" % [_marker().get_rect(), hold.get_rect()])


## BP7 QA: at the screen's top the step stays on the screen, and a ping with no room over Hold here's plate goes under it.
func test_at_the_top_edge_they_step_clear_and_stay_on_the_screen() -> void:
	_hud.setup_orders(ControlsConfig.new())
	_ping(YOU, Vector3(0.0, 40.0, -20.0))
	_ping(BRICK, Vector3(0.3, 40.0, -20.0))
	_place(1.0)
	var screen := Rect2(Vector2.ZERO, _hud.size)
	var a := _marker().get_rect()
	var b := _marker(BRICK).get_rect()
	assert_lt(minf(a.position.y, b.position.y), _cfg.ping_marker_edge, "held at the top")
	assert_true(screen.encloses(a) and screen.encloses(b), "%s %s on the screen" % [a, b])
	assert_true(_clear_of(a, b, _cfg.ping_clear_gap), "%s %s" % [a, b])
	_book.of(BRICK).spot = Vector3(30.0, 0.0, -20.0)
	for i in 60:
		_place(1.02 + i * 0.016)
	a = _marker().get_rect()
	assert_almost_eq(_hud.ping_markers().nudge_of(0), 0.0, 0.5, "settled where its ping is, at the screen's top")
	# Hold here's plate just under the ping's middle: pushed up clear of it, the ping would leave the screen
	var tip := _camera.project_position(Vector2(a.get_center().x, a.position.y + 12.0 + 43.0), 20.0)
	_hud.place_hold_marker(_camera, tip - Vector3.UP * _cfg.hold_marker_height, true)
	var hold := _hud.hold_marker().get_rect()
	assert_lt(hold.position.y, a.end.y, "the plate meets the ping")
	assert_gt(hold.get_center().y, a.get_center().y, "its middle under the ping's: the ping would go over it")
	assert_gt(a.end.y + _cfg.ping_clear_gap - hold.position.y, a.position.y, "no room over the plate")
	for i in 60:
		_place(2.0 + i * 0.016)
	a = _marker().get_rect()
	assert_true(screen.encloses(a), "%s on the screen" % a)
	assert_gte(a.position.y, hold.end.y, "under the plate")
	assert_true(_clear_of(a, hold, _cfg.ping_clear_gap), "%s clear of the plate %s" % [a, hold])


func test_a_frame_of_pings_stepping_clear_allocates_no_object() -> void:
	_ping(YOU, Vector3(0.0, 0.0, -20.0))
	_ping(BRICK, Vector3(0.3, 0.0, -20.5))
	_place(1.0)
	var objects := Performance.get_monitor(Performance.OBJECT_COUNT)
	for i in 100:
		_hud.place_pings(_camera, _book, 1.0 + i * 0.016, true)
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), objects)


func test_pinned_on_the_left_it_sits_under_a_flag_pinned_there() -> void:
	var flag_pole := Vector3(-60.0, 0.0, -10.0)
	_hud.place_flag_marker(_camera, flag_pole, true)
	_ping(YOU, Vector3(-50.0, 0.0, -10.0))
	_place(1.0)
	var flag := _hud._flag_marker.occupied()
	assert_eq(_hud._flag_marker.pinned_side(), -1)
	assert_gte(_marker().position.y, flag.end.y, "under the flag's plate")


# --- hidden ---

func test_hidden_while_you_spectate_with_the_board_up_paused_or_switched_off() -> void:
	_ping(YOU, Vector3(0.0, 0.0, -9.0))
	_ping(BRICK, Vector3(3.0, 0.0, -9.0))
	_place(1.0)
	assert_eq(_hud.ping_markers().shown(), 2)
	_place(1.0, false)
	assert_eq(_hud.ping_markers().shown(), 0, "watching someone else")
	_hud.board().visible = true # as Tab shows it in a match (no match numbers here to fill it)
	_hud.place_pings(_camera, _book, 1.0, true)
	assert_eq(_hud.ping_markers().shown(), 0, "the scoreboard up")
	_hud.show_board(false)
	_place(1.0)
	assert_eq(_hud.ping_markers().shown(), 2)
	_hud.hide_pings()
	assert_eq(_hud.ping_markers().shown(), 0, "the pause menu")
	var prefs := HudPrefs.new()
	prefs.ping_markers = false
	_hud.apply_prefs(prefs)
	_place(1.0)
	assert_eq(_hud.ping_markers().shown(), 0, "Ping markers off")


func test_only_your_teams_pings_show() -> void:
	_ping(ROOK, Vector3(0.0, 0.0, -9.0))
	_place(1.0)
	assert_eq(_hud.ping_markers().shown(), 0)
	assert_null(_marker(ROOK), "no marker made for the other team")
	_ping(BRICK, Vector3(0.0, 0.0, -9.0), true, 0.5, true)
	_place(1.0)
	assert_true(_marker(BRICK).visible, "a teammate's mark from their call shows")


## The HUD size applies; the HUD opacity leaves the pings solid (UR8: it is the replica panel's and the minimap's).
func test_hud_size_applies_and_the_pings_stay_solid() -> void:
	var prefs := HudPrefs.new()
	prefs.hud_size = 1.5
	prefs.panel_opacity = 0.5
	_hud.apply_prefs(prefs)
	_ping(YOU, Vector3(1.0, 0.0, -9.0))
	_place(1.0)
	var m := _marker()
	var at := _camera.unproject_position(Vector3(1.0, _cfg.ping_spot_height, -9.0)) / 1.5
	assert_almost_eq(m.position + m.pivot_offset, at, Vector2(0.5, 0.5), "placed in the HUD's scaled px")
	assert_almost_eq(_hud.ping_markers().modulate.a, 1.0, 0.001)
	var box := m._edge.get_theme_stylebox("panel") as StyleBoxFlat
	assert_almost_eq(box.bg_color.a, HudStyle.BACKING_CLOCK, 0.001, "the pinned plate's navy")


# --- the minimap ---

func test_the_minimap_shows_the_ring_and_diamond_and_off_hides_them() -> void:
	var map := MapData.new()
	_hud.setup_minimap(map, MinimapConfig.new(), MinimapHearing.new(MinimapConfig.new()), "Depot", 4)
	_ping(YOU, Vector3(3.0, 0.0, -3.0))
	_ping(BRICK, Vector3(200.0, 0.0, 0.0), true)
	_ping(ROOK, Vector3(1.0, 0.0, 1.0))
	var you := _state.characters[YOU]
	_hud.update_minimap(_state, you, 0.0, 1.0, false, Vector3.ZERO, _book)
	var view := _hud.minimap().view()
	assert_eq(view.ping_count(), 2, "your team's two, the one off the panel on its rim")
	assert_false(view.ping_is_contact(0))
	assert_true(view.ping_is_contact(1))
	var prefs := HudPrefs.new()
	prefs.ping_markers = false
	_hud.apply_prefs(prefs)
	_hud.update_minimap(_state, you, 0.0, 1.0, false, Vector3.ZERO, _book)
	assert_eq(view.ping_count(), 0, "Ping markers off")


func test_a_ping_off_the_panel_is_drawn_on_its_rim() -> void:
	var cfg := MinimapConfig.new()
	var view := HudMinimap.View.new()
	add_child_autofree(view)
	view.size = Vector2(196.0, 196.0)
	view.setup(cfg, [] as Array[Texture2D], cfg.layer_scale, Vector2.ZERO, 4)
	view.begin(Vector2.ZERO, -1, 0.0, false, Color.BLUE, Color.ORANGE)
	var far := view._to_panel(Vector2(200.0, 0.0))
	var on_rim := view._pin(far, cfg.mark_pad)
	assert_almost_eq(on_rim.x, view.size.x * 0.5 - cfg.mark_pad, 0.01)


# --- the pip ---

func _audio() -> SimAudio:
	var audio := SimAudio.new()
	add_child_autofree(audio)
	audio.setup(SoundConfig.new(), [] as Array[StringName], BodyConfig.new(), null, null)
	return audio


func _pips(audio: SimAudio) -> int:
	var n := 0
	var pip: Array = audio._streams[&"ping_pip"]
	for v in audio._own:
		if v.playing and pip.has(v.stream):
			n += 1
	return n


func test_your_ping_plays_one_soft_pip_in_your_ear() -> void:
	var audio := _audio()
	assert_false((audio._streams[&"ping_pip"] as Array).is_empty(), "the rendered cue")
	_ping(YOU, Vector3(0.0, 0.0, -9.0), false, 1.0)
	audio.on_ping(_book, YOU)
	assert_eq(_pips(audio), 1)
	var v: AudioStreamPlayer = null
	for o in audio._own:
		if o.playing:
			v = o
	assert_eq(v.bus, SimAudio.BUS_INTERFACE)
	assert_almost_eq(v.volume_db, linear_to_db(SoundConfig.new().ping_pip_gain), 0.01)
	audio.on_ping(_book, YOU)
	assert_eq(_pips(audio), 1, "once a ping")


func test_a_teammates_mark_or_ping_plays_no_pip() -> void:
	var audio := _audio()
	_ping(BRICK, Vector3(0.0, 0.0, -9.0), true, 1.0, true)
	audio.on_ping(_book, YOU)
	_ping(BRICK, Vector3(0.0, 0.0, -9.0), false, 2.0)
	audio.on_ping(_book, YOU)
	assert_eq(_pips(audio), 0)


func test_the_pip_is_the_recorded_beep_short_and_under_the_shot_timer() -> void:
	# The owner's recorded beep (AU2, tools/cut_recordings.py), lower and shorter than the shot timer's.
	var pip := load("res://assets/audio/cues/ping_pip_1.wav") as AudioStreamWAV
	var timer := load("res://assets/audio/cues/count_beep_1.wav") as AudioStreamWAV
	assert_not_null(pip)
	assert_not_null(timer)
	assert_almost_eq(pip.get_length(), 0.08, 0.002)
	assert_lt(pip.get_length(), timer.get_length(), "a mark, not a countdown")
	var cfg := SoundConfig.new()
	assert_almost_eq(cfg.ping_pip_gain, 0.2, 1e-6)
	assert_lt(cfg.ping_pip_gain, cfg.beep_gain, "quieter than the shot timer")


# --- the setting ---

func test_ping_markers_are_on_by_default_saved_and_an_old_file_loads_on() -> void:
	assert_true(HudPrefs.new().ping_markers)
	var p := HudPrefs.new()
	p.ping_markers = false
	var back := HudPrefs.new()
	back.from_dict(p.to_dict())
	assert_false(back.ping_markers, "saved")
	var old := p.to_dict()
	old.erase("ping_markers")
	back.from_dict(old)
	assert_true(back.ping_markers, "a file from before them loads On")
	old["ping_markers"] = "no"
	back.from_dict(old)
	assert_true(back.ping_markers, "a bad value falls back")


func test_the_tab_has_ping_markers_on_and_saves_a_change() -> void:
	var s := Settings.new(PlayTuning.new())
	var screen := SettingsScreen.new()
	screen.settings = s
	screen.save_path = SAVE
	add_child_autofree(screen)
	screen.open()
	var page: SettingsHudPage = screen._hud_page
	assert_true(page._pings.button_pressed)
	page._pings.toggled.emit(false)
	assert_false(s.hud.ping_markers)
	assert_false(s.dirty, "a click saves at once")
	screen.close()
	var back := Settings.new(PlayTuning.new())
	back.load_file(SAVE)
	assert_false(back.hud.ping_markers)


# --- no waste ---

func test_markers_are_made_once_one_per_teammate() -> void:
	var layer := _hud.ping_markers()
	assert_eq(layer.count(), 2, "you and Brick")
	var children := layer.get_child_count()
	for i in 20:
		_ping(YOU, Vector3(i - 10.0, 0.0, -9.0), i % 2 == 0, float(i))
		_place(float(i))
	assert_eq(layer.get_child_count(), children)


func test_a_frame_with_none_allocates_nothing() -> void:
	_place(1.0)
	var objects := Performance.get_monitor(Performance.OBJECT_COUNT)
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	for i in 100:
		_hud.place_pings(_camera, _book, 1.0 + i * 0.016, true)
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), objects)
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes)


func test_a_frame_with_a_ping_up_allocates_no_object() -> void:
	_ping(YOU, Vector3(0.0, 0.0, -9.0))
	_ping(BRICK, Vector3(-60.0, 0.0, -9.0), true)
	_place(1.0)
	var objects := Performance.get_monitor(Performance.OBJECT_COUNT)
	for i in 100:
		_hud.place_pings(_camera, _book, 1.0 + i * 0.016, true)
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), objects)


func test_the_markers_go_with_the_hud() -> void:
	var layer := _hud.ping_markers()
	var m := _marker()
	_hud.free()
	assert_false(is_instance_valid(layer))
	assert_false(is_instance_valid(m))


# --- in a match ---

func test_a_ping_in_a_match_shows_on_screen_and_the_minimap_and_pips() -> void:
	var session := PlaySession.new()
	session.mode = MatchOptions.MODE_ELIMINATION
	session.bots_active = false
	add_child_autofree(session)
	await wait_physics_frames(3)
	var player := session.player
	var book := session._bots.pings
	var p := book.of(player.id)
	p.owner = player.id
	p.team = player.team
	p.kind = Pings.Kind.SPOT
	var ahead := -session._eyes.global_basis.z
	p.spot = player.position + Vector3(ahead.x, 0.0, ahead.z).normalized() * 6.0
	p.point = p.spot
	p.at = session.state.time
	book.placed += 1
	await wait_physics_frames(2)
	await wait_process_frames(2)
	var m := session.hud().ping_markers().marker_of(player.id)
	assert_true(m.visible, "over the field")
	assert_true(m.text().begins_with("PING · "))
	assert_eq(session.hud().minimap().view().ping_count(), 1, "on the minimap")
	assert_eq(session._audio._ping_at, p.at, "the pip started (it lasts 0.08 s, so a slow frame may see it over)")
	session._open_pause()
	assert_false(m.visible, "hidden in the pause menu")
	session._resume()


func test_over_the_field_it_is_one_drawn_item_and_the_plate_is_filled_only_when_pinned() -> void:
	_ping(YOU, Vector3(0.0, 0.0, -9.0))
	_place(1.0)
	var m := _marker()
	var drawn := 0
	for c: CanvasItem in m.find_children("*", "CanvasItem", true, false):
		if c.is_visible_in_tree():
			drawn += 1
	assert_eq(drawn, 0, "the glyph and words are the marker's own drawing")
	assert_eq(m._edge_words.text, "", "the hidden plate's words are never shaped")
	_ping(YOU, Vector3(-60.0, 0.0, -10.0))
	_place(1.0)
	assert_true(m.pinned())
	assert_eq(m._edge_words.text, "PING · 61 M")
