class_name LoadoutFacts
extends RefCounted
## What the Loadout screens show about the loadout carried: for each slot the replica it plays (LoadoutRules.carried, so a
## replica not on offer shows as the slot's default, as it plays), its setup, its words ("Cobalt · 0.25 g · LiPo") and the
## Performance sheet against the replica as it comes, both in the air of the field the Match page has picked (`field`,
## AUD2: a gas replica's energy and every BB's flight; the rated 20 °C without one). Read-only: edits go through
## LoadoutRules and SavedLoadouts. Call `refresh` after any change.

const SLOTS: Array[Loadout.Slot] = [Loadout.Slot.PRIMARY, Loadout.Slot.SECONDARY]
const SLOT_KEYS: Array[String] = ["LOADOUT_PRIMARY", "LOADOUT_SECONDARY"]

var saved: SavedLoadouts = null
var tuning: SimTuning = null
var hud: HudConfig = null
## The view's zoom aiming through iron sights (a replica with an optic has its own).
var iron_zoom: float = 1.0
## The air the figures are measured in (null: the rated air), set_field.
var field: FieldAir = null

var _kit: Kit = null
## Each slot's pool item, and the replicas as they come, measured once each (they don't change while the screen is open).
var _items: Array[Pool.Item] = [null, null]
var _comes_by_key: Dictionary[StringName, LoadoutPerformance.Figures] = {}


func _init(saved_in: SavedLoadouts, sim: SimTuning = null, hud_in: HudConfig = null) -> void:
	saved = saved_in
	tuning = sim if sim != null else SimTuning.load_default()
	var play := PlayTuning.load_default()
	hud = hud_in if hud_in != null else play.hud
	iron_zoom = play.view.aim_zoom
	refresh()


func rules() -> LoadoutRules:
	return saved.rules


func pool() -> Pool:
	return saved.rules.pool


## Measures in `f`'s air from now on (null: the rated air); the figures as they come are measured again.
func set_field(f: FieldAir) -> void:
	field = f
	_comes_by_key.clear()
	refresh()


## Whether the figures are in a field's own air, other than the rated.
func in_field_air() -> bool:
	return field != null and field.applies()


## The air the figures are measured in: the field's, or null for the rated (AirModel.of).
func air() -> AirModel:
	return field.air(tuning.ballistics) if in_field_air() else null


## The field and its air as the figures say it ("Woodland at night, 8 °C"; "" in the rated air).
func field_words() -> String:
	if not in_field_air():
		return ""
	var where := TranslationServer.translate("LOADOUT_FIELD_NIGHT") % field.map_name if field.night else field.map_name
	return TranslationServer.translate("LOADOUT_FIELD_AIR") % [where, roundi(field.temperature)]


## The Performance sheet's line for `replica_name`, the field's air with it when the figures are in it.
func sheet_sub(replica_name: String) -> String:
	var line := TranslationServer.translate("LOADOUT_SHEET_SUB") % replica_name
	if in_field_air():
		line += TranslationServer.translate("LOADOUT_SHEET_FIELD") % field_words()
	return line


## Reads the carried loadout again.
func refresh() -> void:
	_kit = saved.rules.carried(saved.carried())
	if in_field_air():
		_kit.set_temperature(tuning.weather, field.temperature, field.rated)
	for slot in SLOTS:
		_items[slot] = null
		if slot < _kit.size():
			_items[slot] = saved.rules.pool.replica_by_key(_kit.replicas[slot].id)


## True if `slot` carries a replica the game can play.
func has(slot: Loadout.Slot) -> bool:
	return _items[slot] != null


func item(slot: Loadout.Slot) -> Pool.Item:
	return _items[slot]


## The replica as carried: its power source and dial applied.
func replica(slot: Loadout.Slot) -> ReplicaConfig:
	return _kit.replicas[slot]


## The replica as it comes.
func as_it_comes(slot: Loadout.Slot) -> ReplicaConfig:
	return saved.rules.config(_items[slot])


func tune(slot: Loadout.Slot) -> ReplicaTune:
	return saved.rules.tune_of(saved.carried(), _items[slot].id)


func capped(slot: Loadout.Slot) -> bool:
	return _kit.capped[slot]


## The slot a replica is carried in, or -1.
func slot_of(id: String) -> int:
	for slot in SLOTS:
		if _items[slot] != null and _items[slot].id == id:
			return slot
	return -1


## The paint as shown: "Cobalt", or a plain colour's name under Realistic colours; "Own colours" for a replica that keeps them.
func paint_name(slot: Loadout.Slot, realistic: bool) -> String:
	var paint := tune(slot).paint
	if paint == ReplicaSchemes.OWN:
		return TranslationServer.translate("LOADOUT_OWN_COLOURS")
	return ReplicaSchemes.paint_name(paint, realistic)


## The power source as shown ("11.1 V LiPo"); "" for a replica with its power built in.
func power_name(slot: Loadout.Slot) -> String:
	var pw := saved.rules.pool.item(tune(slot).power_id)
	return power_label(pw) if pw != null else ""


static func power_label(pw: Pool.Item) -> String:
	return pw.display_name


## "0.25 g · hop-up 65 %", the BBs part's line.
func bbs_line(slot: Loadout.Slot) -> String:
	var t := tune(slot)
	return TranslationServer.translate("LOADOUT_BBS_LINE") % [t.bb_weight, roundi(t.hop_up * 100.0)]


## The parts `item`'s setup fits now, as the models and the tabs show them: part slot -> the part's Key. A saved part that
## doesn't fit, or a dev part with Dev content off, is not here (it plays as not fitted).
func fitted_keys(item: Pool.Item) -> Dictionary:
	var out: Dictionary = {}
	for part_slot: StringName in Pool.PART_TABLES.values():
		var pt := fitted_part(item, part_slot)
		if pt != null:
			out[part_slot] = pt.key
	return out


## The fitted part of `item` in `part_slot`, or null.
func fitted_part(item: Pool.Item, part_slot: StringName) -> Pool.Item:
	var t := saved.rules.tune_of(saved.carried(), item.id)
	var pt := pool().item(t.parts.get(part_slot, ""))
	return pt if pt != null and saved.rules.parts_for(item.id, part_slot).has(pt) else null


## The sheet for `slot`: the replica as carried against as it comes.
func sheet(slot: Loadout.Slot) -> LoadoutPerformance.Sheet:
	var r := replica(slot)
	var base := as_it_comes(slot)
	var t := tune(slot)
	var carried := LoadoutPerformance.measure(r, t.bb_weight, r.hop_up_dial, tuning, hud.hop_band, hud.hop_range,
			iron_zoom, air())
	var comes := _comes_of(slot, base)
	return LoadoutPerformance.compare(carried, comes, capped(slot), saved.rules.stats.energy_limit(r.site_class))


## The replica as it comes, measured once.
func _comes_of(slot: Loadout.Slot, base: ReplicaConfig) -> LoadoutPerformance.Figures:
	var key := _items[slot].key
	if not _comes_by_key.has(key):
		_comes_by_key[key] = LoadoutPerformance.measure(_comes_in_field(base), base.bb_weight, base.hop_up_dial, tuning,
				hud.hop_band, hud.hop_range, iron_zoom, air())
	return _comes_by_key[key]


## `base` as it comes on the field: a gas replica's energy scaled by the field's air as a carried one's (Kit
## set_temperature), under its site limit on its own BBs; any other as it is.
func _comes_in_field(base: ReplicaConfig) -> ReplicaConfig:
	if not in_field_air() or base.power != Kit.GAS:
		return base
	var r := base.duplicate() as ReplicaConfig
	var limit := saved.rules.stats.energy_limit(base.site_class) \
			/ Ballistics.weight_energy_share(base, saved.rules.rules, base.bb_weight)
	r.muzzle_energy = minf(base.muzzle_energy * field.gas_share(tuning.weather), limit)
	return r
