class_name ReplicaView
extends Node3D
## The replica in your hands (the browser game's render/replicas/viewmodel.ts): each replica of the loadout drawn from
## its model (assets/models/replicas/<id>.glb), the one in hand shown, posed from the character's state every rendered
## frame: at the hip or with its sight line through the eye as the sight comes up, dropped while it is drawn, carried
## low on a sprint, canted through a reload, kicked back by each shot, lagging a touch behind a turn and pulled back
## near a wall, and what still reaches into a wall drawn over it, never into it (its depth pressed towards the eye:
## ViewModelConfig.depth_scale). Fired on the run it comes up out of the carry, square to the view, while
## shots go out and a moment after the last one. A gas pistol's slide locks back on its last BB and closes near the end of
## the reload; the fire selector shows the mode it is set to (SelectorPose). Its parts are fitted from their models
## (ReplicaParts), as the menus show them; aimed with an optic, the eye looks along the optic's sight line through its
## glass (OpticGlass). Reduced motion (set_motion) draws less of the sway, the kick and the reload's cant. Hit
## (`on_hit`), it jolts and drops out of view before it hides, the same with motion reduced. Inspected (IN1, `inspect`),
## it is turned over in the hands by its InspectPose while its model's Inspect clip works its parts, the parts' sounds
## going out as `inspect_sound`; a shot, a hit, a reload, a draw, a switch, the holster, a sprint or raising the sight
## ends it (the pose eases back, the parts rest at once). A child of the camera.

## A part of the replica in hand made a sound while it is inspected: an InspectPose cue (SimAudio.inspect_sound).
signal inspect_sound(cue: StringName)

const MODEL_DIR := "res://assets/models/replicas/"
## The models' animation clips (docs/CC0_ASSETS.md › Replica models).
const FIRE_CLIP := &"Fire"
const RELOAD_CLIP := &"Reload"
const SLIDE_LOCK_CLIP := &"SlideLock"
const INSPECT_CLIP := &"Inspect"
## The shortest length (s) a share of an inspect is taken over (no division by a zero-length clip).
const MIN_LENGTH := 0.001
## The power source whose replicas lock their slide back on empty (gas blowback).
const SLIDE_LOCK_POWER := &"gas"

## One replica's drawn model and the points on it the view needs.
class Held:
	extends RefCounted
	## The Key of the replica it is drawn as (ReplicaConfig.model_id): its model, hold and pose.
	var id: StringName = &""
	var root: Node3D = null
	var anim: AnimationPlayer = null
	var muzzle: Node3D = null
	## The rear sight's place in the model (its origin is the model's), the sight line's back end.
	var rear_sight: Vector3 = Vector3.ZERO
	## The slide a gas pistol locks back on empty, as drawn (null for the rest), what holds its bone back over any clip,
	## and whether it is held back now.
	var slide: Node3D = null
	var slide_hold: SlideLockPose = null
	var slide_locked: bool = false
	## A reload clip is posed part way (cleared when the reload ends or is cut short).
	var in_reload: bool = false
	## Its fitted parts, and its optic's glass (null: none, or the iron sights).
	var fit: ReplicaParts.Fit = null
	var window: OpticGlass.Sight = null
	## Holds its fire selector at the mode it is set to (null: the model has none).
	var selector: SelectorPose = null
	## How fast a shot plays its Fire clip: 1, or for a bolt-action replica its cycle stretched to its ready time.
	var fire_speed: float = 1.0
	## The grip part fitted (its Key; empty: none), which your left hand holds (BP8).
	var grip: StringName = &""
	## Holds the magazine in your left hand through a reload (null: the model has no magazine bone), and the
	## magazine's place in the hand by the arms' reload clip, taken where the hand takes it (BP8).
	var carry: MagazineCarry = null
	var in_hand: Dictionary[StringName, Transform3D] = {}

var _cfg: ViewModelConfig = null
## Whose arms you see holding the replica (FigureMix.HUMAN or FigureMix.ROBOT), set by PlaySession from the match's
## mix: ArmsView.
var arms_kind: int = FigureMix.HUMAN:
	set(kind):
		arms_kind = kind
		if _arms != null:
			_arms.set_kind(kind)
## Your arms skin only (Dev › Skin-only arms, BP8), switched live: ArmsView.
var skin_arms: bool = false:
	set(on):
		skin_arms = on
		if _arms != null:
			_arms.set_skin(on)
var _arms: ArmsView = null
var _held: Array[Held] = []
var _active: int = -1
var _kick: float = 0.0
## Your hit (FI5): the jolt left, in shots' kicks, and the time since the hit while it drops (s; -1: none).
var _jolt: float = 0.0
var _hit_age: float = -1.0
var _sway: Vector2 = Vector2.ZERO
var _carry: float = 0.0
## Seconds left that a shot holds it up out of the sprint carry.
var _fire_hold: float = 0.0
## How far into the holster it is (0 in hand, 1 put away); kept through a draw from the holster, which rises from it.
var _away: float = 0.0
var _pull: float = 0.0
var _last_yaw: float = 0.0
var _last_pitch: float = 0.0
var _query: WorldQuery = null
var _wall: RayHit = RayHit.new()
var _glass: OpticGlass = null
## How much of the sway, the kick and the reload's cant to draw (Reduced motion).
var _motion: MotionScale = MotionScale.new()
## Each material the replicas wear and its copy with the depth pressed (ViewModelConfig.depth_scale), made once a view
## (shared paints are pressed once), and each copy's own.
var _pressed: Dictionary[Material, Material] = {}
var _pressed_from: Dictionary[Material, Material] = {}
## The inspect (IN1): asked for since the last frame; seconds into the one under way (-1: none), its length and pose,
## and its next sound; and, once it ends early, the seconds left easing back from the turn and shift it was at.
var _inspect_asked: bool = false
var _inspect_age: float = -1.0
var _inspect_length: float = 0.0
var _inspect_pose: InspectPose = null
var _inspect_sound: int = 0
var _inspect_fade: float = 0.0
var _inspect_turn: Vector3 = Vector3.ZERO
var _inspect_shift: Vector3 = Vector3.ZERO


## Draws `loadout` from its models, slot `i` in `paints[i]` (the replica's default where the kit names none; see
## ReplicaPaint) and, if `realistic`, every bold scheme as its plain colour, with `parts[i]` fitted (Kit.parts); `query`
## finds walls to pull back from. `view` and `eyes` (the camera this is under) draw an optic's glass.
func setup(cfg: ViewModelConfig, loadout: Array[ReplicaConfig], query: WorldQuery,
		paints: Array[StringName] = [], realistic: bool = false, parts: Array[Dictionary] = [],
		view: ViewConfig = null, eyes: Camera3D = null) -> void:
	_cfg = cfg
	_query = query
	_arms = ArmsView.new()
	add_child(_arms)
	_arms.setup(cfg)
	_arms.set_kind(arms_kind)
	_arms.set_skin(skin_arms)
	if view != null and eyes != null:
		_glass = OpticGlass.new()
		_glass.setup(cfg, view, eyes)
		add_child(_glass)
	for i in loadout.size():
		var r := loadout[i]
		var paint := paints[i] if i < paints.size() else ReplicaPaint.default_paint(r)
		var fitted: Dictionary = parts[i] if i < parts.size() else {}
		_held.append(_load(r, paint, realistic, fitted))


## Draws `motion`'s share of the sway, the kick and the reload's cant from the next frame (Reduced motion).
func set_motion(motion: MotionScale) -> void:
	_motion = motion


## Your arms' materials (ArmsView), for ShaderPrewarm, so the first replica shown or switched to doesn't hitch.
func arms_materials() -> Array[Material]:
	return _arms.materials() if _arms != null else [] as Array[Material]


## The optic glass's camera while it draws a raised sight's view (OpticGlass.drawing_camera), or null.
func glass_camera() -> Camera3D:
	return _glass.drawing_camera() if _glass != null else null


## The optics' glass materials, for ShaderPrewarm, with the glass's picture readied now (none without an optic's glass).
func prewarm_glass() -> Array[Material]:
	var out: Array[Material] = []
	for held in _held:
		if held.window != null:
			out.append(held.window.material)
			if held.window.hip_material != null:
				out.append(held.window.hip_material)
	if not out.is_empty():
		_glass.prewarm()
	return out


## The muzzle of the replica in hand, in the world (where your BBs are drawn from).
func muzzle_position() -> Vector3:
	if _active < 0 or _held[_active].muzzle == null:
		return global_position
	return _held[_active].muzzle.global_position


## A shot from the replica in hand: kick it back and work its trigger (and a pistol's slide).
func on_shot() -> void:
	_kick = minf(_cfg.kick_max, _kick + 1.0)
	_fire_hold = _cfg.sprint_fire_hold
	_cut_inspect()
	if _active >= 0 and _held[_active].anim != null and _held[_active].anim.has_animation(FIRE_CLIP):
		_held[_active].anim.stop()
		_held[_active].anim.play(FIRE_CLIP, -1.0, _held[_active].fire_speed)


## You were hit: the replica jolts ViewModelConfig.hit_jolt kicks and drops hit_drop out of view over hit_drop_time,
## then hides (whatever Reduced motion says: the camera doesn't move).
func on_hit() -> void:
	_jolt = _cfg.hit_jolt
	_hit_age = 0.0
	_cut_inspect()


## Inspect the replica in hand (IN1): from the next frame it is turned over to look at, unless it can't be now (see
## `inspect_blocked`); asked again while one is under way, nothing changes.
func inspect() -> void:
	_inspect_asked = true


## True while nothing can be inspected for `c`, its sight raised `aim` (as drawn): sprinting, holstered (a bomb in hand
## too), reloading, drawing or the sight coming up.
func inspect_blocked(c: Character, aim: float) -> bool:
	var a := c.armament
	return a.replicas.is_empty() or c.sprinting or a.holstered or a.reload_left > 0.0 or a.draw_left > 0.0 \
			or aim > _cfg.inspect_aim_cancel


## Whether an inspect is under way.
func inspecting() -> bool:
	return _inspect_age >= 0.0


## Poses the replica in hand for `c`, `delta` seconds since the last frame, its sight raised `aim` (as drawn:
## AimFollow); `eye` and `look` find walls in front.
func update(c: Character, view_yaw: float, view_pitch: float, eye: Vector3, look: Vector3, delta: float,
		aim: float) -> void:
	var a := c.armament
	var in_play := Elimination.is_in_play(c)
	if in_play:
		_hit_age = -1.0
	elif _hit_age >= 0.0:
		_hit_age += maxf(delta, 0.0)
	var dropping := not in_play and _hit_age >= 0.0 and _hit_age <= _cfg.hit_drop_time
	visible = (in_play or dropping) and not a.replicas.is_empty()
	if not visible:
		_hit_age = -1.0
		_jolt = 0.0
		# A raise never outlives the view: shown again, it comes back as the character stands.
		_fire_hold = 0.0
		_drop_inspect()
		_inspect_asked = false
		if _glass != null:
			_glass.update(null, 0.0)
		return
	if a.active != _active:
		# The draw brings the next replica up from below: nothing of the last one's turn is eased onto it.
		_drop_inspect()
		_show(a.active)
	var held := _held[_active]
	var follow := 1.0 - exp(-_cfg.return_rate * delta)
	var steady := lerpf(1.0, _cfg.aim_steady, aim)

	# The sight line through the eye when aimed; the hip otherwise.
	var hip: Vector3 = _cfg.hip.get(held.id, _cfg.hip_default)
	var aimed := Vector3(0.0, 0.0, _cfg.aim_forward.get(held.id, _cfg.aim_forward_default)) - held.rear_sight
	var raise := aim * aim * (3.0 - 2.0 * aim)
	var pos := hip.lerp(aimed, raise)
	var rot := Vector3.ZERO

	# Lag behind a turn, springing back.
	var turn := Vector2(angle_difference(_last_yaw, view_yaw), view_pitch - _last_pitch)
	_last_yaw = view_yaw
	_last_pitch = view_pitch
	_sway = (_sway + turn * _cfg.sway_per_radian).limit_length(_cfg.sway_max)
	_sway = _sway.lerp(Vector2.ZERO, follow)
	pos += Vector3(_sway.x, _sway.y, 0.0) * (steady * _motion.sway)

	# Each shot kicks it back and up, recovering.
	_kick = lerpf(_kick, 0.0, follow)
	pos += Vector3(0.0, _cfg.kick_lift, _cfg.kick_back) * (_kick * steady * _motion.kick)
	# Hit: a jolt of whole kicks, then down out of view (neither scaled by Reduced motion).
	_jolt = lerpf(_jolt, 0.0, follow)
	pos += Vector3(0.0, _cfg.kick_lift, _cfg.kick_back) * _jolt
	if dropping:
		pos.y -= _cfg.hit_drop * smoothstep(0.0, _cfg.hit_drop_time, _hit_age)

	# Carried low on a sprint, unless firing: a shot in the last sprint_fire_hold brings it up, quicker (a trigger held
	# with nothing going out, empty or reloading, leaves it carried).
	_fire_hold = maxf(0.0, _fire_hold - delta)
	var firing := _fire_hold > 0.0
	var carry_rate := _cfg.sprint_fire_raise if firing else _cfg.carry_time
	# Up onto a ledge (CL1) it is carried low too: a hand is on the edge.
	var climbing := c.vault.active and c.vault.climb
	_carry = move_toward(_carry, 1.0 if (c.sprinting or climbing) and not firing else 0.0,
			delta / carry_rate)
	pos.y -= _cfg.sprint_drop * _carry
	rot.y += _cfg.sprint_tilt * 0.5 * _carry
	rot.x -= _cfg.sprint_tilt * 0.3 * _carry

	# Put away down and tipped; drawn up from below, from further down out of the holster.
	if a.holstered:
		_away = move_toward(_away, 1.0, delta / _cfg.holster_time)
		var s := _away * _away * (3.0 - 2.0 * _away)
		pos.y -= _cfg.holster_drop * s
		rot.x -= _cfg.holster_tilt * s
	elif a.draw_total > 0.0 and a.draw_left > 0.0:
		var left := a.draw_left / a.draw_total
		pos.y -= lerpf(_cfg.draw_drop, _cfg.holster_drop, _away) * left * left
		rot.x -= _cfg.holster_tilt * _away * left * left
	else:
		_away = 0.0
	# With a bomb in hand your arms hold it (GrenadeView): the replica's let go once it is down out of view.
	_arms.set_shown(Grenades.held(c) == Grenade.Kind.NONE or _away < 1.0)

	# Turned over to look at (IN1): ended by what `inspect_blocked` names here, before a reload's clip takes the parts.
	if inspect_blocked(c, aim):
		_cut_inspect()
	elif _inspect_asked and _inspect_age < 0.0 and _inspect_fade <= 0.0:
		# Not while easing back from one just ended: it would snap from the turn to the first key.
		_start_inspect(held)
	_inspect_asked = false
	_pose_inspect(delta)
	rot += _inspect_turn
	pos += _inspect_shift

	# Canted through a reload, its clip following the reload's progress (and your left hand changing the magazine).
	var reload_share := -1.0
	if a.reload_left > 0.0:
		var r := a.replica()
		var progress := clampf(1.0 - a.reload_left / maxf(r.reload_time, 0.001), 0.0, 1.0)
		var bell := _cfg.reload_bell(held.id, progress) * _motion.reload_cant
		var move := _cfg.reload_move(held.id)
		rot += _cfg.reload_cant(held.id) * bell
		pos += Vector3(-move.y, move.x, -move.z) * bell
		_seek(held, RELOAD_CLIP, progress)
		held.in_reload = true
		reload_share = progress
	elif held.in_reload:
		# Finished or cut short (a switch, a new round): back to the clip's end, magazine home.
		_seek(held, RELOAD_CLIP, 1.0)
		held.in_reload = false
		held.slide_locked = false
	if held.slide != null:
		_pose_slide(held, a)
	if held.selector != null:
		held.selector.mode = a.fire_mode()
	if _arms != null:
		_arms.follow(held.anim, delta, reload_share)
		_carry_magazine(held, reload_share)
		# Working a bolt at the hip: canted toward the eye so the right hand stays on screen (BP7, row 17).
		var work := _arms.work_share()
		if work > 0.0:
			var share: float = _cfg.work_cant.get(held.id, 1.0)
			var bell := sin(PI * work) * _motion.reload_cant * (1.0 - raise) * share
			rot += Vector3(_cfg.bolt_tilt, _cfg.bolt_turn, _cfg.bolt_roll) * bell
			pos += Vector3(-_cfg.bolt_inward, _cfg.bolt_lift, 0.0) * bell

	# Pulled back from a wall in front, at the hip.
	var pull := 0.0
	if _query.ray(eye, eye + look * _cfg.reach, _wall):
		pull = minf(_cfg.pull_back_max, _cfg.reach * (1.0 - _wall.fraction))
	_pull = lerpf(_pull, pull, follow)
	# Aimed, the sight stays at the eye (pulled back it would pass behind it); the pressed depth keeps it over the wall.
	pos.z += _pull * (1.0 - raise)

	held.root.position = pos
	held.root.rotation = rot
	if _glass != null:
		# A variable optic's glass shows the zoom it is turned to (SN2); a fixed scope's never changes.
		if held.window != null and held.window.magnify > 0.0:
			held.window.magnify = a.zooms[_active]
		_glass.update(held.window, aim)


## True while `a`'s replica in hand would hold a gas pistol's slide back: its magazine is empty and no reload is under
## way.
static func slide_held_back(a: Armament) -> bool:
	return not a.replicas.is_empty() and a.mag() == 0 and a.reload_left <= 0.0


## Locks the slide back once the last shot's cycle has run, keeps it back through a reload of an empty magazine until
## slide_release_at of the way, and lets it home once the magazine has BBs again. Called only for a slide held by a
## SlideLockPose.
func _pose_slide(held: Held, a: Armament) -> void:
	var lock := slide_held_back(a)
	if a.reload_left > 0.0:
		# The magazine is swapped at the reload's end, so an empty one now was empty when it began: the slide is back,
		# even when the reload cut the last shot's Fire clip short of slide_lock_after (KI2).
		var progress := 1.0 - a.reload_left / maxf(a.replica().reload_time, 0.001)
		held.slide_locked = a.mag() == 0 and progress < _cfg.slide_release_at
	elif lock and not held.slide_locked:
		var anim := held.anim
		var cycling := anim.is_playing() and anim.current_animation == FIRE_CLIP \
				and anim.current_animation_position < _cfg.slide_lock_after
		if not cycling:
			# Inspected, the Inspect clip keeps the parts: the hold alone keeps the slide back.
			if not inspecting():
				_seek(held, SLIDE_LOCK_CLIP, 1.0)
			held.slide_locked = true
	elif not lock and held.slide_locked:
		if not inspecting():
			_seek(held, FIRE_CLIP, 0.0)
		held.slide_locked = false
	# The bone is held over whatever clip is posed (the Reload clip keys the slide forward): SlideLockPose.
	held.slide_hold.active = held.slide_locked


## Starts an inspect of `held`: its pose (by replica id, else the default) over its Inspect clip's length (else the
## pose's), the clip played from its start.
func _start_inspect(held: Held) -> void:
	_inspect_pose = _cfg.inspect_poses.get(held.id, _cfg.inspect_pose_default) as InspectPose
	_inspect_length = _inspect_pose.duration
	if held.anim != null and held.anim.has_animation(INSPECT_CLIP):
		_inspect_length = held.anim.get_animation(INSPECT_CLIP).length
		held.anim.stop()
		held.anim.play(INSPECT_CLIP)
	_inspect_age = 0.0
	_inspect_sound = 0
	_inspect_fade = 0.0


## Ends the inspect under way early: the pose eases back from where it is over inspect_cancel_time, and the parts of
## the replica in hand go back to rest at once (the clip's start).
func _cut_inspect() -> void:
	if _inspect_age < 0.0:
		return
	_inspect_age = -1.0
	_inspect_fade = _cfg.inspect_cancel_time
	var held := _held[_active]
	if held.anim != null and held.anim.assigned_animation == INSPECT_CLIP:
		held.anim.pause()
		_seek(held, INSPECT_CLIP, 0.0)


## Ends the inspect under way, if any, with nothing left to ease back (the replica hidden, or another drawn).
func _drop_inspect() -> void:
	_cut_inspect()
	_inspect_fade = 0.0
	_inspect_turn = Vector3.ZERO
	_inspect_shift = Vector3.ZERO


## Moves the inspect on `delta` seconds: the pose at its share and the sounds it has reached; once ended early, the
## pose eased back towards the hold.
func _pose_inspect(delta: float) -> void:
	var step := maxf(delta, 0.0)
	if _inspect_age >= 0.0:
		_inspect_age += step
		var share := minf(_inspect_age / maxf(_inspect_length, MIN_LENGTH), 1.0)
		_inspect_turn = _inspect_pose.turn_at(share)
		_inspect_shift = _inspect_pose.shift_at(share)
		var cues := _inspect_pose.sound_at
		while _inspect_sound < cues.size() and share >= cues[_inspect_sound]:
			inspect_sound.emit(_inspect_pose.sound_cue[_inspect_sound])
			_inspect_sound += 1
		if share >= 1.0:
			_inspect_age = -1.0
	elif _inspect_fade > 0.0:
		var keep := maxf(_inspect_fade - step, 0.0) / _inspect_fade
		_inspect_turn *= keep
		_inspect_shift *= keep
		_inspect_fade = maxf(_inspect_fade - step, 0.0)
	else:
		_inspect_turn = Vector3.ZERO
		_inspect_shift = Vector3.ZERO


func _show(slot: int) -> void:
	for i in _held.size():
		_held[i].root.visible = i == slot
		# Only the replica in hand updates its skeleton each frame.
		if _held[i].selector != null:
			_held[i].selector.active = i == slot
		if _held[i].window != null:
			_held[i].window.disc.visible = false
	_active = slot
	_kick = 0.0
	if slot >= 0 and slot < _held.size():
		_arms.hold(_held[slot].id, _held[slot].root, _held[slot].grip)


## Your left hand carries the magazine over its share of the reload (`share`; below 0, none): ViewModelConfig.
## reload_carry. The magazine's place in the hand is taken once for each of the arms' reload clips, where the hand takes
## it; then each frame the magazine goes where the hand is, down out of view and back up with the fresh one.
func _carry_magazine(held: Held, share: float) -> void:
	if held.carry == null:
		return
	var span: Vector2 = _cfg.reload_carry.get(held.id, Vector2.ZERO)
	var clip := _arms.reload_clip()
	if clip == &"" or share < span.x or share > span.y or span.y <= span.x:
		return
	if not held.in_hand.has(clip):
		_seek(held, RELOAD_CLIP, span.x)
		_arms.follow(held.anim, 0.0, span.x)
		held.in_hand[clip] = _arms.left_hand(held.root).affine_inverse() * held.carry.in_root(held.root)
		_seek(held, RELOAD_CLIP, share)
		_arms.follow(held.anim, 0.0, share)
	held.carry.place(held.root, _arms.left_hand(held.root) * held.in_hand[clip])


func _seek(held: Held, clip: StringName, share: float) -> void:
	if held.anim == null or not held.anim.has_animation(clip):
		return
	if held.anim.current_animation != clip:
		held.anim.play(clip)
		held.anim.pause()
	held.anim.seek(share * held.anim.get_animation(clip).length, true)


func _load(r: ReplicaConfig, paint: StringName, realistic: bool, parts: Dictionary) -> Held:
	var held := Held.new()
	# Drawn, held and posed as its model's replica (a stand-in model's, CS1).
	held.id = r.model_id()
	# A bolt-action replica's cycle stretched to its ready time with its parts (the loadout's stats carry them; row 19).
	if r.bolt_action and r.fire_rate > 0.0:
		held.fire_speed = _cfg.bolt_cycle_end * r.fire_rate
	held.root = Node3D.new()
	held.root.name = "Held_%s" % r.id
	held.root.visible = false
	add_child(held.root)
	var scene := load(MODEL_DIR + held.id + ".glb") as PackedScene
	if scene == null:
		push_warning("ReplicaView: no model for replica %s" % r.id)
		return held
	var model := scene.instantiate() as Node3D
	held.root.add_child(model)
	held.fit = ReplicaParts.fit(model, held.id, parts)
	held.grip = StringName(parts.get(ReplicaParts.GRIP_SLOT, &""))
	ReplicaPaint.apply(model, paint, realistic)
	held.anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	held.selector = SelectorPose.attach(model, held.anim)
	held.carry = MagazineCarry.attach(model, ReplicaParts.MAGAZINE_ATTACHMENT)
	held.muzzle = held.fit.muzzle
	var rear := model.find_child("RearSight", true, false) as Node3D
	if r.power == SLIDE_LOCK_POWER:
		held.slide_hold = SlideLockPose.attach(model, held.anim)
		if held.slide_hold != null:
			held.slide = model.find_child("slide", true, false) as Node3D
		if held.slide == null and held.slide_hold != null:
			held.slide_hold.queue_free()
			held.slide_hold = null
	if rear != null:
		held.rear_sight = rear.position
	if held.fit.optic != null:
		_aim_through(held, r)
	# The figures' cut-down copy never shows in the hands, and the hands' replica casts no shadow on the field and
	# stays out of the glass's view.
	var figure := model.find_child(ReplicaParts.FIGURE_NODE, true, false) as Node3D
	if figure != null:
		figure.visible = false
	for mesh: Node in model.find_children("*", "GeometryInstance3D", true, false):
		(mesh as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(mesh as GeometryInstance3D).layers = OpticGlass.HANDS_LAYER
	_press_depth(model)
	return held


## The material surface `i` of `mesh_node` wears as painted (ReplicaPaint), before its depth was pressed: null where it
## wears the model's own.
func painted(mesh_node: MeshInstance3D, i: int) -> Material:
	var worn := mesh_node.get_surface_override_material(i)
	var source: Material = _pressed_from.get(worn, worn)
	return null if source == mesh_node.mesh.surface_get_material(i) else source


## Every surface of `model` wears a copy of its material with the depth pressed towards the eye, so the replica draws
## over a wall it reaches into. The optic's glass presses its own (OpticGlass).
func _press_depth(model: Node) -> void:
	if _cfg.depth_scale >= 1.0:
		return
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh == null or mesh_node.material_override != null:
			continue
		for i in mesh_node.mesh.get_surface_count():
			var worn := mesh_node.get_active_material(i)
			if worn is BaseMaterial3D or ReplicaPaint.is_surface(worn):
				mesh_node.set_surface_override_material(i, _pressed_copy(worn))


## `worn` with its depth pressed: a BaseMaterial3D's z-clip scale, or the worn paint's (ReplicaPaint, RW1) uniform.
func _pressed_copy(worn: Material) -> Material:
	if not _pressed.has(worn):
		var copy := worn.duplicate() as Material
		var plain := copy as BaseMaterial3D
		if plain != null:
			plain.use_z_clip_scale = true
			plain.z_clip_scale = _cfg.depth_scale
		else:
			(copy as ShaderMaterial).set_shader_parameter(&"z_clip_scale", _cfg.depth_scale)
		_pressed[worn] = copy
		_pressed_from[copy] = worn
	return _pressed[worn]


## Aims `held` along its optic's sight line: with a glass, the eye sits optic_eye_back behind it (and the glass is drawn,
## magnified for a scope); without, its sight line's mark is the rear sight.
func _aim_through(held: Held, r: ReplicaConfig) -> void:
	var fit := held.fit
	held.rear_sight = fit.sight_line
	if not _cfg.optic_eye_back.has(fit.optic_key) or not _cfg.optic_glass_z.has(fit.optic_key):
		return
	var glass_z := (fit.optic.transform * Vector3(0.0, 0.0, _cfg.optic_glass_z[fit.optic_key])).z
	var forward: float = _cfg.aim_forward.get(held.id, _cfg.aim_forward_default)
	held.rear_sight = Vector3(fit.sight_line.x, fit.sight_line.y, forward + glass_z + _cfg.optic_eye_back[fit.optic_key])
	if _glass != null:
		var magnify := r.aim_zoom if r.zoom_in_glass else 0.0
		held.window = _glass.add_window(fit.model, fit.optic, fit.optic_key, fit.sight_line, magnify)
