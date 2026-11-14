extends GutTest
## QA for the Dev 3 audit's fixes (AUD1): each fix pinned where it can be reached headless. The bots' hold clock and
## view, a lift's rise and the stairs share, the throw's recovery with both hands on the bomb, the bomb's set-down room,
## the weapon rail for someone out, the bomb notes on a settings change, Burst's least, AZERTY loadout keys, tooltips over
## the Monitor and Renderer buttons, the Match page waiting while hidden, the callouts after a skip, the map load's
## one-pass cores and floors against a straightforward reference, the Undo-first save replace and the Lamp light switch.

const DT := 1.0 / 60.0
const ROOT := "user://test-aud1-qa"
const LOADOUTS := "user://test_aud1_loadouts.save"
const SETTINGS := "user://test_aud1_settings.save"

const MINIMAL := """## Personalities

| Personality | Card note |
|---|---|
| Rusher | {name} rushes. |
| Anchor | {name} anchors. |

## How they move

| Personality | Lane pause (×) | Cover at a lane point (×) | Cover on contact from (×) | Walk the last (×) | Flank chance (+) | Burst (×) | Burst pause (×) | Watch where you ducked (s) |
|---|---|---|---|---|---|---|---|---|
| Rusher | 0.3 | 0.3 | 1 | 0.25 | -0.25 | 1.2 | 0.8 | – |
| Anchor | 1.5 | 1.5 | 0.7 | 1 | 0 | 1 | 1 | 1–2.5 |

## Habits

| Personality | Pushes in | Waits for the team | Own lane | Holds until (s left) | Aims from cover | Holds angles | Slices corners |
|---|---|---|---|---|---|---|---|
| Rusher | yes | no | no | – | no | – | – |
| Anchor | no | yes | no | 60 | yes | yes | – |

## Roster

| Name | Personality |
|---|---|
| Dash | Rusher |
| Rook | Anchor |
"""


var tuning: SimTuning = SimTuning.load_default()
var config: BotConfig = BotConfig.load_default()
var _w: BotWorld = null


func after_each() -> void:
	SettingsApply.use_screens(null)
	for path: String in [LOADOUTS, SETTINGS]:
		SaveFile.remove(path)
	if DirAccess.dir_exists_absolute(ROOT):
		_wipe(ROOT)


func _wipe(path: String) -> void:
	for d: String in DirAccess.get_directories_at(path):
		_wipe(path.path_join(d))
	for f: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)


# ---------------------------------------------------------------- bots

func _bot(at: Vector3 = Vector3.ZERO) -> Bot:
	var loadout := ReplicaStats.default_loadout()
	var me := Character.new(0, 0, at, 0.0, loadout)
	var foe := Character.new(1, 1, Vector3(0.0, 0.0, -40.0), 0.0, loadout)
	_w = BotWorld.new()
	_w.tuning = tuning
	_w.cfg = config
	_w.query = WorldQuery.new()
	_w.planner = RoundPlanner.new(1)
	_w.planner.enemy_yaw[0] = 0.0
	_w.characters = [me, foe]
	_w.time = 10.0
	return Bot.new(me, 1, config.skill_for(&"normal"), 2)


func test_a_hold_clock_stands_still_until_the_round_is_live() -> void:
	var b := _bot()
	b.hold_left = 2.0
	b.team_wait = 0.0
	_w.live = false
	for i in 300:
		assert_false(BotMovement._advance(b, _w, DT), "holding, it doesn't go")
	assert_eq(b.hold_left, 2.0, "the start countdown spends none of a lane mate's delay")
	assert_eq(b.team_wait, 0.0)
	assert_true(b.holding)
	_w.live = true
	BotMovement._advance(b, _w, DT)
	assert_almost_eq(b.hold_left, 2.0 - DT, 1e-6, "live: it counts down")
	assert_almost_eq(b.team_wait, DT, 1e-6)


func test_a_bot_on_its_spot_does_not_turn_its_view_to_the_fields_plus_z() -> void:
	var b := _bot()
	b.mode = Bot.Mode.ADVANCE
	b.hunting = true
	b.move_dir = Vector3.ZERO # waiting for a lift, riding one
	var cmd := PlayerCommand.new()
	for i in 240:
		BotCombat.aim(b, _w, null, BotSenses.eye_of(b.character, tuning), true, cmd, DT)
	assert_lt(absf(b.aim_yaw), 0.3, "it looks to the enemy side as one standing does, not at atan2(0, 0)")


func test_a_walking_bot_still_faces_its_step() -> void:
	var b := _bot()
	b.mode = Bot.Mode.ADVANCE
	b.hunting = true
	b.move_dir = Vector3(1.0, 0.0, 0.0)
	var cmd := PlayerCommand.new()
	for i in 240:
		BotCombat.aim(b, _w, null, BotSenses.eye_of(b.character, tuning), true, cmd, DT)
	assert_lt(b.aim_yaw, -1.0, "control: walking along +X turns the view towards it")


# ---------------------------------------------------------------- lift rise and stairs

func _runner(slope: float) -> Character:
	var feet := Vector3(0.0, tuning.body.rest_gap, 0.0)
	var c := Character.new(4, 0, feet, 0.0)
	c.grounded = true
	c.prev_position = feet
	c.position = feet + Vector3(0.0, slope * 0.05, -0.05)
	return c


func _climb(c: Character, ticks: int) -> void:
	for i in ticks:
		Hitbox.step_stairs(c, tuning.hits, DT)


func test_a_cars_rise_is_not_a_stair_climb() -> void:
	var riding := _runner(0.5)
	riding.lift_rise = 0.5 * 0.05 # the whole rise is the car's
	_climb(riding, 30)
	assert_eq(riding.stairs, 0.0, "walking in a rising car plays no stairs clips")
	var climbing := _runner(0.5)
	_climb(climbing, 30)
	assert_almost_eq(climbing.stairs, 1.0, 1e-3, "control: the same rise on a stair is a climb")


func test_a_climb_in_a_rising_car_counts_only_its_own_rise() -> void:
	var c := _runner(1.0) # 0.05 up a tick
	c.lift_rise = 0.05 * 0.5 # half of it the car's: the legs climb 0.5
	_climb(c, 30)
	assert_gt(c.stairs, 0.0, "its own climb still reads")
	var all_car := _runner(1.0)
	all_car.lift_rise = 0.05
	_climb(all_car, 30)
	assert_eq(all_car.stairs, 0.0)


func test_a_respawn_clears_the_carried_rise() -> void:
	var c := Character.new(4, 0)
	c.lift_rise = 0.3
	c.respawn()
	assert_eq(c.lift_rise, 0.0)


func test_carry_records_the_cars_rise_for_a_rider_and_zero_off_the_car() -> void:
	var map := MapData.load_map("subway", MapStyle.new(), 6)
	var level := MapLevel.new()
	add_child_autofree(level)
	level.build(map, MapStyle.new(), tuning.body, null, null, false, null, tuning.lifts)
	var q := level.query()
	var spec := q.lifts[0]
	var lifts := Lifts.new(tuning, q)
	var state := LiftState.new()
	lifts.reset(state)
	state.phase[0] = LiftState.Phase.MOVING
	state.y[0] = 4.0
	state.rise[0] = 0.1
	var rider := Character.new(0, 0, spec.car_point(3.9) + Vector3(0.0, tuning.body.rest_gap, 0.0), 0.0)
	var before := rider.position.y
	lifts.carry(rider, state)
	assert_almost_eq(rider.lift_rise, rider.position.y - before, 1e-6, "what the car carried it")
	assert_gt(rider.lift_rise, 0.0)
	rider.position = spec.landing_point(2, tuning.lifts)
	lifts.carry(rider, state)
	assert_eq(rider.lift_rise, 0.0, "off the car the last tick's rise is forgotten")
	state.rise[0] = 0.0
	rider.lift_rise = 0.2
	lifts.carry(rider, state)
	assert_eq(rider.lift_rise, 0.0, "a car standing still carries nothing")


# ---------------------------------------------------------------- the throw and the bomb

func test_a_throws_recovery_with_both_hands_on_the_bomb_keeps_the_replica_away() -> void:
	var g := Grenades.new(tuning, WorldQuery.new())
	var cfg := PlantConfig.new()
	var events := SimEvents.new()
	var pool: Array[Grenade] = []
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	c.grenades.carry(1, 1)
	# the throw put the replica down; the arming began meanwhile
	c.armament.put_down()
	var hand := c.grenades
	hand.throwing = Grenade.Kind.SMOKE
	hand.released = true
	hand.recover_left = DT * 0.5
	hand.was_holstered = false
	Plant.hands_on(c, true, cfg, events)
	assert_true(c.bomb_was_holstered, "it was away when the hands went on (the throw had it down)")
	g.step_throw(c, Vector3(0.0, 1.6, 0.0), pool, events, DT)
	assert_eq(hand.throwing, Grenade.Kind.NONE, "the throw is over")
	assert_true(c.armament.holstered, "not drawn in the middle of the arming")
	assert_eq(events.count_of(GameEvent.Kind.DRAW), 0)
	Plant.hands_on(c, false, cfg, events)
	assert_false(c.armament.holstered, "drawn as the hands come off the bomb")
	assert_eq(events.count_of(GameEvent.Kind.DRAW), 1)


func test_a_throws_recovery_with_free_hands_draws_the_replica_as_before() -> void:
	var g := Grenades.new(tuning, WorldQuery.new())
	var events := SimEvents.new()
	var pool: Array[Grenade] = []
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	c.grenades.carry(1, 1)
	c.armament.put_down()
	c.grenades.throwing = Grenade.Kind.SMOKE
	c.grenades.released = true
	c.grenades.recover_left = DT * 0.5
	g.step_throw(c, Vector3(0.0, 1.6, 0.0), pool, events, DT)
	assert_false(c.armament.holstered)
	assert_eq(events.count_of(GameEvent.Kind.DRAW), 1)


func test_a_replica_holstered_before_the_throw_stays_away_through_the_arming() -> void:
	var g := Grenades.new(tuning, WorldQuery.new())
	var cfg := PlantConfig.new()
	var events := SimEvents.new()
	var pool: Array[Grenade] = []
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	c.grenades.carry(1, 1)
	c.armament.put_down()
	c.grenades.throwing = Grenade.Kind.SMOKE
	c.grenades.released = true
	c.grenades.recover_left = DT * 0.5
	c.grenades.was_holstered = true
	Plant.hands_on(c, true, cfg, events)
	g.step_throw(c, Vector3(0.0, 1.6, 0.0), pool, events, DT)
	Plant.hands_on(c, false, cfg, events)
	assert_true(c.armament.holstered, "it was holstered before the throw: it stays so")


func test_a_turn_towards_a_wall_on_the_tick_the_arming_starts_is_seen_by_the_set_down() -> void:
	var world := BoxWorld.new(tuning.body)
	world.add_floor(60.0, 60.0)
	var site := Vector3(5.0, 0.0, -5.0)
	world.add_box(Vector3(5.0, 1.0, -5.6), Vector3(12.0, 2.0, 0.2)) # its face at z = -5.5, 0.5 m ahead of -Z
	var ends: Array[MapEnd] = []
	for e in 2:
		var end := MapEnd.new()
		end.spawns.append(SpawnPoint.new(Vector3(-20.0 if e == 0 else 20.0, 0.0, 20.0), 0.0))
		end.dead_zone.append(SpawnPoint.new(Vector3(-25.0 if e == 0 else 25.0, 0.0, 25.0), 0.0))
		ends.append(end)
	var sim := Simulation.new(tuning, world, world.mover(), ends, -10.0)
	var state := GameState.new(5, tuning)
	var loadout := ReplicaStats.default_loadout()
	state.characters.append(Character.new(0, 0, Vector3.ZERO, 0.0, loadout))
	state.characters.append(Character.new(1, 1, Vector3.ZERO, 0.0, loadout))
	sim.start_match(state)
	var rs := state.round_state
	rs.mode = RoundState.Mode.PLANT_THE_BOMB
	rs.phase = RoundState.Phase.LIVE
	rs.hold = 0.0
	rs.attackers = 0
	rs.plant.set_sites(PackedVector3Array([site]), PackedFloat32Array([4.0]), 4.0)
	rs.plant.reset()
	rs.plant.status = PlantState.Status.CARRIED
	rs.plant.carrier = 0
	var c := state.characters[0]
	var foe := state.characters[1]
	c.position = site + Vector3(0.0, tuning.body.rest_gap, 0.0)
	c.prev_position = c.position
	c.yaw = PI * 0.5 # facing -X, open
	c.grounded = true
	foe.position = Vector3(-25.0, 0.0, 25.0)
	foe.prev_position = foe.position
	var cmds: Array[PlayerCommand] = [PlayerCommand.new(), PlayerCommand.new()]
	cmds[0].reset(0.0, 0.0) # turns to face -Z, the wall, on the tick it presses use
	cmds[0].interact = true
	cmds[1].reset(foe.yaw, 0.0)
	sim.step(state, cmds, DT)
	assert_eq(rs.plant.planter, 0, "the arming started")
	assert_lt(rs.plant.set_room, 1.0, "the room ahead is measured from the turned view: the wall is seen")
	var room_ahead := Vector2(rs.plant.set_at.x - c.position.x, rs.plant.set_at.z - c.position.z).length()
	assert_lt(room_ahead, 0.5, "set down short of the wall, not into it")


# ---------------------------------------------------------------- HUD

func test_someone_out_carries_no_bomb_on_the_rail() -> void:
	var rs := RoundState.new()
	rs.mode = RoundState.Mode.PLANT_THE_BOMB
	rs.plant.status = PlantState.Status.CARRIED
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	rs.plant.carrier = c.id
	assert_eq(HudPlant.rail_carry(rs, c), WeaponRail.Carry.CARRIED, "control: in play, carrying")
	rs.plant.planter = c.id
	assert_eq(HudPlant.rail_carry(rs, c), WeaponRail.Carry.SETTING, "control: setting it down")
	c.status = Character.Status.OUT
	assert_eq(HudPlant.rail_carry(rs, c), WeaponRail.Carry.NONE, "hit with the bomb: the row goes at once")


func _hud() -> Hud:
	var state := GameState.new()
	for i in 4:
		state.characters.append(Character.new(i, 0 if i < 2 else 1))
	var hud := Hud.new()
	add_child_autofree(hud)
	hud.setup(HudConfig.new(), TeamConfig.new(), ViewConfig.new(), SimTuning.new(), state.characters[0])
	hud.setup_field(BoxWorld.new(), BodyConfig.new(), PackedStringArray(["", "Brick", "Rook", "Dash"]),
			state.characters, null)
	return hud


func test_the_bomb_notes_survive_a_settings_change_with_callouts_off() -> void:
	var hud := _hud()
	var p := HudPrefs.new()
	p.callouts = false
	hud.apply_prefs(p) # the switch goes off: call lines dropped (none yet)
	hud.hit_lines().add_note(2, "planted the bomb at A", 1.0)
	assert_eq(hud.hit_lines().count(), 1)
	hud.apply_prefs(p) # any other setting changed: the same prefs again
	hud.apply_prefs(p)
	assert_eq(hud.hit_lines().count(), 1, "the note is not wiped by a volume slider")
	p.callouts = true
	hud.apply_prefs(p)
	assert_eq(hud.hit_lines().count(), 1, "switching on drops nothing")
	p.callouts = false
	hud.apply_prefs(p)
	assert_eq(hud.hit_lines().count(), 0, "as it goes off the call lines are dropped")


func test_the_flag_marker_hides_under_the_banner_and_comes_back_without_it() -> void:
	var hud := _hud()
	var r := Rect2(10.0, 10.0, 20.0, 20.0)
	assert_false(hud._under_stack(r), "no banner or plate showing: nothing to be under")
	hud._banner.visible = true
	hud._banner.size = Vector2(200.0, 40.0)
	hud._banner.position = Vector2.ZERO
	hud._middle.position = Vector2.ZERO
	assert_true(hud._under_stack(r), "over the banner")
	assert_false(hud._under_stack(Rect2(500.0, 500.0, 5.0, 5.0)), "clear of it")
	hud._banner.visible = false
	assert_false(hud._under_stack(r), "the banner gone")


# ---------------------------------------------------------------- config

func test_a_burst_of_zero_warns_and_keeps_one() -> void:
	var text := MINIMAL.replace("| Rusher | 0.3 | 0.3 | 1 | 0.25 | -0.25 | 1.2 | 0.8 | – |",
			"| Rusher | 0.3 | 0.3 | 1 | 0.25 | -0.25 | 0 | 0.8 | – |")
	var f := BotsFile.parse(text)
	assert_eq(f.problems.size(), 1, str(f.problems))
	assert_string_contains(f.problems[0], "Burst (×)")
	assert_string_contains(f.problems[0], "0.1")
	assert_eq(f.style(&"rusher").burst, 1.0, "the neutral value stands")
	assert_almost_eq(f.style(&"rusher").burst_pause, 0.8, 1e-6, "the rest of the row still counts")


func test_a_burst_of_the_least_is_read_and_a_zero_pause_still_is_allowed() -> void:
	var text := MINIMAL.replace("| Rusher | 0.3 | 0.3 | 1 | 0.25 | -0.25 | 1.2 | 0.8 | – |",
			"| Rusher | 0 | 0 | 0 | 0 | -0.25 | 0.1 | 0 | – |")
	var f := BotsFile.parse(text)
	assert_eq(f.problems, [] as Array[String])
	assert_almost_eq(f.style(&"rusher").burst, 0.1, 1e-6)
	assert_eq(f.style(&"rusher").burst_pause, 0.0)
	assert_eq(f.style(&"rusher").hold_time, 0.0)


func test_no_shipped_personality_has_a_burst_below_the_least() -> void:
	var f := BotsFile.read_file()
	for k: StringName in f.kinds:
		assert_gte(f.style(k).burst, BotsFile.BURST_LEAST, "%s" % k)


# ---------------------------------------------------------------- menus

func _loadout_page(saved: SavedLoadouts, settings: Settings) -> LoadoutPage:
	var page := LoadoutPage.new(saved, settings)
	page.save_path = LOADOUTS
	page.settings_path = SETTINGS
	add_child_autofree(page)
	return page


func _azerty(logical: Key, physical: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = logical
	e.physical_keycode = physical
	e.pressed = true
	return e


func test_keys_1_to_5_pick_a_loadout_by_where_they_sit_on_an_azerty_layout() -> void:
	var saved := SavedLoadouts.new(LoadoutRules.standard())
	saved.create()
	saved.create()
	var page := _loadout_page(saved, Settings.new())
	assert_eq(saved.current, 2)
	page._unhandled_input(_azerty(KEY_AMPERSAND, KEY_1))
	assert_eq(saved.current, 0, "the ampersand key on the 1 position")
	page._unhandled_input(_azerty(KEY_QUOTEDBL, KEY_3))
	assert_eq(saved.current, 2, "the quote key on the 3 position")
	page._unhandled_input(_azerty(KEY_A, KEY_Q))
	assert_eq(saved.current, 2, "a letter key is no number")
	page._unhandled_input(_azerty(KEY_ASCIITILDE, KEY_2))
	assert_eq(saved.current, 1)
	var shifted := _azerty(KEY_1, KEY_1)
	shifted.shift_pressed = true
	page._unhandled_input(shifted)
	assert_eq(saved.current, 1, "a shifted key picks nothing")
	await wait_process_frames(2)


func test_the_monitor_and_renderer_buttons_carry_their_rows_help() -> void:
	var settings := Settings.new(PlayTuning.new())
	var screen := SettingsScreen.new()
	screen.settings = settings
	screen.save_path = ROOT.path_join("settings.save")
	DirAccess.make_dir_recursive_absolute(ROOT)
	add_child_autofree(screen)
	var ds := FakeScreens.new()
	ds.sizes = [Vector2i(2560, 1440), Vector2i(1920, 1080)]
	ds.rates = [144.0, 60.0]
	SettingsApply.use_screens(ds)
	screen.open()
	var display: SettingsDisplayPage = screen._display_page
	assert_not_null(display.monitor_choice())
	assert_ne(tr("SETTINGS_MONITOR_HELP"), "")
	for i in 2:
		assert_eq(display.monitor_choice().button(i).tooltip_text, tr("SETTINGS_MONITOR_HELP"),
				"the Monitor button %d" % i)
	var graphics: SettingsGraphicsPage = screen._graphics_page
	var choice := graphics.renderer_choice()
	assert_not_null(choice)
	for i in choice.get_child_count():
		assert_eq(choice.button(i).tooltip_text, tr("GRAPHICS_RENDERER_NOTE"), "the Renderer button %d" % i)


func test_the_match_page_waits_while_hidden_and_reads_the_settings_when_shown() -> void:
	var settings := Settings.new()
	var page := MatchPage.new(MatchPicks.new(), settings)
	page.rules_box().save_path = ROOT.path_join("rules.save")
	DirAccess.make_dir_recursive_absolute(ROOT)
	add_child_autofree(page)
	var shown := page._tuning
	assert_not_null(shown)
	# control: shown, a settings change retunes
	page._tuning = null
	settings.changed.emit()
	assert_not_null(page._tuning, "shown: it reads the new settings at once")
	page.visible = false
	page._tuning = null
	for i in 20:
		settings.changed.emit() # a slider dragged under Settings
	assert_null(page._tuning, "hidden: nothing rebuilt for a page nobody sees")
	assert_true(page._stale)
	page.visible = true
	assert_not_null(page._tuning, "shown again: read once")
	assert_false(page._stale)
	page.visible = false
	page.visible = true
	assert_false(page._stale, "shown with nothing changed: nothing to do")


func test_a_match_page_freed_while_stale_leaves_no_connection() -> void:
	var settings := Settings.new()
	var page := MatchPage.new(MatchPicks.new(), settings)
	page.rules_box().save_path = ROOT.path_join("rules2.save")
	DirAccess.make_dir_recursive_absolute(ROOT)
	add_child(page)
	page.visible = false
	settings.changed.emit()
	remove_child(page)
	assert_false(settings.changed.is_connected(page._on_rules_changed))
	page.free()
	settings.changed.emit()


# ---------------------------------------------------------------- map load: same results as the references

func _map(id: String) -> MapData:
	var m := MapData.load_map(id, PlayTuning.load_default().map_style, 1 if id == "range" else tuning.rounds.team_size)
	assert_true(m.ok(), "%s loads: %s" % [id, m.problems])
	return m


func test_site_cores_fold_the_same_tiles_as_the_per_block_walk() -> void:
	var play := PlayTuning.load_default()
	for id: String in ["range", "depot"]:
		var m := _map(id)
		var level := MapLevel.new()
		add_child_autofree(level)
		level.build(m, play.map_style, tuning.body, play.baked_light, LightingConfig.for_map(play.lighting, null, m,
				LightingConfig.DAY), false, play.site_look)
		var got := GreyboxFaces.tile(m, play.baked_light.cell, play.baked_light.ground_y)
		var want := GreyboxFaces.tile(m, play.baked_light.cell, play.baked_light.ground_y)
		level._site_cores(got)
		var cored := 0
		for i in m.blocks.size():
			var core := SiteSurface.core_of(play.site_look, m.blocks[i], m)
			if core == Transform3D.IDENTITY:
				continue
			cored += 1
			for v in want.blocks.size():
				if want.blocks[v] == i:
					want.positions[v] = core * want.positions[v]
		assert_gt(cored, 0, "%s has cored blocks" % id)
		assert_eq(got.positions.size(), want.positions.size())
		var wrong := 0
		for v in want.positions.size():
			if not got.positions[v].is_equal_approx(want.positions[v]):
				wrong += 1
		assert_eq(wrong, 0, "%s: every vertex where the straightforward walk puts it" % id)


func _reference_bases(map: MapData, cfg: MinimapConfig) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	out.resize(map.blocks.size())
	for i in map.blocks.size():
		var b := map.blocks[i]
		var bottom := b.center.y - b.size.y * 0.5
		var best := -INF
		for f in map.blocks:
			if f == b or not MinimapField._is_floor(f) or not MinimapField._holds(f, b.center.x, b.center.z):
				continue
			var top := MinimapField._floor_top(f, b.center.x, b.center.z)
			if top <= bottom + cfg.floor_contact:
				best = maxf(best, top)
		out[i] = best if is_finite(best) else bottom
	return out


func test_minimap_bases_match_the_block_against_block_reference() -> void:
	var cfg := PlayTuning.load_default().minimap
	for id: String in ["depot", "range", "subway"]:
		var m := _map(id)
		var got := MinimapField._bases(m, cfg)
		var want := _reference_bases(m, cfg)
		assert_eq(got.size(), want.size())
		var wrong := 0
		for i in want.size():
			if got[i] != want[i]:
				wrong += 1
		assert_eq(wrong, 0, "%s: %d blocks' floors" % [id, m.blocks.size()])


# ---------------------------------------------------------------- the save

func _keeper(dir: String) -> SaveKeeper:
	DirAccess.make_dir_recursive_absolute(dir)
	var keeper := SaveKeeper.new()
	var paths: Array[String] = []
	for path: String in SaveBundle.PATHS:
		paths.append(dir.path_join(path.get_file()))
	keeper.store_paths = paths
	keeper.points_path = dir.path_join("restore_points.save")
	keeper.undo_path = dir.path_join("undo.save")
	keeper.clock = func() -> float: return 1792497600.0
	keeper.utc_offset_minutes = 0
	return keeper


func _snapshot(dir: String) -> Dictionary[String, PackedByteArray]:
	var out: Dictionary[String, PackedByteArray] = {}
	for f: String in DirAccess.get_files_at(dir):
		out[f] = FileAccess.get_file_as_bytes(dir.path_join(f))
	return out


func test_a_refused_replace_leaves_a_damaged_store_in_its_place() -> void:
	var dir := ROOT.path_join("replace")
	var keeper := _keeper(dir)
	for i in keeper.store_paths.size():
		assert_true(SaveFile.write(keeper.store_paths[i], SaveBundle.KINDS[i], 1, {"n": 1}))
	keeper.keep_today()
	# one store damaged, the others whole: the save is not empty, so the Undo copy has to be written
	SaveFile.remove(keeper.store_paths[0])
	var f := FileAccess.open(keeper.store_paths[0], FileAccess.WRITE)
	f.store_string("ASAVE settings 1 beef\n{}")
	f.close()
	keeper.undo_path = dir.path_join("no/such/folder/undo.save") # the Undo write is refused
	var before := _snapshot(dir)
	assert_false(keeper.replace(SaveBundle.new(), SaveKeeper.What.DELETE))
	assert_string_contains(keeper.last_error, "Undo")
	assert_eq(_snapshot(dir), before, "every file as found: the damaged store still there, nothing set aside")
	for name: String in _snapshot(dir):
		assert_false(name.contains(".corrupt-"), "nothing quarantined by a refused replace")
	assert_false(SaveFile.held(keeper.store_paths[0]), "a refused replace holds nothing")
	SaveFile.release(PackedStringArray(keeper.store_paths))


func test_a_replace_that_goes_through_still_sets_a_damaged_store_aside() -> void:
	var dir := ROOT.path_join("replace-ok")
	var keeper := _keeper(dir)
	for i in keeper.store_paths.size():
		assert_true(SaveFile.write(keeper.store_paths[i], SaveBundle.KINDS[i], 1, {"n": 1}))
	keeper.keep_today()
	SaveFile.remove(keeper.store_paths[0])
	var f := FileAccess.open(keeper.store_paths[0], FileAccess.WRITE)
	f.store_string("ASAVE settings 1 beef\n{}")
	f.close()
	assert_true(keeper.replace(keeper.restore_points()[0].save, SaveKeeper.What.RESTORE))
	var aside := 0
	for name: String in _snapshot(dir):
		if name.contains(".corrupt-"):
			aside += 1
	assert_eq(aside, 1, "the damaged settings kept aside, never destroyed")
	assert_not_null(keeper.undo_slot(), "and the Undo copy written first")
	SaveFile.release(PackedStringArray(keeper.store_paths))


# ---------------------------------------------------------------- in a match

func test_calls_made_during_a_skip_are_passed_over_then_not_played_when_it_ends() -> void:
	var session := PlaySession.new()
	session.bots_active = false
	session.settings = Settings.new(PlayTuning.new())
	session.settings_path = SETTINGS
	add_child_autofree(session)
	await wait_physics_frames(2)
	var state := session.state
	var said := session._bots.callouts.said
	var mate := -1
	for c in state.characters:
		if c.team == session.player.team and c.id != session.player.id:
			mate = c.id
	session._skipping = true
	for i in 12:
		said.add(mate, session.player.team, CalloutsFile.Event.CONTACT, "Contact %d" % i, state.time)
		session._after_tick()
	assert_eq(session._audio._call_serial, said.total, "the serial moved with every skipped tick")
	session._skipping = false
	session._after_tick()
	var playing := 0
	for v in session._audio.radio_voices():
		if v.playing:
			playing += 1
	assert_eq(playing, 0, "no radio click for a call made under the cover")
	session._skipping = true
	session.settings.hud.callouts = false
	said.add(mate, session.player.team, CalloutsFile.Event.CONTACT, "Late", state.time)
	session._after_tick()
	session._skipping = false
	assert_eq(session._audio._call_serial, said.total, "callouts off: passed over too")


func test_the_lamp_light_switch_refreshes_the_scene_light_only_on_a_change() -> void:
	var session := PlaySession.new()
	session.map_id = "depot"
	session.practice = true
	session.autopilot = true
	session.settings = Settings.new(PlayTuning.new())
	add_child_autofree(session)
	await wait_physics_frames(2)
	assert_gte(session._lamp_light, 0, "the first apply recorded it, with no refresh then")
	var ultra := GraphicsTable.shared().preset(&"ultra").copy()
	ultra.lamp_lights = GraphicsQuality.LampLights.OFF
	session._apply_graphics(ultra)
	for i in FieldLighting.SCENE_LIGHT_REFRESH_FRAMES + 2:
		await get_tree().process_frame
	assert_false(session._lighting.refreshing_scene_light())
	session._apply_graphics(ultra)
	assert_false(session._lighting.refreshing_scene_light(), "the same Lamp light again: no refresh")
	var near := ultra.copy()
	near.lamp_lights = GraphicsQuality.LampLights.NEAR
	session._apply_graphics(near)
	if session._lighting.environment.sdfgi_enabled or session._lighting.refreshing_scene_light():
		assert_true(session._lighting.refreshing_scene_light(), "a Lamp light switch gathers the bounce afresh")
	session._apply_graphics(near)
	assert_eq(session._lamp_light, int(GraphicsQuality.LampLights.NEAR))
	for i in FieldLighting.SCENE_LIGHT_REFRESH_FRAMES + 2:
		await get_tree().process_frame
	assert_false(session._lighting.refreshing_scene_light(), "and it ends")


# ---------------------------------------------------------------- the parts, keep and release

func test_two_kept_takes_are_independent_copies() -> void:
	ReplicaParts.keep()
	var parts := {&"light": &"weaponTorch", &"laser": &"redLaser"}
	var a := ReplicaParts.take(&"pistol", parts, false)
	var b := ReplicaParts.take(&"pistol", parts, false)
	assert_false(a.is_empty())
	for slot: StringName in a:
		assert_ne(a[slot], b[slot], "%s: its own node" % slot)
		assert_null(a[slot].get_parent(), "%s: owned by nothing" % slot)
	var moved: Vector3 = b[&"light"].position
	a[&"light"].position += Vector3(5.0, 0.0, 0.0)
	assert_eq(b[&"light"].position, moved, "moving one leaves the other where it was")
	var fig := ReplicaParts.take(&"pistol", parts, true)
	ReplicaParts.release()
	for d: Dictionary[StringName, Node3D] in [a, b, fig]:
		for n: Node3D in d.values():
			n.free()


func test_a_kept_run_leaves_no_objects_behind() -> void:
	var before := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	for round_n in 3:
		ReplicaParts.keep()
		var taken: Array[Dictionary] = []
		for key: StringName in [&"aeg", &"pistol", &"aeg", &"sniper"]:
			taken.append(ReplicaParts.take(key, {&"light": &"weaponTorch", &"laser": &"redLaser",
					&"optic": &"redDot"}, true))
			taken.append(ReplicaParts.take(key, {&"optic": &"redDot"}, false))
		ReplicaParts.release()
		for d: Dictionary in taken:
			for n: Variant in d.values():
				(n as Node3D).free()
	assert_eq(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), orphans, "no orphan nodes")
	assert_lte(int(Performance.get_monitor(Performance.OBJECT_COUNT)), before + 2, "no objects left held")


func test_a_take_asking_for_a_missing_part_between_keep_and_release_gives_the_others() -> void:
	ReplicaParts.keep()
	var got := ReplicaParts.take(&"aeg", {&"light": &"weaponTorch", &"optic": &"noSuchPart"}, true)
	ReplicaParts.release()
	assert_true(got.has(&"light"))
	assert_false(got.has(&"optic"))
	for n: Node3D in got.values():
		n.free()
