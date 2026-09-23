#!/usr/bin/env python3
"""Fail when a relative Markdown link in the repo points at a missing file."""

import os
import re
import sys
from pathlib import Path

SKIP_DIRS = {"_build", ".git", ".mooncakes", ".moonagent", "outputs", "node_modules", "__pycache__"}
LINK_RE = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")


def iter_markdown(root: Path):
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for name in filenames:
            if name.endswith(".md"):
                yield Path(dirpath) / name


def main() -> int:
    root = Path(__file__).resolve().parent.parent
    broken = []
    for md in iter_markdown(root):
        text = md.read_text(encoding="utf-8")
        for target in LINK_RE.findall(text):
            if target.startswith(("http://", "https://", "mailto:", "#")):
                continue
            path = target.split("#", 1)[0]
            if not path:
                continue
            resolved = (md.parent / path).resolve()
            if not resolved.exists():
                broken.append((md.relative_to(root), target))
    for md, target in broken:
        print(f"{md}: broken link {target}")
    if broken:
        print(f"{len(broken)} broken link(s)")
        return 1
    print("all relative links resolve")
    return 0


if __name__ == "__main__":
    sys.exit(main())
