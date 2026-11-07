class_name VoicePool
extends RefCounted
## A fixed set of voices shared by every cue (katanashotgun's voice_pool.gd), made once at setup so a busy moment never
## makes a player. A play picks its voice:
## 1. a cue already at its max voices reuses its own oldest;
## 2. else a free voice;
## 3. else the oldest of the lowest priority no higher than its own (stolen);
## 4. else it is dropped (counted).
## Ages are the order voices were taken in. `players` are anything with `playing` (AudioStreamPlayer or
## AudioStreamPlayer3D; a stand-in in the tests).

## Who may take whose voice: interface cues and your own sounds over others' shots and hits, over their steps,
## mechanisms and impacts, over the field's ambience calls.
enum Priority { CALL, FIELD, SHOT, OWN }

var players: Array = []
## Voices taken from a playing cue of the same or a lower priority.
var stolen: int = 0
## Plays skipped because every voice was busy with something more important.
var dropped: int = 0
var _cue: Array[StringName] = []
var _prio: PackedInt32Array = PackedInt32Array()
var _started: PackedInt64Array = PackedInt64Array()
var _serial: int = 0


func _init(voices: Array) -> void:
	players = voices
	_cue.resize(voices.size())
	_prio.resize(voices.size())
	_started.resize(voices.size())


## The index of the voice to play `cue` on at `priority`, with at most `max_voices` of it at once; -1 drops the play.
func acquire(cue: StringName, priority: int, max_voices: int) -> int:
	var own := -1
	var own_count := 0
	var free := -1
	for i in players.size():
		if not players[i].playing:
			if free < 0:
				free = i
			continue
		if _cue[i] == cue:
			own_count += 1
			if own < 0 or _started[i] < _started[own]:
				own = i
	var pick := -1
	if own_count >= max_voices:
		if own < 0: # a cue allowed no voices at all
			dropped += 1
			return -1
		pick = own
	elif free >= 0:
		pick = free
	else:
		for i in players.size():
			if _prio[i] > priority:
				continue
			if pick < 0 or _prio[i] < _prio[pick] or (_prio[i] == _prio[pick] and _started[i] < _started[pick]):
				pick = i
		if pick < 0:
			dropped += 1
			return -1
		stolen += 1
	_serial += 1
	_cue[pick] = cue
	_prio[pick] = priority
	_started[pick] = _serial
	return pick


## The play number voice `i` took for its last cue (acquire's order; 0: never taken), so a caller that kept it can tell
## whether that voice still holds its own play.
func serial_of(i: int) -> int:
	return _started[i] if i >= 0 and i < _started.size() else -1


## The serial of the play acquire last handed out.
func last_serial() -> int:
	return _serial


## At most `max` starts of one kind of sound within `window` seconds (the browser game's VoiceLimit), so a busy moment
## stays readable: six sprinters, a hose of BBs.
class StartLimit:
	extends RefCounted

	var max: int = 0
	var window: float = 0.0
	var _start: float = -INF
	var _count: int = 0

	func _init(most: int, seconds: float) -> void:
		max = most
		window = seconds

	## Whether a sound may start at `now` (s), counting it if so.
	func take(now: float) -> bool:
		if now - _start > window:
			_start = now
			_count = 0
		if _count >= max:
			return false
		_count += 1
		return true
