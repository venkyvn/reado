#!/usr/bin/env python3
r"""
pbxproj_tool.py — kiểm tra project.pbxproj (synchronized folders, ADR-046).

Từ B1 repo-hygiene-r1, `Reado` và `ReadoTests` là PBXFileSystemSynchronizedRootGroup:
Xcode tự nhận mọi file trong thư mục, không còn 4 dấu vết/file → không còn `add`/`remove`.
Thêm/xoá/di chuyển file Swift = tạo/xoá/`git mv` trong app/Reado hoặc app/ReadoTests.

Cách dùng (chạy từ gốc repo):
    python3 scripts/pbxproj_tool.py check   # cổng của scripts/test.sh; exit 1 nếu lệch
    python3 scripts/pbxproj_tool.py list    # xem objectVersion, root group, target, exception set

`check` bắt các dấu hiệu quay lại kiểu cũ hoặc file bị loại khỏi target ngầm:
  1. objectVersion >= 70 (synchronized folders)
  2. Reado + ReadoTests là root group đồng bộ, mỗi target gắn đúng group cùng tên
  3. không còn PBXFileReference .swift / PBXBuildFile "in Sources" rời (ai đó thêm file kiểu cũ)
  4. không có exception set (file trong membershipExceptions bị LOẠI khỏi target — skip ngầm)
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path

MIN_OBJECT_VERSION = 70
TARGETS = ("Reado", "ReadoTests")


def find_pbxproj(root: Path) -> Path:
    """Tìm project.pbxproj duy nhất, bỏ .xcode-packages / DerivedData."""
    candidates = [
        p for p in root.rglob("project.pbxproj")
        if ".xcode-packages" not in p.as_posix() and "DerivedData" not in p.as_posix()
    ]
    if len(candidates) == 1:
        return candidates[0]
    if candidates:
        raise SystemExit(f"Tìm thấy {len(candidates)} pbxproj, dùng --pbxproj: {candidates}")
    raise SystemExit("Không tìm thấy project.pbxproj trong workspace")


def parse(content: str) -> dict:
    m = re.search(r"objectVersion = (\d+);", content)
    version = int(m.group(1)) if m else 0

    # root group đồng bộ: id -> path. Không dùng regex bao cả block vì
    # `explicitFileTypes = {};` chứa "};" làm cụt block → nhìn từ "isa" tới "isa" kế tiếp.
    roots = {}
    for m in re.finditer(r"isa = PBXFileSystemSynchronizedRootGroup;", content):
        head = content[:m.start()]
        ids = re.findall(r"\b([0-9A-Fa-f]{24})\b", head[-200:])
        tail = content[m.end():]
        nxt = re.search(r"isa = ", tail)
        body = tail[: nxt.start() if nxt else 600]
        p = re.search(r"path = \"?([^\";]+)\"?;", body)
        if ids and p:
            roots[ids[-1]] = p.group(1)

    # target -> id các root group đồng bộ đang gắn
    targets = {}
    for m in re.finditer(r"/\* (Reado|ReadoTests) \*/ = \{\s*isa = PBXNativeTarget;", content):
        tail = content[m.end():]
        nxt = re.search(r"isa = PBXNativeTarget;|End PBXNativeTarget section", tail)
        body = tail[: nxt.start() if nxt else len(tail)]
        g = re.search(r"fileSystemSynchronizedGroups = \(([^)]*)\)", body)
        targets[m.group(1)] = re.findall(r"\b([0-9A-Fa-f]{24})\b", g.group(1)) if g else []

    exceptions = []
    for m in re.finditer(r"membershipExceptions = \(([^)]*)\)", content):
        exceptions += [x.strip().strip('",') for x in m.group(1).splitlines() if x.strip()]

    return {"version": version, "roots": roots, "targets": targets, "exceptions": exceptions}


def tracked_swift_count(root: Path) -> int:
    try:
        out = subprocess.run(
            ["git", "ls-files", "app/Reado", "app/ReadoTests"],
            cwd=root, capture_output=True, text=True, check=True,
        ).stdout.splitlines()
    except Exception:
        return -1
    return sum(1 for f in out if f.endswith(".swift"))


def check_project(pbxproj: Path) -> int:
    content = pbxproj.read_text(encoding="utf-8")
    info = parse(content)
    errors = []

    if info["version"] < MIN_OBJECT_VERSION:
        errors.append(f"objectVersion = {info['version']} (< {MIN_OBJECT_VERSION}) — chưa phải synchronized folders; "
                      "nhờ fen Convert to Folder trong Xcode")

    root_paths = set(info["roots"].values())
    for name in TARGETS:
        if name not in root_paths:
            errors.append(f"thiếu PBXFileSystemSynchronizedRootGroup path = {name}")
        ids = info["targets"].get(name)
        if ids is None:
            errors.append(f"không thấy PBXNativeTarget {name}")
        elif not any(info["roots"].get(i) == name for i in ids):
            errors.append(f"target {name} không gắn root group đồng bộ cùng tên (fileSystemSynchronizedGroups)")

    if "sourcecode.swift" in content:
        errors.append("còn PBXFileReference .swift rời — file thêm kiểu cũ (group thường). "
                      "Xoá reference trong Xcode (Remove Reference), để thư mục tự nhận")
    if re.search(r"in Sources \*/ = \{isa = PBXBuildFile", content):
        errors.append("còn PBXBuildFile 'in Sources' rời — dấu vết kiểu cũ")

    if info["exceptions"]:
        errors.append("có exception set — các file này bị LOẠI khỏi target (dễ skip ngầm): "
                      + ", ".join(info["exceptions"]))

    if errors:
        for e in errors:
            print(f"LỖI: {e}")
        return 1

    n = tracked_swift_count(Path.cwd())
    print(f"OK: synchronized folders {' + '.join(TARGETS)} (objectVersion {info['version']}), "
          f"{n} file Swift đang track sẽ được Xcode tự nhận")
    return 0


def show_list(pbxproj: Path) -> None:
    info = parse(pbxproj.read_text(encoding="utf-8"))
    print(f"objectVersion: {info['version']}")
    print("== root group đồng bộ ==")
    for i, p in info["roots"].items():
        print(f"  {p:12s} ({i})")
    print("== target -> group ==")
    for t, ids in info["targets"].items():
        print(f"  {t:12s} -> {[info['roots'].get(i, i) for i in ids]}")
    print(f"== exception set: {len(info['exceptions'])} file ==")
    for e in info["exceptions"]:
        print(f"  {e}")


def main() -> None:
    ap = argparse.ArgumentParser(description="Kiểm project.pbxproj synchronized folders")
    ap.add_argument("action", choices=["check", "list", "add", "remove"])
    ap.add_argument("--pbxproj", help="đường dẫn pbxproj (mặc định tự tìm)")
    args, _ = ap.parse_known_args()

    if args.action in ("add", "remove"):
        raise SystemExit("Không cần nữa: tạo/xoá file trong app/Reado hoặc app/ReadoTests là "
                         "Xcode tự nhận (synchronized folders, ADR-046).")

    pbx = Path(args.pbxproj) if args.pbxproj else find_pbxproj(Path.cwd())
    if not pbx.exists():
        raise SystemExit(f"pbxproj không tồn tại: {pbx}")
    if args.action == "check":
        sys.exit(check_project(pbx))
    show_list(pbx)


if __name__ == "__main__":
    main()
