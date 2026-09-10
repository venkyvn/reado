/**
 * ui/toast.ts — context + hook đọc API toast (ADR-020), KHÔNG chứa component.
 *
 * Tách riêng khỏi ToastProvider.tsx vì quy tắc fast-refresh của React: một file
 * nên chỉ export component — hook trộn chung thì file không còn là "chi component".
 *
 * THÔNG TIN sai phải được thấy: lỗi nền (persist phiên đọc hỏng, cờ "đã lưu"
 * hỏng...) hiện toast thay vì console.error âm thầm.
 */
import { createContext, useContext } from "react"

export interface ToastApi {
  error(message: string): void
  info(message: string): void
}

export const ToastContext = createContext<ToastApi | null>(null)

export function useToast(): ToastApi {
  const api = useContext(ToastContext)
  if (!api) throw new Error("useToast phải chạy trong ToastProvider (App.tsx)")
  return api
}
