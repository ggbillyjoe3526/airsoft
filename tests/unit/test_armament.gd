extends GutTest
## Replica handling (game/sim/armament.gd), ported from the browser game's sim/armament.test.ts: fire modes and rates,
## magazines swapped on reload, dry fire, draws, seeded spread, recoil and the BBs each replica fires.

const DT := 1.0 / 60.0
const EYE := Vector3(0.0, 1.6, 0.0)

var tuning: SimTuning
var rules: ReplicaRulesConfig
var aeg: ReplicaConfig
var pistol: ReplicaConfig
var c: Character
var a: Armament
var cmd: PlayerCommand
var pool: BBPool
var rng: RandomNumberGenerator
var events: SimEvents
## Events of each kind over the last run, and the ticks (of that run) a shot went on.
var counts: Dictionary[int, int] = {}
var shot_ticks: Array[int] = []


func before_each() -> void:
	tuning = SimTuning.new()
	rules = tuning.replica_rules
	var loadout := ReplicaStats.default_loadout()
	aeg = loadout[0]
	pistol = loadout[1]
	c = Character.new(1, 0, Vector3.ZERO, 0.0, loadout)
	a = c.armament
	cmd = PlayerCommand.new()
	pool = BBPool.new(512)
	rng = Seeds.stream(7)
	events = SimEvents.new()


## Runs `ticks` ticks, `setup` (cmd, tick) filling the command each tick; one-shot inputs are cleared after each.
## Returns the shots fired.
func run(ticks: int, setup: Callable = Callable(), can_fire: bool = true) -> int:
	counts.clear()
	shot_ticks.clear()
	for i in ticks:
		if setup.is_valid():
			setup.call(cmd, i)
		events.clear()
		Armament.step(c, cmd, EYE, 1.0, can_fire, pool, rng, events, tuning, DT)
		for k in events.count:
			var kind: int = events.items[k].kind
			counts[kind] = counts.get(kind, 0) + 1
			if kind == GameEvent.Kind.SHOT:
				shot_ticks.append(i)
		cmd.reload = false
		cmd.switch_to = -1
		cmd.cycle_fire_mode = false
	return n(GameEvent.Kind.SHOT)


func n(kind: GameEvent.Kind) -> int:
	return counts.get(kind, 0)


func hold(p: PlayerCommand, _i: int) -> void:
	p.fire = true


func release(p: PlayerCommand, _i: int) -> void:
	p.fire = false


func draw_ticks(r: ReplicaConfig) -> int:
	return ceili(r.draw_time / DT) + 1


func switch_to(slot: int) -> void:
	run(1, func(p: PlayerCommand, _i: int) -> void: p.switch_to = slot)


func newest_bb() -> BB:
	var best: BB = null
	for b in pool.bbs:
		if b.active and (best == null or b.serial > best.serial):
			best = b
	return best


func test_fires_the_aeg_at_its_exact_fire_rate_while_held() -> void:
	assert_eq(a.fire_mode(), ReplicaConfig.FireMode.AUTO)
	var shots := run(60, hold)
	assert_eq(shots, int(aeg.fire_rate), "one second held: fire_rate BBs")
	assert_eq(a.mag(), aeg.mag_size - shots)
	# Ten seconds of fire, magazine changes left out: still the exact rate (the cooldown keeps its overshoot).
	a.ammo[0].mag = 1000
	assert_eq(run(600, hold), int(aeg.fire_rate * 10.0), "no drift over ten seconds")


func test_fires_the_pistol_once_per_press_never_faster_than_its_rate() -> void:
	switch_to(1)
	run(draw_ticks(pistol))
	assert_eq(a.active, 1)
	assert_eq(run(60, hold), 1, "a held trigger: one shot")
	run(1, release)
	var shots := run(60, func(p: PlayerCommand, i: int) -> void: p.fire = i % 2 == 0)
	assert_true(shots <= int(pistol.fire_rate) + 1, "capped by the fire rate: %d" % shots)
	assert_true(shots >= int(pistol.fire_rate) - 1, "clicks aren't dropped: %d" % shots)


func test_clicks_dry_when_empty_then_reloads_with_a_full_spare() -> void:
	assert_eq(Array(a.ammo[0].pouch), [aeg.mag_size, aeg.mag_size, aeg.mag_size])
	a.ammo[0].mag = 0
	run(1, hold)
	assert_eq(n(GameEvent.Kind.SHOT), 0)
	assert_eq(n(GameEvent.Kind.DRY_FIRE), 1)
	assert_eq(n(GameEvent.Kind.RELOAD_START), 1)
	run(ceili(aeg.reload_time / DT) + 1, release)
	assert_eq(n(GameEvent.Kind.RELOAD_END), 1)
	assert_eq(a.mag(), aeg.mag_size)
	var pouch := Array(a.ammo[0].pouch)
	pouch.sort()
	assert_eq(pouch, [0, aeg.mag_size, aeg.mag_size], "the empty went back in the pouch")


func test_swaps_in_the_fullest_spare_and_keeps_the_old_magazine_as_it_is() -> void:
	run(1, func(p: PlayerCommand, _i: int) -> void: p.reload = true)
	assert_eq(n(GameEvent.Kind.RELOAD_START), 0, "a full magazine: nothing fuller")
	a.ammo[0].mag = 10
	a.ammo[0].pouch = PackedInt32Array([25, 40, 5])
	run(1, func(p: PlayerCommand, _i: int) -> void: p.reload = true)
	assert_eq(n(GameEvent.Kind.RELOAD_START), 1)
	assert_true(a.reloading())
	run(ceili(aeg.reload_time / DT) + 1)
	assert_eq(a.mag(), 40, "the fullest spare")
	assert_eq(Array(a.ammo[0].pouch), [25, 10, 5], "the 10 went back where the 40 was")
	assert_eq(a.spare_bbs(), 40)
	a.ammo[0].mag = 30
	run(1, func(p: PlayerCommand, _i: int) -> void: p.reload = true)
	assert_eq(n(GameEvent.Kind.RELOAD_START), 0, "no spare fuller than 30")


func test_says_so_when_a_reload_is_refused() -> void:
	a.ammo[0].mag = 30
	a.ammo[0].pouch = PackedInt32Array([25, 25, 25])
	run(1, func(p: PlayerCommand, _i: int) -> void: p.reload = true)
	assert_eq(n(GameEvent.Kind.RELOAD_START), 0)
	assert_eq(n(GameEvent.Kind.RELOAD_REFUSED), 1)
	run(5)
	assert_eq(n(GameEvent.Kind.RELOAD_REFUSED), 0, "only on the press")


func test_knows_which_spare_a_reload_would_take() -> void:
	var m := Armament.Ammo.new()
	var cases := [[10, [25, 40, 5], 1], [30, [25, 25, 25], -1], [0, [0, 0, 0], -1], [0, [0, 3, 0], 1], [5, [], -1]]
	for case: Array in cases:
		m.mag = case[0]
		m.pouch = PackedInt32Array(case[1])
		assert_eq(m.next_spare(), case[2], str(case))
	# A full magazine: R does nothing, quietly; one short with nothing fuller says so.
	run(1, func(p: PlayerCommand, _i: int) -> void: p.reload = true)
	assert_eq(n(GameEvent.Kind.RELOAD_REFUSED), 0)
	a.ammo[0].mag = aeg.mag_size - 1
	a.ammo[0].pouch = PackedInt32Array([aeg.mag_size - 1, 0, 0])
	run(1, func(p: PlayerCommand, _i: int) -> void: p.reload = true)
	assert_eq(n(GameEvent.Kind.RELOAD_REFUSED), 1)


func test_leaves_the_magazines_as_they_were_when_a_switch_cancels_a_reload() -> void:
	a.ammo[0].mag = 12
	a.ammo[0].pouch = PackedInt32Array([60, 30, 0])
	run(1, func(p: PlayerCommand, _i: int) -> void: p.reload = true)
	run(floori(aeg.reload_time / DT / 2.0))
	switch_to(1)
	run(ceili(aeg.reload_time / DT))
	assert_eq(a.ammo[0].mag, 12)
	assert_eq(Array(a.ammo[0].pouch), [60, 30, 0])


func test_runs_dry_for_good_once_every_magazine_is_empty() -> void:
	a.ammo[0].mag = 0
	a.ammo[0].pouch = PackedInt32Array([0, 0, 0])
	run(1, hold)
	assert_eq(n(GameEvent.Kind.DRY_FIRE), 1)
	assert_eq(n(GameEvent.Kind.RELOAD_START), 0, "nothing left to load")
	run(1, func(p: PlayerCommand, _i: int) -> void: p.reload = true)
	assert_eq(n(GameEvent.Kind.RELOAD_START), 0)


func test_empties_every_magazine_it_carries_and_no_more() -> void:
	assert_eq(run(60 * 40, hold), aeg.mag_size * aeg.mags)
	assert_eq(a.mag(), 0)
	assert_eq(a.spare_bbs(), 0)


func test_cannot_fire_while_reloading_or_drawing_and_a_switch_cancels_a_reload() -> void:
	a.ammo[0].mag = 5
	run(1, func(p: PlayerCommand, _i: int) -> void: p.reload = true)
	assert_eq(run(10, hold), 0, "reloading")
	run(1, func(p: PlayerCommand, _i: int) -> void:
		p.fire = false
		p.switch_to = 1)
	assert_eq(n(GameEvent.Kind.DRAW), 1)
	assert_false(a.reloading())
	assert_true(a.drawing())
	assert_eq(a.ammo[0].mag, 5, "the cancelled reload loaded nothing")
	assert_eq(run(floori(pistol.draw_time / DT) - 1, func(p: PlayerCommand, i: int) -> void: p.fire = i % 2 == 0), 0,
			"drawing")
	run(30, release)
	assert_eq(run(1, hold), 1)


func test_keeps_a_reload_pressed_during_a_draw_and_starts_it_once_up() -> void:
	a.ammo[1].mag = 5
	switch_to(1)
	run(draw_ticks(pistol), func(p: PlayerCommand, i: int) -> void: p.reload = i == 3)
	assert_eq(n(GameEvent.Kind.RELOAD_START), 1)
	assert_true(a.reloading())
	run(ceili(pistol.reload_time / DT) + 1)
	assert_eq(a.ammo[1].mag, pistol.mag_size)


func test_drops_a_reload_asked_for_during_a_draw_when_switching_again() -> void:
	a.ammo[0].mag = 5
	switch_to(1)
	run(3, func(p: PlayerCommand, i: int) -> void: p.reload = i == 1)
	switch_to(0)
	run(draw_ticks(aeg) + 5)
	assert_eq(n(GameEvent.Kind.RELOAD_START), 0)
	assert_eq(a.ammo[0].mag, 5)


func test_the_trigger_does_nothing_when_the_character_cannot_fire() -> void:
	assert_eq(run(30, hold, false), 0)
	assert_eq(n(GameEvent.Kind.DRY_FIRE), 0)
	assert_eq(pool.active_count(), 0)
	a.ammo[0].mag = 0
	run(30, hold, false)
	assert_eq(n(GameEvent.Kind.DRY_FIRE), 0, "no dry click either")


func test_spawns_a_bb_at_the_eye_at_muzzle_velocity_along_the_aim() -> void:
	run(1, hold)
	var bb := newest_bb()
	assert_eq(bb.owner_id, 1)
	var speed := bb.velocity.length()
	assert_almost_eq(speed, Ballistics.muzzle_velocity(aeg, rules), 1e-3, "Vector3 is single precision")
	assert_almost_eq(speed, 88.0, 0.5, "~1 J on 0.25 g BBs")
	assert_true(bb.velocity.z < -0.99 * speed, "yaw 0 aims down -Z")
	assert_almost_eq(bb.position.distance_to(EYE), 0.0, 1e-6)
	var shot := events.first(GameEvent.Kind.SHOT)
	assert_eq(shot.actor, 1)
	assert_eq(shot.slot, 0)
	assert_eq(shot.position, EYE)
	assert_almost_eq(shot.direction.dot(bb.velocity.normalized()), 1.0, 1e-9)


func test_fires_each_replicas_own_bbs() -> void:
	run(1, hold)
	var rifle_bb := newest_bb()
	assert_almost_eq(rifle_bb.mass, 0.00025, 1e-9)
	assert_eq(rifle_bb.spin, aeg.hop_up_max * aeg.hop_up_dial * tuning.ballistics.spin_per_hop, "factory dial's backspin")
	run(1, release)
	switch_to(1)
	run(draw_ticks(pistol))
	run(1, hold)
	var pistol_bb := newest_bb()
	assert_ne(pistol_bb, rifle_bb)
	assert_almost_eq(pistol_bb.mass, 0.0002, 1e-9)
	assert_eq(pistol_bb.spin, pistol.hop_up_max * pistol.hop_up_dial * tuning.ballistics.spin_per_hop)
	assert_almost_eq(pistol_bb.velocity.length(), 83.7, 0.5)  # 0.70 J with 0.20 g (PH2)


func test_gives_each_bb_the_hop_up_its_replica_is_dialled_to() -> void:
	a.hop_ups[0] = 1.0
	run(1, hold)
	assert_eq(newest_bb().spin, aeg.hop_up_max * tuning.ballistics.spin_per_hop)
	a.hop_ups[0] = 5.0
	run(1, release)
	a.cooldown = 0.0
	run(1, hold)
	assert_eq(newest_bb().spin, aeg.hop_up_max * rules.hop_up_max_dial * tuning.ballistics.spin_per_hop, "held in range")


func test_fires_the_bb_weight_picked_heavier_leaves_slower_with_a_little_more_energy() -> void:
	a.bb_weights[0] = 0.28
	run(1, hold)
	var bb := newest_bb()
	assert_almost_eq(bb.mass, 0.00028, 1e-9)
	var speed := bb.velocity.length()
	assert_almost_eq(speed, Ballistics.muzzle_velocity(aeg, rules, 0.28), 1e-3)
	assert_true(speed < Ballistics.muzzle_velocity(aeg, rules))
	assert_true(0.5 * bb.mass * speed * speed > aeg.muzzle_energy)


## Sideways angles of `shots` single shots fired with a fresh stream seeded `seed_value`, at `spread_scale`.
func sideways_angles(shots: int, spread_scale: float, seed_value: int = 7) -> Array[float]:
	before_each()
	rng = Seeds.stream(seed_value)
	c.spread_scale = spread_scale
	var out: Array[float] = []
	for i in shots:
		a.recoil = 0.0
		a.cooldown = 0.0
		a.ammo[0].mag = 10
		run(1, hold)
		run(1, release)
		var v := newest_bb().velocity
		out.append(asin(v.x / v.length()))
	return out


func test_spread_is_about_the_configured_amount_and_seeded() -> void:
	var xs := sideways_angles(300, 1.0)
	var sum := 0.0
	for x in xs:
		sum += x * x
	var sd := sqrt(sum / xs.size())
	var want := deg_to_rad(aeg.spread_deg)
	assert_between(sd, want * 0.7, want * 1.3)
	assert_eq(sideways_angles(20, 1.0), xs.slice(0, 20), "same seed, same directions")
	var shaky := sideways_angles(20, 2.6)
	for i in 20:
		assert_almost_eq(shaky[i], xs[i] * 2.6, 1e-6, "the spread scale scales the same draws")
	assert_ne(sideways_angles(20, 1.0, 8), xs.slice(0, 20), "another seed, other directions")


func test_spreads_as_much_sideways_as_up_and_down_whatever_the_pitch() -> void:
	var stream := Seeds.stream(11)
	for pitch_deg: float in [0.0, 70.0]:
		var yaw := 0.4
		var pitch := deg_to_rad(pitch_deg)
		var f := Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))
		var right := Vector3(cos(yaw), 0.0, -sin(yaw))
		var up := right.cross(f)
		var h := 0.0
		var v := 0.0
		var count := 4000
		for i in count:
			var gx := stream.randfn(0.0, 1.0)
			var gy := stream.randfn(0.0, 1.0)
			var d := Armament.spread_direction(yaw, pitch, deg_to_rad(aeg.spread_deg), gx, gy,
					deg_to_rad(rules.max_shot_pitch_deg))
			h += pow(asin(d.dot(right)), 2.0)
			v += pow(asin(d.dot(up)), 2.0)
		var sh := sqrt(h / count)
		var sv := sqrt(v / count)
		assert_between(sh / sv, 0.93, 1.07, "pitch %s" % pitch_deg)
		assert_true(sh > deg_to_rad(aeg.spread_deg) * 0.9)


func test_never_sends_a_bb_past_vertical() -> void:
	c.pitch = PI / 2.0 - 0.02
	run(60, hold)
	assert_true(pool.active_count() > 5)
	for bb in pool.bbs:
		if bb.active:
			assert_true(bb.velocity.z <= 0.0, "past vertical a BB aimed down -Z would head +Z")


func test_kicks_the_aim_up_per_shot_caps_it_and_recovers() -> void:
	run(1, hold)
	assert_almost_eq(a.recoil, deg_to_rad(aeg.recoil_deg), 1e-6)
	run(59, hold)
	assert_true(a.recoil <= deg_to_rad(rules.recoil_max_deg) + 1e-12)
	run(ceili(rules.recoil_recovery_time * 5.0 / DT), release)
	assert_true(a.recoil < deg_to_rad(aeg.recoil_deg) * 0.1)


func test_a_double_tap_never_fires_faster_than_the_rate_after_sitting_ready() -> void:
	switch_to(1)
	run(draw_ticks(pistol) + 30)
	run(40, func(p: PlayerCommand, i: int) -> void: p.fire = i == 0 or i == 2)
	assert_eq(shot_ticks.size(), 2)
	assert_true((shot_ticks[1] - shot_ticks[0]) * DT >= 1.0 / pistol.fire_rate - 1e-9, str(shot_ticks))


func test_turns_fast_clicking_into_shots_at_the_full_rate() -> void:
	for hz: float in [7.5, 8.6, 10.0]:
		before_each()
		switch_to(1)
		run(draw_ticks(pistol))
		var period := 60.0 / hz
		var shots := run(120, func(p: PlayerCommand, i: int) -> void: p.fire = fmod(float(i), period) < 2.0)
		var clicks := ceili(120.0 / period)
		assert_true(shots >= mini(clicks, int(pistol.fire_rate * 2.0)) - 1, "%s Hz: %d" % [hz, shots])
		assert_true(shots <= int(pistol.fire_rate * 2.0) + 1)


func test_an_empty_aeg_held_clicks_once_then_reloads() -> void:
	a.ammo[0].mag = 3
	assert_eq(run(60, hold), 3)
	assert_eq(n(GameEvent.Kind.DRY_FIRE), 1)
	assert_eq(n(GameEvent.Kind.RELOAD_START), 1)


func test_clicks_and_reloads_again_after_switching_away_mid_reload_and_back() -> void:
	a.ammo[0].mag = 0
	run(2, hold)
	assert_true(a.reloading())
	run(1, func(p: PlayerCommand, _i: int) -> void:
		p.fire = true
		p.switch_to = 1)
	run(draw_ticks(pistol), hold)
	run(1, func(p: PlayerCommand, _i: int) -> void:
		p.fire = true
		p.switch_to = 0)
	run(draw_ticks(aeg) + 1, hold)
	assert_eq(n(GameEvent.Kind.DRY_FIRE), 1)
	assert_eq(n(GameEvent.Kind.RELOAD_START), 1)


func test_steps_the_aeg_selector_and_the_pistol_has_only_semi() -> void:
	var semi := ReplicaConfig.FireMode.SEMI
	var burst := ReplicaConfig.FireMode.BURST
	var auto := ReplicaConfig.FireMode.AUTO
	assert_eq(aeg.fire_modes, [semi, burst, auto] as Array[ReplicaConfig.FireMode])
	assert_eq(pistol.fire_modes, [semi] as Array[ReplicaConfig.FireMode])
	assert_eq(Armament.next_fire_mode(aeg, auto), semi)
	assert_eq(Armament.next_fire_mode(aeg, semi), burst)
	assert_eq(Armament.next_fire_mode(aeg, burst), auto)
	assert_eq(Armament.next_fire_mode(pistol, semi), semi)
	assert_eq(a.modes, [auto, semi] as Array[ReplicaConfig.FireMode])
	run(1, func(p: PlayerCommand, _i: int) -> void: p.cycle_fire_mode = true)
	assert_eq(a.modes[0], semi)
	var e := events.first(GameEvent.Kind.FIRE_MODE)
	assert_eq([e.actor, e.slot, e.value], [1, 0, semi])
	run(5)
	assert_eq(a.modes[0], semi, "one press, one step")
	switch_to(1)
	run(1, func(p: PlayerCommand, _i: int) -> void: p.cycle_fire_mode = true)
	assert_eq(n(GameEvent.Kind.FIRE_MODE), 0, "the pistol's selector says nothing")
	assert_eq(a.modes, [semi, semi] as Array[ReplicaConfig.FireMode])


func test_fires_one_bb_per_pull_in_semi_however_long_held() -> void:
	run(1, func(p: PlayerCommand, _i: int) -> void: p.cycle_fire_mode = true)
	assert_eq(a.fire_mode(), ReplicaConfig.FireMode.SEMI)
	assert_eq(run(60, hold), 1)


func test_fires_a_burst_per_pull_at_the_fire_rate_held_or_tapped() -> void:
	a.modes[0] = ReplicaConfig.FireMode.BURST
	assert_eq(run(60, hold), rules.burst_shots, "held a whole second: one burst")
	for i in range(1, shot_ticks.size()):
		assert_almost_eq((shot_ticks[i] - shot_ticks[i - 1]) * DT, 1.0 / aeg.fire_rate, 0.05)
	run(1, release)
	assert_eq(run(31, func(p: PlayerCommand, i: int) -> void: p.fire = i == 0), rules.burst_shots, "a tap: a whole burst")
	assert_eq(a.mag(), aeg.mag_size - 2 * rules.burst_shots)


func test_ignores_pulls_during_a_burst_and_buffers_one_just_after() -> void:
	a.modes[0] = ReplicaConfig.FireMode.BURST
	var during := ceili(rules.burst_shots / aeg.fire_rate / DT) - 1
	assert_eq(run(during, func(p: PlayerCommand, i: int) -> void: p.fire = i % 2 == 0), rules.burst_shots)
	assert_eq(a.burst_shots_left, 0)
	assert_eq(run(30, func(p: PlayerCommand, i: int) -> void: p.fire = i == 0), rules.burst_shots)


func test_ends_a_burst_early_when_the_magazine_runs_dry() -> void:
	a.modes[0] = ReplicaConfig.FireMode.BURST
	a.ammo[0].mag = rules.burst_shots - 1
	assert_eq(run(30, func(p: PlayerCommand, i: int) -> void: p.fire = i == 0), rules.burst_shots - 1)
	assert_eq(n(GameEvent.Kind.DRY_FIRE), 1)
	assert_eq(n(GameEvent.Kind.RELOAD_START), 1)
	assert_eq(a.burst_shots_left, 0)


func test_cuts_a_burst_short_on_a_switch_or_when_it_cannot_fire() -> void:
	a.modes[0] = ReplicaConfig.FireMode.BURST
	assert_eq(run(1, hold), 1)
	assert_eq(a.burst_shots_left, rules.burst_shots - 1)
	switch_to(1)
	assert_eq(a.burst_shots_left, 0)
	before_each()
	a.modes[0] = ReplicaConfig.FireMode.BURST
	run(1, hold)
	assert_eq(run(30, release, false), 0)
	assert_eq(a.burst_shots_left, 0)


func test_keeps_selectors_dials_and_bb_weights_across_rounds() -> void:
	a.modes[0] = ReplicaConfig.FireMode.BURST
	a.hop_ups[0] = 0.4
	a.hop_ups[1] = 0.8
	a.bb_weights[0] = 0.28
	a.ammo[0].mag = 3
	a.ammo[1].pouch[0] = 0
	switch_to(1)
	c.respawn()
	assert_eq(a.modes, [ReplicaConfig.FireMode.BURST, ReplicaConfig.FireMode.SEMI] as Array[ReplicaConfig.FireMode])
	assert_eq(Array(a.hop_ups), [0.4, 0.8])
	assert_eq(Array(a.bb_weights), [0.28, pistol.bb_weight])
	assert_eq(a.mag(), aeg.mag_size)
	assert_eq(a.active, 0)
	assert_eq(a.ammo[1].spare_bbs(), pistol.mag_size * (pistol.mags - 1))


func test_needs_a_fresh_pull_for_a_semi_shot_when_held_as_a_round_starts() -> void:
	a.modes[0] = ReplicaConfig.FireMode.SEMI
	run(1, hold)
	c.respawn()
	assert_eq(run(10, hold), 0)
	assert_eq(run(1, release), 0)
	assert_eq(run(1, hold), 1)


func test_an_empty_loadout_does_nothing() -> void:
	var empty: Array[ReplicaConfig] = []
	c = Character.new(2, 1, Vector3.ZERO, 0.0, empty)
	assert_eq(run(10, hold), 0)
	assert_null(c.armament.replica())
	assert_eq(c.armament.mag(), 0)


func test_allocates_no_objects_per_tick_once_warm() -> void:
	a.ammo[0].mag = 100000
	run(120, hold)
	var before := Performance.get_monitor(Performance.OBJECT_COUNT)
	run(600, func(p: PlayerCommand, i: int) -> void:
		p.fire = i % 50 < 40
		p.switch_to = 1 if i == 300 else (0 if i == 400 else -1))
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), before)
