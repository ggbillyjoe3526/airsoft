class_name SoundCues
extends RefCounted
## Settings › Accessibility's sound cues (the browser game's ui/soundCues.ts, AC4): where the sounds you hear come from,
## as markers round the crosshair (HudSoundCues draws them). PlaySession feeds it each tick's events after the step,
## while the cues are on, through the same ears as MinimapHearing: the character the view is through (you, or the
## teammate you watch once out). Heard as far as each sound plays (SoundConfig): the other team's footsteps and vaults
## within step_reach (a step on loud ground further, by its carry), their runs into noisy props as steps out to each
## knock's reach, their doors opening or shutting as steps out to each door's reach (DO1), anyone's shot but the
## listener's within max_distance × the replica's heard_scale (a silencer halves it), anyone's hit call but the
## listener's within max_distance. Flat distance; walls are not checked (a muffled sound is still heard). Each player
## and kind has one marker, so a burst moves and renews one; the pool (AccessibilityConfig.cue_markers) is made once and
## never grows: with every marker up, the oldest makes way. A marker stays cue_life seconds, fading over the last
## cue_fade, at an opacity from 1 beside you to cue_far_opacity at its sound's reach. A new round or match clears them.
## Reads the state, never writes it; a tick allocates nothing.

enum Kind { STEP, SHOT, HIT }


## One marker: whose sound, of which kind, where it was and when.
class Cue:
	var character_id: int = -1
	var kind: Kind = Kind.STEP
	var live: bool = false
	## Where the sound was made (only its flat bearing from the listener is drawn).
	var at: Vector3 = Vector3.ZERO
	## When it was last heard (GameState.time, s), and its opacity for the distance it was heard at (before fading).
	var heard_at: float = 0.0
	var near: float = 1.0


## The pool, made once: AccessibilityConfig.cue_markers records.
var cues: Array[Cue] = []
## Whose ears (the character id; -1 before the first tick) and their team: steps of that team are not cues.
var listener_id: int = -1
var side: int = -1
## The simulated time (s) of the last tick heard.
var time: float = 0.0

var _cfg: AccessibilityConfig = null
var _sound: SoundConfig = null
var _match: int = -1


func _init(cfg: AccessibilityConfig, sound: SoundConfig) -> void:
	_cfg = cfg
	_sound = sound
	for i in maxi(cfg.cue_markers, 0):
		cues.append(Cue.new())


## After a simulation tick: the cues `listener` heard in the tick's events. A new match, a new round or new ears (the
## view moved to another player) clear them.
func on_tick(state: GameState, listener: Character) -> void:
	if state.match_number != _match:
		_match = state.match_number
		clear()
	if listener != null:
		if listener.team != side or listener.id != listener_id:
			clear()
			side = listener.team
		listener_id = listener.id
	time = state.time
	var events := state.events
	for i in events.count:
		var e := events.items[i]
		match e.kind:
			GameEvent.Kind.SHOT:
				var shooter := state.character(e.actor)
				if shooter != null and e.actor != listener_id:
					var reach := _sound.max_distance * MinimapHearing.heard_scale(shooter, e.slot)
					_hear(e.actor, Kind.SHOT, e.position, reach, listener)
			GameEvent.Kind.FOOTSTEP, GameEvent.Kind.VAULT, GameEvent.Kind.PROP_KNOCK, GameEvent.Kind.DOOR, \
					GameEvent.Kind.LIFT:
				var walker := state.character(e.actor)
				if walker != null and walker.team != side and Elimination.is_in_play(walker):
					var reach := e.reach if e.kind == GameEvent.Kind.PROP_KNOCK or e.kind == GameEvent.Kind.DOOR \
							or e.kind == GameEvent.Kind.LIFT \
							else _sound.step_reach * e.carry
					_hear(walker.id, Kind.STEP, walker.position, reach, listener)
			GameEvent.Kind.CHARACTER_HIT:
				if e.target >= 0 and e.target != listener_id:
					var caller := state.character(e.target)
					_hear(e.target, Kind.HIT, caller.position if caller != null else e.position, _sound.max_distance,
							listener)
			GameEvent.Kind.ROUND_START:
				clear()
	_age()


## How strongly `c` shows (0..1): its opacity for the distance, full until its last cue_fade seconds, then fading out.
func opacity(c: Cue) -> float:
	if not c.live:
		return 0.0
	var left := _cfg.cue_life - (time - c.heard_at)
	if _cfg.cue_fade <= 0.0:
		return c.near if left > 0.0 else 0.0
	return c.near * clampf(left / _cfg.cue_fade, 0.0, 1.0)


## How many markers are up.
func live_count() -> int:
	var n := 0
	for c in cues:
		if c.live:
			n += 1
	return n


## The live marker for `character_id`'s sounds of `kind`, or null.
func cue_of(character_id: int, kind: Kind) -> Cue:
	for c in cues:
		if c.live and c.character_id == character_id and c.kind == kind:
			return c
	return null


## Takes every marker down.
func clear() -> void:
	for c in cues:
		c.live = false


## The bearing (radians, clockwise from straight ahead; a sound behind and to the left is -3π/4) of `to` from `from`
## for eyes looking `yaw` (Character: yaw 0 down -Z, positive turning left). Flat: heights don't count.
static func bearing(from: Vector3, to: Vector3, yaw: float) -> float:
	var dx := to.x - from.x
	var dz := to.z - from.z
	var ahead := -sin(yaw) * dx - cos(yaw) * dz
	var right := cos(yaw) * dx - sin(yaw) * dz
	return atan2(right, ahead)


## `character_id` made a sound of `kind` at `at`, heard as far as `reach` (m): within it of the listener, its marker
## for that player and kind moves there and starts again.
func _hear(character_id: int, kind: Kind, at: Vector3, reach: float, listener: Character) -> void:
	if listener == null or reach <= 0.0:
		return
	var ear := listener.position
	var d := Vector2(at.x - ear.x, at.z - ear.z).length()
	if d > reach:
		return
	var c := _marker_for(character_id, kind)
	if c == null:
		return
	c.character_id = character_id
	c.kind = kind
	c.at = at
	c.heard_at = time
	c.near = lerpf(1.0, _cfg.cue_far_opacity, d / reach)
	c.live = true


## The marker kept for `character_id`'s `kind`: theirs if up, else a free one, else the one heard longest ago.
func _marker_for(character_id: int, kind: Kind) -> Cue:
	var free: Cue = null
	var oldest: Cue = null
	for c in cues:
		if c.live:
			if c.character_id == character_id and c.kind == kind:
				return c
			if oldest == null or c.heard_at < oldest.heard_at:
				oldest = c
		elif free == null:
			free = c
	return free if free != null else oldest


## Takes down the markers past their life.
func _age() -> void:
	for c in cues:
		if c.live and time - c.heard_at >= _cfg.cue_life:
			c.live = false
