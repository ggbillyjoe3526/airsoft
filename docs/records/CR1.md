# CR1 · Custom match rules behind the Match screen

**Review:** critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-10-22 | 1 | Opus (build thread) | pass | 8/8 accept | (a first critic run refused: the checks had run on an earlier head; re-run, no attempt spent) |

## Decisions

- **Step 15 is two tasks:** CR1 (this) puts the Custom rule set's switches in the settings and plays them; CR2 draws
  the Rules section from the approved concepts (`/mnt/project-files/concepts/step15-rules/`, William 2026-10-22 11:49).
  The step is the five switches the build order names (team size, rounds to win, round time, friendly fire,
  ricochets); the browser game's other switches (win by two, time out to more players, semi only, realcap, factory
  kit) came with Tournament and Pro CQB and go with them to the field rule presets (ROADMAP › Modes Update).
- **The switches are saved, the pick is not:** Settings.custom_rules keeps your Custom setup between launches (the
  browser game saved each choice); Skirmish or Custom is a match pick in MatchPicks, kept for the session like the
  map and mode (MN2), so a new launch starts on Skirmish.
- **Choices as the browser game offered them:** 1v1 to 3v3 (Depot holds three a side; 4v4 and up wait for Woodland),
  first to 3, 5, 7 or 10, round time 1:30 to 5:00 in half minutes. A saved value off those keeps its default alone.
- **A Custom match plays a copy of the tuning** (CustomRules.applied_to): load_default returns the one cached resource,
  so writing into it would carry Custom's numbers into the next Skirmish match and the menus.
- **The ends swap one round short of the win** (first to 5: after 4, as Skirmish; first to 10: after 9), as the
  browser game's roundRulesFor, so a full-length match's decider is played in the second half.
- **Never in the records, XP capped:** a Custom match stays out of the records even with every switch at Skirmish's
  (it is a different match to the player), and its multiplier is at most data/levels.md's new Custom row (×1.5, the
  browser game's CUSTOM_RULES_PAY_CAP, "Custom pays like Hard"); Easy and Normal pay as before.
- **The smoke test always plays Skirmish.**
