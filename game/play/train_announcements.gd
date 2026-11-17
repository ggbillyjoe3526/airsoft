class_name TrainAnnouncements
extends RefCounted
## When Subway's easter egg announcements (TA1, TrainAnnounceConfig) sound: the gap its random count of times, each
## at its random gap after the one before, to a listener near a train or inside one; the one-off once, to a listener
## standing inside a train. Timed on the simulation's clock from a generator seeded from the config's rng_seed and the
## match's (presentation only, never the match's stream): the same seeds give the same announcements, and each rematch
## new ones. `begin` starts a match.

## Keeps each rematch's announcements apart (an arbitrary prime, as AmbientCalls.PER_MATCH).
const PER_MATCH := 2654435761

## Where the last announcement `due` gave sounds from: the nearest point of the train's inside to the feet.
var at: Vector3 = Vector3.ZERO
var _cfg: TrainAnnounceConfig = null
## Each train's inside (where the feet count as in it).
var _inside: Array[AABB] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## The match's gap plays still to come and when the next comes due (s); whether the one-off is still to come and when
## it comes due (s).
var _gaps_left: int = 0
var _gap_next: float = INF
var _once_left: bool = false
var _once_next: float = INF


func _init(cfg: TrainAnnounceConfig, trains: Array[TrainDressing]) -> void:
	_cfg = cfg
	for t in trains:
		_inside.append(inside_of(t, cfg))


## Where the feet stand inside train `t`: its box less `cfg.wall` at each side and end, from `cfg.floor_drop` under its
## lowest car's floor to its box's top.
static func inside_of(t: TrainDressing, cfg: TrainAnnounceConfig) -> AABB:
	var floor_y := t.box.position.y
	if not t.cars.is_empty():
		floor_y = INF
		for c in t.cars:
			floor_y = minf(floor_y, c.middle.y)
	var lo := Vector3(t.box.position.x + cfg.wall, floor_y - cfg.floor_drop, t.box.position.z + cfg.wall)
	var hi := t.box.end - Vector3(cfg.wall, 0.0, cfg.wall)
	return AABB(lo, (hi - lo).max(Vector3.ZERO))


## The seed match `match_number` (1 for the first) of a state seeded with `match_seed` is timed from.
static func seed_for(cfg: TrainAnnounceConfig, match_seed: int, match_number: int) -> int:
	return Seeds.derive(match_seed ^ cfg.rng_seed, 1, ((match_number - 1) * PER_MATCH) & Seeds.MASK_32)


## Starts match `match_number` of a state seeded with `match_seed` at `now` (s): the gap's random count of plays, its
## first due first_min to first_max from now, and the one-off due once_min to once_max from now.
func begin(match_seed: int, match_number: int, now: float) -> void:
	_rng.seed = seed_for(_cfg, match_seed, match_number)
	_gaps_left = _rng.randi_range(_cfg.gap_plays_min, maxi(_cfg.gap_plays_min, _cfg.gap_plays_max))
	_gap_next = now + _rng.randf_range(_cfg.first_min, _cfg.first_max)
	_once_left = true
	_once_next = now + _rng.randf_range(_cfg.once_min, _cfg.once_max)


## The trains' count (none: nothing ever plays).
func trains() -> int:
	return _inside.size()


## Whether `feet` stand inside a train.
func in_train(feet: Vector3) -> bool:
	return _nearest(feet, 0.0) >= 0


## Whether `feet` stand near a train (within TrainAnnounceConfig.near of its inside) or inside one.
func near_train(feet: Vector3) -> bool:
	return _nearest(feet, _cfg.near) >= 0


## The announcement to play at `now` (s) for a listener whose feet are at `feet` (none: `&""`; none while `busy`,
## another still playing): the one-off once it is due and they stand inside a train, else the gap once it is due and they
## stand near a train or in one. `at` is then where it sounds from; the gap's next play comes due its random gap from
## now.
func due(now: float, feet: Vector3, busy: bool = false) -> StringName:
	if busy:
		return &""
	if _once_left and now >= _once_next:
		var i := _nearest(feet, 0.0)
		if i >= 0:
			_once_left = false
			at = _closest(i, feet)
			return _cfg.once_cue
	if _gaps_left > 0 and now >= _gap_next:
		var i := _nearest(feet, _cfg.near)
		if i >= 0:
			_gaps_left -= 1
			_gap_next = now + _rng.randf_range(_cfg.apart_min, _cfg.apart_max)
			at = _closest(i, feet)
			return _cfg.gap_cue
	return &""


## The nearest train's index whose inside `feet` are within `within` m of (-1: none).
func _nearest(feet: Vector3, within: float) -> int:
	var best := -1
	var best_d := within * within
	for i in _inside.size():
		var d := _closest(i, feet).distance_squared_to(feet)
		if d <= best_d:
			best = i
			best_d = d
	return best


## The point of train `i`'s inside nearest `feet`.
func _closest(i: int, feet: Vector3) -> Vector3:
	var box := _inside[i]
	return feet.clamp(box.position, box.end)
