class_name SoundOcclusion
extends RefCounted
## Muffling through walls (presentation; the browser game's audio/occlusion.ts and sfx.ts updateMuffling): how much of
## another character's sound level geometry blocks from the listener's eyes, through SoundPath's rays (the bots hear
## through the same walls), and the bus and level it plays at for that share. A character's share is reused for
## occlusion_refresh_ticks (a new listener casts afresh); a tick casts at most occlusion_ray_budget rays, so a sound
## over it keeps its character's last share and a BB impact over it plays open. No ray beyond occlusion_reach: there the
## last share closes to full over occlusion_far_ramp, in occlusion_far_step steps. Records made once per character id;
## a tick allocates nothing. Counts its rays and their time for the budget (rays_max, rays_total, ticks, ray_usec).

## A cast so long ago that any tick refreshes it.
const NEVER := -1_000_000

## Rays cast this tick; the most in one tick, all of them, the ticks counted and the time the rays took (µs).
var rays: int = 0
var rays_max: int = 0
var rays_total: int = 0
var ticks: int = 0
var ray_usec: int = 0

var _cfg: SoundConfig = null
var _query: WorldQuery = null
var _heights: PackedFloat64Array = PackedFloat64Array()
var _hit: RayHit = RayHit.new()
var _tick: int = 0
var _ear: Vector3 = Vector3.ZERO
## The listener's id (-1: nobody's ears, so nothing is muffled).
var _listener_id: int = -1
## By character id: the share its rays last found and the tick they were cast.
var _ray_share: PackedFloat32Array = PackedFloat32Array()
var _cast_at: PackedInt32Array = PackedInt32Array()
## How many characters the records were last made for, so a tick with the same cast walks none of them.
var _seen: int = 0


## Muffling by `cfg`'s occlusion numbers through `query` (the level; null: nothing is ever muffled).
func _init(cfg: SoundConfig, query: WorldQuery) -> void:
	_cfg = cfg
	_query = query
	for h in cfg.occlusion_ray_heights:
		_heights.append(h)


## Starts a tick heard through `listener`'s eyes at `ear` (null: nobody's). Makes a record for any of `characters` new
## to it (the match's first tick); a listener other than the last one's casts every share afresh.
func begin_tick(characters: Array[Character], listener: Character, ear: Vector3) -> void:
	_tick += 1
	ticks += 1
	rays = 0
	_ear = ear
	if characters.size() != _seen:
		_seen = characters.size()
		for c in characters:
			if c.id >= _cast_at.size():
				var from := _cast_at.size()
				_cast_at.resize(c.id + 1)
				_ray_share.resize(c.id + 1)
				for k in range(from, c.id + 1):
					_cast_at[k] = NEVER
					_ray_share[k] = 0.0
	var id := listener.id if listener != null else -1
	if id != _listener_id:
		_listener_id = id
		_cast_at.fill(NEVER)


## The blocked share (0 open .. 1 a wall) of a sound `c` makes, heard by this tick's listener: its own sounds and
## anyone's with no listener or no level are open.
func share_of(c: Character) -> float:
	if _query == null or _listener_id < 0 or c == null or c.id == _listener_id or c.id < 0 \
			or c.id >= _cast_at.size():
		return 0.0
	var id := c.id
	var beyond := _ear.distance_to(c.position) - _cfg.occlusion_reach
	if beyond <= 0.0 and _tick - _cast_at[id] >= _cfg.occlusion_refresh_ticks and _take(_heights.size()):
		var start := Time.get_ticks_usec()
		_ray_share[id] = SoundPath.blocked_share(_query, _ear, c.position, _heights, _hit)
		ray_usec += Time.get_ticks_usec() - start
		_cast_at[id] = _tick
	return closed_far(_cfg, _ray_share[id], beyond)


## The blocked share (0 or 1) of a BB impact at `at` on a surface, the BB arriving along `came` (its velocity; zero:
## not known): one ray from the listener's eyes to occlusion_impact_back back along `came`, on the BB's side of the
## surface, so a wall thinner than the old gap still blocks it (BP2), or with no `came` stopping occlusion_surface_gap
## short of `at`. Over the tick's budget it plays open; beyond reach it closes from open.
func impact_share(at: Vector3, came: Vector3 = Vector3.ZERO) -> float:
	if _query == null or _listener_id < 0:
		return 0.0
	var beyond := _ear.distance_to(at) - _cfg.occlusion_reach
	if beyond > 0.0:
		return closed_far(_cfg, 0.0, beyond)
	if not _take(1):
		return 0.0
	var start := Time.get_ticks_usec()
	var blocked := false
	if came.length_squared() > 0.0:
		blocked = _query.ray_past_railings(_ear, at - came.normalized() * _cfg.occlusion_impact_back, _hit)
	else:
		blocked = SoundPath.line_blocked(_query, _ear, at, _cfg.occlusion_surface_gap, _hit)
	ray_usec += Time.get_ticks_usec() - start
	return 1.0 if blocked else 0.0


## `share` closed towards full for a sound `beyond` m past occlusion_reach: over occlusion_far_ramp, a
## occlusion_far_step at a time (the browser's M53), so a character crossing the line isn't cleared or muffled at once.
static func closed_far(cfg: SoundConfig, share: float, beyond: float) -> float:
	if beyond <= 0.0:
		return share
	var stepped := floorf(beyond / cfg.occlusion_far_step) * cfg.occlusion_far_step if cfg.occlusion_far_step > 0.0 \
			else beyond
	var far := clampf(stepped / cfg.occlusion_far_ramp, 0.0, 1.0) if cfg.occlusion_far_ramp > 0.0 else 1.0
	return share + (1.0 - share) * far


## The bus a sound meant for `bus` plays on when `share` of it is blocked, at the nearest of open, half and full:
## Effects and Footsteps on EffectsHalf or EffectsFull, Power on PowerHalf or PowerFull; a silenced shot (Muffled) on
## whichever low-pass is lower, its own or the share's. Open, or any other bus: as it is.
static func bus_for(bus: StringName, share: float, cfg: SoundConfig) -> StringName:
	var step := roundi(clampf(share, 0.0, 1.0) * 2.0)
	if step == 0:
		return bus
	var half := step == 1
	match bus:
		SimAudio.BUS_EFFECTS, SimAudio.BUS_FOOTSTEPS:
			return SoundMix.BUS_EFFECTS_HALF if half else SoundMix.BUS_EFFECTS_FULL
		SimAudio.BUS_POWER:
			return SoundMix.BUS_POWER_HALF if half else SoundMix.BUS_POWER_FULL
		SimAudio.BUS_MUFFLED:
			var bus_share := SoundMix.HALF_SHARE if half else SoundMix.FULL_SHARE
			if SoundMix.share_cutoff_hz(cfg, bus_share) < cfg.muffled_cutoff_hz:
				return SoundMix.BUS_EFFECTS_HALF if half else SoundMix.BUS_EFFECTS_FULL
	return bus


## The level (linear) a sound meant for `bus` plays at on bus_for's bus so it is heard at `share`'s level (the
## browser's, from 1 open to occlusion_muffled_gain): what that bus doesn't already give at its own share.
static func level_for(bus: StringName, share: float, cfg: SoundConfig) -> float:
	var given := 1.0
	match bus_for(bus, share, cfg):
		SoundMix.BUS_EFFECTS_HALF, SoundMix.BUS_POWER_HALF:
			given = SoundMix.share_gain(cfg, SoundMix.HALF_SHARE)
		SoundMix.BUS_EFFECTS_FULL, SoundMix.BUS_POWER_FULL:
			given = SoundMix.share_gain(cfg, SoundMix.FULL_SHARE)
	if given <= 0.0: # a bus muffled to silence already gives all of it
		return 1.0
	return SoundMix.share_gain(cfg, share) / given


## Takes `n` rays from the tick's budget, if they fit.
func _take(n: int) -> bool:
	if rays + n > _cfg.occlusion_ray_budget:
		return false
	rays += n
	rays_total += n
	rays_max = maxi(rays_max, rays)
	return true
