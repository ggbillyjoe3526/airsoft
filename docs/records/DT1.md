# DT1 · Sniper Rifle public, The Street dev

**Review:** pending

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

## Defaults taken

- **No High Output Battery.** The only "High Output Battery" is pool.md's worked example of adding a battery, not a real
  item (no stats row, no level), so nothing was changed for it; told the owner.
