class_name HudPlant
extends RefCounted
## What Plant The Bomb (PB1) shows, as plain rules the HUD's nodes only draw (tests read them without a screen): which
## prompt the player gets under the crosshair, what the gauge under the score bar reads, and what the marker points at
## and calls it. Reads RoundState.plant and the characters; allocates nothing.

## The prompt for the player: Use does something now. PICK_UP: an attacker beside the bomb on the ground. PLANT: the
## carrier inside a site, not yet arming. DEFUSE: a defender beside the armed bomb, not yet on it.
enum Prompt { NONE, PICK_UP, PLANT, DEFUSE }
## The gauge's state: hidden, the bomb being armed, the armed bomb being disarmed, or armed with nobody on it.
enum Gauge { NONE, PLANTING, DEFUSING, ARMED }
## What the marker points at. BOMB: the bomb on the ground ("BOMB"). SITE: a site ("SITE A"). BOMB_AT: the armed bomb
## ("BOMB A"). NONE: hidden.
enum Aim { NONE, BOMB, SITE, BOMB_AT }


## Whether `rs` is a live Plant The Bomb round (the countdown over).
static func live(rs: RoundState) -> bool:
	return rs.mode == RoundState.Mode.PLANT_THE_BOMB and rs.attackers >= 0 and rs.is_live()


## The prompt `player` gets this tick, through their own eyes (the caller leaves it out while spectating).
static func prompt(rs: RoundState, player: Character, cfg: PlantConfig) -> Prompt:
	if not live(rs) or not Elimination.is_in_play(player):
		return Prompt.NONE
	var ps := rs.plant
	match ps.status:
		PlantState.Status.DOWN:
			if player.team == rs.attackers and Plant.in_reach(ps, player, cfg.pickup_reach, cfg):
				return Prompt.PICK_UP
		PlantState.Status.CARRIED:
			if ps.carrier == player.id and ps.planter != player.id and Plant.site_at(ps, player.position, cfg) >= 0:
				return Prompt.PLANT
		PlantState.Status.PLANTED:
			if player.team != rs.attackers and ps.defuser != player.id \
					and Plant.in_reach(ps, player, cfg.defuse_reach, cfg):
				return Prompt.DEFUSE
	return Prompt.NONE


## Whether `player` carries the bomb now (the quiet line "You have the bomb"), not while setting it down (PB3: the
## PLANTING gauge says what is going on then).
static func carrying(rs: RoundState, player: Character) -> bool:
	return live(rs) and rs.plant.status == PlantState.Status.CARRIED and rs.plant.carrier == player.id \
			and rs.plant.planter != player.id and Elimination.is_in_play(player)


## Plant The Bomb's bomb on the weapon rail of `c` (PB3, the owner's ask): carried, being set down and armed, or none.
static func rail_carry(rs: RoundState, c: Character) -> WeaponRail.Carry:
	if rs.mode != RoundState.Mode.PLANT_THE_BOMB or rs.plant.status != PlantState.Status.CARRIED \
			or rs.plant.carrier != c.id:
		return WeaponRail.Carry.NONE
	return WeaponRail.Carry.SETTING if rs.plant.planter == c.id else WeaponRail.Carry.CARRIED


## What the gauge reads: the bomb being armed (status CARRIED, a planter on it), being disarmed (PLANTED, a defuser on
## it), or armed with nobody on it; hidden otherwise.
static func gauge(rs: RoundState) -> Gauge:
	if rs.mode != RoundState.Mode.PLANT_THE_BOMB or not rs.under_way():
		return Gauge.NONE
	var ps := rs.plant
	if ps.status == PlantState.Status.CARRIED and ps.planter >= 0:
		return Gauge.PLANTING
	if ps.status == PlantState.Status.PLANTED:
		return Gauge.DEFUSING if ps.defuser >= 0 else Gauge.ARMED
	return Gauge.NONE


## How full the gauge is (0..1) in state `g`: the arming, or the disarming (an armed bomb left alone keeps its
## checkpoint).
static func gauge_fill(rs: RoundState, g: Gauge) -> float:
	match g:
		Gauge.PLANTING:
			return clampf(rs.plant.planting, 0.0, 1.0)
		Gauge.DEFUSING, Gauge.ARMED:
			return clampf(rs.plant.defusing, 0.0, 1.0)
	return 0.0


## The team whose colour fills the gauge in state `g`: the attackers' while arming, the defenders' otherwise.
static func gauge_team(rs: RoundState, g: Gauge) -> int:
	return rs.attackers if g == Gauge.PLANTING else 1 - rs.attackers


## What the marker points at for `watched`'s team. Hidden unless the round is under way (the countdown shows it too).
## DOWN: the attackers see the bomb, the defenders a site. CARRIED: a site. PLANTED: the bomb, for both.
static func aim(rs: RoundState, watched: Character, planned_site: int) -> Aim:
	if rs.mode != RoundState.Mode.PLANT_THE_BOMB or rs.attackers < 0 or not rs.under_way():
		return Aim.NONE
	match rs.plant.status:
		PlantState.Status.DOWN:
			if watched.team == rs.attackers:
				return Aim.BOMB
			return Aim.SITE if aim_site(rs, watched, planned_site) >= 0 else Aim.NONE
		PlantState.Status.CARRIED:
			return Aim.SITE if aim_site(rs, watched, planned_site) >= 0 else Aim.NONE
		PlantState.Status.PLANTED:
			return Aim.BOMB_AT
	return Aim.NONE


## The site the marker names: the armed bomb's; else, for an attacker looking at a teammate's carry, the site the bots
## head for (`planned_site`, -1 or out of range: the nearest); else the site nearest `watched`. -1 for none.
static func aim_site(rs: RoundState, watched: Character, planned_site: int) -> int:
	var ps := rs.plant
	if ps.status == PlantState.Status.PLANTED:
		return ps.site
	if ps.status == PlantState.Status.CARRIED and ps.carrier != watched.id and watched.team == rs.attackers \
			and planned_site >= 0 and planned_site < ps.sites.size():
		return planned_site
	return Plant.nearest_site(ps, watched.position)


## Where the marker sits for `a` (aim, with `site` from aim_site): over the bomb, or over the site's middle.
static func aim_spot(rs: RoundState, a: Aim, site: int) -> Vector3:
	if a == Aim.SITE and site >= 0 and site < rs.plant.sites.size():
		return rs.plant.sites[site]
	return rs.plant.position


## The marker's words for `a` at `site` ("BOMB", "SITE A", "BOMB A"), in caps.
static func aim_title(a: Aim, site: int) -> String:
	var letter: String = Plant.LETTERS[clampi(site, 0, Plant.MOST - 1)]
	match a:
		Aim.SITE:
			return (TranslationServer.translate(&"HUD_SITE_NAMED") % letter).to_upper()
		Aim.BOMB_AT:
			return (TranslationServer.translate(&"HUD_BOMB_NAMED") % letter).to_upper()
	return HudStyle.caps("HUD_BOMB_MARKER")


## The words after the actor's name in the feed's note for the PLANT event `e` ("picked up the bomb", "planted the bomb
## at A"), as `you` see it, or "" for none: a pick-up and a drop show to your team when you attack, the plant and the
## defuse to everyone; the arming, the beeps and the rest are not news. `actor` is who did it.
static func feed_words(rs: RoundState, e: GameEvent, actor: Character, you: Character) -> String:
	if actor == null:
		return ""
	var mine := actor.team == you.team and you.team == rs.attackers
	match e.value:
		Plant.Cue.PICKED_UP:
			return TranslationServer.translate(&"HUD_BOMB_FEED_PICKED_UP") if mine else ""
		Plant.Cue.DROPPED:
			return TranslationServer.translate(&"HUD_BOMB_FEED_DROPPED") if mine else ""
		Plant.Cue.PLANTED:
			var letter: String = Plant.LETTERS[clampi(e.value2, 0, Plant.MOST - 1)]
			return TranslationServer.translate(&"HUD_BOMB_FEED_PLANTED") % letter
		Plant.Cue.DEFUSED:
			return TranslationServer.translate(&"HUD_BOMB_FEED_DEFUSED")
	return ""
