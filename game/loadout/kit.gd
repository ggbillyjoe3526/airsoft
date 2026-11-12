class_name Kit
extends RefCounted
## What a loadout plays as (the browser game's PlayerKit): each slot's replica as carried (its power source, parts and
## hop-up dial applied), the BB weight loaded, its paint and Glowing BBs choice, and whether the site limit cut its
## energy, and the bombs it carries. Made by LoadoutRules.carried; Armament takes the replicas and weights, the hand the
## bombs.

## ReplicaConfig.power of a replica driven by gas: the one kind the air's temperature changes (set_temperature).
const GAS := &"gas"

var replicas: Array[ReplicaConfig] = []
## The bomb in each grenade slot (LoadoutRules.bombs_of), for Grenades.Hand.picks.
var bombs: Array[Grenade.Kind] = []
var bb_weights: PackedFloat64Array = PackedFloat64Array()
var paints: Array[StringName] = []
## Each slot's Glowing BBs choice (WL8): how its BBs are drawn, never how they fly.
var glow_bbs: Array[Loadout.Glow] = []
## Each slot's fitted parts' Keys by part slot (Pool.PART_TABLES), for the models; a slot not listed is as it comes.
var parts: Array[Dictionary] = []  # each Dictionary[StringName, StringName]
## True for a slot whose power source would have pushed it past its site limit (the Loadout says so).
var capped: Array[bool] = []
## Each slot's muzzle energy (J) as built, before the site limit, in the air replicas are rated in, and the most its
## site lets it leave the barrel with at the BB weight loaded (LoadoutRules.carried): what set_temperature works from.
var energies: PackedFloat64Array = PackedFloat64Array()
var limits: PackedFloat64Array = PackedFloat64Array()
## Carries a dev item: the match stays off the record (docs/DECISIONS.md › Content tags and dev content). A light
## counts only where it is fitted, at night (`light_dev`).
var dev: bool = false
## Each slot's weapon light as fitted at night (Torch.Light; null: none), and whether one of them is a dev item.
var lights: Array[Torch.Light] = []
var light_dev: bool = false


func size() -> int:
	return replicas.size()


## Sets each gas replica's muzzle energy for a field whose air is at `temperature` °C (PH1): `weather`'s share of its
## energy as built (rated in air at `rated` °C), still under its site limit, as the site's chrono would read it on the
## day. Electric and spring replicas shoot the same in any weather. Call it before the kit's replicas go into a match;
## calling it again for another field starts from the energy as built.
func set_temperature(weather: WeatherConfig, temperature: float, rated: float) -> void:
	var share := weather.gas_energy_scale(temperature, rated)
	for i in mini(replicas.size(), mini(energies.size(), limits.size())):
		if replicas[i].power == GAS:
			replicas[i].muzzle_energy = minf(energies[i] * share, limits[i])


## The lights each slot carries on a field lit by a preset with `night` as its flag: by day a weapon light does nothing
## (only its lens would glow), so none is fitted and the kit plays exactly as one without (the browser's partsUnder).
func lights_for(night: bool) -> Array[Torch.Light]:
	var out: Array[Torch.Light] = []
	if night:
		out.assign(lights)
	return out


## Each slot's fitted parts' Keys for the models under a preset with `night` as its flag: by day without the light,
## which isn't fitted then (`lights_for`). The day's are copies; the night's are `parts` itself.
func parts_under(night: bool) -> Array[Dictionary]:
	if night:
		return parts
	var out: Array[Dictionary] = []
	for keys: Dictionary in parts:
		var day := keys.duplicate()
		day.erase(Pool.LIGHT_SLOT)
		out.append(day)
	return out


## Whether this kit, played under a preset with `night` as its flag, carries a dev item (its light only at night).
func dev_under(night: bool) -> bool:
	return dev or (night and light_dev)
