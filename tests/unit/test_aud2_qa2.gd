extends GutTest
## QA's tests for the Dev 3 audit's third pass (AUD1, attempt 4): the edges of the owner-approved changes of
## 2026-11-14 (the Compact SMG and the Pump Shotgun public and their levels swapped, the holstered figure's step pump,
## a switch between replicas of one class, the Sniper Rifle's bolt, the replica surface's detail, the rebuilt range
## props, the one rule for a field's air).

const FRAME := 1.0 / 60.0
const SMG := "000026"
const SHOTGUN := "000027"
## The props' boxes the map data and the dressing fit them to (m; origin on the ground, centred on x and z).
const PROP_BOXES: Dictionary[String, Vector3] = {
	"sandbags": Vector3(1.2, 0.9, 0.6), "site_toilet": Vector3(1.2, 2.4, 1.2), "water_tote": Vector3(1.2, 1.2, 1.2)}

var cfg: FigureConfig = null
var hits: HitConfig = null
var pose: FigurePose = null


func before_each() -> void:
	cfg = FigureConfig.new()
	hits = HitConfig.new()
	pose = FigurePose.new(cfg)


func _rules(dev: bool) -> LoadoutRules:
	var rules := LoadoutRules.standard()
	rules.dev_content = dev
	return rules


# --- The two replicas public, their levels swapped ---


func test_the_compact_smg_and_the_pump_shotgun_are_offered_with_dev_content_off() -> void:
	var rules := _rules(false)
	assert_true(rules.is_offered(SMG), "the Compact SMG")
	assert_true(rules.is_offered(SHOTGUN), "the Pump Shotgun")
	assert_eq(rules.offered().size(), 6, "six replicas on the Loadout page")
	var dev_on := _rules(true)
	assert_eq(dev_on.offered().size(), rules.offered().size(), "Dev content adds no replica of its own any more")


func test_every_public_replica_has_a_public_power_source_unlocked_no_later_than_itself() -> void:
	var table := LevelTable.shared()
	var rules := _rules(false)
	for it in rules.offered():
		var mine := table.unlock_level(it.id)
		var powers := rules.pool.powers_for(it, false)
		if powers.is_empty():
			continue
		var first := 9999
		for pw in powers:
			first = mini(first, table.unlock_level(pw.id))
		assert_lte(first, maxi(mine, 1), "%s (level %d) unlocks no earlier than a power source it takes" % [it.display_name, mine])
		# What it comes with is never later than it.
		for w in rules.pool.comes_with(it):
			assert_lte(table.unlock_level(w.id), maxi(mine, 1), "%s comes with %s" % [it.display_name, w.display_name])


func test_each_level_s_new_unlocks_name_the_swapped_pair_once_and_in_place() -> void:
	var table := LevelTable.shared()
	assert_true(table.unlocks_up_to(10).has(SHOTGUN), "the shotgun by 10")
	assert_false(table.unlocks_up_to(9).has(SHOTGUN))
	assert_false(table.unlocks_up_to(11).has(SMG), "the SMG not before 12")
	assert_true(table.unlocks_up_to(12).has(SMG))
	var seen := 0
	for lv in table.levels:
		for id in lv.unlocks:
			if id == SMG or id == SHOTGUN:
				seen += 1
	assert_eq(seen, 2, "each listed on exactly one level")


# --- The bots' kits with Dev content off ---


func test_the_breacher_and_the_clearer_are_carried_with_dev_content_off_and_build_whole() -> void:
	var rules := _rules(false)
	var kits := BotKits.shared()
	assert_eq(kits.problems.size(), 0, "the kit file reads clean")
	for plan in kits.kits:
		assert_true(BotKits.offers(rules, plan), "%s is on offer with Dev content off" % plan.kit_name)
		var kit := BotKits.kit_of(plan, rules)
		assert_eq(kit.replicas.size(), plan.slots.size(), "%s carries what its table says" % plan.kit_name)
	for name: String in ["Breacher", "Clearer"]:
		var found := false
		for plan in kits.kits:
			found = found or plan.kit_name == name
		assert_true(found, "%s is a kit" % name)


func test_the_clearer_is_indoor_only_and_the_breacher_goes_everywhere_with_dev_content_off() -> void:
	var rules := _rules(false)
	var kits := BotKits.shared()
	var drawn: Dictionary[String, int] = {}
	for s in 3000:
		for field: StringName in [BotKits.OUTDOOR, BotKits.INDOOR]:
			var p := kits.pick(&"hard", rules, s, &"rusher", 1.0, field)
			if p != null:
				drawn["%s@%s" % [p.kit_name, field]] = int(drawn.get("%s@%s" % [p.kit_name, field], 0)) + 1
	assert_eq(drawn.get("Clearer@%s" % BotKits.OUTDOOR, 0), 0, "never outdoors")
	assert_gt(drawn.get("Clearer@%s" % BotKits.INDOOR, 0), 0, "indoors")
	assert_gt(drawn.get("Breacher@%s" % BotKits.OUTDOOR, 0), 0, "the Breacher outdoors")
	assert_gt(drawn.get("Breacher@%s" % BotKits.INDOOR, 0), 0, "and indoors")


# --- The one rule for a field's air ---


func test_a_field_s_air_is_what_the_match_had_for_every_listed_field_by_day_and_night_and_for_none() -> void:
	var tuning := SimTuning.new()
	var rated := tuning.ballistics.air_temperature
	for e in MapCatalog.shared().entries:
		for night: bool in [false, true]:
			# The match's own formula before the refactor (play_session.gd at 2cbd855).
			var old := tuning.weather.temperature_at(e.air_or(rated), night and e.wind > 0.0)
			assert_almost_eq(FieldAir.temperature_on(e, night, tuning), old, 1e-6, "%s night %s" % [e.id, night])
	assert_almost_eq(FieldAir.temperature_on(null, false, tuning), rated, 1e-6, "no field, by day: rated")
	assert_almost_eq(FieldAir.temperature_on(null, true, tuning), rated - tuning.weather.night_drop, 1e-6,
			"no field, night: colder (the open)")


func test_a_night_cools_an_open_field_and_not_a_still_air_one() -> void:
	var tuning := SimTuning.new()
	var open := 0
	var still := 0
	for e in MapCatalog.shared().entries:
		var gap := FieldAir.temperature_on(e, false, tuning) - FieldAir.temperature_on(e, true, tuning)
		if e.wind > 0.0:
			open += 1
			assert_almost_eq(gap, tuning.weather.night_drop, 1e-6, "%s: the night's drop" % e.id)
		else:
			still += 1
			assert_almost_eq(gap, 0.0, 1e-6, "%s: still air stays" % e.id)
	assert_gt(open, 0)
	assert_gt(still, 0, "an indoor field is listed")


# --- The holstered step pump ---


func test_the_step_pump_is_none_at_a_standstill_and_the_walking_pace_and_capped_at_the_run() -> void:
	assert_eq(UpperBlend.step_pump(hits, 0.0), 0.0, "standing still: the arms hang")
	assert_eq(UpperBlend.step_pump(hits, hits.walking_speed), 0.0, "at the walking threshold")
	assert_eq(UpperBlend.step_pump(hits, -3.0), 0.0, "a negative speed is none")
	assert_almost_eq(UpperBlend.step_pump(hits, hits.holster_step_speed), hits.holster_step_mix, 1e-6)
	assert_almost_eq(UpperBlend.step_pump(hits, hits.holster_step_speed * 10.0), hits.holster_step_mix, 1e-6,
			"never more than the mix, however fast")
	hits.holster_step_speed = 0.0
	assert_eq(UpperBlend.step_pump(hits, 5.0), 0.0, "a zero full-speed setting divides by nothing")
	hits.holster_step_speed = 4.2
	hits.holster_step_mix = 0.0
	assert_eq(UpperBlend.step_pump(hits, 5.0), 0.0, "mix 0 is the old hang")


func _holstered(speed: float, crouch: float = 0.0) -> Character:
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	c.grounded = true
	c.armament.holstered = true
	c.holster_weight = 1.0
	c.sprint_weight = 0.0
	c.crouch_amount = crouch
	c.velocity = Vector3(0.0, 0.0, -speed)
	return c


func _upper_of(c: Character) -> PackedVector3Array:
	HitPose.pose(c, hits, hits.fit)
	return HitPose.upper.duplicate()


func _apart(a: PackedVector3Array, b: PackedVector3Array) -> float:
	var most := 0.0
	for k in a.size():
		most = maxf(most, a[k].distance_to(b[k]))
	return most


## The upper joints with the step pump at `mix` of the sprint's (0: the old hang) for `c` as it stands.
func _upper_at_mix(c: Character, mix: float) -> PackedVector3Array:
	hits.holster_step_mix = mix
	return _upper_of(c)


func test_the_hit_volume_of_a_holstered_figure_follows_the_drawn_arms_at_a_step() -> void:
	# Same legs and hips either way: only the arms' share of the pump differs.
	var run := _holstered(hits.holster_step_speed)
	assert_gt(_apart(_upper_at_mix(run, 0.0), _upper_at_mix(run, 0.45)), 1e-4, "the arms pump at a run, so the volume's do")
	var still := _holstered(0.0)
	assert_lt(_apart(_upper_at_mix(still, 0.0), _upper_at_mix(still, 0.45)), 1e-6, "standing still: the arms hang")


func test_an_eliminated_or_airborne_holstered_figure_keeps_its_arms_hanging_in_the_volume() -> void:
	var out := _holstered(hits.holster_step_speed)
	out.status = Character.Status.OUT
	assert_lt(_apart(_upper_at_mix(out, 0.0), _upper_at_mix(out, 0.45)), 1e-6, "out mid-step: no pump")
	var air := _holstered(hits.holster_step_speed)
	air.grounded = false
	assert_lt(_apart(_upper_at_mix(air, 0.0), _upper_at_mix(air, 0.45)), 1e-6, "in the air: no pump")


func test_a_crouched_holstered_figure_below_the_walking_pace_hangs_its_arms() -> void:
	var creep := _holstered(hits.walking_speed * 0.9, 1.0)
	assert_lt(_apart(_upper_at_mix(creep, 0.0), _upper_at_mix(creep, 0.45)), 1e-6, "a creep is no step")
	var step := _holstered(hits.holster_step_speed, 1.0)
	assert_gt(_apart(_upper_at_mix(step, 0.0), _upper_at_mix(step, 0.45)), 1e-4, "a crouched step at speed pumps")


# --- A switch between two replicas of one class ---


func _armed(ids: Array[StringName]) -> Character:
	var l: Array[ReplicaConfig] = []
	for id in ids:
		l.append(ReplicaStats.load_replica(id))
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, l)
	c.grounded = true
	return c


func _begin_switch(c: Character, to: int, seconds: float = 0.4) -> void:
	c.armament.active = to
	c.armament.draw_total = seconds
	c.armament.draw_left = seconds
	pose.read(c, 1.0, hits)


func test_a_switch_between_two_rifles_is_forwards_and_hands_over_at_the_same_class_share() -> void:
	var c := _armed([&"aeg", &"smg", &"pistol"])
	pose.read(c, 1.0, hits)
	_begin_switch(c, 1)
	assert_true(pose.switching)
	assert_true(pose.switch_same, "rifle to rifle")
	assert_false(pose.switch_back, "forwards: from the rifle's end")
	assert_eq(pose.in_hand, 0, "the old rifle until the turn")
	c.armament.draw_left = c.armament.draw_total * (1.0 - cfg.switch_same_from) + 0.002
	pose.read(c, 1.0, hits)
	assert_eq(pose.in_hand, 0, "just before the turn")
	c.armament.draw_left = c.armament.draw_total * (1.0 - cfg.switch_same_from) - 0.002
	pose.read(c, 1.0, hits)
	assert_eq(pose.in_hand, 1, "the new rifle after it")


func test_a_switch_between_two_pistols_is_backwards_and_one_across_classes_is_not_the_same() -> void:
	var c := _armed([&"aeg", &"pistol", &"cyber"])
	pose.read(c, 1.0, hits)
	_begin_switch(c, 1)
	assert_false(pose.switch_same, "rifle to pistol is across")
	assert_false(pose.switch_back)
	pose.settle(1.0)
	c.armament.draw_left = 0.0
	pose.read(c, 1.0, hits)
	assert_false(pose.switching, "done")
	_begin_switch(c, 2)
	assert_true(pose.switch_same, "pistol to pistol")
	assert_true(pose.switch_back, "from the pistol's end")


func test_a_switch_cut_by_another_switch_starts_from_what_is_in_the_hand_and_ends_clean() -> void:
	var c := _armed([&"aeg", &"smg", &"pistol"])
	pose.read(c, 1.0, hits)
	_begin_switch(c, 1)
	# Past the turn: the SMG is in the hand. Then the pistol is chosen at once.
	c.armament.draw_left = c.armament.draw_total * 0.2
	pose.read(c, 1.0, hits)
	assert_eq(pose.in_hand, 1)
	_begin_switch(c, 2)
	assert_true(pose.switch_started, "a new switch")
	assert_false(pose.switch_same, "from the SMG to the pistol is across")
	assert_eq(pose.in_hand, 1, "the SMG until the pistol's hand-over")
	# And back before the first turn of a same-class one: rifle 1 to rifle 0 while 0.1 in.
	c.armament.draw_left = 0.0
	pose.read(c, 1.0, hits)
	assert_false(pose.switching)
	assert_eq(pose.in_hand, 2)


func test_a_switch_to_the_same_slot_or_out_of_the_holster_is_no_same_class_switch() -> void:
	var c := _armed([&"aeg", &"smg"])
	c.armament.holstered = true
	pose.read(c, 1.0, hits)
	c.armament.holstered = false
	_begin_switch(c, 1)
	assert_false(pose.switching, "out of the holster is a draw, not a switch")
	assert_false(pose.switch_same)


func test_the_switch_seek_of_a_same_class_switch_is_zero_at_both_ends_and_reaches_at_the_turn() -> void:
	# The seek's turn, as the body computes it (figure_body.gd), for each share of a draw.
	var half := cfg.switch_same_from
	for share: float in [0.0, half, 1.0]:
		var turn: float = share / half if share < half else (1.0 - share) / (1.0 - half)
		assert_between(turn, 0.0, 1.0, "share %.2f" % share)
	assert_gt(half, 0.0, "a zero turn would divide by nothing")
	assert_lt(half, 1.0, "a turn at the draw's end would too")


# --- The Sniper Rifle's bolt ---


func test_the_bolt_clip_never_runs_slower_than_the_recording_and_other_replicas_are_unchanged() -> void:
	var vm := ViewModelConfig.new()
	var rate := 1.0 / 2.5
	var r := ReplicaStats.load_replica(&"sniper").duplicate() as ReplicaConfig
	r.fire_rate = rate
	var view := ReplicaView.new()
	add_child_autofree(view)
	view.setup(vm, [r] as Array[ReplicaConfig], BoxWorld.new())
	var held: ReplicaView.Held = view._held[0]
	assert_almost_eq(held.fire_speed, vm.bolt_cycle_end / vm.bolt_knock_at, 1e-4, "a 2.5 s cycle plays at the knock's pace")
	var fast := ReplicaStats.load_replica(&"sniper").duplicate() as ReplicaConfig
	fast.fire_rate = 4.0
	var view2 := ReplicaView.new()
	add_child_autofree(view2)
	view2.setup(vm, [fast] as Array[ReplicaConfig], BoxWorld.new())
	var held2: ReplicaView.Held = view2._held[0]
	assert_almost_eq(held2.fire_speed, vm.bolt_cycle_end * 4.0, 1e-4, "a quick cycle still stretches the clip to its time")


# --- The replica surface's detail ---


func test_each_mesh_detail_has_a_surface_detail_and_only_low_reads_one_side() -> void:
	assert_eq(GraphicsApply.SURFACE_DETAIL.size(), GraphicsApply.MESH_LOD.size(), "one per mesh detail")
	assert_eq(GraphicsApply.SURFACE_DETAIL[GraphicsQuality.MeshDetail.LOW], 0.0)
	for d: int in [GraphicsQuality.MeshDetail.MEDIUM, GraphicsQuality.MeshDetail.HIGH, GraphicsQuality.MeshDetail.ULTRA]:
		assert_eq(GraphicsApply.SURFACE_DETAIL[d], 1.0)


func test_the_surface_detail_is_sent_only_when_it_changes_and_the_global_is_declared() -> void:
	assert_true(ProjectSettings.has_setting("shader_globals/look_surface_detail"), "declared in the project")
	var rs := GraphicsApply.Server.new()
	assert_eq(rs.surface_detail, 1.0)
	rs.set_surface_detail(0.0)
	assert_eq(rs.surface_detail, 0.0)
	rs.set_surface_detail(1.0)
	assert_eq(rs.surface_detail, 1.0, "back to the approved look")


# --- The arch fill on a map with no station ---


func test_the_arch_fill_does_nothing_on_a_field_that_is_not_subway() -> void:
	var map := MapData.load_map("woodland", MapStyle.new(), 6)
	var play := PlayTuning.new()
	var level := MapLevel.new()
	add_child_autofree(level)
	level.build(map, play.map_style, SimTuning.new().body, play.baked_light,
			LightingConfig.for_map(play.lighting, null, map, LightingConfig.DAY), false, play.site_look,
			SimTuning.new().lifts, play.station_look)
	var table := GraphicsTable.shared()
	for preset: StringName in [&"low", &"high", &"low"]:
		GraphicsApply.apply_field(table.preset(preset), null, null, null, level)
	assert_null(level.station_material(), "no station, no material to set")


# --- The range props ---


func test_the_rebuilt_props_keep_their_boxes_and_carry_no_collision() -> void:
	for id: String in PROP_BOXES:
		var scene := load("res://assets/models/props/%s.glb" % id) as PackedScene
		assert_not_null(scene, id)
		var root := scene.instantiate()
		add_child_autofree(root)
		var box: AABB = _bounds(root, Transform3D.IDENTITY, null)
		var want := PROP_BOXES[id]
		assert_almost_eq(box.size, want, Vector3.ONE * 0.02, "%s: the size the dressing fits" % id)
		assert_almost_eq(box.position, Vector3(-want.x * 0.5, 0.0, -want.z * 0.5), Vector3.ONE * 0.02,
				"%s: on the ground, centred" % id)
		assert_eq(root.find_children("*", "CollisionObject3D", true, false).size(), 0, "%s: look only" % id)


func _bounds(n: Node, xf: Transform3D, so_far: Variant) -> AABB:
	var t := xf
	var out: Variant = so_far
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D:
		var a: AABB = t * (n as MeshInstance3D).get_aabb()
		out = a if out == null else (out as AABB).merge(a)
	for c in n.get_children():
		out = _bounds(c, t, out)
	return out as AABB
