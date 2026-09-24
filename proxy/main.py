"""Proxy Reado — POST /v1/analyze. Key Gemini chỉ ở GEMINI_API_KEY.

Chạy:
  cd proxy
  python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
  GEMINI_API_KEY=... GEMINI_MODEL=gemini-2.5-flash .venv/bin/uvicorn main:app --host 0.0.0.0 --port 8080

iPhone không gọi được localhost của laptop qua 4G. Cần HTTPS công khai,
rồi đặt READO_PROXY_BASE_URL trong scheme Xcode.
"""

import os
from threading import Lock

from fastapi import FastAPI, File, Form, Header, UploadFile
from fastapi.responses import JSONResponse

from normalize import AnalyzeFailure, normalize, parse_model_text
from prompt import VERSION, text as prompt_text

app = FastAPI()
_cache: dict[str, dict] = {}
_lock = Lock()


def _error(status: int, code: str, message: str) -> JSONResponse:
    return JSONResponse(
        status_code=status,
        content={"error": {"code": code, "message": message}},
    )


def _call_gemini(image: bytes, mime: str, cefr: str) -> str:
    from google import genai
    from google.genai import types

    api_key = os.environ.get("GEMINI_API_KEY", "").strip()
    if not api_key:
        raise AnalyzeFailure(500, "PROVIDER_ERROR", "thiếu GEMINI_API_KEY")
    model = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash").strip()
    client = genai.Client(api_key=api_key)
    response = client.models.generate_content(
        model=model,
        contents=[
            types.Part.from_bytes(data=image, mime_type=mime or "image/jpeg"),
            prompt_text(cefr or "B2"),
        ],
        config=types.GenerateContentConfig(
            response_mime_type="application/json",
        ),
    )
    body = getattr(response, "text", None) or ""
    if not body.strip():
        raise AnalyzeFailure(502, "PROVIDER_ERROR", "Gemini trả rỗng")
    return body


@app.post("/v1/analyze")
async def analyze(
    image: UploadFile = File(...),
    cefr_level: str = Form("B2"),
    x_reado_image_hash: str | None = Header(default=None, alias="X-Reado-Image-Hash"),
    x_reado_prompt_version: str | None = Header(default=None, alias="X-Reado-Prompt-Version"),
):
    image_hash = (x_reado_image_hash or "").strip().lower()
    if not image_hash:
        return _error(400, "IDEMPOTENCY_MISSING", "thiếu X-Reado-Image-Hash")

    # App gửi Prompt.version. Lệch version thì vẫn chạy prompt proxy, không chặn.
    _ = x_reado_prompt_version or str(VERSION)

    with _lock:
        cached = _cache.get(image_hash)
    if cached is not None:
        return cached

    raw = await image.read()
    if not raw:
        return _error(400, "IMAGE_UNREADABLE", "ảnh rỗng")
    mime = image.content_type or "image/jpeg"

    try:
        import asyncio

        model_text = await asyncio.to_thread(_call_gemini, raw, mime, cefr_level)
        payload = normalize(parse_model_text(model_text))
    except AnalyzeFailure as exc:
        return _error(exc.status, exc.code, exc.message)
    except Exception as exc:
        message = str(exc)
        if "429" in message or "RESOURCE_EXHAUSTED" in message:
            return _error(429, "RATE_LIMITED", message)
        return _error(502, "PROVIDER_ERROR", message)

    with _lock:
        _cache[image_hash] = payload
    return payload
