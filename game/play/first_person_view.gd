class_name FirstPersonView
extends Node3D
## The player's eyes (the browser game's render/camera.ts): a Camera3D at the character's eye, drawn between the last two
## ticks, turned by the mouse every rendered frame (PlayerInput's view) and lifted by the replica's recoil. A lean moves
## the eyes as the simulation does (Lean.offset, the one lean geometry) and rolls the view a little
## (ViewConfig.lean_camera_roll); a lean a wall cuts short eases out instead of snapping, never drawn into the wall. A
## vault dips and tips the view. Reduced motion (set_motion) draws less of the lean's roll and the vault's dip and tip,
## never less recoil: the climb shows where the next BB goes. Once hit, the view follows the character's own heading as
## it walks off. Zooms a little as the sight comes up (as its optic does; a scope zooms only inside its glass). The
## easing runs on rendered frames; the rules stay on the tick. At night the weapon torch of whoever the view is through
## is a real spot from the rail while lit (WL7, `set_torch`): with a light in your kit, on Medium and up, one of the
## preset's real lights, casting shadows on High and Ultra with Sun shadows on; else TorchBeams draws it as a haze.

## Recoil on screen follows the simulation's at this rate (1/s of simulation time), so a 60 Hz kick reads smoothly at
## any frame rate and game speed.
const RECOIL_FOLLOW := 40.0
## The share of a lean the eye's pace is measured over (FirstPersonView._ease_lean).
const LEAN_PACE_STEP := 0.01

var camera: Camera3D = null
## The view's own zoom right now (1: none), as the camera draws it: the HUD's crosshair is sized on it, not on the
## turn's zoom, which through a scope's glass is the glass's (BP3).
var view_zoom: float = 1.0
## How much the view and a scope's glass magnify with the sight up at all (BP6): the view's zoom raised (1 lowered) and
## the glass's as it is turned (0: no glass zooms); their targets, not eased, so the figures' detail lines
## (FigureConfig.zoomed_lines) change once a raise or a turn, never every frame.
var detail_zoom: float = 1.0
var glass_zoom: float = 0.0
## Seconds of simulation time per real second (the pacer's rate: the Dev settings' game speed); the recoil follows over
## the simulation's time, so slowed it eases between the ticks instead of stepping with them.
var sim_rate: float = 1.0
var _view: ViewConfig = null
var _body: BodyConfig = null
var _hits: HitConfig = null
var _recoil: float = 0.0
## The lean drawn (eased out of a cut) and the vault's dip and tip now (0..1).
var _lean: float = 0.0
var _vault: float = 0.0
## How much of the lean's roll and the vault's dip and tip to draw (Reduced motion).
var _motion: MotionScale = MotionScale.new()
## The torch's real spot on the rail (null: none, on Low or by day) and the light it was last set for.
var _torch: SpotLight3D = null
var _torch_light: Torch.Light = null


## `hits` holds the lean's geometry: the simulation's own (SimTuning.hits); the built-in values when not given.
func setup(view: ViewConfig, body: BodyConfig, hits: HitConfig = null) -> void:
	_view = view
	_body = body
	_hits = hits if hits != null else HitConfig.new()
	camera = Camera3D.new()
	camera.name = "Eyes"
	camera.near = view.near
	camera.far = view.far
	camera.fov = view.vertical_fov()
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	add_child(camera)
	camera.make_current()


## The view's own torch drawn as `mode` (GraphicsApply.torch_mode): a real spot on the rail, with shadows or not, made
## once and kept; HAZE frees it (TorchBeams draws the haze). Only on a field played at night: by day nothing calls it.
func set_torch(mode: TorchBeams.Mode) -> void:
	if mode == TorchBeams.Mode.HAZE:
		if _torch != null:
			_torch.queue_free()
			_torch = null
		return
	if _torch == null:
		_torch = SpotLight3D.new()
		_torch.name = "Torch"
		_torch.position = TorchBeams.RAIL
		_torch.light_color = TorchBeams.COLOUR
		_torch.light_energy = TorchBeams.SPOT_ENERGY
		_torch.spot_attenuation = TorchBeams.SPOT_ATTENUATION
		_torch.spot_angle_attenuation = TorchBeams.SPOT_ANGLE_ATTENUATION
		_torch.visible = false
		_torch_light = null
		camera.add_child(_torch)
	_torch.shadow_enabled = mode == TorchBeams.Mode.SHADOWED


## The torch's real spot, or null (none: Low, or by day).
func torch() -> SpotLight3D:
	return _torch


## Draws `motion`'s share of the lean's roll and the vault's dip and tip from the next frame (Reduced motion).
func set_motion(motion: MotionScale) -> void:
	_motion = motion


## Places the eyes for `c` at `fraction` of the way from its last tick to this one, zoomed for `aim`, the sight's raise
## as drawn (AimFollow). `own`: your own character, looking where your mouse does; else (spectating, or out) where `c`
## looks.
func update(c: Character, input: PlayerInput, fraction: float, delta: float, aim: float, own: bool = true) -> void:
	var crouch := lerpf(c.prev_crouch_amount, c.crouch_amount, fraction)
	var lean := lerpf(c.prev_lean, c.lean, fraction)
	var feet := c.prev_position.lerp(c.position, fraction)
	_recoil = lerpf(_recoil, c.armament.recoil, 1.0 - exp(-RECOIL_FOLLOW * delta * sim_rate))
	var yaw := input.view_yaw
	var pitch := input.view_pitch
	if not own or not Elimination.is_in_play(c):
		yaw = lerp_angle(c.prev_yaw, c.yaw, fraction)
		pitch = lerpf(c.prev_pitch, c.pitch, fraction)
	var height := Character.eye_height(crouch, _body)
	_lean = _ease_lean(lean, height, crouch, yaw, delta, own and Elimination.is_in_play(c))
	var v := c.vault
	var swing := sin(PI * clampf(v.time / v.end, 0.0, 1.0)) if v.active and v.end > 0.0 else 0.0
	_vault = lerpf(_vault, swing, 1.0 - exp(-_view.vault_follow * delta))
	var vault := _vault * _motion.vault_tip
	position = feet + Vector3(0.0, height - _view.vault_dip * vault, 0.0) + Lean.offset(height, _lean, crouch, yaw, _hits)
	# Leaning right tips the view's top to the right: a roll about the line of sight (local -Z), negative about +Z.
	rotation = Vector3(pitch + _recoil - _view.vault_tip * vault, yaw, -_lean * _view.lean_camera_roll * _motion.lean_roll)
	if _torch != null:
		_show_torch(c)
	var r := c.armament.replica()
	var zoom := lerpf(1.0, aimed_zoom(r, _view), aim)
	# The turn follows what the eye sees: through a scope's glass that is the glass's zoom (2× to 6× on the Variable
	# Scope), not the view round it (BP3: Scale with zoom did nothing through a scope).
	input.zoom = lerpf(1.0, maxf(c.armament.zoom_now(), 1.0), aim) if r != null and r.zoom_in_glass else zoom
	view_zoom = zoom
	detail_zoom = maxf(aimed_zoom(r, _view), 1.0) if aim > 0.0 else 1.0
	glass_zoom = glass_zoom_of(r, c.armament.zoom_now()) if aim > 0.0 else 0.0
	camera.fov = _view.vertical_fov(zoom)


## The view's zoom with `r`'s sight fully raised: its optic's, unless that zooms only inside its glass (a scope, drawn by
## ReplicaView), else the iron sights'.
static func aimed_zoom(r: ReplicaConfig, view: ViewConfig) -> float:
	if r != null and r.aim_zoom > 0.0 and not r.zoom_in_glass:
		return r.aim_zoom
	return view.aim_zoom


## How much `r`'s scope glass magnifies turned to `turned` (Armament.zoom_now; a fixed scope's is its aim_zoom); 0 for
## a sight with no zooming glass.
static func glass_zoom_of(r: ReplicaConfig, turned: float) -> float:
	if r == null or not r.zoom_in_glass:
		return 0.0
	return maxf(r.aim_zoom, turned)


## The lean to draw for the simulation's `lean`: it follows at once, except that a sudden drop (a wall cutting the lean
## short) eases out at a full lean per lean_cut_ease_time, held within lean_cut_allowance metres of the simulation's eye.
## `follow` false (spectating, out) draws the simulation's lean as it is.
func _ease_lean(lean: float, height: float, crouch: float, yaw: float, delta: float, follow: bool) -> float:
	# A zero ease time is no easing: the cut snaps, as before.
	if not follow or _view.lean_cut_ease_time <= 0.0:
		return lean
	var eased := move_toward(_lean, lean, delta / _view.lean_cut_ease_time)
	# The eye swings on an arc: its pace near upright (m per full lean) bounds how far any share of a lean moves it.
	var pace := Lean.offset(height, LEAN_PACE_STEP, crouch, yaw, _hits).length() / LEAN_PACE_STEP
	var band := _view.lean_cut_allowance / maxf(pace, 0.001)
	return clampf(eased, lean - band, lean + band)


## The spot on while `c`'s torch is lit, shaped by its light (reach and spill) when that changes.
func _show_torch(c: Character) -> void:
	var lit := Torch.lit(c)
	_torch.visible = lit
	if not lit:
		return
	var light := Torch.in_hand(c)
	if light != _torch_light:
		_torch_light = light
		_torch.spot_range = light.reach
		_torch.spot_angle = light.spill_deg * 0.5
