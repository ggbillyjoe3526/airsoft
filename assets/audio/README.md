# Sounds

**The owner's recordings** (AU2, 2026-11-03) replace most of the cues: `tools/cut_recordings.py` cuts William's 36
recordings (the originals in the shared project files, `audio/william/raw/`) into every replica's shots, power parts,
dry clicks and magazines, the gas pistol's slide lock (`slideLock_gas`), the Sniper Rifle's cocking (`boltCycle`, the
pistol's slide timed to the Fire clip), BBs on metal, wood, glass, plastic, cardboard and players (`impact_*`,
`bodyHit`), the pouch, the hi-cap rattle, the magazine thrown and caught, the torch, the props run into (clank,
rattle, plastic, wood), the doors, the whistle, the shot timer's beep and the ping's pip. Each take is matched to the
loudest 50 ms of the synthesised cue it replaced, so SoundConfig's levels hold (the script lists each cue's recording,
takes and level). Re-cut with `python3 tools/cut_recordings.py <raw folder>`, then `godot --headless --path . --import`.
A gas pistol's shot is split where its crack gives way to the slide and the gas: the crack is `shot_gas`, the rest its
power part `power_gas`, so the two together are the recording.

**The second batch** (AU5, 2026-11-04): 30 more recordings give the steps on concrete, gravel and leaves, the kit
rustle (`foley_*`), the holster, the draw, the vault, the hit tick and hit marker, the steel ring, the glass prop, the
selector, the radio, the electric, spring and cyber magazines, the grenades' pin, bounce and smoke hiss, and two more
doors each way. Every ground's steps are then balanced to the recorded concrete, within
1 dB overall and 2 dB in the 0.7 to 4 kHz band (`balance_steps`; the rule is in `docs/DECISIONS.md` › Audio). With
`--loops` the script also makes the beds `loops/indoor.wav` (the Depot), `street_day.wav` and `street_night.wav` (the
street ambience, the Range's since 2026-11-05 and The Street's until that map went, 2026-11-09; the night one was
Woodland's night too until AU9): a stretch of each recording, its spikes ridden
down, cross-faded into a seamless loop and stored at its peak, with `peaks.json` holding the factor that brings it to
an RMS of 1, so a bed's gain in `play_tuning.tres` is its loudness.

**The third batch** (AU6, 2026-11-04): 11 more give the whistle (`whistle_short`, `whistle_long`: his blasts under
0.9 s and over, each cut to SoundConfig's length), the steps on metal (its rumble under 250 Hz taken out), grass and
gravel, the flag rope (`rope_up`, `rope_down`: 0.25 s of his first pull and his second), the flash bomb
(`flash_bang`; clean since AU7), the Sniper Rifle's shot (`shot_spring`, from each burst; its run-up before the burst is
`power_spring`) and bolt (`boltCycle`), and `loops/woods_day.wav`, Woodland's day bed. The Cyber Pistol's whir is his
electric toothbrush (his pick). His steps that never fall quiet between them (metal, running on gravel) are cut where
each starts (`onsets`).

**The bombs re-cut** (AU7, 2026-11-05; owner: they "don't sound like the recordings"): each cut starts on its sound
(`from_onsets`; the pin's takes were found 3 to 15 ms after its click, the can's first 0.18 s before its knock).
`grenade_pin` is his click high-passed at 300 Hz and left at its peak (matched to the old pin's loudness it took
17 dB and the limiter, and hissed), lifted by SoundConfig.pin_gain; `grenade_bounce` is his can's knock group
(0.6 s: the knock and its rattle, 30 dB down by 0.3 to 0.4 s), played once from a bomb's bounce
(SoundConfig.bounce_hold); `smoke_pop` is his long spray alone from its burst (the can pitched down as a pop is gone);
`flash_bang` his balloon pop clean, SoundConfig.bang_gain making up most of the level the soft clip gave, with an echo
after it (BP8: slap echoes and a diffuse tail, `echoed` in tools/cut_recordings.py, 2.2 s in all, eased out).

**The batch of 2026-11-08** (AU9): 5 more give the steps on wood (`step_wood_run`, `_sprint`, `_land`: his walk and
run on a wooden floor cut where each step starts, his jumps as takes, then balanced like every ground), the steel skip
run into (`prop_steel`: about 0.9 s of each of his two metal bangs) and `loops/woods_night.wav`, Woodland's night bed (his
woods at night, which leaves the street's night bed to the street ambience).

**The batch of 2026-11-11** (AU10): 17 more give the steps on soil (`step_earth_*`, in place of gravel softened), metal
(`step_metal_*`, a new walk, run and jumps in place of his first walk) and water (`step_water_*`, in place of the
synthesised splashes: his wading cut where each step starts, his jumps in as takes, at the splashes' levels), the lifts'
doors (`lift_doors`) and the car setting off (`lift_motor`: each of his two rides from its motor's start, 3.2 s, faded
before its stop), and `loops/tunnel.wav`, Subway's background (his tunnel, its rumble under 60 Hz taken out). The Sniper
Rifle keeps his first shot (his pick over his new one, which is kept unused), and the Compact SMG keeps its stand-ins
(his pick over his own SMG recording), its motor now with his toothbrush's whir 4 dB under it (`power_smg`).

**Every replica fired empty** plays one cue, `dryFire`: the gas pistol's recorded dry click as it is, for today's
replicas and any added later (owner, 2026-11-05: final, not a stand-in).

**The laser** (LZ1, 2026-11-08): Dev › Lasers' shot, `shot_laser_1.wav` to `_5`, is the owner's pick, B, of three
mixes `tools/laser_sound.py` makes from four free laser sound effects he sent (`audio/william/raw/laser/` in the shared
project files; source and licence in `docs/ASSETS.md`): `--samples` writes the three, `--pick B` its five variants
(each from its own takes of the pew and zap, a little quicker or slower; the first B as he heard it).

**Placeholders** (AU3, 2026-11-03; AU5; AU6; AU10): until the owner records them, 5 cues are his recordings reused,
re-pitched, filtered or sliced (BBs on concrete, soil and leaves, and the jumps onto gravel and leaves). The script labels each
one with what to record; `python3 tools/cut_recordings.py <raw folder> --placeholders` prints them, and those still
synthesised, as tables. The owner's plain status of every sound is in the shared project files, `audio/sound-status.md`
(keep it current with every audio change).

Everything below that the recordings didn't replace is still the browser game's synthesis:

Every sound the browser game synthesised, rendered once to WAV (16-bit mono, 44.1 kHz) from its recipes
(`legacy/browser/src/config/sounds.ts`, renderer `legacy/browser/src/audio/dsp.ts`) on 2026-10-18, with the same
seeds the browser game used, so they sound as they did.

- `cues/<cue>_<n>.wav`: each cue's variants (the cue's dots become underscores: `shot.electric` is
  `shot_electric_1.wav` to `_5.wav`). A shot's power part (`power_*`) plays with its shot on its own volume slider.
  The browser game's 78 cues were rendered here, since joined by the owner's recordings (below): 88 cues and 406 files,
  plus the whistle's 2 cues and 6 files (BP4 removed the unused motor spin-up and spin-down).
- `loops/<id>.wav`: the browser game's ambience bed `yard`, seamless, imported to loop; it still plays on the Range
  (its `pines`, `insects` and `crackle` went unused after AU5 and BP4 removed them). The owner's beds are above. They
  render far above full scale (the browser played them as float through a small gain), so each is stored normalised to
  its peak, and `loops/peaks.json` records that peak: play a loop at the browser game's gain times its peak to hear it
  at the browser's level.
- `cues/whistle_short_<n>.wav`, `whistle_long_<n>.wav` and `ping_pip_1.wav`: the pip is recorded since AU2; the
  whistle was `tools/cut_recordings.py`'s synthesised pea whistle from AU3 and is his own since AU6 (above). The
  browser game's draft (its live pea whistle and its beep) still renders with `tools/render_whistle.gd`, only to a
  folder named after `--`.
- `cues/grenade_pin_<n>.wav`, `grenade_bounce_<n>.wav`, `smoke_pop_<n>.wav` and `flash_bang_<n>.wav` (1 to 3): the
  smoke and flash bombs (SF1), made for this game, so never in the browser game. `tools/render_grenades.gd` renders
  them from its own constants and seeds (the pin's metal tink and scrape, a canister's hollow knock, the smoke's pop
  and fading hiss, the flash's short crack and thump), each scaled to a 0.9 peak; their levels are SoundConfig's. To
  re-render: `godot --headless --path . -s res://tools/render_grenades.gd`, then `godot --headless --path . --import`.
  The throw itself plays `magToss`. Since AU5 the pin, the bounce and the smoke's pop are the owner's recordings
  (above), and the flash's bang too since AU6 (all re-cut in AU7), so this renderer only drafts.
- `cues/door_open_<n>.wav` and `door_shut_<n>.wav` (1 to 5): recorded since AU2, 4 and 5 since AU5; the synthesised draft (DO1)
  renders with `tools/render_doors.gd` to a folder named after `--`.
- `cues/lift_chime_1.wav`, `lift_doors_1` to `_3`, `lift_motor_1` and `_2`, `lift_button_1`, `lift_buzz_1` (MT2):
  Subway's lifts (the car's arrival, its doors sliding, setting off, a button's beep, the too-full buzzer); the doors
  and the car setting off are the owner's lift since AU10 (`tools/cut_recordings.py`, levelled to the placeholders'
  loudness), the chime, the button and the buzzer still synthesised placeholders from `tools/lift_sounds.py` at a 0.7
  peak; their levels are SoundConfig's `lift_gain` and `lift_button_gain`. To re-render the placeholders: `python3
  tools/lift_sounds.py`, then `godot --headless --path . --import`.
- `cues/boltCycle_<n>.wav` (1 to 3): recorded since AU2 (the pistol's slide), his rifle bolt since AU6; the
  synthesised draft (SN1) renders with `tools/render_bolt.gd` to a folder named after `--`.
- Not baked in: the room reverb and distance muffling, which were applied live; in Godot they belong to the audio buses
  and `AudioStreamPlayer3D`.

Made by the project, so no external licence (`docs/ASSETS.md` › Made by the project). To change a sound, change its
recipe and re-render; until a Godot renderer exists, the browser game's renderer runs under Node (the 2026-10-18
salvage record says how). The recorded cues are re-cut from the recordings (above).
