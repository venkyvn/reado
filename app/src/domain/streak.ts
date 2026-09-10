/**
 * domain/streak.ts — streak ngày ôn liên tục (FR-14 criterion cuối).
 *
 * Thuần, không đụng DB: nhận tập nhãn "ngày ôn" (yyyy-mm-dd — đã ánh xạ qua
 * dayBounds với giờ chuyển ngày + múi giờ device) + nhãn hôm nay, trả độ dài
 * chuỗi ngày liên tiếp.
 *
 * Quy ước neo (giữ streak không đứt trong lúc hôm nay chưa có buổi ôn nào):
 * đếm lùi từ HÔM NAY nếu hôm nay có ôn, ngược lại đếm lùi từ HÔM QUA. Như vậy
 * streak chỉ đứt khi cả hôm nay lẫn hôm qua đều trống — đúng cách người dùng
 * hình dung "tôi đang giữ chuỗi", không trừng phạt người chưa kịp ôn buổi tối.
 *
 * Chuỗi nhãn không cần liên tục về lịch thật — previousDayLabel lùi 24h từ
 * nhãn trước, đúng phép tính lịch UTC giản lược (nhãn đã là ngày lịch).
 */
import { dayBounds } from "./time"

const DAY_MS = 24 * 60 * 60 * 1000

/** Nhãn "ngày học" chứa instant này — dayBounds đã áp giờ chuyển ngày + múi giờ. */
export function dayLabelOf(instantIso: string, cutoffHour: number, timeZone: string): string {
  return dayBounds(new Date(instantIso), cutoffHour, timeZone).dayLabel
}

/** Lùi đúng một ngày lịch từ nhãn yyyy-mm-dd → nhãn ngày trước. */
export function previousDayLabel(label: string): string {
  const noonUtc = Date.parse(`${label}T12:00:00.000Z`)
  const prev = new Date(noonUtc - DAY_MS)
  const pad = (n: number) => String(n).padStart(2, "0")
  return `${prev.getUTCFullYear()}-${pad(prev.getUTCMonth() + 1)}-${pad(prev.getUTCDate())}`
}

/** Độ dài chuỗi ngày ôn liên tục kết thúc ở hôm nay (hoặc hôm qua nếu hôm nay chưa ôn). */
export function computeStreak(dayLabels: ReadonlySet<string>, todayLabel: string): number {
  let label = dayLabels.has(todayLabel) ? todayLabel : previousDayLabel(todayLabel)
  let days = 0
  while (dayLabels.has(label)) {
    days += 1
    label = previousDayLabel(label)
  }
  return days
}
