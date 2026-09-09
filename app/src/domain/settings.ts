/**
 * domain/settings.ts — FR-15 (Learning Settings): hằng số mặc định + cổng kiểm
 * tra DUY NHẤT cho patch settings.
 *
 * Vì sao cổng nằm ở domain chứ không ở UI: UI có thể quên, nhưng bảng `settings`
 * có những cột mà R1 CHỐT là không mở cho người dùng — `request_retention` (FR-15:
 * "để mặc định 0.9", PRD mục 7 gọi nó là núm dễ tự bắn chân nhất), `fsrs_params`/
 * `fsrs_version` (R1 dùng tham số mặc định), `day_cutoff_hour`, `enable_fuzz`,
 * `maximum_interval`, và `ai_provider` (R1 chỉ có MỘT adapter Gemini — cho đổi
 * provider khi không có adapter thứ hai là nói dối người dùng). Nên đường ghi duy
 * nhất đi qua đây và field ngoài whitelist bị TỪ CHỐI, không bỏ qua im lặng
 * (coding-conventions mục 3).
 *
 * Hàm thuần — không DB, không React — nên test được không cần SQLite.
 */
import { SettingsError } from "./errors";
import { CEFR_VALUES } from "./types";
import type { Cefr, Settings } from "./types";

/** Mặc định Gemini (Q-03 + schema.sql). Hai nơi dùng chung để không drift:
 *  form BYOK trong flow capture và màn Cài đặt. */
export const DEFAULT_AI_BASE_URL = "https://generativelanguage.googleapis.com";
export const DEFAULT_AI_MODEL = "gemini-3.6-flash";

/** Trần hạn mức thẻ mới — chỉ để chặn giá trị vô lý (gõ nhầm 1000000). */
export const MAX_DAILY_NEW_LIMIT = 999;
export const MAX_AI_MODEL_LENGTH = 120;

/** Các cột FR-15 cho người dùng chỉnh ở R1. */
export type EditableSettingsPatch = Partial<
  Pick<Settings, "cefrLevel" | "dailyNewLimit" | "aiBaseUrl" | "aiModel" | "aiApiKey">
>;

const EDITABLE_KEYS = new Set<string>(["cefrLevel", "dailyNewLimit", "aiBaseUrl", "aiModel", "aiApiKey"]);

/** Field bị khoá ở R1, kèm lý do — dùng cho thông điệp lỗi (UI hiện nguyên văn). */
const LOCKED_KEYS: Record<string, string> = {
  requestRetention: "request_retention để mặc định 0.9 ở R1 (FR-15)",
  maximumInterval: "maximum_interval chưa mở ở R1",
  enableFuzz: "enable_fuzz chưa mở ở R1",
  dayCutoffHour: "day_cutoff_hour chưa mở ở R1",
  fsrsParams: "fsrs_params để trống ở R1 — dùng tham số mặc định của thư viện",
  fsrsVersion: "fsrs_version đi cùng fsrs_params, R1 để trống",
  aiProvider: "ai_provider chỉ có adapter Gemini ở R1 — đổi provider cần adapter mới (R2)",
};

function asString(value: unknown, code: "bad_cefr" | "bad_base_url" | "bad_model" | "empty_key", field: string): string {
  if (typeof value !== "string") throw new SettingsError(code, `${field} phải là chuỗi`, field);
  return value;
}

/**
 * Chuẩn hoá + kiểm tra patch từ UI. Trả patch CHỈ chứa field editable, đã trim và
 * đã áp mặc định cho base URL / model rỗng (rỗng = "về mặc định Gemini", hiện
 * ngay trên form sau khi lưu nên không phải quyết định ngầm).
 *
 * Quy ước `aiApiKey`: `undefined` = không đổi · `null` = xoá key · chuỗi rỗng/toàn
 * khoảng trắng = LỖI (muốn xoá thì gửi null — nút "Xoá key"), vì coi chuỗi rỗng
 * là "không đổi" sẽ âm thầm bỏ thao tác người dùng vừa làm.
 */
export function normalizeSettingsPatch(raw: Record<string, unknown>): EditableSettingsPatch {
  const patch: EditableSettingsPatch = {};

  for (const key of Object.keys(raw)) {
    if (EDITABLE_KEYS.has(key)) continue;
    const reason = LOCKED_KEYS[key];
    throw new SettingsError(
      reason ? "readonly_field" : "unknown_field",
      reason ? `${key} không chỉnh được: ${reason}` : `${key} không phải field settings hợp lệ`,
      key,
    );
  }

  if (raw.cefrLevel !== undefined) {
    const value = asString(raw.cefrLevel, "bad_cefr", "cefrLevel");
    if (!(CEFR_VALUES as readonly string[]).includes(value)) {
      throw new SettingsError("bad_cefr", `CEFR phải thuộc ${CEFR_VALUES.join("/")} — nhận "${value}"`, "cefrLevel");
    }
    patch.cefrLevel = value as Cefr;
  }

  if (raw.dailyNewLimit !== undefined) {
    const value = raw.dailyNewLimit;
    if (typeof value !== "number" || !Number.isInteger(value) || value < 0 || value > MAX_DAILY_NEW_LIMIT) {
      throw new SettingsError(
        "bad_daily_limit",
        `hạn mức thẻ mới phải là số nguyên 0..${MAX_DAILY_NEW_LIMIT} — nhận ${String(value)}`,
        "dailyNewLimit",
      );
    }
    patch.dailyNewLimit = value;
  }

  if (raw.aiBaseUrl !== undefined) {
    const value = asString(raw.aiBaseUrl, "bad_base_url", "aiBaseUrl").trim();
    if (value === "") {
      patch.aiBaseUrl = DEFAULT_AI_BASE_URL;
    } else {
      let parsed: URL;
      try {
        parsed = new URL(value);
      } catch {
        throw new SettingsError("bad_base_url", `base URL không hợp lệ: "${value}"`, "aiBaseUrl");
      }
      if (parsed.protocol !== "https:" && parsed.protocol !== "http:") {
        throw new SettingsError("bad_base_url", `base URL phải là http(s): "${value}"`, "aiBaseUrl");
      }
      patch.aiBaseUrl = value;
    }
  }

  if (raw.aiModel !== undefined) {
    const value = asString(raw.aiModel, "bad_model", "aiModel").trim();
    if (value.length > MAX_AI_MODEL_LENGTH) {
      throw new SettingsError("bad_model", `tên model quá dài (> ${MAX_AI_MODEL_LENGTH} ký tự)`, "aiModel");
    }
    patch.aiModel = value === "" ? DEFAULT_AI_MODEL : value;
  }

  if (raw.aiApiKey !== undefined) {
    if (raw.aiApiKey === null) {
      patch.aiApiKey = null;
    } else {
      const value = asString(raw.aiApiKey, "empty_key", "aiApiKey").trim();
      if (value === "") {
        throw new SettingsError(
          "empty_key",
          'API key rỗng — dùng nút "Xoá key" nếu muốn xoá',
          "aiApiKey",
        );
      }
      patch.aiApiKey = value;
    }
  }

  if (Object.keys(patch).length === 0) {
    throw new SettingsError("empty_patch", "không có field nào để lưu");
  }
  return patch;
}
