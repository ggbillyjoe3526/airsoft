class_name RoundHold
extends RefCounted
## A test's way past the round's start countdown (BP8): a PlaySession starts a round held for its 3 s, and what is played
## (the clock text of an overtime, the round being live, bots acting) waits for it. A test about a live round calls
## this once. (Not the player's skip of a round they are out of: that is PlaySession.start_skip.)


## Ends the start countdown of `state`'s round at once, as the sim does at GO: the round is live from now on.
static func release(state: GameState) -> void:
	Round.end_countdown(state.round_state, state.events)
