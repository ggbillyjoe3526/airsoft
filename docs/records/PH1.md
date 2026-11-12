# PH1 · The physics audit: weather per field, moving-target hits, heavier BBs

**Review:** REVIEW_LINE

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
ATTEMPT_ROWS

The owner's ask (2026-11-12): "go over the physics of the game... check that the guns are accurate. Check ballistics,
trajectories, gravity, mass, etc. also look at wind, temperatures and any other environmental aspects that may affect
the simulation of shooting", "look at hit detection. Make sure hits on bots/objects are detected properly and
accurately", and "if you need to adjust the specs of any weapons/attachments or accessories then feel free to do so".
No task block (asked for directly). Not the gated Dev 3 final pass.

## What held up

The flight model is sound and was left alone. Checked against a copy of it in Python and the published figures:

- Gravity 9.81 m/s², a 5.95 mm BB, air density from the ideal gas law (1.204 kg/m³ at 20 °C), Sutherland viscosity,
  a sphere's drag by Reynolds number, hop-up as Magnus lift (CL = S / (0.981 + 2.022·S)) with the spin decaying in
  flight, E = ½·m·v², and joule creep by BB weight (exponent 0.15).
- The midpoint integrator at 60 Hz lands within 2 mm of a 6000 Hz reference at 50 m.
- The replicas as they ship, in still air at 20 °C: the AEG Rifle 0.97 J with 0.25 g leaves at 88 m/s (289 fps), holds
  the 15 cm band to 39 m and lands at 52 m; the Sniper Rifle 1.9 J with 0.30 g, 113 m/s, 48 m and 63 m; the Compact SMG
  0.75 J with 0.20 g, 87 m/s, 27 m; the Cyber Pistol 1.0 J with 0.25 g, 89 m/s, 33 m; the GBB Pistol 0.52 J with
  0.20 g, 72 m/s, 27 m. Backspin at the dial's factory setting is 6,000 to 9,000 rpm. All within what real replicas of
  those classes do, the GBB Pistol's energy apart (Known issues left).
- Hits on the level (Jolt's swept ray per tick, railing bars, leaves, water) and the analytic capsule tests of
  `Hitbox` are exact for a standing body: a BB cannot tunnel a wall or a body at any speed the game allows.

## What was wrong, and what changed

- **Wind blew indoors.** One wind draw for every map, so Depot and Subway had a crosswind of up to 1.8 m/s (32 cm of
  drift at 30 m on the AEG). `data/maps.md` gains **Wind (×)**: 0 for Depot and Subway, 1 for Woodland and the Range.
- **The air was 20 °C everywhere, always.** `data/maps.md` gains **Air (°C)**: Depot and the Range 20, Woodland 16,
  Subway 14, and an open field is 8 °C colder at night (`WeatherConfig.night_drop`). Colder air is denser, so a BB
  slows a little sooner; the bots' lead and the HUD's hop readout use the field's air too.
- **Gas ignored temperature.** A gas replica's energy now follows the air by 1.2 % per °C from the 20 °C it is rated
  at (`WeatherConfig.gas_energy_per_degree`; the field rule of thumb of about 1 fps per °F), clamped 0.5 to 1.4 and
  never past the site limit. The GBB Pistol holds the band to 27 m at 20 °C and 24 m on Woodland at night (8 °C).
  Electric and spring replicas are unchanged.
- **A moving body was tested where it ended the tick.** The BB's segment was swept against the body's position at
  the tick's end, so a BB crossing a sprinter's trailing edge passed up to 11 cm of body that was there when the BB
  went by. `BBStep._first_body` now tests in the body's frame (the body's own step taken off the BB's), which is the
  exact answer for two things moving in straight lines over one tick. A body that stood still, or jumped further than
  `HitConfig.max_stride` (a respawn), is tested as it stands.
- **Joule creep could pass the site limit.** The limit was applied at the factory BB weight; a heavier BB then crept
  over it (the Cyber Pistol, 1.0 J on the pistol class's 1.0 J limit, shot 1.03 J with 0.30 g BBs). The limit is now
  read with the BBs loaded, as a site's chrono does.
- **BBs stopped at 0.30 g.** The Loadout loads 0.20 to 0.40 g. Heavier than 0.30 g only pays on the Sniper Rifle; a
  pistol loses reach with it.
- **A lobbed BB vanished in the air.** A BB lived 2.5 s; the longest lob the game allows (0.40 g at the bolt-action
  limit, 24° up) flies 130 m in 5.5 s. `max_lifetime` is 6.0 s.

The pause menu says the field's air under the match line ("Air 16 °C · breeze 1.2 m/s", "Air 20 °C · still air") and a
map card's tooltip says whether the field is open to the breeze.

## Decisions

- **Indoor fields are still air** (`docs/DECISIONS.md` › Gameplay and feel). The owner asked for the environment to be
  right; a draught inside a warehouse is not.
- **Field temperatures** are a British field's: a heated hall 20 °C, a wood by day 16 °C and 8 °C at night, an
  underground station 14 °C. Data, one cell each.
- **Night is colder outdoors only**, and only Woodland has a night preset today.
- **The Range keeps the breeze and 20 °C**: it stands in the open, and it is where the Loadout's figures are checked.
- **No weather picker.** The field decides; nothing new to set before a match.
- **Left out on purpose** (fun over simulation; each would make a miss feel random or a hit feel unearned):
  shot-to-shot velocity and hop variation beyond the replica's spread, a BB inheriting the shooter's own speed, a
  canted hop-up curving the shot, gas cooling down in rapid fire, rain and humidity, altitude.
- **Per-replica energies are unchanged.** The balance thread (RP1) had just settled them; PH1 changes how the
  environment acts on them, not the cards.
- **The debug BB trail stays 2.5 s**: it is for reading a shot, not a lob.

## Known issues left

- The GBB Pistol's 0.52 J is below a real green-gas pistol's 0.7 to 0.85 J (`docs/KNOWN_ISSUES.md`): the owner's call.
- The Loadout's reach, speed and flight picture are at the rated 20 °C in still air (`docs/KNOWN_ISSUES.md`).
- A practice range swinger or pop-up is not swept through its own move (`docs/KNOWN_ISSUES.md`).
