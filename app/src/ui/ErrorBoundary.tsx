/**
 * ui/ErrorBoundary.tsx — chặn lỗi render của toàn app (ADR-020).
 *
 * Chỉ bắt lỗi trong cây React (render/lifecycle) — KHÔNG bắt lỗi event handler
 * hay promise (những lỗi đó có đường riêng: AnalysisError có UI retry, lỗi nền
 * đi qua toast). Mục đích: user không bao giờ thấy màn hình trắng; dữ liệu nằm
 * trong SQLite/OPFS nên lỗi render KHÔNG đụng tới dữ liệu đã lưu.
 */
import { Component } from "react"
import type { ErrorInfo, ReactNode } from "react"

interface Props {
  children: ReactNode
}

interface State {
  error: Error | null
}

export class ErrorBoundary extends Component<Props, State> {
  state: State = { error: null }

  static getDerivedStateFromError(error: Error): State {
    return { error }
  }

  componentDidCatch(error: Error, info: ErrorInfo): void {
    // Vẫn ghi log đầy đủ để debug — đây là lỗi thật cần sửa, không phải lỗi nền.
    console.error("ErrorBoundary bắt lỗi render:", error, info.componentStack)
  }

  render() {
    if (this.state.error) {
      return (
        <main className="shell pad">
          <h1>Reado</h1>
          <div className="banner banner-error">
            Có lỗi không mong đợi khi vẽ màn hình này. Dữ liệu của bạn vẫn an toàn trong kho lưu trữ
            — tải lại là có thể dùng tiếp.
          </div>
          <p className="fine">{this.state.error.message}</p>
          <button type="button" className="primary" onClick={() => window.location.reload()}>
            Tải lại ứng dụng
          </button>
        </main>
      )
    }
    return this.props.children
  }
}
