#!/usr/bin/env python3
"""Audit Mega-Journey spine + nested Cataclysm Journey for missing travel."""
from __future__ import annotations

import re
import sys
from pathlib import Path

GENERATED = Path(__file__).resolve().parents[1] / "Data" / "Routes" / "Generated.lua"
sys.stdout.reconfigure(encoding="utf-8", errors="replace")


def classify(name: str) -> str:
    n = name.lower()
    if "getting there" in n or n.endswith(" post reset") or "finale" in n:
        return "travel"
    if " to " in n or "travel -" in n:
        return "travel"
    if "exploration" in n:
        return "explore"
    if name.startswith("Midnight - ") or name.startswith("The War Within - "):
        return "explore"
    if name.startswith("Cataclysm - ") and "travel" not in n and "getting there" not in n:
        if "finale" in n:
            return "travel"
        return "explore"
    if name in {"WoD - Exploration", "Cataclysm - Journey"}:
        return "explore"
    return "other"


def audit_sequence(label: str, leaves: list[str]) -> list[tuple[str, str]]:
    print(f"\n=== {label} ({len(leaves)} leaves) ===")
    issues = []
    for i in range(len(leaves) - 1):
        a, b = leaves[i], leaves[i + 1]
        ca, cb = classify(a), classify(b)
        flag = ""
        if ca == "explore" and cb == "explore":
            flag = " MISSING TRAVEL"
            issues.append((a, b))
        print(f"  {i:02d}->{i+1:02d} [{ca}->{cb}]{flag}")
        print(f"    {a}")
        print(f"    {b}")
    return issues


def main() -> None:
    text = GENERATED.read_text(encoding="utf-8")
    m = re.search(
        r'R\["Exploration Mega-Journey"\]\s*=\s*\{.*?route\s*=\s*\{([^}]+)\}',
        text,
        re.S,
    )
    if not m:
        raise SystemExit("Mega-Journey route not found")
    mega = re.findall(r'"([^"]+)"', m.group(1))
    all_issues = audit_sequence("Mega-Journey", mega)

    # Nested Cataclysm Journey faction route lists
    jm = re.search(r'R\["Cataclysm - Journey"\]\s*=\s*\{(.*?)\nR\["', text, re.S)
    if jm:
        block = jm.group(1)
        for label, pat in (
            ("Cata Journey Alliance", r'faction = "Alliance".*?routes\s*=\s*\{([^}]+)\}'),
            ("Cata Journey Horde", r'\{\s*routes\s*=\s*\{([^}]+)\}'),
        ):
            mm = re.search(pat, block, re.S)
            if mm:
                leaves = re.findall(r'"([^"]+)"', mm.group(1))
                all_issues.extend(audit_sequence(label, leaves))

    print("\n=== ALL GAPS ===")
    if not all_issues:
        print("None — every explore chapter is separated by travel.")
    else:
        for a, b in all_issues:
            print(f"  {a}  =>  {b}")
        raise SystemExit(1)


if __name__ == "__main__":
    main()
