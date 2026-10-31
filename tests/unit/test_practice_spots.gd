extends GutTest
## Practice on any field (WL9; the browser game's map/practiceSpots.test.ts, practiceLayout.test.ts and
## rangeSessionMapPractice.test.ts, M94): Practice offered on every field, its targets laid out from the map's own data on
## Depot and Woodland (lane points facing back down their lane, the other end's spawns, points along long
## legs, each on the floor, none near your start or crowding another, crouched behind low cover, steel, movers and
## swingers where they fit), the START plate ahead of your start, the challenge lighting only what you can see, a best
## per map, and a practice session on Depot by day and on Woodland at night with your torch.

const MAPS: Array[String] = ["depot", "woodland"]
const RECORDS := "user://test_wl9_records.save"
const AEG := "000002"
const TORCH := "000020"
## How near (m) a target must stand to the floor a ray finds under it.
const ON_FLOOR := 0.05

var tuning: SimTuning = SimTuning.load_default()
var cfg: RangeConfig = tuning.targets
var hit: RayHit = RayHit.new()
var cases: Dictionary[String, Case] = {}


## One map's layout and what its own colliders say about each target, taken while its level alone stood (levels all
## stand at the origin, so two at once would meet each other's rays).
class Case:
	extends RefCounted
	var map: MapData = null
	var specs: Array[RangeTarget.Spec] = []
	var spots: Array[PracticeSpots.Spot] = []
	var again: Array[RangeTarget.Spec] = []
	## Per target: the floor a ray finds under it (NAN for none), and whether a wall stands right in front of its face.
	var floor_hit: PackedFloat64Array = PackedFloat64Array()
	var walled: Array[bool] = []
	## Whether anything stands between your eye at the start and the START plate.
	var start_blocked: bool = true


func before_all() -> void:
	# The yard too (the old Depot, DR1): its end-1 spawns are in reach of the target cap, the hall's lanes fill it first.
	# And the old wood (OldWoodland, WR1), whose lane points stand behind low cover.
	for id: String in MAPS + ["yard", "old_woodland"]:
		var c := Case.new()
		if id == "yard":
			c.map = YardMap.load_map(MapStyle.new(), 1)
		elif id == "old_woodland":
			c.map = OldWoodland.load_map(MapStyle.new(), 1)
		else:
			c.map = MapData.load_map(id, MapStyle.new(), 1)
		var level := MapLevel.new()
		add_child(level)
		level.build(c.map, MapStyle.new(), tuning.body)
		var nav := NavGrid.build(c.map, tuning.nav, tuning.body)
		var query := level.query()
		c.specs = PracticeSpots.layout(c.map, nav, query, tuning)
		c.spots = PracticeSpots.spots(c.map, nav, query, cfg)
		c.again = PracticeSpots.layout(c.map, nav, query, tuning)
		var s := PracticeSpots.start_of(c.map)
		var eye := s.position + Vector3.UP * (tuning.body.rest_gap + tuning.body.stand_eye_height)
		for t in c.specs:
			var feet := _feet(t)
			var top := Vector3(t.position.x, feet + 0.5, t.position.z)
			c.floor_hit.append(hit.position.y if query.ray(top, top + Vector3.DOWN, hit) else NAN)
			c.walled.append(PracticeSpots.blocked(Vector3(t.position.x, feet + cfg.field_high_ray, t.position.z),
					Vector2(sin(t.yaw), cos(t.yaw)), cfg.field_cover_reach, query))
			if t.start:
				c.start_blocked = query.ray(eye, t.position, hit)
		cases[id] = c
		level.free()


func after_all() -> void:
	SaveFile.remove(RECORDS)


## The floor a target stands on: a figure's feet (a mover's trolley under them), a plate's post's foot.
func _feet(s: RangeTarget.Spec) -> float:
	if s.kind == RangeTarget.Kind.STEEL:
		return s.position.y - (cfg.start_height if s.start else cfg.plate_height)
	return s.position.y - (cfg.mover_trolley_height if s.motion == RangeTarget.Motion.MOVER else 0.0)


# --- the Match page ---

func test_practice_is_offered_on_every_field() -> void:
	var catalog := MapCatalog.shared()
	for e in catalog.fields(true):
		assert_true(MatchOptions.modes_offered(e).has(MatchOptions.MODE_PRACTICE), e.id)
		assert_true(MatchOptions.mode_pickable(MatchOptions.MODE_PRACTICE, e, false), "%s, with or without a pole" % e.id)
		assert_eq(MatchOptions.only_tag_key(MatchOptions.MODE_PRACTICE, e), "", e.id)
	var public_ids := PackedStringArray()
	for e in catalog.fields(false):
		public_ids.append(e.id)
	assert_true(public_ids.has("woodland"), "Woodland is public (owner, 2026-10-29)")
	assert_eq(MatchOptions.modes_offered(catalog.find("range")), PackedStringArray([MatchOptions.MODE_PRACTICE]))


func test_practice_picked_on_a_field_stays_picked_on_the_next_field() -> void:
	var settings := Settings.new()
	settings.dev.dev_content = true
	var page := MatchPage.new(MatchPicks.new(), settings)
	add_child_autofree(page)
	page.mode_card("practice").pressed.emit()
	assert_eq(page.picks.mode, MatchOptions.MODE_PRACTICE)
	assert_false(page.mode_card("practice").disabled, "Depot hosts Practice")
	assert_eq(page.play_button().text, "PRACTICE")
	page.map_card("woodland").pressed.emit()
	assert_eq(page.picks.mode, MatchOptions.MODE_PRACTICE, "still Practice on Woodland")
	page.map_card("range").pressed.emit()
	page.map_card("depot").pressed.emit()
	assert_eq(page.picks.mode, MatchOptions.MODE_PRACTICE, "you picked Practice, the Range didn't")


# --- the layout ---

func test_targets_come_from_the_map_alone_on_depot_and_woodland() -> void:
	for id in MAPS:
		var c := cases[id]
		var specs := c.specs
		var kinds: Dictionary[String, int] = {}
		for s in specs:
			kinds[s.label] = kinds.get(s.label, 0) + 1
		gut.p("%s: %d targets %s" % [id, specs.size(), kinds])
		assert_gt(specs.size(), 10, "%s: a field's worth of targets" % id)
		assert_lte(specs.size(), cfg.field_max_targets + 1, id)
		assert_gt(kinds.get(PracticeSpots.STEEL, 0), 0, "%s: steel" % id)
		assert_gt(kinds.get(PracticeSpots.FIGURE, 0), 0, "%s: figures" % id)
		assert_gt(kinds.get(PracticeSpots.POPUP, 0), 0, "%s: pop-ups" % id)
		assert_eq(kinds.get(PracticeSpots.START, 0), 1, "%s: one START plate" % id)
		var off_floor: Array[String] = []
		var near_start: Array[String] = []
		var walled: Array[String] = []
		for i in specs.size():
			var s := specs[i]
			if is_nan(c.floor_hit[i]) or absf(c.floor_hit[i] - _feet(s)) > ON_FLOOR:
				off_floor.append("%s at %s" % [s.label, s.position])
			if s.start:
				continue
			for sp in c.map.ends[0].spawns:
				if Vector2(sp.position.x - s.position.x, sp.position.z - s.position.z).length() < cfg.field_clear_of_start:
					near_start.append("%s at %s" % [s.label, s.position])
			if c.walled[i]:
				walled.append("%s at %s" % [s.label, s.position])
		assert_eq(off_floor, [] as Array[String], "%s: every target on the floor" % id)
		assert_eq(near_start, [] as Array[String], "%s: none near your end's spawns" % id)
		assert_eq(walled, [] as Array[String], "%s: none faces a wall" % id)


func test_no_two_targets_crowd_each_other_on_a_floor() -> void:
	for id in MAPS:
		var specs := cases[id].specs
		var crowded := 0
		for i in specs.size():
			for j in range(i + 1, specs.size()):
				var a := specs[i]
				var b := specs[j]
				if a.start or b.start:
					continue
				if Vector2(a.position.x - b.position.x, a.position.z - b.position.z).length() < cfg.field_min_gap - 0.01 \
						and absf(_feet(a) - _feet(b)) < cfg.field_storey_gap:
					crowded += 1
		assert_eq(crowded, 0, id)


func test_lane_points_face_back_down_their_lane_and_the_other_end_faces_your_start() -> void:
	var m := cases["yard"].map
	var spots := cases["yard"].spots
	var start := PracticeSpots.start_of(m).position
	var back_down := 0
	var lane_spots := 0
	var at_their_start := 0
	for s in spots:
		if s.source == PracticeSpots.Source.LANE:
			lane_spots += 1
			for lane in m.lanes:
				for i in range(1, lane.size()):
					if Vector2(lane[i].x - s.position.x, lane[i].z - s.position.z).length() < 0.01:
						var back := Vector2(lane[i - 1].x - lane[i].x, lane[i - 1].z - lane[i].z).normalized()
						back_down += 1 if s.face.dot(back) > 0.999 else 0
		elif s.source == PracticeSpots.Source.START:
			at_their_start += 1
			var to_start := Vector2(start.x - s.position.x, start.z - s.position.z).normalized()
			assert_gt(s.face.dot(to_start), 0.999, "an end-1 spawn faces your start")
	assert_gt(lane_spots, 5)
	assert_gt(back_down, 3, "lane points watch back down their lane")
	assert_gt(at_their_start, 0, "the other end's spawns")
	var from := 0.0
	for s in spots:
		assert_gte(s.from_start, from, "near to far")
		from = s.from_start


func test_crouched_figures_movers_and_swingers_stand_where_they_fit() -> void:
	var crouched := 0
	var movers := 0
	var swingers := 0
	for id in cases:
		for s in cases[id].specs:
			crouched += 1 if s.crouched else 0
			movers += 1 if s.motion == RangeTarget.Motion.MOVER else 0
			swingers += 1 if s.motion == RangeTarget.Motion.SWINGER else 0
			if s.motion == RangeTarget.Motion.MOVER:
				assert_eq(s.track, cfg.field_mover_track)
				assert_true(cfg.field_mover_speeds.has(s.speed))
			if s.crouched:
				assert_eq(s.kind, RangeTarget.Kind.FIGURE)
	assert_gt(crouched, 0, "behind low cover")
	assert_gt(movers, 0, "on a lane's leg")
	# No steel spot on Depot or Woodland has room for a frame (Neon Heights' did): the fit is tested on its own below.
	gut.p("swingers on the fields: %d" % swingers)


## A swinger's frame fits on open level floor, and not with a wall within its legs' reach.
func test_a_swinger_fits_on_open_floor_and_not_beside_a_wall() -> void:
	var floor_block := {"kind": "floor", "center": {"x": 0, "y": -0.25, "z": 0}, "size": {"x": 30, "y": 0.5, "z": 30}}
	var wall := {"kind": "wall", "center": {"x": 1.0, "y": 1.0, "z": 0}, "size": {"x": 0.2, "y": 2, "z": 3}}
	var spot := PracticeSpots.Spot.new()
	for blocks: Array in [[floor_block], [floor_block, wall]]:
		var map := MapData.parse(JSON.stringify({"name": "Flat", "blocks": blocks}), MapStyle.new(), 1)
		var level := MapLevel.new()
		add_child(level)
		level.build(map, MapStyle.new(), tuning.body)
		var nav := NavGrid.build(map, tuning.nav, tuning.body)
		var fits := PracticeSpots._swinger_fits(spot, nav, level.query(), cfg)
		assert_eq(fits, blocks.size() == 1, "open floor" if blocks.size() == 1 else "a wall 0.9 m to the side")
		level.free()


func test_the_start_plate_stands_ahead_of_your_start_in_plain_sight() -> void:
	for id in MAPS:
		var m := cases[id].map
		var s := PracticeSpots.start_of(m)
		var plate: RangeTarget.Spec = null
		for t in cases[id].specs:
			if t.start:
				plate = t
		assert_not_null(plate, id)
		if plate == null:
			continue
		var away := Vector2(plate.position.x - s.position.x, plate.position.z - s.position.z)
		assert_true(cfg.field_start_ahead.has(snappedf(away.length(), 0.001)), "%s: %.2f m ahead" % [id, away.length()])
		var ahead := Vector2(-sin(s.yaw), -cos(s.yaw))
		assert_gt(away.normalized().dot(ahead), cos(1.06), "%s: in front of you" % id)
		assert_lte(absf(_feet(plate) - s.position.y), cfg.field_start_climb, id)
		assert_false(cases[id].start_blocked, "%s: nothing between your eye and it" % id)


func test_the_layout_is_the_same_every_time() -> void:
	for id in MAPS:
		var c := cases[id]
		assert_eq(c.again.size(), c.specs.size(), id)
		for i in mini(c.again.size(), c.specs.size()):
			assert_eq(c.again[i].position, c.specs[i].position)
			assert_eq(c.again[i].label, c.specs[i].label)


# --- the timed challenge on a field ---

func test_on_a_field_the_challenge_lights_only_targets_in_your_sight() -> void:
	var world := BoxWorld.new(tuning.body)
	world.add_floor(80.0, 80.0)
	world.add_box(Vector3(0.0, 1.5, -9.0), Vector3(3.0, 3.0, 0.4))
	var specs: Array[RangeTarget.Spec] = []
	for at: Vector3 in [Vector3(0.0, 0.0, -12.0), Vector3(6.0, 0.0, -12.0), Vector3(0.0, 0.0, -60.0)]:
		var f := RangeTarget.Spec.new()
		f.kind = RangeTarget.Kind.FIGURE
		f.position = at
		f.label = PracticeSpots.FIGURE
		specs.append(f)
	var start := RangeTarget.Spec.new()
	start.position = Vector3(0.0, cfg.start_height, -4.0)
	start.radius = cfg.plate_radius
	start.start = true
	specs.append(start)
	var rng := Seeds.stream(9)
	var targets := RangeTargets.create(specs, tuning, rng)
	var me := Character.new(0, 0, Vector3(0.0, tuning.body.rest_gap, 0.0), 0.0, ReplicaStats.default_loadout())
	var c := RangeChallenge.new("depot", 0)
	c.sight = RangeChallenge.Sight.new()
	c.sight.query = world
	c.sight.watcher = me
	c.sight.body = tuning.body
	c.sight.hits = tuning.hits
	c.sight.reach = cfg.field_sight_reach
	assert_false(c.sight.sees(targets[0]), "behind the wall")
	assert_true(c.sight.sees(targets[1]), "in the open")
	assert_false(c.sight.sees(targets[2]), "beyond the sight reach")
	assert_almost_eq(c.sight.away(targets[1]), Vector2(6.0, 12.0).length(), 1e-4)
	c.set_on(true, targets, cfg, rng)
	var events := SimEvents.new()
	var e := events.add(GameEvent.Kind.TARGET_HIT)
	e.actor = 0
	e.target = 3
	c.step(targets, events, cfg, 1.0 / 60.0, rng, false)
	events.clear()
	for i in roundi((cfg.challenge_countdown + 1.0) * 60.0):
		if c.phase == RangeChallenge.Phase.RUNNING:
			break
		c.step(targets, events, cfg, 1.0 / 60.0, rng, false)
	assert_eq(c.phase, RangeChallenge.Phase.RUNNING)
	assert_eq(targets[0].lit, 0.0, "never the one behind the wall")
	assert_eq(targets[2].lit, 0.0, "nor the one too far")
	assert_almost_eq(targets[1].lit, cfg.challenge_lit_time + cfg.challenge_lit_per_metre * Vector2(6.0, 12.0).length(),
			1e-4, "lit for how far it is from where you stand")


func test_on_a_field_a_run_with_nothing_in_sight_looks_again_only_now_and_then() -> void:
	var world := CountingWorld.new(tuning.body)
	world.add_floor(80.0, 80.0)
	world.add_box(Vector3(0.0, 1.5, -9.0), Vector3(3.0, 3.0, 0.4))
	var figure := RangeTarget.Spec.new()
	figure.kind = RangeTarget.Kind.FIGURE
	figure.position = Vector3(0.0, 0.0, -12.0)
	figure.label = PracticeSpots.FIGURE
	var start := RangeTarget.Spec.new()
	start.position = Vector3(0.0, cfg.start_height, -4.0)
	start.radius = cfg.plate_radius
	start.start = true
	var specs: Array[RangeTarget.Spec] = [figure, start]
	var rng := Seeds.stream(9)
	var targets := RangeTargets.create(specs, tuning, rng)
	var me := Character.new(0, 0, Vector3(0.0, tuning.body.rest_gap, 0.0), 0.0, ReplicaStats.default_loadout())
	var c := RangeChallenge.new("depot", 0)
	c.sight = RangeChallenge.Sight.new()
	c.sight.query = world
	c.sight.watcher = me
	c.sight.body = tuning.body
	c.sight.hits = tuning.hits
	c.sight.reach = cfg.field_sight_reach
	c.set_on(true, targets, cfg, rng)
	var events := SimEvents.new()
	var e := events.add(GameEvent.Kind.TARGET_HIT)
	e.actor = 0
	e.target = 1
	c.step(targets, events, cfg, 1.0 / 60.0, rng, false)
	events.clear()
	while c.phase != RangeChallenge.Phase.RUNNING:
		c.step(targets, events, cfg, 1.0 / 60.0, rng, false)
	world.rays = 0
	for i in 60:
		c.step(targets, events, cfg, 1.0 / 60.0, rng, false)
	assert_eq(targets[0].lit, 0.0, "behind the wall")
	assert_between(world.rays, 1, ceili(1.0 / cfg.field_sight_retry) + 1, "a look every %.2f s, not every tick"
			% cfg.field_sight_retry)
	# Step out from behind the wall: the figure lights within one retry.
	me.position.x = 8.0
	for i in ceili(cfg.field_sight_retry * 60.0) + 1:
		c.step(targets, events, cfg, 1.0 / 60.0, rng, false)
	assert_gt(targets[0].lit, 0.0, "in sight again")


func test_each_map_keeps_its_own_best_old_range_bests_carry_over_and_a_helped_run_never_counts() -> void:
	var r := Records.new()
	r.from_dict({"best_challenge": {"range": 14}})
	assert_eq(r.challenge_best("range"), 14, "a range best saved before WL9 carries over")
	var run := RangeChallenge.Run.new()
	run.hits = 9
	assert_true(r.add_challenge_run("depot", run))
	assert_eq(r.challenge_best("depot"), 9)
	assert_eq(r.challenge_best("range"), 14, "each map its own")
	var helped := RangeChallenge.Run.new()
	helped.hits = 30
	helped.helped = true
	assert_false(r.add_challenge_run("woodland", helped), "a play-changing Dev setting: never a best")
	assert_eq(r.challenge_best("woodland"), 0)
	assert_true(r.save(RECORDS))
	var back := Records.new()
	back.load_file(RECORDS)
	assert_eq(back.challenge_best("depot"), 9, "saved through SaveFile")


func test_on_a_field_the_readout_counts_from_where_you_stand_and_only_a_fall_off_the_world_is_out() -> void:
	var r := HudRangeReadout.new()
	add_child_autofree(r)
	r.setup(cfg, 0, true, -10.0)
	assert_eq(r.lines()[0], "PRACTICE")
	var state := GameState.new(1, tuning)
	state.characters.append(Character.new(0, 0, Vector3(3.0, 0.0, 4.0), 0.0, ReplicaStats.default_loadout()))
	var e := state.events.add(GameEvent.Kind.BB_IMPACT)
	e.actor = 0
	e.position = Vector3(3.0, 0.0, -8.0)
	r.on_tick(state)
	assert_eq(r.lines()[1], "Missed landed 12 m away")
	state.events.clear()
	e = state.events.add(GameEvent.Kind.BB_LOST)
	e.actor = 0
	e.position = Vector3(3.0, 2.0, 84.0)
	r.on_tick(state)
	assert_eq(r.lines()[1], "Missed landed 80 m away", "far past any range wall, still over the field")
	state.events.clear()
	e = state.events.add(GameEvent.Kind.BB_LOST)
	e.actor = 0
	e.position = Vector3(3.0, -12.0, 4.0)
	r.on_tick(state)
	assert_eq(r.last().kind, HudRangeReadout.Kind.OUT, "below the world: out")


# --- practice sessions ---

func test_practice_on_depot_has_no_bots_no_score_and_starts_you_at_end_0s_first_spawn() -> void:
	var session := PlaySession.new()
	session.practice = true
	session.challenge_on = true
	session.map_id = "depot"
	session.player_team = PlaySession.TEAM_BETA
	session.settings = Settings.new()
	add_child_autofree(session)
	assert_eq(session.state.characters.size(), 1, "no bots")
	assert_true(session.state.round_state.practice, "no rounds, no score")
	var first := cases["depot"].map.ends[0].spawns[0].position
	assert_almost_eq(session.player.position.x, first.x, 0.05)
	assert_almost_eq(session.player.position.z, first.z, 0.05)
	assert_eq(session.state.targets.size(), cases["depot"].specs.size(), "the layout")
	assert_true(RangeChallenge.has_start(session.state.targets))
	assert_eq(session.state.challenge.phase, RangeChallenge.Phase.READY, "the challenge on, START standing")
	assert_eq(session.state.challenge.course, "depot", "Depot's own best")
	assert_not_null(session.state.challenge.sight, "lighting only what you see")
	assert_eq(session.find_children("*", "RangeView", true, false).size(), 0, "no range markings on a field")
	assert_eq(session.hud().range_readout().lines()[0], "PRACTICE")
	assert_eq(session.player.yaw, _start_yaw(session.state.targets), "facing the START plate")


func test_practice_on_woodland_plays_by_day_and_by_night_with_your_torch_fitted() -> void:
	var settings := Settings.new()
	var rules := LoadoutRules.standard()
	var l := rules.default_loadout("Night")
	rules.set_part(l, AEG, &"light", TORCH)
	for pick: StringName in [&"", LightingConfig.NIGHT]:
		var session := PlaySession.new()
		session.practice = true
		session.map_id = "woodland"
		session.lighting_pick = pick
		session.settings = settings
		session.kit = rules.carried(l)
		add_child_autofree(session)
		var night := pick == LightingConfig.NIGHT
		assert_eq(session.lighting().night, night, "Woodland by day first, by night when picked (WR1)")
		assert_eq(session.state.characters.size(), 1, "no bots")
		var fitted := false
		for light in session.player.armament.lights:
			fitted = fitted or light != null
		assert_eq(fitted, night, "your torch fitted at night only")
		assert_gt(session.state.targets.size(), 10)
		assert_false(session.state.dev_content, "the torch and the map are public")


func _start_yaw(targets: Array[RangeTarget]) -> float:
	for t in targets:
		if t.start:
			return t.yaw
	return NAN


## A BoxWorld that counts its rays.
class CountingWorld:
	extends BoxWorld
	var rays: int = 0

	func ray(from: Vector3, to: Vector3, hit: RayHit) -> bool:
		rays += 1
		return super.ray(from, to, hit)
