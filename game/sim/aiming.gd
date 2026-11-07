class_name Aiming
## Aiming down sights (the browser game's sim/aiming.ts, M84): through the iron sights or a fitted optic. Not while
## reloading, bringing a replica up or with it holstered (the sight comes back up afterwards if the button is still held;
## an aim press draws a holstered replica: Armament). Aiming slows you to walking pace and rules out sprinting
## (Movement), and the sight comes up over aim_raise_time (times the replica's raise_scale: its optic and handling),
## tightening the aim as it does (Accuracy). Call before the
## movement step, for characters in play.


static func step(c: Character, cmd: PlayerCommand, cfg: MovementConfig, dt: float) -> void:
	# Reload and draw are as the last tick left them: a reload started this tick lowers the sight on the next.
	# Not mid-vault: an aim held through one comes up again after it (BP5).
	c.aiming = cmd.aim and can_aim(c)
	var raise := dt / raise_time(c, cfg)
	c.aim_raise = minf(1.0, c.aim_raise + raise) if c.aiming else maxf(0.0, c.aim_raise - raise)


## Whether `c`'s sight can be up this tick if aim is held, by the armament as the last tick left it: a replica in hand,
## not mid-reload, draw or vault. The player's input reads it before the tick (BP6), so a mouse wheel notch on the tick a
## reload or draw has just started switches rather than turning a zoom the sight no longer shows.
static func can_aim(c: Character) -> bool:
	var a := c.armament
	return not a.holstered and not a.reloading() and not a.drawing() and not c.vault.active


## Whether the zoom keys turn `c`'s optic this tick if aim is held (SN2, BP6): a variable optic in hand whose sight can
## be up (can_aim), no bomb thrown or in hand. Read before the tick, as can_aim.
static func zoom_turns(c: Character) -> bool:
	return c.armament.zoom_turns() and can_aim(c) and not Grenades.throwing(c) \
			and Grenades.in_hand(c) == Grenade.Kind.NONE


## The seconds `c`'s sight takes to come all the way up (or down): aim_raise_time times its replica's raise_scale.
static func raise_time(c: Character, cfg: MovementConfig) -> float:
	var r := c.armament.replica()
	return cfg.aim_raise_time * (r.raise_scale if r != null else 1.0)
