Task: CI3 · QA commit pending · Verdict: Pass

Blocking: none. Advisory: none.

Checked (static, no match guards or full suite re-run, as instructed):
- Each of the six night-guards matrix `test:` values (elimination_at_normal, elimination_at_easy, attack_defend_at_normal, attack_defend_at_easy, elimination_at_hard, attack_defend_at_hard) is a substring of exactly one test in tests/guards/test_woodland_guards.gd (lines 11-32); together they cover all six tests. No value is a substring of another test name.
- Log names are unique across ci.yml (guards-1..4, plant-guards-1..3, night-guards-1..6); no duplicates, so artifact names cannot collide.
- No remaining reference to `at_hard` (as a job id) or "both modes at Hard" outside docs/records history; only a comment in ci.yml:232 describing why the split was made, and test names/comment in the guard file.

Tests added: none (config-only change; the matrix is the test).
Not testable here: the real CI run time of each half (local runs 712 s and 680 s per the task, under the 30 min limit).
