/**
 * ui/swipe.test.ts — hợp đồng máy của chuẩn vuốt (chủ chốt 2026-09-09):
 * trái = Easy(4), phải = Good(3), chưa đủ ngưỡng = không chấm.
 */
import { describe, expect, it } from "vitest"
import { SWIPE_COMMIT_PX, isTap, shouldLockDrag, swipeVerdict } from "./swipe"

describe("swipeVerdict", () => {
  it("quẹt trái đủ sâu → easy", () => {
    expect(swipeVerdict(-SWIPE_COMMIT_PX)).toBe("easy")
    expect(swipeVerdict(-250)).toBe("easy")
  })

  it("quẹt phải đủ sâu → good", () => {
    expect(swipeVerdict(SWIPE_COMMIT_PX)).toBe("good")
    expect(swipeVerdict(120)).toBe("good")
  })

  it("dưới ngưỡng → null: thẻ bật về, không chấm nhầm", () => {
    expect(swipeVerdict(-SWIPE_COMMIT_PX + 1)).toBeNull()
    expect(swipeVerdict(SWIPE_COMMIT_PX - 0.5)).toBeNull()
    expect(swipeVerdict(0)).toBeNull()
  })
})

describe("shouldLockDrag", () => {
  it("đứng yên hoặc chỉ lướt dọc → chưa khoá (để trang cuộn)", () => {
    expect(shouldLockDrag(2, 0, false)).toBe(false)
    expect(shouldLockDrag(6, 40, false)).toBe(false)
    expect(shouldLockDrag(8, 9, false)).toBe(false) // chưa vượt ngưỡng ngang
  })

  it("kéo ngang thắng trục dọc → khoá kéo thẻ", () => {
    expect(shouldLockDrag(9, 5, false)).toBe(true)
    expect(shouldLockDrag(-20, -12, false)).toBe(true)
  })

  it("đã khoá rồi thì giữ dù đổi hướng", () => {
    expect(shouldLockDrag(-3, 30, true)).toBe(true)
  })
})

describe("isTap", () => {
  it("rung nhẹ quanh điểm chạm → tap, lật mặt sau", () => {
    expect(isTap(-5)).toBe(true)
    expect(isTap(11)).toBe(true)
  })

  it("lệch rõ → không phải tap, không lật nhầm", () => {
    expect(isTap(30)).toBe(false)
    expect(isTap(-60)).toBe(false)
  })
})
