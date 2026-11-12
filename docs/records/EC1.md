# EC1 · Subway's shots echo

**Review:** critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-12 | 1 | Opus 5.5 (build thread) | ✓ | 8/8 Accept | – |

## Goal

The owner, 2026-11-12: "Also for the Subway map exclusively, I want gun sounds to have a bit more volume and reverb to
them as it's an underground/indoor map. This only applies to this map. Give me sample sounds comparing gun shots in
woodland vs subway."

## Decisions

- **A Shots bus every shot plays through.** Shot, power part, laser shot and a silenced shot (Muffled now feeds
  Shots), yours and the bots', open or through cover (new ShotsHalf and ShotsFull, set as EffectsHalf and
  EffectsFull). With no echo it is a 0 dB pass-through with its reverb off, so every other map sounds as before.
- **Per map, by id.** `SoundConfig.shot_echoes` lists Subway alone (`ShotEcho` holds the numbers); a map's ambience
  was not used as the key, so the echo stays with the map if its background changes.
- **Defaults (owner to tune by ear):** +2 dB on the bus; reverb room 0.72, damping 0.35 (bright tiles), high-pass
  0.25 (no boom under a motor), pre-delay 28 ms, wet 0.28, dry 1: a quick slap and about a second of tail. Your own
  shots peak at the Master limiter already, so up close the 2 dB shows mostly as body and tail.
- **Guns only.** Steps, impacts, mechanisms (the sniper's bolt cycle too) and grenades stay dry; the flashbang has
  its own echo baked in (AU7/BP8).
- **Leaving the match puts the bus back,** only by the SimAudio that set it (QA's advisory: an old match freed after
  a new one's setup must not switch the new echo off).
- **Samples** through the game's own buses (AudioEffectRecord on Master, the default volumes):
  `audio/william/preview/ec1/` in the shared files, Woodland then Subway for each replica, plain and silenced.

## Known issues left

- The sniper's bolt cycle plays dry straight after an echoing shot (critic's advisory); left for the owner's ear.
