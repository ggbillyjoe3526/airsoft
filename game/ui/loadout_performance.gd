class_name LoadoutPerformance
extends RefCounted
## The Performance sheet's numbers (concept `step9-loadout/loadout.html`, `.perf`): a replica as the loadout carries it
## against the same replica as it comes. Each row has its value, the value as it comes, a bar (how full, on the sheet's
## own scale) and a verdict: better, worse or the same, on what the row counts as better. Values come from the Kit's
## replica (power source applied) and Ballistics (hop_up_reach, flight_time, muzzle energy and speed); the site limit
## capping the energy is the Kit's `capped`. Pure: nothing here draws.

enum Better { HIGHER, LOWER, NONE }

## A site's chrono shoots 0.20 g BBs; the speed row reads as it would (the concept's "Speed as a site's chrono reads it").
const CHRONO_GRAMS := 0.20
const FEET_PER_METRE := 1.0 / 0.3048
## The time row's distance (m).
const TIME_DISTANCE := 20.0
## The Moving row's bar when a magazine rattles (a share; the concept's short red bar).
const RATTLES_BAR := 0.3
## Rows that show only on the Customise tabs they belong to (the sheet's `extra`), and the one only a rattling magazine adds.
const TAB_ROWS: Array[StringName] = [&"zoom", &"aim"]
## Rows shown only for a replica whose value isn't 1, as carried or as it comes (the Compact SMG's pace and spread on
## the move, CS1; PP1): ×1 on every other replica, so they'd only crowd the sheet.
const OFF_ONE_ROWS: Array[StringName] = [&"pace", &"move_spread"]
## Rows shown only for a replica whose value is above 0, as carried or as it comes (the Pump Shotgun's pattern, SH1).
const ABOVE_ZERO_ROWS: Array[StringName] = [&"pattern"]
const MOVING_ROW := &"moving"
## The step a fire rate under WHOLE_RATE (BBs/s) is shown to, and the rate from which it shows whole (rate_text).
const RATE_STEP := 0.01
const WHOLE_RATE := 2.0
## The rows, top to bottom: the Figures field, the translation keys of its name and unit, the decimals shown, the value
## the bar is full at, whether a short bar is the good one, and which way counts as better.
const SPECS: Array[Dictionary] = [
	{"field": &"energy", "name": "PERF_ENERGY", "unit": "PERF_UNIT_J", "decimals": 2, "full": 2.3, "invert": false,
			"better": Better.HIGHER},
	{"field": &"speed", "name": "PERF_SPEED", "unit": "PERF_UNIT_FPS", "decimals": 0, "full": 460.0, "invert": false,
			"better": Better.HIGHER},
	{"field": &"bb_weight", "name": "PERF_BB_WEIGHT", "unit": "PERF_UNIT_G", "decimals": 2, "full": 0.5,
			"invert": false, "better": Better.NONE},
	{"field": &"rate", "name": "PERF_RATE", "unit": "PERF_UNIT_BBS", "decimals": 2, "full": 20.0, "invert": false,
			"better": Better.HIGHER},
	{"field": &"on_target", "name": "PERF_ON_TARGET", "unit": "PERF_UNIT_M", "decimals": 0, "full": 60.0,
			"invert": false, "better": Better.HIGHER},
	{"field": &"time", "name": "PERF_TIME", "unit": "PERF_UNIT_S", "decimals": 2, "full": 0.85, "invert": true,
			"better": Better.LOWER},
	{"field": &"spread", "name": "PERF_SPREAD", "unit": "PERF_UNIT_DEG", "decimals": 2, "full": 1.2, "invert": true,
			"better": Better.LOWER},
	{"field": &"pattern", "name": "PERF_PATTERN", "unit": "PERF_UNIT_DEG", "decimals": 1, "full": 3.0, "invert": false,
			"better": Better.NONE},
	{"field": &"zoom", "name": "PERF_ZOOM", "unit": "PERF_UNIT_X", "decimals": 2, "full": 6.0, "invert": false,
			"better": Better.HIGHER},
	{"field": &"aim", "name": "PERF_AIM", "unit": "PERF_UNIT_S", "decimals": 2, "full": 0.4, "invert": true,
			"better": Better.LOWER},
	{"field": &"recoil", "name": "PERF_RECOIL", "unit": "PERF_UNIT_DEG", "decimals": 2, "full": 0.8, "invert": true,
			"better": Better.LOWER},
	{"field": &"magazines", "name": "PERF_MAGAZINES", "unit": "", "decimals": 0, "full": 600.0, "invert": false,
			"better": Better.HIGHER},
	{"field": &"reload", "name": "PERF_RELOAD", "unit": "PERF_UNIT_S", "decimals": 1, "full": 3.5, "invert": true,
			"better": Better.LOWER},
	{"field": &"draw", "name": "PERF_DRAW", "unit": "PERF_UNIT_S", "decimals": 2, "full": 0.9, "invert": true,
			"better": Better.LOWER},
	{"field": &"pace", "name": "PERF_PACE", "unit": "PERF_UNIT_X", "decimals": 2, "full": 1.2, "invert": false,
			"better": Better.HIGHER},
	{"field": &"move_spread", "name": "PERF_MOVE_SPREAD", "unit": "PERF_UNIT_X", "decimals": 2, "full": 1.0,
			"invert": true, "better": Better.LOWER},
	{"field": &"moving", "name": "PERF_MOVING", "unit": "", "decimals": 0, "full": 1.0, "invert": false,
			"better": Better.NONE},
]


## What a replica shoots and handles as, with `grams` BBs loaded and its hop-up dial where it is.
class Figures:
	extends RefCounted
	var energy: float = 0.0
	var speed: float = 0.0
	var bb_weight: float = 0.0
	var rate: float = 0.0
	## BBs a shot sends (the rate row reads "1.7 × 3", SH1) and how far off the shot's line each leaves (degrees).
	var shot_bbs: int = 1
	var pattern: float = 0.0
	var on_target: float = 0.0
	## True when the BB never left the band within the readout range ("60+ m").
	var on_target_full: bool = false
	var time: float = 0.0
	var spread: float = 0.0
	var recoil: float = 0.0
	var mag_size: int = 0
	var mags: int = 0
	var reload: float = 0.0
	var draw: float = 0.0
	## The view's zoom when aimed (the optic's, or the iron sights'), and the seconds to bring the sight up.
	var zoom: float = 1.0
	var aim: float = 0.0
	## The pace it's carried at and the share of moving's spread it takes (×, ReplicaConfig.pace and move_spread).
	var pace: float = 1.0
	var move_spread: float = 1.0
	## A rattling magazine: bots close by hear it as you move.
	var rattles: bool = false
	var magazines: float:
		get:
			return float(mag_size * mags)


class Row:
	extends RefCounted
	var field: StringName = &""
	var name_key: String = ""
	var unit_key: String = ""
	## The value as shown ("0.97", "60 × 4") and as it comes.
	var text: String = ""
	var as_comes_text: String = ""
	## How full the bar is, 0 to 1.
	var bar: float = 0.0
	## 1 better, -1 worse, 0 the same (or a row that isn't better or worse).
	var verdict: int = 0
	## The row belongs to some Customise tabs only (`TAB_ROWS`); `present` is false for the Moving row without a rattle
	## and for an OFF_ONE_ROWS row at ×1.
	var tab_only: bool = false
	var present: bool = true
	## The Magazines row's two numbers, each with its own verdict, as the part tabs' cards colour them (BP6): the
	## magazine's size ("120 ×") and how many ("2"). Empty for every other row.
	var parts: PackedStringArray = PackedStringArray()
	var part_verdicts: PackedInt32Array = PackedInt32Array()

	## True if the sheet draws the row when the Customise tab asks for the rows in `extra`.
	func is_shown(extra: PackedStringArray = PackedStringArray()) -> bool:
		return present and (not tab_only or extra.has(String(field)))


class Sheet:
	extends RefCounted
	var rows: Array[Row] = []
	## The site limit cut the energy (Kit.capped), and the limit (J).
	var capped: bool = false
	var limit: float = 0.0

	func row(field: StringName) -> Row:
		for r in rows:
			if r.field == field:
				return r
		return null

	## The names of the shown rows with `verdict`, as keys.
	func keys_with(verdict: int, extra: PackedStringArray = PackedStringArray()) -> PackedStringArray:
		var out := PackedStringArray()
		for r in rows:
			if r.verdict == verdict and r.is_shown(extra):
				out.append(r.name_key)
		return out


## `replica` loaded with `grams` BBs and its dial at `dial`, measured by `tuning`'s ballistics: `range_limit` m is the
## readout's reach and `band` m the "on target" band (the HUD's hop-up readout uses the same); `iron_zoom` is the view's
## zoom aiming through iron sights.
static func measure(replica: ReplicaConfig, grams: float, dial: float, tuning: SimTuning, band: float,
		range_limit: float, iron_zoom: float) -> Figures:
	var f := Figures.new()
	var rules := tuning.replica_rules
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	f.energy = Ballistics.muzzle_energy(replica, rules, grams)
	f.speed = Ballistics.muzzle_velocity(replica, rules, CHRONO_GRAMS) * FEET_PER_METRE
	f.bb_weight = grams
	f.rate = replica.fire_rate
	f.shot_bbs = replica.shot_bbs
	f.pattern = replica.pattern_deg if replica.shot_bbs > 1 else 0.0
	var reach := Ballistics.hop_up_reach(replica, dial, tuning, dt, band, range_limit, grams)
	f.on_target = reach.on_target_to
	f.on_target_full = reach.on_target_to >= range_limit
	f.time = Ballistics.flight_time(replica, dial, TIME_DISTANCE, tuning, dt, grams)
	# from the hip, as the wiki gives it: a hip spread (the Sniper Rifle wider, the Compact SMG tighter) counts (PP1)
	f.spread = replica.spread_deg * replica.hip_spread
	f.recoil = replica.recoil_deg
	f.mag_size = replica.mag_size
	f.mags = replica.mags
	f.reload = replica.reload_time
	f.draw = replica.draw_time
	f.zoom = maxf(replica.aim_zoom, replica.aim_zoom_to) if replica.aim_zoom > 0.0 else iron_zoom
	f.aim = tuning.movement.aim_raise_time * replica.raise_scale
	f.pace = replica.pace
	f.move_spread = replica.move_spread
	f.rattles = replica.rattles
	return f


## The sheet comparing `carried` with `comes`; `capped` and `limit` as the Kit says.
static func compare(carried: Figures, comes: Figures, capped: bool, limit: float) -> Sheet:
	var sheet := Sheet.new()
	sheet.capped = capped
	sheet.limit = limit
	for spec in SPECS:
		var field: StringName = spec["field"]
		if field == MOVING_ROW:
			sheet.rows.append(_moving(spec, carried))
			continue
		var decimals: int = spec["decimals"]
		var value: float = carried.get(field)
		var before: float = comes.get(field)
		var r := Row.new()
		r.field = field
		r.name_key = spec["name"]
		r.unit_key = spec["unit"]
		r.tab_only = TAB_ROWS.has(field)
		if OFF_ONE_ROWS.has(field):
			r.present = not is_equal_approx(value, 1.0) or not is_equal_approx(before, 1.0)
		elif ABOVE_ZERO_ROWS.has(field):
			r.present = value > 0.0 or before > 0.0
		r.text = _shown(field, carried, value, decimals)
		r.as_comes_text = _shown(field, comes, before, decimals)
		var share := clampf(value / float(spec["full"]), 0.0, 1.0)
		r.bar = 1.0 - share if spec["invert"] else share
		var step := pow(10.0, -decimals)
		var diff := snappedf(value, step) - snappedf(before, step)
		var better: Better = spec["better"]
		if better != Better.NONE and is_finite(diff) and not is_zero_approx(diff):
			r.verdict = int(signf(diff)) * (1 if better == Better.HIGHER else -1)
		if field == &"magazines":
			_split_magazines(r, carried, comes)
		sheet.rows.append(r)
	return sheet


## The Magazines row's size and count apart, more of either the better ("%d × %d": the text up to the second number,
## then the second number).
static func _split_magazines(r: Row, carried: Figures, comes: Figures) -> void:
	var size_text := (TranslationServer.translate("PERF_MAGAZINES_FORMAT") % [carried.mag_size, carried.mags])
	var count := str(carried.mags)
	r.parts = PackedStringArray([size_text.trim_suffix(count).strip_edges(), count])
	r.part_verdicts = PackedInt32Array([signi(carried.mag_size - comes.mag_size), signi(carried.mags - comes.mags)])


## The Moving row: "Rattles" in red, and only when a magazine rattles.
static func _moving(spec: Dictionary, carried: Figures) -> Row:
	var r := Row.new()
	r.field = spec["field"]
	r.name_key = spec["name"]
	r.unit_key = spec["unit"]
	r.present = carried.rattles
	r.text = TranslationServer.translate("PERF_RATTLES")
	r.as_comes_text = TranslationServer.translate("PERF_QUIET")
	r.bar = RATTLES_BAR
	r.verdict = -1 if carried.rattles else 0
	return r


static func _shown(field: StringName, f: Figures, value: float, decimals: int) -> String:
	if field == &"magazines":
		return TranslationServer.translate("PERF_MAGAZINES_FORMAT") % [f.mag_size, f.mags]
	if field == &"on_target" and f.on_target_full:
		return TranslationServer.translate("PERF_FULL_RANGE") % roundi(value)
	if field == &"rate":
		# Several BBs a shot: shots a second times the BBs each sends ("1.7 × 3", as the magazines read "30 × 5").
		if f.shot_bbs > 1:
			return TranslationServer.translate("PERF_RATE_SHOTS_FORMAT") % [rate_text(value), f.shot_bbs]
		return rate_text(value)
	return ("%." + str(decimals) + "f") % value


## A fire rate (BBs/s) as the Loadout shows it: from WHOLE_RATE up to the nearest whole (13, 15 with a LiPo), below it
## to two places without trailing zeros (0.8, 0.76), so a spring's slower cycling shows (BP3: 0.8 read "1").
static func rate_text(rate: float) -> String:
	if rate >= WHOLE_RATE:
		return str(roundi(rate))
	var shown := snappedf(rate, RATE_STEP)
	return str(roundi(shown)) if is_equal_approx(shown, roundf(shown)) else String.num(shown)
