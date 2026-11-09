# CI2 · Unit tests in seven parts

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-09 | 1 | Opus 5.5 (build thread) | see Checks | pending | – |

## Goal

Stop the unit test jobs timing out at random on open pull requests. On main (537fdab) part 1 took 1,020 s of its
1,080 s limit; on PR #263 part 3, 706 s on main, ran out at 1,098 s. The same part runs up to about half as long again
on a slow runner (part 1 took 702 s on #263 and 1,020 s on main), so every part near 12 minutes or more was at risk.

## What was built

- **Seven parts, split by name at a table** (`tools/unit_tests.sh`, `BOUNDS`): part 1 is every file before
  `test_bots_`, then `test_df`, `test_g`, `test_mc`, `test_rg` and `test_torch_` each start a part. `--parts` prints
  the count; without a part the script runs them all in turn. `tools/check.sh` runs and totals every part.
- **CI:** part 1 stays in the job with the smoke test and the notices (job id `godot`, name kept); parts 2 to 7 are one
  matrix job, `unit`, named "Unit tests part N" as before. A step in the `godot` job fails when the script's part
  count and the matrix's disagree, so a new bound can't leave a part unrun.

## Measured (GUT's JUnit times, a cloud session, 2026-11-09)

| Old part | Time | Split at | New parts |
|---|---|---|---|
| 1 (`test_a`..`test_dev`) | 1,114 s | `test_bots_` (after `test_bots.gd`, 194 s alone) | 1: 540 s, 2: 573 s |
| 2 (`test_df`..`test_f`) | not re-timed (CI 610 s on main, 903 s on #263) | – | 3 |
| 3 (`test_g`..`test_re`) | 952 s | `test_mc` | 4: 456 s, 5: 496 s |
| 4 (`test_rg`..`test_z`) | 1,099 s | `test_torch_` | 6: 577 s, 7: 522 s |

## Decisions

- **Part 4 split too.** Not in the brief, but at 838 s on main it was nearer the limit than part 3.
- **Old part 2 kept whole.** At about 10 minutes it has room; the slowest run seen (903 s) is inside the limit.
- **The 1,080 s limit kept.** Smaller parts give the headroom; a hang still stops inside the job's 20 minutes.

## Known issues left

- None.
