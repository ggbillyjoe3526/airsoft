extends GutTest
## TV1 (the owner's playtest of 0.1 Beta 2, items 3 and 6). Woodland's thickets stand as tiers that narrow with their
## spruces as drawn (TierSteps, MapStyle.tier_steps), each in its box, touching rows with no slot between them, so a
## line grazing a thicket's end past its spruces flies on and one through its middle still stops; only thickets stand
## so. A hit character walking off as its respawn wait runs out leaves the field (its fade) before it comes back, never
## drawn at its spawn in a blink, and its team counts it coming through the fade; one still calling its hit calls
## first. A walk-off with no way on foot steps down a climb's drop: Subway's east end, whose dead zone is on the track
## below the platforms, walks there instead of into a wall.

const DT := 1.0 / 60.0
## A grazing line passes this far (m) inside a thicket's open end, at this height over the ground (a chest).
const GRAZE_IN := 0.1
const CHEST := 1.3
## Room (m) beyond the end, and either side, that no other block may take for the grazing test's thicket.
const CLEAR := 2.5
## A share of a box's height and a side's length to look along for slots, and how far in from the face (m).
const SAMPLES := 6
const FACE_IN := 0.01

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
	var with_tiers := 0
	for b in others:
		var tiers := _tiers(b, others)
		if tiers.is_empty():
			continue
		with_tiers += 1
		var box := AABB(b.center - b.size * 0.5, b.size).grow(1e-4)
		var corners := TierSteps.CORNERS.size()
		var tier_count: int = play.map_style.tier_steps[&"spruce"].size()
		for t in tiers:
			assert_true(box.encloses(t), "a tier of %s lies in its box" % b.center)
		# the tiers' boxes come CORNERS a tier, from the foot up: none reaches further out than the one under it
		for k in range(1, tier_count):
			for c in corners:
				var low := tiers[(k - 1) * corners + c]
				var high := tiers[k * corners + c]
				assert_almost_eq(high.position.y, low.end.y, 1e-4, "tier %d stands on the one below" % k)
				assert_true(high.position.x >= low.position.x - 1e-4 and high.end.x <= low.end.x + 1e-4
						and high.position.z >= low.position.z - 1e-4 and high.end.z <= low.end.z + 1e-4,
						"tier %d of %s draws in" % [k, b.center])
	assert_gt(with_tiers, 50, "most thickets have an open side")


func test_touching_thickets_leave_no_slot_between_them() -> void:
	var m := _woodland.map
	var others := TierSteps.tiered_blocks(m, play.map_style, play.site_look.props)
	var looked := 0
	for b in others:
		var tiers := _tiers(b, others)
		if tiers.is_empty():
			continue
		var b_box := AABB(b.center - b.size * 0.5, b.size)
		var lo := b.center - b.size * 0.5
		var hi := b.center + b.size * 0.5
		for axis: int in [0, 2]:
			for side: float in [-1.0, 1.0]:
				var along := 2 - axis
				for o in others:
					if o == b:
						continue
					var face := hi[axis] if side > 0.0 else lo[axis]
					var o_face := (o.center - o.size * 0.5)[axis] if side > 0.0 else (o.center + o.size * 0.5)[axis]
					if absf(face - o_face) > TierSteps.TOUCH:
						continue
					var from := maxf(lo[along], o.center[along] - o.size[along] * 0.5)
					var to := minf(hi[along], o.center[along] + o.size[along] * 0.5)
					if to - from < 0.1:
						continue
					var o_tiers := _tiers(o, others)
					var o_box := AABB(o.center - o.size * 0.5, o.size)
					for i in SAMPLES:
						for j in SAMPLES:
							# on the seam, up to the lower of the two tops, through the lower half of the box (where
							# bodies are): just inside this block or just inside the other
							var p := Vector3.ZERO
							p[axis] = face - side * FACE_IN
							p[along] = lerpf(from, to, (i + 0.5) / SAMPLES)
							p.y = lo.y + b.size.y * 0.5 * (j + 0.5) / SAMPLES
							if p.y > minf(b_box.end.y, o_box.end.y) or p.y < maxf(lo.y, o_box.position.y):
								continue
							var q := p
							q[axis] = face + side * FACE_IN
							looked += 1
							var shut := _inside(tiers, p) or (o_tiers.is_empty() and o_box.has_point(q)) \
									or _inside(o_tiers, q)
							assert_true(shut, "the seam between %s and %s is closed at %s" % [b.center, o.center, p])
	assert_gt(looked, 1000, "the faces between touching rows were looked along")


static func _inside(boxes: Array[AABB], p: Vector3) -> bool:
	for box in boxes:
		if box.grow(1e-4).has_point(p):
			return true
	return false


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


## Steps until `c` is back in play (or `seconds` run out); returns the statuses it had, one a tick.
func _watch(sim: Simulation, state: GameState, c: Character, seconds: float) -> Array[Character.Status]:
	var cmds: Array[PlayerCommand] = []
	for i in 4:
		cmds.append(PlayerCommand.new())
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
