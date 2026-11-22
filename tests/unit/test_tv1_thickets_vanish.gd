extends GutTest
## TV1 (the owner's playtest of 0.1 Beta 2, items 3 and 6). Woodland's thickets stand as tiers that narrow with their
## spruces as drawn (TierSteps, MapStyle.tier_steps), each in its box and round each spruce (WH1: a line through the
## gap between two spruces' tops flies on), a thicket closed on every side standing as its box, so a line grazing a
## thicket's end past its spruces flies on and one through its middle still stops; only thickets stand so. A hit character walking off as its respawn wait runs out leaves the field (its fade) before it comes back, never
## drawn at its spawn in a blink, and its team counts it coming through the fade; one still calling its hit calls
## first. A walk-off with no way on foot steps down a climb's drop: Subway's east end, whose dead zone is on the track
## below the platforms, walks there instead of into a wall.

const DT := 1.0 / 60.0
## A grazing line passes this far (m) inside a thicket's open end, at this height over the ground (a chest).
const GRAZE_IN := 0.1
const CHEST := 1.3
## Room (m) beyond the end, and either side, that no other block may take for the grazing test's thicket.
const CLEAR := 2.5
## A share of a thicket's height through its spruces' upper boughs, where their tops stand apart.
const TOPS := 0.62
## A line from the owner's circled bank (WH1): an eye at the stream to a chest past the thicket at (18.5, -0.5).
const CIRCLED_FROM := Vector3(2.263365, 1.61, 15.13224)
const CIRCLED_TO := Vector3(22.42001, 2.890888, 4.714402)

var play: PlayTuning = PlayTuning.load_default()
var tuning: SimTuning = SimTuning.new()
var loadout: Array[ReplicaConfig] = []
var _woodland: MatchRunner = null


func before_all() -> void:
	loadout = ReplicaStats.default_loadout()
	_woodland = MatchRunner.new(self, "woodland")


func after_all() -> void:
	if _woodland != null:
		_woodland.free_level()


func _tiers(b: MapData.Block, others: Array[MapData.Block]) -> Array[AABB]:
	var out: Array[AABB] = []
	TierSteps.boxes(b, play.map_style, play.site_look.props, others, out)
	return out


# --- item 3: the thickets ---

func test_only_woodland_s_thickets_stand_as_tiers() -> void:
	for id: String in ["woodland", "depot", "subway"]:
		var m := MapData.load_map(id, play.map_style, tuning.rounds.team_size)
		var tiered := TierSteps.tiered_blocks(m, play.map_style, play.site_look.props)
		for b in tiered:
			assert_eq(b.kind, &"thicket", "%s: only thickets stand as tiers (%s at %s)" % [id, b.kind, b.center])
		if id == "woodland":
			assert_gt(tiered.size(), 100, "every Woodland thicket")
		else:
			assert_eq(tiered.size(), 0, "%s has none" % id)


func test_each_thicket_s_tiers_lie_in_its_box_and_draw_in_as_they_rise() -> void:
	var m := _woodland.map
	var others := TierSteps.tiered_blocks(m, play.map_style, play.site_look.props)
	var steps: PackedVector2Array = play.map_style.tier_steps[&"spruce"]
	var with_tiers := 0
	for b in others:
		var tiers := _tiers(b, others)
		if tiers.is_empty():
			continue
		with_tiers += 1
		var box := AABB(b.center - b.size * 0.5, b.size).grow(1e-4)
		var by_tier: Array[Array] = []
		by_tier.resize(steps.size())
		for k in steps.size():
			by_tier[k] = []
		for t in tiers:
			assert_true(box.encloses(t), "a tier of %s lies in its box" % b.center)
			var k := _tier_of(b, t, steps)
			assert_gt(k, -1, "a box of %s spans one tier's height (%s)" % [b.center, t])
			if k > -1:
				by_tier[k].append(t)
		# a tier reaching 0 (the spruces' tips) stands as nothing
		for k in steps.size():
			if steps[k].y <= 0.0:
				assert_eq(by_tier[k].size(), 0, "tier %d of %s reaches nowhere" % [k, b.center])
		# from the boughs' widest tier up, each tier's boxes lie over the one's below (each prop draws in)
		for k in range(2, steps.size()):
			for t: AABB in by_tier[k]:
				assert_true(_over(by_tier[k - 1], t), "tier %d of %s draws in (%s)" % [k, b.center, t])
	assert_gt(with_tiers, 50, "most thickets have an open side")


## The tier of `steps` whose height `t` spans in block `b`, or -1.
func _tier_of(b: MapData.Block, t: AABB, steps: PackedVector2Array) -> int:
	var lo := b.center.y - b.size.y * 0.5
	for k in steps.size():
		var to := steps[k + 1].x if k + 1 < steps.size() else 1.0
		if absf(t.position.y - (lo + b.size.y * steps[k].x)) < 1e-3 and absf(t.end.y - (lo + b.size.y * to)) < 1e-3:
			return k
	return -1


## Whether one of `boxes` holds `t` in plan.
static func _over(boxes: Array, t: AABB) -> bool:
	for o: AABB in boxes:
		if t.position.x >= o.position.x - 1e-4 and t.end.x <= o.end.x + 1e-4 and t.position.z >= o.position.z - 1e-4 \
				and t.end.z <= o.end.z + 1e-4:
			return true
	return false


func test_a_thicket_other_rows_close_on_every_side_stands_as_its_box() -> void:
	var others := TierSteps.tiered_blocks(_woodland.map, play.map_style, play.site_look.props)
	var b: MapData.Block = null
	for o in others:
		if not _tiers(o, others).is_empty():
			b = o
			break
	assert_not_null(b, "a thicket with tiers")
	if b == null:
		return
	# the same thicket with a copy of itself against each side: nothing sees past its spruces, so it is its box
	var ring: Array[MapData.Block] = [b]
	for axis: int in [0, 2]:
		for side: float in [-1.0, 1.0]:
			var n := MapData.Block.new()
			n.kind = b.kind
			n.dress = b.dress
			n.size = b.size
			n.center = b.center
			n.center[axis] += side * b.size[axis]
			ring.append(n)
	assert_eq(_tiers(b, ring).size(), 0, "a thicket shut in on every side stands as its box")
	ring.pop_back()
	assert_gt(_tiers(b, ring).size(), 0, "one open side and it stands as tiers")


## A thicket whose -x end is open with CLEAR m of nothing else beyond it and to either side.
func _open_end(m: MapData, others: Array[MapData.Block]) -> MapData.Block:
	for b in others:
		if b.size.x < b.size.z or b.size.x < 2.0 or _tiers(b, others).is_empty():
			continue
		var lo := b.center - b.size * 0.5
		var room := AABB(Vector3(lo.x - CLEAR, lo.y, lo.z - CLEAR), Vector3(CLEAR + 0.5, b.size.y, b.size.z + CLEAR * 2.0))
		var clear := true
		for o in m.blocks:
			if o != b and o.kind != &"floor" and AABB(o.center - o.size * 0.5, o.size).intersects(room):
				clear = false
				break
		if clear:
			return b
	return null


func test_a_line_grazing_a_thicket_s_end_flies_on_and_one_through_it_stops() -> void:
	var m := _woodland.map
	var others := TierSteps.tiered_blocks(m, play.map_style, play.site_look.props)
	var b := _open_end(m, others)
	assert_not_null(b, "a thicket with an open end in the clear")
	if b == null:
		return
	var query := _woodland.level.query()
	var hit := RayHit.new()
	var lo := b.center - b.size * 0.5
	var hi := b.center + b.size * 0.5
	var x := lo.x + GRAZE_IN
	var y := m.terrain.height_clamped(x, b.center.z) + CHEST
	var from := Vector3(x, y, lo.z - CLEAR * 0.8)
	var to := Vector3(x, y, hi.z + CLEAR * 0.8)
	var met := query.sight_ray(from, to, hit)
	var in_box := met and AABB(lo, b.size).grow(0.01).has_point(hit.position)
	assert_false(in_box, "a line %.1f m inside %s's open end at chest height, past its end spruce, flies on" % [
			GRAZE_IN, b.center])
	assert_false(query.ray(from, to, hit) and AABB(lo, b.size).grow(0.01).has_point(hit.position), "a BB too")
	var mid := Vector3(b.center.x, m.terrain.height_clamped(b.center.x, b.center.z) + CHEST, 0.0)
	assert_true(query.sight_ray(Vector3(mid.x, mid.y, lo.z - CLEAR * 0.8), Vector3(mid.x, mid.y, hi.z + CLEAR * 0.8),
			hit), "a line through its middle stops")


func test_a_line_between_two_spruces_tops_flies_on() -> void:
	var m := _woodland.map
	var others := TierSteps.tiered_blocks(m, play.map_style, play.site_look.props)
	var b := _open_end(m, others)
	assert_not_null(b, "a thicket with an open end in the clear")
	if b == null:
		return
	var tiers := _tiers(b, others)
	var lo := b.center - b.size * 0.5
	var hi := b.center + b.size * 0.5
	# a level line across the block (along z) through the upper boughs, where no tier box stands: between two tops
	var y := lo.y + b.size.y * TOPS
	var x: float = NAN
	for i in 200:
		var at := lerpf(lo.x + 0.3, hi.x - 0.3, (i + 0.5) / 200.0)
		if not _meets(tiers, at, y):
			x = at
			break
	assert_false(is_nan(x), "the tops of %s's spruces stand apart" % b.center)
	if is_nan(x):
		return
	var hit := RayHit.new()
	var from := Vector3(x, y, lo.z - CLEAR * 0.8)
	var to := Vector3(x, y, hi.z + CLEAR * 0.8)
	var query := _woodland.level.query()
	assert_false(query.sight_ray(from, to, hit) and AABB(lo, b.size).grow(0.01).has_point(hit.position),
			"a line between the tops of %s's spruces flies on" % b.center)
	assert_false(query.ray(from, to, hit) and AABB(lo, b.size).grow(0.01).has_point(hit.position), "a BB too")


## Whether a line along z at `x`, `y` meets one of `boxes`.
static func _meets(boxes: Array[AABB], x: float, y: float) -> bool:
	for t in boxes:
		if x >= t.position.x and x <= t.end.x and y >= t.position.y and y <= t.end.y:
			return true
	return false


func test_the_line_from_the_owner_s_circled_bank_misses_the_thicket_it_used_to_stop_on() -> void:
	# WH1 (the owner's playtest, item 5): a chest seen past the bank's thicket west of Hut row, its spruces half sunk
	# in the slope; TV1's tiers ran out to the block's face there and stopped the line on nothing drawn
	var hit := RayHit.new()
	var query := _woodland.level.query()
	var met := query.ray(CIRCLED_FROM, CIRCLED_TO, hit)
	var in_thicket := false
	if met:
		for b in _woodland.map.blocks:
			if b.kind == &"thicket" and AABB(b.center - b.size * 0.5, b.size).grow(0.01).has_point(hit.position):
				in_thicket = true
	assert_false(in_thicket, "the line flies past the thicket (stopped at %s)" % (hit.position if met else Vector3.ZERO))


# --- item 6: no bot drawn at its spawn in a blink ---

func _ends() -> Array[MapEnd]:
	var ends: Array[MapEnd] = []
	for e in 2:
		var side := -1.0 if e == 0 else 1.0
		var end := MapEnd.new()
		for i in 3:
			end.spawns.append(SpawnPoint.new(Vector3(side * 10.0, 0.0, (i - 1) * 2.0), 0.0))
		for i in 3:
			# far off, so a walk-off is still on its way when its wait runs out
			end.dead_zone.append(SpawnPoint.new(Vector3(side * 28.0, 0.0, 15.0 + i), 0.0))
		ends.append(end)
	return ends


## A 2v2 Attack / Defend on a flat floor, round 1 live; `delay` s each wait (negative: the game's).
func _match(delay: float = -1.0) -> Array:
	var t := tuning
	if delay >= 0.0:
		t = tuning.duplicate() as SimTuning
		t.rounds = tuning.rounds.duplicate() as RoundConfig
		t.rounds.respawn_delay = delay
		t.rounds.defender_respawn_delay = delay
	var w := BoxWorld.new(t.body)
	w.add_floor(80.0, 60.0)
	var sim := Simulation.new(t, w, w.mover(), _ends(), -10.0)
	var state := GameState.new(1, t)
	state.round_state.mode = RoundState.Mode.ATTACK_DEFEND
	state.round_state.pole = Vector3(0.0, 0.0, 14.0)
	for i in 4:
		state.characters.append(Character.new(i, i % 2, Vector3.ZERO, 0.0, loadout))
	sim.start_match(state)
	return [sim, state]


## Steps until `c` is back in play (or `seconds` run out), everyone facing `yaw`; returns the statuses it had, one a
## tick.
func _watch(sim: Simulation, state: GameState, c: Character, seconds: float, yaw: float = 0.0) -> Array[Character.Status]:
	var cmds: Array[PlayerCommand] = []
	for i in 4:
		cmds.append(PlayerCommand.new())
		cmds[i].yaw = yaw
	var seen: Array[Character.Status] = []
	for i in roundi(seconds / DT):
		sim.step(state, cmds, DT)
		seen.append(c.status)
		if c.status == Character.Status.ALIVE:
			break
	return seen


func test_a_walk_off_fades_out_before_it_comes_back() -> void:
	var m := _match()
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var c := state.characters[1]
	c.position = Vector3(0.0, tuning.body.rest_gap, 4.0)
	Elimination.eliminate(c, 0, state.characters, sim.ends)
	var seen := _watch(sim, state, c, 30.0)
	assert_eq(seen[-1], Character.Status.ALIVE, "it comes back")
	assert_true(seen.has(Character.Status.WALKING_OFF), "walking off when its wait ran out")
	var leaving := seen.count(Character.Status.LEAVING)
	assert_almost_eq(leaving * DT, tuning.hits.vanish_time, DT * 1.5, "it faded out over the whole fade")
	assert_ne(seen[-2], Character.Status.WALKING_OFF, "never from walking off straight to its spawn")
	var wait := Respawns.delay(state.round_state, tuning.rounds, c.team)
	assert_almost_eq(seen.size() * DT, wait, DT * 2.0, "back when its wait ran out, as before")


func test_its_team_counts_it_coming_through_the_fade() -> void:
	var m := _match()
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var cmds: Array[PlayerCommand] = []
	for i in 4:
		cmds.append(PlayerCommand.new())
	Elimination.eliminate(state.characters[1], 0, state.characters, sim.ends)
	Elimination.eliminate(state.characters[3], 0, state.characters, sim.ends)
	var c := state.characters[3]
	while c.status != Character.Status.ALIVE and state.time < 30.0:
		sim.step(state, cmds, DT)
		if c.status == Character.Status.LEAVING:
			assert_true(Respawns.waiting(c), "fading out, it still has a respawn coming")
		assert_eq(state.round_state.phase, RoundState.Phase.LIVE, "the round plays on")
	assert_eq(c.status, Character.Status.ALIVE)


func test_one_still_calling_its_hit_calls_walks_and_fades_first() -> void:
	var m := _match(0.5)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var c := state.characters[1]
	Elimination.eliminate(c, 0, state.characters, sim.ends)
	var seen := _watch(sim, state, c, 10.0)
	assert_eq(seen[-1], Character.Status.ALIVE, "it comes back")
	assert_gt(seen.count(Character.Status.CALLING) * DT, tuning.hits.call_time - DT * 2.0, "its hit called whole")
	assert_almost_eq(seen.count(Character.Status.LEAVING) * DT, tuning.hits.vanish_time, DT * 1.5, "then faded")


func test_a_subway_platform_walk_off_steps_down_to_the_east_dead_zone() -> void:
	var r := MatchRunner.new(self, "subway")
	var bots := BotConfig.load_default()
	NavVaults.link(r.nav, r.level.query(), r.tuning.vault, r.tuning.body, bots.vault_price)
	var dz: Vector3 = r.map.ends[1].dead_zone[0].position
	var route := PackedVector3Array()
	# on the platforms, west of the east tunnel's mouth (where the east end's walk-offs stopped against its pier)
	for from: Vector3 in [Vector3(37.7, 0.9, -6.9), Vector3(20.0, 0.9, 6.0)]:
		assert_false(r.nav.find_route(from, dz, route), "no way on foot from %s" % from)
		assert_true(r.nav.find_route(from, dz, route, false, null, true), "down a drop from %s" % from)
		assert_true(route.size() > 1 and route[-1].distance_to(dz) < 0.5, "to its dead-zone spot")
		var down := false
		for i in range(1, route.size()):
			down = down or route[i - 1].y - route[i].y > 0.5
		assert_true(down, "stepping down off the platform")
	r.free_level()


## The first character `c` with the others (all in play) standing 6 m off its walk, facing it, `wall` with a wall between;
## 3 s waits, so it is still walking off near them as its wait runs out.
func _watched(wall: bool) -> Array:
	var m := _match(3.0)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var c := state.characters[1]
	c.position = Vector3(0.0, tuning.body.rest_gap, 4.0)
	for o: Character in [state.characters[0], state.characters[2], state.characters[3]]:
		o.position = Vector3(0.0, tuning.body.rest_gap, -6.0)
		o.yaw = PI
	if wall:
		var w := sim.query as BoxWorld
		w.add_box(Vector3(0.0, 1.5, -3.0), Vector3(40.0, 3.0, 0.4))
	return [sim, state, c]


func test_a_walk_off_someone_watches_walks_on_before_it_fades() -> void:
	var m := _watched(false)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var c: Character = m[2]
	assert_true(Respawns.seen(c, state.characters, tuning, sim.query, RayHit.new()), "the others see it")
	Elimination.eliminate(c, 0, state.characters, sim.ends)
	var seen := _watch(sim, state, c, 40.0, PI)
	assert_eq(seen[-1], Character.Status.ALIVE, "it comes back")
	var wait := 3.0
	var walked := seen.count(Character.Status.WALKING_OFF) * DT
	assert_gt(seen.size() * DT, wait + tuning.hits.seen_most - DT * 3.0, "it walked on, watched, past its wait")
	assert_lt(seen.size() * DT, wait + tuning.hits.seen_most + DT * 6.0, "but no longer than seen_most")
	assert_gt(walked, 0.0, "walking off all that while")
	assert_almost_eq(seen.count(Character.Status.LEAVING) * DT, tuning.hits.vanish_time, DT * 1.5, "then faded")


func test_a_walk_off_nobody_can_see_fades_as_its_wait_runs_out() -> void:
	var m := _watched(true)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var c: Character = m[2]
	assert_false(Respawns.seen(c, state.characters, tuning, sim.query, RayHit.new()), "the wall hides it")
	Elimination.eliminate(c, 0, state.characters, sim.ends)
	var seen := _watch(sim, state, c, 40.0, PI)
	assert_almost_eq(seen.size() * DT, 3.0, DT * 2.0, "back when its wait ran out")


func test_nobody_out_of_play_or_facing_away_sees_it() -> void:
	var m := _watched(false)
	var sim: Simulation = m[0]
	var state: GameState = m[1]
	var c: Character = m[2]
	var hit := RayHit.new()
	for o: Character in [state.characters[0], state.characters[2], state.characters[3]]:
		o.yaw = 0.0
	assert_false(Respawns.seen(c, state.characters, tuning, sim.query, hit), "all facing away")
	state.characters[0].yaw = PI
	Elimination.eliminate(state.characters[0], 1, state.characters, sim.ends)
	assert_false(Respawns.seen(c, state.characters, tuning, sim.query, hit), "the one facing it is out")
	assert_false(Respawns.seen(c, state.characters, tuning, null, hit), "no level, nobody sees")


func test_a_subway_track_walk_off_needing_a_climb_is_refused_without_a_search() -> void:
	var r := MatchRunner.new(self, "subway")
	var bots := BotConfig.load_default()
	NavVaults.link(r.nav, r.level.query(), r.tuning.vault, r.tuning.body, bots.vault_price)
	var dz: Vector3 = r.map.ends[1].dead_zone[0].position
	var route := PackedVector3Array()
	var platform := Vector3(37.7, 0.9, -6.9)
	assert_true(r.nav.find_route(platform, dz, route, false, null, true), "down to the dead zone from the platform")
	# and back up: from the dead zone to the platform only a climb goes
	var before := r.nav.searches
	assert_false(r.nav.find_route(dz, platform, route, false, null, true), "no drop goes up")
	assert_eq(r.nav.searches, before, "refused before any search")
	r.free_level()


func test_a_miss_aimed_up_counts_farther_than_a_level_one() -> void:
	# TV1's guard: a burst 10.4° up at a near target on Woodland's slope knocked out a teammate 71 m on.
	var cfg := BotConfig.load_default()
	var up := Vector3(0.45, 0.18, -0.88)
	assert_eq(BotCombat.miss_reach(cfg, 10.0, Vector3(1.0, 0.0, 0.0)), cfg.friendly_carry, "level: as before")
	assert_eq(BotCombat.miss_reach(cfg, 10.0, Vector3(1.0, -0.2, 0.0)), cfg.friendly_carry, "down: as before")
	assert_gt(BotCombat.miss_reach(cfg, 10.0, up), 71.0, "10° up: past that teammate")
	assert_eq(BotCombat.miss_reach(cfg, 80.0, up), maxf(80.0 + cfg.friendly_beyond_target,
			BotCombat.miss_reach(cfg, 10.0, up)), "a far target: whichever is farther")
