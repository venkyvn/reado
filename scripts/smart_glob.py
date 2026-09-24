#!/usr/bin/env python3
"""
smart_glob.py — Tìm file trong workspace có lọc cache + generated, trả kết quả gọn.

Vấn đề: `glob **/*.md` trước trả 123 kết quả (~15k token để đọc danh sách), đa phần là
.agents/skills/*, .xcode-packages/*, qr/v2/*, design-system/* — không liên quan task.
Tool này loại hết trong .gitignore.

Cách dùng (từ gốc repo):
    python3 scripts/smart_glob.py --ext .md                      # toàn bộ md
    python3 scripts/smart_glob.py --ext .swift                   # file swift (app/)
    python3 scripts/smart_glob.py --ext .swift --root app        # chỉ app/
    python3 scripts/smart_glob.py --name "*.pbxproj"             # theo tên
    python3 scripts/smart_glob.py --all                          # liệt kê mọi file
    python3 scripts/smart_glob.py --ext .md --limit 20           # giới hạn output (~token tiết kiệm)

Mặc định LOẠI trừ (giống AGENTS.md §2a + cache build):
    DerivedData/ .tmp/ .xcode-packages/ .build/ .swiftpm/ node_modules/ .git/
    app/DerivedData/ app/.tmp/ app/.xcode-packages/
    + đuôi binary/generated: .o .dia .pcm .scan .d .png .jpg .jpeg .xcassets(nested) ...

Output:
    - Luôn in tổng số file tìm được.
    - Nếu ≤ 8: in đầy đủ path.
    - Nếu > 8: in 8 đầu + '(8 + n more — tổng X).' → agent gọi --ext với --limit hoặc grep để
      thu hẹp, KHÔNG phải đọc cả 123 path.
    - Tuỳ chọn --json cho máy đọc.

Không tuân theo --root thì mặc định gốc workspace; path in ra tương đối so với --root.
"""

import argparse
import json
import os
import sys
from pathlib import Path

# Cache/generated/excluded — mặc định LUÔN loại
EXCLUDE_DIRS = {
    "DerivedData", ".tmp", ".xcode-packages", ".build", ".swiftpm",
    "node_modules", ".git", ".agents", "design-system", "qr", "ref",
    "vendor", "Pods",
}

EXCLUDE_EXT = {
    ".o", ".dia", ".pcm", ".scan", ".d", ".png", ".jpg", ".jpeg",
    ".gif", ".webp", ".a", ".framework", ".xcframework", ".ipa", ".zip",
    ".xcassets", ".dylib", ".tbd", ".modulemap", ".swiftmodule", ".swiftdoc",
    ".dSYM",
}

def should_exclude(rel: Path) -> bool:
    """Trả True nếu path nằm trong thư mục bị loại, hoặc đuôi bị loại."""
    parts = rel.parts
    for part in parts:
        if part in EXCLUDE_DIRS:
            return True
    if rel.suffix.lower() in EXCLUDE_EXT:
        return True
    # loại cả files bắt đầu bằng "." (ẩn, ví dụ .DS_Store)
    if any(p.startswith(".") for p in parts):
        return True
    return False


def main():
    ap = argparse.ArgumentParser(description="Tìm files trong workspace, lọc cache/generated")
    ap.add_argument("--root", default=".", help="thư mục gốc (mặc định .)")
    ap.add_argument("--ext", action="append", help="đuôi file, ví dụ --ext .md, có thể lặp")
    ap.add_argument("--name", help="glob tên file, ví dụ --name '*.pbxproj'")
    ap.add_argument("--not-ext", action="append", default=[], help="đuôi bị loại thêm")
    ap.add_argument("--include-cache", action="store_true", help="BẬT cả cache (không khuyến khích)")
    ap.add_argument("--all", action="store_true", help="liệt kê mọi file (không lọc theo điều kiện)")
    ap.add_argument("--limit", type=int, default=8, help="số path in tối đa trước khi thu hẹp")
    ap.add_argument("--json", action="store_true", help="xuất JSON")
    args = ap.parse_args()

    root = Path(args.root).resolve()
    if not root.is_dir():
        raise SystemExit(f"root không tồn tại: {root}")

    # valid extensions
    exts = {e.lower() if e.startswith(".") else "." + e.lower() for e in (args.ext or [])}
    not_exts = {e.lower() if e.startswith(".") else "." + e.lower() for e in args.not_ext}

    results = []
    for p in root.rglob("*"):
        if not p.is_file():
            continue
        rel = p.relative_to(root)
        if should_exclude(rel):
            continue
        if args.all:
            results.append(rel.as_posix())
            continue
        if exts and p.suffix.lower() not in exts:
            continue
        if p.suffix.lower() in not_exts:
            continue
        if args.name:
            import fnmatch
            if not fnmatch.fnmatch(p.name, args.name):
                continue
        if not exts and not args.name:
            # không điều kiện
            continue
        results.append(rel.as_posix())

    results.sort()

    total = len(results)
    if args.json:
        print(json.dumps({"count": total, "paths": results}, ensure_ascii=False))
        return

    display = results[: args.limit] if total > args.limit else results
    for r in display:
        print(r)
    if total > args.limit:
        print(f"\n… +{total - args.limit} more — tổng {total} file. "
              f"Dùng --ext --limit hoặc grep để thu hẹp, đừng đọc hết.")

    print(f"\nTổng {total} file.")


if __name__ == "__main__":
    main()