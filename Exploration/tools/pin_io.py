#!/usr/bin/env python3
"""Shared Generated.lua pin parse/emit that preserves full pin source text.

Used by nn_reorder_route.py and areatable_audit_nn.py so reorders never strip
triggers, notes, radii, actions, or preceding -- comments.
"""
from __future__ import annotations

import re
from typing import Any


def extract_route_block(text: str, route: str) -> tuple[int, int, str]:
    """Return (start, end, block) for R[\"route\"] = { ... }."""
    m = re.search(rf'R\["{re.escape(route)}"\] = \{{', text)
    if not m:
        raise KeyError(f"route not found: {route}")
    start = m.start()
    m2 = re.search(r'\nR\["', text[start + 1 :])
    end = start + 1 + m2.start() if m2 else len(text)
    return start, end, text[start:end]


def _find_route_array(block: str) -> tuple[int, int]:
    """Return [content_start, closing_brace_index] for route = { ... }."""
    rm = re.search(r"route\s*=\s*\{", block)
    if not rm:
        raise ValueError("no route = { in block")
    depth = 0
    i = rm.end() - 1
    content_start = rm.end()
    while i < len(block):
        ch = block[i]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return content_start, i
        i += 1
    raise ValueError("unclosed route = {")


def _scan_balanced_table(s: str, open_idx: int) -> int:
    """Given index of '{', return index of matching '}'."""
    depth = 0
    i = open_idx
    in_str = False
    esc = False
    while i < len(s):
        ch = s[i]
        if in_str:
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == '"':
                in_str = False
        else:
            if ch == '"':
                in_str = True
            elif ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    return i
        i += 1
    raise ValueError("unbalanced table")


def parse_route_pins(block: str) -> list[dict[str, Any]]:
    """Parse explore/travel pins from a route block, keeping raw source + comments.

    Each pin dict:
      name, map, x, y, travel, raw (full text including leading comments/indent),
      and optional fields parsed for tooling.
    Non-pin entries (switch tables, bare strings) are skipped for NN but the
    rewriter only replaces the pin list when used carefully — see emit helpers.
    """
    content_start, content_end = _find_route_array(block)
    body = block[content_start:content_end]
    pins: list[dict[str, Any]] = []

    i = 0
    n = len(body)
    while i < n:
        # Skip whitespace
        while i < n and body[i] in " \t\r\n":
            i += 1
        if i >= n:
            break

        # Collect contiguous leading comment lines + blank lines immediately above a pin
        comment_start = i
        while i < n:
            # line start
            line_end = body.find("\n", i)
            if line_end < 0:
                line_end = n
            line = body[i:line_end]
            stripped = line.strip()
            if stripped.startswith("--") or stripped == "":
                i = line_end + 1 if line_end < n else n
                continue
            break

        if i >= n:
            break

        # Skip switch / nested non-pin tables that don't start with { name =
        # Find next '{'
        while i < n and body[i] in " \t\r\n":
            i += 1
        if i >= n:
            break

        # Bare string entries: "Some Route",
        if body[i] == '"':
            # skip to next comma or end
            j = i + 1
            while j < n and not (body[j] == '"' and body[j - 1] != "\\"):
                j += 1
            j += 1
            while j < n and body[j] in " \t\r\n,":
                j += 1
            i = j
            continue

        if body[i] != "{":
            # unknown token — advance one char to avoid infinite loop
            i += 1
            continue

        # Peek: must look like a pin ({ name = ...})
        peek = body[i : i + 80]
        if not re.match(r'\{\s*name\s*=', peek):
            # nested switch table etc. — skip balanced
            close = _scan_balanced_table(body, i)
            i = close + 1
            while i < n and body[i] in " \t\r\n,":
                i += 1
            continue

        close = _scan_balanced_table(body, i)
        pin_src = body[i : close + 1]
        # include trailing comma + newline if present
        j = close + 1
        while j < n and body[j] in " \t":
            j += 1
        if j < n and body[j] == ",":
            j += 1
        if j < n and body[j] == "\n":
            j += 1

        raw = body[comment_start:j]
        # Ensure raw ends with newline for clean joining
        if not raw.endswith("\n"):
            raw = raw.rstrip() + "\n"

        name_m = re.search(r'name\s*=\s*"([^"]+)"', pin_src)
        map_m = re.search(r"map\s*=\s*(\d+)", pin_src)
        x_m = re.search(r"x\s*=\s*([\d.]+)", pin_src)
        y_m = re.search(r"y\s*=\s*([\d.]+)", pin_src)
        if not (name_m and map_m and x_m and y_m):
            i = j
            continue

        pins.append(
            {
                "name": name_m.group(1),
                "map": int(map_m.group(1)),
                "x": float(x_m.group(1)),
                "y": float(y_m.group(1)),
                "travel": bool(re.search(r"travel\s*=\s*true", pin_src)),
                "raw": raw,
                "pin_src": pin_src,
            }
        )
        i = j

    return pins


def emit_pin_raw(p: dict[str, Any]) -> str:
    """Emit preserved raw pin text (comments + full fields).

    Always ends with a trailing comma so reorders never place a comma-less
    pin between two neighbors (Lua syntax error).
    """
    raw = p.get("raw")
    if raw:
        if not raw.endswith("\n"):
            raw = raw + "\n"
        # Ensure `},` before the final newline (last route pin often omits comma).
        body = raw.rstrip("\n")
        stripped = body.rstrip()
        if stripped.endswith("}"):
            # Already `},` or just `}`
            if not stripped.endswith("},"):
                body = stripped + ","
            else:
                body = stripped
            return body + "\n"
        return raw
    # Fallback for newly constructed pins (audit adds)
    xs = f"{float(p['x']):.2f}"
    ys = f"{float(p['y']):.2f}"
    travel = ""
    if p.get("travel"):
        note = p.get("note") or ""
        note_part = f', note = "{note}"' if note else ""
        travel = f", travel = true{note_part}"
    return (
        f'        {{ name = "{p["name"]}", map = {p["map"]}, '
        f"x = {xs}, y = {ys}{travel}, trigger = {{ type = \"proximity\" }} }},\n"
    )


def replace_route_pins(block: str, pins: list[dict[str, Any]]) -> str:
    """Replace the contents of route = { ... } with emitted pins (preserve header)."""
    content_start, content_end = _find_route_array(block)
    body = "".join(emit_pin_raw(p) for p in pins)
    # Keep indentation consistency: body already includes per-pin indent from raw
    if body and not body.startswith("\n"):
        body = "\n" + body
    if not body.endswith("\n"):
        body += "\n"
    return block[:content_start] + body + "    " + block[content_end:]
