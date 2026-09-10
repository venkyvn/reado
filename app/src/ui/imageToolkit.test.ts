/**
 * ui/imageToolkit.test.ts — test thuần cho scaledSize (kích thước downscale gửi AI).
 * Phần canvas (drawImage/toBlob) cần browser thật → che bằng e2e, không unit test.
 */
import { describe, expect, it } from "vitest"
import { scaledSize } from "./imageToolkit"

describe("scaledSize — quy tắc 2026-09-09: cạnh dài ≤ maxDimension, KHÔNG upscale", () => {
  it("ảnh photo dọc 3024×4032 → 1200×1600 (cạnh dài = 1600)", () => {
    expect(scaledSize(3024, 4032, 1600)).toEqual({ w: 1200, h: 1600, scaled: true })
  })

  it("ảnh ngang 4032×3024 (spread) → 1600×1200", () => {
    expect(scaledSize(4032, 3024, 1600)).toEqual({ w: 1600, h: 1200, scaled: true })
  })

  it("ảnh đã nhỏ hơn ngưỡng giữ nguyên — KHÔNG upscale", () => {
    expect(scaledSize(360, 480, 1600)).toEqual({ w: 360, h: 480, scaled: false })
    expect(scaledSize(750, 1000, 1600)).toEqual({ w: 750, h: 1000, scaled: false })
    expect(scaledSize(1600, 1600, 1600)).toEqual({ w: 1600, h: 1600, scaled: false })
  })

  it("ảnh đúng bằng ngưỡng cũng không scale", () => {
    expect(scaledSize(1200, 1600, 1600)).toEqual({ w: 1200, h: 1600, scaled: false })
  })

  it("làm tròn kích thước về số nguyên, chặn ≥ 1px", () => {
    // 3000×100 → scale 1600/3000 → 1600×53.33 → làm tròn 53.
    expect(scaledSize(3000, 100, 1600)).toEqual({ w: 1600, h: 53, scaled: true })
    // Ảnh dẹt cực đoan 5000×1 → 1600×0.32 → làm tròn 0 → chặn về ≥ 1.
    expect(scaledSize(5000, 1, 1600)).toEqual({ w: 1600, h: 1, scaled: true })
  })
})
