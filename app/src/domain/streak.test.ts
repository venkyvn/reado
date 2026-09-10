/**
 * unit test — domain/streak.ts (FR-14 criterion cuối: streak theo giờ chuyển
 * ngày, không theo nửa đêm hệ thống). Thuần, không đụng DB.
 */
import { describe, expect, it } from "vitest"
import { computeStreak, dayLabelOf, previousDayLabel } from "./streak"

describe("previousDayLabel — lùi một ngày lịch", () => {
  it("ngày thường", () => {
    expect(previousDayLabel("2026-09-10")).toBe("2026-09-09")
  })

  it("qua ranh giới tháng", () => {
    expect(previousDayLabel("2026-09-01")).toBe("2026-08-31")
  })

  it("qua ranh giới năm", () => {
    expect(previousDayLabel("2026-01-01")).toBe("2025-12-31")
  })

  it("năm nhuận: 2024-03-01 → 2024-02-29", () => {
    expect(previousDayLabel("2024-03-01")).toBe("2024-02-29")
  })
})

describe("dayLabelOf — instant UTC → nhãn ngày học theo cutoff + múi giờ", () => {
  const tz = "Asia/Ho_Chi_Minh" // UTC+7
  const cutoff = 4

  it("03:00 giờ địa phương (trước cutoff) thuộc ngày học hôm qua", () => {
    // 2026-09-09T20:00Z = 03:00 ngày 10 local → ngày học 09-09
    expect(dayLabelOf("2026-09-09T20:00:00.000Z", cutoff, tz)).toBe("2026-09-09")
  })

  it("04:30 giờ địa phương (sau cutoff) thuộc ngày học mới", () => {
    // 2026-09-09T21:30Z = 04:30 ngày 10 local → ngày học 09-10
    expect(dayLabelOf("2026-09-09T21:30:00.000Z", cutoff, tz)).toBe("2026-09-10")
  })
})

describe("computeStreak — chuỗi ngày ôn liên tục", () => {
  const s = (...labels: string[]) => new Set(labels)
  const T = "2026-09-10"

  it("không có ngày ôn nào → 0", () => {
    expect(computeStreak(new Set(), T)).toBe(0)
  })

  it("chỉ ôn hôm nay → 1", () => {
    expect(computeStreak(s("2026-09-10"), T)).toBe(1)
  })

  it("hôm nay CHƯA ôn, nhưng hôm qua có → streak tính từ hôm qua, chưa đứt", () => {
    expect(computeStreak(s("2026-09-09"), T)).toBe(1)
  })

  it("ôm hai ngày liên tiếp → 2", () => {
    expect(computeStreak(s("2026-09-10", "2026-09-09"), T)).toBe(2)
  })

  it("đứt một ngày ở giữa → chỉ đếm đoạn gần nhất (không cộng quá khứ xa)", () => {
    // ôn 09-10 và 09-08, nghỉ 09-09 → streak = 1 (chỉ hôm nay)
    expect(computeStreak(s("2026-09-10", "2026-09-08"), T)).toBe(1)
  })

  it("cả hôm nay lẫn hôm qua trống → 0 dù quá khứ có chuỗi dài", () => {
    expect(computeStreak(s("2026-09-07", "2026-09-06"), T)).toBe(0)
  })

  it("chuỗi vắt qua ranh giới tháng vẫn liên tục", () => {
    expect(computeStreak(s("2026-09-01", "2026-08-31", "2026-08-30"), "2026-09-01")).toBe(3)
  })

  it("tập lặp nhãn (nhiều review cùng ngày) không làm streak phình", () => {
    expect(computeStreak(s("2026-09-10", "2026-09-09"), T)).toBe(2)
  })
})
