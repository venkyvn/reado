/**
 * domain/errors.ts — lỗi nghiệp vụ phân biệt được bằng mã.
 *
 * UI dựa vào `code` để hiện thông điệp tiếng Việt chính xác (FR-02: lỗi schema
 * → hiển thị lỗi + retry; FR-04: ảnh mờ/không phải tiếng Anh báo cụ thể). Không
 * bao giờ vẽ UI đọc `message` trực tiếp — message là cho log.
 */

export type AnalysisErrorCode =
  | "missing_key" // chưa cấu hình API key BYOK — nhắc nhập
  | "network" // fetch fail / không có mạng
  | "http" // HTTP không 2xx (5xx, 401 key sai...)
  | "bad_envelope" // response không đúng cấu trúc candidates
  | "finish_reason" // model dừng không phải STOP
  | "bad_json" // text không parse được JSON
  | "schema" // parse được JSON nhưng vỡ schema mục 4 (FR-02: không lưu bản ghi hỏng)
  | "unreadable" // ảnh mờ / trang không phải tiếng Anh (AI trả rỗng)

export class AnalysisError extends Error {
  readonly code: AnalysisErrorCode
  /** HTTP status nếu code = "http". */
  readonly status: number | null

  constructor(code: AnalysisErrorCode, message: string, status: number | null = null) {
    super(message)
    this.name = "AnalysisError"
    this.code = code
    this.status = status
  }
}

/**
 * FR-15: lỗi khi lưu Cài đặt. `code` để UI hiện thông điệp tiếng Việt đúng chỗ;
 * `message` (có tên field) là cho log/owner đọc — không phải copy UI.
 */
export type SettingsErrorCode =
  | "readonly_field" // field có thật nhưng R1 khoá (request_retention, fsrs_params…)
  | "unknown_field" // không phải field settings
  | "bad_cefr"
  | "bad_daily_limit"
  | "bad_base_url"
  | "bad_model"
  | "empty_key"
  | "empty_patch"

export class SettingsError extends Error {
  readonly code: SettingsErrorCode
  /** Tên field (camelCase) liên quan — UI tự ghép câu từ code + field này,
   *  KHÔNG render `message` (conventions mục 1/3: message là cho log). */
  readonly field: string | null

  constructor(code: SettingsErrorCode, message: string, field: string | null = null) {
    super(message)
    this.name = "SettingsError"
    this.code = code
    this.field = field
  }
}

export class StorageError extends Error {
  constructor(message: string) {
    super(message)
    this.name = "StorageError"
  }
}
