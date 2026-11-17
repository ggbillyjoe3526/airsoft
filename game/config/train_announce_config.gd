class_name TrainAnnounceConfig
extends Resource
## Subway's easter egg (TA1, the owner, 2026-11-17): his own two recorded train announcements. In a match, gap_cue
## plays gap_plays_min to gap_plays_max times (a random count) to someone near a train or inside one, the first due
## first_min to first_max seconds into the match and each next one apart_min to apart_max after the last played; once_cue
## plays once, to someone standing inside a train, due once_min to once_max seconds into the match. One that comes due
## waits until someone is where it is heard, and never over the other. Timed from its own generator seeded from rng_seed
## and the match's (presentation only, never the match's stream). Read by TrainAnnouncements and SimAudio.

## The recordings (assets/audio/cues/<cue>_1.wav, tools/announce_sound.py).
@export var gap_cue: StringName = &"announce_gap"
@export var once_cue: StringName = &"announce_kings_cross"
@export var gap_plays_min: int = 2
@export var gap_plays_max: int = 3
## When the gap's first play comes due (s into the match) and the gap after each one played (s).
@export var first_min: float = 20.0
@export var first_max: float = 90.0
@export var apart_min: float = 45.0
@export var apart_max: float = 150.0
## When the one-off comes due (s into the match).
@export var once_min: float = 30.0
@export var once_max: float = 240.0
## Near a train: the feet at most this far (m) from its inside.
@export var near: float = 5.0
## Level (linear gain) on the Effects bus, from the nearest point of the train's inside (from all round you inside it),
## full out to unit_size (m) and heard to `near` plus reach (m), on its own voice so nothing cuts it short. Never
## muffled: the train's doors stand open.
@export var gain: float = 0.8
@export var unit_size: float = 4.0
@export var reach: float = 30.0
## Inside a train: the feet within its box less this much (m) at each side and end (its walls), and no more than
## floor_drop (m) under its cars' floor (not in the track bed under an uncoupled end).
@export var wall: float = 0.15
@export var floor_drop: float = 0.3
## The announcements' own seed (an arbitrary constant, as AmbienceCall.rng_seed).
@export var rng_seed: int = 0x7A1E57
