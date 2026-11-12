class_name SoundMix
extends Node
## The field's mix (presentation; the browser game's CORE-30 and CORE-34): the Field bus, which Effects and Ambience feed
## and Interface goes round, is low-passed and turned down while the character you play is out of play (heard from the
## side line) and dipped under a cue that must be read: your own hit, the referee's whistle at a round's or the match's
## end, the range's Time; and dulled while a flash dazzles you (SF1). The shape is a DuckEnvelope, eased every frame;
## the tick's events start it (on_tick). Setup also sets the occlusion buses' corners and levels from SoundConfig. Leaving play (this node leaving the tree: quit,
## a scene change mid-dip) leaves Field at 0 dB with its filter off, so menus are never muffled.

const BUS_FIELD := &"Field"
## Others' sounds heard through low cover (half) or a wall (full), under Effects and under Power (SP2).
const BUS_EFFECTS_HALF := &"EffectsHalf"
const BUS_EFFECTS_FULL := &"EffectsFull"
const BUS_POWER_HALF := &"PowerHalf"
const BUS_POWER_FULL := &"PowerFull"
## A shot heard through low cover or a wall, under Shots, so a map's echo answers it too (EC1).
const BUS_SHOTS_HALF := &"ShotsHalf"
const BUS_SHOTS_FULL := &"ShotsFull"
## The blocked share each occlusion bus stands for.
const HALF_SHARE := 0.5
const FULL_SHARE := 1.0

var envelope: DuckEnvelope = null
var _bus: int = -1
var _filter: AudioEffectFilter = null
## What the bus was last set to, so an unchanged frame writes nothing.
var _set_db: float = 0.0
var _set_hz: float = 0.0
var _set_on: bool = false


## The field's mix from `cfg`; the bus starts clear.
func setup(cfg: SoundConfig) -> void:
	name = "Mix"
	envelope = DuckEnvelope.new(cfg)
	_bus = AudioServer.get_bus_index(BUS_FIELD)
	if _bus < 0 or AudioServer.get_bus_effect_count(_bus) == 0:
		push_warning("SoundMix: no %s bus with a low-pass filter" % BUS_FIELD)
		_bus = -1
	else:
		_filter = AudioServer.get_bus_effect(_bus, 0) as AudioEffectFilter
	set_occlusion_buses(cfg)
	_clear()


## Reads the tick: whether the character `player_id` plays is out of play (until the match is over), and the events
## that dip the field.
func on_tick(state: GameState, player_id: int) -> void:
	var you := state.character(player_id)
	envelope.out = you != null and not Elimination.is_in_play(you) \
			and state.round_state.phase != RoundState.Phase.MATCH_OVER
	var cfg := envelope.cfg
	var events := state.events
	for i in events.count:
		var e := events.items[i]
		match e.kind:
			GameEvent.Kind.CHARACTER_HIT when e.target == player_id:
				envelope.dip(cfg.hit_dip_depth, cfg.hit_dip_attack, cfg.hit_dip_hold, cfg.hit_dip_release)
			GameEvent.Kind.DAZZLED when e.target == player_id:
				envelope.dip(cfg.flash_dip_depth, cfg.flash_dip_attack, e.reach * cfg.flash_dip_hold,
						cfg.flash_dip_release)
			GameEvent.Kind.ROUND_OVER, GameEvent.Kind.MATCH_OVER:
				_whistle_dip(cfg)
			GameEvent.Kind.CHALLENGE when e.actor == player_id and e.value == RangeChallenge.Cue.TIME:
				_whistle_dip(cfg)


func _process(delta: float) -> void:
	if envelope == null:
		return
	envelope.advance(delta)
	_apply(envelope.gain(), envelope.cutoff_hz(), not envelope.is_open())


func _exit_tree() -> void:
	_clear()


## The occlusion buses' low-pass corners and levels for their shares (`cfg`'s occlusion numbers).
static func set_occlusion_buses(cfg: SoundConfig) -> void:
	for bus: StringName in [BUS_EFFECTS_HALF, BUS_POWER_HALF, BUS_SHOTS_HALF]:
		_set_bus(bus, share_cutoff_hz(cfg, HALF_SHARE), share_gain(cfg, HALF_SHARE))
	for bus: StringName in [BUS_EFFECTS_FULL, BUS_POWER_FULL, BUS_SHOTS_FULL]:
		_set_bus(bus, share_cutoff_hz(cfg, FULL_SHARE), share_gain(cfg, FULL_SHARE))


## The low-pass corner (Hz) for a blocked `share` (0 open .. 1 a wall), on a log scale (the browser's occlusion).
static func share_cutoff_hz(cfg: SoundConfig, share: float) -> float:
	return cfg.occlusion_open_hz * pow(cfg.occlusion_muffled_hz / cfg.occlusion_open_hz, clampf(share, 0.0, 1.0))


## The level (linear) for a blocked `share`.
static func share_gain(cfg: SoundConfig, share: float) -> float:
	return lerpf(1.0, cfg.occlusion_muffled_gain, clampf(share, 0.0, 1.0))


static func _set_bus(bus: StringName, cutoff_hz: float, gain: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0 or AudioServer.get_bus_effect_count(i) == 0:
		push_warning("SoundMix: no %s bus with a low-pass filter" % bus)
		return
	var filter := AudioServer.get_bus_effect(i, 0) as AudioEffectFilter
	if filter != null:
		filter.cutoff_hz = cutoff_hz
	AudioServer.set_bus_volume_db(i, linear_to_db(gain))


func _whistle_dip(cfg: SoundConfig) -> void:
	envelope.dip(cfg.whistle_dip_depth, cfg.whistle_dip_attack, cfg.whistle_dip_hold, cfg.whistle_dip_release)


## Field at 0 dB with its filter off.
func _clear() -> void:
	if _bus < 0:
		return
	_set_db = 0.0
	_set_on = false
	AudioServer.set_bus_volume_db(_bus, 0.0)
	AudioServer.set_bus_effect_enabled(_bus, 0, false)


func _apply(gain: float, cutoff_hz: float, filter_on: bool) -> void:
	if _bus < 0:
		return
	var db := linear_to_db(gain)
	if db != _set_db:
		_set_db = db
		AudioServer.set_bus_volume_db(_bus, db)
	if filter_on != _set_on:
		_set_on = filter_on
		AudioServer.set_bus_effect_enabled(_bus, 0, filter_on)
	if filter_on and cutoff_hz != _set_hz and _filter != null:
		_set_hz = cutoff_hz
		_filter.cutoff_hz = cutoff_hz


## The field's level and low-pass (plain, no Node): out of play eases the level to out_gain and the corner from the
## open corner down to out_hz (log); a dip eases to its depth over its attack, holds, and eases back over its release.
## The level heard is the two multiplied. Times are the envelope's own, advanced by `advance`.
class DuckEnvelope:
	extends RefCounted

	## How close to the end of an ease counts as there: the filter turns off and the level is exactly 1.
	const SETTLED := 0.001

	var cfg: SoundConfig = null
	## Whether the character you play is out of play now.
	var out: bool = false
	## 0 in play .. 1 out, eased.
	var out_amount: float = 0.0
	## The dip's level now (linear, 1 none).
	var dip_gain: float = 1.0
	var _time: float = 0.0
	var _depth: float = 1.0
	var _until: float = 0.0
	var _attack: float = 0.0
	var _release: float = 0.0

	func _init(config: SoundConfig) -> void:
		cfg = config

	## Dips to `depth` within `attack` (s), held `hold` (s) from now, let back over `release` (s). While a dip is on
	## the deeper depth and the later end win; the newest attack and release shape it.
	func dip(depth: float, attack: float, hold: float, release: float) -> void:
		var on := _time < _until
		_depth = minf(_depth, depth) if on else depth
		_until = maxf(_until if on else 0.0, _time + hold)
		_attack = attack
		_release = release

	## Moves the envelope on by `dt` (s).
	func advance(dt: float) -> void:
		var left := dt
		if _time < _until:
			var held := minf(left, _until - _time)
			dip_gain = DuckEnvelope.ease_to(dip_gain, _depth, _attack, held)
			_time += held
			left -= held
		if left > 0.0:
			dip_gain = DuckEnvelope.ease_to(dip_gain, 1.0, _release, left)
			_time += left
			if dip_gain > 1.0 - SETTLED:
				dip_gain = 1.0
		out_amount = DuckEnvelope.ease_to(out_amount, 1.0 if out else 0.0, cfg.out_ease, dt)
		if not out and out_amount < SETTLED:
			out_amount = 0.0

	## The field's level (linear): out of play times the dip.
	func gain() -> float:
		return lerpf(1.0, cfg.out_gain, out_amount) * dip_gain

	## The field's low-pass corner (Hz).
	func cutoff_hz() -> float:
		return cfg.occlusion_open_hz * pow(cfg.out_hz / cfg.occlusion_open_hz, out_amount)

	## Whether the filter is fully open (off): in play and settled.
	func is_open() -> bool:
		return out_amount == 0.0

	## `from` eased towards `to` over `dt` (s) with time constant `tau` (s); none jumps there.
	static func ease_to(from: float, to: float, tau: float, dt: float) -> float:
		if tau <= 0.0:
			return to
		return to + (from - to) * exp(-dt / tau)
