extends GutTest
## The Variable Scope (SN2; owner, 2026-11-02: the 2x Scope, but variable zoom and a little longer; public since
## 2026-11-05): an optic for the top rail that zooms 2× to 6× in its glass, turned 1× a notch by the mouse wheel while
## aimed through it (up zooms in), kept where it is left for the match, slower to raise than the 2x Scope, unlocked at
## level 8, and drawn from the 2x Scope's model run on longer with a zoom ring.

const DT := 1.0 / 60.0
const EYE := Vector3(0.0, 1.6, 0.0)
const AEG := "000002"
const SNIPER := "000021"
const SCOPE := "000010"
const VARIABLE := "000025"

var rules: LoadoutRules


func before_each() -> void:
	rules = LoadoutRules.new(Pool.read_file(), ReplicaStats.read_file(), ReplicaRulesConfig.new())
	rules.dev_content = true


## The AEG as carried with `optic` on its top rail.
func _aeg_with(optic: String) -> ReplicaConfig:
	var l := rules.default_loadout("L")
	assert_true(rules.set_part(l, AEG, &"optic", optic), "fitted")
	return rules.carried(l).replicas[0]


func _character(r: ReplicaConfig) -> Character:
	return Character.new(1, 0, Vector3.ZERO, 0.0, [r] as Array[ReplicaConfig])


## One tick of `c`'s armament with `cmd`; the ZOOM events it made.
func _zoom_events(c: Character, cmd: PlayerCommand, aimed: bool = true) -> Array[GameEvent]:
	c.aiming = aimed
	var events := SimEvents.new()
	Armament.step(c, cmd, EYE, 1.0, true, BBPool.new(4), Seeds.stream(3), events, SimTuning.new(), DT)
	var out: Array[GameEvent] = []
	for k in events.count:
		if events.items[k].kind == GameEvent.Kind.ZOOM:
			out.append(events.items[k])
	return out


func test_it_is_a_public_top_rail_optic_that_fits_both_rifles() -> void:
	var it := rules.pool.item(VARIABLE)
	assert_not_null(it)
	assert_eq(it.display_name, "Variable Scope")
	assert_eq(it.key, &"scopeVar")
	assert_eq(it.slot, &"optic")
	assert_false(it.is_dev(), "public (owner, 2026-11-05)")
	assert_true(rules.set_part(rules.default_loadout("L"), AEG, &"optic", VARIABLE), "the AEG Rifle")
	var l := rules.default_loadout("L")
	assert_true(rules.equip(l, Loadout.Slot.PRIMARY, SNIPER))
	assert_true(rules.set_part(l, SNIPER, &"optic", VARIABLE), "swapped for the Sniper Rifle's 2x Scope")
	rules.dev_content = false
	assert_true(rules.set_part(rules.default_loadout("L"), AEG, &"optic", VARIABLE), "and with Dev content off")


func test_it_zooms_2x_to_6x_in_its_glass_and_raises_slower_than_the_2x_scope() -> void:
	var v := _aeg_with(VARIABLE)
	assert_eq(v.aim_zoom, 2.0)
	assert_eq(v.aim_zoom_to, 6.0)
	assert_true(v.zoom_in_glass, "only its glass zooms")
	var fixed := _aeg_with(SCOPE)
	assert_eq(fixed.aim_zoom, 2.0)
	assert_eq(fixed.aim_zoom_to, 0.0, "the 2x Scope is fixed")
	assert_gt(v.raise_scale, fixed.raise_scale, "longer and heavier: slower to the eye")
	var part := rules.stats.parts.part(&"optic", &"scopeVar")
	assert_almost_eq(part.raise, 2.0, 0.001)
	assert_eq(rules.stats.parts.part(&"optic", &"redDot").zoom_to, 1.25, "the Red Dot reads as fixed")


func test_the_wheel_turns_it_a_notch_at_a_time_between_its_ends() -> void:
	var c := _character(_aeg_with(VARIABLE))
	var a := c.armament
	assert_eq(a.zoom_now(), 2.0, "starts at its lowest")
	assert_true(a.zoom_turns())
	var cmd := PlayerCommand.new()
	cmd.zoom_steps = 1
	var e := _zoom_events(c, cmd)
	assert_eq(a.zoom_now(), 3.0)
	assert_eq(e.size(), 1)
	assert_eq(e[0].value, 300, "the readout's zoom")
	assert_eq(e[0].value2, 1, "it moved")
	cmd.zoom_steps = 10
	_zoom_events(c, cmd)
	assert_eq(a.zoom_now(), 6.0, "no further than 6x")
	e = _zoom_events(c, cmd)
	assert_eq(e[0].value2, 0, "already at its end: the click, no change")
	cmd.zoom_steps = -2
	_zoom_events(c, cmd)
	assert_eq(a.zoom_now(), 4.0)
	cmd.zoom_steps = -10
	_zoom_events(c, cmd)
	assert_eq(a.zoom_now(), 2.0, "no lower than 2x")


func test_its_zoom_is_kept_through_rounds_and_reset_for_a_new_match() -> void:
	var c := _character(_aeg_with(VARIABLE))
	var cmd := PlayerCommand.new()
	cmd.zoom_steps = 2
	_zoom_events(c, cmd)
	c.armament.refill()
	assert_eq(c.armament.zoom_now(), 4.0, "a new round keeps it")
	c.armament.reset_zooms()
	assert_eq(c.armament.zoom_now(), 2.0, "a new match starts it at 2x")


func test_with_the_sight_down_mid_reload_the_wheel_switches_and_never_turns_it() -> void:
	var c := _character(_aeg_with(VARIABLE))
	var cmd := PlayerCommand.new()
	cmd.zoom_steps = 1
	assert_eq(_zoom_events(c, cmd, false).size(), 0, "not aimed (lowered for a reload): no turn")
	assert_eq(c.armament.zoom_now(), 2.0)
	# Aim held through a reload: Aiming lowers the sight, so the play session passes the wheel on as a switch.
	c.armament.reload_left = 1.0
	var aim := PlayerCommand.new()
	aim.aim = true
	Aiming.step(c, aim, SimTuning.new().movement, DT)
	assert_false(c.aiming, "the sight is down mid-reload")
	var input := PlayerInput.new()
	add_child_autofree(input)
	input.setup(ControlsConfig.new(), 1.5)
	input.active = true
	Input.action_press(PlayerInput.AIM)
	_notch(input, MOUSE_BUTTON_WHEEL_DOWN)
	var out := PlayerCommand.new()
	input.fill(out, 0, null, false, c.aiming and c.armament.zoom_turns())
	Input.action_release(PlayerInput.AIM)
	assert_eq(out.zoom_steps, 0)
	assert_eq(out.switch_to, 1, "to the sidearm, as with any sight")
	input.active = false


func test_a_fixed_optic_or_none_never_turns() -> void:
	for optic: String in [SCOPE, "000007", ""]:
		var c := _character(_aeg_with(optic))
		assert_false(c.armament.zoom_turns(), optic)
		var before := c.armament.zoom_now()
		var cmd := PlayerCommand.new()
		cmd.zoom_steps = 1
		assert_eq(_zoom_events(c, cmd).size(), 0, "%s: no ZOOM" % optic)
		assert_eq(c.armament.zoom_now(), before)
	var holstered := _character(_aeg_with(VARIABLE))
	holstered.armament.holstered = true
	assert_false(holstered.armament.zoom_turns(), "nothing to look through holstered")


func test_aimed_the_mouse_wheel_zooms_instead_of_switching() -> void:
	var input := PlayerInput.new()
	add_child_autofree(input)
	input.setup(ControlsConfig.new(), 1.5)
	input.active = true
	var cmd := PlayerCommand.new()
	Input.action_press(PlayerInput.AIM)
	_notch(input, MOUSE_BUTTON_WHEEL_UP)
	input.fill(cmd, 0, null, false, true)
	assert_eq(cmd.zoom_steps, 1, "up zooms in")
	assert_eq(cmd.switch_to, -1, "no switch")
	_notch(input, MOUSE_BUTTON_WHEEL_DOWN)
	_notch(input, MOUSE_BUTTON_WHEEL_DOWN)
	input.fill(cmd, 0, null, false, true)
	assert_eq(cmd.zoom_steps, -2, "down zooms out")
	input.fill(cmd, 0, null, false, true)
	assert_eq(cmd.zoom_steps, 0, "a notch is turned once")
	_notch(input, MOUSE_BUTTON_WHEEL_DOWN)
	input.fill(cmd, 0, null, false, false)
	assert_eq(cmd.zoom_steps, 0, "a fixed optic: the wheel switches")
	assert_eq(cmd.switch_to, 1)
	Input.action_release(PlayerInput.AIM)
	_notch(input, MOUSE_BUTTON_WHEEL_DOWN)
	input.fill(cmd, 0, null, false, true)
	assert_eq(cmd.zoom_steps, 0, "from the hip the wheel switches")
	assert_eq(cmd.switch_to, 1)
	input.active = false


## Zoom in and Zoom out are actions of their own (BP6): Next and Previous replica moved to keys switch while aimed and the
## wheel still zooms; the wheel moved off the zooms switches, aimed or not, and the zoom keys zoom.
func test_the_zoom_keys_are_their_own_and_the_switch_keys_switch_while_aimed() -> void:
	var b := KeyBindings.new()
	b.rebind(&"slot_next", KEY_K)
	b.rebind(&"slot_previous", KEY_J)
	b.apply()
	var input := PlayerInput.new()
	add_child_autofree(input)
	input.setup(ControlsConfig.new(), 1.5)
	input.active = true
	var cmd := PlayerCommand.new()
	Input.action_press(PlayerInput.AIM)
	_key(input, KEY_K)
	input.fill(cmd, 0, null, false, true)
	assert_eq(cmd.zoom_steps, 0, "a switch key never zooms")
	assert_eq(cmd.switch_to, 1, "it switches, aimed or not")
	_notch(input, MOUSE_BUTTON_WHEEL_UP)
	input.fill(cmd, 0, null, false, true)
	assert_eq(cmd.zoom_steps, 1, "the wheel still zooms in")
	assert_eq(cmd.switch_to, -1)
	_notch(input, MOUSE_BUTTON_WHEEL_UP)
	input.fill(cmd, 0, null, false, false)
	assert_eq(cmd.zoom_steps, 0, "no variable optic: a zoom key does nothing")
	assert_eq(cmd.switch_to, -1, "and the wheel, off the switches, switches nothing")
	b.reset()
	b.rebind(&"zoom_in", KEY_I)
	b.rebind(&"zoom_out", KEY_O)
	b.apply()
	_notch(input, MOUSE_BUTTON_WHEEL_DOWN)
	input.fill(cmd, 0, null, false, true)
	assert_eq(cmd.zoom_steps, 0, "the wheel off the zooms switches, aimed through it")
	assert_eq(cmd.switch_to, 1)
	_key(input, KEY_I)
	_key(input, KEY_I)
	_key(input, KEY_O)
	input.fill(cmd, 0, null, false, true)
	assert_eq(cmd.zoom_steps, 1, "its own keys zoom")
	Input.action_release(PlayerInput.AIM)
	input.active = false
	InputMap.load_from_project_settings()


func test_a_notch_on_the_tick_after_a_reload_or_a_draw_starts_switches() -> void:
	var c := _character(_aeg_with(VARIABLE))
	c.aiming = true # the sight was up last tick
	assert_true(Aiming.can_aim(c))
	c.armament.reload_left = 1.0
	assert_false(Aiming.can_aim(c), "a reload under way lowers it this tick")
	c.armament.reload_left = 0.0
	c.armament.draw_left = 0.5
	assert_false(Aiming.can_aim(c), "as a draw does")
	assert_false(Aiming.zoom_turns(c))
	c.armament.draw_left = 0.0
	assert_true(Aiming.zoom_turns(c), "the variable optic in hand, ready")
	c.grenades.readied = Grenade.Kind.SMOKE
	assert_false(Aiming.zoom_turns(c), "not with a bomb in hand")
	c.grenades.readied = Grenade.Kind.NONE
	c.grenades.throwing = Grenade.Kind.FLASH
	assert_false(Aiming.zoom_turns(c), "nor while throwing one")
	c.grenades.throwing = Grenade.Kind.NONE
	assert_false(Aiming.zoom_turns(_character(_aeg_with(SCOPE))), "a fixed scope: never")
	c.armament.draw_left = 0.5
	var input := PlayerInput.new()
	add_child_autofree(input)
	input.setup(ControlsConfig.new(), 1.5)
	input.active = true
	Input.action_press(PlayerInput.AIM)
	_notch(input, MOUSE_BUTTON_WHEEL_DOWN)
	var cmd := PlayerCommand.new()
	input.fill(cmd, 0, null, false, Aiming.zoom_turns(c))
	Input.action_release(PlayerInput.AIM)
	assert_eq(cmd.zoom_steps, 0)
	assert_eq(cmd.switch_to, 1, "not lost: it switches")
	input.active = false


func test_a_turn_made_mid_vault_is_kept_and_a_bomb_in_hand_drops_it() -> void:
	var c := _character(_aeg_with(VARIABLE))
	var cmd := PlayerCommand.new()
	cmd.zoom_steps = 2
	Vault.vaulting_command(c, cmd, PlayerCommand.new())
	var after := Vault.with_held_presses(c.vault, PlayerCommand.new(), PlayerCommand.new())
	assert_eq(after.zoom_steps, 2, "played into the first command after the vault")
	assert_eq(c.vault.held_zoom_steps, 0)
	assert_eq(Grenades.throwing_command(cmd, PlayerCommand.new()).zoom_steps, 0, "not with a bomb in hand")
	var copy := PlayerCommand.new()
	copy.copy_from(cmd)
	assert_eq(copy.zoom_steps, 2)
	copy.reset()
	assert_eq(copy.zoom_steps, 0)


func test_it_unlocks_at_level_10() -> void:
	var table := LevelTable.read_file(rules.pool)
	assert_eq(table.unlock_level(VARIABLE), 10, "with the Compact SMG (LV15)")


func test_both_rifles_parts_files_carry_it_longer_than_the_2x_scope() -> void:
	# The owner's photos (BL8): a compact prism scope, longer than the 2x magnifier, within a part's budget.
	for file: String in ["aeg", "sniper"]:
		var parts := (load("res://assets/models/replicaParts/%s.glb" % file) as PackedScene).instantiate()
		add_child_autofree(parts)
		var v := parts.find_child("optic_scopeVar", true, false) as MeshInstance3D
		var fixed := parts.find_child("optic_scope2x", true, false) as MeshInstance3D
		assert_not_null(v, file)
		assert_not_null(fixed, file)
		if v == null or fixed == null:
			continue
		assert_not_null(v.find_child("optic_scopeVar_Figure", true, false), "%s: its figure version" % file)
		assert_not_null(v.find_child("optic_scopeVar_SightLine", true, false), "%s: its sight line" % file)
		assert_gt(v.get_aabb().size.z, fixed.get_aabb().size.z + 0.05, "%s: longer than the 2x Scope" % file)
		assert_lt(v.mesh.get_faces().size() / 3, 10000, "%s: within a part's 10,000 triangles" % file)


func _key(input: PlayerInput, key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	input._unhandled_input(event)


func _notch(input: PlayerInput, button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	input._unhandled_input(event)
