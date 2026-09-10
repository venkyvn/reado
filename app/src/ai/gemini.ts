/**
 * ai/gemini.ts — adapter Gemini duy nhất hit network (solution-design mục 10).
 *
 * Request shape đã chứng minh hoạt động bằng script Phase 0
 * (response_mime_type + response_schema), tái chế nguyên dạng. Adapter nhận
 * config BYOK qua tham số (không tự đọc settings) — provider khác sau này chỉ
 * là file mới cùng interface AiProvider.
 */
import type { AiCallConfig, AiProvider, PageImage } from "../domain/ai"
import { AnalysisError } from "../domain/errors"
import { parseAndValidateAiText, toAnalysisResult } from "../domain/verify"
import { PROMPT_VERSION, buildPrompt } from "./prompt"
import { geminiSchema } from "./schema"

interface GeminiUsage {
  promptTokenCount?: number
  candidatesTokenCount?: number
}

interface GeminiPart {
  text?: string
}

export function createGeminiProvider(
  fetchImpl: typeof fetch = (...args) => fetch(...args),
): AiProvider {
  return {
    async analyzePage(
      img: PageImage,
      cfg: AiCallConfig,
    ): Promise<import("../domain/types").AnalysisResult> {
      const baseUrl = cfg.baseUrl.replace(/\/+$/, "")
      const url = `${baseUrl}/v1beta/models/${encodeURIComponent(cfg.model)}:generateContent`
      const body = {
        contents: [
          {
            role: "user",
            parts: [
              { inline_data: { mime_type: img.mime, data: img.base64 } },
              { text: buildPrompt(cfg.cefrLevel) },
            ],
          },
        ],
        generationConfig: {
          response_mime_type: "application/json",
          response_schema: geminiSchema(),
        },
      }

      const started = Date.now()
      let res: Response
      try {
        res = await fetchImpl(url, {
          method: "POST",
          headers: {
            "content-type": "application/json",
            "x-goog-api-key": cfg.apiKey,
          },
          body: JSON.stringify(body),
        })
      } catch (e) {
        throw new AnalysisError(
          "network",
          `không gọi được Gemini: ${e instanceof Error ? e.message : String(e)}`,
        )
      }
      const latencyMs = Date.now() - started

      let raw = ""
      try {
        raw = await res.text()
      } catch {
        // giữ rỗng — thông điệp dưới vẫn đủ ý
      }

      if (!res.ok) {
        throw new AnalysisError(
          "http",
          `Gemini trả HTTP ${res.status}: ${raw.slice(0, 300)}`,
          res.status,
        )
      }

      let envelope: {
        candidates?: { finishReason?: string; content?: { parts?: GeminiPart[] } }[]
        usageMetadata?: GeminiUsage
      }
      try {
        envelope = JSON.parse(raw) as typeof envelope
      } catch {
        throw new AnalysisError("bad_envelope", "response không phải JSON")
      }

      const candidate = envelope?.candidates?.[0]
      if (!candidate) {
        throw new AnalysisError("bad_envelope", "response không có candidates")
      }

      const text = (candidate.content?.parts ?? []).map((p) => p.text ?? "").join("")
      const finishReason = candidate.finishReason ?? "(thiếu)"
      if (finishReason !== "STOP") {
        throw new AnalysisError("finish_reason", `finishReason=${finishReason}`)
      }

      // Parse + validate nghiêm ngặt (bad_json / schema / unreadable) — ném lỗi,
      // chưa từng có đường nào lưu bản ghi hỏng (FR-02 criterion).
      const payload = parseAndValidateAiText(text)
      const usage = envelope?.usageMetadata ?? {}
      return toAnalysisResult(payload, {
        promptTokens: Number(usage.promptTokenCount ?? 0),
        candidatesTokens: Number(usage.candidatesTokenCount ?? 0),
        latencyMs,
        promptVersion: PROMPT_VERSION,
      })
    },
  }
}
