class_name AmbienceBed
extends Resource
## A loop under a field's sound (the browser game's AmbienceBed): assets/audio/loops/<loop>.wav at gain (the browser's
## level; the loop is stored at its peak, so it plays at gain times the peak in loops/peaks.json), as the browser plays
## it: two copies half a loop apart (a tonal loop's second copy copy_offset s further on), one panned width to the
## left and one to the right with the browser's equal-power law (its StereoPannerNode), on SimAudio's AmbienceLeft and
## AmbienceRight buses. Each ear hears the pair at gain, as the browser's.

@export var loop: StringName = &""
@export var gain: float = 0.0
@export var width: float = 0.0
@export var copy_offset: float = 0.0


## For a pair panned `width` apart: x a copy's level (of the bed's) and y the pan of the left copy's bus (AudioEffectPanner,
## the right's is -y), so that through Godot's panner (left x(1 - pan), right x(1 + pan) of a mono voice) the left copy
## puts the browser's cos and sin of (1 - width) pi/4 into the left and right ears, and the right copy the other way.
static func pair_gains(width: float) -> Vector2:
	var w := clampf(width, 0.0, 1.0)
	var near := cos((1.0 - w) * PI * 0.25)
	var far := sin((1.0 - w) * PI * 0.25)
	return Vector2((near + far) * 0.5, -(near - far) / (near + far))


## Where in a loop `length` s long the right copy starts: half a loop on, and copy_offset more.
func second_start(length: float) -> float:
	return fposmod(length * 0.5 + copy_offset, length) if length > 0.0 else 0.0
