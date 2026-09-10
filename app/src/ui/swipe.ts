/**
 * ui/swipe.ts — chuẩn tương tác vuốt trên MẶT TRƯỚC thẻ ôn tập (chủ chốt
 * 2026-09-09): quẹt TRÁI = Easy (4) · quẹt PHẢI = Good (3) · chạm = lật mặt sau.
 *
 * Lớp UI chỉ luân chuyển verdict thành rating rồi gọi vào gradeCard sẵn có —
 * FSRS nhận đúng điểm 3/4 qua đúng pipeline (log = snapshot TRƯỚC khi chấm,
 * cards + log cùng transaction), undo kéo thẻ về snapshot y nguyên như nút bấm.
 * Tách hàm thuần để test máy, không đụng DOM/React.
 */

/** Độ lệch ngang (px) đủ để coi là một cú vuốt chấm — dưới mức này chỉ là kéo chơi. */
export const SWIPE_COMMIT_PX = 96

/** Di chuyển ngang vượt mức này (và thắng trục dọc) thì khoá thành kéo thẻ. */
export const DRAG_LOCK_PX = 8

/** Chạm rung quanh điểm nhấn dưới mức này vẫn là TAP → lật thẻ. */
export const TAP_SLOP_PX = 12

export type SwipeVerdict = "easy" | "good" | null

/**
 * Verdict từ độ lệch ngang lúc nhả tay: trái đủ sâu = easy, phải đủ sâu = good,
 * chưa qua ngưỡng = không phải vuốt (thẻ bật về chỗ cũ).
 */
export function swipeVerdict(dxPx: number): SwipeVerdict {
  if (dxPx <= -SWIPE_COMMIT_PX) return "easy"
  if (dxPx >= SWIPE_COMMIT_PX) return "good"
  return null
}

/**
 * Khi nào khoá thành kéo thẻ: đã khoá rồi thì giữ; chưa khoá thì phải chuyển
 * động đủ lớn VÀ trục ngang thắng trục dọc — ngón tay chủ yếu lăn dọc thì để
 * trang cuộn tự nhiên, không cướp.
 */
export function shouldLockDrag(dxPx: number, dyPx: number, locked: boolean): boolean {
  if (locked) return true
  const ax = Math.abs(dxPx)
  return ax > DRAG_LOCK_PX && ax >= Math.abs(dyPx)
}

/** Đủ "đứng yên" để cú nhả tay được coi là TAP (lật mặt sau). */
export function isTap(dxPx: number): boolean {
  return Math.abs(dxPx) <= TAP_SLOP_PX
}
