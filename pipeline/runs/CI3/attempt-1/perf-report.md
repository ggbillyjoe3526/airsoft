Task: CI3 · head cd73330 · Verdict: Pass
Run: no game run by me (config-only; match guards not re-run as instructed) · budget: no baseline yet; judged on the record's measurements, CI history and the 30 min job limit
Metrics: no runtime code changed (ci.yml, test header comment, tests/README.md, record). Node count, orphans, memory, draw calls: n/a.
Record's figures (judgment, not re-measured): clean import 52 s -> 74 s; elimination_at_hard 723 s -> 712 s, same outcomes; attack_defend_at_hard 680 s.
Regressions (> 10 % worse): none attributable to the diff. Import +22 s a job (+42 %) comes from MQ3 (#337) assets, not this change; advisory.
Blocking findings: none
Advisory:
- docs/records/CI3.md: conclusion is sound. Match time unchanged (-1.5 %) with identical outcomes, so MQ3 added no per-match cost; the Hard job was ~23 min of work (723+680 s) locally, so a 21.5 min CI run vs >29.9 min is about 1.4x runner variance. Weak points: one run per side, on a 4-core cloud box, not the runner. The text says +20 s, the table +22 s; trivial.
- .github/workflows/ci.yml:246-247: each half is ~11-12 min locally (+ ~1.5 min import/setup). A runner 1.4x slower gives ~17 min, 2x gives ~24 min; headroom is adequate, about 2.5x.
- Extra runner job: acceptable. Jobs run in parallel; total runner minutes rise only by one extra checkout, Godot fetch and import (~2-3 min). No wall-clock cost, since the longest job gets shorter.
- Not fixed: "Woodland, Elimination at Normal" took 28 min 33 s on #337's main run (16 seeds, one test). It is the next job to be cancelled; the record notes splitting its seeds as a follow-up. Worth a task.
Fixes: none required.
Unexplained: why the Hard job went from 21 min 28 s to >29 min 52 s; runner variance fits (Normal Elimination also moved 17 -> 28 min with no match-time change), but is not proven.
