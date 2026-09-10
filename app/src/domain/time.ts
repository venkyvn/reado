/**
 * domain/time.ts — thời gian & "một ngày học"
 *
 * Theo docs/solution-design.md mục 4.3 & 6:
 * - LƯU: mọi timestamp là UTC tuyệt đối (ISO-8601 `...Z`). Không lưu offset.
 * - TÍNH: "hôm nay" = ngày học theo múi giờ device + `day_cutoff_hour` (mặc định 4).
 *   Đây là chỗ DUY NHẤT trong toàn app được đụng giờ địa phương — hàng đợi,
 *   hạn mức thẻ mới và streak phải đi qua đây (FR-11, FR-14).
 *
 * Ghi chú DST: `dayEnd = dayStart + 24h` tính bằng ms. Với múi giờ có DST, ngày
 * lịch có thể dài 23/25h, nhưng "ngày học" là khoảng 24h kể từ giờ chuyển ngày —
 * đúng cách Anki làm và là behaviour Reado cần cho streak (M-02).
 */

export interface DayBounds {
  /** Thời điểm (UTC) bắt đầu ngày học chứa `now`. */
  dayStart: Date
  /** Thời điểm (UTC) kết thúc ngày học — dayStart + 24h. */
  dayEnd: Date
  /** Nhãn ngày theo lịch địa phương (yyyy-mm-dd), để debug/streak. */
  dayLabel: string
}

interface LocalParts {
  year: number
  month: number
  day: number
  hour: number
  minute: number
  second: number
}

const formatterCache = new Map<string, Intl.DateTimeFormat>()

function partsFormatter(timeZone: string): Intl.DateTimeFormat {
  let f = formatterCache.get(timeZone)
  if (!f) {
    f = new Intl.DateTimeFormat("en-US", {
      timeZone,
      hourCycle: "h23",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
    })
    formatterCache.set(timeZone, f)
  }
  return f
}

/** Các thành phần giờ địa phương của một instant UTC ở múi giờ `timeZone`. */
export function localParts(instant: Date, timeZone: string): LocalParts {
  const parts = partsFormatter(timeZone).formatToParts(instant)
  const out: Partial<LocalParts> = {}
  for (const { type, value } of parts) {
    if (type !== "literal") out[type as keyof LocalParts] = Number(value)
  }
  return out as LocalParts
}

function wallAsUtc(p: LocalParts): number {
  return Date.UTC(p.year, p.month - 1, p.day, p.hour, p.minute, p.second)
}

/**
 * Instant UTC tương ứng với wall time (y, m, d, h, mi, s) ở `timeZone`.
 * Điểm bất động g = W − offset(g): lặp tối đa 3 vòng, offset hằng số thì
 * hội tụ ngay vòng 1; chỉ cần thêm vòng khi tức quanh DST transition.
 */
export function localWallToUtc(
  y: number,
  m: number,
  d: number,
  h: number,
  mi: number,
  s: number,
  timeZone: string,
): Date {
  const W = Date.UTC(y, m - 1, d, h, mi, s) // wall time đọc như UTC
  let guess = W
  for (let i = 0; i < 3; i++) {
    const offsetMs = wallAsUtc(localParts(new Date(guess), timeZone)) - guess
    const corrected = W - offsetMs
    if (corrected === guess) break
    guess = corrected
  }
  return new Date(guess)
}

const DAY_MS = 24 * 60 * 60 * 1000

/**
 * Ngày học chứa `now`: bắt đầu lúc `cutoffHour` giờ địa phương (`timeZone`).
 * Giờ địa phương của `now` nhỏ hơn cutoff → vẫn thuộc ngày học hôm qua
 * (người ôn lúc 1h sáng học "tối hôm qua" — review-scheduling mục 6.2).
 */
export function dayBounds(now: Date, cutoffHour: number, timeZone: string): DayBounds {
  const p = localParts(now, timeZone)
  let y = p.year
  let m = p.month
  let d = p.day
  if (p.hour < cutoffHour) {
    const prev = new Date(Date.UTC(y, m - 1, d, 12) - DAY_MS)
    y = prev.getUTCFullYear()
    m = prev.getUTCMonth() + 1
    d = prev.getUTCDate()
  }
  const dayStart = localWallToUtc(y, m, d, cutoffHour, 0, 0, timeZone)
  const pad = (n: number) => String(n).padStart(2, "0")
  return {
    dayStart,
    dayEnd: new Date(dayStart.getTime() + DAY_MS),
    dayLabel: `${y}-${pad(m)}-${pad(d)}`,
  }
}
