Task: CI3 · Woodland's Hard night guards in two jobs
Attempt: 1 of 4
Head: 420790b (checks on cd73330; only the run's reports differ)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✗
Score: 7/8 → Accept

1. Brief met: ci.yml's `at_hard` entry is `elimination_at_hard` (night-guards-5) and `attack_defend_at_hard`
   (night-guards-6); the six `test:` values match the file's six tests one each. Halves 712 s and 680 s locally. The
   MQ3 cause checked: 723 s before, 712 s after, same outcomes; import +22 s.
2-5. No contract, runtime or gameplay code touched; no new tests needed for a config-only change.
6. Nothing players see; no changelog note is right.
7. Comments and docs consistent (ci.yml, test header, tests/README.md; pipeline/README.md already said six).
8. [judgment] Elimination at Normal (28 min 33 s on #337's main run) left only in the record, no KNOWN_ISSUES row or
   task. Fixed after the verdict: a Release row in docs/KNOWN_ISSUES.md.

Also noted: "about 20 s" vs +22 s (fixed); a required check named for the old job would need the new names.
Owner should test: nothing in the game; on the PR's run both Hard halves finish well under 30 minutes.
