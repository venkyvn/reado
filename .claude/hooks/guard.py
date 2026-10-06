#!/usr/bin/env python3
"""PreToolUse guard Reado — cưỡng chế luật CLAUDE.md §7.

Exit 0 = cho qua. Exit 2 = chặn, in lý do ra stderr (Claude đọc được, tự sửa cách làm).
Không chặn nhầm việc đọc-only (Read/Grep/Glob) hay các Bash khác không match.
Bảng case kiểm: scripts/verify/test_guard.py.
"""
import fnmatch
import json
import os
import re
import shlex
import subprocess
import sys

ROOT = os.path.realpath(
    os.environ.get("CLAUDE_PROJECT_DIR") or os.path.join(os.path.dirname(__file__), "..", "..")
)

PBXPROJ_MSG = (
    "Cấm edit tay project.pbxproj. Thêm/xoá file Swift = tạo/xoá file trong app/Reado hoặc "
    "app/ReadoTests (synchronized folders, Xcode tự nhận). Đổi cấu hình project → nhờ fen làm trong "
    "Xcode (CLAUDE.md §7)."
)

ENV_MSG = (
    "Cấm đọc/sửa .env thật qua tool này — chỉ .env.example (placeholder, được track) là hợp lệ. "
    "Secret nằm trong .env, không được lộ qua Read/Grep/Edit/Write/Bash (CLAUDE.md §7)."
)

GREP_MSG = (
    "grep đệ quy từ gốc repo (hoặc không có path) quét cả dotfile như .env — dùng Grep tool "
    "(tôn trọng .gitignore), chỉ định thư mục con (vd app/), hoặc thêm --exclude='.env*' "
    "(CLAUDE.md §7)."
)

RG_MSG = (
    "rg với -u/--hidden/--no-ignore bỏ qua .gitignore và đọc cả .env — dùng Grep tool "
    "hoặc bỏ các cờ đó (CLAUDE.md §7)."
)

# Khớp basename ".env" hoặc ".env.<suffix>" — ".env.example" được loại trừ riêng (so chuỗi,
# không nhồi vào regex bằng lookahead — lookahead từng bắt sai ".env.example.bak" khi test).
_ENV_PATH_RE = re.compile(r"\.env(?:\.[\w.-]+)?$")
# Khớp token dạng ".env"/".env.<suffix>" đứng sau biên (đầu dòng, khoảng trắng, /, nháy, =, <)
# trong một dòng lệnh Bash.
_ENV_TOKEN_RE = re.compile(r"""(?:^|[\s/"'=<])(\.env(?:\.[\w.-]+)?)\b""")

# Cờ grep nhận tham số: ngắn (trong cụm, vd `-A3`, `-e foo`) và dài (dạng `--x y`, không có dấu =).
_GREP_SHORT_ARG = "efmABCdD"
_GREP_LONG_ARG = {
    "--include", "--exclude", "--exclude-dir", "--exclude-from", "--regexp", "--file",
    "--max-count", "--context", "--after-context", "--before-context", "--directories", "--devices",
}
_ROOT_LIKE = {".", "./", "*", "./*", ".*", "./.*", "..", "../", "~", "/"}
_SEGMENT_SEP = {";", "&&", "||", "|", "&", "(", ")", "|&"}
_WRAPPERS = {"sudo", "command", "env", "time", "nice", "nohup", "exec"}


def _is_env_secret_name(name: str) -> bool:
    if name == ".env.example":
        return False
    return bool(_ENV_PATH_RE.fullmatch(name))


def _path_has_env_secret(path: str) -> bool:
    if not path:
        return False
    name = path.rsplit("/", 1)[-1]
    return _is_env_secret_name(name)


def _glob_hits_env(pattern: str) -> bool:
    """Glob/path của Grep tool có thể khớp file secret không (`.env*`, `**/.env.local`, `.*`…)."""
    name = pattern or ""
    while name.startswith("**/") or name.startswith("*/"):
        name = name.split("/", 1)[1]
    name = name.rsplit("/", 1)[-1]
    if not name or name == ".env.example":
        return False
    if name.startswith(".env") or _is_env_secret_name(name):
        return True
    if name.startswith(".") and fnmatch.fnmatch(".env", name):
        return True
    return ".env" in name and ".env.example" not in name


def _strip_commit_message(cmd: str) -> str:
    """git commit: nội dung -m / heredoc là dữ liệu, không phải đường dẫn — bỏ trước khi dò token .env.
    `-F <file>` không bị bỏ, nên vẫn bị chặn nếu file đó là secret."""
    if not re.search(r"\bgit\s+commit\b", cmd):
        return cmd
    cmd = re.sub(
        r"<<-?\s*(['\"]?)(\w+)\1[^\n]*\n.*?\n[ \t]*\2[ \t]*(?=\n|\)|$)", "", cmd, flags=re.DOTALL
    )
    return re.sub(
        r"""(?<!\S)(?:-[A-Za-z]*m|--message)(?:\s+|=)("(?:[^"\\]|\\.)*"|'[^']*'|\S+)""", "", cmd
    )


def _strip_exclude_args(cmd: str) -> str:
    """`--exclude='.env*'` là cách đúng để grep an toàn — không coi là đọc .env."""
    return re.sub(r"""--exclude(?:-dir)?(?:=|\s+)(?:'[^']*'|"[^"]*"|\S+)""", "", cmd)


def _bash_has_env_secret(cmd: str) -> bool:
    cmd = _strip_exclude_args(_strip_commit_message(cmd))
    return any(tok != ".env.example" for tok in _ENV_TOKEN_RE.findall(cmd))


def _tokenize(cmd: str) -> list[str]:
    try:
        lex = shlex.shlex(cmd, posix=True, punctuation_chars=True)
        lex.whitespace_split = True
        return list(lex)
    except ValueError:
        return cmd.split()


def _segments(tokens: list[str]) -> list[list[str]]:
    """Tách theo ; && || | …, bỏ redirect và đích của nó (`> out`, `2>/dev/null`)."""
    segs: list[list[str]] = []
    cur: list[str] = []
    i = 0
    while i < len(tokens):
        t = tokens[i]
        if t in _SEGMENT_SEP:
            segs.append(cur)
            cur = []
        elif t and set(t) <= set("<>&"):
            i += 1  # bỏ đích redirect
            if cur and cur[-1].isdigit():
                cur.pop()
        else:
            cur.append(t)
        i += 1
    segs.append(cur)
    return [s for s in segs if s]


def _is_root_like(path: str) -> bool:
    if path in _ROOT_LIKE:
        return True
    rp = os.path.realpath(os.path.join(ROOT, os.path.expanduser(path)))
    return rp == ROOT or ROOT.startswith(rp.rstrip("/") + "/")


def _grep_scans_root(args: list[str]) -> bool:
    """True nếu grep đệ quy mà không path / path là gốc repo, và không loại .env."""
    recursive = has_pattern = exclude_env = False
    positional: list[str] = []
    i = 0
    while i < len(args):
        t = args[i]
        if t.startswith("--exclude") and ".env" in (t + (args[i + 1] if i + 1 < len(args) else "")):
            exclude_env = True
        if t == "--":
            positional += args[i + 1:]
            break
        if t.startswith("--"):
            if t in ("--recursive", "--dereference-recursive"):
                recursive = True
            elif t == "--regexp" or t == "--file" or t.startswith(("--regexp=", "--file=")):
                has_pattern = True
            if "=" not in t and t in _GREP_LONG_ARG:
                i += 1
        elif t.startswith("-") and len(t) > 1:
            for j, ch in enumerate(t[1:], start=1):
                if ch in "rR":
                    recursive = True
                if ch in _GREP_SHORT_ARG:
                    if ch in "ef":
                        has_pattern = True
                    if j == len(t) - 1:
                        i += 1  # tham số ở token kế
                    break
        else:
            positional.append(t)
        i += 1
    if not recursive or exclude_env:
        return False
    paths = positional if has_pattern else positional[1:]
    return not paths or any(_is_root_like(p) for p in paths)


def _rg_ignores_gitignore(args: list[str]) -> bool:
    for t in args:
        if t == "--":
            break
        if t in ("--hidden", "--unrestricted") or t.startswith("--no-ignore"):
            return True
        if t.startswith("-") and not t.startswith("--") and ("u" in t[1:] or t == "-."):
            return True
    return False


def _search_violation(cmd: str) -> str | None:
    """Thông báo chặn nếu lệnh có grep/rg có thể lộ dotfile; None nếu ổn. `git grep` chỉ đọc file tracked nên qua."""
    for seg in _segments(_tokenize(cmd)):
        k = 0
        while k < len(seg) and (seg[k] in _WRAPPERS or re.fullmatch(r"\w+=.*", seg[k])):
            k += 1
        if k >= len(seg):
            continue
        prog = os.path.basename(seg[k])
        if prog in ("grep", "egrep", "fgrep") and _grep_scans_root(seg[k + 1:]):
            return GREP_MSG
        if prog == "rg" and _rg_ignores_gitignore(seg[k + 1:]):
            return RG_MSG
    return None


def _commit_audit_problems(cmd: str) -> str | None:
    """`git commit` → chạy scripts/verify/audit.sh; có PROBLEM thì trả danh sách để chặn. Env
    READO_SKIP_COMMIT_AUDIT chặn đệ quy (audit.sh chạy test_guard.py chạy lại guard này)."""
    if os.environ.get("READO_SKIP_COMMIT_AUDIT") or not re.search(r"\bgit\s+commit\b", cmd):
        return None
    audit = os.path.join(ROOT, "scripts", "verify", "audit.sh")
    if not os.path.exists(audit):
        return None
    try:
        proc = subprocess.run([audit], cwd=ROOT, capture_output=True, text=True, timeout=120,
                              env={**os.environ, "READO_SKIP_COMMIT_AUDIT": "1"})
    except Exception:
        return None  # audit lỗi hạ tầng thì đừng chặn oan
    if proc.returncode == 0:
        return None
    problems = [l for l in proc.stdout.splitlines() if l.startswith(("PROBLEM:", "audit:"))]
    return "Không commit được khi audit đỏ (scripts/verify/audit.sh):\n" + "\n".join(problems)


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

    if tool == "Grep":
        for key in ("path", "glob"):
            if _glob_hits_env(inp.get(key, "") or ""):
                block(ENV_MSG)

    if tool == "Bash":
        cmd = inp.get("command", "") or ""
        if "project.pbxproj" in cmd and re.search(
            r"sed\s+-i|perl\s+-[a-z]*i|>\s*\S*project\.pbxproj", cmd
        ):
            block(PBXPROJ_MSG)
        if _bash_has_env_secret(cmd):
            block(ENV_MSG)
        violation = _search_violation(cmd)
        if violation:
            block(violation)
        audit_problems = _commit_audit_problems(cmd)
        if audit_problems:
            block(audit_problems)
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
