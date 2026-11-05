Task: MAG1 · the alternative magazines · head ae1a9fc (attempt 1; attempt 2 keeps the same budgets) · Verdict: Pass (advisories only)
Run: no game/ code changed; judged from the files against docs/CC0_ASSETS.md › Size limits.

Metrics
- aeg.glb (replicaParts) 355 KB -> ~0.76 MB; with BL8 (#205, 1.37 MB with the old magazines) about 1.8 MB of 2 MB.
- pistol.glb (replicaParts) 123 KB -> ~0.33 MB.
- Parts 8,410 to 9,700 triangles (attempt 2), under 10,000 each; figure copies 44, 44, 28.

Draw path (code)
- replica_parts.gd: figures load only the `<part>_Figure` copy; the full part is drawn only in the player's hands and
  on menu pictures. The replica's own magazine is hidden, not drawn, while a part is fitted.
- Figures' hand-carried magazines and tosses use the replica's own magazine mesh: unaffected.

Regressions (>10 % worse): none measured.

Advisories
1. First person with a hi-cap: the held AEG draws about 47k triangles (40k replica less its 2.3k magazine plus the
   part). Parts have their own 10k budget; trivial for Forward+ on desktop.
2. Parts load per fit and are freed with their holder; mesh resources cached by ResourceLoader, paid once a session.
3. Nothing enforced the 2 MB parts-file limit: test_magazine_models.gd now does (attempt 2).
