class_name HudCountdown
extends HudBanner
## The round's start countdown (BP8): a plate under the round banner showing 3, 2, 1, then "GO!" for a moment. It holds
## its own timer, so the HUD only passes it the sim's events and the frame's time. Shown only while a round is held or
## in its "GO!"; a round that has none (the range, a custom rule of 0 s) never shows it.

## Seconds of "GO!" left (0: not showing it).
var _go_left: float = 0.0


## A digit of the countdown: `number` shows.
func count(number: int) -> void:
	show_text(str(number), "")
	_go_left = 0.0


## The countdown ended: "GO!" for `seconds`, but only if a countdown was showing (a round that had none just starts).
func go(text: String, seconds: float) -> void:
	if not visible:
		return
	show_text(text, "")
	_go_left = seconds


## Gone at once: the round started afresh or is over.
func end() -> void:
	visible = false
	_go_left = 0.0


## Time passing: "GO!" goes when its moment is up.
func tick(delta: float) -> void:
	if _go_left > 0.0:
		_go_left -= delta
		if _go_left <= 0.0:
			visible = false
