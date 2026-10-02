#!/usr/bin/env python3
"""prompt_eval.py — so song song kết quả nhiều bản prompt FR-02 trên OCR thật
đã kéo về bằng scripts/pull_diagnostics.sh + scripts/diag_summary.py (ADR-037),
để chấm prompt mới (v6) có tệ hơn prompt đang chạy (v5) không trước khi đổi
`Prompt.version` (docs/plans/prompt-v6.md T1).

    python3 scripts/prompt_eval.py --diagnostics .tmp/diagnostics/<ts> \
        --prompt scripts/prompts/v5.txt --prompt scripts/prompts/v6.txt

Không có --diagnostics → dùng thư mục mới nhất trong .tmp/diagnostics/.
Mỗi thư mục analyses/<id>/ cần sẵn page_ocr.txt + meta.json (model, baseURL, cefr)
— tự ghi bởi DebugTrace lúc phân tích thật, không phải input tay.

Key đọc từ .env ở gốc repo lúc chạy (không in ra, không ghi vào kết quả) —
cùng cú pháp khối PROVIDER=/API_KEY= như scripts/sim_aibox.sh dùng cho simulator.
Không dependency ngoài stdlib.

Output: một file Markdown trong .tmp/prompt-eval/ — KHÔNG chứa text trang gốc
(bản quyền sách), chỉ model/cefr/độ dài response + JSON tóm tắt mỗi prompt.
"""
import argparse
import json
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parent.parent


def latest_diagnostics_dir() -> Path | None:
    base = ROOT / ".tmp" / "diagnostics"
    if not base.is_dir():
        return None
    candidates = sorted(p for p in base.iterdir() if p.is_dir())
    return candidates[-1] if candidates else None


def find_analyses_dir(diagnostics_root: Path) -> Path | None:
    matches = [p for p in diagnostics_root.rglob("analyses") if p.is_dir()]
    return matches[0] if matches else None


def load_json(path: Path) -> dict:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {}


def pick_env_key(env_path: Path) -> str | None:
    """Giống pick_key trong scripts/sim_aibox.sh: khối cuối có PROVIDER=apibox,
    hoặc API_KEY cuối cùng nếu không có khối apibox. Khối cách nhau bằng dòng
    trống hoặc `---`."""
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

    for block in blocks:
        if get(block, "PROVIDER") == "apibox":
            key = get(block, "API_KEY")
            if key:
                return key
    for block in reversed(blocks):
        key = get(block, "API_KEY")
        if key:
            return key
    return None


def extra_body_params(base_url: str) -> dict:
    """Khớp OpenAICompatClient.extraBodyParams — chỉ host đã kiểm mới nhận
    field riêng, tránh provider khác trả 400 vì field lạ."""
    host = (urlparse(base_url).hostname or "").lower()
    if host == "api.ai-box.vn" or host.endswith(".ai-box.vn"):
        return {"enable_thinking": False}
    return {}


def build_body(model: str, prompt: str, extra: dict, include_response_format: bool) -> dict:
    """Khớp OpenAICompatClient.body — cùng shape message để so được công bằng
    với app thật (không stream ở đây, script chỉ cần kết quả cuối)."""
    payload = {
        "model": model,
        "stream": False,
        "messages": [
            {
                "role": "system",
                "content": "Chỉ trả về một JSON object hợp lệ, không markdown, không giải thích.",
            },
            {
                "role": "user",
                "content": [{"type": "text", "text": prompt}],
            },
        ],
    }
    if include_response_format:
        payload["response_format"] = {"type": "json_object"}
    payload.update(extra)
    return payload


def call_model(base_url: str, api_key: str, model: str, prompt: str) -> tuple[str, str]:
    """Gọi {base_url}/chat/completions. Trả (content, error) — error rỗng nếu ok.
    Thử response_format trước; 400 có nhắc 'response_format' thì gọi lại không kèm
    field đó (cùng hành vi retry của OpenAICompatClient)."""
    extra = extra_body_params(base_url)
    url = base_url.rstrip("/") + "/chat/completions"

    def attempt(include_rf: bool) -> tuple[str, str]:
        body = build_body(model, prompt, extra, include_rf)
        data = json.dumps(body).encode("utf-8")
        req = urllib.request.Request(
            url,
            data=data,
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {api_key}",
            },
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                raw = resp.read().decode("utf-8", errors="replace")
        except urllib.error.HTTPError as exc:
            raw_err = exc.read().decode("utf-8", errors="replace")
            return "", f"http {exc.code}: {raw_err[:300]}"
        except urllib.error.URLError as exc:
            return "", f"network: {exc}"
        try:
            parsed = json.loads(raw)
            content = parsed["choices"][0]["message"]["content"]
            return content, ""
        except Exception as exc:
            return "", f"parse response thất bại: {exc} — raw[:300]={raw[:300]}"

    content, error = attempt(True)
    if error.startswith("http 400") and "response_format" in error.lower():
        content, error = attempt(False)
    return content, error


def summarize(content: str) -> str:
    """Tóm tắt JSON trả về thành vài dòng — không in nguyên text trang."""
    try:
        parsed = json.loads(content)
    except Exception:
        snippet = re.sub(r"\s+", " ", content)[:200]
        return f"KHÔNG parse được JSON — đầu response: {snippet!r}"
    segments = parsed.get("segments", [])
    vocab = parsed.get("vocabulary", [])
    terms = ", ".join(v.get("term", "?") for v in vocab[:8])
    phrase_count = sum(len(s.get("phrases", []) or []) for s in segments)
    return (
        f"{len(segments)} segment, {len(vocab)} vocab (top 8: {terms}), "
        f"{phrase_count} phrases, summary_vi {len(parsed.get('summary_vi', ''))} ký tự"
    )


def run(diagnostics_dir: Path, prompt_paths: list[Path], limit: int, out_dir: Path) -> Path:
    analyses_dir = find_analyses_dir(diagnostics_dir)
    if analyses_dir is None:
        sys.exit(f"Không thấy analyses/ trong {diagnostics_dir} — kéo lại bằng pull_diagnostics.sh.")

    env_path = ROOT / ".env"
    api_key = pick_env_key(env_path)
    if not api_key:
        sys.exit(f"Không tìm được API_KEY trong {env_path} — kiểm tra file.")

    prompt_templates = {p.name: p.read_text(encoding="utf-8") for p in prompt_paths}

    folders = sorted(p for p in analyses_dir.iterdir() if p.is_dir())[:limit]
    if not folders:
        sys.exit(f"Không có lần phân tích nào trong {analyses_dir}.")

    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{time.strftime('%Y%m%dT%H%M%SZ', time.gmtime())}.md"

    lines = [
        f"# prompt_eval — {diagnostics_dir.name}",
        "",
        f"Prompts: {', '.join(prompt_templates)} · {len(folders)} lần phân tích",
        "",
    ]

    for folder in folders:
        ocr_path = folder / "page_ocr.txt"
        meta_path = folder / "meta.json"
        if not ocr_path.exists() or not meta_path.exists():
            continue
        page_ocr = ocr_path.read_text(encoding="utf-8", errors="replace")
        meta = load_json(meta_path)
        model = meta.get("model")
        base_url = meta.get("baseURL")
        cefr = meta.get("cefr", "B1")
        if not model or not base_url:
            lines.append(f"## {folder.name} — thiếu model/baseURL trong meta.json, bỏ qua")
            lines.append("")
            continue

        lines.append(f"## {folder.name} (model={model}, cefr={cefr}, {len(page_ocr)} ký tự OCR)")
        for name, template in prompt_templates.items():
            prompt_text = template.replace("{CEFR}", cefr).replace("{PAGE_OCR}", page_ocr)
            content, error = call_model(base_url, api_key, model, prompt_text)
            if error:
                lines.append(f"- **{name}**: lỗi — {error}")
            else:
                lines.append(f"- **{name}**: {summarize(content)}")
        lines.append("")

    out_path.write_text("\n".join(lines), encoding="utf-8")
    return out_path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--diagnostics", type=Path, default=None,
                         help="Thư mục .tmp/diagnostics/<ts> — thiếu thì dùng bản mới nhất")
    parser.add_argument("--prompt", type=Path, action="append", required=True,
                         help="File template prompt (lặp lại để so nhiều bản)")
    parser.add_argument("--limit", type=int, default=30, help="Số lần phân tích tối đa (mặc định 30)")
    parser.add_argument("--out-dir", type=Path, default=ROOT / ".tmp" / "prompt-eval")
    args = parser.parse_args()

    diagnostics_dir = args.diagnostics or latest_diagnostics_dir()
    if diagnostics_dir is None:
        sys.exit("Không có --diagnostics và .tmp/diagnostics/ trống — chạy scripts/pull_diagnostics.sh trước.")
    if not diagnostics_dir.is_dir():
        sys.exit(f"Không thấy thư mục: {diagnostics_dir}")

    for p in args.prompt:
        if not p.exists():
            sys.exit(f"Không thấy prompt template: {p}")

    out_path = run(diagnostics_dir, args.prompt, args.limit, args.out_dir)
    print(f"Đã ghi: {out_path}")


if __name__ == "__main__":
    main()
