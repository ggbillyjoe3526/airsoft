# Sounds

Every sound the browser game synthesised, rendered once to WAV (16-bit mono, 44.1 kHz) from its recipes
(`legacy/browser/src/config/sounds.ts`, renderer `legacy/browser/src/audio/dsp.ts`) on 2026-10-18, with the same
seeds the browser game used, so they sound as they did.

- `cues/<cue>_<n>.wav`: each cue's variants (the cue's dots become underscores: `shot.electric` is
  `shot_electric_1.wav` to `_5.wav`). A shot's power part (`power_*`) plays with its shot on its own volume slider.
  78 cues, 372 files, and the whistle's 2 cues and 6 files (below).
- `loops/<id>.wav`: the ambience beds (`yard`, `pines`, `insects`, `crackle`), seamless,
  imported to loop. They render far above full scale (the browser played them as float through a small gain), so each
  is stored normalised to its peak, and `loops/peaks.json` records that peak: play a loop at the browser game's gain
  times its peak to hear it at the browser's level.
- `cues/whistle_short_<n>.wav` and `whistle_long_<n>.wav` (1 to 3): the referee's pea whistle, which the browser game
  synthesised live, so it was never in the salvage. `tools/render_whistle.gd` renders it from SoundConfig's whistle
  numbers in `game/config/play_tuning.tres` (2900 Hz, warbling at 28 Hz by 4 %, 20 ms in, 50 ms out; a short blast
  0.14 s, a long 0.8 s; each variant's warble a third of a cycle on), at full scale: it plays at `whistle_gain`. To
  re-render after changing those numbers: `godot --headless --path . -s res://tools/render_whistle.gd`, then
  `godot --headless --path . --import`, and commit the files with their `.import` files
  (`tests/unit/test_whistle_sound.gd` fails until the files match the numbers).
- `cues/ping_pip_1.wav`: your ping's pip (PN2; the browser game's AUDIO.pingPip, played live by its whistle's beep),
  rendered by the same tool from SoundConfig's ping_pip numbers (a plain 1700 Hz sine, 0.08 s, the whistle's fade in
  and out) at full scale: it plays at `ping_pip_gain` (`tests/unit/test_ping_markers.gd` checks the file).
- `cues/grenade_pin_<n>.wav`, `grenade_bounce_<n>.wav`, `smoke_pop_<n>.wav` and `flash_bang_<n>.wav` (1 to 3): the
  smoke and flash bombs (SF1), made for this game, so never in the browser game. `tools/render_grenades.gd` renders
  them from its own constants and seeds (the pin's metal tink and scrape, a canister's hollow knock, the smoke's pop
  and fading hiss, the flash's short crack and thump), each scaled to a 0.9 peak; their levels are SoundConfig's. To
  re-render: `godot --headless --path . -s res://tools/render_grenades.gd`, then `godot --headless --path . --import`.
  The throw itself plays `magToss`.
- `cues/door_open_<n>.wav` and `door_shut_<n>.wav` (1 to 3): the hinged doors (DO1), made for this game.
  `tools/render_doors.gd` renders them from its own constants and seeds (a latch's click and a hinge's creak; a shorter
  creak, a plywood leaf's slam and the latch), each scaled to a 0.9 peak; their level is SoundConfig's `door_gain`. To
  re-render: `godot --headless --path . -s res://tools/render_doors.gd`, then `godot --headless --path . --import`.
- `cues/boltCycle_<n>.wav` (1 to 3): the Sniper Rifle's cocking after every shot (SN1), made for this game.
  `tools/render_bolt.gd` renders it from its own constants and seeds (the charging handle's plastic scrape over the
  spring's rising zing, the sear's click, the snap home), timed to the model's Fire clip and scaled to a 0.9 peak. To
  re-render: `godot --headless --path . -s res://tools/render_bolt.gd`, then `godot --headless --path . --import`.
- Not baked in: the room reverb and distance muffling, which were applied live; in Godot they belong to the audio buses
  and `AudioStreamPlayer3D`.

Made by the project, so no external licence (`docs/ASSETS.md` › Made by the project). To change a sound, change its
recipe and re-render; until a Godot renderer exists, the browser game's renderer runs under Node (the 2026-10-18
salvage record says how). The whistle has its Godot renderer (above).
