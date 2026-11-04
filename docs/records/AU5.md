# AU5 · The owner's second batch: footsteps, kit, hits, gear, more doors, and the Depot's and The Street's ambience

**Review:** critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-04 | 1 | Opus 5.5 (build thread) | ✓ | 7/8 Revise | dead rope placeholders left in the cutter |
| 2026-11-04 | 2 | Opus 5.5 (build thread) | ✓ | 8/8 Accept | – |

## Decisions

- **The owner's answers** to seven questions on the batch are in `docs/DECISIONS.md` › Audio (the second batch).
  Three were defaults he took (toothbrush, keys, deodorant).
- **Footsteps:** concrete's run is `walking_concrete`, its sprint `Running` and its landing `Jumping` (the "solid
  floor"); wood is the solid floor 10 % lower (12 % for the landing), a labelled placeholder. Gravel and leaves run and
  sprint are recorded; their landings are their steps 15 % lower, placeholders. Grass is the leaves low-passed at
  3.5 kHz and soil the gravel low-passed at 2.5 kHz, placeholders. Takes are the five closest to each file's median
  loudness (`steady()`), so no step jumps out. Metal stays synthesised.
- **Footsteps stay information:** the recordings differ by up to 7 dB in the 0.7 to 4 kHz band (gravel's crunch), so
  `balance_steps()` turns each ground's band and the rest up or down until it is within 1 dB of concrete overall and
  2 dB in the band (the ruling's 1.5 and 3, with room), measured as the browser game's test measured it. Gravel's
  band comes down most (5.6 dB on the run); metal's synthesised steps are balanced to the new concrete too. Running the
  script again changes nothing. A test holds the overall 1.5 dB in the game's own files; the band half is held by
  the script only (a band test would need an FFT GDScript doesn't have). Grass and soil reuse the same five leaves
  and gravel takes at all three paces (labelled placeholders).
- **Kit rustle (`foley_crouch`, `stand`, `lean`):** the loudest windows of `clothes_rustle` (0.25, 0.22, 0.16 s) with
  `jangling_keys` 10 dB under. **Holster, draw, vault** from their recordings (0.4 and 0.5 s, steady takes).
- **Hits:** the goggles take high-passed at 800 Hz, 0.1 s, is `hitTick`; the tap, 0.12 s, `hitMarker` (at the same
  loudest 50 ms, its peak 5 dB under the synthesised one's: a softer transient). **Also recorded now:** `selector`
  (the switch, 0.08 s), `radio_ack` (the radio, 0.3 s), `steelRing` (the steel target, 0.4 s) and `prop_glass`
  (the glass bumped, 0.4 s, 3 variants), all AU3 placeholders until now.
- **Magazines:** the remote's battery cover, the quieter takes off and the others on, 15 % lower for the AEG, 20 % for
  the sniper rifle, as is for the Cyber Pistol. The gas pistol keeps its own.
- **Grenades:** the pin (takes 2 to 4; the first is too thin; its loudest 50 ms land at -12.6 to -14 dB against
  the -10.2 target, the limiter holding its sharp peak, so about 3 dB quieter than the synthesised pin), the can for
  the bounce (0.2 s), and the smoke's pop: the can 40 % lower under the long deodorant spray 9 dB down, 3.5 s. The flash stays synthesised (a balloon is on
  the list).
- **Flag rope:** the pen click 10 % higher (up) and 5 % lower (down), placeholders.
- **Doors:** two more takes each way (5 variants, was 3), from `door_open_and_close`.
- **Ambience beds:** `--loops` takes a stretch of each recording (indoor 3 to 55 s, the two outdoor files 3 to 45 and
  5 to 47 s joined, street night 3 to 65 s), rides spikes down by up to 4 dB (`ride()`) so no event repeats loudly,
  and cross-fades the ends equal-power over 2 s. Gains are RMS: indoor and street day 0.03, street night 0.02, woods
  0.018 day and 0.02 night, all under the yard's 0.035 (tested). The Depot's calls are the roof's creak; The Street's
  a bird, a crow and a dog by day and the dog at night; Woodland keeps its own.
- **Not used:** the electric toothbrush (a comparison against the approved Cyber Pistol is in the shared files'
  `audio/william/preview/au5/`), the short deodorant spray, and the room tone (used only to measure the floor). The
  old pines, insects and crackle loops stay on disk, unused (about 0.3 MB imported, still exported; can wait).
- **The owner's status file** (`audio/sound-status.md` in the shared project files) lists what's left to record.

## Known issues left

- Woodland's bed is the street at night until a forest is recorded (`docs/KNOWN_ISSUES.md`).
