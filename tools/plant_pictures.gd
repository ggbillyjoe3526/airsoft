extends SceneTree
## Pictures of Plant The Bomb for review (PB1): a whole PlaySession on a field, the bots standing at their starts, the
## bomb's state set by hand. First person with the HUD, as an attacker (the bomb on the ground at the start, carrying
## it in Site A, keying it in, the armed bomb) and as a defender (at the armed bomb, the kit at work); then the HUD
## off and the camera free: the bomb (PB2's model) armed close up, the wire cutters laid open beside it, a bot carrying
## it strapped at the hip (standing and crouched), and each site's ring and letter. Needs a
## display, so under xvfb:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 \
##       -s res://tools/plant_pictures.gd -- <folder> [map id] [--graphics=high]
## Dev only: tools/ never ships.

const SIZE := Vector2i(1600, 900)
const EYE := 1.62
## Frames drawn before each picture (the light and the HUD settling), the play stopped meanwhile (PlaySession.speed 0)
## so what is posed stays posed however slowly the frames come.
const SETTLE := 40
## The most frames a step of the play is waited for.
const PATIENCE := 1200

var _session: PlaySession = null
var _folder := ""
var _count := 0


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _grab(name: String) -> void:
	_session.speed = 0
	await _frames(SETTLE)
	await RenderingServer.frame_post_draw
	_count += 1
	root.get_texture().get_image().save_png("%s/%02d-%s.png" % [_folder, _count, name])
	_session.speed = 1


## Plays on until `done` says so (or PATIENCE frames have passed).
func _until(done: Callable) -> void:
	var waited := 0
	while not done.call() and waited < PATIENCE:
		await process_frame
		waited += 1
	if waited >= PATIENCE:
		push_warning("plant_pictures: a step never came (picture %d next)" % (_count + 1))


## The player at `at`, looking at `target`.
func _stand(at: Vector3, target: Vector3) -> void:
	var c := _session.player
	c.position = at
	c.prev_position = at
	c.velocity = Vector3.ZERO
	var d := target - (at + Vector3.UP * EYE)
	_session._input.view_yaw = atan2(-d.x, -d.z)
	_session._input.view_pitch = atan2(d.y, Vector2(d.x, d.z).length())


## A spot `back` m from `p` towards `from`, on `p`'s floor.
static func _towards(p: Vector3, from: Vector3, back: float) -> Vector3:
	var way := Vector3(from.x - p.x, 0.0, from.z - p.z).normalized()
	return p + way * back


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_folder = args[0] if not args.is_empty() else "user://plant"
	DirAccess.make_dir_recursive_absolute(_folder)
	root.size = SIZE
	_session = PlaySession.new()
	_session.settings = Settings.new(PlayTuning.new())
	_session.settings.graphics_forced = GraphicsPick.forced(args)
	_session.map_id = args[1] if args.size() > 1 and not args[1].begins_with("--") else "depot"
	_session.mode = MatchOptions.MODE_PLANT_THE_BOMB
	_session.player_team = 0
	_session.bots_active = false
	_session.match_seed = 3
	root.add_child(_session)
	if _session.state == null or _session.plant_view() == null:
		push_error("plant_pictures: %s does not host the mode" % _session.map_id)
		quit(1)
		return
	await _frames(4)
	var st := _session.state
	var rs := st.round_state
	var ps := rs.plant
	var cfg := _session._tuning.plant
	var you := _session.player
	var start := ps.position
	await _until(func() -> bool: return rs.is_live())
	# 1. An attacker at the start: the bomb on the ground ahead, the prompt to take it.
	_stand(_towards(start, you.position, 1.3), start + Vector3.UP * 0.1)
	await _grab("first-person-attacker-bomb-on-the-ground-at-the-start")
	# 2. Carrying it into Site A: the ring, the letter and the prompt to plant.
	var site := ps.sites[0]
	Input.action_press(PlayerInput.USE_DOOR)
	await _until(func() -> bool: return ps.status == PlantState.Status.CARRIED)
	Input.action_release(PlayerInput.USE_DOOR)
	var edge := _towards(site, start, ps.radii[0] + 3.0)
	_stand(edge, site + Vector3.UP * 1.0)
	await _grab("first-person-attacker-carrying-the-bomb-to-site-A")
	# 3. Keying it in, half way: the gauge, the replica lowered.
	var spot := _towards(site, start, 1.0)
	_stand(spot, spot + (site - spot).normalized() * 0.9 + Vector3.UP * 0.1)
	Input.action_press(PlayerInput.USE_DOOR)
	await _until(func() -> bool: return ps.planting >= 0.5 or ps.planted())
	await _grab("first-person-attacker-planting-half-way")
	# 4. Armed: seen from a few metres back, the fuse on the clock.
	await _until(func() -> bool: return ps.planted())
	Input.action_release(PlayerInput.USE_DOOR)
	ps.fuse_left = cfg.fuse_time
	var bomb := ps.position
	_stand(_towards(bomb, start, 3.5), bomb + Vector3.UP * 0.1)
	await _grab("first-person-attacker-the-armed-bomb-at-site-A")
	# 5. A defender at the armed bomb: the prompt to make it safe.
	rs.attackers = 1 - you.team
	_stand(_towards(bomb, start, 1.2), bomb + Vector3.UP * 0.1)
	await _grab("first-person-defender-at-the-armed-bomb")
	# 6. The kit at work, past the checkpoint.
	Input.action_press(PlayerInput.USE_DOOR)
	await _until(func() -> bool: return ps.defusing >= 0.6 or not ps.planted())
	await _grab("first-person-defender-defusing")
	Input.action_release(PlayerInput.USE_DOOR)
	rs.attackers = you.team
	await _frames(4)
	# The HUD off, the play stopped, the camera free.
	_session.set_physics_process(false)
	_session.set_process(false)
	for child in _session.find_children("*", "CanvasLayer", true, false):
		(child as CanvasLayer).visible = false
	_session._hands.visible = false
	var camera := _session._eyes.camera
	var view := _session.plant_view()
	camera.fov = 60.0
	# 7. The bomb, armed, close up.
	ps.defuser = -1
	view.refresh(ps, rs.attackers, null, 1.0, false, 0.0)
	camera.look_at_from_position(_towards(bomb, start, 0.9) + Vector3(0.35, 0.5, 0.0), bomb + Vector3.UP * 0.06)
	await _grab("the-bomb-armed-close-up")
	# 8. Being made safe: the cutters laid open beside its wires.
	ps.defuser = you.id
	view.refresh(ps, rs.attackers, null, 1.0, false, 0.12)
	camera.look_at_from_position(_towards(bomb, start, 0.55) + Vector3(0.25, 0.35, 0.0), bomb + Vector3.UP * 0.08)
	await _grab("the-wire-cutters-laid-beside-the-bomb-close-up")
	ps.defuser = -1
	# 9, 10. Carried by a bot of the attackers, strapped at its left hip, standing and crouched.
	var bot: Character = null
	for c in st.characters:
		if c != you and c.team == rs.attackers:
			bot = c
			break
	if bot != null:
		ps.status = PlantState.Status.CARRIED
		ps.carrier = bot.id
		view.refresh(ps, rs.attackers, bot, 1.0, false, 0.0)
		var left := Vector3(-1.0, 0.0, 0.0).rotated(Vector3.UP, bot.yaw)
		var ahead := Vector3(0.0, 0.0, -1.0).rotated(Vector3.UP, bot.yaw)
		camera.look_at_from_position(bot.position + left * 1.6 + ahead * 0.9 + Vector3.UP * 1.3,
				bot.position + left * 0.25 + Vector3.UP * 0.85)
		await _grab("a-bot-carrying-the-bomb-strapped-at-its-hip")
		bot.crouch_amount = 1.0
		bot.prev_crouch_amount = 1.0
		bot.low = true
		_session.set_process(true)  # the figures pose the crouch (the play itself stays stopped: speed 0)
		_session.speed = 0
		await _frames(30)
		_session.set_process(false)
		_session._hands.visible = false
		view.refresh(ps, rs.attackers, bot, 1.0, false, 0.0)
		camera.look_at_from_position(bot.position + left * 1.5 + ahead * 0.9 + Vector3.UP * 1.0,
				bot.position + left * 0.25 + Vector3.UP * 0.6)
		await _grab("a-bot-crouched-carrying-the-bomb")
		bot.crouch_amount = 0.0
		bot.prev_crouch_amount = 0.0
		bot.low = false
	# 11, 12. Each site from outside its ring.
	ps.status = PlantState.Status.DOWN
	ps.carrier = -1
	ps.position = start
	view.refresh(ps, rs.attackers, null, 1.0, false, 0.0)
	camera.fov = 75.0
	for i in ps.sites.size():
		var from := _towards(ps.sites[i], start, ps.radii[i] + 5.0) + Vector3.UP * 2.6
		camera.look_at_from_position(from, ps.sites[i] + Vector3.UP * 0.8)
		await _grab("site-%s-ring-and-letter" % Plant.LETTERS[i])
	print("plant_pictures: %d pictures in %s" % [_count, _folder])
	quit()
