extends GutTest
## The full-screen map (FM1): held, its key opens the minimap's field whole and north up over a dimmed screen, for any
## map (Depot and Woodland here, whatever their size); it shows what the minimap shows and never the other team itself
## (DECISIONS › Minimap: hearing only), with the named areas' words; its pointer takes the mouse instead of the view, a
## click there is a Go there to that point of the field and a ping's press a ping there, and fire needs a fresh press
## after. Go there's key and the order wheel's Go There are a Go there ping along the view. A frame allocates nothing.

const ACTIONS: Array[StringName] = [&"field_map", &"order_wheel", &"fire", &"aim", &"ping", &"ping_move",
		&"move_forward"]

var input: PlayerInput = null
var controls: ControlsConfig = ControlsConfig.new()
var cmd: PlayerCommand = PlayerCommand.new()
var cfg: MinimapConfig = null
var teams: TeamConfig = null
var state: GameState = null
var heard: MinimapHearing = null
var you: Character = null
var mate: Character = null
var enemy: Character = null
var depot: MapData = null
var woodland: MapData = null


func before_all() -> void:
	depot = MapData.load_map("depot", MapStyle.new(), 1)
	woodland = MapData.load_map("woodland", MapStyle.new(), 1)


func before_each() -> void:
	controls.wheel_pick = ControlsConfig.WheelPick.HOVER
	input = PlayerInput.new()
	input.setup(controls, 1.5)
	add_child_autofree(input)
	input.active = true
	input.allow_map(true)
	cfg = MinimapConfig.new()
	teams = TeamConfig.new()
	state = GameState.new(5)
	var kit: Array[ReplicaConfig] = [ReplicaConfig.new()]
	you = Character.new(0, 0, Vector3(-10.0, 0.0, 1.5), 0.0, kit)
	mate = Character.new(1, 0, Vector3(-3.5, 0.0, -3.5), 0.0, kit)
	enemy = Character.new(2, 1, Vector3(3.0, 0.0, -4.0), 0.0, kit)
	var everyone: Array[Character] = [you, mate, enemy]
	for c in everyone:
		state.characters.append(c)
		c.prev_position = c.position
	heard = MinimapHearing.new(cfg)
	heard.on_tick(state, you)


func after_each() -> void:
	for action: StringName in ACTIONS:
		Input.action_release(action)


func _event(action: StringName, pressed: bool) -> void:
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)
	var e := InputEventAction.new()
	e.action = action
	e.pressed = pressed
	input._unhandled_input(e)


func _tap(action: StringName) -> void:
	_event(action, true)
	_event(action, false)


func _move(dx: float, dy: float) -> void:
	var e := InputEventMouseMotion.new()
	e.screen_relative = Vector2(dx, dy)
	input._unhandled_input(e)


## The map built over a minimap of `map`, in a 1920 × 1080 HUD.
func _field_map(map: MapData) -> HudFieldMap:
	var root := Control.new()
	root.size = Vector2(1920.0, 1080.0)
	add_child_autofree(root)
	var mm := HudMinimap.new()
	root.add_child(mm)
	mm.setup(cfg, teams, map, heard, "Depot", state.characters.size(), Vector2(32.0, 26.0))
	var fm := HudFieldMap.new()
	root.add_child(fm)
	fm.setup(cfg, mm, map, "Depot", state.characters.size(), 8.0, 2.0)
	return fm


func _show(fm: HudFieldMap, pointing: bool = true, covered: bool = false) -> void:
	fm.update(state, you, 0.0, 1.0, false, Vector3.ZERO, null, input.field_map(), pointing, covered)


# --- the pointer ---

func test_the_pointer_opens_on_you_stays_on_the_square_and_reads_the_field_under_it() -> void:
	var p := MapPointer.new()
	p.frame(Vector2(10.0, -20.0), 4.0, 400.0, 3.5, Vector2(40.0, -8.0))
	p.start()
	assert_true(p.open)
	assert_eq(p.at, Vector2(40.0, -8.0), "on you")
	assert_eq(p.world(), Vector3(20.0, 3.5, -22.0), "x right, z down, the floor shown")
	p.move(Vector2(1000.0, -1000.0))
	assert_eq(p.at, Vector2(400.0, -400.0), "kept on the square")
	p.close()
	assert_false(p.open)


# --- the input ---

func test_held_the_map_takes_the_mouse_and_letting_go_closes_it() -> void:
	input.field_map().frame(Vector2.ZERO, 2.0, 400.0, 0.0, Vector2.ZERO)
	Input.action_press(&"move_forward")
	_event(&"field_map", true)
	assert_true(input.field_map().open)
	_move(50.0, 20.0)
	assert_almost_eq(input.view_yaw, 0.0, 1e-6, "the view stays put")
	assert_eq(input.field_map().at, Vector2(50.0, 20.0) * controls.map_gain * controls.sensitivity)
	input.fill(cmd)
	assert_eq(cmd.forward, 1.0, "feet still move")
	assert_false(cmd.fire)
	_event(&"field_map", false)
	assert_false(input.field_map().open)
	_move(50.0, 0.0)
	assert_lt(input.view_yaw, 0.0, "closed, the mouse turns the view again")


func test_a_click_on_the_map_is_a_go_there_and_the_pings_press_a_ping_there() -> void:
	input.field_map().frame(Vector2(5.0, 5.0), 2.0, 400.0, 0.0, Vector2.ZERO)
	_event(&"field_map", true)
	_move(20.0, -40.0)
	_tap(&"fire")
	input.fill(cmd)
	assert_true(cmd.ping and cmd.ping_move and cmd.ping_on_map)
	assert_eq(cmd.ping_target, Vector3(15.0, 0.0, -15.0))
	assert_false(cmd.fire, "the click is no shot")
	input.fill(cmd)
	assert_false(cmd.ping, "once")
	_tap(&"ping")
	input.fill(cmd)
	assert_true(cmd.ping and cmd.ping_on_map)
	assert_false(cmd.ping_move, "a plain ping")
	_event(&"field_map", false)
	Input.action_press(&"fire")
	input.fill(cmd)
	assert_false(cmd.fire, "fire needs a fresh press once it closes")


func test_no_map_to_open_on_the_range_and_no_ping_on_it_while_you_are_out() -> void:
	input.allow_map(false)
	_event(&"field_map", true)
	assert_false(input.field_map().open)
	_event(&"field_map", false)
	input.allow_map(true)
	input.allow_orders(true, false)
	_event(&"field_map", true)
	assert_true(input.field_map().open, "out, you can still look")
	_tap(&"fire")
	input.fill(cmd)
	assert_false(cmd.ping, "but not ping")
	assert_false(input.orders_allowed())


func test_the_map_and_the_order_wheel_never_open_together() -> void:
	_event(&"field_map", true)
	_event(&"order_wheel", true)
	assert_false(input.wheel().open)
	_event(&"order_wheel", false)
	_event(&"field_map", false)
	_event(&"order_wheel", true)
	_event(&"field_map", true)
	assert_false(input.field_map().open)


func test_go_theres_key_and_the_wheels_go_there_ping_along_the_view() -> void:
	_tap(&"ping_move")
	input.fill(cmd)
	assert_true(cmd.ping and cmd.ping_move)
	assert_false(cmd.ping_on_map)
	assert_eq(cmd.squad_order, SquadOrder.Kind.NONE, "a ping, not an order")
	var slot := controls.wheel_orders.find(SquadOrder.Kind.MOVE)
	assert_gt(slot, -1, "Go There is on the wheel")
	assert_eq(controls.wheel_keys[slot], &"ping_move")
	assert_eq(controls.wheel_labels[slot], "ORDER_MOVE")
	_event(&"order_wheel", true)
	var angle := TAU * slot / controls.wheel_orders.size()
	_move(sin(angle) * 150.0, -cos(angle) * 150.0)
	_event(&"order_wheel", false)
	input.fill(cmd)
	assert_true(cmd.ping and cmd.ping_move, "picked on the wheel")


func test_the_keys_have_defaults_in_the_settings_list_and_the_input_map() -> void:
	assert_true(KeyBindings.ACTIONS.has(&"field_map"))
	assert_true(KeyBindings.ACTIONS.has(&"ping_move"))
	assert_eq(KeyBindings.DEFAULTS[&"field_map"], [KEY_M])
	assert_eq(KeyBindings.DEFAULTS[&"ping_move"], [-MOUSE_BUTTON_XBUTTON1])
	assert_true(InputMap.has_action(&"field_map"))
	assert_true(InputMap.has_action(&"ping_move"))
	assert_ne(tr("ACT_FIELD_MAP"), "ACT_FIELD_MAP")
	assert_ne(tr("ACT_PING_MOVE"), "ACT_PING_MOVE")
	assert_eq(tr("ORDER_MOVE"), "Go There")


# --- the map on screen ---

func test_any_map_fits_whole_in_the_square_north_up() -> void:
	for map: MapData in [depot, woodland]:
		var fm := _field_map(map)
		input.field_map().start()
		_show(fm)
		var v := fm.view()
		assert_true(fm.visible)
		assert_eq(v.size.x, v.size.y, "a square")
		assert_almost_eq(v.size.y, 1080.0 - cfg.map_margin * 2.0, 0.5, "as big as the screen allows")
		var world := v.field_size()
		assert_gt(world.x, 0.0)
		var span := world * v.px_per_m()
		assert_almost_eq(maxf(span.x, span.y), v.size.x * cfg.map_fit, 0.5, "the field fills map_fit of it")
		# The field's corners are on the square.
		var origin := v.centre() - world * 0.5
		for corner: Vector2 in [origin, origin + world]:
			var p := v.panel_of(corner)
			assert_lt(maxf(absf(p.x), absf(p.y)), v.size.x * 0.5 + 0.5)
		input.field_map().close()


func test_it_frames_the_pointer_on_the_square_and_on_you() -> void:
	var fm := _field_map(depot)
	input.field_map().start()
	_show(fm)
	var p := input.field_map()
	var v := fm.view()
	assert_eq(p.half, v.size.x * 0.5)
	assert_almost_eq(p.ppm, v.px_per_m(), 1e-5)
	assert_eq(p.you, v.panel_of(Vector2(you.position.x, you.position.z)))
	p.at = p.you
	var at := p.world()
	assert_almost_eq(at.x, you.position.x, 1e-3, "the pointer on you reads where you stand")
	assert_almost_eq(at.z, you.position.z, 1e-3)


func test_it_shows_what_the_minimap_shows_and_never_the_other_team() -> void:
	var fm := _field_map(depot)
	input.field_map().start()
	_show(fm)
	var v := fm.view()
	assert_eq(v._dot_count, 1, "your teammate, not the enemy")
	assert_eq(v._patch_count, 0, "nothing heard yet")
	var patch := heard.patch_of(enemy.id)
	patch.live = true
	patch.centre = enemy.position
	patch.radius = 3.0
	patch.heard_at = heard.time
	_show(fm)
	assert_eq(v._patch_count, 1, "only where your side heard them")
	assert_eq(v._dot_count, 1)


func test_it_names_the_areas_and_hides_while_shut_or_under_the_scoreboard() -> void:
	var fm := _field_map(depot)
	_show(fm)
	assert_false(fm.visible, "shut")
	input.field_map().start()
	_show(fm)
	assert_true(fm.visible)
	var names := fm.area_words()
	assert_gt(names.size(), 0)
	for a in depot.areas:
		if a.floor_from <= 0.0:
			assert_true(names.has(a.name.to_upper()), a.name)
	_show(fm, true, true)
	assert_false(fm.visible, "never over the scoreboard or the summary")


func test_the_areas_words_are_one_a_name_over_its_biggest_box() -> void:
	var small := MapAreas.Area.new()
	small.name = "Yard"
	small.x0 = 0.0
	small.x1 = 2.0
	small.z0 = 0.0
	small.z1 = 2.0
	var big := MapAreas.Area.new()
	big.name = "Yard"
	big.x0 = 10.0
	big.x1 = 20.0
	big.z0 = 10.0
	big.z1 = 30.0
	var other := MapAreas.Area.new()
	other.name = "Dock"
	other.x1 = 1.0
	other.z1 = 1.0
	var list: Array[MapAreas.Area] = [small, big, other]
	var words := HudFieldMap.areas_of(list)
	assert_eq(words.size(), 2)
	assert_eq(words[0].name, "YARD")
	assert_eq(words[0].at, Vector2(15.0, 20.0))


func test_go_theres_marker_reads_go_until_they_are_there() -> void:
	var marker := HudHoldMarker.new()
	add_child_autofree(marker)
	marker.setup(HudConfig.new(), Color.WHITE)
	var camera := Camera3D.new()
	add_child_autofree(camera)
	marker.set_going(true)
	marker.place(camera, Vector3(0.0, 0.0, -18.0), true, Vector2(1920.0, 1080.0), Rect2())
	assert_eq(marker.text(), "GO · 18 M")
	marker.set_going(false)
	marker.place(camera, Vector3(0.0, 0.0, -18.0), true, Vector2(1920.0, 1080.0), Rect2())
	assert_eq(marker.text(), "HOLD · 18 M")


func test_a_frame_of_the_open_map_allocates_nothing() -> void:
	var fm := _field_map(woodland)
	input.field_map().start()
	for i in 5:
		_show(fm)
	var before := Performance.get_monitor(Performance.OBJECT_COUNT)
	for i in 100:
		input.field_map().move(Vector2(1.0, 0.5))
		_show(fm)
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), before)


func test_go_theres_key_on_the_open_map_sends_them_to_the_pointer_not_the_hidden_view() -> void:
	input.field_map().frame(Vector2.ZERO, 2.0, 400.0, 0.0, Vector2.ZERO)
	_event(&"field_map", true)
	_move(40.0, 0.0)
	_tap(&"ping_move")
	input.fill(cmd)
	assert_true(cmd.ping and cmd.ping_move and cmd.ping_on_map)
	assert_eq(cmd.ping_target, Vector3(20.0, 0.0, 0.0))
