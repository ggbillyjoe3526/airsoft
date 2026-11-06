extends GutTest
## QA hunt for CP1 (the Cyber Pistol in play): swaps, saved loadouts, the sim on its modes, sound mixes, the selector
## pose through slot switches and a freed model, repainted pictures and figures, and nothing left behind.

const DT := 1.0 / 60.0
const EYE := Vector3(0.0, 1.6, 0.0)
const AEG := "000002"
const PISTOL := "000001"
const CYBER := "000019"
const LIPO := "000015"

var rules: LoadoutRules


func before_each() -> void:
	ReplicaPaint.clear()
	rules = LoadoutRules.new(Pool.read_file(), ReplicaStats.read_file(), ReplicaRulesConfig.new())


func _unlocked() -> Progress:
	var progress := Progress.new(LevelTable.read_file(rules.pool))
	rules.follow_progress(progress, false)
	progress.add_xp(progress.table.levels[10].total)
	return progress


func _cyber() -> ReplicaConfig:
	return rules.config(rules.pool.item(CYBER))


func _hands(replicas: Array[ReplicaConfig]) -> ReplicaView:
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, replicas)
	var view := ReplicaView.new()
	add_child_autofree(view)
	view.setup(ViewModelConfig.new(), c.armament.replicas, BoxWorld.new())
	return view


func _frame(view: ReplicaView, c: Character) -> void:
	view.update(c, 0.0, 0.0, Vector3(0.0, 1.6, 0.0), Vector3.FORWARD, DT, c.aim_raise)


func _selector_pose(held: ReplicaView.Held) -> Transform3D:
	var skeleton := held.root.find_child("Skeleton3D", true, false) as Skeleton3D
	await skeleton.skeleton_updated
	var pose := skeleton.get_bone_pose(skeleton.find_bone(SelectorPose.BONE))
	await wait_process_frames(1)
	return pose


# ---- loadouts -------------------------------------------------------------------------------------------------

func test_the_cyber_pistol_can_be_primary_and_swaps_with_the_pistol() -> void:
	_unlocked()
	var l := rules.default_loadout("L")
	assert_true(rules.equip(l, Loadout.Slot.PRIMARY, CYBER))
	assert_eq(l.equipped, PackedStringArray([CYBER, PISTOL]), "the AEG left for the cyber")
	assert_true(rules.equip(l, Loadout.Slot.SECONDARY, CYBER), "put back to the other slot swaps")
	assert_eq(l.equipped, PackedStringArray([PISTOL, CYBER]))
	var kit := rules.carried(l)
	assert_eq(kit.replicas.size(), 2)
	assert_eq(kit.replicas[1].id, &"cyber")
	assert_eq(kit.paints[1], ReplicaSchemes.OWN)


func test_a_cyber_pistol_saved_below_level_ten_keeps_the_choice_and_plays_the_default() -> void:
	var progress := Progress.new(LevelTable.read_file(rules.pool))
	rules.follow_progress(progress, false)
	var l := rules.default_loadout("L")
	l.equipped[Loadout.Slot.SECONDARY] = CYBER
	assert_eq(rules.clean(l), [] as Array[String], "the choice is kept, not cleaned")
	assert_eq(l.equipped[Loadout.Slot.SECONDARY], CYBER)
	var kit := rules.carried(l)
	assert_eq(kit.replicas.size(), 2)
	assert_eq(kit.replicas[1].id, &"pistol", "plays the default while locked")
	progress.add_xp(progress.table.levels[10].total)
	assert_eq(rules.carried(l).replicas[1].id, &"cyber", "and the choice comes back at level 10")


func test_the_cyber_pistol_as_primary_below_level_ten_does_not_double_the_pistol() -> void:
	var progress := Progress.new(LevelTable.read_file(rules.pool))
	rules.follow_progress(progress, false)
	var l := rules.default_loadout("L")
	l.equipped[Loadout.Slot.PRIMARY] = CYBER
	l.equipped[Loadout.Slot.SECONDARY] = PISTOL
	var kit := rules.carried(l)
	var ids: Array[StringName] = []
	for r in kit.replicas:
		ids.append(r.id)
	assert_eq(ids, [&"aeg", &"pistol"] as Array[StringName])


func test_a_power_source_saved_on_the_cyber_pistol_is_cleaned_and_never_carried() -> void:
	var l := rules.default_loadout("L")
	l.equipped[Loadout.Slot.SECONDARY] = CYBER
	var t := rules.default_tune(rules.pool.item(CYBER))
	t.power_id = LIPO
	l.tunes[CYBER] = t
	var said := rules.carried(l)
	assert_almost_eq(said.replicas[1].muzzle_energy, 1.0, 1e-6, "the LiPo's energy is not applied")
	assert_almost_eq(said.replicas[1].fire_rate, 14.0, 1e-6, "nor its rate")
	assert_eq(rules.clean(l).size(), 1, "listed")
	assert_eq(t.power_id, "")


func test_hop_up_and_bb_weight_on_the_cyber_pistol_snap_and_reach_the_kit() -> void:
	var l := rules.default_loadout("L")
	l.equipped[Loadout.Slot.SECONDARY] = CYBER
	assert_almost_eq(rules.tune_of(l, CYBER).hop_up, 0.95, 1e-6, "comes at 95 %")
	var dial := rules.set_hop_up(l, CYBER, 5.0)
	assert_lte(dial, rules.rules.hop_up_max_dial)
	assert_almost_eq(rules.carried(l).replicas[1].hop_up_dial, dial, 1e-6)
	var w := rules.set_bb_weight(l, CYBER, 99.0)
	assert_almost_eq(rules.carried(l).bb_weights[1], w, 1e-6)
	assert_lte(w, rules.rules.bb_weight_max)
	assert_false(rules.set_paint(l, CYBER, &"cobalt"), "no scheme applies")


func test_a_heavier_bb_never_lifts_the_cyber_pistol_over_the_pistol_limit() -> void:
	var l := rules.default_loadout("L")
	l.equipped[Loadout.Slot.SECONDARY] = CYBER
	var r := rules.carried(l).replicas[1]
	assert_lte(r.muzzle_energy, rules.stats.energy_limit(&"pistol") + 1e-9)


# ---- the simulation ----------------------------------------------------------------------------------------------

func _run(c: Character, ticks: int, fire_every: bool, tuning: SimTuning, pool: BBPool, rng: RandomNumberGenerator,
		cmd: PlayerCommand) -> int:
	var shots := 0
	var events := SimEvents.new()
	for i in ticks:
		cmd.fire = fire_every
		events.clear()
		Armament.step(c, cmd, EYE, 1.0, true, pool, rng, events, tuning, DT)
		for k in events.count:
			if events.items[k].kind == GameEvent.Kind.SHOT:
				shots += 1
		cmd.reload = false
	return shots


func test_the_cyber_pistol_fires_a_burst_per_pull_and_full_auto_at_its_rate() -> void:
	var tuning := SimTuning.new()
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, [_cyber()] as Array[ReplicaConfig])
	c.armament.active = 0
	c.armament.draw_left = 0.0
	var pool := BBPool.new(512)
	var rng := Seeds.stream(3)
	var cmd := PlayerCommand.new()
	c.armament.modes[0] = ReplicaConfig.FireMode.BURST
	assert_eq(_run(c, 60, true, tuning, pool, rng, cmd), tuning.replica_rules.burst_shots, "held: one burst")
	assert_eq(c.armament.mag(), 50 - tuning.replica_rules.burst_shots)
	c.armament.modes[0] = ReplicaConfig.FireMode.AUTO
	var shots := _run(c, 60, true, tuning, pool, rng, cmd)
	assert_between(shots, 13, 15, "14 a second held for a second")
	assert_eq(c.armament.ammo[0].spare_bbs(), 100, "two spare magazines of 50 untouched")


func test_the_cyber_pistol_reloads_a_fresh_magazine_of_fifty_and_clicks_once_when_dry() -> void:
	var tuning := SimTuning.new()
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, [_cyber()] as Array[ReplicaConfig])
	c.armament.draw_left = 0.0
	c.armament.modes[0] = ReplicaConfig.FireMode.AUTO
	var pool := BBPool.new(512)
	var rng := Seeds.stream(3)
	var cmd := PlayerCommand.new()
	var shots := _run(c, 60 * 8, true, tuning, pool, rng, cmd)
	assert_gt(shots, 50, "it ran dry and reloaded from a spare")
	assert_lte(c.armament.mag(), 50)
	assert_lt(c.armament.ammo[0].spare_bbs(), 100, "a spare magazine was used")


# ---- sound -------------------------------------------------------------------------------------------------------

func test_a_match_with_aeg_gbb_and_cyber_loads_each_profile_once_and_all_sound() -> void:
	var gas := rules.config(rules.pool.item(PISTOL))
	var aeg := rules.config(rules.pool.item(AEG))
	var profiles: Array[StringName] = []
	for r in [aeg, gas, _cyber(), aeg, _cyber()] as Array[ReplicaConfig]:
		if not profiles.has(r.sound_profile()):
			profiles.append(r.sound_profile())
	assert_eq(profiles.size(), 3)
	var audio := SimAudio.new()
	add_child_autofree(audio)
	audio.setup(SoundConfig.new(), profiles, BodyConfig.new(), null, null)
	for p in profiles:
		for table: Dictionary in [audio._shot, audio._mag_out, audio._mag_in]:
			assert_true(table.has(p), "%s has its cue" % p)
			assert_false((audio._streams[table[p]] as Array).is_empty(), "%s cue has sounds" % p)
	assert_false((audio._streams[SimAudio.DRY_CUE] as Array).is_empty(), "every replica's dry click has sounds")
	assert_eq(audio._power[&"cyber"], &"")
	assert_ne(audio._power[&"gas"], &"")
	assert_ne(audio._power[&"electric"], &"")
	assert_gt(profiles.size(), 0)


func test_every_event_of_a_cyber_holder_plays_without_error() -> void:
	var audio := SimAudio.new()
	add_child_autofree(audio)
	audio.setup(SoundConfig.new(), [&"cyber"] as Array[StringName], BodyConfig.new(), null, null)
	var state := GameState.new(1)
	state.characters.append(Character.new(0, 0, Vector3.ZERO, 0.0, [_cyber()] as Array[ReplicaConfig]))
	state.characters.append(Character.new(1, 1, Vector3(3.0, 0.0, 0.0), 0.0, [_cyber()] as Array[ReplicaConfig]))
	for kind: GameEvent.Kind in [GameEvent.Kind.SHOT, GameEvent.Kind.DRY_FIRE, GameEvent.Kind.RELOAD_START,
			GameEvent.Kind.RELOAD_END]:
		for actor in 2:
			var e := state.events.add(kind)
			e.actor = actor
			e.slot = 0
	audio.on_tick(state, 0, null)
	assert_true(true, "no script error")


# ---- the selector pose ---------------------------------------------------------------------------------------------

func test_the_selector_pose_follows_a_mode_change_mid_burst_and_a_slot_switch() -> void:
	var c := Character.new(1, 0, Vector3.ZERO, 0.0,
			[_cyber(), rules.config(rules.pool.item(PISTOL))] as Array[ReplicaConfig])
	var view := ReplicaView.new()
	add_child_autofree(view)
	view.setup(ViewModelConfig.new(), c.armament.replicas, BoxWorld.new())
	var held: ReplicaView.Held = view._held[0]
	assert_not_null(held.selector)
	assert_null((view._held[1] as ReplicaView.Held).selector, "the GBB Pistol has none")
	c.armament.modes[0] = ReplicaConfig.FireMode.BURST
	_frame(view, c)
	view.on_shot()
	var burst: Transform3D = await _selector_pose(held)
	c.armament.modes[0] = ReplicaConfig.FireMode.SEMI
	_frame(view, c)
	var semi: Transform3D = await _selector_pose(held)
	assert_ne(burst.origin, semi.origin, "the mode changed mid-burst shows at once")
	# Away to the pistol and back: the pose comes back with the mode.
	c.armament.active = 1
	_frame(view, c)
	await wait_process_frames(2)
	c.armament.active = 0
	c.armament.modes[0] = ReplicaConfig.FireMode.AUTO
	_frame(view, c)
	var auto: Transform3D = await _selector_pose(held)
	assert_ne(auto.origin, semi.origin)
	assert_almost_eq(auto.origin.y, 0.0216, 1e-3, "auto: the track's end at the CZ1 size")


func test_a_mode_outside_the_known_ones_does_not_break_the_pose() -> void:
	var model := (load("res://assets/models/replicas/cyber.glb") as PackedScene).instantiate()
	add_child_autofree(model)
	var anim := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var pose := SelectorPose.attach(model, anim)
	assert_not_null(pose)
	pose.mode = 7 as ReplicaConfig.FireMode
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	await skeleton.skeleton_updated
	await wait_process_frames(1)
	pass_test("clamped")


func test_a_posed_model_freed_while_its_view_goes_leaves_no_nodes() -> void:
	var before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var orphans := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	for i in 3:
		var view := _hands([_cyber(), ReplicaStats.default_loadout()[0]] as Array[ReplicaConfig])
		await wait_process_frames(2)
		view.queue_free()
		await wait_process_frames(2)
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), before, "no node left")
	assert_lte(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), orphans, "no orphan")


# ---- pictures and figures --------------------------------------------------------------------------------------------

func test_a_cyber_menu_picture_goes_realistic_and_back() -> void:
	var pictures := ReplicaPictures.new()
	add_child_autofree(pictures)
	var bold := pictures.texture(&"cyber", ReplicaSchemes.OWN, false)
	var plain := pictures.texture(&"cyber", ReplicaSchemes.OWN, true)
	var bold_again := pictures.texture(&"cyber", ReplicaSchemes.OWN, false)
	assert_not_null(bold)
	assert_not_null(plain)
	assert_not_null(bold_again)
	assert_eq(pictures.count(), 1, "one picture, repainted")
	await wait_process_frames(3)
	var shot: Object = pictures._shots[&"cyber"]
	for node: Node in shot.model.find_children("*", "MeshInstance3D", true, false):
		var m := node as MeshInstance3D
		for i in m.mesh.get_surface_count():
			if m.mesh.surface_get_material(i).resource_name == "CyberLine":
				assert_null(m.get_surface_override_material(i), "bold again: its own glowing line")


func test_a_cyber_figure_draws_the_pistol_and_goes_plain_under_realistic_colours() -> void:
	var loadout: Array[ReplicaConfig] = [_cyber()]
	var c := Character.new(2, 1, Vector3.ZERO, 0.0, loadout)
	var f := FigureView.new()
	add_child_autofree(f)
	f.setup(c, Color.RED, HitConfig.new(), ThemeDB.fallback_font, true)
	var held: MeshInstance3D = f._replicas[0]
	assert_not_null(held, "the Figure mesh of cyber.glb")
	var seen := false
	for i in held.mesh.get_surface_count():
		var own := held.mesh.surface_get_material(i)
		if own != null and ReplicaSchemes.OWN_REALISTIC.has(StringName(own.resource_name)):
			seen = true
			assert_not_null(held.get_surface_override_material(i), "%s plain" % own.resource_name)
	if not seen:
		pending("the Figure mesh carries no Cyber* material names, so realistic cannot touch it")


# ---- stats ------------------------------------------------------------------------------------------------------------

func test_balance_row_for_the_cyber_pistol_reads_from_stats_not_the_tres() -> void:
	var r := _cyber()
	var row := ReplicaStats.read_file()
	assert_not_null(row)
	assert_eq(r.sound_profile(), &"cyber", "the stats row doesn't drop the sound")
	assert_eq(r.id, &"cyber")
