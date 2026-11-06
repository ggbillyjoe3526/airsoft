# DT1 · Sniper Rifle public, The Street dev

**Review:** 1 attempt · critic Accept 7/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-05 | 1 | Opus 5.5 (project thread) | ✓ | 7/8 Accept | – (check 8: a waiting changelog line and a PLAYTEST intro still called the rifle dev; fixed) |

## The ask

The owner, 2026-11-05: "Sniper rifle and parts should now be public. Same for high output battery. The Street map is
now Dev only."

## What changed

- `data/pool.md`: the Sniper Rifle (000021), the M130, M140 and M150 Springs (000022 to 000024) and the Variable Scope
  (000025) are tagged `public`. `data/maps.md`: The Street is tagged `dev`.
- The Variable Scope gets the Customise and Armory blurb it never had (`PART_BLURB_SCOPEVAR`, `en.po`), found once it
  showed with Dev content off.
- Wiki: a Sniper Rifle section (Replicas), springs and the Variable Scope (Parts and Power), The Street off Maps and
  Bots and into the Roadmap's In development. The waiting changelog notes lose their "(dev content)" tags.
- Tests: the dev-gating tests that leaned on the rifle keep their cover by tagging it dev in their own pool
  (`test_sn1_qa.gd`, `test_bp3.gd`); the shipped-tag tests follow the new tags.
- KNOWN_ISSUES: the bare level 7 row is gone (the M140 is public); the Woodland sniper lean row now says players meet it.

## Review fixes

- QA: `test_no_dev_maps_listed_with_dev_content_off` still listed The Street (fixed); the UR2 text-fit tests pick The
  Street with Dev content on so they still measure its text; PLAYTEST, ROADMAP, KNOWN_ISSUES and the wiki's NOT KEPT
  line follow the tags.
- Critic: `changelog.d/bug-pass-full-game.md` no longer says sniper gear runs are not kept; PLAYTEST's SN1 intro drops
  Dev content.

## CI's finding

- The Street's night guards on Easy failed at seed 7: a Sniper-kit bot (bots carry the rifle without Dev content now)
  knocked out a teammate 1 m away. Armament keeps a press made while a bolt-action cycles until the bolt is home
  (bolt_press_window), up to most of a second after the bot's line-of-fire check. Bots now never press while the bolt
  is still worked (`BotCombat._bolt_cycling`; `tests/unit/test_dt1_qa.gd`, which fails without it). Seed 7 has no
  friendly hit and the Street night guards pass. QA and performance Pass; the shorter press_buffer keep on every
  replica is a KNOWN_ISSUES row.

## Defaults taken

- **No High Output Battery.** The only "High Output Battery" is pool.md's worked example of adding a battery, not a real
  item (no stats row, no level), so nothing was changed for it; told the owner.
- **The Woodland sniper lean row stays "can wait".** SN3 measured 55 to 60 % for end 0 with sniper bots; players meet
  it now, so it is in the owner's playtest list (PLAYTEST › DT1) rather than re-tuned here.
