#!/usr/bin/env python3
"""Bảng case cho .claude/hooks/guard.py — chạy: python3 scripts/verify/test_guard.py (exit 1 nếu có case lệch).

Mỗi case: (tool, input, exit mong đợi). 0 = cho qua, 2 = chặn. Nguồn: docs/plans/workflow-docs-r1.md Phụ lục B.
"""
import json
import subprocess
import sys
from pathlib import Path

GUARD = Path(__file__).resolve().parents[2] / ".claude" / "hooks" / "guard.py"

HEREDOC_COMMIT = "git commit -m \"$(cat <<'EOF'\nfix(guard): chặn đọc .env qua grep\n\nbody có .env.local\nEOF\n)\""

CASES = [
    # --- grep / rg đệ quy
    ("Bash", {"command": "grep -rn API_KEY ."}, 2),
    ("Bash", {"command": "grep -rn API_KEY"}, 2),
    ("Bash", {"command": "grep --recursive API_KEY"}, 2),
    ("Bash", {"command": "grep -rn API_KEY . 2>/dev/null"}, 2),
    ("Bash", {"command": "cd app && egrep -R KEY ./"}, 2),
    ("Bash", {"command": "rg -uu API_KEY"}, 2),
    ("Bash", {"command": "rg --hidden KEY"}, 2),
    ("Bash", {"command": "rg --no-ignore KEY app/"}, 2),
    ("Bash", {"command": "grep -rqwF foo app/"}, 0),
    ("Bash", {"command": "grep -rn KEY . --exclude='.env*'"}, 0),
    ("Bash", {"command": "grep -n foo scripts/test.sh"}, 0),
    ("Bash", {"command": "git grep API_KEY"}, 0),
    ("Bash", {"command": "rg -n foo app/"}, 0),
    ("Bash", {"command": "ls app | grep -i reado"}, 0),
    # --- Grep tool
    ("Grep", {"pattern": "KEY", "glob": ".env*"}, 2),
    ("Grep", {"pattern": "KEY", "glob": "**/.env.local"}, 2),
    ("Grep", {"pattern": "KEY", "glob": "*/.env*"}, 2),
    ("Grep", {"pattern": "KEY", "glob": "*.swift"}, 0),
    ("Grep", {"pattern": "KEY", "glob": ".env.example"}, 0),
    # --- git commit
    ("Bash", {"command": 'git commit -m "chặn đọc .env"'}, 0),
    ("Bash", {"command": HEREDOC_COMMIT}, 0),
    ("Bash", {"command": "git commit -F .env"}, 2),
    ("Bash", {"command": 'git commit -m "x" && cat .env'}, 2),
    # --- luật cũ vẫn giữ
    ("Bash", {"command": "cat .env"}, 2),
    ("Bash", {"command": "cat .env.example"}, 0),
    ("Bash", {"command": "cd app && xcodebuild test"}, 2),
    ("Bash", {"command": "swift build"}, 2),
    ("Bash", {"command": "scripts/test.sh kit"}, 0),
    ("Edit", {"file_path": "app/Reado.xcodeproj/project.pbxproj"}, 2),
    ("Edit", {"file_path": "app/Reado/App/ReadoApp.swift"}, 0),
    ("Read", {"file_path": "/x/.env"}, 2),
    ("Read", {"file_path": "/x/.env.example"}, 0),
]


def run(tool: str, tool_input: dict) -> tuple[int, str]:
    p = subprocess.run(
        [sys.executable, str(GUARD)],
        input=json.dumps({"tool_name": tool, "tool_input": tool_input}),
        capture_output=True,
        text=True,
    )
    return p.returncode, p.stderr.strip()


def main() -> int:
    bad = 0
    for tool, tool_input, want in CASES:
        got, err = run(tool, tool_input)
        if got != want:
            bad += 1
            print(f"LỆCH  {tool} {json.dumps(tool_input, ensure_ascii=False)}  mong {want}, được {got}  {err[:80]}")
    print(f"{len(CASES) - bad}/{len(CASES)} case đúng")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
