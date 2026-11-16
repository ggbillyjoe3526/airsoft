extends GutTest
## BP9 QA: edges of the fixes. The wheel's tap (a wheel of no tap, a key let go unseen, a wheel shut or a window lost
## inside or past the tap, the view's catch-up at the aimed and inverted sensitivity, nothing left over for the next
## opening); the order notices (once, never for the giver hit or an order replaced); the safe start's graphics with
## odd tables; the Spotted arrow's ends.

const ACTIONS: Array[StringName] = [&"order_wheel", &"fire", &"aim"]

const DT := 1.0 / 60.0
const KILL_Y := -10.0
## Yaw that looks along +X.
const EAST := -PI * 0.5
const YOU := 0
const NEAR := 3
const FAR := 4
const SPOTS: Array[Vector3] = [Vector3(-30.0, 0.0, 20.0), Vector3(-32.0, 0.0, 23.0), Vector3(-28.0, 0.0, 23.0),
		Vector3(40.0, 0.0, -40.0), Vector3(42.0, 0.0, -40.0)]

var tuning: SimTuning = SimTuning.load_default()
var config: BotConfig = null

var map: MapData = null
var nav: NavGrid = null
var state: GameState = null
var sim: Simulation = null
var bots: BotController = null
var commands: Array[PlayerCommand] = []
var cmd: PlayerCommand = null
var you: Character = null
var mates: Array[Bot] = []
var _nav: NavGrid = null
var input: PlayerInput = null
var controls: ControlsConfig = null
var pcmd: PlayerCommand = PlayerCommand.new()


func before_each() -> void:
	config = BotConfig.load_default().duplicate() as BotConfig
	controls = ControlsConfig.new()
	input = PlayerInput.new()
	input.setup(controls, 1.5)
	add_child_autofree(input)
	input.active = true


func after_each() -> void:
	for action: StringName in ACTIONS:
		Input.action_release(action)


static func _block(kind: StringName, center: Vector3, size: Vector3) -> MapData.Block:
	var b := MapData.Block.new()
	b.kind = kind
	b.center = center
	b.size = size
	return b


## You and two bot teammates at SPOTS, two opponents far off (still, driven by nobody), round 1 live.
func _squad() -> void:
	map = MapData.new()
	map.id = "open field"
	map.kill_y = KILL_Y
	var w := BoxWorld.new(tuning.body)
	w.add_floor(100.0, 100.0)
	map.blocks.append(_block(&"floor", Vector3(0.0, -0.25, 0.0), Vector3(100.0, 0.5, 100.0)))
	for e in 2:
		var end := MapEnd.new()
		for i in 3:
			end.spawns.append(SpawnPoint.new(SPOTS[i] if e == 0 else SPOTS[3] + Vector3(2.0 * i, 0.0, 0.0), EAST))
		end.dead_zone.append(SpawnPoint.new(Vector3(-45.0, 0.0, 45.0) if e == 0 else Vector3(45.0, 0.0, -45.0), 0.0))
		map.ends.append(end)
	if _nav == null:
		_nav = NavGrid.build(map, tuning.nav, tuning.body)
	nav = _nav
	sim = Simulation.new(tuning, w, w.mover(), map.ends, KILL_Y)
	sim.nav = nav
	state = GameState.new(5, tuning)
	var loadout := ReplicaStats.default_loadout()
	commands.clear()
	for i in SPOTS.size():
		state.characters.append(Character.new(i, 0 if i < 3 else 1, SPOTS[i], EAST, loadout))
		commands.append(PlayerCommand.new())
	bots = BotController.new(state, YOU, map, nav, w, tuning, config)
	sim.start_match(state)
	state.cheats.bots_hold_fire = true
	bots.observe(state)
	# Nobody drives the opponents: they stand where a test puts them.
	for i in range(bots.world.bots.size() - 1, -1, -1):
		if bots.world.bots[i].character.team == 1:
			bots.world.bots.remove_at(i)
	for i in SPOTS.size():
		state.characters[i].position = SPOTS[i]
	you = state.characters[YOU]
	cmd = commands[YOU]
	cmd.reset(EAST, 0.0)
	mates.clear()
	for b in bots.world.bots:
		if b.character.team == 0:
			mates.append(b)
	_run(0.5)


func _tick() -> void:
	bots.think(state, commands, DT)
	sim.step(state, commands, DT)
	bots.observe(state)


func _run(seconds: float) -> void:
	for t in roundi(seconds / DT):
		_tick()


func _event(action: StringName, pressed: bool) -> void:
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)
	var e := InputEventAction.new()
	e.action = action
	e.pressed = pressed
	input._unhandled_input(e)


func _move(dx: float, dy: float) -> void:
	var e := InputEventMouseMotion.new()
	e.screen_relative = Vector2(dx, dy)
	input._unhandled_input(e)


func _hold_past_a_tap() -> void:
	input.wheel().opened_ms -= 1000


# --- the wheel's tap ---

func test_with_no_tap_time_every_press_is_a_hold_and_a_click_wheel_gives_nothing_on_release() -> void:
	controls.wheel_tap = 0.0
	controls.wheel_pick = ControlsConfig.WheelPick.CLICK
	_event(&"fire", true)
	_event(&"order_wheel", true)
	_event(&"order_wheel", false)
	input.fill(pcmd)
	assert_false(pcmd.ping, "nothing is a tap, and Click picks only by a click")
	assert_false(pcmd.fire, "the wheel was up for no time at all, and still took the trigger")
	assert_false(input.wheel().open)


func test_a_key_let_go_unseen_after_the_wheel_came_up_holds_the_trigger_back_until_a_fresh_pull() -> void:
	_event(&"fire", true)
	_event(&"order_wheel", true)
	_hold_past_a_tap()
	input.fill(pcmd)
	assert_false(pcmd.fire, "up: the trigger is the wheel's")
	Input.action_release(&"order_wheel") # no event: a rebind, the window losing the key
	input.fill(pcmd)
	assert_false(input.wheel().open, "closed")
	assert_false(pcmd.ping, "giving nothing")
	assert_false(pcmd.fire, "the trigger still held from the wheel's time")
	Input.action_release(&"fire")
	input.fill(pcmd)
	_event(&"fire", true)
	input.fill(pcmd)
	assert_true(pcmd.fire, "a fresh pull fires")


func test_a_key_let_go_unseen_inside_a_tap_gives_nothing_and_keeps_the_burst() -> void:
	_event(&"fire", true)
	_event(&"order_wheel", true)
	Input.action_release(&"order_wheel")
	input.fill(pcmd)
	assert_false(input.wheel().open)
	assert_false(pcmd.ping, "an unseen release is not a tap")
	assert_true(pcmd.fire, "the trigger was never the wheel's")
	_event(&"order_wheel", true)
	assert_true(input.wheel().open, "and the wheel opens again at the next press")


func test_a_wheel_shut_past_a_tap_holds_the_trigger_back_and_one_shut_inside_it_does_not() -> void:
	_event(&"fire", true)
	_event(&"order_wheel", true)
	_hold_past_a_tap()
	input.fill(pcmd)
	input.allow_orders(true, false) # hit, or the match paused
	input.allow_orders(true, true)
	input.fill(pcmd)
	assert_false(input.wheel().open)
	assert_false(pcmd.fire, "the wheel was up: no shot from the click that was meant for it")
	assert_false(pcmd.ping, "and nothing given")
	Input.action_release(&"fire")
	input.fill(pcmd)
	_event(&"fire", true)
	input.fill(pcmd)
	assert_true(pcmd.fire)


func test_losing_the_window_inside_a_tap_leaves_no_key_and_no_ping_behind() -> void:
	_event(&"fire", true)
	_event(&"order_wheel", true)
	_move(30.0, 10.0)
	input.release()
	assert_false(input.wheel().open)
	Input.action_release(&"order_wheel")
	Input.action_release(&"fire")
	input.active = true
	input.fill(pcmd)
	assert_false(pcmd.ping, "the key came up unseen: no Spotted")
	assert_false(pcmd.fire)
	_event(&"order_wheel", true)
	_event(&"order_wheel", false)
	var yaw := input.view_yaw
	input.fill(pcmd)
	assert_true(pcmd.ping_spot, "the next tap spots")
	assert_almost_eq(input.view_yaw, yaw, 1e-6)


func test_the_motion_of_one_tap_is_not_turned_again_by_the_next() -> void:
	_event(&"order_wheel", true)
	_move(80.0, -20.0)
	_event(&"order_wheel", false)
	var yaw := input.view_yaw
	var pitch := input.view_pitch
	assert_ne(yaw, 0.0)
	_event(&"order_wheel", true)
	_event(&"order_wheel", false)
	assert_almost_eq(input.view_yaw, yaw, 1e-6, "a still tap turns nothing")
	assert_almost_eq(input.view_pitch, pitch, 1e-6)
	_event(&"order_wheel", true)
	_move(10.0, 0.0)
	_hold_past_a_tap()
	_event(&"order_wheel", false)
	_event(&"order_wheel", true)
	_event(&"order_wheel", false)
	assert_almost_eq(input.view_yaw, yaw, 1e-6, "what a hold swallowed does not come back at the next tap")


func test_a_taps_view_catch_up_turns_as_free_motion_does_aimed_inverted_and_zoomed() -> void:
	controls.aim_sensitivity = 0.4
	controls.invert_y = true
	controls.scale_with_zoom = true
	input.zoom = 2.5
	Input.action_press(&"aim")
	_move(90.0, 35.0)
	var free_yaw := input.view_yaw
	var free_pitch := input.view_pitch
	input.face(0.0, 0.0)
	_event(&"order_wheel", true)
	_move(50.0, 20.0)
	_move(40.0, 15.0)
	_event(&"order_wheel", false)
	assert_almost_eq(input.view_yaw, free_yaw, 1e-6)
	assert_almost_eq(input.view_pitch, free_pitch, 1e-6)


func test_a_flick_made_inside_the_tap_still_lands_when_the_key_is_held_on() -> void:
	controls.wheel_pick = ControlsConfig.WheelPick.CLICK
	var layout := OrderWheelLayout.new(controls)
	var at := layout.box(1).get_center() / controls.wheel_gain
	_event(&"order_wheel", true)
	_move(at.x, at.y)
	_hold_past_a_tap()
	assert_eq(input.wheel().pick(), 1)
	_event(&"fire", true)
	input.fill(pcmd)
	assert_ne(pcmd.squad_order, SquadOrder.Kind.NONE, "the click picks the button the flick reached")
	assert_false(pcmd.fire, "and is no shot")
	assert_false(input.wheel().open)


# --- order notices ---

func test_a_follow_whose_every_carrier_is_hit_tells_you_once() -> void:
	_squad()
	cmd.squad_order = SquadOrder.Kind.FOLLOW
	_tick()
	cmd.squad_order = SquadOrder.Kind.NONE
	for m in mates:
		Elimination.eliminate(m.character, NEAR, state.characters, sim.ends)
	var before := bots.order_outcome.serial
	_run(0.1)
	assert_eq(bots.order_outcome.serial, before + 1, "one notice")
	assert_eq(bots.order_outcome.notice, SquadOrders.Notice.CANCELLED)
	_run(1.0)
	assert_eq(bots.order_outcome.serial, before + 1, "and not again")


func test_a_giver_who_is_hit_is_told_nothing_of_the_order_that_ends_with_them() -> void:
	_squad()
	cmd.squad_order = SquadOrder.Kind.COVER
	_tick()
	cmd.squad_order = SquadOrder.Kind.NONE
	var before := bots.order_outcome.serial
	Elimination.eliminate(you, NEAR, state.characters, sim.ends)
	_run(0.2)
	assert_eq(bots.orders.order_of(YOU), SquadOrder.Kind.NONE)
	assert_eq(bots.order_outcome.serial, before, "no notice for a giver who is out")


func test_an_order_replaced_by_another_adds_no_cancelled_notice_when_it_settles() -> void:
	_squad()
	cmd.squad_order = SquadOrder.Kind.FOLLOW
	_tick()
	cmd.squad_order = SquadOrder.Kind.COVER
	_tick()
	cmd.squad_order = SquadOrder.Kind.NONE
	var after := bots.order_outcome.serial
	var last := bots.order_outcome.notice
	_run(0.5)
	assert_eq(bots.orders.order_of(YOU), SquadOrder.Kind.COVER)
	assert_eq(bots.order_outcome.serial, after, "the new order stands: nothing more is said (last: %d)" % last)


# --- the safe start's graphics ---

func test_trying_settings_again_with_odd_saved_graphics_tables_does_not_break() -> void:
	for odd: Variant in [{}, "high", null, 7, {"volumetric_fog": "on"}, {"volumetric_fog": 3}]:
		var s := Settings.new(PlayTuning.new())
		var g := GraphicsGuard.new()
		g.previous = {"graphics_choice": "custom", "graphics_base": "medium", "graphics_custom": odd,
				"renderer": int(Settings.Renderer.AUTO)}
		g.state = GraphicsGuard.State.STARTING
		assert_true(g.asking())
		g.try_again(s)
		assert_false(g.asking(), "answered (%s)" % str(odd))
		assert_eq(s.graphics_choice, GraphicsQuality.CUSTOM)


func test_a_v3_file_still_brings_the_custom_haze_on_over_as_high_and_v4_keeps_it() -> void:
	var fog := GraphicsQuality.VOLUMETRIC_FOG
	var moved := Settings.migrate_defaults({"graphics_custom": {fog: "on"}}, 3)
	assert_eq((moved["graphics_custom"] as Dictionary)[fog], GraphicsQuality.CHOICES[fog][GraphicsQuality.VolumetricFog.HIGH])
	var kept := Settings.migrate_defaults({"graphics_custom": {fog: "on"}}, 4)
	assert_eq((kept["graphics_custom"] as Dictionary)[fog], "on", "a version 4 file's value is its own")


# --- Spotted's arrow ---

func test_a_spotted_arrow_clamps_nothing_odd_at_fraction_ends_and_over_a_respawn_jump() -> void:
	var hud_cfg := HudConfig.new()
	var me := Character.new(0, 0, Vector3(-30.0, 0.0, 20.0), 0.0, ReplicaStats.default_loadout())
	var enemy := Character.new(1, 1, Vector3(-10.0, 0.0, 21.0), 0.0, ReplicaStats.default_loadout())
	enemy.prev_position = Vector3(-10.0, 0.0, 21.0)
	var characters: Array[Character] = [me, enemy]
	var spots := Spots.new(characters, PingConfig.new())
	spots._until[enemy.id] = 10.0
	spots._by[enemy.id] = me.team
	var arrows := HudSpotArrows.new()
	add_child_autofree(arrows)
	arrows.setup(hud_cfg, tuning, characters, me)
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.look_at_from_position(Vector3(-30.0, 1.6, 20.0), Vector3(-10.0, 1.6, 20.0))
	var area := get_viewport().get_visible_rect().size
	arrows.place(camera, spots, 1.0, true, area)
	var rest := arrows.tip(0)
	assert_eq(arrows.count(), 1)
	for fraction: float in [0.0, 1.0]:
		arrows.place(camera, spots, 1.0, true, area, fraction)
		assert_eq(arrows.tip(0), rest, "a figure that stood still stays put at %.0f" % fraction)
	enemy.prev_position = Vector3(-10.0, 0.0, 21.0) + Vector3(300.0, 0.0, 300.0)
	arrows.place(camera, spots, 1.0, true, area, 1.0)
	assert_eq(arrows.tip(0), rest, "at the end of the tick it is where the tick put it, however far it came from")
	arrows.place(camera, spots, 1.0, false, area, 0.5)
	assert_eq(arrows.count(), 0, "none when hidden")
