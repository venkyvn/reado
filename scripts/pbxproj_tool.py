#!/usr/bin/env python3
r"""
pbxproj_tool.py — Thao tác project.pbxproj bằng lệnh, không edit tay.

Vấn đề: session trước agent edit pbxproj tay 12 lần (read toàn file 5 lần → đốt ~600k token).
Tool này gói gọn việc thêm/xoá file vào 1 lệnh, không cần read/edit tay.

Cách dùng (chạy từ gốc repo):
    python3 scripts/pbxproj_tool.py add \
        --pbxproj app/Reado.xcodeproj/project.pbxproj \
        --file app/Reado/NewScreen.swift \
        --group Reado \          # group chứa file: Reado | ReadoTests
        --target Reado \         # target: Reado | ReadoTests
        --comment "NewScreen.swift"

    python3 scripts/pbxproj_tool.py add --file app/ReadoTests/NewTests.swift --group ReadoTests --target ReadoTests

    python3 scripts/pbxproj_tool.py remove --file app/Reado/Obsolete.swift --group Reado --target Reado

    python3 scripts/pbxproj_tool.py list --pbxproj app/Reado.xcodeproj/project.pbxproj   # xem cấu trúc

    python3 scripts/pbxproj_tool.py check   # đối chiếu git ls-files vs 4 tham chiếu bắt buộc/file

WORKSPACE-AGNOSTIC: nhận pbxproj qua flag `--pbxproj` hoặc từ var env PBXPROJ, mặc định tìm
app/**/project.pbxproj (loại .xcode-packages).

Tiền điều kiện file: --file phải tồn tại trên đĩa (script resolve path tương đối so với
thư mục chứa app/), nếu không tự tạo empty. Có flag --touch để tự touch nếu chưa có.

ID scheme hoà hợp với project hiện có (Reado kit riêng, objectVersion 60):
  - fileRef        : 5B<0N>0000000000000000<xxxx>
  - buildFile      : 5C<0N>0000000000000000<xxxx>
    trong đó N = 1 (Reado), 2 (ReadoTests), <xxxx> = số thứ tự kế tiếp (hex, ≥ 1)
  Tool tự cấp ID kế tiếp bằng cách quét tất cả ID đang dùng.

Sau khi chạy: agent KHÔNG cần đọc lại pbxproj. Kiểm tra bằng:
    grep -c "NewScreen" app/Reado.xcodeproj/project.pbxproj   # phải ≥ 3 (fileRef+buildFile+buildPhase)
Build check: `scripts/test.sh` rồi grep /tmp/build.log.
"""

import argparse
import json
import os
import re
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def find_pbxproj(root: Path) -> Path:
    """Tìm project.pbxproj duy nhất, bỏ .xcode-packages / DerivedData."""
    candidates = []
    for p in root.rglob("project.pbxproj"):
        s = p.as_posix()
        if ".xcode-packages" in s or "DerivedData" in s:
            continue
        candidates.append(p)
    if len(candidates) == 1:
        return candidates[0]
    if len(candidates) > 1:
        raise SystemExit(f"Tìm thấy {len(candidates)} pbxproj, dùng --pbxproj: {candidates}")
    raise SystemExit("Không tìm thấy project.pbxproj trong workspace")


def existing_hex_ids(content: str, prefix: str) -> list:
    """Mọi id hex 24 ký tự bắt đầu bằng prefix (5B..., 5C...)."""
    pat = re.compile(re.escape(prefix) + r"[0-9A-Fa-f]{22}")
    return pat.findall(content)


def next_id(content: str, prefix: str, target_group: int) -> str:
    """ID kế tiếp: prefix + group digit + 1 hex byte + 14 hex số thứ tự."""
    used = set(existing_hex_ids(content, prefix))
    byte = 0
    while True:
        # bytes 3..4 là group 01/02 (không trùng) — tự tăng để tránh collision
        idx = 1
        while idx < 0x10:
            seed = f"{prefix}{target_group:02X}{byte:02X}{idx:04X}00000000000000"
            if len(seed) != 24:
                idx += 1
                continue
            if seed.upper() not in used:
                return seed
            idx += 1
        byte += 1


def group_hex_for(target: str) -> int:
    """Reado -> 1, ReadoTests -> 2."""
    t = target.lower()
    if "test" in t:
        return 2
    return 1


# ---------------------------------------------------------------------------
# Read/write pbxproj
# ---------------------------------------------------------------------------

def read_pbxproj(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def write_pbxproj(path: Path, content: str) -> None:
    path.write_text(content, encoding="utf-8")


def get_group_id(content: str, group_name: str) -> str:
    """Trả id của PBXGroup tên `group_name` (path = group_name)."""
    # Pattern robust hơn: chấp nhận comment /* ... */ sau ID và trước '='
    # Ví dụ: 5A0000000000000000000004 /* ReadoTests */ = { isa = PBXGroup; ... path = ReadoTests; ... };
    pat = re.compile(
        r'([0-9A-Fa-f]{24})\s*(?:/\*[^*]*\*/)?\s*=\s*\{\s*isa\s*=\s*PBXGroup;(.*?)\};',
        re.S | re.I
    )
    for m in pat.finditer(content):
        gid = m.group(1)
        body = m.group(2)
        # Kiểm tra xem body có chứa path = "group_name" hoặc path = group_name
        if re.search(r'\bpath\s*=\s*"?%s"?' % re.escape(group_name), body, re.I):
            return gid
    raise SystemExit(f"Không tìm thấy PBXGroup tên '{group_name}' trong pbxproj")


def add_to_children(content: str, group_id: str, child_id: str, child_comment: str) -> str:
    """Thêm child_id vào danh sách children của group. Idempotent (kiểm tra TRONG list children)."""
    pat = re.compile(r'(' + re.escape(group_id) + r'\s*(?:/\*[^*]*\*/)?\s*=\s*\{\s*isa\s*=\s*PBXGroup;[\s\S]*?)(children\s*=\s*\()')
    m = pat.search(content)
    if not m:
        raise SystemExit(f"Không tìm thấy block children cho group {group_id}")
    before = m.group(1) + m.group(2)
    insert_pos = content.index(before) + len(before)
    # tìm vị trí kết thúc children
    close_idx = content.index(");", insert_pos)
    segment = content[insert_pos:close_idx]
    if f"{child_id} /* {child_comment} */" in segment:
        return content
    indent = "\n\t\t\t\t"
    new_child = f"{indent}{child_id} /* {child_comment} */,"
    content = content[:close_idx] + new_child + content[close_idx:]
    return content


def add_build_file(content: str, build_file_id: str, file_ref_id: str, comment: str, group_note: str) -> str:
    """Thêm PBXBuildFile section."""
    marker = "/* Begin PBXBuildFile section */"
    if marker not in content:
        raise SystemExit("pbxproj thiếu PBXBuildFile section")
    if f"{build_file_id} /* {comment}" in content:
        return content
    entry = f"\n\t\t{build_file_id} /* {comment} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_id} /* {comment} */; }};"
    end_marker = "/* End PBXBuildFile section */"
    idx = content.index(end_marker)
    content = content[:idx] + entry + "\n" + content[idx:]
    return content


def add_file_reference(content: str, file_ref_id: str, file_path: str, comment: str, group_id: str) -> str:
    """Thêm PBXFileReference entry."""
    marker = "/* Begin PBXFileReference section */"
    if marker not in content:
        raise SystemExit("pbxproj thiếu PBXFileReference section")
    if f"{file_ref_id} /* {comment}" in content:
        return content
    name = Path(file_path).name
    ext_suffix = _file_ref_type(file_path)
    entry = f"\n\t\t{file_ref_id} /* {comment} */ = {{isa = PBXFileReference; lastKnownFileType = {ext_suffix}; path = {name}; sourceTree = \"<group>\"; }};"
    end_marker = "/* End PBXFileReference section */"
    idx = content.index(end_marker)
    content = content[:idx] + entry + "\n" + content[idx:]
    return content


def _file_ref_type(path: str) -> str:
    ext = Path(path).suffix.lower()
    if ext == ".swift":
        return "sourcecode.swift"
    if ext == ".h":
        return "sourcecode.c.h"
    if ext in (".png", ".jpg", ".jpeg"):
        return "image.png"
    if ext in (".json",):
        return "text.json"
    return "text"


def add_to_sources_build_phase(content: str, build_file_id: str, comment: str, target: str) -> str:
    """Thêm build_file_id vào Sources build phase của target."""
    group = group_hex_for(target)
    phase_prefix = f"5D0{group}00000000000000000001"
    # tìm block sources cho target đó
    pat = re.compile(
        r'(' + re.escape(phase_prefix) + r'\s*/\*\s*Sources\s*\*/\s*=\s*\{\s*isa\s*=\s*PBXSourcesBuildPhase;[\s\S]*?)(files\s*=\s*\()'
    )
    m = pat.search(content)
    if not m:
        raise SystemExit(f"Không tìm thấy Sources build phase cho target prefix {phase_prefix}")
    before = m.group(1) + m.group(2)
    insert_pos = content.index(before) + len(before)
    close_idx = content.index(");", insert_pos)
    segment = content[insert_pos:close_idx]
    if f"{build_file_id} /* {comment} in Sources */" in segment:
        return content
    indent = "\n\t\t\t\t"
    new_file = f"{indent}{build_file_id} /* {comment} in Sources */,"
    content = content[:close_idx] + new_file + content[close_idx:]
    return content


def remove_file_from_content(content: str, file_path: str, group_name: str, target: str, group_id: str) -> str:
    """Gỡ toàn bộ tham chiếu của file (buildfile + fileref + children + build phase)."""
    name = Path(file_path).name
    # 1) children của group
    pat = re.compile(r'(' + re.escape(group_id) + r'\s*(?:/\*[^*]*\*/)?\s*=\s*\{\s*isa\s*=\s*PBXGroup;[\s\S]*?)(children\s*=\s*\()')
    m = pat.search(content)
    if m:
        before = m.group(1) + m.group(2)
        pos = content.index(before) + len(before)
        close_idx = content.index(");", pos)
        seg = content[pos:close_idx]
        # xoá dòng chứa /* name */
        newseg = re.sub(r'\n[ \t]*[0-9A-Fa-f]{24} /\* ' + re.escape(name) + r' \*/,', '', seg)
        content = content[:pos] + newseg + content[close_idx:]

    # 2) PBXBuildFile có fileRef trỏ file name
    # gom id fileref cần xoá = mọi fileref có comment name
    file_ref_ids = set(re.findall(r'(\b[0-9A-Fa-f]{24})\s*/\*\s*' + re.escape(name) + r'\s*\*/', content))
    if file_ref_ids:
        for fr in file_ref_ids:
            pat_bf = re.compile(r'\n[ \t]*(\b[0-9A-Fa-f]{24})(\s*/\*\s*' + re.escape(name) + r'\s*in\s*Sources\s*\*/\s*=\s*\{isa\s*=\s*PBXBuildFile;\s*fileRef\s*=\s*' + re.escape(fr) + r'\s*(?:/\*[^*]*\*/)?\s*;\s*\};)')
            content = pat_bf.sub('', content)
            # xoá trong Sources build phase list
            pat_ph = re.compile(r'\n[ \t]*(?:[0-9A-Fa-f]{24}) /\* ' + re.escape(name) + r' in Sources \*/,')
            content = pat_ph.sub('', content)

    # 3) PBXFileReference
    pat_fr = re.compile(r'\n[ \t]*(?:[0-9A-Fa-f]{24})\s*/\*\s*' + re.escape(name) + r'\s*\*/\s*=\s*\{isa\s*=\s*PBXFileReference;[\s\S]*?\};\s*\n')
    content = pat_fr.sub('\n', content)
    return content


# ---------------------------------------------------------------------------
# High-level
# ---------------------------------------------------------------------------

def add_file(pbxproj: Path, file_arg: str, group: str, target: str, comment: str, touch: bool):
    content = read_pbxproj(pbxproj)

    # resolve file path
    fpath = Path(file_arg)
    if not fpath.is_absolute():
        # relative: cwd là gốc repo; file thường nằm trong app/...
        # nếu bắt đầu bằng app/ giữ nguyên, nếu không thử trong app/
        fpath = Path.cwd() / file_arg
    if not fpath.exists():
        # thử trong app/
        alt = Path.cwd() / "app" / file_arg
        if alt.exists():
            fpath = alt
    if not fpath.exists():
        if touch:
            fpath.touch()
            print(f"[touch] tạo file trống {fpath}", file=sys.stderr)
        else:
            raise SystemExit(f"File không tồn tại: {fpath} (dùng --touch để tạo trống)")

    name = fpath.name
    if not comment:
        comment = name
    group_id = get_group_id(content, group)
    target_group = group_hex_for(target)

    fr = next_id(content, "5B", target_group)
    bf = next_id(content, "5C", target_group)

    content = add_file_reference(content, fr, fpath.as_posix(), comment, group_id)
    content = add_build_file(content, bf, fr, comment, group)
    content = add_to_children(content, group_id, fr, comment)
    content = add_to_sources_build_phase(content, bf, comment, target)

    write_pbxproj(pbxproj, content)
    print(f"OK: đã thêm {comment} -> group '{group}' / target '{target}'")
    print(f"  fileRef  {fr}")
    print(f"  buildFile {bf}")
    print(f"Verify: grep -c \"{comment}\" {pbxproj}  (mong đợi ≥3)")


def remove_file(pbxproj: Path, file_arg: str, group: str, target: str):
    content = read_pbxproj(pbxproj)
    name = Path(file_arg).name
    group_id = get_group_id(content, group)
    content = remove_file_from_content(content, file_arg, group, target, group_id)
    write_pbxproj(pbxproj, content)
    print(f"OK: đã gỡ {name} khỏi pbxproj")


def show_list(pbxproj: Path):
    content = read_pbxproj(pbxproj)

    def sec(name):
        pat = r'/\*\s*Begin %s section\s*\*/' % name + r'([\s\S]*?)' + r'/\*\s*End %s section\s*\*/' % name
        m = re.search(pat, content)
        return m.group(1) if m else "(none)"

    print("== PBXFileReference ==")
    for line in sec("PBXFileReference").splitlines():
        if "//" in line:  # comment line? no, comment in obj
            pass
        m = re.search(r'/\*\s*([^*]+?)\s*\*/\s*=\s*\{isa\s*=\s*PBXFileReference', line)
        if m:
            print("  ", m.group(1))
    print("\n== PBXGroup ==")
    # liệt kê groups có path hoặc name — gom theo children Trực tiếp
    seen = set()
    for m in re.finditer(r'(\b[0-9A-Fa-f]{24})\s*=\s*\{\s*isa\s*=\s*PBXGroup;[\s\S]*?(?:path|name)\s*=\s*"?([^"\s;}]+)"?', content):
        label = m.group(2)
        oid = m.group(1)
        if label in seen:
            continue
        seen.add(label)
        print(f"  {label:20s} ({oid})")
    # nếu group tên thiếu, vẫn in số lượng
    total_groups = len(re.findall(r'isa\s*=\s*PBXGroup;', content))
    print("\n== PBXBuildFile ==")
    for line in re.findall(r'\b[0-9A-Fa-f]{24}\s*/\*\s*([^*]+?)\s*in\s*Sources\s*\*/', content):
        print("  ", line.strip())


def check_project(pbxproj: Path) -> int:
    """Đối chiếu mọi *.swift track trong git (app/Reado, app/ReadoTests) với 4 dấu vết
    bắt buộc trong pbxproj: PBXFileReference, PBXBuildFile, group child, Sources phase.
    Thiếu 1 trong 4 → file bị Xcode skip NGẦM (không lỗi build, test "thừa xanh").
    Trả 0 = sạch, 1 = có vấn đề (in danh sách thiếu)."""
    import subprocess

    content = read_pbxproj(pbxproj)
    root = Path.cwd()  # quy ước tool: luôn chạy từ gốc repo (như add_file)

    try:
        tracked = subprocess.run(
            ["git", "ls-files", "app/Reado", "app/ReadoTests"],
            cwd=root, capture_output=True, text=True, check=True,
        ).stdout.splitlines()
    except Exception as exc:
        print(f"Không chạy được git ls-files: {exc}", file=sys.stderr)
        return 1

    swift_files = [f for f in tracked if f.endswith(".swift") and "/Reado.xcodeproj/" not in f]
    problems = []
    for rel in swift_files:
        name = Path(rel).name
        has_fileref = bool(re.search(
            r'/\*\s*' + re.escape(name) + r'\s*\*/\s*=\s*\{isa\s*=\s*PBXFileReference;', content))
        has_buildfile = bool(re.search(
            r'/\*\s*' + re.escape(name) + r'\s*in\s*Sources\s*\*/\s*=\s*\{isa\s*=\s*PBXBuildFile;', content))
        has_child = bool(re.search(
            r'\b[0-9A-Fa-f]{24}\s*/\*\s*' + re.escape(name) + r'\s*\*/,', content))
        has_phase = bool(re.search(
            r'\b[0-9A-Fa-f]{24}\s*/\*\s*' + re.escape(name) + r'\s*in\s*Sources\s*\*/,', content))
        missing = [
            label for label, ok in (
                ("PBXFileReference", has_fileref),
                ("PBXBuildFile", has_buildfile),
                ("group child", has_child),
                ("Sources phase", has_phase),
            ) if not ok
        ]
        if missing:
            problems.append((rel, missing))

    # Ngược lại: PBXFileReference .swift mà tên không khớp file nào đang track
    # (path trong pbxproj chỉ là basename, tương đối theo group — so theo tên là đúng quy ước tool này).
    existing_names = {Path(f).name for f in swift_files}
    dangling = []
    for m in re.finditer(
        r'/\*\s*([^*]+?\.swift)\s*\*/\s*=\s*\{isa\s*=\s*PBXFileReference;', content
    ):
        comment_name = m.group(1)
        if comment_name not in existing_names:
            dangling.append(comment_name)

    if not problems and not dangling:
        print(f"OK: {len(swift_files)} file Swift đủ 4 tham chiếu trong pbxproj")
        return 0

    for rel, missing in problems:
        print(f"THIẾU {', '.join(missing)}: {rel}")
    for name in dangling:
        print(f"TREO (fileRef trỏ file không tồn tại trên đĩa): {name}")
    return 1


# ---------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(description="Thao tác project.pbxproj — chống edit tay đốt token")
    ap.add_argument("action", choices=["add", "remove", "list", "check"],
                    help="add=thêm file, remove=gỡ file, list=liệt kê cấu trúc, check=đối chiếu git ls-files vs 4 tham chiếu")
    ap.add_argument("--pbxproj", help="đường dẫn pbxproj (mặc định tự tìm)")
    ap.add_argument("--file", help="đường dẫn file Swift cần thêm/gỡ")
    ap.add_argument("--group", default="Reado", help="PBXGroup chứa file: Reado | ReadoTests")
    ap.add_argument("--target", default="Reado", help="target build: Reado | ReadoTests")
    ap.add_argument("--comment", default="", help="tên hiển thị (mặc định = basename file)")
    ap.add_argument("--touch", action="store_true", help="tự touch file nếu chưa tồn tại")

    args = ap.parse_args()
    root = Path.cwd()

    if args.pbxproj:
        pbx = Path(args.pbxproj)
        if not pbx.exists():
            raise SystemExit(f"pbxproj không tồn tại: {pbx}")
    else:
        pbx = find_pbxproj(root)

    if args.action == "add":
        if not args.file:
            raise SystemExit("add cần --file")
        add_file(pbx, args.file, args.group, args.target, args.comment, args.touch)
    elif args.action == "remove":
        if not args.file:
            raise SystemExit("remove cần --file")
        remove_file(pbx, args.file, args.group, args.target)
    elif args.action == "list":
        show_list(pbx)
    elif args.action == "check":
        sys.exit(check_project(pbx))


if __name__ == "__main__":
    main()