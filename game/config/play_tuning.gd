class_name PlayTuning
extends Resource
## Everything the playing view reads that isn't a rule: the mouse, the camera, the replica in hand, effects, sound and
## the HUD, one typed Resource each (docs/ARCHITECTURE.md › Contracts 6). play_tuning.tres is the instance the game
## loads.

const DEFAULT_PATH := "res://game/config/play_tuning.tres"

@export var controls: ControlsConfig = ControlsConfig.new()
@export var view: ViewConfig = ViewConfig.new()
@export var viewmodel: ViewModelConfig = ViewModelConfig.new()
@export var effects: EffectsConfig = EffectsConfig.new()
@export var sound: SoundConfig = SoundConfig.new()
@export var hud: HudConfig = HudConfig.new()
@export var map_style: MapStyle = MapStyle.new()
## The day preset and the night (night_lighting.tres); a map plays one of them (LightingConfig.for_map).
@export var lighting: LightingConfig = LightingConfig.new()
@export var night_lighting: LightingConfig = LightingConfig.new()
@export var baked_light: BakeConfig = BakeConfig.new()
@export var skyline: SkylineConfig = SkylineConfig.new()
## An indoor field's roof (DR1: Depot's hall).
@export var roof: RoofConfig = RoofConfig.new()
## A station's lifts (MT2: Subway's).
@export var lifts: LiftViewConfig = LiftViewConfig.new()
## A station's ticket gates' paddle doors (SM3: Subway's).
@export var gate_paddles: GatePaddlesConfig = GatePaddlesConfig.new()
## A station's small fittings along its rooms' walls, floors and ceilings (SD2: Subway's).
@export var station_detail: StationDetailConfig = StationDetailConfig.new()
@export var woods: WoodsConfig = WoodsConfig.new()
## The floors' worn marks (WM1, WearMarks).
@export var marks: MarksConfig = MarksConfig.new()
## What a field's lights stand on or hang from (WG4: Woodland's campfires and lanterns).
@export var light_fixtures: LightFixturesConfig = LightFixturesConfig.new()
@export var teams: TeamConfig = TeamConfig.new()
@export var debug_view: DebugViewConfig = DebugViewConfig.new()
@export var flag: FlagViewConfig = FlagViewConfig.new()
## Plant The Bomb's prop and sites as drawn (PB1).
@export var plant: PlantViewConfig = PlantViewConfig.new()
@export var range_view: RangeViewConfig = RangeViewConfig.new()
@export var minimap: MinimapConfig = MinimapConfig.new()
@export var figures: FigureConfig = FigureConfig.new()
## How a map naming a site dress is drawn (DD1: Depot's temporary dress).
@export var site_look: SiteLook = SiteLook.new()
## How a map naming a station dress is drawn (MT3: Subway's CC0 photo sets).
@export var station_look: StationLook = StationLook.new()
## A station's lamps and extras (SM5: Subway's tunnel lamps, signs, posters, clocks, bins), StationFixtures.
@export var station_fixtures: StationFixturesConfig = StationFixturesConfig.new()
## The game's look on every map: the shared light, the picture's grade and the graphics effects (docs/ART.md).
@export var look: LookConfig = LookConfig.new()
## Seconds the match's summary stays up before the next match starts (a click starts it sooner); the wait starts once
## the last round's table makes way.
@export var rematch_delay: float = 15.0
## Out, a press of the trigger skips the round (MC1): the rest is played out as fast as the computer allows, this many
## milliseconds of ticks each rendered frame until it ends. The cover is still, so a long frame costs nothing seen: most
## of the time goes to ticks (a Woodland tick of ten bots is a few ms).
@export var skip_budget_ms: float = 50.0
## Seconds out of the round before a press of the trigger can skip it (owner, 2026-11-03: the clicks of the fight that
## put you out skipped the round at once). The skip hint shows once it can.
@export var skip_grace: float = 1.5
## The countdown at every match round's start (s: 3, 2, 1, then GO! and the whistle; BP8). Everyone is held still and the
## clock waits; 0 for none. The range has none. Put into the round tuning (RoundConfig.start_countdown) as a match loads.
@export var round_countdown: float = 3.0
## With the loading screen's Continue (MC1): the longest (s) the shaders' warm-up may keep it hidden after the match is
## first drawn.
@export var go_fallback: float = 10.0


## The game's play tuning, or the built-in values with a warning if it can't be loaded.
static func load_default() -> PlayTuning:
	var res := load(DEFAULT_PATH) as PlayTuning
	if res == null:
		push_warning("PlayTuning: %s could not be loaded; using the built-in values" % DEFAULT_PATH)
		return PlayTuning.new()
	return res
