class_name Torch
extends RefCounted
## The weapon torch (the browser game's sim/torch.ts, M33h; WL7): a light fitted to a replica (Armament.lights), switched
## on and off through the command (PlayerCommand.toggle_torch) like any other control, so the player and the bots work
## it the same way. It lights only the replica in hand: holstered, or switched to a replica without one, it goes out;
## hit, it goes out with the hand going up; each round starts with it off (Character.respawn). A light is fitted only
## on a field played at night (Kit.lights_for): by day nothing here ever switches. What a lit torch shows the bots is
## NightField's; what it looks like, TorchBeams' and FirstPersonView's. Allocates only the event of a switch.


## One fitted light: its pool Key and data/stats.md's Lights row.
class Light:
	extends RefCounted
	var key: StringName = &""
	## How far its beam lights someone well enough to be made out (m), its hotspot's and its spill's full angles (deg).
	var reach: float = 0.0
	var beam_deg: float = 0.0
	var spill_deg: float = 0.0

	static func of(light_key: StringName, row: PartStats.Part) -> Light:
		var l := Light.new()
		l.key = light_key
		l.reach = row.reach
		l.beam_deg = row.beam
		l.spill_deg = row.spill
		return l


## The light on the replica in `c`'s hand, or null (none fitted, or holstered).
static func in_hand(c: Character) -> Light:
	return c.armament.light_in_hand()


## Whether `c`'s torch is lit now: switched on, on the replica in hand, and in play.
static func lit(c: Character) -> bool:
	return c.torch_on and Elimination.is_in_play(c) and c.armament.light_in_hand() != null


## One tick of `c`'s torch, in play, after its armament (a switch or holster this tick counts): `toggle` (the command's
## press) switches it, with a TORCH event, only while a light is in hand; with none in hand a lit torch goes out (also
## an event: the thumb's click as the replica goes away). `relight` (a throw ended, or a bomb went back, with the torch
## on before it: Grenades.take_torch_back) puts it back on when a light is in hand again, silently and without counting
## as a switch (as the throw always did; a bot's torch held its minimum hold through it).
## `c.torch_time` counts the seconds since the last switch.
static func step(c: Character, toggle: bool, events: SimEvents, dt: float, relight: bool = false) -> void:
	c.torch_time += dt
	if c.armament.light_in_hand() == null:
		if c.torch_on:
			_switch(c, false, events)
		return
	if relight:
		c.torch_on = true
	if toggle:
		_switch(c, not c.torch_on, events)


## Out at once and silently (a hit: the hand goes up).
static func put_out(c: Character) -> void:
	c.torch_on = false


static func _switch(c: Character, on: bool, events: SimEvents) -> void:
	c.torch_on = on
	c.torch_time = 0.0
	var e := events.add(GameEvent.Kind.TORCH)
	e.actor = c.id
	e.slot = c.armament.active
	e.value = 1 if on else 0
