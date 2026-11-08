class_name FlagConfig
extends Resource
## Attack / Defend's flag (the browser game's config/modes.ts FLAG; DECISIONS 2026-10-01), after the flag games played
## at real sites: attackers raise their flag by standing at the pole, defenders at the pole pull it back down, both at
## once hold it still. Read by game/sim/flag.gd and round.gd.

## Players in play within this distance of the pole (m, flat) work the rope: an arm's reach and a step, so a crouched
## player by the pole counts.
@export var radius: float = 1.6
## ... with their feet within this height of the pole's foot (m, BP4): a player on a roof or a floor above, inside the
## radius flat, doesn't work the rope (OvertimeConfig.reach_height's rule).
@export var reach_height: float = 1.0
## Seconds for the attackers to raise the flag from the bottom to the top (BP8, owner: longer, 5 s made a raise too
## quick to answer). 7 s with a 3 s hold put Depot's attackers at 52.6 % ±4.7 (16 seeds, Normal); 7.5 s with 5 s
## held them to 35.5 %.
@export var raise_time: float = 7.0
## Once fully raised, the flag must stay up this long (s) for the attackers to win (BP8, owner: hold the flag): a
## defender on the rope pulls it off the top and the hold starts again from nothing; both teams on the rope pause it.
## 0: raised wins at once.
@export var hold_time: float = 3.0
## Seconds for the defenders to pull it from the top to the bottom: a retake needs no long stand in the open.
@export var lower_time: float = 3.0
## Time running out while the attackers work the rope (raising, or contesting it) or hold a raised flag goes on until
## they stop, for at most this long (s): long enough to finish a raise well under way and its hold.
@export var max_overtime: float = 15.0
## The rope ratchets audibly every this share of the pole (a FLAG_ROPE event).
@export var rope_step: float = 1.0 / 12.0
