class_name SoundConfig
extends Resource
## How the rendered sounds (assets/audio/) play: each kind's level (linear gain, the browser game's config/audio.ts
## levels), pitch and level spread, how far sounds carry, the voice pools, the field's mix (out of play and the dips),
## the occlusion numbers, kit rustle and landings, the ambience and the referee's whistle. Read by SimAudio and
## SoundMix. The buses are default_bus_layout.tres: Field (the world, which SoundMix muffles and dips) and Interface
## under Master; Effects (replicas, impacts, hits) and Ambience under Field; Footsteps, Power, Muffled (a silenced shot,
## through its low-pass filter) and EffectsHalf and EffectsFull (heard through low cover or a wall) under Effects;
## PowerHalf and PowerFull under Power.

const CUE_DIR := "res://assets/audio/cues/"
const LOOP_DIR := "res://assets/audio/loops/"
const PEAKS_PATH := "res://assets/audio/loops/peaks.json"
## Variants each cue has on disk (`<cue>_1.wav` ...).
@export var variants: int = 5
## Levels and pitch spreads (± share) by kind. A shot plays with its power part (motor whir, gas pop) on top.
@export var shot_gain: float = 1.4
@export var shot_pitch: float = 0.03
## A shot's power part (the motor's whir, the gas's pop and hiss, the spring's twang) plays at its power source's gain
## in power_gains, or power_gain for one not listed. The rendered motor sits about 11 dB under its shot, the gas's 4 dB
## and the spring's 7 dB, so each is lifted to be heard over a firefight at full Power volume (owner, 2026-11-01: AU1).
@export var power_gain: float = 2.5
@export var power_gains: Dictionary[StringName, float] = {&"electric": 4.0, &"gas": 2.2, &"spring": 2.5}
@export var mechanism_gain: float = 0.8
@export var mechanism_pitch: float = 0.04
@export var step_gain: float = 0.54
@export var own_step_gain: float = 0.25
@export var step_pitch: float = 0.06
## Level spread (± dB) on each play by kind, on top of the rendered variants' own; interface cues have none.
@export var shot_spread_db: float = 1.0
@export var mechanism_spread_db: float = 1.5
@export var step_spread_db: float = 2.0
@export var vault_spread_db: float = 1.5
@export var rope_spread_db: float = 1.0
@export var impact_spread_db: float = 2.0
@export var hit_spread_db: float = 0.5
@export var steel_ring_spread_db: float = 1.0
## Kit rustle (FoleyTracker; the browser game's levels.foley and ownFoley): a crouch, a stand or a lean starting.
## Others' only within foley_reach (m) of your ears and at most foley_limit starting within foley_window (s). One
## character's lean rustles at most once in foley_lean_gap (s), yours too: a lean against a wall restarts at each turn.
@export var foley_gain: float = 0.8
@export var own_foley_gain: float = 0.45
@export var foley_pitch: float = 0.08
@export var foley_spread_db: float = 1.5
@export var foley_reach: float = 9.0
@export var foley_limit: int = 3
@export var foley_window: float = 0.15
@export var foley_lean_gap: float = 0.6
## A landing (a FOOTSTEP LAND) sounds as a step from FootstepConfig.land_min_speed (m/s down) and louder and lower the
## harder it comes down, up to land_hard_gain times the level and land_hard_pitch times the pitch at hard_land_speed
## (a hop lands at about 5.4 m/s, a drop off a 1.6 m ledge at 8), with a kit rustle at that speed or more. Your own
## landing at own_land_gain, a little over your own steps.
@export var hard_land_speed: float = 8.0
@export var land_hard_gain: float = 1.41
@export var land_hard_pitch: float = 0.85
@export var own_land_gain: float = 0.3
## A vault's hands and kit on the obstacle: louder than a step, as it carries further.
@export var vault_gain: float = 0.7
@export var own_vault_gain: float = 0.4
@export var vault_pitch: float = 0.06
## A run into a noisy prop (PROP_KNOCK, NP1): its boom, clank, rattle or knock from where it was hit, above a vault's
## level as it carries further, heard out to prop_reach (m), a little past the furthest a bot hears one (20 m).
@export var prop_gain: float = 0.85
@export var prop_pitch: float = 0.08
@export var prop_spread_db: float = 1.5
@export var prop_reach: float = 26.0
## A door opening or shutting (DOOR, DO1): its creak, latch and slam from the door, yours too, heard out to door_reach
## (m), a little past the furthest a bot hears one (DoorConfig.heard, 20 m).
@export var door_gain: float = 0.8
@export var door_reach: float = 26.0
## Smoke and flash bombs (SF1): a bomb's knock where it bounces (at the gain times its speed into the surface over
## bounce_full_speed, at most the gain) and a smoke's pop and hiss, both heard out to prop_reach; a flash's bang, heard
## out to bang_reach (m). The pin and the throw are mechanisms (mechanism_gain).
@export var bounce_gain: float = 0.7
@export var bounce_full_speed: float = 6.0
@export var smoke_pop_gain: float = 0.8
@export var bang_gain: float = 1.0
@export var bang_reach: float = 60.0
## Attack / Defend's flag rope ratcheting a notch at the pole (FLAG_ROPE), heard from the pole.
@export var rope_gain: float = 0.8
@export var rope_pitch: float = 0.04
@export var impact_gain: float = 0.9
## A BB brushing through a bush's edge and flying on (BB_LEAVES, WL5): the leaves' rustle (impact_leaves) this loud, half
## a stop in the leaves (which plays at impact_gain).
@export var leaf_brush_gain: float = 0.45
@export var impact_pitch: float = 0.1
@export var body_hit_gain: float = 1.0
@export var hit_tick_gain: float = 1.0
@export var hit_marker_gain: float = 0.55
@export var beep_gain: float = 1.9
## A teammate's radio keyed twice, in your ear only: a squad order you gave was taken (M22).
@export var radio_ack_gain: float = 0.5
@export var radio_ack_pitch: float = 0.02
## A bot's callout (CO2; the browser game's radioCall, CL1): the same radio click, no voice. A teammate's in your ear on
## the Interface bus at radio_call_gain, panned toward where they stand at radio_pan of the field's full pan (0
## centred, 1 as far as a field sound goes) on one of radio_voices; an enemy's from where they stand at
## radio_call_enemy_gain, only within enemy_radio_reach (m) of your ears and muffled through walls as their other sounds.
@export var radio_call_gain: float = 0.35
@export var radio_call_enemy_gain: float = 0.6
@export var radio_call_pitch: float = 0.04
@export var radio_pan: float = 0.6
@export var enemy_radio_reach: float = 15.0
@export var radio_voices: int = 2
## Your ping placed (PN2; the browser game's AUDIO.pingPip, PG1): one short soft pip in your ear on the Interface bus,
## lower and quieter than the shot timer so it reads as a mark, not a countdown. A plain sine at ping_pip_hz,
## ping_pip_length (s) long with the whistle's attack and release, rendered by tools/render_whistle.gd as ping_pip_1 and
## played at ping_pip_gain (the browser's volume, as whistle_gain is).
@export var ping_pip_gain: float = 0.13
@export var ping_pip_hz: float = 1700.0
@export var ping_pip_length: float = 0.08
## The practice range (M21): steel rings, a plywood figure knocks (an impact on wood), each heard target_reach (m) away,
## all the way down the range (its far corner is 74 m from the back).
@export var target_reach: float = 80.0
@export var steel_ring_gain: float = 1.4
@export var steel_ring_pitch: float = 0.03
## The timed challenge's shot timer (M93), on the countdown beep: one each second of the countdown and Go a little
## lower; Time is the referee's long blast.
@export var go_pitch: float = 0.8
## A silenced replica's shot (ReplicaConfig.muffled): duller and quieter, low-passed at this cutoff (Hz) on the Muffled
## bus and played at this share of its level (the browser game's AUDIO.suppressed). Its power part sounds as it is.
@export var muffled_cutoff_hz: float = 1400.0
@export var muffled_gain: float = 0.45
## Others' sounds are at full level within unit_size (m) and fall away out to max_distance (m), beyond which they are
## not played at all (the browser game's AUDIO.spatial.maxDistance); the range's targets carry target_reach.
@export var unit_size: float = 4.0
@export var max_distance: float = 60.0
## Others' shots and their power parts carry further (owner, 2026-11-01: bots' gunfire was lost; AU1): full level within
## shot_unit_size (m), falling away out to shot_reach (m), a silenced replica's reach scaled as the minimap hears it
## (MinimapHearing.heard_scale). Up close a shot and its power part are capped at their own level or field_max_db,
## the louder (AudioStreamPlayer3D.max_db), so a bot's lifted motor beside you sounds as loud as yours and nothing
## shot-kind is quieter up close than before; every other sound of another's is capped at field_max_db (Godot's
## default).
@export var shot_unit_size: float = 10.0
@export var shot_reach: float = 120.0
@export var field_max_db: float = 3.0
## Others' footsteps (and magazine rattle) only within step_reach (m) of your ears, about as far as bots hear a sprint,
## and at most step_limit of them start within step_window (s): six sprinters stay readable (AUDIO.footsteps).
@export var step_reach: float = 22.0
@export var step_limit: int = 4
@export var step_window: float = 0.1
## At most impact_limit BB impacts on the field start within impact_window (s): a hose of BBs stays readable.
@export var impact_limit: int = 8
@export var impact_window: float = 0.1
## Voices made once at setup (VoicePool): positional ones for the field's sounds, plain ones for your own and the
## interface. One cue sounds on at most cue_voices at once (a shot on shot_cue_voices) before its oldest is reused.
@export var field_voices: int = 24
@export var own_voices: int = 8
@export var cue_voices: int = 4
@export var shot_cue_voices: int = 6
## While the character you play is out of play the field (Effects and Ambience, never the interface) is heard as from
## the side line: low-passed to out_hz and turned to out_gain (linear), easing over out_ease (s, a time constant).
@export var out_hz: float = 900.0
@export var out_gain: float = 0.5
@export var out_ease: float = 0.15
## Dips: a cue that must be read lowers the field to the depth (linear) within about the attack (s, a time constant),
## holds it for the hold (s), then lets it back over the release (s). Your own hit dips deepest; the referee's whistle
## (a round's end, the match's end, the range's Time) gentler. Overlapping dips keep the deeper depth and the later end.
@export var hit_dip_depth: float = 0.4
@export var hit_dip_attack: float = 0.008
@export var hit_dip_hold: float = 0.25
@export var hit_dip_release: float = 0.1
@export var whistle_dip_depth: float = 0.6
@export var whistle_dip_attack: float = 0.03
@export var whistle_dip_hold: float = 0.6
@export var whistle_dip_release: float = 0.15
## A flash dazzling you (SF1) dulls the field the same way, held for flash_dip_hold of the dazzle's seconds.
@export var flash_dip_depth: float = 0.3
@export var flash_dip_attack: float = 0.01
@export var flash_dip_hold: float = 0.6
@export var flash_dip_release: float = 0.8
## Muffling through walls (SP2; the browser game's AUDIO.occlusion): rays from your ears to a character's feet raised by
## each of the ray heights (m: knees and head); the blocked share glides a low-pass from occlusion_open_hz to
## occlusion_muffled_hz on a log scale and the level from 1 to occlusion_muffled_gain. The half and full buses sit at
## shares 0.5 and 1. A BB impact casts one ray to occlusion_impact_back (m) back along the BB's way in from where it
## struck, on its own side of the surface however thin the wall (BP2), or, with no way in known, stopping
## occlusion_surface_gap (m) short of it. No ray beyond occlusion_reach (m): the last share closes to full over
## occlusion_far_ramp (m) more, in occlusion_far_step (m) steps. A character's share is reused for
## occlusion_refresh_ticks; a tick casts at most occlusion_ray_budget rays.
@export var occlusion_ray_heights: PackedFloat32Array = PackedFloat32Array([0.45, 1.5])
@export var occlusion_open_hz: float = 18000.0
@export var occlusion_muffled_hz: float = 700.0
@export var occlusion_muffled_gain: float = 0.55
@export var occlusion_surface_gap: float = 0.2
@export var occlusion_impact_back: float = 0.05
@export var occlusion_reach: float = 60.0
@export var occlusion_far_ramp: float = 60.0
@export var occlusion_far_step: float = 5.0
@export var occlusion_refresh_ticks: int = 6
@export var occlusion_ray_budget: int = 24
## Every field's beds and calls by day and by night (the browser game's AMBIENCES), picked by the map's `ambience`: the
## beds on the Ambience bus at their gain times the loop's stored peak (assets/audio/README.md), the calls round the
## listener on the Ambience bus at the field pool's lowest priority. Every bed and call plays at ambience_gain times its
## own level, under the Ambience volume (owner, 2026-11-01: too loud and distracting; AU1).
@export var ambiences: AmbienceConfig = AmbienceConfig.new()
@export var ambience_gain: float = 0.5
## The referee's pea whistle (the browser game's whistle.ts), rendered by tools/render_whistle.gd as whistle_short and
## whistle_long, whistle_variants of each with the warble's phase moved round its cycle, and played at whistle_gain on
## the Interface bus. A sine at whistle_hz whose pitch warbles at whistle_warble_hz by whistle_warble_depth (a share of
## the pitch: the pea rattling), fading in over whistle_attack (s) and out over the last whistle_release (s).
@export var whistle_gain: float = 0.25
@export var whistle_hz: float = 2900.0
@export var whistle_warble_hz: float = 28.0
@export var whistle_warble_depth: float = 0.04
@export var whistle_attack: float = 0.02
@export var whistle_release: float = 0.05
@export var whistle_variants: int = 3
## A short blast (s; a round's start) and a long one (s; a round's end, the match's end, the range's Time).
@export var whistle_short: float = 0.14
@export var whistle_long: float = 0.8
## The blasts: a round starts on round_start_blasts short ones, each starting round_start_gap blast-lengths after the
## one before; a round ends on one long; the match ends on match_over_blasts more long ones after it, each
## match_over_gap blast-lengths on from the one before.
@export var round_start_blasts: int = 2
@export var round_start_gap: float = 1.6
@export var match_over_blasts: int = 3
@export var match_over_gap: float = 1.3
## Elimination's overtime flag going up (the browser game's overtimeWhistle): overtime_blasts short blasts, each
## starting overtime_gap blast-lengths after the one before.
@export var overtime_blasts: int = 3
@export var overtime_gap: float = 1.5


## When round start blast `i` (0-based, of round_start_blasts; each whistle_short long) starts, in seconds after the
## first.
func round_start_blast(i: int) -> float:
	return whistle_short * round_start_gap * i


## When overtime blast `i` (0-based, of overtime_blasts; each whistle_short long) starts, in seconds after the first.
func overtime_blast(i: int) -> float:
	return whistle_short * overtime_gap * i


## When extra match-over blast `i` (0-based, of match_over_blasts; each whistle_long long) starts, in seconds after the
## round's end blast (the browser game's matchOverBlastStart).
func match_over_blast(i: int) -> float:
	return whistle_long * match_over_gap * (i + 1)
