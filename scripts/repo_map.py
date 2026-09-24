#!/usr/bin/env python3
"""
repo_map.py — tree thư mục Swift + signature (protocol / public types / public func).

Stdout only. Không ghi docs/ — file generated bust prompt cache.

Cách dùng (gốc repo):
    python3 scripts/repo_map.py
    python3 scripts/repo_map.py --root app/ReadoKit/Sources --limit 40
    python3 scripts/repo_map.py --tree-only
    python3 scripts/repo_map.py --sigs-only
"""

from __future__ import annotations

import argparse
import re
import sys
from collections import defaultdict
from pathlib import Path

EXCLUDE_DIRS = {
    "DerivedData",
    ".tmp",
    ".xcode-packages",
    ".build",
    ".swiftpm",
    "node_modules",
    ".git",
}

DEFAULT_ROOTS = (
    "app/Reado",
    "app/ReadoKit/Sources",
    "app/ReadoTests",
)

# public/open types + mọi protocol (kể internal) + public/open func
SIG_RE = re.compile(
    r"^\s*(?:"
    r"(?:(?:public|open|package)\s+)+(?:(?:final|indirect|class)\s+)*"
    r"(?:protocol|struct|class|enum|actor|func|typealias)\s+"
    r"|"
    r"protocol\s+"
    r")"
    r"([A-Za-z_][A-Za-z0-9_]*)"
)


def repo_root() -> Path:
    return Path(__file__).resolve().parent.parent


def should_exclude(rel: Path) -> bool:
    return any(part in EXCLUDE_DIRS or part.startswith(".") for part in rel.parts)


def iter_swift(base: Path) -> list[Path]:
    if not base.is_dir():
        return []
    out: list[Path] = []
    for p in base.rglob("*.swift"):
        try:
            rel = p.relative_to(base)
        except ValueError:
            continue
        if should_exclude(rel):
            continue
        out.append(p)
    return sorted(out)


def print_tree(label: str, base: Path, files: list[Path]) -> None:
    print(f"## {label}")
    if not files:
        print("  (không có .swift hoặc path không tồn tại)")
        print()
        return
    dirs: set[str] = set()
    for f in files:
        rel = f.relative_to(base)
        parts = rel.parts[:-1]
        acc = []
        for part in parts:
            acc.append(part)
            dirs.add("/".join(acc))
        dirs.add(rel.as_posix())
    for d in sorted(dirs, key=lambda s: s.lower()):
        depth = d.count("/")
        name = d.split("/")[-1]
        print(f"{'  ' * depth}{name}")
    print()


def module_key(path: Path, repo: Path) -> str:
    rel = path.relative_to(repo)
    dirs = [p for p in rel.parts[:-1] if p not in ("app", "Sources")]
    if len(dirs) >= 2:
        return f"{dirs[0]}/{dirs[-1]}"
    if dirs:
        return dirs[0]
    return path.parent.name


def extract_sigs(path: Path) -> list[str]:
    lines_out: list[str] = []
    try:
        text = path.read_text(encoding="utf-8")
    except OSError:
        return lines_out
    for raw in text.splitlines():
        line = raw.rstrip()
        stripped = line.lstrip()
        if stripped.startswith("//") or stripped.startswith("/*") or stripped.startswith("*"):
            continue
        if SIG_RE.search(line):
            lines_out.append(re.sub(r"\s+", " ", stripped)[:160])
    return lines_out


def main() -> None:
    ap = argparse.ArgumentParser(description="Tree + Swift signatures (stdout)")
    ap.add_argument(
        "--root",
        action="append",
        dest="roots",
        help="thư mục con (lặp được). Mặc định: Reado + ReadoKit/Sources + ReadoTests",
    )
    ap.add_argument("--limit", type=int, default=80, help="số dòng signature in ra (mặc định 80)")
    ap.add_argument("--tree-only", action="store_true")
    ap.add_argument("--sigs-only", action="store_true")
    args = ap.parse_args()

    root = repo_root()
    rels = args.roots or list(DEFAULT_ROOTS)
    bases = [(label, (root / label).resolve()) for label in rels]
    missing = [label for label, p in bases if not p.is_dir()]
    existing = [(label, p) for label, p in bases if p.is_dir()]
    for label in missing:
        print(f"# thiếu path: {label}", file=sys.stderr)

    all_files: list[tuple[str, Path, Path]] = []
    for label, base in existing:
        for f in iter_swift(base):
            all_files.append((label, base, f))

    if not args.sigs_only:
        print(f"# repo_map  swift_files={len(all_files)}")
        print()
        for label, base in existing:
            files = [f for lab, b, f in all_files if lab == label]
            print_tree(label, base, files)

    if args.tree_only:
        return

    grouped: dict[str, list[tuple[Path, str]]] = defaultdict(list)
    for _label, base, f in all_files:
        key = module_key(f, root)
        rel = f.relative_to(base)
        for sig in extract_sigs(f):
            grouped[key].append((rel, sig))

    printed = 0
    limit = max(0, args.limit)
    total_sigs = sum(len(v) for v in grouped.values())
    print("## signatures")
    for key in sorted(grouped):
        if printed >= limit:
            break
        print(f"### {key}")
        for rel, sig in grouped[key]:
            if printed >= limit:
                break
            print(f"  {rel.as_posix()}: {sig}")
            printed += 1
        print()

    if total_sigs > printed:
        print(
            f"… +{total_sigs - printed} more — tổng {total_sigs} signature. "
            "Thu hẹp --root hoặc tăng --limit, đừng glob **/*.swift."
        )


if __name__ == "__main__":
    main()
