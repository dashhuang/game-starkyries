#!/usr/bin/env python3
"""
Fetch individual Brotato Wiki entity pages and extract their section text.

The structured templates cover table data, but many important mechanics live in
single-page Notes sections. This script adds that layer without changing the
core snapshot format produced by sync_brotato_wiki.py.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import html
import json
import re
import time
import urllib.parse
import urllib.request
from pathlib import Path

from lxml import html as lxml_html


BASE_URL = "https://brotato.wiki.spellsandguns.com"


def fetch_text(url: str, *, user_agent: str = "Codex Brotato entity audit") -> str:
    req = urllib.request.Request(url, headers={"User-Agent": user_agent})
    with urllib.request.urlopen(req, timeout=30) as response:
        charset = response.headers.get_content_charset() or "utf-8"
        return response.read().decode(charset, errors="replace")


def page_url(title: str) -> str:
    return f"{BASE_URL}/{urllib.parse.quote(title.replace(' ', '_'), safe='/_:')}"


def search_url(query: str) -> str:
    params = urllib.parse.urlencode({"action": "query", "list": "search", "srsearch": query, "srlimit": 5, "format": "json"})
    return f"{BASE_URL}/api.php?{params}"


def safe_name(title: str) -> str:
    return re.sub(r"[^A-Za-z0-9_.-]+", "_", title.replace("/", "__")).strip("_") or "unknown"


def clean_text(text: str) -> str:
    text = html.unescape(text or "")
    text = text.replace("\xa0", " ")
    text = re.sub(r"\n{3,}", "\n\n", text)
    text = re.sub(r"[ \t]+", " ", text)
    return text.strip()


def load_entity_index(snapshot_dir: Path) -> list[dict[str, str]]:
    index_path = snapshot_dir / "parsed" / "entity_index.json"
    entities = json.loads(index_path.read_text(encoding="utf-8"))
    out: list[dict[str, str]] = []
    for entity in entities:
        out.append(
            {
                "kind": entity["kind"],
                "id": entity["id"],
                "name": entity["name"],
                "url": page_url(entity["name"]),
            }
        )
    return out


def load_enemy_entities(snapshot_dir: Path) -> list[dict[str, str]]:
    tables_path = snapshot_dir / "parsed" / "html_tables" / "Enemies.tables.json"
    if not tables_path.exists():
        return []
    tables = json.loads(tables_path.read_text(encoding="utf-8"))
    entities: list[dict[str, str]] = []
    seen: set[str] = set()
    for table in tables:
        columns = set(table.get("columns", []))
        if "Name" not in columns or "Behavior" not in columns:
            continue
        for row in table.get("rows", []):
            name = clean_text(str(row.get("Name", "")))
            if not name or name in seen:
                continue
            seen.add(name)
            entities.append({"kind": "enemy", "id": name.lower(), "name": name, "url": page_url(name)})
    return entities


def get_content_root(document: lxml_html.HtmlElement) -> lxml_html.HtmlElement:
    parser_roots = document.xpath('//*[contains(concat(" ", normalize-space(@class), " "), " mw-parser-output ")]')
    if parser_roots:
        return parser_roots[0]
    roots = document.xpath('//*[@id="mw-content-text"]')
    return roots[0] if roots else document


def extract_sections(html_text: str) -> dict[str, object]:
    document = lxml_html.fromstring(html_text)
    title = clean_text(" ".join(document.xpath("//h1/text()"))) or clean_text(document.findtext(".//title") or "")
    root = get_content_root(document)

    sections: list[dict[str, object]] = []
    current: dict[str, object] | None = None
    buffer: list[str] = []

    def flush() -> None:
        nonlocal current, buffer
        if current is not None:
            current["text"] = clean_text("\n".join(buffer))
            sections.append(current)
        current = None
        buffer = []

    for node in root.iterchildren():
        tag = node.tag.lower() if isinstance(node.tag, str) else ""
        if not tag:
            continue
        if tag in {"h2", "h3", "h4"}:
            flush()
            heading = clean_text(node.text_content())
            heading = re.sub(r"\[edit\]$", "", heading).strip()
            current = {"level": int(tag[1]), "heading": heading, "text": ""}
            continue
        if current is not None:
            text = clean_text(node.text_content())
            if text:
                buffer.append(text)
    flush()

    notes = "\n\n".join(
        section["text"]
        for section in sections
        if "note" in str(section.get("heading", "")).lower()
    )

    return {
        "title": title,
        "sections": sections,
        "notes": clean_text(notes),
    }


def candidate_urls(entity: dict[str, str]) -> list[str]:
    name = entity["name"]
    candidates = [entity["url"], page_url(name.replace("’", "'")), page_url(entity["id"])]
    if entity["kind"] in {"elite", "boss"}:
        candidates.extend([page_url(f"Enemies#{name}"), page_url("Enemies")])
    # Keep order and uniqueness.
    out: list[str] = []
    for url in candidates:
        if url not in out:
            out.append(url)
    return out


def search_candidate_urls(entity: dict[str, str]) -> list[str]:
    candidates = []
    for query in [entity["name"], entity["id"]]:
        try:
            data = json.loads(fetch_text(search_url(query)))
        except Exception:
            continue
        for result in data.get("query", {}).get("search", [])[:5]:
            title = result.get("title")
            if title:
                candidates.append(page_url(title))
    out = []
    for url in candidates:
        if url not in out:
            out.append(url)
    return out


def fetch_entity(entity: dict[str, str], output_dir: Path, refresh: bool) -> dict[str, object]:
    kind_dir = output_dir / "raw_entity_html" / entity["kind"]
    kind_dir.mkdir(parents=True, exist_ok=True)
    html_path = kind_dir / f"{safe_name(entity['name'])}.html"

    errors = []
    html_text = ""
    used_url = ""
    if html_path.exists() and not refresh:
        html_text = html_path.read_text(encoding="utf-8")
        used_url = entity["url"]
    else:
        urls = candidate_urls(entity)
        for url in urls:
            try:
                html_text = fetch_text(url)
                used_url = url
                html_path.write_text(html_text, encoding="utf-8")
                break
            except Exception as exc:
                errors.append({"url": url, "error": repr(exc)})
        if not html_text:
            for url in search_candidate_urls(entity):
                if url in urls:
                    continue
                try:
                    html_text = fetch_text(url)
                    used_url = url
                    html_path.write_text(html_text, encoding="utf-8")
                    break
                except Exception as exc:
                    errors.append({"url": url, "error": repr(exc)})

    if not html_text:
        return {**entity, "ok": False, "errors": errors, "sections": [], "notes": ""}

    extracted = extract_sections(html_text)
    return {
        **entity,
        "url": used_url or entity["url"],
        "ok": True,
        "errors": errors,
        "page_title": extracted["title"],
        "sections": extracted["sections"],
        "notes": extracted["notes"],
    }


def write_json(path: Path, data: object) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def write_notes_csv(path: Path, records: list[dict[str, object]]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=["kind", "id", "name", "ok", "url", "page_title", "notes"])
        writer.writeheader()
        for record in records:
            writer.writerow(
                {
                    "kind": record.get("kind", ""),
                    "id": record.get("id", ""),
                    "name": record.get("name", ""),
                    "ok": record.get("ok", False),
                    "url": record.get("url", ""),
                    "page_title": record.get("page_title", ""),
                    "notes": record.get("notes", ""),
                }
            )


def write_report(snapshot_dir: Path, records: list[dict[str, object]], include_enemies: bool) -> None:
    total = len(records)
    ok = sum(1 for record in records if record.get("ok"))
    with_notes = sum(1 for record in records if record.get("notes"))
    by_kind: dict[str, dict[str, int]] = {}
    for record in records:
        kind = str(record.get("kind", "unknown"))
        stats = by_kind.setdefault(kind, {"total": 0, "ok": 0, "notes": 0})
        stats["total"] += 1
        stats["ok"] += int(bool(record.get("ok")))
        stats["notes"] += int(bool(record.get("notes")))

    lines = [
        "# Brotato实体单页抓取报告",
        "",
        f"生成时间（UTC）：{dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()}",
        "",
        f"总实体数：{total}",
        f"成功抓取：{ok}",
        f"含Notes章节：{with_notes}",
        "",
        "## 分类统计",
        "",
        "| 类型 | 总数 | 成功抓取 | 含Notes |",
        "|---|---:|---:|---:|",
    ]
    for kind in sorted(by_kind):
        stats = by_kind[kind]
        lines.append(f"| {kind} | {stats['total']} | {stats['ok']} | {stats['notes']} |")

    failed = [record for record in records if not record.get("ok")]
    lines.extend(["", "## 抓取失败", ""])
    if failed:
        for record in failed:
            lines.append(f"- {record.get('kind')} / {record.get('name')}: {record.get('errors')}")
    else:
        lines.append("- 无")

    lines.extend(
        [
            "",
            "## 输出文件",
            "",
            "- `raw_entity_html/`：实体单页原始HTML。",
            "- `parsed/entity_pages.json`：每个实体的章节文本与Notes。",
            "- `parsed/csv/entity_notes.csv`：便于筛选的Notes CSV。",
            "",
            "## 口径说明",
            "",
            "单页Notes是机制边界和特殊交互的重要来源，但仍属于Wiki公开资料层。若Notes与原始模板或主表冲突，必须在差异报告中保留冲突，而不是静默覆盖。",
        ]
    )
    if not include_enemies:
        lines.extend(
            [
                "",
                "敌人默认不按单页抓取，因为多数敌人没有独立页面；敌人数据以 `raw_html/Enemies.html` 和 `parsed/html_tables/Enemies.tables.json` 为准。需要测试敌人单页URL时可使用 `--include-enemies`。",
            ]
        )
    (snapshot_dir / "实体单页抓取报告.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--date", default="2026-05-11", help="Snapshot folder name under 数据快照/")
    parser.add_argument("--delay", type=float, default=0.12, help="Delay between HTTP requests.")
    parser.add_argument("--refresh", action="store_true", help="Refetch pages even when cached HTML exists.")
    parser.add_argument("--include-enemies", action="store_true", help="Also attempt individual enemy pages. Most enemy data lives on Enemies, not separate pages.")
    parser.add_argument("--limit", type=int, default=0, help="Debug limit.")
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[1]
    snapshot_dir = root / "数据快照" / args.date
    parsed_dir = snapshot_dir / "parsed"
    parsed_dir.mkdir(parents=True, exist_ok=True)

    entities = load_entity_index(snapshot_dir)
    if args.include_enemies:
        entities += load_enemy_entities(snapshot_dir)
    # Deduplicate by kind + name while preserving order.
    deduped = []
    seen = set()
    for entity in entities:
        key = (entity["kind"], entity["name"].lower())
        if key in seen:
            continue
        seen.add(key)
        deduped.append(entity)
    entities = deduped[: args.limit or None]

    records = []
    for index, entity in enumerate(entities, start=1):
        records.append(fetch_entity(entity, snapshot_dir, args.refresh))
        if index < len(entities):
            time.sleep(args.delay)

    write_json(parsed_dir / "entity_pages.json", records)
    write_notes_csv(parsed_dir / "csv" / "entity_notes.csv", records)
    write_report(snapshot_dir, records, args.include_enemies)

    summary = {
        "snapshot_dir": str(snapshot_dir),
        "entities": len(records),
        "ok": sum(1 for record in records if record.get("ok")),
        "with_notes": sum(1 for record in records if record.get("notes")),
    }
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
