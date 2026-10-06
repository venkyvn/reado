#!/usr/bin/env python3
"""envkey.py — bộ đọc key trong .env duy nhất (sim_aibox.sh gọi như CLI, prompt_eval.py import).

Khối cách nhau bằng dòng trống hoặc `---`. Lấy API_KEY của khối CUỐI có PROVIDER=apibox; không có khối apibox
thì lấy API_KEY của khối cuối cùng có key. Không bao giờ in gì ngoài chính key (CLI) — caller không được log nó.

CLI: python3 scripts/lib/envkey.py [path/to/.env]   (mặc định .env ở gốc repo; in key hoặc dòng rỗng)
"""
import sys
from pathlib import Path


def pick_env_key(env_path: Path) -> str | None:
    if not env_path.exists():
        return None
    blocks: list[list[str]] = []
    current: list[str] = []
    for line in env_path.read_text(encoding="utf-8").splitlines():
        if line.strip() in ("", "---"):
            if current:
                blocks.append(current)
                current = []
            continue
        current.append(line)
    if current:
        blocks.append(current)

    def get(block: list[str], name: str) -> str | None:
        for line in block:
            if line.startswith(name + "="):
                return line.split("=", 1)[1].strip()
        return None

    key = None
    for block in blocks:
        if get(block, "PROVIDER") == "apibox":
            key = get(block, "API_KEY") or key
    if key:
        return key
    for block in reversed(blocks):
        candidate = get(block, "API_KEY")
        if candidate:
            return candidate
    return None


if __name__ == "__main__":
    default = Path(__file__).resolve().parents[2] / ".env"
    print(pick_env_key(Path(sys.argv[1]) if len(sys.argv) > 1 else default) or "")
