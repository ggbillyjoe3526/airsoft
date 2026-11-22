# FPC1 · The fields' pictures drawn again

**Review:** 2 attempts · critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-22 | 1 | Opus 5.5 (build thread) | ✓ | 7/8 Retry | no changelog note; performance report not on disk |
| 2026-11-22 | 2 | Opus 5.5 (build thread) | ✓ | 8/8 Accept | – |

## Decisions

- **The owner's 22 November playtest note, item 6.** Depot, Woodland and Subway's pictures (the loading screen's and
  the Match page's small copies) drawn again on High from the maps as they are now; the Range's is unchanged.
- **Subway's trains in the pictures.** `tools/eye_pictures.gd` now stands a station's trains (TrainView) and hides the
  roof lamps inside their cars, as `PlaySession` dresses them; the same north platform spot now has its train beside it.
- **Depot and Woodland: the owner picked from pictures** (`/mnt/project-files/playtest/map-pictures-fpc1/`, four Depot
  views and three Woodland views, 22 November): Depot looking into Chrono hall past a pillar (`-10,-10,-127,2`),
  Woodland's Log stacks track toward B (`20,40,-90,2`); he kept Subway's north platform. Spots are in `docs/ASSETS.md`.

## Known issues left

- The picture tool still leaves out the lamps hidden indoors and the Range's chimney smoke (`docs/KNOWN_ISSUES.md`).
