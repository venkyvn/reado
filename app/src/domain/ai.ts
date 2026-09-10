/**
 * domain/ai.ts — "port" cho AI provider (solution-design mục 3.1: ai implement
 * interface do domain định nghĩa). Adapter duy nhất hit network là ai/gemini.ts.
 */
import type { AnalysisResult, Cefr } from "./types"

/** Ảnh trang cần phân tích — base64 đã bỏ tiền tố data:. */
export interface PageImage {
  base64: string
  mime: string
}

/** Cấu hình BYOK cho MỘT lần gọi — usecase đọc từ settings rồi truyền vào.
 *  Adapter không tự đọc settings: nó là hàm thuần với cấu hình. */
export interface AiCallConfig {
  baseUrl: string
  apiKey: string
  model: string
  cefrLevel: Cefr
}

export interface AiProvider {
  /**
   * MỘT lần gọi multimodal: OCR + dịch + trích vocab + tóm tắt (A-01).
   * Ném AnalysisError với mã chính xác khi hỏng; không bao giờ trả dữ liệu
   * bán hỏng — validate schema xong (domain/verify) mới trả AnalysisResult.
   */
  analyzePage(img: PageImage, cfg: AiCallConfig): Promise<AnalysisResult>
}
