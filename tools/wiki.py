#!/usr/bin/env python3
"""The game's wiki: docs/wiki/ holds one Markdown file per page, published to the repository's GitHub wiki by
.github/workflows/wiki.yml on every merge to main. docs/wiki/README.md explains the conventions.

Numbers are never typed into a page: a page holds a marker line such as `<!-- wiki:replicas -->` and the build puts a
table there, read from the game's own data (data/*.md, the map files, the key bindings, the text file). Patch-Notes is
written from changelog.d/ and CHANGELOG.md. Dev content (dev maps and gear) is named only on the pages in
DEV_PAGES or under an "In development" heading, and the hidden Easter egg nowhere (docs/DECISIONS.md).

Usage:
  python3 tools/wiki.py check [--base REF]   CI: build the pages, then check links, headings, the sidebar, dev and
                                             hidden content and that every public item is named. With --base, warn
                                             when a change adds a changelog note but leaves docs/wiki/ untouched.
  python3 tools/wiki.py build OUT            write the publishable wiki to OUT
"""
import json
import math
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WIKI = ROOT / "docs" / "wiki"
DATA = ROOT / "data"
# Never published: the contributor notes for the folder.
SKIP = {"README.md", ".gdignore"}
# Pages the build writes itself.
GENERATED_PAGES = {"Patch-Notes"}
# Pages that may name dev content anywhere: what is coming, and the developers' page that explains the Dev switch.
DEV_PAGES = {"Roadmap", "Development"}
# Dev content the data tables don't tag (night play and glowing BBs went public with Woodland, owner 2026-10-29).
# Data-tagged dev maps and pool items are added to this list at run time.
EXTRA_DEV_TERMS = ["dev content"]
# Named nowhere, not even as dev content: robots are a hidden Dev-only Easter egg (DECISIONS, owner 2026-10-24).
HIDDEN_RE = re.compile(r"robot", re.I)
# Key-binding actions that belong to a pool item: listed only while the item is public.
ACTION_ITEMS = {"torch": "Weapon Torch"}
MARKER_RE = re.compile(r"^<!-- wiki:([a-z-]+)(?: ([A-Za-z0-9_.-]+))? -->$")
LINK_RE = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")
HEADING_RE = re.compile(r"^(#{1,6})\s+(.*?)\s*#*\s*$")


class WikiError(Exception):
    """A source the wiki is built from can't be read; the message names the file."""


def rel(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


# --- Reading the sources -----------------------------------------------------------------------------------------


def md_tables(path: Path) -> list:
    """Every table in a Markdown file, as (heading line above it, the '## ' section it is in, rows as dicts)."""
    out = []
    heading = section = ""
    header = None
    rows: list = []
    for line in path.read_text(encoding="utf-8").splitlines() + [""]:
        if line.startswith("|"):
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if header is None:
                header = cells
            elif not all(re.fullmatch(r":?-+:?", c) for c in cells):
                rows.append(dict(zip(header, cells)))
            continue
        if header is not None:
            out.append((heading, section, rows))
            header, rows = None, []
        if line.startswith("#"):
            heading = line.strip()
            if line.startswith("## "):
                section = heading
    return out


def md_table(path: Path, heading: str) -> list:
    """The table under the heading line `heading` (such as '## Replicas')."""
    for h, _, rows in md_tables(path):
        if h == heading:
            return rows
    raise WikiError(f"{rel(path)} has no table under '{heading}'")


def cell(row: dict, column: str, path: Path) -> str:
    if column not in row:
        raise WikiError(f"{rel(path)}: a table has no '{column}' column")
    return row[column]


def pool() -> list:
    """Every item in data/pool.md › Assets: dicts with Name, Key or Type, Fits or Tags, Access."""
    path = DATA / "pool.md"
    items = []
    for heading, section, rows in md_tables(path):
        if section != "## Assets":
            continue
        for row in rows:
            name, access = cell(row, "Name", path), cell(row, "Access", path)
            if access not in ("public", "dev"):
                raise WikiError(f"{rel(path)}: '{name}' has Access '{access}', not public or dev")
            items.append(dict(row, kind=heading.lstrip("# ")))
    if not items:
        raise WikiError(f"{rel(path)} lists no items under '## Assets'")
    return items


def public_names() -> set:
    return {i["Name"] for i in pool() if i["Access"] == "public"}


def maps() -> list:
    path = DATA / "maps.md"
    rows = md_table(path, "## Maps")
    for row in rows:
        if cell(row, "Tag", path) not in ("public", "dev"):
            raise WikiError(f"{rel(path)}: map '{row['Id']}' has Tag '{row['Tag']}', not public or dev")
    return rows


def dev_terms() -> list:
    terms = list(EXTRA_DEV_TERMS)
    terms += [i["Name"] for i in pool() if i["Access"] == "dev"]
    terms += [m["Name"] for m in maps() if m["Tag"] == "dev"]
    return terms


def unlock_levels() -> dict:
    """Item name -> the level that unlocks it, from data/levels.md."""
    path = DATA / "levels.md"
    out = {}
    for row in md_table(path, "## Levels"):
        for name in filter(None, (n.strip() for n in cell(row, "Unlocks", path).split(","))):
            out[name] = int(cell(row, "Level", path))
    return out


def po_strings() -> dict:
    """msgid -> msgstr from the game's English text (game/ui/text/en.po), multi-line strings joined."""
    out = {}
    key = None
    field = ""
    for line in (ROOT / "game/ui/text/en.po").read_text(encoding="utf-8").splitlines():
        m = re.match(r'^(msgid|msgstr) "(.*)"$', line)
        if m:
            field = m.group(1)
            if field == "msgid":
                key = m.group(2)
                out[key] = ""
            elif key is not None:
                out[key] = m.group(2)
        elif line.startswith('"') and key is not None and field == "msgstr":
            out[key] += line[1:-1]
    return out


def gd_defaults(path: Path) -> dict:
    """`@export var name: Type = value` defaults from a tuning script, as strings."""
    found = re.findall(r"^@export var (\w+):\s*\w+\s*=\s*(.+?)\s*(?:#.*)?$", path.read_text(encoding="utf-8"), re.M)
    if not found:
        raise WikiError(f"{rel(path)} has no '@export var name: Type = value' lines")
    return dict(found)


def gd_const(path: Path, name: str) -> str:
    m = re.search(rf"^const {name}\b[^=]*=\s*(.+)$", path.read_text(encoding="utf-8"), re.M)
    if not m:
        raise WikiError(f"{rel(path)} has no const {name}")
    return m.group(1).strip()


def sentence(label: str) -> str:
    """'RENDER SCALE' -> 'Render scale'."""
    return label[:1].upper() + label[1:].lower() if label.isupper() else label


def num(text: str) -> float:
    return float(text.replace("−", "-"))


def fmt(value: float) -> str:
    return f"{value:g}"


def mins(seconds: float) -> str:
    return f"{int(seconds) // 60}:{int(seconds) % 60:02d}"


# --- The generated tables ----------------------------------------------------------------------------------------


def table(header: list, rows: list) -> str:
    lines = ["| " + " | ".join(header) + " |", "|" + "---|" * len(header)]
    lines += ["| " + " | ".join(str(c) for c in row) + " |" for row in rows]
    return "\n".join(lines)


def level_label(level) -> str:
    return "–" if level is None else ("from the start" if level == 0 else f"level {level}")


def replica_items() -> list:
    return [i for i in pool() if i["kind"] == "Replicas" and i["Access"] == "public"]


def fits_names(fits: str) -> str:
    """The public replicas a part fits, from its Fits tags against the replicas' Tags."""
    want = {t.strip() for t in fits.split(",")}
    names = [r["Name"] for r in replica_items() if want & {t.strip() for t in r["Tags"].split(",")}]
    return ", ".join(names) or "–"


def gen_replicas(_arg: str) -> str:
    """The replicas side by side: one column each, one row per stat (data/stats.md › Replicas)."""
    path = DATA / "stats.md"
    stats = {cell(r, "Key", path): r for r in md_table(path, "## Replicas")}
    limits = {r["Class"]: r["Limit (J)"] for r in md_table(path, "## Site limits")}
    levels = unlock_levels()
    cols = []
    for item in replica_items():
        if item["Key"] not in stats:
            raise WikiError(f"{rel(path)} › Replicas has no row for '{item['Key']}' ({item['Name']})")
        cols.append((item, stats[item["Key"]]))
    if not cols:
        raise WikiError("data/pool.md lists no public replica")

    def speed(s: dict) -> str:
        return f"{math.sqrt(2 * num(s['Energy (J)']) / (num(s['BB (g)']) / 1000)):.0f} m/s"

    rows = [
        ("Class", lambda i, s: s["Class"]),
        ("Unlocks", lambda i, s: level_label(levels.get(i["Name"]))),
        ("Muzzle energy", lambda i, s: f"{s['Energy (J)']} J"),
        ("Factory BB weight", lambda i, s: f"{s['BB (g)']} g"),
        ("Muzzle speed", lambda i, s: speed(s)),
        ("Fire rate", lambda i, s: f"{s['Fire rate (BBs/s)']} BBs/s"),
        ("Magazine", lambda i, s: f"{s['Magazine (BBs)']} BBs"),
        ("Magazines carried", lambda i, s: s["Magazines"]),
        ("Reload", lambda i, s: f"{s['Reload (s)']} s"),
        ("Draw", lambda i, s: f"{s['Draw (s)']} s"),
        ("Spread from the hip", lambda i, s: f"{s['Spread (°)']}°"),
        ("Recoil per shot", lambda i, s: f"{s['Recoil (°)']}°"),
        ("Site limit", lambda i, s: f"{limits.get(s['Class'], '–')} J"),
    ]
    try:
        body = [[f"**{label}**"] + [get(i, s) for i, s in cols] for label, get in rows]
    except (KeyError, ValueError) as e:
        raise WikiError(f"{rel(path)} › Replicas: a column or number can't be read ({e})") from e
    return table([""] + [i["Name"] for i, _ in cols], body)


def part_value(column: str, value: str) -> str:
    """A stats cell as a player reads it: '%' columns signed, '(×)' columns as ×n, '(+)' signed, 1 or 0 as '–'."""
    v = value.strip()
    if v in ("", "–", "-"):
        return "–"
    if column.endswith("%"):
        n = num(v)
        return "–" if n == 0 else f"{n:+g} %"
    if column.endswith("(×)"):
        n = num(v)
        return "–" if n == 1 else f"×{n:g}"
    if column.endswith("(+)"):
        n = num(v)
        return "–" if n == 0 else f"{n:+g}"
    return v


def part_column(column: str) -> str:
    return re.sub(r"\s*(%|\(×\)|\(\+\))$", "", column)


PART_SECTIONS = {
    "power": ("## Power sources", "Power sources"),
    "optics": ("## Optics", "Optics"),
    "grips": ("## Grips", "Grips"),
    "lasers": ("## Lasers", "Lasers"),
    "magazines": ("## Magazines", "Magazines"),
    "barrels": ("## Barrels", "Barrels"),
    "muzzle": ("## Muzzle parts", "Muzzle parts"),
    "lights": ("## Lights", "Lights"),
}


def gen_parts(which: str) -> str:
    """One kind of part (data/stats.md section, names, fits and access from pool.md), public items only."""
    if which not in PART_SECTIONS:
        raise WikiError(f"unknown part kind '{which}': one of {', '.join(PART_SECTIONS)}")
    heading, kind = PART_SECTIONS[which]
    path = DATA / "stats.md"
    rows = md_table(path, heading)
    items = [i for i in pool() if i["kind"] == kind]
    by_id = {i.get("Key") or i.get("ID"): i for i in items} | {i["ID"]: i for i in items}
    levels = unlock_levels()
    stat_cols = [c for c in (rows[0] if rows else {}) if c not in ("Key", "ID", "Name")]
    have = {row.get("Key") or row.get("ID") for row in rows}
    for item in items:
        if item["Access"] == "public" and item.get("Key", item["ID"]) not in have and item["ID"] not in have:
            raise WikiError(f"{rel(path)} › {heading.lstrip('# ')} has no row for '{item['Name']}'")
    out = []
    for row in rows:
        ident = row.get("Key") or row.get("ID")
        item = by_id.get(ident)
        if item is None:
            raise WikiError(f"{rel(path)} › {heading.lstrip('# ')}: '{ident}' isn't in data/pool.md")
        if item["Access"] != "public":
            continue
        fits = fits_names(item["Fits"]) if "Fits" in item else "–"
        if kind == "Power sources":
            fits = fits_names(item["Fits"]) + f" ({item['Type']})"
        out.append([f"**{item['Name']}**", fits, level_label(levels.get(item["Name"]))]
                   + [part_value(c, row[c]) for c in stat_cols])
    if not out:
        return "_None in the game yet._"
    return table(["", "Fits", "Unlocks"] + [part_column(c) for c in stat_cols], out)


def gen_site_limits(_arg: str) -> str:
    path = DATA / "stats.md"
    rows = []
    for r in md_table(path, "## Site limits"):
        names = [i["Name"] for i in replica_items() if r["Class"] in {t.strip() for t in i["Tags"].split(",")}]
        rows.append([r["Class"].capitalize(), f"{cell(r, 'Limit (J)', path)} J", ", ".join(names) or "–"])
    return table(["Class", "Most energy allowed", "Replicas"], rows)


def gen_unlocks(_arg: str) -> str:
    path = DATA / "levels.md"
    public = public_names()
    rows = []
    total = 0
    for r in md_table(path, "## Levels"):
        total += int(cell(r, "XP", path))
        names = [n.strip() for n in cell(r, "Unlocks", path).split(",") if n.strip() in public]
        if names:
            level = int(r["Level"])
            rows.append([f"**{level}**" + (" (start)" if level == 0 else ""), r["XP"], total, ", ".join(names)])
    return table(["Level", "XP for this level", "XP in all", "Unlocks"], rows)


def gen_xp(_arg: str) -> str:
    path = DATA / "levels.md"
    tables = [rows for h, _, rows in md_tables(path) if h == "## XP"]
    if len(tables) < 2:
        raise WikiError(f"{rel(path)} › XP needs its event table and its difficulty table")
    events, mult = tables[0], tables[1]
    a = table(["What you did", "XP"], [[cell(r, "Event", path), cell(r, "XP", path)] for r in events])
    b = table(["Bots", "XP multiplier"],
              [[cell(r, "Difficulty", path), f"×{cell(r, 'Multiplier', path)}"] for r in mult])
    return a + "\n\n" + b


def team_sizes(m: dict) -> str:
    lo, std, hi = m["Min"], m["Standard"], m["Max"]
    if m["Kind"] == "range":
        return "solo"
    if lo == hi:
        return f"{lo}v{lo}"
    return f"{lo}v{lo} to {hi}v{hi} (usual {std}v{std})"


def round_of(m: dict) -> str:
    """A field's Skirmish round (its Round cell, else the round tuning's); none on the range."""
    if m["Kind"] == "range":
        return "–"
    own = m.get("Round", "").strip()
    if own:
        return mins(num(own))
    return mins(float(gd_defaults(ROOT / "game/config/round_config.gd")["round_time"]))


def gen_maps(_arg: str) -> str:
    rows = []
    for m in maps():
        if m["Tag"] != "public":
            continue
        kind = {"field": "Field", "range": "Practice range"}.get(m["Kind"], m["Kind"])
        rows.append([f"**[{m['Name']}](Maps#{slug(m['Name'])})**", kind, team_sizes(m), round_of(m), m["Blurb"]])
    return table(["Map", "Kind", "Team sizes", "Round", "About"], rows)


def public_map(map_id: str) -> dict:
    for m in maps():
        if m["Id"] == map_id:
            if m["Tag"] != "public":
                raise WikiError(f"docs/wiki asks for '{map_id}', a dev map: dev maps stay off the public pages")
            return m
    raise WikiError(f"data/maps.md has no map '{map_id}'")


def gen_areas(map_id: str) -> str:
    public_map(map_id)
    path = DATA / "maps" / f"{map_id}.json"
    areas = [a.get("name") for a in json.loads(path.read_text(encoding="utf-8")).get("areas", [])]
    if not areas:
        raise WikiError(f"{rel(path)} names no areas")
    return ", ".join(f"**{a}**" for a in sorted(set(filter(None, areas))))


def gen_range_targets(_arg: str) -> str:
    public_map("range")
    path = DATA / "maps" / "range.json"
    groups: dict = {}
    for t in json.loads(path.read_text(encoding="utf-8")).get("targets", []):
        label = t.get("label") or t.get("kind", "?")
        groups.setdefault(label, []).append(t.get("distance"))
    if not groups:
        raise WikiError(f"{rel(path)} has no targets")
    rows = []
    for label, dists in groups.items():
        ds = sorted({d for d in dists if d is not None})
        where = ", ".join(f"{fmt(d)} m" for d in ds)
        rows.append([f"**{label}**", len(dists), where])
    return table(["Target", "How many", "Distance"], rows)


KEY_NAMES = {
    "SHIFT": "Shift", "ALT": "Alt", "CTRL": "Ctrl", "SPACE": "Space", "TAB": "Tab", "UP": "Up arrow",
    "DOWN": "Down arrow", "LEFT": "Left arrow", "RIGHT": "Right arrow", "PAGEUP": "Page Up", "PAGEDOWN": "Page Down",
    "ENTER": "Enter", "BACKSPACE": "Backspace", "CAPSLOCK": "Caps Lock",
}
MOUSE_KEYS = {"LEFT": "KEY_MOUSE_LEFT", "RIGHT": "KEY_MOUSE_RIGHT", "MIDDLE": "KEY_MOUSE_MIDDLE",
              "WHEEL_UP": "KEY_WHEEL_UP", "WHEEL_DOWN": "KEY_WHEEL_DOWN", "XBUTTON1": "KEY_MOUSE_4",
              "XBUTTON2": "KEY_MOUSE_5"}


def gen_controls(_arg: str) -> str:
    """The default keys, in the order Settings › Controls lists them (game/input/key_bindings.gd, en.po names)."""
    path = ROOT / "game/input/key_bindings.gd"
    src = path.read_text(encoding="utf-8")
    order = re.findall(r'&"(\w+)"', re.search(r"const ACTIONS[^=]*=\s*\[(.*?)\]", src, re.S).group(1))
    defaults = dict(re.findall(r'^\s*&"(\w+)":\s*\[(.*?)\],?$', src, re.M))
    po = po_strings()
    public = public_names()
    rows = []
    for action in order:
        if action in ACTION_ITEMS and ACTION_ITEMS[action] not in public:
            continue
        label = po.get(f"ACT_{action.upper()}")
        if not label:
            raise WikiError(f"game/ui/text/en.po has no ACT_{action.upper()} for the '{action}' key")
        keys = []
        for code in filter(None, (c.strip() for c in defaults.get(action, "").split(","))):
            m = re.fullmatch(r"KEY_(\w+)", code)
            mm = re.fullmatch(r"-MOUSE_BUTTON_(\w+)", code)
            if m:
                k = m.group(1)
                keys.append(KEY_NAMES.get(k, k if len(k) == 1 else None))
            elif mm and mm.group(1) in MOUSE_KEYS:
                keys.append(po.get(MOUSE_KEYS[mm.group(1)]))
            else:
                keys.append(None)
            if keys[-1] is None:
                raise WikiError(f"{rel(path)}: no name for the key {code}; add it to KEY_NAMES in tools/wiki.py")
        rows.append([sentence(label), " or ".join(f"**{k}**" for k in keys) or "–"])
    return table(["Action", "Keys"], rows)


def gen_graphics(_arg: str) -> str:
    path = DATA / "graphics.md"
    po = po_strings()
    rows = []
    for r in md_table(path, "## Rows"):
        label = po.get(cell(r, "Label", path), r["Label"])

        def show(v: str) -> str:
            return po.get(f"GRAPHICS_CHOICE_{v.upper()}", v)

        rows.append([f"**{sentence(label)}**"] + [show(r[p]) for p in ("Low", "Medium", "High", "Ultra")])
    return table(["Setting", "Low", "Medium", "High", "Ultra"], rows)


def gen_personalities(_arg: str) -> str:
    path = DATA / "bots.md"
    roster: dict = {}
    for r in md_table(path, "## Roster"):
        roster.setdefault(cell(r, "Personality", path), []).append(r["Name"])
    rows = []
    for r in md_table(path, "## Personalities"):
        p = cell(r, "Personality", path)
        note = cell(r, "Card note", path).replace("{name}", "This bot")
        rows.append([f"**{p}**", note, ", ".join(roster.get(p, []))])
    return table(["Personality", "How it plays", "Names"], rows)


def gen_bot_kits(_arg: str) -> str:
    path = DATA / "bot-kits.md"
    public = public_names()
    rows = []
    for r in md_table(path, "## Kits"):
        gear = [r.get("Primary", ""), r.get("Secondary", "")]
        gear += [p.strip() for p in (r.get("Primary parts", "") + "," + r.get("Secondary parts", "")).split(",")]
        if any(g and g not in public for g in gear):
            continue

        def carry(replica: str, parts: str) -> str:
            return f"{replica} with {parts}" if parts else f"{replica} as it comes"

        rows.append([f"**{cell(r, 'Kit', path)}**",
                     carry(r["Primary"], r.get("Primary parts", "")),
                     carry(r["Secondary"], r.get("Secondary parts", "")) if r.get("Secondary") else "–"]
                    + [f"{r.get(d) or 0} %" for d in ("Easy", "Normal", "Hard")])
    return table(["Kit", "Primary", "Sidearm", "Easy", "Normal", "Hard"], rows)


def gen_rules(_arg: str) -> str:
    """Skirmish's rules (the round and hit tuning defaults) beside what a Custom match can set."""
    rounds = gd_defaults(ROOT / "game/config/round_config.gd")
    hits = gd_defaults(ROOT / "game/config/hit_config.gd")
    custom = ROOT / "game/save/custom_rules.gd"
    wins = gd_const(custom, "WINS_NEEDED").strip("[]")
    lo, hi = (float(x) for x in re.findall(r"[\d.]+", gd_const(custom, "ROUND_TIME_RANGE").partition("(")[2]))
    step = float(gd_const(custom, "ROUND_TIME_STEP"))
    try:
        on = {"true": "On", "false": "Off"}
        rows = [
            ["Team size", "the map's usual size", "the sizes the map offers ([Maps](Maps))"],
            ["Rounds to win", f"first to {rounds['wins_needed']}",
             "first to " + ", ".join(w.strip() for w in wins.split(",")[:-1]) + " or " + wins.split(",")[-1].strip()],
            ["Round time", mins(float(rounds["round_time"])) + ", or the map's own ([Maps](Maps))",
             f"{mins(lo)} to {mins(hi)}, in {fmt(step)} s steps"],
            ["Friendly fire", on[hits["friendly_fire"]], "On or Off"],
            ["Ricochets knock you out", on[hits["ricochets_count"]], "On or Off"],
            ["Ends swap", f"after round {rounds['half_time_after']}", "one round before the win"],
        ]
    except KeyError as e:
        raise WikiError(f"a match rule default is missing ({e}): game/config/round_config.gd, hit_config.gd") from e
    return table(["Rule", "Skirmish", "Custom"], rows)


def gen_movement(_arg: str) -> str:
    """Each pace's top speed and the jump's height (game/config/movement_config.gd)."""
    m = gd_defaults(ROOT / "game/config/movement_config.gd")
    try:
        paces = [
            ("Walk", m["walk_speed"], "silent"),
            ("Crouch-walk", m["crouch_speed"], "silent"),
            ("Run", m["run_speed"], "heard by players and bots nearby"),
            ("Run, holstered", m["holster_run_speed"], "heard by players and bots nearby"),
            ("Sprint", m["sprint_speed"], "heard further"),
            ("Sprint, holstered", round(float(m["sprint_speed"]) * float(m["holster_sprint_scale"]), 2),
             "heard further"),
        ]
        rows = [[f"**{name}**", f"{float(v):g} m/s", noise] for name, v, noise in paces]
        jump = float(m["jump_speed"]) ** 2 / (2 * float(m["gravity"]))
    except KeyError as e:
        raise WikiError(f"game/config/movement_config.gd has no {e}") from e
    return table(["Pace", "Top speed", "Noise"], rows) + f"\n\nA jump lifts you about **{jump:.2f} m**."


def gen_dev_content(_arg: str) -> str:
    """What the Dev content switch shows today: the maps and pool items tagged dev."""
    rows = [[f"**{m['Name']}**", "Map", m["Blurb"]] for m in maps() if m["Tag"] == "dev"]
    rows += [[f"**{i['Name']}**", i["kind"].rstrip("s"), "–"]
             for i in pool() if i["Access"] == "dev"]
    return table(["Content", "Kind", "About"], rows) if rows else "_Nothing is dev content today._"


def gen_godot(_arg: str) -> str:
    """The pinned Godot version, as CI installs it (.github/workflows/ci.yml GODOT_VERSION)."""
    m = re.search(r'^\s*GODOT_VERSION:\s*"([^"]+)"', (ROOT / ".github/workflows/ci.yml").read_text(encoding="utf-8"),
                  re.M)
    if not m:
        raise WikiError(".github/workflows/ci.yml has no GODOT_VERSION")
    return m.group(1)


def gen_config(arg: str) -> str:
    """One tuning value for a sentence: `file.name` reads `@export var name` in game/config/file.gd (5.0 shows as 5)."""
    file, _, name = arg.partition(".")
    path = ROOT / "game" / "config" / f"{file}.gd"
    if not file or not name or not path.is_file():
        raise WikiError(f"'wiki:config {arg}' needs file.name, with game/config/file.gd existing")
    value = gd_defaults(path).get(name)
    if value is None:
        raise WikiError(f"{rel(path)} has no '@export var {name}'")
    try:
        return fmt(float(value))
    except ValueError as e:
        raise WikiError(f"{rel(path)}: {name} = {value} isn't a plain number") from e


def gen_version(_arg: str) -> str:
    m = re.search(r'^config/version="(.*)"$', (ROOT / "project.godot").read_text(encoding="utf-8"), re.M)
    if not m:
        raise WikiError("project.godot has no config/version")
    return m.group(1)


def gen_latest(_arg: str) -> str:
    """The newest released version in CHANGELOG.md, or a line saying none is out yet."""
    m = re.search(r"^## (.+)$", (ROOT / "CHANGELOG.md").read_text(encoding="utf-8"), re.M)
    if m:
        return f"The latest download is **{m.group(1)}**."
    return f"No download is out yet: the first, **{gen_version('')}**, is on its way."


GENERATORS = {
    "replicas": gen_replicas,
    "parts": gen_parts,
    "site-limits": gen_site_limits,
    "unlocks": gen_unlocks,
    "xp": gen_xp,
    "maps": gen_maps,
    "areas": gen_areas,
    "range-targets": gen_range_targets,
    "controls": gen_controls,
    "graphics": gen_graphics,
    "personalities": gen_personalities,
    "bot-kits": gen_bot_kits,
    "rules": gen_rules,
    "movement": gen_movement,
    "dev-content": gen_dev_content,
    "godot": gen_godot,
    "config": gen_config,
    "version": gen_version,
    "latest": gen_latest,
}


def expand(name: str, text: str) -> str:
    out = []
    for line in text.splitlines():
        m = MARKER_RE.match(line.strip())
        if m and m.group(1) in GENERATORS:
            out.append(GENERATORS[m.group(1)](m.group(2) or ""))
        elif m or line.strip().startswith("<!-- wiki:"):
            raise WikiError(f"docs/wiki/{name}.md: unknown marker '{line.strip()}'. Markers: {', '.join(GENERATORS)}")
        else:
            out.append(line)
    # A marker inside a sentence, such as `<!-- wiki:version -->`, is replaced in place.
    joined = "\n".join(out) + "\n"

    def inline(m: re.Match) -> str:
        if m.group(1) not in GENERATORS:
            raise WikiError(f"docs/wiki/{name}.md: unknown marker '{m.group(0)}'. Markers: {', '.join(GENERATORS)}")
        return GENERATORS[m.group(1)](m.group(2) or "")

    joined = re.sub(r"<!-- wiki:([a-z-]+)(?: ([A-Za-z0-9_.-]+))? -->", inline, joined)
    if "<!-- wiki:" in joined:
        raise WikiError(f"docs/wiki/{name}.md: a '<!-- wiki:' marker isn't written as '<!-- wiki:name arg -->'")
    return joined


# --- Patch notes -------------------------------------------------------------------------------------------------


def note_blocks(text: str) -> list:
    """A changelog section's '### Title' blocks, as (title, [bullet text, with its wrapped lines])."""
    blocks: list = []
    for line in text.splitlines():
        if line.startswith("### "):
            blocks.append((line[4:].strip(), []))
        elif line.startswith("- ") and blocks:
            blocks[-1][1].append(line)
        elif line.strip() and blocks and blocks[-1][1]:
            blocks[-1][1][-1] += "\n" + line
    return blocks


def mentions(text: str, terms: list) -> bool:
    low = norm(text)
    return any(re.search(r"(?<!\w)" + re.escape(norm(t)) + r"(?!\w)", low) for t in terms)


def render_notes(text: str, terms: list) -> str:
    """A changelog section for players: no Internal blocks and no hidden content, and what only dev content has
    moved under an 'In development' heading at the end."""
    public, dev = [], []
    merged: dict = {}
    for title, bullets in note_blocks(text):
        if title.lower() == "internal" or HIDDEN_RE.search(title):
            continue
        bullets = [b for b in bullets if not HIDDEN_RE.search(b)]
        whole_dev = mentions(title, terms)
        clean = re.sub(r"\s*\(dev content\)\s*$", "", title, flags=re.I)
        pub = [] if whole_dev else [b for b in bullets if not mentions(b, terms)]
        dv = bullets if whole_dev else [b for b in bullets if mentions(b, terms)]
        if pub:
            public.append((clean, pub))
        if dv:
            if clean in merged:
                merged[clean].extend(dv)
            else:
                merged[clean] = list(dv)
                dev.append((clean, merged[clean]))
    parts = [f"### {t}\n" + "\n".join(b) for t, b in public] or ["Nothing yet."]
    if dev:
        parts.append("### In development\n\nBeing built, and not in the public game yet: these show only with "
                     "**Settings › Dev › Dev content** on. See the [Roadmap](Roadmap).")
        parts += [f"#### {t}\n" + "\n".join(b) for t, b in dev]
    return "\n\n".join(parts)


def patch_notes() -> str:
    """Patch-Notes.md: what is waiting for the next download, then every released version from CHANGELOG.md."""
    terms = dev_terms()
    upcoming = subprocess.run(["bash", "tools/changelog.sh", "unreleased"], cwd=ROOT, capture_output=True,
                              text=True, check=True).stdout
    changelog = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
    parts = [
        "# Patch Notes",
        "What changed in each version, newest first, in plain words. Downloads are on the "
        "[Releases page](https://github.com/ggbillyjoe3526/airsoft/releases), and what's planned next is on "
        "the [Roadmap](Roadmap). These notes are written from the same files as each release's notes.",
        f"## Coming in {gen_version('')}",
        "Already built and on its way in the next download:",
        render_notes(upcoming, terms),
    ]
    for m in re.finditer(r"^## (.+?)\n(.*?)(?=^## |\Z)", changelog, re.M | re.S):
        parts += [f"## {m.group(1).strip()}", render_notes(m.group(2), terms)]
    return "\n\n".join(parts) + "\n"


# --- Build and check ---------------------------------------------------------------------------------------------


def source_pages() -> dict:
    """Page name -> text, for every page in docs/wiki/."""
    return {f.stem: f.read_text(encoding="utf-8") for f in sorted(WIKI.glob("*.md")) if f.name not in SKIP}


def build(out: Path) -> int:
    out = out.resolve()
    if out.exists():
        # Only ever replace an earlier build, never a folder that holds anything else (a mistyped OUT like ".").
        if out in (ROOT, WIKI) or out in ROOT.parents or (any(out.iterdir()) and not (out / "Home.md").is_file()):
            print(f"{out} isn't an earlier wiki build; pick an empty or new folder such as build/wiki",
                  file=sys.stderr)
            return 1
        shutil.rmtree(out)
    out.mkdir(parents=True)
    for name, text in source_pages().items():
        (out / f"{name}.md").write_text(expand(name, text), encoding="utf-8")
    if (WIKI / "images").is_dir():
        shutil.copytree(WIKI / "images", out / "images")
    (out / "Patch-Notes.md").write_text(patch_notes(), encoding="utf-8")
    print(f"Wrote {len(list(out.glob('*.md')))} pages to {out}")
    return 0


def slug(heading: str) -> str:
    """The anchor GitHub gives a heading."""
    h = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", heading)
    h = re.sub(r"[*_`]", "", h).strip().lower()
    h = re.sub(r"[^\w\- ]", "", h)
    return h.replace(" ", "-")


def headings(text: str) -> list:
    """(level, title, line number) of every heading outside code blocks."""
    out, in_code = [], False
    for n, line in enumerate(text.splitlines()):
        if line.startswith("```"):
            in_code = not in_code
            continue
        m = None if in_code else HEADING_RE.match(line)
        if m:
            out.append((len(m.group(1)), m.group(2), n))
    return out


def anchors(text: str) -> set:
    seen: dict = {}
    out = set()
    for _, title, _ in headings(text):
        s = slug(title)
        out.add(s if s not in seen else f"{s}-{seen[s]}")
        seen[s] = seen.get(s, 0) + 1
    return out


def without_dev_sections(text: str) -> str:
    """The page with every 'In development' section (to the next heading of its level or above) left out."""
    lines = text.splitlines()
    drop, level = False, 0
    keep = []
    for n, line in enumerate(lines):
        m = HEADING_RE.match(line)
        if m:
            if drop and len(m.group(1)) <= level:
                drop = False
            if not drop and m.group(2).strip().lower() == "in development":
                drop, level = True, len(m.group(1))
        if not drop:
            keep.append(line)
    return "\n".join(keep)


def norm(s: str) -> str:
    s = s.replace("’", "'").replace("‘", "'").lower()
    return re.sub(r"\s+", " ", s)


def check_built(built: Path) -> int:
    bad = 0
    pages = {f.stem: f.read_text(encoding="utf-8") for f in sorted(built.glob("*.md"))}

    def error(page: str, msg: str) -> None:
        nonlocal bad
        src = f"docs/wiki/{page}.md" if page not in GENERATED_PAGES else "tools/wiki.py"
        print(f"::error file={src}::{page}: {msg}")
        bad = 1

    if "Home" not in pages:
        error("Home", "docs/wiki/Home.md is missing: it is the wiki's front page.")
        return 1
    page_anchors = {name: anchors(text) for name, text in pages.items()}
    for name, text in pages.items():
        for target in LINK_RE.findall(text):
            if re.match(r"^[a-z][a-z0-9+.-]*:", target, re.I):
                continue  # https:, mailto:
            page, _, anchor = target.partition("#")
            page = page or name
            if page.startswith("images/"):
                if not (built / page).is_file():
                    error(name, f"picture that doesn't exist: ({target}). Put it in docs/wiki/images/.")
                continue
            if page not in pages:
                error(name, f"link to a page that doesn't exist: ({target}). Pages are file names without .md.")
            elif anchor and anchor not in page_anchors[page]:
                error(name, f"link to a heading that doesn't exist: ({target}). Anchors are the heading in "
                            "lowercase with dashes for spaces.")

    linked = {t.partition("#")[0] for t in LINK_RE.findall(pages.get("_Sidebar", ""))}
    for name in sorted(pages):
        if not name.startswith("_") and name not in linked:
            error("_Sidebar", f"page {name} isn't in the sidebar. Add a link to it in docs/wiki/_Sidebar.md.")

    terms = dev_terms()
    for name, text in pages.items():
        if HIDDEN_RE.search(text):
            error(name, "names the hidden Easter egg (robots). It stays out of the wiki (docs/DECISIONS.md).")
        if name in DEV_PAGES:
            continue
        rest = norm(without_dev_sections(text))
        for t in terms:
            if re.search(r"(?<!\w)" + re.escape(norm(t)) + r"(?!\w)", rest):
                error(name, f"names dev content ('{t}') outside an 'In development' section. Dev content is named "
                            f"only on {', '.join(sorted(DEV_PAGES))} or under an 'In development' heading.")

    corpus = norm("\n".join(pages.values()))
    names = public_names() | {m["Name"] for m in maps() if m["Tag"] == "public"}
    for n in sorted(names):
        if not re.search(r"(?<!\w)" + re.escape(norm(n)) + r"(?!\w)", corpus):
            error("Home", f"'{n}' is in the game but no page names it. Describe it on the right page.")
    if bad == 0:
        print(f"Wiki OK: {len(pages)} pages; links and headings resolve, dev content stays in its place and every "
              "public item and map is named.")
    return bad


def check(base: str = "") -> int:
    with tempfile.TemporaryDirectory() as tmp:
        out = Path(tmp) / "wiki"
        try:
            if build(out) != 0:
                return 1
        except (WikiError, subprocess.CalledProcessError, OSError, ValueError, KeyError, AttributeError) as e:
            print(f"::error::The wiki can't be built: {e}")
            return 1
        bad = check_built(out)
    if base:
        changed = subprocess.run(["git", "diff", "--name-only", "--diff-filter=AM", f"{base}...HEAD"],
                                 cwd=ROOT, capture_output=True, text=True)
        files = changed.stdout.split() if changed.returncode == 0 else []
        notes = [f for f in files if f.startswith("changelog.d/") and not f.endswith("README.md")]
        if notes and not any(f.startswith("docs/wiki/") for f in files):
            print(f"::warning::This change adds a changelog note ({', '.join(notes)}) but no wiki page. If players "
                  "will notice it, update the page in docs/wiki/ that describes it (docs/wiki/README.md).")
    return bad


def main(argv: list) -> int:
    try:
        if argv and argv[0] == "check":
            return check(argv[2] if len(argv) >= 3 and argv[1] == "--base" else "")
        if len(argv) == 2 and argv[0] == "build":
            return build(Path(argv[1]))
    except WikiError as e:
        print(f"::error::The wiki can't be built: {e}", file=sys.stderr)
        return 1
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
