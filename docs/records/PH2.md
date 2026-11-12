# PH2 · The GBB Pistol 0.70 J and the Compact SMG 0.85 J

**Review:** 2 attempts · critic Accept 7/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-12 | 1 | build thread | ✓ 6,041 of 6,043 (2 pending) | 6/8 Retry | Balance judged at factory BB weights only: a tuned pistol reached 42 m on Black Gas with 0.32 g; stale doc lines |
| 2026-11-12 | 2 | build thread | ✓ 6,052 of 6,054 (2 pending) | 7/8 Accept | – |

The owner (2026-11-12), on reading PH1's finding that the GBB Pistol's 0.52 J was below a real green-gas pistol's:
"Increase gbb pistol to 0.7J and SMG to 0.85J. Would that still be balanced?" No task block (asked for directly).

## The figures

Measured with the game's own flight (`Ballistics.hop_up_reach`, the 15 cm band, still air at 20 °C). "As it comes" is
the factory dial and BB weight; "furthest" is the best over every dial notch, power source and BB weight the Loadout
allows (0.20 to 0.40 g).

| | Before | After |
|---|---|---|
| GBB Pistol, Green Gas, as it comes | 0.52 J, 237 fps, 27 m | 0.70 J, 274 fps, 29 m |
| GBB Pistol, Red Gas, as it comes | 0.57 J, 29 m | 0.77 J, 288 fps, 31 m |
| GBB Pistol, Black Gas, as it comes | 0.62 J, 30 m | 0.84 J, 301 fps, 32 m |
| GBB Pistol, Woodland at night (8 °C) | 24 m | 0.60 J, 254 fps, 26 m |
| GBB Pistol, furthest | 37.7 m (Black Gas, 0.30 g) | 37.6 m (Black Gas, 0.23 g) |
| Compact SMG, as it comes | 0.75 J, 284 fps, 27 m | 0.85 J, 302 fps, 30 m |
| Compact SMG, furthest | 31 m | 31 m |
| 20 m takes | pistol 0.39 s, SMG 0.33 s | pistol 0.34 s, SMG 0.31 s |

Beside them, unchanged: the Cyber Pistol 33 m as it comes and 38.4 m at its furthest (0.22 g), the AEG Rifle 39 m
and 44 m (0.35 g), the Sniper Rifle 48 m as it comes.

## Decisions

- **The energies are the owner's** (`docs/DECISIONS.md` › The GBB Pistol shoots 0.70 J and the Compact SMG 0.85 J).
- **Each keeps its job through its hop-up** (the default taken to "would that still be balanced?"): the extra
  energy is a quicker BB and a little reach as it comes; the furthest either can be tuned to stays where it was.
- **The pistol's hop-up tops out at 0.19 (0.3 before) and comes at 75 %.** Attempt 1 left its range alone and judged
  it at the factory BB weight: "36 m against the Cyber Pistol's 35 m". The critic measured across BB weights: 42.3 m
  on Black Gas with 0.32 g BBs, 4 m past the Cyber Pistol's furthest and 1.6 m short of the AEG Rifle's. With the
  range trimmed the pistol's furthest is 37.6 m, as before PH2, and as it comes it stays under the Cyber Pistol on
  every gas (29, 31 and 32 m against 33 m). 75 % is two notches under where Black Gas over-hops.
- **The SMG's hop-up tops out at 0.135 (0.15 before) and comes at 95 %.** Left alone, 0.85 J took its best reach from
  31 m to 34 m with 18 BBs a second, half the moving spread and the quickest feet: the AEG Rifle's job as well as its
  own. PP1 cut its best reach for the same reason.
- **Saved dials are converted, once.** A dial is a share of its replica's hop-up range, so a loadout saved before
  PH2 would have lifted less (the SMG's 85 % gave 26.7 m, the pistol's 55 % about 23 m). `loadouts.save` is version 2:
  a version 1 file has its pistol and SMG dials multiplied by the old range over the new as it loads
  (`ReplicaRulesConfig.hop_up_rescale_v1`, `SavedLoadouts._hop_ups_from_v1`), on a notch and no further than the
  dial goes, and is saved as version 2 at the next save. A pistol dial saved above 63 % was past what the new range
  lifts and loads at 100 %.
- **A saved dial keeps its lift, not its place on the dial.** A pistol saved at the old factory 55 % loads at 85 %
  (32 m on Green Gas, where it shot before the cap), not at the new factory 75 %: the conversion cannot tell a dial
  the player chose from one saved by a repaint, and keeping what the replica did is the safe reading (the critic's
  advisory; on Black Gas that dial is one notch under over-hop, as it was before).
- **The critic's last failed check (8, two doc lines)** was fixed after the Accept: the night figure in
  `changelog.d/physics-audit.md` (about 2 m) and the ruling's wording in `docs/DECISIONS.md`.
- **No other replica, part or power source changed.** The site limits hold both with room: the pistol's strongest
  gas 0.84 J under 1.0 J, the SMG 0.85 J under 1.2 J.

## Bot bench

`tools/balance.sh depot`, 8 seeds, Normal, both modes (16 matches, 126 rounds), on main and on attempt 1's energies.
Reports: `/mnt/project-files/pipeline/runs/PH2/attempt-1/balance-depot-before.md` and `balance-depot-after.md`.

Every figure is the same to the last digit on both (Alpha 53.1 % of decided Elimination rounds, attackers 43.5 % of
Attack / Defend rounds, first hit at a median 14.5 s and 12.8 m, no round on the clock; 0 of 16 figures outside its
band). The bench's bots carry the factory loadout and fight with the AEG Rifle; the pistol is their fallback and decided
nothing (not one figure moved), and the Compact SMG's Breacher kit is Dev content, which the bench does not field. So it shows that nothing
else moved, and says nothing about the two replicas themselves; their balance here rests on the measured reach
above and the invariants in `tests/unit/test_rp1_balance.gd` and `test_ph2_qa.gd`.

## Known issues left

- `docs/KNOWN_ISSUES.md` › Balance: PH2's numbers are from the data, not from play (the bot bench does not field
  either replica); whether the pistol still feels like a sidearm and the SMG still short is the owner's playtest.
- `tests/unit/replica_fixtures.gd` keeps a standalone 0.52 J pistol for the flight tests that need fixed numbers
  (QA's note): no game code reads it.
