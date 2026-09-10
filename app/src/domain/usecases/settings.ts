/**
 * domain/usecases/settings.ts — FR-15: đọc/ghi Cài đặt.
 *
 * Đường ghi duy nhất cho NGƯỜI DÙNG vào bảng `settings`: mọi patch người dùng
 * tạo ra phải qua `normalizeSettingsPatch` (domain/settings.ts) trước khi tới
 * repo, nên không màn nào chạm được cột đã khoá ở R1 (request_retention,
 * fsrs_params…). Ngoại lệ đã tồn tại TRƯỚC task này và KHÔNG phải thao tác của
 * người dùng: write-probe chẩn đoán ở StorageCheckScreen ghi lại nguyên giá trị
 * `requestRetention` qua repo để đo "ghi được không" (không đổi dữ liệu). Muốn
 * khép hẳn thì đổi probe đó sang boot-probe (đã tự chứng minh persist riêng).
 *
 * Vì sao KHÔNG dựng lại scheduler sau khi lưu: scheduler được bootstrap lắp một
 * lần từ `request_retention`/`maximum_interval`/`enable_fuzz` — cả ba đều thuộc
 * nhóm KHOÁ ở R1, nên không có đường người dùng đổi chúng. Hai field người dùng
 * đổi được (`cefr_level`, `daily_new_limit`) đều được đọc lại từ DB ở MỖI lần
 * dùng: `analyzePage` đọc lúc gọi AI, `buildDueQueue`/`getHomeStats` đọc lúc dựng
 * hàng đợi — nên chúng có hiệu lực ngay ở lần chụp/ôn kế tiếp, không cần reload.
 * Nếu sau này mở `request_retention`, chỗ này PHẢI dựng lại scheduler.
 */
import { normalizeSettingsPatch } from "../settings"
import type { AppServices } from "../services"
import type { Settings } from "../types"

export async function getSettings(svc: AppServices): Promise<Settings> {
  return svc.repos.settings.get()
}

/**
 * Lưu patch đã kiểm tra. `raw` nhận `Record<string, unknown>` vì đây là cổng
 * runtime: field lạ / field khoá bị ném SettingsError (không bỏ qua im lặng).
 * Trả về settings SAU khi lưu để UI hiển thị đúng giá trị đã chuẩn hoá (vd base
 * URL rỗng → mặc định Gemini hiện ngay trên form).
 */
export async function updateSettings(
  svc: AppServices,
  raw: Record<string, unknown>,
): Promise<Settings> {
  const patch = normalizeSettingsPatch(raw)
  return svc.repos.settings.updatePartial(patch)
}
