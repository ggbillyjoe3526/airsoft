class_name FieldAir
extends RefCounted
## The air a match on the Match page's pick plays in (PH1), for the Loadout's figures (AUD2, owner 2026-11-14): as
## PlaySession sets the match's weather, the field's Air (data/maps.md, MapCatalog) cooled by WeatherConfig.night_drop
## on a night match on a field the breeze reaches, or the rated air (BallisticsConfig.air_temperature) for a map not
## listed. Plain data; the map's presets are read from its file once a session (MapData.presets_in).

## The field's name ("Woodland"), and whether the match is played at night.
var map_name: String = ""
var night: bool = false
## The match's air and the replicas' rated air (°C).
var temperature: float = 20.0
var rated: float = 20.0

## The air model this air makes (air), made the first time it is asked for.
var _air: AirModel = null

## The presets each map's file offers, read once.
static var _presets: Dictionary[String, Array] = {}


## The air of a match on `map_id` lit by the pick `lighting_pick` (MatchPicks.lighting; Dev › Time of day `forced`),
## with `tuning`'s ballistics and weather and `play`'s night preset.
static func of(map_id: String, lighting_pick: StringName, forced: StringName, tuning: SimTuning,
		play: PlayTuning) -> FieldAir:
	var f := FieldAir.new()
	f.rated = tuning.ballistics.air_temperature
	f.temperature = f.rated
	var listed := MapCatalog.shared().find(map_id)
	if listed == null:
		return f
	f.map_name = listed.display_name
	if not _presets.has(map_id):
		_presets[map_id] = MapData.presets_in(map_id)
	var m := MapData.new()
	m.lighting_presets.assign(_presets[map_id])
	var played := m.preset_played(lighting_pick, forced)
	f.night = play.night_lighting.night and played == play.night_lighting.id
	f.temperature = tuning.weather.temperature_at(listed.air_or(f.rated), f.night and listed.wind > 0.0)
	return f


## Whether the field's air is other than the rated (the Loadout then says it).
func applies() -> bool:
	return not is_equal_approx(temperature, rated)


## The air model of `cfg` in this air (AirModel.of itself in the rated air), made once.
func air(cfg: BallisticsConfig) -> AirModel:
	if _air == null:
		_air = AirModel.at(cfg, temperature)
	return _air


## The share of its rated energy a gas replica shoots with here (WeatherConfig.gas_energy_scale).
func gas_share(weather: WeatherConfig) -> float:
	return weather.gas_energy_scale(temperature, rated)
