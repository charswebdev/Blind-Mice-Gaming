#!/usr/bin/env python3
"""Find/fix missing commas between adjacent pin tables in Generated.lua."""
from __future__ import annotations

import re
from pathlib import Path

GENERATED = Path(__file__).resolve().parents[1] / "Data" / "Routes" / "Generated.lua"

# Closing of a pin table then next pin starts without comma
PATTERN = re.compile(
    r'(\}\s*)\n(\{\s*name\s*=)',
)


def main() -> None:
    text = GENERATED.read_text(encoding="utf-8")
    # Only fix when previous close is not already followed by comma
    # Match: }\n{ name  where } is not },
    bad = list(re.finditer(r'\}\n(\{\s*name\s*=)', text))
    print(f"found {len(bad)} missing-comma site(s)")
    for m in bad:
        line = text.count("\n", 0, m.start()) + 1
        ctx = text[max(0, m.start() - 60) : m.start() + 40].replace("\n", "\\n")
        print(f"  line {line}: ...{ctx}...")

    if not bad:
        return

    new, n = re.subn(r'\}\n(\{\s*name\s*=)', r'},\n\1', text)
    GENERATED.write_text(new, encoding="utf-8", newline="\n")
    print(f"fixed {n}")


if __name__ == "__main__":
    main()
