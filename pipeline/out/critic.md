Task: SL4 · Sunlit Concrete: menus, HUD and replicas
Attempt: 1 of 4
Head: 64813e3
Checks: 1 ✗ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✗ | 8 ✗
Score: 5/8 → Retry (also: QA and performance reports for the head not on disk)
1. MinimapConfig's ink and map_backdrop still navy 080d18; the replicas' edge scuffs deferred without the
   KNOWN_ISSUES row the record cites.
7. The charcoal copied as literals across pause_menu, report_panel, chevron_shape, hud_sound_cues, graphics_notice,
   hud_order_wheel, crash_screen instead of derived from GameTheme; report_panel's REPORT_INK still cool c8d0dc.
8. docs/FEATURES.md:29 and :72 still say teal; the KNOWN_ISSUES row missing.
Must-fix: minimap inks from GameTheme.BG; dark plates from GameTheme (a shared shade constant); one report ink; the
KNOWN_ISSUES row; FEATURES.md through the changelog agent; QA and performance reports on disk.
