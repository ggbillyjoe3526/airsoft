Task: none (SD1) · QA commit pending · Verdict: Pass

Blocking: none. Advisory: PropDressConfig.named_only() caches a duplicate; edits to `models`/other fields on the source config after the first call are not reflected (shipped config is a loaded resource, so harmless today). A dress naming an unknown model warns once and keeps the box (checked).

Tests added:
- tests/unit/test_station_dress.gd · named model that fails to load: StationSurface still draws the box (vertex count unchanged), PropDress.build is null, and the Depot map still kind-dresses · fails if mesh() skipped on b.dress alone rather than props.dresses(b).
- (dev's two tests reviewed: crate-naming and named_only idempotence/no-kind; both meaningful.)

Checked, no bug: Subway colliders equal the greybox's (existing test); non-station maps keep full props (PlaySession else-branch, MapLevel only narrows when _station != null); TILE/cored blocks keep boxes.
Suite: test_station_dress.gd 22/22 pass, 3.8s. Full tools/check.sh run separately by the lead.
Not tested: visual look of a named prop on a real station (needs display); no Subway block names a model yet.
