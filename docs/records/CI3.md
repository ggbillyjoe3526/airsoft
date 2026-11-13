# CI3 · Woodland's Hard night guards in two jobs

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-13 | 1 | Opus 5.5 (build thread) | see Checks | pending | – |

## Goal

Stop the CI job "Night match guards, Woodland, both modes at Hard" running out its 30 minutes. It was cancelled at the
limit on main's run for #337 (run 43347661654, step cancelled at 29 min 52 s) and once on #338. It held two tests of
8 seeds each, 16 whole Woodland matches at night, the same count as the Normal jobs, but Hard rounds run longer.

## What was built

- **`.github/workflows/ci.yml`:** the `night-guards` matrix entry `at_hard` is two entries, "Woodland, Elimination at
  Hard" (`elimination_at_hard`, log `night-guards-5`) and "Woodland, Attack / Defend at Hard"
  (`attack_defend_at_hard`, log `night-guards-6`), as the Normal and Easy guards are. No test is dropped or changed:
  the six entries now name the file's six tests one each. The job's comment says why.
- **Docs:** the test file's header and `tests/README.md` say six jobs. `pipeline/README.md` and `ci.yml`'s header
  already said six.
- No changelog note: nothing a player or the owner sees in the game changes.

## Did MQ3 slow Woodland's matches?

No. MQ3 (#337) made `human.glb` 9.7 to 12.5 MB and added 2048 gear maps, so both were measured in a cloud session (4
cores) on the commit before it (`62ea8f2`, #336) and on main (`acfc982`, #338), side by side so both shared the
machine alike:

| Measure | Before MQ3 | Main | |
|---|---|---|---|
| `godot --headless --import` from a clean `.godot/` | 52 s | 74 s | +22 s a job, the new maps' compression |
| `elimination_at_hard` (8 seeds, `tools/match_guards.sh`) | 723 s | 712 s | the same matches: 61 rounds, 0 on time, 2 to the overtime flag, 15 knocks on both |

The matches themselves did not slow; the import costs about 20 s more a job. CI's own times for the Hard job were
21 min 28 s on #336's main run and over 29 min 52 s on #337's: GitHub's runners vary by about half again for the same
work (CI2 measured 702 s and 1,020 s for one unit part), and a 21-minute job has no room for that. Each half now
runs about half of it.

## Checks

- `tools/check.sh` on the branch: changelog notes, wiki, unit tests parts 1 to 7 (6,454 tests, 6,452 passing, the
  rest pending as on main), smoke test, licence notices all pass; gdlint (installed apart) passes on the changed test
  file. `ci.yml` parses as YAML.
- `tools/match_guards.sh test_woodland_guards elimination_at_hard`: Passing Tests 1, 712 s locally (above).
- `tools/match_guards.sh test_woodland_guards attack_defend_at_hard`: Passing Tests 1, 680 s locally beside the unit
  tests (63 rounds over 8 seeds, 36 captures, the flag raised in 8 matches, 0 on time). Each half is about 11 to 12
  minutes, half the job's 30, so a runner half again slower still has room.

## Left as is

- "Woodland, Elimination at Normal" took 28 min 33 s on #337's main run (17 min 17 s on #336's). It is 16 seeds of
  one test, so it cannot be split in `ci.yml` alone; if it is cancelled at the limit, split its seeds in two tests
  (document).
