"""Chuẩn hoá JSON Gemini về schema AnalysisResponseDecoder đọc được."""

import json

VALID_POS = {"noun", "verb", "adj", "adv", "phrase", "other"}
VALID_CEFR = {"A2", "B1", "B2", "C1"}


class AnalyzeFailure(Exception):
    def __init__(self, status: int, code: str, message: str):
        self.status = status
        self.code = code
        self.message = message


def parse_model_text(raw: str) -> dict:
    text = raw.strip()
    if text.startswith("```"):
        text = text.split("\n", 1)[-1]
        fence = text.rfind("```")
        if fence != -1:
            text = text[:fence]
    try:
        data = json.loads(text)
    except json.JSONDecodeError as exc:
        raise AnalyzeFailure(502, "SCHEMA_VIOLATION", f"JSON: {exc}") from exc
    if not isinstance(data, dict):
        raise AnalyzeFailure(502, "SCHEMA_VIOLATION", "response không phải object")
    return data


def normalize(data: dict) -> dict:
    segments = []
    for item in data.get("segments") or []:
        if not isinstance(item, dict):
            continue
        source = str(item.get("source_en") or "").strip()
        translation = str(item.get("translation_vi") or "").strip()
        if source and translation:
            segments.append({"source_en": source, "translation_vi": translation})

    vocabulary = []
    for item in data.get("vocabulary") or []:
        if not isinstance(item, dict):
            continue
        term = str(item.get("term") or "").strip()
        meaning = str(item.get("meaning_vi") or "").strip()
        example = str(item.get("example") or "").strip()
        if not term or not meaning or not example:
            continue
        pos = str(item.get("pos") or "").strip().lower()
        if pos not in VALID_POS:
            pos = "other"
        cefr_raw = str(item.get("cefr") or "").strip().upper()
        cefr = cefr_raw if cefr_raw in VALID_CEFR else None
        ipa = str(item.get("ipa") or "").strip()
        row = {
            "term": term,
            "pos": pos,
            "meaning_vi": meaning,
            "example": example,
        }
        if ipa:
            row["ipa"] = ipa
        if cefr:
            row["cefr"] = cefr
        vocabulary.append(row)

    summary = str(data.get("summary_vi") or "").strip()
    if not segments and not vocabulary:
        raise AnalyzeFailure(
            422,
            "NON_ENGLISH_TEXT",
            "không đọc được văn bản tiếng Anh trên ảnh",
        )
    return {
        "segments": segments,
        "vocabulary": vocabulary,
        "summary_vi": summary,
    }
