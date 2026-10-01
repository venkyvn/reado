#!/usr/bin/env python3
"""PreToolUse guard Reado — cưỡng chế luật CLAUDE.md §7.

Exit 0 = cho qua. Exit 2 = chặn, in lý do ra stderr (Claude đọc được, tự sửa cách làm).
Không chặn nhầm việc đọc-only (Read/Grep/Glob) hay các Bash khác không match.
"""
import json
import re
import sys


PBXPROJ_MSG = (
    "Cấm edit tay project.pbxproj. Thêm/xoá file Swift = tạo/xoá file trong app/Reado hoặc "
    "app/ReadoTests (synchronized folders, Xcode tự nhận). Đổi cấu hình project → nhờ fen làm trong "
    "Xcode (CLAUDE.md §7)."
)

ENV_MSG = (
    "Cấm đọc/sửa .env thật qua tool này — chỉ .env.example (placeholder, được track) là hợp lệ. "
    "Secret nằm trong .env, không được lộ qua Read/Grep/Edit/Write/Bash (CLAUDE.md §7)."
)

# Khớp basename ".env" hoặc ".env.<suffix>" — ".env.example" được loại trừ riêng (so chuỗi,
# không nhồi vào regex bằng lookahead — lookahead từng bắt sai ".env.example.bak" khi test).
_ENV_PATH_RE = re.compile(r"\.env(?:\.[\w.-]+)?$")
# Khớp token dạng ".env"/".env.<suffix>" đứng sau biên (đầu dòng, khoảng trắng, /, nháy, =, <)
# trong một dòng lệnh Bash.
_ENV_TOKEN_RE = re.compile(r"""(?:^|[\s/"'=<])(\.env(?:\.[\w.-]+)?)\b""")


def _is_env_secret_name(name: str) -> bool:
    if name == ".env.example":
        return False
    return bool(_ENV_PATH_RE.fullmatch(name))


def _path_has_env_secret(path: str) -> bool:
    if not path:
        return False
    name = path.rsplit("/", 1)[-1]
    return _is_env_secret_name(name)


def _bash_has_env_secret(cmd: str) -> bool:
    return any(tok != ".env.example" for tok in _ENV_TOKEN_RE.findall(cmd))


def block(msg: str) -> None:
    print(msg, file=sys.stderr)
    sys.exit(2)


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)  # input không đọc được thì đừng chặn oan

    tool = data.get("tool_name", "")
    inp = data.get("tool_input", {}) or {}

    if tool in ("Edit", "Write", "MultiEdit"):
        path = inp.get("file_path", "") or ""
        if path.endswith("project.pbxproj"):
            block(PBXPROJ_MSG)
        if _path_has_env_secret(path):
            block(ENV_MSG)

    if tool in ("Read", "Grep"):
        for key in ("file_path", "path", "glob"):
            if _path_has_env_secret(inp.get(key, "") or ""):
                block(ENV_MSG)

    if tool == "Bash":
        cmd = inp.get("command", "") or ""
        if "project.pbxproj" in cmd and re.search(
            r"sed\s+-i|perl\s+-[a-z]*i|>\s*\S*project\.pbxproj", cmd
        ):
            block(PBXPROJ_MSG)
        if _bash_has_env_secret(cmd):
            block(ENV_MSG)
        if re.search(r"(^|[;&|]\s*)swift\s+(build|test)\b", cmd):
            block(
                "Cấm `swift build`/`swift test` (đụng cache ~/Library) — "
                "dùng `scripts/test.sh` (CLAUDE.md §2)."
            )
        if re.search(r"(^|[;&|]\s*)xcodebuild\b", cmd) and "scripts/test.sh" not in cmd:
            allowed_bare = re.search(r"xcodebuild\s+(-version|-list|-showsdks)\b", cmd)
            if not allowed_bare:
                block(
                    "Đừng gọi `xcodebuild` trần — dùng "
                    "`scripts/test.sh [build|test|test-without-building] [args]` (CLAUDE.md §7)."
                )

    sys.exit(0)


if __name__ == "__main__":
    main()
