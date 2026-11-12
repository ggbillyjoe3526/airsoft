class_name GameState
extends RefCounted
## The whole simulation's state as plain data (the browser game's sim/state.ts). Presentation reads it and the tick's
## events; it never writes them.

var tick: int = 0
## Seconds of simulated time.
var time: float = 0.0
## The seed the match was started with: the same seed and the same commands replay the same match.
var match_seed: int = 0
var characters: Array[Character] = []
var bbs: BBPool = null
## What happened during the last tick (shots, hits, rounds). Cleared at the start of every tick.
var events: SimEvents = SimEvents.new()
## The match's own random stream: shot spread and anything else random in the rules.
var rng: RandomNumberGenerator = null
var round_state: RoundState = null
## The practice range's targets (RangeTargets.create from the map's specs); empty in a match.
var targets: Array[RangeTarget] = []
## The practice range's timed challenge on those targets: off until switched on (RangeChallenge.set_on).
var challenge: RangeChallenge = RangeChallenge.new()
## Matches started on this state (a rematch is the next), and the breeze of the one being played: still air until the
## first starts.
var match_number: int = 0
var wind: Wind = null
## The field's weather (PH1, Simulation.set_weather before the match starts): the share of the breeze that reaches it
## (0 indoors), its air's temperature (°C) and the air BBs fly through at that temperature. Until set: the whole
## breeze, in the air replicas are rated in (BallisticsConfig.air_temperature).
var wind_share: float = 1.0
var air_temperature: float = 0.0
var air: AirModel = null
## The magazines in the air (MagShare), a pool of MagShareConfig.max_tosses made once.
var mag_tosses: Array[MagShare.Toss] = []
## The smoke and flash bombs thrown (Grenades, SF1), a pool of GrenadeConfig.max_grenades made once.
var grenades: Array[Grenade] = []
## The level's hinged doors (Doors, DO1): sized to them as each match starts.
var doors: DoorState = DoorState.new()
## The level's lifts (Lifts, MT2): sized to them as each match starts.
var lifts: LiftState = LiftState.new()
## Until when each of the level's noisy props (PropNoise, by index) stays quiet after a knock or a ring (s, as `time`):
## grown to one per prop on the first tick.
var prop_quiet: PackedFloat64Array = PackedFloat64Array()
## The Dev settings that change play (DevCheats.apply writes them); the match is on a map or with content tagged dev;
## and the match stays out of the records (dev content, or a cheat on at any time since it started).
var cheats: DevCheats = DevCheats.new()
var dev_content: bool = false
var off_record: bool = false


func _init(seed_value: int = 0, tuning: SimTuning = null) -> void:
	var t := tuning if tuning != null else SimTuning.new()
	match_seed = seed_value & Seeds.MASK_32
	rng = Seeds.stream(match_seed)
	bbs = BBPool.new(t.ballistics.max_bbs)
	round_state = RoundState.new()
	wind = Wind.still(t.wind)
	air_temperature = t.ballistics.air_temperature
	air = AirModel.of(t.ballistics)
	mag_tosses = MagShare.make_tosses(t.mag_share.max_tosses)
	grenades = Grenades.make_pool(t.grenades.max_grenades)


## The character with `character_id`, or null.
func character(character_id: int) -> Character:
	for c in characters:
		if c.id == character_id:
			return c
	return null
