class_name LoadoutRules
extends RefCounted
## What a loadout may hold and what it plays as (the browser game's pool/loadoutModel.ts and pool/kit.ts): the
## replicas on offer, each replica's setup as it comes, the edits the Loadout makes (each checked and snapped), and the
## kit a loadout is carried as. Pure: the pool, stats.md and the replica rules are handed in.
##
## Gear that is saved but not on offer now (a dev replica with Dev content off, or one not unlocked yet) stays picked and
## plays as the slot's default (docs/DECISIONS.md › Loadout). Items are locked only while `levels` is set (the menus and
## your own kit: `follow_progress`); without it, as for the bots, everything is unlocked.

var pool: Pool = null
var stats: ReplicaStats = null
var rules: ReplicaRulesConfig = null
## The grenade slots and the default pick (BP8).
var bombs: GrenadeConfig = GrenadeConfig.new()
## Dev content on: dev items are offered too.
var dev_content: bool = false
## The levels and the player's progress, read live (a Reset level shows at once); null: everything is unlocked
## (levelling off, or no player's progress applies).
var levels: LevelTable = null
var progress: Progress = null
var _configs: Dictionary[StringName, ReplicaConfig] = {}


func _init(pool_in: Pool, stats_in: ReplicaStats, rules_in: ReplicaRulesConfig) -> void:
	pool = pool_in
	stats = stats_in
	rules = rules_in


## The rules as shipped: data/pool.md, data/stats.md and the default replica rules.
static func standard() -> LoadoutRules:
	var s := ReplicaStats.read_file()
	s.warn()
	var t := SimTuning.load_default()
	var out := LoadoutRules.new(Pool.shared(), s, t.replica_rules)
	out.bombs = t.grenades
	return out


## Locks what `progress` hasn't unlocked, unless `levelling_off` (Settings › Dev › Disable levelling) unlocks it all.
func follow_progress(progress_in: Progress, levelling_off: bool) -> void:
	levels = null if levelling_off else progress_in.table
	progress = progress_in


## True if item `id` isn't unlocked yet (an item no level unlocks is locked for good).
func is_locked(id: String) -> bool:
	return levels != null and not progress.has(id)


## The level that unlocks item `id`, or -1 if none does.
func unlock_level(id: String) -> int:
	return levels.unlock_level(id) if levels != null else -1


## The replicas a player can carry now, in pool order: those the game can play (a built-in config), public ones and,
## with Dev content on, dev ones.
func offered() -> Array[Pool.Item]:
	var out: Array[Pool.Item] = []
	for it in pool.replicas:
		if (dev_content or not it.is_dev()) and config(it) != null:
			out.append(it)
	return out


func is_offered(id: String) -> bool:
	for it in offered():
		if it.id == id:
			return true
	return false


## On offer and unlocked: it can be picked and plays as it is.
func is_available(id: String) -> bool:
	return is_offered(id) and not is_locked(id)


## The replica's stats as it comes (stats.md over the built-in config), or null if the game can't play it.
func config(item: Pool.Item) -> ReplicaConfig:
	if item == null or item.kind != Pool.Kind.REPLICA:
		return null
	if not _configs.has(item.key):
		_configs[item.key] = stats.replica_config(item.key)
	return _configs[item.key]


## The replica the slot carries for a new player (ReplicaStats.DEFAULT_LOADOUT), or "" if the pool lacks it.
func default_id(slot: Loadout.Slot) -> String:
	var it := pool.replica_by_key(ReplicaStats.DEFAULT_LOADOUT[slot])
	return it.id if it != null else ""


## A new player's loadout: the default replicas, each as it comes.
func default_loadout(loadout_name: String) -> Loadout:
	var l := Loadout.new()
	l.name = loadout_name
	for slot: Loadout.Slot in [Loadout.Slot.PRIMARY, Loadout.Slot.SECONDARY]:
		l.equipped[slot] = default_id(slot)
	return l


## `item` as it comes: its factory BB weight and dial, its class's colour, the first power source that fits and the
## parts it comes with (pool.md › Comes with; one still locked stays off until it is unlocked, as any part).
func default_tune(item: Pool.Item) -> ReplicaTune:
	var t := ReplicaTune.new()
	var r := config(item)
	if r == null:
		return t
	t.bb_weight = clampf(r.bb_weight, rules.bb_weight_min, rules.bb_weight_max)
	t.hop_up = clampf(r.hop_up_dial, rules.hop_up_min_dial, rules.hop_up_max_dial)
	t.paint = ReplicaSchemes.OWN if ReplicaSchemes.OWN_COLOURS.has(item.key) \
			else ReplicaSchemes.default_paint(r.site_class)
	# A public replica comes with a public power source; a dev one may come with a dev one (the Sniper Rifle's springs).
	var powers := pool.powers_for(item, item.is_dev())
	t.power_id = powers[0].id if not powers.is_empty() else ""
	for pt in pool.comes_with(item):
		t.parts[pt.slot] = pt.id
	return t


## The setup of replica `id` in `loadout`: the one saved, else as it comes.
func tune_of(loadout: Loadout, id: String) -> ReplicaTune:
	if loadout.tunes.has(id):
		return loadout.tunes[id]
	return default_tune(pool.item(id))


## Carries replica `id` in `slot`; one already in the other slot swaps places. False if it isn't on offer or unlocked.
func equip(loadout: Loadout, slot: Loadout.Slot, id: String) -> bool:
	if not is_available(id):
		return false
	var other := 1 - int(slot)
	if loadout.equipped[other] == id:
		loadout.equipped[other] = loadout.equipped[slot]
	loadout.equipped[slot] = id
	return true


## Loads `grams` into replica `id`, kept within the range and snapped to its step; returns the weight set.
func set_bb_weight(loadout: Loadout, id: String, grams: float) -> float:
	var t := _editable(loadout, id)
	t.bb_weight = snap_bb_weight(grams)
	return t.bb_weight


## Sets replica `id`'s hop-up dial, kept within its range and snapped to the dial's notches; returns the dial set.
func set_hop_up(loadout: Loadout, id: String, dial: float) -> float:
	var t := _editable(loadout, id)
	t.hop_up = snap_hop_up(dial)
	return t.hop_up


## Paints replica `id`; false (and nothing changed) for an unknown paint or a replica that keeps its own colours.
func set_paint(loadout: Loadout, id: String, paint: StringName) -> bool:
	var it := pool.item(id)
	if it == null or ReplicaSchemes.OWN_COLOURS.has(it.key) or not ReplicaSchemes.is_paint(paint):
		return false
	_editable(loadout, id).paint = paint
	return true


## Fits power source `power_id` to replica `id`; false (and nothing changed) if it doesn't fit, isn't on offer or isn't
## unlocked.
func set_power(loadout: Loadout, id: String, power_id: String) -> bool:
	var it := pool.item(id)
	var pw := pool.item(power_id)
	if it == null or pw == null or pw.kind != Pool.Kind.POWER or not pool.powers_for(it, dev_content).has(pw) \
			or is_locked(power_id):
		return false
	_editable(loadout, id).power_id = power_id
	return true


## The parts for `slot` replica `id` can take now, in pool order (dev ones only with Dev content on).
func parts_for(id: String, slot: StringName) -> Array[Pool.Item]:
	var it := pool.item(id)
	if it == null or it.kind != Pool.Kind.REPLICA:
		return []
	return pool.parts_for(it, slot, dev_content)


## Fits part `part_id` to replica `id` in `slot`, or takes the slot's part off for "" (as it comes); false (and nothing
## changed) if the part isn't one for that slot that fits, is on offer and is unlocked.
func set_part(loadout: Loadout, id: String, slot: StringName, part_id: String) -> bool:
	if not Pool.PART_TABLES.values().has(slot):
		return false
	if part_id == "":
		var it := pool.item(id)
		if it == null or it.kind != Pool.Kind.REPLICA:
			return false
		_editable(loadout, id).parts.erase(slot)
		return true
	if not parts_for(id, slot).has(pool.item(part_id)) or is_locked(part_id):
		return false
	_editable(loadout, id).parts[slot] = part_id
	return true


func snap_bb_weight(grams: float) -> float:
	var g := clampf(grams, rules.bb_weight_min, rules.bb_weight_max)
	return snappedf(g, rules.bb_weight_step)


func snap_hop_up(dial: float) -> float:
	var d := clampf(dial, rules.hop_up_min_dial, rules.hop_up_max_dial)
	return clampf(snappedf(d, rules.hop_up_dial_step), rules.hop_up_min_dial, rules.hop_up_max_dial)


## Puts back the default for every saved value that won't do (an unknown replica, a weight out of range, a power
## source that doesn't fit), each listed. Replicas not on offer now stay: they play as the default (carried).
func clean(loadout: Loadout) -> Array[String]:
	var out: Array[String] = []
	for slot: Loadout.Slot in [Loadout.Slot.PRIMARY, Loadout.Slot.SECONDARY]:
		var id := loadout.equipped[slot]
		var it := pool.item(id)
		if it == null or it.kind != Pool.Kind.REPLICA:
			out.append("%s: slot %d held \"%s\", no replica: the default" % [loadout.name, slot + 1, id])
			loadout.equipped[slot] = default_id(slot)
	if loadout.equipped[0] == loadout.equipped[1]:
		out.append("%s: the same replica in both slots: the default secondary" % loadout.name)
		loadout.equipped[1] = default_id(Loadout.Slot.SECONDARY) if loadout.equipped[0] != default_id(
				Loadout.Slot.SECONDARY) else default_id(Loadout.Slot.PRIMARY)
	for id: String in loadout.tunes.keys():
		var it := pool.item(id)
		if it == null or it.kind != Pool.Kind.REPLICA:
			out.append("%s: a setup for \"%s\", no replica: dropped" % [loadout.name, id])
			loadout.tunes.erase(id)
			continue
		var t := loadout.tunes[id]
		var fallback := default_tune(it)
		if is_nan(t.bb_weight) or not is_equal_approx(t.bb_weight, snap_bb_weight(t.bb_weight)):
			out.append("%s: %s's BB weight %s won't do: as it comes" % [loadout.name, it.display_name, t.bb_weight])
			t.bb_weight = fallback.bb_weight
		if is_nan(t.hop_up) or not is_equal_approx(t.hop_up, snap_hop_up(t.hop_up)):
			out.append("%s: %s's hop-up %s won't do: as it comes" % [loadout.name, it.display_name, t.hop_up])
			t.hop_up = fallback.hop_up
		var own := ReplicaSchemes.OWN_COLOURS.has(it.key)
		if (own and t.paint != ReplicaSchemes.OWN) or (not own and not ReplicaSchemes.is_paint(t.paint)):
			out.append("%s: %s's colour \"%s\" won't do: as it comes" % [loadout.name, it.display_name, t.paint])
			t.paint = fallback.paint
		var pw := pool.item(t.power_id)
		if t.power_id != fallback.power_id and (pw == null or pw.kind != Pool.Kind.POWER or not pool.fits(pw, it)):
			out.append("%s: %s's power source \"%s\" won't do: as it comes" % [loadout.name, it.display_name,
					t.power_id])
			t.power_id = fallback.power_id
		for slot: StringName in t.parts.keys():
			var pt := pool.item(t.parts[slot])
			if pt == null or pt.kind != Pool.Kind.PART or pt.slot != slot or not pool.fits(pt, it):
				out.append("%s: %s's %s \"%s\" won't do: as it comes" % [loadout.name, it.display_name, slot,
						t.parts[slot]])
				t.parts.erase(slot)
	return out


## The bomb in each of `loadout`'s grenade slots: its pick, or the default pick where it has none that will do.
func bombs_of(loadout: Loadout) -> Array[Grenade.Kind]:
	return bombs.carried_picks(loadout.bombs)

## Puts `kind` (a smoke or a flash) in `loadout`'s grenade slot `slot`; false when it was there already or won't do.
func set_bomb(loadout: Loadout, slot: int, kind: Grenade.Kind) -> bool:
	var picks := bombs_of(loadout)
	if slot < 0 or slot >= picks.size() or (kind != Grenade.Kind.SMOKE and kind != Grenade.Kind.FLASH) \
			or picks[slot] == kind:
		return false
	picks[slot] = kind
	loadout.bombs = picks
	return true


## What `loadout` plays as: each slot's replica (the slot's default if it isn't on offer or unlocked now) with its power
## source (the default one if it isn't), its parts (as it comes where a part isn't) and dial, its weapon light (fitted
## only at night, Kit.lights_for), and its BB weight and paint, and its bombs (`bombs_of`). A slot whose replica the game
## can't play is left out.
func carried(loadout: Loadout) -> Kit:
	var kit := Kit.new()
	kit.bombs = bombs_of(loadout)
	var used := PackedStringArray()
	for slot: Loadout.Slot in [Loadout.Slot.PRIMARY, Loadout.Slot.SECONDARY]:
		var id := loadout.equipped[slot]
		if not is_available(id) or used.has(id):
			id = default_id(slot) if not used.has(default_id(slot)) else default_id(1 - int(slot) as Loadout.Slot)
		var it := pool.item(id)
		var base := config(it)
		if base == null or used.has(id):
			continue
		used.append(id)
		var t := tune_of(loadout, id)
		var power_id := t.power_id
		var pw := pool.item(power_id)
		if pw == null or not pool.powers_for(it, dev_content).has(pw) or is_locked(power_id):
			power_id = default_tune(it).power_id
			pw = pool.item(power_id)
		var r := base.duplicate() as ReplicaConfig
		var p := stats.power(power_id)
		var fitted := _fitted(it, t)
		var energy := base.muzzle_energy * (1.0 + p.energy) * _apply_parts(r, fitted)
		var limit := stats.energy_limit(base.site_class)
		r.muzzle_energy = minf(energy, limit)
		r.fire_rate = base.fire_rate * (1.0 + p.fire_rate)
		r.recoil_deg = base.recoil_deg * (1.0 + p.recoil)
		r.hop_up_dial = t.hop_up
		var keys: Dictionary[StringName, StringName] = {}
		var light: Torch.Light = null
		for part_slot: StringName in fitted:
			var pt := fitted[part_slot]
			keys[part_slot] = pt.key
			if part_slot == Pool.LIGHT_SLOT:
				# Fitted only at night (Kit.lights_for): a dev torch makes only a night match dev.
				light = Torch.Light.of(pt.key, stats.parts.part(part_slot, pt.key))
				kit.light_dev = kit.light_dev or pt.is_dev()
			else:
				kit.dev = kit.dev or pt.is_dev()
		kit.replicas.append(r)
		kit.bb_weights.append(t.bb_weight)
		kit.paints.append(t.paint)
		kit.glow_bbs.append(loadout.glow_of(id))
		kit.parts.append(keys)
		kit.lights.append(light)
		kit.capped.append(energy > limit)
		kit.dev = kit.dev or it.is_dev() or (pw != null and pw.is_dev())
	return kit


## The parts of `t` that `it` takes now: slot → Pool.Item.
func _fitted(it: Pool.Item, t: ReplicaTune) -> Dictionary[StringName, Pool.Item]:
	var out: Dictionary[StringName, Pool.Item] = {}
	for slot: StringName in t.parts:
		var pt := pool.item(t.parts[slot])
		if pt != null and pt.slot == slot and pool.parts_for(it, slot, dev_content).has(pt) and not is_locked(pt.id):
			out[slot] = pt
	return out


## Lays `fitted` over `r` (the browser game's handlingOf and kit): the magazine's capacity, count, reload and draw; the
## handling of the grip, barrel and muzzle part on the draw and the sight's raise; the optic's zoom and raise; the grip's
## shake; the laser's and barrel's spread; rattles; how far shots are heard. Returns what the barrel and muzzle part
## multiply the energy by (before the site limit).
func _apply_parts(r: ReplicaConfig, fitted: Dictionary[StringName, Pool.Item]) -> float:
	var optic := _part(fitted, &"optic")
	var grip := _part(fitted, &"grip")
	var laser := _part(fitted, &"laser")
	var mag := _part(fitted, &"magazine")
	var barrel := _part(fitted, &"barrel")
	var muzzle := _part(fitted, &"muzzle")
	# A front-heavy barrel or muzzle part is slower to bring up and to raise to your eye, like a heavier grip.
	var handling := grip.handling * barrel.handling * muzzle.handling
	r.mag_size = maxi(1, roundi(r.mag_size * mag.capacity))
	r.mags = maxi(1, r.mags + mag.carried)
	r.reload_time *= mag.reload
	r.draw_time *= mag.draw * handling
	r.raise_scale = handling * optic.raise
	# An optic with no stats.md row has no zoom of its own: the iron sights' stays.
	r.aim_zoom = optic.zoom if fitted.has(&"optic") and stats.parts.has(&"optic", fitted[&"optic"].key) else 0.0
	r.zoom_in_glass = optic.in_glass and r.aim_zoom > 0.0
	# Only a scope's glass shows a turned zoom (ReplicaView): a whole-view optic stays fixed.
	r.aim_zoom_to = optic.zoom_to if r.zoom_in_glass and optic.zoom_to > r.aim_zoom else 0.0
	r.shake_scale = grip.shake
	r.spread_deg *= laser.spread * barrel.spread
	r.rattles = mag.rattles
	r.heard_scale = muzzle.heard
	r.muffled = muzzle.heard < 1.0
	return (1.0 + barrel.energy) * (1.0 + muzzle.energy)


func _part(fitted: Dictionary[StringName, Pool.Item], slot: StringName) -> PartStats.Part:
	return stats.parts.part(slot, fitted[slot].key) if fitted.has(slot) else stats.parts.part(slot, &"")


## The setup of replica `id` to edit: the saved one, made from the default the first time.
func _editable(loadout: Loadout, id: String) -> ReplicaTune:
	if not loadout.tunes.has(id):
		loadout.tunes[id] = default_tune(pool.item(id))
	return loadout.tunes[id]
