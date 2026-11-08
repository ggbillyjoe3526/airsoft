class_name SimTuning
extends Resource
## Every tuning value the simulation reads, one typed Resource per area (docs/ARCHITECTURE.md › Contracts 6). The values
## live in each script's defaults, ported from the browser game where they were tuned by play; sim_tuning.tres is the
## instance the game loads, so a value changed in the inspector is saved there.

const DEFAULT_PATH := "res://game/config/sim_tuning.tres"

@export var ballistics: BallisticsConfig = BallisticsConfig.new()
@export var wind: WindConfig = WindConfig.new()
@export var ricochet: RicochetConfig = RicochetConfig.new()
@export var movement: MovementConfig = MovementConfig.new()
@export var vault: VaultConfig = VaultConfig.new()
@export var accuracy: AccuracyConfig = AccuracyConfig.new()
@export var body: BodyConfig = BodyConfig.new()
@export var hits: HitConfig = HitConfig.new()
@export var rounds: RoundConfig = RoundConfig.new()
@export var flag: FlagConfig = FlagConfig.new()
@export var overtime: OvertimeConfig = OvertimeConfig.new()
@export var targets: RangeConfig = RangeConfig.new()
@export var footsteps: FootstepConfig = FootstepConfig.new()
@export var replica_rules: ReplicaRulesConfig = ReplicaRulesConfig.new()
@export var nav: NavConfig = NavConfig.new()
@export var noise: NoiseConfig = NoiseConfig.new()
@export var pings: PingConfig = PingConfig.new()
@export var mag_share: MagShareConfig = MagShareConfig.new()
@export var grenades: GrenadeConfig = GrenadeConfig.new()
@export var doors: DoorConfig = DoorConfig.new()
@export var lasers: LaserConfig = LaserConfig.new()


## The game's tuning (sim_tuning.tres), or the built-in values with a warning if it can't be loaded.
static func load_default() -> SimTuning:
	var res := load(DEFAULT_PATH) as SimTuning
	if res == null:
		push_warning("SimTuning: %s could not be loaded; using the built-in values" % DEFAULT_PATH)
		return SimTuning.new()
	return res
