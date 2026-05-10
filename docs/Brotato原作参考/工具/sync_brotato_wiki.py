#!/usr/bin/env python3
"""
Fetch and parse the current public Brotato Wiki data into a versioned local
snapshot.

The wiki is MediaWiki-based. The most reliable structured sources are the raw
data templates:
  - Template:Character Data
  - Template:Weapon Data
  - Template:Item Data
  - Template:Elite Data
  - Template:Boss Data

HTML pages are still saved because several systems are documented as prose or
tables rather than data templates.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import html
import io
import json
import re
import time
import urllib.parse
import urllib.request
from pathlib import Path

try:
    import pandas as pd
except Exception:  # pragma: no cover - handled at runtime for local envs.
    pd = None

try:
    from lxml import html as lxml_html
except Exception:  # pragma: no cover - handled at runtime for local envs.
    lxml_html = None


BASE_URL = "https://brotato.wiki.spellsandguns.com"

CORE_PAGES = [
    "Brotato_Wiki",
    "Characters",
    "Weapons",
    "Items",
    "Enemies",
    "Waves",
    "Shop",
    "Stats",
    "Max_HP",
    "HP_Regeneration",
    "Life_Steal",
    "Damage",
    "Melee_Damage",
    "Ranged_Damage",
    "Elemental_Damage",
    "Attack_Speed",
    "Crit_Chance",
    "Engineering",
    "Range",
    "Armor",
    "Dodge",
    "Speed",
    "Explosion",
    "Less_Enemy_Speed",
    "Danger_Levels",
    "Endless_Mode",
    "Progress",
    "Upgrades",
    "Materials",
    "Harvesting",
    "Luck",
    "Trees",
    "Crate",
    "Consumable",
    "Curse",
    "Modding_Notes",
]

RAW_TEMPLATES = {
    "Template:GetVersion": "get_version.wiki",
    "Template:Character Data": "character_data.wiki",
    "Template:Weapon Data": "weapon_data.wiki",
    "Template:Item Data": "item_data.wiki",
    "Template:Elite Data": "elite_data.wiki",
    "Template:Boss Data": "boss_data.wiki",
}

FIELD_ALIASES = {
    "attackspeed": "attack_speed",
    "unlockedby": "unlocked_by",
    "unlocktype": "unlock_type",
    "wantedtags": "wanted_tags",
    "startingwpns": "starting_weapons",
    "isdlc": "is_dlc",
    "lifesteal": "life_steal",
}

TIER_ALIASES = {
    "1": "tier1",
    "common": "tier1",
    "2": "tier2",
    "rare": "tier2",
    "3": "tier3",
    "epic": "tier3",
    "4": "tier4",
    "legendary": "tier4",
}


def fetch_text(url: str, *, user_agent: str = "Codex Brotato data audit") -> str:
    req = urllib.request.Request(url, headers={"User-Agent": user_agent})
    with urllib.request.urlopen(req, timeout=30) as response:
        charset = response.headers.get_content_charset() or "utf-8"
        return response.read().decode(charset, errors="replace")


def raw_url(title: str) -> str:
    return f"{BASE_URL}/index.php?title={urllib.parse.quote(title.replace(' ', '_'))}&action=raw"


def page_url(title: str) -> str:
    return f"{BASE_URL}/{urllib.parse.quote(title.replace(' ', '_'), safe='/_:')}"


def safe_name(title: str) -> str:
    return re.sub(r"[^A-Za-z0-9_.-]+", "_", title.replace("/", "__")).strip("_")


def slugify(value: str) -> str:
    value = clean_markup(value).lower()
    value = re.sub(r"[^a-z0-9]+", "_", value)
    return value.strip("_") or "table"


def clean_markup(value: str) -> str:
    value = html.unescape(value or "")
    value = value.replace("<br>", "\n").replace("<br />", "\n").replace("<br/>", "\n")
    value = re.sub(r"<[^>]+>", "", value)
    value = re.sub(r"\{\{Color\|[^|{}]+\|([^{}]+?)\}\}", r"\1", value)
    value = re.sub(r"\{\{Color\|color=[^|{}]+\|text=([^{}]+?)\}\}", r"\1", value)
    value = re.sub(r"\{\{StatIcon\|([^{}]+?)\}\}", r" \1", value)
    value = re.sub(r"\[\[File:[^\]]+\]\]", "", value)
    value = re.sub(r"\[\[([^|\]]+)\|([^\]]+)\]\]", r"\2", value)
    value = re.sub(r"\[\[([^\]]+)\]\]", r"\1", value)
    value = value.replace("{{!}}", "|")
    value = re.sub(r"\s+\n", "\n", value)
    value = re.sub(r"\n\s+", "\n", value)
    value = re.sub(r"[ \t]+", " ", value)
    return value.strip()


def normalize_field(name: str) -> str:
    name = name.strip().lower().replace("-", "_")
    return FIELD_ALIASES.get(name, name)


def extract_top_level_entries(wikitext: str) -> dict[str, str]:
    lines = wikitext.splitlines()
    entry_start = re.compile(r"^\|([^|#][^=]*?)\s*=\s*\{\{#switch:\{\{lc:\{\{\{2\|")
    entries: dict[str, list[str]] = {}
    current_name: str | None = None
    current_lines: list[str] = []

    for line in lines:
        if line.startswith("|") and "=" not in line:
            # Some templates add ASCII aliases immediately before the real
            # Unicode title, for example "|esty's couch" then
            # "|esty’s couch = ...". Keep the canonical entry only.
            continue
        match = entry_start.match(line)
        if match:
            if current_name:
                entries[current_name] = current_lines
            current_name = clean_markup(match.group(1)).lower()
            current_lines = [line]
            continue
        if current_name:
            if line.startswith("|#default="):
                entries[current_name] = current_lines
                current_name = None
                current_lines = []
            else:
                current_lines.append(line)

    if current_name:
        entries[current_name] = current_lines

    return {name: "\n".join(block) for name, block in entries.items()}


def split_top_level_fields(block: str) -> dict[str, str]:
    lines = block.splitlines()[1:]
    fields: dict[str, list[str]] = {}
    current_field: str | None = None

    for line in lines:
        if line.lstrip().startswith("|#default="):
            current_field = None
            continue
        if line.startswith("\t|") and not line.startswith("\t\t|"):
            match = re.match(r"^\t\|([A-Za-z0-9_]+)\s*=(.*)$", line)
            if match:
                current_field = normalize_field(match.group(1))
                fields[current_field] = [match.group(2)]
                continue
        if current_field:
            fields[current_field].append(line)

    return {key: "\n".join(value).strip() for key, value in fields.items()}


def parse_tier_switch(value: str) -> dict[str, str] | None:
    tiers: dict[str, str] = {}
    for line in value.splitlines():
        match = re.match(r"^\s*\|([^=]+?)=(.*)$", line)
        if not match:
            continue
        aliases = [part.strip().lower() for part in match.group(1).split("|") if part.strip()]
        tier = next((TIER_ALIASES[a] for a in aliases if a in TIER_ALIASES), None)
        if tier:
            tiers[tier] = clean_markup(match.group(2))
    return tiers or None


def parse_template_data(wikitext: str, kind: str) -> list[dict[str, object]]:
    records: list[dict[str, object]] = []
    for name, block in extract_top_level_entries(wikitext).items():
        raw_fields = split_top_level_fields(block)
        record: dict[str, object] = {
            "id": name,
            "name": " ".join(part.capitalize() for part in name.split()),
            "kind": kind,
            "fields_raw": raw_fields,
            "fields": {},
        }
        fields: dict[str, object] = {}
        for key, raw_value in raw_fields.items():
            tiers = parse_tier_switch(raw_value)
            fields[key] = tiers if tiers else clean_markup(raw_value)
        record["fields"] = fields
        records.append(record)
    return records


def extract_table_contexts(html_text: str) -> list[str]:
    if lxml_html is None:
        return []
    try:
        document = lxml_html.fromstring(html_text)
    except Exception:
        return []

    contexts: list[str] = []
    heading_stack: list[str] = []
    for node in document.xpath("//h2|//h3|//h4|//table"):
        tag = node.tag.lower() if isinstance(node.tag, str) else ""
        if tag in {"h2", "h3", "h4"}:
            level = int(tag[1]) - 2
            heading = clean_markup(node.text_content())
            heading = re.sub(r"\[edit\]$", "", heading).strip()
            heading_stack = heading_stack[:level]
            if heading:
                heading_stack.append(heading)
            continue
        if tag == "table":
            classes = node.get("class", "")
            if "navbox" in classes or "toc" in classes:
                continue
            contexts.append(" > ".join(heading_stack))
    return contexts


def parse_html_tables(html_text: str) -> list[dict[str, object]]:
    if pd is None:
        return []
    try:
        tables = pd.read_html(io.StringIO(html_text), flavor="lxml")
    except ValueError:
        return []

    parsed = []
    contexts = extract_table_contexts(html_text)
    for index, table in enumerate(tables):
        table = table.fillna("")
        table.columns = [str(col).strip() for col in table.columns]
        parsed.append(
            {
                "table_index": index,
                "section": contexts[index] if index < len(contexts) else "",
                "columns": list(table.columns),
                "row_count": int(len(table)),
                "rows": table.astype(str).to_dict(orient="records"),
            }
        )
    return parsed


def write_json(path: Path, data: object) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def fetch_source_snapshot(snapshot_dir: Path, delay: float) -> tuple[dict[str, str], dict[str, str], list[dict[str, str]]]:
    raw_dir = snapshot_dir / "raw_templates"
    html_dir = snapshot_dir / "raw_html"
    raw_dir.mkdir(parents=True, exist_ok=True)
    html_dir.mkdir(parents=True, exist_ok=True)

    raw_texts: dict[str, str] = {}
    html_texts: dict[str, str] = {}
    errors: list[dict[str, str]] = []

    for title, filename in RAW_TEMPLATES.items():
        try:
            text = fetch_text(raw_url(title))
            raw_texts[title] = text
            (raw_dir / filename).write_text(text, encoding="utf-8")
        except Exception as exc:
            errors.append({"kind": "raw_template", "title": title, "url": raw_url(title), "error": repr(exc)})
        time.sleep(delay)

    for title in CORE_PAGES:
        try:
            text = fetch_text(page_url(title))
            html_texts[title] = text
            (html_dir / f"{safe_name(title)}.html").write_text(text, encoding="utf-8")
        except Exception as exc:
            errors.append({"kind": "html_page", "title": title, "url": page_url(title), "error": repr(exc)})
            (html_dir / f"{safe_name(title)}.error.txt").write_text(f"{page_url(title)}\n{exc!r}\n", encoding="utf-8")
        time.sleep(delay)

    return raw_texts, html_texts, errors


def extract_wiki_version(raw_texts: dict[str, str], html_texts: dict[str, str]) -> str:
    version_raw = clean_markup(raw_texts.get("Template:GetVersion", ""))
    match = re.search(r"\b\d+\.\d+\.\d+\.\d+\b", version_raw)
    if match:
        return match.group(0)
    for text in html_texts.values():
        match = re.search(r"Updated for version:.*?(\d+\.\d+\.\d+\.\d+)", text, re.S)
        if match:
            return match.group(1)
    return "unknown"


def extract_shop_formula(shop_html: str) -> dict[str, str]:
    text = clean_markup(shop_html)
    formulas = {}
    inc = re.search(r"Reroll Increase:\s*([^\n]+)", text)
    first = re.search(r"First Reroll Price:\s*([^\n]+)", text)
    if inc:
        formulas["reroll_increase"] = inc.group(1).strip()
    if first:
        formulas["first_reroll_price"] = first.group(1).strip()
    return formulas


def extract_item_count_crosscheck(items_html: str, item_tables: list[dict[str, object]]) -> dict[str, object]:
    text = clean_markup(items_html)
    declared = {}
    match = re.search(
        r"There are currently\s+(\d+)\s+items in vanilla Brotato plus\s+(\d+)\s+items in Abyssal Terrors for\s+(\d+)\s+total",
        text,
        re.I,
    )
    if match:
        declared = {
            "vanilla": int(match.group(1)),
            "dlc": int(match.group(2)),
            "total": int(match.group(3)),
        }
    main_table_rows = None
    for table in item_tables:
        columns = table.get("columns", [])
        if {"Name", "Rarity", "Effects", "Base Price"}.issubset(set(columns)):
            main_table_rows = table.get("row_count")
            break
    return {
        "declared_by_items_page": declared,
        "items_main_table_rows": main_table_rows,
    }


def build_snapshot(raw_texts: dict[str, str], html_texts: dict[str, str], source_errors: list[dict[str, str]]) -> dict[str, object]:
    characters = parse_template_data(raw_texts["Template:Character Data"], "character")
    weapons = parse_template_data(raw_texts["Template:Weapon Data"], "weapon")
    items = parse_template_data(raw_texts["Template:Item Data"], "item")
    elites = parse_template_data(raw_texts["Template:Elite Data"], "elite")
    bosses = parse_template_data(raw_texts["Template:Boss Data"], "boss")

    html_tables = {
        title: parse_html_tables(text)
        for title, text in html_texts.items()
    }
    item_crosscheck = extract_item_count_crosscheck(
        html_texts.get("Items", ""),
        html_tables.get("Items", []),
    )

    version = extract_wiki_version(raw_texts, html_texts)
    generated_utc = dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()

    return {
        "metadata": {
            "source": "Brotato Wiki",
            "base_url": BASE_URL,
            "wiki_version": version,
            "generated_utc": generated_utc,
            "core_pages": CORE_PAGES,
            "raw_templates": list(RAW_TEMPLATES),
            "source_errors": source_errors,
        },
        "counts": {
            "characters": len(characters),
            "weapons": len(weapons),
            "items": len(items),
            "elites": len(elites),
            "bosses": len(bosses),
            "html_tables": sum(len(tables) for tables in html_tables.values()),
        },
        "shop_formula": extract_shop_formula(html_texts.get("Shop", "")),
        "source_cross_checks": {
            "items": {
                **item_crosscheck,
                "item_data_template_entries": len(items),
            },
        },
        "characters": characters,
        "weapons": weapons,
        "items": items,
        "elites": elites,
        "bosses": bosses,
        "html_tables": html_tables,
    }


def write_summary(snapshot_dir: Path, snapshot: dict[str, object]) -> None:
    counts = snapshot["counts"]
    meta = snapshot["metadata"]
    formula = snapshot.get("shop_formula", {})
    cross_checks = snapshot.get("source_cross_checks", {})
    item_check = cross_checks.get("items", {})
    declared = item_check.get("declared_by_items_page", {})
    errors = snapshot["metadata"].get("source_errors", [])
    error_lines = "\n".join(
        f"- `{item['title']}`：{item['error']} ({item['url']})"
        for item in errors
    ) or "- 无"
    report = f"""# Brotato Wiki 当前数据快照校验报告

生成时间（UTC）：{meta["generated_utc"]}

来源：{BASE_URL}

Wiki 当前版本：`{meta["wiki_version"]}`

## 已保存的原始证据

- `raw_templates/`：角色、武器、道具、Elite、Boss、版本号的 MediaWiki 原始模板。
- `raw_html/`：核心系统页面 HTML，包括 Characters、Weapons、Items、Enemies、Waves、Shop、Stats、Danger Levels、Endless Mode、Progress 等。
- `parsed/brotato_wiki_snapshot.json`：由原始模板和 HTML 表格解析出的机器可读总表。
- `parsed/csv/`：角色、道具模板条目、武器、武器分级、Elite、Boss，以及页面级表格的CSV导出。
- `parsed/csv/template_fields_long.csv`：角色、武器、道具、Elite、Boss模板字段的全字段长表。
- `parsed/csv/html_table_index.csv`：所有页面表格CSV的检索索引。
- `parsed/html_tables/`：每个核心页面的 HTML 表格抽取结果，保留行列结构和所在页面章节。

## 抓取失败来源

{error_lines}

## 结构化计数

| 数据类型 | 当前解析数量 |
|---|---:|
| 角色 | {counts["characters"]} |
| 武器 | {counts["weapons"]} |
| 道具 | {counts["items"]} |
| Elite | {counts["elites"]} |
| Boss | {counts["bosses"]} |
| HTML 表格 | {counts["html_tables"]} |

## 道具数量交叉检查

| 证据口径 | 数量 |
|---|---:|
| Items页面正文声明（原版） | {declared.get("vanilla", "未解析到")} |
| Items页面正文声明（DLC） | {declared.get("dlc", "未解析到")} |
| Items页面正文声明（合计） | {declared.get("total", "未解析到")} |
| Items主表HTML解析行数 | {item_check.get("items_main_table_rows", "未解析到")} |
| `Template:Item Data`模板条目 | {item_check.get("item_data_template_entries", "未解析到")} |

> 处理口径：数据库文档中的“237道具”沿用Items页面正文声明；模板中的239条全部保留到机器可读快照，供识别内部、衍生或特殊状态条目。不能把模板条目数直接等同于普通可购道具数。

## 当前商店刷新公式

| 项 | 线上 Wiki 当前记录 |
|---|---|
| Reroll Increase | `{formula.get("reroll_increase", "未解析到")}` |
| First Reroll Price | `{formula.get("first_reroll_price", "未解析到")}` |

## 本次校验结论

1. 角色、武器、道具三类核心数据应以 `raw_templates/` 的模板为准；这些模板是 Wiki 页面自身声明的数据源。
2. 本地旧文档中若仍记录 `floor(波次 / 2)` / `floor(波次 × 0.33)` 一类刷新公式，应视为过期，需按当前快照修正或标注版本差异。
3. `Enemies`、`Shop`、`Stats`、`Danger Levels`、`Endless Mode`、`Progress` 等系统信息已保存原始 HTML、表格抽取 JSON 和逐表 CSV；prose 规则仍需要人工转写进主文档。

## 仍不能宣称“公开资料已完整复刻”的部分

- 每波精确刷怪脚本：敌人组、数量曲线、生成间隔、组权重、地图/模式差异。
- 游戏内部实现细节：敌人 AI 状态机、碰撞/寻路/攻击判定边界、商店实际随机抽取代码。
- 版本差异：本快照对应 Wiki 当前版本 `{meta["wiki_version"]}`；如果目标是复刻某个 Steam/移动端具体版本，需要对照该版本游戏文件或实测。

这些内容可以继续通过数据挖掘、实测录屏和统计脚本补齐；在没有证据前，本地文档必须标为“未公开确认”。
"""
    (snapshot_dir / "校验报告.md").write_text(report, encoding="utf-8")


def write_entity_index(snapshot_dir: Path, snapshot: dict[str, object]) -> None:
    parsed_dir = snapshot_dir / "parsed"
    parsed_dir.mkdir(parents=True, exist_ok=True)
    rows = []
    for section in ["characters", "weapons", "items", "elites", "bosses"]:
        for record in snapshot[section]:
            rows.append(
                {
                    "kind": record["kind"],
                    "id": record["id"],
                    "name": record["name"],
                    "url": page_url(str(record["name"])),
                }
            )
    write_json(parsed_dir / "entity_index.json", rows)


def scalar_field(record: dict[str, object], key: str) -> str:
    fields = record.get("fields", {})
    if not isinstance(fields, dict):
        return ""
    value = fields.get(key, "")
    if isinstance(value, dict):
        return json.dumps(value, ensure_ascii=False, sort_keys=True)
    return str(value)


def write_csv(path: Path, fieldnames: list[str], rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow({field: row.get(field, "") for field in fieldnames})


def write_html_table_csv_exports(snapshot_dir: Path, snapshot: dict[str, object]) -> None:
    csv_root = snapshot_dir / "parsed" / "csv"
    table_csv_dir = csv_root / "html_tables"
    table_csv_dir.mkdir(parents=True, exist_ok=True)

    index_rows: list[dict[str, object]] = []
    for title, tables in snapshot["html_tables"].items():
        page_slug = safe_name(str(title))
        for table in tables:
            if not isinstance(table, dict):
                continue
            table_index = int(table.get("table_index", 0))
            section = str(table.get("section", ""))
            section_slug = slugify(section)
            csv_name = f"{page_slug}.table_{table_index:02d}.{section_slug}.csv"
            rows = table.get("rows", [])
            columns = [str(col) for col in table.get("columns", [])]
            if not columns and isinstance(rows, list) and rows:
                columns = list(rows[0])
            if isinstance(rows, list):
                write_csv(table_csv_dir / csv_name, columns, rows)
            index_rows.append(
                {
                    "page": title,
                    "table_index": table_index,
                    "section": section,
                    "row_count": table.get("row_count", ""),
                    "columns": " | ".join(columns),
                    "csv_path": f"html_tables/{csv_name}",
                    "source_url": page_url(str(title)),
                }
            )

    write_csv(
        csv_root / "html_table_index.csv",
        ["page", "table_index", "section", "row_count", "columns", "csv_path", "source_url"],
        index_rows,
    )


def write_template_field_csv_exports(snapshot_dir: Path, snapshot: dict[str, object]) -> None:
    csv_root = snapshot_dir / "parsed" / "csv"
    field_rows: list[dict[str, object]] = []
    index: dict[tuple[str, str], int] = {}

    for section in ["characters", "weapons", "items", "elites", "bosses"]:
        for record in snapshot[section]:
            fields = record.get("fields", {})
            raw_fields = record.get("fields_raw", {})
            if not isinstance(fields, dict) or not isinstance(raw_fields, dict):
                continue
            for field_name in sorted(set(fields) | set(raw_fields)):
                value = fields.get(field_name, "")
                raw_value = raw_fields.get(field_name, "")
                value_text = json.dumps(value, ensure_ascii=False, sort_keys=True) if isinstance(value, (dict, list)) else str(value)
                field_rows.append(
                    {
                        "kind": record["kind"],
                        "id": record["id"],
                        "name": record["name"],
                        "field": field_name,
                        "value": value_text,
                        "raw_value": str(raw_value),
                    }
                )
                key = (str(record["kind"]), field_name)
                index[key] = index.get(key, 0) + 1

    index_rows = [
        {"kind": kind, "field": field, "entity_count": count}
        for (kind, field), count in sorted(index.items())
    ]
    write_csv(csv_root / "template_fields_long.csv", ["kind", "id", "name", "field", "value", "raw_value"], field_rows)
    write_csv(csv_root / "template_field_index.csv", ["kind", "field", "entity_count"], index_rows)


def write_csv_exports(snapshot_dir: Path, snapshot: dict[str, object]) -> None:
    csv_dir = snapshot_dir / "parsed" / "csv"

    character_fields = ["id", "name", "stats", "unlocked_by", "unlocks", "unlock_type", "wanted_tags", "starting_weapons", "is_dlc"]
    character_rows = [
        {"id": r["id"], "name": r["name"], **{field: scalar_field(r, field) for field in character_fields if field not in {"id", "name"}}}
        for r in snapshot["characters"]
    ]
    write_csv(csv_dir / "characters.csv", character_fields, character_rows)

    item_fields = ["id", "name", "rarity", "stats", "price", "unique", "unlocked_by", "limit", "tags", "is_dlc"]
    item_rows = [
        {"id": r["id"], "name": r["name"], **{field: scalar_field(r, field) for field in item_fields if field not in {"id", "name"}}}
        for r in snapshot["items"]
    ]
    write_csv(csv_dir / "items_template_entries.csv", item_fields, item_rows)

    weapon_fields = ["id", "name", "rarity", "types", "special", "unlocked_by", "attacktype", "is_dlc"]
    weapon_rows = [
        {"id": r["id"], "name": r["name"], **{field: scalar_field(r, field) for field in weapon_fields if field not in {"id", "name"}}}
        for r in snapshot["weapons"]
    ]
    write_csv(csv_dir / "weapons.csv", weapon_fields, weapon_rows)

    tier_fields = ["id", "name", "tier", "damage", "attack_speed", "dps", "crit", "range", "knockback", "life_steal", "price"]
    tier_rows: list[dict[str, object]] = []
    for weapon in snapshot["weapons"]:
        fields = weapon.get("fields", {})
        if not isinstance(fields, dict):
            continue
        for tier in ["tier1", "tier2", "tier3", "tier4"]:
            row: dict[str, object] = {"id": weapon["id"], "name": weapon["name"], "tier": tier}
            for key in tier_fields:
                if key in {"id", "name", "tier"}:
                    continue
                value = fields.get(key, "")
                if isinstance(value, dict):
                    row[key] = value.get(tier, "")
                else:
                    row[key] = value
            tier_rows.append(row)
    write_csv(csv_dir / "weapon_tiers.csv", tier_fields, tier_rows)

    simple_fields = ["id", "name", "stats", "minimumdanger", "reward"]
    elite_rows = [
        {"id": r["id"], "name": r["name"], **{field: scalar_field(r, field) for field in simple_fields if field not in {"id", "name"}}}
        for r in snapshot["elites"]
    ]
    write_csv(csv_dir / "elites.csv", simple_fields, elite_rows)

    boss_fields = ["id", "name", "stats", "reward"]
    boss_rows = [
        {"id": r["id"], "name": r["name"], **{field: scalar_field(r, field) for field in boss_fields if field not in {"id", "name"}}}
        for r in snapshot["bosses"]
    ]
    write_csv(csv_dir / "bosses.csv", boss_fields, boss_rows)

    write_template_field_csv_exports(snapshot_dir, snapshot)
    write_html_table_csv_exports(snapshot_dir, snapshot)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--date",
        default=dt.datetime.now().strftime("%Y-%m-%d"),
        help="Snapshot folder name under 数据快照/",
    )
    parser.add_argument("--delay", type=float, default=0.15, help="Delay between HTTP requests.")
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[1]
    snapshot_dir = root / "数据快照" / args.date
    parsed_dir = snapshot_dir / "parsed"
    table_dir = parsed_dir / "html_tables"
    parsed_dir.mkdir(parents=True, exist_ok=True)
    table_dir.mkdir(parents=True, exist_ok=True)

    raw_texts, html_texts, source_errors = fetch_source_snapshot(snapshot_dir, args.delay)
    required = ["Template:Character Data", "Template:Weapon Data", "Template:Item Data"]
    missing = [title for title in required if title not in raw_texts]
    if missing:
        raise RuntimeError(f"Required raw templates missing: {missing}")
    snapshot = build_snapshot(raw_texts, html_texts, source_errors)

    write_json(parsed_dir / "brotato_wiki_snapshot.json", snapshot)
    write_entity_index(snapshot_dir, snapshot)
    write_csv_exports(snapshot_dir, snapshot)

    for title, tables in snapshot["html_tables"].items():
        write_json(table_dir / f"{safe_name(title)}.tables.json", tables)

    write_summary(snapshot_dir, snapshot)

    print(json.dumps({"snapshot_dir": str(snapshot_dir), "counts": snapshot["counts"], "version": snapshot["metadata"]["wiki_version"]}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
