# AU2 · The owner's recordings in the game

**Review:** critic Accept 7/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-03 | 1 | Opus 5.5 (build thread) | ✓ (one cue-count assert updated, re-run) | 7/8 Accept | – (check 8, docs: fixed in the same push) |

## Decisions

- **The owner's rulings on his first recordings** are in `docs/DECISIONS.md` › Audio.
- **Levels.** Each take is matched to the loudest 50 ms of the synthesised cue it replaced, so SoundConfig's gains hold;
  peaks over -1 dB are held by a limiter of at most 6 dB. The whistle (`whistle_gain` 0.25 → 0.45) and the ping's pip
  (`ping_pip_gain` 0.13 → 0.2) are lifted by the gap between a recording and the old full-scale sine.
- **The whistle's blasts.** Short 0.3 s (was 0.14, a real blast is longer), long kept at the browser's 0.8 s, so the
  match's end still takes 3.92 s.
- **Replicas from the pistol and the motor.** AEG: the motor's spin-up, 0.11 s a shot, under the pistol's crack at
  90 % pitch; its dry click the motor alone. Cyber Pistol: the motor 20 % higher, 0.07 s, under a smaller crack.
  Sniper Rifle: the pistol's shot at 75 % pitch (its synthesised spring twang stays), its magazine at 85 %, the
  pistol's metal slide as its cocking, the pull back and the run home each moved onto the Fire clip's 0.50 s and
  0.71 s. The rifles' magazines are the pistol's at 90 %.
- **The gas pistol's shot is split** where its crack gives way to the slide and the gas: the crack is `shot_gas`, the
  rest `power_gas` (on the Power volume), so together they are the recording.
- **New surfaces.** Glass (`glass`), plastic (`bins`, `toilet`) and cardboard (`wrapped`, `drum`) have BB sounds of
  their own and otherwise go as the metal and wood they were: bounce, puff, minimap tint, steps and noise. The Depot
  and range bakes were re-baked for the changed block surfaces (same light).
- **Set aside:** the slide release and the slide rack (no moment plays them yet), the gas refill (owner: not used),
  the room tone (cleaning reference only). The draft renderers (whistle, doors, bolt) now write only to a folder named
  after `--`.

## Known issues left

- The gas pistol's slide closing on a reload from empty (`ReplicaView`) has no sound yet; the recorded slide release
  could play there.
- Not recorded yet, still synthesised: the steps, concrete, earth and leaf impacts, the selector, the draw, the radio,
  the kit rustle, the hits' tick and confirmation, the vault, the steel ring, the flag rope, the steel skip and glass
  props, the grenades and the ambience.
