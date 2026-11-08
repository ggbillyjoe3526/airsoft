extends GutTest
## Reduced motion (AC5): MotionScale gives data/accessibility.md's shares; On, or Follow system while the display asks
## for it, draws no sway, half the kick and the reload's cant, a quarter of the lean's roll and the vault's dip and tip,
## no wind dust and a steady flag warning, never less of the recoil climb, and all of your hit's jolt and drop (FI5); a
## change reaches a match at once.

const DT := 1.0 / 60.0
## Frames enough for the view's easing to settle.
const SETTLE := 120

var table: AccessibilityTable = null


func before_each() -> void:
	table = AccessibilityTable.read_file()


func after_each() -> void:
	get_tree().paused = false


# --- the shares ---

func test_full_motion_draws_all_of_everything() -> void:
	var m := MotionScale.of(false)
	for share: float in [m.sway, m.kick, m.reload_cant, m.lean_roll, m.vault_tip, m.dust, m.hud_pulse, m.hit_jolt]:
		assert_eq(share, 1.0)


func test_reduced_motion_draws_the_table_s_shares() -> void:
	var m := MotionScale.of(true)
	assert_eq([m.sway, m.kick, m.reload_cant, m.lean_roll, m.vault_tip, m.dust, m.hud_pulse, m.hit_jolt],
			[0.0, 0.5, 0.5, 0.25, 0.25, 0.0, 0.0, 0.5], "sway 0, kick and cant half, lean and vault a quarter, no dust")
	for id in AccessibilityTable.MOTION_IDS:
		assert_eq(m.get(String(id)), table.share(id), "%s is the file's" % id)


func test_the_shares_come_from_the_table_given() -> void:
	var t := AccessibilityTable.parse("## Reduced motion\n\n| ID | Motion | Share |\n|---|---|---|\n| sway | s | 0.3 |\n")
	assert_almost_eq(MotionScale.of(true, t).sway, 0.3, 1e-6)
	assert_eq(MotionScale.of(true, t).kick, 0.5, "a row left out keeps its built-in share")


func test_on_or_the_system_asking_reduces_motion() -> void:
	var s := Settings.new(PlayTuning.new())
	s.reduced_motion = Settings.ReducedMotion.ON
	assert_true(s.reduces_motion(0), "On, whatever the system says")
	s.reduced_motion = Settings.ReducedMotion.OFF
	assert_false(s.reduces_motion(1), "Off, whatever the system says")
	s.reduced_motion = Settings.ReducedMotion.SYSTEM
	assert_true(s.reduces_motion(1), "the system asking")
	assert_false(s.reduces_motion(0))
	assert_false(s.reduces_motion(-1), "the system can't say")


# --- the view ---

func _eyes() -> FirstPersonView:
	var view := FirstPersonView.new()
	add_child_autofree(view)
	view.setup(ViewConfig.new(), BodyConfig.new(), HitConfig.new())
	return view


func _player_input() -> PlayerInput:
	var input := PlayerInput.new()
	autofree(input)
	return input


## A character standing at a full lean right with `recoil` on its replica, `vaulting` half way over a vault.
func _leaning(recoil: float, vaulting: bool) -> Character:
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	c.prev_position = c.position
	c.lean = 1.0
	c.prev_lean = 1.0
	c.armament.recoil = recoil
	if vaulting:
		c.vault.active = true
		c.vault.end = 1.0
		c.vault.time = 0.5
	return c


## The eyes' rotation and height once settled on `c` with `motion`.
func _settled(c: Character, motion: MotionScale) -> Transform3D:
	var view := _eyes()
	view.set_motion(motion)
	var input := _player_input()
	for i in SETTLE:
		view.update(c, input, 1.0, DT, c.aim_raise)
	return view.transform


func test_a_full_lean_rolls_the_view_a_quarter_as_much_with_motion_reduced() -> void:
	var cfg := ViewConfig.new()
	var full := _settled(_leaning(0.0, false), MotionScale.of(false))
	var reduced := _settled(_leaning(0.0, false), MotionScale.of(true))
	assert_almost_eq(full.basis.get_euler().z, -cfg.lean_camera_roll, 1e-4, "the full roll")
	assert_almost_eq(reduced.basis.get_euler().z, -cfg.lean_camera_roll * 0.25, 1e-4, "a quarter of it")


func test_the_recoil_climb_is_the_same_either_way() -> void:
	var full := _settled(_leaning(0.04, false), MotionScale.of(false))
	var reduced := _settled(_leaning(0.04, false), MotionScale.of(true))
	assert_almost_eq(full.basis.get_euler().x, 0.04, 1e-4, "climbed by the recoil")
	assert_almost_eq(reduced.basis.get_euler().x, full.basis.get_euler().x, 1e-6, "the climb shows where the BB goes")


func test_a_vault_dips_and_tips_the_view_a_quarter_as_much() -> void:
	var cfg := ViewConfig.new()
	var still := _settled(_leaning(0.0, false), MotionScale.of(false))
	var full := _settled(_leaning(0.0, true), MotionScale.of(false))
	var reduced := _settled(_leaning(0.0, true), MotionScale.of(true))
	var dip := still.origin.y - full.origin.y
	assert_almost_eq(dip, cfg.vault_dip, 1e-3, "the full dip half way over")
	assert_almost_eq(still.origin.y - reduced.origin.y, dip * 0.25, 1e-3, "a quarter of the dip")
	var tip := still.basis.get_euler().x - full.basis.get_euler().x
	assert_gt(tip, 0.0)
	assert_almost_eq(still.basis.get_euler().x - reduced.basis.get_euler().x, tip * 0.25, 1e-3, "a quarter of the tip")


# --- the replica ---

func _hands(c: Character, motion: MotionScale) -> ReplicaView:
	var hands := ReplicaView.new()
	add_child_autofree(hands)
	hands.setup(ViewModelConfig.new(), c.armament.replicas, BoxWorld.new())
	hands.set_motion(motion)
	return hands


func _pose(hands: ReplicaView, c: Character, yaw: float = 0.0) -> void:
	hands.update(c, yaw, 0.0, Vector3(0.0, 1.6, 0.0), Vector3.FORWARD, DT, c.aim_raise)


## How far a shot moves the replica in hand from where it rests, a frame after it, with `motion`.
func _kicked(motion: MotionScale) -> Vector3:
	var c := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
	var hands := _hands(c, motion)
	for i in SETTLE:
		_pose(hands, c)
	var rest: Vector3 = hands._held[c.armament.active].root.position
	hands.on_shot()
	_pose(hands, c)
	return hands._held[c.armament.active].root.position - rest


func test_a_shot_kicks_the_replica_half_as_far_with_motion_reduced() -> void:
	var full := _kicked(MotionScale.of(false))
	var reduced := _kicked(MotionScale.of(true))
	assert_gt(full.length(), 0.001, "a shot kicks it back")
	assert_almost_eq(reduced, full * 0.5, Vector3.ONE * 1e-5, "half the kick")


func test_turning_sways_the_replica_only_with_full_motion() -> void:
	for reduced: bool in [false, true]:
		var c := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
		var hands := _hands(c, MotionScale.of(reduced))
		for i in SETTLE:
			_pose(hands, c)
		var rest: Vector3 = hands._held[c.armament.active].root.position
		_pose(hands, c, 0.3)
		var moved: float = (hands._held[c.armament.active].root.position - rest).length()
		if reduced:
			assert_almost_eq(moved, 0.0, 1e-6, "no sway")
		else:
			assert_gt(moved, 0.001, "a turn sways it")


func test_a_reload_cants_the_replica_half_as_much() -> void:
	var tilts: Array[Vector3] = []
	for reduced: bool in [false, true]:
		var c := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
		var hands := _hands(c, MotionScale.of(reduced))
		c.armament.reload_left = c.armament.replica().reload_time * 0.5
		_pose(hands, c)
		tilts.append(hands._held[c.armament.active].root.rotation)
	var cfg := ViewModelConfig.new()
	var id := ReplicaStats.default_loadout()[0].id
	assert_almost_eq(tilts[0], cfg.reload_cant(id) * cfg.reload_bell(id, 0.5), Vector3.ONE * 1e-4,
			"the full cant half way through")
	assert_almost_eq(tilts[1], tilts[0] * 0.5, Vector3.ONE * 1e-5, "half of it")


func test_your_hit_jolts_and_drops_the_replica_the_same_with_motion_reduced() -> void:
	var paths: Array[PackedVector3Array] = []
	for reduced: bool in [false, true]:
		var c := Character.new(0, 0, Vector3.ZERO, 0.0, ReplicaStats.default_loadout())
		var hands := _hands(c, MotionScale.of(reduced))
		_pose(hands, c)
		c.status = Character.Status.CALLING
		hands.on_hit()
		var path := PackedVector3Array()
		for i in 15:
			_pose(hands, c)
			path.append(hands._held[c.armament.active].root.position)
		paths.append(path)
	assert_gt(paths[0][0].z - paths[0][14].z, 0.01, "control: it jolts back, then comes in")
	assert_gt(paths[0][0].y - paths[0][14].y, 0.4, "control: it drops")
	for i in 15:
		assert_almost_eq(paths[1][i], paths[0][i], Vector3.ONE * 1e-6, "frame %d: the same, the camera never moves" % i)


# --- the dust ---

func test_reduced_motion_takes_the_wind_dust_away_and_back() -> void:
	var cfg := EffectsConfig.new()
	var dust := WindDust.new()
	add_child_autofree(dust)
	dust.setup(cfg)
	dust.set_share(1.0)
	assert_true(dust.visible)
	dust.set_motion(MotionScale.of(true))
	assert_false(dust.visible, "no dust")
	assert_false(dust.emitting)
	dust.set_share(0.5)
	assert_false(dust.visible, "a graphics change doesn't bring it back")
	dust.set_motion(MotionScale.of(false))
	assert_true(dust.visible, "back with full motion")
	assert_eq(dust.amount, roundi(cfg.dust_count * 0.5), "at the graphics' share")


# --- in a match ---

func test_a_change_reaches_a_match_at_once_and_holds_the_flag_warning_steady() -> void:
	var settings := Settings.new(PlayTuning.new())
	settings.reduced_motion = Settings.ReducedMotion.OFF
	var session := PlaySession.new()
	session.settings = settings
	session.mode = MatchOptions.MODE_ATTACK_DEFEND
	session.bots_active = false
	add_child_autofree(session)
	await wait_physics_frames(2)
	var rs := session.state.round_state
	rs.flag.status = FlagState.Status.RAISING
	rs.attackers = 1 - session.player.team
	var hud := session.hud()
	var lows: Array[float] = []
	for reduced: bool in [false, true]:
		settings.reduced_motion = Settings.ReducedMotion.ON if reduced else Settings.ReducedMotion.OFF
		settings.mark_changed()
		assert_eq(session._eyes._motion.lean_roll, 0.25 if reduced else 1.0, "the view at once")
		assert_eq(session._hands._motion.kick, 0.5 if reduced else 1.0, "the replica at once")
		assert_eq(session._dust.visible, not reduced and session._dust._quality > 0.0, "the dust at once")
		var low := 1.0
		for i in 60:
			hud.update(session.state, 1.0, DT)
			assert_true(hud.flag_warning_shown())
			low = minf(low, hud._warning.modulate.a)
		lows.append(low)
	assert_almost_eq(lows[0], HudStyle.WARNING_PULSE_LOW, 0.02, "the warning pulses with full motion")
	assert_eq(lows[1], 1.0, "and holds steady at full with motion reduced")
