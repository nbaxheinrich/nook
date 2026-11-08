#!/usr/bin/env python3
"""Point Zed at the Nook theme and the monospace font, keeping the rest of settings.json.

usage: zed.py SETTINGS_JSON FONT

Zed's settings.json is JSON with comments and trailing commas, so it is edited as text: only the
top-level keys set here are replaced (or added at the top), every other byte stays as it was.
"""
import json
import sys
from pathlib import Path


def skip_ws(s, i):
    """Skip whitespace and // or /* */ comments."""
    while i < len(s):
        if s[i].isspace():
            i += 1
        elif s.startswith("//", i):
            j = s.find("\n", i)
            i = len(s) if j < 0 else j + 1
        elif s.startswith("/*", i):
            j = s.find("*/", i + 2)
            i = len(s) if j < 0 else j + 2
        else:
            break
    return i


def skip_string(s, i):
    i += 1
    while s[i] != '"':
        i += 2 if s[i] == "\\" else 1
    return i + 1


def skip_value(s, i):
    if s[i] == '"':
        return skip_string(s, i)
    if s[i] in "{[":
        depth = 0
        while True:
            i = skip_ws(s, i)
            c = s[i]
            if c == '"':
                i = skip_string(s, i)
                continue
            if c in "{[":
                depth += 1
            elif c in "}]":
                depth -= 1
                if depth == 0:
                    return i + 1
            i += 1
    while i < len(s) and s[i] not in ",}] \t\r\n/":   # number, true, false, null
        i += 1
    return i


def top_level(s):
    """Return ({key: (value_start, value_end)}, index just after the opening brace)."""
    i = skip_ws(s, 0)
    if i >= len(s) or s[i] != "{":
        raise ValueError("settings.json does not hold a JSON object")
    body = i = i + 1
    keys = {}
    while True:
        i = skip_ws(s, i)
        if s[i] == "}":
            return keys, body
        end = skip_string(s, i)
        key = json.loads(s[i:end])
        i = skip_ws(s, end)
        if s[i] != ":":
            raise ValueError(f"expected ':' after {key!r}")
        start = skip_ws(s, i + 1)
        stop = skip_value(s, start)
        keys[key] = (start, stop)
        i = skip_ws(s, stop)
        if s[i] == ",":
            i += 1


def main(path, font):
    want = {"theme": "Nook"}
    if font != "Monospace":
        want |= {"buffer_font_family": font, "ui_font_family": font}
    p = Path(path)
    s = p.read_text() if p.exists() else ""
    if not s.strip():
        s = "{\n}\n"
    keys, body = top_level(s)
    # Replace from the end backwards so earlier offsets stay valid.
    for key, (a, b) in sorted(((k, keys[k]) for k in want if k in keys), key=lambda kv: -kv[1][0]):
        s = s[:a] + json.dumps(want[key]) + s[b:]
    new = "".join(f'\n  {json.dumps(k)}: {json.dumps(v)},' for k, v in want.items() if k not in keys)
    s = s[:body] + new + s[body:]
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(s)


if __name__ == "__main__":
    main(*sys.argv[1:3])
