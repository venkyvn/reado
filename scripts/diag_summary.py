#!/usr/bin/env python3
"""diag_summary.py — tóm tắt log chẩn đoán DebugTrace (ADR-037) đã kéo về bằng
scripts/pull_diagnostics.sh, để đọc gọn thay vì mở từng file JSON.

    python3 scripts/diag_summary.py .tmp/diagnostics/<ts>/
    python3 scripts/diag_summary.py .tmp/diagnostics/<ts>/ --full   # in cả segment/vocab

Không đụng mạng, không đụng máy — chỉ đọc file đã có trên đĩa.
"""
import argparse
import json
import sys
from pathlib import Path


def find_one(root: Path, name: str) -> Path | None:
    matches = list(root.rglob(name))
    return matches[0] if matches else None


def find_dir(root: Path, name: str) -> Path | None:
    matches = [p for p in root.rglob(name) if p.is_dir()]
    return matches[0] if matches else None


def load_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001 — chỉ để báo, không phải app logic
        return {"_error": f"parse lỗi: {exc}"}


def summarize_analysis(folder: Path, full: bool) -> None:
    meta = load_json(folder / "meta.json") if (folder / "meta.json").exists() else {}
    print(f"\n=== {folder.name} ===")
    if meta:
        keys = [
            "model", "baseURL", "cefr", "httpStatus", "ocrMs", "ocrChars", "ocrLines",
            "totalMs", "error", "decodeError", "retriedWithoutResponseFormat",
        ]
        line = " ".join(f"{k}={meta[k]}" for k in keys if k in meta)
        print(line or "(meta rỗng)")

    ocr_path = folder / "ocr.json"
    if ocr_path.exists():
        ocr = load_json(ocr_path)
        lines = ocr.get("lines", [])
        print(f"OCR engine: {ocr.get('engine', 'legacy (log cũ)')}")
        breaks = [l for l in lines if l.get("breakBefore")]
        raw = ocr.get("rawObservationCount")
        kept = ocr.get("observationCount")
        dropped = ocr.get("droppedLowConfidence", [])
        if raw is not None:
            if ocr.get("engine") == "documents":
                # documents: raw = số đoạn, kept = số hàng — khác đơn vị, không có "unseen".
                print(f"OCR documents: paragraphs={raw} lines={kept}")
            else:
                # ocr-line-drop: raw > kept + len(dropped) nghĩa Vision không hề thấy
                # phần chênh lệch đó — không phải do code mình lọc confidence.
                unseen = raw - kept - len(dropped) if kept is not None else None
                extra = f" unseen(Vision không thấy)={unseen}" if unseen else ""
                print(f"OCR observations: raw={raw} kept={kept} droppedLowConfidence={len(dropped)}{extra}")
            for d in dropped:
                conf = d.get("confidence", 0)
                preview = d.get("text", "")[:60]
                print(f"  [dropped conf={conf:.2f}] {preview!r}")
        print(f"OCR: {len(lines)} hàng, {len(breaks)} chỗ ngắt đoạn")
        for l in breaks:
            reason = l.get("breakReason", "?")
            preview = l.get("text", "")[:60]
            print(f"  [{reason}] {preview!r}")

        # apple-ai-r1 T4 (ADR-061) — chỉ có khi soát OCR bật; log cũ không có
        # khoá này thì im lặng bỏ qua (không in gì thêm).
        fixes = ocr.get("fixes")
        if fixes is not None:
            rejected = ocr.get("fixRejected", 0)
            ms = ocr.get("fixMs")
            err = ocr.get("fixError")
            print(f"OCR fix: {len(fixes)} áp / {rejected} loại / {ms} ms" + (f" lỗi={err!r}" if err else ""))
            for f in fixes:
                print(f"  {f.get('wrong')!r} → {f.get('right')!r}")

    analysis_path = folder / "analysis.json"
    if analysis_path.exists():
        analysis = load_json(analysis_path)
        segments = analysis.get("segments", [])
        vocabulary = analysis.get("vocabulary", [])
        print(f"Response: {len(segments)} segment, {len(vocabulary)} từ vựng")
        if full:
            for i, seg in enumerate(segments):
                en = seg.get("source_en", "")[:80]
                print(f"  segment[{i}] EN: {en!r}")
    elif (folder / "response_raw.txt").exists():
        raw = (folder / "response_raw.txt").read_text(encoding="utf-8", errors="replace")
        print(f"Response raw (không decode được): {raw[:200]!r}")


def summarize_events(events_path: Path) -> None:
    if not events_path.exists():
        return
    print(f"\n=== events.jsonl ({events_path}) ===")
    counts: dict[str, int] = {}
    errors = []
    for line in events_path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        key = f"{event.get('cat')}.{event.get('name')}"
        counts[key] = counts.get(key, 0) + 1
        if "fail" in str(event.get("name", "")).lower() or "error" in str(event.get("name", "")).lower():
            errors.append(event)
    for key, count in sorted(counts.items(), key=lambda kv: -kv[1]):
        print(f"  {count:4d}  {key}")
    if errors:
        print(f"\n  {len(errors)} sự kiện lỗi gần nhất (tối đa 10):")
        for event in errors[-10:]:
            print(f"    {event.get('ts')} {event.get('cat')}.{event.get('name')} {event.get('fields')}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("root", help="Thư mục đã kéo về bằng scripts/pull_diagnostics.sh")
    parser.add_argument("--full", action="store_true", help="In cả nội dung segment EN")
    args = parser.parse_args()

    root = Path(args.root)
    if not root.exists():
        sys.exit(f"Không thấy thư mục: {root}")

    analyses_dir = find_dir(root, "analyses")
    if analyses_dir:
        folders = sorted(p for p in analyses_dir.iterdir() if p.is_dir())
        print(f"{len(folders)} lần phân tích trong {analyses_dir}")
        for folder in folders:
            summarize_analysis(folder, args.full)
    else:
        print("Không thấy thư mục analyses/ — chưa phân tích lần nào, hoặc đường dẫn sai.")

    events_path = find_one(root, "events.jsonl")
    if events_path:
        summarize_events(events_path)


if __name__ == "__main__":
    main()
