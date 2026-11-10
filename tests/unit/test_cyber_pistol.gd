extends GutTest
## The Cyber Pistol in play (CP1): it plays by stats.md's `cyber` row with its built-in battery, unlocks at level 10,
## is drawn from `cyber.glb` with its sights marked and its selector showing the fire mode, and sounds as its own.

const DT := 1.0 / 60.0
const AEG := "000002"
const PISTOL := "000001"
const CYBER := "000019"
const LIPO := "000015"

var rules: LoadoutRules


func before_each() -> void:
	rules = LoadoutRules.new(Pool.read_file(), ReplicaStats.read_file(), ReplicaRulesConfig.new())


func _cyber() -> ReplicaConfig:
	return rules.config(rules.pool.item(CYBER))


func _hands(c: Character) -> ReplicaView:
	var view := ReplicaView.new()
	add_child_autofree(view)
	view.setup(ViewModelConfig.new(), c.armament.replicas, BoxWorld.new())
	return view


func test_it_plays_by_its_stats_row() -> void:
	var r := _cyber()
	assert_not_null(r, "a built-in config since CP1")
	assert_eq(r.display_name, "Cyber Pistol")
	assert_eq(r.fire_modes, [ReplicaConfig.FireMode.SEMI, ReplicaConfig.FireMode.BURST,
			ReplicaConfig.FireMode.AUTO] as Array[ReplicaConfig.FireMode])
	assert_eq(r.default_fire_mode, ReplicaConfig.FireMode.SEMI, "comes on semi")
	assert_almost_eq(r.fire_rate, 14.0, 1e-6)
	assert_eq(r.mag_size, 50)
	assert_eq(r.mags, 3)
	assert_almost_eq(r.reload_time, 1.1, 1e-6)
	assert_almost_eq(r.draw_time, 0.28, 1e-6)
	assert_almost_eq(r.muzzle_energy, 1.0, 1e-6)
	assert_eq(r.site_class, &"pistol")
	assert_almost_eq(r.spread_deg, 0.3, 1e-6)
	assert_almost_eq(r.recoil_deg, 0.06, 1e-6)
	assert_eq(r.sound_profile(), &"cyber")
	assert_eq(rules.config(rules.pool.item(AEG)).sound_profile(), &"electric", "the rest sound as their power")


func test_its_battery_is_built_in_so_no_power_source_fits_or_changes_it() -> void:
	var l := rules.default_loadout("L")
	assert_true(rules.equip(l, Loadout.Slot.SECONDARY, CYBER))
	assert_false(rules.set_power(l, CYBER, LIPO), "no power source fits it")
	assert_eq(rules.tune_of(l, CYBER).power_id, "")
	var kit := rules.carried(l)
	assert_eq(kit.replicas[1].id, &"cyber")
	assert_almost_eq(kit.replicas[1].fire_rate, 14.0, 1e-6, "plays at its own rate")
	assert_almost_eq(kit.replicas[1].muzzle_energy, 1.0, 1e-6, "at the pistol limit")


func test_it_unlocks_at_the_cap_level_15() -> void:
	var progress := Progress.new(LevelTable.read_file(rules.pool))
	rules.follow_progress(progress, false)
	assert_eq(rules.unlock_level(CYBER), 15, "a replica every five levels, the Cyber Pistol last (LV15)")
	var l := rules.default_loadout("L")
	assert_false(rules.equip(l, Loadout.Slot.SECONDARY, CYBER), "locked at level 0")
	progress.add_xp(progress.table.levels[progress.table.cap()].total)
	assert_eq(progress.level(), 15)
	assert_true(rules.equip(l, Loadout.Slot.SECONDARY, CYBER), "unlocked at the cap")
	assert_eq(rules.carried(l).replicas[1].id, &"cyber")


func test_in_hand_it_is_drawn_from_its_model_with_its_sights_marked() -> void:
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, [rules.config(rules.pool.item(AEG)), _cyber()] as Array[ReplicaConfig])
	var view := _hands(c)
	var held := view._held[1]
	assert_eq(held.id, &"cyber")
	assert_not_null(held.muzzle)
	assert_almost_eq(held.rear_sight, Vector3(0.0, 0.03024, 0.06835), Vector3.ONE * 1e-4,
			"the rear notch, as marked (at the GBB's size since CZ1)")
	assert_null(held.slide, "electric: no slide lock")
	assert_not_null(held.selector)
	c.armament.active = 1
	_frame(view, c)
	assert_true(held.root.visible)
	assert_true(held.selector.active)
	assert_false(view._held[0].selector.active, "the AEG put away doesn't update its skeleton")


## The selector bone's pose in `held`'s model as drawn: read as the skeleton updates, after the animation and its
## modifiers (the skeleton puts its animated poses back once drawn), then out of the skeleton's update before the test
## goes on, so nothing is freed in the middle of it.
func _drawn_selector(held: ReplicaView.Held) -> Transform3D:
	var skeleton := held.root.find_child("Skeleton3D", true, false) as Skeleton3D
	await skeleton.skeleton_updated
	var pose := skeleton.get_bone_pose(skeleton.find_bone(SelectorPose.BONE))
	await wait_process_frames(1)
	return pose


func _frame(view: ReplicaView, c: Character) -> void:
	view.update(c, 0.0, 0.0, Vector3(0.0, 1.6, 0.0), Vector3.FORWARD, DT, c.aim_raise)


func test_its_selector_shows_the_fire_mode_even_while_the_fire_clip_plays() -> void:
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, [_cyber()] as Array[ReplicaConfig])
	var view := _hands(c)
	var held := view._held[0]
	_frame(view, c)
	var semi: Transform3D = await _drawn_selector(held)
	c.armament.modes[0] = ReplicaConfig.FireMode.AUTO
	_frame(view, c)
	view.on_shot()
	var auto: Transform3D = await _drawn_selector(held)
	assert_almost_eq(semi.origin.y, 0.0145, 1e-3, "semi: half way along the clip (CZ1 size)")
	assert_almost_eq(auto.origin.y, 0.0216, 1e-3, "auto: the clip's end, held through the Fire clip")


func test_the_aegs_selector_turns_with_its_fire_mode_too() -> void:
	var c := Character.new(1, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	var view := _hands(c)
	var held := view._held[0]
	assert_not_null(held.selector)
	c.armament.modes[0] = ReplicaConfig.FireMode.SEMI
	_frame(view, c)
	var semi: Transform3D = await _drawn_selector(held)
	c.armament.modes[0] = ReplicaConfig.FireMode.AUTO
	_frame(view, c)
	var auto: Transform3D = await _drawn_selector(held)
	assert_gt(semi.basis.get_rotation_quaternion().angle_to(auto.basis.get_rotation_quaternion()), 0.5,
			"the lever turned")


func test_a_model_without_a_selector_clip_gets_no_selector_pose() -> void:
	var model := (load("res://assets/models/replicas/pistol.glb") as PackedScene).instantiate()
	add_child_autofree(model)
	var anim := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert_null(SelectorPose.attach(model, anim), "the GBB Pistol has no selector")
	assert_null(SelectorPose.attach(model, null))


func test_it_sounds_as_its_own_with_no_power_part() -> void:
	var audio := SimAudio.new()
	add_child_autofree(audio)
	audio.setup(SoundConfig.new(), [&"cyber", &"electric"] as Array[StringName], BodyConfig.new(), null, null)
	assert_eq(audio._power[&"cyber"], &"", "no power part apart")
	assert_ne(audio._power[&"electric"], &"")
	for cue: StringName in [audio._shot[&"cyber"], SimAudio.DRY_CUE, audio._mag_out[&"cyber"],
			audio._mag_in[&"cyber"]]:
		assert_false((audio._streams[cue] as Array).is_empty(), "%s has its sounds" % cue)
	var state := GameState.new(1)
	state.characters.append(Character.new(0, 0, Vector3.ZERO, 0.0, [_cyber()] as Array[ReplicaConfig]))
	var e := state.events.add(GameEvent.Kind.SHOT)
	e.actor = 0
	e.slot = 0
	audio.on_tick(state, 0, null)
	assert_not_null(audio._own[0].stream, "the shot played")
	assert_null(audio._own[1].stream, "no second voice for a power part")
