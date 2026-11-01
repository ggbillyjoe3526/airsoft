class_name FieldChecks
extends RefCounted
## The rules every field keeps (FC1; the browser game's content/mapRules.ts and mapLayoutChecks.ts laneChecks), as pure
## checks over one field's MapData and NavGrid, and its layout (FC2; mapLayoutChecks.ts), judged on a FieldMeasure's
## figures: each gives a check id (FieldStandard.CHECKS), pass, warn or fail, and a sentence with its figure and place.
## Numbers from FieldStandard. Test-only (tests/ never ships); test_field_rules.gd runs `run` and test_field_layout.gd
## `layout` on every field in data/maps.md.

enum Status { PASS, WARN, FAIL }

## How many places a failing sentence names before "and N more".
const LISTED := 4


## One check's verdict.
class Result:
	extends RefCounted
	var id: String = ""
	var status: Status = Status.PASS
	var text: String = ""

	func _init(check_id: String, verdict: Status, sentence: String) -> void:
		id = check_id
		status = verdict
		text = sentence

	func _to_string() -> String:
		return "%s %s: %s" % [id, str(Status.keys()[status]).to_lower(), text]


## Every check on one field. A field whose row is incomplete or whose file is refused gets field.registered alone.
## `teams`: every team colour of both sets (AccessibilityTable.colours); `allowed`: the block pairs the owner lets
## clash (FieldStandard.allowed_clashes).
static func run(entry: MapCatalog.Entry, map: MapData, nav: NavGrid, style: MapStyle, teams: Array[Color],
		allowed: PackedStringArray) -> Array[Result]:
	var out: Array[Result] = [registered(entry, map)]
	if out[0].status == Status.FAIL:
		return out
	out.append(room(map))
	out.append(on_floor(map, nav))
	out.append(ramps(map))
	out.append(kill_y(map))
	out.append_array(blocks(map, allowed))
	out.append(team_colour(map, style, teams))
	out.append(areas(map, nav))
	out.append(lanes(map))
	out.append(night(map))
	return out


## The ids of the checks in `results` that fail, sorted, each once.
static func failing(results: Array[Result]) -> PackedStringArray:
	var out := PackedStringArray()
	for r in results:
		if r.status == Status.FAIL and not out.has(r.id):
			out.append(r.id)
	out.sort()
	return out


## Listed with a name and a blurb, and its file loads.
static func registered(entry: MapCatalog.Entry, map: MapData) -> Result:
	var missing := PackedStringArray()
	if entry.display_name.strip_edges().is_empty():
		missing.append("a name")
	if entry.blurb.strip_edges().is_empty():
		missing.append("a blurb")
	if not missing.is_empty():
		return Result.new(FieldStandard.REGISTERED, Status.FAIL, "Its row in data/maps.md has no %s." %
				" or ".join(missing))
	if not map.ok():
		return Result.new(FieldStandard.REGISTERED, Status.FAIL, "Its file data/maps/%s.json is refused: %s." %
				[entry.id, "; ".join(map.problems)])
	return Result.new(FieldStandard.REGISTERED, Status.PASS, "Listed as \"%s\"; its file loads (%d blocks)." %
			[entry.display_name, map.blocks.size()])


## A spawn and a dead-zone spot per player at each end, for the largest team the map offers (data/maps.md's Max, WL2;
## one the catalogue doesn't list, the largest the Match screen offers: CustomRules.TEAM_SIZES).
static func room(map: MapData) -> Result:
	var listed := MapCatalog.shared().find(map.id)
	var need: int = listed.team_max if listed != null else CustomRules.TEAM_SIZES.max()
	var short := PackedStringArray()
	for e in map.ends.size():
		var end := map.ends[e]
		if end.spawns.size() < need:
			short.append("end %d has %s" % [e, plural(end.spawns.size(), "spawn")])
		if end.dead_zone.size() < need:
			short.append("end %d has %s" % [e, plural(end.dead_zone.size(), "dead-zone spot")])
	if map.ends.size() != 2:
		short.append("it has %d ends" % map.ends.size())
	if not short.is_empty():
		return Result.new(FieldStandard.ROOM, Status.FAIL, "Not enough room for %d a side: %s." % [need,
				", ".join(short)])
	return Result.new(FieldStandard.ROOM, Status.PASS, "%d or more spawns and dead-zone spots at each end, for up to %d a side."
			% [need, need])


## Every place play stands someone, in words and where: spawns, dead-zone spots, lane points and the flag.
static func points(map: MapData) -> Dictionary[String, Vector3]:
	var out: Dictionary[String, Vector3] = {}
	for e in map.ends.size():
		for i in map.ends[e].spawns.size():
			out["end %d spawn %d" % [e, i + 1]] = map.ends[e].spawns[i].position
		for i in map.ends[e].dead_zone.size():
			out["end %d dead-zone spot %d" % [e, i + 1]] = map.ends[e].dead_zone[i].position
	for l in map.lanes.size():
		for i in map.lanes[l].size():
			out["lane %d point %d" % [l + 1, i + 1]] = map.lanes[l][i]
	if map.has_pole:
		out["the flag"] = map.pole
	if map.has_overtime_flag:
		out["the overtime flag"] = map.overtime_flag
	return out


## Every point within FieldStandard.ON_FLOOR_SLACK of the nav floor under it, on walkable ground. On sloping ground a
## node's floor is the ground at its cell's middle, so a point whose node is on the ground (within a 1:2 slope's rise
## across the cell) is measured against the ground right under it instead.
static func on_floor(map: MapData, nav: NavGrid) -> Result:
	var all := points(map)
	var off := PackedStringArray()
	for what in all:
		var says := off_floor(map, nav, what, all[what])
		if not says.is_empty():
			off.append(says)
	if not off.is_empty():
		return Result.new(FieldStandard.ON_FLOOR, Status.FAIL, _list(off) + ".")
	return Result.new(FieldStandard.ON_FLOOR, Status.PASS, "All %d spawns, dead-zone spots, lane points and flags stand on walkable floor."
			% all.size())


## Where `what` at `p` stands wrong, in words ("" on walkable floor): off the map, more than
## FieldStandard.ON_FLOOR_SLACK off the nav floor under it (on sloping ground, the ground right under it), or where nobody
## can stand.
static func off_floor(map: MapData, nav: NavGrid, what: String, p: Vector3) -> String:
	var k := nav.node_at(p)
	var floor := nav.floor_y[k] if k >= 0 else NAN
	var ground := map.terrain.height_at(p.x, p.z) if map.terrain != null else NAN
	if not is_nan(ground) and absf(floor - ground) <= FieldStandard.MAX_RAMP_SLOPE * nav.cell:
		floor = ground
	if k < 0:
		return "%s at %s is off the map" % [what, at(p)]
	if absf(p.y - floor) > FieldStandard.ON_FLOOR_SLACK:
		return "%s at %s is %s m off the floor" % [what, at(p), num(p.y - floor)]
	if nav.walkable[k] != 1:
		return "%s at %s is where nobody can stand" % [what, at(p)]
	return ""


## Every ramp FieldStandard.MAX_RAMP_SLOPE (1:2) or gentler.
static func ramps(map: MapData) -> Result:
	var limit := "1:%s" % num(1.0 / FieldStandard.MAX_RAMP_SLOPE)
	var steep := PackedStringArray()
	var count := 0
	for b in map.blocks:
		if b.rise == MapData.Rise.NONE:
			continue
		count += 1
		var along_x := b.rise == MapData.Rise.POS_X or b.rise == MapData.Rise.NEG_X
		var run := b.size.x if along_x else b.size.z
		if b.size.y / run > FieldStandard.MAX_RAMP_SLOPE + 1e-6:
			steep.append("the ramp at %s rises 1:%s" % [at(b.center), num(run / b.size.y)])
	if not steep.is_empty():
		return Result.new(FieldStandard.RAMPS, Status.FAIL, "Too steep to walk (%s at most): %s." % [limit, _list(steep)])
	return Result.new(FieldStandard.RAMPS, Status.PASS, "%s, each %s or gentler." % [plural(count, "ramp"), limit])


## The floor of last resort (kill_y) under every block's bottom.
static func kill_y(map: MapData) -> Result:
	var lowest := INF
	var low_place := Vector3.ZERO
	for b in map.blocks:
		var bottom := b.center.y - b.size.y * 0.5
		if bottom < lowest:
			lowest = bottom
			low_place = b.center
	if not map.kill_y < lowest:
		return Result.new(FieldStandard.KILL_Y, Status.FAIL, "Its floor of last resort (%s m) is not under everything: the lowest block, at %s, reaches down to %s m."
				% [num(map.kill_y), at(low_place), num(lowest)])
	return Result.new(FieldStandard.KILL_Y, Status.PASS, "Its floor of last resort (%s m) is under everything (lowest %s m)."
			% [num(map.kill_y), num(lowest)])


## A block in a sentence: its kind and centre, to the centimetre (the browser's where()).
static func where(b: MapData.Block) -> String:
	return "%s at %.2f, %.2f, %.2f" % [b.kind, b.center.x, b.center.y, b.center.z]


## The pairs of blocks that overlap by more than FieldStandard.SEAM_SLACK on all three axes, each "A and B".
static func clashes(map: MapData) -> PackedStringArray:
	var out := PackedStringArray()
	var n := map.blocks.size()
	for i in n:
		var a := map.blocks[i]
		var a_lo := a.center - a.size * 0.5
		var a_hi := a.center + a.size * 0.5
		for j in range(i + 1, n):
			var b := map.blocks[j]
			var b_lo := b.center - b.size * 0.5
			var b_hi := b.center + b.size * 0.5
			var grip := minf(minf(a_hi.x, b_hi.x) - maxf(a_lo.x, b_lo.x),
					minf(minf(a_hi.y, b_hi.y) - maxf(a_lo.y, b_lo.y), minf(a_hi.z, b_hi.z) - maxf(a_lo.z, b_lo.z)))
			if grip > FieldStandard.SEAM_SLACK:
				out.append("%s and %s" % [where(a), where(b)])
	return out


## No block inside another but the `allowed` pairs; an allowed pair no longer there warns (take it off the list).
static func blocks(map: MapData, allowed: PackedStringArray) -> Array[Result]:
	var found := clashes(map)
	var unexpected := PackedStringArray()
	for c in found:
		if not allowed.has(c):
			unexpected.append(c)
	var out: Array[Result] = []
	if not unexpected.is_empty():
		out.append(Result.new(FieldStandard.BLOCKS, Status.FAIL, "Blocks stand inside each other (more than %s m every way): %s."
				% [num(FieldStandard.SEAM_SLACK, 3), _list(unexpected)]))
	else:
		var kept := ", except %d pairs the owner allows" % allowed.size() if not allowed.is_empty() else ""
		out.append(Result.new(FieldStandard.BLOCKS, Status.PASS, "No block of %d stands inside another%s." % [
				map.blocks.size(), kept]))
	var gone := PackedStringArray()
	for c in allowed:
		if not found.has(c):
			gone.append(c)
	if not gone.is_empty():
		out.append(Result.new(FieldStandard.BLOCKS, Status.WARN, "The exceptions list clashes no longer there (%s): take them off FieldStandard.EXCEPTIONS."
				% "; ".join(gone)))
	return out


## HSL hue (degrees) and saturation of sRGB colour `c`, taken on linear RGB as three.js getHSL does (Godot's `Color.s`
## is HSV's, which reads greyer colours as saturated).
static func hue_saturation(c: Color) -> Vector2:
	var lin := c.srgb_to_linear()
	var hi := maxf(lin.r, maxf(lin.g, lin.b))
	var lo := minf(lin.r, minf(lin.g, lin.b))
	var d := hi - lo
	if d <= 0.0:
		return Vector2.ZERO
	return Vector2(lin.h * 360.0, d / (1.0 - absf(hi + lo - 1.0)))


## The hue (degrees, 0 to 180) between `c` and the nearest of `teams`.
static func hue_gap(c: Color, teams: Array[Color]) -> float:
	var h := hue_saturation(c).x
	var least := 360.0
	for t in teams:
		var d := fmod(absf(h - hue_saturation(t).x), 360.0)
		least = minf(least, minf(d, 360.0 - d))
	return least


## Whether `c` reads as one of `teams`: FieldStandard.MIN_SATURATION or more within HUE_MARGIN_DEG of a team's hue.
static func reads_as_team(c: Color, teams: Array[Color]) -> bool:
	return hue_saturation(c).y >= FieldStandard.MIN_SATURATION and hue_gap(c, teams) <= FieldStandard.HUE_MARGIN_DEG


## The colours the field is drawn in, by name: each block's own colour (ST1), MapStyle.colour_of for each other kind
## on it, every container colour, and each surface drawn in its own colour (gravel).
static func drawn_colours(map: MapData, style: MapStyle) -> Dictionary[String, Color]:
	var out: Dictionary[String, Color] = {}
	for b in map.blocks:
		var kind := String(b.kind)
		if b.colour.a > 0.0:
			out["%s #%s" % [kind, b.colour.to_html(false)]] = b.colour
		elif style.surface_colours.has(b.surface):
			out[str(RayHit.Surface.find_key(b.surface)).to_lower()] = style.block_colour(b)
		elif b.kind == &"container":
			for i in style.container_colours.size():
				out["container %d" % (i + 1)] = style.colour_of(b.kind, i)
		elif not out.has(kind):
			out[kind] = style.colour_of(b.kind, 0)
	return out


## No drawn block colour reads as a team colour of either set (TEAM_COLOUR_RULE).
static func team_colour(map: MapData, style: MapStyle, teams: Array[Color]) -> Result:
	var drawn := drawn_colours(map, style)
	var bad := PackedStringArray()
	var nearest := ""
	var nearest_gap := INF
	for what in drawn:
		var c := drawn[what]
		var hs := hue_saturation(c)
		var gap := hue_gap(c, teams)
		var said := "the %s #%s (hue %s°, saturation %s, %s° from a team's hue)" % [what, c.to_html(false),
				num(hs.x, 1), num(hs.y), num(gap, 1)]
		if reads_as_team(c, teams):
			bad.append(said)
		elif hs.y >= FieldStandard.MIN_SATURATION and gap < nearest_gap:
			nearest_gap = gap
			nearest = said
	if not bad.is_empty():
		return Result.new(FieldStandard.TEAM_COLOUR, Status.FAIL, "Drawn in a team colour (saturation %s or more within %s° of hue): %s."
				% [num(FieldStandard.MIN_SATURATION), num(FieldStandard.HUE_MARGIN_DEG), _list(bad)])
	var closest := "; the nearest saturated one is %s" % nearest if not nearest.is_empty() else ""
	return Result.new(FieldStandard.TEAM_COLOUR, Status.PASS, "None of its %d drawn colours reads as a team's%s." % [
			drawn.size(), closest])


## Night and lights agree (the browser's map.night): `night` in the file is its first preset's, and a map with pools of
## light plays at night under some preset it offers, where they light anyone.
static func night(map: MapData) -> Result:
	var choices := map.lighting_presets
	var by_default := choices[0] == LightingConfig.NIGHT
	var names := PackedStringArray()
	for c in choices:
		names.append(String(c))
	if map.night != by_default:
		return Result.new(FieldStandard.NIGHT, Status.FAIL, "It says night is %s, but its first lighting (%s) is %s." % [
				"on" if map.night else "off", names[0], "night" if by_default else "day"])
	if not map.lights.is_empty() and not choices.has(LightingConfig.NIGHT):
		return Result.new(FieldStandard.NIGHT, Status.FAIL, "It has %s but is never played at night, where they light "
				% plural(map.lights.size(), "light pool") + "anyone.")
	var lights := " with %s" % plural(map.lights.size(), "light pool") if not map.lights.is_empty() else ""
	return Result.new(FieldStandard.NIGHT, Status.PASS, "Played by %s%s; night and lights agree." % [
			" or ".join(names), lights])


## Every walkable nav cell in a named area (MapAreas), and every name holding one.
static func areas(map: MapData, nav: NavGrid) -> Result:
	if map.areas.is_empty():
		return Result.new(FieldStandard.AREAS, Status.FAIL, "It names no areas: a callout says no place.")
	var unnamed := PackedStringArray()
	var used: Dictionary[String, bool] = {}
	var walkable := 0
	for k in nav.node_count():
		if nav.walkable[k] != 1:
			continue
		walkable += 1
		var p := nav.node_position(k)
		var area := MapAreas.area_at(map.areas, p)
		if area.is_empty():
			unnamed.append(at(p))
		else:
			used[area] = true
	if not unnamed.is_empty():
		return Result.new(FieldStandard.AREAS, Status.FAIL, "%d of %d walkable spots in no named area: %s." % [
				unnamed.size(), walkable, _list(unnamed)])
	var never := PackedStringArray()
	for a in map.areas:
		if not used.has(a.name) and not never.has(a.name):
			never.append(a.name)
	if not never.is_empty():
		return Result.new(FieldStandard.AREAS, Status.FAIL, "Named areas nobody can stand in: %s." % ", ".join(never))
	return Result.new(FieldStandard.AREAS, Status.PASS, "%d named areas cover all %d walkable spots." % [used.size(),
			walkable])


## LANES_STANDARD lanes or more pass, MIN_LANES warns, fewer fail.
static func lanes(map: MapData) -> Result:
	var n := map.lanes.size()
	if n < FieldStandard.MIN_LANES:
		return Result.new(FieldStandard.LANES, Status.FAIL, "%s: a field needs at least %d, so there is a way round."
				% [plural(n, "lane"), FieldStandard.MIN_LANES])
	if n < FieldStandard.LANES_STANDARD:
		return Result.new(FieldStandard.LANES, Status.WARN, "%s, fewer than Depot's %d: fine for a small field, if its brief says so."
				% [plural(n, "lane"), FieldStandard.LANES_STANDARD])
	return Result.new(FieldStandard.LANES, Status.PASS, "%s (Depot has %d)." % [plural(n, "lane"),
			FieldStandard.LANES_STANDARD])


## The layout's checks on one field (FC2; the browser's mapLayoutChecks.ts), judged on `m`'s figures: its lanes walk,
## its routes are whole, the spawn yards unseen, the longest sightline within `limit` (FieldStandard.sightline_limit;
## `reason` the exception's, "" for Depot's standard), the middle fair, on a field with a flag the head start, and the
## overtime flag's spot.
static func layout(m: FieldMeasure, limit: float, reason: String) -> Array[Result]:
	var out: Array[Result] = [lane_walk(m), routes(m), spawn_sight(m), sightline(m, limit, reason), middle(m)]
	if m.map.has_pole:
		out.append(flag(m))
	out.append(overtime_flag(m))
	return out


## Each lane walks point to point on foot, ending within the route snap, from end 0's half towards end 1's.
static func lane_walk(m: FieldMeasure) -> Result:
	var map := m.map
	var c0 := _spawn_centre(map.ends[0])
	var c1 := _spawn_centre(map.ends[1])
	var broken := PackedStringArray()
	for l in map.lanes.size():
		var lane := map.lanes[l]
		for i in range(1, lane.size()):
			if not is_finite(m.walk(lane[i - 1], lane[i])):
				broken.append("lane %d can't be walked from point %d to %d (%s to %s)" % [l + 1, i, i + 1,
						at(lane[i - 1]), at(lane[i])])
		if lane.size() < 2:
			broken.append("lane %d has fewer than two points" % (l + 1))
		elif _across(lane[0], c0) > _across(lane[0], c1) \
				or not _across(lane[lane.size() - 1], c0) > _across(lane[0], c0):
			broken.append("lane %d does not run from end 0 towards end 1" % (l + 1))
	if not broken.is_empty():
		return Result.new(FieldStandard.LANE_WALK, Status.FAIL, _list(broken) + ".")
	return Result.new(FieldStandard.LANE_WALK, Status.PASS, "Every lane of %d walks end to end, from end 0 towards end 1."
			% map.lanes.size())


## Every spawn reaches the middle and the flag on foot, and every end 0 spawn every end 1 spawn.
static func routes(m: FieldMeasure) -> Result:
	var map := m.map
	var cut := PackedStringArray()
	var mw := m.middle_walks()
	var fw := m.flag_walks()
	for e in map.ends.size():
		for i in map.ends[e].spawns.size():
			if not is_finite(mw[e][i]):
				cut.append("end %d spawn %d can't reach the middle (%s)" % [e, i + 1, at(m.middle())])
			if map.has_pole and not is_finite(fw[e][i]):
				cut.append("end %d spawn %d can't reach the flag" % [e, i + 1])
	for i in map.ends[0].spawns.size():
		for j in map.ends[1].spawns.size():
			if not is_finite(m.walk(map.ends[0].spawns[i].position, map.ends[1].spawns[j].position)):
				cut.append("end 0 spawn %d can't reach end 1 spawn %d" % [i + 1, j + 1])
	if not cut.is_empty():
		return Result.new(FieldStandard.ROUTES, Status.FAIL, _list(cut) + ".")
	return Result.new(FieldStandard.ROUTES, Status.PASS, "Every spawn reaches the other end%s and the middle on foot."
			% (", the flag" if map.has_pole else ""))


## Nobody within FieldStandard.SPAWN_YARD_RADIUS of one end's spawns sees anyone within it of the other's, standing or
## crouched.
static func spawn_sight(m: FieldMeasure) -> Result:
	var r := num(FieldStandard.SPAWN_YARD_RADIUS)
	var seen := m.spawns_seen()
	if seen != null:
		return Result.new(FieldStandard.SPAWN_SIGHT, Status.FAIL, "The spawns see each other: someone %s at %s sees %s (each within %s m of a spawn)."
				% [seen.eye, at(seen.from), at(seen.to), r])
	return Result.new(FieldStandard.SPAWN_SIGHT, Status.PASS, "Nobody within %s m of one end's spawns sees anyone within %s m of the other's, standing or crouched."
			% [r, r])


## The longest clear standing eye line, across the ground, at most `limit` (m); `reason` the owner's, if it is not
## Depot's standard.
static func sightline(m: FieldMeasure, limit: float, reason: String) -> Result:
	var s := m.sightline()
	if s == null:
		return Result.new(FieldStandard.SIGHTLINE, Status.FAIL, "No two places to stand see each other: the field has no walkable ground.")
	var says := "The longest clear line is %s m, from %s to %s" % [num(s.metres, 1), at(s.from), at(s.to)]
	var against := "allowed up to %s m: %s" % [num(limit, 1), reason] if not reason.is_empty() \
			else "Depot's standard is %s m" % num(limit, 1)
	if s.metres > limit:
		return Result.new(FieldStandard.SIGHTLINE, Status.FAIL, "%s; %s. Break it with cover, or write down why it stays."
				% [says, against])
	return Result.new(FieldStandard.SIGHTLINE, Status.PASS, "%s (%s)." % [says, against])


## Each end's mean walk from its spawns to the middle: the longer within FieldStandard.WALK_SPREAD of the shorter
## passes, within WALK_SPREAD_WARN warns, more fails.
static func middle(m: FieldMeasure) -> Result:
	var mw := m.middle_walks()
	var a := FieldMeasure.mean(mw[0])
	var b := FieldMeasure.mean(mw[1])
	if not is_finite(a) or not is_finite(b):
		return Result.new(FieldStandard.MIDDLE, Status.FAIL, "An end can't walk to the middle of the field (%s)." %
				at(m.middle()))
	var spread := maxf(a, b) / minf(a, b) - 1.0
	var says := "From its spawns, end 0 walks %s m to the middle (%s) and end 1 %s m: %s %% apart" % [num(a, 1),
			at(m.middle()), num(b, 1), num(spread * 100.0, 0)]
	if spread > FieldStandard.WALK_SPREAD_WARN:
		return Result.new(FieldStandard.MIDDLE, Status.FAIL, "%s, more than %s %%. One end gets there first." % [says,
				num(FieldStandard.WALK_SPREAD_WARN * 100.0, 0)])
	if spread > FieldStandard.WALK_SPREAD:
		return Result.new(FieldStandard.MIDDLE, Status.WARN, "%s, past the standard %s %%. Worth a look in play." % [
				says, num(FieldStandard.WALK_SPREAD * 100.0, 0)])
	return Result.new(FieldStandard.MIDDLE, Status.PASS, "%s (within the standard %s %%)." % [says,
			num(FieldStandard.WALK_SPREAD * 100.0, 0)])


## Attack / Defend: the attackers' (end 0) mean walk to the flag at least FieldStandard.flag_head_start times the
## defenders' (FLAG_HEAD_START but where the owner wrote down less), and the flag out of sight of the attackers' spawn
## yard.
static func flag(m: FieldMeasure) -> Result:
	var fw := m.flag_walks()
	var attack := FieldMeasure.mean(fw[0])
	var defend := FieldMeasure.mean(fw[1])
	if not is_finite(attack) or not is_finite(defend):
		return Result.new(FieldStandard.FLAG, Status.FAIL, "An end can't walk to the flag at %s." % at(m.map.pole))
	var ratio := attack / defend
	var says := "The attackers (end 0) walk %s m to the flag, the defenders %s m: %s times as far" % [num(attack, 1),
			num(defend, 1), num(ratio)]
	var need := FieldStandard.flag_head_start(m.map.id)
	var why := FieldStandard.flag_head_start_reason(m.map.id)
	if ratio < need:
		return Result.new(FieldStandard.FLAG, Status.FAIL, "%s. The defenders need a head start: at least %s times%s." % [
				says, num(need), " (%s)" % why if not why.is_empty() else ""])
	if m.flag_seen():
		return Result.new(FieldStandard.FLAG, Status.FAIL, "%s, but the flag at %s can be seen from the attackers' spawn."
				% [says, at(m.map.pole)])
	return Result.new(FieldStandard.FLAG, Status.PASS, "%s (at least %s%s), and it is out of sight of the attackers' spawn."
			% [says, num(need), ": %s" % why if not why.is_empty() else ""])


## Elimination's overtime flag (the browser's overtimeFlagCheck; OV1): on walkable floor, out of the bushes (no leaves
## from just over its foot to a standing eye), and each end's mean walk from its spawns within FieldStandard.WALK_SPREAD
## of the other's (past it a failure: the task's 15 %, stricter than the middle's look), both inside the overtime's time at a run (else a
## look). A field without one warns: a clock run out level is a draw at once there.
static func overtime_flag(m: FieldMeasure) -> Result:
	var map := m.map
	if not map.has_overtime_flag:
		return Result.new(FieldStandard.OVERTIME_FLAG, Status.WARN, "It has no overtime flag: an Elimination round that runs out of time level is a draw at once.")
	var spot := map.overtime_flag
	var off := off_floor(map, m.nav, "The overtime flag", spot)
	if not off.is_empty():
		return Result.new(FieldStandard.OVERTIME_FLAG, Status.FAIL, off + ".")
	if map.foliage.depth(spot + Vector3.UP * FieldStandard.OVERTIME_FOOT_CLEAR, spot + Vector3.UP * m.stand_eye) > 0.0:
		return Result.new(FieldStandard.OVERTIME_FLAG, Status.FAIL, "The overtime flag at %s stands in a bush, where nobody sees it."
				% at(spot))
	var ow := m.overtime_walks()
	var a := FieldMeasure.mean(ow[0])
	var b := FieldMeasure.mean(ow[1])
	if not is_finite(a) or not is_finite(b):
		return Result.new(FieldStandard.OVERTIME_FLAG, Status.FAIL, "An end can't walk to the overtime flag at %s." % at(spot))
	var tuning := SimTuning.load_default()
	var run := maxf(a, b) / tuning.movement.run_speed
	var spread := maxf(a, b) / minf(a, b) - 1.0
	var says := "From its spawns, end 0 walks %s m to the overtime flag (%s) and end 1 %s m: %s %% apart" % [num(a, 1),
			at(spot), num(b, 1), num(spread * 100.0, 0)]
	if spread > FieldStandard.WALK_SPREAD:
		return Result.new(FieldStandard.OVERTIME_FLAG, Status.FAIL, "%s, more than %s %%. One end gets there first." % [
				says, num(FieldStandard.WALK_SPREAD * 100.0, 0)])
	if run > tuning.overtime.time:
		return Result.new(FieldStandard.OVERTIME_FLAG, Status.WARN, "%s, %s s at a run: longer than the overtime's %s s."
				% [says, num(run, 1), num(tuning.overtime.time, 0)])
	return Result.new(FieldStandard.OVERTIME_FLAG, Status.PASS, "%s (within the standard %s %%), %s s at a run, inside the overtime's %s s."
			% [says, num(FieldStandard.WALK_SPREAD * 100.0, 0), num(run, 1), num(tuning.overtime.time, 0)])


## The middle of an end's spawns, on the ground plane.
static func _spawn_centre(end: MapEnd) -> Vector2:
	var sum := Vector2.ZERO
	for s in end.spawns:
		sum += Vector2(s.position.x, s.position.z)
	return sum / maxi(1, end.spawns.size())


## How far `p` is from `c` across the ground (m).
static func _across(p: Vector3, c: Vector2) -> float:
	return Vector2(p.x, p.z).distance_to(c)


## A point in a sentence, to the decimetre (the browser's at()).
static func at(p: Vector3) -> String:
	return "%s, %s, %s" % [num(p.x, 1), num(p.y, 1), num(p.z, 1)]


## `x` to `digits` places, trailing zeros dropped (the browser's num()).
static func num(x: float, digits: int = 2) -> String:
	var s := String.num(x, digits).trim_suffix(".0")
	return "0" if s == "-0" else s


## `n` and `one`, made plural ("s") unless n is 1.
static func plural(n: int, one: String) -> String:
	return "%d %s" % [n, one if n == 1 else one + "s"]


## The first LISTED of `items`, then how many more.
static func _list(items: PackedStringArray) -> String:
	var shown := "; ".join(items.slice(0, LISTED))
	return shown if items.size() <= LISTED else "%s; and %d more" % [shown, items.size() - LISTED]
