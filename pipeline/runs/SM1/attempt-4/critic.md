Task: SM1 · Subway's trains in their models · Attempt 4 of 4 · Head 438c9aa
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✗ — Score 7/8 → Accept (non-blocking judgment miss).
1. The pale strip by the open cab is gone (sm1-ends-final/3 and /4): flush wall faces looking into a train box take its lining finish (station_surface.gd `_train_round`, `_round_finish`); the cars' lamps leave the station surface's layer out (roof_view.gd hide_lamps_in `unlit`, roof_lamps.gd leave_out).
2. No contract changed (hide_lamps_in gained a defaulted parameter).
3. No per-frame work; build-time allocations only.
4. test_trains reads ARRAY_CUSTOM0 on every train box side vertex (fails without the fix); mask and layer tests.
5. Named constants LAYER, LINING_REACH, LINING_INSET; typed.
6. The tunnel reads plausibly; no camera or light mask leaves bit 16 out.
7. Stray pipeline/out duplicates and committed raw QA dumps.
8. QA's 57eb0b8 overwrote main's tests/unit/test_sm1_qa.gd (18 match-summary tests). Must-fix before merge: restore it, move the layer test to its own file, drop the raw dumps, re-run the checks (total +18).
Owner checks: south open cab from the track (even concrete); cars bright inside, players lit; the platform floor by open doors without car-light spill; the trains through a scope; the north car's widest point against the trackside wall; platform walls by the cars.
