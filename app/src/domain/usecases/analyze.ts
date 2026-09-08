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