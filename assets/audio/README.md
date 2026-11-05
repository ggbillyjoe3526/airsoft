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
`--loops` the script also makes the beds `loops/indoor.wav` (the Depot), `street_day.wav` and `street_night.wav` (The
Street; the night one is Woodland's night too for now): a stretch of each recording, its spikes ridden
down, cross-faded into a seamless loop and stored at its peak, with `peaks.json` holding the factor that brings it to
an RMS of 1, so a bed's gain in `play_tuning.tres` is its loudness.

**The third batch** (AU6, 2026-11-04): 11 more give the whistle (`whistle_short`, `whistle_long`: his blasts under
0.9 s and over, each cut to SoundConfig's length), the steps on metal (its rumble under 250 Hz taken out), grass and
gravel, the flag rope (`rope_up`, `rope_down`: 0.25 s of his first pull and his second), the flash bomb
(`flash_bang`, saturated), the Sniper Rifle's shot (`shot_spring`, from each burst; its run-up before the burst is
`power_spring`) and bolt (`boltCycle`), and `loops/woods_day.wav`, Woodland's day bed. The Cyber Pistol's whir is his
electric toothbrush (his pick). His steps that never fall quiet between them (metal, running on gravel) are cut where
each starts (`onsets`).

**Every replica fired empty** plays one cue, `dryFire`: the gas pistol's recorded dry click as it is, for today's
replicas and any added later (owner, 2026-11-05: final, not a stand-in).

**Placeholders** (AU3, 2026-11-03; AU5; AU6): until the owner records them, 13 cues are his recordings reused,
re-pitched, filtered or sliced (BBs on concrete, soil and leaves,
the steel skip, the steps on wood and soil, and the jumps onto wood, gravel, leaves and metal). The script labels each
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
  (above), and the flash's bang too since AU6, so this renderer only drafts.
- `cues/door_open_<n>.wav` and `door_shut_<n>.wav` (1 to 5): recorded since AU2, 4 and 5 since AU5; the synthesised draft (DO1)
  renders with `tools/render_doors.gd` to a folder named after `--`.
- `cues/boltCycle_<n>.wav` (1 to 3): recorded since AU2 (the pistol's slide), his rifle bolt since AU6; the
  synthesised draft (SN1) renders with `tools/render_bolt.gd` to a folder named after `--`.
- Not baked in: the room reverb and distance muffling, which were applied live; in Godot they belong to the audio buses
  and `AudioStreamPlayer3D`.

Made by the project, so no external licence (`docs/ASSETS.md` › Made by the project). To change a sound, change its
recipe and re-render; until a Godot renderer exists, the browser game's renderer runs under Node (the 2026-10-18
salvage record says how). The recorded cues are re-cut from the recordings (above).
