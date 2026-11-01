class_name MinimapHearing
extends RefCounted
## What your side heard, for the minimap (the browser game's heard patches, M23; DECISIONS 2026-10-04: the minimap shows
## teammates, and the other team only as patches where they were last heard). PlaySession feeds it each tick's events
## after the step, heard through one character's ears: the one the view is through (you, or the teammate you watch once
## out); its side is that character's team. An enemy in play is heard when a footstep or vault of theirs lands within
## step_reach of the listener (a step on loud ground further, by its carry), a run of theirs into a noisy prop within
## the knock's reach (as a step), a door of theirs opening or shutting within its reach (as a step, DO1), or a shot
## within shot_reach × the replica's heard_scale (flat distance; walls are not checked, as the browser). Each enemy has
## one patch, the last thing heard: a circle off their real position by a blur drawn from the match's own minimap stream
## (Seeds), with them always inside it, fading out after patch_life. A sound from inside a live patch renews it where it
## is; from outside, it moves. A hit call removes that player's patch and a new round clears them all. Reads the state,
## never writes it; plain data the HUD draws (MM4). A tick allocates nothing: the records are made when a match starts.

enum Sound { STEP, SHOT }


## One enemy's patch, `live` until patch_life after the last thing heard of them.
class Patch:
	var character_id: int = -1
	var live: bool = false
	## The last thing heard: a footstep or vault (drawn dashed), or a shot (a dot).
	var sound: Sound = Sound.STEP
	## The patch's middle (at the heard enemy's feet height, for storeys) and its radius (m).
	var centre: Vector3 = Vector3.ZERO
	var radius: float = 0.0
	## When they were last heard (GameState.time, s).
	var heard_at: float = 0.0
	## Its middle lies beyond the panel's view radius from the listener: drawn small on the rim, towards it.
	var beyond_view: bool = false


## One record for each character of the match, in the order of GameState.characters; only enemies' ever go live.
var patches: Array[Patch] = []
## Whose ears (the character id; -1 before the first tick) and their team: the side whose enemies are heard.
var listener_id: int = -1
var side: int = -1
## The simulated time (s) of the last tick heard.
var time: float = 0.0
## How close the minimap shows the field (HudPrefs.minimap_zoom): the view radius `beyond_view` is measured on is
## MinimapConfig.view_radius over it.
var zoom: float = 1.0

var _cfg: MinimapConfig = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _match: int = -1


func _init(cfg: MinimapConfig) -> void:
	_cfg = cfg


## After a simulation tick: what `listener` heard of the tick's events. A new match makes the records and reseeds the
## stream; a listener on another team clears the patches (they were the other side's), one on the same team keeps them.
func on_tick(state: GameState, listener: Character) -> void:
	if state.match_number != _match or patches.size() != state.characters.size():
		_start_match(state)
	if listener != null:
		if listener.team != side:
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
				if shooter != null:
					_hear(shooter, e.position, _cfg.shot_reach * heard_scale(shooter, e.slot), Sound.SHOT, listener)
			GameEvent.Kind.FOOTSTEP, GameEvent.Kind.VAULT, GameEvent.Kind.PROP_KNOCK, GameEvent.Kind.DOOR:
				var walker := state.character(e.actor)
				if walker != null:
					var reach := e.reach if e.kind == GameEvent.Kind.PROP_KNOCK or e.kind == GameEvent.Kind.DOOR \
							else _cfg.step_reach * e.carry
					_hear(walker, walker.position, reach, Sound.STEP, listener)
			GameEvent.Kind.CHARACTER_HIT:
				var p := patch_of(e.target)
				if p != null:
					_drop(p)
			GameEvent.Kind.ROUND_START:
				clear()
	_age(listener)


## The patch kept for `character_id`, or null.
func patch_of(character_id: int) -> Patch:
	for p in patches:
		if p.character_id == character_id:
			return p
	return null


## How many patches are live.
func live_count() -> int:
	var n := 0
	for p in patches:
		if p.live:
			n += 1
	return n


## How strongly `p` shows (0..1): full until its last patch_fade seconds, then fading to nothing.
func shade(p: Patch) -> float:
	if not p.live:
		return 0.0
	var left := _cfg.patch_life - (time - p.heard_at)
	if _cfg.patch_fade <= 0.0:
		return 1.0 if left > 0.0 else 0.0
	return clampf(left / _cfg.patch_fade, 0.0, 1.0)


## Forgets every patch.
func clear() -> void:
	for p in patches:
		_drop(p)


func _start_match(state: GameState) -> void:
	_match = state.match_number
	_rng.seed = Seeds.minimap_seed(state.match_seed, _match)
	if patches.size() != state.characters.size():
		patches.clear()
		for c in state.characters:
			patches.append(Patch.new())
	for i in patches.size():
		patches[i].character_id = state.characters[i].id
	clear()


## `source` made a sound of `sound` at `at`, heard as far as `reach` (m): an enemy of the side in play within reach of
## the listener gets their patch renewed (still inside it) or placed afresh.
func _hear(source: Character, at: Vector3, reach: float, sound: Sound, listener: Character) -> void:
	if listener == null or source.team == side or not Elimination.is_in_play(source):
		return
	var ear := listener.position
	if Vector2(at.x - ear.x, at.z - ear.z).length_squared() > reach * reach:
		return
	var p := patch_of(source.id)
	if p == null:
		return
	var feet := source.position
	p.heard_at = time
	p.sound = sound
	if p.live and Vector2(feet.x - p.centre.x, feet.z - p.centre.z).length() <= p.radius:
		p.centre.y = feet.y # heard on another storey: the patch takes the floor it came from
		return
	var share := _cfg.shot_blur_share if sound == Sound.SHOT else _cfg.step_blur_share
	var blur := clampf(Vector2(feet.x - ear.x, feet.z - ear.z).length() * share, _cfg.blur_min, _cfg.blur_max)
	var angle := _rng.randf() * TAU
	var off := sqrt(_rng.randf()) * blur
	p.centre = Vector3(feet.x + cos(angle) * off, feet.y, feet.z + sin(angle) * off)
	p.radius = blur + _cfg.patch_pad
	p.live = true


## Ends patches past their life and marks the rest beyond the view radius from the listener, or not.
func _age(listener: Character) -> void:
	for p in patches:
		if not p.live:
			continue
		if time - p.heard_at >= _cfg.patch_life:
			_drop(p)
		elif listener != null:
			var d := Vector2(p.centre.x - listener.position.x, p.centre.z - listener.position.z)
			var reach := _cfg.view_radius / maxf(zoom, HudPrefs.MINIMAP_ZOOM_RANGE.x)
			p.beyond_view = d.length_squared() > reach * reach


static func _drop(p: Patch) -> void:
	p.live = false
	p.beyond_view = false


## How far the shot from `slot` carries as a share (a silencer halves it): the active replica's if the slot is unknown.
## SoundCues reads it too.
static func heard_scale(shooter: Character, slot: int) -> float:
	var replicas := shooter.armament.replicas
	var r: ReplicaConfig = replicas[slot] if slot >= 0 and slot < replicas.size() else shooter.armament.replica()
	return r.heard_scale if r != null else 1.0
