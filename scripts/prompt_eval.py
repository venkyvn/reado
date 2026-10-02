#!/usr/bin/env python3
"""prompt_eval.py — so song song kết quả nhiều bản prompt FR-02 trên OCR thật
đã kéo về bằng scripts/pull_diagnostics.sh + scripts/diag_summary.py (ADR-037),
để chấm prompt mới (v6) có tệ hơn prompt đang chạy (v5) không trước khi đổi
`Prompt.version` (docs/plans/prompt-v6.md T1).

    python3 scripts/prompt_eval.py --diagnostics .tmp/diagnostics/<ts> \
        --prompt scripts/prompts/v5.txt \
        --prompt app/ReadoKit/Sources/ReadoKit/Analysis/Prompt.swift \
        --model qwen3.8-flash

--prompt nhận file .txt (template thô, placeholder {CEFR}/{PAGE_OCR}) hoặc .swift
(rút thẳng literal multi-line string trong `Prompt.text`, cùng placeholder) — so
trực tiếp với bản đang sửa trong ReadoKit, không cần chép tay ra .txt mỗi lần đổi prompt.
--model/--base-url ghi đè meta.json khi model gốc đã đổi tên/ngừng ở provider.

Không có --diagnostics → dùng thư mục mới nhất trong .tmp/diagnostics/.
Mỗi thư mục analyses/<id>/ cần sẵn page_ocr.txt + meta.json (model, baseURL, cefr)
— tự ghi bởi DebugTrace lúc phân tích thật, không phải input tay.

Key đọc từ .env ở gốc repo lúc chạy (không in ra, không ghi vào kết quả) —
cùng cú pháp khối PROVIDER=/API_KEY= như scripts/sim_aibox.sh dùng cho simulator.
Không dependency ngoài stdlib.

Output: một file Markdown trong .tmp/prompt-eval/ (đã gitignore) — có text trang
+ bản dịch/cặp cụm/vocab từng prompt để fen chấm cạnh nhau, KHÔNG commit vào repo
(bản quyền sách).
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


def load_prompt_template(path: Path) -> str:
    """Trả về template thô (placeholder {CEFR}/{PAGE_OCR}). File .txt đọc nguyên;
    file .swift rút literal multi-line string trong thân `func text(...)` của
    Prompt.swift — để so trực tiếp bản đang sửa, không lệch do chép tay ra .txt."""
    if path.suffix != ".swift":
        return path.read_text(encoding="utf-8")
    text = path.read_text(encoding="utf-8")
    match = re.search(r'"""\n(.*?)\n([ \t]*)"""', text, re.DOTALL)
    if not match:
        sys.exit(f"Không tìm thấy literal \"\"\" ... \"\"\" trong {path}")
    body, indent = match.group(1), match.group(2)
    lines = [line[len(indent):] if line.startswith(indent) else line
             for line in body.split("\n")]
    rebuilt = "\n".join(lines)
    rebuilt = rebuilt.replace("\\(cefrLevel)", "{CEFR}").replace("\\(pageOCR)", "{PAGE_OCR}")
    return rebuilt.replace("\\\\", "\\")


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


def md_cell(text: str) -> str:
    """Escape một ô bảng Markdown — gộp xuống dòng, chặn `|` phá bảng."""
    return re.sub(r"\s+", " ", text or "").replace("|", "\\|").strip()


def render_segments_table(parsed_by_prompt: dict[str, dict | None], prompt_names: list[str]) -> list[str]:
    """Bảng song song theo chỉ số segment: EN (lấy từ prompt đầu tiên có đúng
    segment đó) + VI/phrases riêng của mỗi prompt — segmentation có thể lệch
    nhẹ giữa hai bản, nhưng cùng OCR nên đa số khớp theo chỉ số."""
    seg_lists = {
        name: (parsed_by_prompt.get(name) or {}).get("segments", []) or []
        for name in prompt_names
    }
    max_len = max((len(v) for v in seg_lists.values()), default=0)
    if max_len == 0:
        return []
    header = ["#", "EN (source_en)"]
    header += [f"VI · {name}" for name in prompt_names]
    header += [f"phrases · {name}" for name in prompt_names]
    lines = [
        "| " + " | ".join(header) + " |",
        "| " + " | ".join(["---"] * len(header)) + " |",
    ]
    for i in range(max_len):
        en = ""
        for name in prompt_names:
            segs = seg_lists[name]
            if i < len(segs) and segs[i].get("source_en"):
                en = segs[i]["source_en"]
                break
        row = [str(i + 1), md_cell(en)]
        for name in prompt_names:
            segs = seg_lists[name]
            vi = segs[i].get("translation_vi", "") if i < len(segs) else ""
            row.append(md_cell(vi))
        for name in prompt_names:
            segs = seg_lists[name]
            phrases = (segs[i].get("phrases") or []) if i < len(segs) else []
            phrase_text = "; ".join(
                f"{p.get('en', '?')} → {p.get('vi', '?')}" for p in phrases)
            row.append(md_cell(phrase_text))
        lines.append("| " + " | ".join(row) + " |")
    return lines


def render_vocab_lists(parsed_by_prompt: dict[str, dict | None], prompt_names: list[str]) -> list[str]:
    """Vocab giữ nguyên thứ tự AI trả về — đúng cái cần chấm cho preselect top 5."""
    lines: list[str] = []
    for name in prompt_names:
        parsed = parsed_by_prompt.get(name)
        if not parsed:
            continue
        vocab = parsed.get("vocabulary", []) or []
        lines.append(f"**vocab · {name}** (thứ tự AI, {len(vocab)} từ, 5 đầu sẽ chọn sẵn):")
        for idx, v in enumerate(vocab, 1):
            mark = "→ preselect" if idx <= 5 else ""
            lines.append(
                f"{idx}. {v.get('term', '?')} ({v.get('cefr', '?')}) — "
                f"{v.get('meaning_vi', '?')} {mark}".rstrip())
        lines.append("")
    return lines


def run(
    diagnostics_dir: Path,
    prompt_paths: list[Path],
    limit: int,
    out_dir: Path,
    model_override: str | None,
    base_url_override: str | None,
) -> Path:
    analyses_dir = find_analyses_dir(diagnostics_dir)
    if analyses_dir is None:
        sys.exit(f"Không thấy analyses/ trong {diagnostics_dir} — kéo lại bằng pull_diagnostics.sh.")

    env_path = ROOT / ".env"
    api_key = pick_env_key(env_path)
    if not api_key:
        sys.exit(f"Không tìm được API_KEY trong {env_path} — kiểm tra file.")

    prompt_templates = {p.name: load_prompt_template(p) for p in prompt_paths}
    prompt_names = list(prompt_templates)

    folders = sorted(p for p in analyses_dir.iterdir() if p.is_dir())[:limit]
    if not folders:
        sys.exit(f"Không có lần phân tích nào trong {analyses_dir}.")

    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{time.strftime('%Y%m%dT%H%M%SZ', time.gmtime())}.md"

    lines = [
        f"# prompt_eval — {diagnostics_dir.name}",
        "",
        f"Prompts: {', '.join(prompt_names)} · {len(folders)} lần phân tích"
        + (f" · model ghi đè = {model_override}" if model_override else ""),
        "",
    ]

    for folder in folders:
        ocr_path = folder / "page_ocr.txt"
        meta_path = folder / "meta.json"
        if not ocr_path.exists() or not meta_path.exists():
            continue
        page_ocr = ocr_path.read_text(encoding="utf-8", errors="replace")
        meta = load_json(meta_path)
        model = model_override or meta.get("model")
        base_url = base_url_override or meta.get("baseURL")
        cefr = meta.get("cefr", "B1")
        if not model or not base_url:
            lines.append(f"## {folder.name} — thiếu model/baseURL (meta.json hoặc --model/--base-url), bỏ qua")
            lines.append("")
            continue

        lines.append(f"## {folder.name} (model={model}, cefr={cefr}, {len(page_ocr)} ký tự OCR)")
        parsed_by_prompt: dict[str, dict | None] = {}
        for name, template in prompt_templates.items():
            prompt_text = template.replace("{CEFR}", cefr).replace("{PAGE_OCR}", page_ocr)
            content, error = call_model(base_url, api_key, model, prompt_text)
            if error:
                lines.append(f"- **{name}**: lỗi — {error}")
                parsed_by_prompt[name] = None
                continue
            lines.append(f"- **{name}**: {summarize(content)}")
            try:
                parsed_by_prompt[name] = json.loads(content)
            except Exception:
                parsed_by_prompt[name] = None
        lines.append("")

        table = render_segments_table(parsed_by_prompt, prompt_names)
        if table:
            lines.extend(table)
            lines.append("")
        lines.extend(render_vocab_lists(parsed_by_prompt, prompt_names))

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
    parser.add_argument("--model", type=str, default=None,
                         help="Ghi đè model trong meta.json (model gốc đã đổi tên/ngừng ở provider)")
    parser.add_argument("--base-url", type=str, default=None,
                         help="Ghi đè baseURL trong meta.json")
    args = parser.parse_args()

    diagnostics_dir = args.diagnostics or latest_diagnostics_dir()
    if diagnostics_dir is None:
        sys.exit("Không có --diagnostics và .tmp/diagnostics/ trống — chạy scripts/pull_diagnostics.sh trước.")
    if not diagnostics_dir.is_dir():
        sys.exit(f"Không thấy thư mục: {diagnostics_dir}")

    for p in args.prompt:
        if not p.exists():
            sys.exit(f"Không thấy prompt template: {p}")

    out_path = run(diagnostics_dir, args.prompt, args.limit, args.out_dir, args.model, args.base_url)
    print(f"Đã ghi: {out_path}")


if __name__ == "__main__":
    main()
