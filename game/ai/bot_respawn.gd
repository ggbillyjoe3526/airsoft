class_name BotRespawn
## Where a hit bot comes back into the round (RS1, Respawns): picked once a time out, on its own stream, and held until
## it is back (the simulation reads the pick only as the wait runs out, and shuts a forward spawn with an enemy near it).


## The spawn `b` picks (PlayerCommand.spawn_pick), out with a respawn coming: decided the first time it is asked this
## time out (b.spawn_picked; Bot.reset clears it as it comes back). With its team free to use its end's forward spawns
## (Respawns.forward_for), one of them at random with its personality's chance (bots.md › Forward spawn), or
## BotConfig.forward_spawn_chance; otherwise, and on an end with none, 0: the start area.
static func pick(b: Bot, w: BotWorld) -> int:
	if b.spawn_picked:
		return b.spawn_pick
	b.spawn_picked = true
	b.spawn_pick = 0
	var c := b.character
	if c.end < 0 or c.end >= w.ends.size() or w.ends[c.end] == null:
		return 0
	var count := w.ends[c.end].forward.size()
	var allowed := Respawns.forward_for(RoundState.has_sides(w.mode), w.attackers, c.team, w.tuning.rounds)
	if count == 0 or not allowed:
		return 0
	var chance := b.style.spawn_chance if b.style.has_spawn_chance else w.cfg.forward_spawn_chance
	if b.rng.randf() < chance:
		b.spawn_pick = 1 + b.rng.randi_range(0, count - 1)
	return b.spawn_pick
