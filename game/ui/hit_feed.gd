class_name HitFeed
extends RefCounted
## The hit feed's lines (the browser game's HIT_FEED): who fired, who was hit and called it, and when (simulation time),
## newest first. A line lasts `line_time`, fading over its last `fade_time`, unless it is kept (the line you were hit
## in stays up until the round ends: `release_kept`), or all hits stay when `stay` (the HUD tab's Keep: the newest
## `max_lines` hits, for the whole match). Your team's callouts share it (CO2): a call line is the speaker and the
## words, with a hit line's time and fade, but never kept, so on Keep the hits stay and the calls still go. At most
## `max_lines` lines are held, the oldest not kept going first; on Keep, `max_lines` hits and up to `max_lines` calls
## beside them, so a call never pushes a hit out: the newest `max_lines` lines show (`shown`) and a hit a call moved
## past them is hidden until the call ages out. Plain data: the HUD draws it (HudFeed). The lines are made once (room
## for both on Keep) and reused.

class Line:
	## The shooter, or a call's speaker.
	var shooter: int = -1
	var victim: int = -1
	var time: float = 0.0
	var keep: bool = false
	## A callout (`words` its line as said) rather than a hit.
	var call: bool = false
	var words: String = ""
	## A note of the bomb (Plant The Bomb, PB1: "Rook planted the bomb at A"): a call's line, drawn with the bomb's sign.
	var note: bool = false


var max_lines: int = 6
var line_time: float = 6.0
var fade_time: float = 1.0
## Every line stays (never ages out or fades) until it is pushed off or the feed is cleared.
var stay: bool = false
## Bumped whenever the lines change (one added or one gone), so the HUD rebuilds rows only then.
var version: int = 0

var _lines: Array[Line] = []
var _count: int = 0


func setup(lines: int, show_for: float, fade_for: float) -> void:
	max_lines = maxi(1, lines)
	line_time = show_for
	fade_time = clampf(fade_for, 0.0, show_for)
	_lines.clear()
	# Room for max_lines hits and max_lines calls, so Keep can hold both (stay may be set after setup).
	for i in max_lines * 2:
		_lines.append(Line.new())
	_count = 0
	version += 1


## A hit: `shooter`'s BB hit `victim`, who called it, at simulation time `at`; `kept` lines stay up until
## release_kept. When full the oldest line not kept goes (on Keep, the oldest hit not kept: never a call's place).
func add(shooter: int, victim: int, at: float, kept: bool = false) -> void:
	_make_room(false)
	var line := _front()
	line.shooter = shooter
	line.victim = victim
	line.time = at
	line.keep = kept
	line.call = false
	line.words = ""
	line.note = false


## A teammate's callout: `speaker` said `words` at simulation time `at`, the newest line, so it always shows. It ages
## and fades as a hit line, even on Keep, where it takes the place of the oldest call once max_lines calls are held and
## never a hit's: the hits it moves past the newest max_lines are hidden, not dropped.
func add_call(speaker: int, words: String, at: float, note: bool = false) -> void:
	_make_room(true)
	var line := _front()
	line.shooter = speaker
	line.victim = -1
	line.time = at
	line.keep = false
	line.call = true
	line.words = words
	line.note = note


## A note of the bomb (Plant The Bomb, PB1): `actor` did `words` ("planted the bomb at A") at simulation time `at`. A
## call's line in every way (the newest, aging and fading, gone with the round's calls) drawn with the bomb's sign.
func add_note(actor: int, words: String, at: float) -> void:
	add_call(actor, words, at, true)


## How many lines show: the newest max_lines (on Keep the feed may hold more, hits a call moved past them).
func shown() -> int:
	return mini(_count, max_lines)


## Frees a place for a new line, a call's (`call`) or a hit's: on Keep, once max_lines of its kind are held, the oldest
## of its kind not kept goes; otherwise, once max_lines lines are held, the oldest line not kept goes (the newest when
## every line is kept).
func _make_room(call: bool) -> void:
	if stay:
		var held := 0
		for i in _count:
			if _lines[i].call == call:
				held += 1
		if held < max_lines:
			return
		var oldest := _count - 1
		while oldest >= 0 and (_lines[oldest].call != call or _lines[oldest].keep):
			oldest -= 1
		if oldest < 0: # every hit kept: the oldest of its kind goes
			oldest = _count - 1
			while _lines[oldest].call != call:
				oldest -= 1
		_remove(oldest)
		return
	while _count >= max_lines:
		var oldest := _count - 1
		while oldest > 0 and _lines[oldest].keep:
			oldest -= 1
		_remove(oldest)


## Takes line `i` out, the lines after it moving up; its place goes back to the free ones.
func _remove(i: int) -> void:
	var line := _lines[i]
	for k in range(i, _count - 1):
		_lines[k] = _lines[k + 1]
	_count -= 1
	_lines[_count] = line
	version += 1


## Drops every call line (a new round, or Settings › HUD › Callouts switched off); the hits keep their order.
func drop_calls() -> void:
	var left := 0
	for i in _count:
		var line := _lines[i]
		if not line.call:
			_lines[i] = _lines[left]
			_lines[left] = line
			left += 1
	if left != _count:
		_count = left
		version += 1


## The first free line, moved to the front as the newest (_make_room has made sure there is one).
func _front() -> Line:
	var line := _lines[_count]
	for i in range(_count, 0, -1):
		_lines[i] = _lines[i - 1]
	_lines[0] = line
	_count += 1
	version += 1
	return line


## Drops the lines older than line_time at `now`, but not the kept ones (nor, on Keep, the hits); the rest keep their
## order.
func prune(now: float) -> void:
	var left := 0
	for i in _count:
		var line := _lines[i]
		if line.keep or (stay and not line.call) or now - line.time < line_time:
			_lines[i] = _lines[left]
			_lines[left] = line
			left += 1
	if left != _count:
		_count = left
		version += 1


## Lets the kept lines go (the round ended): they age out as any other.
func release_kept() -> void:
	for i in _count:
		if _lines[i].keep:
			_lines[i].keep = false
			version += 1


func clear() -> void:
	if _count > 0:
		_count = 0
		version += 1


## How many lines are held (on Keep more than show: `shown`).
func count() -> int:
	return _count


## The `i`th line, 0 the newest.
func line(i: int) -> Line:
	return _lines[i]


## How opaque the `i`th line is at `now`: 1 until its last fade_time, then down to 0.
func alpha(i: int, now: float) -> float:
	if _lines[i].keep or (stay and not _lines[i].call):
		return 1.0
	var left := line_time - (now - _lines[i].time)
	if fade_time <= 0.0 or left >= fade_time:
		return 1.0
	return clampf(left / fade_time, 0.0, 1.0)
