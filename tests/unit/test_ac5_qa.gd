extends GutTest
## QA for AC5 (HUD size, Reduced motion): the round's table, the match summary and the XP card, which test_hud_size's
## parts list leaves out, stay on the screen (the game's 1920×1080 canvas) from 80 % to 150 %, as they do at 100 %; and
## a settings change repeated leaves no new connections.

const CANVAS := Vector2(1920.0, 1080.0)
## 21:9 is wider (project.godot's expand), 4:3 taller; the summary is the widest thing the HUD shows.
const CANVASES: Array[Vector2] = [Vector2(1920.0, 1080.0), Vector2(2560.0, 1080.0), Vector2(1920.0, 1440.0)]
const SIZES: Array[float] = [1.0, 0.8, 1.5]
const EDGE_SLACK := 0.5

var state: GameState = null
var you: Character = null


func before_each() -> void:
	state = GameState.new(1)
	for i in 6:
		var c := Character.new(i, i % 2, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
		c.prev_position = c.position
		state.characters.append(c)
	you = state.characters[0]


func _hud(hud_size: float, canvas: Vector2 = CANVAS) -> Hud:
	var frame := Control.new()
	frame.size = canvas
	add_child_autofree(frame)
	var hud := Hud.new()
	frame.add_child(hud)
	hud.setup(HudConfig.new(), TeamConfig.new(), ViewConfig.new(), SimTuning.new(), you)
	var names := PackedStringArray()
	for i in 6:
		names.append("Bot %d" % i)
	hud._stats = MatchStats.new()
	hud._names = names
	hud._summary.set_names(names)
	hud._round_result.set_names(names)
	var p := HudPrefs.new()
	p.hud_size = hud_size
	hud.apply_prefs(p)
	return hud


func _inside(c: Control, what: String, canvas: Vector2 = CANVAS) -> void:
	var r := c.get_global_rect()
	assert_true(Rect2(Vector2.ZERO, canvas).grow(EDGE_SLACK).encloses(r), "%s: %s off the %s canvas" % [what, r, canvas])


func test_the_summary_and_the_xp_card_stay_on_screen_from_80_to_150_percent() -> void:
	var pool := Pool.read_file()
	var levels := LevelTable.read_file(pool)
	for canvas in CANVASES:
		for size in SIZES:
			var hud := _hud(size, canvas)
			var label := "at %d%% on %s" % [roundi(size * 100.0), canvas]
			var progress := Progress.new(levels)
			var outcome := MatchXp.Outcome.new()
			outcome.won = true
			outcome.rounds_won = 3
			outcome.hits = 4
			var settled := PlayerTally.Settled.new()
			settled.earned = MatchXp.earned(levels, outcome)
			settled.level_up = progress.add_xp(settled.earned.total)
			hud.show_xp(settled, progress)
			hud.open_summary(state, true, "Hold the angle")
			hud.update(state, 1.0, 0.0)
			await wait_process_frames(2)
			var summary := hud._summary
			assert_true(summary.is_open())
			assert_not_null(hud.xp_card())
			_inside(hud.xp_card(), "XP card " + label, canvas)
			for c in summary.get_children():
				if c is Control and (c as Control).is_visible_in_tree():
					_inside(c as Control, "summary part %s %s" % [c.name, label], canvas)
			hud.get_parent().queue_free()


func test_the_round_table_stays_on_screen_from_80_to_150_percent() -> void:
	for size in SIZES:
		var hud := _hud(size)
		hud.round_result().round_over(1, 30, state.time)
		state.time += 30.0
		hud.update(state, 1.0, 0.05)
		state.time += 30.0
		hud.update(state, 1.0, 0.05)
		await wait_process_frames(2)
		var table := hud.round_result().table()
		assert_true(table.is_visible_in_tree(), "the table shows at %d%%" % roundi(size * 100.0))
		_inside(table, "round table at %d%%" % roundi(size * 100.0))
		hud.get_parent().queue_free()


func test_repeated_changes_add_no_connections() -> void:
	var settings := Settings.new(PlayTuning.new())
	var session := PlaySession.new()
	session.settings = settings
	session.bots_active = false
	add_child_autofree(session)
	await wait_physics_frames(2)
	var before := settings.changed.get_connections().size()
	for i in 20:
		settings.hud.hud_size = 0.8 if i % 2 == 0 else 1.5
		settings.reduced_motion = Settings.ReducedMotion.ON if i % 2 == 0 else Settings.ReducedMotion.OFF
		settings.mark_changed()
	assert_eq(settings.changed.get_connections().size(), before, "no new listeners on the settings")


func test_hold_here_s_ring_stays_on_the_floor_it_rings_at_every_size() -> void:
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.position = Vector3(0.0, 1.6, 0.0)
	var spot := Vector3(0.0, 0.0, -20.0)
	var area := get_viewport().get_visible_rect().size
	for size in SIZES:
		var hud := _hud(size, area)
		hud.setup_orders(ControlsConfig.new())
		hud.apply_prefs(_prefs_at(size))
		for i in 2:
			hud.place_hold_marker(camera, spot, true)
			await wait_process_frames(1)
		var marker := hud.hold_marker()
		assert_true(marker.ring_shown(), "the ring shows over a spot straight ahead at %s" % size)
		var ring: Control = marker._ring
		var points: PackedVector2Array = marker._ring.points
		var worst := 0.0
		for i in points.size():
			var drawn := ring.get_global_transform() * points[i]
			worst = maxf(worst, drawn.distance_to(camera.unproject_position(spot + marker._ring_ground[i])))
		assert_lt(worst, 1.0, "every ring point is drawn where the floor is seen at %d%%: off by %.1f px" % [roundi(size * 100.0), worst])
		hud.get_parent().queue_free()


func _prefs_at(hud_size: float) -> HudPrefs:
	var p := HudPrefs.new()
	p.hud_size = hud_size
	return p
