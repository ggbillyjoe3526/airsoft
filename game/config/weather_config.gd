class_name WeatherConfig
extends Resource
## The weather a field plays in (PH1): how much of the match's breeze reaches it and how warm its air is, each map's own
## (data/maps.md's Wind and Air columns, MapCatalog.Entry). The air's temperature sets its density and viscosity, so
## every BB's drag and lift (AirModel.at), and how hard a gas replica shoots: the gas in its magazine pushes with its
## vapour pressure, which falls in the cold. Replicas are rated in BallisticsConfig.air_temperature's air, as on a site's
## chrono. Read by game/sim/simulation.gd (set_weather) and game/loadout/kit.gd (set_temperature).

## A night match in the open is this much colder (°C) than the map's Air; a hall or a station keeps its air.
@export var night_drop: float = 8.0
## The share of its rated muzzle energy a gas replica gains or loses per °C from the rated air: 1.2 %, which is 0.6 %
## of its speed, about 1 fps a °F on a 290 fps pistol (the players' rule of thumb for green gas).
@export var gas_energy_per_degree: float = 0.012
## The least and most of its rated energy a gas replica shoots with, however cold or hot the field.
@export var gas_energy_min: float = 0.5
@export var gas_energy_max: float = 1.4


## The air's temperature (°C) on a field whose map says `map_temperature`, by day or on a `cold_night` (a night match
## on a field open to the sky).
func temperature_at(map_temperature: float, cold_night: bool) -> float:
	return map_temperature - night_drop if cold_night else map_temperature


## The share of its rated muzzle energy a gas replica shoots with in air at `temperature` (°C), rated in air at `rated`.
func gas_energy_scale(temperature: float, rated: float) -> float:
	return clampf(1.0 + gas_energy_per_degree * (temperature - rated), gas_energy_min, gas_energy_max)
