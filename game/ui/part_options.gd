class_name PartOptions
extends RefCounted
## What a Customise part tab offers (concepts `optic.png`, `magazine.png`): for one slot of the replica carried, the replica
## as it comes there and each part that fits, with the figures it would give (LoadoutRules.carried on the loadout with that
## part in that slot, the rest as it is), each figure against the slot as it comes: better or worse, and the words for what
## is better and worse. Read-only; the page asks, LoadoutRules edits.

## One figure's value, how many decimals show (zeros after the point are dropped unless `trim` is false), and whether a higher
## one is the better one.
const VALUES: Dictionary[StringName, Dictionary] = {
	&"zoom": {"decimals": 2, "higher": true},
	&"aim": {"decimals": 2, "higher": false},
	&"shake": {"decimals": 0, "higher": false},
	&"spread": {"decimals": 2, "higher": false, "trim": false},
	&"hip": {"decimals": 2, "higher": false, "trim": false},
	&"move": {"decimals": 0, "higher": false},
	&"energy": {"decimals": 2, "higher": true, "trim": false},
	&"heard": {"decimals": 0, "higher": false},
	&"capacity": {"decimals": 0, "higher": true},
	&"carried": {"decimals": 0, "higher": true},
	&"reload": {"decimals": 2, "higher": false},
	&"draw": {"decimals": 2, "higher": false},
	&"reach": {"decimals": 0, "higher": true},
	&"spill": {"decimals": 0, "higher": true},
}
## The pieces of a card's numbers line: the translation key of its words (each %s is a figure) and the figures in it.
const PIECES: Dictionary[StringName, Dictionary] = {
	&"zoom": {"fmt": "PART_FIG_ZOOM", "values": [&"zoom"]},
	&"aim": {"fmt": "PART_FIG_AIM", "values": [&"aim"]},
	&"shake": {"fmt": "PART_FIG_SHAKE", "values": [&"shake"]},
	&"spread": {"fmt": "PART_FIG_SPREAD", "values": [&"spread"]},
	&"hip": {"fmt": "PART_FIG_HIP", "values": [&"hip"]},
	&"move": {"fmt": "PART_FIG_MOVE", "values": [&"move"]},
	&"energy": {"fmt": "PART_FIG_ENERGY", "values": [&"energy"]},
	&"heard": {"fmt": "PART_FIG_HEARD", "values": [&"heard"]},
	&"magazine": {"fmt": "PART_FIG_MAGAZINE", "values": [&"capacity", &"carried"]},
	&"reload": {"fmt": "PART_FIG_RELOAD", "values": [&"reload"]},
	&"draw": {"fmt": "PART_FIG_DRAW", "values": [&"draw"]},
	&"reach": {"fmt": "PART_FIG_REACH", "values": [&"reach"]},
	&"spill": {"fmt": "PART_FIG_SPILL", "values": [&"spill"]},
}
## Each slot's card line: the pieces always shown, and the ones added when the part changes them.
const SLOT_PIECES: Dictionary[StringName, Array] = {
	&"optic": [&"zoom", &"aim"],
	&"grip": [&"aim", &"shake"],
	&"laser": [&"hip"],
	&"magazine": [&"magazine", &"reload"],
	&"barrel": [&"energy", &"spread"],
	&"muzzle": [&"energy", &"heard"],
	&"light": [&"reach", &"spill"],
}
const SLOT_EXTRA_PIECES: Dictionary[StringName, Array] = {
	&"grip": [&"move"],
	&"laser": [&"aim"],
	&"magazine": [&"draw"],
	&"barrel": [&"aim"],
	&"muzzle": [&"aim"],
}
## Slots whose parts carry the slot's name in theirs ("Hi-Cap Magazine"): the cards drop it ("Hi-Cap").
const SHORT_NAME_SLOTS: Array[StringName] = [&"magazine"]
## Slots with nothing there as it comes: their tab line is dim ("None").
const EMPTY_SLOTS: Array[StringName] = [&"grip", &"laser", &"light"]
const SEPARATOR := " · "
const RATTLES_VALUE := &"rattles"


## One card: the slot as it comes (`part` null) or a part.
class Option:
	extends RefCounted
	var part: Pool.Item = null
	var name: String = ""
	## The words in the picture's place for the slot as it comes ("Iron sights").
	var picture_words: String = ""
	## The numbers line, plain and with BBCode colours, then the line of words under it.
	var figures_plain: String = ""
	var figures_markup: String = ""
	var blurb_plain: String = ""
	var blurb_markup: String = ""
	var picked: bool = false
	var rattles: bool = false
	## What is better and worse than the slot as it comes, as words.
	var better: PackedStringArray = PackedStringArray()
	var worse: PackedStringArray = PackedStringArray()
	## The level that unlocks the part, while it is locked; -1 when it can be picked.
	var lock_level: int = -1

	func id() -> String:
		return part.id if part != null else ""


var _facts: LoadoutFacts = null


func _init(facts: LoadoutFacts) -> void:
	_facts = facts


## The part's name as the cards and the tab list say it.
static func short_name(part: Pool.Item) -> String:
	if SHORT_NAME_SLOTS.has(part.slot):
		var word := " " + TranslationServer.translate("PART_" + String(part.slot).to_upper() + "_WORD")
		if part.display_name.ends_with(word):
			return part.display_name.trim_suffix(word)
	return part.display_name


## True if any replica could take a part in `part_slot` now (on offer: a dev one only with Dev content on). A slot with
## none, such as the light while it is dev and Dev content is off, shows as coming LATER.
func offered(part_slot: StringName) -> bool:
	var rules := _facts.rules()
	for it in rules.pool.replicas:
		if not rules.pool.parts_for(it, part_slot, rules.dev_content).is_empty():
			return true
	return false


## True if replica `slot` of the loadout can take a part in `part_slot`.
func takes(slot: Loadout.Slot, part_slot: StringName) -> bool:
	return not _facts.rules().parts_for(_facts.item(slot).id, part_slot).is_empty()


## The cards of `part_slot` for the replica in `slot`: as it comes first, then each part that fits in pool order.
func options(slot: Loadout.Slot, part_slot: StringName) -> Array[Option]:
	var item := _facts.item(slot)
	var rules := _facts.rules()
	var fitted := _facts.fitted_part(item, part_slot)
	var comes := _measure(slot, item, part_slot, null)
	var out: Array[Option] = []
	var candidates: Array[Pool.Item] = [null]
	candidates.append_array(rules.parts_for(item.id, part_slot))
	for part: Pool.Item in candidates:
		var o := Option.new()
		o.part = part
		o.picked = part == fitted
		if part != null and rules.is_locked(part.id):
			o.lock_level = rules.unlock_level(part.id)
		var values := comes if part == null else _measure(slot, item, part_slot, part)
		_fill(o, item, part_slot, values, comes)
		out.append(o)
	return out


## The mounts the slot's parts need ("pistol-rail"), each once: what a replica that can't take one lacks.
func mounts_of(part_slot: StringName) -> PackedStringArray:
	var out := PackedStringArray()
	for pt: Pool.Item in _facts.pool().parts:
		if pt.slot == part_slot:
			for tag in pt.fits:
				if not out.has(tag):
					out.append(tag)
	return out


## What the part tab shows for `part_slot` in the tab list under its name: the part fitted, else the slot as it comes.
func tab_line(slot: Loadout.Slot, part_slot: StringName) -> String:
	var pt := _facts.fitted_part(_facts.item(slot), part_slot)
	if pt != null:
		return short_name(pt)
	return _keyed("PART_COMES", part_slot, _facts.item(slot).key)


## The names of the parts fitted to the replica in `slot`, in slot order.
func fitted_names(slot: Loadout.Slot) -> PackedStringArray:
	var out := PackedStringArray()
	for part_slot: StringName in Pool.PART_TABLES.values():
		var pt := _facts.fitted_part(_facts.item(slot), part_slot)
		if pt != null:
			out.append(pt.display_name)
	return out


## The figures of `part` (or the slot as it comes, null) in `part_slot`: the replica as carried with it, everything else
## as it is. Value id -> number.
func _measure(slot: Loadout.Slot, item: Pool.Item, part_slot: StringName, part: Pool.Item) -> Dictionary:
	var rules := _facts.rules()
	var l := _facts.saved.carried().copy("")
	rules.set_part(l, item.id, part_slot, part.id if part != null else "")
	var kit := rules.carried(l)
	var r := kit.replicas[slot]
	var tuning := _facts.tuning
	var values: Dictionary = {}
	# A variable optic (SN2) shows the most it zooms.
	values[&"zoom"] = maxf(r.aim_zoom, r.aim_zoom_to) if r.aim_zoom > 0.0 else _facts.iron_zoom
	values[&"aim"] = tuning.movement.aim_raise_time * r.raise_scale
	values[&"shake"] = r.shake_scale * 100.0
	values[&"spread"] = r.spread_deg
	# From the hip, as the Performance sheet's Spread row has it: a laser tightens only that (RP1).
	values[&"hip"] = r.spread_deg * r.hip_spread
	# The share of moving's spread it takes (a grip steadies it, RP1).
	values[&"move"] = r.move_spread * 100.0
	values[&"energy"] = Ballistics.muzzle_energy(r, tuning.replica_rules, kit.bb_weights[slot])
	values[&"heard"] = r.heard_scale * 100.0
	values[&"capacity"] = float(r.mag_size)
	values[&"carried"] = float(r.mags)
	values[&"reload"] = r.reload_time
	values[&"draw"] = r.draw_time
	values[RATTLES_VALUE] = r.rattles
	# A light's reach and beam as it shines at night (none: nothing lit).
	var light: Torch.Light = kit.lights[slot] if slot < kit.lights.size() else null
	values[&"reach"] = light.reach if light != null else 0.0
	values[&"spill"] = light.spill_deg if light != null else 0.0
	return values


func _fill(o: Option, item: Pool.Item, part_slot: StringName, values: Dictionary, comes: Dictionary) -> void:
	var part := o.part
	var tag_good := GameTheme.GOOD.to_html(false)
	var tag_bad := GameTheme.BAD.to_html(false)
	var pieces: Array = SLOT_PIECES[part_slot].duplicate()
	for extra: StringName in SLOT_EXTRA_PIECES.get(part_slot, []):
		if _differs(extra, values, comes):
			pieces.append(extra)
	var plain := PackedStringArray()
	var markup := PackedStringArray()
	for piece: StringName in pieces:
		var spec: Dictionary = PIECES[piece]
		var shown_plain: Array[String] = []
		var shown_markup: Array[String] = []
		for id: StringName in spec["values"]:
			var text := _number(id, values[id])
			var verdict := 0 if part == null else _verdict(id, values, comes)
			shown_plain.append(text)
			shown_markup.append(text if verdict == 0 else "[b][color=#%s]%s[/color][/b]" % [
					tag_good if verdict > 0 else tag_bad, text])
			if verdict > 0:
				o.better.append(TranslationServer.translate("PART_BETTER_" + String(id).to_upper()))
			elif verdict < 0:
				o.worse.append(TranslationServer.translate("PART_WORSE_" + String(id).to_upper()))
		var fmt := TranslationServer.translate(spec["fmt"])
		if plain.is_empty():
			fmt = fmt.substr(0, 1).to_upper() + fmt.substr(1)
		plain.append(fmt % shown_plain)
		markup.append(fmt % shown_markup)
	o.figures_plain = SEPARATOR.join(plain)
	o.figures_markup = SEPARATOR.join(markup)
	if part == null:
		o.name = _keyed("PART_NONE_NAME", part_slot, item.key)
		o.picture_words = _keyed("PART_NONE_PICTURE", part_slot, item.key)
		o.blurb_plain = _keyed("PART_NONE_BLURB", part_slot, item.key)
		o.blurb_markup = o.blurb_plain
		return
	o.name = short_name(part)
	o.blurb_plain = TranslationServer.translate("PART_BLURB_" + String(part.key).to_upper())
	o.blurb_markup = o.blurb_plain
	o.rattles = values[RATTLES_VALUE]
	if o.rattles:
		var label := TranslationServer.translate("PART_RATTLES")
		o.blurb_plain = "%s %s" % [label, o.blurb_plain]
		o.blurb_markup = "[b][color=#%s]%s[/color][/b] %s" % [tag_bad, label, o.blurb_markup]
		o.worse.append(TranslationServer.translate("PART_WORSE_RATTLES"))


## 1 if `id` is better than the slot as it comes, -1 if worse, 0 if the same as shown.
func _verdict(id: StringName, values: Dictionary, comes: Dictionary) -> int:
	var spec: Dictionary = VALUES[id]
	var step := pow(10.0, -int(spec["decimals"]))
	var diff := snappedf(values[id], step) - snappedf(comes[id], step)
	if is_zero_approx(diff):
		return 0
	return int(signf(diff)) * (1 if spec["higher"] else -1)


func _differs(piece: StringName, values: Dictionary, comes: Dictionary) -> bool:
	for id: StringName in PIECES[piece]["values"]:
		if _verdict(id, values, comes) != 0:
			return true
	return false


## A figure as shown: its decimals, no trailing zeros ("1.8", "0.15", "120").
static func _number(id: StringName, value: float) -> String:
	var decimals: int = VALUES[id]["decimals"]
	var shown := ("%." + str(decimals) + "f") % value
	if decimals > 0 and VALUES[id].get("trim", true):
		shown = shown.rstrip("0").rstrip(".")
	return shown


## The words under `prefix` for `part_slot`, the replica's own where it has them ("PART_COMES_MUZZLE_AEG"), else the slot's.
static func _keyed(prefix: String, part_slot: StringName, replica_key: StringName) -> String:
	var slot_key := "%s_%s" % [prefix, String(part_slot).to_upper()]
	var own := "%s_%s" % [slot_key, String(replica_key).to_upper()]
	var words := TranslationServer.translate(own)
	return words if words != own else TranslationServer.translate(slot_key)
