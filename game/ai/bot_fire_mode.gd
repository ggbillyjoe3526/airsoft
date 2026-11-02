class_name BotFireMode
extends RefCounted
## A bot's fire selector on a field with a start mode ("no full auto indoors", owner 2026-11-02, NA1): it keeps the
## replica on the field's start mode (Armament.start_mode) and may go to full auto only for a target across open
## ground down a long sight line (owner: "if the bot is aiming down that sight line and the target is in an open space
## then the bots can go full auto. It's an option; it doesn't mean they have to"). The map's data says both: the sight
## line is the level's own geometry along the aim (a ray, BotConfig.auto_line_min long), the open ground the nav grid's
## open field (NavGrid.open, the clear space round the target's cell, BotConfig.auto_open_min). As a burst begins with
## both true it decides once per target (BotConfig.auto_chance); it goes back to the start mode once the shot isn't
## open any more or the target is gone. On a field without a start mode it never touches the selector (bot kits come
## on full auto there, BotKits.kit_of). Allocation-free.

## The sight line's check (one at a time: the bots think in turn).
static var _hit: RayHit = RayHit.new()


## The selector this tick, called before the trigger: a press of the selector key while the replica in hand isn't on
## the mode wanted (one step a tick: semi to auto takes two).
static func select(b: Bot, w: BotWorld, target: Character, cmd: PlayerCommand) -> void:
	if w.start_mode == ReplicaConfig.FireMode.AUTO:
		return
	if target == null or not b.target_visible:
		b.auto_for = -1
	var a := b.character.armament
	if a.replicas.is_empty():
		return
	var replica := a.replicas[a.active]
	var wanted := ReplicaConfig.FireMode.AUTO if b.auto_for >= 0 and target != null and b.auto_for == target.id \
			else Armament.start_mode(replica, w.start_mode)
	if a.fire_mode() != wanted and replica.fire_modes.has(wanted):
		cmd.cycle_fire_mode = true


## As a burst begins at `target` from `eye` along the unit `dir`: whether this target gets full auto. Only once per
## target (a bot doesn't roll again each burst); an open shot no longer open takes it back to the start mode.
static func on_burst(b: Bot, w: BotWorld, target: Character, eye: Vector3, dir: Vector3) -> void:
	if w.start_mode == ReplicaConfig.FireMode.AUTO or target == null:
		return
	var a := b.character.armament
	if a.replicas.is_empty() or not a.replicas[a.active].fire_modes.has(ReplicaConfig.FireMode.AUTO):
		b.auto_for = -1
		return
	if not open_shot(w, eye, dir, target.position):
		b.auto_for = -1
		return
	if b.auto_for == target.id or b.auto_rolled_for == target.id:
		return
	b.auto_rolled_for = target.id
	if b.rng.randf() < w.cfg.auto_chance:
		b.auto_for = target.id


## Whether a shot from `eye` along `dir` at someone standing at `feet` is the open one full auto is for: nothing of
## the level within auto_line_min along the aim (a long sight line), and `feet` on open ground (the nav grid's open
## field at least auto_open_min round it).
static func open_shot(w: BotWorld, eye: Vector3, dir: Vector3, feet: Vector3) -> bool:
	return long_line(w, eye, dir) and open_at(w, feet)


static func long_line(w: BotWorld, eye: Vector3, dir: Vector3) -> bool:
	return not w.query.ray_past_railings(eye, eye + dir * w.cfg.auto_line_min, _hit)


static func open_at(w: BotWorld, feet: Vector3) -> bool:
	if w.nav == null:
		return false
	var c := w.nav.cell_index(feet.x, feet.z)
	return c >= 0 and w.nav.open[c] * w.nav.cell >= w.cfg.auto_open_min
