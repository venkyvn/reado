/**
 * ui/ToastProvider.tsx — provider + danh sách toast (ADR-020), KHÔNG dùng library.
 *
 * Lắp trong App.tsx, PHÍA TRÊN AppRoot — để AppRoot dùng được `useToast` (từ
 * ./toast.ts) cho các handler nền của nó. Giới hạn: tối đa 3 toast cùng lúc,
 * mỗi toast tự tắt sau 4s hoặc tắt tay bằng nút ✕.
 *
 * Toast KHÔNG thay ErrorBoundary: nó chỉ báo lỗi đã bắt được, không bắt lỗi render.
 */
import { useCallback, useMemo, useRef, useState } from "react"
import type { ReactNode } from "react"
import { ToastContext } from "./toast"
import type { ToastApi } from "./toast"

export interface ToastItem {
  id: number
  kind: "error" | "info"
  message: string
}

export function ToastProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<ToastItem[]>([])
  const nextId = useRef(1)

  const dismiss = useCallback((id: number) => {
    setToasts((ts) => ts.filter((t) => t.id !== id))
  }, [])

  const push = useCallback(
    (kind: ToastItem["kind"], message: string) => {
      const id = nextId.current++
      // Giữ tối đa 2 cái cũ + 1 cái mới = 3 toast — màn hình mobile không bị ngợp.
      setToasts((ts) => [...ts.slice(-2), { id, kind, message }])
      window.setTimeout(() => dismiss(id), 4000)
    },
    [dismiss],
  )

  const api = useMemo<ToastApi>(
    () => ({
      error: (m) => push("error", m),
      info: (m) => push("info", m),
    }),
    [push],
  )

  return (
    <ToastContext.Provider value={api}>
      {children}
      <div className="toast-stack" role="status" aria-live="polite">
        {toasts.map((t) => (
          <div key={t.id} className={`toast toast-${t.kind}`}>
            <span className="toast-msg">{t.message}</span>
            <button
              type="button"
              className="toast-close"
              aria-label="Đóng thông báo"
              onClick={() => dismiss(t.id)}
            >
              ✕
            </button>
          </div>
        ))}
      </div>
    </ToastContext.Provider>
  )
}
