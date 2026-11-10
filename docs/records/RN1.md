# RN1 · Kingsmere renamed Subway (owner request, 2026-11-10)

**Review:** critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-10 | 1 | build thread | ✓ | 8/8 Accept | – |

## Decisions

- **Id and files renamed too (default).** The owner asked for the name; the id went with it (`kingsmere` to `subway`:
  `data/maps/subway.json`, `tools/subway/`, `assets/maps/subway.jpg` and its card), so no file keeps the old name.
  The task records before this one (MT1, MT2, CL1, MT3) are history and keep it, as do the changelog notes' file
  names (their order comes from when git first saw them); the notes' text says Subway.
- **A save that remembers Kingsmere opens on Subway** (`Progress.RENAMED_MAPS`), not on the first card.
- **Woodland was already Woodland** on every player-facing surface (the map table, the Match page, the wiki); only six
  test names said "woodlands", and they now say "woodland". The recording `woodlands.wav` and a quote in DECISIONS
  keep the owner's words.
