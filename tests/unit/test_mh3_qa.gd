extends GutTest
## QA hunt for MH3 (Need a Mag on H and the wheel, the hand-off line and the toss on screen): the wheel's Toss a Mag and
## the line against the simulation's own pick of who a press tosses to, the glyph's and the wheel's lifecycle (ask
## lapses, toss in the air, catch, asker out), each toss wearing its own thrower's replica's magazine, a toss whose
## round is decided or whose catcher is out, and H not colliding with another default binding. Headless, on a BoxWorld
## floor with the default loadout.

const DT := 1.0 / 60.0
const NAMES := ["", "Rook", "Brick", "Fox"]
const YOU := 0
const ROOK := 1
const BRICK := 2

var tuning := SimTuning.new()
var loadout: Array[ReplicaConfig] = []
var controls := ControlsConfig.new()
var world: BoxWorld = null
var sim: Simulation = null
var state: GameState = null
var cmds: Array[PlayerCommand] = []
var hud: Hud = null
var wheel: OrderWheelPointer = null
var outcome := SquadOrders.Outcome.new()


func before_all() -> void:
	loadout = ReplicaStats.default_loadout()


func before_each() -> void:
	controls = ControlsConfig.new()
	wheel = OrderWheelPointer.new(controls.wheel_reach, controls.wheel_dead_zone, controls.wheel_orders.size())
	outcome = SquadOrders.Outcome.new()


## You (0), Rook (1) 4 m off, Brick (2) 8 m off on your team, Fox (3) far off on the other; round 1 live.
func _match() -> void:
	var w := BoxWorld.new(tuning.body)
	w.add_floor(60.0, 30.0)
	world = w
	var ends: Array[MapEnd] = []
	for e in 2:
		var end := MapEnd.new()
		for i in 3:
			end.spawns.append(SpawnPoint.new(Vector3(-10.0 if e == 0 else 10.0, 0.0, i * 2.0), 0.0))
			end.dead_zone.append(SpawnPoint.new(Vector3(-25.0 if e == 0 else 25.0, 0.0, 10.0), 0.0))
		ends.append(end)
	sim = Simulation.new(tuning, w, w.mover(), ends, -10.0)
	state = GameState.new(5, tuning)
	for i in 4:
		state.characters.append(Character.new(i, 0 if i < 3 else 1, Vector3.ZERO, 0.0, loadout))
	sim.start_match(state)
	var spots: Array[Vector3] = [Vector3.ZERO, Vector3(4.0, 0.0, 0.0), Vector3(0.0, 0.0, 8.0),
			Vector3(25.0, 0.0, -10.0)]
	for c in state.characters:
		c.position = spots[c.id] + Vector3(0.0, c.position.y, 0.0)
		c.prev_position = c.position
	cmds.clear()
	for c in state.characters:
		var k := PlayerCommand.new()
		k.reset(c.yaw, c.pitch)
		cmds.append(k)
	var frame := Control.new()
	frame.size = get_viewport().get_visible_rect().size
	add_child_autofree(frame)
	hud = Hud.new()
	frame.add_child(hud)
	hud.setup(HudConfig.new(), TeamConfig.new(), ViewConfig.new(), tuning, state.characters[YOU])
	hud.setup_orders(controls)
	hud.setup_mag_line(sim.mag_share, state.characters.size())
	hud.setup_field(w, tuning.body, PackedStringArray(NAMES), state.characters, null)


func _tick(pressing: Array = []) -> void:
	for k in cmds:
		k.mag_hand_off = false
	for id: int in pressing:
		cmds[id].mag_hand_off = true
	sim.step(state, cmds, DT)
	hud.on_tick(state, false)
	hud.update_orders(wheel, SquadOrder.Kind.NONE, outcome, DT)


func _ticks(n: int) -> void:
	for i in n:
		_tick()


static func _last_mag(c: Character) -> void:
	c.armament.ammo[0].pouch.fill(0)


func _line() -> HudMagLine:
	return hud.mag_line()


func _open_wheel() -> HudOrderWheel:
	wheel.start()
	wheel.at = Vector2(-80.0, -26.0)
	hud.update_orders(wheel, SquadOrder.Kind.NONE, outcome, DT)
	return hud.order_wheel()


func _camera() -> Camera3D:
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.look_at_from_position(Vector3(-6.0, 1.6, 4.0), Vector3(2.0, 1.0, 4.0))
	return camera


# --- the wheel and the line against the simulation's own pick ---

## The press tosses to the nearest asker IN REACH (MagShare._nearest_asker); the wheel's item must read Toss a Mag
## whenever a press would toss, so a nearer asker behind a wall must not hide a farther one in the open.
func test_the_wheel_reads_toss_a_mag_when_a_farther_asker_is_in_reach_and_the_nearest_is_walled_off() -> void:
	_match()
	world.add_box(Vector3(2.0, 1.5, 0.0), Vector3(0.4, 3.0, 4.0))
	state.characters[BRICK].position = Vector3(0.0, 0.0, 5.0)
	state.characters[BRICK].prev_position = state.characters[BRICK].position
	_last_mag(state.characters[ROOK])
	_last_mag(state.characters[BRICK])
	_tick([ROOK, BRICK])
	assert_eq(state.characters[ROOK].mag.asked, YOU, "Rook (4 m, behind the wall) asks you")
	assert_eq(state.characters[BRICK].mag.asked, YOU, "Brick (5 m, in the open) asks you")
	var pick := MagShare.SparePick.new()
	var you := state.characters[YOU]
	assert_false(sim.mag_share.can_toss_to(you, state.characters[ROOK], pick), "the wall is in the way")
	assert_true(sim.mag_share.can_toss_to(you, state.characters[BRICK], pick), "Brick is in reach")
	var w := _open_wheel()
	assert_true(_line().toss_ready(), "a press would toss to Brick")
	assert_eq(w.slice_name(5), "TOSS A MAG", "so the wheel's item reads Toss a Mag")
	wheel.close()
	_tick([YOU])
	var toss := state.events.first(GameEvent.Kind.MAG_TOSS)
	assert_not_null(toss, "the press did toss")
	if toss != null:
		assert_eq(toss.target, BRICK, "to Brick")


# --- the lifecycle of the glyph and the wheel item ---

func test_the_glyph_goes_when_the_ask_lapses_and_when_the_asker_is_out() -> void:
	_match()
	var camera := _camera()
	await wait_process_frames(1)
	var you := state.characters[YOU]
	_last_mag(state.characters[ROOK])
	_tick([ROOK])
	hud.place_team_markers(camera, state.characters, you, 1.0)
	assert_true(hud.team_markers().has_mag(ROOK), "Rook asks you")
	assert_eq(_line().text, "Rook needs a mag · 4 m")
	state.time += tuning.mag_share.ask_time + 1.0
	_tick()
	hud.place_team_markers(camera, state.characters, you, 1.0)
	assert_eq(state.characters[ROOK].mag.asked, -1, "the ask lapsed")
	assert_false(hud.team_markers().has_mag(ROOK), "no glyph once the ask lapsed")
	assert_eq(_line().text, "", "and no line")
	assert_false(_line().visible)
	state.characters[ROOK].mag.next_ask = -INF
	_tick([ROOK])
	hud.place_team_markers(camera, state.characters, you, 1.0)
	assert_true(hud.team_markers().has_mag(ROOK), "Rook asks again")
	state.characters[ROOK].status = Character.Status.CALLING
	_tick()
	hud.place_team_markers(camera, state.characters, you, 1.0)
	assert_false(hud.team_markers().has_mag(ROOK), "an asker who is out has no glyph")
	assert_eq(_line().text, "", "and the line stops naming them")


func test_the_wheel_item_reads_need_a_mag_again_once_the_toss_is_in_the_air() -> void:
	_match()
	_last_mag(state.characters[ROOK])
	_tick([ROOK])
	var w := _open_wheel()
	assert_eq(w.slice_name(5), "TOSS A MAG")
	_tick([YOU])
	assert_not_null(state.events.first(GameEvent.Kind.MAG_TOSS))
	hud.update_orders(wheel, SquadOrder.Kind.NONE, outcome, DT)
	assert_eq(w.slice_name(5), "NEED A MAG", "nothing left to toss to: the magazine is in the air")
	assert_false(_line().toss_ready())


# --- the toss view ---

func test_each_toss_wears_its_throwers_replica_magazine_slot_and_all() -> void:
	_match()
	var cyber := ReplicaStats.load_replica(&"cyber")
	var squad: Array[ReplicaConfig] = [cyber, loadout[1]]
	state.characters[ROOK] = Character.new(ROOK, 0, Vector3(4.0, 0.0, 0.0), 0.0, squad)
	var models := FigureModels.new(FigureConfig.new())
	var view := MagTossView.new()
	add_child_autofree(view)
	view.setup(state.mag_tosses.size(), state.characters, models, sim.mag_share)
	for slot in 2:
		var t := state.mag_tosses[slot]
		t.active = true
		t.from_id = ROOK
		t.from_slot = slot
		t.to_id = YOU
		t.from = Vector3(4.0, 1.3, 0.0)
		t.age = 0.1
		t.flight = 0.6
	view.update(state, 0.0, DT)
	var want0 := models.magazine_mesh(cyber.id)
	var want1 := models.magazine_mesh(loadout[1].id)
	assert_not_null(want0, "the cyber model has a magazine")
	assert_ne(view.mesh_of(0), view.mesh_of(1), "a rifle's and a pistol's differ")
	if want0 != null:
		assert_eq(view.mesh_of(0), want0, "slot 0: the cyber's own")
	if want1 != null:
		assert_eq(view.mesh_of(1), want1, "slot 1: the pistol's own")


func test_every_replica_model_has_a_magazine_mesh_to_toss() -> void:
	var models := FigureModels.new(FigureConfig.new())
	for id: StringName in [&"aeg", &"cyber", &"pistol"]:
		assert_not_null(models.magazine_mesh(id), "%s has a Magazine mesh" % id)


func test_a_toss_whose_catcher_goes_out_or_whose_round_is_decided_disappears() -> void:
	_match()
	var view := MagTossView.new()
	add_child_autofree(view)
	view.setup(state.mag_tosses.size(), state.characters, null, sim.mag_share)
	_last_mag(state.characters[ROOK])
	_tick([ROOK])
	_tick([YOU])
	view.update(state, 0.5, DT)
	assert_true(view.shown(0), "in the air")
	state.characters[ROOK].status = Character.Status.CALLING
	var lost := false
	for i in 90:
		_tick()
		lost = lost or state.events.first(GameEvent.Kind.MAG_LOST) != null
		view.update(state, 0.5, DT)
	assert_true(lost, "the catcher went out: the magazine is lost")
	assert_false(view.shown(0), "a lost toss is not drawn")
	# And with the round decided while one flies.
	_match()
	var view2 := MagTossView.new()
	add_child_autofree(view2)
	view2.setup(state.mag_tosses.size(), state.characters, null, sim.mag_share)
	_last_mag(state.characters[ROOK])
	_tick([ROOK])
	_tick([YOU])
	view2.update(state, 0.5, DT)
	assert_true(view2.shown(0))
	state.round_state.phase = RoundState.Phase.OVER
	assert_false(state.round_state.is_live(), "a phase that is not live")
	_tick()
	view2.update(state, 0.5, DT)
	assert_false(view2.shown(0), "the round decided: every magazine in the air is lost and gone")


func test_the_toss_lands_at_the_catchers_chest() -> void:
	_match()
	var view := MagTossView.new()
	add_child_autofree(view)
	view.setup(state.mag_tosses.size(), state.characters, null, sim.mag_share)
	var t := state.mag_tosses[0]
	t.active = true
	t.from_id = YOU
	t.to_id = ROOK
	t.from = Vector3(0.0, 1.3, 0.0)
	t.age = 0.0
	t.flight = 0.5
	var chest := sim.mag_share.catch_point(state.characters[ROOK])
	view.update(state, 1.0, 0.5)
	var m := view.get_child(0) as MeshInstance3D
	var middle := m.mesh.get_aabb().get_center()
	assert_almost_eq(m.transform * middle, chest, Vector3.ONE * 0.01, "lands at the catcher's chest")


# --- input ---

func test_h_is_bound_by_no_other_default_action() -> void:
	var holders: Array[StringName] = []
	for action: StringName in KeyBindings.ACTIONS:
		for code: int in KeyBindings.DEFAULTS.get(action, []):
			if code == KEY_H:
				holders.append(action)
	assert_eq(holders, [&"mag_hand_off"] as Array[StringName], "only the hand-off defaults to H")
	var in_map: Array[StringName] = []
	for action in InputMap.get_actions():
		if String(action).begins_with("ui_"):
			continue
		for ev in InputMap.action_get_events(action):
			var k := ev as InputEventKey
			if k != null and (k.physical_keycode == KEY_H or k.keycode == KEY_H):
				in_map.append(action)
	assert_eq(in_map, [&"mag_hand_off"] as Array[StringName], "the input map has H on the hand-off alone")
