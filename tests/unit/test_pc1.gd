extends GutTest
## PC1 (owner's playtest, 2026-11-22): the sprint key held while moving forward always runs, winning over walk, a held
## or toggled crouch (and AltGr's Ctrl), a held or toggled sight and a lean; the HIT! sign is red for both teams.

var input: PlayerInput = null
var controls: ControlsConfig = null
var cmd: PlayerCommand = PlayerCommand.new()


## A flat floor at y = 0.
class Flat:
	extends CharacterMover

	func move(c: Character, d: Vector3) -> Vector3:
		var out := d
		if c.position.y + d.y <= 0.0:
			out.y = -c.position.y
		return out

	func probe_ground(c: Character, max_drop: float) -> float:
		return -c.position.y if c.position.y <= max_drop else NAN


func before_each() -> void:
	controls = ControlsConfig.new()
	input = PlayerInput.new()
	input.setup(controls, 1.5)
	add_child_autofree(input)
	input.active = true


func after_each() -> void:
	for action: StringName in [&"move_forward", &"move_back", &"move_left", &"walk", &"crouch", &"sprint", &"aim",
			&"lean_left", &"lean_right"]:
		Input.action_release(action)


func _press(action: StringName) -> void:
	Input.action_press(action)
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	input._unhandled_input(e)


func test_sprint_held_going_forward_wins_over_walk_crouch_aim_and_lean() -> void:
	for held: StringName in [&"walk", &"crouch", &"aim", &"lean_left", &"lean_right"]:
		Input.action_press(&"move_forward")
		Input.action_press(held)
		Input.action_press(&"sprint")
		input.fill(cmd)
		assert_true(cmd.sprint, held)
		assert_false(cmd.walk or cmd.crouch or cmd.aim, "%s held: let go for the sprint" % held)
		assert_eq(cmd.lean, 0.0, "%s held: no lean" % held)
		Input.action_release(&"sprint")
		input.fill(cmd)
		assert_true(cmd.walk or cmd.crouch or cmd.aim or cmd.lean != 0.0, "%s: back once the sprint is let go" % held)
		Input.action_release(held)


func test_sprint_lets_go_of_a_toggled_crouch_and_sight() -> void:
	controls.crouch_toggle = true
	controls.aim_toggle = true
	Input.action_press(&"move_forward")
	_press(&"crouch")
	_press(&"aim")
	input.fill(cmd)
	assert_true(cmd.crouch and cmd.aim, "toggled down and up")
	Input.action_press(&"sprint")
	input.fill(cmd)
	assert_false(cmd.crouch or cmd.aim)
	Input.action_release(&"sprint")
	input.fill(cmd)
	assert_false(cmd.crouch or cmd.aim, "the toggles were let go: you run on standing, sight down")


func test_sprint_held_standing_still_or_going_back_leaves_the_rest_alone() -> void:
	Input.action_press(&"sprint")
	Input.action_press(&"aim")
	input.fill(cmd)
	assert_true(cmd.aim, "standing still: the sight stays up")
	Input.action_press(&"move_back")
	Input.action_press(&"walk")
	input.fill(cmd)
	assert_true(cmd.aim and cmd.walk, "going back: no sprint, nothing let go")


func test_the_sprint_command_runs_through_a_held_walk_and_crouch_in_the_movement() -> void:
	var c := Character.new(0, 0, Vector3.ZERO, 0.0)
	c.grounded = true
	Input.action_press(&"move_forward")
	Input.action_press(&"walk")
	Input.action_press(&"crouch")
	Input.action_press(&"sprint")
	var mover := Flat.new()
	for i in 60:
		input.fill(cmd)
		Movement.step(c, cmd, MovementConfig.new(), AccuracyConfig.new(), 1.0 / 60.0, mover)
	assert_true(c.sprinting, "a second on, sprinting")
	assert_false(c.walking)


func test_the_hit_sign_is_red_for_both_teams() -> void:
	var sign := FigureView.make_sign(ThemeDB.fallback_font)
	autofree(sign)
	assert_eq(sign.modulate, FigureView.SIGN_COLOUR)
	assert_eq(sign.outline_modulate, FigureView.SIGN_COLOUR.darkened(FigureView.SIGN_OUTLINE_DARKEN))
	assert_gt(FigureView.SIGN_COLOUR.r, 0.9, "red")
	assert_lt(maxf(FigureView.SIGN_COLOUR.g, FigureView.SIGN_COLOUR.b), 0.3, "and only red")
