class_name BotFireMode
extends RefCounted
## A bot's fire selector on a field with a start mode ("no full auto indoors", owner 2026-11-02, NA1): it keeps the
## replica on the field's start mode (Armament.start_mode) and may go to full auto only for a target across open
## ground down a long sight line (owner: "if the bot is aiming down that sight line and the target is in an open space
## then the bots can go full auto. It's an option; it doesn't mean they have to"). The map's data says both: the sight
## line is the level's own geometry along the aim (a ray, BotConfig.auto_line_min long), the open ground the nav grid's
## open field (NavGrid.open, the clear space round the target's cell, BotConfig.auto_open_min). As a burst begins with
## both true it decides once per target (BotConfig.auto_chance); it goes back to the start mode once the shot isn't
## open any more or the target is gone. On semi it taps at a player's pace (pull). On a field without a start mode it
## never touches the selector and pulls as it always has (bot kits come on full auto there, BotKits.kit_of).
## Allocation-free.

## The sight line's check (one at a time: the bots think in turn).
static var _hit: RayHit = RayHit.new()


## The trigger this tick, given whether the bot `wants` it down (on semi, a fresh pull). On a field with a start mode a
## bot on semi pulls no faster than a player taps (BotConfig.semi_tap_gap), so semi indoors is slower than full auto
## (a replica cycles a pull as fast as its full-auto rate, fire_rate); elsewhere, and in burst or auto, as wanted.
static func pull(b: Bot, w: BotWorld, wants: bool) -> bool:
	var a := b.character.armament
	if w.start_mode == ReplicaConfig.FireMode.AUTO or a.fire_mode() != ReplicaConfig.FireMode.SEMI:
		return wants
	if not wants or w.time < b.next_tap:
		return false
	b.next_tap = w.time + w.cfg.semi_tap_gap
	return true


## The selector this tick, called before the trigger: a press of the selector key while the replica in hand isn't on
## the mode wanted (one step a tick: semi to auto takes two). Never through a vault, or while presses kept through
## one are still played (Vault.with_held_presses): a press then would be kept too, and the selector would run past
## the mode wanted.
static func select(b: Bot, w: BotWorld, target: Character, cmd: PlayerCommand) -> void:
	if w.start_mode == ReplicaConfig.FireMode.AUTO:
		return
	var a := b.character.armament
	var v := b.character.vault
	if a.replicas.is_empty() or v.active or v.held_fire_modes > 0:
		return
	var replica := a.replicas[a.active]
	# Out of sight it goes back to the start mode and ends the burst, but keeps the target's full auto for when the next
	# burst finds it in the open again (on_burst; BP3: losing sight for a tick behind cover took it for good, the roll
	# being once per target).
	var shown := target != null and b.target_visible
	if not shown and b.auto_open:
		b.auto_open = false
		b.burst_left = 0.0
	var wanted := ReplicaConfig.FireMode.AUTO if shown and b.auto_open and b.goes_auto_for(target.id) \
			else Armament.start_mode(replica, w.start_mode)
	if a.fire_mode() != wanted and replica.fire_modes.has(wanted):
		cmd.cycle_fire_mode = true


## As a burst begins at `target` from `eye` along the unit `dir`: whether this target gets full auto. Only once per
## target in a round, remembered through fights with others between (BP6: a bot doesn't roll again each burst or each
## return); an open shot no longer open takes it back to the start mode, for good with that target.
static func on_burst(b: Bot, w: BotWorld, target: Character, eye: Vector3, dir: Vector3) -> void:
	if w.start_mode == ReplicaConfig.FireMode.AUTO or target == null:
		return
	var a := b.character.armament
	var bit := Bot.target_bit(target.id)
	if a.replicas.is_empty() or not a.replicas[a.active].fire_modes.has(ReplicaConfig.FireMode.AUTO):
		b.auto_won &= ~bit
		b.auto_open = false
		return
	# Decided against for this target: nothing to check again.
	if b.auto_rolled & bit != 0 and b.auto_won & bit == 0:
		b.auto_open = false
		return
	if not open_shot(w, eye, dir, target.position):
		b.auto_won &= ~bit # taken back: rolled, so never again for this target
		b.auto_open = false
		return
	if b.auto_won & bit != 0:
		b.auto_open = true
		return
	b.auto_rolled |= bit
	b.auto_open = false
	if b.rng.randf() < w.cfg.auto_chance:
		b.auto_won |= bit
		b.auto_open = true


## A burst held up (glass or leaves in the line, the sight not up) and picked up again at `target`: its full auto stays
## only if the shot is still the open one from where they now stand (BP6), else the burst finishes on the start mode.
static func on_resume(b: Bot, w: BotWorld, target: Character, eye: Vector3, dir: Vector3) -> void:
	if not b.auto_open or w.start_mode == ReplicaConfig.FireMode.AUTO or target == null:
		return
	if not open_shot(w, eye, dir, target.position):
		b.auto_open = false


## Whether a shot from `eye` along `dir` at someone standing at `feet` is the open one full auto is for: `feet` on open
## ground (the nav grid's open field at least auto_open_min round it), and nothing of the level within auto_line_min
## along the aim's heading (a long sight line).
static func open_shot(w: BotWorld, eye: Vector3, dir: Vector3, feet: Vector3) -> bool:
	return open_at(w, feet) and long_line(w, eye, dir)


## Level at eye height along the aim's heading (a line down the hall, not into the floor short of it).
static func long_line(w: BotWorld, eye: Vector3, dir: Vector3) -> bool:
	var level := Vector3(dir.x, 0.0, dir.z)
	if level.is_zero_approx():
		return false
	return not w.query.ray_past_railings(eye, eye + level.normalized() * w.cfg.auto_line_min, _hit)


static func open_at(w: BotWorld, feet: Vector3) -> bool:
	if w.nav == null:
		return false
	var c := w.nav.cell_index(feet.x, feet.z)
	return c >= 0 and w.nav.open[c] * w.nav.cell >= w.cfg.auto_open_min
