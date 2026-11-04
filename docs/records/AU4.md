# AU4 · A softer, deeper spring and a thud on the Sniper Rifle, more motor on the Cyber Pistol

**Review:** critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-04 | 1 | Opus 5.5 (build thread) | ✓ | 8/8 Accept | – (four rounds of owner previews before review) |

## Decisions

- **The owner's asks** are in `docs/DECISIONS.md` › Audio; the amounts below are defaults for "a tiny bit" and "a
  bit".
- **Four rounds of previews** with the owner (`audio/william/preview/au4/` in the shared project files, each at one
  level with the one before). Round 2 was too metallic, echoing and thin on the rifle and too high on the pistol; round
  3 settled the pistol ("fine for now") and the rifle's body; round 4 put the crack back on the rifle, which ships.
- **The spring (`power_spring`):** the BB-on-metal ring at 38 % pitch (was 45 %), low-passed at 1.8 kHz to take the
  bright ring off, cut to 0.16 s (was 0.33) for less echo, 8 dB under its AU3 level (-27.3).
- **The shot (`shot_spring`):** the pitched-down pistol shot low-passed at 4 kHz (softer crack), a knock on wood at
  60 % pitch low-passed at 1.5 kHz 3 dB under it, and `thud()` in `tools/cut_recordings.py` (a sine falling from about
  130 to 55 Hz over 0.12 s) 3 dB under that, with the AEG's crack at 85 % pitch on top at the same loudest 50 ms
  ("needs more of a 'crack'"); levelled as before (-16.8), 0.50 to 0.52 s with the knock's tail.
- **The Cyber Pistol (`shot_cyber`):** the whir at 95 % of the motor's pitch (was 120 %), its slice 0.09 s (was 0.07,
  still overlapping its 14 BBs a second's 0.071 s gap, so full auto runs together) and 3 dB up against the crack, with
  `ev_hum()` 9 dB under it: a tone rising from 380 to 550 Hz with its 2nd and 3rd harmonics and a 120 Hz hum, the
  whine of an e-bike's motor. The limiter holds the crack's peak, so the shot's loudest 50 ms vary by about 2 dB
  between variants.
- **No slide sound on the Cyber Pistol:** a short slide tick, then an electric one, were tried for its small moving
  part; the owner kept the pistol without it ("happy with the latest sounds").
- Both stay labelled placeholders until the owner records a spring rifle and an electric pistol (or foley for them).

## Known issues left

- None new.
