class_name GameEvent
extends RefCounted
## One thing that happened during a tick, for sound, HUD and effects (docs/ARCHITECTURE.md › Contracts 3). The
## simulation never reads events back. Events are pooled (SimEvents): read them during the tick's presentation, never
## keep one.

enum Kind {
	SHOT, ## actor fired a BB from slot at position, along direction.
	DRY_FIRE, ## actor pulled the trigger on an empty magazine (slot).
	RELOAD_START, ## actor started swapping magazines (slot).
	RELOAD_END, ## actor's fresh magazine is in (slot).
	RELOAD_REFUSED, ## actor pressed reload with no spare fuller than the loaded magazine (slot).
	DRAW, ## actor started bringing up the replica in slot.
	FIRE_MODE, ## actor's selector on slot moved to value (ReplicaConfig.FireMode).
	BB_IMPACT, ## actor's BB stopped at position: on the level (target -1, value2 the RayHit.Surface; direction its velocity as it landed), in a bush's leaves (target -1, value BBStep.IN_LEAVES; direction its unit path, reach the leaves it crossed) or a body not knocked out.
	BB_LOST, ## actor's BB fell out of the level or flew past its lifetime at position.
	CHARACTER_HIT, ## actor's BB hit target at position, flying along direction: target is out and calls the hit.
	FOOTSTEP, ## actor's footstep (value: Footstep) on surface (value2: RayHit.Surface), carrying carry × as far; LAND: direction, down at its speed.
	VAULT, ## actor started a vault at position: hands and boots on the obstacle, loud (bots hear it far).
	ROUND_START, ## round number value is live.
	ROUND_OVER, ## value won the round (-1: a draw), for reason.
	MATCH_OVER, ## value won the match.
	RICOCHET_TICK, ## actor's bounced BB reached target at position along direction, but ricochets don't count: a tick.
	HOP_UP, ## actor turned the hop-up dial on slot to value (hundredths of its range); value2 0 if it was already at an end.
	HOLSTER, ## actor put the replica in slot away.
	FLAG_ROPE, ## Attack / Defend's flag passed a rope step at position (the pole), value 1 going up, 0 coming down.
	TARGET_HIT, ## actor's BB hit range target at position along direction; value: its RangeTarget.Kind; value2 1: bounced.
	CHALLENGE, ## the timed challenge's cue value (RangeChallenge.Cue) for actor (the player); value2: a count's seconds left.
	SQUAD_ORDER, ## actor (in play, the round live) gave squad order value (SquadOrder.Kind); value2 1: from the order wheel.
	SQUAD_ORDER_REFUSED, ## actor's squad order value came while it was out or between rounds; value2 1: from the wheel.
	PROP_KNOCK, ## actor ran into noisy prop target (WorldQuery block index) at position: value its NoiseConfig.Sound, value2 its RayHit.Surface, heard out to reach.
	PROP_RING, ## actor's BB rang noisy prop target at position, landing hard on steel: value its NoiseConfig.Sound, heard faintly out to reach.
	BB_LEAVES, ## actor's BB came out of a bush's edge at position, flying along direction (before the leaves turned it), and flies on.
	TORCH, ## actor switched the weapon torch on the replica in slot on (value 1) or off (value 0); off too as the replica goes away.
	OVERTIME, ## Elimination's clock ran out with both teams in play: the overtime flag is up at position (its foot).
	PING, ## actor (in play, the round live) pinged along direction (unit) from its eyes at position: value 1 where its view met the field reach m off (within PingConfig.reach), value 0 for nothing there (the sky); value 2 (FM1) placed on the full-screen map at position; value2 1 for a Go there.
	MAG_ASK, ## actor (low on BBs for the replica in slot) asked teammate target for a magazine, standing at position (MagShare).
	MAG_TOSS, ## actor tossed target a magazine of value BBs from its slot value2, for target's slot, from its hand at position, reach m to target's chest.
	MAG_CATCH, ## target caught actor's magazine at position (its chest): value BBs went into its spares of slot; value2 the thrower's slot.
	MAG_LOST, ## actor's magazine to target fell at position with its value BBs: target out of play, or the round decided; slot, value2 as MAG_CATCH.
	MAG_REFUSED, ## actor's hand-off press did nothing: value the MagShare.Refusal, target the teammate it concerns (-1: none).
	GRENADE_PIN, ## actor (standing at position) pulled the pin of a bomb of kind value (Grenade.Kind): its replica goes down for the throw.
	GRENADE_THROW, ## actor threw bomb target (its GameState.grenades slot) of kind value from its eyes at position, flying at direction (m/s).
	GRENADE_BOUNCE, ## actor's bomb target (kind value) struck the level at position on value2 (RayHit.Surface), reach m/s into it.
	SMOKE_POP, ## actor's smoke bomb target popped at position: its cloud grows from there.
	FLASH_BANG, ## actor's flash bomb went bang at position.
	DAZZLED, ## actor's flash at position dazzled target for reach s; value its strength in hundredths.
	DOOR, ## actor toggled door target (WorldQuery's order) at position (its leaf's middle): value 1 shutting, 0 opening; heard out to reach through walls (Doors, DO1).
}

## RATTLE: a rattling magazine (ReplicaConfig.rattles) while walking or moving crouched, otherwise silent.
enum Footstep { RUN, SPRINT, LAND, RATTLE }
## CAPTURED: Attack / Defend's flag raised (the attackers win). OVERTIME_FLAG: Elimination's overtime flag touched
## (the toucher's team wins).
enum RoundEnd { ELIMINATED, TIME, CAPTURED, OVERTIME_FLAG }
## A PING's value for one placed on the full-screen map (FM1).
const PING_ON_MAP := 2

var kind: Kind = Kind.SHOT
## Who did it: the shooter, the BB's owner, the stepper. -1 for none (round events).
var actor: int = -1
## Who it happened to: the character hit, the body a BB stopped on, the range target hit. -1 for none.
var target: int = -1
## The loadout slot of the replica involved, or -1.
var slot: int = -1
## The event's number: a fire mode, a winner, a round, a footstep kind, a range target's kind, a squad order.
var value: int = 0
## A second number: a footstep's or an impact's surface, a round's end reason.
var value2: int = 0
var position: Vector3 = Vector3.ZERO
## Which way: a shot's or a hit's flight; a landing's fall, its length the touchdown speed (m/s).
var direction: Vector3 = Vector3.ZERO
## How far a footstep carries as a share of its kind's usual reach (NoiseConfig.ground: run, sprint and landing steps on
## gravel and steel plate 1.35; anything else 1).
var carry: float = 1.0
## How far a prop's knock or ring is heard (m); how far off a ping's view met the field (m).
var reach: float = 0.0


func reset(new_kind: Kind) -> void:
	kind = new_kind
	actor = -1
	target = -1
	slot = -1
	value = 0
	value2 = 0
	position = Vector3.ZERO
	direction = Vector3.ZERO
	carry = 1.0
	reach = 0.0
