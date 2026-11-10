# MOD1 · Mode order on the Match page (owner request, 2026-11-10)

**Review:** critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-10 | 1 | build thread | ✓ | 8/8 Accept | – |

## Decisions

- **Attack / Defend, Elimination, Practice, top to bottom (owner, 2026-11-10).** `MatchOptions.MODES`, `BUILT_MODES`
  and the field's `KIND_MODES` take the same order, so every list of modes reads alike. Attack / Defend stays the mode
  picked at start, and a map without a flagpole still falls back to Elimination.
