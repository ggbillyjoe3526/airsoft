class_name BotHolster
## Bots and the holster (the browser game's ai/botHolster.ts): the same command and rules as the player's. A bot puts its
## primary away on a long, calm sprint through its own half, and draws it again, the slower draw, as soon as that stops
## being safe: someone seen or heard, the enemy's half, a reload to make, or the sprint over for a moment
## (BotConfig.holster_*). A follower sprinting after a giver whose replica is away puts its own away at once (Follow me).
## Allocates nothing.


## Writes `cmd.holster` and `cmd.switch_to` for `b` (the primary, which also draws it when holstered; -1 while it keeps
## it away). Call last in a bot's tick, once its sprint, fire and reload are decided.
static func step(b: Bot, w: BotWorld, cmd: PlayerCommand, dt: float) -> void:
	var cfg := w.cfg
	var a := b.character.armament
	b.sprint_run = b.sprint_run + dt if cmd.sprint else 0.0
	b.sprint_gap = 0.0 if cmd.sprint else b.sprint_gap + dt
	var busy := cmd.fire or cmd.reload or a.reloading() or a.reload_queued
	var safe := w.live and not busy and not b.target_visible and w.time - b.last_threat_at > cfg.holster_calm_for \
			and not w.planner.in_enemy_half(b)
	# Following a giver with the replica away (Follow me), it puts its own away too as it sprints, once safe, and keeps
	# it away while the giver does: its sprint breaks as it eases back into place never add up to holster_after (and
	# drawing at each one would flap), and with its replica up it can't keep pace with the holster's faster sprint
	# (MovementConfig.holster_sprint_scale; NA1's Follow me guard).
	var with_giver := b.order == SquadOrder.Kind.FOLLOW and b.order_giver != null and put_away(b.order_giver)
	var away := safe and (b.sprint_gap < cfg.holster_draw_after or with_giver if a.holstered
			else b.sprint_run >= cfg.holster_after or (with_giver and cmd.sprint))
	cmd.holster = away and not a.holstered
	cmd.switch_to = -1 if away else 0


## Whether `c` has put its replica away in the holster: a bomb in hand or being thrown puts it down for the throw, and
## counts as away only if it was holstered before (BP3: followers holstered as the giver readied a flash, then drew
## slowly at the first threat).
static func put_away(c: Character) -> bool:
	var hand := c.grenades
	if hand.readied != Grenade.Kind.NONE:
		return hand.ready_was_holstered
	if hand.throwing != Grenade.Kind.NONE:
		return hand.was_holstered
	return c.armament.holstered
