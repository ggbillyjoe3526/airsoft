class_name BotRadio
## The bots' team radio (BQ3): a bot that sees an enemy afresh tells its teammates where after its skill's share_delay,
## as a teammate's call heard exactly there. A teammate within the skill's share_radius of the spot takes it as it takes
## a noise (BotBrain: goes after it, or watches it from its post or under an order); one fighting, already seeing
## someone, out of play or with fresher news of its own keeps its own. Allocates nothing.


## `b` has just seen `enemy` afresh (BotSenses.perceive): with a radio (share_radius above zero) and nothing it is
## about to tell, it tells its teammates after its share_delay.
static func saw(b: Bot, w: BotWorld, enemy: Character) -> void:
	if b.skill.share_radius <= 0.0 or b.share_id >= 0:
		return
	b.share_id = enemy.id
	b.share_spot = enemy.position
	b.share_at = w.time + b.pick(b.skill.share_delay)


## Before the bots think: each call due is told (tell), from where the caller sees the enemy now if it still does, else
## where it saw them.
static func step(w: BotWorld) -> void:
	for b in w.bots:
		if b.share_id < 0 or w.time < b.share_at:
			continue
		if Elimination.is_in_play(b.character) and w.live:
			var spot := b.last_known if b.target_id == b.share_id and b.target_visible else b.share_spot
			tell(b, w, spot)
		b.share_id = -1
		b.share_at = INF


## `b` tells its teammates in play within its share_radius of `spot` that an enemy is there.
static func tell(b: Bot, w: BotWorld, spot: Vector3) -> void:
	var cfg := w.cfg
	var reach_sq := b.skill.share_radius * b.skill.share_radius
	for m in w.bots:
		if m == b or m.character.team != b.character.team or m.target_visible or m.mode == Bot.Mode.FIGHT \
				or not Elimination.is_in_play(m.character):
			continue
		var p := m.character.position
		if Vector2(spot.x - p.x, spot.z - p.z).length_squared() > reach_sq:
			continue
		if m.has_last_known and w.time - maxf(m.last_seen_at(), m.heard_at) < cfg.hearing_contact_time:
			continue
		m.last_known = spot
		m.has_last_known = true
		m.heard_at = w.time
		m.last_threat_at = w.time
