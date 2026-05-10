#!/usr/bin/env python3
"""Verify the local Brotato Wiki snapshot against the current documented口径."""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from pathlib import Path


EXPECTED = {
    "wiki_version": "1.1.10.9",
    "characters": 62,
    "weapons": 77,
    "items_template": 239,
    "elites": 8,
    "bosses": 2,
    "html_tables": 219,
    "weapon_tiers": 308,
    "template_fields_long": 3426,
    "template_field_index": 34,
    "html_table_index": 219,
    "html_table_csv_files": 219,
    "entity_total": 388,
    "entity_ok": 385,
    "entity_notes": 68,
    "enemy_active": 66,
    "enemy_with_unused": 67,
}


def read_csv_rows(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle))


def check_equal(results: list[dict[str, object]], name: str, got: object, expected: object) -> None:
    results.append(
        {
            "check": name,
            "got": got,
            "expected": expected,
            "ok": got == expected,
        }
    )


def count_enemy_rows(snapshot_dir: Path) -> tuple[int, int]:
    table_dir = snapshot_dir / "parsed" / "csv" / "html_tables"
    active = 0
    for index in [0, 1, 2, 3, 4, 5]:
        matches = list(table_dir.glob(f"Enemies.table_{index:02d}.*.csv"))
        if len(matches) != 1:
            raise RuntimeError(f"Expected one Enemies table {index:02d}, found {len(matches)}")
        active += len(read_csv_rows(matches[0]))

    unused_matches = list(table_dir.glob("Enemies.table_07.*.csv"))
    if len(unused_matches) != 1:
        raise RuntimeError(f"Expected one Enemies unused table, found {len(unused_matches)}")
    with_unused = active + len(read_csv_rows(unused_matches[0]))
    return active, with_unused


def parse_entity_report(snapshot_dir: Path) -> dict[str, int]:
    report_path = snapshot_dir / "实体单页抓取报告.md"
    report = report_path.read_text(encoding="utf-8")
    values: dict[str, int] = {}
    for label, key in [("总实体数", "total"), ("成功抓取", "ok"), ("含Notes章节", "notes")]:
        match = re.search(label + r"：(\d+)", report)
        if not match:
            raise RuntimeError(f"Missing {label} in {report_path}")
        values[key] = int(match.group(1))
    return values


def verify(snapshot_dir: Path) -> dict[str, object]:
    snapshot = json.loads((snapshot_dir / "parsed" / "brotato_wiki_snapshot.json").read_text(encoding="utf-8"))
    csv_dir = snapshot_dir / "parsed" / "csv"
    results: list[dict[str, object]] = []

    metadata = snapshot["metadata"]
    counts = snapshot["counts"]
    check_equal(results, "wiki_version", metadata["wiki_version"], EXPECTED["wiki_version"])
    check_equal(results, "characters", counts["characters"], EXPECTED["characters"])
    check_equal(results, "weapons", counts["weapons"], EXPECTED["weapons"])
    check_equal(results, "items_template", counts["items"], EXPECTED["items_template"])
    check_equal(results, "elites", counts["elites"], EXPECTED["elites"])
    check_equal(results, "bosses", counts["bosses"], EXPECTED["bosses"])
    check_equal(results, "html_tables", counts["html_tables"], EXPECTED["html_tables"])

    check_equal(results, "weapon_tiers.csv rows", len(read_csv_rows(csv_dir / "weapon_tiers.csv")), EXPECTED["weapon_tiers"])
    check_equal(results, "template_fields_long.csv rows", len(read_csv_rows(csv_dir / "template_fields_long.csv")), EXPECTED["template_fields_long"])
    check_equal(results, "template_field_index.csv rows", len(read_csv_rows(csv_dir / "template_field_index.csv")), EXPECTED["template_field_index"])
    check_equal(results, "html_table_index.csv rows", len(read_csv_rows(csv_dir / "html_table_index.csv")), EXPECTED["html_table_index"])
    check_equal(results, "html table csv files", len(list((csv_dir / "html_tables").glob("*.csv"))), EXPECTED["html_table_csv_files"])

    item_check = snapshot["source_cross_checks"]["items"]
    check_equal(results, "items page declared total", item_check["declared_by_items_page"]["total"], 237)
    check_equal(results, "items page main table rows", item_check["items_main_table_rows"], 231)
    check_equal(results, "item data template entries", item_check["item_data_template_entries"], EXPECTED["items_template"])

    formula = snapshot["shop_formula"]
    check_equal(results, "shop reroll increase", formula.get("reroll_increase"), "Rounddown(0.40 * Wave Number) (Minimum of 1)")
    check_equal(results, "shop first reroll price", formula.get("first_reroll_price"), "Rounddown(Wave Number * 0.75) + Reroll Increase")

    active_enemies, enemies_with_unused = count_enemy_rows(snapshot_dir)
    check_equal(results, "enemy active rows", active_enemies, EXPECTED["enemy_active"])
    check_equal(results, "enemy rows with unused", enemies_with_unused, EXPECTED["enemy_with_unused"])

    entity_report = parse_entity_report(snapshot_dir)
    check_equal(results, "entity total", entity_report["total"], EXPECTED["entity_total"])
    check_equal(results, "entity ok", entity_report["ok"], EXPECTED["entity_ok"])
    check_equal(results, "entity notes", entity_report["notes"], EXPECTED["entity_notes"])

    ok = all(item["ok"] for item in results)
    return {"snapshot_dir": str(snapshot_dir), "ok": ok, "results": results}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("snapshot_dir", nargs="?", default=str(Path(__file__).resolve().parents[1] / "数据快照" / "2026-05-11"))
    args = parser.parse_args()

    result = verify(Path(args.snapshot_dir))
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
