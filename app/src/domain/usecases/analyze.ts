/**
 * domain/usecases/analyze.ts — FR-02: gọi AI một lần, nhận kết quả đã xác minh.
 *
 * BYOK: đọc config từ settings. Chưa có key → AnalysisError("missing_key") để
 * UI nhắc nhập ngay trong flow capture (hành vi đã ghi thẳng trong DDL: "null
 * = chưa nhập; app nhắc khi capture đầu tiên").
 */
import type { PageImage } from "../ai";
import { AnalysisError } from "../errors";
import type { AppServices } from "../services";
import type { AnalysisResult } from "../types";
import { newId, toUtcIso } from "../utils";

export async function analyzePage(
  svc: AppServices,
  img: PageImage,
): Promise<AnalysisResult> {
  const settings = await svc.repos.settings.get();
  if (!settings.aiApiKey) {
    throw new AnalysisError("missing_key", "chưa có API key BYOK trong settings");
  }
  const model = settings.aiModel;
  if (!model) {
    throw new AnalysisError("missing_key", "chưa có model AI trong settings");
  }
  return svc.ai.analyzePage(img, {
    baseUrl: settings.aiBaseUrl,
    apiKey: settings.aiApiKey,
    model,
    cefrLevel: settings.cefrLevel,
  });
}

/**
 * FR-14 "số trang đã phân tích": ghi MỘT sự kiện vào bảng analyses sau khi một
 * trang được phân tích THÀNH CÔNG và kết quả tới được tay người dùng.
 *
 * Vì sao để UI gọi thay vì ghi ngay trong analyzePage: dev chạy StrictMode làm
 * effect 2 lần → 2 lần gọi AI thật, lần thứ nhất bị runId-guard bỏ. UI gọi hàm
 * này SAU guard nên đếm đúng 1 sự kiện cho 1 trang người dùng thấy được — kể cả
 * ở dev. Bên cạnh con đếm, dòng này lưu số đo NFR-02 (latency/token/provider/
 * model/prompt_version) làm dữ liệu cho M-03. KHÔNG lưu key, KHÔNG lưu ảnh.
 *
 * Trả về `id` của dòng analyses — task 3.15 (Q-10-reopen) dùng CHÍNH id này
 * cho dòng reading_sessions ghi kèm (provenance 1:1 giữa sự kiện phân tích và
 * phiên đọc), nên UI gọi persistReadingSession ngay sau hàm này.
 */
export async function recordAnalyzedPage(
  svc: AppServices,
  result: AnalysisResult,
): Promise<string> {
  const settings = await svc.repos.settings.get();
  const id = newId();
  await svc.repos.analyses.insert({
    id,
    analyzedAt: toUtcIso(svc.now()),
    cefr: settings.cefrLevel,
    provider: settings.aiProvider,
    model: settings.aiModel,
    promptVersion: result.promptVersion,
    latencyMs: Number.isFinite(result.latencyMs) ? Math.round(result.latencyMs) : null,
    tokensIn: result.usage.promptTokens,
    tokensOut: result.usage.candidatesTokens,
  });
  return id;
}