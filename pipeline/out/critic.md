Task: BP7 A4 · Menus, HUD, audio, report, tests, wiki, release (rows 22, 25, 26, 33, 43, 46, 59, 61, 62, 65, 66, 67, 83, 84, 85, 89, 90, 93, 96, 102)
Attempt: 2 of 4
Head: 8fc90d0 (`git rev-parse HEAD` matches. `--import` clean and leaves the tree clean. Targeted GUT: graphics_guard, run_record, run_record_real_process, ping_markers, match_page, title_and_menus, settings_gameplay, ambience_pair, crash_screen, boot_screen: 179/179 pass, no script errors)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✗ | 8 ✓
Score: 7/8 → Accept (one non-blocking check failed, judgment). Condition: the QA and performance passes are for 0269307, so they should re-confirm 8fc90d0 (RunBeat's thread, the card copies) before merge.
Failed checks, with evidence:
7. [judgment] hud_ping_markers.gd, in _clear: the under-the-plate flip has no test. The second half of test_ping_markers' `test_at_the_top_edge_they_step_clear_and_stay_on_the_screen` says it covers "a ping with no room over Hold here's plate goes under it". But the plate sits 9 px under the ping's top, so the needed push is smaller than the ping's distance from the top. The ping goes up with room to spare, and the test passes without the line (the worker says so, record :49). That test claims coverage it doesn't have. Not a Retry: the row's feature is covered by the four tests that fail on main. Fix it in this pull request: put the ping at the very top, so the push it needs is more than its y (then the test fails without the line), or drop the line.
Must-fix list, attempt 1 → 2:
- Row 85: fixed. graphics_guard.gd saves `at`. held_by_other goes stale after RunRecord.STALE_SECONDS unless that pid's RunBeat is fresh. A pre-BP7 record (at = -1) is decided by pid alone. Tests: test_graphics_guard (stale, beating, another pid's beat, clock set back, a file without `at`), and a whole-Main start that trips on a stale id.
- Bus layout: in Godot's order. A fresh `--import` leaves no diff.
- Pictures: match_page.gd and menu_backdrop.gd use assets/maps/cards/*.jpg (480x270, lossy, mipmapped, 61 KB the four). That is about 0.7 MB of RGBA8 texture each, against the record's +35.0 MB → +5.3 MB on the menus' first open (llvmpipe). test_match_page fails if a card holds a full picture. Only the loading screen keeps the 1920x1080 picture, one at a time.
- Range floor: KNOWN_ISSUES row filed. Tab count corrected (settings_screen.gd:1). The release.yml version stamping is in the record (:35).
RunBeat (game/save/run_beat.gd), new:
- Thread-safe. `_write` is static and touches only its bound arguments (a path, a pid, a time) and its own FileAccess. No member, node or resource is read off the main thread. `beat()` waits for each finished task before adding the next and skips a beat while a write is still going. `_next` changes only on the main thread.
- Shutdown is sound. main.gd `_exit_tree` calls `finish()` after `save_closed`. The Timer is a child, out of the tree first, so no beat can start after `finish()`.
- A write cut short is safe: it truncates to an older time or a bad field count, which `read` passes over (tested). The record isn't rewritten each beat.
- Cost: one bound Callable and one task every 10 s, nothing per frame (check 3).
Owner should test in the game (at most 6, one line each):
- Settings › Gameplay with keyboard and pad. Should the Order wheel's Hover/Click move there too?
- NVDA on the Match page and the Loadout: do cards read their words, and the new ones after a pick?
- Headphones on each field: is the ambience wider and no louder?
- The first open of the Match page (no hitch?), the cards' sharpness at 4K, and the loading picture at 1080p and 4K.
- Two pings close together, and one on Hold here's sign near the top of the screen: do they part gently and stay on screen?
- Open the game twice quickly and wait in the menus a few minutes: does the second copy leave the first alone (no safe-graphics prompt)? Also check Airsoft.exe's icon from the pull request's Release dry run.
