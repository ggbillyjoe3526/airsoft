Task: none (UR1 part 1) · head bb3d796 (re-read on 89d8286 and the attempt-2 head) · Verdict: Pass
Run: no match run (menus only; a match never builds them). Diff read; the backdrop's blur timed headless with the real MenuBackdrop.blurred.
Per-frame work: none added. NavRail, MenuBackdrop, MenuScreen and Settings › About have no _process, Timer or tween; the backdrop draws two textured rects. NavRail.set_current builds two StyleBoxFlats a tab on a tab change only.
Backdrop blur (measured): 15 to 20 ms a pick on the main thread at bb3d796 (the cubic grow to 384x216 was the cost). Advisory taken in 89d8286: blurred once a path for the run (static cache, four fields about 1 MB) and grown bilinear, so a pick or the menus' rebuild after a match costs no frame.
Fonts and styleboxes: the FontVariation caches are keyed by constants only (bounded at a few dozen); the three Barlow faces (about 63 KB) load on first heading and stay for the run.
Teardown: Settings, About, the report panel and the credits are freed or kept as before; About's signals connect once an instance; the backdrop goes with the menus when a match starts.
Blocking findings: none. Regressions: none measured.
