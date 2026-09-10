/**
 * Test day cutoff — hợp đồng "một ngày" của giải pháp (solution-design mục 6,
 * review-scheduling mục 6.2). Múi giờ cố định Asia/Bangkok (UTC+7, không DST)
 * để test deterministic; hàm nhận tz tham số nên device tz nào cũng chạy được.
 */
import { describe, expect, it } from "vitest"
import { dayBounds, localWallToUtc } from "./time"

const TZ = "Asia/Bangkok" // UTC+7, không DST
const CUTOFF = 4 // mặc định settings.day_cutoff_hour

describe("dayBounds — giờ chuyển ngày 4h sáng, theo múi giờ device", () => {
  it("17:00 giờ địa phương (sau cutoff) → ngày học bắt đầu 04:00 cùng ngày lịch", () => {
    // 2026-09-08T10:00Z = 17:00 tại UTC+7
    const { dayStart, dayEnd, dayLabel } = dayBounds(new Date("2026-09-08T10:00:00Z"), CUTOFF, TZ)
    expect(dayStart.toISOString()).toBe("2026-09-07T21:00:00.000Z") // 04:00+07
    expect(dayEnd.toISOString()).toBe("2026-09-08T21:00:00.000Z")
    expect(dayLabel).toBe("2026-09-08")
  })

  it("03:00 giờ địa phương (TRƯỚC cutoff) → vẫn thuộc ngày học hôm qua", () => {
    // 2026-09-08T20:00Z = 03:00 ngày 09-09 tại UTC+7 → người ôn đêm: ngày học là 09-08
    const { dayStart, dayLabel } = dayBounds(new Date("2026-09-08T20:00:00Z"), CUTOFF, TZ)
    expect(dayStart.toISOString()).toBe("2026-09-07T21:00:00.000Z") // 04:00+07 ngày 09-08
    expect(dayLabel).toBe("2026-09-08")
  })

  it("đúng 04:00 giờ địa phương = giây đầu tiên của ngày học MỚI", () => {
    // 2026-09-07T21:00Z = đúng 04:00 ngày 09-08 → thuộc ngày 09-08, không lùi
    const { dayStart, dayLabel } = dayBounds(new Date("2026-09-07T21:00:00Z"), CUTOFF, TZ)
    expect(dayStart.toISOString()).toBe("2026-09-07T21:00:00.000Z")
    expect(dayLabel).toBe("2026-09-08")
  })

  it("lệch tháng/năm vẫn an toàn: 01h sáng 01-01 → ngày học 31-12 năm trước", () => {
    // 2026-12-31T18:00Z = 01:00 ngày 01-01-2027 tại UTC+7
    const { dayStart, dayLabel } = dayBounds(new Date("2026-12-31T18:00:00Z"), CUTOFF, TZ)
    expect(dayStart.toISOString()).toBe("2026-12-30T21:00:00.000Z") // 04:00+07 ngày 31-12-2026
    expect(dayLabel).toBe("2026-12-31")
  })
})

describe("localWallToUtc — wall time địa phương → instant UTC", () => {
  it("04:00 tại UTC+7 = 21:00Z ngày hôm trước", () => {
    expect(localWallToUtc(2026, 9, 8, 4, 0, 0, TZ).toISOString()).toBe("2026-09-07T21:00:00.000Z")
  })

  it("nửa đêm địa phương cũng đúng", () => {
    expect(localWallToUtc(2026, 9, 8, 0, 0, 0, TZ).toISOString()).toBe("2026-09-07T17:00:00.000Z")
  })

  it("múi giờ âm: 04:00 tại America/Los_Angeles (PDT, UTC-7) = 11:00Z cùng ngày", () => {
    expect(localWallToUtc(2026, 9, 8, 4, 0, 0, "America/Los_Angeles").toISOString()).toBe(
      "2026-09-08T11:00:00.000Z",
    )
  })
})
