class_name Armament
extends RefCounted
## A character's replicas and what they're doing: magazines, the selector, reloads, draws, the trigger and recoil (the
## browser game's sim/armament.ts, without its optics, parts, magazine toss, bottomless magazines or vault hold-off; the
## weapon torch fitted to each replica is here, Torch switches it). Plain data; `step` is the only rule that changes it
## during play.

## Magazines carried for one replica: the one loaded and the spares in the pouch, each with the BBs it has left. A
## reload swaps the loaded one for the fullest spare and puts the old one back as it is (no topping up); empties stay
## empty. Nothing refills during a round (in practice the spares stay full: RangeTargets.refill_spares).
class Ammo:
	extends RefCounted
	## BBs in the loaded magazine.
	var mag: int = 0
	## BBs in each spare magazine (fixed length: a slot is swapped, never removed).
	var pouch: PackedInt32Array = PackedInt32Array()

	## Full magazines for `r`: the loaded one and mags - 1 spares.
	func fill(r: ReplicaConfig) -> void:
		mag = r.mag_size
		pouch.resize(maxi(0, r.mags - 1))
		pouch.fill(r.mag_size)

	## The spare a reload would take: the fullest, if it holds more than the loaded one; else -1 (the HUD marks it).
	func next_spare() -> int:
		var best := -1
		for i in pouch.size():
			if best < 0 or pouch[i] > pouch[best]:
				best = i
		return best if best >= 0 and pouch[best] > mag else -1

	## BBs left in the spares together.
	func spare_bbs() -> int:
		var n := 0
		for m in pouch:
			n += m
		return n


## The replica in each loadout slot.
var replicas: Array[ReplicaConfig] = []
## Each slot's magazines.
var ammo: Array[Ammo] = []
## The slot in hand.
var active: int = 0
## Seconds until the next shot may go (slightly negative keeps an auto rate exact).
var cooldown: float = 0.0
## Each slot's cooldown while it is put away (s, 0 for the slot in hand): a bolt still cycling keeps cycling while
## stowed, and never holds up the replica switched to (BP3: the Sniper Rifle's 1.25 s blocked the pistol's first shot).
var stowed_cooldowns: PackedFloat64Array = PackedFloat64Array()
## The replica is put away (the holster): nothing in hand fires, aims, reloads, turns its dial or switches its selector.
var holstered: bool = false
## The aim button last tick: a press, not a held button, draws a holstered replica.
var aim_was_down: bool = false
## Seconds left on the reload under way (0: none), and on bringing the replica in hand up after a switch or out of the
## holster.
var reload_left: float = 0.0
var draw_left: float = 0.0
## Seconds the draw under way takes in all (presentation shows draw_left / draw_total), and whether it came out of the
## holster (the arms rise from it partway through: UpperBlend).
var draw_total: float = 0.0
var drawn_from_holster: bool = false
## Seconds left to honour a semi or burst press that came while the replica wasn't ready.
var pending_press: float = 0.0
## A reload pressed during a draw: it starts once the replica is up.
var reload_queued: bool = false
## This trigger pull has clicked dry already (a held trigger clicks once per pull).
var dry_fired_this_pull: bool = false
## The trigger last tick, for press detection. Kept through a refill, so a trigger held as a round starts needs a fresh
## pull for a semi shot.
var trigger_was_down: bool = false
## Shots never use up the magazine: the Dev settings' Bottomless magazines, kept between rounds (DevCheats).
var bottomless: bool = false
## The upward aim kick from recoil now (rad).
var recoil: float = 0.0
## BBs still to come in the burst under way (0: none).
var burst_shots_left: int = 0
## Each slot's selector setting (one of its fire_modes), hop-up dial (0..1 of hop_up_max), BB weight (g) and optic zoom
## (×: aim_zoom, turned up to aim_zoom_to on a variable optic, SN2). Factory values to start; kept through a refill.
var modes: Array[ReplicaConfig.FireMode] = []
var hop_ups: PackedFloat64Array = PackedFloat64Array()
var bb_weights: PackedFloat64Array = PackedFloat64Array()
var zooms: PackedFloat64Array = PackedFloat64Array()
## Each slot's weapon light (Torch.Light; null: none). Set as the match is built, only on a field played at night
## (Kit.lights_for); empty or short: no light on the slots past its end.
var lights: Array[Torch.Light] = []


## A fresh armament for `loadout`: full magazines, each replica's selector and dial as it comes, and the BB weight
## loaded in each slot (`weights`, a Kit's; a slot it has none for loads its factory weight).
static func create(loadout: Array[ReplicaConfig], weights: PackedFloat64Array = PackedFloat64Array()) -> Armament:
	var a := Armament.new()
	a.replicas = loadout.duplicate()
	for i in a.replicas.size():
		var r := a.replicas[i]
		var m := Ammo.new()
		m.fill(r)
		a.ammo.append(m)
		a.modes.append(r.default_fire_mode)
		a.hop_ups.append(r.hop_up_dial)
		a.zooms.append(r.aim_zoom)
		a.bb_weights.append(weights[i] if i < weights.size() else r.bb_weight)
		a.stowed_cooldowns.append(0.0)
	return a


## Full magazines again for a new round, the first slot in hand and nothing under way; selectors, dials, BB weights and
## the trigger's state kept.
func refill() -> void:
	for i in replicas.size():
		ammo[i].fill(replicas[i])
	active = 0
	holstered = false
	cooldown = 0.0
	stowed_cooldowns.fill(0.0)
	reload_left = 0.0
	draw_left = 0.0
	draw_total = 0.0
	drawn_from_holster = false
	pending_press = 0.0
	reload_queued = false
	dry_fired_this_pull = false
	recoil = 0.0
	burst_shots_left = 0


## Every selector back to its replica's default, for a new match (the browser game's restartMatch), held to
## `most` (the field's start mode, RoundState.start_mode; AUTO: no rule) as start_mode holds it.
func reset_fire_modes(most: ReplicaConfig.FireMode = ReplicaConfig.FireMode.AUTO) -> void:
	for i in replicas.size():
		modes[i] = start_mode(replicas[i], most)


## The mode `r` starts on under a field's start mode `most` ("no full auto indoors", owner 2026-11-02): its default
## where that is no higher (SEMI < BURST < AUTO), else the highest mode it offers that is, else its lowest. Any replica
## whose default is full auto is held, whatever it is.
static func start_mode(r: ReplicaConfig, most: ReplicaConfig.FireMode) -> ReplicaConfig.FireMode:
	if r.default_fire_mode <= most or r.fire_modes.is_empty():
		return r.default_fire_mode
	var lowest := r.fire_modes[0]
	var held := false
	var highest_held := lowest
	for m in r.fire_modes:
		lowest = mini(lowest, m) as ReplicaConfig.FireMode
		if m <= most and (not held or m > highest_held):
			highest_held = m
			held = true
	return highest_held if held else lowest


## Every hop-up dial back to its replica's setting, for a new match: a turn in play lasts the match.
func reset_hop_ups() -> void:
	for i in replicas.size():
		hop_ups[i] = replicas[i].hop_up_dial


## Every variable optic back to its lowest zoom, for a new match: a turn in play lasts the match (SN2).
func reset_zooms() -> void:
	for i in replicas.size():
		zooms[i] = replicas[i].aim_zoom


## The zoom aimed through the optic on the replica in hand (×; 0: none of its own, the iron sights').
func zoom_now() -> float:
	if replicas.is_empty():
		return 0.0
	return zooms[active]


## The replica in hand has a variable optic (SN2): aimed, the mouse wheel turns its zoom.
func zoom_turns() -> bool:
	return not replicas.is_empty() and not holstered and replicas[active].aim_zoom_to > replicas[active].aim_zoom


## The light on the replica in hand, or null: none fitted, or the replica is holstered (the torch goes out, M92).
func light_in_hand() -> Torch.Light:
	if holstered or active >= lights.size():
		return null
	return lights[active]


## The replica in hand, or null with an empty loadout.
func replica() -> ReplicaConfig:
	return replicas[active] if active < replicas.size() else null


## Any magazine carried rattles (ReplicaConfig.rattles): heard as you move, even walking.
func rattles() -> bool:
	for r in replicas:
		if r.rattles:
			return true
	return false


## The selector setting of the replica in hand.
func fire_mode() -> ReplicaConfig.FireMode:
	return modes[active] if active < modes.size() else ReplicaConfig.FireMode.SEMI


## Fills the loaded magazine of the replica in hand (the Dev settings' Bottomless switched on, DevCheats.apply); a
## dry pull clicks again once it runs out, and spares are untouched.
func top_up_in_hand() -> void:
	if active >= replicas.size():
		return
	ammo[active].mag = replicas[active].mag_size
	dry_fired_this_pull = false


## BBs in the loaded magazine of the replica in hand, and in its spares together.
func mag() -> int:
	return ammo[active].mag if active < ammo.size() else 0


func spare_bbs() -> int:
	return ammo[active].spare_bbs() if active < ammo.size() else 0


func reloading() -> bool:
	return reload_left > 0.0


## A reload is all the replica in hand waits for: its magazine is empty, a spare has BBs, and nothing is under way (no
## reload, none queued for the end of a draw, not holstered). The HUD's reload prompt shows on it (RL2).
func reload_due() -> bool:
	if replicas.is_empty() or holstered or reload_left > 0.0 or reload_queued:
		return false
	var loaded := ammo[active]
	return loaded.mag <= 0 and loaded.next_spare() >= 0


func drawing() -> bool:
	return draw_left > 0.0


## The selector's next setting for `r` after `mode`, wrapping round; `mode` itself if it has only one.
static func next_fire_mode(r: ReplicaConfig, mode: ReplicaConfig.FireMode) -> ReplicaConfig.FireMode:
	if r.fire_modes.is_empty():
		return r.default_fire_mode
	var i := r.fire_modes.find(mode)
	return r.fire_modes[(i + 1) % r.fire_modes.size()]


## The way a shot goes: the aim (`yaw`, `pitch`) thrown off by `gx` and `gy` standard deviations of `spread` (rad),
## sideways and up (sim/armament.ts spreadDirection, audit SIM-09). Up and down is a change of pitch, held within
## `max_pitch` (rad) so a shot never goes over the top; sideways is a turn about the line of sight's own up, so it is the
## same angle at any pitch.
static func spread_direction(yaw: float, pitch: float, spread: float, gx: float, gy: float, max_pitch: float) -> Vector3:
	var p := clampf(pitch + gy * spread, -max_pitch, max_pitch)
	var cp := cos(p)
	var f := Vector3(-sin(yaw) * cp, sin(p), -cos(yaw) * cp)
	# Right of the aim, level and square to it; a tangent, so the angle off the aim is exactly gx × spread.
	var side := tan(gx * spread)
	return Vector3(f.x + cos(yaw) * side, f.y, f.z - sin(yaw) * side).normalized()


## One tick of `c`'s replica handling: switching, the selector, reloading, firing and recoil. BBs leave from `eye`;
## `kick_scale` multiplies each shot's kick (above 1 on the run). With `can_fire` false (out of play, the round decided,
## through a vault and the moment after) the trigger does nothing and a burst under way ends. `fire_hold_off` (s) is how
## long `can_fire` stays false after a vault: a semi or burst press made then is kept that much longer, so it fires when
## the replica comes up instead of expiring first.
static func step(c: Character, cmd: PlayerCommand, eye: Vector3, kick_scale: float, can_fire: bool, pool: BBPool,
		rng: RandomNumberGenerator, events: SimEvents, tuning: SimTuning, dt: float, fire_hold_off: float = 0.0) -> void:
	var a := c.armament
	if a.replicas.is_empty():
		return
	var rules := tuning.replica_rules
	a.recoil *= exp(-dt / rules.recoil_recovery_time)
	# The tick the cooldown runs out keeps its overshoot (down to -dt), so a held trigger fires at the exact rate on
	# average. In semi and burst a replica that sat ready a whole tick rests at 0, so a fresh pull isn't a tick early.
	if a.cooldown <= 0.0 and a.modes[a.active] != ReplicaConfig.FireMode.AUTO:
		a.cooldown = 0.0
	else:
		a.cooldown = maxf(-dt, a.cooldown - dt)
	for i in a.stowed_cooldowns.size():
		if a.stowed_cooldowns[i] > 0.0:
			a.stowed_cooldowns[i] = maxf(0.0, a.stowed_cooldowns[i] - dt)
	a.pending_press = maxf(0.0, a.pending_press - dt)
	if a.draw_left > 0.0:
		a.draw_left = maxf(0.0, a.draw_left - dt)

	if a.reload_left > 0.0:
		a.reload_left -= dt
		if a.reload_left <= 0.0:
			a.reload_left = 0.0
			var loading := a.ammo[a.active]
			var best := loading.next_spare()
			if best >= 0:
				var loaded := loading.mag
				loading.mag = loading.pouch[best]
				loading.pouch[best] = loaded
			a.dry_fired_this_pull = false # a fresh magazine: running it dry clicks (and reloads) again
			a._event(events, GameEvent.Kind.RELOAD_END, c.id)

	# The holster: putting the replica away cancels a reload and a draw, as a switch does. Holstered, a slot draws that
	# replica, and a fresh trigger pull, aim press or reload the one put away, each the slower draw from the holster; a
	# reload pressed for it starts once it is up. Switching cancels a reload: the magazine being swapped stays as it was.
	var slot := cmd.switch_to if cmd.switch_to >= 0 and cmd.switch_to < a.replicas.size() else -1
	if cmd.holster and not a.holstered:
		a.holstered = true
		a.reload_left = 0.0
		a.draw_left = 0.0
		a.pending_press = 0.0
		a.burst_shots_left = 0
		a.reload_queued = false
		a._event(events, GameEvent.Kind.HOLSTER, c.id)
	elif a.holstered:
		var press := (cmd.fire and not a.trigger_was_down) or (cmd.aim and not a.aim_was_down) or cmd.reload
		if slot >= 0 or press:
			a._draw(slot if slot >= 0 else a.active, c.id, events, rules.holster_draw_scale)
	elif slot >= 0 and slot != a.active:
		a._draw(slot, c.id, events)
	a.aim_was_down = cmd.aim
	if a.holstered:
		# Nothing in hand: the trigger is only followed, so one held as the replica went away doesn't draw it.
		a.trigger_was_down = cmd.fire
		if not cmd.fire:
			a.dry_fired_this_pull = false
		return
	var replica_now := a.replicas[a.active]
	var ammo_now := a.ammo[a.active]

	if cmd.cycle_fire_mode and replica_now.fire_modes.size() > 1:
		a.modes[a.active] = next_fire_mode(replica_now, a.modes[a.active])
		a.burst_shots_left = 0
		var moved := a._event(events, GameEvent.Kind.FIRE_MODE, c.id)
		moved.value = a.modes[a.active]
	var mode := a.modes[a.active]
	if cmd.hop_up_steps != 0:
		a._turn_hop_up(c.id, cmd.hop_up_steps, rules, events)
	# Only with the sight up (Aiming: not mid-reload or draw): a turn you can't see is no turn.
	if cmd.zoom_steps != 0 and c.aiming and a.zoom_turns():
		a._turn_zoom(c.id, cmd.zoom_steps, rules, events)

	var ready := a.draw_left <= 0.0 and a.reload_left <= 0.0
	if cmd.reload and a.draw_left > 0.0 and a.reload_left <= 0.0:
		a.reload_queued = true
	var reload_asked := (cmd.reload or a.reload_queued) and ready
	if ready:
		a.reload_queued = false
	if reload_asked:
		if ammo_now.next_spare() >= 0:
			a._start_reload(c.id, events)
		elif ammo_now.mag < replica_now.mag_size:
			# Nothing fuller to swap in: said, unless the magazine is full anyway (R then plainly does nothing).
			a._event(events, GameEvent.Kind.RELOAD_REFUSED, c.id)

	var pressed := cmd.fire and not a.trigger_was_down
	a.trigger_was_down = cmd.fire
	if not cmd.fire:
		a.dry_fired_this_pull = false
	# Semi and burst presses are kept briefly, so a click during the cooldown still fires when ready.
	if pressed:
		a.pending_press = rules.press_buffer + fire_hold_off
		if replica_now.bolt_action and a.cooldown > 0.0 and a.cooldown <= rules.bolt_press_window:
			# A spring rifle is worked by hand: a click once the handle is home fires as the cycle ends (BP3: one
			# after the handle looked home but before the cycle ran out was lost, with no shot and no dry click).
			a.pending_press += a.cooldown
	var busy := a.draw_left > 0.0 or a.reload_left > 0.0
	if a.burst_shots_left > 0 and (not can_fire or busy):
		a.burst_shots_left = 0
	if mode == ReplicaConfig.FireMode.BURST:
		# One pull, one burst: a pull during a burst doesn't queue another (one just after it is buffered).
		if a.burst_shots_left > 0:
			a.pending_press = 0.0
		elif a.pending_press > 0.0 and can_fire and not busy and a.cooldown <= 0.0:
			a.burst_shots_left = rules.burst_shots
			a.pending_press = 0.0
	var wants_shot := false
	match mode:
		ReplicaConfig.FireMode.AUTO:
			wants_shot = cmd.fire
		ReplicaConfig.FireMode.BURST:
			wants_shot = a.burst_shots_left > 0
		_:
			wants_shot = a.pending_press > 0.0
	if not wants_shot or not can_fire or busy or a.cooldown > 0.0:
		return

	if ammo_now.mag <= 0:
		# Empty: one dry click per pull (a burst that runs dry clicks once and ends), then a reload if a spare has BBs
		# and the controller reloads automatically.
		var click := false
		if mode == ReplicaConfig.FireMode.AUTO:
			click = not a.dry_fired_this_pull
		else:
			click = mode == ReplicaConfig.FireMode.BURST or pressed or a.pending_press > 0.0
		a.burst_shots_left = 0
		if click:
			a.dry_fired_this_pull = true
			a.pending_press = 0.0
			a._event(events, GameEvent.Kind.DRY_FIRE, c.id)
			# A manual reload (the player's setting, RL2) leaves it empty: only R loads it.
			if ammo_now.next_spare() >= 0 and not cmd.manual_reload:
				a._start_reload(c.id, events)
		return

	a.pending_press = 0.0
	if a.burst_shots_left > 0:
		a.burst_shots_left -= 1
	if not a.bottomless:
		ammo_now.mag -= 1
	a.cooldown += 1.0 / replica_now.fire_rate
	a._fire(c, replica_now, eye, kick_scale, pool, rng, events, tuning)


func _event(events: SimEvents, kind: GameEvent.Kind, actor: int) -> GameEvent:
	var e := events.add(kind)
	e.actor = actor
	e.slot = active
	return e


## Turns the hop-up dial of the replica in hand by `steps` notches (the browser game's turnHopUp, HD1): onto the dial's
## own steps and within its range, kept for the rest of the match. A HOP_UP event says so, even at an end of the dial.
func _turn_hop_up(actor: int, steps: int, rules: ReplicaRulesConfig, events: SimEvents) -> void:
	var before := hop_ups[active]
	var notch := roundi(before / rules.hop_up_dial_step) + steps
	var dial := clampf(notch * rules.hop_up_dial_step, rules.hop_up_min_dial, rules.hop_up_max_dial)
	hop_ups[active] = dial
	var e := _event(events, GameEvent.Kind.HOP_UP, actor)
	e.value = roundi(dial * 100.0)
	e.value2 = 1 if not is_equal_approx(dial, before) else 0


## Turns the variable optic on the replica in hand `steps` notches of `rules.zoom_step` (positive: in), between its
## aim_zoom and aim_zoom_to, with its ZOOM event.
func _turn_zoom(actor: int, steps: int, rules: ReplicaRulesConfig, events: SimEvents) -> void:
	var r := replicas[active]
	var before := zooms[active]
	var notch := roundi((before - r.aim_zoom) / rules.zoom_step) + steps
	var zoom := clampf(r.aim_zoom + notch * rules.zoom_step, r.aim_zoom, r.aim_zoom_to)
	zooms[active] = zoom
	var e := _event(events, GameEvent.Kind.ZOOM, actor)
	e.value = roundi(zoom * 100.0)
	e.value2 = 1 if not is_equal_approx(zoom, before) else 0


## The replica goes down for a throw (Grenades): away as holstered, silently, a reload, a draw and a burst stopped as a
## switch's are.
func put_down() -> void:
	holstered = true
	reload_left = 0.0
	draw_left = 0.0
	pending_press = 0.0
	burst_shots_left = 0
	reload_queued = false


## The replica in hand comes back up after a throw: `scale` times its draw time, with its DRAW event.
func bring_up(actor: int, events: SimEvents, scale: float) -> void:
	if not replicas.is_empty():
		_draw(active, actor, events, scale)


## Brings the replica in `slot` up, out of the holster or in place of the one in hand: `scale` times its draw time (1
## for a switch). Cancels a reload, a burst and a queued reload.
func _draw(slot: int, actor: int, events: SimEvents, scale: float = 1.0) -> void:
	if slot != active and slot < stowed_cooldowns.size() and active < stowed_cooldowns.size():
		stowed_cooldowns[active] = maxf(cooldown, 0.0)
		cooldown = stowed_cooldowns[slot]
		stowed_cooldowns[slot] = 0.0
	active = slot
	drawn_from_holster = holstered
	holstered = false
	# A press kept for the replica put away never fires the one drawn (BP3: a bolt-window click fired the pistol).
	pending_press = 0.0
	reload_left = 0.0
	draw_left = replicas[slot].draw_time * scale
	draw_total = draw_left
	dry_fired_this_pull = false # a dry click on the other replica doesn't count for this one
	burst_shots_left = 0
	reload_queued = false
	_event(events, GameEvent.Kind.DRAW, actor)


func _start_reload(actor: int, events: SimEvents) -> void:
	reload_left = replicas[active].reload_time
	_event(events, GameEvent.Kind.RELOAD_START, actor)


func _fire(c: Character, r: ReplicaConfig, eye: Vector3, kick_scale: float, pool: BBPool, rng: RandomNumberGenerator,
		events: SimEvents, tuning: SimTuning) -> void:
	var rules := tuning.replica_rules
	# Sideways first, then up and down: the browser game's draw order.
	var gx := rng.randfn(0.0, 1.0)
	var gy := rng.randfn(0.0, 1.0)
	var spread := deg_to_rad(r.spread_deg) * c.spread_scale
	var dir := spread_direction(c.yaw, c.pitch + recoil, spread, gx, gy, deg_to_rad(rules.max_shot_pitch_deg))
	recoil = minf(deg_to_rad(rules.recoil_max_deg), recoil + deg_to_rad(r.recoil_deg) * kick_scale)
	var e := _event(events, GameEvent.Kind.SHOT, c.id)
	e.position = eye
	e.direction = dir
	# The BB's path starts at the eye: its first step catches cover right in front of the shooter and anyone point-blank,
	# and it never hits its owner. Presentation draws it leaving the muzzle.
	var grams := bb_weights[active]
	var bb := pool.spawn(c.id, eye, dir, Ballistics.muzzle_velocity(r, rules, grams),
			Ballistics.hop_up_lift(r, hop_ups[active], rules), Ballistics.bb_mass(r, grams), tuning.ballistics.spin_per_hop,
			active)
	# Dev › Lasers (LZ1): the same shot, spread and kick, but a laser that BBStep resolves this tick.
	if c.lasers and bb != null:
		bb.laser = true
		e.value2 = GameEvent.SHOT_LASER
