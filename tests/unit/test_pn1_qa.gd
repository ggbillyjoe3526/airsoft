extends GutTest
## PN1 QA (pings): the ping press next to the order wheel, a free mouse and focus loss, and the bots' sight keeping its
## old reach for every caller that gives none (BotSenses.visible_part).

const DT := 1.0 / 60.0

var input: PlayerInput = null
var controls: ControlsConfig = ControlsConfig.new()


func before_each() -> void:
	controls.wheel_pick = ControlsConfig.WheelPick.HOVER
	input = PlayerInput.new()
	input.setup(controls, 1.5)
	add_child_autofree(input)
	input.active = true


func after_each() -> void:
	Input.action_release(&"order_wheel")
	controls.wheel_tap = ControlsConfig.new().wheel_tap


func _press(action: StringName, pressed: bool = true) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = pressed
	input._unhandled_input(e)


func test_a_middle_click_with_the_wheel_open_is_no_ping_no_order_and_no_shot() -> void:
	# Held past its tap at once: inside the tap the view turns and a ping is taken (BP13, test_bp13_qa.gd).
	controls.wheel_tap = 0.0
	Input.action_press(&"order_wheel")
	_press(&"order_wheel")
	assert_true(input.wheel().open, "the wheel is up")
	_press(&"ping")
	assert_true(input.wheel().open, "a ping press leaves the wheel as it is")
	var c := PlayerCommand.new()
	input.fill(c)
	# Past the tap the wheel holds the view still, so a ping would land where the view was left (KI1).
	assert_false(c.ping, "no ping while the wheel is open")
	assert_eq(c.squad_order, SquadOrder.Kind.NONE, "no order given")
	assert_false(c.fire, "no shot")


func test_a_free_mouse_pings_nothing_and_focus_loss_drops_a_ping_waiting() -> void:
	var c := PlayerCommand.new()
	input.active = false
	_press(&"ping")
	input.active = true
	input.fill(c)
	assert_false(c.ping, "a menu click pings nothing")
	_press(&"ping")
	input.release()
	input.active = true
	input.fill(c)
	assert_false(c.ping, "a press waiting when focus is lost is dropped")


func test_a_release_of_the_ping_button_is_not_a_second_ping() -> void:
	var c := PlayerCommand.new()
	_press(&"ping", true)
	input.fill(c)
	assert_true(c.ping)
	_press(&"ping", false)
	input.fill(c)
	assert_false(c.ping)


func test_visible_part_with_no_reach_is_the_bots_view_distance_as_before() -> void:
	var tuning := SimTuning.load_default()
	var cfg := BotConfig.load_default()
	var level := BoxWorld.new(tuning.body)
	level.add_floor(200.0, 200.0)
	var loadout := ReplicaStats.default_loadout()
	var me := Character.new(0, 0, Vector3.ZERO, -PI * 0.5, loadout)
	var near := Character.new(1, 1, Vector3(cfg.view_distance - 5.0, 0.0, 0.0), 0.0, loadout)
	var far := Character.new(2, 1, Vector3(cfg.view_distance + 20.0, 0.0, 0.0), 0.0, loadout)
	var world := BotWorld.new()
	world.tuning = tuning
	world.cfg = cfg
	world.query = level
	world.characters = [me, near, far]
	assert_gt(BotSenses.visible_part(me, near, world), 0.0, "in view distance")
	assert_eq(BotSenses.visible_part(me, far, world), 0.0, "past the view distance: nothing, as before")
	assert_eq(BotSenses.visible_part(me, far, world, -1.0), 0.0, "-1 is the default")
	assert_gt(BotSenses.visible_part(me, far, world, cfg.view_distance + 30.0), 0.0, "a longer reach sees it")
	assert_eq(BotSenses.visible_part(me, near, world, 5.0), 0.0, "a shorter reach does not")
