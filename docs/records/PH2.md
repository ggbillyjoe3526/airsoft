# PH2 · The GBB Pistol 0.70 J and the Compact SMG 0.85 J

**Review:** REVIEW_LINE

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
ATTEMPT_ROWS

The owner (2026-11-12), on reading PH1's finding that the GBB Pistol's 0.52 J was below a real green-gas pistol's:
"Increase gbb pistol to 0.7J and SMG to 0.85J. Would that still be balanced?" No task block (asked for directly).

## The figures

Measured with the game's own flight (`Ballistics.hop_up_reach`, the 15 cm band, still air at 20 °C, each replica's
factory BBs):

| | Before | After |
|---|---|---|
| GBB Pistol, Green Gas | 0.52 J, 237 fps, 27 m as it comes, 31 m at its best hop-up | 0.70 J, 274 fps, 30 m, 35 m |
| GBB Pistol, Red Gas | 0.57 J, 29 m | 0.77 J, 288 fps, 32 m, 35 m |
| GBB Pistol, Black Gas | 0.62 J, 30 m | 0.84 J, 301 fps, 33 m, 36 m |
| GBB Pistol, Woodland at night (8 °C) | 24 m | 0.60 J, 254 fps, 27 m |
| Compact SMG | 0.75 J, 284 fps, 27 m, 31 m | 0.85 J, 302 fps, 30 m, 31 m |
| 20 m takes | pistol 0.39 s, SMG 0.33 s | pistol 0.34 s, SMG 0.31 s |

Beside them, unchanged: the AEG Rifle 39 m (0.30 s to 20 m), the Cyber Pistol 33 m as it comes and 35 m at its best,
the Sniper Rifle 48 m.

## Decisions

- **The energies are the owner's** (`docs/DECISIONS.md` › The GBB Pistol shoots 0.70 J and the Compact SMG 0.85 J).
- **The pistol's hop-up comes at 50 %, not 55 %.** At 0.70 J and 55 % it held 33 m, but Red and Black Gas sat one
  notch under over-hopping (60 %: 20 m). At 50 % every gas gains reach in order: 30, 32, 33 m.
- **The SMG's hop-up tops out at 0.135 (0.15 before) and comes at 95 %.** Left alone, 0.85 J took its best reach from
  31 m to 34 m with 18 BBs a second, half the moving spread and the quickest feet: the AEG Rifle's job as well as its
  own. Its best reach stays 31 m (PP1 cut it for the same reason), so the extra energy is a BB that gets there sooner.
- **The pistol's hop-up range is left alone.** With its dial tuned it now reaches 35 m (36 m on Black Gas) against
  the Cyber Pistol's 35 m, so the Cyber Pistol no longer out-reaches it. The Cyber Pistol still fires 14 BBs a second
  against single shots, at half the spread and an eighth of the kick; the owner was told, and offered the same cap as
  the SMG's if he wants the Cyber Pistol to stay the longer pistol.
- **No other replica, part or power source changed.** The site limits hold both with room: the pistol's strongest
  gas 0.84 J under 1.0 J, the SMG 0.85 J under 1.2 J.

## Known issues left

- `docs/KNOWN_ISSUES.md` › Balance: PH2's numbers are from the data, not from play; whether the pistol still feels
  like a sidearm and the Cyber Pistol still earns its level is the owner's playtest.
