# QA report: UF2 (Loadout SWITCH REPLICA click, no double-click Customise)

Verdict: **Pass**

## Run
- tests/unit/test_uf2_clicks.gd: 4/4 pass (15 asserts), clicks pushed through the viewport (motion, press, release).
- Fails without the fix: with origin/main's loadout_gear.gd restored, 4/4 fail; fix restored afterwards (git diff clean of my probing).
- No production or test edits by QA.

## Hunt
- Same bug elsewhere: every `add_content` caller (loadout_switch, settings_access_page, part_page, customise_view x4,
  match_page x2, loadout_strip x2) wraps display content only (labels, swatches, stat rows). The Buttons/Sliders in those
  files (_close, _back, _play, LoadoutSlider, cue-size HSlider, _link) are added outside a card's pad. Only loadout_gear
  had controls inside a card, and both (CUSTOMISE, SWITCH REPLICA) now get STOP after add_content.
- `MouseFilter` STOP set before add_content anywhere in game/ui: none (the grep for MOUSE_FILTER_STOP shows only
  shades/overlays, menu_parts._lock, turntable, armory dots).
- Removed `_double_click`: no remaining references in game/ or tests/. `customise_requested` still wired from the CUSTOMISE button only.
- Docs: docs/PLAYTEST.md updated (line 1198). docs/KNOWN_ISSUES.md:110 still lists "mouse double-click on a carried card"
  as needing a real display; now stale (minor, docs only).
- Residual: menu_parts._lock re-enables STOP on any BaseButton in a locked-then-unlocked subtree, so unlocking a card
  containing the buttons restores STOP (fine); cards are not locked on this page.

## Not verifiable here
Real-mouse feel on a display: click SWITCH REPLICA on each carried card, double-click a card (only picks it), CUSTOMISE opens it.
