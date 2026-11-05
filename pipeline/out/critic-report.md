Task: AU8 · One dry click for every replica; the range sounds like The Street
Attempt: 2 of 4
Head: a9511d2 (QA and performance Pass on 10ca090; a9511d2 adds only docs, the reports and the changelog note)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept
Failed checks, with evidence: none.
1. game/play/sim_audio.gd +46 DRY_CUE, +169 loaded once, +231 played for every profile; data/maps/range.json +3 "street".
2. No contract in ARCHITECTURE › Contracts touched.
3. DRY_FIRE plays a constant StringName; nothing allocated (performance agrees).
4. tests/unit/test_recordings.gd +170 fails on main (electric, spring, cyber played dryFire_<p>); covers a later profile.
7. Renames byte-identical, the five UIDs match origin/main; no stale dryFire_<profile> or _dry references.
8. DECISIONS, audio README, ASSETS, wiki Replicas and Practice-Range, record (Cyber Pistol default stated), changelog
   note (no Sniper Rifle named). Advisory, not blocking: two lines still over 120 columns after the rewrap,
   docs/ASSETS.md:74 (172) and docs/wiki/Practice-Range.md:5 (180).
Must-fix for the next attempt: none. Optional: rewrap those two lines.
Owner should test in the game:
- An empty AEG Rifle, trigger pulled: the pistol's click, no motor.
- The same on the spring rifle and the Cyber Pistol: the same click at the same level.
- The click is audible over handling and ambience.
- Practice range by day: The Street's bed and calls, no yard.
- Practice range with Dev › Time of day at night: The Street's night set.
